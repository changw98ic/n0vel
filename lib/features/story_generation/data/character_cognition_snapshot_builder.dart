import 'package:novel_writer/app/state/app_workspace_store.dart';

import '../domain/character_cognition_models.dart';

class CharacterCognitionSnapshotBuilder {
  CharacterCognitionSnapshot build({
    required CharacterRecord record,
    List<CharacterBelief> beliefs = const [],
    List<RelationshipSlice> relationships = const [],
    List<SocialPositionSlice> socialPositions = const [],
    PresentationState presentation = const PresentationState(characterId: ''),
  }) {
    return CharacterCognitionSnapshot(
      characterId: record.id,
      name: record.name,
      role: record.role,
      beliefs: beliefs,
      relationships: relationships,
      socialPositions: socialPositions,
      presentation:
          presentation.characterId.isEmpty
              ? PresentationState(characterId: record.id)
              : presentation,
    );
  }

  CharacterCognitionSnapshot buildMinimal(CharacterRecord record) {
    return CharacterCognitionSnapshot(
      characterId: record.id,
      name: record.name,
      role: record.role,
    );
  }

  List<CharacterCognitionSnapshot> buildForScene({
    required List<CharacterRecord> characters,
    required String sceneId,
    List<CharacterBelief> beliefs = const [],
    List<RelationshipSlice> relationships = const [],
    List<SocialPositionSlice> socialPositions = const [],
    List<PresentationState> presentations = const [],
  }) {
    final beliefIndex = _indexById<CharacterBelief>(
      beliefs,
      (b) => b.subjectId,
    );
    final relIndex = _indexById<RelationshipSlice>(
      relationships,
      (r) => r.characterId,
    );
    final posIndex = _indexById<SocialPositionSlice>(
      socialPositions,
      (p) => p.characterId,
    );
    final presIndex = _indexById<PresentationState>(
      presentations,
      (p) => p.characterId,
    );

    return [
      for (final record in characters)
        CharacterCognitionSnapshot(
          characterId: record.id,
          name: record.name,
          role: record.role,
          beliefs: beliefIndex[record.id] ?? const [],
          relationships: relIndex[record.id] ?? const [],
          socialPositions:
              (posIndex[record.id] ?? const [])
                  .where((p) => p.contextId == sceneId || p.contextId.isEmpty)
                  .toList(),
          presentation: presIndex[record.id]?.firstOrNull ?? PresentationState(
            characterId: record.id,
          ),
        ),
    ];
  }

  /// Builds a [CharacterCognitionSnapshot] from projected [atoms] with
  /// source traces.
  ///
  /// Atoms are sorted by [CharacterCognitionAtom.sequence] and grouped by
  /// [CognitionKind] into the appropriate snapshot sections:
  ///
  /// - [CognitionKind.perceivedEvent], [CognitionKind.reportedEvent],
  ///   [CognitionKind.acceptedBelief], [CognitionKind.inference] map to
  ///   [CharacterBelief] entries at their native certainty.
  /// - [CognitionKind.suspicion], [CognitionKind.uncertainty] map to
  ///   [CharacterBelief] entries with reduced confidence.
  /// - [CognitionKind.goal], [CognitionKind.intent] produce [CharacterBelief]
  ///   entries with the atom kind noted in source.
  /// - [CognitionKind.relationshipView] maps to [RelationshipSlice] entries.
  /// - [CognitionKind.selfState] updates the [PresentationState].
  /// - [CognitionKind.presentation], [CognitionKind.memory] are carried over
  ///   as-is from existing state via the optional parameters.
  ///
  /// Each generated entry preserves the originating atom ID in its [source]
  /// field for traceability.
  static CharacterCognitionSnapshot buildSnapshot({
    required String characterId,
    required String name,
    required String role,
    required List<CharacterCognitionAtom> atoms,
  }) {
    final sorted = CharacterCognitionAtom.sorted(atoms);

    final beliefs = <CharacterBelief>[];
    final relationships = <RelationshipSlice>[];
    PresentationState presentation = PresentationState(
      characterId: characterId,
    );

    for (final atom in sorted) {
      switch (atom.kind) {
        case CognitionKind.perceivedEvent:
        case CognitionKind.reportedEvent:
          beliefs.add(CharacterBelief(
            subjectId: characterId,
            targetId: _firstOrEmpty(atom.sourceCharacterIds),
            claim: atom.content,
            confidence: atom.certainty,
            source: atom.id,
          ));

        case CognitionKind.acceptedBelief:
        case CognitionKind.inference:
          beliefs.add(CharacterBelief(
            subjectId: characterId,
            targetId: _firstOrEmpty(atom.sourceCharacterIds),
            claim: atom.content,
            confidence: atom.certainty,
            source: atom.id,
          ));

        case CognitionKind.suspicion:
        case CognitionKind.uncertainty:
          beliefs.add(CharacterBelief(
            subjectId: characterId,
            targetId: _firstOrEmpty(atom.sourceCharacterIds),
            claim: atom.content,
            confidence: atom.certainty * 0.5,
            source: atom.id,
          ));

        case CognitionKind.goal:
        case CognitionKind.intent:
          beliefs.add(CharacterBelief(
            subjectId: characterId,
            targetId: '',
            claim: atom.content,
            confidence: atom.certainty,
            source: '${atom.kind.name}:${atom.id}',
          ));

        case CognitionKind.relationshipView:
          relationships.add(RelationshipSlice(
            characterId: characterId,
            otherId: _firstOrEmpty(atom.sourceCharacterIds),
            kind: atom.kind.name,
            trust: atom.certainty,
            tension: 1.0 - atom.certainty,
            notes: atom.content,
          ));

        case CognitionKind.selfState:
          presentation = presentation.copyWith(
            displayedEmotion: atom.content,
          );

        case CognitionKind.presentation:
        case CognitionKind.memory:
          break;
      }
    }

    return CharacterCognitionSnapshot(
      characterId: characterId,
      name: name,
      role: role,
      beliefs: beliefs,
      relationships: relationships,
      presentation: presentation,
    );
  }
}

Map<String, List<T>> _indexById<T>(
  List<T> items,
  String Function(T) idExtractor,
) {
  final index = <String, List<T>>{};
  for (final item in items) {
    final id = idExtractor(item);
    index.putIfAbsent(id, () => []).add(item);
  }
  return index;
}

String _firstOrEmpty(List<String> list) {
  return list.isNotEmpty ? list.first : '';
}
