import 'dart:math';

import 'app_llm_client_types.dart';

/// Retry policy for LLM requests.
class AppLlmRetryPolicy {
  const AppLlmRetryPolicy({
    this.maxRetries = 3,
    this.baseDelayMs = 1000,
    this.jitterRatio = 0.2,
    this.maxReconnectAttempts = 7,
    this.retryableFailureKinds = _defaultRetryableKinds,
  });

  final int maxRetries;
  final int baseDelayMs;
  final double jitterRatio;
  final int maxReconnectAttempts;
  final Set<AppLlmFailureKind> retryableFailureKinds;

  static const _defaultRetryableKinds = {
    AppLlmFailureKind.timeout,
    AppLlmFailureKind.rateLimited,
    AppLlmFailureKind.server,
    AppLlmFailureKind.network,
  };

  /// Creates a policy with no jitter for deterministic testing.
  const AppLlmRetryPolicy.noJitter({
    int maxRetries = 3,
    int baseDelayMs = 1000,
    int maxReconnectAttempts = 7,
  }) : this(
         maxRetries: maxRetries,
         baseDelayMs: baseDelayMs,
         jitterRatio: 0.0,
         maxReconnectAttempts: maxReconnectAttempts,
       );

  /// Default policy with production-safe jitter.
  static const defaults = AppLlmRetryPolicy();

  /// Checks if a failure kind is retryable.
  bool isRetryable(AppLlmFailureKind? kind) {
    if (kind == null) return false;
    return retryableFailureKinds.contains(kind);
  }

  /// Calculates backoff delay with optional jitter.
  int backoffMs(int attempt, {Random? rng}) {
    final exponential = baseDelayMs * (1 << attempt);
    if (jitterRatio <= 0) {
      return exponential;
    }
    final jitter = (exponential * jitterRatio).round();
    final effectiveRng = rng ?? Random();
    return exponential + effectiveRng.nextInt(jitter + 1);
  }

  AppLlmRetryPolicy copyWith({
    int? maxRetries,
    int? baseDelayMs,
    double? jitterRatio,
    int? maxReconnectAttempts,
    Set<AppLlmFailureKind>? retryableFailureKinds,
  }) {
    return AppLlmRetryPolicy(
      maxRetries: maxRetries ?? this.maxRetries,
      baseDelayMs: baseDelayMs ?? this.baseDelayMs,
      jitterRatio: jitterRatio ?? this.jitterRatio,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      retryableFailureKinds:
          retryableFailureKinds ?? this.retryableFailureKinds,
    );
  }
}

/// Request execution policy for LLM request pool concurrency.
class AppLlmRequestExecutionPolicy {
  const AppLlmRequestExecutionPolicy({
    this.maxConcurrent = 3,
    this.minStartIntervalMs = 0,
  });

  final int maxConcurrent;
  final int minStartIntervalMs;

  /// Default policy.
  static const defaults = AppLlmRequestExecutionPolicy();

  AppLlmRequestExecutionPolicy copyWith({
    int? maxConcurrent,
    int? minStartIntervalMs,
  }) {
    return AppLlmRequestExecutionPolicy(
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      minStartIntervalMs: minStartIntervalMs ?? this.minStartIntervalMs,
    );
  }
}
