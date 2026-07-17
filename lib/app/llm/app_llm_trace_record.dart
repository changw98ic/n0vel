import 'app_llm_prompt_version.dart';

/// 一次 LLM 调用的完整追踪记录。
///
/// 包含 prompt 版本、schema 校验结果、provider 信息等，
/// 支持按版本查询回放。记录是只追加的（append-only），不可修改。
class LlmTraceRecord {
  const LlmTraceRecord({
    required this.id,
    required this.timestamp,
    this.promptVersion,
    required this.providerId,
    required this.model,
    this.schemaType,
    this.schemaValid,
    this.schemaViolations,
    required this.succeeded,
    this.latencyMs,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  /// 唯一标识。
  final String id;

  /// 调用时间戳。
  final DateTime timestamp;

  /// Prompt 模板版本（如果已知）。
  final PromptVersion? promptVersion;

  /// Provider 标识（如 provider profile id）。
  final String providerId;

  /// 使用的模型名称。
  final String model;

  /// Schema 类型标识（如 'prose', 'review', 'director', 'generic'）。
  final String? schemaType;

  /// Schema 校验是否通过。
  final bool? schemaValid;

  /// Schema 校验违规列表。
  final List<String>? schemaViolations;

  /// 调用是否成功。
  final bool succeeded;

  /// 延迟毫秒数。
  final int? latencyMs;

  /// Prompt token 数量。
  final int? promptTokens;

  /// Completion token 数量。
  final int? completionTokens;

  /// 总 token 数量。
  final int? totalTokens;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      if (promptVersion != null) 'promptVersion': promptVersion!.toJson(),
      'providerId': providerId,
      'model': model,
      if (schemaType != null) 'schemaType': schemaType,
      if (schemaValid != null) 'schemaValid': schemaValid,
      if (schemaViolations != null && schemaViolations!.isNotEmpty)
        'schemaViolations': schemaViolations,
      'succeeded': succeeded,
      if (latencyMs != null) 'latencyMs': latencyMs,
      if (promptTokens != null) 'promptTokens': promptTokens,
      if (completionTokens != null) 'completionTokens': completionTokens,
      if (totalTokens != null) 'totalTokens': totalTokens,
    };
  }

  factory LlmTraceRecord.fromJson(Map<String, Object?> json) {
    final pvJson = json['promptVersion'] as Map<String, Object?>?;
    return LlmTraceRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      promptVersion: pvJson != null ? PromptVersion.fromJson(pvJson) : null,
      providerId: json['providerId'] as String,
      model: json['model'] as String,
      schemaType: json['schemaType'] as String?,
      schemaValid: json['schemaValid'] as bool?,
      schemaViolations: (json['schemaViolations'] as List<Object?>?)
          ?.cast<String>(),
      succeeded: json['succeeded'] as bool,
      latencyMs: json['latencyMs'] as int?,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      totalTokens: json['totalTokens'] as int?,
    );
  }
}
