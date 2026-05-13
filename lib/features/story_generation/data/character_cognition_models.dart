part of 'scene_pipeline_models.dart';

// ---------------------------------------------------------------------------
// Character cognition models
// ---------------------------------------------------------------------------

/// A character's belief about another character (or the world).
class CharacterBelief {
  const CharacterBelief({
    required this.holderId,
    required this.targetId,
    required this.aspect,
    required this.value,
  });

  final String holderId;
  final String targetId;
  final String aspect;
  final String value;
}

/// Dynamic relationship state between two characters in the current scene.
class RelationshipSlice {
  const RelationshipSlice({
    required this.characterA,
    required this.characterB,
    required this.label,
    this.tension = 0,
    this.trust = 0,
  });

  final String characterA;
  final String characterB;
  final String label;
  final int tension;
  final int trust;
}

/// A character's social position within the current scene context.
class SocialPositionSlice {
  const SocialPositionSlice({
    required this.characterId,
    required this.role,
    required this.formalRank,
    required this.actualInfluence,
  });

  final String characterId;
  final String role;
  final String formalRank;
  final String actualInfluence;
}

/// How a character presents themselves, including deception.
class PresentationState {
  const PresentationState({
    required this.characterId,
    required this.surfaceEmotion,
    required this.hiddenEmotion,
    required this.deceptionTarget,
    required this.deceptionContent,
  });

  final String characterId;
  final String surfaceEmotion;
  final String hiddenEmotion;
  final String deceptionTarget;
  final String deceptionContent;

  bool get isDeceptive => deceptionTarget.trim().isNotEmpty;
}
