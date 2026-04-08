import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import '../command/command.dart';
import '../connectors/connector.dart';
import '../connectors/standalone_connector.dart';
import '../errors.dart';
import '../protocol/resp_parser.dart';
import '../pubsub/subscription_set.dart';
import 'redis_options.dart';
import 'redis_status.dart';

/// A Redis pub/sub message.
class PubSubMessage {
  PubSubMessage({required this.channel, required this.message, this.pattern});

  final String channel;
  final String? pattern;
  final String message;
}

/// A production-grade Redis client for Dart.
///
/// Supports connection management, reconnection, offline queue,
/// pub/sub, and the full Redis command set.
class Redis {
  Redis([RedisOptions options = const RedisOptions()])
    : this.options = options,
      _connector =
          options.connector ??
          StandaloneConnector(
            host: options.host,
            port: options.port,
            securityContext: options.securityContext,
            connectTimeout: options.connectTimeout,
            noDelay: options.noDelay,
            keepAlive: options.keepAlive,
          ) {
    if (!options.lazyConnect) {
      // Schedule connection in next microtask to allow listeners to attach
      scheduleMicrotask(() {
        if (_status == RedisStatus.wait) {
          this.connect();
        }
      });
    }
  }

  /// Create a Redis client from a URL.
  ///
  /// Format: `redis://[username:password@]host[:port][/db]`
  factory Redis.fromUrl(String url, [RedisOptions? overrides]) {
    final uri = Uri.parse(url);
    final baseOptions = RedisOptions(
      host: uri.host.isEmpty ? 'localhost' : uri.host,
      port: uri.port == 0 ? 6379 : uri.port,
      username:
          uri.userInfo.contains(':')
              ? uri.userInfo.split(':').first
              : null,
      password:
          uri.userInfo.contains(':') ? uri.userInfo.split(':').last : null,
      db:
          uri.pathSegments.isNotEmpty
              ? int.tryParse(uri.pathSegments.first) ?? 0
              : 0,
    );

    if (overrides != null) {
      return Redis(
        baseOptions.copyWith(
          connectTimeout: overrides.connectTimeout,
          commandTimeout: overrides.commandTimeout,
          lazyConnect: overrides.lazyConnect,
          enableOfflineQueue: overrides.enableOfflineQueue,
          retryStrategy: overrides.retryStrategy,
          maxRetriesPerRequest: overrides.maxRetriesPerRequest,
        ),
      );
    }
    return Redis(baseOptions);
  }

  final RedisOptions options;
  final Connector _connector;

  RedisStatus _status = RedisStatus.wait;
  RedisStatus get status => _status;

  Socket? _socket;
  StreamSubscription<List<int>>? _socketSubscription;
  RespParser? _parser;

  /// FIFO queue of commands waiting for server replies.
  final Queue<Command> _commandQueue = Queue<Command>();
  List<Command>? _prevCommandQueue;

  /// Commands queued while not connected (replayed on ready).
  final Queue<Command> _offlineQueue = Queue<Command>();

  /// Tracks whether we're in subscriber mode.
  bool _subscriberMode = false;

  /// Active pub/sub subscriptions for auto-resubscribe.
  final SubscriptionSet _subscriptions = SubscriptionSet();

  /// Current database index (for restoring after reconnect).
  int _currentDb = 0;

  /// Connection epoch — incremented on each connect to discard stale handlers.
  int _connectionEpoch = 0;

  /// Retry attempt counter.
  int _retryAttempts = 0;

  /// Timer for reconnection delay.
  Timer? _reconnectTimer;

  /// Timer for socket timeout.
  Timer? _socketTimeoutTimer;

  /// Whether user manually initiated disconnect.
  bool _manuallyClosing = false;

  // === Event Streams ===

  final StreamController<void> _onConnect = StreamController<void>.broadcast();
  final StreamController<void> _onReady = StreamController<void>.broadcast();
  final StreamController<Object> _onError = StreamController<Object>.broadcast();
  final StreamController<void> _onClose = StreamController<void>.broadcast();
  final StreamController<void> _onEnd = StreamController<void>.broadcast();
  final StreamController<int> _onReconnecting =
      StreamController<int>.broadcast();
  final StreamController<PubSubMessage> _onMessage =
      StreamController<PubSubMessage>.broadcast();

