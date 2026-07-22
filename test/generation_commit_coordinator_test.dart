import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/authoring_table_definitions.dart';
import 'package:novel_writer/features/story_generation/data/generation_commit_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('GenerationCommitCoordinator', () {
    late Database db;
    late GenerationLedgerSqliteStore ledger;
    late GenerationCommitCoordinator coordinator;

    setUp(() {
      db = sqlite3.openInMemory();
      db.execute('PRAGMA foreign_keys = ON');
      ledger = GenerationLedgerSqliteStore(db: db)..ensureTables();
      coordinator = GenerationCommitCoordinator(db: db)..ensureTables();
      _seedCandidate(ledger, db);
    });

    tearDown(() => db.dispose());

    test('commit digest preserves the canonical ledger text identity', () {
      expect(
        GenerationCommitDigest.text('第一行\r\n第二行'),
        'sha256:61f8655a9b219b9ce122c6c7cd59ad09feac38240699cfec8d0c9b1e81a748ab',
      );
    });

    test('commits all authoring effects once and retries by receipt', () {
      final request = _request();
      final first = coordinator.accept(request);

      expect(first, isA<GenerationCommitApplied>());
      expect(
        db.select('SELECT text_body FROM draft_documents').single['text_body'],
        '最终正文',
      );
      expect(db.select('SELECT * FROM version_entries'), hasLength(1));
      expect(
        db
            .select('SELECT state FROM story_generation_pending_writes')
            .single['state'],
        'committed',
      );
      expect(
        db.select('SELECT status FROM story_generation_runs').single['status'],
        'committed',
      );
      expect(
        db.select('SELECT * FROM story_generation_commit_receipts'),
        hasLength(1),
      );
      expect(db.select('SELECT * FROM story_generation_outbox'), hasLength(1));
      expect(
        db.select('SELECT * FROM story_generation_summary_revisions'),
        hasLength(1),
      );
      expect(
        db.select('SELECT * FROM story_generation_summary_heads'),
        hasLength(1),
      );

      final retry = coordinator.accept(request);
      expect(retry, isA<GenerationCommitAlreadyApplied>());
      expect(db.select('SELECT * FROM version_entries'), hasLength(1));
      expect(db.select('SELECT * FROM story_generation_outbox'), hasLength(1));
      expect(
        () => coordinator.accept(_request(candidateHash: 'other-candidate')),
        throwsA(isA<GenerationIdempotencyConflict>()),
      );
    });

    test(
      'commits exact final prose continuity and reloads only proven state',
      () {
        final staged = db.select(
          '''SELECT payload_json FROM story_generation_pending_writes
                 WHERE write_kind = 'sceneSummaryContribution' ''',
        ).single;
        final payload = jsonDecode(staged['payload_json'] as String) as Map;
        final contribution = payload['contribution'] as Map;
        expect(contribution['prose'], '最终正文');
        expect(
          contribution['finalProseHash'],
          GenerationCommitDigest.text('最终正文'),
        );

        expect(coordinator.accept(_request()), isA<GenerationCommitApplied>());
        final committed = ledger.loadCommittedContinuityLedger(
          projectId: 'project-1',
          sourceSceneIds: const <String>['scene-1'],
        );
        expect(committed, hasLength(1));
        expect(committed.single['entityId'], 'evidence-drive');
        expect(committed.single['holder'], 'liuxi');
      },
    );

    test('folds reverse commits in caller-provided narrative order', () {
      _seedCandidateVariant(
        ledger,
        db,
        runId: 'run-2',
        requestId: 'request-2',
        sceneId: 'scene-2',
        sceneScopeId: 'project-1::scene-2',
        finalProse: '第二场正文',
        previousDraft: '第二场旧稿',
        holder: 'scene-two-holder',
        candidateHash: 'candidate-2',
        writeId: 'write-2',
      );

      expect(
        coordinator.accept(
          _requestVariant(
            acceptIdempotencyKey: 'accept-2',
            runId: 'run-2',
            sceneScopeId: 'project-1::scene-2',
            sceneId: 'scene-2',
            candidateHash: 'candidate-2',
            writeId: 'write-2',
            finalProse: '第二场正文',
            previousDraft: '第二场旧稿',
            holder: 'scene-two-holder',
            committedAtMs: 400,
          ),
        ),
        isA<GenerationCommitApplied>(),
      );
      expect(
        coordinator.accept(_request(committedAtMs: 500)),
        isA<GenerationCommitApplied>(),
      );

      final reloaded = ledger.loadCommittedContinuityLedger(
        projectId: 'project-1',
        sourceSceneIds: const <String>['scene-1', 'scene-2'],
      );
      expect(reloaded.single['holder'], 'scene-two-holder');
      expect(reloaded.single['sourceSceneId'], 'scene-2');
    });

    test('same-millisecond cross-scene commits still use narrative order', () {
      _seedCandidateVariant(
        ledger,
        db,
        runId: 'run-0',
        requestId: 'request-0',
        sceneId: 'scene-2',
        sceneScopeId: 'project-1::scene-2',
        finalProse: '第二场正文',
        previousDraft: '第二场旧稿',
        holder: 'scene-two-holder',
        candidateHash: 'candidate-0',
        writeId: 'write-0',
      );

      expect(
        coordinator.accept(
          _requestVariant(
            acceptIdempotencyKey: 'accept-0',
            runId: 'run-0',
            sceneScopeId: 'project-1::scene-2',
            sceneId: 'scene-2',
            candidateHash: 'candidate-0',
            writeId: 'write-0',
            finalProse: '第二场正文',
            previousDraft: '第二场旧稿',
            holder: 'scene-two-holder',
            committedAtMs: 500,
          ),
        ),
        isA<GenerationCommitApplied>(),
      );
      expect(
        coordinator.accept(_request(committedAtMs: 500)),
        isA<GenerationCommitApplied>(),
      );

      final reloaded = ledger.loadCommittedContinuityLedger(
        projectId: 'project-1',
        sourceSceneIds: const <String>['scene-1', 'scene-2'],
      );
      expect(reloaded.single['holder'], 'scene-two-holder');
    });

    test(
      'same-scene same-millisecond commits use the stable commit ordinal',
      () {
        expect(
          coordinator.accept(_request(committedAtMs: 500)),
          isA<GenerationCommitApplied>(),
        );
        _seedCandidateVariant(
          ledger,
          db,
          runId: 'run-0',
          requestId: 'request-0',
          sceneId: 'scene-1',
          sceneScopeId: 'project-1::scene-1',
          finalProse: '同场修订正文',
          previousDraft: '最终正文',
          holder: 'newer-same-scene-holder',
          candidateHash: 'candidate-0',
          writeId: 'write-0',
        );

        expect(
          coordinator.accept(
            _requestVariant(
              acceptIdempotencyKey: 'accept-0',
              runId: 'run-0',
              sceneScopeId: 'project-1::scene-1',
              sceneId: 'scene-1',
              candidateHash: 'candidate-0',
              writeId: 'write-0',
              finalProse: '同场修订正文',
              previousDraft: '最终正文',
              holder: 'newer-same-scene-holder',
              committedAtMs: 500,
            ),
          ),
          isA<GenerationCommitApplied>(),
        );

        final ordinals = db.select('''
        SELECT commit_ordinal FROM story_generation_committed_continuity
        ORDER BY commit_ordinal
      ''');
        expect(ordinals.map((row) => row['commit_ordinal']).toList(), <Object?>[
          1,
          2,
        ]);
        final reloaded = ledger.loadCommittedContinuityLedger(
          projectId: 'project-1',
          sourceSceneIds: const <String>['scene-1'],
        );
        expect(reloaded.single['holder'], 'newer-same-scene-holder');
      },
    );

    test('legacy-only continuity fails closed without a stable ordinal', () {
      expect(coordinator.accept(_request()), isA<GenerationCommitApplied>());
      _rebuildContinuityAsLegacySchema(ledger, db);

      expect(
        () => ledger.loadCommittedContinuityLedger(
          projectId: 'project-1',
          sourceSceneIds: const <String>['scene-1'],
        ),
        throwsA(isA<GenerationLedgerInvariantViolation>()),
      );
    });

    test('a regenerated scene supersedes its legacy continuity safely', () {
      expect(coordinator.accept(_request()), isA<GenerationCommitApplied>());
      _rebuildContinuityAsLegacySchema(ledger, db);
      _seedCandidateVariant(
        ledger,
        db,
        runId: 'run-regenerated',
        requestId: 'request-regenerated',
        sceneId: 'scene-1',
        sceneScopeId: 'project-1::scene-1',
        finalProse: '重新生成正文',
        previousDraft: '最终正文',
        holder: 'regenerated-holder',
        candidateHash: 'candidate-regenerated',
        writeId: 'write-regenerated',
      );

      expect(
        coordinator.accept(
          _requestVariant(
            acceptIdempotencyKey: 'accept-regenerated',
            runId: 'run-regenerated',
            sceneScopeId: 'project-1::scene-1',
            sceneId: 'scene-1',
            candidateHash: 'candidate-regenerated',
            writeId: 'write-regenerated',
            finalProse: '重新生成正文',
            previousDraft: '最终正文',
            holder: 'regenerated-holder',
            committedAtMs: 500,
          ),
        ),
        isA<GenerationCommitApplied>(),
      );
      expect(
        db
            .select('''
              SELECT commit_ordinal
              FROM story_generation_committed_continuity
              ORDER BY receipt_id
            ''')
            .map((row) => row['commit_ordinal']),
        containsAll(<Object?>[null, 1]),
      );

      final reloaded = ledger.loadCommittedContinuityLedger(
        projectId: 'project-1',
        sourceSceneIds: const <String>['scene-1'],
      );
      expect(reloaded.single['holder'], 'regenerated-holder');
    });

    test('rejects payload JSON tampering before author commit', () {
      final tampered = GenerationPendingWritePayloadIntegrity.canonicalJson(
        _continuityPayload(holder: 'attacker'),
      );
      db.execute(
        '''UPDATE story_generation_pending_writes SET payload_json = ?
           WHERE run_id = 'run-1' AND candidate_revision = 0''',
        <Object?>[tampered],
      );

      expect(
        () => coordinator.accept(_request()),
        throwsA(isA<GenerationCandidateEvidenceConflict>()),
      );
      _expectUncommitted(db);
    });

    test('rejects coordinated payload, hash, and manifest tampering', () {
      final tampered = GenerationPendingWritePayloadIntegrity.canonicalJson(
        _continuityPayload(holder: 'attacker'),
      );
      final tamperedHash =
          GenerationPendingWritePayloadIntegrity.hashCanonicalJson(tampered);
      db.execute(
        '''UPDATE story_generation_pending_writes
           SET payload_json = ?, payload_hash = ?
           WHERE run_id = 'run-1' AND candidate_revision = 0''',
        <Object?>[tampered, tamperedHash],
      );
      db.execute(
        '''UPDATE story_generation_candidate_payloads
           SET pending_write_manifest_json = ?
           WHERE run_id = 'run-1' AND candidate_revision = 0''',
        <Object?>[
          GenerationPendingWritePayloadIntegrity.canonicalJson(<Object?>[
            <String, Object?>{
              'writeId': 'write-1',
              'payloadHash': tamperedHash,
            },
          ]),
        ],
      );

      expect(
        () => coordinator.accept(_request()),
        throwsA(isA<GenerationCandidateEvidenceConflict>()),
      );
      _expectUncommitted(db);
    });

    test('revalidates payload integrity immediately before projection', () {
      final tampered = GenerationPendingWritePayloadIntegrity.canonicalJson(
        _continuityPayload(holder: 'late-attacker'),
      );
      final faulting = GenerationCommitCoordinator(
        db: db,
        faultInjector: (step) {
          if (step == GenerationCommitStep.candidateValidated) {
            db.execute(
              '''UPDATE story_generation_pending_writes SET payload_json = ?
                 WHERE run_id = 'run-1' AND candidate_revision = 0''',
              <Object?>[tampered],
            );
          }
        },
      );

      expect(
        () => faulting.accept(_request()),
        throwsA(isA<GenerationCandidateEvidenceConflict>()),
      );
      _expectUncommitted(db);
    });

    test('rejects coordinated late payload, hash, and manifest tampering', () {
      final tampered = GenerationPendingWritePayloadIntegrity.canonicalJson(
        _continuityPayload(holder: 'late-attacker'),
      );
      final tamperedHash =
          GenerationPendingWritePayloadIntegrity.hashCanonicalJson(tampered);
      final faulting = GenerationCommitCoordinator(
        db: db,
        faultInjector: (step) {
          if (step != GenerationCommitStep.candidateValidated) return;
          db.execute(
            '''UPDATE story_generation_pending_writes
               SET payload_json = ?, payload_hash = ?
               WHERE run_id = 'run-1' AND candidate_revision = 0''',
            <Object?>[tampered, tamperedHash],
          );
          db.execute(
            '''UPDATE story_generation_candidate_payloads
               SET pending_write_manifest_json = ?
               WHERE run_id = 'run-1' AND candidate_revision = 0''',
            <Object?>[
              GenerationPendingWritePayloadIntegrity.canonicalJson(<Object?>[
                <String, Object?>{
                  'writeId': 'write-1',
                  'payloadHash': tamperedHash,
                },
              ]),
            ],
          );
        },
      );

      expect(
        () => faulting.accept(_request()),
        throwsA(isA<GenerationCandidateEvidenceConflict>()),
      );
      _expectUncommitted(db);
    });

    for (final attack in <String, void Function(Database)>{
      'row addition': (database) {
        database.execute('''INSERT INTO story_generation_pending_writes (
               run_id, candidate_revision, write_id, project_id, chapter_id,
               scene_id, logical_entity_id, write_kind, payload_hash,
               payload_json, derivation_class, state, tier, producer,
               visibility, owner_id, created_at_ms, expires_at_ms
             )
             SELECT run_id, candidate_revision, 'late-write', project_id,
               chapter_id, scene_id, 'late-entity', write_kind, payload_hash,
               payload_json, derivation_class, state, tier, producer,
               visibility, owner_id, created_at_ms, expires_at_ms
             FROM story_generation_pending_writes
             WHERE run_id = 'run-1' AND candidate_revision = 0''');
      },
      'row deletion': (database) {
        database.execute('''DELETE FROM story_generation_pending_writes
             WHERE run_id = 'run-1' AND candidate_revision = 0''');
      },
      'state mutation': (database) {
        database.execute(
          '''UPDATE story_generation_pending_writes SET state = 'discarded'
             WHERE run_id = 'run-1' AND candidate_revision = 0''',
        );
      },
      'kind mutation': (database) {
        database.execute(
          '''UPDATE story_generation_pending_writes SET write_kind = 'thoughtAtom'
             WHERE run_id = 'run-1' AND candidate_revision = 0''',
        );
      },
    }.entries) {
      test('rejects late pending namespace ${attack.key}', () {
        final faulting = GenerationCommitCoordinator(
          db: db,
          faultInjector: (step) {
            if (step == GenerationCommitStep.candidateValidated) {
              attack.value(db);
            }
          },
        );

        expect(
          () => faulting.accept(_request()),
          throwsA(isA<GenerationCandidateEvidenceConflict>()),
        );
        _expectUncommitted(db);
      });
    }

    test('ignores tampered pending-write cache after commit', () {
      expect(coordinator.accept(_request()), isA<GenerationCommitApplied>());
      final tampered = GenerationPendingWritePayloadIntegrity.canonicalJson(
        _continuityPayload(holder: 'post-commit-attacker'),
      );
      db.execute(
        '''UPDATE story_generation_pending_writes SET payload_json = ?
           WHERE run_id = 'run-1' AND candidate_revision = 0''',
        <Object?>[tampered],
      );

      final reloaded = ledger.loadCommittedContinuityLedger(
        projectId: 'project-1',
        sourceSceneIds: const <String>['scene-1'],
      );
      expect(reloaded.single['holder'], 'liuxi');
    });

    for (final cacheAttack in <String, void Function(Database)>{
      'deletion': (database) =>
          database.execute('DELETE FROM story_generation_pending_writes'),
      'state mutation': (database) => database.execute(
        "UPDATE story_generation_pending_writes SET state = 'discarded'",
      ),
      'kind mutation': (database) => database.execute(
        "UPDATE story_generation_pending_writes SET write_kind = 'thoughtAtom'",
      ),
    }.entries) {
      test(
        'keeps durable continuity after post-commit cache ${cacheAttack.key}',
        () {
          expect(
            coordinator.accept(_request()),
            isA<GenerationCommitApplied>(),
          );
          cacheAttack.value(db);

          expect(
            ledger
                .loadCommittedContinuityLedger(
                  projectId: 'project-1',
                  sourceSceneIds: const <String>['scene-1'],
                )
                .single['holder'],
            'liuxi',
          );
        },
      );
    }

    test(
      'makes durable continuity delete, state, kind, hash, and payload immutable',
      () {
        expect(coordinator.accept(_request()), isA<GenerationCommitApplied>());
        for (final statement in <String>[
          'DELETE FROM story_generation_committed_continuity',
          "UPDATE story_generation_committed_continuity SET state = 'staged'",
          "UPDATE story_generation_committed_continuity SET write_kind = 'thoughtAtom'",
          "UPDATE story_generation_committed_continuity SET payload_hash = 'tampered'",
          "UPDATE story_generation_committed_continuity SET payload_json = '{}'",
        ]) {
          expect(() => db.execute(statement), throwsA(isA<SqliteException>()));
        }
        expect(
          ledger
              .loadCommittedContinuityLedger(
                projectId: 'project-1',
                sourceSceneIds: const <String>['scene-1'],
              )
              .single['holder'],
          'liuxi',
        );
      },
    );

    test('reloads durable continuity after legitimate TTL sweep', () {
      expect(coordinator.accept(_request()), isA<GenerationCommitApplied>());

      final report = ledger.sweepRetention(nowMs: 1001);
      expect(report.deletedCandidatePayloads, 1);
      expect(report.deletedPendingWrites, 1);
      expect(
        db.select('SELECT * FROM story_generation_candidate_payloads'),
        isEmpty,
      );
      expect(
        db.select('SELECT * FROM story_generation_pending_writes'),
        isEmpty,
      );
      expect(
        ledger
            .loadCommittedContinuityLedger(
              projectId: 'project-1',
              sourceSceneIds: const <String>['scene-1'],
            )
            .single['holder'],
        'liuxi',
      );
    });

    test(
      'fails closed for a tampered manifest without authoritative writes',
      () {
        db.execute('''
        UPDATE story_generation_candidate_payloads
        SET pending_write_manifest_json = '[]'
        WHERE run_id = 'run-1' AND candidate_revision = 0
        ''');

        expect(
          () => coordinator.accept(_request()),
          throwsA(isA<GenerationCandidateEvidenceConflict>()),
        );
        _expectUncommitted(db);
      },
    );

    test('cannot relabel a sealed candidate run into another scene scope', () {
      expect(
        () => db.execute('''
            UPDATE story_generation_runs
            SET scene_scope_id = 'project-1::scene-2'
            WHERE run_id = 'run-1'
          '''),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => coordinator.accept(
          _requestVariant(
            acceptIdempotencyKey: 'accept-relabeled-scope',
            runId: 'run-1',
            sceneScopeId: 'project-1::scene-2',
            sceneId: 'scene-1',
            candidateHash: 'candidate-hash',
            writeId: 'write-1',
            finalProse: '最终正文',
            previousDraft: '旧草稿',
            holder: 'liuxi',
            committedAtMs: 500,
          ),
        ),
        throwsA(isA<GenerationRunStateConflict>()),
      );
      _expectUncommitted(db);
      expect(db.select('SELECT * FROM version_entries'), isEmpty);
      expect(
        db.select('SELECT project_id, text_body FROM draft_documents'),
        <Map<String, Object?>>[
          <String, Object?>{
            'project_id': 'project-1::scene-1',
            'text_body': '旧草稿',
          },
        ],
      );
    });

    test(
      'commit rejects a legacy cross-scene run before touching either draft',
      () {
        // Model a malformed row already present in a V28 database. Production
        // V29 migration blocks this row, while the commit boundary independently
        // fails closed if a damaged/offline-edited database reaches it.
        db.execute(
          'DROP TRIGGER IF EXISTS prevent_generation_run_identity_update',
        );
        db.execute('PRAGMA ignore_check_constraints = ON');
        db.execute('''
        UPDATE story_generation_runs
        SET scene_scope_id = 'project-1::scene-2'
        WHERE run_id = 'run-1'
      ''');
        db.execute('PRAGMA ignore_check_constraints = OFF');
        createStoryGenerationRunIdentityWriteGuards(db);
        db.execute('''
        INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
        VALUES ('project-1::scene-2', '第二场作者原稿', 100)
      ''');

        expect(
          () => coordinator.accept(
            _requestVariant(
              acceptIdempotencyKey: 'accept-cross-scene',
              runId: 'run-1',
              sceneScopeId: 'project-1::scene-2',
              sceneId: 'scene-1',
              candidateHash: 'candidate-hash',
              writeId: 'write-1',
              finalProse: '最终正文',
              previousDraft: '第二场作者原稿',
              holder: 'liuxi',
              committedAtMs: 500,
            ),
          ),
          throwsA(isA<GenerationRunStateConflict>()),
        );
        _expectUncommitted(db);
        expect(db.select('SELECT * FROM version_entries'), isEmpty);
        expect(
          db.select('''
          SELECT project_id, text_body FROM draft_documents ORDER BY project_id
        '''),
          <Map<String, Object?>>[
            <String, Object?>{
              'project_id': 'project-1::scene-1',
              'text_body': '旧草稿',
            },
            <String, Object?>{
              'project_id': 'project-1::scene-2',
              'text_body': '第二场作者原稿',
            },
          ],
        );
      },
    );

    test('returns a typed draft conflict for a stale base digest', () {
      db.execute("UPDATE draft_documents SET text_body = '作者并发编辑'");

      expect(
        () => coordinator.accept(_request()),
        throwsA(isA<GenerationDraftConflict>()),
      );
      _expectUncommitted(db);
      expect(
        db.select('SELECT text_body FROM draft_documents').single['text_body'],
        '作者并发编辑',
      );
    });

    test(
      'returns a typed material conflict without mutating the candidate',
      () {
        expect(
          () => coordinator.accept(_request(materialDigest: 'material-after')),
          throwsA(isA<GenerationMaterialConflict>()),
        );
        _expectUncommitted(db);
      },
    );

    test('rolls every pre-commit statement back under fault injection', () {
      for (final step in [
        GenerationCommitStep.begun,
        GenerationCommitStep.candidateValidated,
        GenerationCommitStep.draftWritten,
        GenerationCommitStep.versionWritten,
        GenerationCommitStep.pendingWritesCommitted,
        GenerationCommitStep.feedbackConsumed,
        GenerationCommitStep.receiptWritten,
        GenerationCommitStep.runCommitted,
        GenerationCommitStep.outboxWritten,
        GenerationCommitStep.beforeCommit,
      ]) {
        final faulting = GenerationCommitCoordinator(
          db: db,
          faultInjector: (actual) {
            if (actual == step) throw StateError('injected $step');
          },
        );

        expect(() => faulting.accept(_request()), throwsStateError);
        _expectUncommitted(db);
        expect(
          db
              .select('SELECT text_body FROM draft_documents')
              .single['text_body'],
          '旧草稿',
        );
        expect(db.select('SELECT * FROM version_entries'), isEmpty);
      }
    });

    test(
      'does not compensate a durable commit when response crashes after commit',
      () {
        final faulting = GenerationCommitCoordinator(
          db: db,
          faultInjector: (step) {
            if (step == GenerationCommitStep.afterCommit) {
              throw StateError('response lost');
            }
          },
        );
        expect(() => faulting.accept(_request()), throwsStateError);

        expect(
          db.select('SELECT * FROM story_generation_commit_receipts'),
          hasLength(1),
        );
        expect(
          db.select('SELECT * FROM story_generation_outbox'),
          hasLength(1),
        );
        expect(
          coordinator.accept(_request()),
          isA<GenerationCommitAlreadyApplied>(),
        );
      },
    );

    test(
      'validates JSON feedback lease and consumes it in the same transaction',
      () {
        db.execute(
          '''
        INSERT INTO author_feedback_projects (project_id, payload_json, updated_at_ms)
        VALUES (?, ?, ?)
        ''',
          [
            'project-1',
            '''{"items":[{"id":"feedback-1","status":"revisionRequested","decisions":[]}],"generationLeases":{"feedback-1":{"ownerRunId":"run-1","expiresAtMs":999,"state":"leased"}}}''',
            100,
          ],
        );
        const claim = GenerationFeedbackLeaseClaimRequest(
          projectId: 'project-1',
          runId: 'run-1',
          feedbackIds: ['feedback-1'],
          leaseExpiresAtMs: 999,
          claimedAtMs: 200,
        );
        final leases = coordinator.claimFeedbackLeases(claim);
        expect(coordinator.claimFeedbackLeases(claim), hasLength(1));
        expect(
          () => coordinator.claimFeedbackLeases(
            const GenerationFeedbackLeaseClaimRequest(
              projectId: 'project-1',
              runId: 'run-2',
              feedbackIds: ['feedback-1'],
              leaseExpiresAtMs: 999,
              claimedAtMs: 200,
            ),
          ),
          throwsA(isA<GenerationMaterialConflict>()),
        );
        final result = coordinator.accept(_request(feedbackLeases: leases));
        expect(result, isA<GenerationCommitApplied>());
        final payload =
            db
                    .select('SELECT payload_json FROM author_feedback_projects')
                    .single['payload_json']
                as String;
        expect(payload, contains('"accepted"'));
        expect(payload, contains('"consumed"'));
      },
    );

    test(
      'observes a writer from a second SQLite connection before BEGIN IMMEDIATE',
      () {
        final file = File(
          '${Directory.systemTemp.path}/generation-commit-${DateTime.now().microsecondsSinceEpoch}.db',
        );
        addTearDown(() => file.deleteSync());
        final first = sqlite3.open(file.path);
        final second = sqlite3.open(file.path);
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        first.execute('PRAGMA foreign_keys = ON');
        second.execute('PRAGMA foreign_keys = ON');
        final fileLedger = GenerationLedgerSqliteStore(db: first)
          ..ensureTables();
        final fileCoordinator = GenerationCommitCoordinator(db: first)
          ..ensureTables();
        _seedCandidate(fileLedger, first);

        second.execute(
          "UPDATE draft_documents SET text_body = '第二连接编辑' WHERE project_id = 'project-1::scene-1'",
        );
        expect(
          () => fileCoordinator.accept(_request()),
          throwsA(isA<GenerationDraftConflict>()),
        );
        expect(
          first.select('SELECT * FROM story_generation_commit_receipts'),
          isEmpty,
        );
      },
    );
  });
}

