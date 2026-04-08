import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../client/redis.dart';
import '../errors.dart';

/// A Redis Lua script with SHA-1 caching.
///
/// Uses EVALSHA for efficiency, with automatic fallback to EVAL
/// when the script is not yet cached on the server.
class RedisScript {
  RedisScript(
    this.lua, {
    this.numberOfKeys,
    this.readOnly = false,
  }) : sha = sha1.convert(utf8.encode(lua)).toString();

  /// The Lua source code.
  final String lua;

  /// Number of KEYS arguments (null = inferred from args).
  final int? numberOfKeys;

  /// Whether this script is read-only (for cluster replica routing).
  final bool readOnly;

  /// SHA-1 hash of the Lua source.
  final String sha;

  /// Execute this script on the given Redis client.
  ///
  /// [keys] are the KEYS arguments, [args] are the ARGV arguments.
  Future<Object?> execute(
    Redis redis, {
    List<String> keys = const [],
    List<Object> args = const [],
  }) async {
    final numKeys = this.numberOfKeys ?? keys.length;
    final fullArgs = <Object>[this.sha, numKeys.toString(), ...keys, ...args];

    try {
      return await redis.call('EVALSHA', fullArgs);
    } on RedisError catch (e) {
      if (e.message.startsWith('NOSCRIPT')) {
        // Script not cached — send full EVAL
        final evalArgs = <Object>[
          this.lua,
          numKeys.toString(),
          ...keys,
          ...args,
        ];
        return redis.call('EVAL', evalArgs);
      }
      rethrow;
    }
  }
}
