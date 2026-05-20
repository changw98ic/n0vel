import 'typed_artifact.dart';

/// Identifies a pipeline role and the artifact type it produces.
abstract class PipelineRoleContract {
  const PipelineRoleContract();

  /// Unique identifier for this role (e.g. 'context_enrichment', 'director').
  String get roleId;

  /// The type of artifact this role produces.
  ArtifactType get outputType;
}

/// A single stage in the generation pipeline.
///
/// Each stage accepts a typed input artifact and produces a typed output
/// artifact, with access to the shared [PipelineContext] (defined in
/// stage_runner.dart, P0-09).
abstract class PipelineStage<I extends TypedArtifact, O extends TypedArtifact>
    extends PipelineRoleContract {
  const PipelineStage();

  /// Execute this stage with the given [input] and pipeline [context].
  ///
  /// [context] is a [PipelineContext] from stage_runner.dart — passed
  /// as Object here to avoid circular imports; typed in P0-09.
  Future<O> execute(I input, Object context);

  /// Maximum retry attempts for this stage before escalating.
  int get maxRetries => 2;
}
