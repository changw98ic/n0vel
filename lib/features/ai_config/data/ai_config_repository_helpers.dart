import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/services/ai/models/model_config.dart' as core_model;
import '../../../core/services/ai/models/model_tier.dart' as core_tier;
import '../../../core/services/ai/models/provider_config.dart' as core_provider;
import '../../../core/services/ai/providers/ai_provider.dart';
import '../../../core/services/ai/providers/anthropic_provider.dart';
import '../../../core/services/ai/providers/azure_openai_provider.dart';
import '../../../core/services/ai/providers/custom_provider.dart';
import '../../../core/services/ai/providers/ollama_provider.dart';
import '../../../core/services/ai/providers/openai_provider.dart';
import '../domain/model_config.dart';

class AIConfigRepositoryAccum {
  int count = 0;
  int tokens = 0;

  void add(int value) {
    count++;
    tokens += value;
  }
}

String buildAIConfigRepositoryModelKey(String keyPrefix, ModelTier tier) =>
    '${keyPrefix}model_${tier.name}';

String buildAIConfigRepositoryPromptKey(String keyPrefix, String templateId) =>
    '${keyPrefix}prompt_$templateId';

int defaultMaxTokensForAIConfigTier(ModelTier tier) {
  return switch (tier) {
    ModelTier.fast => 4096,
    ModelTier.middle => 8192,
    ModelTier.thinking => 16384,
  };
}

ModelConfig buildDefaultAIConfigModel({
  required ModelTier tier,
  required String providerType,
  required String modelName,
  required String? apiEndpoint,
  required double temperature,
  required int maxOutputTokens,
  required double topP,
  required double frequencyPenalty,
  required double presencePenalty,
  required bool isEnabled,
  required DateTime? lastValidatedAt,
  required bool isValid,
}) {
  return ModelConfig(
    tier: tier,
    providerType: providerType,
    modelName: modelName,
    apiEndpoint: apiEndpoint,
    temperature: temperature,
    maxOutputTokens: maxOutputTokens,
    topP: topP,
    frequencyPenalty: frequencyPenalty,
    presencePenalty: presencePenalty,
    isEnabled: isEnabled,
    lastValidatedAt: lastValidatedAt,
    isValid: isValid,
  );
}

String? resolveAIConfigRepositoryApiKey(
  String? stored, {
  required String? fallback,
}) {
  if (stored != null && stored.isNotEmpty) {
    return stored;
  }
  return fallback;
}

AIProvider buildAIConfigRepositoryProvider(
  core_model.AIProviderType type,
  Dio dio,
) {
  return switch (type) {
    core_model.AIProviderType.openai => OpenAIProvider(dio: dio),
    core_model.AIProviderType.anthropic => AnthropicProvider(dio: dio),
    core_model.AIProviderType.azure => AzureOpenAIProvider(dio: dio),
    core_model.AIProviderType.ollama => OllamaProvider(dio: dio),
    _ => CustomProvider(dio: dio),
  };
}

core_model.ModelConfig buildAIConfigRepositoryCoreModelConfig({
  required ModelTier tier,
  required ModelConfig config,
  required core_tier.ModelTier coreTier,
}) {
  return core_model.ModelConfig(
    id: '${tier.name}_${config.providerType}_${config.modelName}',
    tier: coreTier,
    displayName: '${config.providerType}:${config.modelName}',
    providerType: config.providerType,
    modelName: config.modelName,
    apiEndpoint: config.apiEndpoint,
    temperature: config.temperature,
    maxOutputTokens: config.maxOutputTokens,
    topP: config.topP,
    frequencyPenalty: config.frequencyPenalty,
    presencePenalty: config.presencePenalty,
    isEnabled: config.isEnabled,
    lastValidatedAt: config.lastValidatedAt,
    isValid: config.isValid,
  );
}

FunctionMapping buildAIConfigRepositoryFunctionMapping({
  required AIFunction function,
  required String? overrideTierName,
}) {
  return FunctionMapping(
    functionKey: function.key,
    overrideTierName: overrideTierName,
    useOverride: overrideTierName != null,
  );
}

ModelTier? resolveAIConfigRepositoryTierName(String? tierName) {
  if (tierName == null) return null;
  for (final tier in ModelTier.values) {
    if (tier.name == tierName) return tier;
  }
  return null;
}

