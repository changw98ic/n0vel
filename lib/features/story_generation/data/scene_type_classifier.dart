import 'scene_runtime_models.dart';

/// Broad scene type categories that influence prompt strategy.
enum SceneType {
  dialogue,
  action,
  introspective,
  transitional,
  climactic,
  mystery,
  romance,
}

/// Result of scene type classification with confidence information.
class SceneTypeResult {
  const SceneTypeResult({
    required this.primaryType,
    required this.confidence,
    this.secondaryType,
  });

  final SceneType primaryType;
  final double confidence;
  final SceneType? secondaryType;

  /// Chinese label for use in prompts.
  String get label => switch (primaryType) {
    SceneType.dialogue => '对话场景',
    SceneType.action => '动作/冲突场景',
    SceneType.introspective => '内心独白/沉思场景',
    SceneType.transitional => '过渡/衔接场景',
    SceneType.climactic => '高潮/转折场景',
    SceneType.mystery => '悬疑/探秘场景',
    SceneType.romance => '情感/亲密场景',
  };

  /// Suggested pacing for this scene type.
  String get suggestedPacing => switch (primaryType) {
    SceneType.dialogue => 'medium',
    SceneType.action => 'fast',
    SceneType.introspective => 'slow',
    SceneType.transitional => 'fast',
    SceneType.climactic => 'fast',
    SceneType.mystery => 'slow',
    SceneType.romance => 'slow',
  };

  /// Suggested tone for this scene type.
  String get suggestedTone => switch (primaryType) {
    SceneType.dialogue => '自然流畅',
    SceneType.action => '紧张激烈',
    SceneType.introspective => '细腻深沉',
    SceneType.transitional => '简洁克制',
    SceneType.climactic => '紧张爆发',
    SceneType.mystery => '悬疑压抑',
    SceneType.romance => '温柔细腻',
  };
}

/// Classifies a scene into a [SceneType] based on its brief content, cast,
/// and target length. Uses keyword matching + structural heuristics.
class SceneTypeClassifier {
  SceneTypeClassifier();

  static const Map<SceneType, List<String>> _keywordMap = {
    SceneType.action: [
      '打', '战', '搏', '冲突', '追赶', '逃跑', '攻击', '防守', '对抗',
      '厮杀', '格斗', '枪', '刀', '剑', '血', '伤', '击败', '击退',
      '对峙', '逼问', '拦住', '施压', '怒吼', '咆哮', '拍桌',
    ],
    SceneType.climactic: [
      '高潮', '转折', '真相大白', '揭露', '揭秘', '决战', '最终',
      '关键时刻', '生死', '命运', '决定', '抉择', '破釜沉舟',
      '绝境', '孤注一掷', '决战时刻', '总攻',
    ],
    SceneType.mystery: [
      '线索', '谜', '疑', '调查', '探', '暗示', '暗藏', '未知',
      '发现', '察觉', '怀疑', '秘密', '隐藏', '诡异', '蹊跷',
      '不可告人', '幕后', '隐情', '端倪',
    ],
    SceneType.romance: [
      '爱', '恋', '情', '吻', '拥抱', '亲昵', '温柔', '心动',
      '暧昧', '表白', '告白', '思念', '牵挂', '凝视', '牵手',
      '依偎', '缠绵', '深情', '柔情',
    ],
    SceneType.introspective: [
      '回忆', '沉思', '内心', '独白', '冥想', '反省', '思考',
      '犹豫', '彷徨', '梦境', '幻觉', '意识流', '感悟', '领悟',
      '纠结', '挣扎', '矛盾', '自问',
    ],
    SceneType.transitional: [
      '离开', '出发', '到达', '途经', '回到', '前往', '移步',
      '过渡', '时间跳转', '数日后', '次日', '翌日', '半年后',
      '回到', '赶往', '前往',
    ],
    SceneType.dialogue: [
      '对话', '交谈', '商议', '讨论', '谈判', '闲聊', '聊天',
      '问', '答', '说', '讲', '诉说', '倾诉', '争论',
    ],
  };

  SceneTypeResult classify(SceneBrief brief) {
    final text = '${brief.sceneTitle} ${brief.sceneSummary} ${brief.targetBeat}'
        .toLowerCase();
    final castCount = brief.cast.length;

    final scores = <SceneType, double>{};

    // Keyword scoring
    for (final entry in _keywordMap.entries) {
      var score = 0.0;
      for (final kw in entry.value) {
        if (text.contains(kw)) {
          score += kw.length <= 1 ? 1.0 : 2.0;
        }
      }
      scores[entry.key] = score;
    }

    // Structural heuristics
    if (castCount >= 4) {
      scores[SceneType.action] = (scores[SceneType.action] ?? 0) + 2.0;
      scores[SceneType.dialogue] = (scores[SceneType.dialogue] ?? 0) + 1.0;
    } else if (castCount <= 1) {
      scores[SceneType.introspective] =
          (scores[SceneType.introspective] ?? 0) + 3.0;
    } else if (castCount == 2) {
      scores[SceneType.dialogue] = (scores[SceneType.dialogue] ?? 0) + 1.5;
      scores[SceneType.romance] = (scores[SceneType.romance] ?? 0) + 0.5;
    }

    // Length heuristics: short scenes tend to be transitional
    if (brief.targetLength <= 250) {
      scores[SceneType.transitional] =
          (scores[SceneType.transitional] ?? 0) + 2.0;
    }

    // Pick top two
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sorted.isEmpty || sorted.first.value == 0) {
      // Default to dialogue when no signals
      return const SceneTypeResult(
        primaryType: SceneType.dialogue,
        confidence: 0.3,
      );
    }

    final total = sorted.fold<double>(0, (sum, e) => sum + e.value);
    final confidence = total > 0 ? sorted.first.value / total : 0.5;
    final secondary =
        sorted.length >= 2 && sorted[1].value > 0 ? sorted[1].key : null;

    return SceneTypeResult(
      primaryType: sorted.first.key,
      confidence: confidence.clamp(0.0, 1.0),
      secondaryType: secondary,
    );
  }
}
