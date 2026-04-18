import 'models/model_tier.dart';

class AIPromptBuilder {
  const AIPromptBuilder();

  String buildSystemPrompt({
    required AIFunction function,
    String? overridePrompt,
    required bool respondInChinese,
  }) {
    final basePrompt = overridePrompt ?? _getDefaultSystemPrompt(function);
    final languageDirective = respondInChinese
        ? '请务必使用中文回复。'
        : 'Please respond in English.';
    return '$basePrompt\n$languageDirective';
  }

  String buildUserPrompt(
    String prompt, {
    Map<String, dynamic>? variables,
  }) {
    var result = prompt;
    if (variables != null) {
      variables.forEach((key, value) {
        result = result.replaceAll('{$key}', value.toString());
      });
    }
    return result;
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
      AIFunction.entityCreation =>
        '你是一位专业的小说设定创建助手。根据用户的描述生成完整的角色、地点、物品或势力设定。',
      AIFunction.entityExtraction => '你是一位专业的设定提取助手，请从文本中提取角色、地点、物品等实体信息。',
    };
  }
}
