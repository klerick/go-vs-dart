import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ioredis/src/protocol/resp_parser.dart';
import 'package:ioredis/src/errors.dart';
import 'package:ioredis/src/client/redis_options.dart';
import 'package:ioredis/src/command/command.dart';

Uint8List toBytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('stringNumbers', () {
    test('default — integers parsed as int', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
      );

      parser.addData(toBytes(':42\r\n'));
      expect(replies, hasLength(1));
      expect(replies[0], isA<int>());
      expect(replies[0], 42);
    });

    test('stringNumbers=true — integers returned as String', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
        stringNumbers: true,
      );

      parser.addData(toBytes(':42\r\n'));
      expect(replies, hasLength(1));
      expect(replies[0], isA<String>());
      expect(replies[0], '42');
    });

    test('stringNumbers=true — large integers preserved as string', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
        stringNumbers: true,
      );

      // Larger than JS MAX_SAFE_INTEGER
      parser.addData(toBytes(':9007199254740993\r\n'));
      expect(replies[0], '9007199254740993');
    });

    test('stringNumbers=true — negative integers as string', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
        stringNumbers: true,
      );

      parser.addData(toBytes(':-1\r\n'));
      expect(replies[0], '-1');
    });

    test('stringNumbers=true — zero as string', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
        stringNumbers: true,
      );

      parser.addData(toBytes(':0\r\n'));
      expect(replies[0], '0');
    });

    test('stringNumbers does not affect bulk strings', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
        stringNumbers: true,
      );

      parser.addData(toBytes('\$5\r\nhello\r\n'));
      expect(replies[0], 'hello');
    });

    test('stringNumbers does not affect simple strings', () {
      final replies = <Object?>[];
      final parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (_) {},
        stringNumbers: true,
      );

      parser.addData(toBytes('+OK\r\n'));
      expect(replies[0], 'OK');
    });
  });

  group('reconnectOnError', () {
    test('default is null', () {
      const options = RedisOptions();
      expect(options.reconnectOnError, isNull);
    });

    test('callback receives RedisError', () {
      RedisError? receivedError;
      final options = RedisOptions(
        reconnectOnError: (error) {
          receivedError = error;
          return ReconnectAction.none;
        },
      );

      // Verify callback is stored
      expect(options.reconnectOnError, isNotNull);

      // Simulate calling it
      final action = options.reconnectOnError!(RedisError('READONLY You can\'t write against a read only replica.'));
      expect(action, ReconnectAction.none);
      expect(receivedError, isNotNull);
      expect(receivedError!.message, contains('READONLY'));
    });

    test('can return reconnect action', () {
      final options = RedisOptions(
        reconnectOnError: (error) {
          if (error.message.contains('READONLY')) {
            return ReconnectAction.reconnect;
          }
          return ReconnectAction.none;
        },
      );

      final action1 = options.reconnectOnError!(RedisError('READONLY'));
      expect(action1, ReconnectAction.reconnect);

      final action2 = options.reconnectOnError!(RedisError('ERR wrong number of arguments'));
      expect(action2, ReconnectAction.none);
    });

    test('can return reconnectAndResend action', () {
      final options = RedisOptions(
        reconnectOnError: (error) {
          if (error.message.contains('READONLY')) {
            return ReconnectAction.reconnectAndResend;
          }
          return ReconnectAction.none;
        },
      );

      final action = options.reconnectOnError!(RedisError('READONLY'));
      expect(action, ReconnectAction.reconnectAndResend);
    });
  });

  group('autoResendUnfulfilledCommands', () {
    test('default is true', () {
      const options = RedisOptions();
      expect(options.autoResendUnfulfilledCommands, true);
    });

    test('can be disabled', () {
      const options = RedisOptions(autoResendUnfulfilledCommands: false);
      expect(options.autoResendUnfulfilledCommands, false);
    });
  });

  group('noDelay', () {
    test('default is true', () {
      const options = RedisOptions();
      expect(options.noDelay, true);
    });

    test('can be disabled', () {
      const options = RedisOptions(noDelay: false);
      expect(options.noDelay, false);
    });
  });
}