  Stream<void> get onConnect => _onConnect.stream;
  Stream<void> get onReady => _onReady.stream;
  Stream<Object> get onError => _onError.stream;
  Stream<void> get onClose => _onClose.stream;
  Stream<void> get onEnd => _onEnd.stream;
  Stream<int> get onReconnecting => _onReconnecting.stream;

  /// Stream of pub/sub messages.
  Stream<PubSubMessage> get messages => _onMessage.stream;

  // === Lifecycle ===

  /// Connect to the Redis server.
  Future<void> connect() async {
    if (_status == RedisStatus.ready || _status == RedisStatus.connecting) {
      return;
    }

    _status = RedisStatus.connecting;
    _connectionEpoch++;
    final epoch = _connectionEpoch;

    try {
      _socket = await _connector.connect();
    } catch (e) {
      if (epoch != _connectionEpoch) return; // stale
      _status = RedisStatus.close;
      _onError.add(e);
      _handleClose();
      return;
    }

    if (epoch != _connectionEpoch) return; // stale

    _status = RedisStatus.connect;
    _onConnect.add(null);

    // Wire up RESP parser
    _parser = RespParser(
      onReply: _handleReply,
      onError: _handleParseError,
      stringNumbers: this.options.stringNumbers,
    );

    _socketSubscription = _socket!.listen(
      _handleData,
      onError: _handleSocketError,
      onDone: _handleSocketDone,
    );

    // Handshake: AUTH → SELECT → CLIENT SETNAME → ready check
    await _performHandshake(epoch);
  }

  Future<void> _performHandshake(int epoch) async {
    try {
      // AUTH
      if (this.options.password != null) {
        if (this.options.username != null) {
          await _sendInternalCommand('AUTH', [
            this.options.username!,
            this.options.password!,
          ]);
        } else {
          await _sendInternalCommand('AUTH', [this.options.password!]);
        }
      }

      if (epoch != _connectionEpoch) return;

      // SELECT
      _currentDb = this.options.db;
      if (_currentDb != 0) {
        await _sendInternalCommand('SELECT', [_currentDb.toString()]);
      }

      if (epoch != _connectionEpoch) return;

      // CLIENT SETNAME
      if (this.options.connectionName != null) {
        await _sendInternalCommand('CLIENT', [
          'SETNAME',
          this.options.connectionName!,
        ]);
      }

      if (epoch != _connectionEpoch) return;

      // READONLY (for cluster replicas)
      if (this.options.readOnly) {
        await _sendInternalCommand('READONLY', []);
      }

      if (epoch != _connectionEpoch) return;

      // Ready check
      if (this.options.enableReadyCheck) {
        final info = await _sendInternalCommand('INFO', []);
        if (epoch != _connectionEpoch) return;

        final infoStr = info?.toString() ?? '';
        if (infoStr.contains('loading:1')) {
          // Server is still loading — wait and retry
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (epoch != _connectionEpoch) return;
          await _performHandshake(epoch);
          return;
        }
      }

      // Ready!
      _status = RedisStatus.ready;
      _retryAttempts = 0;
      _onReady.add(null);

      // Resend unfulfilled commands from previous connection
      if (_prevCommandQueue != null) {
        for (final cmd in _prevCommandQueue!) {
          this.sendCommand(cmd);
        }
        _prevCommandQueue = null;
      }

      // Replay offline queue
      _replayOfflineQueue();

      // Auto-resubscribe
      if (this.options.autoResubscribe && !_subscriptions.isEmpty) {
        await _resubscribe();
      }
    } catch (e) {
      if (epoch != _connectionEpoch) return;
      _onError.add(e);
      this.disconnect();
    }
  }

