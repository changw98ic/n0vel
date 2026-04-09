import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'model_config.freezed.dart';
part 'model_config.g.dart';

/// 模型层级
enum ModelTier {
  thinking('深度思考', '复杂推理、深度分析、角色推演', Icons.psychology, Colors.purple),
  middle('平衡模式', '审查、提取、一致性检查', Icons.balance, Colors.blue),
  fast('快速响应', '续写、对话生成、简单任务', Icons.bolt, Colors.green);

  const ModelTier(this.displayName, this.description, this.icon, this.color);

  final String displayName;
  final String description;
  final IconData icon;
  final Color color;
}

/// AI 功能
enum AIFunction {
  continuation('续写', 'AI 续写内容', 'edit_note', 'fast'),
  dialogue('对话生成', '基于角色档案生成对话', 'chat', 'fast'),
  characterSim('角色推演', '扮演角色进行推演', 'person', 'thinking'),
  review('章节审查', '多维度审查章节', 'rate_review', 'middle'),
  extraction('设定提取', '从文本提取设定', 'input', 'middle'),
  consistencyCheck('一致性检查', '检查设定一致性', 'check_circle', 'middle'),
  timelineExtract('时间线提取', '提取时间线事件', 'timeline', 'middle'),
  oocDetection('OOC检测', '检测角色行为是否OOC', 'warning', 'middle'),
  summary('摘要生成', '生成章节摘要', 'summarize', 'fast'),
  povGeneration('视角生成', '生成配角视角内容', 'visibility', 'thinking');

  const AIFunction(this.label, this.description, this.iconName, this.defaultTierName);

  final String label;
  final String description;
  final String iconName;
  final String defaultTierName;

  String get key => name;

  IconData get icon => switch (iconName) {
    'edit_note' => Icons.edit_note,
    'chat' => Icons.chat,
    'person' => Icons.person,
    'rate_review' => Icons.rate_review,
    'input' => Icons.input,
    'check_circle' => Icons.check_circle,
    'timeline' => Icons.timeline,
    'warning' => Icons.warning,
    'summarize' => Icons.summarize,
    'visibility' => Icons.visibility,
    _ => Icons.article,
  };

  ModelTier get defaultTier => switch (defaultTierName) {
    'thinking' => ModelTier.thinking,
    'middle' => ModelTier.middle,
    'fast' => ModelTier.fast,
    _ => ModelTier.middle,
  };

  static AIFunction? fromKey(String key) {
    try {
      return values.firstWhere((f) => f.key == key);
    } catch (_) {
      return null;
    }
  }
}

/// 模型配置
@freezed
class ModelConfig with _$ModelConfig {
  const factory ModelConfig({
    required ModelTier tier,
    required String providerType,
    required String modelName,
    String? apiEndpoint,
    @Default(0.7) double temperature,
    @Default(4096) int maxOutputTokens,
    @Default(1.0) double topP,
    @Default(0.0) double frequencyPenalty,
    @Default(0.0) double presencePenalty,
    @Default(true) bool isEnabled,
    DateTime? lastValidatedAt,
    @Default(false) bool isValid,
  }) = _ModelConfig;

  factory ModelConfig.fromJson(Map<String, dynamic> json) =>
      _$ModelConfigFromJson(json);
}

/// 功能映射配置
@freezed
class FunctionMapping with _$FunctionMapping {
  const FunctionMapping._();

  const factory FunctionMapping({
    required String functionKey,
    String? overrideTierName,
    @Default(false) bool useOverride,
  }) = _FunctionMapping;

  factory FunctionMapping.fromJson(Map<String, dynamic> json) =>
      _$FunctionMappingFromJson(json);

  ModelTier? get overrideTier {
    if (overrideTierName == null) return null;
    return switch (overrideTierName) {
      'thinking' => ModelTier.thinking,
      'middle' => ModelTier.middle,
      'fast' => ModelTier.fast,
      _ => null,
    };
  }

  AIFunction? get function => AIFunction.fromKey(functionKey);
}

/// Prompt 模板
class PromptTemplate {
  final String id;
  final String name;
  final String description;
  final String systemPrompt;
  final String? userPromptTemplate;
  final String iconName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  PromptTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.userPromptTemplate,
    required this.iconName,
    required this.createdAt,
    this.updatedAt,
  });

  IconData get icon => switch (iconName) {
    'edit_note' => Icons.edit_note,
    'chat' => Icons.chat,
    'person' => Icons.person,
    'rate_review' => Icons.rate_review,
    'extract' => Icons.input,
    'check_circle' => Icons.check_circle,
    'timeline' => Icons.timeline,
    'warning' => Icons.warning,
    'summarize' => Icons.summarize,
    'visibility' => Icons.visibility,
    _ => Icons.article,
  };
}

/// 使用统计
class UsageStats {
  final int todayRequests;
  final int todayTokens;
  final int weekRequests;
  final int weekTokens;
  final int monthRequests;
  final int monthTokens;
  final Map<String, ModelUsageStats> byModel;
  final Map<String, FunctionUsageStats> byFunction;

  UsageStats({
    required this.todayRequests,
    required this.todayTokens,
    required this.weekRequests,
    required this.weekTokens,
    required this.monthRequests,
    required this.monthTokens,
    required this.byModel,
    required this.byFunction,
  });
}

class ModelUsageStats {
  final int requests;
  final int tokens;
  final double estimatedCost;

  ModelUsageStats({
    required this.requests,
    required this.tokens,
    required this.estimatedCost,
  });
}

class FunctionUsageStats {
  final int requests;
  final int tokens;

  FunctionUsageStats({
    required this.requests,
    required this.tokens,
  });
}
