import 'dart:async';

/// Sliding-window rate limiter for LLM API requests.
///
/// Tracks request timestamps within a one-minute rolling window and delays
/// callers when the configured [requestsPerMinute] limit would be exceeded.
///
/// The [now] parameter can be injected for deterministic testing; it defaults
/// to [DateTime.now] in production.
class RequestRateLimiter {
  RequestRateLimiter({
    required int requestsPerMinute,
    DateTime Function()? now,
  }) : _maxRequests = requestsPerMinute < 1 ? 1 : requestsPerMinute,
       _now = now ?? DateTime.now;

  final int _maxRequests;
  final DateTime Function() _now;
  final List<DateTime> _timestamps = [];

  static const Duration _window = Duration(minutes: 1);

  /// How long until a request slot is available, or [Duration.zero] if
  /// a request can proceed immediately.
  Duration nextAvailableIn() {
    _prune();
    if (_timestamps.length < _maxRequests) return Duration.zero;
    final waitUntil = _timestamps.first.add(_window);
    final remaining = waitUntil.difference(_now());
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  /// Record a request at the current moment.
  void record() {
    _prune();
    _timestamps.add(_now());
  }

  /// Wait (if necessary) for a slot, then record the request.
  Future<void> acquire() async {
    final delay = nextAvailableIn();
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    record();
  }

  /// Number of recorded requests currently inside the rolling window.
  int get activeCount {
    _prune();
    return _timestamps.length;
  }

  void _prune() {
    final cutoff = _now().subtract(_window);
    while (_timestamps.isNotEmpty && _timestamps.first.isBefore(cutoff)) {
      _timestamps.removeAt(0);
    }
  }
}
