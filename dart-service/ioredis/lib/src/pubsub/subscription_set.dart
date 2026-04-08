/// Tracks active Pub/Sub subscriptions by type.
class SubscriptionSet {
  final Map<String, Set<String>> _sets = {
    'subscribe': <String>{},
    'psubscribe': <String>{},
    'ssubscribe': <String>{},
  };

  /// Register a subscription.
  void add(String type, String channel) {
    final normalized = _normalize(type);
    _sets[normalized]?.add(channel);
  }

  /// Unregister a subscription.
  void remove(String type, String channel) {
    final normalized = _normalize(type);
    _sets[normalized]?.remove(channel);
  }

  /// Get all channels for a subscription type.
  Set<String> channels(String type) {
    final normalized = _normalize(type);
    return _sets[normalized] ?? const {};
  }

  /// Whether there are no active subscriptions.
  bool get isEmpty {
    return _sets.values.every((set) => set.isEmpty);
  }

  /// Clear all subscriptions.
  void clear() {
    for (final set in _sets.values) {
      set.clear();
    }
  }

  /// Normalize unsubscribe types to their subscribe counterpart.
  String _normalize(String type) {
    return switch (type) {
      'unsubscribe' => 'subscribe',
      'punsubscribe' => 'psubscribe',
      'sunsubscribe' => 'ssubscribe',
      _ => type,
    };
  }
}
