import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/app_scene_context_storage_io.dart';
import 'package:novel_writer/app/state/story_outline_storage_io.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_material_manifest_repository.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/legacy_generation_candidate_seed.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('material-cas-');
    path = '${dir.path}/authoring.db';
  });
  tearDown(() => dir.delete(recursive: true));

  test(
    'workspace or outline mutation through a second storage connection conflicts',
    () async {
      final workspace = SqliteAppWorkspaceStorage(dbPath: path);
      final outline = SqliteStoryOutlineStorage(dbPath: path);
      await workspace.save(_workspace(world: '规则一', profile: '角色一'));
      await outline.save(_outline('节拍一'), projectId: 'project-1');
      final db = sqlite3.open(path);
      addTearDown(db.dispose);
      db.execute('PRAGMA foreign_keys = ON');
      final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
      final digest = GenerationMaterialManifestRepository(
        db: db,
      ).buildCurrent(projectId: 'project-1', sceneId: 'scene-1').materialDigest;
      _seed(ledger, db, digest: digest);

      final coordinator = GenerationCommitCoordinator(db: db)..ensureTables();
      // A real second storage writer changes world/profile after freeze.
      await workspace.save(_workspace(world: '规则二', profile: '角色二'));
      expect(
        () => coordinator.accept(_request(digest)),
        throwsA(isA<GenerationMaterialConflict>()),
      );
      expect(
        db
            .select('SELECT state FROM story_generation_pending_writes')
            .single['state'],
        'staged',
      );

      await outline.save(_outline('节拍二'), projectId: 'project-1');
      expect(
        () => coordinator.accept(_request(digest)),
        throwsA(isA<GenerationMaterialConflict>()),
      );
    },
  );

  test(
    'unchanged manifest-backed material accepts and promotes the candidate',
    () async {
      final workspace = SqliteAppWorkspaceStorage(dbPath: path);
      final outline = SqliteStoryOutlineStorage(dbPath: path);
      await workspace.save(_workspace(world: '规则一', profile: '角色一'));
      await outline.save(_outline('节拍一'), projectId: 'project-1');
      final db = sqlite3.open(path);
      addTearDown(db.dispose);
      db.execute('PRAGMA foreign_keys = ON');
      final ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
      final digest = GenerationMaterialManifestRepository(
        db: db,
      ).buildCurrent(projectId: 'project-1', sceneId: 'scene-1').materialDigest;
      _seed(ledger, db, digest: digest);

      final result = (GenerationCommitCoordinator(
        db: db,
      )..ensureTables()).accept(_request(digest));
      expect(result, isA<GenerationCommitApplied>());
      expect(
        db.select('SELECT * FROM story_generation_commit_receipts'),
        hasLength(1),
      );
      expect(
        db.select('SELECT text_body FROM draft_documents').single['text_body'],
        'final',
      );
      expect(db.select('SELECT * FROM version_entries'), hasLength(1));
      expect(
        db
            .select('SELECT state FROM story_generation_pending_writes')
            .single['state'],
        'committed',
      );
    },
  );

  test(
    'scene context and review writers atomically advance material CAS',
    () async {
      final context = SqliteAppSceneContextStorage(dbPath: path);
      final reviews = SqliteReviewTaskStorage(dbPath: path);
      await context.save({
        'sceneSummary': '场景摘要一',
        'characterSummary': '角色摘要一',
        'worldSummary': '世界摘要一',
      }, projectId: 'project-1');
      await reviews.save({
        'tasks': [
          {'id': 'r1', 'title': '审校一', 'body': '发现一'},
        ],
      }, projectId: 'project-1');
      final db = sqlite3.open(path);
      addTearDown(db.dispose);
      final journal = GenerationMaterialManifestRepository(db: db);
      final before = journal.buildCurrent(
        projectId: 'project-1',
        sceneId: 'scene-1',
      );

      await context.save({
        'sceneSummary': '场景摘要二',
        'characterSummary': '角色摘要一',
        'worldSummary': '世界摘要一',
      }, projectId: 'project-1');
      await reviews.save({
        'tasks': [
          {'id': 'r1', 'title': '审校二', 'body': '发现二'},
        ],
      }, projectId: 'project-1');
      final after = journal.buildCurrent(
        projectId: 'project-1',
        sceneId: 'scene-1',
      );

      expect(after.materialDigest, isNot(before.materialDigest));
      expect(
        db
            .select('''
        SELECT source_kind FROM story_generation_material_sources
        WHERE project_id = 'project-1' ORDER BY source_kind
      ''')
            .map((row) => row['source_kind']),
        containsAll(<String>['sceneContext', 'review']),
      );
    },
  );
}

Map<String, Object?> _workspace({
  required String world,
  required String profile,
}) => {
  'projects': [
    {
      'id': 'project-1',
      'sceneId': 'scene-1',
      'title': 'P',
      'genre': '',
      'summary': '',
      'recentLocation': '',
      'lastOpenedAtMs': 1,
    },
  ],
  'charactersByProject': {
    'project-1': [
      {'id': 'c1', 'name': 'C', 'role': 'R', 'summary': profile},
    ],
  },
  'worldNodesByProject': {
    'project-1': [
      {'id': 'w1', 'title': 'W', 'detail': world},
    ],
  },
  'scenesByProject': {
    'project-1': [
      {
        'id': 'scene-1',
        'chapterLabel': 'chapter-1',
        'title': 'S',
        'summary': 'scene',
      },
    ],
  },
};

