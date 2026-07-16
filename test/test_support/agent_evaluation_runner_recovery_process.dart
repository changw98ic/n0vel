import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_fixture_sandbox.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_runner.dart';
import 'package:novel_writer/features/story_generation/domain/evaluation/outcome_evaluation.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('runner recovery process lane', _runProcessLane);
}

Future<void> _runProcessLane() async {
  final mode = Platform.environment['AGENT_EVAL_RECOVERY_MODE'] ?? '';
  final crashStage = Platform.environment['AGENT_EVAL_RECOVERY_STAGE'] ?? '';
  final rootPath = Platform.environment['AGENT_EVAL_RECOVERY_ROOT'] ?? '';
  if (!<String>{'crash', 'recover'}.contains(mode) ||
      !<String>{
        'prepared',
        'accepted',
        'outboxCompleted',
        'finalPersisted',
      }.contains(crashStage) ||
      rootPath.isEmpty) {
    throw StateError('runner recovery process environment is invalid');
  }
  final root = Directory(rootPath);
  final authorityPath = '${root.path}/authority.sqlite';
  final fixturePath = '${root.path}/fixture.sqlite';
  final productionPath = '${root.path}/production.sqlite';
  final executionId = 'runner-recovery-$crashStage';
  final authority = sqlite3.open(authorityPath);
  AgentEvaluationFixtureSandbox? sandbox;
  try {
    authority.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(authority);
    _seedBundles(authority);
    final manifest = _manifest(experimentId: 'experiment-$crashStage');
    sandbox = AgentEvaluationFixtureSandbox.openOrCreate(
      executionId: executionId,
      fixtureDatabasePath: fixturePath,
      productionDatabasePath: productionPath,
      durableParent: Directory('${root.path}/durable'),
    );
    final runner = AgentEvaluationRunner(
      manifestStore: AgentEvaluationManifestStore(db: authority),
      ledger: AgentEvaluationLedger(db: authority),
      fixtureSandbox: sandbox,
    );
    await runner.run(
      manifest: manifest,
      executionId: executionId,
      workerId: mode == 'crash' ? 'worker-a' : 'worker-b',
      actualBuildArtifactHash: manifest.buildArtifactHash,
      verifierExists: (_) => true,
      trialExecutor: (context) async {
        final pathFile = File('${root.path}/$mode-database-path.txt');
        pathFile.writeAsStringSync(context.sandboxDatabasePath!, flush: true);
        final candidateHash = AgentEvaluationHashes.domainHash(
          'runner-recovery-process-candidate-v1',
          context.lease.trialSlotId,
        );
        bool hasStage(String stage) => context.database.select(
          'SELECT 1 FROM recovery_state WHERE stage = ?',
          <Object?>[stage],
        ).isNotEmpty;

        if (!hasStage('providerResponse')) {
          File('${root.path}/provider-calls.log').writeAsStringSync(
            '${context.lease.trialSlotId}\n',
            mode: FileMode.append,
            flush: true,
          );
          context.database.execute(
            "INSERT INTO recovery_state(stage) VALUES ('providerResponse')",
          );
        }
        const stages = <AgentEvaluationDurableRecoveryStage>[
          AgentEvaluationDurableRecoveryStage.prepared,
          AgentEvaluationDurableRecoveryStage.accepted,
          AgentEvaluationDurableRecoveryStage.outboxCompleted,
          AgentEvaluationDurableRecoveryStage.finalPersisted,
        ];
        for (final stage in stages) {
          if (hasStage(stage.name)) {
            if (mode == 'recover') {
              // Production recovery can revisit an earlier local boundary
              // after a later checkpoint already committed. The callback must
              // return the verified head instead of attempting a rollback.
              await context.persistDurableSandboxRecoveryCheckpoint!(
                stage: stage,
                candidateHash: candidateHash,
              );
            }
            continue;
          }
          context.database.execute(
            'INSERT INTO recovery_state(stage) VALUES (?)',
            <Object?>[stage.name],
          );
          await context.persistDurableSandboxRecoveryCheckpoint!(
            stage: stage,
            candidateHash: candidateHash,
          );
          if (mode == 'crash' && stage.name == crashStage) {
            // Deliberately bypass Runner cleanup. This models SIGKILL after
            // both the sandbox snapshot and fenced authority append committed.
            exit(73);
          }
        }
        if (Platform.environment['AGENT_EVAL_RECOVERY_CLEANUP_FAULT'] == '1') {
          final blocker = Directory(
            '${context.sandboxDatabasePath}.recovery.'
            '${_digest('f')}.sqlite.cleanup-fault',
          )..createSync();
          File('${blocker.path}/retained').writeAsStringSync('retain');
        }
        return AgentEvaluationTrialExecutionResult(
          outcome: const ActualTrialOutcome(
            terminalState: TrialTerminalState.blocked,
            failureCodes: <String>{'budget.exceeded'},
            accepted: false,
            evidenceComplete: true,
          ),
          evaluatedContent: 'recovered:${context.lease.trialSlotId}',
        );
      },
      cancellationToken: AgentEvaluationCancellationToken(),
      onProgress: (_) {},
      leaseDurationMs: mode == 'crash' ? 100 : 5000,
    );
    stdout.write('sealed');
  } finally {
    sandbox?.dispose();
    authority.dispose();
  }
}

