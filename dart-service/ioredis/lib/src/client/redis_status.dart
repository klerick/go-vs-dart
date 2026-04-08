/// Connection status of the Redis client.
enum RedisStatus {
  /// Client created but not connected.
  wait,

  /// Connection in progress.
  connecting,

  /// Socket connected, handshake in progress (AUTH, SELECT, ready check).
  connect,

  /// Fully ready to accept commands.
  ready,

  /// Connection closed, may reconnect.
  close,

  /// Waiting before reconnection attempt.
  reconnecting,

  /// Connection permanently closed.
  end,
}
