import 'dart:async';

import '../client/redis.dart';

/// Options for scan stream operations.
class ScanOptions {
  const ScanOptions({this.match, this.count, this.type});

  /// Pattern to match keys against (e.g. "user:*").
  final String? match;

  /// Hint for how many elements to return per iteration.
  final int? count;

  /// Filter by type (only for SCAN, not SSCAN/HSCAN/ZSCAN).
  final String? type;
}

/// Creates a Dart [Stream] that wraps Redis SCAN family commands.
///
/// Iterates through all matching keys/members/fields using cursor-based
/// pagination. Handles cursor tracking and termination automatically.
Stream<String> scanStream(
  Redis redis, {
  String command = 'SCAN',
  String? key,
  ScanOptions options = const ScanOptions(),
}) async* {
  var cursor = '0';

  do {
    final args = <Object?>[];

    // SSCAN/HSCAN/ZSCAN require key as first arg
    if (key != null) {
      args.add(key);
    }

    args.add(cursor);

    if (options.match != null) {
      args.addAll(['MATCH', options.match!]);
    }
    if (options.count != null) {
      args.addAll(['COUNT', options.count!]);
    }
    if (options.type != null && command.toUpperCase() == 'SCAN') {
      args.addAll(['TYPE', options.type!]);
    }

    final result = await redis.call(command, args);
    if (result is! List || result.length < 2) break;

    cursor = result[0].toString();
    final items = result[1];
    if (items is List) {
      for (final item in items) {
        yield item.toString();
      }
    }
  } while (cursor != '0');
}
