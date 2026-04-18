part of 'ai_service.dart';

class AIServicePromptBundle {
  final String systemPrompt;
  final String userPrompt;

  const AIServicePromptBundle({
    required this.systemPrompt,
    required this.userPrompt,
  });
}

List<AIProvider> buildDefaultAIProviders() => [
  OpenAIProvider(),
  AnthropicProvider(),
  OllamaProvider(),
  AzureOpenAIProvider(),
  CustomProvider(),
];

Map<String, dynamic> buildAIServiceCacheParams(AIRequestConfig config) => {
  'temperature': config.temperature,
  'maxTokens': config.maxTokens,
};

AIServicePromptBundle buildAIServicePromptBundle({
  required AIPromptBuilder promptBuilder,
  required String prompt,
  required AIRequestConfig config,
  required bool respondInChinese,
}) {
  return AIServicePromptBundle(
    systemPrompt: promptBuilder.buildSystemPrompt(
      function: config.function,
      overridePrompt: config.systemPrompt,
      respondInChinese: respondInChinese,
    ),
    userPrompt: promptBuilder.buildUserPrompt(
      prompt,
      variables: config.variables,
    ),
  );
}

bool shouldAIServiceRespondInChinese(getx.Locale? locale) =>
    locale?.languageCode.startsWith('zh') ?? true;

AIResponse buildCachedAIResponse({
  required String cachedResponse,
  required int? inputTokens,
  required int? outputTokens,
  required String modelId,
  required Duration responseTime,
}) {
  return AIResponse(
    content: cachedResponse,
    inputTokens: inputTokens ?? 0,
    outputTokens: outputTokens ?? 0,
    modelId: modelId,
    responseTime: responseTime,
    fromCache: true,
  );
}

int buildAIRetryDelayMs({
  required int attempt,
  required Random random,
}) {
  return (1000 * (1 << attempt)) + random.nextInt(1000);
}

feature_config.ModelTier toAIServiceFeatureTier(ModelTier tier) {
  return switch (tier) {
    ModelTier.thinking => feature_config.ModelTier.thinking,
    ModelTier.middle => feature_config.ModelTier.middle,
    ModelTier.fast => feature_config.ModelTier.fast,
  };
}
