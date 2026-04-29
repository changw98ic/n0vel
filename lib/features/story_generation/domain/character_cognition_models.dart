enum CognitionKind {
  perceivedEvent,
  reportedEvent,
  acceptedBelief,
  inference,
  suspicion,
  uncertainty,
  relationshipView,
  selfState,
  goal,
  intent,
  presentation,
  memory,
}

class CharacterCognitionAtom implements Comparable<CharacterCognitionAtom> {
  CharacterCognitionAtom({
    required this.id,
    required this.projectId,
    required this.characterId,
    required this.sceneId,
    required this.sequence,
    required this.kind,
    required this.content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    this.createdAtMs = 0,
  }) : sourceEventIds = List<String>.unmodifiable(
         _parseStringList(sourceEventIds),
       ),
       sourceCharacterIds = List<String>.unmodifiable(
         _parseStringList(sourceCharacterIds),
       ),
       tags = List<String>.unmodifiable(_parseStringList(tags)),
       supersedesAtomIds = List<String>.unmodifiable(
         _parseStringList(supersedesAtomIds),
       ),
       certainty = certainty.clamp(0.0, 1.0),
       salience = salience.clamp(0.0, 1.0),
       emotionalWeight = emotionalWeight.clamp(0.0, 1.0);

  factory CharacterCognitionAtom.perceivedEvent({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.perceivedEvent,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.reportedEvent({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.reportedEvent,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.acceptedBelief({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.acceptedBelief,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.inference({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.inference,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.suspicion({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.suspicion,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.selfState({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.selfState,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.goal({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.goal,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  factory CharacterCognitionAtom.intent({
    required String id,
    required String projectId,
    required String characterId,
    required String sceneId,
    required int sequence,
    required String content,
    List<String> sourceEventIds = const [],
    List<String> sourceCharacterIds = const [],
    List<String> tags = const [],
    List<String> supersedesAtomIds = const [],
    double certainty = 1.0,
    double salience = 0.5,
    double emotionalWeight = 0.0,
    int createdAtMs = 0,
  }) {
    return CharacterCognitionAtom(
      id: id,
      projectId: projectId,
      characterId: characterId,
      sceneId: sceneId,
      sequence: sequence,
      kind: CognitionKind.intent,
      content: content,
      sourceEventIds: sourceEventIds,
      sourceCharacterIds: sourceCharacterIds,
      tags: tags,
      supersedesAtomIds: supersedesAtomIds,
      certainty: certainty,
      salience: salience,
      emotionalWeight: emotionalWeight,
      createdAtMs: createdAtMs,
    );
  }

  final String id;
  final String projectId;
  final String characterId;
  final String sceneId;
  final int sequence;
  final CognitionKind kind;
  final String content;
  final List<String> sourceEventIds;
  final List<String> sourceCharacterIds;
  final double certainty;
  final double salience;
  final double emotionalWeight;
  final List<String> tags;
  final List<String> supersedesAtomIds;
  final int createdAtMs;

  CharacterCognitionAtom copyWith({
    String? id,
    String? projectId,
    String? characterId,
    String? sceneId,
    int? sequence,
    CognitionKind? kind,
    String? content,
    List<String>? sourceEventIds,
    List<String>? sourceCharacterIds,
    double? certainty,
    double? salience,
    double? emotionalWeight,
    List<String>? tags,
    List<String>? supersedesAtomIds,
    int? createdAtMs,
  }) {
    return CharacterCognitionAtom(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      characterId: characterId ?? this.characterId,
      sceneId: sceneId ?? this.sceneId,
      sequence: sequence ?? this.sequence,
      kind: kind ?? this.kind,
      content: content ?? this.content,
      sourceEventIds: sourceEventIds ?? this.sourceEventIds,
      sourceCharacterIds: sourceCharacterIds ?? this.sourceCharacterIds,
      certainty: certainty ?? this.certainty,
      salience: salience ?? this.salience,
      emotionalWeight: emotionalWeight ?? this.emotionalWeight,
      tags: tags ?? this.tags,
      supersedesAtomIds: supersedesAtomIds ?? this.supersedesAtomIds,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'characterId': characterId,
      'sceneId': sceneId,
      'sequence': sequence,
      'kind': kind.name,
      'content': content,
      'sourceEventIds': sourceEventIds,
      'sourceCharacterIds': sourceCharacterIds,
      'certainty': certainty,
      'salience': salience,
      'emotionalWeight': emotionalWeight,
      'tags': tags,
      'supersedesAtomIds': supersedesAtomIds,
      'createdAtMs': createdAtMs,
    };
  }

  static CharacterCognitionAtom fromJson(Map<Object?, Object?> json) {
    return CharacterCognitionAtom(
      id: json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      sceneId: json['sceneId']?.toString() ?? '',
      sequence: _parseIntOrFallback(json['sequence'], fallback: 0),
      kind: _parseCognitionKind(json['kind']),
      content: json['content']?.toString() ?? '',
      sourceEventIds: _parseStringList(json['sourceEventIds']),
      sourceCharacterIds: _parseStringList(json['sourceCharacterIds']),
      certainty: _parseClampedDouble(json['certainty'], fallback: 1.0),
      salience: _parseClampedDouble(json['salience'], fallback: 0.5),
      emotionalWeight: _parseClampedDouble(
        json['emotionalWeight'],
        fallback: 0.0,
      ),
      tags: _parseStringList(json['tags']),
      supersedesAtomIds: _parseStringList(json['supersedesAtomIds']),
      createdAtMs: _parseIntOrFallback(json['createdAtMs'], fallback: 0),
    );
  }

  static List<CharacterCognitionAtom> sorted(
    Iterable<CharacterCognitionAtom> atoms,
  ) {
    return List<CharacterCognitionAtom>.unmodifiable(
      List<CharacterCognitionAtom>.from(atoms)..sort(),
    );
  }

  static List<CharacterCognitionAtom> forCharacter(
    Iterable<CharacterCognitionAtom> atoms,
    String characterId,
  ) {
    return sorted([
      for (final atom in atoms)
        if (atom.characterId == characterId) atom,
    ]);
  }

  static Map<CognitionKind, List<CharacterCognitionAtom>> groupByKind(
    Iterable<CharacterCognitionAtom> atoms,
  ) {
    final groups = {
      for (final kind in CognitionKind.values) kind: <CharacterCognitionAtom>[],
    };
    for (final atom in sorted(atoms)) {
      groups[atom.kind]!.add(atom);
    }
    return Map<CognitionKind, List<CharacterCognitionAtom>>.unmodifiable({
      for (final entry in groups.entries)
        entry.key: List<CharacterCognitionAtom>.unmodifiable(entry.value),
    });
  }

  @override
  int compareTo(CharacterCognitionAtom other) {
    final projectCmp = projectId.compareTo(other.projectId);
    if (projectCmp != 0) return projectCmp;
    final characterCmp = characterId.compareTo(other.characterId);
    if (characterCmp != 0) return characterCmp;
    final sceneCmp = sceneId.compareTo(other.sceneId);
    if (sceneCmp != 0) return sceneCmp;
    final sequenceCmp = sequence.compareTo(other.sequence);
    if (sequenceCmp != 0) return sequenceCmp;
    final createdCmp = createdAtMs.compareTo(other.createdAtMs);
    if (createdCmp != 0) return createdCmp;
    return id.compareTo(other.id);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharacterCognitionAtom &&
        other.id == id &&
        other.projectId == projectId &&
        other.characterId == characterId &&
        other.sceneId == sceneId &&
        other.sequence == sequence &&
        other.kind == kind &&
        other.content == content &&
        _listEquals(other.sourceEventIds, sourceEventIds) &&
        _listEquals(other.sourceCharacterIds, sourceCharacterIds) &&
        other.certainty == certainty &&
        other.salience == salience &&
        other.emotionalWeight == emotionalWeight &&
        _listEquals(other.tags, tags) &&
        _listEquals(other.supersedesAtomIds, supersedesAtomIds) &&
        other.createdAtMs == createdAtMs;
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    characterId,
    sceneId,
    sequence,
    kind,
    content,
    Object.hashAll(sourceEventIds),
    Object.hashAll(sourceCharacterIds),
    certainty,
    salience,
    emotionalWeight,
    Object.hashAll(tags),
    Object.hashAll(supersedesAtomIds),
    createdAtMs,
  );
}

final _cognitionKindByName = {
  for (final kind in CognitionKind.values) kind.name: kind,
};

CognitionKind _parseCognitionKind(Object? raw) {
  return _cognitionKindByName[raw?.toString()] ?? CognitionKind.perceivedEvent;
}

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

class CharacterBelief {
  CharacterBelief({
    required this.subjectId,
    required this.targetId,
    required this.claim,
    double confidence = 1.0,
    this.source = '',
  }) : confidence = confidence.clamp(0.0, 1.0);

  final String subjectId;
  final String targetId;
  final String claim;
  final double confidence;
  final String source;

  CharacterBelief copyWith({
    String? subjectId,
    String? targetId,
    String? claim,
    double? confidence,
    String? source,
  }) {
    return CharacterBelief(
      subjectId: subjectId ?? this.subjectId,
      targetId: targetId ?? this.targetId,
      claim: claim ?? this.claim,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'subjectId': subjectId,
      'targetId': targetId,
      'claim': claim,
      'confidence': confidence,
      'source': source,
    };
  }

  static CharacterBelief fromJson(Map<Object?, Object?> json) {
    return CharacterBelief(
      subjectId: json['subjectId']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      claim: json['claim']?.toString() ?? '',
      confidence: _parseClampedDouble(json['confidence'], fallback: 1.0),
      source: json['source']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharacterBelief &&
        other.subjectId == subjectId &&
        other.targetId == targetId &&
        other.claim == claim &&
        other.confidence == confidence &&
        other.source == source;
  }

  @override
  int get hashCode =>
      Object.hash(subjectId, targetId, claim, confidence, source);
}

class RelationshipSlice {
  RelationshipSlice({
    required this.characterId,
    required this.otherId,
    required this.kind,
    double trust = 0.5,
    double tension = 0.0,
    this.notes = '',
  })  : trust = trust.clamp(0.0, 1.0),
        tension = tension.clamp(0.0, 1.0);

  final String characterId;
  final String otherId;
  final String kind;
  final double trust;
  final double tension;
  final String notes;

  RelationshipSlice copyWith({
    String? characterId,
    String? otherId,
    String? kind,
    double? trust,
    double? tension,
    String? notes,
  }) {
    return RelationshipSlice(
      characterId: characterId ?? this.characterId,
      otherId: otherId ?? this.otherId,
      kind: kind ?? this.kind,
      trust: trust ?? this.trust,
      tension: tension ?? this.tension,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'otherId': otherId,
      'kind': kind,
      'trust': trust,
      'tension': tension,
      'notes': notes,
    };
  }

  static RelationshipSlice fromJson(Map<Object?, Object?> json) {
    return RelationshipSlice(
      characterId: json['characterId']?.toString() ?? '',
      otherId: json['otherId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      trust: _parseClampedDouble(json['trust'], fallback: 0.5),
      tension: _parseClampedDouble(json['tension'], fallback: 0.0),
      notes: json['notes']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelationshipSlice &&
        other.characterId == characterId &&
        other.otherId == otherId &&
        other.kind == kind &&
        other.trust == trust &&
        other.tension == tension &&
        other.notes == notes;
  }

  @override
  int get hashCode =>
      Object.hash(characterId, otherId, kind, trust, tension, notes);
}

class SocialPositionSlice {
  const SocialPositionSlice({
    required this.characterId,
    required this.contextId,
    required this.role,
    this.rank = 0,
    this.notes = '',
  });

  final String characterId;
  final String contextId;
  final String role;
  final int rank;
  final String notes;

  SocialPositionSlice copyWith({
    String? characterId,
    String? contextId,
    String? role,
    int? rank,
    String? notes,
  }) {
    return SocialPositionSlice(
      characterId: characterId ?? this.characterId,
      contextId: contextId ?? this.contextId,
      role: role ?? this.role,
      rank: rank ?? this.rank,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'contextId': contextId,
      'role': role,
      'rank': rank,
      'notes': notes,
    };
  }

  static SocialPositionSlice fromJson(Map<Object?, Object?> json) {
    return SocialPositionSlice(
      characterId: json['characterId']?.toString() ?? '',
      contextId: json['contextId']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      rank: _parseIntOrFallback(json['rank'], fallback: 0),
      notes: json['notes']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialPositionSlice &&
        other.characterId == characterId &&
        other.contextId == contextId &&
        other.role == role &&
        other.rank == rank &&
        other.notes == notes;
  }

  @override
  int get hashCode =>
      Object.hash(characterId, contextId, role, rank, notes);
}

class PresentationState {
  const PresentationState({
    required this.characterId,
    this.displayedEmotion = '',
    this.hiddenEmotion = '',
    this.deceptionTarget = '',
    this.deceptionContent = '',
  });

  final String characterId;
  final String displayedEmotion;
  final String hiddenEmotion;
  final String deceptionTarget;
  final String deceptionContent;

  bool get isDeceiving =>
      deceptionTarget.isNotEmpty && deceptionContent.isNotEmpty;

  PresentationState copyWith({
    String? characterId,
    String? displayedEmotion,
    String? hiddenEmotion,
    String? deceptionTarget,
    String? deceptionContent,
  }) {
    return PresentationState(
      characterId: characterId ?? this.characterId,
      displayedEmotion: displayedEmotion ?? this.displayedEmotion,
      hiddenEmotion: hiddenEmotion ?? this.hiddenEmotion,
      deceptionTarget: deceptionTarget ?? this.deceptionTarget,
      deceptionContent: deceptionContent ?? this.deceptionContent,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'displayedEmotion': displayedEmotion,
      'hiddenEmotion': hiddenEmotion,
      'deceptionTarget': deceptionTarget,
      'deceptionContent': deceptionContent,
    };
  }

  static PresentationState fromJson(Map<Object?, Object?> json) {
    return PresentationState(
      characterId: json['characterId']?.toString() ?? '',
      displayedEmotion: json['displayedEmotion']?.toString() ?? '',
      hiddenEmotion: json['hiddenEmotion']?.toString() ?? '',
      deceptionTarget: json['deceptionTarget']?.toString() ?? '',
      deceptionContent: json['deceptionContent']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresentationState &&
        other.characterId == characterId &&
        other.displayedEmotion == displayedEmotion &&
        other.hiddenEmotion == hiddenEmotion &&
        other.deceptionTarget == deceptionTarget &&
        other.deceptionContent == deceptionContent;
  }

  @override
  int get hashCode => Object.hash(
        characterId,
        displayedEmotion,
        hiddenEmotion,
        deceptionTarget,
        deceptionContent,
      );
}

class CharacterCognitionSnapshot {
  CharacterCognitionSnapshot({
    required this.characterId,
    required this.name,
    required this.role,
    List<CharacterBelief> beliefs = const [],
    List<RelationshipSlice> relationships = const [],
    List<SocialPositionSlice> socialPositions = const [],
    PresentationState presentation = const PresentationState(characterId: ''),
  })  : beliefs = List<CharacterBelief>.unmodifiable(beliefs),
        relationships = List<RelationshipSlice>.unmodifiable(relationships),
        socialPositions =
            List<SocialPositionSlice>.unmodifiable(socialPositions),
        _presentation = presentation;

  final String characterId;
  final String name;
  final String role;
  final List<CharacterBelief> beliefs;
  final List<RelationshipSlice> relationships;
  final List<SocialPositionSlice> socialPositions;

  final PresentationState _presentation;
  PresentationState get presentation => _presentation.characterId.isEmpty
      ? PresentationState(characterId: characterId)
      : _presentation;

  List<CharacterBelief> beliefsAbout(String targetId) {
    return [
      for (final belief in beliefs)
        if (belief.targetId == targetId) belief,
    ];
  }

  RelationshipSlice? relationshipWith(String otherId) {
    for (final rel in relationships) {
      if (rel.otherId == otherId) {
        return rel;
      }
    }
    return null;
  }

  SocialPositionSlice? positionIn(String contextId) {
    for (final pos in socialPositions) {
      if (pos.contextId == contextId) {
        return pos;
      }
    }
    return null;
  }

  CharacterCognitionSnapshot copyWith({
    String? characterId,
    String? name,
    String? role,
    List<CharacterBelief>? beliefs,
    List<RelationshipSlice>? relationships,
    List<SocialPositionSlice>? socialPositions,
    PresentationState? presentation,
  }) {
    return CharacterCognitionSnapshot(
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      role: role ?? this.role,
      beliefs: beliefs ?? this.beliefs,
      relationships: relationships ?? this.relationships,
      socialPositions: socialPositions ?? this.socialPositions,
      presentation: presentation ?? _presentation,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'name': name,
      'role': role,
      'beliefs': [for (final b in beliefs) b.toJson()],
      'relationships': [for (final r in relationships) r.toJson()],
      'socialPositions': [for (final p in socialPositions) p.toJson()],
      'presentation': presentation.toJson(),
    };
  }

  static CharacterCognitionSnapshot fromJson(Map<Object?, Object?> json) {
    return CharacterCognitionSnapshot(
      characterId: json['characterId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      beliefs: _decodeList(json['beliefs'], CharacterBelief.fromJson),
      relationships:
          _decodeList(json['relationships'], RelationshipSlice.fromJson),
      socialPositions:
          _decodeList(json['socialPositions'], SocialPositionSlice.fromJson),
      presentation: json['presentation'] is Map
          ? PresentationState.fromJson(
              Map<Object?, Object?>.from(json['presentation'] as Map),
            )
          : PresentationState(
              characterId: json['characterId']?.toString() ?? '',
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharacterCognitionSnapshot &&
        other.characterId == characterId &&
        other.name == name &&
        other.role == role &&
        _listEquals(other.beliefs, beliefs) &&
        _listEquals(other.relationships, relationships) &&
        _listEquals(other.socialPositions, socialPositions) &&
        other.presentation == presentation;
  }

  @override
  int get hashCode => Object.hash(
        characterId,
        name,
        role,
        Object.hashAll(beliefs),
        Object.hashAll(relationships),
        Object.hashAll(socialPositions),
        presentation,
      );
}

double _parseClampedDouble(Object? raw, {required double fallback}) {
  final parsed = double.tryParse(raw?.toString() ?? '');
  if (parsed == null) return fallback;
  return parsed.clamp(0.0, 1.0);
}

int _parseIntOrFallback(Object? raw, {required int fallback}) {
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

List<T> _decodeList<T>(
  Object? raw,
  T Function(Map<Object?, Object?>) decoder,
) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) decoder(Map<Object?, Object?>.from(item)),
  ];
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
