import 'ai/models/model_tier.dart';
import 'writer_runtime_hooks.dart';

/// 写作意图类型
enum WriterIntent {
  chapterWriting('chapter-writing'),
  entityCreation('entity-creation'),
  review('review'),
  consistencyCheck('consistency-check'),
  worldbuilding('worldbuilding'),
  dialogueGeneration('dialogue-generation'),
  contentSearch('content-search'),
  contentGeneration('content-generation'),
  planning('planning'),
  generalChat('general-chat');

  final String key;
  const WriterIntent(this.key);
}

/// 意图解析结果
class IntentResolution {
  final WriterIntent intent;
  final String skillId;
  final String agentId;
  final String? teamId;
  final List<String> runtimePaths;
  final HookRuleType ruleType;
  final double confidence;

  const IntentResolution({
    required this.intent,
    required this.skillId,
    required this.agentId,
    this.teamId,
    required this.runtimePaths,
    required this.ruleType,
    required this.confidence,
  });
}

/// 统一意图路由器
/// 将用户任务解析为具体的 skill/agent/team/ruleType/runtimePaths
class WriterIntentResolver {
  /// 从用户任务文本解析意图
  IntentResolution resolve(String task) {
    final lower = task.toLowerCase();

    // ── 优先级从高到低匹配 ──

    // 章节创作
    if (_matches(lower, ['章节', '正文', '续写', 'chapter', '第1章', '第一章', '写一章'])) {
      return IntentResolution(
        intent: WriterIntent.chapterWriting,
        skillId: 'chapter-writing',
        agentId: 'writer-agent',
        runtimePaths: const ['lib/core/services/ai/', 'lib/modules/editor/'],
        ruleType: HookRuleType.chapterBody,
        confidence: 0.9,
      );
    }

    // 世界观设定
    if (_matches(lower, ['世界观', 'worldbuilding', '力量体系', '设定体系', '核心设定'])) {
      return IntentResolution(
        intent: WriterIntent.worldbuilding,
        skillId: 'entity-creation',
        agentId: 'writer-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.worldbuilding,
        confidence: 0.85,
      );
    }

    // 对话生成
    if (_matches(lower, ['对话', '对白', 'dialogue', '台词'])) {
      return IntentResolution(
        intent: WriterIntent.dialogueGeneration,
        skillId: 'chapter-writing',
        agentId: 'editor-agent',
        runtimePaths: const ['lib/core/services/ai/', 'lib/modules/editor/'],
        ruleType: HookRuleType.dialogueSnippet,
        confidence: 0.85,
      );
    }

    // 一致性检查
    if (_matches(lower, ['一致性', 'consistency', '设定冲突', 'ooc'])) {
      return IntentResolution(
        intent: WriterIntent.consistencyCheck,
        skillId: 'review-analysis',
        agentId: 'reviewer-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.general,
        confidence: 0.9,
      );
    }

    // 审查
    if (_matches(lower, ['审查', '评审', 'review', '节奏', '视角'])) {
      return IntentResolution(
        intent: WriterIntent.review,
        skillId: 'review-analysis',
        agentId: 'reviewer-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.general,
        confidence: 0.85,
      );
    }

    // 实体创建
    if (_matches(lower, ['角色', '地点', '物品', '势力', '关系', 'create', 'character', 'entity'])) {
      return IntentResolution(
        intent: WriterIntent.entityCreation,
        skillId: 'entity-creation',
        agentId: 'writer-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.entityBio,
        confidence: 0.85,
      );
    }

    // 内容搜索
    if (_matches(lower, ['搜索', '查找', 'search', 'list'])) {
      return IntentResolution(
        intent: WriterIntent.contentSearch,
        skillId: 'content-management',
        agentId: 'writer-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.general,
        confidence: 0.8,
      );
    }

    // 内容生成/提取
    if (_matches(lower, ['生成', 'generate', '提取', 'extract', '设定提取'])) {
      return IntentResolution(
        intent: WriterIntent.contentGeneration,
        skillId: 'content-generation',
        agentId: 'extractor-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.general,
        confidence: 0.8,
      );
    }

    // 规划
    if (_matches(lower, ['规划', '大纲', '计划', 'plan', 'plot'])) {
      return IntentResolution(
        intent: WriterIntent.planning,
        skillId: 'content-generation',
        agentId: 'planner-agent',
        runtimePaths: const ['lib/core/services/ai/'],
        ruleType: HookRuleType.general,
        confidence: 0.8,
      );
    }

    // 默认：通用对话
    return const IntentResolution(
      intent: WriterIntent.generalChat,
      skillId: 'chapter-writing',
      agentId: 'writer-agent',
      runtimePaths: ['lib/core/services/ai/', 'lib/modules/editor/'],
      ruleType: HookRuleType.general,
      confidence: 0.3,
    );
  }

