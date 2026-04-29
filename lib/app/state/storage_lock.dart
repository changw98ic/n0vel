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
  Future<void>? _pending;

  Future<T> run<T>(Future<T> Function() action) async {
    if (_pending == null) {
      try {
        final future = action();
        _pending = future.then((_) {}, onError: (_) {});
        return await future;
      } finally {
        _pending = null;
      }
    }

    final previous = _pending!;
    final completer = Completer<void>();
    _pending = completer.future;
    await previous;
    try {
      return await action();
    } finally {
      completer.complete();
      _pending = null;
    }
  }
}
