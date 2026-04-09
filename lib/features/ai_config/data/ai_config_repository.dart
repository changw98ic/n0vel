import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/database/database.dart';

import '../../../core/services/ai/models/model_config.dart' as core_model;
import '../../../core/services/ai/models/model_tier.dart' as core_tier;
import '../../../core/services/ai/models/provider_config.dart' as core_provider;
import '../../../core/services/ai/providers/anthropic_provider.dart';
import '../../../core/services/ai/providers/azure_openai_provider.dart';
import '../../../core/services/ai/providers/custom_provider.dart';
import '../../../core/services/ai/providers/ollama_provider.dart';
import '../../../core/services/ai/providers/openai_provider.dart';
import '../domain/model_config.dart';

/// AI 配置仓库
class AIConfigRepository {
  static const String _keyPrefix = 'ai_config_';
  static const String _defaultLocalProviderType = 'custom';
  static const String _defaultLocalModelName = 'google/gemma-4-26b-a4b';
  static const String _defaultLocalEndpoint = 'http://127.0.0.1:1234/v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// 获取模型配置
  Future<ModelConfig?> getModelConfig(ModelTier tier) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}model_${tier.name}';

    final providerType = prefs.getString('${key}_provider');
    final modelName = prefs.getString('${key}_model');
    final apiEndpoint = prefs.getString('${key}_endpoint');
    final temperature = prefs.getDouble('${key}_temperature') ?? 0.7;
    final maxTokens = prefs.getInt('${key}_max_tokens') ?? 4096;
    final topP = prefs.getDouble('${key}_top_p') ?? 1.0;
    final frequencyPenalty = prefs.getDouble('${key}_frequency_penalty') ?? 0.0;
    final presencePenalty = prefs.getDouble('${key}_presence_penalty') ?? 0.0;
    final isEnabled = prefs.getBool('${key}_enabled') ?? true;
    final lastValidatedAt = prefs.getInt('${key}_validated_at') != null
        ? DateTime.fromMillisecondsSinceEpoch(
            prefs.getInt('${key}_validated_at')!,
          )
        : null;
    final isValid = prefs.getBool('${key}_is_valid') ?? false;

    if (providerType == null || modelName == null) {
      // 返回默认配置
      return ModelConfig(
        tier: tier,
        providerType: providerType ?? _defaultLocalProviderType,
        modelName: modelName ?? _defaultLocalModelName,
        apiEndpoint: apiEndpoint ?? _defaultLocalEndpoint,
        temperature: temperature,
        maxOutputTokens: maxTokens,
        topP: topP,
        frequencyPenalty: frequencyPenalty,
        presencePenalty: presencePenalty,
        isEnabled: isEnabled,
        lastValidatedAt: lastValidatedAt,
        isValid: isValid,
      );
    }

    return ModelConfig(
      tier: tier,
      providerType: providerType,
      modelName: modelName,
      apiEndpoint: apiEndpoint,
      temperature: temperature,
      maxOutputTokens: maxTokens,
      topP: topP,
      frequencyPenalty: frequencyPenalty,
      presencePenalty: presencePenalty,
      isEnabled: isEnabled,
      lastValidatedAt: lastValidatedAt,
      isValid: isValid,
    );
  }

  /// 保存模型配置
  Future<void> saveModelConfig({
    required ModelTier tier,
    required String providerType,
    required String modelName,
    String? apiEndpoint,
    String? apiKey,
    double temperature = 0.7,
    int maxOutputTokens = 4096,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}model_${tier.name}';

    // 保存配置到 SharedPreferences
    await prefs.setString('${key}_provider', providerType);
    await prefs.setString('${key}_model', modelName);
    if (apiEndpoint != null) {
      await prefs.setString('${key}_endpoint', apiEndpoint);
    }
    await prefs.setDouble('${key}_temperature', temperature);
    await prefs.setInt('${key}_max_tokens', maxOutputTokens);

    // API Key 使用 flutter_secure_storage 安全存储
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.write(key: '${key}_apikey', value: apiKey);
    }
  }

  /// 测试连接
  Future<core_provider.ConnectionTestResult> testConnection(ModelTier tier) async {
    try {
      // 获取该层级的配置
      final config = await getModelConfig(tier);
      if (config == null) {
        return core_provider.ConnectionTestResult.fail('未找到模型配置');
      }

      // 从安全存储中读取 API Key
      final apiKey = await _getApiKey(tier);
      final providerType = config.providerType.toLowerCase();
      final requiresApiKey =
          providerType != 'ollama' && providerType != 'custom';
      if (requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
        return core_provider.ConnectionTestResult.fail('API 密钥未设置');
      }

      // 根据提供商类型测试连接
      final type = _toCoreProviderType(config.providerType);
      return _testProviderConnection(apiKey ?? '', config, type);
    } catch (e) {
      return core_provider.ConnectionTestResult.fail('测试失败: $e');
    }
  }

  /// 从安全存储获取 API Key
  Future<String?> _getApiKey(ModelTier tier) async {
    final key = '${_keyPrefix}model_${tier.name}';
    try {
      return await _secureStorage.read(key: '${key}_apikey');
    } catch (_) {
      return null;
    }
  }

  /// 测试提供商连接（统一方法）
  Future<core_provider.ConnectionTestResult> _testProviderConnection(
    String apiKey,
    ModelConfig config,
    core_model.AIProviderType type,
  ) async {
    try {
      final dio = Dio();
      final provider = switch (type) {
        core_model.AIProviderType.openai => OpenAIProvider(dio: dio),
        core_model.AIProviderType.anthropic => AnthropicProvider(dio: dio),
        core_model.AIProviderType.azure => AzureOpenAIProvider(dio: dio),
        core_model.AIProviderType.ollama => OllamaProvider(dio: dio),
        _ => CustomProvider(dio: dio),
      };
      return provider.validateConnection(
        _buildProviderConfig(apiKey: apiKey, config: config, type: type),
      );
    } catch (e) {
      return core_provider.ConnectionTestResult.fail('$e');
    }
  }

  /// 获取所有模型配置
  Future<List<ModelConfig>> getAllModelConfigs() async {
    final configs = <ModelConfig>[];
    for (final tier in ModelTier.values) {
      final config = await getModelConfig(tier);
      if (config != null) {
        configs.add(config);
      }
    }
    return configs;
  }

  Future<core_model.ModelConfig?> getCoreModelConfig(ModelTier tier) async {
    final config = await getModelConfig(tier);
    if (config == null) {
      return null;
    }

    return core_model.ModelConfig(
      id: '${tier.name}_${config.providerType}_${config.modelName}',
      tier: _toCoreTier(tier),
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

  Future<core_provider.ProviderConfig?> getCoreProviderConfig(
    ModelTier tier,
  ) async {
    final config = await getModelConfig(tier);
    if (config == null) {
      return null;
    }

    final apiKey = await _getApiKey(tier);
    return _buildProviderConfig(
      apiKey: apiKey ?? '',
      config: config,
      type: _toCoreProviderType(config.providerType),
    );
  }

  /// 获取功能映射列表
  Future<List<FunctionMapping>> getFunctionMappings() async {
    final prefs = await SharedPreferences.getInstance();
    return AIFunction.values.map((f) {
      final key = '${_keyPrefix}mapping_${f.key}';
      final overrideTierName = prefs.getString(key);
      return FunctionMapping(
        functionKey: f.key,
        overrideTierName: overrideTierName,
        useOverride: overrideTierName != null,
      );
    }).toList();
  }

  /// 获取单个功能的层级覆盖（消费 updateFunctionMapping 写入的值）
  Future<ModelTier?> getFunctionOverrideTier(String functionKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}mapping_$functionKey';
    final tierName = prefs.getString(key);
    if (tierName == null) return null;
    for (final tier in ModelTier.values) {
      if (tier.name == tierName) return tier;
    }
    return null;
  }

  /// 更新功能映射
  Future<void> updateFunctionMapping({
    required String functionKey,
    required ModelTier tier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}mapping_$functionKey';
    await prefs.setString(key, tier.name);
  }

  /// 获取 Prompt 模板列表
  Future<List<PromptTemplate>> getPromptTemplates() async {
    // 返回默认模板
    return [
      PromptTemplate(
        id: 'continuation',
        name: '续写模板',
        description: '用于 AI 续写内容',
        systemPrompt: '你是一位专业的小说作家助手。请根据给定的上下文，自然地续写故事内容。保持文风一致，注意情节连贯性。',
        iconName: 'edit_note',
        createdAt: DateTime.now(),
      ),
      PromptTemplate(
        id: 'dialogue',
        name: '对话生成模板',
        description: '基于角色档案生成对话',
        systemPrompt: '你是一位专业的小说对话作家。请根据角色性格和情境，生成符合角色特点的对话。',
        iconName: 'chat',
        createdAt: DateTime.now(),
      ),
      PromptTemplate(
        id: 'review',
        name: '章节审查模板',
        description: '多维度审查章节质量',
        systemPrompt: '你是一位专业的小说编辑。请从设定一致性、角色OOC、剧情逻辑、节奏把控等维度审查给定的章节内容。',
        iconName: 'rate_review',
        createdAt: DateTime.now(),
      ),
      PromptTemplate(
        id: 'character_sim',
        name: '角色推演模板',
        description: '扮演角色进行行为推演',
        systemPrompt: '请完全沉浸在给定角色的视角中。根据角色的性格、价值观、说话风格和当前情境，推演角色可能的反应、决策和内心活动。',
        iconName: 'person',
        createdAt: DateTime.now(),
      ),
    ];
  }

  /// 保存 Prompt 模板
  Future<void> savePromptTemplate(PromptTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_keyPrefix}prompt_${template.id}';

    await prefs.setString(key, template.id);
    await prefs.setString('${key}_name', template.name);
    await prefs.setString('${key}_description', template.description);
    await prefs.setString('${key}_system', template.systemPrompt);
    if (template.userPromptTemplate != null) {
      await prefs.setString('${key}_user', template.userPromptTemplate!);
    }
    await prefs.setString('${key}_icon', template.iconName);
    await prefs.setInt(
      '${key}_created',
      template.createdAt.millisecondsSinceEpoch,
    );
    if (template.updatedAt != null) {
      await prefs.setInt(
        '${key}_updated',
        template.updatedAt!.millisecondsSinceEpoch,
      );
    }
  }

  /// 获取使用统计（从 Drift 数据库真实记录聚合）
  Future<UsageStats> getUsageStats() async {
    final db = await _getDb();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = DateTime(now.year, now.month - 1, now.day);

    // 查询所有成功记录
    final allRecords = await (db.select(db.aIUsageRecords)
          ..where((t) => t.status.equals('success')))
        .get();

    int todayRequests = 0, todayTokens = 0;
    int weekRequests = 0, weekTokens = 0;
    int monthRequests = 0, monthTokens = 0;
    final byModel = <String, _Accum>{};
    final byFunction = <String, _Accum>{};

    for (final r in allRecords) {
      final ts = r.createdAt;
      final total = r.totalTokens;

      if (ts.isAfter(today)) {
        todayRequests++;
        todayTokens += total;
      }
      if (ts.isAfter(weekAgo)) {
        weekRequests++;
        weekTokens += total;
      }
      if (ts.isAfter(monthAgo)) {
        monthRequests++;
        monthTokens += total;
      }

      byModel.putIfAbsent(r.tier, () => _Accum()).add(total);
      byFunction.putIfAbsent(r.functionType, () => _Accum()).add(total);
    }

    return UsageStats(
      todayRequests: todayRequests,
      todayTokens: todayTokens,
      weekRequests: weekRequests,
      weekTokens: weekTokens,
      monthRequests: monthRequests,
      monthTokens: monthTokens,
      byModel: byModel.map((k, v) => MapEntry(
        k,
        ModelUsageStats(requests: v.count, tokens: v.tokens, estimatedCost: 0),
      )),
      byFunction: byFunction.map((k, v) => MapEntry(
        k,
        FunctionUsageStats(requests: v.count, tokens: v.tokens),
      )),
    );
  }

  Future<AppDatabase> _getDb() async => Get.find<AppDatabase>();

  /// 记录 API 调用
  Future<void> logApiCall({
    required ModelTier tier,
    required AIFunction function,
    required int inputTokens,
    required int outputTokens,
    required bool success,
  }) async {
    await _appendRecord('ai_api_call_history', {
      'timestamp': DateTime.now().toIso8601String(),
      'tier': tier.name,
      'function': function.name,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'totalTokens': inputTokens + outputTokens,
      'success': success,
    }, maxRecords: 1000);
  }

  /// 记录AI配置变更
  Future<void> logConfigChange({
    required ModelTier tier,
    required String changeType,
    required Map<String, dynamic> oldValue,
    required Map<String, dynamic> newValue,
  }) async {
    await _appendRecord('ai_config_change_history', {
      'timestamp': DateTime.now().toIso8601String(),
      'tier': tier.name,
      'changeType': changeType,
      'oldValue': oldValue,
      'newValue': newValue,
    }, maxRecords: 500);
  }

  Future<void> _appendRecord(String key, Map<String, dynamic> record, {required int maxRecords}) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(key) ?? [];
    history.add(jsonEncode(record));
    if (history.length > maxRecords) {
      history.removeRange(0, history.length - maxRecords);
    }
    await prefs.setStringList(key, history);
  }

  /// 获取API调用历史
  Future<List<Map<String, dynamic>>> getApiCallHistory({int limit = 100}) async =>
      _getHistory('ai_api_call_history', limit);

  /// 获取配置变更历史
  Future<List<Map<String, dynamic>>> getConfigChangeHistory({int limit = 100}) async =>
      _getHistory('ai_config_change_history', limit);

  Future<List<Map<String, dynamic>>> _getHistory(String key, int limit) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(key) ?? [])
        .take(limit)
        .map((r) => jsonDecode(r) as Map<String, dynamic>)
        .toList();
  }

  core_provider.ProviderConfig _buildProviderConfig({
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

  core_tier.ModelTier _toCoreTier(ModelTier tier) {
    return switch (tier) {
      ModelTier.thinking => core_tier.ModelTier.thinking,
      ModelTier.middle => core_tier.ModelTier.middle,
      ModelTier.fast => core_tier.ModelTier.fast,
    };
  }

  core_model.AIProviderType _toCoreProviderType(String providerType) {
    return switch (providerType.toLowerCase()) {
      'openai' => core_model.AIProviderType.openai,
      'anthropic' || 'claude' => core_model.AIProviderType.anthropic,
      'ollama' => core_model.AIProviderType.ollama,
      'azure' => core_model.AIProviderType.azure,
      _ => core_model.AIProviderType.custom,
    };
  }
}

class _Accum {
  int count = 0;
  int tokens = 0;
  void add(int t) {
    count++;
    tokens += t;
  }
}