  /// 从 AIFunction 映射（用于非对话场景的确定性路由）
  IntentResolution resolveFromFunction(AIFunction function) {
    return switch (function) {
      AIFunction.continuation || AIFunction.dialogue => IntentResolution(
          intent: WriterIntent.chapterWriting,
          skillId: 'chapter-writing',
          agentId: 'writer-agent',
          runtimePaths: const ['lib/core/services/ai/', 'lib/modules/editor/'],
          ruleType: HookRuleType.chapterBody,
          confidence: 1.0,
        ),
      AIFunction.characterSimulation || AIFunction.povGeneration => IntentResolution(
          intent: WriterIntent.dialogueGeneration,
          skillId: 'chapter-writing',
          agentId: 'editor-agent',
          runtimePaths: const ['lib/core/services/ai/', 'lib/modules/editor/'],
          ruleType: HookRuleType.dialogueSnippet,
          confidence: 1.0,
        ),
      AIFunction.review ||
      AIFunction.pacingAnalysis ||
      AIFunction.perspectiveCheck ||
      AIFunction.aiStyleDetection => IntentResolution(
          intent: WriterIntent.review,
          skillId: 'review-analysis',
          agentId: 'reviewer-agent',
          runtimePaths: const ['lib/core/services/ai/'],
          ruleType: HookRuleType.general,
          confidence: 1.0,
        ),
      AIFunction.consistencyCheck || AIFunction.oocDetection => IntentResolution(
          intent: WriterIntent.consistencyCheck,
          skillId: 'review-analysis',
          agentId: 'reviewer-agent',
          runtimePaths: const ['lib/core/services/ai/'],
          ruleType: HookRuleType.general,
          confidence: 1.0,
        ),
      AIFunction.extraction || AIFunction.entityExtraction => IntentResolution(
          intent: WriterIntent.contentGeneration,
          skillId: 'content-generation',
          agentId: 'extractor-agent',
          runtimePaths: const ['lib/core/services/ai/'],
          ruleType: HookRuleType.general,
          confidence: 1.0,
        ),
      AIFunction.timelineExtract => IntentResolution(
          intent: WriterIntent.consistencyCheck,
          skillId: 'review-analysis',
          agentId: 'reviewer-agent',
          runtimePaths: const ['lib/core/services/ai/'],
          ruleType: HookRuleType.general,
          confidence: 1.0,
        ),
      AIFunction.entityCreation => IntentResolution(
          intent: WriterIntent.entityCreation,
          skillId: 'entity-creation',
          agentId: 'writer-agent',
          runtimePaths: const ['lib/core/services/ai/'],
          ruleType: HookRuleType.entityBio,
          confidence: 1.0,
        ),
      AIFunction.planning => IntentResolution(
          intent: WriterIntent.planning,
          skillId: 'content-generation',
          agentId: 'planner-agent',
          runtimePaths: const ['lib/core/services/ai/'],
          ruleType: HookRuleType.general,
          confidence: 1.0,
        ),
      AIFunction.chat => IntentResolution(
          intent: WriterIntent.generalChat,
          skillId: 'chapter-writing',
          agentId: 'writer-agent',
          runtimePaths: const ['lib/core/services/ai/', 'lib/modules/editor/'],
          ruleType: HookRuleType.general,
          confidence: 1.0,
        ),
    };
  }

  bool _matches(String lower, List<String> keywords) {
    return keywords.any(lower.contains);
  }
}
