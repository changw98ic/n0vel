part of 'scene_pipeline_models.dart';

// ---------------------------------------------------------------------------
// Knowledge & retrieval
// ---------------------------------------------------------------------------

/// A discrete piece of knowledge the system holds.
///
/// Lightweight snippet used by the pipeline's retrieval controller and task
/// card.  For the richer scene-level knowledge atom with visibility/budget
/// controls, see [scene_context_models.KnowledgeAtom].
class KnowledgeSnippet {
  const KnowledgeSnippet({
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
///
/// Lightweight intent with tool name, query string, and purpose.
/// For the richer domain-level retrieval request with parameters and
/// validation, see [pipeline_models.RetrievalIntent].
class LightRetrievalIntent {
  const LightRetrievalIntent({
    required this.toolName,
    required this.query,
    required this.purpose,
  });

  final String toolName;
  final String query;
  final String purpose;

  static const String kToolStructuredProfile = 'character_profile';
  static const String kToolRelationship = 'relationship';
  static const String kToolWorldSetting = 'world_setting';
  static const String kToolPastEvent = 'past_event';
  static const String kToolWritingReference = 'search_writing_reference';
}

/// A compressed retrieval result injected into prompts as a capsule.
///
/// Lightweight capsule used by the legacy pipeline's retrieval controller.
/// For the richer domain-level capsule with budget management, see
/// [pipeline_models.ContextCapsule].  For the runtime capsule with
/// visibility scopes and TTL, see [scene_runtime_models.ContextCapsule].
class LightContextCapsule {
  const LightContextCapsule({
    required this.intent,
    required this.summary,
    required this.tokenBudget,
  });

  final LightRetrievalIntent intent;
  final String summary;
  final int tokenBudget;
}
