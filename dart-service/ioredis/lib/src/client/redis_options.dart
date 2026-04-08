import 'dart:io';

import '../connectors/connector.dart';
import '../errors.dart';

/// Reconnection behavior when a command error occurs.
enum ReconnectAction {
  /// Do not reconnect.
  none,

  /// Reconnect to Redis.
  reconnect,

  /// Reconnect and resend the failed command.
  reconnectAndResend,
}

/// Configuration options for the Redis client.
class RedisOptions {
  const RedisOptions({
    this.host = 'localhost',
    this.port = 6379,
    this.username,
    this.password,
    this.db = 0,
    this.connectTimeout = const Duration(seconds: 10),
    this.commandTimeout,
    this.socketTimeout,
    this.keepAlive,
    this.noDelay = true,
    this.lazyConnect = false,
    this.readOnly = false,
    this.connectionName,
    this.enableOfflineQueue = true,
    this.enableReadyCheck = true,
    this.maxRetriesPerRequest = 20,
    this.retryStrategy = _defaultRetryStrategy,
    this.reconnectOnError,
    this.autoResubscribe = true,
    this.autoResendUnfulfilledCommands = true,
    this.keyPrefix,
    this.stringNumbers = false,
    this.securityContext,
    this.connector,
  });

  final String host;
  final int port;
  final String? username;
  final String? password;
  final int db;
  final Duration connectTimeout;
  final Duration? commandTimeout;
  final Duration? socketTimeout;
  final Duration? keepAlive;
  final bool noDelay;
  final bool lazyConnect;
  final bool readOnly;
  final String? connectionName;
  final bool enableOfflineQueue;
  final bool enableReadyCheck;
  final int? maxRetriesPerRequest;
  final String? keyPrefix;
  final bool stringNumbers;
  final SecurityContext? securityContext;
  final Connector? connector;

  /// Retry strategy: given attempt number, return delay Duration or null to stop.
  final Duration? Function(int retryAttempts)? retryStrategy;

  /// Called on command error to decide reconnection behavior.
  final ReconnectAction Function(RedisError error)? reconnectOnError;

  /// Whether to automatically resubscribe after reconnection.
  final bool autoResubscribe;

  /// Whether to resend unfulfilled commands after reconnection.
  final bool autoResendUnfulfilledCommands;

  /// Create a copy with overrides.
  RedisOptions copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    int? db,
    Duration? connectTimeout,
    Duration? commandTimeout,
    Duration? socketTimeout,
    bool? lazyConnect,
    bool? readOnly,
    String? connectionName,
    bool? enableOfflineQueue,
    bool? enableReadyCheck,
    int? maxRetriesPerRequest,
    Duration? Function(int)? retryStrategy,
    Connector? connector,
    SecurityContext? securityContext,
  }) {
    return RedisOptions(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      db: db ?? this.db,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      commandTimeout: commandTimeout ?? this.commandTimeout,
      socketTimeout: socketTimeout ?? this.socketTimeout,
      lazyConnect: lazyConnect ?? this.lazyConnect,
      readOnly: readOnly ?? this.readOnly,
      connectionName: connectionName ?? this.connectionName,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
      enableReadyCheck: enableReadyCheck ?? this.enableReadyCheck,
      maxRetriesPerRequest: maxRetriesPerRequest ?? this.maxRetriesPerRequest,
      retryStrategy: retryStrategy ?? this.retryStrategy,
      connector: connector ?? this.connector,
      securityContext: securityContext ?? this.securityContext,
      keepAlive: this.keepAlive,
      noDelay: this.noDelay,
      keyPrefix: this.keyPrefix,
      stringNumbers: this.stringNumbers,
      reconnectOnError: this.reconnectOnError,
      autoResubscribe: this.autoResubscribe,
      autoResendUnfulfilledCommands: this.autoResendUnfulfilledCommands,
    );
  }

  static Duration? _defaultRetryStrategy(int retryAttempts) {
    final ms = retryAttempts * 50;
    if (ms > 2000) return const Duration(milliseconds: 2000);
    return Duration(milliseconds: ms);
  }
}
