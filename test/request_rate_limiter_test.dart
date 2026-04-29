import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/request_rate_limiter.dart';

void main() {
  DateTime t(int seconds) => DateTime(2024, 1, 1, 0, 0, seconds);

  group('RequestRateLimiter', () {
    test('nextAvailableIn returns zero when under limit', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 3, now: () => now);

      expect(limiter.nextAvailableIn(), Duration.zero);
      limiter.record();
      expect(limiter.activeCount, 1);
      expect(limiter.nextAvailableIn(), Duration.zero);
    });

    test('nextAvailableIn returns wait duration when at limit', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 2, now: () => now);

      limiter.record();
      now = t(1);
      limiter.record();

      now = t(2);
      expect(limiter.nextAvailableIn(), const Duration(seconds: 58));
    });

    test('timestamps outside window are pruned', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 2, now: () => now);

      limiter.record();
      now = t(1);
      limiter.record();
      expect(limiter.activeCount, 2);

      // Advance past the 60s window — first timestamp should be pruned
      now = t(61);
      expect(limiter.activeCount, 1);
      expect(limiter.nextAvailableIn(), Duration.zero);
    });

    test('requestsPerMinute < 1 is treated as 1', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 0, now: () => now);

      limiter.record();
      now = t(1);
      expect(limiter.nextAvailableIn(), const Duration(seconds: 59));
    });

    test('activeCount reflects pruned state', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 10, now: () => now);

      for (var i = 0; i < 5; i++) {
        limiter.record();
        now = t(i + 1);
      }
      expect(limiter.activeCount, 5);

      // Jump to t=62 — cutoff is t(2); t(0) and t(1) are pruned, t(2)..t(4) remain
      now = t(62);
      expect(limiter.activeCount, 3);
    });

    test('sliding window allows new requests as old ones expire', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 2, now: () => now);

      limiter.record(); // t=0
      now = t(10);
      limiter.record(); // t=10

      // At limit — oldest is t(0), expires at t(60), wait = 60-15 = 45s
      now = t(15);
      expect(limiter.nextAvailableIn(), const Duration(seconds: 45));

      // First request expires once we pass t=60 (isBefore is strict)
      now = t(61);
      expect(limiter.nextAvailableIn(), Duration.zero);
      limiter.record(); // t=61 — t(0) pruned, now slots are t(10) and t(61)
      expect(limiter.activeCount, 2);
    });

    test('multiple rapid records fill up correctly', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 3, now: () => now);

      limiter.record();
      limiter.record();
      limiter.record();
      expect(limiter.activeCount, 3);

      now = t(5);
      expect(limiter.nextAvailableIn(), const Duration(seconds: 55));
    });

    test('nextAvailableIn is zero when all timestamps expired', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 1, now: () => now);

      limiter.record();
      now = t(61);
      expect(limiter.nextAvailableIn(), Duration.zero);
    });

    test('record prunes before adding', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 1, now: () => now);

      limiter.record();
      now = t(61);
      // Old timestamp is pruned, so new record succeeds without blocking
      limiter.record();
      expect(limiter.activeCount, 1);
    });

    test('acquire records timestamp after waiting', () async {
      // Use real time for this async test — RPM=100 is effectively unlimited
      final limiter = RequestRateLimiter(requestsPerMinute: 100);
      await limiter.acquire();
      expect(limiter.activeCount, 1);
    });
  });

  group('RequestRateLimiter edge cases', () {
    test('single request per minute', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 1, now: () => now);

      expect(limiter.nextAvailableIn(), Duration.zero);
      limiter.record();

      now = t(30);
      expect(limiter.nextAvailableIn(), const Duration(seconds: 30));

      now = t(60);
      expect(limiter.nextAvailableIn(), Duration.zero);
    });

    test('boundary: exactly at window edge', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 1, now: () => now);

      limiter.record();

      // Exactly 60 seconds later — the timestamp is no longer "before" the cutoff
      // cutoff = now - 60s = t(-60), timestamp is t(0), t(0).isBefore(t(-60)) = false
      // So the timestamp survives, and we still need to wait
      now = t(60);
      expect(limiter.nextAvailableIn(), Duration.zero);
    });

    test('high RPM accommodates many requests', () {
      var now = t(0);
      final limiter = RequestRateLimiter(requestsPerMinute: 60, now: () => now);

      for (var i = 0; i < 60; i++) {
        limiter.record();
      }
      expect(limiter.activeCount, 60);

      now = t(1);
      expect(limiter.nextAvailableIn(), const Duration(seconds: 59));
    });
  });
}
