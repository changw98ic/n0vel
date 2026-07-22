part of 'scene_pipeline_models.dart';

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
    this.sourceLogicalAttemptId,
    this.sourceCallSiteId,
  });

  final String text;
  final int beatCount;
  final int attempt;
  final String? sourceLogicalAttemptId;
  final String? sourceCallSiteId;
}
