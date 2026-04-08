import 'dart:async';
import 'dart:collection';
import 'dart:math';

import '../client/redis.dart';
import '../client/redis_status.dart';
import '../command/command.dart';
import '../errors.dart';
import 'cluster_options.dart';
import 'connection_pool.dart';
import 'delay_queue.dart';

/// Redis Cluster client status.
enum ClusterStatus {
  wait,
  connecting,
  connect,
  ready,
  reconnecting,
  disconnecting,
  close,
  end,
}

/// A Redis Cluster client.
///
/// Automatically routes commands to the correct node based on key slot,
/// handles MOVED/ASK redirects, and manages cluster topology.
class RedisCluster {
  RedisCluster(
    this._startupNodes, [
    ClusterOptions options = const ClusterOptions(),
  ]) : this.options = options,
       _connectionPool = ConnectionPool(options.redisOptions) {
    if (!this.options.lazyConnect) {
      scheduleMicrotask(() {
        if (_status == ClusterStatus.wait) {
          this.connect();
        }
      });
    }
  }

  final List<ClusterNode> _startupNodes;
  final ClusterOptions options;
  final ConnectionPool _connectionPool;
  final DelayQueue _delayQueue = DelayQueue();

  ClusterStatus _status = ClusterStatus.wait;
  ClusterStatus get status => _status;

  /// 16384 slots → list of node keys [master, replica1, ...]
  final List<List<String>> _slots = List<List<String>>.generate(
    16384,
    (_) => const [],
  );

  /// Offline queue for commands sent before ready.
  final Queue<Command> _offlineQueue = Queue<Command>();

  /// Whether a topology refresh is in-flight.
  bool _isRefreshing = false;

  /// Connection epoch for stale-detection.
  int _connectionEpoch = 0;

  int _retryAttempts = 0;

  final _random = Random();

  // === Events ===

  final StreamController<void> _onReady = StreamController<void>.broadcast();
  final StreamController<Object> _onError = StreamController<Object>.broadcast();
  final StreamController<void> _onClose = StreamController<void>.broadcast();
  final StreamController<void> _onEnd = StreamController<void>.broadcast();

  Stream<void> get onReady => _onReady.stream;
  Stream<Object> get onError => _onError.stream;
  Stream<void> get onClose => _onClose.stream;
  Stream<void> get onEnd => _onEnd.stream;

  // === Lifecycle ===

  /// Connect to the cluster.
  Future<void> connect() async {
    if (_status == ClusterStatus.ready ||
        _status == ClusterStatus.connecting) {
      return;
    }

    _status = ClusterStatus.connecting;
    _connectionEpoch++;
    final epoch = _connectionEpoch;

    // Initialize connection pool with startup nodes
    final nodes =
        _startupNodes
            .map(
              (n) => (host: n.host, port: n.port, readOnly: false),
            )
            .toList();
    _connectionPool.reset(nodes);

    // Connect to at least one node
    for (final node in _startupNodes) {
      final client = _connectionPool.getByKey(node.key);
      if (client == null) continue;
      try {
        await client.connect();
        break;
      } catch (_) {
        continue;
      }
    }

    if (epoch != _connectionEpoch) return;

    // Refresh slot mapping
    try {
      await this.refreshSlotsCache();
    } catch (e) {
      if (epoch != _connectionEpoch) return;
      _onError.add(e);
      _status = ClusterStatus.close;
      _handleReconnect();
      return;
    }

    if (epoch != _connectionEpoch) return;

    _status = ClusterStatus.ready;
    _retryAttempts = 0;
    _onReady.add(null);

    // Replay offline queue
    while (_offlineQueue.isNotEmpty) {
      final cmd = _offlineQueue.removeFirst();
      this.sendCommand(cmd);
    }
  }

  /// Disconnect from the cluster.
  Future<void> disconnect() async {
    if (_status == ClusterStatus.end) return;
    _status = ClusterStatus.end;
    _delayQueue.clear();

    // Reject pending commands
    while (_offlineQueue.isNotEmpty) {
      _offlineQueue.removeFirst().reject(const ConnectionClosedError());
    }

    await _connectionPool.disconnectAll();
    _onEnd.add(null);
  }

  /// Get nodes by role.
  List<Redis> nodes([NodeRole role = NodeRole.all]) {
    return _connectionPool.getNodes(role);
  }

  // === Command Execution ===

  /// Send a command to the appropriate cluster node.
  ///
  /// Handles MOVED/ASK redirects transparently — the caller gets a Future
  /// that resolves after all redirects are followed.
  Future<Object?> sendCommand(Command command, {int redirections = 0}) async {
    if (_status != ClusterStatus.ready) {
      if (this.options.enableOfflineQueue) {
        _offlineQueue.add(command);
        return command.future;
      }
      throw const ConnectionClosedError();
    }

    final slot = command.getSlot();
    Redis? node;

    if (slot == null) {
      node = _connectionPool.getSample(NodeRole.master);
      if (node == null) throw ClusterAllFailedError();
    } else {
      final nodeKey = _selectNode(slot, command.readOnly);
      node = _connectionPool.getByKey(nodeKey);
      if (node == null) {
        throw RedisError('ERR No node available for slot $slot ($nodeKey)');
      }
    }

    try {
      // Ensure node is connected
      if (node.status != RedisStatus.ready) {
        await node.connect();
      }

      final cmd = Command(command.name, command.args);
      return await node.sendCommand(cmd);
    } on RedisRedirectError catch (e) {
      if (redirections >= this.options.maxRedirections) {
        rethrow;
      }
      if (e.redirectType == 'MOVED') {
        return _handleMoved(e, command, slot ?? 0, redirections);
      } else if (e.redirectType == 'ASK') {
        return _handleAsk(e, command, redirections);
      }
      rethrow;
    } on RedisError catch (e) {
      if (redirections >= this.options.maxRedirections) rethrow;
      final msg = e.message;
      if (msg.startsWith('TRYAGAIN')) {
        await Future<void>.delayed(this.options.retryDelayOnTryAgain);
        return this.sendCommand(command, redirections: redirections + 1);
      } else if (msg.startsWith('CLUSTERDOWN')) {
        await Future<void>.delayed(this.options.retryDelayOnClusterDown);
        await this.refreshSlotsCache();
        return this.sendCommand(command, redirections: redirections + 1);
      }
      rethrow;
    }
  }

