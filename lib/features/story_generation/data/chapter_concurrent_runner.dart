import '../../../app/state/app_settings_store.dart';
import 'pipeline_stage_runner_dependencies.dart';
import 'pipeline_stage_runner_impl.dart';
import 'character_memory_store.dart';
import 'generation_pipeline_config.dart';
import 'narrative_arc_models.dart';
import 'narrative_arc_tracker.dart';
import 'roleplay_session_store.dart';
import 'scene_pipeline_scheduler.dart';
import '../domain/scene_models.dart';

class ChapterConcurrentRunner {
  ChapterConcurrentRunner({
    required this.settingsStore,
    required this.pipelineConfig,
    this.roleplaySessionStore,
    this.characterMemoryStore,
  });

  final AppSettingsStore settingsStore;
  final GenerationPipelineConfig pipelineConfig;
  final RoleplaySessionStore? roleplaySessionStore;
  final CharacterMemoryStore? characterMemoryStore;

  Future<List<SceneRuntimeOutput>> runAll(
    List<SceneBrief> briefs, {
    NarrativeArcState? initialArc,
    void Function(int completed, int total, SceneRuntimeOutput output)?
    onSceneComplete,
  }) async {
    var latestArc = initialArc ?? NarrativeArcState();
    final arcTracker = NarrativeArcTracker();
    var completedCount = 0;

    final scheduler = ScenePipelineScheduler<SceneBrief, SceneRuntimeOutput>(
      maxConcurrentScenes: pipelineConfig.maxConcurrentScenes,
      canCommitResult: (result) =>
          result.review.decision == SceneReviewDecision.pass,
      onResultCommitted: (index, result) {
        completedCount++;
        latestArc = arcTracker.update(current: latestArc, output: result);
        onSceneComplete?.call(completedCount, briefs.length, result);
      },
    );

    return scheduler.run(
      scenes: briefs,
      runScene: (brief, {required onSpeculationReady}) async {
        final arcSnapshot = latestArc;
        final briefWithArc = brief.copyWith(narrativeArc: arcSnapshot);

        for (var attempt = 1; ; attempt++) {
          try {
            final orchestrator = PipelineStageRunnerImpl(
              settingsStore: settingsStore,
              pipelineConfig: pipelineConfig,
              dependencies: PipelineStageRunnerDependencies(
                roleplay: PipelineRoleplayDependencies(
                  roleplaySessionStore: roleplaySessionStore,
                  characterMemoryStore: characterMemoryStore,
                ),
              ),
            );

            final result = await orchestrator.runScene(
              briefWithArc,
              onSpeculationReady: onSpeculationReady,
            );

            if (result.review.decision == SceneReviewDecision.pass ||
                attempt >= pipelineConfig.maxSceneRetries) {
              return result;
            }
          } catch (_) {
            if (attempt >= pipelineConfig.maxSceneRetries) {
              rethrow;
            }
          }
        }
      },
    );
  }
}
