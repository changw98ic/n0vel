class TokenUsage {
  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.modelName,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String? modelName;

  factory TokenUsage.fromJson(Map<String, Object?> json) {
    return TokenUsage(
      promptTokens: (json['prompt_tokens'] as int?) ?? 0,
      completionTokens: (json['completion_tokens'] as int?) ?? 0,
      totalTokens: (json['total_tokens'] as int?) ?? 0,
      modelName: json['model']?.toString(),
    );
  }

  TokenUsage operator +(TokenUsage other) {
    return TokenUsage(
      promptTokens: promptTokens + other.promptTokens,
      completionTokens: completionTokens + other.completionTokens,
      totalTokens: totalTokens + other.totalTokens,
    );
  }

  @override
  String toString() =>
      'TokenUsage(prompt=$promptTokens, completion=$completionTokens, total=$totalTokens)';
}
