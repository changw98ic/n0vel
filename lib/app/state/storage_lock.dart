import 'dart:async';

/// A global, key-partitioned asynchronous lock for storage operations.
///
/// Each unique [key] gets its own wait queue, so operations targeting
/// different files or databases can run concurrently, while operations
/// targeting the same path are serialized.
class StorageLock {
  static final StorageLock _instance = StorageLock._();
  factory StorageLock() => _instance;
  StorageLock._();

  final Map<String, _LockQueue> _queues = <String, _LockQueue>{};

  /// Runs [action] while holding the lock for [key].
  ///
  /// If another operation is already in progress for the same [key],
  /// this call waits until it completes before starting [action].
  Future<T> synchronized<T>(String key, Future<T> Function() action) async {
    final queue = _queues.putIfAbsent(key, () => _LockQueue());
    return queue.run(action);
  }
}

class _LockQueue {
  Future<void>? _tail;

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _tail;
    final completer = Completer<void>();
    _tail = completer.future;

    if (previous != null) {
      await previous;
    }

    try {
      return await action();
    } finally {
      if (identical(_tail, completer.future)) {
        _tail = null;
      }
      completer.complete();
    }
  }
}
