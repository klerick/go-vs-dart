/// Redis error returned by server (RESP error reply).
class RedisError implements Exception {
  factory RedisError(String message) {
    // Parse error prefix: "ERR ...", "WRONGTYPE ...", "MOVED ...", etc.
    final spaceIndex = message.indexOf(' ');
    if (spaceIndex > 0) {
      final prefix = message.substring(0, spaceIndex);
      // Known error types with structured data
      if (prefix == 'MOVED' || prefix == 'ASK') {
        return RedisRedirectError._(message, prefix);
      }
    }
    return RedisError._(message);
  }

  RedisError._(this.message);

  final String message;

  @override
  String toString() {
    return 'RedisError: $message';
  }
}

/// MOVED/ASK redirect error from Redis Cluster.
class RedisRedirectError extends RedisError {
  RedisRedirectError._(String message, this.redirectType) : super._(message) {
    // "MOVED 3999 127.0.0.1:6381" or "ASK 3999 127.0.0.1:6381"
    final parts = message.split(' ');
    if (parts.length >= 3) {
      slot = int.tryParse(parts[1]) ?? -1;
      final hostPort = parts[2].split(':');
      host = hostPort[0];
      port = hostPort.length > 1 ? int.tryParse(hostPort[1]) ?? 6379 : 6379;
    }
  }

  final String redirectType;
  late final int slot;
  late final String host;
  late final int port;
}

/// Thrown when max retries per request exceeded.
class MaxRetriesPerRequestError implements Exception {
  MaxRetriesPerRequestError(this.maxRetries);

  final int maxRetries;

  @override
  String toString() {
    return 'Reached the max retries per request limit ($maxRetries). '
        'Refer to "maxRetriesPerRequest" option.';
  }
}

/// Thrown when command times out.
class CommandTimeoutException implements Exception {
  CommandTimeoutException(this.commandName, this.timeout);

  final String commandName;
  final Duration timeout;

  @override
  String toString() {
    return 'Command "$commandName" timed out after $timeout';
  }
}

/// Thrown when connection is closed and command cannot be sent.
class ConnectionClosedError implements Exception {
  const ConnectionClosedError();

  static const message = 'Connection is closed.';

  @override
  String toString() {
    return message;
  }
}

/// Thrown when all cluster nodes fail.
class ClusterAllFailedError implements Exception {
  ClusterAllFailedError([this.lastError]);

  final Object? lastError;

  @override
  String toString() {
    return 'Failed to refresh slots cache.${lastError != null ? ' Last error: $lastError' : ''}';
  }
}
