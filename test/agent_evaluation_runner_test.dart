import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_call_trace.dart';
import 'package:novel_writer/app/llm/app_llm_response_cache.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_cache_receipt_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_side_effects.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trace_context.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_typed_evidence.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/outcome_evaluation.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/pass3_evaluation.dart';

void main() {
  late Directory tempDirectory;
  late String productionDatabasePath;
  late Database authorityDb;
  late AgentEvaluationFixtureSandbox fixtureSandbox;
  late AgentEvaluationRunner runner;
  late ExperimentManifest manifest;
  late AgentEvaluationCancellationToken cancellation;
  var clock = 100;

  setUp(() {
    tempDirectory = Directory.systemTemp.createTempSync('agent-runner-');
    final authorityPath = '${tempDirectory.path}/authority.sqlite';
    final fixturePath = '${tempDirectory.path}/fixture.sqlite';
    productionDatabasePath = '${tempDirectory.path}/production.sqlite';
    authorityDb = sqlite3.open(authorityPath);
    authorityDb.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(authorityDb);
    _seedBundles(authorityDb);
    final fixture = sqlite3.open(fixturePath);
    fixture.execute('CREATE TABLE trial_state (value TEXT NOT NULL)');
    fixture.dispose();
    sqlite3.open(productionDatabasePath).dispose();
    fixtureSandbox = AgentEvaluationFixtureSandbox.create(
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionDatabasePath,
      temporaryParent: tempDirectory,
    );
    runner = AgentEvaluationRunner(
      manifestStore: AgentEvaluationManifestStore(db: authorityDb),
      ledger: AgentEvaluationLedger(db: authorityDb),
      fixtureSandbox: fixtureSandbox,
      nowMs: () => clock++,
    );
    manifest = _manifest();
    cancellation = AgentEvaluationCancellationToken();
  });

  tearDown(() {
    fixtureSandbox.dispose();
    authorityDb.dispose();
    tempDirectory.deleteSync(recursive: true);
  });

  test('production side-effect contract is release-bound', () {
    expect(
      AgentEvaluationProductionSideEffectKeys.supportedList,
      const <String>[
        AgentEvaluationProductionSideEffectKeys.commitReceipt,
        AgentEvaluationProductionSideEffectKeys.outbox,
        AgentEvaluationProductionSideEffectKeys.authoritativeWrite,
      ],
    );
    expect(
      AgentEvaluationProductionSideEffectKeys.supported,
      AgentEvaluationProductionSideEffectKeys.supportedList.toSet(),
    );
    expect(
      AgentEvaluationManifestStore.releaseDomain,
      'agent-evaluation-manifest-store-release-v2',
    );
    expect(
      AgentEvaluationManifestStore.releaseHash,
      matches(RegExp(r'^sha256:[a-f0-9]{64}$')),
    );
    expect(
      AgentEvaluationFixtureSandbox.releaseDomain,
      'eval-fixture-sandbox-release-v7',
    );
    expect(
      AgentEvaluationFixtureSandbox.releaseHash,
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
  });

  test(
    'correct blocked outcome passes Pass3 with progress and no state leak',
    () async {
      final initialCounts = <int>[];
      final progress = <AgentEvaluationProgress>[];

      final report = await _run(
        runner,
        manifest,
        cancellation,
        onProgress: progress.add,
        executor: (context) async {
          expect(
            AgentEvaluationTraceContext.current?.trialSlotId,
            context.lease.trialSlotId,
          );
          final count =
              context.database
                      .select('SELECT COUNT(*) AS count FROM trial_state')
                      .single['count']
                  as int;
          initialCounts.add(count);
          context.database.execute(
            "INSERT INTO trial_state(value) VALUES ('${context.lease.trialSlotId}')",
          );
          context.reportStage('story-pipeline');
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent: 'blocked:${context.lease.trialSlotId}',
          );
        },
      );

      expect(initialCounts, <int>[0, 0, 0]);
      expect(report.cellPass3.single.passed, isTrue);
      expect(report.scenarioPass3.values.single, isTrue);
      expect(progress.any((event) => event.stage == 'story-pipeline'), isTrue);
      expect(
        progress.where((event) => event.latestStatus == 'pass'),
        hasLength(3),
      );
    },
  );

  test('wrongly accepted blocked scenario seals every trial as fail', () async {
    final report = await _run(
      runner,
      manifest,
      cancellation,
      executor: (context) async => AgentEvaluationTrialExecutionResult(
        outcome: const ActualTrialOutcome(
          terminalState: TrialTerminalState.accepted,
          accepted: true,
          evidenceComplete: true,
        ),
        evaluatedContent: 'accepted:${context.lease.trialSlotId}',
      ),
    );

    expect(report.cellPass3.single.passed, isFalse);
    expect(report.cellPass3.single.trialResults.values, everyElement('fail'));
  });

  test(
    'runner observes canonical authoritative writes outside the sandbox',
    () async {
      expect(
        File(productionDatabasePath).absolute.path,
        isNot(startsWith('${fixtureSandbox.sandboxPath}/')),
      );
      final production = sqlite3.open(productionDatabasePath);
      production.execute(
        'CREATE TABLE draft_documents (id INTEGER PRIMARY KEY)',
      );
      production.execute('INSERT INTO draft_documents (id) VALUES (1)');
      production.dispose();
      expect(
        fixtureSandbox
            .readProductionSideEffectCounts()[AgentEvaluationProductionSideEffectKeys
            .authoritativeWrite],
        1,
      );

      final sentinelManifest = _manifest(
        experimentId: 'experiment-production-side-effect-sentinel',
        forbiddenSideEffects: const <String>[
          AgentEvaluationProductionSideEffectKeys.authoritativeWrite,
        ],
      );
      final report = await _run(
        runner,
        sentinelManifest,
        cancellation,
        executor: (context) async => AgentEvaluationTrialExecutionResult(
          outcome: const ActualTrialOutcome(
            terminalState: TrialTerminalState.blocked,
            failureCodes: <String>{'budget.exceeded'},
            accepted: false,
            evidenceComplete: true,
          ),
          evaluatedContent: 'sentinel:${context.lease.trialSlotId}',
        ),
      );

      expect(report.cellPass3.single.passed, isFalse);
      expect(report.cellPass3.single.trialResults.values, everyElement('fail'));
      expect(report.scenarioPass3.values.single, isFalse);
      final observations = authorityDb.select(
        '''SELECT value_json FROM eval_observations
           WHERE stage_id = 'outcome' AND kind = 'comparison'
           ORDER BY observation_id''',
      );
      expect(observations, hasLength(3));
      for (final row in observations) {
        final value =
            jsonDecode(row['value_json'] as String) as Map<String, Object?>;
        expect(
          (value['sideEffectCounts']!
              as Map<String, Object?>)[AgentEvaluationProductionSideEffectKeys
              .authoritativeWrite],
          1,
        );
        expect(
          value['violations'],
          contains(OutcomeViolation.forbiddenSideEffect.name),
        );
      }
    },
  );

  test('attempt trace sink rejects a foreign formal identity', () async {
    var checked = false;
    await _run(
      runner,
      manifest,
      cancellation,
      executor: (context) async {
        final sink = AgentEvaluationAttemptTraceSink()..beginAttempt(context);
        await expectLater(
          sink.record(
            AppLlmCallTraceEntry(
              timestampMs: 1,
              traceName: 'foreign',
              model: 'model',
              host: 'provider.invalid',
              messageCount: 1,
              maxTokens: 1,
              succeeded: true,
              latencyMs: 1,
              promptTokens: 1,
              completionTokens: 1,
              totalTokens: 2,
              estimatedPromptTokens: 1,
              estimatedCompletionTokens: 1,
              promptChars: 1,
              completionChars: 1,
              metadata: <String, Object?>{
                ...AgentEvaluationTraceContext.current!.toTraceMetadata(),
                'runId': 'foreign-run',
              },
            ),
          ),
          throwsStateError,
        );
        sink.abortAttempt();
        checked = true;
        return AgentEvaluationTrialExecutionResult(
          outcome: const ActualTrialOutcome(
            terminalState: TrialTerminalState.blocked,
            failureCodes: <String>{'budget.exceeded'},
            accepted: false,
            evidenceComplete: true,
          ),
          evaluatedContent: 'blocked:${context.lease.trialSlotId}',
        );
      },
    );
    expect(checked, isTrue);
  });

  test('production evidence cannot be enabled without strict gate mode', () {
    expect(
      () => runner.run(
        manifest: manifest,
        executionId: 'production-without-gate',
        workerId: 'worker-1',
        actualBuildArtifactHash: manifest.buildArtifactHash,
        verifierExists: (_) => true,
        trialExecutor: (_) async => throw StateError('must not execute'),
        cancellationToken: cancellation,
        onProgress: (_) {},
        requireProductionEvidence: true,
      ),
      throwsA(isA<AgentEvaluationManifestException>()),
    );
  });

  test(
    'release evidence mode writes usage and six dimensions before seal',
    () async {
      final report = await _run(
        runner,
        manifest,
        cancellation,
        requireGateEvidence: true,
        executor: (context) async {
          final evaluatedContent = 'evaluated:${context.lease.trialSlotId}';
          final evaluatedContentHash = AgentEvaluationHashes.domainHash(
            'eval-trial-content-v1',
            evaluatedContent,
          );
          final scores = <String, int>{
            for (final dimension in AgentEvaluationQualityDimensions.values)
              dimension: 96000000,
          };
          final judgeOutputHash = _digest('8');
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent: evaluatedContent,
            usage: AgentEvaluationAttemptUsage(
              promptTokens: 100,
              completionTokens: 50,
              costMicrousd: 25,
            ),
            qualityEvidence: AgentEvaluationQualityEvidence(
              scoreMicrosByDimension: scores,
              judgePromptReleaseHash: _digest('4'),
              judgeModelRouteHash: _digest('5'),
              rubricReleaseHash: _digest('1'),
              aggregatorReleaseHash: _digest('2'),
              evaluatedContentHash: evaluatedContentHash,
              externalJudgeOutputHash: judgeOutputHash,
              externalEvaluationEvidenceHash:
                  AgentEvaluationQualityEvidence.calculateExternalEvidenceHash(
                    scoreMicrosByDimension: scores,
                    judgePromptReleaseHash: _digest('4'),
                    judgeModelRouteHash: _digest('5'),
                    rubricReleaseHash: _digest('1'),
                    aggregatorReleaseHash: _digest('2'),
                    evaluatedContentHash: evaluatedContentHash,
                    externalJudgeOutputHash: judgeOutputHash,
                  ),
            ),
            hardGateEvidence: AgentEvaluationHardGateEvidence(
              safetyPassed: true,
              transactionPassed: true,
              safetyVerifierReleaseHash: _digest('6'),
              transactionVerifierReleaseHash: _digest('7'),
              safetyEvidenceHash: _digest('9'),
              transactionEvidenceHash: _digest('a'),
            ),
          );
        },
      );

      expect(report.cellPass3.single.passed, isTrue);
      expect(
        authorityDb.select(
          "SELECT * FROM eval_observations WHERE stage_id = 'performance'",
        ),
        hasLength(3),
      );
      expect(
        authorityDb.select(
          "SELECT * FROM eval_observations WHERE stage_id = 'quality'",
        ),
        hasLength(18),
      );
      expect(
        authorityDb.select(
          "SELECT * FROM eval_observations WHERE stage_id = 'hard-gate'",
        ),
        hasLength(6),
      );
    },
  );

  test('release evidence mode refuses to seal caller-only outcomes', () async {
    await expectLater(
      _run(
        runner,
        manifest,
        cancellation,
        requireGateEvidence: true,
        executor: (context) async => AgentEvaluationTrialExecutionResult(
          outcome: const ActualTrialOutcome(
            terminalState: TrialTerminalState.blocked,
            failureCodes: <String>{'budget.exceeded'},
            accepted: false,
            evidenceComplete: true,
          ),
          evaluatedContent: 'unevaluated:${context.lease.trialSlotId}',
        ),
      ),
      throwsA(
        isA<AgentEvaluationManifestException>().having(
          (error) => error.message,
          'message',
          contains('typed usage evidence'),
        ),
      ),
    );
    expect(
      authorityDb.select(
        "SELECT * FROM eval_trial_slots WHERE status = 'sealed'",
      ),
      isEmpty,
    );
  });

  test(
    'failed evidence validation leaves the same attempt reclaimable',
    () async {
      var omitEvidence = true;
      Future<AgentEvaluationTrialExecutionResult> executor(
        AgentEvaluationTrialContext context,
      ) async {
        if (omitEvidence) {
          omitEvidence = false;
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent: 'evaluated:${context.lease.trialSlotId}',
          );
        }
        return _releaseEvidence(context);
      }

      await expectLater(
        _run(
          runner,
          manifest,
          cancellation,
          requireGateEvidence: true,
          executor: executor,
        ),
        throwsA(isA<AgentEvaluationManifestException>()),
      );
      final interruptedAttempt = authorityDb
          .select('SELECT * FROM eval_trial_attempts')
          .single;
      expect(interruptedAttempt['attempt_no'], 1);
      expect(interruptedAttempt['status'], 'started');
      expect(interruptedAttempt['finished_at_ms'], isNull);

      final resumed = await _run(
        runner,
        manifest,
        cancellation,
        requireGateEvidence: true,
        executor: executor,
      );

      expect(resumed.cellPass3.single.passed, isTrue);
      expect(
        authorityDb.select(
          "SELECT status FROM eval_trial_attempts WHERE status <> 'completed'",
        ),
        isEmpty,
      );
      expect(
        authorityDb
            .select('SELECT DISTINCT attempt_no FROM eval_trial_attempts')
            .map((row) => row['attempt_no']),
        <Object?>[1],
      );
    },
  );

  test(
    'resume skips terminal transport evidence and reclaims started content',
    () async {
      var call = 0;
      Future<AgentEvaluationTrialExecutionResult> executor(
        AgentEvaluationTrialContext context,
      ) async {
        call += 1;
        if (call == 1) {
          throw AgentEvaluationTransportException(
            'retryable transport failure',
            usage: AgentEvaluationAttemptUsage(
              promptTokens: 1,
              completionTokens: 0,
              costMicrousd: 1,
            ),
          );
        }
        if (call == 2) {
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent: 'evaluated:${context.lease.trialSlotId}',
          );
        }
        return _releaseEvidence(context);
      }

      await expectLater(
        _run(
          runner,
          manifest,
          cancellation,
          requireGateEvidence: true,
          executor: executor,
        ),
        throwsA(isA<AgentEvaluationManifestException>()),
      );
      final interrupted = authorityDb.select(
        '''SELECT trial_slot_id, attempt_no, kind, status FROM eval_trial_attempts
           ORDER BY attempt_no''',
      );
      expect(interrupted, hasLength(2));
      expect(interrupted.first['kind'], 'transport');
      expect(interrupted.first['status'], 'failed');
      expect(interrupted.last['attempt_no'], 2);
      expect(interrupted.last['status'], 'started');

      final resumed = await _run(
        runner,
        manifest,
        cancellation,
        requireGateEvidence: true,
        executor: executor,
      );

      expect(resumed.cellPass3.single.passed, isTrue);
      final firstSlotAttempts = authorityDb.select(
        '''SELECT attempt_no, kind, status FROM eval_trial_attempts
           WHERE trial_slot_id = ? ORDER BY attempt_no''',
        <Object?>[interrupted.first['trial_slot_id']],
      );
      expect(firstSlotAttempts, hasLength(2));
      expect(firstSlotAttempts.last['attempt_no'], 2);
      expect(firstSlotAttempts.last['status'], 'completed');
    },
  );

  test('three pass slots with repeated content cannot obtain Pass3', () async {
    final report = await _run(
      runner,
      manifest,
      cancellation,
      executor: (_) async => const AgentEvaluationTrialExecutionResult(
        outcome: ActualTrialOutcome(
          terminalState: TrialTerminalState.blocked,
          failureCodes: <String>{'budget.exceeded'},
          accepted: false,
          evidenceComplete: true,
        ),
        evaluatedContent: 'identical cached trajectory',
      ),
    );

    expect(report.cellPass3.single.trialResults.values, everyElement('pass'));
    expect(report.cellPass3.single.passed, isFalse);
    expect(
      report.cellPass3.single.failureReasons,
      contains(Pass3Failure.reusedContent),
    );
  });

  test(
    'formal cache prevents cross-slot provenance at the key boundary',
    () async {
      final cache = AppLlmResponseCache(delegate: _StaticCacheClient());
      final report = await _run(
        runner,
        manifest,
        cancellation,
        executor: (context) async {
          cache.beginEvaluationScope(
            AppLlmCacheEvaluationScope(
              executionId: context.lease.executionId,
              trialSlotId: context.lease.trialSlotId,
              attemptNo: context.attemptNo,
              runId: context.runId,
              generationBundleHash:
                  'sha256:${context.cell.generationBundleHash}',
              modelRouteHash: context.cell.modelRouteHash,
              decodingConfigHash: context.cell.decodingConfigHash,
              outputSchemaHash: 'runner-cache-output-schema-v1',
              promptReleaseHash: 'runner-cache-prompt-release-v1',
            ),
          );
          final request = AppLlmChatRequest(
            baseUrl: 'https://cache-provenance.test',
            apiKey: 'test-credential',
            model: 'test-model',
            messages: const <AppLlmChatMessage>[
              AppLlmChatMessage(role: 'user', content: 'same frozen request'),
            ],
            formalCacheIdentity: AppLlmFormalCacheRequestIdentity(
              stageId: 'runner-cache-provenance',
              generationBundleHash:
                  'sha256:${context.cell.generationBundleHash}',
              parserRelease: 'runner-cache-parser-v1',
            ),
          );
          await cache.chat(request);
          final receiptStore = AgentEvaluationCacheReceiptStore(
            db: authorityDb,
          );
          for (final receipt in cache.finishEvaluationScope()) {
            receiptStore.append(receipt);
          }
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent: 'trajectory:${context.lease.trialSlotId}',
          );
        },
      );

      expect(report.cellPass3.single.passed, isTrue);
      expect(
        report.cellPass3.single.failureReasons,
        isNot(contains(Pass3Failure.nonIndependent)),
      );
      final receipts = authorityDb.select(
        '''SELECT disposition, source_trial_slot_id, current_trial_slot_id
      FROM eval_cache_receipts ORDER BY rowid''',
      );
      expect(receipts, hasLength(3));
      expect(receipts.every((row) => row['disposition'] == 'miss'), isTrue);
      expect(
        receipts.every(
          (row) => row['source_trial_slot_id'] == row['current_trial_slot_id'],
        ),
        isTrue,
      );
    },
  );

  test(
    'transport replacement request cannot exceed frozen max attempts',
    () async {
      var calls = 0;
      final report = await _run(
        runner,
        manifest,
        cancellation,
        executor: (_) async {
          calls += 1;
          throw const AgentEvaluationTransportException(
            'provider unavailable',
            requestedReplacementAttempts: 100,
          );
        },
      );

      expect(calls, 9); // 3 frozen attempts × 3 logical slots, never 100.
      expect(report.cellPass3.single.passed, isFalse);
      expect(
        authorityDb.select(
          "SELECT * FROM eval_trial_attempts WHERE kind = 'transport'",
        ),
        hasLength(9),
      );
      expect(
        authorityDb.select(
          "SELECT * FROM eval_trial_attempts WHERE kind = 'content'",
        ),
        isEmpty,
      );
    },
  );

  test(
    'indeterminate provider completion seals insufficient without replay',
    () async {
      var calls = 0;
      final report = await _run(
        runner,
        manifest,
        cancellation,
        executor: (_) async {
          calls += 1;
          throw AgentEvaluationIndeterminateProviderCompletionException(
            'provider response cannot be proved after restart',
            usage: AgentEvaluationAttemptUsage(
              promptTokens: 100,
              completionTokens: 50,
              costMicrousd: 25,
            ),
          );
        },
      );

      expect(calls, 3, reason: 'one call per slot; no transport replay');
      expect(
        report.cellPass3.single.trialResults.values,
        everyElement('insufficientEvidence'),
      );
      expect(
        authorityDb.select(
          "SELECT * FROM eval_trial_attempts WHERE kind = 'transport'",
        ),
        hasLength(3),
      );
      expect(
        authorityDb.select(
          "SELECT * FROM eval_trial_slots WHERE result = 'insufficientEvidence'",
        ),
        hasLength(3),
      );
    },
  );

  test('cancellation and deadline stop before provider execution', () async {
    var calls = 0;
    cancellation.cancel();
    final cancelledReport = await _run(
      runner,
      manifest,
      cancellation,
      executor: (_) async {
        calls += 1;
        throw StateError('must not run');
      },
    );
    expect(cancelledReport.cancelled, isTrue);
    expect(calls, 0);

    final deadlineManifest = _manifest(experimentId: 'experiment-deadline');
    final deadlineReport = await _run(
      runner,
      deadlineManifest,
      AgentEvaluationCancellationToken(),
      executionId: 'execution-deadline',
      deadlineAtMs: 0,
      executor: (_) async {
        calls += 1;
        throw StateError('must not run');
      },
    );
    expect(deadlineReport.deadlineExceeded, isTrue);
    expect(calls, 0);
  });

  test('crash resumes the same slot and skips slots already sealed', () async {
    var shouldCrash = true;
    var calls = 0;
    String? crashedTrialSlotId;
    Future<AgentEvaluationTrialExecutionResult> executor(
      AgentEvaluationTrialContext context,
    ) async {
      calls += 1;
      if (shouldCrash) {
        shouldCrash = false;
        crashedTrialSlotId = context.lease.trialSlotId;
        context.database.execute(
          "INSERT INTO trial_state(value) VALUES ('before-crash')",
        );
        throw StateError('simulated process crash');
      }
      final trialState = context.database.select('SELECT * FROM trial_state');
      expect(
        trialState,
        context.lease.trialSlotId == crashedTrialSlotId
            ? hasLength(1)
            : isEmpty,
      );
      return AgentEvaluationTrialExecutionResult(
        outcome: const ActualTrialOutcome(
          terminalState: TrialTerminalState.blocked,
          failureCodes: <String>{'budget.exceeded'},
          accepted: false,
          evidenceComplete: true,
        ),
        evaluatedContent: 'blocked:${context.lease.trialSlotId}',
      );
    }

    await expectLater(
      _run(runner, manifest, cancellation, executor: executor),
      throwsA(isA<StateError>()),
    );
    final resumed = await _run(
      runner,
      manifest,
      cancellation,
      executor: executor,
    );
    final callsAfterResume = calls;
    final replay = await _run(
      runner,
      manifest,
      cancellation,
      executor: executor,
    );

    expect(resumed.cellPass3.single.passed, isTrue);
    expect(replay.cellPass3.single.passed, isTrue);
    expect(calls, callsAfterResume); // sealed trials are not sampled again.
  });

  test(
    'episode steps share one sandbox per trial and remain trial-isolated',
    () async {
      final episodeManifest = _episodeManifest();
      final pathsByTrial = <int, Set<String>>{};
      final initialStepOneCounts = <int>[];
      final report = await _run(
        runner,
        episodeManifest,
        cancellation,
        executionId: 'execution-episode',
        executor: (context) async {
          final databasePath =
              context.database.select('PRAGMA database_list').single['file']
                  as String;
          (pathsByTrial[context.lease.trialNo] ??= <String>{}).add(
            databasePath,
          );
          if (context.scenario.episodeStep == 1) {
            final count =
                context.database
                        .select('SELECT COUNT(*) AS count FROM trial_state')
                        .single['count']
                    as int;
            initialStepOneCounts.add(count);
            context.database.execute(
              "INSERT INTO trial_state(value) VALUES ('step-1')",
            );
          } else {
            expect(
              context.database.select('SELECT value FROM trial_state'),
              hasLength(1),
            );
          }
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent:
                'episode:${context.scenario.episodeStep}:${context.lease.trialSlotId}',
          );
        },
      );

      expect(report.cellPass3, hasLength(2));
      expect(report.cellPass3.every((cell) => cell.passed), isTrue);
      expect(initialStepOneCounts, <int>[0, 0, 0]);
      expect(pathsByTrial, hasLength(3));
      expect(pathsByTrial.values, everyElement(hasLength(1)));
      expect(
        pathsByTrial.values.map((paths) => paths.single).toSet(),
        hasLength(3),
      );
    },
  );

  test(
    'new process resumes committed episode generations and fences crash copy',
    () async {
      fixtureSandbox.dispose();
      final durableRoot = Directory('${tempDirectory.path}/durable');
      fixtureSandbox = AgentEvaluationFixtureSandbox.openOrCreate(
        executionId: 'execution-cross-process',
        fixtureDatabasePath: '${tempDirectory.path}/fixture.sqlite',
        productionDatabasePath: '${tempDirectory.path}/production.sqlite',
        durableParent: durableRoot,
      );
      final runnerA = AgentEvaluationRunner(
        manifestStore: AgentEvaluationManifestStore(db: authorityDb),
        ledger: AgentEvaluationLedger(db: authorityDb),
        fixtureSandbox: fixtureSandbox,
        nowMs: () => clock++,
      );
      final episodeManifest = _episodeManifest();
      var crashed = false;
      await expectLater(
        _run(
          runnerA,
          episodeManifest,
          cancellation,
          executionId: 'execution-cross-process',
          executor: (context) async {
            if (context.scenario.episodeStep == 1) {
              context.database.execute(
                'INSERT INTO trial_state(value) VALUES (?)',
                <Object?>['committed-step-1:${context.lease.trialNo}'],
              );
            } else {
              crashed = true;
              context.database.execute(
                "INSERT INTO trial_state(value) VALUES ('orphan-stale-write')",
              );
              throw StateError('simulated process death after stale write');
            }
            return AgentEvaluationTrialExecutionResult(
              outcome: const ActualTrialOutcome(
                terminalState: TrialTerminalState.blocked,
                failureCodes: <String>{'budget.exceeded'},
                accepted: false,
                evidenceComplete: true,
              ),
              evaluatedContent:
                  'episode-a:${context.scenario.episodeStep}:${context.lease.trialSlotId}',
            );
          },
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('simulated process death'),
          ),
        ),
      );
      expect(crashed, isTrue);
      fixtureSandbox.dispose();
      authorityDb.dispose();

      authorityDb = sqlite3.open('${tempDirectory.path}/authority.sqlite');
      authorityDb.execute('PRAGMA foreign_keys = ON');
      fixtureSandbox = AgentEvaluationFixtureSandbox.openOrCreate(
        executionId: 'execution-cross-process',
        fixtureDatabasePath: '${tempDirectory.path}/fixture.sqlite',
        productionDatabasePath: '${tempDirectory.path}/production.sqlite',
        durableParent: durableRoot,
      );
      final runnerB = AgentEvaluationRunner(
        manifestStore: AgentEvaluationManifestStore(db: authorityDb),
        ledger: AgentEvaluationLedger(db: authorityDb),
        fixtureSandbox: fixtureSandbox,
        nowMs: () => clock++,
      );
      final observed = <String>[];
      final report = await _run(
        runnerB,
        episodeManifest,
        cancellation,
        executionId: 'execution-cross-process',
        executor: (context) async {
          if (context.scenario.episodeStep == 1) {
            context.database.execute(
              'INSERT INTO trial_state(value) VALUES (?)',
              <Object?>['committed-step-1:${context.lease.trialNo}'],
            );
          } else {
            final values = context.database
                .select('SELECT value FROM trial_state ORDER BY value')
                .map((row) => row['value'] as String)
                .toList(growable: false);
            expect(values, <String>[
              'committed-step-1:${context.lease.trialNo}',
            ]);
            expect(values, isNot(contains('orphan-stale-write')));
            observed.addAll(values);
          }
          return AgentEvaluationTrialExecutionResult(
            outcome: const ActualTrialOutcome(
              terminalState: TrialTerminalState.blocked,
              failureCodes: <String>{'budget.exceeded'},
              accepted: false,
              evidenceComplete: true,
            ),
            evaluatedContent:
                'episode-b:${context.scenario.episodeStep}:${context.lease.trialSlotId}',
          );
        },
      );

      expect(report.cellPass3.every((cell) => cell.passed), isTrue);
      expect(observed, hasLength(3));
      final generations = authorityDb.select(
        '''SELECT isolation_trial_id, generation_no, database_file_hash
           FROM eval_sandbox_generations
           WHERE execution_id = 'execution-cross-process'
           ORDER BY isolation_trial_id, generation_no''',
      );
      expect(generations, hasLength(6));
      expect(
        generations.where((row) => row['generation_no'] == 2),
        hasLength(3),
      );
      expect(
        generations.every(
          (row) => RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(row['database_file_hash'] as String),
        ),
        isTrue,
      );
    },
  );

  test('long provider work renews the lease until fenced acceptance', () async {
    final realClockRunner = AgentEvaluationRunner(
      manifestStore: AgentEvaluationManifestStore(db: authorityDb),
      ledger: AgentEvaluationLedger(db: authorityDb),
      fixtureSandbox: fixtureSandbox,
    );
    final report = await _run(
      realClockRunner,
      manifest,
      cancellation,
      executionId: 'execution-heartbeat',
      leaseDurationMs: 45,
      executor: (context) async {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        final slot = authorityDb
            .select(
              '''SELECT lease_owner, lease_epoch, lease_expires_at_ms
                 FROM eval_trial_slots WHERE trial_slot_id = ?''',
              <Object?>[context.lease.trialSlotId],
            )
            .single;
        expect(slot['lease_owner'], 'worker-1');
        expect(slot['lease_epoch'], context.lease.epoch);
        expect(
          slot['lease_expires_at_ms'] as int,
          greaterThan(DateTime.now().millisecondsSinceEpoch),
        );
        return AgentEvaluationTrialExecutionResult(
          outcome: const ActualTrialOutcome(
            terminalState: TrialTerminalState.blocked,
            failureCodes: <String>{'budget.exceeded'},
            accepted: false,
            evidenceComplete: true,
          ),
          evaluatedContent: 'heartbeat:${context.lease.trialSlotId}',
        );
      },
    );
    expect(report.cellPass3.single.passed, isTrue);
  });
}

