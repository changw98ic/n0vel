import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';

/// 场景中的角色信息（轻量级）
class CharacterInScene {
  final String name;
  final String? personality;
  final String? speechStyle;
  final String? currentMood;

  const CharacterInScene({
    required this.name,
    this.personality,
    this.speechStyle,
    this.currentMood,
  });
}

/// 写作辅助服务
/// 提供实时 AI 写作建议：续写、对话生成、场景描写
class WritingAssistService {
  final AIService _aiService;

  WritingAssistService({required AIService aiService}) : _aiService = aiService;

  /// 续写建议 — 根据上下文生成续写选项
  /// Returns [count] continuation suggestions (default 3)
  Future<List<String>> suggestContinuations({
    required String precedingText,
    required String workId,
    int count = 3,
  }) async {
    try {
      // 取最后约 1000 个字符作为上下文
      final context = precedingText.length > 1000
          ? precedingText.substring(precedingText.length - 1000)
          : precedingText;

      final prompt = '''
请根据以下小说片段，给出$count个不同方向的续写建议。
每个建议应该风格各异，有的侧重情节推进，有的侧重人物心理，有的侧重环境描写。

要求：
- 每个续写建议约 100-200 字
- 用编号列出（1. 2. 3.）
- 续写内容应与上文风格和语气保持一致
- 不要重复已有内容

上文：
$context''';

      final config = AIRequestConfig(
        function: AIFunction.continuation,
        userPrompt: prompt,
        temperature: 0.8,
        maxTokens: 1500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return _parseNumberedSuggestions(response.content, count);
    } catch (e) {
      return [];
    }
  }

  /// 对话生成 — 根据在场角色和场景生成对话
  Future<List<String>> generateDialogue({
    required String sceneContext,
    required List<CharacterInScene> characters,
    required String workId,
    int count = 3,
  }) async {
    try {
      final characterDescriptions = characters.map((c) {
        final parts = <String>['角色：${c.name}'];
        if (c.personality != null) {
          parts.add('性格：${c.personality}');
        }
        if (c.speechStyle != null) {
          parts.add('说话风格：${c.speechStyle}');
        }
        if (c.currentMood != null) {
          parts.add('当前情绪：${c.currentMood}');
        }
        return parts.join('，');
      }).join('\n');

      final prompt = '''
请根据以下场景和角色信息，生成$count组对话。

场景描述：
$sceneContext

在场角色：
$characterDescriptions

要求：
- 每组对话应体现角色的说话风格和性格特点
- 对话应推动情节发展或深化角色关系
- 用编号列出每组对话（1. 2. 3.）
- 每组对话包含 3-6 轮交锋
- 对话格式：角色名：「台词」''';

      final config = AIRequestConfig(
        function: AIFunction.dialogue,
        userPrompt: prompt,
        temperature: 0.85,
        maxTokens: 2000,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return _parseNumberedSuggestions(response.content, count);
    } catch (e) {
      return [];
    }
  }

  /// 场景描写辅助 — 基于地点设定生成描写
  Future<String> suggestSceneDescription({
    required String locationName,
    required String locationDescription,
    required String currentContext,
    required String workId,
  }) async {
    try {
      final prompt = '''
请根据以下地点设定和当前情节，生成一段富有画面感的场景描写。

地点名称：$locationName
地点设定：$locationDescription

当前情节上下文：
$currentContext

要求：
- 融合视觉（看到的）、听觉（听到的）、嗅觉（闻到的）、触觉（感受到的）等多种感官描写
- 描写应服务于当前情节氛围
- 篇幅约 150-300 字
- 语言应与上下文风格一致
- 不要包含角色对话，只描写环境''';

      final config = AIRequestConfig(
        function: AIFunction.continuation,
        userPrompt: prompt,
        temperature: 0.7,
        maxTokens: 600,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return response.content.trim();
    } catch (e) {
      return '';
    }
  }

  /// 获取写作提示 — 当作者卡住时给出方向建议
  Future<String> getWritingPrompt({
    required String currentText,
    required String chapterOutline,
    required String workId,
  }) async {
    try {
      final prompt = '''
你是一位经验丰富的小说创作顾问。作者正在写作中遇到了瓶颈，请根据以下信息给出创作方向建议。

当前已写内容（最后部分）：
${currentText.length > 800 ? currentText.substring(currentText.length - 800) : currentText}

本章大纲/计划：
$chapterOutline

请从以下角度给出建议：
1. 情节推进：接下来可以发生什么事件？
2. 角色发展：角色在这一刻可以有什么内心变化？
3. 冲突设计：可以引入什么样的新冲突或张力？
4. 氛围营造：可以怎样调整叙事节奏？

请给出具体、可操作的建议，而不是泛泛而谈。''';

      final config = AIRequestConfig(
        function: AIFunction.review,
        overrideTier: ModelTier.thinking,
        userPrompt: prompt,
        temperature: 0.9,
        maxTokens: 1200,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return response.content.trim();
    } catch (e) {
      return '';
    }
  }

  /// 从 AI 回复中解析编号建议
  /// 支持格式：1. xxx / 1、xxx / 一、xxx / 第一，xxx
  List<String> _parseNumberedSuggestions(String content, int expectedCount) {
    final results = <String>[];

    // 尝试按编号分割
    // 匹配模式：数字+点/顿号 开头，或者中文数字+顿号开头
    final regex = RegExp(
      r'(?:^|\n)\s*(?:\d+[.、．)\s]|[一二三四五六七八九十]+[、)])\s*',
    );

    final matches = regex.allMatches(content).toList();

    if (matches.length >= 2) {
      for (var i = 0; i < matches.length && results.length < expectedCount; i++) {
        final start = matches[i].end;
        final end =
            i + 1 < matches.length ? matches[i + 1].start : content.length;
        final suggestion = content.substring(start, end).trim();
        if (suggestion.isNotEmpty) {
          results.add(suggestion);
        }
      }
    }

    // 如果编号解析失败，尝试按段落分割
    if (results.isEmpty) {
      final paragraphs = content
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      for (final paragraph in paragraphs.take(expectedCount)) {
        // 去掉开头的编号
        final cleaned = paragraph.replaceFirst(
          RegExp(r'^\s*(?:\d+[.、．)\s]|[一二三四五六七八九十]+[、)])\s*'),
          '',
        );
        if (cleaned.isNotEmpty) {
          results.add(cleaned);
        }
      }
    }

    // 如果仍然没有结果，按换行分割取前 N 条非空行
    if (results.isEmpty) {
      final lines = content
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      for (final line in lines.take(expectedCount)) {
        final cleaned = line.replaceFirst(
          RegExp(r'^\s*(?:\d+[.、．)\s]|[一二三四五六七八九十]+[、)])\s*'),
          '',
        );
        if (cleaned.isNotEmpty) {
          results.add(cleaned);
        }
      }
    }

    return results;
  }
}
