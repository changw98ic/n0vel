import 'dart:async';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get/get.dart' as getx;

import '../../../features/ai_config/data/ai_config_repository.dart';
import '../../../features/ai_config/domain/model_config.dart' as feature_config;
import '../../database/database.dart';
import 'ai_prompt_builder.dart';
import 'ai_usage_tracker.dart';
import 'cache/cache_manager.dart';
import 'models/model_config.dart';
import 'models/model_tier.dart';
import 'models/provider_config.dart';
import 'providers/ai_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/azure_openai_provider.dart';
import 'providers/custom_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

part 'ai_service.freezed.dart';
part 'ai_service_request_helpers.dart';

extension StringToAIProviderType on String {
  AIProviderType toProviderType() {
    final lower = toLowerCase();
    return switch (lower) {
      'openai' => AIProviderType.openai,
      'anthropic' || 'claude' => AIProviderType.anthropic,
      'ollama' => AIProviderType.ollama,
      'azure' => AIProviderType.azure,
      _ => AIProviderType.custom,
    };
  }
}

/// AI 鐠囬攱鐪扮拫鍐暏閻ㄥ嫬浼愰崗?class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        id: json['id'] as String,
        name: json['name'] as String,
        arguments: json['arguments'] as Map<String, dynamic>,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'arguments': arguments,
      };
}

@freezed
class AIResponse with _$AIResponse {
  const factory AIResponse({
    required String content,
    required int inputTokens,
    required int outputTokens,
    required String modelId,
    required Duration responseTime,
    required bool fromCache,
    String? requestId,
    Map<String, dynamic>? metadata,
    @Default([]) List<ToolCall> toolCalls,
    String? thinking,
  }) = _AIResponse;
}

@freezed
class AIRequestConfig with _$AIRequestConfig {
  const factory AIRequestConfig({
    required AIFunction function,
    String? systemPrompt,
    required String userPrompt,
    Map<String, dynamic>? variables,
    ModelTier? overrideTier,
    String? overrideModelId,
    @Default(true) bool useCache,
    @Default(true) bool stream,
    @Default(1.0) double temperature,
    int? maxTokens,
    void Function(String)? onStreamChunk,
  }) = _AIRequestConfig;
}

sealed class AIResult<T> {
  const AIResult();
}

class AISuccess<T> extends AIResult<T> {
  final T data;
  final AIResponse response;

  const AISuccess(this.data, this.response);
}

class AIFailure<T> extends AIResult<T> {
  final String error;
  final String? errorCode;
  final int? statusCode;

  const AIFailure(this.error, {this.errorCode, this.statusCode});
}

