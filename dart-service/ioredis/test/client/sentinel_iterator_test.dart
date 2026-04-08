import 'package:test/test.dart';
import 'package:ioredis/src/connectors/sentinel/sentinel_iterator.dart';

void main() {
  group('SentinelIterator', () {
    test('iterates through all sentinels', () {
      final iter = SentinelIterator([
        const SentinelAddress(host: 'a', port: 26379),
        const SentinelAddress(host: 'b', port: 26379),
        const SentinelAddress(host: 'c', port: 26379),
      ]);

      expect(iter.next()?.host, equals('a'));
      expect(iter.next()?.host, equals('b'));
      expect(iter.next()?.host, equals('c'));
      expect(iter.next(), isNull);
    });

    test('reset restarts iteration', () {
      final iter = SentinelIterator([
        const SentinelAddress(host: 'a', port: 26379),
        const SentinelAddress(host: 'b', port: 26379),
      ]);

      iter.next();
      iter.next();
      expect(iter.next(), isNull);

      iter.reset();
      expect(iter.next()?.host, equals('a'));
    });

    test('reset with moveCurrentToFirst prioritizes last used', () {
      final iter = SentinelIterator([
        const SentinelAddress(host: 'a', port: 26379),
        const SentinelAddress(host: 'b', port: 26379),
        const SentinelAddress(host: 'c', port: 26379),
      ]);

      iter.next(); // a
      iter.next(); // b
      iter.reset(moveCurrentToFirst: true);

      // 'b' should be first now (it was last used at cursor-1)
      expect(iter.next()?.host, equals('b'));
    });

    test('add deduplicates', () {
      final iter = SentinelIterator([
        const SentinelAddress(host: 'a', port: 26379),
      ]);

      expect(
        iter.add(const SentinelAddress(host: 'a', port: 26379)),
        isFalse,
      );
      expect(iter.add(const SentinelAddress(host: 'b', port: 26379)), isTrue);
      expect(iter.length, equals(2));
    });

    test('add normalizes empty host to 127.0.0.1', () {
      final iter = SentinelIterator([
        const SentinelAddress(host: '127.0.0.1', port: 26379),
      ]);
      expect(
        iter.add(const SentinelAddress(host: '', port: 26379)),
        isFalse,
      ); // duplicate
    });
  });

  group('SentinelAddress', () {
    test('equality by host and port', () {
      const a = SentinelAddress(host: 'redis', port: 6379);
      const b = SentinelAddress(host: 'redis', port: 6379);
      expect(a, equals(b));
    });

    test('inequality with different port', () {
      const a = SentinelAddress(host: 'redis', port: 6379);
      const b = SentinelAddress(host: 'redis', port: 6380);
      expect(a, isNot(equals(b)));
    });
  });
}