  /// Disconnect from the server.
  Future<void> disconnect({bool reconnect = false}) async {
    if (_status == RedisStatus.end) return;

    _manuallyClosing = !reconnect;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socketTimeoutTimer?.cancel();
    _socketTimeoutTimer = null;

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    _connector.disconnect();
    _socket = null;
    _parser?.reset();

    if (!reconnect) {
      _status = RedisStatus.end;
      _flushQueues(const ConnectionClosedError());
      _onEnd.add(null);
    } else {
      _status = RedisStatus.close;
      _handleClose();
    }
  }

  /// Create a duplicate client with the same or overridden options.
  Redis duplicate([RedisOptions? overrides]) {
    return Redis(overrides ?? this.options);
  }

  // === Command Execution ===

  /// Send a command to Redis.
  Future<Object?> sendCommand(Command command) {
    // In subscriber mode, only certain commands are allowed
    if (_subscriberMode && !command.isValidInSubscriberMode) {
      command.reject(
        RedisError(
          'ERR only (P|S)SUBSCRIBE / (P|S)UNSUBSCRIBE / PING / QUIT are allowed in this context',
        ),
      );
      return command.future;
    }

    if (_status == RedisStatus.ready) {
      _writeCommand(command);
    } else if (_status == RedisStatus.end) {
      command.reject(const ConnectionClosedError());
    } else if (this.options.enableOfflineQueue) {
      _offlineQueue.add(command);
    } else {
      command.reject(const ConnectionClosedError());
    }

    return command.future;
  }

  /// Execute an arbitrary command by name.
  Future<Object?> call(String name, [List<Object?> args = const []]) {
    final command = Command(name, args, keyPrefix: this.options.keyPrefix);
    if (this.options.commandTimeout != null) {
      command.setTimeout(this.options.commandTimeout!);
    }
    return this.sendCommand(command);
  }

  // === Pub/Sub ===

  /// Subscribe to channels.
  Future<void> subscribe(List<String> channels) async {
    for (final ch in channels) {
      _subscriptions.add('subscribe', ch);
    }
    await this.call('SUBSCRIBE', channels);
  }

  /// Subscribe to patterns.
  Future<void> psubscribe(List<String> patterns) async {
    for (final p in patterns) {
      _subscriptions.add('psubscribe', p);
    }
    await this.call('PSUBSCRIBE', patterns);
  }

  /// Unsubscribe from channels.
  Future<void> unsubscribe([List<String>? channels]) async {
    if (channels != null) {
      for (final ch in channels) {
        _subscriptions.remove('unsubscribe', ch);
      }
    } else {
      _subscriptions.channels('subscribe').clear();
    }
    await this.call('UNSUBSCRIBE', channels ?? []);
  }

  /// Unsubscribe from patterns.
  Future<void> punsubscribe([List<String>? patterns]) async {
    if (patterns != null) {
      for (final p in patterns) {
        _subscriptions.remove('punsubscribe', p);
      }
    } else {
      _subscriptions.channels('psubscribe').clear();
    }
    await this.call('PUNSUBSCRIBE', patterns ?? []);
  }

  /// Publish a message to a channel.
  Future<int> publish(String channel, String message) async {
    final result = await this.call('PUBLISH', [channel, message]);
    return result as int;
  }

  // === Pipeline & Transaction ===

  /// Create a new pipeline for command batching.
  Pipeline pipeline() {
    return Pipeline._(this);
  }

  /// Create a MULTI/EXEC transaction pipeline.
  Pipeline multi() {
    final p = Pipeline._(this);
    p._addRaw('MULTI', []);
    return p;
  }

  // === Internals ===

  void _writeCommand(Command command) {
    if (_socket == null) {
      command.reject(const ConnectionClosedError());
      return;
    }

    try {
      _socket!.add(command.toWritable());
      _commandQueue.add(command);
      _resetSocketTimeout();
    } catch (e) {
      command.reject(e);
    }
  }

  Future<Object?> _sendInternalCommand(String name, List<Object> args) {
    final command = Command(name, args);
    _writeCommand(command);
    return command.future;
  }

  void _handleData(List<int> data) {
    _resetSocketTimeout();
    _parser?.addData(data is Uint8List ? data : Uint8List.fromList(data));
  }

