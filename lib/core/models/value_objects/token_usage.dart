import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_usage.freezed.dart';

/// Token 使用量值对象
@freezed
class TokenUsage with _$TokenUsage {
  const TokenUsage._();

  const factory TokenUsage({
    required int inputTokens,
    required int outputTokens,
    required String modelId,
    required DateTime timestamp,
  }) = _TokenUsage;

  /// 总 Token 数
  int get total => inputTokens + outputTokens;

  /// 估算费用（美元）
  double estimateCost({
    required double inputPricePerK,
    required double outputPricePerK,
  }) {
    final inputCost = (inputTokens / 1000) * inputPricePerK;
    final outputCost = (outputTokens / 1000) * outputPricePerK;
    return inputCost + outputCost;
  }
}

/// Token 使用统计
@freezed
class TokenUsageStats with _$TokenUsageStats {
  const factory TokenUsageStats({
    required int totalInputTokens,
    required int totalOutputTokens,
    required int requestCount,
    required double estimatedCost,
    required Map<String, int> byFunction,
    required Map<String, int> byModel,
  }) = _TokenUsageStats;
}
