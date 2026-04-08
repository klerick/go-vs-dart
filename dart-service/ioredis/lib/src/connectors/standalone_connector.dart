import 'dart:io';
import 'dart:typed_data';

import 'connector.dart';

/// Platform-specific TCP keepAlive constants.
/// Only supported platforms are included — others silently skip keepAlive.
const _keepAliveConfig = <String, _KeepAliveConstants>{
  'linux': _KeepAliveConstants(soKeepalive: 9, tcpKeepidle: 4, tcpKeepintvl: 5, tcpKeepcnt: 6),
  'android': _KeepAliveConstants(soKeepalive: 9, tcpKeepidle: 4, tcpKeepintvl: 5, tcpKeepcnt: 6),
  'macos': _KeepAliveConstants(soKeepalive: 8, tcpKeepidle: 0x10),
  'ios': _KeepAliveConstants(soKeepalive: 8, tcpKeepidle: 0x10),
  'freebsd': _KeepAliveConstants(soKeepalive: 8, tcpKeepidle: 0x10),
};

class _KeepAliveConstants {
  final int soKeepalive;
  final int tcpKeepidle;
  final int? tcpKeepintvl;
  final int? tcpKeepcnt;

  const _KeepAliveConstants({
    required this.soKeepalive,
    required this.tcpKeepidle,
    this.tcpKeepintvl,
    this.tcpKeepcnt,
  });
}

/// Connects directly to a single Redis server via TCP or TLS.
class StandaloneConnector extends Connector {
  StandaloneConnector({
    this.host = 'localhost',
    this.port = 6379,
    this.securityContext,
    this.connectTimeout = const Duration(seconds: 10),
    this.noDelay = true,
    this.keepAlive,
    super.disconnectTimeout,
  });

  final String host;
  final int port;
  final SecurityContext? securityContext;
  final Duration connectTimeout;
  final bool noDelay;
  final Duration? keepAlive;

  @override
  Future<Socket> connect() async {
    final Socket socket;
    if (this.securityContext != null) {
      socket = await SecureSocket.connect(
        this.host,
        this.port,
        context: this.securityContext,
        timeout: this.connectTimeout,
      );
    } else {
      socket = await Socket.connect(
        this.host,
        this.port,
        timeout: this.connectTimeout,
      );
    }
    if (this.noDelay) {
      socket.setOption(SocketOption.tcpNoDelay, true);
    }
    if (this.keepAlive != null) {
      _enableKeepAlive(socket, this.keepAlive!);
    }
    this.stream = socket;
    return socket;
  }

  static void _enableKeepAlive(Socket socket, Duration idle) {
    final config = _keepAliveConfig[Platform.operatingSystem];
    if (config == null) return;

    final idleSeconds = idle.inSeconds;
    const levelTcp = 6; // IPPROTO_TCP

    // Enable SO_KEEPALIVE
    socket.setRawOption(RawSocketOption(
      RawSocketOption.levelSocket,
      config.soKeepalive,
      _intToBytes(1),
    ));

    // Set idle time before first probe
    socket.setRawOption(RawSocketOption(
      levelTcp,
      config.tcpKeepidle,
      _intToBytes(idleSeconds),
    ));

    // Set inter-probe interval and probe count (Linux/Android only)
    if (config.tcpKeepintvl != null) {
      socket.setRawOption(RawSocketOption(
        levelTcp,
        config.tcpKeepintvl!,
        _intToBytes(idleSeconds ~/ 3),
      ));
    }
    if (config.tcpKeepcnt != null) {
      socket.setRawOption(RawSocketOption(
        levelTcp,
        config.tcpKeepcnt!,
        _intToBytes(3),
      ));
    }
  }

  static Uint8List _intToBytes(int value) {
    final data = ByteData(4);
    data.setInt32(0, value, Endian.host);
    return data.buffer.asUint8List();
  }
}