void _rebuildContinuityAsLegacySchema(
  GenerationLedgerSqliteStore ledger,
  Database db,
) {
  db.execute('''
    ALTER TABLE story_generation_committed_continuity
    RENAME TO story_generation_committed_continuity_with_ordinal
  ''');
  db.execute('''
    CREATE TABLE story_generation_committed_continuity (
      receipt_id TEXT PRIMARY KEY CHECK (length(trim(receipt_id)) > 0),
      run_id TEXT NOT NULL,
      candidate_revision INTEGER NOT NULL CHECK (candidate_revision >= 0),
      project_id TEXT NOT NULL CHECK (length(trim(project_id)) > 0),
      chapter_id TEXT NOT NULL CHECK (length(trim(chapter_id)) > 0),
      scene_id TEXT NOT NULL CHECK (length(trim(scene_id)) > 0),
      write_id TEXT NOT NULL CHECK (length(trim(write_id)) > 0),
      write_kind TEXT NOT NULL CHECK (write_kind = 'sceneSummaryContribution'),
      state TEXT NOT NULL CHECK (state = 'committed'),
      payload_hash TEXT NOT NULL CHECK (length(trim(payload_hash)) > 0),
      payload_json TEXT NOT NULL,
      final_prose_hash TEXT NOT NULL CHECK (length(trim(final_prose_hash)) > 0),
      pending_write_set_hash TEXT NOT NULL
        CHECK (length(trim(pending_write_set_hash)) > 0),
      committed_at_ms INTEGER NOT NULL CHECK (committed_at_ms >= 0),
      UNIQUE (run_id, candidate_revision, write_id),
      FOREIGN KEY (receipt_id)
        REFERENCES story_generation_commit_receipts(receipt_id)
        ON DELETE RESTRICT,
      FOREIGN KEY (run_id, candidate_revision)
        REFERENCES story_generation_candidate_proofs(run_id, candidate_revision)
        ON DELETE RESTRICT,
      FOREIGN KEY (run_id, project_id, chapter_id, scene_id)
        REFERENCES story_generation_runs(run_id, project_id, chapter_id, scene_id)
        ON DELETE RESTRICT
    )
  ''');
  db.execute('''
    INSERT INTO story_generation_committed_continuity (
      receipt_id, run_id, candidate_revision, project_id, chapter_id,
      scene_id, write_id, write_kind, state, payload_hash, payload_json,
      final_prose_hash, pending_write_set_hash, committed_at_ms
    )
    SELECT receipt_id, run_id, candidate_revision, project_id, chapter_id,
      scene_id, write_id, write_kind, state, payload_hash, payload_json,
      final_prose_hash, pending_write_set_hash, committed_at_ms
    FROM story_generation_committed_continuity_with_ordinal
  ''');
  db.execute('DROP TABLE story_generation_committed_continuity_with_ordinal');
  ledger.ensureTables();
}

