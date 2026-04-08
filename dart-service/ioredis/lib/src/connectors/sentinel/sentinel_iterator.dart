/// Address of a Redis Sentinel node.
class SentinelAddress {
  const SentinelAddress({this.host = '127.0.0.1', this.port = 26379});

  final String host;
  final int port;

  @override
  bool operator ==(Object other) {
    return other is SentinelAddress &&
        this.host == other.host &&
        this.port == other.port;
  }

  @override
  int get hashCode => Object.hash(this.host, this.port);

  @override
  String toString() {
    return '$host:$port';
  }
}

/// Circular iterator over Sentinel addresses.
///
/// Supports prioritizing the last successful sentinel and
/// dynamic discovery of new sentinel nodes.
class SentinelIterator {
  SentinelIterator(List<SentinelAddress> sentinels)
    : _sentinels = List<SentinelAddress>.of(sentinels);

  final List<SentinelAddress> _sentinels;
  int _cursor = 0;

  /// Get the next sentinel address, or null if the cycle is exhausted.
  SentinelAddress? next() {
    if (_cursor >= _sentinels.length) return null;
    return _sentinels[_cursor++];
  }

  /// Reset the cursor for a new cycle.
  ///
  /// If [moveCurrentToFirst] is true, the last used sentinel is moved
  /// to the front of the list (prioritizing the successful one).
  void reset({bool moveCurrentToFirst = false}) {
    if (moveCurrentToFirst && _sentinels.length > 1 && _cursor > 0) {
      final lastUsed = _sentinels.removeAt(_cursor - 1);
      _sentinels.insert(0, lastUsed);
    }
    _cursor = 0;
  }

  /// Add a new sentinel address (deduplication by host:port).
  ///
  /// Returns true if added, false if already exists.
  bool add(SentinelAddress address) {
    final normalized = SentinelAddress(
      host: address.host.isEmpty ? '127.0.0.1' : address.host,
      port: address.port,
    );
    if (_sentinels.contains(normalized)) return false;
    _sentinels.add(normalized);
    return true;
  }

  /// Number of known sentinels.
  int get length => _sentinels.length;

  @override
  String toString() {
    return 'SentinelIterator(cursor=$_cursor, sentinels=$_sentinels)';
  }
}
