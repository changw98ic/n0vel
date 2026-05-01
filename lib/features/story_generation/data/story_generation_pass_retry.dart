import 'dart:async';
import 'dart:math';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/request_rate_limiter.dart';

const int _defaultMaxTransientRetries = 3;
const int storyGenerationDefaultMaxTokens =
    AppLlmChatRequest.unlimitedMaxTokens;
const int storyGenerationEditorialMaxTokens = 4096;
const int storyGenerationMaxEscalatedTokens = 65536;
const Duration _baseRetryDelay = Duration(milliseconds: 500);
const Duration _maxRetryDelay = Duration(seconds: 30);
final _retryJitter = Random();
Duration _exponentialBackoffWithJitter(int attempt) {
  final delayMs =
      _baseRetryDelay.inMilliseconds * (1 << attempt); // 2^attempt * base
  final cappedMs = delayMs.clamp(0, _maxRetryDelay.inMilliseconds);
  final jitterMs = _retryJitter.nextInt((cappedMs * 0.2).ceil() + 1);
  return Duration(milliseconds: cappedMs + jitterMs);
}

Future<AppLlmChatResult> requestStoryGenerationPassWithRetry({
  required AppSettingsStore settingsStore,
  required List<AppLlmChatMessage> messages,
  int maxTransientRetries = _defaultMaxTransientRetries,
  int maxOutputRetries = 2,
  int initialMaxTokens = storyGenerationDefaultMaxTokens,
  int maxEscalatedTokens = storyGenerationMaxEscalatedTokens,
  bool Function(String text)? shouldRetryOutput,
  RequestRateLimiter? rateLimiter,
  String? traceName,
  Map<String, Object?> traceMetadata = const {},
}) async {
  var transientRetries = 0;
  var outputRetries = 0;
  var maxTokens = _normalizeTokenLimit(initialMaxTokens);
  final tokenCeiling = _normalizeTokenLimit(maxEscalatedTokens);
  var attempt = 0;

  while (true) {
    if (rateLimiter != null) {
      await rateLimiter.acquire();
    }
    final result = await settingsStore.requestAiCompletion(
      messages: messages,
      maxTokens: maxTokens,
      traceName: traceName ?? _inferStoryGenerationTraceName(messages),
      traceMetadata: {
        ...traceMetadata,
        'attempt': attempt,
        'transientRetryCount': transientRetries,
        'outputRetryCount': outputRetries,
        'maxTokens': maxTokens,
      },
    );
    attempt += 1;

    if (_shouldRetryWithMoreTokens(result: result, maxTokens: maxTokens)) {
      final nextMaxTokens = _nextTokenLimit(maxTokens, ceiling: tokenCeiling);
      if (nextMaxTokens > maxTokens) {
        maxTokens = nextMaxTokens;
        continue;
      }
    }

    if (result.succeeded &&
        (shouldRetryOutput?.call(result.text ?? '') ?? false) &&
        outputRetries < maxOutputRetries) {
      outputRetries += 1;
      continue;
    }

    if (result.succeeded) {
      return result;
    }

    if (!isRetryableStoryGenerationTransportFailure(result) ||
        transientRetries >= maxTransientRetries) {
      return result;
    }

    transientRetries += 1;
    await Future<void>.delayed(
      _exponentialBackoffWithJitter(transientRetries - 1),
    );
  }
}

String _inferStoryGenerationTraceName(List<AppLlmChatMessage> messages) {
  final taskPattern = RegExp(r'^(任务|任务类型)[:：]\s*(.+)$');
  for (final message in messages.reversed) {
    for (final rawLine in message.content.split('\n')) {
      final match = taskPattern.firstMatch(rawLine.trim());
      final value = match?.group(2)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  }
  return 'story_generation_pass';
}

int _normalizeTokenLimit(int value) {
  if (value <= AppLlmChatRequest.unlimitedMaxTokens) {
    return AppLlmChatRequest.unlimitedMaxTokens;
  }
  if (value < storyGenerationEditorialMaxTokens) {
    return storyGenerationEditorialMaxTokens;
  }
  return value > storyGenerationMaxEscalatedTokens
      ? storyGenerationMaxEscalatedTokens
      : value;
}

int _nextTokenLimit(int current, {required int ceiling}) {
  if (current <= AppLlmChatRequest.unlimitedMaxTokens) {
    return AppLlmChatRequest.unlimitedMaxTokens;
  }
  if (current < storyGenerationEditorialMaxTokens) {
    return storyGenerationEditorialMaxTokens.clamp(1, ceiling);
  }
  final doubled = current * 2;
  return doubled > ceiling ? ceiling : doubled;
}

bool _shouldRetryWithMoreTokens({
  required AppLlmChatResult result,
  required int maxTokens,
}) {
  if (maxTokens <= AppLlmChatRequest.unlimitedMaxTokens) {
    return false;
  }
  if (result.succeeded) {
    final text = result.text ?? '';
    return _looksEmptyOrTruncated(
      text: text,
      completionTokens: result.completionTokens,
      maxTokens: maxTokens,
    );
  }

  if (result.failureKind != AppLlmFailureKind.invalidResponse) {
    return false;
  }

  final detail = (result.detail ?? '').toLowerCase();
  return detail.contains('没有可用文本') ||
      detail.contains('empty') ||
      detail.contains('truncated') ||
      detail.contains('截断') ||
      detail.contains('max token') ||
      detail.contains('finish_reason') ||
      detail.contains('length');
}

bool _looksEmptyOrTruncated({
  required String text,
  required int? completionTokens,
  required int maxTokens,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return true;
  }

  if (completionTokens != null && completionTokens >= (maxTokens * 0.95)) {
    return true;
  }

  if (trimmed.length <= 8 &&
      (trimmed == '...' || trimmed == '…' || trimmed == '……')) {
    return true;
  }

  return trimmed.endsWith('，') ||
      trimmed.endsWith('、') ||
      trimmed.endsWith('：') ||
      trimmed.endsWith(':');
}

bool isRetryableStoryGenerationTransportFailure(AppLlmChatResult result) {
  if (result.succeeded) {
    return false;
  }

  if (result.failureKind == AppLlmFailureKind.network ||
      result.failureKind == AppLlmFailureKind.timeout ||
      result.failureKind == AppLlmFailureKind.rateLimited) {
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
      detail.contains('server overloaded') ||
      detail.contains('overloaded') ||
      detail.contains('please try again') ||
      detail.contains('try again in') ||
      detail.contains('please retry shortly') ||
      detail.contains('too many requests') ||
      detail.contains('rate limit') ||
      detail.contains('rate-limit') ||
      detail.contains('resource exhausted') ||
      detail.contains('timed out');
}
