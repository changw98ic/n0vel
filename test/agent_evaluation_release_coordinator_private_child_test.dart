import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_holdout_runner.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final enabled =
      Platform.environment['AGENT_EVAL_PURPOSE_COORDINATOR_CHILD'] == '1';
  test(
    'purpose-built coordinator private child process',
    () async {
      final env = Platform.environment;
      String required(String name) {
        final value = (env[name] ?? '').trim();
        if (value.isEmpty) throw StateError('missing child input');
        return value;
      }

      final signer = await AgentEvaluationTrustedHoldoutSigner.fromSeedFile(
        keyId: required('AGENT_EVAL_CHILD_KEY_ID'),
        path: required('AGENT_EVAL_CHILD_SEED_FILE'),
      );
      final vault = File(required('AGENT_EVAL_CHILD_VAULT'));
      final authorityPath = required('AGENT_EVAL_CHILD_AUTHORITY_DB');
      final authority = sqlite3.open(authorityPath, mode: OpenMode.readOnly);
      late final String priceTableHash;
      late final String evaluationBundleHash;
      try {
        priceTableHash =
            authority
                    .select(
                      'SELECT price_table_hash FROM eval_price_table_releases',
                    )
                    .single['price_table_hash']
                as String;
        evaluationBundleHash =
            authority
                    .select(
                      'SELECT evaluation_bundle_hash FROM evaluation_bundles',
                    )
                    .single['evaluation_bundle_hash']
                as String;
      } finally {
        authority.dispose();
      }
      final workIdentity = AgentEvaluationHashes.domainHash(
        'agent-evaluation-purpose-child-work-v1',
        required('AGENT_EVAL_CHILD_ACCESS_ID'),
      ).substring(0, 16);
      final runner = AgentEvaluationPrivateProductionHoldoutRunner.purposeBuilt(
        authorityDatabasePath: authorityPath,
        accessId: required('AGENT_EVAL_CHILD_ACCESS_ID'),
        privatePlanPath: required('AGENT_EVAL_CHILD_PRIVATE_PLAN'),
        vaultPath: vault.path,
        privateWorkDirectory: Directory(
          '${vault.parent.path}/purpose-child-$workIdentity',
        ),
        signer: signer,
        execution: _PurposeBuiltPrivateExecution(
          priceTableHash: priceTableHash,
          evaluationBundleHash: evaluationBundleHash,
        ),
      );
      final response = await runner.run();
      final output = File(required('AGENT_EVAL_CHILD_RESPONSE'));
      output.writeAsStringSync(response.canonicalJson, flush: true);
      if (!Platform.isWindows) {
        final chmod = Process.runSync('chmod', <String>['600', output.path]);
        if (chmod.exitCode != 0) throw StateError('child chmod failed');
      }
    },
    skip: enabled ? false : 'purpose coordinator child bootstrap only',
  );
}

final class _PurposeBuiltPrivateExecution
    implements AgentEvaluationPrivateProductionExecution {
  const _PurposeBuiltPrivateExecution({
    required this.priceTableHash,
    required this.evaluationBundleHash,
  });

  final String priceTableHash;
  final String evaluationBundleHash;

  @override
  Future<AgentEvaluationPrivateProductionArtifacts> run({
    required AgentEvaluationPrivateProductionGrant grant,
    required AgentEvaluationPrivateProductionPlan plan,
    required Directory privateWorkDirectory,
  }) async {
    if (plan.scenarioSet.isEmpty ||
        plan.fixture.isEmpty ||
        plan.opaqueHoldoutScenarioSetHash !=
            grant.opaqueHoldoutScenarioSetHash) {
      throw StateError('purpose-built private plan is incomplete');
    }
    final projection = AgentEvaluationProductionHoldoutProjection(
      executionSummary: <String, Object?>{
        'schemaVersion': 'production-holdout-redacted-execution-summary-v1',
        'status': 'completed',
        'releaseConfigurationHash': AgentEvaluationHashes.domainHash(
          'agent-evaluation-release-configuration-v1',
          plan.releaseConfiguration,
        ),
        'executionCommitmentHash': _digest('7'),
        'expectedSlotCount': 60,
        'completedSlotCount': 60,
      },
      scorecard: <String, Object?>{
        'schemaVersion': 'production-holdout-redacted-scorecard-v1',
        'inputSetHash': _digest('6'),
        'expectedCellSetHash': _digest('4'),
        'expectedSlotSetHash': _digest('5'),
        'aggregateCommitmentHash': _digest('8'),
      },
      gateVerdict: <String, Object?>{
        'schemaVersion': 'production-holdout-redacted-gate-v1',
        'status': 'promote',
        'scorecardHash': _digest('8'),
        'projectionHash': _digest('a'),
        'policyHash': AgentEvaluationStandardGatePolicy.policyHash,
        'reasonCodes': <String>['all-gates-pass'],
      },
    );
    return AgentEvaluationPrivateProductionArtifacts(
      productionManifestHash: _digest('e'),
      privateExecutionSummaryHash: _digest('7'),
      privateScorecardHash: _digest('8'),
      privateGateVerdictHash: _digest('9'),
      privateProjectionHash: _digest('a'),
      expectedCellSetHash: _digest('4'),
      expectedSlotSetHash: _digest('5'),
      executionBudgetPolicyHash: _digest('f'),
      executorReleaseHash: _digest('0'),
      evaluationBundleHash: evaluationBundleHash,
      priceTableHash: priceTableHash,
      gatePolicyHash: AgentEvaluationStandardGatePolicy.policyHash,
      projection: projection,
    );
  }
}

String _digest(String value) => value * 64;
