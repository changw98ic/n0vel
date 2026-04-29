import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';

/// Builds [SceneBrief] instances from [ScenePlan] or legacy outline data.
///
/// This is the bridge between the planning layer ([ScenePlan]/[ChapterPlan])
/// and the runtime orchestration layer ([SceneBrief]).
class SceneBriefBuilder {
  SceneBriefBuilder._();

  /// Build a [SceneBrief] from a [ScenePlan] (primary path).
  ///
  /// Maps plan fields to brief fields and enriches metadata with beat summary
  /// and plan reference information. Cast and narrative arc are left empty/null
  /// for later population by cast resolver and arc tracker respectively.
  static SceneBrief fromScenePlan({
    required ScenePlan plan,
    required ChapterPlan chapterPlan,
    String? projectId,
  }) {
    final sortedBeats = List<BeatPlan>.from(plan.beats)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final targetBeat = sortedBeats.isNotEmpty ? sortedBeats.first.content : '';
    final beatSummary = sortedBeats
        .take(3)
        .map((b) => b.content)
        .join(' / ');

    final transitionId = sortedBeats
        .where((b) => b.transitionTarget != null)
        .map((b) => b.transitionTarget!.id)
        .firstOrNull;

    final enrichedMetadata = <String, Object?>{
      ...plan.metadata,
      '_beatSummary': beatSummary,
      '_planId': plan.id,
      if (transitionId != null) '_transitionId': transitionId,
    };

    return SceneBrief(
      projectId: projectId,
      chapterId: chapterPlan.id,
      chapterTitle: chapterPlan.title,
      sceneId: plan.id,
      sceneTitle: plan.title,
      sceneSummary: plan.summary,
      targetLength: plan.targetLength,
      targetBeat: targetBeat,
      worldNodeIds: plan.worldNodeIds,
      metadata: enrichedMetadata,
    );
  }

  /// Build a [SceneBrief] from legacy outline snapshot (fallback path).
  ///
  /// Straight field mapping with no enrichment. Used when a [ScenePlan] is
  /// unavailable and only raw outline data exists.
  static SceneBrief fromLegacyOutline({
    required String chapterId,
    required String chapterTitle,
    required String sceneId,
    required String sceneTitle,
    required String sceneSummary,
    String? projectId,
    List<String> worldNodeIds = const [],
    String targetBeat = '',
  }) {
    return SceneBrief(
      projectId: projectId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      sceneId: sceneId,
      sceneTitle: sceneTitle,
      sceneSummary: sceneSummary,
      worldNodeIds: worldNodeIds,
      targetBeat: targetBeat,
    );
  }

  /// Build a [SceneBrief] with priority: [ScenePlan] first, legacy fallback.
  ///
  /// When [plan] and [chapterPlan] are both provided, delegates to
  /// [fromScenePlan]. Otherwise falls back to [fromLegacyOutline] using the
  /// legacy* parameters.
  static SceneBrief build({
    ScenePlan? plan,
    ChapterPlan? chapterPlan,
    String? projectId,
    // legacy fallback args
    String? legacyChapterId,
    String? legacyChapterTitle,
    String? legacySceneId,
    String? legacySceneTitle,
    String? legacySceneSummary,
    List<String> legacyWorldNodeIds = const [],
    String legacyTargetBeat = '',
  }) {
    if (plan != null && chapterPlan != null) {
      return fromScenePlan(
        plan: plan,
        chapterPlan: chapterPlan,
        projectId: projectId,
      );
    }

    return fromLegacyOutline(
      chapterId: legacyChapterId ?? '',
      chapterTitle: legacyChapterTitle ?? '',
      sceneId: legacySceneId ?? '',
      sceneTitle: legacySceneTitle ?? '',
      sceneSummary: legacySceneSummary ?? '',
      projectId: projectId,
      worldNodeIds: legacyWorldNodeIds,
      targetBeat: legacyTargetBeat,
    );
  }
}
