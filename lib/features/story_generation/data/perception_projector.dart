import '../domain/character_cognition_models.dart';

/// A discrete event within a scene that can be projected into character cognition.
class SceneEvent {
  SceneEvent({
    required this.id,
    required this.sceneId,
    required this.type,
    required this.content,
    required this.sequence,
    this.speakerId,
    List<String> presentCharacterIds = const [],
    List<String> targetIds = const [],
    Map<String, Object?> metadata = const {},
  })  : presentCharacterIds =
            List<String>.unmodifiable(presentCharacterIds),
        targetIds = List<String>.unmodifiable(targetIds),
        metadata = Map<String, Object?>.unmodifiable(metadata);

  final String id;
  final String sceneId;

  /// 'dialogue', 'action', 'description', 'internal', 'transition'
  final String type;
  final String content;

  /// Who spoke or initiated. Null for narration / description.
  final String? speakerId;

  /// Characters physically present and able to observe.
  final List<String> presentCharacterIds;

  /// Characters targeted or affected by the event.
  final List<String> targetIds;

  /// Ordering within the scene.
  final int sequence;
  final Map<String, Object?> metadata;

  SceneEvent copyWith({
    String? id,
    String? sceneId,
    String? type,
    String? content,
    String? speakerId,
    List<String>? presentCharacterIds,
    List<String>? targetIds,
    int? sequence,
    Map<String, Object?>? metadata,
  }) {
    return SceneEvent(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      type: type ?? this.type,
      content: content ?? this.content,
      speakerId: speakerId ?? this.speakerId,
      presentCharacterIds: presentCharacterIds ?? this.presentCharacterIds,
      targetIds: targetIds ?? this.targetIds,
      sequence: sequence ?? this.sequence,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'type': type,
      'content': content,
      'speakerId': speakerId,
      'presentCharacterIds': presentCharacterIds,
      'targetIds': targetIds,
      'sequence': sequence,
      'metadata': metadata,
    };
  }

