import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ioredis/src/errors.dart';
import 'package:ioredis/src/protocol/resp_parser.dart';

void main() {
  group('RespParser', () {
    late List<Object?> replies;
    late List<RedisError> errors;
    late RespParser parser;

    setUp(() {
      replies = [];
      errors = [];
      parser = RespParser(
        onReply: (reply) => replies.add(reply),
        onError: (error) => errors.add(error),
      );
    });

    Uint8List toBytes(String s) => Uint8List.fromList(utf8.encode(s));

    group('Simple String', () {
      test('parses simple string', () {
        parser.addData(toBytes('+OK\r\n'));
        expect(replies, equals(['OK']));
      });

      test('parses empty simple string', () {
        parser.addData(toBytes('+\r\n'));
        expect(replies, equals(['']));
      });
    });

    group('Error', () {
      test('parses error reply', () {
        parser.addData(toBytes('-ERR unknown command\r\n'));
        expect(errors, hasLength(1));
        expect(errors[0].message, equals('ERR unknown command'));
      });

      test('parses MOVED error', () {
        parser.addData(toBytes('-MOVED 3999 127.0.0.1:6381\r\n'));
        expect(errors, hasLength(1));
        expect(errors[0], isA<RedisRedirectError>());
        final moved = errors[0] as RedisRedirectError;
        expect(moved.redirectType, equals('MOVED'));
        expect(moved.slot, equals(3999));
        expect(moved.host, equals('127.0.0.1'));
        expect(moved.port, equals(6381));
      });
    });

    group('Integer', () {
      test('parses positive integer', () {
        parser.addData(toBytes(':1000\r\n'));
        expect(replies, equals([1000]));
      });

      test('parses zero', () {
        parser.addData(toBytes(':0\r\n'));
        expect(replies, equals([0]));
      });

      test('parses negative integer', () {
        parser.addData(toBytes(':-5\r\n'));
        expect(replies, equals([-5]));
      });
    });

    group('Bulk String', () {
      test('parses bulk string', () {
        parser.addData(toBytes('\$3\r\nfoo\r\n'));
        expect(replies, equals(['foo']));
      });

      test('parses empty bulk string', () {
        parser.addData(toBytes('\$0\r\n\r\n'));
        expect(replies, equals(['']));
      });

      test('parses null bulk string', () {
        parser.addData(toBytes('\$-1\r\n'));
        expect(replies, equals([null]));
      });

      test('returns Uint8List when returnBuffers is true', () {
        final bufParser = RespParser(
          onReply: (reply) => replies.add(reply),
          onError: (error) => errors.add(error),
          returnBuffers: true,
        );
        bufParser.addData(toBytes('\$3\r\nfoo\r\n'));
        expect(replies, hasLength(1));
        expect(replies[0], isA<Uint8List>());
        expect(utf8.decode(replies[0] as Uint8List), equals('foo'));
      });
    });

    group('Array', () {
      test('parses array of bulk strings', () {
        parser.addData(toBytes('*2\r\n\$3\r\nfoo\r\n\$3\r\nbar\r\n'));
        expect(replies, hasLength(1));
        expect(replies[0], equals(['foo', 'bar']));
      });

      test('parses empty array', () {
        parser.addData(toBytes('*0\r\n'));
        expect(replies, equals([[]]));
      });

      test('parses null array', () {
        parser.addData(toBytes('*-1\r\n'));
        expect(replies, equals([null]));
      });

      test('parses mixed type array', () {
        parser.addData(toBytes('*3\r\n:1\r\n\$3\r\nfoo\r\n+OK\r\n'));
        expect(replies, hasLength(1));
        expect(replies[0], equals([1, 'foo', 'OK']));
      });

      test('parses nested arrays', () {
        parser.addData(
          toBytes('*2\r\n*2\r\n:1\r\n:2\r\n*2\r\n:3\r\n:4\r\n'),
        );
        expect(replies, hasLength(1));
        expect(
          replies[0],
          equals([
            [1, 2],
            [3, 4],
          ]),
        );
      });

      test('parses array with null element', () {
        parser.addData(toBytes('*3\r\n\$3\r\nfoo\r\n\$-1\r\n\$3\r\nbar\r\n'));
        expect(replies, hasLength(1));
        expect(replies[0], equals(['foo', null, 'bar']));
      });
    });

    group('Chunked data', () {
      test('handles data split across chunks', () {
        parser.addData(toBytes('+O'));
        expect(replies, isEmpty);
        parser.addData(toBytes('K\r\n'));
        expect(replies, equals(['OK']));
      });

      test('handles bulk string split in data', () {
        parser.addData(toBytes('\$6\r\nfoo'));
        expect(replies, isEmpty);
        parser.addData(toBytes('bar\r\n'));
        expect(replies, equals(['foobar']));
      });

      test('handles split in length line', () {
        parser.addData(toBytes('\$'));
        expect(replies, isEmpty);
        parser.addData(toBytes('3\r\nfoo\r\n'));
        expect(replies, equals(['foo']));
      });

      test('handles multiple replies in single chunk', () {
        parser.addData(toBytes('+OK\r\n+PONG\r\n:42\r\n'));
        expect(replies, equals(['OK', 'PONG', 42]));
      });

      test('handles array split across chunks', () {
        parser.addData(toBytes('*2\r\n\$3\r\nfoo\r\n'));
        expect(replies, isEmpty);
        parser.addData(toBytes('\$3\r\nbar\r\n'));
        expect(replies, hasLength(1));
        expect(replies[0], equals(['foo', 'bar']));
      });
    });

    group('reset', () {
      test('clears parser state', () {
        parser.addData(toBytes('\$3\r\nfo')); // incomplete
        parser.reset();
        parser.addData(toBytes('+OK\r\n'));
        expect(replies, equals(['OK']));
      });
    });
  });
}
