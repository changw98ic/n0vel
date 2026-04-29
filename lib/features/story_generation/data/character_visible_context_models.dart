class VisibilityAcl {
  VisibilityAcl({
    this.isPublic = false,
    this.isAuthorOnly = false,
    Set<String> characterIds = const {},
    Set<String> groupIds = const {},
  }) : characterIds = Set.unmodifiable(characterIds),
       groupIds = Set.unmodifiable(groupIds);

  VisibilityAcl.public()
    : isPublic = true,
      isAuthorOnly = false,
      characterIds = const {},
      groupIds = const {};

  VisibilityAcl.authorOnly()
    : isPublic = false,
      isAuthorOnly = true,
      characterIds = const {},
      groupIds = const {};

  VisibilityAcl.characters(Set<String> ids)
    : isPublic = false,
      isAuthorOnly = false,
      characterIds = Set.unmodifiable(ids),
      groupIds = const {};

  VisibilityAcl.groups(Set<String> ids)
    : isPublic = false,
      isAuthorOnly = false,
      characterIds = const {},
      groupIds = Set.unmodifiable(ids);

  final bool isPublic;
  final bool isAuthorOnly;
  final Set<String> characterIds;
  final Set<String> groupIds;

  bool canSee(String characterId, {Set<String> characterGroupIds = const {}}) {
    if (isAuthorOnly) return false;
    if (isPublic) return true;
    if (characterIds.contains(characterId)) return true;
    return groupIds.any(characterGroupIds.contains);
  }
}

class PublicSceneState {
  const PublicSceneState({required this.summary});

  final String summary;
}

class VisibleEvent {
  const VisibleEvent({
    required this.round,
    required this.actorId,
    required this.actorName,
    this.visibleAction = '',
    this.dialogue = '',
    this.publicFact = '',
  });

  final int round;
  final String actorId;
  final String actorName;
  final String visibleAction;
  final String dialogue;
  final String publicFact;

  String toPromptLine() {
    final parts = <String>[
      'R$round',
      actorName,
      if (visibleAction.trim().isNotEmpty) '动作=${visibleAction.trim()}',
      if (dialogue.trim().isNotEmpty) '对白=${dialogue.trim()}',
      if (publicFact.trim().isNotEmpty) '事实=${publicFact.trim()}',
    ];
    return parts.join('/');
  }
}

class CharacterKnownFact {
  const CharacterKnownFact({
    required this.content,
    required this.acl,
    this.confidence = 1,
    this.source = '',
  });

  final String content;
  final VisibilityAcl acl;
  final double confidence;
  final String source;
}

class CharacterVisibleContext {
  CharacterVisibleContext({
    required this.characterId,
    required this.characterName,
    required this.role,
    required this.privateBriefing,
    required this.publicSceneState,
    List<VisibleEvent> visibleEvents = const [],
    List<CharacterKnownFact> knownFacts = const [],
    List<String> beliefs = const [],
    List<String> relationships = const [],
    List<String> socialPositions = const [],
  }) : visibleEvents = List.unmodifiable(visibleEvents),
       knownFacts = List.unmodifiable(knownFacts),
       beliefs = List.unmodifiable(beliefs),
       relationships = List.unmodifiable(relationships),
       socialPositions = List.unmodifiable(socialPositions);

  final String characterId;
  final String characterName;
  final String role;
  final String privateBriefing;
  final PublicSceneState publicSceneState;
  final List<VisibleEvent> visibleEvents;
  final List<CharacterKnownFact> knownFacts;
  final List<String> beliefs;
  final List<String> relationships;
  final List<String> socialPositions;

  String toPromptText() {
    return [
      '角色：$characterName($role)',
      '公共局面：${publicSceneState.summary}',
      if (privateBriefing.trim().isNotEmpty) '角色简报：$privateBriefing',
      if (knownFacts.isNotEmpty)
        '已知事实：${knownFacts.map((fact) => fact.content).join('；')}',
      if (beliefs.isNotEmpty) '信念：${beliefs.join('；')}',
      if (relationships.isNotEmpty) '关系：${relationships.join('；')}',
      if (socialPositions.isNotEmpty) '社会位置：${socialPositions.join('；')}',
      if (visibleEvents.isNotEmpty)
        '已发生：${visibleEvents.map((event) => event.toPromptLine()).join('；')}',
    ].join('\n');
  }
}
