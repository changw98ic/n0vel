import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'V12 file-backed chapter heads are complete, revisioned, isolated, and atomic',
    () {
      final file = File(
        '${Directory.systemTemp.path}/generation-v12-${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final db = sqlite3.open(file.path);
      addTearDown(() {
        db.dispose();
        if (file.existsSync()) file.deleteSync();
      });
      db.execute('PRAGMA foreign_keys = ON');
      final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
      final coordinator = GenerationCommitCoordinator(db: db)..ensureTables();

      final later = _seedCandidate(
        ledger: ledger,
        db: db,
        runId: 'run-scene-2',
        projectId: 'project-a',
        chapterId: 'chapter-shared',
        sceneId: 'scene-2',
        prose: '后场景正文',
        candidateHash: 'candidate-scene-2',
      );
      final earlier = _seedCandidate(
        ledger: ledger,
        db: db,
        runId: 'run-scene-1',
        projectId: 'project-a',
        chapterId: 'chapter-shared',
        sceneId: 'scene-1',
        prose: '前场景正文',
        candidateHash: 'candidate-scene-1',
      );

      coordinator.accept(later.request());
      expect(_heads(db, 'project-a'), isEmpty);
      expect(
        db.select('SELECT * FROM story_generation_summary_contributions'),
        hasLength(1),
      );

      coordinator.accept(earlier.request());
      final firstHead = _heads(db, 'project-a').single;
      final firstRevisionId = firstHead['revision_id'] as String;
      final firstHash = _revisionHash(db, firstRevisionId);
      expect(
        db.select('SELECT * FROM story_generation_summary_contributions'),
        hasLength(2),
      );
      expect(_outboxReceiptIdsAreBound(db), isTrue);

      // A replacement is a new run, rather than an edit of an immutable receipt.
      final replacement = _seedCandidate(
        ledger: ledger,
        db: db,
        runId: 'run-scene-1-replacement',
        projectId: 'project-a',
        chapterId: 'chapter-shared',
        sceneId: 'scene-1',
        prose: '前场景修订正文',
        candidateHash: 'candidate-scene-1-replacement',
        baseProse: '前场景正文',
      );
      coordinator.accept(replacement.request());
      final replacementHead = _heads(db, 'project-a').single;
      expect(replacementHead['revision_id'], isNot(firstRevisionId));
      expect(
        _revisionHash(db, replacementHead['revision_id'] as String),
        isNot(firstHash),
      );
      expect(
        db.select('''
          SELECT * FROM story_generation_summary_revisions
          WHERE project_id = 'project-a' AND chapter_id = 'chapter-shared'
        '''),
        hasLength(2),
      );

      final otherProject = _seedCandidate(
        ledger: ledger,
        db: db,
        runId: 'run-project-b',
        projectId: 'project-b',
        chapterId: 'chapter-shared',
        sceneId: 'scene-1',
        prose: '项目B正文',
        candidateHash: 'candidate-project-b',
      );
      coordinator.accept(otherProject.request());
      expect(
        _heads(db, 'project-a').single['revision_id'],
        replacementHead['revision_id'],
      );
      expect(_heads(db, 'project-b'), hasLength(1));
      expect(
        db.select('''
          SELECT * FROM story_generation_summary_contributions
          WHERE project_id = 'project-b' AND chapter_id = 'chapter-shared'
        '''),
        hasLength(1),
      );

      final headsBeforeReject = db
          .select('SELECT * FROM story_generation_summary_heads')
          .length;
      final outboxBeforeReject = db
          .select('SELECT * FROM story_generation_outbox')
          .length;
      final rejected = _seedCandidate(
        ledger: ledger,
        db: db,
        runId: 'run-rejected',
        projectId: 'project-c',
        chapterId: 'chapter-rejected',
        sceneId: 'scene-1',
        prose: '不应入库',
        candidateHash: 'candidate-rejected',
      );
      ledger.rejectCandidate(
        runId: rejected.runId,
        candidateRevision: 0,
        rejectedAtMs: 999,
      );
      expect(_heads(db, 'project-c'), isEmpty);
      expect(
        db.select('SELECT * FROM story_generation_summary_heads').length,
        headsBeforeReject,
      );
      expect(
        db.select('SELECT * FROM story_generation_outbox').length,
        outboxBeforeReject,
      );

      final faulted = _seedCandidate(
        ledger: ledger,
        db: db,
        runId: 'run-faulted',
        projectId: 'project-d',
        chapterId: 'chapter-faulted',
        sceneId: 'scene-1',
        prose: '事务必须回滚',
        candidateHash: 'candidate-faulted',
      );
      final faulting = GenerationCommitCoordinator(
        db: db,
        faultInjector: (step) {
          if (step == GenerationCommitStep.beforeCommit) {
            throw StateError('inject rollback');
          }
        },
      );
      expect(() => faulting.accept(faulted.request()), throwsStateError);
      expect(_heads(db, 'project-d'), isEmpty);
      expect(
        db.select('SELECT * FROM story_generation_summary_heads').length,
        headsBeforeReject,
      );
      expect(
        db.select('SELECT * FROM story_generation_outbox').length,
        outboxBeforeReject,
      );
    },
  );
}

