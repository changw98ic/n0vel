import '../domain/contracts/settings_contract.dart';
import 'ai_cliche_detector.dart';
import 'pipeline_stage_runner_impl.dart';
import 'character_memory_store.dart';
import 'generation_pipeline_config.dart';
import 'narrative_arc_models.dart';
import 'narrative_arc_tracker.dart';
import 'pipeline_event_log.dart';
import 'roleplay_session_store.dart';
import 'scene_pipeline_scheduler.dart';
import '../domain/contracts/stage_runner.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

class ChapterCrossSceneClicheGateFailure implements Exception {
  ChapterCrossSceneClicheGateFailure(List<AiClicheFinding> findings)
    : findings = List<AiClicheFinding>.unmodifiable(findings);

  final List<AiClicheFinding> findings;

  @override
  String toString() =>
      'ChapterCrossSceneClicheGateFailure: ${findings.map((finding) => '${finding.kind.label} ${finding.context}').join('；')}';
}

class ChapterCrossSceneClicheGate {
  const ChapterCrossSceneClicheGate();

  List<AiClicheFinding> evaluate(Map<String, String> orderedScenes) {
    final report = AiClicheDetector().detectAcrossScenes(orderedScenes);
    return List<AiClicheFinding>.unmodifiable(
      report.findings.where(
        (finding) => finding.kind.name.startsWith('crossScene'),
      ),
    );
  }

  void enforce(Map<String, String> orderedScenes) {
    final findings = evaluate(orderedScenes);
    if (findings.isNotEmpty) {
      throw ChapterCrossSceneClicheGateFailure(findings);
    }
  }
}

typedef ChapterSceneRunnerFactory = ChapterGenerationService Function();

class ChapterConcurrentRunner {
  ChapterConcurrentRunner({
    required this.settingsStore,
    required this.pipelineConfig,
    this.roleplaySessionStore,
    this.characterMemoryStore,
    PipelineEventLog? evidenceLog,
    ChapterSceneRunnerFactory? sceneRunnerFactory,
  }) : _evidenceLog = evidenceLog,
       _sceneRunnerFactory =
           sceneRunnerFactory ??
           (() {
             if (!pipelineConfig.contentRedrawAllowed) {
               return PipelineStageRunnerImpl.sealedProduction(
                 settingsStore: settingsStore,
                 pipelineConfig: pipelineConfig,
                 eventLog: PipelineEvidenceLogScope.current,
                 roleplaySessionStore: roleplaySessionStore,
                 characterMemoryStore: characterMemoryStore,
               );
             }
             return PipelineStageRunnerImpl(
               settingsStore: settingsStore,
               pipelineConfig: pipelineConfig,
               eventLog: PipelineEvidenceLogScope.current,
               roleplaySessionStore: roleplaySessionStore,
               characterMemoryStore: characterMemoryStore,
             );
           });

  final StoryGenerationSettingsContract settingsStore;
  final GenerationPipelineConfig pipelineConfig;
  final RoleplaySessionStore? roleplaySessionStore;
  final CharacterMemoryStore? characterMemoryStore;
  final PipelineEventLog? _evidenceLog;
  final ChapterSceneRunnerFactory _sceneRunnerFactory;

  Future<List<SceneRuntimeOutput>> runAll(
    List<SceneBrief> briefs, {
    NarrativeArcState? initialArc,
    void Function(int completed, int total, SceneRuntimeOutput output)?
    onSceneComplete,
  }) async {
    if (!pipelineConfig.contentRedrawAllowed) {
      final evidenceLog = _evidenceLog ?? PipelineEvidenceLogScope.current;
      if (evidenceLog == null) {
        throw StateError(
          'no-redraw chapter generation requires a persistent evidence sink',
        );
      }
      if (evidenceLog is! PipelineEventLogImpl) {
        throw StateError(
          'no-redraw chapter generation requires a concrete durable JSONL '
          'evidence log',
        );
      }
      if (!identical(PipelineEvidenceLogScope.current, evidenceLog)) {
        return PipelineEvidenceLogScope.run(
          eventLog: evidenceLog,
          body: () => runAll(
            briefs,
            initialArc: initialArc,
            onSceneComplete: onSceneComplete,
          ),
        );
      }
      await evidenceLog.prepareEvidencePersistence();
    }

    var latestArc = initialArc ?? NarrativeArcState();
    final arcTracker = NarrativeArcTracker();
    var completedCount = 0;
    final committedSceneTexts = <String, String>{};
    const crossSceneClicheGate = ChapterCrossSceneClicheGate();

    bool requiresCrossSceneClicheGate(SceneBrief brief) =>
        pipelineConfig.hardGatesEnabled &&
        (brief.formalExecution ||
            brief.metadata['requireClicheHardGate'] == true);

    final scheduler = ScenePipelineScheduler<SceneBrief, SceneRuntimeOutput>(
      maxConcurrentScenes: pipelineConfig.maxConcurrentScenes,
      canCommitResult: (result) {
        if (result.review.decision != SceneReviewDecision.pass) return false;
        if (!requiresCrossSceneClicheGate(result.brief)) return true;
        final sceneKey = '${result.brief.chapterId}/${result.brief.sceneId}';
        return crossSceneClicheGate.evaluate(<String, String>{
          ...committedSceneTexts,
          sceneKey: result.prose.text,
        }).isEmpty;
      },
      onResultCommitted: (index, result) {
        completedCount++;
        committedSceneTexts['${result.brief.chapterId}/${result.brief.sceneId}'] =
            result.prose.text;
        latestArc = arcTracker.update(current: latestArc, output: result);
        onSceneComplete?.call(completedCount, briefs.length, result);
      },
    );

    final outputs = await scheduler.run(
      scenes: briefs,
      runScene: (brief, {required onSpeculationReady}) async {
        final arcSnapshot = latestArc;
        final briefWithArc = brief.copyWith(narrativeArc: arcSnapshot);
        final maximumAttempts = pipelineConfig.contentRedrawAllowed
            ? pipelineConfig.maxSceneRetries
            : 1;

        for (var attempt = 1; ; attempt++) {
          try {
            final orchestrator = _sceneRunnerFactory();

            final result = await orchestrator.runScene(
              briefWithArc,
              onSpeculationReady: onSpeculationReady,
            );

            if (result.review.decision == SceneReviewDecision.pass ||
                attempt >= maximumAttempts) {
              return result;
            }
          } catch (_) {
            if (attempt >= maximumAttempts) {
              rethrow;
            }
          }
        }
      },
    );
    if (briefs.any(requiresCrossSceneClicheGate)) {
      crossSceneClicheGate.enforce(<String, String>{
        for (final output in outputs)
          '${output.brief.chapterId}/${output.brief.sceneId}':
              output.prose.text,
      });
    }
    return outputs;
  }
}