  void _handleReply(Object? reply) {
    // Check for pub/sub messages and subscription confirmations.
    // Must check even when not in subscriber mode (to handle initial SUBSCRIBE reply).
    if (reply is List && reply.isNotEmpty) {
      final type = reply[0].toString().toLowerCase();
      switch (type) {
        case 'message':
          _onMessage.add(
            PubSubMessage(
              channel: reply[1].toString(),
              message: reply[2].toString(),
            ),
          );
          return;
        case 'pmessage':
          _onMessage.add(
            PubSubMessage(
              pattern: reply[1].toString(),
              channel: reply[2].toString(),
              message: reply[3].toString(),
            ),
          );
          return;
        case 'smessage':
          _onMessage.add(
            PubSubMessage(
              channel: reply[1].toString(),
              message: reply[2].toString(),
            ),
          );
          return;
        case 'subscribe':
        case 'psubscribe':
        case 'ssubscribe':
          _subscriberMode = true;
          if (_commandQueue.isNotEmpty) {
            _commandQueue.removeFirst().resolve(reply);
          }
          return;
        case 'unsubscribe':
        case 'punsubscribe':
        case 'sunsubscribe':
          final count = reply[2];
          if (count is int && count == 0) {
            _subscriberMode = false;
          }
          if (_commandQueue.isNotEmpty) {
            _commandQueue.removeFirst().resolve(reply);
          }
          return;
      }
    }

    // Normal command reply
    if (_commandQueue.isNotEmpty) {
      final command = _commandQueue.removeFirst();
      if (reply is RedisError) {
        this._handleCommandError(command, reply);
      } else {
        command.resolve(reply);
      }
    }
  }

  /// Handle Redis error on a command — check reconnectOnError callback.
  void _handleCommandError(Command command, RedisError error) {
    final callback = this.options.reconnectOnError;
    if (callback == null) {
      command.reject(error);
      return;
    }

    final action = callback(error);
    switch (action) {
      case ReconnectAction.none:
        command.reject(error);
      case ReconnectAction.reconnect:
        if (_status != RedisStatus.reconnecting) {
          this.disconnect(reconnect: true);
        }
        command.reject(error);
      case ReconnectAction.reconnectAndResend:
        if (_status != RedisStatus.reconnecting) {
          this.disconnect(reconnect: true);
        }
        this.sendCommand(command);
    }
  }

  void _handleParseError(RedisError error) {
    // Server replied with an error (e.g. WRONGTYPE, ERR) — route to command queue
    if (_commandQueue.isNotEmpty) {
      _commandQueue.removeFirst().reject(error);
    } else {
      _onError.add(error);
    }
  }

  void _handleSocketError(Object error) {
    _onError.add(error);
  }

  void _handleSocketDone() {
    _socketSubscription = null;
    _socket = null;

    if (_status == RedisStatus.end) return;

    _status = RedisStatus.close;
    _onClose.add(null);
    _handleClose();
  }

  void _handleClose() {
    if (_manuallyClosing) {
      _manuallyClosing = false;
      return;
    }

    // Abort incomplete transactions before saving
    _abortTransactionFragments(_commandQueue);
    _abortTransactionFragments(_offlineQueue);

    // Save or flush command queue
    if (this.options.autoResendUnfulfilledCommands && _commandQueue.isNotEmpty) {
      _prevCommandQueue = _commandQueue.toList();
      _commandQueue.clear();
    } else if (this.options.maxRetriesPerRequest != null) {
      _flushCommandQueue();
    }

    // Retry strategy
    final strategy = this.options.retryStrategy;
    if (strategy == null) {
      _status = RedisStatus.end;
      _flushQueues(const ConnectionClosedError());
      _onEnd.add(null);
      return;
    }

    _retryAttempts++;
    final delay = strategy(_retryAttempts);
    if (delay == null) {
      _status = RedisStatus.end;
      _flushQueues(const ConnectionClosedError());
      _onEnd.add(null);
      return;
    }

    _status = RedisStatus.reconnecting;
    _onReconnecting.add(_retryAttempts);

    _reconnectTimer = Timer(delay, () {
      if (_status == RedisStatus.reconnecting) {
        this.connect();
      }
    });
  }

