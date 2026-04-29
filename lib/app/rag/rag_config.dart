/// Configuration for the OpenViking RAG integration.
class RagConfig {
  const RagConfig({
    this.serverUrl = 'http://localhost:1933',
    this.defaultLimit = 10,
    this.scoreThreshold = 0.5,
    this.tokenBudget = 800,
    this.connectTimeoutMs = 5000,
    this.receiveTimeoutMs = 15000,
  });

  final String serverUrl;
  final int defaultLimit;
  final double scoreThreshold;
  final int tokenBudget;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;

  RagConfig copyWith({
    String? serverUrl,
    int? defaultLimit,
    double? scoreThreshold,
    int? tokenBudget,
    int? connectTimeoutMs,
    int? receiveTimeoutMs,
  }) {
    return RagConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      defaultLimit: defaultLimit ?? this.defaultLimit,
      scoreThreshold: scoreThreshold ?? this.scoreThreshold,
      tokenBudget: tokenBudget ?? this.tokenBudget,
      connectTimeoutMs: connectTimeoutMs ?? this.connectTimeoutMs,
      receiveTimeoutMs: receiveTimeoutMs ?? this.receiveTimeoutMs,
    );
  }
}
