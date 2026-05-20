import 'event_log.dart';
import 'memory_writeback_gate.dart';
import 'pipeline_role_contract.dart';
import 'rag_retrieval_policy.dart';
import 'typed_artifact.dart';

/// Context available to all pipeline stages during execution.
///
/// Provides access to shared infrastructure: event logging, retrieval
/// policy, memory writeback gating, and stage-local metadata.
class PipelineContext {
  const PipelineContext({
    required this.eventLog,
    required this.retrievalPolicy,
    required this.writebackGate,
    required this.sceneBrief,
    this.metadata = const {},
  });

  /// Event log for emitting structured pipeline events.
  final PipelineEventLog eventLog;

  /// RAG retrieval policy for the current pipeline run.
  final RagRetrievalPolicy retrievalPolicy;

  /// Memory writeback gate for validating memory writes.
  final MemoryWritebackGate writebackGate;

  /// The scene brief being processed.
  final SceneBriefRef sceneBrief;

  /// Stage-local metadata.
  final Map<String, Object?> metadata;

  /// Create a copy with additional metadata.
  PipelineContext withMetadata(Map<String, Object?> extra) {
    return PipelineContext(
      eventLog: eventLog,
      retrievalPolicy: retrievalPolicy,
      writebackGate: writebackGate,
      sceneBrief: sceneBrief,
      metadata: {...metadata, ...extra},
    );
  }
}

/// Lightweight reference to the scene being processed.
///
/// Avoids importing the full SceneBrief model from the data layer.
class SceneBriefRef {
  const SceneBriefRef({
    required this.projectId,
    required this.sceneId,
    this.sceneIndex = 0,
    this.totalScenesInChapter = 0,
  });

  final String projectId;
  final String sceneId;
  final int sceneIndex;
  final int totalScenesInChapter;
}

/// Interface for structured event logging during pipeline execution.
abstract class PipelineEventLog {
  const PipelineEventLog();

  /// Emit a pipeline event.
  void emit(PipelineEvent event);

  /// Query events by criteria.
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  });

  /// Flush buffered events to persistent storage.
  Future<void> flush();
}

/// Declarative pipeline stage runner — the only entry point for scene
/// generation after the hard cutover.
///
/// Replaces the legacy orchestrator with an event-log-driven
/// stage execution model. Stages are executed sequentially; each stage
/// receives typed artifacts from the previous stage.
abstract class PipelineStageRunner {
  const PipelineStageRunner();

  /// The ordered stages in this pipeline.
  List<PipelineStage<TypedArtifact, TypedArtifact>> get stages;

  /// Event log for the runner itself.
  PipelineEventLog get eventLog;

  /// Default retrieval policy (can be overridden per-run).
  RagRetrievalPolicy get defaultRetrievalPolicy;

  /// Memory writeback gate.
  MemoryWritebackGate get writebackGate;

  /// Maximum global retries across all stages before aborting.
  int get maxGlobalRetries => 3;

  /// Run the full pipeline for a scene.
  ///
  /// Iterates through [stages], passing typed artifacts between stages,
  /// emitting events, and handling failures via [FailureCode].
  Future<PipelineRunResult> run(SceneBriefRef brief, PipelineContext context);
}

/// Result of a complete pipeline run.
class PipelineRunResult {
  const PipelineRunResult({
    required this.success,
    required this.events,
    this.finalArtifact,
    this.failureCode,
    this.failedStageId,
  });

  /// Whether the pipeline completed all stages successfully.
  final bool success;

  /// All events emitted during the run.
  final List<PipelineEvent> events;

  /// The final output artifact (null on failure).
  final TypedArtifact? finalArtifact;

  /// The failure code if the pipeline failed.
  final FailureCode? failureCode;

  /// The stage that failed (if any).
  final String? failedStageId;
}
