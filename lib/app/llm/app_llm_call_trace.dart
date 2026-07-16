import 'app_llm_client_types.dart';
import 'app_llm_prompt_invocation.dart';
import 'app_llm_prompt_release.dart';
import 'app_llm_prompt_version.dart';

abstract interface class AppLlmCallTraceSink {
  Future<void> record(AppLlmCallTraceEntry entry);
}

/// Marker for audit paths where losing a trace must fail the operation.
/// Ordinary application telemetry remains best-effort.
abstract interface class AppLlmRequiredCallTraceSink
    implements AppLlmCallTraceSink {}

class AppLlmCallTraceEntry {
  const AppLlmCallTraceEntry({
    required this.timestampMs,
    this.startedAtMs,
    this.completedAtMs,
    required this.traceName,
    required this.model,
    required this.host,
    required this.messageCount,
    required this.maxTokens,
    required this.succeeded,
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.estimatedPromptTokens,
    required this.estimatedCompletionTokens,
    required this.promptChars,
    required this.completionChars,
    required this.metadata,
    this.failureKind,
    this.statusCode,
    this.errorDetail,
    this.promptReleaseRef,
    this.promptVersion,
    this.stageId,
    this.callSiteId,
    this.variantId,
    this.generationBundleHash,
    this.renderedMessagesDigest,
    this.resolvedVariablesDigest,
    this.rendererContractHash,
    this.schemaType,
    this.schemaValid,
    this.schemaViolations,
  });

  /// Exact dispatch interval captured after a request-pool slot is acquired.
  ///
  /// Legacy entries omit both values and remain reconstructable from
  /// [timestampMs] and [latencyMs].
  final int? startedAtMs;
  final int? completedAtMs;
  final int timestampMs;
  final String traceName;
  final String model;
  final String host;
  final int messageCount;
  final int maxTokens;
  final bool succeeded;
  final int? latencyMs;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int estimatedPromptTokens;
  final int estimatedCompletionTokens;
  final int promptChars;
  final int completionChars;
  final String? failureKind;
  final int? statusCode;
  final String? errorDetail;
  final Map<String, Object?> metadata;

  /// Immutable prompt snapshot identity used by formal generation calls.
  final PromptReleaseRef? promptReleaseRef;

  /// Prompt 模板版本（如果调用方提供）。
  final PromptVersion? promptVersion;

  final String? stageId;
  final String? callSiteId;
  final String? variantId;
  final String? generationBundleHash;
  final String? renderedMessagesDigest;
  final String? resolvedVariablesDigest;
  final String? rendererContractHash;

  /// Schema 类型标识（如 'prose', 'review', 'director', 'generic'）。
  final String? schemaType;

  /// Schema 校验是否通过（null 表示未执行校验）。
  final bool? schemaValid;

  /// Schema 校验违规描述列表。
  final List<String>? schemaViolations;

