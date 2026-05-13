part of 'scene_pipeline_models.dart';

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
  static const String kToolWritingReference = 'search_writing_reference';
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
