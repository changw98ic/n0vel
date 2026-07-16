import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_material_manifest_repository.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'canonical manifest changes when a journaled world, outline, review, or context source changes',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      final repository = GenerationMaterialManifestRepository(db: db);
      final frozen = repository.freezeSnapshot(
        runId: 'run-1',
        projectId: 'project-1',
        sceneId: 'scene-1',
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['world-v1'],
          outlineBeats: ['outline-v1'],
          sceneSummaries: ['context-v1'],
          reviewFindings: ['review-v1'],
        ),
        nowMs: 1,
      );
      repository.upsertSource(
        projectId: 'project-1',
        sceneId: 'scene-1',
        sourceKind: 'world',
        sourceId: 'world-source',
        revisionToken: '2',
        contentHash: 'world-v2',
        updatedAtMs: 2,
      );
      final changed = repository.buildCurrent(
        projectId: 'project-1',
        sceneId: 'scene-1',
      );
      expect(changed.materialDigest, isNot(frozen.materialDigest));
    },
  );
}
