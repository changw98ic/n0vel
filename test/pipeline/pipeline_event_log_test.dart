import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/typed_artifact.dart';

void main() {
  group('PipelineEventLogImpl', () {
    late PipelineEventLogImpl log;

    setUp(() {
      log = PipelineEventLogImpl();
    });

    tearDown(() async {
      await log.dispose();
    });

    test('emit and query events', () {
      log.emit(
        const PipelineEvent(
          timestampMs: 100,
          stageId: 'director',
          eventType: 'started',
        ),
      );
      log.emit(
        const PipelineEvent(
          timestampMs: 200,
          stageId: 'review',
          eventType: 'failed',
          failureCode: FailureCode.qualityFail,
        ),
      );
      log.emit(
        const PipelineEvent(
          timestampMs: 300,
          stageId: 'review',
          eventType: 'completed',
        ),
      );

      expect(log.query(stageId: 'review'), hasLength(2));
      expect(log.query(eventType: 'started'), hasLength(1));
      expect(log.query(failureCode: FailureCode.qualityFail), hasLength(1));
      expect(log.query(), hasLength(3));
    });

    test('ring buffer evicts oldest when full', () {
      log = PipelineEventLogImpl(ringBufferSize: 3);
      for (var i = 0; i < 5; i++) {
        log.emit(
          PipelineEvent(timestampMs: i, stageId: 'stage$i', eventType: 'tick'),
        );
      }
      expect(log.query(), hasLength(3));
      expect(log.query().first.stageId, 'stage2');
    });

    test('query with no matches returns empty', () {
      log.emit(
        const PipelineEvent(timestampMs: 1, stageId: 'a', eventType: 'b'),
      );
      expect(log.query(stageId: 'nonexistent'), isEmpty);
    });

    test('memory log is not accepted as durable experiment evidence', () async {
      expect(log.canPersistAndRetrieveEvidence, isFalse);
      expect(log.evidenceLocator, isNull);
      await expectLater(log.prepareEvidencePersistence(), throwsStateError);
      await expectLater(log.readPersistedEvents(), throwsStateError);
      expect(
        () => PipelineEvidenceLogScope.run(eventLog: log, body: () {}),
        throwsArgumentError,
      );
    });

    group('JSONL persistence', () {
      late Directory tempDir;
      late String jsonlPath;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('pipeline_log_test_');
        jsonlPath = '${tempDir.path}/pipeline.jsonl';
      });

      tearDown(() async {
        await log.dispose();
        await tempDir.delete(recursive: true);
      });

      test('writes events to JSONL file', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        expect(log.canPersistAndRetrieveEvidence, isTrue);
        expect(log.evidenceLocator, File(jsonlPath).absolute.path);
        await log.prepareEvidencePersistence();
        log.emit(
          const PipelineEvent(
            timestampMs: 42,
            stageId: 'director',
            eventType: 'started',
            artifactType: ArtifactType.directorPlan,
          ),
        );
        await log.flush();

        final content = await File(jsonlPath).readAsString();
        expect(content, contains('"stageId":"director"'));
        expect(content, contains('"artifactType":"directorPlan"'));
        final persisted = await log.readPersistedEvents();
        expect(persisted, hasLength(1));
        expect(persisted.single.stageId, 'director');
      });

      test('appendAndFlushEvidence is an observable commit barrier', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();

        await log.appendAndFlushEvidence(
          const PipelineEvent(
            timestampMs: 43,
            stageId: 'experiment_evidence',
            eventType: storyGenerationAttemptEvidenceRecordedEventType,
            metadata: <String, Object?>{
              'schemaVersion': storyGenerationAttemptEvidenceEventSchemaVersion,
              'private': <String, Object?>{'sequenceNo': 0},
            },
          ),
        );

        // No caller-side flush is needed: completion means a fresh reader can
        // already observe the evidence.
        final content = await File(jsonlPath).readAsString();
        expect(
          content,
          contains(storyGenerationAttemptEvidenceRecordedEventType),
        );
        final persisted = await log.readPersistedEvents();
        expect(persisted, hasLength(1));
        expect(
          persisted.single.eventType,
          storyGenerationAttemptEvidenceRecordedEventType,
        );
      });

      test(
        'scope survives async factory boundaries and shares its sink',
        () async {
          log = PipelineEventLogImpl(jsonlPath: jsonlPath);

          final inherited = await PipelineEvidenceLogScope.run(
            eventLog: log,
            body: () async {
              await Future<void>.value();
              return PipelineEvidenceLogScope.current;
            },
          );

          expect(inherited, same(log));
          expect(PipelineEvidenceLogScope.current, isNull);
        },
      );

      test('concurrent flush callers each wait for persisted writes', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();
        log.emit(
          const PipelineEvent(
            timestampMs: 1,
            stageId: 'first',
            eventType: 'recorded',
          ),
        );
        final firstFlush = log.flush();
        log.emit(
          const PipelineEvent(
            timestampMs: 2,
            stageId: 'second',
            eventType: 'recorded',
          ),
        );
        final secondFlush = log.flush();

        await Future.wait([firstFlush, secondFlush]);

        expect(
          (await log.readPersistedEvents()).map((event) => event.stageId),
          ['first', 'second'],
        );
      });

      test(
        'exclusive evidence lease rejects a second writer until dispose',
        () async {
          final first = PipelineEventLogImpl(jsonlPath: jsonlPath);
          final second = PipelineEventLogImpl(jsonlPath: jsonlPath);
          addTearDown(first.dispose);
          addTearDown(second.dispose);

          await first.prepareEvidencePersistence();
          await expectLater(
            second.prepareEvidencePersistence(),
            throwsStateError,
          );

          await first.dispose();
          await second.prepareEvidencePersistence();
          await second.appendAndFlushEvidence(
            const PipelineEvent(
              timestampMs: 3,
              stageId: 'experiment_evidence',
              eventType: 'lease_handoff_verified',
            ),
          );
          expect(
            (await second.readPersistedEvents()).single.eventType,
            'lease_handoff_verified',
          );
        },
      );

      test(
        'evidence append fails before the writer lease is prepared',
        () async {
          log = PipelineEventLogImpl(jsonlPath: jsonlPath);
          await expectLater(
            log.appendAndFlushEvidence(
              const PipelineEvent(
                timestampMs: 4,
                stageId: 'experiment_evidence',
                eventType: 'must_not_persist',
              ),
            ),
            throwsStateError,
          );
          expect(await File(jsonlPath).exists(), isFalse);
        },
      );

      test('torn JSONL tail fails closed', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await File(
          jsonlPath,
        ).writeAsString('{"timestampMs":1,"stageId":"experiment_evidence"');

        await expectLater(
          log.readPersistedEvents(),
          throwsA(isA<FormatException>()),
        );
      });

      test(
        'same run and scene claim once before concurrent provider dispatch',
        () async {
          log = PipelineEventLogImpl(jsonlPath: jsonlPath);
          await log.prepareEvidencePersistence();
          final barrier = Completer<void>();
          var providerCalls = 0;

          Future<Object?> openThenDispatch() async {
            await barrier.future;
            try {
              await log.openStoryGenerationEvidenceJournal(
                evidenceRunId: 'atomic-claim-run-v1',
                sceneId: 'scene-1',
                preparedBriefDigest: _digestFor(50),
                generationArmPolicy: 'arm-a-v1',
              );
              providerCalls += 1;
              return null;
            } on Object catch (error) {
              return error;
            }
          }

          final results = <Future<Object?>>[
            openThenDispatch(),
            openThenDispatch(),
          ];
          barrier.complete();
          final settled = await Future.wait(results);

          expect(providerCalls, 1);
          expect(settled.where((result) => result == null), hasLength(1));
          expect(
            settled.whereType<StoryGenerationEvidenceIntegrityFailure>(),
            hasLength(1),
          );
          final persisted = await log.readPersistedEvents();
          expect(persisted, hasLength(1));
          expect(
            persisted.single.eventType,
            storyGenerationEvidenceJournalClaimRecordedEventType,
          );
        },
      );

      test('different scene identities may claim the shared sink', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();
        await Future.wait([
          log.openStoryGenerationEvidenceJournal(
            evidenceRunId: 'parallel-scene-claim-run-v1',
            sceneId: 'scene-1',
            preparedBriefDigest: _digestFor(50),
            generationArmPolicy: 'arm-a-v1',
          ),
          log.openStoryGenerationEvidenceJournal(
            evidenceRunId: 'parallel-scene-claim-run-v1',
            sceneId: 'scene-2',
            preparedBriefDigest: _digestFor(51),
            generationArmPolicy: 'arm-a-v1',
          ),
        ]);

        final claims = (await log.readPersistedEvents())
            .where(
              (event) =>
                  event.eventType ==
                  storyGenerationEvidenceJournalClaimRecordedEventType,
            )
            .toList(growable: false);
        expect(claims, hasLength(2));
        expect(
          claims.map((event) => event.metadata['sceneId']).toSet(),
          <String>{'scene-1', 'scene-2'},
        );
      });

      test('durable zero-intent claim blocks replay after restart', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();
        await log.openStoryGenerationEvidenceJournal(
          evidenceRunId: 'zero-intent-recovery-run-v1',
          sceneId: 'scene-1',
          preparedBriefDigest: _digestFor(50),
          generationArmPolicy: 'arm-a-v1',
        );
        expect(
          (await log.readPersistedEvents()).single.eventType,
          storyGenerationEvidenceJournalClaimRecordedEventType,
        );
        await log.dispose();

        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();
        await expectLater(
          log.openStoryGenerationEvidenceJournal(
            evidenceRunId: 'zero-intent-recovery-run-v1',
            sceneId: 'scene-1',
            preparedBriefDigest: _digestFor(50),
            generationArmPolicy: 'arm-a-v1',
          ),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
        );
        final persisted = await log.readPersistedEvents();
        expect(persisted.map((event) => event.eventType), <String>[
          storyGenerationEvidenceJournalClaimRecordedEventType,
          storyGenerationEvidenceInvalidatedEventType,
        ]);
        expect(
          (persisted.last.metadata['private'] as Map)['reason'],
          'unfinished_journal_recovered',
        );
        expect(
          persisted.where(
            (event) =>
                event.eventType ==
                storyGenerationAttemptIntentRecordedEventType,
          ),
          isEmpty,
        );
      });

      test(
        'orphan write-ahead intent blocks restart before redispatch',
        () async {
          log = PipelineEventLogImpl(jsonlPath: jsonlPath);
          await log.prepareEvidencePersistence();
          final first = await log.openStoryGenerationEvidenceJournal(
            evidenceRunId: 'orphan-recovery-run-v1',
            sceneId: 'scene-1',
            preparedBriefDigest: _digestFor(50),
            generationArmPolicy: 'arm-a-v1',
          );
          await first.persistIntent(
            _intent(
              evidenceRunId: 'orphan-recovery-run-v1',
              logicalAttemptId: _digestFor(1),
            ),
          );
          await log.dispose();

          log = PipelineEventLogImpl(jsonlPath: jsonlPath);
          await log.prepareEvidencePersistence();
          await expectLater(
            log.openStoryGenerationEvidenceJournal(
              evidenceRunId: 'orphan-recovery-run-v1',
              sceneId: 'scene-1',
              preparedBriefDigest: _digestFor(50),
              generationArmPolicy: 'arm-a-v1',
            ),
            throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
          );
          expect(
            (await log.readPersistedEvents()).where(
              (event) =>
                  event.eventType ==
                  storyGenerationEvidenceInvalidatedEventType,
            ),
            hasLength(1),
          );
        },
      );

      test(
        'exact prose bytes issue authority bound to the persisted terminal envelope',
        () async {
          log = PipelineEventLogImpl(jsonlPath: jsonlPath);
          await log.prepareEvidencePersistence();

          for (final source in <({String callSiteId, int seed, String text})>[
            (
              callSiteId: 'scene-editorial-generator',
              seed: 301,
              text: '编辑正文\n保留原始换行',
            ),
            (callSiteId: 'language-polish', seed: 302, text: '润色正文\n保留原始换行'),
          ]) {
            final runId = 'source-seal-positive-${source.seed}';
            final journal = await log.openStoryGenerationEvidenceJournal(
              evidenceRunId: runId,
              sceneId: 'scene-1',
              preparedBriefDigest: _digestFor(50),
              generationArmPolicy: 'arm-a-v1',
            );
            final attempt = await _sourceAttempt(
              journal: journal,
              logicalAttemptId: _digestFor(source.seed),
              callSiteId: source.callSiteId,
              artifactText: source.text,
            );
            final logicalId = attempt.logicalAttemptId!;
            final sealed = await journal.sealArtifact(
              stageId: 'polish_candidate_before_gates',
              artifactText: source.text,
              sourceLogicalAttemptId: logicalId,
              sourceCallSiteId: source.callSiteId,
            );
            final envelope = StoryGenerationAttemptEvidenceEnvelope(
              attempts: <StoryGenerationAttemptEvidence>[attempt],
            );

            expect(
              await journal.persistAndVerifyEnvelope(
                envelope: envelope,
                completed: true,
                finalArtifactDigest: sealed,
              ),
              isTrue,
            );
            final authority = journal.issueReceiptAuthority(
              sealedArtifactDigest: sealed,
            );
            final tamperedEnvelope = StoryGenerationAttemptEvidenceEnvelope(
              attempts: <StoryGenerationAttemptEvidence>[
                _tamperedSourceAttempt(attempt),
              ],
            );
            expect(
              authority.consumeForReceipt(
                evidenceRunId: runId,
                sceneId: 'scene-1',
                generationArmPolicy: 'arm-a-v1',
                preparedBriefDigest: _digestFor(50),
                intents: journal.verifiedAdmissionOrderedIntents,
                envelope: tamperedEnvelope,
                sealedArtifactDigest: sealed,
              ),
              isFalse,
              reason:
                  'post-terminal callsite/model/fingerprint mutation must not consume authority',
            );
            expect(
              authority.consumeForReceipt(
                evidenceRunId: runId,
                sceneId: 'scene-1',
                generationArmPolicy: 'arm-a-v1',
                preparedBriefDigest: _digestFor(50),
                intents: journal.verifiedAdmissionOrderedIntents,
                envelope: envelope,
                sealedArtifactDigest: sealed,
              ),
              isFalse,
              reason: 'a mismatched presentation burns the one-shot authority',
            );
          }
        },
      );

      test(
        'wrong source id, failed source, and byte substitution reject authority',
        () async {
          log = PipelineEventLogImpl(jsonlPath: jsonlPath);
          await log.prepareEvidencePersistence();

          Future<void> expectRejected({
            required String runId,
            required String sourceSeed,
            required String? artifactText,
            required String sealText,
            bool useWrongSourceId = false,
          }) async {
            final journal = await log.openStoryGenerationEvidenceJournal(
              evidenceRunId: runId,
              sceneId: 'scene-1',
              preparedBriefDigest: _digestFor(50),
              generationArmPolicy: 'arm-a-v1',
            );
            final attempt = await _sourceAttempt(
              journal: journal,
              logicalAttemptId: sourceSeed,
              callSiteId: 'scene-editorial-generator',
              artifactText: artifactText,
            );
            final logicalId = attempt.logicalAttemptId!;
            final sealed = await journal.sealArtifact(
              stageId: 'polish_candidate_before_gates',
              artifactText: sealText,
              sourceLogicalAttemptId: useWrongSourceId
                  ? _digestFor(399)
                  : logicalId,
              sourceCallSiteId: 'scene-editorial-generator',
            );
            final envelope = StoryGenerationAttemptEvidenceEnvelope(
              attempts: <StoryGenerationAttemptEvidence>[attempt],
            );

            expect(
              await journal.persistAndVerifyEnvelope(
                envelope: envelope,
                completed: true,
                finalArtifactDigest: sealed,
              ),
              isFalse,
            );
            expect(
              () => journal.issueReceiptAuthority(sealedArtifactDigest: sealed),
              throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
            );
          }

          await expectRejected(
            runId: 'source-seal-wrong-id-v1',
            sourceSeed: _digestFor(311),
            artifactText: '不能冒名的正文',
            sealText: '不能冒名的正文',
            useWrongSourceId: true,
          );
          await expectRejected(
            runId: 'source-seal-failed-source-v1',
            sourceSeed: _digestFor(312),
            artifactText: null,
            sealText: '失败调用没有生成这段正文',
          );
          await expectRejected(
            runId: 'source-seal-byte-substitution-v1',
            sourceSeed: _digestFor(313),
            artifactText: '原始正文',
            sealText: '原始正文 ',
          );
        },
      );

      test('quality scorer output cannot impersonate final prose', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();
        const runId = 'source-seal-quality-impostor-v1';
        final journal = await log.openStoryGenerationEvidenceJournal(
          evidenceRunId: runId,
          sceneId: 'scene-1',
          preparedBriefDigest: _digestFor(50),
          generationArmPolicy: 'arm-a-v1',
        );
        final editorial = await _sourceAttempt(
          journal: journal,
          logicalAttemptId: _digestFor(321),
          callSiteId: 'scene-editorial-generator',
          artifactText: '真正的最终正文',
        );
        final scorer = await _sourceAttempt(
          journal: journal,
          logicalAttemptId: _digestFor(322),
          callSiteId: 'quality-scorer',
          artifactText: '综合：96\n总结：通过',
        );
        final scorerId = scorer.logicalAttemptId!;

        expect(
          () => journal.sealArtifact(
            stageId: 'polish_candidate_before_gates',
            artifactText: '综合：96\n总结：通过',
            sourceLogicalAttemptId: scorerId,
            sourceCallSiteId: 'quality-scorer',
          ),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
        );

        final sealed = await journal.sealArtifact(
          stageId: 'polish_candidate_before_gates',
          artifactText: '综合：96\n总结：通过',
          sourceLogicalAttemptId: scorerId,
          sourceCallSiteId: 'scene-editorial-generator',
        );
        final envelope = StoryGenerationAttemptEvidenceEnvelope(
          attempts: <StoryGenerationAttemptEvidence>[editorial, scorer],
        );
        expect(
          await journal.persistAndVerifyEnvelope(
            envelope: envelope,
            completed: true,
            finalArtifactDigest: sealed,
          ),
          isFalse,
        );
        expect(
          () => journal.issueReceiptAuthority(sealedArtifactDigest: sealed),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
        );
      });

      test('concurrent attempts reserve continuous unique sequences', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.prepareEvidencePersistence();
        final journal = await log.openStoryGenerationEvidenceJournal(
          evidenceRunId: 'concurrent-sequence-run-v1',
          sceneId: 'scene-1',
          preparedBriefDigest: _digestFor(50),
          generationArmPolicy: 'arm-a-v1',
        );
        final logicalIds = <String>[
          for (var index = 1; index <= 12; index += 1) _digestFor(index),
        ];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serverDone = server.forEach((request) async {
          await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode(<String, Object?>{
                'id': 'concurrent-source-response',
                'model': 'test-model',
                'choices': <Object?>[
                  <String, Object?>{
                    'message': <String, Object?>{'content': '并发尝试正文'},
                  },
                ],
                'usage': <String, Object?>{
                  'prompt_tokens': 20,
                  'completion_tokens': 10,
                  'total_tokens': 30,
                },
              }),
            );
          await request.response.close();
        });
        final store = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: createDefaultAppLlmClient(),
        );
        await store.save(
          providerName: 'Local Test',
          baseUrl: 'http://${server.address.host}:${server.port}/v1',
          model: 'test-model',
          apiKey: '',
          timeout: const AppLlmTimeoutConfig.uniform(2000),
          maxTokens: 4096,
        );
        late final List<StoryGenerationAttemptEvidence> outcomes;
        try {
          outcomes = await Future.wait(<Future<StoryGenerationAttemptEvidence>>[
            for (var index = 0; index < logicalIds.length; index += 1)
              _sourceAttemptWithStore(
                journal: journal,
                store: store,
                logicalAttemptId: logicalIds[index],
                callSiteId: 'scene-editorial-generator',
              ),
          ]);
        } finally {
          store.dispose();
          await server.close(force: true);
          await serverDone;
        }

        final persisted = await log.readPersistedEvents();
        final intents = persisted.where(
          (event) =>
              event.eventType == storyGenerationAttemptIntentRecordedEventType,
        );
        final attempts = persisted
            .where(
              (event) =>
                  event.eventType ==
                  storyGenerationAttemptEvidenceRecordedEventType,
            )
            .toList(growable: false);
        expect(
          intents.map(
            (event) => (event.metadata['private'] as Map)['sequenceNo'],
          ),
          List<int>.generate(logicalIds.length, (index) => index),
        );
        expect(
          attempts.map(
            (event) => (event.metadata['private'] as Map)['sequenceNo'],
          ),
          List<int>.generate(logicalIds.length, (index) => index),
        );
        await journal.sealArtifact(
          stageId: 'polish_candidate_before_gates',
          artifactText: '并发尝试正文',
          sourceLogicalAttemptId: outcomes.first.logicalAttemptId!,
          sourceCallSiteId: 'scene-editorial-generator',
        );
        final outcomeByLogicalId = <String, StoryGenerationAttemptEvidence>{
          for (final outcome in outcomes) outcome.logicalAttemptId!: outcome,
        };
        final admissionOrderedOutcomes = <StoryGenerationAttemptEvidence>[
          for (final event in attempts)
            outcomeByLogicalId[(event.metadata['private']
                    as Map)['logicalAttemptId']!
                as String]!,
        ];
        expect(
          await journal.persistAndVerifyEnvelope(
            envelope: StoryGenerationAttemptEvidenceEnvelope(
              attempts: admissionOrderedOutcomes,
            ),
            completed: false,
            finalArtifactDigest: null,
          ),
          isFalse,
        );
        await expectLater(
          journal.persistIntent(
            _intent(
              evidenceRunId: 'concurrent-sequence-run-v1',
              logicalAttemptId: _digestFor(99),
            ),
          ),
          throwsA(isA<StoryGenerationEvidenceIntegrityFailure>()),
        );
      });

      test('flush is idempotent', () async {
        log = PipelineEventLogImpl(jsonlPath: jsonlPath);
        await log.flush();
        await log.flush();
      });
    });
  });
}

