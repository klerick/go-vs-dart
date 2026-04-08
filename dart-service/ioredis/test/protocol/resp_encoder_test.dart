import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:ioredis/src/protocol/resp_encoder.dart';

void main() {
  late RespEncoder encoder;

  setUp(() {
    encoder = RespEncoder();
  });

  group('RespEncoder', () {
    test('encodes simple command without args', () {
      final bytes = encoder.encode(['PING']);
      final result = utf8.decode(bytes);
      expect(result, equals('*1\r\n\$4\r\nPING\r\n'));
    });

    test('encodes SET command with string args', () {
      final bytes = encoder.encode(['SET', 'key', 'value']);
      final result = utf8.decode(bytes);
      expect(
        result,
        equals('*3\r\n\$3\r\nSET\r\n\$3\r\nkey\r\n\$5\r\nvalue\r\n'),
      );
    });

    test('encodes integer arguments', () {
      final bytes = encoder.encode(['EXPIRE', 'key', 60]);
      final result = utf8.decode(bytes);
      expect(
        result,
        equals('*3\r\n\$6\r\nEXPIRE\r\n\$3\r\nkey\r\n\$2\r\n60\r\n'),
      );
    });

    test('encodes empty string', () {
      final bytes = encoder.encode(['SET', 'key', '']);
      final result = utf8.decode(bytes);
      expect(
        result,
        equals('*3\r\n\$3\r\nSET\r\n\$3\r\nkey\r\n\$0\r\n\r\n'),
      );
    });

    test('encodes binary data (Uint8List)', () {
      final binary = Uint8List.fromList([0x00, 0xFF, 0x42]);
      final bytes = encoder.encode(['SET', 'key', binary]);
      // Length should be 3 for the binary data
      expect(
        utf8.decode(bytes.sublist(0, bytes.indexOf(0x00))),
        contains('\$3\r\n'),
      );
    });

    test('encodes UTF-8 multibyte strings correctly', () {
      // "привет" is 12 bytes in UTF-8
      final bytes = encoder.encode(['SET', 'key', 'привет']);
      final result = utf8.decode(bytes);
      expect(result, contains('\$12\r\nпривет\r\n'));
    });

    test('encodeAll encodes multiple commands', () {
      final bytes = encoder.encodeAll([
        ['SET', 'a', '1'],
        ['SET', 'b', '2'],
      ]);
      final result = utf8.decode(bytes);
      expect(result, contains('*3\r\n\$3\r\nSET\r\n\$1\r\na\r\n\$1\r\n1'));
      expect(result, contains('*3\r\n\$3\r\nSET\r\n\$1\r\nb\r\n\$1\r\n2'));
    });
  });
}
