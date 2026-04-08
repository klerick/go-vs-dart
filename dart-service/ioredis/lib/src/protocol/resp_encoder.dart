import 'dart:convert';
import 'dart:typed_data';

const _crlf = [0x0D, 0x0A]; // \r\n

/// Encodes Redis commands into RESP (REdis Serialization Protocol) bytes.
///
/// All commands are encoded as RESP Arrays of Bulk Strings:
/// `*<count>\r\n$<len>\r\n<data>\r\n...`
class RespEncoder {
  /// Encodes a command (name + args) into RESP bytes.
  ///
  /// Each element is converted to a Bulk String:
  /// - [String] → UTF-8 encoded
  /// - [int] / [double] → toString() → UTF-8
  /// - [Uint8List] → raw bytes (binary-safe)
  Uint8List encode(List<Object> args) {
    final parts = <List<int>>[];
    var totalLength = 0;

    // Array header: *<count>\r\n
    final header = _encodeArrayHeader(args.length);
    parts.add(header);
    totalLength += header.length;

    for (final arg in args) {
      final bytes = _toBulkString(arg);
      parts.add(bytes);
      totalLength += bytes.length;
    }

    // Concatenate all parts into single buffer
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  /// Encodes multiple commands into a single buffer (for pipelining).
  Uint8List encodeAll(List<List<Object>> commands) {
    final parts = <Uint8List>[];
    var totalLength = 0;
    for (final cmd in commands) {
      final encoded = this.encode(cmd);
      parts.add(encoded);
      totalLength += encoded.length;
    }
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final part in parts) {
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  Uint8List _encodeArrayHeader(int count) {
    final str = '*$count\r\n';
    return Uint8List.fromList(utf8.encode(str));
  }

  Uint8List _toBulkString(Object value) {
    final Uint8List data;
    if (value is Uint8List) {
      data = value;
    } else if (value is String) {
      data = Uint8List.fromList(utf8.encode(value));
    } else if (value is int || value is double) {
      data = Uint8List.fromList(utf8.encode(value.toString()));
    } else {
      data = Uint8List.fromList(utf8.encode(value.toString()));
    }

    // $<len>\r\n<data>\r\n
    final header = utf8.encode('\$${data.length}\r\n');
    final result = Uint8List(header.length + data.length + 2);
    result.setRange(0, header.length, header);
    result.setRange(header.length, header.length + data.length, data);
    result[result.length - 2] = _crlf[0];
    result[result.length - 1] = _crlf[1];
    return result;
  }
}
