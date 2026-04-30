import 'dart:async';

class AppLlmRequestPool {
  int _maxConcurrent;
  int _active = 0;
  int _reserved = 0;
  final List<Completer<void>> _waiters = [];
  Completer<void>? _cooldownCompleter;
  Timer? _cooldownTimer;
  DateTime? _cooldownUntil;

  AppLlmRequestPool({int maxConcurrent = 3}) : _maxConcurrent = maxConcurrent;

  int get maxConcurrent => _maxConcurrent;

  set maxConcurrent(int value) {
    final newLimit = value < 1 ? 1 : value;
    _maxConcurrent = newLimit;
    _drainWaiters();
  }

  int get active => _active;
  int get waiting => _waiters.length;
  bool get isCoolingDown => _cooldownCompleter != null;

  void coolDownFor(Duration duration) {
    if (duration <= Duration.zero) {
      return;
    }

    final cooldownUntil = DateTime.now().add(duration);
    final activeUntil = _cooldownUntil;
    if (_cooldownCompleter != null &&
        activeUntil != null &&
        !cooldownUntil.isAfter(activeUntil)) {
      return;
    }

    _cooldownCompleter ??= Completer<void>();
    _cooldownUntil = cooldownUntil;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(duration, _finishCooldown);
  }

  Future<T> run<T>(Future<T> Function() operation) async {
    if (_canStartImmediately) {
      _active += 1;
    } else {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      _drainWaiters();
      await waiter.future;
      _reserved -= 1;
      _active += 1;
    }

    try {
      return await operation();
    } finally {
      _active -= 1;
      _drainWaiters();
    }
  }

  bool get _canStartImmediately =>
      _cooldownCompleter == null &&
      _waiters.isEmpty &&
      _reserved == 0 &&
      _active < _maxConcurrent;

  void _finishCooldown() {
    final completer = _cooldownCompleter;
    if (completer == null) {
      return;
    }

    _cooldownCompleter = null;
    _cooldownTimer = null;
    _cooldownUntil = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
    _drainWaiters();
  }

  void _drainWaiters() {
    if (_cooldownCompleter != null) {
      return;
    }

    while (_active + _reserved < _maxConcurrent && _waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      _reserved += 1;
      waiter.complete();
    }
  }
}

final globalLlmRequestPool = AppLlmRequestPool(maxConcurrent: 3);
