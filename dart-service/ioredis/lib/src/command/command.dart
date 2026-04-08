import 'dart:async';
import 'dart:typed_data';

import '../errors.dart';
import '../protocol/resp_encoder.dart';
import 'command_flags.dart';

/// Static argument transformers by command name.
/// Called BEFORE flatten — args may contain Map, List, etc.
final Map<String, List<Object?> Function(List<Object?>)>
    _argumentTransformers = {
      'mset': _flattenMapArg,
      'msetnx': _flattenMapArg,
      'hmset': _flattenMapArg,
      'hset': _flattenMapArg,
    };

/// Static reply transformers by command name.
final Map<String, Object? Function(Object?)> _replyTransformers = {
  'hgetall': _listToMap,
};

List<Object?> _flattenMapArg(List<Object?> args) {
  if (args.isEmpty) return args;
  final first = args[0];
  if (first is Map) {
    final result = <Object?>[];
    for (final entry in first.entries) {
      result.add(entry.key.toString());
      result.add(entry.value);
    }
    return result;
  }
  return args;
}

Object? _listToMap(Object? reply) {
  if (reply is! List) return reply;
  final map = <String, Object?>{};
  for (var i = 0; i < reply.length; i += 2) {
    map[reply[i].toString()] = reply[i + 1];
  }
  return map;
}

/// Represents a single Redis command with its arguments, future result, and encoding.
class Command {
  factory Command(
    String name,
    List<Object?> args, {
    String? keyPrefix,
    bool readOnly = false,
    bool inTransaction = false,
  }) {
    final lowerName = name.toLowerCase();

    // Apply argument transformer BEFORE flattening (so Map args are still Maps)
    final transformer = _argumentTransformers[lowerName];
    List<Object?> transformedArgs;
    if (transformer != null) {
      transformedArgs = transformer(args);
    } else {
      transformedArgs = args;
    }

    // Flatten nested lists and convert nulls
    var flatArgs = _flattenArgs(transformedArgs);

    // Apply key prefix
    if (keyPrefix != null && keyPrefix.isNotEmpty) {
      flatArgs = _applyKeyPrefix(lowerName, flatArgs, keyPrefix);
    }

    return Command._(
      lowerName,
      flatArgs,
      readOnly: readOnly,
      inTransaction: inTransaction,
    );
  }

  Command._(
    this.name,
    this.args, {
    this.readOnly = false,
    this.inTransaction = false,
  });

  /// Command name (lowercase).
  final String name;

  /// Flattened and transformed arguments.
  final List<Object> args;

  /// Whether this command is read-only (for cluster replica routing).
  final bool readOnly;

  /// Whether this command is inside a MULTI/EXEC transaction.
  bool inTransaction;

  /// Pipeline index for result mapping.
  int? pipelineIndex;

  /// Whether the command result should be ignored (e.g. ASKING).
  bool ignore = false;

  final Completer<Object?> _completer = Completer<Object?>();

  /// Future that resolves with the server reply.
  Future<Object?> get future => _completer.future;

  /// Whether the command's future is already completed.
  bool get isCompleted => _completer.isCompleted;

  /// Resolve the command with a reply from the server.
  void resolve(Object? reply) {
    if (_completer.isCompleted) return;
    _cancelTimeout();

    final transformer = _replyTransformers[this.name];
    if (transformer != null && !this.inTransaction) {
      _completer.complete(transformer(reply));
    } else {
      _completer.complete(reply);
    }
  }

  /// Reject the command with an error.
  void reject(Object error, [StackTrace? stack]) {
    if (_completer.isCompleted) return;
    _cancelTimeout();
    _completer.completeError(error, stack);
  }

  Timer? _timeoutTimer;

