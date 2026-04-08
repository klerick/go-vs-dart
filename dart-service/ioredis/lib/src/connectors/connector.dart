import 'dart:io';

/// Abstract base for all Redis connectors.
///
/// Connectors handle the low-level socket creation (TCP/TLS/Unix).
abstract class Connector {
  Connector({this.disconnectTimeout = const Duration(seconds: 2)});

  final Duration disconnectTimeout;
  Socket? stream;

  /// Establish connection and return the socket.
  Future<Socket> connect();

  /// Gracefully disconnect.
  void disconnect() {
    final s = this.stream;
    if (s == null) return;
    s.destroy();
    this.stream = null;
  }

  /// Validate the connection (e.g. Sentinel role check).
  bool check(Map<String, String> info) {
    return true;
  }
}