final class _StaticCacheClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async =>
      const AppLlmChatResult.success(text: 'cached response');

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

Future<AgentEvaluationRunReport> _run(
  AgentEvaluationRunner runner,
  ExperimentManifest manifest,
  AgentEvaluationCancellationToken cancellation, {
  required AgentEvaluationTrialExecutor executor,
  String executionId = 'execution-1',
  int? deadlineAtMs,
  void Function(AgentEvaluationProgress)? onProgress,
  bool requireGateEvidence = false,
  int leaseDurationMs = 60000,
}) => runner.run(
  manifest: manifest,
  executionId: executionId,
  workerId: 'worker-1',
  actualBuildArtifactHash: manifest.buildArtifactHash,
  verifierExists: (_) => true,
  trialExecutor: executor,
  cancellationToken: cancellation,
  onProgress: onProgress ?? (_) {},
  requireGateEvidence: requireGateEvidence,
  leaseDurationMs: leaseDurationMs,
  deadlineAtMs: deadlineAtMs,
);

AgentEvaluationTrialExecutionResult _releaseEvidence(
  AgentEvaluationTrialContext context,
) {
  final evaluatedContent = 'evaluated:${context.lease.trialSlotId}';
  final evaluatedContentHash = AgentEvaluationHashes.domainHash(
    'eval-trial-content-v1',
    evaluatedContent,
  );
  final scores = <String, int>{
    for (final dimension in AgentEvaluationQualityDimensions.values)
      dimension: 96000000,
  };
  final judgeOutputHash = _digest('8');
  return AgentEvaluationTrialExecutionResult(
    outcome: const ActualTrialOutcome(
      terminalState: TrialTerminalState.blocked,
      failureCodes: <String>{'budget.exceeded'},
      accepted: false,
      evidenceComplete: true,
    ),
    evaluatedContent: evaluatedContent,
    usage: AgentEvaluationAttemptUsage(
      promptTokens: 100,
      completionTokens: 50,
      costMicrousd: 25,
    ),
    qualityEvidence: AgentEvaluationQualityEvidence(
      scoreMicrosByDimension: scores,
      judgePromptReleaseHash: _digest('4'),
      judgeModelRouteHash: _digest('5'),
      rubricReleaseHash: _digest('1'),
      aggregatorReleaseHash: _digest('2'),
      evaluatedContentHash: evaluatedContentHash,
      externalJudgeOutputHash: judgeOutputHash,
      externalEvaluationEvidenceHash:
          AgentEvaluationQualityEvidence.calculateExternalEvidenceHash(
            scoreMicrosByDimension: scores,
            judgePromptReleaseHash: _digest('4'),
            judgeModelRouteHash: _digest('5'),
            rubricReleaseHash: _digest('1'),
            aggregatorReleaseHash: _digest('2'),
            evaluatedContentHash: evaluatedContentHash,
            externalJudgeOutputHash: judgeOutputHash,
          ),
    ),
    hardGateEvidence: AgentEvaluationHardGateEvidence(
      safetyPassed: true,
      transactionPassed: true,
      safetyVerifierReleaseHash: _digest('6'),
      transactionVerifierReleaseHash: _digest('7'),
      safetyEvidenceHash: _digest('9'),
      transactionEvidenceHash: _digest('a'),
    ),
  );
}

