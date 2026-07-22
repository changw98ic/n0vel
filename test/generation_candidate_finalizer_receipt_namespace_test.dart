import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_candidate_identity.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/generation_evidence_receipt_fixture.dart';

void main() {
  group('candidate finalizer sealed receipt namespace binding', () {
    for (final replay in <({String name, String runId, String sceneId})>[
      (name: 'another run', runId: 'run-source', sceneId: _sceneId),
      (name: 'another scene', runId: _runId, sceneId: 'scene-source'),
    ]) {
      test(
        'rejects an otherwise valid receipt from ${replay.name} before staging',
        () async {
          final db = sqlite3.openInMemory();
          addTearDown(db.dispose);
          db.execute('PRAGMA foreign_keys = ON');
          final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
          final setup = _startSealedRun(ledger);
          final replayedReceipt = await buildGenerationEvidenceReceiptFixture(
            evidenceRunId: replay.runId,
            sceneId: replay.sceneId,
            generationArmPolicy: _armPolicy,
            preparedBriefDigest: setup.capture.preparedBriefDigest,
            generationBundleHash: setup.capture.generationBundleHash,
            artifactText: _finalProse,
          );

          expect(
            () => setup.finalizer.finalize(
              runId: _runId,
              output: _minimalOutput(setup.brief),
              capture: setup.capture,
              nowMs: 200,
              generationEvidenceReceipt: replayedReceipt,
            ),
            throwsStateError,
          );
          expect(
            db.select('SELECT * FROM story_generation_candidate_namespaces'),
            isEmpty,
          );
          expect(
            db.select('SELECT * FROM story_generation_candidate_proofs'),
            isEmpty,
          );
          expect(
            db.select('SELECT * FROM story_generation_candidate_payloads'),
            isEmpty,
          );
          expect(
            db.select('SELECT * FROM story_generation_pending_writes'),
            isEmpty,
          );
        },
      );
    }
  });
}

const _runId = 'receipt-finalizer-run-target';
const _projectId = 'project-1';
const _chapterId = 'chapter-1';
const _sceneId = 'receipt-finalizer-scene-target';
const _sceneScopeId = 'project-1::receipt-finalizer-scene-target';
const _armPolicy = 'arm-current-v1';
const _finalProse = '雨水越过锈蚀窗框，落在摊开的账页上。';

({
  GenerationLedgerCandidateFinalizer finalizer,
  GenerationRunCapture capture,
  SceneBrief brief,
})
_startSealedRun(GenerationLedgerSqliteStore ledger) {
  final finalizer = GenerationLedgerCandidateFinalizer(ledger: ledger);
  final brief = SceneBrief(
    projectId: _projectId,
    chapterId: _chapterId,
    chapterTitle: '第一章',
    sceneId: _sceneId,
    sceneTitle: '账页',
    sceneSummary: '核对被雨水打湿的账页。',
  );
  final capture = finalizer.startRun(
    runId: _runId,
    requestId: 'request-target',
    projectId: _projectId,
    chapterId: _chapterId,
    sceneId: _sceneId,
    sceneScopeId: _sceneScopeId,
    baseDraft: _finalProse,
    brief: brief,
    materials: const ProjectMaterialSnapshot(),
    nowMs: 100,
    generationEvidenceMode: GenerationCandidateIdentity.sealedNoRedrawMode,
    generationArmPolicy: _armPolicy,
  );
  return (finalizer: finalizer, capture: capture, brief: brief);
}

SceneRuntimeOutput _minimalOutput(SceneBrief brief) => SceneRuntimeOutput(
  brief: brief,
  resolvedCast: const [],
  director: const SceneDirectorOutput(text: '核对账页。'),
  roleOutputs: const [],
  prose: const SceneProseDraft(text: _finalProse, attempt: 1),
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
    summary: '通过。',
  ),
);
