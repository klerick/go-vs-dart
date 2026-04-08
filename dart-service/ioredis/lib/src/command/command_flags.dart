/// Static sets of command names categorized by behavior.
///
/// Mirrors ioredis Command.ts flags for subscriber mode, blocking commands, etc.
abstract final class CommandFlags {
  /// Commands valid in subscriber mode.
  static const validInSubscriberMode = {
    'subscribe',
    'psubscribe',
    'ssubscribe',
    'unsubscribe',
    'punsubscribe',
    'sunsubscribe',
    'ping',
    'quit',
  };

  /// Commands that enter subscriber mode.
  static const enterSubscriberMode = {
    'subscribe',
    'psubscribe',
    'ssubscribe',
  };

  /// Commands that exit subscriber mode.
  static const exitSubscriberMode = {
    'unsubscribe',
    'punsubscribe',
    'sunsubscribe',
  };

  /// Commands that will disconnect.
  static const willDisconnect = {'quit'};

  /// Commands part of handshake (sent before ready).
  static const handshakeCommands = {
    'auth',
    'select',
    'client',
    'readonly',
    'info',
  };

  /// Blocking commands.
  static const blockingCommands = {
    'blpop',
    'brpop',
    'brpoplpush',
    'blmove',
    'bzpopmin',
    'bzpopmax',
    'bzmpop',
    'blmpop',
    'xread',
    'xreadgroup',
  };

  /// Commands to ignore for reconnectOnError.
  static const ignoreReconnectOnError = {'client'};

  /// Check if command has a specific flag.
  static bool isValidInSubscriberMode(String name) {
    return validInSubscriberMode.contains(name.toLowerCase());
  }

  static bool isEnterSubscriberMode(String name) {
    return enterSubscriberMode.contains(name.toLowerCase());
  }

  static bool isExitSubscriberMode(String name) {
    return exitSubscriberMode.contains(name.toLowerCase());
  }

  static bool isBlocking(String name) {
    return blockingCommands.contains(name.toLowerCase());
  }
}
