import 'package:novel_writer/app/state/app_storage_clone.dart';
import 'story_generation_models.dart';
import 'story_prompt_templates.dart';

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

// ---------------------------------------------------------------------------
// Knowledge & retrieval
// ---------------------------------------------------------------------------

/// A discrete piece of knowledge the system holds.
class KnowledgeAtom {
  const KnowledgeAtom({
    required this.id,
    required this.category,
    required this.content,
    required this.sourceId,
  });

  final String id;
  final String category;
  final String content;
  final String sourceId;
}

/// What a role agent wants to retrieve mid-turn.
class RetrievalIntent {
  const RetrievalIntent({
    required this.toolName,
    required this.query,
    required this.purpose,
  });

  final String toolName;
  final String query;
  final String purpose;

  static const String kToolCharacterProfile = 'character_profile';
  static const String kToolRelationship = 'relationship';
  static const String kToolWorldSetting = 'world_setting';
  static const String kToolPastEvent = 'past_event';
}

/// A compressed retrieval result injected into prompts as a capsule.
class ContextCapsule {
  const ContextCapsule({
    required this.intent,
    required this.summary,
    required this.tokenBudget,
  });

  final RetrievalIntent intent;
  final String summary;
  final int tokenBudget;
}

// ---------------------------------------------------------------------------
// Roleplay turn output (replaces free-form DynamicRoleAgentOutput in pipeline)
// ---------------------------------------------------------------------------

class RolePlayTurnOutput {
  RolePlayTurnOutput({
    required this.characterId,
    required this.name,
    required this.stance,
    required this.action,
    required this.taboo,
    required List<RetrievalIntent> retrievalIntents,
    this.disclosure = '',
    this.presentation,
    Map<String, Object?> metadata = const {},
  }) : retrievalIntents = _immutableList(retrievalIntents),
       metadata = _immutableMap(metadata);

  final String characterId;
  final String name;
  final String stance;
  final String action;
  final String taboo;
  final List<RetrievalIntent> retrievalIntents;
  final String disclosure;
  final PresentationState? presentation;
  final Map<String, Object?> metadata;

  factory RolePlayTurnOutput.fromDynamicAgentOutput(
    DynamicRoleAgentOutput output,
  ) {
    final lines = output.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    String stance = '';
    String action = '';
    String taboo = '';
    String disclosure = '';
    final retrievalIntents = <RetrievalIntent>[];
    final l = StoryPromptTemplates.locale;
    final stancePrefix = '${l.stanceLabel}${l.colon}';
    final actionPrefix = '${l.actionLabel}${l.colon}';
    final tabooPrefix = '${l.tabooLabel}${l.colon}';
    final retrievalPrefix = '${l.retrievalLabel}${l.colon}';
    const disclosurePrefix = '披露：';
    const processPrefix = '过程：';
    const statePrefix = '局面：';
    for (final line in lines) {
      if (line.startsWith(stancePrefix)) {
        stance = line.substring(stancePrefix.length).trim();
      } else if (line.startsWith(actionPrefix)) {
        action = line.substring(actionPrefix.length).trim();
      } else if (line.startsWith(tabooPrefix)) {
        taboo = line.substring(tabooPrefix.length).trim();
      } else if (line.startsWith(disclosurePrefix)) {
        disclosure = line.substring(disclosurePrefix.length).trim();
      } else if (line.startsWith(processPrefix)) {
        final process = line.substring(processPrefix.length).trim();
        disclosure = _appendDisclosure(disclosure, process);
      } else if (line.startsWith(statePrefix)) {
        final state = line.substring(statePrefix.length).trim();
        disclosure = _appendDisclosure(disclosure, state);
      } else if (line.startsWith(retrievalPrefix)) {
        final intent = _parseRetrievalIntent(
          line.substring(retrievalPrefix.length).trim(),
        );
        if (intent != null) {
          retrievalIntents.add(intent);
        }
      }
    }

    return RolePlayTurnOutput(
      characterId: output.characterId,
      name: output.name,
      stance: stance,
      action: action,
      taboo: taboo,
      retrievalIntents: retrievalIntents,
      disclosure: disclosure,
    );
  }

  static String _appendDisclosure(String current, String value) {
    if (value.isEmpty) return current;
    if (current.isEmpty) return value;
    return '$current / $value';
  }

  static RetrievalIntent? _parseRetrievalIntent(String raw) {
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    return RetrievalIntent(
      toolName: parts[0].trim(),
      query: parts[1].trim(),
      purpose: parts.length > 2 ? parts[2].trim() : '',
    );
  }
}

// ---------------------------------------------------------------------------
// Scene director structured plan
// ---------------------------------------------------------------------------

/// Pacing hint for a scene.
enum ScenePacing { slow, medium, fast }

/// Per-character direction note generated by the scene director.
class DirectorCharacterNote {
  const DirectorCharacterNote({
    required this.characterId,
    required this.name,
    this.motivation = '',
    this.emotionalArc = '',
    this.keyAction = '',
  });

  final String characterId;
  final String name;
  final String motivation;
  final String emotionalArc;
  final String keyAction;
}

/// Structured representation of the director's 4-line plan plus metadata.
class SceneDirectorPlan {
  SceneDirectorPlan({
    required this.target,
    required this.conflict,
    required this.progression,
    required this.constraints,
    this.tone = '',
    this.pacing = ScenePacing.medium,
    List<DirectorCharacterNote> characterNotes = const [],
  }) : characterNotes = _immutableList(characterNotes);

  final String target;
  final String conflict;
  final String progression;
  final String constraints;
  final String tone;
  final ScenePacing pacing;
  final List<DirectorCharacterNote> characterNotes;

