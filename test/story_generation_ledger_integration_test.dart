import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_run_storage.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_candidate_finalizer.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_digest.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/production_pre_quality_gate.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/data/roleplay_session_store_io.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_store_io.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_delta_models.dart';
import 'package:novel_writer/features/story_generation/data/character_visible_context_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Database db;
  late GenerationLedgerSqliteStore ledger;
  late GenerationCommitCoordinator coordinator;
  late AppSettingsStore settings;
  late AppWorkspaceStore workspace;
  late StoryGenerationStore generation;
  late AppDraftStore draft;
  late InMemoryStoryGenerationRunStorage runStorage;

  setUp(() async {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
    coordinator = GenerationCommitCoordinator(db: db)..ensureTables();
    settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
    workspace = AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage());
    generation = StoryGenerationStore(
      storage: InMemoryStoryGenerationStorage(),
      workspaceStore: workspace,
    );
    await generation.waitUntilReady();
    draft = AppDraftStore(
      storage: InMemoryAppDraftStorage(),
      workspaceStore: workspace,
    );
    draft.updateText('作者原稿');
    runStorage = InMemoryStoryGenerationRunStorage();
    db.execute(
      'INSERT INTO draft_documents (project_id, text_body, updated_at_ms) VALUES (?, ?, ?)',
      [workspace.currentSceneScopeId, '作者原稿', 1],
    );
  });

  tearDown(() {
    draft.dispose();
    generation.dispose();
    workspace.dispose();
    settings.dispose();
    db.dispose();
  });

  StoryGenerationRunStore buildStore({
    bool failProof = false,
    String Function()? proseFactory,
  }) {
    if (failProof) {
      db.execute('''
        CREATE TRIGGER fail_candidate_proof
        BEFORE INSERT ON story_generation_candidate_proofs
        BEGIN SELECT RAISE(ABORT, 'injected proof failure'); END
      ''');
    }
    return StoryGenerationRunStore(
      settingsStore: settings,
      workspaceStore: workspace,
      generationStore: generation,
      draftStore: draft,
      storage: runStorage,
      generationLedger: ledger,
      generationCandidateFinalizer: GenerationLedgerCandidateFinalizer(
        ledger: ledger,
      ),
      generationCommitCoordinator: coordinator,
      orchestratorFactory: (_) => _PassingRunner(
        settingsStore: settings,
        prose: proseFactory?.call() ?? _passingProse,
      ),
    );
  }

  test(
    'pipeline success creates proof, payload, and same-namespace manifest',
    () async {
      final store = buildStore();
      addTearDown(store.dispose);
      await store.ready;

      await store.runCurrentScene();

      expect(
        store.snapshot.status,
        StoryGenerationRunStatus.completed,
        reason: store.snapshot.errorDetail,
      );
      expect(store.snapshot.hasDurableCandidateProof, isTrue);
      expect(store.snapshot.candidateProse, _passingProse);
      expect(
        store.snapshot.candidateGenerationBundleHash,
        startsWith('sha256:'),
      );
      final runBundle = db.select(
        '''SELECT bundle_hash FROM story_generation_run_bundles
           WHERE run_id = ?''',
        <Object?>[store.snapshot.runId],
      );
      expect(runBundle, hasLength(1));
      expect(
        store.snapshot.candidateGenerationBundleHash,
        'sha256:${runBundle.single['bundle_hash']}',
      );
      expect(
        store.snapshot.candidateHash,
        GenerationLedgerDigest.object({
          'runId': store.snapshot.runId,
          'candidateRevision': store.snapshot.candidateRevision,
          'finalProseHash': store.snapshot.candidateFinalProseHash,
          'deterministicGateEvidenceHash':
              store.snapshot.candidateDeterministicGateEvidenceHash,
          'finalCouncilEvidenceHash':
              store.snapshot.candidateFinalCouncilEvidenceHash,
          'qualityEvidenceHash': store.snapshot.candidateQualityEvidenceHash,
          'pendingWriteSetHash': store.snapshot.candidatePendingWriteSetHash,
          'materialDigest': store.snapshot.candidateMaterialDigest,
          'inputDigest': store.snapshot.candidateInputDigest,
          'generationBundleHash': store.snapshot.candidateGenerationBundleHash,
        }),
      );
      expect(
        db.select('SELECT * FROM story_generation_candidate_proofs'),
        hasLength(1),
      );
      expect(
        db.select('SELECT * FROM story_generation_candidate_payloads'),
        hasLength(1),
      );
      final pending = db.select(
        'SELECT * FROM story_generation_pending_writes',
      );
      expect(pending, hasLength(3));
      expect(
        db
            .select(
              'SELECT status, current_candidate_revision FROM story_generation_runs',
            )
            .single['status'],
        'candidateReady',
      );
      expect(
        db.select('''
          SELECT 1 FROM story_generation_stage_checkpoints
          WHERE ordinal = 12 AND stage_id = 'finalization' AND status = 'completed'
        '''),
        hasLength(1),
      );
      final manifest =
          db
                  .select(
                    'SELECT pending_write_manifest_json FROM story_generation_candidate_payloads',
                  )
                  .single['pending_write_manifest_json']
              as String;
      for (final write in pending) {
        expect(manifest, contains(write['write_id']));
        expect(manifest, contains(write['payload_hash']));
      }
    },
  );

  test(
    'proof/payload failure cannot be rendered as a successful candidate',
    () async {
      final store = buildStore(failProof: true);
      addTearDown(store.dispose);
      await store.ready;

      await store.runCurrentScene();

      expect(store.snapshot.status, StoryGenerationRunStatus.failed);
      expect(store.snapshot.hasDurableCandidateProof, isFalse);
      expect(store.snapshot.candidateProse, isEmpty);
      expect(
        db.select('SELECT * FROM story_generation_candidate_proofs'),
        isEmpty,
      );
      expect(
        db.select('SELECT * FROM story_generation_candidate_payloads'),
        isEmpty,
      );
      expect(
        db.select('''
          SELECT * FROM story_generation_stage_checkpoints
          WHERE ordinal = 12 AND stage_id = 'finalization'
        '''),
        isEmpty,
        reason:
            'ordinal 12 must not become visible before the proof/payload/run pointer transaction succeeds',
      );
      final run = db.select('''
        SELECT status, phase, last_error_code
        FROM story_generation_runs
      ''').single;
      expect(run['status'], 'failed');
      expect(run['phase'], 'fail');
      expect(run['last_error_code'], 'pipeline_failed');
    },
  );

  test('restart refuses a snapshot whose proof payload was removed', () async {
    final first = buildStore();
    addTearDown(first.dispose);
    await first.ready;
    await first.runCurrentScene();
    db.execute('DELETE FROM story_generation_candidate_payloads');

    final restored = buildStore();
    addTearDown(restored.dispose);
    await restored.ready;

    expect(restored.snapshot.status, StoryGenerationRunStatus.failed);
    expect(restored.snapshot.hasDurableCandidateProof, isFalse);
    expect(restored.snapshot.candidateProse, isEmpty);
  });

  test('restart and accept reject a spoofed generation bundle', () async {
    final first = buildStore();
    addTearDown(first.dispose);
    await first.ready;
    await first.runCurrentScene();
    final spoofedHash = List<String>.filled(64, 'f').join();
    final spoofed = first.snapshot.toJson()
      ..['candidateGenerationBundleHash'] = 'sha256:$spoofedHash';
    await runStorage.save(spoofed, sceneScopeId: workspace.currentSceneScopeId);

    final restored = buildStore();
    addTearDown(restored.dispose);
    await restored.ready;

    expect(restored.snapshot.status, StoryGenerationRunStatus.failed);
    expect(restored.snapshot.hasDurableCandidateProof, isFalse);
    expect(restored.snapshot.candidateProse, isEmpty);
    await expectLater(
      restored.acceptCurrentCandidate(),
      throwsA(isA<StateError>()),
    );
    expect(
      db.select('SELECT * FROM story_generation_commit_receipts'),
      isEmpty,
    );
  });

  test(
    'an existing run cannot be rebound to another published bundle',
    () async {
      final store = buildStore();
      addTearDown(store.dispose);
      await store.ready;
      await store.runCurrentScene();
      final original = store.snapshot.candidateGenerationBundleHash;
      final otherRawHash = List<String>.filled(64, 'e').join();
      db.execute(
        '''INSERT INTO generation_bundles
         (bundle_hash, bundle_id, releases_json, created_at_ms)
         VALUES (?, 'hostile-rebind', '[]', 1)''',
        <Object?>[otherRawHash],
      );
      final run = db.select(
        'SELECT * FROM story_generation_runs WHERE run_id = ?',
        <Object?>[store.snapshot.runId],
      ).single;

      expect(
        () => ledger.createRunWithGenerationBundle(
          run: GenerationRunRecord(
            runId: run['run_id'] as String,
            requestId: run['request_id'] as String,
            projectId: run['project_id'] as String,
            chapterId: run['chapter_id'] as String,
            sceneId: run['scene_id'] as String,
            sceneScopeId: run['scene_scope_id'] as String,
            status: run['status'] as String,
            phase: run['phase'] as String,
            schemaVersion: run['schema_version'] as int,
            createdAtMs: run['created_at_ms'] as int,
            updatedAtMs: run['updated_at_ms'] as int,
          ),
          generationBundleHash: 'sha256:$otherRawHash',
          createdAtMs: 2,
        ),
        throwsA(isA<GenerationLedgerInvariantViolation>()),
      );
      expect(ledger.generationBundleHashForRun(store.snapshot.runId), original);
    },
  );

  test(
    'restart keeps proof pointer and accept/reject alter only their write set',
    () async {
      final first = buildStore();
      addTearDown(first.dispose);
      await first.ready;
      await first.runCurrentScene();
      final runId = first.snapshot.runId;
      final revision = first.snapshot.candidateRevision;

      final restored = buildStore();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.snapshot.hasDurableCandidateProof, isTrue);
      expect(restored.snapshot.runId, runId);
      expect(restored.snapshot.candidateRevision, revision);

      expect(await restored.rejectCurrentCandidate(), isTrue);
      expect(
        db
            .select('SELECT state FROM story_generation_pending_writes')
            .map((row) => row['state']),
        everyElement('discarded'),
      );
      expect(
        db.select('SELECT text_body FROM draft_documents').single['text_body'],
        '作者原稿',
      );
      expect(db.select('SELECT * FROM version_entries'), isEmpty);

      // A rejected candidate is terminal and cannot be promoted later.
      expect(
        () => coordinator.accept(_requestFor(first.snapshot, workspace)),
        throwsA(isA<GenerationRunStateConflict>()),
      );
    },
  );

  test(
    'accept commits the exact proof after restart and keeps one receipt',
    () async {
      final first = buildStore();
      addTearDown(first.dispose);
      await first.ready;
      await first.runCurrentScene();
      final restored = buildStore();
      addTearDown(restored.dispose);
      await restored.ready;

      await restored.acceptCurrentCandidate();
      expect(
        db.select('SELECT text_body FROM draft_documents').single['text_body'],
        _passingProse,
      );
      expect(db.select('SELECT * FROM version_entries'), hasLength(1));
      expect(
        db.select('SELECT * FROM story_generation_commit_receipts'),
        hasLength(1),
      );
      expect(
        db
            .select('SELECT state FROM story_generation_pending_writes')
            .map((row) => row['state']),
        everyElement('committed'),
      );
    },
  );

  test(
    'accept projects staged roleplay and character deltas into existing stores',
    () async {
      final store = buildStore();
      addTearDown(store.dispose);
      await store.ready;
      await store.runCurrentScene();
      await store.acceptCurrentCandidate();

      final roleplay = await RoleplaySessionStoreIO(db: db).loadSession(
        projectId: workspace.currentProjectId,
        chapterId: workspace.currentScene.chapterLabel,
        sceneId: workspace.currentScene.id,
      );
      final memories = await CharacterMemoryStoreIO(db: db)
          .loadCharacterMemories(
            projectId: workspace.currentProjectId,
            characterId: 'character-1',
            tier: MemoryTier.character,
          );
      expect(roleplay, isNotNull);
      expect(roleplay!.rounds, hasLength(1));
      expect(
        memories.map((delta) => delta.deltaId),
        contains('delta-accepted'),
      );
    },
  );

  test('author edit re-finalizes N+1 and accepts only its namespace', () async {
    var invocation = 0;
    final store = buildStore(
      proseFactory: () =>
          invocation++ == 0 ? _initialRevisionProse : _editedRevisionProse,
    );
    addTearDown(store.dispose);
    await store.ready;

    await store.runCurrentScene();
    final runId = store.snapshot.runId;
    expect(store.snapshot.candidateRevision, 0);
    expect(store.snapshot.candidateProse, _initialRevisionProse);

    await store.beginEditedCandidateRevision(_editedRevisionProse);
    await store.runCurrentScene();

    expect(store.snapshot.errorDetail, isEmpty);
    expect(store.snapshot.status, StoryGenerationRunStatus.completed);
    expect(store.snapshot.candidateRevision, 1);
    expect(store.snapshot.candidateProse, _editedRevisionProse);
    final proofs = db.select(
      '''
        SELECT candidate_revision, final_prose_hash
        FROM story_generation_candidate_proofs
        WHERE run_id = ? ORDER BY candidate_revision
      ''',
      [runId],
    );
    expect(proofs, hasLength(2));
    expect(proofs.map((row) => row['candidate_revision']), [0, 1]);
    expect(
      proofs.last['final_prose_hash'],
      GenerationCommitDigest.text(_editedRevisionProse),
    );
    expect(
      db
          .select(
            '''
          SELECT stage_attempt FROM story_generation_stage_checkpoints
          WHERE run_id = ? AND ordinal = 12 AND stage_id = 'finalization'
          ORDER BY stage_attempt
        ''',
            [runId],
          )
          .map((row) => row['stage_attempt']),
      [1, 2],
    );

    await store.acceptCurrentCandidate();
    expect(
      db
          .select(
            '''
          SELECT candidate_revision FROM story_generation_pending_writes
          WHERE run_id = ? AND state = 'committed'
          ORDER BY candidate_revision, write_id
        ''',
            [runId],
          )
          .map((row) => row['candidate_revision']),
      everyElement(1),
    );
    final revisionOneWrites = db.select(
      '''
        SELECT derivation_class, payload_json
        FROM story_generation_pending_writes
        WHERE run_id = ? AND candidate_revision = 1
      ''',
      [runId],
    );
    expect(
      revisionOneWrites.map((row) => row['derivation_class']),
      containsAll(<String>['preProse', 'proseDerived']),
    );
    expect(
      revisionOneWrites
          .map((row) => row['payload_json'] as String)
          .where((payload) => payload.contains('sceneSummaryContribution')),
      everyElement(contains(_editedRevisionProse)),
    );
    expect(
      db
          .select(
            '''
          SELECT state FROM story_generation_pending_writes
          WHERE run_id = ? AND candidate_revision = 0
        ''',
            [runId],
          )
          .map((row) => row['state']),
      everyElement('staged'),
    );
    expect(
      db
          .select(
            '''
          SELECT candidate_revision FROM story_generation_commit_receipts
          WHERE run_id = ?
        ''',
            [runId],
          )
          .single['candidate_revision'],
      1,
    );
  });
}

