import '../client/redis_options.dart';
import '../connectors/sentinel/sentinel_connector.dart';

/// Scale reads strategy for cluster.
enum ScaleReads {
  /// Read from master only (default).
  master,

  /// Read from slaves only.
  slave,

  /// Read from any node.
  all,
}

/// A cluster startup node.
class ClusterNode {
  const ClusterNode({this.host = '127.0.0.1', this.port = 6379});

  final String host;
  final int port;

  String get key => '$host:$port';
}

/// Configuration for Redis Cluster client.
class ClusterOptions {
  const ClusterOptions({
    this.maxRedirections = 16,
    this.retryDelayOnFailover = const Duration(milliseconds: 100),
    this.retryDelayOnClusterDown = const Duration(milliseconds: 100),
    this.retryDelayOnTryAgain = const Duration(milliseconds: 100),
    this.retryDelayOnMoved = Duration.zero,
    this.slotsRefreshTimeout = const Duration(seconds: 1),
    this.slotsRefreshInterval = const Duration(seconds: 5),
    this.enableOfflineQueue = true,
    this.enableReadyCheck = true,
    this.scaleReads = ScaleReads.master,
    this.lazyConnect = false,
    this.redisOptions = const RedisOptions(),
    this.natMap,
    this.clusterRetryStrategy = _defaultClusterRetryStrategy,
    this.enableAutoPipelining = false,
  });

  final int maxRedirections;
  final Duration retryDelayOnFailover;
  final Duration retryDelayOnClusterDown;
  final Duration retryDelayOnTryAgain;
  final Duration retryDelayOnMoved;
  final Duration slotsRefreshTimeout;
  final Duration slotsRefreshInterval;
  final bool enableOfflineQueue;
  final bool enableReadyCheck;
  final ScaleReads scaleReads;
  final bool lazyConnect;
  final RedisOptions redisOptions;
  final NatMap? natMap;
  final bool enableAutoPipelining;

  /// Retry strategy for cluster reconnection.
  final Duration? Function(int retryAttempts, String? reason)?
      clusterRetryStrategy;

  static Duration? _defaultClusterRetryStrategy(int times, String? reason) {
    final ms = 100 + times * 2;
    if (ms > 2000) return const Duration(milliseconds: 2000);
    return Duration(milliseconds: ms);
  }
}
