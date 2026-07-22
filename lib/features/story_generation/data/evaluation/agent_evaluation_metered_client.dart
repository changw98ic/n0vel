import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../../../app/llm/app_llm_client_contract.dart';
import '../../../../app/llm/app_llm_client_types.dart';
import 'agent_evaluation_execution_budget.dart';
import 'agent_evaluation_manifest.dart';

final class AgentEvaluationProviderCallEvidence {
  AgentEvaluationProviderCallEvidence({
    required this.sequenceNo,
    required this.modelRouteHash,
    required this.model,
    required this.promptTokens,
    required this.completionTokens,
    required this.succeeded,
    this.failureKind,
  }) {
    AgentEvaluationHashes.requireDigest(modelRouteHash, 'modelRouteHash');
    if (sequenceNo <= 0 || model.trim().isEmpty) {
      throw ArgumentError('provider call identity is invalid');
    }
    if (promptTokens < 0 || completionTokens < 0) {
      throw ArgumentError('provider token usage must be non-negative');
    }
  }

  final int sequenceNo;
  final String modelRouteHash;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final bool succeeded;
  final AppLlmFailureKind? failureKind;
}

final class AgentEvaluationMeterSnapshot {
  AgentEvaluationMeterSnapshot._({
    required this.trialSlotId,
    required this.attemptNo,
    required this.modelRouteHash,
    required this.model,
    required List<AgentEvaluationProviderCallEvidence> calls,
  }) : calls = List<AgentEvaluationProviderCallEvidence>.unmodifiable(calls);

  final String trialSlotId;
  final int attemptNo;
  final String modelRouteHash;
  final String model;
  final List<AgentEvaluationProviderCallEvidence> calls;

  /// Rehydrates an append-only, hash-verified provider checkpoint.
  ///
  /// This does not create usage evidence by itself. Callers must first verify
  /// the enclosing checkpoint digest and formal attempt identity.
  factory AgentEvaluationMeterSnapshot.rehydrate({
    required String trialSlotId,
    required int attemptNo,
    required String modelRouteHash,
    required String model,
    required Iterable<AgentEvaluationProviderCallEvidence> calls,
  }) {
    final frozen = calls.toList(growable: false);
    if (trialSlotId.trim().isEmpty || attemptNo <= 0 || model.trim().isEmpty) {
      throw ArgumentError('meter checkpoint identity is invalid');
    }
    AgentEvaluationHashes.requireDigest(modelRouteHash, 'modelRouteHash');
    if (frozen.isEmpty ||
        frozen.asMap().entries.any(
          (entry) =>
              entry.value.sequenceNo != entry.key + 1 ||
              entry.value.modelRouteHash != modelRouteHash ||
              entry.value.model != model,
        )) {
      throw ArgumentError('meter checkpoint call sequence is invalid');
    }
    return AgentEvaluationMeterSnapshot._(
      trialSlotId: trialSlotId,
      attemptNo: attemptNo,
      modelRouteHash: modelRouteHash,
      model: model,
      calls: frozen,
    );
  }
}

