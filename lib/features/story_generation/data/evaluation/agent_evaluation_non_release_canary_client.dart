import 'dart:async';
import 'dart:math' as math;

import '../../../../app/llm/app_llm_client_contract.dart';
import '../../../../app/llm/app_llm_client_types.dart';
import 'agent_evaluation_execution_budget.dart';
import 'agent_evaluation_metered_client.dart';

/// One secret-free provider-call record from a non-release production canary.
final class AgentEvaluationNonReleaseCanaryCall {
  const AgentEvaluationNonReleaseCanaryCall({
    required this.sequenceNo,
    required this.requestedModel,
    required this.providerModel,
    required this.promptTokens,
    required this.completionTokens,
    required this.latencyMs,
    required this.succeeded,
    required this.accounting,
    this.failureCode,
  });

  final int sequenceNo;
  final String requestedModel;
  final String? providerModel;
  final int promptTokens;
  final int completionTokens;
  final int latencyMs;
  final bool succeeded;

  /// `exact` for verified provider usage, `reserved-upper-bound` otherwise.
  final String accounting;
  final String? failureCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'sequenceNo': sequenceNo,
    'requestedModel': requestedModel,
    if (providerModel != null) 'providerModel': providerModel,
    'promptTokens': promptTokens,
    'completionTokens': completionTokens,
    'totalTokens': promptTokens + completionTokens,
    'latencyMs': latencyMs,
    'succeeded': succeeded,
    'accounting': accounting,
    if (failureCode != null) 'failureCode': failureCode,
  };
}

final class AgentEvaluationNonReleaseCanaryException implements Exception {
  const AgentEvaluationNonReleaseCanaryException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() =>
      'AgentEvaluationNonReleaseCanaryException($code, $message)';
}

/// Fail-closed, single-dispatch client for explicitly authorized canaries.
///
/// This is intentionally not a release authority. It freezes one route,
/// disables transport streaming/fallback so one logical call is exactly one
/// HTTP dispatch, reserves a conservative token upper bound before dispatch,
/// and requires the provider response to echo both exact usage and the exact
/// requested model. Any indeterminate result permanently stops the client.
final class AgentEvaluationNonReleaseCanaryClient implements AppLlmClient {
  AgentEvaluationNonReleaseCanaryClient({
    required AppLlmClient inner,
    required AgentEvaluationExecutionBudgetGuard budget,
    required this.expectedModel,
    required this.expectedProvider,
    required String expectedBaseUrl,
    required String frozenApiKey,
    required String modelRouteHash,
    this.enforceZeroCost = true,
  }) : _inner = inner,
       _budget = budget,
       _expectedBaseUrl = canonicalAgentEvaluationBaseUrl(expectedBaseUrl),
       _frozenApiKey = frozenApiKey,
       _modelRouteHash = modelRouteHash {
    final route = budget.requireRoute(
      modelRouteHash: modelRouteHash,
      model: expectedModel,
    );
    if (!enforceZeroCost &&
        budget.policy.costEnforcement !=
            AgentEvaluationCostEnforcement.disabled) {
      throw const AgentEvaluationNonReleaseCanaryException(
        'cost-mode-mismatch',
        'cost-unbounded canary requires explicit disabled cost enforcement',
      );
    }
    if (enforceZeroCost &&
        (budget.policy.costEnforcement !=
                AgentEvaluationCostEnforcement.metered ||
            budget.policy.maxCostMicrousd != 0 ||
            route.promptMicrousdPerMillionTokens != 0 ||
            route.completionMicrousdPerMillionTokens != 0)) {
      throw const AgentEvaluationNonReleaseCanaryException(
        'nonzero-price-policy',
        'non-release zero-price canary requires a frozen zero-cost route',
      );
    }
  }

  final AppLlmClient _inner;
  final AgentEvaluationExecutionBudgetGuard _budget;
  final String expectedModel;
  final AppLlmProvider expectedProvider;
  final String _expectedBaseUrl;
  final String _frozenApiKey;
  final String _modelRouteHash;

  /// Whether the frozen route must prove a zero-price policy.
  ///
  /// Set to false only for an explicitly cost-unbounded canary. In that mode
  /// this client still enforces the call, token, duration, route, and exact
  /// provider-model gates, but its cost fields are intentionally not evidence
  /// of provider billing.
  final bool enforceZeroCost;
  final List<AgentEvaluationNonReleaseCanaryCall> _calls =
      <AgentEvaluationNonReleaseCanaryCall>[];
  int _nextSequence = 0;
  String? _terminalFailureCode;

  List<AgentEvaluationNonReleaseCanaryCall> get calls {
    final copy = _calls.toList(growable: false)
      ..sort((left, right) => left.sequenceNo.compareTo(right.sequenceNo));
    return List<AgentEvaluationNonReleaseCanaryCall>.unmodifiable(copy);
  }

  AgentEvaluationExecutionBudgetSnapshot get budgetSnapshot =>
      _budget.snapshot();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final terminal = _terminalFailureCode;
    if (terminal != null) {
      throw AgentEvaluationNonReleaseCanaryException(
        'canary-already-aborted',
        'canary was permanently stopped by $terminal',
      );
    }
    if (request.model.trim() != expectedModel.trim() ||
        request.provider != expectedProvider ||
        canonicalAgentEvaluationBaseUrl(request.baseUrl) != _expectedBaseUrl ||
        request.apiKey != _frozenApiKey) {
      _abort('frozen-route-mismatch');
      throw const AgentEvaluationNonReleaseCanaryException(
        'frozen-route-mismatch',
        'provider request contradicts the authorized canary route',
      );
    }
    final promptUpperBound = canonicalAgentEvaluationPromptTokenUpperBound(
      request,
    );
    // Some production generation stages omit maxTokens and rely on the
    // provider default. The canary must make that implicit default finite
    // before reserving or dispatching, otherwise the hard token gate cannot
    // prove the request is bounded.
    final completionUpperBound =
        request.maxTokens <= AppLlmChatRequest.unlimitedMaxTokens
        ? AppLlmChatRequest.defaultMaxTokens
        : request.effectiveMaxTokens;
    final reservation = _budget.reserve(
      modelRouteHash: _modelRouteHash,
      model: expectedModel,
      maxCompletionTokens: completionUpperBound,
      promptTokensUpperBound: promptUpperBound,
    );
    final sequenceNo = ++_nextSequence;
    final stopwatch = Stopwatch()..start();
    var reservationOpen = true;

