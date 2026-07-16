import 'pipeline_stage_runner_impl.dart';

/// Creates a fresh stateful story pipeline runner for each generation run.
class StoryPipelineFactory {
  const StoryPipelineFactory(this._createRunner);

  final PipelineStageRunnerImpl Function() _createRunner;

  PipelineStageRunnerImpl create() => _createRunner();
}
