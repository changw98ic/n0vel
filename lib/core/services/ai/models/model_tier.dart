/// AI 模型层级枚举
/// 三层模型体系：Thinking/Middle/Fast
enum ModelTier {
  /// 思考层 - 复杂推理、深度分析、角色推演
  thinking(
    name: '深度思考',
    description: '复杂推理、深度分析、角色推演',
    priority: 0,
  ),

  /// 中间层 - 平衡性能与成本
  middle(
    name: '平衡模式',
    description: '章节审查、设定提取、一致性检查',
    priority: 1,
  ),

  /// 快速层 - 快速响应、低成本
  fast(
    name: '快速响应',
    description: '续写、对话生成、简单任务',
    priority: 2,
  );

  const ModelTier({
    required this.name,
    required this.description,
    required this.priority,
  });

  final String name;
  final String description;
  final int priority;

  /// 从字符串解析
  static ModelTier? fromString(String value) {
    return switch (value.toLowerCase()) {
      'thinking' => ModelTier.thinking,
      'middle' => ModelTier.middle,
      'fast' => ModelTier.fast,
      _ => null,
    };
  }
}

/// AI 功能类型
/// 用于自动映射到对应的模型层级
enum AIFunction {
  /// 续写 → Fast
  continuation('continuation', ModelTier.fast),

  /// 对话生成 → Fast
  dialogue('dialogue', ModelTier.fast),

  /// 角色推演 → Thinking
  characterSimulation('character_simulation', ModelTier.thinking),

  /// 章节审查 → Middle
  review('review', ModelTier.middle),

  /// 设定提取 → Middle
  extraction('extraction', ModelTier.middle),

  /// 一致性检查 → Middle
  consistencyCheck('consistency_check', ModelTier.middle),

  /// 时间线提取 → Middle
  timelineExtract('timeline_extract', ModelTier.middle),

  /// OOC检测 → Middle
  oocDetection('ooc_detection', ModelTier.middle),

  /// AI口吻检测 → Middle
  aiStyleDetection('ai_style_detection', ModelTier.middle),

  /// 视角检测 → Middle
  perspectiveCheck('perspective_check', ModelTier.middle),

  /// 节奏分析 → Middle
  pacingAnalysis('pacing_analysis', ModelTier.middle),

  /// 配角视角生成 → Thinking
  povGeneration('pov_generation', ModelTier.thinking),

  /// AI 对话 → Fast
  chat('chat', ModelTier.fast),

  /// 实体创建 → Thinking
  entityCreation('entity_creation', ModelTier.thinking),

  /// 实体提取 → Middle
  entityExtraction('entity_extraction', ModelTier.middle);

  const AIFunction(this.key, this.defaultTier);

  final String key;
  final ModelTier defaultTier;

  static AIFunction? fromKey(String key) {
    return values.cast<AIFunction?>().firstWhere(
          (f) => f?.key == key,
          orElse: () => null,
        );
  }
}
