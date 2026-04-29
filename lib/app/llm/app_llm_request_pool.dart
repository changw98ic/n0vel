import 'dart:async';

class AppLlmRequestPool {
  int _maxConcurrent;
  int _active = 0;
  final List<Completer<void>> _waiters = [];

  AppLlmRequestPool({int maxConcurrent = 3}) : _maxConcurrent = maxConcurrent;

  int get maxConcurrent => _maxConcurrent;

  set maxConcurrent(int value) {
    final newLimit = value < 1 ? 1 : value;
    _maxConcurrent = newLimit;
    while (_active < _maxConcurrent && _waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }

  int get active => _active;
  int get waiting => _waiters.length;

  Future<T> run<T>(Future<T> Function() operation) async {
    while (_active >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active += 1;
    try {
      return await operation();
    } finally {
      _active -= 1;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}

final globalLlmRequestPool = AppLlmRequestPool(maxConcurrent: 3);
