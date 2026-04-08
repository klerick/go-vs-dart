import 'dart:convert';
import 'dart:typed_data';

import '../errors.dart';

/// Callback for parsed RESP replies.
typedef OnReply = void Function(Object? reply);

/// Callback for RESP errors from server.
typedef OnError = void Function(RedisError error);

/// Incremental streaming parser for RESP (REdis Serialization Protocol).
///
/// Handles chunked data from socket — data may arrive split at any byte
/// boundary. The parser accumulates incomplete data and resumes when more
/// bytes arrive.
class RespParser {
  factory RespParser({
    required OnReply onReply,
    required OnError onError,
    bool returnBuffers = false,
    bool stringNumbers = false,
  }) {
    return RespParser._(onReply, onError, returnBuffers, stringNumbers);
  }

  RespParser._(this.onReply, this.onError, this.returnBuffers, this.stringNumbers);

  final OnReply onReply;
  final OnError onError;
  final bool returnBuffers;
  final bool stringNumbers;

  /// Internal buffer accumulating incomplete data.
  Uint8List _buffer = Uint8List(0);

  /// Current read offset in _buffer.
  int _offset = 0;

  /// Reset parser state (e.g. on reconnection).
  void reset() {
    _buffer = Uint8List(0);
    _offset = 0;
  }

  /// Feed data chunk from socket into parser.
  void addData(Uint8List data) {
    if (_offset < _buffer.length) {
      // Append to remaining data
      final remaining = _buffer.length - _offset;
      final newBuffer = Uint8List(remaining + data.length);
      newBuffer.setRange(0, remaining, _buffer, _offset);
      newBuffer.setRange(remaining, remaining + data.length, data);
      _buffer = newBuffer;
      _offset = 0;
    } else {
      _buffer = data;
      _offset = 0;
    }

    while (_offset < _buffer.length) {
      final savedOffset = _offset;
      final result = _parseReply();
      if (result == _incomplete) {
        // Not enough data — restore offset and wait for more
        _offset = savedOffset;
        break;
      }

      if (result is RedisError) {
        this.onError(result);
      } else {
        this.onReply(result);
      }
    }

    // Compact buffer if fully consumed
    if (_offset >= _buffer.length) {
      _buffer = Uint8List(0);
      _offset = 0;
    }
  }

  /// Sentinel for incomplete data.
  static const _incomplete = _Incomplete();

  /// Parse one RESP value starting at current offset.
  /// Returns parsed value, [RedisError], or [_incomplete] if need more data.
  Object? _parseReply() {
    if (_offset >= _buffer.length) return _incomplete;

    final type = _buffer[_offset];
    _offset++;

    switch (type) {
      case 0x2B: // '+' Simple String
        return _parseSimpleString();
      case 0x2D: // '-' Error
        return _parseError();
      case 0x3A: // ':' Integer
        return _parseInteger();
      case 0x24: // '$' Bulk String
        return _parseBulkString();
      case 0x2A: // '*' Array
        return _parseArray();
      default:
        return _incomplete;
    }
  }

  /// Read line until \r\n, return as String. Returns [_incomplete] if not enough data.
  Object _readLine() {
    for (var i = _offset; i < _buffer.length - 1; i++) {
      if (_buffer[i] == 0x0D && _buffer[i + 1] == 0x0A) {
        final line = utf8.decode(_buffer.sublist(_offset, i));
        _offset = i + 2;
        return line;
      }
    }
    return _incomplete;
  }

  Object? _parseSimpleString() {
    final line = _readLine();
    if (line is _Incomplete) return _incomplete;
    return line as String;
  }

  Object _parseError() {
    final line = _readLine();
    if (line is _Incomplete) return _incomplete;
    return RedisError(line as String);
  }

  Object? _parseInteger() {
    final line = _readLine();
    if (line is _Incomplete) return _incomplete;
    if (this.stringNumbers) return line as String;
    return int.parse(line as String);
  }

  Object? _parseBulkString() {
    final line = _readLine();
    if (line is _Incomplete) return _incomplete;
    final length = int.parse(line as String);

    // Null Bulk String
    if (length == -1) return null;

    // Check if we have enough data: <length bytes> + \r\n
    if (_offset + length + 2 > _buffer.length) return _incomplete;

    final data = _buffer.sublist(_offset, _offset + length);
    _offset += length + 2; // skip data + \r\n

    if (this.returnBuffers) {
      return Uint8List.fromList(data);
    }
    return utf8.decode(data);
  }

  Object? _parseArray() {
    final line = _readLine();
    if (line is _Incomplete) return _incomplete;
    final count = int.parse(line as String);

    // Null Array
    if (count == -1) return null;

    final result = <Object?>[];
    for (var i = 0; i < count; i++) {
      final element = _parseReply();
      if (element == _incomplete) return _incomplete;
      result.add(element is RedisError ? element : element);
    }
    return result;
  }
}

/// Sentinel class for incomplete parse state.
class _Incomplete {
  const _Incomplete();
}
