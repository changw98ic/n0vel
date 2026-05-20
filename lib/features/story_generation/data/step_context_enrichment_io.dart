import 'package:novel_writer/app/rag/hybrid_retriever.dart' show RagSceneContext;

import 'scene_runtime_models.dart' show SceneBrief;
import '../domain/memory_models.dart' show StoryRetrievalPack;
import '../domain/scene_models.dart'
    show ProjectMaterialSnapshot, SceneContextAssembly;
import '../domain/contracts/typed_artifact.dart';

// ---------------------------------------------------------------------------
// Step 1: Context Enrichment
// ---------------------------------------------------------------------------

class ContextEnrichmentInput extends TypedArtifact {
  const ContextEnrichmentInput({required this.brief, this.materials});

  final SceneBrief brief;
  final ProjectMaterialSnapshot? materials;

  @override
  ArtifactType get type => ArtifactType.contextAssembly;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}

class ContextEnrichmentOutput extends TypedArtifact {
  const ContextEnrichmentOutput({
    required this.effectiveMaterials,
    this.retrievalPack,
    this.ragContext,
    this.cachedAssembly,
  });

  final ProjectMaterialSnapshot effectiveMaterials;
  final StoryRetrievalPack? retrievalPack;
  final RagSceneContext? ragContext;
  final SceneContextAssembly? cachedAssembly;

  @override
  ArtifactType get type => ArtifactType.contextAssembly;

  @override
  Map<String, Object?> toJson() => {'type': type.name};

  @override
  int get tokenEstimate => 0;
}
