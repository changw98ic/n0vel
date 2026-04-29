export '../domain/scene_models.dart'
    show ProjectMaterialSnapshot, SceneContextAssembly;

import '../domain/scene_models.dart';
import 'story_memory_indexer.dart';
import '../domain/story_pipeline_interfaces.dart';

/// Assembles scene context from project materials before generation.
///
/// Gathers world nodes, character records, outline data, scene context,
/// and previously accepted scene states into a compact assembly.
/// Runs memory indexing and attaches scene-level retrieval requirements.
class SceneContextAssembler implements SceneContextAssemblerService {
  SceneContextAssembler({StoryMemoryIndexer? indexer})
      : _indexer = indexer ?? StoryMemoryIndexer();

  final StoryMemoryIndexer _indexer;

  /// Assembles context for the given [brief] from [materials].
  ///
  /// Indexes project material into memory chunks and computes retrieval
  /// requirements based on the scene brief.
  @override
  SceneContextAssembly assemble({
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
  }) {
    final requirements = <String>[];

    if (brief.cast.isNotEmpty) {
      requirements.add('character_profiles');
    }
    if (brief.worldNodeIds.isNotEmpty) {
      requirements.add('world_rules');
    }
    if (materials.acceptedStates.isNotEmpty) {
      requirements.add('state_ledger');
    }
    if (materials.outlineBeats.isNotEmpty) {
      requirements.add('outline_beats');
    }

    final scopeId = '${brief.chapterId}:${brief.sceneId}';
    final chunks = _indexer.index(
      projectId: brief.chapterId,
      scopeId: scopeId,
      materials: materials,
    );

    return SceneContextAssembly(
      brief: brief,
      materialSnapshot: materials,
      retrievalRequirements: requirements,
      memoryChunks: chunks,
    );
  }
}