const _passingProse = '「证据就在这里，追兵已经到了。」他把文件压在桌上，门外的脚步声正在逼近。';
const _initialRevisionProse = '「证据先别交出去，追兵已经到了。」他扣住文件，门外的脚步声正在逼近。';
const _editedRevisionProse = '「证据现在交出去，追兵已经到了。」他推开文件，门外的警报骤然响起。';

GenerationCommitRequest _requestFor(
  StoryGenerationRunSnapshot snapshot,
  AppWorkspaceStore workspace,
) => GenerationCommitRequest(
  acceptIdempotencyKey: 'direct-retry:${snapshot.runId}',
  runId: snapshot.runId,
  candidateRevision: snapshot.candidateRevision!,
  projectId: workspace.currentProjectId,
  sceneScopeId: workspace.currentSceneScopeId,
  candidateHash: snapshot.candidateHash,
  expectedBaseDraftHash: snapshot.candidateBaseDraftHash,
  expectedMaterialDigest: snapshot.candidateMaterialDigest,
  expectedInputDigest: snapshot.candidateInputDigest,
  expectedFinalProseHash: snapshot.candidateFinalProseHash,
  expectedDeterministicGateEvidenceHash:
      snapshot.candidateDeterministicGateEvidenceHash,
  expectedFinalCouncilEvidenceHash: snapshot.candidateFinalCouncilEvidenceHash,
  expectedQualityEvidenceHash: snapshot.candidateQualityEvidenceHash,
  expectedPendingWriteSetHash: snapshot.candidatePendingWriteSetHash,
  committedAtMs: 100,
);

