import 'dart:convert';

import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';

/// 角色模拟结果
class SimulationResult {
  final String characterName;
  final String reaction; // 角色反应（行为+心理）
  final String? dialogue; // 角色可能说的话
  final String? innerThought; // 内心独白
  final String? emotionalState; // 情绪状态描述
  final int inputTokens;
  final int outputTokens;

  const SimulationResult({
    required this.characterName,
    required this.reaction,
    this.dialogue,
    this.innerThought,
    this.emotionalState,
    required this.inputTokens,
    required this.outputTokens,
  });
}

/// 场景上下文
class SimulationContext {
  final String sceneDescription;
  final String? precedingEvents; // 前情
  final List<String>? presentCharacters; // 在场其他角色名
  final String? locationName;
  final String? timeOfDay;
  final String? atmosphere; // 氛围描述

  const SimulationContext({
    required this.sceneDescription,
    this.precedingEvents,
    this.presentCharacters,
    this.locationName,
    this.timeOfDay,
    this.atmosphere,
  });
}

/// 对话行
class DialogueLine {
  final String characterName;
  final String dialogue;
  final String? stageDirection; // 舞台指示（动作/表情）
  final String? innerThought;

  const DialogueLine({
    required this.characterName,
    required this.dialogue,
    this.stageDirection,
    this.innerThought,
  });
}

/// 角色简要档案（用于对话模拟）
class SimCharacterProfile {
  final String name;
  final String? personality;
  final String? speechStyle;
  final String? coreValues;
  final String? currentMood;

  const SimCharacterProfile({
    required this.name,
    this.personality,
    this.speechStyle,
    this.coreValues,
    this.currentMood,
  });
}

/// OOC 分析结果
class OOCAnalysis {
  final bool isOOC;
  final double confidence; // 0.0-1.0
  final String? explanation; // 为什么判定 OOC
  final String? suggestion; // 修改建议

  const OOCAnalysis({
    required this.isOOC,
    required this.confidence,
    this.explanation,
    this.suggestion,
  });
}

/// 角色模拟服务
/// 根据角色设定和场景上下文，模拟角色的行为、对话和心理活动
class CharacterSimulationService {
  final AIService _aiService;

  CharacterSimulationService({required AIService aiService})
      : _aiService = aiService;

  // ---------------------------------------------------------------------------
  // simulateCharacter
  // ---------------------------------------------------------------------------