void _seedBundles(Database db) {
  if (db.select(
    'SELECT 1 FROM generation_bundles WHERE bundle_hash = ?',
    <Object?>[_digest('b')],
  ).isNotEmpty) {
    return;
  }
  db.execute(
    '''INSERT INTO generation_bundles (
         bundle_hash, bundle_id, releases_json, created_at_ms
       ) VALUES (?, 'recovery-bundle', '[{}]', 1)''',
    <Object?>[_digest('b')],
  );
  db.execute(
    '''INSERT INTO prompt_releases (
         release_id, template_id, semantic_version, language, content_hash,
         system_template, user_template, variables_schema_json,
         output_schema_json, renderer_release, parser_release,
         repair_policy_json, variables_schema_hash, output_schema_hash,
         owner, change_note, created_at_ms
       ) VALUES ('recovery-release', 'recovery', '1.0.0', 'zh', ?,
         'system', 'user', '{}', '{}', 'renderer-v1', 'parser-v1', '{}',
         ?, ?, 'test', 'recovery fixture', 1)''',
    <Object?>[_digest('c'), _digest('d'), _digest('e')],
  );
  db.execute(
    '''INSERT INTO generation_bundle_releases (
         bundle_hash, stage_id, call_site_id, variant_id, prompt_release_id
       ) VALUES (?, 'recovery', 'recovery', 'zh', 'recovery-release')''',
    <Object?>[_digest('b')],
  );
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'recovery-evaluator', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('f'), _digest('1'), _digest('2'), _digest('3')],
  );
}

ExperimentManifest _manifest({required String experimentId}) {
  final scenario = ScenarioRelease(
    scenarioId: 'blocked-budget',
    version: '1.0.0',
    difficulty: 'adversarial',
    inputFixture: const <String, Object?>{'scene': 1},
    fixtureHash: _digest('4'),
    isolationMode: 'independent',
    requiredCapabilities: const <String>['budget'],
    adversarialMutations: const <String>['crash'],
    verifierReleaseRefs: const <String>['budget-verifier-v1'],
    rubricReleaseRef: 'rubric-v1',
    expectedTerminalState: 'blocked',
    requiredFailureCodes: const <String>['budget.exceeded'],
    allowedAdditionalFailureCodes: const <String>[],
    forbiddenFailureCodes: const <String>[],
    outcomeComparatorReleaseRef: 'outcome-v1',
    forbiddenSideEffects: const <String>['authority-write'],
    acceptExpected: false,
    referenceFacts: const <String, Object?>{},
    maxBudget: const <String, Object?>{'calls': 1},
  );
  final set = ScenarioSetRelease(
    setId: 'runner-recovery-set',
    version: '1.0.0',
    scenarios: <ScenarioRelease>[scenario],
    fixtureCount: 1,
    outlineSceneCount: 1,
    holdout: false,
    createdAtMs: 1,
  );
  final cells = ExperimentManifest.expandCanonicalCells(
    generationBundleHashes: <String>[_digest('b')],
    modelRouteHashes: <String>[_digest('5')],
    scenarios: <ScenarioRelease>[scenario],
    decodingConfigHashes: <String>[_digest('6')],
  );
  return ExperimentManifest(
    experimentId: experimentId,
    scenarioSet: set,
    generationBundleHashes: <String>[_digest('b')],
    evaluationBundleHash: _digest('f'),
    modelRouteHashes: <String>[_digest('5')],
    decodingConfigHashes: <String>[_digest('6')],
    cells: cells,
    pipelineConfigHash: _digest('7'),
    providerConfigHashWithoutSecrets: _digest('8'),
    providerApiRevision: 'test-api-v1',
    sdkAdapterReleaseHash: _digest('9'),
    tokenizerReleaseHash: _digest('a'),
    priceTableHash: _digest('c'),
    codeCommit: 'runner-recovery-test',
    sourceTreeHash: _digest('d'),
    buildArtifactHash: _digest('e'),
    runtimeReleaseHash: _digest('1'),
    trialsPerCell: 1,
    seedPolicy: const <String, Object?>{'mode': 'recorded'},
    trialIsolationPolicy: const <String, Object?>{
      'mode': 'durable-epoch-fenced-sqlite',
    },
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 1},
    performanceSamplingPolicy: const <String, Object?>{},
    qualityComparisonPolicyHash: _digest('2'),
    holdoutAccessPolicy: HoldoutAccessPolicy(
      policyHash: _digest('3'),
      accessBudget: 1,
      accessOrdinal: 0,
    ),
    budgets: const <String, Object?>{},
    qualityThresholds: const <String, Object?>{},
    createdAtMs: 1,
  );
}

String _digest(String value) => List<String>.filled(64, value).join();