ExperimentManifest _manifest({
  String experimentId = 'experiment-1',
  List<String> forbiddenSideEffects = const <String>['authority-write'],
}) {
  final scenario = ScenarioRelease(
    scenarioId: 'blocked-budget',
    version: '1.0.0',
    difficulty: 'adversarial',
    inputFixture: const <String, Object?>{'scene': 1},
    fixtureHash: _digest('4'),
    isolationMode: 'independent',
    requiredCapabilities: const <String>['budget'],
    adversarialMutations: const <String>['budget-limit'],
    verifierReleaseRefs: const <String>['budget-verifier-v1'],
    rubricReleaseRef: 'rubric-v1',
    expectedTerminalState: 'blocked',
    requiredFailureCodes: const <String>['budget.exceeded'],
    allowedAdditionalFailureCodes: const <String>[],
    forbiddenFailureCodes: const <String>[],
    outcomeComparatorReleaseRef: 'outcome-comparator-v1',
    forbiddenSideEffects: forbiddenSideEffects,
    acceptExpected: false,
    referenceFacts: const <String, Object?>{},
    maxBudget: const <String, Object?>{'calls': 3},
  );
  final set = ScenarioSetRelease(
    setId: 'runner-set',
    version: '1.0.0',
    scenarios: <ScenarioRelease>[scenario],
    fixtureCount: 1,
    outlineSceneCount: 1,
    holdout: false,
    createdAtMs: 1,
  );
  final cells = ExperimentManifest.expandCanonicalCells(
    generationBundleHashes: <String>[_digest('b')],
    modelRouteHashes: <String>[_digest('1')],
    scenarios: <ScenarioRelease>[scenario],
    decodingConfigHashes: <String>[_digest('d')],
  );
  return ExperimentManifest(
    experimentId: experimentId,
    scenarioSet: set,
    generationBundleHashes: <String>[_digest('b')],
    evaluationBundleHash: _digest('e'),
    modelRouteHashes: <String>[_digest('1')],
    decodingConfigHashes: <String>[_digest('d')],
    cells: cells,
    pipelineConfigHash: _digest('2'),
    providerConfigHashWithoutSecrets: _digest('3'),
    providerApiRevision: 'glm-api-2026-07',
    sdkAdapterReleaseHash: _digest('5'),
    tokenizerReleaseHash: _digest('6'),
    priceTableHash: _digest('7'),
    codeCommit: 'deadbeef',
    sourceTreeHash: _digest('8'),
    buildArtifactHash: _digest('9'),
    runtimeReleaseHash: _digest('a'),
    trialsPerCell: 3,
    seedPolicy: const <String, Object?>{'mode': 'recorded'},
    trialIsolationPolicy: const <String, Object?>{'mode': 'independent-db'},
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 3},
    performanceSamplingPolicy: const <String, Object?>{'minimum': 20},
    qualityComparisonPolicyHash: _digest('c'),
    holdoutAccessPolicy: HoldoutAccessPolicy(
      policyHash: _digest('f'),
      accessBudget: 1,
      accessOrdinal: 0,
    ),
    budgets: const <String, Object?>{'calls': 9},
    qualityThresholds: const <String, Object?>{'overall': 95},
    createdAtMs: 1,
  );
}