String _digestFor(int value) =>
    'sha256:${value.toRadixString(16).padLeft(64, '0')}';

StoryGenerationAttemptIntent _intent({
  required String evidenceRunId,
  required String logicalAttemptId,
  String stageId = 'director',
  String callSiteId = 'scene-director',
}) => StoryGenerationAttemptIntent(
  evidenceRunId: evidenceRunId,
  sceneId: 'scene-1',
  preparedBriefDigest: _digestFor(50),
  logicalAttemptId: logicalAttemptId,
  attempt: 0,
  maxTokens: 4096,
  transientRetryCount: 0,
  outputRetryCount: 0,
  stageId: stageId,
  callSiteId: callSiteId,
  variantId: 'current',
  generationBundleHash: _digestFor(100),
  promptReleaseRef: <String, Object?>{'contentHash': _digestFor(101)},
  promptReleaseContentHash: _digestFor(101),
  renderedMessagesDigest: _digestFor(102),
  resolvedVariablesDigest: _digestFor(103),
  rendererContractHash: _digestFor(104),
  selectedRouteBindingHash: _selectedRouteBindingHash,
  generationArmPolicy: 'arm-a-v1',
  retryContractHash: _digestFor(106),
  evaluationPhase: null,
);

Future<StoryGenerationAttemptEvidence> _sourceAttempt({
  required PipelineStoryGenerationEvidenceJournal journal,
  required String logicalAttemptId,
  required String callSiteId,
  required String? artifactText,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.host}:${server.port}/v1';
  final serverDone = server.forEach((request) async {
    await utf8.decoder.bind(request).join();
    request.response
      ..statusCode = artifactText == null
          ? HttpStatus.internalServerError
          : HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode(
          artifactText == null
              ? <String, Object?>{
                  'error': <String, Object?>{'message': 'injected failure'},
                }
              : <String, Object?>{
                  'id': 'private-response-source',
                  'model': 'test-model',
                  'choices': <Object?>[
                    <String, Object?>{
                      'message': <String, Object?>{'content': artifactText},
                    },
                  ],
                  'usage': <String, Object?>{
                    'prompt_tokens': 20,
                    'completion_tokens': 10,
                    'total_tokens': 30,
                  },
                },
        ),
      );
    await request.response.close();
  });
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: createDefaultAppLlmClient(),
  );
  await store.save(
    providerName: 'Local Test',
    baseUrl: baseUrl,
    model: 'test-model',
    apiKey: '',
    timeout: const AppLlmTimeoutConfig.uniform(1000),
    maxTokens: 4096,
  );
  try {
    return await _sourceAttemptWithStore(
      journal: journal,
      store: store,
      logicalAttemptId: logicalAttemptId,
      callSiteId: callSiteId,
    );
  } finally {
    store.dispose();
    await server.close(force: true);
    await serverDone;
  }
}

