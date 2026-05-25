import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_dependencies.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';

void main() {
  test('runner accepts dependencies grouped by pipeline role', () {
    final settingsStore = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
    );
    addTearDown(settingsStore.dispose);

    final eventLog = PipelineEventLogImpl();
    final runner = PipelineStageRunnerImpl(
      settingsStore: settingsStore,
      pipelineConfig: const GenerationPipelineConfig(maxProseRetries: 1),
      dependencies: PipelineStageRunnerDependencies(
        runtime: PipelineRuntimeDependencies(eventLog: eventLog),
      ),
    );

    expect(runner.eventLog, same(eventLog));
    expect(runner.stages.map((stage) => stage.roleId), [
      'context_enrichment',
      'director',
      'roleplay',
      'stage_narration',
      'beat_resolution',
      'editorial',
      'review',
      'polish',
      'finalization',
    ]);
  });

  test('default dependency bundle exposes explicit role groups', () {
    const dependencies = PipelineStageRunnerDependencies();

    expect(dependencies.runtime, isA<PipelineRuntimeDependencies>());
    expect(dependencies.context, isA<PipelineContextDependencies>());
    expect(dependencies.planning, isA<PipelinePlanningDependencies>());
    expect(dependencies.roleplay, isA<PipelineRoleplayDependencies>());
    expect(dependencies.drafting, isA<PipelineDraftingDependencies>());
    expect(dependencies.review, isA<PipelineReviewDependencies>());
    expect(dependencies.finalization, isA<PipelineFinalizationDependencies>());
  });
}