/// Fail-closed provider wrapper used by release evaluation harnesses.
///
/// A formal attempt owns the complete call scope. Callers cannot select a late
/// cursor and omit earlier calls, and overlapping attempts are rejected.
final class AgentEvaluationMeteredAppLlmClient
    implements
        AppLlmClient,
        AppLlmSinglePhysicalDispatchCapability,
        AppLlmPhysicalDispatchLifecycle {
  AgentEvaluationMeteredAppLlmClient({
    required AppLlmClient inner,
    required this.model,
    required this.provider,
    required String baseUrl,
    String? frozenModelRouteHash,
    AppLlmTimeoutConfig? frozenTimeout,
    String? frozenApiKey,
    AgentEvaluationExecutionBudgetGuard? executionBudget,
    int? frozenMaxCompletionTokens,
    int? maxCallsPerAttempt,
    int? maxTokensPerAttempt,
    bool returnFailedResultAfterAccounting = false,
  }) : _inner = inner,
       baseUrl = canonicalAgentEvaluationBaseUrl(baseUrl),
       modelRouteHash = frozenModelRouteHash ?? modelRouteHashFor(model),
       _frozenTimeout = frozenTimeout,
       _frozenApiKey = frozenApiKey,
       _executionBudget = executionBudget,
       _frozenMaxCompletionTokens = frozenMaxCompletionTokens,
       _maxCallsPerAttempt = maxCallsPerAttempt,
       _maxTokensPerAttempt = maxTokensPerAttempt,
       _returnFailedResultAfterAccounting = returnFailedResultAfterAccounting {
    if (model.trim().isEmpty) {
      throw ArgumentError.value(model, 'model', 'must not be empty');
    }
    AgentEvaluationHashes.requireDigest(modelRouteHash, 'modelRouteHash');
    if (frozenMaxCompletionTokens != null &&
        (frozenMaxCompletionTokens < AppLlmChatRequest.defaultMaxTokens ||
            frozenMaxCompletionTokens > AppLlmChatRequest.maximumMaxTokens)) {
      throw ArgumentError(
        'frozen max completion tokens cannot be represented by transport',
      );
    }
    if ((maxCallsPerAttempt == null) != (maxTokensPerAttempt == null) ||
        (maxCallsPerAttempt != null && maxCallsPerAttempt <= 0) ||
        (maxTokensPerAttempt != null && maxTokensPerAttempt <= 0)) {
      throw ArgumentError(
        'formal attempt call and token caps must be positive and paired',
      );
    }
    executionBudget?.requireRoute(modelRouteHash: modelRouteHash, model: model);
  }

  final AppLlmClient _inner;
  final String model;
  final AppLlmProvider provider;
  final String baseUrl;
  final String modelRouteHash;
  final AppLlmTimeoutConfig? _frozenTimeout;
  final String? _frozenApiKey;
  final AgentEvaluationExecutionBudgetGuard? _executionBudget;
  final int? _frozenMaxCompletionTokens;
  final int? _maxCallsPerAttempt;
  final int? _maxTokensPerAttempt;
  final bool _returnFailedResultAfterAccounting;
  _AttemptScope? _active;

  static final String releaseHash =
      'sha256:${AgentEvaluationHashes.domainHash('agent-evaluation-metered-client-release-v2', const <String, Object?>{'scope': 'complete-formal-attempt-call-sequence', 'reservation': 'charge-before-provider-dispatch', 'failure': 'retain-and-return-conservative-prompt-completion-for-formal-tracing', 'caps': 'execution-and-attempt-call-token-deadline'})}';

  static String modelRouteHashFor(String model) =>
      AgentEvaluationHashes.domainHash('eval-model-route-v1', <String, Object?>{
        'model': model.trim(),
      });

  bool get isActive => _active != null;
  bool get hasExecutionBudgetGuard => _executionBudget != null;
  String? get executionBudgetPolicyHash => _executionBudget?.policyHash;

  @override
  bool get supportsSinglePhysicalDispatch =>
      appLlmClientSupportsSinglePhysicalDispatch(_inner);

  @override
  Future<void> shutdownPhysicalDispatches() =>
      shutdownAppLlmClientPhysicalDispatches(_inner);

  void beginAttempt({required String trialSlotId, required int attemptNo}) {
    if (_active != null) {
      throw StateError('another formal provider attempt is already active');
    }
    if (trialSlotId.trim().isEmpty || attemptNo <= 0) {
      throw ArgumentError('formal attempt identity is invalid');
    }
    _active = _AttemptScope(trialSlotId: trialSlotId, attemptNo: attemptNo);
  }

  AgentEvaluationMeterSnapshot finishAttempt() {
    final scope = _active;
    if (scope == null) {
      throw StateError('no formal provider attempt is active');
    }
    _active = null;
    if (scope.incomplete ||
        scope.calls.isEmpty ||
        scope.pendingCalls != 0 ||
        scope.pendingTokens != 0) {
      throw StateError('formal provider attempt is incomplete');
    }
    return AgentEvaluationMeterSnapshot._(
      trialSlotId: scope.trialSlotId,
      attemptNo: scope.attemptNo,
      modelRouteHash: modelRouteHash,
      model: model,
      calls: scope.calls,
    );
  }

  void abortAttempt() {
    _active = null;
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    validateAppLlmSinglePhysicalDispatchCapability(
      client: _inner,
      request: request,
    );
    final scope = _active;
    if (scope == null) {
      throw StateError('provider call is outside a formal evaluation attempt');
    }
    if (request.model.trim() != model.trim() ||
        request.provider != provider ||
        canonicalAgentEvaluationBaseUrl(request.baseUrl) != baseUrl ||
        (_frozenApiKey != null && request.apiKey != _frozenApiKey) ||
        (_frozenTimeout != null &&
            !_sameTimeout(request.timeout, _frozenTimeout))) {
      scope.incomplete = true;
      throw StateError('provider request contradicts the frozen route');
    }
    AgentEvaluationBudgetReservation? reservation;
    int? reservedPromptTokens;
    int? reservedCompletionTokens;
    var failedReservationRecorded = false;
    var attemptCapDenied = false;
    var attemptReservationHeld = false;
    var attemptReservedTokens = 0;

    void recordFailedReservation({AppLlmFailureKind? failureKind}) {
      final current = reservation;
      final promptTokens = reservedPromptTokens;
      final completionTokens = reservedCompletionTokens;
      if (current == null || promptTokens == null || completionTokens == null) {
        return;
      }
      try {
        _executionBudget!.finishFailure(current);
      } on Object {
        scope.incomplete = true;
        rethrow;
      }
      reservation = null;
      scope.calls.add(
        AgentEvaluationProviderCallEvidence(
          sequenceNo: scope.calls.length + 1,
          modelRouteHash: modelRouteHash,
          model: model,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          succeeded: false,
          failureKind: failureKind,
        ),
      );
      failedReservationRecorded = true;
    }

    try {
      final promptTokensUpperBound =
          canonicalAgentEvaluationPromptTokenUpperBound(request);
      final completionTokensUpperBound = request.effectiveMaxTokens;
      final maxCalls = _maxCallsPerAttempt;
      final maxTokens = _maxTokensPerAttempt;
      if (maxCalls != null && maxTokens != null) {
        final usedTokens = scope.calls.fold<int>(
          0,
          (sum, call) => sum + call.promptTokens + call.completionTokens,
        );
        if (scope.calls.length + scope.pendingCalls >= maxCalls) {
          attemptCapDenied = true;
          throw const AgentEvaluationBudgetException(
            'attempt-call-limit-exceeded',
            'formal attempt call limit reached before provider dispatch',
          );
        }
        attemptReservedTokens =
            promptTokensUpperBound + completionTokensUpperBound;
        if (usedTokens + scope.pendingTokens + attemptReservedTokens >
            maxTokens) {
          attemptCapDenied = true;
          throw const AgentEvaluationBudgetException(
            'attempt-token-limit-exceeded',
            'formal attempt token limit reached before provider dispatch',
          );
        }
        scope.pendingCalls += 1;
        scope.pendingTokens += attemptReservedTokens;
        attemptReservationHeld = true;
      }
      final budget = _executionBudget;
      if (budget != null) {
        if (request.maxTokens <= AppLlmChatRequest.unlimitedMaxTokens) {
          scope.incomplete = true;
          throw const AgentEvaluationBudgetException(
            'unbounded-completion-reservation',
            'release provider maxTokens must be finite before dispatch',
          );
        }
        final effectiveMaxTokens = request.effectiveMaxTokens;
        if (_frozenMaxCompletionTokens case final ceiling?
            when effectiveMaxTokens > ceiling) {
          scope.incomplete = true;
          throw const AgentEvaluationBudgetException(
            'completion-normalization-exceeded',
            'transport maxTokens normalization exceeds the frozen ceiling',
          );
        }
        reservation = budget.reserve(
          modelRouteHash: modelRouteHash,
          model: model,
          maxCompletionTokens: completionTokensUpperBound,
          promptTokensUpperBound: promptTokensUpperBound,
        );
        reservedPromptTokens = promptTokensUpperBound;
        reservedCompletionTokens = completionTokensUpperBound;
      }
      final remaining = budget?.remainingDuration();
      final boundedRequest = remaining == null
          ? request
          : copyAgentEvaluationRequestWithDeadline(
              request,
              remaining: remaining,
            );
      // llm-call-site: boundary.evaluation.sut-meter
      final providerFuture = _inner.chat(boundedRequest);
      final singlePhysicalDispatch =
          request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single;
      final result = remaining == null || singlePhysicalDispatch
          ? await providerFuture
          : await providerFuture.timeout(remaining);
      final promptTokens = result.promptTokens;
      final completionTokens = result.completionTokens;
      if (!result.succeeded) {
        if (reservation != null) {
          recordFailedReservation(failureKind: result.failureKind);
        } else {
          scope.incomplete = true;
        }
        if (_returnFailedResultAfterAccounting && failedReservationRecorded) {
          return AppLlmChatResult.meteredFailure(
            failureKind:
                result.failureKind ?? AppLlmFailureKind.invalidResponse,
            meteredPromptTokens: reservedPromptTokens!,
            meteredCompletionTokens: reservedCompletionTokens!,
            statusCode: result.statusCode,
            detail: result.detail,
            dispatchResolution: result.dispatchResolution,
            dispatchFailureDisposition: result.dispatchFailureDisposition,
            providerBoundaryReceipt: result.providerBoundaryReceipt,
          );
        }
        throw StateError('release provider returned a classified failure');
      }
      if (promptTokens == null ||
          completionTokens == null ||
          (result.totalTokens != null &&
              result.totalTokens != promptTokens + completionTokens)) {
        if (reservation != null) {
          recordFailedReservation();
        } else {
          scope.incomplete = true;
        }
        throw StateError(
          'release provider omitted exact prompt/completion token usage',
        );
      }
      if (reservation != null) {
        final completedReservation = reservation!;
        reservation = null;
        _executionBudget!.reconcileSuccess(
          completedReservation,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        );
      }
      scope.calls.add(
        AgentEvaluationProviderCallEvidence(
          sequenceNo: scope.calls.length + 1,
          modelRouteHash: modelRouteHash,
          model: model,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          succeeded: result.succeeded,
        ),
      );
      return result;
    } on Object catch (error) {
      if (reservation != null) {
        recordFailedReservation(failureKind: _failureKindForThrown(error));
      }
      if (!failedReservationRecorded && !attemptCapDenied) {
        scope.incomplete = true;
      }
      if (_returnFailedResultAfterAccounting && failedReservationRecorded) {
        return AppLlmChatResult.meteredFailure(
          failureKind: _failureKindForThrown(error),
          meteredPromptTokens: reservedPromptTokens!,
          meteredCompletionTokens: reservedCompletionTokens!,
          statusCode: error is AppLlmStreamException ? error.statusCode : null,
          detail: 'provider call failed after dispatch',
        );
      }
      rethrow;
    } finally {
      if (attemptReservationHeld) {
        scope.pendingCalls -= 1;
        scope.pendingTokens -= attemptReservedTokens;
      }
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    _active?.incomplete = true;
    throw UnsupportedError(
      'streaming is disabled in release evaluation because exact metering '
      'must be recorded atomically',
    );
  }
}

AppLlmFailureKind _failureKindForThrown(Object error) => switch (error) {
  TimeoutException() => AppLlmFailureKind.timeout,
  AppLlmStreamException(:final failureKind) => failureKind,
  _ => AppLlmFailureKind.network,
};

/// Canonical, tokenizer-independent and deliberately conservative. A token
/// cannot contain less than one UTF-8 byte; JSON framing and provider message
/// envelopes are reserved separately so the provider is never crossed with a
/// prompt whose upper bound exceeds the frozen route ceiling.
int canonicalAgentEvaluationPromptTokenUpperBound(AppLlmChatRequest request) {
  final canonicalMessages = <Object?>[
    for (final message in request.messages)
      <String, Object?>{'role': message.role, 'content': message.content},
  ];
  final encodedBytes = utf8.encode(jsonEncode(canonicalMessages)).length;
  return encodedBytes + 4096 + (request.messages.length * 512);
}

AppLlmChatRequest copyAgentEvaluationRequestWithDeadline(
  AppLlmChatRequest request, {
  required Duration remaining,
}) {
  final remainingMs = math.max(1, remaining.inMilliseconds);
  int bounded(int value) => math.max(1, math.min(value, remainingMs));
  final current = request.timeout;
  return AppLlmChatRequest(
    baseUrl: request.baseUrl,
    apiKey: request.apiKey,
    model: request.model,
    timeout: AppLlmTimeoutConfig(
      connectTimeoutMs: bounded(current.connectTimeoutMs),
      sendTimeoutMs: bounded(current.sendTimeoutMs),
      receiveTimeoutMs: bounded(current.receiveTimeoutMs),
      idleTimeoutMs: bounded(current.effectiveIdleTimeoutMs),
    ),
    maxTokens: request.effectiveMaxTokens,
    messages: request.messages,
    provider: request.provider,
    onPartialText: request.onPartialText,
    formalCacheIdentity: request.formalCacheIdentity,
    formalDispatchIdentity: request.formalDispatchIdentity,
    preferStreaming: request.preferStreaming,
    physicalDispatchPolicy: request.physicalDispatchPolicy,
    dispatchEvidenceNonce: request.dispatchEvidenceNonce,
  );
}

bool _sameTimeout(AppLlmTimeoutConfig left, AppLlmTimeoutConfig? right) =>
    right != null &&
    left.connectTimeoutMs == right.connectTimeoutMs &&
    left.sendTimeoutMs == right.sendTimeoutMs &&
    left.receiveTimeoutMs == right.receiveTimeoutMs &&
    left.idleTimeoutMs == right.idleTimeoutMs;

final class _AttemptScope {
  _AttemptScope({required this.trialSlotId, required this.attemptNo});

  final String trialSlotId;
  final int attemptNo;
  final List<AgentEvaluationProviderCallEvidence> calls =
      <AgentEvaluationProviderCallEvidence>[];
  int pendingCalls = 0;
  int pendingTokens = 0;
  bool incomplete = false;
}

String canonicalAgentEvaluationBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ArgumentError.value(
      value,
      'baseUrl',
      'must be an absolute HTTP URL without credentials, query, or fragment',
    );
  }
  var path = uri.path;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return uri
      .replace(
        scheme: uri.scheme.toLowerCase(),
        host: uri.host.toLowerCase(),
        path: path,
      )
      .toString();
}