  /// Reconstruct the standard 4-line text format.
  String toText() {
    final l = StoryPromptTemplates.locale;
    return [
      '${l.targetLabel}${l.colon}$target',
      '${l.conflictLabel}${l.colon}$conflict',
      '${l.progressionLabel}${l.colon}$progression',
      '${l.constraintLabel}${l.colon}$constraints',
    ].join('\n');
  }

  /// Find the direction note for [characterId], if any.
  DirectorCharacterNote? noteFor(String characterId) {
    for (final note in characterNotes) {
      if (note.characterId == characterId) return note;
    }
    return null;
  }

  /// Parse from the standard 4-line format. Returns `null` if the format
  /// doesn't match.
  static SceneDirectorPlan? tryParse(String text) {
    final l = StoryPromptTemplates.locale;
    final targetPrefix = '${l.targetLabel}${l.colon}';
    final conflictPrefix = '${l.conflictLabel}${l.colon}';
    final progressionPrefix = '${l.progressionLabel}${l.colon}';
    final constraintPrefix = '${l.constraintLabel}${l.colon}';
    final lines = text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
    if (lines.length < 4) return null;
    if (!lines[0].startsWith(targetPrefix)) return null;
    if (!lines[1].startsWith(conflictPrefix)) return null;
    if (!lines[2].startsWith(progressionPrefix)) return null;
    if (!lines[3].startsWith(constraintPrefix)) return null;
    return SceneDirectorPlan(
      target: lines[0].substring(targetPrefix.length),
      conflict: lines[1].substring(conflictPrefix.length),
      progression: lines[2].substring(progressionPrefix.length),
      constraints: lines[3].substring(constraintPrefix.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Scene task card
// ---------------------------------------------------------------------------

class SceneTaskCard {
  SceneTaskCard({
    required this.brief,
    required List<ResolvedSceneCastMember> cast,
    this.directorPlan = '',
    this.directorPlanParsed,
    List<CharacterBelief> beliefs = const [],
    List<RelationshipSlice> relationships = const [],
    List<SocialPositionSlice> socialPositions = const [],
    List<KnowledgeAtom> knowledge = const [],
    Map<String, Object?> metadata = const {},
  }) : cast = _immutableList(cast),
       beliefs = _immutableList(beliefs),
       relationships = _immutableList(relationships),
       socialPositions = _immutableList(socialPositions),
       knowledge = _immutableList(knowledge),
       metadata = _immutableMap(metadata);

  final SceneBrief brief;
  final List<ResolvedSceneCastMember> cast;
  final String directorPlan;
  final SceneDirectorPlan? directorPlanParsed;
  final List<CharacterBelief> beliefs;
  final List<RelationshipSlice> relationships;
  final List<SocialPositionSlice> socialPositions;
  final List<KnowledgeAtom> knowledge;
  final Map<String, Object?> metadata;

  /// Beliefs held by [characterId] about others.
  List<CharacterBelief> beliefsFor(String characterId) => [
    for (final b in beliefs)
      if (b.holderId == characterId) b,
  ];

  /// Relationship slices involving [characterId].
  List<RelationshipSlice> relationshipsFor(String characterId) => [
    for (final r in relationships)
      if (r.characterA == characterId || r.characterB == characterId) r,
  ];

  /// Social position for [characterId], if any.
  SocialPositionSlice? socialPositionFor(String characterId) {
    for (final sp in socialPositions) {
      if (sp.characterId == characterId) return sp;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Resolved scene beat
// ---------------------------------------------------------------------------

enum SceneBeatKind { fact, dialogue, action, internal, narration }

class SceneBeat {
  const SceneBeat({
    required this.kind,
    required this.content,
    required this.sourceCharacterId,
    this.order = 0,
  });

  final SceneBeatKind kind;
  final String content;
  final String sourceCharacterId;
  final int order;
}

// ---------------------------------------------------------------------------
// Scene editorial draft
// ---------------------------------------------------------------------------

class SceneEditorialDraft {
  const SceneEditorialDraft({
    required this.text,
    required this.beatCount,
    required this.attempt,
  });

  final String text;
  final int beatCount;
  final int attempt;
}

// ---------------------------------------------------------------------------
// Pipeline runtime output (extends SceneRuntimeOutput concept)
// ---------------------------------------------------------------------------

class ScenePipelineOutput {
  ScenePipelineOutput({
    required this.taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<ContextCapsule> capsules,
    required List<SceneBeat> resolvedBeats,
    required this.editorialDraft,
    required this.review,
    required this.proseAttempts,
    required this.softFailureCount,
  }) : roleTurns = _immutableList(roleTurns),
       capsules = _immutableList(capsules),
       resolvedBeats = _immutableList(resolvedBeats);

  final SceneTaskCard taskCard;
  final List<RolePlayTurnOutput> roleTurns;
  final List<ContextCapsule> capsules;
  final List<SceneBeat> resolvedBeats;
  final SceneEditorialDraft editorialDraft;
  final SceneReviewResult review;
  final int proseAttempts;
  final int softFailureCount;
}

// ---------------------------------------------------------------------------
// Helpers (shared with story_generation_models.dart pattern)
// ---------------------------------------------------------------------------

List<T> _immutableList<T>(List<T> items) => List<T>.unmodifiable(items);

Map<String, Object?> _immutableMap(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in cloneStorageMap(value).entries)
        entry.key: _immutableValue(entry.value),
    });

Object? _immutableValue(Object? value) {
  if (value is Map<String, Object?>) return _immutableMap(value);
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _immutableValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (final item in value) _immutableValue(item),
    ]);
  }
  return value;
}
