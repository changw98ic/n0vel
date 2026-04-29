class SceneRoleplaySession {
  SceneRoleplaySession({
    required this.chapterId,
    required this.sceneId,
    required this.sceneTitle,
    required List<SceneRoleplayRound> rounds,
    List<SceneRoleplayCommittedFact> committedFacts = const [],
    this.finalPublicState = '',
  }) : rounds = List.unmodifiable(rounds),
       committedFacts = List.unmodifiable(committedFacts);

  final String chapterId;
  final String sceneId;
  final String sceneTitle;
  final List<SceneRoleplayRound> rounds;
  final List<SceneRoleplayCommittedFact> committedFacts;
  final String finalPublicState;

  bool get isEmpty => rounds.isEmpty;

  String toPromptText({int maxChars = 2400}) {
    final lines = <String>[
      '场景：$sceneTitle',
      for (final round in rounds) ...round.toPromptLines(),
      if (committedFacts.isNotEmpty) '已提交事实：',
      for (final fact in committedFacts) '- ${fact.toPromptLine()}',
      if (finalPublicState.trim().isNotEmpty) '最终局面：$finalPublicState',
    ];
    return _compact(lines.join('\n'), maxChars: maxChars);
  }

  String toCommittedPromptText({int maxChars = 2400}) {
    final lines = <String>[
      '场景：$sceneTitle',
      for (final round in rounds) ...round.toPublicPromptLines(),
      if (committedFacts.isNotEmpty) '已提交事实：',
      for (final fact in committedFacts) '- ${fact.toPromptLine()}',
      if (finalPublicState.trim().isNotEmpty) '最终公开局面：$finalPublicState',
    ];
    return _compact(lines.join('\n'), maxChars: maxChars);
  }

  static String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}

class SceneRoleplayCommittedFact {
  const SceneRoleplayCommittedFact({
    required this.sequenceId,
    required this.round,
    required this.source,
    required this.content,
    required this.previousHash,
    required this.contentHash,
  });

  final int sequenceId;
  final int round;
  final String source;
  final String content;
  final String previousHash;
  final String contentHash;

  String toPromptLine() {
    return '#$sequenceId/R$round/$source/$contentHash：$content';
  }
}

class SceneRoleplayRound {
  SceneRoleplayRound({
    required this.round,
    required List<SceneRoleplayTurn> turns,
    required this.arbitration,
  }) : turns = List.unmodifiable(turns);

  final int round;
  final List<SceneRoleplayTurn> turns;
  final SceneRoleplayArbitration arbitration;

  List<String> toPromptLines() {
    return [
      '回合$round：',
      for (final turn in turns) '- ${turn.toTranscriptLine()}',
      '- 裁决：${arbitration.toPromptLine()}',
    ];
  }

  List<String> toPublicPromptLines() {
    return [
      '回合$round公开事件：',
      for (final turn in turns)
        if (turn.hasPublicEvent) '- ${turn.toPublicEventLine()}',
      '- 公开裁决：${arbitration.toPromptLine()}',
    ];
  }
}

class SceneRoleplayTurn {
  const SceneRoleplayTurn({
    required this.round,
    required this.characterId,
    required this.name,
    required this.intent,
    required this.visibleAction,
    required this.dialogue,
    required this.innerState,
    required this.taboo,
    required this.rawText,
    this.skillId = '',
    this.skillVersion = '',
  });

  final int round;
  final String characterId;
  final String name;
  final String intent;
  final String visibleAction;
  final String dialogue;
  final String innerState;
  final String taboo;
  final String rawText;
  final String skillId;
  final String skillVersion;

  bool get hasPublicEvent =>
      visibleAction.trim().isNotEmpty || dialogue.trim().isNotEmpty;

  String toTranscriptLine() {
    final parts = <String>[
      'R$round',
      name,
      if (skillId.isNotEmpty) 'skill=$skillId@$skillVersion',
      if (intent.isNotEmpty) '意图=$intent',
      if (visibleAction.isNotEmpty) '动作=$visibleAction',
      if (dialogue.isNotEmpty) '对白=$dialogue',
      if (innerState.isNotEmpty) '内心=$innerState',
    ];
    return parts.join('/');
  }

  String toPublicEventLine() {
    final parts = <String>[
      'R$round',
      name,
      if (visibleAction.isNotEmpty) '动作=$visibleAction',
      if (dialogue.isNotEmpty) '对白=$dialogue',
    ];
    return parts.join('/');
  }
}

class SceneRoleplayArbitration {
  const SceneRoleplayArbitration({
    required this.fact,
    required this.state,
    required this.pressure,
    required this.nextPublicState,
    required this.shouldStop,
    required this.rawText,
    this.skillId = '',
    this.skillVersion = '',
  });

  final String fact;
  final String state;
  final String pressure;
  final String nextPublicState;
  final bool shouldStop;
  final String rawText;
  final String skillId;
  final String skillVersion;

  String toPromptLine() {
    return [
      if (skillId.isNotEmpty) 'skill=$skillId@$skillVersion',
      if (fact.isNotEmpty) '事实=$fact',
      if (state.isNotEmpty) '状态=$state',
      if (pressure.isNotEmpty) '压力=$pressure',
      '收束=${shouldStop ? '是' : '否'}',
    ].join('；');
  }
}