    void recordFailure(String code, {String? providerModel}) {
      _calls.add(
        AgentEvaluationNonReleaseCanaryCall(
          sequenceNo: sequenceNo,
          requestedModel: expectedModel,
          providerModel: providerModel,
          promptTokens: promptUpperBound,
          completionTokens: completionUpperBound,
          latencyMs: stopwatch.elapsedMilliseconds,
          succeeded: false,
          accounting: 'reserved-upper-bound',
          failureCode: code,
        ),
      );
    }

    try {
      final remaining = _budget.remainingDuration();
      final boundedRequest = _copyForSingleDispatch(
        request,
        remaining: remaining,
        maxTokens: completionUpperBound,
      );
      // llm-call-site: boundary.evaluation.non-release-canary-single-dispatch
      final result = await _inner.chat(boundedRequest).timeout(remaining);
      final providerModel = result.providerModel?.trim();
      if (!result.succeeded) {
        _budget.finishFailure(reservation);
        reservationOpen = false;
        final code = 'provider-${result.failureKind?.name ?? 'failure'}';
        recordFailure(code, providerModel: providerModel);
        _abort(code);
        throw AgentEvaluationNonReleaseCanaryException(
          code,
          'provider returned a classified failure',
        );
      }
      if (providerModel == null || providerModel.isEmpty) {
        _budget.finishFailure(reservation);
        reservationOpen = false;
        recordFailure('provider-model-missing');
        _abort('provider-model-missing');
        throw const AgentEvaluationNonReleaseCanaryException(
          'provider-model-missing',
          'provider response omitted exact model identity',
        );
      }
      if (providerModel != expectedModel.trim()) {
        _budget.finishFailure(reservation);
        reservationOpen = false;
        recordFailure('provider-model-mismatch', providerModel: providerModel);
        _abort('provider-model-mismatch');
        throw const AgentEvaluationNonReleaseCanaryException(
          'provider-model-mismatch',
          'provider response model differs from the authorized model',
        );
      }
      final promptTokens = result.promptTokens;
      final completionTokens = result.completionTokens;
      if (promptTokens == null ||
          completionTokens == null ||
          promptTokens < 0 ||
          completionTokens < 0 ||
          (result.totalTokens != null &&
              result.totalTokens != promptTokens + completionTokens)) {
        _budget.finishFailure(reservation);
        reservationOpen = false;
        recordFailure(
          'provider-usage-indeterminate',
          providerModel: providerModel,
        );
        _abort('provider-usage-indeterminate');
        throw const AgentEvaluationNonReleaseCanaryException(
          'provider-usage-indeterminate',
          'provider response omitted exact prompt/completion usage',
        );
      }
      reservationOpen = false;
      _budget.reconcileSuccess(
        reservation,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );
      _calls.add(
        AgentEvaluationNonReleaseCanaryCall(
          sequenceNo: sequenceNo,
          requestedModel: expectedModel,
          providerModel: providerModel,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          latencyMs: stopwatch.elapsedMilliseconds,
          succeeded: true,
          accounting: 'exact',
        ),
      );
      return result;
    } on AgentEvaluationNonReleaseCanaryException {
      rethrow;
    } on Object catch (error) {
      if (reservationOpen) {
        _budget.finishFailure(reservation);
        reservationOpen = false;
        final code = error is TimeoutException
            ? 'provider-deadline-exhausted'
            : 'provider-operation-threw';
        recordFailure(code);
        _abort(code);
        throw AgentEvaluationNonReleaseCanaryException(
          code,
          'provider operation failed after dispatch',
        );
      }
      _abort('budget-reconciliation-failed');
      throw const AgentEvaluationNonReleaseCanaryException(
        'budget-reconciliation-failed',
        'provider usage could not be reconciled within the hard budget',
      );
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw const AgentEvaluationNonReleaseCanaryException(
      'streaming-disabled',
      'non-release canary requires one atomic metered response',
    );
  }

  void _abort(String code) {
    _terminalFailureCode ??= code;
  }
}

AppLlmChatRequest _copyForSingleDispatch(
  AppLlmChatRequest request, {
  required Duration remaining,
  required int maxTokens,
}) {
  final remainingMs = math.max(1, remaining.inMilliseconds);
  int bounded(int value) => math.max(1, math.min(value, remainingMs));
  final timeout = request.timeout;
  return AppLlmChatRequest(
    baseUrl: request.baseUrl,
    apiKey: request.apiKey,
    model: request.model,
    timeout: AppLlmTimeoutConfig(
      connectTimeoutMs: bounded(timeout.connectTimeoutMs),
      sendTimeoutMs: bounded(timeout.sendTimeoutMs),
      receiveTimeoutMs: bounded(timeout.receiveTimeoutMs),
      idleTimeoutMs: bounded(timeout.effectiveIdleTimeoutMs),
    ),
    maxTokens: maxTokens,
    messages: request.messages,
    provider: request.provider,
    onPartialText: request.onPartialText,
    formalCacheIdentity: request.formalCacheIdentity,
    preferStreaming: false,
  );
}