  /// Set a command timeout. If the command is not resolved within [duration],
  /// it will be rejected with [CommandTimeoutException].
  void setTimeout(Duration duration) {
    _timeoutTimer = Timer(duration, () {
      this.reject(CommandTimeoutException(this.name, duration));
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  static final _encoder = RespEncoder();

  /// Encode this command to RESP bytes for sending to the server.
  Uint8List toWritable() {
    final parts = <Object>[this.name, ...this.args];
    return _encoder.encode(parts);
  }

  /// Calculate Redis Cluster slot for this command.
  ///
  /// Returns null if the command has no keys (e.g. PING, INFO).
  int? getSlot() {
    final keys = this.getKeys();
    if (keys.isEmpty) return null;
    return calculateSlot(keys[0].toString());
  }

  /// Extract key arguments from this command.
  ///
  /// Simple heuristic: for most commands the first argument is the key.
  /// Multi-key commands: second arg onwards for some commands.
  List<Object> getKeys() {
    if (this.args.isEmpty) return const [];

    // Commands with no keys
    const noKeyCommands = {
      'ping',
      'info',
      'auth',
      'select',
      'dbsize',
      'flushall',
      'flushdb',
      'time',
      'quit',
      'save',
      'bgsave',
      'bgrewriteaof',
      'config',
      'client',
      'cluster',
      'command',
      'debug',
      'discard',
      'exec',
      'multi',
      'randomkey',
      'script',
      'subscribe',
      'unsubscribe',
      'psubscribe',
      'punsubscribe',
      'ssubscribe',
      'sunsubscribe',
      'publish',
      'monitor',
      'slaveof',
      'replicaof',
      'wait',
      'swapdb',
      'slowlog',
    };

    if (noKeyCommands.contains(this.name)) return const [];

    // EVAL/EVALSHA: keys start at index 2, count is at index 1
    if (this.name == 'eval' || this.name == 'evalsha') {
      if (this.args.length < 2) return const [];
      final numKeys = int.tryParse(this.args[1].toString()) ?? 0;
      if (numKeys == 0 || this.args.length < 2 + numKeys) return const [];
      return this.args.sublist(2, 2 + numKeys);
    }

    // XREAD/XREADGROUP: keys start after STREAMS keyword
    if (this.name == 'xread' || this.name == 'xreadgroup') {
      for (var i = 0; i < this.args.length; i++) {
        if (this.args[i].toString().toUpperCase() == 'STREAMS') {
          final remaining = this.args.length - i - 1;
          final numKeys = remaining ~/ 2;
          return this.args.sublist(i + 1, i + 1 + numKeys);
        }
      }
      return const [];
    }

    // Most commands: first arg is the key
    return [this.args[0]];
  }

  /// Check if this command enters subscriber mode.
  bool get isEnterSubscriberMode {
    return CommandFlags.isEnterSubscriberMode(this.name);
  }

  /// Check if this command exits subscriber mode.
  bool get isExitSubscriberMode {
    return CommandFlags.isExitSubscriberMode(this.name);
  }

  /// Check if this command is valid in subscriber mode.
  bool get isValidInSubscriberMode {
    return CommandFlags.isValidInSubscriberMode(this.name);
  }

  /// Check if this is a blocking command.
  bool get isBlocking {
    return CommandFlags.isBlocking(this.name);
  }

  /// Flatten nested lists and convert all args to strings/Uint8List.
  static List<Object> _flattenArgs(List<Object?> args) {
    final result = <Object>[];
    for (final arg in args) {
      if (arg == null) {
        result.add('');
      } else if (arg is Uint8List) {
        result.add(arg);
      } else if (arg is List) {
        result.addAll(_flattenArgs(arg.cast<Object?>()));
      } else {
        result.add(arg.toString());
      }
    }
    return result;
  }

  static List<Object> _applyKeyPrefix(
    String name,
    List<Object> args,
    String prefix,
  ) {
    if (args.isEmpty) return args;
    // Simple case: prefix the first argument (the key)
    final result = List<Object>.from(args);
    if (result.isNotEmpty && result[0] is String) {
      result[0] = '$prefix${result[0]}';
    }
    return result;
  }

  @override
  String toString() {
    return 'Command($name ${args.join(' ')})';
  }
}

// ===== CRC16 for Redis Cluster =====

/// CRC16-CCITT lookup table, generated programmatically to avoid typos.
final List<int> _crc16Table = _generateCrc16Table();

List<int> _generateCrc16Table() {
  const polynomial = 0x1021;
  final table = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    var crc = i << 8;
    for (var j = 0; j < 8; j++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ polynomial) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
    table[i] = crc;
  }
  return table;
}

/// Calculate Redis Cluster slot for a key using CRC16-CCITT.
///
/// Supports hash tags: `{tag}rest` → slot calculated from `tag` only.
int calculateSlot(String key) {
  // Hash tag extraction
  final start = key.indexOf('{');
  if (start != -1) {
    final end = key.indexOf('}', start + 1);
    if (end > start + 1) {
      key = key.substring(start + 1, end);
    }
  }

  var crc = 0;
  for (var i = 0; i < key.length; i++) {
    crc = ((crc << 8) & 0xFFFF) ^ _crc16Table[((crc >> 8) ^ key.codeUnitAt(i)) & 0xFF];
  }
  return crc & 0x3FFF; // 16384 slots
}
