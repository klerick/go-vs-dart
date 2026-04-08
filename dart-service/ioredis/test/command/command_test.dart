import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ioredis/src/command/command.dart';
import 'package:ioredis/src/errors.dart';

void main() {
  group('Command', () {
    test('creates command with name and args', () {
      final cmd = Command('SET', ['key', 'value']);
      expect(cmd.name, equals('set'));
      expect(cmd.args, equals(['key', 'value']));
    });

    test('lowercases command name', () {
      final cmd = Command('GET', ['key']);
      expect(cmd.name, equals('get'));
    });

    test('resolve completes future', () async {
      final cmd = Command('GET', ['key']);
      cmd.resolve('hello');
      expect(await cmd.future, equals('hello'));
    });

    test('resolve with null', () async {
      final cmd = Command('GET', ['key']);
      cmd.resolve(null);
      expect(await cmd.future, isNull);
    });

    test('reject completes future with error', () async {
      final cmd = Command('GET', ['key']);
      cmd.reject(RedisError('ERR test'));
      expect(cmd.future, throwsA(isA<RedisError>()));
    });

    test('resolve is idempotent (second call ignored)', () async {
      final cmd = Command('GET', ['key']);
      cmd.resolve('first');
      cmd.resolve('second');
      expect(await cmd.future, equals('first'));
    });

    test('reject is idempotent after resolve', () async {
      final cmd = Command('GET', ['key']);
      cmd.resolve('ok');
      cmd.reject(RedisError('ERR'));
      expect(await cmd.future, equals('ok'));
    });

    test('isCompleted tracks state', () {
      final cmd = Command('GET', ['key']);
      expect(cmd.isCompleted, isFalse);
      cmd.resolve('ok');
      expect(cmd.isCompleted, isTrue);
    });

    test('flattens nested list args', () {
      final cmd = Command('MGET', [
        ['key1', 'key2', 'key3'],
      ]);
      expect(cmd.args, equals(['key1', 'key2', 'key3']));
    });

    test('converts null args to empty string', () {
      final cmd = Command('SET', ['key', null]);
      expect(cmd.args, equals(['key', '']));
    });

    test('converts int args to string', () {
      final cmd = Command('EXPIRE', ['key', 60]);
      expect(cmd.args, equals(['key', '60']));
    });

    test('preserves Uint8List args', () {
      final binary = Uint8List.fromList([1, 2, 3]);
      final cmd = Command('SET', ['key', binary]);
      expect(cmd.args[1], isA<Uint8List>());
    });

    group('toWritable', () {
      test('encodes to valid RESP', () {
        final cmd = Command('SET', ['key', 'value']);
        final bytes = cmd.toWritable();
        final result = utf8.decode(bytes);
        expect(
          result,
          equals(
            '*3\r\n\$3\r\nset\r\n\$3\r\nkey\r\n\$5\r\nvalue\r\n',
          ),
        );
      });
    });

    group('argument transformers', () {
      test('HSET flattens Map argument', () {
        final cmd = Command('HSET', [
          <String, Object>{'field1': 'value1', 'field2': 'value2'},
        ]);
        expect(cmd.args, equals(['field1', 'value1', 'field2', 'value2']));
      });

      test('MSET flattens Map argument', () {
        final cmd = Command('MSET', [
          <String, Object>{'key1': 'val1', 'key2': 'val2'},
        ]);
        expect(cmd.args, equals(['key1', 'val1', 'key2', 'val2']));
      });

      test('HSET passes through list args unchanged', () {
        final cmd = Command('HSET', ['key', 'field', 'value']);
        expect(cmd.args, equals(['key', 'field', 'value']));
      });
    });

    group('reply transformers', () {
      test('HGETALL transforms list to map', () async {
        final cmd = Command('HGETALL', ['key']);
        cmd.resolve(['field1', 'value1', 'field2', 'value2']);
        final result = await cmd.future;
        expect(result, isA<Map<String, Object?>>());
        expect(result, equals({'field1': 'value1', 'field2': 'value2'}));
      });

      test('HGETALL with null reply', () async {
        final cmd = Command('HGETALL', ['key']);
        cmd.resolve(null);
        expect(await cmd.future, isNull);
      });

      test('HGETALL passes through non-list reply', () async {
        final cmd = Command('HGETALL', ['key']);
        cmd.resolve('not-a-list');
        expect(await cmd.future, equals('not-a-list'));
      });
    });

    group('key prefix', () {
      test('applies prefix to first arg', () {
        final cmd = Command('GET', ['key'], keyPrefix: 'app:');
        expect(cmd.args[0], equals('app:key'));
      });
    });

    group('command flags', () {
      test('isBlocking for BLPOP', () {
        expect(Command('BLPOP', ['key', '0']).isBlocking, isTrue);
      });

      test('isBlocking false for GET', () {
        expect(Command('GET', ['key']).isBlocking, isFalse);
      });

      test('isEnterSubscriberMode for SUBSCRIBE', () {
        expect(
          Command('SUBSCRIBE', ['channel']).isEnterSubscriberMode,
          isTrue,
        );
      });

      test('isExitSubscriberMode for UNSUBSCRIBE', () {
        expect(
          Command('UNSUBSCRIBE', ['channel']).isExitSubscriberMode,
          isTrue,
        );
      });
    });

    group('timeout', () {
      test('rejects on timeout', () async {
        final cmd = Command('GET', ['key']);
        cmd.setTimeout(const Duration(milliseconds: 10));
        expect(cmd.future, throwsA(isA<CommandTimeoutException>()));
      });

      test('timeout cancelled on resolve', () async {
        final cmd = Command('GET', ['key']);
        cmd.setTimeout(const Duration(milliseconds: 100));
        cmd.resolve('ok');
        expect(await cmd.future, equals('ok'));
        // Wait past timeout to ensure no double-complete
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
    });

    group('getKeys', () {
      test('returns first arg for simple commands', () {
        final cmd = Command('GET', ['mykey']);
        expect(cmd.getKeys(), equals(['mykey']));
      });

      test('returns empty for no-key commands', () {
        expect(Command('PING', []).getKeys(), isEmpty);
        expect(Command('INFO', []).getKeys(), isEmpty);
        expect(Command('AUTH', ['password']).getKeys(), isEmpty);
      });

      test('returns empty for commands with no args', () {
        expect(Command('PING', []).getKeys(), isEmpty);
      });
    });

    group('getSlot', () {
      test('returns null for no-key commands', () {
        expect(Command('PING', []).getSlot(), isNull);
      });

      test('returns slot for key', () {
        final slot = Command('GET', ['test']).getSlot();
        expect(slot, isNotNull);
        expect(slot, greaterThanOrEqualTo(0));
        expect(slot, lessThan(16384));
      });

      test('same key always returns same slot', () {
        final slot1 = Command('GET', ['mykey']).getSlot();
        final slot2 = Command('SET', ['mykey', 'val']).getSlot();
        expect(slot1, equals(slot2));
      });
    });
  });

  group('calculateSlot', () {
    test('returns value in valid range', () {
      final slot = calculateSlot('test');
      expect(slot, greaterThanOrEqualTo(0));
      expect(slot, lessThan(16384));
    });

    test('deterministic', () {
      expect(calculateSlot('key'), equals(calculateSlot('key')));
    });

    test('different keys may have different slots', () {
      // Not guaranteed but highly likely for different keys
      final slots = <int>{};
      for (var i = 0; i < 100; i++) {
        slots.add(calculateSlot('key$i'));
      }
      expect(slots.length, greaterThan(1));
    });

    test('hash tag routes to same slot', () {
      expect(calculateSlot('{user}.name'), equals(calculateSlot('{user}.age')));
      expect(
        calculateSlot('{user}.name'),
        equals(calculateSlot('{user}.email')),
      );
    });

    test('hash tag uses content between first {}', () {
      expect(calculateSlot('{tag}rest'), equals(calculateSlot('tag')));
    });

    test('empty hash tag is ignored', () {
      // {} has no content between braces, so full key is used
      expect(calculateSlot('{}key'), equals(calculateSlot('{}key')));
    });
  });
}
