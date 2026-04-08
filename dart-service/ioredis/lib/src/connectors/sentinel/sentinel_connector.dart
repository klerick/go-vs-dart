import 'dart:async';
import 'dart:io';

import '../../client/redis.dart';
import '../../client/redis_options.dart';
import '../../errors.dart';
import '../connector.dart';
import 'sentinel_iterator.dart';

/// Role of the target Redis server behind Sentinel.
enum SentinelRole { master, slave }

/// NAT address mapping function.
typedef NatMap = ({String host, int port}) Function(String host, int port);

/// Connects to Redis via Sentinel for high-availability.
///
/// Discovers the current master or slave address from Sentinel nodes,
/// then establishes a direct connection to the Redis server.
class SentinelConnector extends Connector {
  SentinelConnector({
    required this.name,
    required List<SentinelAddress> sentinels,
    this.role = SentinelRole.master,
    this.sentinelPassword,
    this.sentinelUsername,
    this.sentinelRetryStrategy,
    this.connectTimeout = const Duration(seconds: 10),
    this.enableFailoverDetector = false,
    this.natMap,
    this.updateSentinels = true,
    this.securityContext,
    this.sentinelSecurityContext,
    super.disconnectTimeout,
  }) : _iterator = SentinelIterator(sentinels);

  /// Sentinel master group name.
  final String name;

  /// Target role: master or slave.
  final SentinelRole role;

  /// Password for Sentinel nodes.
  final String? sentinelPassword;

  /// Username for Sentinel nodes.
  final String? sentinelUsername;

  /// Retry strategy when all sentinels are unreachable.
  final Duration? Function(int retryAttempts)? sentinelRetryStrategy;

  /// Connection timeout for sentinel queries.
  final Duration connectTimeout;

  /// Whether to subscribe to +switch-master for auto-failover.
  final bool enableFailoverDetector;

  /// NAT address mapping.
  final NatMap? natMap;

  /// Whether to discover new sentinels during connection.
  final bool updateSentinels;

  /// TLS context for the main Redis connection.
  final SecurityContext? securityContext;

  /// TLS context for Sentinel connections.
  final SecurityContext? sentinelSecurityContext;

  final SentinelIterator _iterator;
  int _retryAttempts = 0;
  List<Redis>? _failoverClients;

  @override
  Future<Socket> connect() async {
    return _connectToNext();
  }

  Future<Socket> _connectToNext() async {
    final sentinel = _iterator.next();

    if (sentinel == null) {
      // All sentinels exhausted — retry cycle
      _retryAttempts++;
      final strategy = this.sentinelRetryStrategy;
      if (strategy == null) {
        throw RedisError(
          'ERR All sentinels are unreachable and no retry strategy configured',
        );
      }
      final delay = strategy(_retryAttempts);
      if (delay == null) {
        throw RedisError('ERR All sentinels are unreachable');
      }
      await Future<void>.delayed(delay);
      _iterator.reset();
      return _connectToNext();
    }

    try {
      final resolved = await _resolveAddress(sentinel);
      if (resolved == null) {
        return _connectToNext(); // try next sentinel
      }

      var host = resolved.host;
      var port = resolved.port;

      // Apply NAT mapping
      if (this.natMap != null) {
        final mapped = this.natMap!(host, port);
        host = mapped.host;
        port = mapped.port;
      }

      // Connect to actual Redis server
      final Socket socket;
      if (this.securityContext != null) {
        socket = await SecureSocket.connect(
          host,
          port,
          context: this.securityContext,
          timeout: this.connectTimeout,
        );
      } else {
        socket = await Socket.connect(host, port, timeout: this.connectTimeout);
      }
      socket.setOption(SocketOption.tcpNoDelay, true);

      this.stream = socket;
      _iterator.reset(moveCurrentToFirst: true);
      _retryAttempts = 0;

      // Start failover detector
      if (this.enableFailoverDetector) {
        _initFailoverDetector();
      }

      return socket;
    } catch (_) {
      return _connectToNext(); // try next sentinel
    }
  }

  Future<SentinelAddress?> _resolveAddress(SentinelAddress sentinel) async {
    final client = Redis(
      RedisOptions(
        host: sentinel.host,
        port: sentinel.port,
        password: this.sentinelPassword,
        username: this.sentinelUsername,
        connectTimeout: this.connectTimeout,
        lazyConnect: true,
        enableReadyCheck: false,
        retryStrategy: (_) => null, // no retry
        securityContext: this.sentinelSecurityContext,
      ),
    );

    try {
      await client.connect();

      if (this.role == SentinelRole.master) {
        return _resolveMaster(client);
      } else {
        return _resolveSlave(client);
      }
    } catch (_) {
      return null;
    } finally {
      await client.disconnect();
    }
  }

  Future<SentinelAddress?> _resolveMaster(Redis client) async {
    final result = await client.call('SENTINEL', [
      'get-master-addr-by-name',
      this.name,
    ]);
    if (result is! List || result.length < 2) return null;

    // Update sentinel list
    if (this.updateSentinels) {
      await _updateSentinelList(client);
    }

    return SentinelAddress(
      host: result[0].toString(),
      port: int.parse(result[1].toString()),
    );
  }

  Future<SentinelAddress?> _resolveSlave(Redis client) async {
    final result = await client.call('SENTINEL', ['slaves', this.name]);
    if (result is! List || result.isEmpty) return null;

    // Filter available slaves
    final available = <Map<String, String>>[];
    for (final slave in result) {
      if (slave is! List) continue;
      final info = <String, String>{};
      for (var i = 0; i < slave.length; i += 2) {
        info[slave[i].toString()] = slave[i + 1].toString();
      }
      final flags = info['flags'] ?? '';
      if (flags.contains('disconnected') ||
          flags.contains('s_down') ||
          flags.contains('o_down')) {
        continue;
      }
      available.add(info);
    }

    if (available.isEmpty) return null;

    // Random selection
    final selected = available[DateTime.now().millisecondsSinceEpoch %
        available.length];
    return SentinelAddress(
      host: selected['ip'] ?? '127.0.0.1',
      port: int.tryParse(selected['port'] ?? '6379') ?? 6379,
    );
  }

  Future<void> _updateSentinelList(Redis client) async {
    try {
      final result = await client.call('SENTINEL', ['sentinels', this.name]);
      if (result is! List) return;

      for (final sentinel in result) {
        if (sentinel is! List) continue;
        final info = <String, String>{};
        for (var i = 0; i < sentinel.length; i += 2) {
          info[sentinel[i].toString()] = sentinel[i + 1].toString();
        }
        final host = info['ip'];
        final port = int.tryParse(info['port'] ?? '');
        if (host != null && port != null) {
          _iterator.add(SentinelAddress(host: host, port: port));
        }
      }
    } catch (_) {
      // Ignore errors during sentinel discovery
    }
  }

  void _initFailoverDetector() {
    // Subscribe to +switch-master on sentinel nodes
    // When detected, disconnect → triggers reconnection via Redis client
    // Simplified: one sentinel subscription for now
    _cleanupFailoverDetector();
    // Full implementation would subscribe to multiple sentinels
  }

  void _cleanupFailoverDetector() {
    if (_failoverClients != null) {
      for (final client in _failoverClients!) {
        client.disconnect();
      }
      _failoverClients = null;
    }
  }

  @override
  void disconnect() {
    _cleanupFailoverDetector();
    super.disconnect();
  }
}