  /// 模拟单个角色在场景中的反应
  Future<SimulationResult> simulateCharacter({
    required String characterName,
    required String characterProfile, // JSON string of character data
    required SimulationContext context,
    required String workId,
  }) async {
    try {
      final profileSection = _buildProfileSection(characterProfile);
      final contextSection = _buildContextSection(context);

      final systemPrompt = '''你是一位专业的角色扮演推演引擎。你的任务是根据角色的完整档案和给定场景，精确模拟该角色在场景中的反应。

你必须严格遵循角色的性格设定、行为模式、语言风格和价值观。你的模拟结果应当让人感到"这就是这个角色会做的事"。

请严格按照以下 JSON 格式输出，不要输出任何其他内容：
{
  "reaction": "角色的行为和心理反应描述",
  "dialogue": "角色说出的话（如有），无对话则为空字符串",
  "innerThought": "角色的内心独白",
  "emotionalState": "角色当前的情绪状态描述"
}''';

      final prompt = '''请模拟以下角色在给定场景中的反应。

## 角色档案
角色名：$characterName
$profileSection

## 场景信息
$contextSection

请严格按照角色设定进行推演，输出 JSON 格式的结果。''';

      final config = AIRequestConfig(
        function: AIFunction.characterSimulation,
        systemPrompt: systemPrompt,
        userPrompt: prompt,
        temperature: 0.75,
        maxTokens: 1500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      final parsed = _parseSimulationResponse(response.content);

      return SimulationResult(
        characterName: characterName,
        reaction: parsed['reaction'] ?? '角色陷入沉默，目光微微闪烁。',
        dialogue: parsed['dialogue'],
        innerThought: parsed['innerThought'],
        emotionalState: parsed['emotionalState'],
        inputTokens: response.inputTokens,
        outputTokens: response.outputTokens,
      );
    } catch (e) {
      return SimulationResult(
        characterName: characterName,
        reaction: '角色陷入沉默，目光微微闪烁。（模拟失败：$e）',
        inputTokens: 0,
        outputTokens: 0,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // simulateDialogue
  // ---------------------------------------------------------------------------

  /// 模拟角色间对话
  Future<List<DialogueLine>> simulateDialogue({
    required List<SimCharacterProfile> characters,
    required SimulationContext context,
    required String topic, // 对话主题
    int turns = 4, // 对话轮数
    required String workId,
  }) async {
    if (characters.isEmpty) return [];
    if (characters.length == 1) {
      // 单角色：生成内心独白式的自言自语
      return _simulateMonologue(characters.first, context, topic, workId);
    }

    try {
      final charactersSection = characters.map((c) {
        final parts = <String>['【${c.name}】'];
        if (c.personality != null) parts.add('性格：${c.personality}');
        if (c.speechStyle != null) parts.add('语言风格：${c.speechStyle}');
        if (c.coreValues != null) parts.add('核心价值观：${c.coreValues}');
        if (c.currentMood != null) parts.add('当前情绪：${c.currentMood}');
        return parts.join('\n');
      }).join('\n\n');

      final contextSection = _buildContextSection(context);

      final systemPrompt = '''你是一位专业的小说对话作家。你的任务是根据角色的设定和场景，生成角色之间自然、生动的对话。

要求：
1. 每个角色的对话必须严格符合其语言风格和性格设定
2. 对话应推动情节发展或深化角色关系
3. 包含适当的舞台指示（动作、表情、小动作）
4. 对话应有来有往，体现角色间的化学反应

请严格按照以下 JSON 数组格式输出，不要输出任何其他内容：
[
  {
    "characterName": "说话角色名",
    "dialogue": "角色说的话",
    "stageDirection": "舞台指示（动作/表情）",
    "innerThought": "角色内心想法（可选）"
  }
]''';

      final prompt = '''请根据以下信息，模拟 $turns 轮角色对话。

## 对话主题
$topic

## 参与角色
$charactersSection

## 场景信息
$contextSection

请生成 $turns 轮对话（每轮包含一个角色的发言），严格按照 JSON 数组格式输出。''';

      final config = AIRequestConfig(
        function: AIFunction.characterSimulation,
        systemPrompt: systemPrompt,
        userPrompt: prompt,
        temperature: 0.85,
        maxTokens: 2500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return _parseDialogueLines(response.content);
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // analyzeCharacterBehavior (OOC detection)
  // ---------------------------------------------------------------------------

  /// 检测角色行为是否符合设定（OOC检测辅助）
  Future<OOCAnalysis> analyzeCharacterBehavior({
    required String characterName,
    required String characterProfile,
    required String textToAnalyze,
    required String workId,
  }) async {
    try {
      final profileSection = _buildProfileSection(characterProfile);

      final systemPrompt = '''你是一位专业的角色 OOC（Out of Character）检测专家。你的任务是比对角色的完整设定与给定文本中该角色的表现，判断角色行为是否偏离设定。

你需要从以下维度进行分析：
1. **语言风格一致性**：对话的措辞、句式、语气是否符合角色设定的语言风格
2. **行为逻辑一致性**：角色的行为反应是否符合其性格特征和行为模式
3. **情感合理性**：角色的情绪表现是否符合其人格特质和当前情境
4. **价值观一致性**：角色的决策和态度是否符合其核心价值观和道德基线

请严格按照以下 JSON 格式输出，不要输出任何其他内容：
{
  "isOOC": true或false,
  "confidence": 0.0到1.0之间的数值,
  "explanation": "判定理由的详细说明",
  "suggestion": "如果不一致，给出修改建议；如果一致，给出空字符串"
}''';

      final prompt = '''请检测以下文本中角色"${characterName}"的表现是否偏离设定。

## 角色设定
$profileSection

## 待分析文本
$textToAnalyze

请逐维度分析，输出 JSON 格式的判定结果。''';

      final config = AIRequestConfig(
        function: AIFunction.oocDetection,
        systemPrompt: systemPrompt,
        userPrompt: prompt,
        temperature: 0.3,
        maxTokens: 1200,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return _parseOOCAnalysis(response.content);
    } catch (e) {
      return OOCAnalysis(
        isOOC: false,
        confidence: 0.0,
        explanation: 'OOC 分析失败：$e',
      );
    }
  }

  // ===========================================================================
  // Private helpers
  // ===========================================================================

  /// 从 JSON 字符串构建可读的角色档案段落
  String _buildProfileSection(String characterProfileJson) {
    try {
      final data = json.decode(characterProfileJson) as Map<String, dynamic>;
      final sections = <String>[];

      // MBTI
      final mbti = data['mbti'];
      if (mbti != null) {
        sections.add('MBTI 人格类型：$mbti');
      }

      // 大五人格
      final bigFive = data['bigFive'];
      if (bigFive != null && bigFive is Map) {
        final dims = <String>[];
        final openness = bigFive['openness'];
        final conscientiousness = bigFive['conscientiousness'];
        final extraversion = bigFive['extraversion'];
        final agreeableness = bigFive['agreeableness'];
        final neuroticism = bigFive['neuroticism'];
        if (openness != null) dims.add('开放性 $openness');
        if (conscientiousness != null) dims.add('尽责性 $conscientiousness');
        if (extraversion != null) dims.add('外向性 $extraversion');
        if (agreeableness != null) dims.add('宜人性 $agreeableness');
        if (neuroticism != null) dims.add('神经质 $neuroticism');
        if (dims.isNotEmpty) sections.add('大五人格：${dims.join("，")}');
      }

      // 性格关键词
      final personalityKeywords = data['personalityKeywords'];
      if (personalityKeywords is List && personalityKeywords.isNotEmpty) {
        sections.add('性格关键词：${personalityKeywords.join("、")}');
      }

      // 核心价值观
      final coreValues = data['coreValues'];
      if (coreValues != null && coreValues.toString().isNotEmpty) {
        sections.add('核心价值观：$coreValues');
      }

      // 恐惧
      final fears = data['fears'];
      if (fears != null && fears.toString().isNotEmpty) {
        sections.add('恐惧：$fears');
      }

      // 欲望
      final desires = data['desires'];
      if (desires != null && desires.toString().isNotEmpty) {
        sections.add('欲望：$desires');
      }

      // 道德基线
      final moralBaseline = data['moralBaseline'];
      if (moralBaseline != null && moralBaseline.toString().isNotEmpty) {
        sections.add('道德基线：$moralBaseline');
      }

      // 语言风格
      final speechStyle = data['speechStyle'];
      if (speechStyle is Map) {
        final speechParts = <String>[];
        final languageStyle = speechStyle['languageStyle'];
        final toneStyle = speechStyle['toneStyle'];
        final speed = speechStyle['speed'];
        final catchphrases = speechStyle['catchphrases'];
        final sentencePatterns = speechStyle['sentencePatterns'];
        final vocabularyPreferences = speechStyle['vocabularyPreferences'];
        final tabooWords = speechStyle['tabooWords'];

        if (languageStyle != null) speechParts.add('语言风格：$languageStyle');
        if (toneStyle != null) speechParts.add('语气：$toneStyle');
        if (speed != null) speechParts.add('语速：$speed');
        if (catchphrases is List && catchphrases.isNotEmpty) {
          speechParts.add('口头禅：${catchphrases.join("、")}');
        }
        if (sentencePatterns is List && sentencePatterns.isNotEmpty) {
          speechParts.add('句式偏好：${sentencePatterns.join("、")}');
        }
        if (vocabularyPreferences is List && vocabularyPreferences.isNotEmpty) {
          speechParts.add('词汇偏好：${vocabularyPreferences.join("、")}');
        }
        if (tabooWords is List && tabooWords.isNotEmpty) {
          speechParts.add('避讳词：${tabooWords.join("、")}');
        }
        if (speechParts.isNotEmpty) {
          sections.add('语言风格设定：\n${speechParts.map((p) => "  - $p").join("\n")}');
        }
      }

      // 行为模式
      final behaviorPatterns = data['behaviorPatterns'];
      if (behaviorPatterns is List && behaviorPatterns.isNotEmpty) {
        final patternDescs = behaviorPatterns.map((p) {
          if (p is Map) {
            final trigger = p['trigger'] ?? '';
            final behavior = p['behavior'] ?? '';
            final desc = p['description'];
            if (desc != null && desc.toString().isNotEmpty) {
              return '  - 当"$trigger"时 → "$behavior"（$desc）';
            }
            return '  - 当"$trigger"时 → "$behavior"';
          }
          return null;
        }).whereType<String>().toList();
        if (patternDescs.isNotEmpty) {
          sections.add('行为模式：\n${patternDescs.join("\n")}');
        }
      }

      // 台词示例
      final speechExamples = data['speechStyle'] is Map
          ? (data['speechStyle'] as Map)['examples']
          : null;
      if (speechExamples is List && speechExamples.isNotEmpty) {
        final examples = speechExamples.map((e) {
          if (e is Map) {
            final scene = e['scene'] ?? '';
            final emotion = e['emotion'] ?? '';
            final line = e['line'] ?? '';
            return '  - [$scene / $emotion] "$line"';
          }
          return null;
        }).whereType<String>().toList();
        if (examples.isNotEmpty) {
          sections.add('台词示例：\n${examples.join("\n")}');
        }
      }

      // 其他文本字段兜底：如果 JSON 解析后没有匹配到任何已知字段，
      // 将原始 JSON 作为补充信息
      if (sections.isEmpty) {
        sections.add('原始档案：$characterProfileJson');
      } else {
        // 检查是否有未处理的顶层字段
        final knownKeys = {
          'mbti', 'bigFive', 'personalityKeywords', 'coreValues',
          'fears', 'desires', 'moralBaseline', 'speechStyle',
          'behaviorPatterns',
        };
        final extraKeys =
            data.keys.where((k) => !knownKeys.contains(k)).toList();
        if (extraKeys.isNotEmpty) {
          final extras = extraKeys
              .map((k) => '$k：${data[k]}')
              .where((s) => s.isNotEmpty)
              .join('；');
          if (extras.isNotEmpty) sections.add('其他设定：$extras');
        }
      }

      return sections.join('\n\n');
    } catch (_) {
      // JSON 解析失败，直接作为文本使用
      return characterProfileJson;
    }
  }

  /// 从 SimulationContext 构建可读的场景信息段落
  String _buildContextSection(SimulationContext context) {
    final parts = <String>[];

    parts.add('场景描述：${context.sceneDescription}');

    if (context.precedingEvents != null &&
        context.precedingEvents!.isNotEmpty) {
      parts.add('前情提要：${context.precedingEvents}');
    }

    if (context.locationName != null && context.locationName!.isNotEmpty) {
      parts.add('地点：${context.locationName}');
    }

    if (context.timeOfDay != null && context.timeOfDay!.isNotEmpty) {
      parts.add('时间：${context.timeOfDay}');
    }

    if (context.atmosphere != null && context.atmosphere!.isNotEmpty) {
      parts.add('氛围：${context.atmosphere}');
    }

    if (context.presentCharacters != null &&
        context.presentCharacters!.isNotEmpty) {
      parts.add('在场其他角色：${context.presentCharacters!.join("、")}');
    }

    return parts.join('\n');
  }

  /// 解析 simulateCharacter 的 AI 回复为结构化数据
  Map<String, String?> _parseSimulationResponse(String content) {
    try {
      // 尝试提取 JSON 块
      final jsonStr = _extractJsonBlock(content);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          return {
            'reaction': decoded['reaction']?.toString(),
            'dialogue': decoded['dialogue']?.toString(),
            'innerThought': decoded['innerThought']?.toString(),
            'emotionalState': decoded['emotionalState']?.toString(),
          };
        }
      }
    } catch (_) {
      // JSON 解析失败，尝试从文本中提取
    }

    // Fallback: 将整个回复作为 reaction
    return {'reaction': content.trim()};
  }

  /// 解析 simulateDialogue 的 AI 回复为 DialogueLine 列表
  List<DialogueLine> _parseDialogueLines(String content) {
    try {
      final jsonStr = _extractJsonBlock(content);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        if (decoded is List) {
          return decoded.map((item) {
            if (item is Map<String, dynamic>) {
              return DialogueLine(
                characterName: item['characterName']?.toString() ?? '未知角色',
                dialogue: item['dialogue']?.toString() ?? '',
                stageDirection: item['stageDirection']?.toString(),
                innerThought: item['innerThought']?.toString(),
              );
            }
            return null;
          }).whereType<DialogueLine>().toList();
        }
      }
    } catch (_) {
      // JSON 解析失败
    }

    // Fallback: 尝试按行解析对话格式 "角色名：「台词」"
    return _parseDialogueFromText(content);
  }

  /// 解析 OOC 分析的 AI 回复
  OOCAnalysis _parseOOCAnalysis(String content) {
    try {
      final jsonStr = _extractJsonBlock(content);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          return OOCAnalysis(
            isOOC: decoded['isOOC'] == true,
            confidence: _parseDouble(decoded['confidence'], 0.5),
            explanation: decoded['explanation']?.toString(),
            suggestion: decoded['suggestion']?.toString(),
          );
        }
      }
    } catch (_) {
      // JSON 解析失败
    }

    // Fallback: 简单文本分析
    final lower = content.toLowerCase();
    final isOOC = lower.contains('ooc') ||
        lower.contains('不一致') ||
        lower.contains('偏离');
    return OOCAnalysis(
      isOOC: isOOC,
      confidence: 0.3,
      explanation: content.trim(),
    );
  }

  /// 从文本内容中提取 JSON 块
  /// 支持纯 JSON、```json ... ``` 包裹、或前后有文字的混合格式
  String? _extractJsonBlock(String content) {
    final trimmed = content.trim();

    // 尝试 1：整体就是 JSON
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return trimmed;
    }

    // 尝试 2：提取 ```json ... ``` 代码块
    final codeBlockRegex = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```');
    final codeBlockMatch = codeBlockRegex.firstMatch(trimmed);
    if (codeBlockMatch != null) {
      return codeBlockMatch.group(1)?.trim();
    }

    // 尝试 3：找到第一个 { 或 [ 开头的 JSON 对象/数组
    final jsonStart = trimmed.indexOf('{');
    final arrayStart = trimmed.indexOf('[');
    int startIdx;

    if (jsonStart >= 0 && (arrayStart < 0 || jsonStart < arrayStart)) {
      startIdx = jsonStart;
    } else if (arrayStart >= 0) {
      startIdx = arrayStart;
    } else {
      return null;
    }

    // 找到匹配的闭合括号
    var depth = 0;
    var inString = false;
    var escape = false;

    for (var i = startIdx; i < trimmed.length; i++) {
      final ch = trimmed[i];
      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\' && inString) {
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{' || ch == '[') depth++;
      if (ch == '}' || ch == ']') {
        depth--;
        if (depth == 0) {
          return trimmed.substring(startIdx, i + 1);
        }
      }
    }

    return null;
  }

  /// 从纯文本中解析对话（当 JSON 解析失败时的降级方案）
  List<DialogueLine> _parseDialogueFromText(String content) {
    final lines = <DialogueLine>[];

    // 匹配格式：角色名：「台词」 或 角色名："台词" 或 角色名:"台词"
    final dialogueRegex = RegExp(
      r'([^：「」""\n]{1,20})[：:]\s*[「"「]([^」"」]+)[」"」]',
    );

    for (final match in dialogueRegex.allMatches(content)) {
      lines.add(DialogueLine(
        characterName: match.group(1)?.trim() ?? '未知角色',
        dialogue: match.group(2)?.trim() ?? '',
      ));
    }

    return lines;
  }

  /// 安全解析 double
  double _parseDouble(dynamic value, double fallback) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// 单角色自言自语
  Future<List<DialogueLine>> _simulateMonologue(
    SimCharacterProfile character,
    SimulationContext context,
    String topic,
    String workId,
  ) async {
    try {
      final contextSection = _buildContextSection(context);
      final characterDesc = _describeSimCharacter(character);

      final systemPrompt = '''你是一位专业的小说作家。请根据角色设定和场景，生成角色的内心独白和自言自语。

请严格按照以下 JSON 数组格式输出，不要输出任何其他内容：
[
  {
    "characterName": "${character.name}",
    "dialogue": "角色自言自语的话（出声的）",
    "stageDirection": "角色的动作或表情",
    "innerThought": "角色内心的想法（不出声）"
  }
]''';

      final prompt = '''请模拟以下角色的内心独白和自言自语。

## 角色设定
$characterDesc

## 场景信息
$contextSection

## 思考主题
$topic

请生成 3-5 条内心活动记录，混合自言自语和内心独白。''';

      final config = AIRequestConfig(
        function: AIFunction.characterSimulation,
        systemPrompt: systemPrompt,
        userPrompt: prompt,
        temperature: 0.8,
        maxTokens: 1500,
        stream: false,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: config,
      );

      return _parseDialogueLines(response.content);
    } catch (e) {
      return [];
    }
  }

  /// 构建 SimCharacterProfile 的描述文本
  String _describeSimCharacter(SimCharacterProfile c) {
    final parts = <String>['角色：${c.name}'];
    if (c.personality != null) parts.add('性格：${c.personality}');
    if (c.speechStyle != null) parts.add('语言风格：${c.speechStyle}');
    if (c.coreValues != null) parts.add('核心价值观：${c.coreValues}');
    if (c.currentMood != null) parts.add('当前情绪：${c.currentMood}');
    return parts.join('\n');
  }
}