class _PassingRunner extends PipelineStageRunnerImpl {
  _PassingRunner({required super.settingsStore, required this.prose});

  final String prose;

  @override
  Future<SceneRuntimeOutput> runScene(
    SceneBrief brief, {
    ProjectMaterialSnapshot? materials,
    void Function()? onSpeculationReady,
  }) async {
    final preQualityEvidence = ProductionPreQualityGate.standard
        .verifyPipelinePolish(
          brief: brief,
          materials: materials ?? const ProjectMaterialSnapshot(),
          prePolishProse: prose,
          finalProse: prose,
          hardGatesEnabled: true,
        );
    return SceneRuntimeOutput(
      brief: brief,
      resolvedCast: const [],
      director: const SceneDirectorOutput(text: '导演通过'),
      roleOutputs: const [],
      roleplaySession: SceneRoleplaySession(
        chapterId: brief.chapterId,
        sceneId: brief.sceneId,
        sceneTitle: brief.sceneTitle,
        rounds: [
          SceneRoleplayRound(
            round: 1,
            turns: const [],
            arbitration: SceneRoleplayArbitration(
              fact: '角色做出承诺',
              state: '关系推进',
              pressure: '误会未解',
              nextPublicState: '承诺待验证',
              shouldStop: true,
              rawText: '裁决通过',
              acceptedMemoryDeltas: [
                CharacterMemoryDelta(
                  deltaId: 'delta-accepted',
                  characterId: 'character-1',
                  kind: CharacterMemoryDeltaKind.intention,
                  content: '会在黎明前兑现承诺',
                  acl: VisibilityAcl.characters({'character-1'}),
                  sourceRound: 1,
                  sourceTurnId: 'turn-1',
                  accepted: true,
                ),
              ],
            ),
          ),
        ],
      ),
      prose: SceneProseDraft(text: prose, attempt: 1),
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
        summary: '质量通过',
      ),
      polishCanonEvidence: preQualityEvidence.polishCanonEvidence,
      storyMechanicsEvidence: preQualityEvidence.storyMechanicsEvidence,
      productionPreQualityEvidence: preQualityEvidence.toJson(),
    );
  }
}