Map<String, Object?> _outline(String beat) => {
  'chapters': [
    {
      'id': 'chapter-1',
      'summary': 'chapter',
      'scenes': [
        {
          'id': 'scene-1',
          'summary': 'scene',
          'beats': [
            {'sequence': 1, 'content': beat},
          ],
        },
      ],
    },
  ],
};

void _seed(
  GenerationLedgerSqliteStore ledger,
  Database db, {
  required String digest,
}) {
  ledger.createRun(
    const GenerationRunRecord(
      runId: 'run-1',
      requestId: 'req-1',
      projectId: 'project-1',
      chapterId: 'chapter-1',
      sceneId: 'scene-1',
      sceneScopeId: 'project-1::scene-1',
      status: 'candidateReady',
      phase: 'finalization',
      schemaVersion: 11,
      createdAtMs: 1,
      updatedAtMs: 1,
    ),
  );
  db.execute(
    "INSERT INTO story_generation_material_manifests VALUES ('run-1','project-1','scene-1',?,'{}',1)",
    [digest],
  );
  ledger.createWorkingProseRevision(
    WorkingProseRevisionRecord(
      runId: 'run-1',
      proseRevision: 0,
      proseHash: GenerationCommitDigest.text('final'),
      proseText: 'final',
      sourceKind: 'polish',
      createdAtMs: 1,
    ),
  );
  ledger.reserveCandidateNamespace(
    const CandidateNamespaceRecord(
      runId: 'run-1',
      candidateRevision: 0,
      sourceProseRevision: 0,
      reservedAtMs: 1,
    ),
  );
  final writeEvidence = _pendingWriteEvidence();
  ledger.upsertPendingWrite(
    PendingWriteRecord(
      runId: 'run-1',
      candidateRevision: 0,
      writeId: 'w',
      projectId: 'project-1',
      chapterId: 'chapter-1',
      sceneId: 'scene-1',
      logicalEntityId: 'x',
      writeKind: 'thoughtAtom',
      payloadHash: writeEvidence.payloadHash,
      payloadJson: writeEvidence.payloadJson,
      derivationClass: 'proseDerived',
      createdAtMs: 1,
      expiresAtMs: 9999,
    ),
  );
  seedHistoricalV1Candidate(
    db: db,
    runId: 'run-1',
    candidateRevision: 0,
    projectId: 'project-1',
    chapterId: 'chapter-1',
    sceneId: 'scene-1',
    sourceProseRevision: 0,
    candidateHash: 'c',
    finalProseHash: GenerationCommitDigest.text('final'),
    deterministicGateEvidenceHash: 'g',
    finalCouncilEvidenceHash: 'r',
    qualityEvidenceHash: 'q',
    pendingWriteSetHash: writeEvidence.pendingWriteSetHash,
    materialDigest: digest,
    inputDigest: 'i',
    finalProse: 'final',
    pendingWriteManifestJson: writeEvidence.manifestJson,
    createdAtMs: 1,
    expiresAtMs: 9999,
  );
  db.execute(
    "UPDATE story_generation_runs SET current_candidate_revision = 0 WHERE run_id = 'run-1'",
  );
  db.execute(
    "INSERT INTO draft_documents VALUES ('project-1::scene-1','base',1)",
  );
}

GenerationCommitRequest _request(String digest) {
  final writeEvidence = _pendingWriteEvidence();
  return GenerationCommitRequest(
    acceptIdempotencyKey: 'key',
    runId: 'run-1',
    candidateRevision: 0,
    projectId: 'project-1',
    sceneScopeId: 'project-1::scene-1',
    candidateHash: 'c',
    expectedBaseDraftHash: GenerationCommitDigest.text('base'),
    expectedMaterialDigest: digest,
    expectedInputDigest: 'i',
    expectedFinalProseHash: GenerationCommitDigest.text('final'),
    expectedDeterministicGateEvidenceHash: 'g',
    expectedFinalCouncilEvidenceHash: 'r',
    expectedQualityEvidenceHash: 'q',
    expectedPendingWriteSetHash: writeEvidence.pendingWriteSetHash,
    committedAtMs: 2,
  );
}

({
  String payloadJson,
  String payloadHash,
  String manifestJson,
  String pendingWriteSetHash,
})
_pendingWriteEvidence() {
  final payloadJson = GenerationPendingWritePayloadIntegrity.canonicalJson(
    <String, Object?>{
      'kind': 'thoughtAtom',
      'schemaVersion': 1,
      'projectId': 'project-1',
      'chapterId': 'chapter-1',
      'sceneId': 'scene-1',
      'target': <String, Object?>{
        'projectId': 'project-1',
        'chapterId': 'chapter-1',
        'sceneId': 'scene-1',
      },
      'thought': <String, Object?>{
        'id': 'thought-1',
        'projectId': 'project-1',
        'scopeId': 'scene-1',
        'content': '可采纳观察',
      },
    },
  );
  final payloadHash = GenerationPendingWritePayloadIntegrity.hashCanonicalJson(
    payloadJson,
  );
  final manifest = <Map<String, Object?>>[
    <String, Object?>{'writeId': 'w', 'payloadHash': payloadHash},
  ];
  return (
    payloadJson: payloadJson,
    payloadHash: payloadHash,
    manifestJson: GenerationPendingWritePayloadIntegrity.canonicalJson(
      manifest,
    ),
    pendingWriteSetHash: GenerationPendingWritePayloadIntegrity.hashValue(
      manifest,
    ),
  );
}
