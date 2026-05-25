import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_execution_policy.dart';

void main() {
  group('AppLlmRetryPolicy', () {
    test('default policy has expected values', () {
      const policy = AppLlmRetryPolicy.defaults;

      expect(policy.maxRetries, 3);
      expect(policy.baseDelayMs, 1000);
      expect(policy.jitterRatio, 0.2);
      expect(policy.maxReconnectAttempts, 7);
    });

    test('noJitter policy has zero jitter ratio', () {
      const policy = AppLlmRetryPolicy.noJitter(
        maxRetries: 5,
        baseDelayMs: 2000,
      );

      expect(policy.maxRetries, 5);
      expect(policy.baseDelayMs, 2000);
      expect(policy.jitterRatio, 0.0);
    });

    test('isRetryable returns true for transient failures', () {
      const policy = AppLlmRetryPolicy.defaults;

      expect(policy.isRetryable(AppLlmFailureKind.timeout), isTrue);
      expect(policy.isRetryable(AppLlmFailureKind.rateLimited), isTrue);
      expect(policy.isRetryable(AppLlmFailureKind.server), isTrue);
      expect(policy.isRetryable(AppLlmFailureKind.network), isTrue);
    });

    test('isRetryable returns false for non-retryable failures', () {
      const policy = AppLlmRetryPolicy.defaults;

      expect(policy.isRetryable(AppLlmFailureKind.unauthorized), isFalse);
      expect(policy.isRetryable(AppLlmFailureKind.modelNotFound), isFalse);
      expect(policy.isRetryable(AppLlmFailureKind.invalidResponse), isFalse);
      expect(
        policy.isRetryable(AppLlmFailureKind.unsupportedPlatform),
        isFalse,
      );
      expect(policy.isRetryable(AppLlmFailureKind.insecureScheme), isFalse);
      expect(policy.isRetryable(null), isFalse);
    });

    test('backoffMs with zero jitter is deterministic', () {
      const policy = AppLlmRetryPolicy.noJitter(baseDelayMs: 1000);

      expect(policy.backoffMs(0), 1000); // 1000 * 2^0 = 1000
      expect(policy.backoffMs(1), 2000); // 1000 * 2^1 = 2000
      expect(policy.backoffMs(2), 4000); // 1000 * 2^2 = 4000
      expect(policy.backoffMs(3), 8000); // 1000 * 2^3 = 8000
    });

    test('backoffMs with jitter adds random delay', () {
      const policy = AppLlmRetryPolicy(baseDelayMs: 1000, jitterRatio: 0.2);

      // Use deterministic seeded random for reproducibility
      final rng = Random(42);

      final base = policy.backoffMs(1, rng: rng); // 2000 base
      // With 20% jitter, should be between 2000 and 2400 (inclusive)
      expect(base, greaterThanOrEqualTo(2000));
      expect(base, lessThanOrEqualTo(2400));
    });

    test('backoffMs respects baseDelayMs parameter', () {
      const policy = AppLlmRetryPolicy.noJitter(baseDelayMs: 500);

      expect(policy.backoffMs(0), 500);
      expect(policy.backoffMs(1), 1000);
      expect(policy.backoffMs(2), 2000);
    });

    test('copyWith preserves unchanged values', () {
      const policy = AppLlmRetryPolicy(
        maxRetries: 3,
        baseDelayMs: 1000,
        jitterRatio: 0.2,
        maxReconnectAttempts: 7,
      );

      final copy = policy.copyWith(maxRetries: 5);

      expect(copy.maxRetries, 5);
      expect(copy.baseDelayMs, 1000);
      expect(copy.jitterRatio, 0.2);
      expect(copy.maxReconnectAttempts, 7);
    });

    test('custom retryableFailureKinds is respected', () {
      const policy = AppLlmRetryPolicy(
        retryableFailureKinds: {
          AppLlmFailureKind.timeout,
          AppLlmFailureKind.network,
        },
      );

      expect(policy.isRetryable(AppLlmFailureKind.timeout), isTrue);
      expect(policy.isRetryable(AppLlmFailureKind.network), isTrue);
      expect(policy.isRetryable(AppLlmFailureKind.rateLimited), isFalse);
      expect(policy.isRetryable(AppLlmFailureKind.server), isFalse);
    });
  });

  group('AppLlmRequestExecutionPolicy', () {
    test('default policy has expected values', () {
      const policy = AppLlmRequestExecutionPolicy.defaults;

      expect(policy.maxConcurrent, 3);
      expect(policy.minStartIntervalMs, 0);
    });

    test('custom maxConcurrent is respected', () {
      const policy = AppLlmRequestExecutionPolicy(
        maxConcurrent: 10,
        minStartIntervalMs: 125,
      );

      expect(policy.maxConcurrent, 10);
      expect(policy.minStartIntervalMs, 125);
    });

    test('copyWith preserves unchanged values', () {
      const policy = AppLlmRequestExecutionPolicy(
        maxConcurrent: 5,
        minStartIntervalMs: 50,
      );

      final copy = policy.copyWith(maxConcurrent: 10);

      expect(copy.maxConcurrent, 10);
      expect(copy.minStartIntervalMs, 50);
    });
  });
}
