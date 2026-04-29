import 'scene_models.dart';
import 'memory_models.dart';
import '../data/scene_pipeline_models.dart' show SceneTaskCard;
import '../data/scene_roleplay_session_models.dart';

/// Resolves scene cast members from a brief.
abstract interface class SceneCastResolverService {
  List<ResolvedSceneCastMember> resolve(SceneBrief brief);
}

/// Runs the scene director planning pass.
abstract interface class SceneDirectorService {
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  });
}

/// Runs dynamic role agents for scene characters.
abstract interface class DynamicRoleAgentService {
  Future<List<DynamicRoleAgentOutput>> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    required SceneDirectorOutput director,
    SceneTaskCard? taskCard,
    String? ragContext,
    void Function(String message)? onStatus,
  });
}

/// Generates scene prose from director plan and role outputs.
abstract interface class SceneProseService {
  Future<SceneProseDraft> generate({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required int attempt,
    String? reviewFeedback,
  });
}

/// Reviews generated scene prose across multiple passes.
abstract interface class SceneReviewService {
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview,
    bool enableLexiconReview,
    void Function(String message)? onStatus,
  });
}

/// Assembles scene context from project materials.
abstract interface class SceneContextAssemblerService {
  SceneContextAssembly assemble({
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
  });
}

/// Retrieves memory packs for scene context enrichment.
abstract interface class StoryMemoryRetrieverService {
  Future<StoryRetrievalPack> retrieve(StoryMemoryQuery query);
}

/// Extracts and persists thought atoms after scene acceptance.
abstract interface class ThoughtMemoryService {
  Future<ThoughtUpdateResult> extractWithLlm({
    required String projectId,
    required SceneRuntimeOutput sceneOutput,
    int? nowMs,
  });

  Future<ThoughtUpdateResult> extractLocal({
    required String projectId,
    required SceneRuntimeOutput sceneOutput,
    int? nowMs,
  });
}

/// Top-level orchestrator for running a complete scene generation pipeline.
abstract interface class ChapterGenerationService {
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function(String message)? onStatus,
  });

  RetrievalTrace? get lastRetrievalTrace;
}

/// Scores a generated scene across multiple quality dimensions.
abstract interface class SceneQualityScorerService {
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  });
}

/// Bridge for cross-chapter context passing.
///
/// Manages chapter-level summaries and loads context from previous chapters
/// to enrich scene generation for continuity across chapter boundaries.
abstract interface class ChapterContextBridgeService {
  /// Persists a chapter summary for cross-chapter retrieval.
  Future<void> saveChapterSummary(String projectId, ChapterSummary summary);

  /// Loads all chapter summaries for a project, ordered by creation time.
  Future<List<ChapterSummary>> loadChapterSummaries(String projectId);

  /// Creates a compressed chapter summary from completed scene outputs.
  ChapterSummary summarizeFromOutputs({
    required String chapterId,
    required String chapterTitle,
    required List<SceneRuntimeOutput> outputs,
    int? nowMs,
  });

  /// Builds cross-chapter context for a new chapter by loading summaries
  /// and key thoughts from previous chapters.
  Future<CrossChapterContext> buildCrossChapterContext({
    required String projectId,
    required String currentChapterId,
    int maxPreviousChapters,
  });

  /// Enriches a material snapshot with cross-chapter context data.
  ProjectMaterialSnapshot enrichMaterialSnapshot(
    ProjectMaterialSnapshot base,
    CrossChapterContext context,
  );
}
