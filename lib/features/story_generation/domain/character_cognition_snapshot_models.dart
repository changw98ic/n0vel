import 'character_cognition_slice_models.dart';
import 'character_cognition_utils.dart';

// ---------------------------------------------------------------------------
// CharacterCognitionSnapshot — aggregated cognition state for one character.
// ---------------------------------------------------------------------------

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
      beliefs: decodeList(json['beliefs'], CharacterBelief.fromJson),
      relationships:
          decodeList(json['relationships'], RelationshipSlice.fromJson),
      socialPositions:
          decodeList(json['socialPositions'], SocialPositionSlice.fromJson),
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
        listEquals(other.beliefs, beliefs) &&
        listEquals(other.relationships, relationships) &&
        listEquals(other.socialPositions, socialPositions) &&
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
