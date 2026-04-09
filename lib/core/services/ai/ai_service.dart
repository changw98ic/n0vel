import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' hide JsonKey;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:get/get.dart' as getx;
import 'package:uuid/uuid.dart';

import '../../../features/ai_config/data/ai_config_repository.dart';
import '../../../features/ai_config/domain/model_config.dart' as feature_config;
import '../../database/database.dart';
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

/// AI 请求调用的工具
class ToolCall {
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
  final AppDatabase _db;
  final Uuid _uuid;

  AIService()
    : _cacheManager = PromptCacheManager(),
      _providerRegistry = AIProviderRegistry(),
      _db = getx.Get.find<AppDatabase>(),
      _uuid = const Uuid() {
    _registerDefaultProviders();
  }

  void _registerDefaultProviders() {
    _providerRegistry.register(OpenAIProvider());
    _providerRegistry.register(AnthropicProvider());
    _providerRegistry.register(OllamaProvider());
    _providerRegistry.register(AzureOpenAIProvider());
    _providerRegistry.register(CustomProvider());
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
        params: {
          'temperature': config.temperature,
          'maxTokens': config.maxTokens,
        },
      );
      if (cached != null) {
        stopwatch.stop();
        await _recordAIUsage(
          functionType: config.function.key,
          modelId: modelConfig.id,
          tier: modelConfig.tier.name,
          status: 'success',
          inputTokens: cached.inputTokens ?? 0,
          outputTokens: cached.outputTokens ?? 0,
          responseTimeMs: stopwatch.elapsed.inMilliseconds,
          fromCache: true,
        );
        return AIResponse(
          content: cached.response,
          inputTokens: cached.inputTokens ?? 0,
          outputTokens: cached.outputTokens ?? 0,
          modelId: modelConfig.id,
          responseTime: stopwatch.elapsed,
          fromCache: true,
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

    final systemPrompt = _appendLang(
        config.systemPrompt ?? _getDefaultSystemPrompt(config.function));
    final userPrompt = _buildUserPrompt(prompt, config);

    try {
      final response = await _retryWithBackoff(
        () => provider.complete(
          config: providerConfig,
          model: modelConfig,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
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
          params: {
            'temperature': config.temperature,
            'maxTokens': config.maxTokens,
          },
          inputTokens: response.inputTokens,
          outputTokens: response.outputTokens,
        );
      }

      await _recordAIUsage(
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
      await _recordAIUsage(
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

    final systemPrompt = _appendLang(
        config.systemPrompt ?? _getDefaultSystemPrompt(config.function));
    final userPrompt = _buildUserPrompt(prompt, config);
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
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
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
              '$systemPrompt\n$userPrompt',
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
                params: {
                  'temperature': config.temperature,
                  'maxTokens': config.maxTokens,
                },
                inputTokens: inputTokens,
                outputTokens: outputTokens,
              );
            }
            await _recordAIUsage(
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
            await _recordAIUsage(
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

  String _getDefaultSystemPrompt(AIFunction function) {
    return switch (function) {
      AIFunction.continuation => '你是一位专业的小说作家助手，请根据上下文自然续写。',
      AIFunction.dialogue => '你是一位专业的小说对话作家，请生成符合角色设定的对话。',
      AIFunction.characterSimulation => '你是一位专业的角色扮演助手，请根据角色设定进行推演。',
      AIFunction.review => '你是一位专业的小说编辑，请从一致性、逻辑和节奏维度审查内容。',
      AIFunction.extraction => '你是一位专业的设定提取助手，请提取角色、地点、物品等信息。',
      AIFunction.consistencyCheck => '你是一位专业的一致性检查助手，请检查内容中的设定冲突。',
      AIFunction.timelineExtract => '你是一位专业的时间线提取助手，请提取事件顺序。',
      AIFunction.oocDetection => '你是一位专业的角色 OOC 检测助手，请检查角色行为是否符合设定。',
      AIFunction.aiStyleDetection => '你是一位专业的 AI 文风检测助手，请识别明显的 AI 痕迹。',
      AIFunction.perspectiveCheck => '你是一位专业的视角检测助手，请检查叙事视角是否一致。',
      AIFunction.pacingAnalysis => '你是一位专业的节奏分析助手，请分析叙事节奏是否合理。',
      AIFunction.povGeneration => '你是一位专业的视角生成助手，请从指定角色视角重写内容。',
      AIFunction.chat => '你是一位专业的小说写作助手，请与用户进行友好的对话交流，帮助解决写作相关问题。',
      AIFunction.entityCreation => '你是一位专业的小说设定创建助手。根据用户的描述生成完整的角色、地点、物品或势力设定。',
      AIFunction.entityExtraction => '你是一位专业的设定提取助手，请从文本中提取角色、地点、物品等实体信息。',
    };
  }

  /// 根据当前 locale 追加语言指令
  String _appendLang(String systemPrompt) {
    final isZh = getx.Get.locale?.languageCode.startsWith('zh') ?? true;
    final langSuffix = isZh ? '请务必使用中文回复。' : 'Please respond in English.';
    return '$systemPrompt\n$langSuffix';
  }

  String _buildUserPrompt(String prompt, AIRequestConfig config) {
    var result = prompt;
    final variables = config.variables;
    if (variables != null) {
      variables.forEach((key, value) {
        result = result.replaceAll('{$key}', value.toString());
      });
    }
    return result;
  }

  /// 可重试的 HTTP 状态码
  static const _retryableStatusCodes = {408, 429, 500, 502, 503, 504};

  /// 带指数退避的重试
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
          milliseconds: (1000 * (1 << attempt)) + Random().nextInt(1000),
        );
        await Future.delayed(delay);
      }
    }
  }

  void clearCache() {
    _cacheManager.clear();
  }

  CacheStats get cacheStats => _cacheManager.stats;

  /// 使用原生 tool calling 生成
  /// 直接调用 Provider 的 completeWithTools，支持原生 function calling
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

    final systemPrompt = _appendLang(
        config.systemPrompt ?? _getDefaultSystemPrompt(config.function));
    final userPrompt = _buildUserPrompt(prompt, config);

    try {
      final response = await _retryWithBackoff(
        () => provider.completeWithTools(
          config: providerConfig,
          model: modelConfig,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          tools: tools,
          temperature: config.temperature,
          maxTokens: config.maxTokens,
        ),
        maxRetries: providerConfig.maxRetries,
      );

      await _recordAIUsage(
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
      await _recordAIUsage(
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

  /// 暴露供应商注册表（AgentService 等上层服务需要）
  AIProviderRegistry get providerRegistry => _providerRegistry;

  /// 解析供应商配置（供 AgentService 等上层服务使用）
  /// 返回解析后的 ModelConfig、ProviderConfig 和 AIProvider
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

  Future<void> _recordAIUsage({
    required String functionType,
    required String modelId,
    required String tier,
    required String status,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    String? errorMessage,
    String? requestId,
    required bool fromCache,
    String? workId,
    Map<String, dynamic>? metadata,
  }) async {
    final record = AIUsageRecordsCompanion.insert(
      id: _uuid.v4(),
      workId: Value(workId),
      functionType: functionType,
      modelId: modelId,
      tier: tier,
      status: status,
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      totalTokens: Value(inputTokens + outputTokens),
      responseTimeMs: Value(responseTimeMs),
      errorMessage: Value(errorMessage),
      requestId: Value(requestId),
      fromCache: Value(fromCache),
      metadata: Value(metadata?.toString()),
      createdAt: DateTime.now(),
    );

    await _db.into(_db.aIUsageRecords).insert(record);

    await _updateDailySummary(
      functionType: functionType,
      modelId: modelId,
      tier: tier,
      status: status,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      responseTimeMs: responseTimeMs,
      fromCache: fromCache,
      workId: workId,
    );
  }

  Future<void> _updateDailySummary({
    required String functionType,
    required String modelId,
    required String tier,
    required String status,
    required int inputTokens,
    required int outputTokens,
    required int responseTimeMs,
    required bool fromCache,
    String? workId,
  }) async {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final existing =
        await (_db.select(_db.aIUsageSummaries)
              ..where(
                (table) =>
                    table.workId.equalsNullable(workId) &
                    table.modelId.equals(modelId) &
                    table.functionType.equalsNullable(functionType) &
                    table.date.equals(today),
              )
              ..limit(1))
            .get();

    if (existing.isNotEmpty) {
      final summary = existing.first;
      await (_db.update(
        _db.aIUsageSummaries,
      )..where((table) => table.id.equals(summary.id))).write(
        AIUsageSummariesCompanion(
          requestCount: Value(summary.requestCount + 1),
          successCount: Value(
            status == 'success'
                ? summary.successCount + 1
                : summary.successCount,
          ),
          errorCount: Value(
            status == 'error' ? summary.errorCount + 1 : summary.errorCount,
          ),
          cachedCount: Value(
            fromCache ? summary.cachedCount + 1 : summary.cachedCount,
          ),
          totalInputTokens: Value(summary.totalInputTokens + inputTokens),
          totalOutputTokens: Value(summary.totalOutputTokens + outputTokens),
          totalTokens: Value(summary.totalTokens + inputTokens + outputTokens),
          totalResponseTimeMs: Value(
            summary.totalResponseTimeMs + responseTimeMs,
          ),
          avgResponseTimeMs: Value(
            (summary.totalResponseTimeMs + responseTimeMs) ~/
                (summary.requestCount + 1),
          ),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await _db
        .into(_db.aIUsageSummaries)
        .insert(
          AIUsageSummariesCompanion.insert(
            id: _uuid.v4(),
            workId: Value(workId),
            modelId: modelId,
            tier: tier,
            functionType: Value(functionType),
            date: today,
            requestCount: const Value(1),
            successCount: Value(status == 'success' ? 1 : 0),
            errorCount: Value(status == 'error' ? 1 : 0),
            cachedCount: Value(fromCache ? 1 : 0),
            totalInputTokens: Value(inputTokens),
            totalOutputTokens: Value(outputTokens),
            totalTokens: Value(inputTokens + outputTokens),
            totalResponseTimeMs: Value(responseTimeMs),
            avgResponseTimeMs: Value(responseTimeMs),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<AIUsageRecord>> getAIUsageStatistics({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? functionType,
    int limit = 100,
  }) async {
    final query = _db.select(_db.aIUsageRecords);

    if (workId != null) {
      query.where((table) => table.workId.equals(workId));
    }
    if (startDate != null) {
      query.where((table) => table.createdAt.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((table) => table.createdAt.isSmallerOrEqualValue(endDate));
    }
    if (functionType != null) {
      query.where((table) => table.functionType.equals(functionType));
    }

    query
      ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
      ..limit(limit);

    return query.get();
  }

  Future<List<AIUsageSummary>> getAIUsageSummaries({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
    String? modelId,
  }) async {
    final query = _db.select(_db.aIUsageSummaries);

    if (workId != null) {
      query.where((table) => table.workId.equals(workId));
    }
    if (startDate != null) {
      query.where((table) => table.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((table) => table.date.isSmallerOrEqualValue(endDate));
    }
    if (modelId != null) {
      query.where((table) => table.modelId.equals(modelId));
    }

    query.orderBy([(table) => OrderingTerm.desc(table.date)]);
    return query.get();
  }

  Future<Map<String, dynamic>> getModelUsageStats({
    String? workId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final summaries = await getAIUsageSummaries(
      workId: workId,
      startDate: startDate,
      endDate: endDate,
    );

    final result = <String, Map<String, dynamic>>{};
    for (final summary in summaries) {
      result.putIfAbsent(summary.modelId, () {
        return <String, dynamic>{
          'totalTokens': 0,
          'totalRequests': 0,
          'totalCost': 0.0,
          'avgResponseTime': 0,
          'tier': summary.tier,
        };
      });

      final entry = result[summary.modelId]!;
      entry['totalTokens'] += summary.totalTokens;
      entry['totalRequests'] += summary.requestCount;
      entry['totalCost'] += summary.estimatedCost;
      entry['avgResponseTime'] =
          ((entry['avgResponseTime'] as int) + summary.avgResponseTimeMs) ~/ 2;
    }

    return result;
  }

  feature_config.ModelTier _toFeatureTier(ModelTier tier) {
    return switch (tier) {
      ModelTier.thinking => feature_config.ModelTier.thinking,
      ModelTier.middle => feature_config.ModelTier.middle,
      ModelTier.fast => feature_config.ModelTier.fast,
    };
  }
}
