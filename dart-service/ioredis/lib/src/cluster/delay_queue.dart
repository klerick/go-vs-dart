import 'dart:async';
import 'dart:collection';

/// A queue of deferred function executions, grouped by bucket.
///
/// Used in cluster for delaying retries on MOVED, TRYAGAIN, CLUSTERDOWN.
class DelayQueue {
  final Map<String, Queue<void Function()>> _queues = {};
  final Map<String, Timer> _timers = {};

  /// Push a function to be executed after [delay].
  ///
  /// Functions in the same [bucket] are executed together.
  void push(String bucket, void Function() fn, Duration delay) {
    _queues.putIfAbsent(bucket, Queue<void Function()>.new).add(fn);

    if (!_timers.containsKey(bucket)) {
      _timers[bucket] = Timer(delay, () {
        _execute(bucket);
      });
    }
  }

  void _execute(String bucket) {
    final queue = _queues.remove(bucket);
    _timers.remove(bucket);
    if (queue == null) return;

    while (queue.isNotEmpty) {
      queue.removeFirst()();
    }
  }

  /// Cancel all pending executions.
  void clear() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _queues.clear();
  }
}