ExperimentManifest _episodeManifest() {
  final scenarios = <ScenarioRelease>[
    for (var step = 1; step <= 2; step += 1)
      ScenarioRelease(
        scenarioId: 'episode-step-$step',
        version: '1.0.0',
        difficulty: 'adversarial',
        inputFixture: <String, Object?>{'scene': step},
        fixtureHash: _digest(step == 1 ? '4' : '5'),
        isolationMode: 'episode',
        episodeId: 'episode-1',
        episodeStep: step,
        requiredCapabilities: const <String>['budget'],
        adversarialMutations: const <String>['episode-state'],
        verifierReleaseRefs: const <String>['budget-verifier-v1'],
        rubricReleaseRef: 'rubric-v1',
        expectedTerminalState: 'blocked',
        requiredFailureCodes: const <String>['budget.exceeded'],
        allowedAdditionalFailureCodes: const <String>[],
        forbiddenFailureCodes: const <String>[],
        outcomeComparatorReleaseRef: 'outcome-comparator-v1',
        forbiddenSideEffects: const <String>['authority-write'],
        acceptExpected: false,
        referenceFacts: <String, Object?>{'step': step},
        maxBudget: const <String, Object?>{'calls': 3},
      ),
  ];
  final set = ScenarioSetRelease(
    setId: 'episode-set',
    version: '1.0.0',
    scenarios: scenarios,
    fixtureCount: 2,
    outlineSceneCount: 2,
    holdout: false,
    createdAtMs: 1,
  );
  final cells = ExperimentManifest.expandCanonicalCells(
    generationBundleHashes: <String>[_digest('b')],
    modelRouteHashes: <String>[_digest('1')],
    scenarios: scenarios,
    decodingConfigHashes: <String>[_digest('d')],
  );
  return ExperimentManifest(
    experimentId: 'experiment-episode',
    scenarioSet: set,
    generationBundleHashes: <String>[_digest('b')],
    evaluationBundleHash: _digest('e'),
    modelRouteHashes: <String>[_digest('1')],
    decodingConfigHashes: <String>[_digest('d')],
    cells: cells,
    pipelineConfigHash: _digest('2'),
    providerConfigHashWithoutSecrets: _digest('3'),
    providerApiRevision: 'glm-api-2026-07',
    sdkAdapterReleaseHash: _digest('5'),
    tokenizerReleaseHash: _digest('6'),
    priceTableHash: _digest('7'),
    codeCommit: 'deadbeef',
    sourceTreeHash: _digest('8'),
    buildArtifactHash: _digest('9'),
    runtimeReleaseHash: _digest('a'),
    trialsPerCell: 3,
    seedPolicy: const <String, Object?>{'mode': 'recorded'},
    trialIsolationPolicy: const <String, Object?>{'mode': 'episode-db'},
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 1},
    performanceSamplingPolicy: const <String, Object?>{'minimum': 20},
    qualityComparisonPolicyHash: _digest('c'),
    holdoutAccessPolicy: HoldoutAccessPolicy(
      policyHash: _digest('f'),
      accessBudget: 1,
      accessOrdinal: 0,
    ),
    budgets: const <String, Object?>{'calls': 6},
    qualityThresholds: const <String, Object?>{'overall': 95},
    createdAtMs: 1,
  );
}

void _seedBundles(Database db) {
  db.execute(
    '''INSERT INTO generation_bundles (
         bundle_hash, bundle_id, releases_json, created_at_ms
       ) VALUES (?, 'runner-bundle', '[{}]', 1)''',
    <Object?>[_digest('b')],
  );
  db.execute(
    '''INSERT INTO prompt_releases (
         release_id, template_id, semantic_version, language, content_hash,
         system_template, user_template, variables_schema_json,
         output_schema_json, renderer_release, parser_release,
         repair_policy_json, variables_schema_hash, output_schema_hash,
         owner, change_note, created_at_ms
       ) VALUES ('runner-release', 'runner', '1.0.0', 'zh', ?,
         'runner system', 'runner user', '{}', '{}', 'renderer-v1',
         'parser-v1', '{}', ?, ?, 'test', 'runner fixture', 1)''',
    <Object?>[_digest('c'), _digest('d'), _digest('e')],
  );
  db.execute(
    '''INSERT INTO generation_bundle_releases (
         bundle_hash, stage_id, call_site_id, variant_id, prompt_release_id
       ) VALUES (?, 'runner', 'runner', 'zh', 'runner-release')''',
    <Object?>[_digest('b')],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'runner-evaluator', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
