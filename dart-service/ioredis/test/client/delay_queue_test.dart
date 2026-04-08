import 'package:test/test.dart';
import 'package:ioredis/src/cluster/delay_queue.dart';

void main() {
  group('DelayQueue', () {
    test('executes after delay', () async {
      final queue = DelayQueue();
      var executed = false;

      queue.push('test', () => executed = true, Duration.zero);

      // Give timer a chance to fire
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(executed, isTrue);
    });

    test('groups by bucket', () async {
      final queue = DelayQueue();
      final results = <int>[];

      queue.push('a', () => results.add(1), Duration.zero);
      queue.push('a', () => results.add(2), Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(results, equals([1, 2]));
    });

    test('different buckets execute independently', () async {
      final queue = DelayQueue();
      final results = <String>[];

      queue.push('a', () => results.add('a'), Duration.zero);
      queue.push('b', () => results.add('b'), Duration.zero);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(results, containsAll(['a', 'b']));
    });

    test('clear cancels pending', () async {
      final queue = DelayQueue();
      var executed = false;

      queue.push(
        'test',
        () => executed = true,
        const Duration(milliseconds: 50),
      );
      queue.clear();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(executed, isFalse);
    });
  });
}