void _seedCandidate(GenerationLedgerSqliteStore ledger, Database db) {
  _seedCandidateVariant(
    ledger,
    db,
    runId: 'run-1',
    requestId: 'request-1',
    sceneId: 'scene-1',
    sceneScopeId: 'project-1::scene-1',
    finalProse: '最终正文',
    previousDraft: '旧草稿',
    holder: 'liuxi',
    candidateHash: 'candidate-hash',
    writeId: 'write-1',
  );
}

void _seedCandidateVariant(
  GenerationLedgerSqliteStore ledger,
  Database db, {
  required String runId,
  required String requestId,
  required String sceneId,
  required String sceneScopeId,
  required String finalProse,
  required String previousDraft,
  required String holder,
  required String candidateHash,
  required String writeId,
}) {
  // The legacy fixture predates immutable generation-bundle binding. The
  // current reader still LEFT JOINs this additive table, so model its absent
  // historical row rather than using a current proof writer.
  db.execute('''
    CREATE TABLE IF NOT EXISTS story_generation_run_bundles (
      run_id TEXT PRIMARY KEY,
      bundle_hash TEXT NOT NULL
    )
  ''');
  final payloadJson = GenerationPendingWritePayloadIntegrity.canonicalJson(
    _continuityPayload(
      holder: holder,
      sceneId: sceneId,
      finalProse: finalProse,
    ),
  );
  final payloadHash = GenerationPendingWritePayloadIntegrity.hashCanonicalJson(
    payloadJson,
  );
  final manifest = <Object?>[
    <String, Object?>{'writeId': writeId, 'payloadHash': payloadHash},
  ];
  final pendingWriteSetHash = GenerationPendingWritePayloadIntegrity.hashValue(
    manifest,
  );
  ledger.createRun(
    GenerationRunRecord(
      runId: runId,
      requestId: requestId,
      projectId: 'project-1',
      chapterId: 'chapter-1',
      sceneId: sceneId,
      sceneScopeId: sceneScopeId,
      status: 'running',
      phase: 'finalization',
      schemaVersion: 9,
      createdAtMs: 100,
      updatedAtMs: 100,
    ),
  );
  ledger.createWorkingProseRevision(
    WorkingProseRevisionRecord(
      runId: runId,
      proseRevision: 0,
      proseHash: GenerationCommitDigest.text(finalProse),
      proseText: finalProse,
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
  ledger.upsertPendingWrite(
    PendingWriteRecord(
      runId: runId,
      candidateRevision: 0,
      writeId: writeId,
      projectId: 'project-1',
      chapterId: 'chapter-1',
      sceneId: sceneId,
      logicalEntityId: sceneId,
      writeKind: 'sceneSummaryContribution',
      payloadHash: payloadHash,
      payloadJson: payloadJson,
      derivationClass: 'proseDerived',
      createdAtMs: 100,
      expiresAtMs: 1000,
    ),
  );
  // This suite exercises legacy V1 acceptance/reload behavior.  It seeds a
  // row that would already exist after an old migration; current write APIs
  // must never be used to mint it.
  _withHistoricalV1SeedAdmission(
    db,
    () => db.execute(
      '''
    INSERT INTO story_generation_candidate_proofs (
      run_id, candidate_revision, project_id, chapter_id, scene_id,
      source_prose_revision, candidate_hash, final_prose_hash,
      deterministic_gate_evidence_hash, final_council_evidence_hash,
      quality_evidence_hash, pending_write_set_hash, material_digest,
      input_digest, proof_identity_version, generation_evidence_mode,
      created_at_ms
    ) VALUES (?, 0, 'project-1', 'chapter-1', ?, 0, ?, ?, 'gate-hash',
      'council-hash', 'quality-hash', ?, 'material-hash', 'input-hash',
      'candidate-proof-v1', 'legacy-unsealed-v1', 100)
    ''',
      <Object?>[
        runId,
        sceneId,
        candidateHash,
        GenerationCommitDigest.text(finalProse),
        pendingWriteSetHash,
      ],
    ),
  );
  db.execute(
    '''
    INSERT INTO story_generation_candidate_payloads (
      run_id, candidate_revision, final_prose, pending_write_manifest_json,
      created_at_ms, expires_at_ms
    ) VALUES (?, 0, ?, ?, 100, 1000)
    ''',
    <Object?>[
      runId,
      finalProse,
      GenerationPendingWritePayloadIntegrity.canonicalJson(manifest),
    ],
  );
  db.execute(
    '''
    UPDATE story_generation_runs
    SET status = 'candidateReady', current_candidate_revision = 0
    WHERE run_id = ?
    ''',
    <Object?>[runId],
  );
  db.execute(
    '''
    INSERT INTO draft_documents (project_id, text_body, updated_at_ms)
    VALUES (?, ?, 100)
    ON CONFLICT(project_id) DO UPDATE SET
      text_body = excluded.text_body,
      updated_at_ms = excluded.updated_at_ms
    ''',
    <Object?>[sceneScopeId, previousDraft],
  );
}

void _withHistoricalV1SeedAdmission(Database db, void Function() seed) {
  // This creates an already-durable V1 fixture only. The V28 database guard
  // is immediately restored before any behavior under test starts.
  db.execute(
    'DROP TRIGGER IF EXISTS prevent_new_legacy_generation_proof_insert',
  );
  try {
    seed();
  } finally {
    createCandidateProofV2WriteGuards(db);
  }
}

GenerationCommitRequest _request({
  String candidateHash = 'candidate-hash',
  String materialDigest = 'material-hash',
  List<GenerationFeedbackLease> feedbackLeases = const [],
  int committedAtMs = 500,
}) => _requestVariant(
  acceptIdempotencyKey: 'accept-1',
  runId: 'run-1',
  sceneScopeId: 'project-1::scene-1',
  sceneId: 'scene-1',
  candidateHash: candidateHash,
  writeId: 'write-1',
  finalProse: '最终正文',
  previousDraft: '旧草稿',
  holder: 'liuxi',
  committedAtMs: committedAtMs,
  materialDigest: materialDigest,
  feedbackLeases: feedbackLeases,
);

GenerationCommitRequest _requestVariant({
  required String acceptIdempotencyKey,
  required String runId,
  required String sceneScopeId,
  required String sceneId,
  required String candidateHash,
  required String writeId,
  required String finalProse,
  required String previousDraft,
  required String holder,
  required int committedAtMs,
  String materialDigest = 'material-hash',
  List<GenerationFeedbackLease> feedbackLeases = const [],
}) => GenerationCommitRequest(
  acceptIdempotencyKey: acceptIdempotencyKey,
  runId: runId,
  candidateRevision: 0,
  projectId: 'project-1',
  sceneScopeId: sceneScopeId,
  candidateHash: candidateHash,
  expectedBaseDraftHash: GenerationCommitDigest.text(previousDraft),
  expectedMaterialDigest: materialDigest,
  expectedInputDigest: 'input-hash',
  expectedFinalProseHash: GenerationCommitDigest.text(finalProse),
  expectedDeterministicGateEvidenceHash: 'gate-hash',
  expectedFinalCouncilEvidenceHash: 'council-hash',
  expectedQualityEvidenceHash: 'quality-hash',
  expectedPendingWriteSetHash: _pendingWriteSetHash(
    writeId: writeId,
    sceneId: sceneId,
    finalProse: finalProse,
    holder: holder,
  ),
  feedbackLeases: feedbackLeases,
  committedAtMs: committedAtMs,
);

Map<String, Object?> _continuityPayload({
  String holder = 'liuxi',
  String sceneId = 'scene-1',
  String finalProse = '最终正文',
}) => <String, Object?>{
  'kind': 'sceneSummaryContribution',
  'schemaVersion': 1,
  'projectId': 'project-1',
  'chapterId': 'chapter-1',
  'sceneId': sceneId,
  'target': <String, Object?>{
    'projectId': 'project-1',
    'chapterId': 'chapter-1',
    'sceneId': sceneId,
  },
  'contribution': <String, Object?>{
    'sceneId': sceneId,
    'finalProseHash': GenerationCommitDigest.text(finalProse),
    'prose': finalProse,
    'continuityLedger': <Object?>[
      <String, Object?>{
        'entityId': 'evidence-drive',
        'aliases': <String>['U盘'],
        'holder': holder,
        'location': 'archive-room',
        'status': 'held',
        'sourceSceneId': sceneId,
      },
    ],
  },
};

String _pendingWriteSetHash({
  String writeId = 'write-1',
  String sceneId = 'scene-1',
  String finalProse = '最终正文',
  String holder = 'liuxi',
}) {
  final payloadJson = GenerationPendingWritePayloadIntegrity.canonicalJson(
    _continuityPayload(
      holder: holder,
      sceneId: sceneId,
      finalProse: finalProse,
    ),
  );
  return GenerationPendingWritePayloadIntegrity.hashValue(<Object?>[
    <String, Object?>{
      'writeId': writeId,
      'payloadHash': GenerationPendingWritePayloadIntegrity.hashCanonicalJson(
        payloadJson,
      ),
    },
  ]);
}

void _expectUncommitted(Database db) {
  expect(db.select('SELECT * FROM story_generation_commit_receipts'), isEmpty);
  expect(
    db.select('SELECT * FROM story_generation_committed_continuity'),
    isEmpty,
  );
  expect(db.select('SELECT * FROM story_generation_outbox'), isEmpty);
  expect(
    db
        .select('SELECT state FROM story_generation_pending_writes')
        .single['state'],
    'staged',
  );
  expect(
    db.select('SELECT status FROM story_generation_runs').single['status'],
    'candidateReady',
  );
}
