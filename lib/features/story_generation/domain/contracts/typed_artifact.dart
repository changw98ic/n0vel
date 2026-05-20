/// Types of artifacts produced and consumed by pipeline stages.
enum ArtifactType {
  contextAssembly,
  directorPlan,
  roleplaySession,
  stageNarration,
  beatResolution,
  proseDraft,
  reviewResult,
  polishedProse,
  sceneOutput,
  thoughtAtomBatch,
  retrievalPack,
}

/// Base class for all typed data flowing through the pipeline.
///
/// Every stage input and output is a [TypedArtifact], enabling
/// compile-time type checking and runtime serialization.
abstract class TypedArtifact {
  const TypedArtifact();

  /// The artifact type discriminator.
  ArtifactType get type;

  /// Serialize to a JSON-compatible map.
  Map<String, Object?> toJson();

  /// Estimated token count for LLM budget tracking.
  int get tokenEstimate;
}