class AIException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final dynamic originalError;

  const AIException(
    this.message, {
    this.code,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'AIException: $message';
}

class TokenCountException extends AIException {
  const TokenCountException(int current, int max)
    : super(
        'Token count exceeds limit: $current > $max',
        code: 'TOKEN_LIMIT_EXCEEDED',
      );
}

class AIService extends getx.GetxController {
  final PromptCacheManager _cacheManager;
  final AIProviderRegistry _providerRegistry;
  final AIPromptBuilder _promptBuilder;
  final AIUsageTracker _usageTracker;

  AIService()
    : _cacheManager = PromptCacheManager(),
      _providerRegistry = AIProviderRegistry(),
      _promptBuilder = const AIPromptBuilder(),
      _usageTracker = AIUsageTracker(getx.Get.find<AppDatabase>()) {
    _registerDefaultProviders();
  }

  void _registerDefaultProviders() {
    for (final provider in buildDefaultAIProviders()) {
      _providerRegistry.register(provider);
    }
  }

  Future<AIResponse> generate({
    required String prompt,
    required AIRequestConfig config,
  }) async {
    final stopwatch = Stopwatch()..start();
    final modelConfig = await _getModelConfig(config);
    if (modelConfig == null) {
      throw AIException('No model configured for ${config.function.key}');
    }

    if (config.useCache) {
      final cached = _cacheManager.find(
        prompt,
        modelConfig.id,
        params: buildAIServiceCacheParams(config),
      );
      if (cached != null) {
        stopwatch.stop();
        await _usageTracker.recordUsage(
          functionType: config.function.key,
          modelId: modelConfig.id,
          tier: modelConfig.tier.name,
          status: 'success',
          inputTokens: cached.inputTokens ?? 0,
          outputTokens: cached.outputTokens ?? 0,
          responseTimeMs: stopwatch.elapsed.inMilliseconds,
          fromCache: true,
        );
        return buildCachedAIResponse(
          cachedResponse: cached.response,
          inputTokens: cached.inputTokens,
          outputTokens: cached.outputTokens,
          modelId: modelConfig.id,
          responseTime: stopwatch.elapsed,
        );
      }
    }

    final providerConfig = await _getProviderConfig(modelConfig);
    if (providerConfig == null) {
      throw AIException(
        'No provider config found for ${modelConfig.providerType}',
      );
    }

    final provider = _providerRegistry.get(
      modelConfig.providerType.toProviderType(),
    );
    if (provider == null) {
      throw AIException(
        'No provider registered for ${modelConfig.providerType}',
      );
    }

    final promptBundle = buildAIServicePromptBundle(
      promptBuilder: _promptBuilder,
      prompt: prompt,
      config: config,
      respondInChinese: shouldAIServiceRespondInChinese(getx.Get.locale),
    );

    try {
      final response = await _retryWithBackoff(
        () => provider.complete(
          config: providerConfig,
          model: modelConfig,
          systemPrompt: promptBundle.systemPrompt,
          userPrompt: promptBundle.userPrompt,
          temperature: config.temperature,
          maxTokens: config.maxTokens,
          stream: false,
        ),
        maxRetries: providerConfig.maxRetries,
      );

      if (config.useCache) {
        _cacheManager.store(
          prompt,
          modelConfig.id,
          response.content,
          params: buildAIServiceCacheParams(config),
          inputTokens: response.inputTokens,
          outputTokens: response.outputTokens,
        );
      }

      await _usageTracker.recordUsage(
        functionType: config.function.key,
        modelId: modelConfig.id,
        tier: modelConfig.tier.name,
        status: 'success',
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        responseTimeMs: response.responseTime.inMilliseconds,
        requestId: response.requestId,
        fromCache: false,
        metadata: response.metadata,
      );

      return response;
    } catch (error) {
      await _usageTracker.recordUsage(
        functionType: config.function.key,
        modelId: modelConfig.id,
        tier: modelConfig.tier.name,
        status: 'error',
        inputTokens: 0,
        outputTokens: 0,
        responseTimeMs: stopwatch.elapsed.inMilliseconds,
        errorMessage: error.toString(),
        fromCache: false,
      );
      rethrow;
    }
  }

  Stream<String> generateStream({
    required String prompt,
    required AIRequestConfig config,
  }) async* {
    final modelConfig = await _getModelConfig(config);
    if (modelConfig == null) {
      throw AIException('No model configured for ${config.function.key}');
    }

    final providerConfig = await _getProviderConfig(modelConfig);
    if (providerConfig == null) {
      throw AIException(
        'No provider config found for ${modelConfig.providerType}',
      );
    }

    final provider = _providerRegistry.get(
      modelConfig.providerType.toProviderType(),
    );
    if (provider == null) {
      throw AIException(
        'No provider registered for ${modelConfig.providerType}',
      );
    }

    final promptBundle = buildAIServicePromptBundle(
      promptBuilder: _promptBuilder,
      prompt: prompt,
      config: config,
      respondInChinese: shouldAIServiceRespondInChinese(getx.Get.locale),
    );
    final controller = StreamController<String>();
    final buffer = StringBuffer();
    final stopwatch = Stopwatch()..start();
    bool controllerClosed = false;

    void safeClose() {
      if (!controllerClosed) {
        controllerClosed = true;
        controller.close();
      }
    }

    unawaited(
      _retryWithBackoff(
        () => provider.complete(
          config: providerConfig,
          model: modelConfig,
          systemPrompt: promptBundle.systemPrompt,
          userPrompt: promptBundle.userPrompt,
          temperature: config.temperature,
          maxTokens: config.maxTokens,
          stream: true,
          onStreamChunk: (chunk) {
            buffer.write(chunk);
            config.onStreamChunk?.call(chunk);
            if (!controllerClosed) {
              controller.add(chunk);
            }
          },
        ),
        maxRetries: providerConfig.maxRetries,
      )
          .then((_) async {
            stopwatch.stop();
            final inputTokens = await provider.countTokens(
              '${promptBundle.systemPrompt}\n${promptBundle.userPrompt}',
              modelConfig.modelName,
            );
            final outputTokens = await provider.countTokens(
              buffer.toString(),
              modelConfig.modelName,
            );
            if (config.useCache) {
              _cacheManager.store(
                prompt,
                modelConfig.id,
                buffer.toString(),
                params: buildAIServiceCacheParams(config),
                inputTokens: inputTokens,
                outputTokens: outputTokens,
              );
            }
            await _usageTracker.recordUsage(
              functionType: config.function.key,
              modelId: modelConfig.id,
              tier: modelConfig.tier.name,
              status: 'success',
              inputTokens: inputTokens,
              outputTokens: outputTokens,
              responseTimeMs: stopwatch.elapsed.inMilliseconds,
              fromCache: false,
            );
            safeClose();
          })
          .catchError((error) async {
            stopwatch.stop();
            await _usageTracker.recordUsage(
              functionType: config.function.key,
              modelId: modelConfig.id,
              tier: modelConfig.tier.name,
              status: 'error',
              inputTokens: 0,
              outputTokens: 0,
              responseTimeMs: stopwatch.elapsed.inMilliseconds,
              errorMessage: error.toString(),
              fromCache: false,
            );
            if (!controllerClosed) {
              controller.addError(error);
            }
            safeClose();
          }),
    );

    yield* controller.stream;
  }

  Future<ModelConfig?> _getModelConfig(AIRequestConfig config) async {
    final repo = getx.Get.find<AIConfigRepository>();

    // Priority: overrideTier > function mapping > function default
    if (config.overrideTier != null) {
      return repo.getCoreModelConfig(_toFeatureTier(config.overrideTier!));
    }

    // Check function-specific tier override from config layer
    final functionTier = await repo.getFunctionOverrideTier(config.function.key);
    final featureTier = functionTier ?? _toFeatureTier(config.function.defaultTier);

    return repo.getCoreModelConfig(featureTier);
  }

  Future<ProviderConfig?> _getProviderConfig(ModelConfig modelConfig) async {
    final repo = getx.Get.find<AIConfigRepository>();
    final featureTier = _toFeatureTier(modelConfig.tier);
    return repo.getCoreProviderConfig(featureTier);
  }

  static const _retryableStatusCodes = {408, 429, 500, 502, 503, 504};

  Future<T> _retryWithBackoff<T>(
    Future<T> Function() fn, {
    required int maxRetries,
  }) async {
    var attempt = 0;
    while (true) {
      try {
        return await fn();
      } on AIException catch (e) {
        final statusCode = e.statusCode;
        if (statusCode != null &&
            !_retryableStatusCodes.contains(statusCode)) {
          rethrow;
        }
        attempt++;
        if (attempt > maxRetries) rethrow;
        final delay = Duration(
          milliseconds: buildAIRetryDelayMs(
            attempt: attempt,
            random: Random(),
          ),
        );
        await Future.delayed(delay);
      }
    }
  }

  void clearCache() {
    _cacheManager.clear();
  }

  CacheStats get cacheStats => _cacheManager.stats;

  /// 娴ｈ法鏁ら崢鐔烘晸 tool calling 閻㈢喐鍨?  /// 閻╁瓨甯寸拫鍐暏 Provider 閻?completeWithTools閿涘本鏁幐浣稿斧閻?function calling
  Future<AIResponse> generateWithTools({
    required String prompt,
    required AIRequestConfig config,
    required List<Map<String, dynamic>> tools,
  }) async {
    final stopwatch = Stopwatch()..start();
    final modelConfig = await _getModelConfig(config);
    if (modelConfig == null) {
      throw AIException('No model configured for ${config.function.key}');
    }

    final providerConfig = await _getProviderConfig(modelConfig);
    if (providerConfig == null) {
      throw AIException(
        'No provider config found for ${modelConfig.providerType}',
      );
    }

    final provider = _providerRegistry.get(
      modelConfig.providerType.toProviderType(),
    );
    if (provider == null) {
      throw AIException(
        'No provider registered for ${modelConfig.providerType}',
      );
    }

    final promptBundle = buildAIServicePromptBundle(
      promptBuilder: _promptBuilder,
      prompt: prompt,
      config: config,
      respondInChinese: shouldAIServiceRespondInChinese(getx.Get.locale),
    );

    try {
      final response = await _retryWithBackoff(
        () => provider.completeWithTools(
          config: providerConfig,
          model: modelConfig,
          systemPrompt: promptBundle.systemPrompt,
          userPrompt: promptBundle.userPrompt,
          tools: tools,
          temperature: config.temperature,
          maxTokens: config.maxTokens,
        ),
        maxRetries: providerConfig.maxRetries,
      );

      await _usageTracker.recordUsage(
        functionType: config.function.key,
        modelId: modelConfig.id,
        tier: modelConfig.tier.name,
        status: 'success',
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
        responseTimeMs: response.responseTime.inMilliseconds,
        requestId: response.requestId,
        fromCache: false,
        metadata: response.metadata,
      );

      return response;
    } catch (error) {
      await _usageTracker.recordUsage(
        functionType: config.function.key,
        modelId: modelConfig.id,
        tier: modelConfig.tier.name,
        status: 'error',
        inputTokens: 0,
        outputTokens: 0,
        responseTimeMs: stopwatch.elapsed.inMilliseconds,
        errorMessage: error.toString(),
        fromCache: false,
      );
      rethrow;
    }
  }

  /// 閺嗘挳婀舵笟娑樼安閸熷棙鏁為崘宀冦€冮敍鍦揼entService 缁涘绗傜仦鍌涙箛閸旓繝娓剁憰渚婄礆
  AIProviderRegistry get providerRegistry => _providerRegistry;

  /// 鐟欙絾鐎芥笟娑樼安閸熷棝鍘ょ純顕嗙礄娓?AgentService 缁涘绗傜仦鍌涙箛閸斺€插▏閻㈩煉绱?  /// 鏉╂柨娲栫憴锝嗙€介崥搴ｆ畱 ModelConfig閵嗕赋roviderConfig 閸?AIProvider
  Future<({ModelConfig model, ProviderConfig config, AIProvider provider})>
      resolveProvider(AIRequestConfig config) async {
    final modelConfig = await _getModelConfig(config);
    if (modelConfig == null) {
      throw AIException('No model configured for ${config.function.key}');
    }

    final providerConfig = await _getProviderConfig(modelConfig);
    if (providerConfig == null) {
      throw AIException(
        'No provider config found for ${modelConfig.providerType}',
      );
    }

    final provider = _providerRegistry.get(
      modelConfig.providerType.toProviderType(),
    );
    if (provider == null) {
      throw AIException(
        'No provider registered for ${modelConfig.providerType}',
      );
    }

    return (
      model: modelConfig,
      config: providerConfig,
      provider: provider,
    );
  }

  Future<List<AIUsageRecord>> getAIUsageStatistics({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? functionType,
    int limit = 100,
  }) async {
    return _usageTracker.getUsageStatistics(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
      functionType: functionType,
      limit: limit,
    );
  }

  Future<List<AIUsageSummary>> getAIUsageSummaries({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? modelId,
  }) async {
    return _usageTracker.getUsageSummaries(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
      modelId: modelId,
    );
  }

  Future<Map<String, dynamic>> getModelUsageStats({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _usageTracker.getModelUsageStats(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  feature_config.ModelTier _toFeatureTier(ModelTier tier) {
    return toAIServiceFeatureTier(tier);
  }
}