List<Row> _heads(Database db, String projectId) => db.select(
  '''
      SELECT * FROM story_generation_summary_heads
      WHERE project_id = ? AND chapter_id = 'chapter-shared'
      ''',
  [projectId],
);

String _revisionHash(Database db, String revisionId) =>
    db
            .select(
              '''
      SELECT scene_commit_set_hash FROM story_generation_summary_revisions
      WHERE revision_id = ?
      ''',
              [revisionId],
            )
            .single['scene_commit_set_hash']
        as String;

bool _outboxReceiptIdsAreBound(Database db) => db.select('''
  SELECT o.source_receipt_id
  FROM story_generation_outbox o
  LEFT JOIN story_generation_commit_receipts r
    ON r.receipt_id = o.source_receipt_id
  WHERE r.receipt_id IS NULL
''').isEmpty;

_SeededCandidate _seedCandidate({
  required GenerationLedgerSqliteStore ledger,
  required Database db,
  required String runId,
  required String projectId,
  required String chapterId,
  required String sceneId,
  required String prose,
  required String candidateHash,
  String baseProse = '旧草稿',
}) {
  final sceneScopeId = '$projectId::$sceneId';
  final writeId = 'write-$runId';
  final deltaId = 'delta-$runId';
  ledger.createRun(
    GenerationRunRecord(
      runId: runId,
      requestId: 'request-$runId',
      projectId: projectId,
      chapterId: chapterId,
      sceneId: sceneId,
      sceneScopeId: sceneScopeId,
      status: 'running',
      phase: 'finalization',
      schemaVersion: 12,
      createdAtMs: 100,
      updatedAtMs: 100,
    ),
  );
  ledger.createWorkingProseRevision(
    WorkingProseRevisionRecord(
      runId: runId,
      proseRevision: 0,
      proseHash: GenerationCommitDigest.text(prose),
      proseText: prose,
      sourceKind: 'polish',
      createdAtMs: 100,
    ),
  );
  ledger.reserveCandidateNamespace(
    CandidateNamespaceRecord(
      runId: runId,
      candidateRevision: 0,
      sourceProseRevision: 0,
      reservedAtMs: 100,
    ),
  );
  final payload = GenerationPendingWritePayloadIntegrity.canonicalJson(
    <String, Object?>{
      'kind': 'characterDelta',
      'schemaVersion': 1,
      'projectId': projectId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'target': <String, Object?>{
        'projectId': projectId,
        'chapterId': chapterId,
        'sceneId': sceneId,
        'characterId': 'character-1',
      },
      'delta': <String, Object?>{
        'deltaId': deltaId,
        'characterId': 'character-1',
        'kind': 'intention',
        'content': '承诺',
        'acl': <String, Object?>{
          'visibility': 'authorOnly',
          'ownerCharacterId': '',
        },
        'sourceRound': 1,
        'sourceTurnId': 'turn-1',
        'confidence': 1,
        'accepted': true,
      },
    },
  );
  final payloadHash = GenerationPendingWritePayloadIntegrity.hashCanonicalJson(
    payload,
  );
  final writes = <Map<String, Object?>>[
    <String, Object?>{
      'writeId': writeId,
      'payloadHash': payloadHash,
      'runId': runId,
      'candidateRevision': 0,
    },
  ];
  final pendingWriteSetHash = GenerationPendingWritePayloadIntegrity.hashValue(
    writes,
  );
  ledger.upsertPendingWrite(
    PendingWriteRecord(
      runId: runId,
      candidateRevision: 0,
      writeId: writeId,
      projectId: projectId,
      chapterId: chapterId,
      sceneId: sceneId,
      logicalEntityId: deltaId,
      writeKind: 'characterDelta',
      payloadHash: payloadHash,
      payloadJson: payload,
      derivationClass: 'preProse',
      createdAtMs: 100,
      expiresAtMs: 1000,
    ),
  );
  ledger.finalizeCandidate(
    proof: CandidateProofRecord(
      runId: runId,
      candidateRevision: 0,
      projectId: projectId,
      chapterId: chapterId,
      sceneId: sceneId,
      sourceProseRevision: 0,
      candidateHash: candidateHash,
      finalProseHash: GenerationCommitDigest.text(prose),
      deterministicGateEvidenceHash: 'gate-$runId',
      finalCouncilEvidenceHash: 'council-$runId',
      qualityEvidenceHash: 'quality-$runId',
      pendingWriteSetHash: pendingWriteSetHash,
      materialDigest: 'material-$runId',
      inputDigest: 'input-$runId',
      createdAtMs: 100,
    ),
    payload: CandidatePayloadRecord(
      runId: runId,
      candidateRevision: 0,
      finalProse: prose,
      pendingWriteManifestJson:
          GenerationPendingWritePayloadIntegrity.canonicalJson(writes),
      createdAtMs: 100,
      expiresAtMs: 1000,
    ),
  );
  db.execute(
    '''
    UPDATE story_generation_runs
    SET status = 'candidateReady', current_candidate_revision = 0
    WHERE run_id = ?
  ''',
    [runId],
  );
  db.execute(
    '''
    INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
    VALUES (?, ?, 100)
    ON CONFLICT(project_id) DO NOTHING
  ''',
    [sceneScopeId, baseProse],
  );
  return _SeededCandidate(
    runId: runId,
    projectId: projectId,
    sceneScopeId: sceneScopeId,
    prose: prose,
    candidateHash: candidateHash,
    baseProse: baseProse,
    pendingWriteSetHash: pendingWriteSetHash,
  );
}

class _SeededCandidate {
  const _SeededCandidate({
    required this.runId,
    required this.projectId,
    required this.sceneScopeId,
    required this.prose,
    required this.candidateHash,
    required this.baseProse,
    required this.pendingWriteSetHash,
  });

  final String runId;
  final String projectId;
  final String sceneScopeId;
  final String prose;
  final String candidateHash;
  final String baseProse;
  final String pendingWriteSetHash;

  GenerationCommitRequest request() => GenerationCommitRequest(
    acceptIdempotencyKey: 'accept-$runId',
    runId: runId,
    candidateRevision: 0,
    projectId: projectId,
    sceneScopeId: sceneScopeId,
    candidateHash: candidateHash,
    expectedBaseDraftHash: GenerationCommitDigest.text(baseProse),
    expectedMaterialDigest: 'material-$runId',
    expectedInputDigest: 'input-$runId',
    expectedFinalProseHash: GenerationCommitDigest.text(prose),
    expectedDeterministicGateEvidenceHash: 'gate-$runId',
    expectedFinalCouncilEvidenceHash: 'council-$runId',
    expectedQualityEvidenceHash: 'quality-$runId',
    expectedPendingWriteSetHash: pendingWriteSetHash,
    committedAtMs: 500,
  );
}
