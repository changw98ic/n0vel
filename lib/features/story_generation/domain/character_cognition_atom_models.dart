import 'character_cognition_utils.dart';

// ---------------------------------------------------------------------------
// CognitionKind enum & CharacterCognitionAtom — the atomic cognition unit.
// ---------------------------------------------------------------------------

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
      sequence: parseIntOrFallback(json['sequence'], fallback: 0),
      kind: _parseCognitionKind(json['kind']),
      content: json['content']?.toString() ?? '',
      sourceEventIds: _parseStringList(json['sourceEventIds']),
      sourceCharacterIds: _parseStringList(json['sourceCharacterIds']),
      certainty: parseClampedDouble(json['certainty'], fallback: 1.0),
      salience: parseClampedDouble(json['salience'], fallback: 0.5),
      emotionalWeight: parseClampedDouble(
        json['emotionalWeight'],
        fallback: 0.0,
      ),
      tags: _parseStringList(json['tags']),
      supersedesAtomIds: _parseStringList(json['supersedesAtomIds']),
      createdAtMs: parseIntOrFallback(json['createdAtMs'], fallback: 0),
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
        listEquals(other.sourceEventIds, sourceEventIds) &&
        listEquals(other.sourceCharacterIds, sourceCharacterIds) &&
        other.certainty == certainty &&
        other.salience == salience &&
        other.emotionalWeight == emotionalWeight &&
        listEquals(other.tags, tags) &&
        listEquals(other.supersedesAtomIds, supersedesAtomIds) &&
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

// ---------------------------------------------------------------------------
// Private helpers local to this file.
// ---------------------------------------------------------------------------

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