  /// Remove incomplete transaction commands from queue.
  /// Commands between MULTI and EXEC that haven't completed are rejected.
  /// MULTI/EXEC is atomic — can't be partially resent.
  void _abortTransactionFragments(Queue<Command> queue) {
    final toRemove = <Command>[];

    for (final cmd in queue) {
      if (cmd.name == 'multi') break;
      if (cmd.name == 'exec') {
        toRemove.add(cmd);
        break;
      }
      if (cmd.inTransaction) {
        toRemove.add(cmd);
      }
    }

    for (final cmd in toRemove) {
      queue.remove(cmd);
      cmd.reject(RedisError('Connection lost during MULTI/EXEC transaction'));
    }
  }

  void _flushCommandQueue() {
    while (_commandQueue.isNotEmpty) {
      final cmd = _commandQueue.removeFirst();
      cmd.reject(const ConnectionClosedError());
    }
  }

  void _flushQueues(Object error) {
    while (_commandQueue.isNotEmpty) {
      _commandQueue.removeFirst().reject(error);
    }
    while (_offlineQueue.isNotEmpty) {
      _offlineQueue.removeFirst().reject(error);
    }
  }

  void _replayOfflineQueue() {
    while (_offlineQueue.isNotEmpty) {
      final command = _offlineQueue.removeFirst();
      _writeCommand(command);
    }
  }

  Future<void> _resubscribe() async {
    final subs = _subscriptions.channels('subscribe');
    if (subs.isNotEmpty) {
      await this.call('SUBSCRIBE', subs.toList());
    }
    final psubs = _subscriptions.channels('psubscribe');
    if (psubs.isNotEmpty) {
      await this.call('PSUBSCRIBE', psubs.toList());
    }
  }

  void _resetSocketTimeout() {
    _socketTimeoutTimer?.cancel();
    if (this.options.socketTimeout != null) {
      _socketTimeoutTimer = Timer(this.options.socketTimeout!, () {
        this.disconnect(reconnect: true);
      });
    }
  }

  /// Close all stream controllers.
  Future<void> close() async {
    await this.disconnect();
    await _onConnect.close();
    await _onReady.close();
    await _onError.close();
    await _onClose.close();
    await _onEnd.close();
    await _onReconnecting.close();
    await _onMessage.close();
  }
}

// === Pipeline ===

/// Batches multiple commands into a single network roundtrip.
class Pipeline {
  Pipeline._(this._redis);

  final Redis _redis;
  final List<Command> _queue = [];
  bool _isTransaction = false;

  void _addRaw(String name, List<Object?> args) {
    final cmd = Command(name, args, keyPrefix: _redis.options.keyPrefix);
    _queue.add(cmd);
    if (name.toUpperCase() == 'MULTI') {
      _isTransaction = true;
    }
  }

  /// Add a command to the pipeline.
  Pipeline addCommand(String name, [List<Object?> args = const []]) {
    _addRaw(name, args);
    return this;
  }

  /// Execute all queued commands.
  ///
  /// Returns a list of `(error, result)` tuples.
  Future<List<(Object? error, Object? result)>> exec() async {
    if (_isTransaction) {
      _addRaw('EXEC', []);
    }

    if (_queue.isEmpty) return const [];

    // Assign pipeline indices
    for (var i = 0; i < _queue.length; i++) {
      _queue[i].pipelineIndex = i;
    }

    // Send all commands at once
    for (final cmd in _queue) {
      _redis.sendCommand(cmd);
    }

    // Collect all results
    final results = <(Object? error, Object? result)>[];

    for (final cmd in _queue) {
      try {
        final result = await cmd.future;
        results.add((null, result));
      } catch (e) {
        results.add((e, null));
      }
    }

    if (_isTransaction) {
      // For transactions: unwrap EXEC result
      // First result is MULTI (OK), last is EXEC (array of results)
      // Return only the inner results
      return results;
    }

    return results;
  }
}