  factory AppLlmCallTraceEntry.fromRequestResult({
    required AppLlmChatRequest request,
    required AppLlmChatResult result,
    required String traceName,
    Map<String, Object?> metadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    PromptInvocationEvidence? promptInvocationEvidence,
    String? schemaType,
    bool? schemaValid,
    List<String>? schemaViolations,
    int? startedAtMs,
    int? completedAtMs,
  }) {
    final resolvedStartedAtMs = startedAtMs;
    final resolvedCompletedAtMs = completedAtMs;
    final hasStartedAt = resolvedStartedAtMs != null;
    final hasCompletedAt = resolvedCompletedAtMs != null;
    if (hasStartedAt != hasCompletedAt) {
      throw ArgumentError(
        'startedAtMs and completedAtMs must be supplied together',
      );
    }
    if (resolvedStartedAtMs != null) {
      final exactCompletedAtMs = resolvedCompletedAtMs!;
      if (resolvedStartedAtMs < 0 ||
          exactCompletedAtMs <= resolvedStartedAtMs) {
        throw ArgumentError.value(
          <int>[resolvedStartedAtMs, exactCompletedAtMs],
          'dispatchInterval',
          'must be a non-negative, non-empty interval',
        );
      }
    }
    final host = _hostFromBaseUrl(request.baseUrl);
    final promptChars = _promptChars(request.messages);
    final completionChars = result.text?.length ?? 0;
    if (promptInvocationEvidence != null &&
        !promptInvocationEvidence.matchesMessages(request.messages)) {
      throw StateError(
        'PromptInvocationEvidence does not match request messages',
      );
    }
    if (promptReleaseRef != null &&
        promptInvocationEvidence != null &&
        promptReleaseRef != promptInvocationEvidence.promptReleaseRef) {
      throw StateError(
        'PromptInvocationEvidence and PromptReleaseRef disagree',
      );
    }
    final resolvedPromptReleaseRef =
        promptInvocationEvidence?.promptReleaseRef ?? promptReleaseRef;
    if (resolvedPromptReleaseRef != null &&
        promptVersion != null &&
        (resolvedPromptReleaseRef.templateId != promptVersion.templateId ||
            resolvedPromptReleaseRef.semanticVersion !=
                promptVersion.version)) {
      throw StateError('PromptReleaseRef and legacy PromptVersion disagree');
    }
    final resolvedPromptVersion =
        promptVersion ??
        (resolvedPromptReleaseRef == null
            ? null
            : PromptVersion(
                templateId: resolvedPromptReleaseRef.templateId,
                version: resolvedPromptReleaseRef.semanticVersion,
                description: 'Derived from immutable PromptReleaseRef',
              ));
    final renderedMessagesDigest =
        promptInvocationEvidence?.renderedMessagesDigest;
    final resolvedVariablesDigest =
        promptInvocationEvidence?.resolvedVariablesDigest;
    final rendererContractHash = promptInvocationEvidence?.rendererContractHash;
    final protectedMetadata = <String, Object?>{
      ...metadata,
      if (resolvedPromptReleaseRef != null)
        'promptReleaseRef': resolvedPromptReleaseRef.toJson(),
      'stageId': ?stageId,
      'callSiteId': ?callSiteId,
      'variantId': ?variantId,
      'generationBundleHash': ?generationBundleHash,
      'renderedMessagesDigest': ?renderedMessagesDigest,
      'resolvedVariablesDigest': ?resolvedVariablesDigest,
      'rendererContractHash': ?rendererContractHash,
    };
    return AppLlmCallTraceEntry(
      timestampMs:
          resolvedCompletedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      startedAtMs: resolvedStartedAtMs,
      completedAtMs: resolvedCompletedAtMs,
      traceName: traceName,
      model: request.model,
      host: host,
      messageCount: request.messages.length,
      maxTokens: request.effectiveMaxTokens,
      succeeded: result.succeeded,
      latencyMs: result.latencyMs,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      totalTokens: result.totalTokens,
      estimatedPromptTokens: _estimateTokensFromChars(promptChars),
      estimatedCompletionTokens: _estimateTokensFromChars(completionChars),
      promptChars: promptChars,
      completionChars: completionChars,
      failureKind: result.failureKind?.name,
      statusCode: result.statusCode,
      errorDetail: result.detail,
      metadata: Map<String, Object?>.unmodifiable(protectedMetadata),
      promptReleaseRef: resolvedPromptReleaseRef,
      promptVersion: resolvedPromptVersion,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      generationBundleHash: generationBundleHash,
      renderedMessagesDigest: renderedMessagesDigest,
      resolvedVariablesDigest: resolvedVariablesDigest,
      rendererContractHash: rendererContractHash,
      schemaType: schemaType,
      schemaValid: schemaValid,
      schemaViolations: schemaViolations != null
          ? List<String>.unmodifiable(schemaViolations)
          : null,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampMs': timestampMs,
      if (startedAtMs != null) 'startedAtMs': startedAtMs,
      if (completedAtMs != null) 'completedAtMs': completedAtMs,
      'traceName': traceName,
      'model': model,
      'host': host,
      'messageCount': messageCount,
      'maxTokens': maxTokens,
      'succeeded': succeeded,
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (promptTokens != null) 'promptTokens': promptTokens,
      if (completionTokens != null) 'completionTokens': completionTokens,
      if (totalTokens != null) 'totalTokens': totalTokens,
      'estimatedPromptTokens': estimatedPromptTokens,
      'estimatedCompletionTokens': estimatedCompletionTokens,
      'promptChars': promptChars,
      'completionChars': completionChars,
      if (failureKind != null) 'failureKind': failureKind,
      if (statusCode != null) 'statusCode': statusCode,
      if (errorDetail != null) 'errorDetail': errorDetail,
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (promptReleaseRef != null)
        'promptReleaseRef': promptReleaseRef!.toJson(),
      if (promptVersion != null) 'promptVersion': promptVersion!.toJson(),
      if (stageId != null) 'stageId': stageId,
      if (callSiteId != null) 'callSiteId': callSiteId,
      if (variantId != null) 'variantId': variantId,
      if (generationBundleHash != null)
        'generationBundleHash': generationBundleHash,
      if (renderedMessagesDigest != null)
        'renderedMessagesDigest': renderedMessagesDigest,
      if (resolvedVariablesDigest != null)
        'resolvedVariablesDigest': resolvedVariablesDigest,
      if (rendererContractHash != null)
        'rendererContractHash': rendererContractHash,
      if (schemaType != null) 'schemaType': schemaType,
      if (schemaValid != null) 'schemaValid': schemaValid,
      if (schemaViolations != null && schemaViolations!.isNotEmpty)
        'schemaViolations': schemaViolations,
    };
  }
}

String _hostFromBaseUrl(String baseUrl) {
  final parsed = Uri.tryParse(baseUrl.trim());
  if (parsed != null && parsed.host.isNotEmpty) {
    return parsed.host;
  }
  return baseUrl;
}

int _promptChars(List<AppLlmChatMessage> messages) {
  var count = 0;
  for (final message in messages) {
    count += message.role.length + message.content.length;
  }
  return count;
}

int _estimateTokensFromChars(int chars) {
  if (chars <= 0) return 0;
  return (chars / 4).ceil();
}
