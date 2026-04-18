part of 'character_simulation_service.dart';

const _simulationFallbackReaction = '角色陷入沉默，目光微微闪烁。';

class _CharacterSimulationPromptBundle {
  final String systemPrompt;
  final String userPrompt;

  const _CharacterSimulationPromptBundle({
    required this.systemPrompt,
    required this.userPrompt,
  });
}

String buildCharacterSimulationProfileSection(String characterProfileJson) {
  try {
    final data = json.decode(characterProfileJson) as Map<String, dynamic>;
    final sections = <String>[];

    final mbti = data['mbti'];
    if (mbti != null) sections.add('MBTI 人格类型：$mbti');

    final bigFive = data['bigFive'];
    if (bigFive is Map) {
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

    final personalityKeywords = data['personalityKeywords'];
    if (personalityKeywords is List && personalityKeywords.isNotEmpty) {
      sections.add('性格关键词：${personalityKeywords.join("、")}');
    }

    final coreValues = data['coreValues'];
    if (coreValues != null && coreValues.toString().isNotEmpty) {
      sections.add('核心价值观：$coreValues');
    }

    final fears = data['fears'];
    if (fears != null && fears.toString().isNotEmpty) {
      sections.add('恐惧：$fears');
    }

    final desires = data['desires'];
    if (desires != null && desires.toString().isNotEmpty) {
      sections.add('欲望：$desires');
    }

    final moralBaseline = data['moralBaseline'];
    if (moralBaseline != null && moralBaseline.toString().isNotEmpty) {
      sections.add('道德基线：$moralBaseline');
    }

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
      if (vocabularyPreferences is List &&
          vocabularyPreferences.isNotEmpty) {
        speechParts.add('词汇偏好：${vocabularyPreferences.join("、")}');
      }
      if (tabooWords is List && tabooWords.isNotEmpty) {
        speechParts.add('避讳词：${tabooWords.join("、")}');
      }
      if (speechParts.isNotEmpty) {
        sections.add('语言风格设定：\n${speechParts.map((p) => "  - $p").join("\n")}');
      }
    }

    final behaviorPatterns = data['behaviorPatterns'];
    if (behaviorPatterns is List && behaviorPatterns.isNotEmpty) {
      final patternDescs = behaviorPatterns
          .map((p) {
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
          })
          .whereType<String>()
          .toList();
      if (patternDescs.isNotEmpty) {
        sections.add('行为模式：\n${patternDescs.join("\n")}');
      }
    }

    final speechExamples =
        data['speechStyle'] is Map ? (data['speechStyle'] as Map)['examples'] : null;
    if (speechExamples is List && speechExamples.isNotEmpty) {
      final examples = speechExamples
          .map((e) {
            if (e is Map) {
              final scene = e['scene'] ?? '';
              final emotion = e['emotion'] ?? '';
              final line = e['line'] ?? '';
              return '  - [$scene / $emotion] "$line"';
            }
            return null;
          })
          .whereType<String>()
          .toList();
      if (examples.isNotEmpty) {
        sections.add('台词示例：\n${examples.join("\n")}');
      }
    }

    if (sections.isEmpty) {
      sections.add('原始档案：$characterProfileJson');
    } else {
      final knownKeys = {
        'mbti',
        'bigFive',
        'personalityKeywords',
        'coreValues',
        'fears',
        'desires',
        'moralBaseline',
        'speechStyle',
        'behaviorPatterns',
      };
      final extraKeys = data.keys.where((k) => !knownKeys.contains(k)).toList();
      final extras = extraKeys
          .map((k) => '$k：${data[k]}')
          .where((s) => s.isNotEmpty)
          .join('；');
      if (extras.isNotEmpty) sections.add('其他设定：$extras');
    }

    return sections.join('\n\n');
  } catch (_) {
    return characterProfileJson;
  }
}

