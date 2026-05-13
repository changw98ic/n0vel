import 'package:novel_writer/app/rag/rag_orchestrator.dart' show RagSceneContext;

import 'scene_runtime_models.dart' show SceneBrief;
import '../domain/memory_models.dart' show StoryRetrievalPack;
import '../domain/scene_models.dart'
    show ProjectMaterialSnapshot, SceneContextAssembly;

// ---------------------------------------------------------------------------
// Step 1: Context Enrichment
// ---------------------------------------------------------------------------

class ContextEnrichmentInput {
  const ContextEnrichmentInput({required this.brief, this.materials});

  final SceneBrief brief;
  final ProjectMaterialSnapshot? materials;
}

class ContextEnrichmentOutput {
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
}
