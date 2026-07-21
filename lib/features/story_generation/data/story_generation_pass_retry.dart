import 'dart:async';
import 'dart:math';

import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import '../domain/contracts/settings_contract.dart';
import 'evaluation/agent_evaluation_trace_context.dart';
import 'story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/data/request_rate_limiter.dart';

const int _defaultMaxTransientRetries = 3;
const int storyGenerationDefaultMaxTokens =
    AppLlmChatRequest.unlimitedMaxTokens;
const int storyGenerationEditorialMaxTokens = 4096;
const int storyGenerationMaxEscalatedTokens = 65536;
const Duration _baseRetryDelay = Duration(milliseconds: 500);
const Duration _maxRetryDelay = Duration(seconds: 30);
final _retryJitter = Random();

typedef StoryGenerationAttemptDispatcher =
    Future<AppLlmChatResult> Function({
      required int maxTokens,
      required int attempt,
      required int transientRetryCount,
      required int outputRetryCount,
    });

Duration _exponentialBackoffWithJitter(int attempt) {
  final delayMs =
      _baseRetryDelay.inMilliseconds * (1 << attempt); // 2^attempt * base
  final cappedMs = delayMs.clamp(0, _maxRetryDelay.inMilliseconds);
  final jitterMs = _retryJitter.nextInt((cappedMs * 0.2).ceil() + 1);
  return Duration(milliseconds: cappedMs + jitterMs);
}

Future<AppLlmChatResult> requestFormalStoryGenerationPassWithRetry({
  required StoryGenerationSettingsContract settingsStore,
  required List<AppLlmChatMessage> messages,
  int maxTransientRetries = _defaultMaxTransientRetries,
  int maxOutputRetries = 2,
  int initialMaxTokens = storyGenerationDefaultMaxTokens,
  int maxEscalatedTokens = storyGenerationMaxEscalatedTokens,
  bool Function(String text)? shouldRetryOutput,
  RequestRateLimiter? rateLimiter,
  String? traceName,
  Map<String, Object?> traceMetadata = const {},
  required StoryPromptInvocation promptInvocation,
  required PromptInvocationEvidence promptInvocationEvidence,
}) {
  if (!promptInvocationEvidence.matchesMessages(messages) ||
      promptInvocationEvidence.promptReleaseRef !=
          promptInvocation.promptReleaseRef ||
      promptInvocationEvidence.release.contentHash !=
          promptInvocation.release.contentHash) {
    throw StateError('formal prompt invocation evidence mismatch');
  }
  final identity = _validateFormalPromptIdentity(
    stageId: promptInvocation.callSite.stageId,
    callSiteId: promptInvocation.callSite.callSiteId,
    variantId: promptInvocation.callSite.variantId,
    generationBundleHash: promptInvocation.generationBundleHash,
  );
  final evaluationContext = AgentEvaluationTraceContext.current;
  if (evaluationContext != null &&
      evaluationContext.generationBundleHash != identity.generationBundleHash) {
    throw StateError(
      'formal evaluation cell bundle does not match prompt invocation bundle',
    );
  }
  return requestStoryGenerationPassWithRetry(
    dispatch:
        ({
          required maxTokens,
          required attempt,
          required transientRetryCount,
          required outputRetryCount,
        }) {
          // llm-call-site: boundary.story.retry-dispatch
          return settingsStore.requestAiCompletion(
            messages: messages,
            maxTokens: maxTokens,
            traceName: traceName ?? _inferStoryGenerationTraceName(messages),
            promptReleaseRef: promptInvocation.promptReleaseRef,
            promptInvocationEvidence: promptInvocationEvidence,
            stageId: identity.stageId,
            callSiteId: identity.callSiteId,
            variantId: identity.variantId,
            generationBundleHash: identity.generationBundleHash,
            traceMetadata: {
              ...traceMetadata,
              'attempt': attempt,
              'transientRetryCount': transientRetryCount,
              'outputRetryCount': outputRetryCount,
              'maxTokens': maxTokens,
              'promptReleaseRef': promptInvocation.promptReleaseRef.toJson(),
              'stageId': identity.stageId,
              'callSiteId': identity.callSiteId,
              'variantId': identity.variantId,
              'generationBundleHash': identity.generationBundleHash,
              if (evaluationContext != null)
                ...evaluationContext.toTraceMetadata(),
            },
          );
        },
    maxTransientRetries: maxTransientRetries,
    maxOutputRetries: maxOutputRetries,
    initialMaxTokens: initialMaxTokens,
    maxEscalatedTokens: maxEscalatedTokens,
    shouldRetryOutput: shouldRetryOutput,
    rateLimiter: rateLimiter,
  );
}

/// Pure retry state machine. The caller owns authorization and transport;
/// production story generation must use
/// [requestFormalStoryGenerationPassWithRetry], which supplies a registered
/// prompt authority before dispatch reaches the provider.
Future<AppLlmChatResult> requestStoryGenerationPassWithRetry({
  required StoryGenerationAttemptDispatcher dispatch,
  int maxTransientRetries = _defaultMaxTransientRetries,
  int maxOutputRetries = 2,
  int initialMaxTokens = storyGenerationDefaultMaxTokens,
  int maxEscalatedTokens = storyGenerationMaxEscalatedTokens,
  bool Function(String text)? shouldRetryOutput,
  RequestRateLimiter? rateLimiter,
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
    final result = await dispatch(
      maxTokens: maxTokens,
      attempt: attempt,
      transientRetryCount: transientRetries,
      outputRetryCount: outputRetries,
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

({
  String stageId,
  String callSiteId,
  String variantId,
  String generationBundleHash,
})
_validateFormalPromptIdentity({
  required String stageId,
  required String callSiteId,
  required String variantId,
  required String generationBundleHash,
}) {
  String requiredValue(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'required');
    }
    return normalized;
  }

  final hash = requiredValue(generationBundleHash, 'generationBundleHash');
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(hash)) {
    throw ArgumentError.value(
      generationBundleHash,
      'generationBundleHash',
      'must be a sha256:<lower-hex> digest',
    );
  }
  return (
    stageId: requiredValue(stageId, 'stageId'),
    callSiteId: requiredValue(callSiteId, 'callSiteId'),
    variantId: requiredValue(variantId, 'variantId'),
    generationBundleHash: hash,
  );
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