Future<StoryGenerationAttemptEvidence> _sourceAttemptWithStore({
  required PipelineStoryGenerationEvidenceJournal journal,
  required AppSettingsStore store,
  required String logicalAttemptId,
  required String callSiteId,
}) async {
  final stageId = callSiteId == 'language-polish'
      ? 'polish'
      : callSiteId == 'quality-scorer'
      ? 'quality-gate'
      : callSiteId == 'scene-director'
      ? 'director'
      : 'editorial';
  final invocation = StoryPromptRegistry.production.invocation(
    stageId: stageId,
    callSiteId: callSiteId,
  );
  final variables = _sourcePromptVariables(
    invocation.release,
    seed: logicalAttemptId,
  );
  final messages = invocation.render(variables).messages;
  final invocationEvidence = invocation.evidence(
    messages,
    resolvedVariables: variables,
  );
  final capture = StoryGenerationAttemptEvidenceCapture();
  await StoryGenerationRetryScope.run(
    policy: const StoryGenerationRetryPolicy.experimentNoContentRedraw(
      maxTotalAttempts: 1,
    ),
    onAttemptEvidence: capture.record,
    persistAttemptIntent: journal.persistIntent,
    persistAttemptEvidence: journal.persistAttempt,
    generationArmPolicy: journal.generationArmPolicy,
    evidenceRunId: journal.evidenceRunId,
    evidenceSceneId: journal.sceneId,
    preparedBriefDigest: journal.preparedBriefDigest,
    body: () => requestFormalStoryGenerationPassWithRetry(
      settingsStore: store,
      messages: messages,
      initialMaxTokens: 4096,
      maxEscalatedTokens: 4096,
      maxTransientRetries: 0,
      maxOutputRetries: 0,
      traceName: 'pipeline-source-seal-test',
      promptInvocation: invocation,
      promptInvocationEvidence: invocationEvidence,
    ),
  );
  return capture.attempts.single;
}

