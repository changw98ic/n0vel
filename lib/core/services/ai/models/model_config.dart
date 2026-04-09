import 'package:freezed_annotation/freezed_annotation.dart';

import 'model_tier.dart';

part 'model_config.freezed.dart';
part 'model_config.g.dart';

/// 模型配置
/// 用户可自定义每个层级的模型
@freezed
class ModelConfig with _$ModelConfig {
  const ModelConfig._();

  const factory ModelConfig({
    required String id,
    required ModelTier tier,
    required String displayName,
    required String providerType,
    required String modelName,
    String? apiEndpoint,
    @Default(0.7) double temperature,
    @Default(16384) int maxOutputTokens,
    @Default(1.0) double topP,
    @Default(0.0) double frequencyPenalty,
    @Default(0.0) double presencePenalty,
    @Default(true) bool isEnabled,
    DateTime? lastValidatedAt,
    @Default(false) bool isValid,
  }) = _ModelConfig;

  factory ModelConfig.fromJson(Map<String, dynamic> json) =>
      _$ModelConfigFromJson(json);

  /// 默认配置模板
  static List<ModelConfig> defaultConfigs() => [
        ModelConfig(
          id: 'thinking_default',
          tier: ModelTier.thinking,
          displayName: 'Thinking (默认)',
          providerType: 'openai',
          modelName: 'gpt-4-turbo',
          temperature: 0.7,
          maxOutputTokens: 16384,
        ),
        ModelConfig(
          id: 'middle_default',
          tier: ModelTier.middle,
          displayName: 'Middle (默认)',
          providerType: 'openai',
          modelName: 'gpt-3.5-turbo',
          temperature: 0.7,
          maxOutputTokens: 8192,
        ),
        ModelConfig(
          id: 'fast_default',
          tier: ModelTier.fast,
          displayName: 'Fast (默认)',
          providerType: 'openai',
          modelName: 'gpt-3.5-turbo',
          temperature: 0.8,
          maxOutputTokens: 4096,
        ),
      ];
}

/// 供应商类型
enum AIProviderType {
  openai('OpenAI', 'https://api.openai.com/v1'),
  anthropic('Claude', 'https://api.anthropic.com/v1'),
  ollama('Ollama', 'http://localhost:11434/api'),
  azure('Azure OpenAI', ''),
  custom('Custom', '');

  const AIProviderType(this.displayName, this.defaultEndpoint);

  final String displayName;
  final String defaultEndpoint;
}
