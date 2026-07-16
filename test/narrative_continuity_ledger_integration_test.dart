import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('accepted candidate stages and reloads its resulting prop ledger', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
    final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
    final brief = SceneBrief(
      projectId: 'project-1',
      chapterId: 'chapter-03',
      chapterTitle: '第三章',
      sceneId: 'scene-04',
      sceneTitle: '交接',
      sceneSummary: '沈渡把证据交给柳溪。',
      cast: [
        SceneCastCandidate(characterId: 'shendu', name: '沈渡', role: '线人'),
        SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '记者'),
      ],
      metadata: const <String, Object?>{
        'continuityLedger': <Object?>[
          <String, Object?>{
            'entityId': 'evidence-drive',
            'aliases': <String>['U盘', '存储卡'],
            'holder': 'shendu',
            'status': 'held',
            'sourceSceneId': 'chapter-03/scene-03',
          },
        ],
      },
    );
    final capture = finalizer.startRun(
      runId: 'run-continuity',
      requestId: 'request-continuity',
      projectId: 'project-1',
      chapterId: brief.chapterId,
      sceneId: brief.sceneId,
      sceneScopeId: 'project-1::chapter-03::scene-04',
      baseDraft: '',
      brief: brief,
      materials: const ProjectMaterialSnapshot(),
      nowMs: 100,
    );

    finalizer.finalize(
      runId: 'run-continuity',
      capture: capture,
      nowMs: 200,
      output: SceneRuntimeOutput(
        brief: brief,
        resolvedCast: const [],
        director: const SceneDirectorOutput(text: '交接证据。'),
        roleOutputs: const [],
        prose: const SceneProseDraft(
          text: '沈渡把U盘交给柳溪。柳溪从衣袋里取出存储卡，确认文件完整。',
          attempt: 1,
        ),
        review: const SceneReviewResult(
          judge: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '通过',
            rawText: '',
          ),
          consistency: SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '一致',
            rawText: '',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 1,
        softFailureCount: 0,
        qualityScore: const SceneQualityScore(
          overall: 96,
          prose: 96,
          coherence: 96,
          character: 96,
          completeness: 96,
          summary: '质量通过。',
        ),
      ),
    );

    final pending = db
        .select(
          'SELECT payload_json FROM story_generation_pending_writes '
          "WHERE write_kind = 'sceneSummaryContribution'",
        )
        .single;
    final payload = jsonDecode(pending['payload_json'] as String) as Map;
    final contribution = payload['contribution'] as Map;
    final stagedLedger = contribution['continuityLedger'] as List;
    expect((stagedLedger.single as Map)['holder'], 'liuxi');
    expect(
      (stagedLedger.single as Map)['sourceSceneId'],
      'chapter-03/scene-04',
    );

    db.execute(
      'UPDATE story_generation_pending_writes '
      "SET state = 'committed', committed_at_ms = 300",
    );
    final reloaded = ledger.loadCommittedContinuityLedger(
      projectId: 'project-1',
      sourceSceneIds: const <String>['scene-04'],
    );
    expect(reloaded, hasLength(1));
    expect(reloaded.single['entityId'], 'evidence-drive');
    expect(reloaded.single['holder'], 'liuxi');
  });
}
