import 'app_llm_client_types.dart';

abstract interface class AppLlmCallTraceSink {
  Future<void> record(AppLlmCallTraceEntry entry);
}

class AppLlmCallTraceEntry {
  const AppLlmCallTraceEntry({
    required this.timestampMs,
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
  });

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

  factory AppLlmCallTraceEntry.fromRequestResult({
    required AppLlmChatRequest request,
    required AppLlmChatResult result,
    required String traceName,
    Map<String, Object?> metadata = const {},
  }) {
    final host = _hostFromBaseUrl(request.baseUrl);
    final promptChars = _promptChars(request.messages);
    final completionChars = result.text?.length ?? 0;
    return AppLlmCallTraceEntry(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
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
      metadata: Map<String, Object?>.unmodifiable(metadata),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestampMs': timestampMs,
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
