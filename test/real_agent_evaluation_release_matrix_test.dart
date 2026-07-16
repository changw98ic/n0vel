import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_executor.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_production_evidence.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_release_harness.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_real_provider_entry_gate.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support/agent_evaluation_production_protocol_client.dart';

void main() {
  group('formal real-provider release harness', () {
    group('atomic unique release report writes', () {
      late Directory reports;

      setUp(() {
        reports = Directory.systemTemp.createTempSync('atomic-release-report-');
      });

      tearDown(() {
        if (reports.existsSync()) reports.deleteSync(recursive: true);
      });

      test('an existing final report advances the ordinal', () {
        final first = File('${reports.path}/report.json')
          ..writeAsStringSync('existing', flush: true);

        final written = writeAgentEvaluationUniqueReportFileAtomically(
          directory: reports,
          fileStem: 'report',
          body: 'complete report',
        );

        expect(written?.path, '${reports.path}/report-1.json');
        expect(first.readAsStringSync(), 'existing');
        expect(written?.readAsStringSync(), 'complete report');
        expect(
          reports
              .listSync()
              .map((entry) => entry.path)
              .where(
                (path) => path.contains('.tmp-') || path.endsWith('.reserve'),
              ),
          isEmpty,
        );
      });

      test('a non-file target failure leaves no report or sidecars', () {
        Directory('${reports.path}/report.json').createSync();

        expect(
          () => writeAgentEvaluationUniqueReportFileAtomically(
            directory: reports,
            fileStem: 'report',
            body: 'must never become visible',
          ),
          throwsA(isA<FileSystemException>()),
        );

        expect(File('${reports.path}/report.json').existsSync(), isFalse);
        expect(File('${reports.path}/report-1.json').existsSync(), isFalse);
        expect(
          reports
              .listSync()
              .map((entry) => entry.path)
              .where(
                (path) => path.contains('.tmp-') || path.endsWith('.reserve'),
              ),
          isEmpty,
        );
      });

      test('a concurrent reservation advances without overwrite', () {
        final reservation = File('${reports.path}/report.json.reserve')
          ..writeAsStringSync('foreign writer', flush: true);

        final written = writeAgentEvaluationUniqueReportFileAtomically(
          directory: reports,
          fileStem: 'report',
          body: 'report',
        );

        expect(reservation.readAsStringSync(), 'foreign writer');
        expect(File('${reports.path}/report.json').existsSync(), isFalse);
        expect(written?.path, '${reports.path}/report-1.json');
        expect(written?.readAsStringSync(), 'report');
      });
    });

    test('preflight requires budgets that cover all 60 slots per model', () {
      expect(() => _configuration(maxProviderCalls: 59), throwsArgumentError);
      expect(
        () => _configuration(maxProviderCalls: (60 * 65) - 1),
        throwsArgumentError,
      );
      expect(
        () => _configuration(maxCompletionTokensPerCall: 4095),
        throwsArgumentError,
      );
      expect(() => _configuration(evaluatorMaxCalls: 59), throwsArgumentError);
      final configuration = _configuration();
      expect(configuration.expectedCells, 20);
      expect(configuration.expectedSlots, 60);
    });

    test(
      'formal release budget covers public and private matrices together',
      () {
        final oneMatrixOnly = _configuration(
          maxAttemptsPerTrial: 3,
          maxCallsPerTrial: 24,
          maxProviderCalls: 4500,
          maxTotalTokens: 500000000,
          evaluatorMaxCalls: 180,
          evaluatorMaxTokens: 20000000,
          evaluatorMaxCostMicrousd: 180,
          evaluatorCostMicrousdPerCall: 1,
          maxTotalCostMicrousd: 1,
          promptPriceMicrousdPerMillionTokens: 0,
          completionPriceMicrousdPerMillionTokens: 0,
          judgePromptPriceMicrousdPerMillionTokens: 0,
          judgeCompletionPriceMicrousdPerMillionTokens: 0,
        );

        expect(
          oneMatrixOnly.requireCombinedReleaseBudgetCoverage,
          throwsArgumentError,
        );
        expect(
          () => AgentEvaluationRealReleaseHarness.realProvider(
            configuration: oneMatrixOnly,
            outputDirectory: Directory.systemTemp,
            releaseBudgetDirectory: Directory.systemTemp,
          ),
          throwsArgumentError,
          reason: 'the release-capable entry point must enforce the total cap',
        );
        expect(
          oneMatrixOnly.combinedReleaseBudgetRequirement.providerCalls,
          9000,
        );
        expect(
          oneMatrixOnly.combinedReleaseBudgetRequirement.totalTokens,
          936864000,
        );
        expect(
          oneMatrixOnly.combinedReleaseBudgetRequirement.evaluatorCalls,
          360,
        );
        expect(
          oneMatrixOnly.combinedReleaseBudgetRequirement.evaluatorTokens,
          37474560,
        );

        final complete = _configuration(
          maxAttemptsPerTrial: 3,
          maxCallsPerTrial: 24,
          maxProviderCalls: 9000,
          maxTotalTokens: 936864000,
          evaluatorMaxCalls: 360,
          evaluatorMaxTokens: 37474560,
          evaluatorMaxCostMicrousd: 360,
          evaluatorCostMicrousdPerCall: 1,
          maxTotalCostMicrousd: 1,
          promptPriceMicrousdPerMillionTokens: 0,
          completionPriceMicrousdPerMillionTokens: 0,
          judgePromptPriceMicrousdPerMillionTokens: 0,
          judgeCompletionPriceMicrousdPerMillionTokens: 0,
        );
        complete.requireCombinedReleaseBudgetCoverage();
      },
    );

    test('retry budget covers every declared transport attempt', () {
      expect(
        () => _configuration(
          maxAttemptsPerTrial: 2,
          maxProviderCalls: (60 * 2 * 65) - 1,
          evaluatorMaxCalls: 120,
          evaluatorMaxTokens: 20000000,
        ),
        throwsArgumentError,
      );
      expect(
        _configuration(
          maxAttemptsPerTrial: 2,
          maxProviderCalls: 60 * 2 * 65,
          evaluatorMaxCalls: 120,
          evaluatorMaxTokens: 20000000,
        ).maxAttemptsPerTrial,
        2,
      );
    });

    test('frozen zero-price routes are valid but negative prices fail', () {
      expect(
        _configuration(
          promptPriceMicrousdPerMillionTokens: 0,
          completionPriceMicrousdPerMillionTokens: 0,
          judgePromptPriceMicrousdPerMillionTokens: 0,
          judgeCompletionPriceMicrousdPerMillionTokens: 0,
        ).expectedSlots,
        60,
      );
      expect(
        () => _configuration(promptPriceMicrousdPerMillionTokens: -1),
        throwsArgumentError,
      );
    });

    test('preflight mirrors per-call cost rounding and judge call cap', () {
      expect(
        () => _configuration(maxTotalCostMicrousd: 7799),
        throwsArgumentError,
        reason: '3840 SUT calls and 60 judge calls each round two token sides',
      );
      expect(_configuration(maxTotalCostMicrousd: 7800).expectedSlots, 60);
      final provider = PurposeBuiltIndependentJudgeClient();
      expect(
        () => _configuration(evaluatorCostMicrousdPerCall: 1),
        throwsArgumentError,
      );
      expect(provider.calls, 0, reason: 'preflight must precede provider IO');
    });

    test(
      'normal production protocol yields receipts, scorecard, and DB verdict',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-matrix-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final sut = PurposeBuiltProductionProtocolClient();
        final judge = PurposeBuiltIndependentJudgeClient();
        final configuration = _configuration(
          evaluatorMaxCalls: 120,
          evaluatorMaxTokens: 20000000,
        );
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: configuration,
          sutClient: sut,
          judgeClient: judge,
          outputDirectory: Directory('${directory.path}/reports'),
          workDirectory: Directory('${directory.path}/work'),
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(result.claimScope, 'real-provider-release');
        expect(result.realProviderEvidence, isFalse);
        expect(result.trustedHoldoutConfirmed, isFalse);
        expect(result.releaseEligible, isFalse);
        expect(result.partitions, hasLength(1));
        final partition = result.partitions.single;
        expect(partition.cellCount, 20);
        expect(partition.slotCount, 60);
        expect(partition.productionReceiptCount, 60);
        expect(partition.regressionStatus, isIn(<String>['promote', 'reject']));
        expect(sut.calls, greaterThan(60));
        expect(judge.calls, 60);
        expect(partition.providerCallCount, sut.calls + judge.calls);
        final budgetEvidence = readAgentEvaluationCombinedReleaseBudgetEvidence(
          configuration: configuration,
          releaseBudgetDirectory: Directory('${directory.path}/work'),
          minimumProviderCalls: partition.providerCallCount,
          minimumJudgeCalls: 60,
        );
        verifyAgentEvaluationCombinedReleaseBudgetEvidence(budgetEvidence);
        expect(
          (budgetEvidence['executionSnapshot']!
              as Map<String, Object?>)['calls'],
          partition.providerCallCount,
        );
        expect(
          sut.systemPrompts.any(
            (prompt) => prompt.contains('causal bridge in order'),
          ),
          isTrue,
          reason: 'the challenger must affect the normal production pipeline',
        );
        expect(
          sut.systemPrompts.any(
            (prompt) => !prompt.contains('causal bridge in order'),
          ),
          isTrue,
          reason: 'the champion and challenger must remain distinct',
        );
        expect(
          judge.requests.every(
            (request) =>
                request.messages.last.content.contains(
                  '"contentType":"untrusted_quoted_candidate"',
                ) &&
                !request.messages.first.content.contains('七号仓'),
          ),
          isTrue,
        );

        final report = File(result.reportPath).readAsStringSync();
        expect(report, contains('"claimScope": "real-provider-release"'));
        expect(report, contains('"releaseEligible": false'));
        expect(report, contains('"executionBudgetPolicyHash"'));
        expect(report, contains('"executionBudgetSnapshotHash"'));
        expect(report, contains('"executionBudgetStartSnapshotHash"'));
        expect(report, contains('"judgeBudgetPolicyHash"'));
        expect(report, contains('"judgeBudgetSnapshotHash"'));
        expect(report, contains('"judgeBudgetStartSnapshotHash"'));
        expect(report, contains('"auditRootHash"'));
        expect(report, contains('"runnerReleaseHash"'));
        expect(report, contains('"criteriaIds"'));
        expect(report, contains('"retention"'));
        expect(report, contains('"level": "audit"'));
        expect(report, contains('"supportsRegrade": false'));
        expect(report, contains('"supportsReExecute": false'));
        expect(report, isNot(contains('immutable')));
        expect(report, contains('"commandIdentity"'));
        expect(report, contains('"durationMs"'));
        expect(report, contains('"exitSemantics"'));
        expect(report, contains('"activeReservations": 0'));
        expect(report, contains('"breached": false'));
        expect(report, isNot(contains('sut-test-secret')));
        expect(report, isNot(contains('judge-test-secret')));
        expect(report, isNot(contains('七号仓')));
        expect(report, isNot(contains('apiKey')));
        expect(report, isNot(contains('baseUrl')));

        final db = sqlite3.open(result.authorityDatabasePath);
        addTearDown(db.dispose);
        expect(
          db.select(
            'SELECT * FROM eval_scorecards WHERE execution_id = ?',
            <Object?>[partition.executionId],
          ),
          hasLength(1),
        );
        expect(
          db.select(
            '''SELECT * FROM eval_release_gate_derivations d
               JOIN eval_release_gate_verdicts v
                 ON v.verdict_hash = d.verdict_hash
               WHERE v.execution_id = ?''',
            <Object?>[partition.executionId],
          ),
          hasLength(1),
        );
        expect(
          db.select(
            'SELECT * FROM eval_dispatch_events WHERE execution_id = ?',
            <Object?>[partition.executionId],
          ),
          isNotEmpty,
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'a conservatively metered provider failure retries and remains DB-derived',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-retry-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final judge = PurposeBuiltIndependentJudgeClient();
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(
            executionId: 'purpose-built-release-retry',
            maxAttemptsPerTrial: 2,
            evaluatorMaxCalls: 120,
            evaluatorMaxTokens: 20000000,
          ),
          sutClient: _FailOnceProductionProtocolClient(),
          judgeClient: judge,
          outputDirectory: Directory('${directory.path}/reports'),
          workDirectory: Directory('${directory.path}/work'),
        );
        addTearDown(harness.dispose);

        final result = await harness.run();
        final db = sqlite3.open(result.authorityDatabasePath);
        addTearDown(db.dispose);
        final attempts = db.select(
          '''SELECT a.status AS attempt_status, a.kind, COUNT(*) AS count
             FROM eval_trial_attempts a
             JOIN eval_trial_slots s ON s.trial_slot_id = a.trial_slot_id
             WHERE s.execution_id = ? GROUP BY a.status, a.kind''',
          <Object?>['purpose-built-release-retry'],
        );

        expect(
          attempts.singleWhere(
            (row) =>
                row['attempt_status'] == 'completed' &&
                row['kind'] == 'content',
          )['count'],
          60,
        );
        expect(
          attempts.where((row) => row['attempt_status'] == 'failed'),
          isEmpty,
          reason: 'the metered transport retry stays inside its formal attempt',
        );
        final usageRows = db.select(
          '''SELECT o.value_json FROM eval_observations o
             JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
             WHERE s.execution_id = ? AND o.stage_id = 'performance'
               AND o.kind = 'usage' ''',
          <Object?>['purpose-built-release-retry'],
        );
        final providerCalls = <Map<String, Object?>>[
          for (final row in usageRows)
            for (final call
                in (jsonDecode(row['value_json'] as String)
                        as Map<String, Object?>)['providerCalls']
                    as List<Object?>)
              Map<String, Object?>.from(call! as Map),
        ];
        expect(usageRows, hasLength(60));
        expect(
          providerCalls.where(
            (call) => call['purpose'] == 'sut' && call['succeeded'] == false,
          ),
          hasLength(1),
          reason: 'the failed physical call remains DB-derived usage evidence',
        );
        expect(judge.calls, 60);
        expect(result.partitions.single.productionReceiptCount, 60);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'a failed judge reservation is charged and blocks SUT replay',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-judge-retry-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final judge = _FailOnceJudgeClient();
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(
            executionId: 'purpose-built-judge-retry',
            maxAttemptsPerTrial: 2,
            evaluatorMaxCalls: 120,
            evaluatorMaxTokens: 20000000,
          ),
          sutClient: PurposeBuiltProductionProtocolClient(),
          judgeClient: judge,
          outputDirectory: Directory('${directory.path}/reports'),
          workDirectory: Directory('${directory.path}/work'),
        );
        addTearDown(harness.dispose);

        await expectLater(
          harness.run(),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('receipts=59'),
            ),
          ),
        );
        final db = sqlite3.open('${directory.path}/work/authority.sqlite');
        addTearDown(db.dispose);
        final failedAttempts = db
            .select(
              '''SELECT COUNT(*) AS count FROM eval_trial_attempts a
                 JOIN eval_trial_slots s
                   ON s.trial_slot_id = a.trial_slot_id
                 WHERE s.execution_id = ? AND a.status = 'failed'
                   AND a.kind = 'transport' ''',
              <Object?>['purpose-built-judge-retry'],
            )
            .single['count'];

        expect(failedAttempts, 1);
        expect(judge.attempts, 60);
        expect(judge.successfulCalls, 59);
        expect(
          db
              .select(
                '''SELECT COUNT(*) AS count
                   FROM eval_production_authority_receipts r
                   JOIN eval_trial_slots s
                     ON s.trial_slot_id = r.trial_slot_id
                   WHERE s.execution_id = ?''',
                <Object?>['purpose-built-judge-retry'],
              )
              .single['count'],
          59,
        );
        final judgeJournal =
            jsonDecode(
                  File(
                    '${directory.path}/work/judge-budget.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(judgeJournal['calls'], 60);
        expect(judgeJournal['succeededCalls'], 59);
        expect(judgeJournal['failedCalls'], 1);
        expect(judgeJournal['reservations'], isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'attempt call cap stops every retry before an extra provider dispatch',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-attempt-call-cap-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final sut = PurposeBuiltProductionProtocolClient();
        final judge = PurposeBuiltIndependentJudgeClient();
        final reports = Directory('${directory.path}/reports');
        final work = Directory('${directory.path}/work');
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(
            executionId: 'purpose-built-attempt-call-cap',
            maxAttemptsPerTrial: 2,
            maxCallsPerTrial: 1,
            maxTokensPerTrial: 104096,
            evaluatorMaxCalls: 120,
            evaluatorMaxTokens: 20000000,
          ),
          sutClient: sut,
          judgeClient: judge,
          outputDirectory: reports,
          workDirectory: work,
        );
        addTearDown(harness.dispose);

        await expectLater(harness.run(), throwsA(anything));

        expect(
          sut.calls,
          60,
          reason:
              'each slot dispatches once; an observed response is not replayed',
        );
        expect(judge.calls, 0);
        final db = sqlite3.open('${work.path}/authority.sqlite');
        addTearDown(db.dispose);
        final attempts = db.select(
          '''SELECT a.status, a.kind FROM eval_trial_attempts a
             JOIN eval_trial_slots s ON s.trial_slot_id = a.trial_slot_id
             WHERE s.execution_id = ? ORDER BY a.attempt_no''',
          <Object?>['purpose-built-attempt-call-cap'],
        );
        expect(attempts, hasLength(60));
        expect(
          attempts.every(
            (row) => row['status'] == 'failed' && row['kind'] == 'transport',
          ),
          isTrue,
        );
        final usageRows = db.select(
          '''SELECT o.value_json FROM eval_observations o
             JOIN eval_trial_slots s ON s.trial_slot_id = o.trial_slot_id
             WHERE s.execution_id = ? AND o.stage_id = 'performance'
               AND o.kind = 'usage' ORDER BY o.attempt_no''',
          <Object?>['purpose-built-attempt-call-cap'],
        );
        expect(usageRows, hasLength(60));
        for (final row in usageRows) {
          final usage = jsonDecode(row['value_json'] as String);
          expect(usage, isA<Map<String, Object?>>());
          final calls = (usage as Map<String, Object?>)['providerCalls'];
          expect(calls, isA<List<Object?>>());
          expect(calls as List<Object?>, hasLength(1));
          expect((calls.single as Map<String, Object?>)['purpose'], 'sut');
        }
        expect(
          db
              .select(
                '''SELECT COUNT(*) AS count
                   FROM eval_production_authority_receipts r
                   JOIN eval_trial_slots s
                     ON s.trial_slot_id = r.trial_slot_id
                   WHERE s.execution_id = ?''',
                <Object?>['purpose-built-attempt-call-cap'],
              )
              .single['count'],
          0,
        );
        final journal =
            jsonDecode(
                  File('${work.path}/execution-budget.json').readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(journal['calls'], 60);
        expect(journal['succeededCalls'], 60);
        expect(journal['failedCalls'], 0);
        expect(journal['breached'], isFalse);
        expect(journal['reservations'], isEmpty);
        final archives = reports.listSync().whereType<File>().toList();
        expect(archives, hasLength(1));
        expect(
          archives.single.readAsStringSync(),
          contains('failed-closed-no-release-claim'),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'attempt token cap rejects an oversized reservation before provider IO',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-attempt-token-cap-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final sut = PurposeBuiltProductionProtocolClient();
        final judge = PurposeBuiltIndependentJudgeClient();
        final reports = Directory('${directory.path}/reports');
        final work = Directory('${directory.path}/work');
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(
            executionId: 'purpose-built-attempt-token-cap',
            maxAttemptsPerTrial: 2,
            maxCallsPerTrial: 2,
            maxTokensPerTrial: 8194,
            maxPromptTokensPerCall: 1,
            evaluatorMaxCalls: 120,
            evaluatorMaxTokens: 20000000,
          ),
          sutClient: sut,
          judgeClient: judge,
          outputDirectory: reports,
          workDirectory: work,
        );
        addTearDown(harness.dispose);

        await expectLater(
          harness.run(),
          throwsA(
            isA<AgentEvaluationProductionEvidenceException>().having(
              (error) => error.message,
              'message',
              contains('attempt-token-limit-exceeded'),
            ),
          ),
        );

        expect(
          sut.calls,
          0,
          reason: 'the oversized reservation must be rejected pre-dispatch',
        );
        expect(judge.calls, 0);
        final journal =
            jsonDecode(
                  File('${work.path}/execution-budget.json').readAsStringSync(),
                )
                as Map<String, Object?>;
        expect(journal['calls'], 0);
        expect(journal['succeededCalls'], 0);
        expect(journal['failedCalls'], 0);
        expect(journal['breached'], isFalse);
        expect(journal['reservations'], isEmpty);
        final archives = reports.listSync().whereType<File>().toList();
        expect(archives, hasLength(1));
        expect(
          archives.single.readAsStringSync(),
          contains('failed-closed-no-release-claim'),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'normally completed losing challenger still archives DB reject',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-db-reject-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(),
          sutClient: _ChallengerMarkedClient(),
          judgeClient: _MarkerAwareJudgeClient(),
          outputDirectory: Directory('${directory.path}/reports'),
          workDirectory: Directory('${directory.path}/work'),
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(result.partitions.single.regressionStatus, 'reject');
        expect(result.releaseEligible, isFalse);
        expect(File(result.reportPath).existsSync(), isTrue);
        final db = sqlite3.open(result.authorityDatabasePath);
        addTearDown(db.dispose);
        expect(
          db.select('''SELECT v.status FROM eval_release_gate_verdicts v
               JOIN eval_release_gate_derivations d
                 ON d.verdict_hash = v.verdict_hash''').single['status'],
          'reject',
        );
        expect(db.select('SELECT * FROM eval_scorecards'), hasLength(1));
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'two required model routes produce one execution and one DB verdict',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-multi-model-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final firstRoute = _sutRoute('glm-purpose-built-sut-a');
        final secondRoute = _sutRoute('glm-purpose-built-sut-b');
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(
            sutRoutes: <AgentEvaluationProductionRouteRelease>[
              firstRoute,
              secondRoute,
            ],
            maxProviderCalls: 200000,
            evaluatorMaxCalls: 120,
            evaluatorMaxTokens: 20000000,
          ),
          sutClient: PurposeBuiltProductionProtocolClient(),
          judgeClient: PurposeBuiltIndependentJudgeClient(),
          outputDirectory: Directory('${directory.path}/reports'),
          workDirectory: Directory('${directory.path}/work'),
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(result.partitions, hasLength(1));
        expect(result.partitions.single.cellCount, 40);
        expect(result.partitions.single.slotCount, 120);
        expect(result.partitions.single.productionReceiptCount, 120);
        final db = sqlite3.open(result.authorityDatabasePath);
        addTearDown(db.dispose);
        expect(db.select('SELECT * FROM eval_executions'), hasLength(1));
        expect(db.select('SELECT * FROM eval_scorecards'), hasLength(1));
        expect(
          db.select('SELECT * FROM eval_release_gate_verdicts'),
          hasLength(1),
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'purpose-built transport can never assert real-provider evidence',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-purpose-built-claim-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
          configuration: _configuration(),
          sutClient: PurposeBuiltProductionProtocolClient(),
          judgeClient: PurposeBuiltIndependentJudgeClient(),
          outputDirectory: Directory('${directory.path}/reports'),
          workDirectory: Directory('${directory.path}/work'),
        );
        addTearDown(harness.dispose);

        final result = await harness.run();

        expect(result.realProviderEvidence, isFalse);
        expect(result.releaseEligible, isFalse);
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test(
      'failure reports are secret-free and never overwrite an archive',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'formal-release-failure-archive-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final reports = Directory('${directory.path}/reports');
        String? firstBody;
        for (var ordinal = 1; ordinal <= 2; ordinal += 1) {
          final harness = AgentEvaluationRealReleaseHarness.purposeBuilt(
            configuration: _configuration(
              executionId: 'purpose-built-failure-$ordinal',
            ),
            sutClient: const _SecretBearingFailureClient(),
            judgeClient: PurposeBuiltIndependentJudgeClient(),
            outputDirectory: reports,
            workDirectory: Directory('${directory.path}/work-$ordinal'),
          );
          try {
            await expectLater(harness.run(), throwsA(anything));
          } finally {
            harness.dispose();
          }
          final files = reports.listSync().whereType<File>().toList()
            ..sort((left, right) => left.path.compareTo(right.path));
          expect(files, hasLength(ordinal));
          if (ordinal == 1) {
            firstBody = files.single.readAsStringSync();
          } else {
            expect(files.first.readAsStringSync(), firstBody);
          }
        }
        final archive = reports
            .listSync()
            .whereType<File>()
            .map((file) => file.readAsStringSync())
            .join('\n');
        expect(archive, contains('"failed-closed-no-release-claim"'));
        expect(archive, contains('"budgetJournalHashes"'));
        expect(archive, isNot(contains('provider-raw-secret')));
        expect(archive, isNot(contains('https://secret-provider.invalid')));
        expect(archive, isNot(contains('private prompt body')));
        expect(archive, isNot(contains('apiKey')));
        expect(archive, isNot(contains('baseUrl')));
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });

  final legacyRealProviderDecision =
      AgentEvaluationRealProviderEntryGate.legacyDecision(
        entryPoint: 'test/real_agent_evaluation_release_matrix_test.dart',
        environment: Platform.environment,
      );
  test(
    'direct formal real provider release matrix is coordinator-only',
    () {},
    skip: legacyRealProviderDecision.denialReason,
  );
}

AgentEvaluationRealReleaseConfiguration _configuration({
  String executionId = 'purpose-built-release-execution',
  int maxAttemptsPerTrial = 1,
  int maxCallsPerTrial = 64,
  int maxTokensPerTrial = 10000000,
  int maxPromptTokensPerCall = 100000,
  int maxProviderCalls = 100000,
  int maxCompletionTokensPerCall = 4096,
  int evaluatorMaxCalls = 60,
  int evaluatorMaxTokens = 10000000,
  int evaluatorMaxCostMicrousd = 1000000,
  int evaluatorCostMicrousdPerCall = 1000,
  int maxTotalCostMicrousd = 100000000,
  int maxTotalTokens = 1000000000,
  List<AgentEvaluationProductionRouteRelease>? sutRoutes,
  int promptPriceMicrousdPerMillionTokens = 1,
  int completionPriceMicrousdPerMillionTokens = 1,
  int judgePromptPriceMicrousdPerMillionTokens = 1,
  int judgeCompletionPriceMicrousdPerMillionTokens = 1,
}) {
  final frozenSutRoutes =
      sutRoutes ??
      <AgentEvaluationProductionRouteRelease>[
        _sutRoute('glm-purpose-built-sut'),
      ];
  final judgeRoute = AgentEvaluationProductionRouteRelease(
    model: 'glm-purpose-built-independent-judge',
    provider: AppLlmProvider.zhipu,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKey: 'judge-test-secret',
    timeout: const AppLlmTimeoutConfig.uniform(30000),
    providerApiRevision: 'purpose-built-api-v1',
    sdkAdapterReleaseHash: _digest('1'),
  );
  return AgentEvaluationRealReleaseConfiguration(
    executionId: executionId,
    sutRoutes: frozenSutRoutes,
    judgeRoute: judgeRoute,
    decoding: AgentEvaluationProductionDecodingRelease.standard(),
    maxAttemptsPerTrial: maxAttemptsPerTrial,
    maxCallsPerTrial: maxCallsPerTrial,
    maxTokensPerTrial: maxTokensPerTrial,
    maxPromptTokensPerCall: maxPromptTokensPerCall,
    maxCompletionTokensPerCall: maxCompletionTokensPerCall,
    maxProviderCalls: maxProviderCalls,
    maxTotalTokens: maxTotalTokens,
    maxTotalCostMicrousd: maxTotalCostMicrousd,
    evaluatorMaxCalls: evaluatorMaxCalls,
    evaluatorMaxTokens: evaluatorMaxTokens,
    evaluatorMaxCostMicrousd: evaluatorMaxCostMicrousd,
    evaluatorTokensPerCall: 4096,
    evaluatorCostMicrousdPerCall: evaluatorCostMicrousdPerCall,
    promptMicrousdPerMillionTokens: promptPriceMicrousdPerMillionTokens,
    completionMicrousdPerMillionTokens: completionPriceMicrousdPerMillionTokens,
    judgePromptMicrousdPerMillionTokens:
        judgePromptPriceMicrousdPerMillionTokens,
    judgeCompletionMicrousdPerMillionTokens:
        judgeCompletionPriceMicrousdPerMillionTokens,
    deadline: const Duration(minutes: 5),
    holdoutAccessBudget: 1,
    codeCommit: 'purpose-built-test-commit',
    sourceTreeHash: _digest('2'),
    buildArtifactHash: _digest('3'),
    runtimeReleaseHash: _digest('4'),
    tokenizerReleaseHash: _digest('5'),
  );
}

AgentEvaluationProductionRouteRelease _sutRoute(String model) =>
    AgentEvaluationProductionRouteRelease(
      model: model,
      provider: AppLlmProvider.zhipu,
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      apiKey: 'sut-test-secret',
      timeout: const AppLlmTimeoutConfig.uniform(30000),
      providerApiRevision: 'purpose-built-api-v1',
      sdkAdapterReleaseHash: _digest('1'),
    );

String _digest(String character) => List.filled(64, character).join();

final class _FailOnceProductionProtocolClient implements AppLlmClient {
  final _inner = PurposeBuiltProductionProtocolClient();
  var _failed = false;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) {
    if (!_failed) {
      _failed = true;
      throw StateError('transient provider failure');
    }
    return _inner.chat(request);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

final class _FailOnceJudgeClient implements AppLlmClient {
  final _inner = PurposeBuiltIndependentJudgeClient();
  var attempts = 0;

  int get successfulCalls => _inner.calls;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) {
    attempts += 1;
    if (attempts == 1) throw StateError('transient judge failure');
    return _inner.chat(request);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

final class _ChallengerMarkedClient implements AppLlmClient {
  final _inner = PurposeBuiltProductionProtocolClient();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final result = await _inner.chat(request);
    final challenger = request.messages.any(
      (message) =>
          message.content.contains('causal bridge in order') ||
          message.content.contains(_challengerReplacement),
    );
    final isProseCall =
        request.messages.first.content.contains('scene editor') ||
        request.messages.last.content.contains('任务：language_polish');
    if (!result.succeeded || !challenger || !isProseCall) return result;
    return AppLlmChatResult.success(
      text: result.text!.replaceAll(_challengerSource, _challengerReplacement),
      latencyMs: result.latencyMs,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
      totalTokens: result.totalTokens,
      tokenUsage: result.tokenUsage,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}

final class _MarkerAwareJudgeClient implements AppLlmClient {
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    final challenger = request.messages.any(
      (message) => message.content.contains(_challengerReplacement),
    );
    final score = challenger ? 10 : 96;
    return AppLlmChatResult.success(
      text:
          '{"scores":{"proseReadability":$score,"plotCausality":$score},'
          '"summary":"blind comparison"}',
      latencyMs: 3,
      promptTokens: 30,
      completionTokens: 12,
      totalTokens: 42,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release judge disables streaming');
}

const _challengerSource = '真正的编号刻在仓门内侧';
const _challengerReplacement = '真正的编号也许根本不存在';

final class _SecretBearingFailureClient implements AppLlmClient {
  const _SecretBearingFailureClient();

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async =>
      const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.server,
        detail:
            'provider-raw-secret https://secret-provider.invalid '
            'private prompt body',
      );

  @override
  Stream<String> chatStream(AppLlmChatRequest request) =>
      throw UnsupportedError('formal release evaluation disables streaming');
}