List<PromptTemplate> buildDefaultAIConfigPromptTemplates(DateTime now) {
  return [
    PromptTemplate(
      id: 'continuation',
      name: '续写模板',
      description: '用于 AI 续写内容',
      systemPrompt:
          '你是一位专业的小说作家助手。请根据给定的上下文，自然地续写故事内容。保持文风一致，注意情节连贯性。',
      iconName: 'edit_note',
      createdAt: now,
    ),
    PromptTemplate(
      id: 'dialogue',
      name: '对话生成模板',
      description: '基于角色档案生成对话',
      systemPrompt: '你是一位专业的小说对话作家。请根据角色性格和情境，生成符合角色特点的对话。',
      iconName: 'chat',
      createdAt: now,
    ),
    PromptTemplate(
      id: 'review',
      name: '章节审查模板',
      description: '多维度审查章节质量',
      systemPrompt:
          '你是一位专业的小说编辑。请从设定一致性、角色OOC、剧情逻辑、节奏把控等维度审查给定的章节内容。',
      iconName: 'rate_review',
      createdAt: now,
    ),
    PromptTemplate(
      id: 'character_sim',
      name: '角色推演模板',
      description: '扮演角色进行行为推演',
      systemPrompt:
          '请完全沉浸在给定角色的视角中。根据角色的性格、价值观、说话风格和当前情境，推演角色可能的反应、决策和内心活动。',
      iconName: 'person',
      createdAt: now,
    ),
  ];
}

void addAIConfigRepositoryAccum(
  Map<String, AIConfigRepositoryAccum> target,
  String key,
  int tokens,
) {
  target.putIfAbsent(key, () => AIConfigRepositoryAccum()).add(tokens);
}

UsageStats buildAIConfigRepositoryUsageStats({
  required int todayRequests,
  required int todayTokens,
  required int weekRequests,
  required int weekTokens,
  required int monthRequests,
  required int monthTokens,
  required Map<String, AIConfigRepositoryAccum> byModel,
  required Map<String, AIConfigRepositoryAccum> byFunction,
}) {
  return UsageStats(
    todayRequests: todayRequests,
    todayTokens: todayTokens,
    weekRequests: weekRequests,
    weekTokens: weekTokens,
    monthRequests: monthRequests,
    monthTokens: monthTokens,
    byModel: byModel.map(
      (key, value) => MapEntry(
        key,
        ModelUsageStats(
          requests: value.count,
          tokens: value.tokens,
          estimatedCost: 0,
        ),
      ),
    ),
    byFunction: byFunction.map(
      (key, value) => MapEntry(
        key,
        FunctionUsageStats(requests: value.count, tokens: value.tokens),
      ),
    ),
  );
}

List<String> appendAIConfigRepositoryHistoryRecord(
  List<String>? existing,
  Map<String, dynamic> record, {
  required int maxRecords,
}) {
  final history = [...?existing, jsonEncode(record)];
  if (history.length > maxRecords) {
    history.removeRange(0, history.length - maxRecords);
  }
  return history;
}

List<Map<String, dynamic>> decodeAIConfigRepositoryHistory(
  List<String>? rawHistory, {
  required int limit,
}) {
  return (rawHistory ?? const [])
      .take(limit)
      .map((item) => jsonDecode(item) as Map<String, dynamic>)
      .toList();
}

core_provider.ProviderConfig buildAIConfigRepositoryProviderConfig({
  required String apiKey,
  required ModelConfig config,
  required core_model.AIProviderType type,
}) {
  return core_provider.ProviderConfig(
    id: 'ai_config_${config.tier.name}_${type.name}',
    type: type,
    name: type.displayName,
    apiKey: apiKey,
    apiEndpoint: config.apiEndpoint,
  );
}

core_tier.ModelTier toAIConfigRepositoryCoreTier(ModelTier tier) {
  return switch (tier) {
    ModelTier.thinking => core_tier.ModelTier.thinking,
    ModelTier.middle => core_tier.ModelTier.middle,
    ModelTier.fast => core_tier.ModelTier.fast,
  };
}

core_model.AIProviderType toAIConfigRepositoryProviderType(String providerType) {
  return switch (providerType.toLowerCase()) {
    'openai' => core_model.AIProviderType.openai,
    'anthropic' || 'claude' => core_model.AIProviderType.anthropic,
    'ollama' => core_model.AIProviderType.ollama,
    'azure' => core_model.AIProviderType.azure,
    _ => core_model.AIProviderType.custom,
  };
}