  /// Execute an arbitrary command.
  Future<Object?> call(String name, [List<Object?> args = const []]) {
    final command = Command(name, args);
    return this.sendCommand(command);
  }

  // === Topology ===

  /// Refresh the cluster slot mapping from the server.
  Future<void> refreshSlotsCache() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final allNodes = _connectionPool.getNodes();
      // Shuffle to distribute load
      final shuffled = List<Redis>.from(allNodes)..shuffle(_random);

      Object? lastError;
      for (final node in shuffled) {
        try {
          if (node.status != RedisStatus.ready) {
            await node.connect();
          }
          final result = await node.call('CLUSTER', ['SLOTS']);
          if (result is List) {
            _parseSlotInfo(result);
            return;
          }
        } catch (e) {
          lastError = e;
          continue;
        }
      }
      throw ClusterAllFailedError(lastError);
    } finally {
      _isRefreshing = false;
    }
  }

  void _parseSlotInfo(List<Object?> slotsData) {
    final newNodes = <({String host, int port, bool readOnly})>[];

    for (final range in slotsData) {
      if (range is! List || range.length < 3) continue;

      final startSlot = range[0] as int;
      final endSlot = range[1] as int;

      final nodeKeys = <String>[];

      for (var i = 2; i < range.length; i++) {
        final nodeInfo = range[i];
        if (nodeInfo is! List || nodeInfo.length < 2) continue;

        final host = nodeInfo[0].toString();
        final port = nodeInfo[1] as int;
        final key = '$host:$port';
        final isReplica = i > 2;

        nodeKeys.add(key);
        newNodes.add((host: host, port: port, readOnly: isReplica));
      }

      for (var slot = startSlot; slot <= endSlot; slot++) {
        _slots[slot] = nodeKeys;
      }
    }

    // Update connection pool
    _connectionPool.reset(newNodes);
  }

  String _selectNode(int slot, bool readOnly) {
    final nodeKeys = _slots[slot];
    if (nodeKeys.isEmpty) {
      // Fallback: random master
      final sample = _connectionPool.getSample(NodeRole.master);
      return sample != null ? '${sample.options.host}:${sample.options.port}' : '';
    }

    if (readOnly && this.options.scaleReads != ScaleReads.master) {
      if (nodeKeys.length > 1) {
        // Random replica
        return nodeKeys[1 + _random.nextInt(nodeKeys.length - 1)];
      }
    }

    return nodeKeys[0]; // master
  }

  Future<Object?> _handleMoved(
    RedisRedirectError error,
    Command command,
    int slot,
    int redirections,
  ) async {
    // Update slot mapping
    final nodeKey = '${error.host}:${error.port}';
    _slots[slot] = [nodeKey, ..._slots[slot].where((k) => k != nodeKey)];

    // Ensure node exists in pool
    final node = _connectionPool.findOrCreate(error.host, error.port);
    if (node.status != RedisStatus.ready) {
      await node.connect();
    }

    // Refresh topology in background
    if (this.options.retryDelayOnMoved == Duration.zero) {
      // Fire and forget
      this.refreshSlotsCache().catchError((_) {});
    } else {
      _delayQueue.push(
        'moved',
        () => this.refreshSlotsCache(),
        this.options.retryDelayOnMoved,
      );
    }

    // Retry command on correct node
    return this.sendCommand(command, redirections: redirections + 1);
  }

  Future<Object?> _handleAsk(
    RedisRedirectError error,
    Command command,
    int redirections,
  ) async {
    final node = _connectionPool.findOrCreate(error.host, error.port);
    if (node.status != RedisStatus.ready) {
      await node.connect();
    }
    // Send ASKING then retry on that specific node
    await node.call('ASKING');
    final cmd = Command(command.name, command.args);
    return node.sendCommand(cmd);
  }

  void _handleReconnect() {
    final strategy = this.options.clusterRetryStrategy;
    if (strategy == null) {
      _status = ClusterStatus.end;
      _onEnd.add(null);
      return;
    }

    _retryAttempts++;
    final delay = strategy(_retryAttempts, null);
    if (delay == null) {
      _status = ClusterStatus.end;
      _onEnd.add(null);
      return;
    }

    _status = ClusterStatus.reconnecting;
    Timer(delay, () {
      if (_status == ClusterStatus.reconnecting) {
        this.connect();
      }
    });
  }

  /// Close the cluster and release all resources.
  Future<void> close() async {
    await this.disconnect();
    await _onReady.close();
    await _onError.close();
    await _onClose.close();
    await _onEnd.close();
  }
}