  static SceneEvent fromJson(Map<Object?, Object?> json) {
    return SceneEvent(
      id: json['id']?.toString() ?? '',
      sceneId: json['sceneId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      speakerId: json['speakerId']?.toString(),
      presentCharacterIds: _parseStringList(json['presentCharacterIds']),
      targetIds: _parseStringList(json['targetIds']),
      sequence: _parseIntOrFallback(json['sequence'], fallback: 0),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SceneEvent &&
        other.id == id &&
        other.sceneId == sceneId &&
        other.type == type &&
        other.content == content &&
        other.speakerId == speakerId &&
        _listEquals(other.presentCharacterIds, presentCharacterIds) &&
        _listEquals(other.targetIds, targetIds) &&
        other.sequence == sequence &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        id,
        sceneId,
        type,
        content,
        speakerId,
        Object.hashAll(presentCharacterIds),
        Object.hashAll(targetIds),
        sequence,
        Object.hashAllUnordered(metadata.entries),
      );
}

/// Projects scene events into per-character cognition atoms.
///
/// Core rules:
/// - Present characters receive observable cognition (perceivedEvent).
/// - Absent characters receive NOTHING (no implicit private knowledge).
/// - Speaker events become 'selfState' for the speaker, 'perceivedEvent' for
///   listeners.
/// - Actions targeting characters become 'perceivedEvent' for witnesses.
/// - Internal events only create atoms for the subject character (selfState).
/// - Description / transition events create 'perceivedEvent' for all present
///   characters.
class PerceptionProjector {
  /// Project [events] into per-character cognition atoms.
  ///
  /// [activeCharacterIds] is the full set of characters in the scene, used for
  /// validation. Only characters listed in each event's [SceneEvent.presentCharacterIds]
  /// actually receive atoms.
  List<CharacterCognitionAtom> project({
    required List<SceneEvent> events,
    required List<String> activeCharacterIds,
    String projectId = '',
  }) {
    if (events.isEmpty) return const [];

    final atoms = <CharacterCognitionAtom>[];
    var atomSeq = 0;

    for (final event in events) {
      final present = event.presentCharacterIds;
      final speaker = event.speakerId;

      switch (event.type) {
        case 'dialogue':
          atomSeq = _projectDialogue(
            event: event,
            present: present,
            speaker: speaker,
            atoms: atoms,
            seq: atomSeq,
            projectId: projectId,
          );

        case 'action':
          atomSeq = _projectAction(
            event: event,
            present: present,
            atoms: atoms,
            seq: atomSeq,
            projectId: projectId,
          );

        case 'internal':
          atomSeq = _projectInternal(
            event: event,
            present: present,
            speaker: speaker,
            atoms: atoms,
            seq: atomSeq,
            projectId: projectId,
          );

        case 'description':
        case 'transition':
          atomSeq = _projectEnvironmental(
            event: event,
            present: present,
            atoms: atoms,
            seq: atomSeq,
            projectId: projectId,
          );
      }
    }

    return List<CharacterCognitionAtom>.unmodifiable(atoms);
  }

  /// Dialogue: speaker gets selfState, all other present characters get
  /// perceivedEvent.
  int _projectDialogue({
    required SceneEvent event,
    required List<String> present,
    required String? speaker,
    required List<CharacterCognitionAtom> atoms,
    required int seq,
    required String projectId,
  }) {
    if (speaker != null && present.contains(speaker)) {
      atoms.add(CharacterCognitionAtom.selfState(
        id: '${event.id}_${speaker}_$seq',
        projectId: projectId,
        characterId: speaker,
        sceneId: event.sceneId,
        sequence: seq,
        content: '我说：「${event.content}」',
        sourceEventIds: [event.id],
        sourceCharacterIds: [speaker],
        certainty: 1.0,
      ));
      seq += 1;
    }

    for (final charId in present) {
      if (charId == speaker) continue;
      atoms.add(CharacterCognitionAtom.perceivedEvent(
        id: '${event.id}_${charId}_$seq',
        projectId: projectId,
        characterId: charId,
        sceneId: event.sceneId,
        sequence: seq,
        content: speaker != null
            ? '$speaker说：「${event.content}」'
            : '有人说了：「${event.content}」',
        sourceEventIds: [event.id],
        sourceCharacterIds: speaker != null ? [speaker] : const [],
        certainty: 1.0,
      ));
      seq += 1;
    }

    return seq;
  }

  /// Action: all present witnesses get perceivedEvent. Targets that are
  /// present also get perceivedEvent (covered by the present loop).
  int _projectAction({
    required SceneEvent event,
    required List<String> present,
    required List<CharacterCognitionAtom> atoms,
    required int seq,
    required String projectId,
  }) {
    for (final charId in present) {
      final isTarget = event.targetIds.contains(charId);
      atoms.add(CharacterCognitionAtom.perceivedEvent(
        id: '${event.id}_${charId}_$seq',
        projectId: projectId,
        characterId: charId,
        sceneId: event.sceneId,
        sequence: seq,
        content: isTarget
            ? '我经历了：${event.content}'
            : '我观察到：${event.content}',
        sourceEventIds: [event.id],
        sourceCharacterIds: event.speakerId != null ? [event.speakerId!] : [],
        certainty: 1.0,
      ));
      seq += 1;
    }
    return seq;
  }

  /// Internal: only the subject (speakerId) gets a selfState atom, and only
  /// if they are present.
  int _projectInternal({
    required SceneEvent event,
    required List<String> present,
    required String? speaker,
    required List<CharacterCognitionAtom> atoms,
    required int seq,
    required String projectId,
  }) {
    if (speaker == null) return seq;
    if (!present.contains(speaker)) return seq;

    atoms.add(CharacterCognitionAtom.selfState(
      id: '${event.id}_${speaker}_$seq',
      projectId: projectId,
      characterId: speaker,
      sceneId: event.sceneId,
      sequence: seq,
      content: '内心独白：${event.content}',
      sourceEventIds: [event.id],
      sourceCharacterIds: [speaker],
      certainty: 1.0,
    ));
    return seq + 1;
  }

  /// Description / transition: all present characters get perceivedEvent.
  int _projectEnvironmental({
    required SceneEvent event,
    required List<String> present,
    required List<CharacterCognitionAtom> atoms,
    required int seq,
    required String projectId,
  }) {
    for (final charId in present) {
      atoms.add(CharacterCognitionAtom.perceivedEvent(
        id: '${event.id}_${charId}_$seq',
        projectId: projectId,
        characterId: charId,
        sceneId: event.sceneId,
        sequence: seq,
        content: '场景描述：${event.content}',
        sourceEventIds: [event.id],
        certainty: 1.0,
      ));
      seq += 1;
    }
    return seq;
  }
}

// ---------------------------------------------------------------------------
// Private parsing helpers
// ---------------------------------------------------------------------------

List<String> _parseStringList(Object? raw) {
  if (raw is! List) return const [];
  return List<String>.unmodifiable([
    for (final item in raw) item?.toString() ?? '',
  ]);
}

int _parseIntOrFallback(Object? raw, {required int fallback}) {
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}
