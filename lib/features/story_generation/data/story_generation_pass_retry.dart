import 'dart:async';
import 'dart:math';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/request_rate_limiter.dart';

const int _defaultMaxTransientRetries = 3;
const Duration _baseRetryDelay = Duration(milliseconds: 500);
const Duration _maxRetryDelay = Duration(seconds: 30);
final _retryJitter = Random();
Duration _exponentialBackoffWithJitter(int attempt) {
  final delayMs = _baseRetryDelay.inMilliseconds *
      (1 << attempt); // 2^attempt * base
  final cappedMs = delayMs.clamp(0, _maxRetryDelay.inMilliseconds);
  final jitterMs = _retryJitter.nextInt((cappedMs * 0.2).ceil() + 1);
  return Duration(milliseconds: cappedMs + jitterMs);
}

Future<AppLlmChatResult> requestStoryGenerationPassWithRetry({
  required AppSettingsStore settingsStore,
  required List<AppLlmChatMessage> messages,
  int maxTransientRetries = _defaultMaxTransientRetries,
  RequestRateLimiter? rateLimiter,
}) async {
  var transientRetries = 0;

  while (true) {
    if (rateLimiter != null) {
      await rateLimiter.acquire();
    }
    final result = await settingsStore.requestAiCompletion(messages: messages);
    if (result.succeeded ||
        !isRetryableStoryGenerationTransportFailure(result) ||
        transientRetries >= maxTransientRetries) {
      return result;
    }

    transientRetries += 1;
    await Future<void>.delayed(_exponentialBackoffWithJitter(transientRetries - 1));
  }
}

bool isRetryableStoryGenerationTransportFailure(AppLlmChatResult result) {
  if (result.succeeded) {
    return false;
  }

  if (result.failureKind == AppLlmFailureKind.network ||
      result.failureKind == AppLlmFailureKind.timeout) {
    return true;
  }

  if (result.failureKind != AppLlmFailureKind.server &&
      result.failureKind != AppLlmFailureKind.invalidResponse) {
    return false;
  }

  final detail = (result.detail ?? '').toLowerCase();
  return detail.contains('connection closed before full header was received') ||
      detail.contains('connection reset by peer') ||
      detail.contains('broken pipe') ||
      detail.contains('software caused connection abort') ||
      detail.contains('connection terminated') ||
      detail.contains('temporarily unavailable') ||
      detail.contains('timed out');
}