Map<String, Object?> _sourcePromptVariables(
  PromptRelease release, {
  required String seed,
}) {
  final schema = release.variablesSchemaSnapshot as Map<String, Object?>;
  final properties = schema['properties']! as Map<String, Object?>;
  return <String, Object?>{
    for (final entry in properties.entries)
      entry.key: switch ((entry.value as Map<String, Object?>)['type']) {
        'string' => 'source-fixture:${entry.key}:$seed',
        'integer' => 1,
        'number' => 1.0,
        'boolean' => true,
        _ => throw StateError('unsupported source fixture: ${entry.key}'),
      },
  };
}

StoryGenerationAttemptEvidence _tamperedSourceAttempt(
  StoryGenerationAttemptEvidence source,
) => StoryGenerationAttemptEvidence(
  attempt: source.attempt,
  maxTokens: source.maxTokens,
  transientRetryCount: source.transientRetryCount,
  outputRetryCount: source.outputRetryCount,
  succeeded: source.succeeded,
  failureKind: source.failureKind,
  statusCode: source.statusCode,
  providerModel: 'tampered-model',
  providerResponseId: source.providerResponseId,
  promptTokens: source.promptTokens,
  completionTokens: source.completionTokens,
  totalTokens: source.totalTokens,
  responseDigest: source.responseDigest,
  disposition: source.disposition,
  stageId: source.stageId,
  callSiteId: 'judge',
  variantId: source.variantId,
  preparedBriefDigest: source.preparedBriefDigest,
  logicalAttemptId: source.logicalAttemptId,
  generationBundleHash: source.generationBundleHash,
  promptReleaseRef: source.promptReleaseRef,
  promptReleaseContentHash: source.promptReleaseContentHash,
  renderedMessagesDigest: source.renderedMessagesDigest,
  resolvedVariablesDigest: source.resolvedVariablesDigest,
  rendererContractHash: source.rendererContractHash,
  selectedRouteBindingHash: source.selectedRouteBindingHash,
  selectedRouteBinding: source.selectedRouteBinding,
  observedDispatchResolutionHash: source.observedDispatchResolutionHash,
  observedDispatchResolution: source.observedDispatchResolution,
  routeResolutionRequired: source.routeResolutionRequired,
  routeResolutionVerified: source.routeResolutionVerified,
  providerBoundaryReceiptHash: source.providerBoundaryReceiptHash,
  providerBoundaryReceipt: source.providerBoundaryReceipt,
  providerBoundaryPhysicalDispatchCount:
      source.providerBoundaryPhysicalDispatchCount,
  providerBoundaryReceiptRequired: source.providerBoundaryReceiptRequired,
  providerBoundaryReceiptVerified: source.providerBoundaryReceiptVerified,
  dispatchFailureDisposition: source.dispatchFailureDisposition,
  artifactDigest: source.artifactDigest,
  generationFingerprint: GenerationFingerprint(
    semanticInput: const <String, Object?>{'tampered': true},
    generationBundleHash: source.generationBundleHash!,
    modelRoute: _digestFor(107),
    decodingParameters: const <String, Object?>{'maxTokens': 4096},
    armPolicy: 'arm-a-v1',
    retryPolicy: _digestFor(106),
  ),
  evaluationFingerprint: source.evaluationFingerprint,
  evaluationFingerprintRequired: source.evaluationFingerprintRequired,
);

final Map<String, Object?> _selectedEndpoint = <String, Object?>{
  'contract': 'app-llm-dispatch-resolution-v1',
  'endpointId': 'test-endpoint',
  'baseUrl': 'http://localhost:11434/v1',
  'model': 'test-model',
  'provider': 'openaiCompatible',
  'isLocal': true,
  'physicalDispatchPolicy': 'single',
};

final Map<String, Object?> _selectedRouteBinding = <String, Object?>{
  'contract': 'story-generation-single-physical-dispatch-route-v1',
  'traceName': 'pipeline-event-log-test',
  'physicalDispatchPolicy': 'single',
  'cachePolicy': 'bypass-read-write',
  'streamFallback': false,
  'gatewayRetries': 0,
  'providerFailover': false,
  'reconnectProbe': false,
  'selectedEndpoint': _selectedEndpoint,
};

final String _selectedRouteBindingHash = AppLlmCanonicalHash.domainHash(
  'story-generation-configured-model-route-v1',
  _selectedRouteBinding,
);