String buildCharacterSimulationContextSection(SimulationContext context) {
  final parts = <String>['场景描述：${context.sceneDescription}'];

  if (context.precedingEvents != null && context.precedingEvents!.isNotEmpty) {
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
  if (context.presentCharacters != null && context.presentCharacters!.isNotEmpty) {
    parts.add('在场其他角色：${context.presentCharacters!.join("、")}');
  }

  return parts.join('\n');
}

_CharacterSimulationPromptBundle _buildSimulationPromptBundle({
  required String characterName,
  required String profileSection,
  required String contextSection,
}) {
  return _CharacterSimulationPromptBundle(
    systemPrompt: '''你是一位专业的角色扮演推演引擎。你的任务是根据角色的完整档案和给定场景，精确模拟该角色在场景中的反应。

你必须严格遵循角色的性格设定、行为模式、语言风格和价值观。你的模拟结果应当让人感到"这就是这个角色会做的事"。

请严格按照以下 JSON 格式输出，不要输出任何其他内容：
{
  "reaction": "角色的行为和心理反应描述",
  "dialogue": "角色说出的话（如有），无对话则为空字符串",
  "innerThought": "角色的内心独白",
  "emotionalState": "角色当前的情绪状态描述"
}''',
    userPrompt: '''请模拟以下角色在给定场景中的反应。

## 角色档案
角色名：$characterName
$profileSection

## 场景信息
$contextSection

请严格按照角色设定进行推演，输出 JSON 格式的结果。''',
  );
}

String _buildCharactersSection(List<SimCharacterProfile> characters) {
  return characters.map(describeCharacterSimulationProfile).join('\n\n');
}

_CharacterSimulationPromptBundle _buildDialoguePromptBundle({
  required int turns,
  required String topic,
  required String charactersSection,
  required String contextSection,
}) {
  return _CharacterSimulationPromptBundle(
    systemPrompt: '''你是一位专业的小说对话作家。你的任务是根据角色的设定和场景，生成角色之间自然、生动的对话。

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
]''',
    userPrompt: '''请根据以下信息，模拟 $turns 轮角色对话。

## 对话主题
$topic

## 参与角色
$charactersSection

## 场景信息
$contextSection

请生成 $turns 轮对话（每轮包含一个角色的发言），严格按照 JSON 数组格式输出。''',
  );
}

_CharacterSimulationPromptBundle _buildOocPromptBundle({
  required String characterName,
  required String profileSection,
  required String textToAnalyze,
}) {
  return _CharacterSimulationPromptBundle(
    systemPrompt: '''你是一位专业的角色 OOC（Out of Character）检测专家。你的任务是比对角色的完整设定与给定文本中该角色的表现，判断角色行为是否偏离设定。

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
}''',
    userPrompt: '''请检测以下文本中角色"${characterName}"的表现是否偏离设定。

## 角色设定
$profileSection

## 待分析文本
$textToAnalyze

请逐维度分析，输出 JSON 格式的判定结果。''',
  );
}

_CharacterSimulationPromptBundle _buildMonologuePromptBundle({
  required SimCharacterProfile character,
  required String characterDescription,
  required String contextSection,
  required String topic,
}) {
  return _CharacterSimulationPromptBundle(
    systemPrompt: '''你是一位专业的小说作家。请根据角色设定和场景，生成角色的内心独白和自言自语。

请严格按照以下 JSON 数组格式输出，不要输出任何其他内容：
[
  {
    "characterName": "${character.name}",
    "dialogue": "角色自言自语的话（出声的）",
    "stageDirection": "角色的动作或表情",
    "innerThought": "角色内心的想法（不出声）"
  }
]''',
    userPrompt: '''请模拟以下角色的内心独白和自言自语。

## 角色设定
$characterDescription

## 场景信息
$contextSection

## 思考主题
$topic

请生成 3-5 条内心活动记录，混合自言自语和内心独白。''',
  );
}

String describeCharacterSimulationProfile(SimCharacterProfile c) {
  final parts = <String>['角色：${c.name}'];
  if (c.personality != null) parts.add('性格：${c.personality}');
  if (c.speechStyle != null) parts.add('语言风格：${c.speechStyle}');
  if (c.coreValues != null) parts.add('核心价值观：${c.coreValues}');
  if (c.currentMood != null) parts.add('当前情绪：${c.currentMood}');
  return parts.join('\n');
}

String _buildSimulationFailureReaction(Object error) =>
    '角色陷入沉默，目光微微闪烁。（模拟失败：$error）';
