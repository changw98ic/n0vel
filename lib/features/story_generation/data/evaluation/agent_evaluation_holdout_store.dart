import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_release_store.dart';
import 'agent_evaluation_trusted_holdout.dart';

abstract final class AgentEvaluationTrustedHoldoutRunnerPolicy {
  static const implementationIdentity =
      'trusted-holdout-separate-vault-ed25519-v2';

  static String get releaseHash =>
      AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash;
}

class AgentEvaluationHoldoutException implements Exception {
  const AgentEvaluationHoldoutException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationHoldoutException: $message';
}

class AgentEvaluationHoldoutConflict extends AgentEvaluationHoldoutException {
  const AgentEvaluationHoldoutConflict(super.message);
}

class SchemaCompatibilityContractRecord {
  const SchemaCompatibilityContractRecord({
    required this.schemaVersion,
    required this.minReaderVersion,
    required this.minWriterVersion,
    required this.upgradePolicyJson,
    required this.rollbackPolicyJson,
  });

  final int schemaVersion;
  final int minReaderVersion;
  final int minWriterVersion;
  final String upgradePolicyJson;
  final String rollbackPolicyJson;
}

class HoldoutConfirmationRecord {
  const HoldoutConfirmationRecord({
    required this.confirmationId,
    required this.tokenId,
    required this.familyId,
    required this.challengerBundleHash,
    required this.executionId,
    required this.result,
    required this.publicResultJson,
    required this.alphaCostMicros,
    required this.createdAtMs,
  });

  final String confirmationId;
  final String tokenId;
  final String familyId;
  final String challengerBundleHash;
  final String executionId;
  final String result;
  final String publicResultJson;
  final int alphaCostMicros;
  final int createdAtMs;
}

class HoldoutAccessRecord {
  const HoldoutAccessRecord({
    required this.accessId,
    required this.tokenId,
    required this.familyId,
    required this.challengerBundleHash,
    required this.executionId,
    required this.trustedRunnerReleaseHash,
    required this.alphaCostMicros,
    required this.state,
    required this.begunAtMs,
  });

  final String accessId;
  final String tokenId;
  final String familyId;
  final String challengerBundleHash;
  final String executionId;
  final String trustedRunnerReleaseHash;
  final int alphaCostMicros;
  final String state;
  final int begunAtMs;
}

class ProductionHoldoutAccessRecord {
  const ProductionHoldoutAccessRecord({
    required this.accessId,
    required this.tokenId,
    required this.familyId,
    required this.challengerBundleHash,
    required this.trustedRunnerReleaseHash,
    required this.alphaCostMicros,
    required this.begunAtMs,
  });

  final String accessId;
  final String tokenId;
  final String familyId;
  final String challengerBundleHash;
  final String trustedRunnerReleaseHash;
  final int alphaCostMicros;
  final int begunAtMs;
}

/// SQLite authority for holdout access budgets and single-use confirmation
/// tokens. Consumption, alpha spending, public confirmation, and token state
/// transition commit in one `BEGIN IMMEDIATE` transaction.
class AgentEvaluationHoldoutStore {
  AgentEvaluationHoldoutStore({
    required this.db,
    required this.trustedHoldoutVerifier,
  });

  final Database db;
  final AgentEvaluationTrustedHoldoutVerifier trustedHoldoutVerifier;

  String get trustedHoldoutPolicyHash => trustedHoldoutVerifier.trustPolicyHash;

  SchemaCompatibilityContractRecord assertCompatible({
    required int readerVersion,
    required int writerVersion,
  }) {
    final rows = db.select('''SELECT * FROM schema_compatibility_contracts
         ORDER BY schema_version DESC LIMIT 1''');
    if (rows.length != 1) {
      throw const AgentEvaluationHoldoutException(
        'schema compatibility contract is missing',
      );
    }
    final row = rows.single;
    final schemaVersion = row['schema_version'] as int;
    final minReader = row['min_reader_version'] as int;
    final minWriter = row['min_writer_version'] as int;
    if (readerVersion < minReader ||
        writerVersion < minWriter ||
        readerVersion > schemaVersion ||
        writerVersion > schemaVersion) {
      throw AgentEvaluationHoldoutConflict(
        'reader/writer version is incompatible with schema $schemaVersion',
      );
    }
    return SchemaCompatibilityContractRecord(
      schemaVersion: schemaVersion,
      minReaderVersion: minReader,
      minWriterVersion: minWriter,
      upgradePolicyJson: row['upgrade_policy_json'] as String,
      rollbackPolicyJson: row['rollback_policy_json'] as String,
    );
  }

  void createFamily({
    required String familyId,
    required String scenarioSetReleaseHash,
    required String holdoutAccessPolicyHash,
    required int maxAccesses,
    required int alphaBudgetMicros,
    required int createdAtMs,
  }) {
    _requireIdentity(familyId, 'familyId');
    _requireDigest(scenarioSetReleaseHash, 'scenarioSetReleaseHash');
    _requireDigest(holdoutAccessPolicyHash, 'holdoutAccessPolicyHash');
    if (maxAccesses <= 0 || alphaBudgetMicros <= 0 || createdAtMs < 0) {
      throw const AgentEvaluationHoldoutException('invalid family policy');
    }
    if (holdoutAccessPolicyHash != trustedHoldoutPolicyHash) {
      throw const AgentEvaluationHoldoutConflict(
        'family holdout policy does not match the pinned trust root',
      );
    }
    try {
      db.execute(
        '''INSERT INTO eval_experiment_families (
             family_id, scenario_set_release_hash, holdout_access_policy_hash,
             max_accesses, used_accesses, alpha_budget_micros,
             alpha_spent_micros, status, created_at_ms, updated_at_ms
           ) VALUES (?, ?, ?, ?, 0, ?, 0, 'active', ?, ?)''',
        <Object?>[
          familyId,
          scenarioSetReleaseHash,
          holdoutAccessPolicyHash,
          maxAccesses,
          alphaBudgetMicros,
          createdAtMs,
          createdAtMs,
        ],
      );
    } on SqliteException catch (error) {
      throw AgentEvaluationHoldoutConflict('family insert conflict: $error');
    }
  }

  /// Freezes distinct public-regression and opaque-production scenario
  /// authorities. [opaqueHoldoutScenarioSetHash] is only a commitment and is
  /// deliberately not a foreign key to the authoring scenario registry.
  void createProductionFamily({
    required String familyId,
    required String productionAuthorityHash,
    required String regressionScenarioSetHash,
    required String opaqueHoldoutScenarioSetHash,
    required String privatePlanHash,
    required String holdoutAccessPolicyHash,
    required int maxAccesses,
    required int alphaBudgetMicros,
    required int createdAtMs,
  }) {
    _requireIdentity(familyId, 'familyId');
    for (final value in <(String, String)>[
      (regressionScenarioSetHash, 'regressionScenarioSetHash'),
      (opaqueHoldoutScenarioSetHash, 'opaqueHoldoutScenarioSetHash'),
      (privatePlanHash, 'privatePlanHash'),
      (holdoutAccessPolicyHash, 'holdoutAccessPolicyHash'),
      (productionAuthorityHash, 'productionAuthorityHash'),
    ]) {
      _requireDigest(value.$1, value.$2);
    }
    if (regressionScenarioSetHash == opaqueHoldoutScenarioSetHash ||
        maxAccesses <= 0 ||
        alphaBudgetMicros <= 0 ||
        createdAtMs < 0) {
      throw const AgentEvaluationHoldoutException(
        'invalid production family policy',
      );
    }
    if (holdoutAccessPolicyHash != trustedHoldoutPolicyHash) {
      throw const AgentEvaluationHoldoutConflict(
        'family holdout policy does not match the pinned trust root',
      );
    }
    try {
      db.execute(
        '''INSERT OR IGNORE INTO eval_experiment_families (
             family_id, scenario_set_release_hash,
             opaque_holdout_scenario_set_hash, private_plan_hash,
             production_authority_hash,
             holdout_access_policy_hash, max_accesses, used_accesses,
             alpha_budget_micros, alpha_spent_micros, status,
             created_at_ms, updated_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, 0, 'active', ?, ?)''',
        <Object?>[
          familyId,
          regressionScenarioSetHash,
          opaqueHoldoutScenarioSetHash,
          privatePlanHash,
          productionAuthorityHash,
          holdoutAccessPolicyHash,
          maxAccesses,
          alphaBudgetMicros,
          createdAtMs,
          createdAtMs,
        ],
      );
      final rows = db.select(
        '''SELECT * FROM eval_experiment_families
           WHERE production_authority_hash = ?''',
        <Object?>[productionAuthorityHash],
      );
      if (rows.length != 1 ||
          rows.single['family_id'] != familyId ||
          rows.single['scenario_set_release_hash'] !=
              regressionScenarioSetHash ||
          rows.single['opaque_holdout_scenario_set_hash'] !=
              opaqueHoldoutScenarioSetHash ||
          rows.single['private_plan_hash'] != privatePlanHash ||
          rows.single['holdout_access_policy_hash'] !=
              holdoutAccessPolicyHash ||
          rows.single['max_accesses'] != maxAccesses ||
          rows.single['alpha_budget_micros'] != alphaBudgetMicros) {
        throw const AgentEvaluationHoldoutConflict(
          'production family authority conflicts with existing identity',
        );
      }
    } on SqliteException catch (error) {
      throw AgentEvaluationHoldoutConflict(
        'production family insert conflict: $error',
      );
    }
  }

  void registerChallenger({
    required String familyId,
    required String challengerBundleHash,
    required int registeredAtMs,
  }) {
    _requireIdentity(familyId, 'familyId');
    _requireDigest(challengerBundleHash, 'challengerBundleHash');
    if (registeredAtMs < 0) {
      throw const AgentEvaluationHoldoutException('invalid registration time');
    }
    try {
      db.execute(
        '''INSERT INTO eval_family_challengers (
             family_id, challenger_bundle_hash, registered_at_ms
           ) VALUES (?, ?, ?)''',
        <Object?>[familyId, challengerBundleHash, registeredAtMs],
      );
    } on SqliteException catch (error) {
      throw AgentEvaluationHoldoutConflict(
        'challenger is unregistered or already registered: $error',
      );
    }
  }

  void issueToken({
    required String tokenId,
    required String familyId,
    required String challengerBundleHash,
    required String regressionVerdictHash,
    required int alphaCostMicros,
    required int issuedAtMs,
  }) {
    _requireIdentity(tokenId, 'tokenId');
    _requireIdentity(familyId, 'familyId');
    _requireDigest(challengerBundleHash, 'challengerBundleHash');
    _requireDigest(regressionVerdictHash, 'regressionVerdictHash');
    if (alphaCostMicros <= 0 || issuedAtMs < 0) {
      throw const AgentEvaluationHoldoutException('invalid token policy');
    }
    _inImmediateTransaction(() {
      final familyRows = db.select(
        '''SELECT f.*, c.challenger_bundle_hash AS winner_bundle_hash,
             v.verdict_hash AS regression_verdict_hash
           FROM eval_experiment_families f
           JOIN eval_family_challengers c ON c.family_id = f.family_id
           JOIN eval_release_gate_verdicts v
             ON v.verdict_kind = 'regression'
             AND v.status = 'promote'
             AND v.challenger_bundle_hash = c.challenger_bundle_hash
             AND v.policy_hash = ? AND v.gate_release_hash = ?
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
             AND d.authority_release_hash = ?
           JOIN eval_executions x ON x.execution_id = v.execution_id
             AND x.experiment_id = v.experiment_id
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
             AND e.scenario_set_release_hash = f.scenario_set_release_hash
           WHERE f.family_id = ? AND f.status = 'active' ''',
        <Object?>[
          AgentEvaluationStandardGatePolicy.policyHash,
          AgentEvaluationStandardGatePolicy.gateReleaseHash,
          AgentEvaluationStandardGatePolicy.gateReleaseHash,
          familyId,
        ],
      );
      if (familyRows.length != 1 ||
          familyRows.single['winner_bundle_hash'] != challengerBundleHash ||
          familyRows.single['regression_verdict_hash'] !=
              regressionVerdictHash) {
        throw const AgentEvaluationHoldoutConflict(
          'family has no unique authority-derived regression winner',
        );
      }
      final family = familyRows.single;
      if ((family['used_accesses'] as int) >= (family['max_accesses'] as int) ||
          (family['alpha_spent_micros'] as int) + alphaCostMicros >
              (family['alpha_budget_micros'] as int)) {
        throw const AgentEvaluationHoldoutConflict(
          'family access or alpha budget is exhausted',
        );
      }
      try {
        db.execute(
          '''INSERT INTO eval_holdout_tokens (
               token_id, family_id, challenger_bundle_hash, alpha_cost_micros,
               state, issued_at_ms, regression_verdict_hash
             ) VALUES (?, ?, ?, ?, 'issued', ?, ?)''',
          <Object?>[
            tokenId,
            familyId,
            challengerBundleHash,
            alphaCostMicros,
            issuedAtMs,
            regressionVerdictHash,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationHoldoutConflict('token issue conflict: $error');
      }
    });
  }

  /// Spends the access and alpha budget before the trusted runner may resolve
  /// any holdout fixture. A crash after this point remains a spent access.
  HoldoutAccessRecord beginHoldoutAccess({
    required String accessId,
    required String tokenId,
    required String challengerBundleHash,
    required String executionId,
    required String trustedRunnerReleaseHash,
    required int begunAtMs,
  }) {
    _requireIdentity(accessId, 'accessId');
    _requireIdentity(tokenId, 'tokenId');
    _requireDigest(challengerBundleHash, 'challengerBundleHash');
    _requireIdentity(executionId, 'executionId');
    _requireDigest(trustedRunnerReleaseHash, 'trustedRunnerReleaseHash');
    if (trustedRunnerReleaseHash !=
        AgentEvaluationTrustedHoldoutRunnerPolicy.releaseHash) {
      throw const AgentEvaluationHoldoutConflict(
        'holdout access requires the frozen trusted runner release',
      );
    }
    if (begunAtMs < 0) {
      throw const AgentEvaluationHoldoutException(
        'invalid holdout access time',
      );
    }
    return _inImmediateTransaction(() {
      final rows = db.select(
        '''SELECT t.*, f.scenario_set_release_hash, f.max_accesses,
             f.used_accesses, f.alpha_budget_micros, f.alpha_spent_micros,
             f.status AS family_status, f.holdout_access_policy_hash,
             e.manifest_json
           FROM eval_holdout_tokens t
           JOIN eval_experiment_families f ON f.family_id = t.family_id
           JOIN eval_executions x ON x.execution_id = ?
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           WHERE t.token_id = ?''',
        <Object?>[executionId, tokenId],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationHoldoutConflict('holdout token not found');
      }
      final token = rows.single;
      if (token['state'] != 'issued' ||
          token['challenger_bundle_hash'] != challengerBundleHash ||
          token['regression_verdict_hash'] == null) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout token is spent or bound to another challenger',
        );
      }
      final manifest = _jsonObject(
        token['manifest_json'] as String,
        'holdout experiment manifest',
      );
      final policy = manifest['holdoutAccessPolicy'];
      if (policy is! Map<String, Object?> ||
          policy['policyHash'] != token['holdout_access_policy_hash']) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout execution policy does not match the experiment family',
        );
      }
      final executionRows = db.select(
        '''SELECT x.status FROM eval_executions x
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           WHERE x.execution_id = ? AND e.scenario_set_release_hash = ?
             AND x.status IN ('created', 'ready')''',
        <Object?>[executionId, token['scenario_set_release_hash']],
      );
      if (executionRows.length != 1) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout execution must be preregistered and not yet started',
        );
      }
      final familyId = token['family_id'] as String;
      final alphaCost = token['alpha_cost_micros'] as int;
      if (token['family_status'] != 'active' ||
          (token['used_accesses'] as int) >= (token['max_accesses'] as int) ||
          (token['alpha_spent_micros'] as int) + alphaCost >
              (token['alpha_budget_micros'] as int)) {
        throw const AgentEvaluationHoldoutConflict(
          'family access or alpha budget is exhausted',
        );
      }
      db.execute(
        '''UPDATE eval_holdout_tokens
           SET state = 'consumed', consumed_at_ms = ?
           WHERE token_id = ? AND state = 'issued' AND consumed_at_ms IS NULL''',
        <Object?>[begunAtMs, tokenId],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout token consumption raced',
        );
      }
      db.execute(
        '''UPDATE eval_experiment_families
           SET used_accesses = used_accesses + 1,
             alpha_spent_micros = alpha_spent_micros + ?,
             status = CASE
               WHEN used_accesses + 1 >= max_accesses
                 OR alpha_spent_micros + ? >= alpha_budget_micros
               THEN 'exhausted' ELSE 'active' END,
             updated_at_ms = ?
           WHERE family_id = ? AND status = 'active'
             AND used_accesses < max_accesses
             AND alpha_spent_micros + ? <= alpha_budget_micros''',
        <Object?>[alphaCost, alphaCost, begunAtMs, familyId, alphaCost],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationHoldoutConflict(
          'family budget consumption raced',
        );
      }
      try {
        db.execute(
          '''INSERT INTO eval_holdout_accesses (
               access_id, token_id, family_id, challenger_bundle_hash,
               execution_id, trusted_runner_release_hash, alpha_cost_micros,
               state, begun_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?, ?, 'begun', ?)''',
          <Object?>[
            accessId,
            tokenId,
            familyId,
            challengerBundleHash,
            executionId,
            trustedRunnerReleaseHash,
            alphaCost,
            begunAtMs,
          ],
        );
      } on SqliteException catch (error) {
        throw AgentEvaluationHoldoutConflict(
          'holdout access begin conflict: $error',
        );
      }
      return HoldoutAccessRecord(
        accessId: accessId,
        tokenId: tokenId,
        familyId: familyId,
        challengerBundleHash: challengerBundleHash,
        executionId: executionId,
        trustedRunnerReleaseHash: trustedRunnerReleaseHash,
        alphaCostMicros: alphaCost,
        state: 'begun',
        begunAtMs: begunAtMs,
      );
    });
  }

  /// Spends the one-use token and alpha budget before a private production
  /// process is launched. The trusted wall clock is captured internally;
  /// callers cannot backdate the access.
  ProductionHoldoutAccessRecord beginProductionHoldoutAccess({
    required String accessId,
    required String tokenId,
    required String challengerBundleHash,
  }) {
    _requireIdentity(accessId, 'accessId');
    _requireIdentity(tokenId, 'tokenId');
    _requireDigest(challengerBundleHash, 'challengerBundleHash');
    final begunAtMs = DateTime.now().millisecondsSinceEpoch;
    final trustedRunnerReleaseHash = trustedHoldoutVerifier.runnerReleaseHash;
    return _inImmediateTransaction(() {
      final rows = db.select(
        '''SELECT t.*, f.max_accesses, f.used_accesses,
             f.alpha_budget_micros, f.alpha_spent_micros,
             f.status AS family_status,
             f.opaque_holdout_scenario_set_hash, f.private_plan_hash
           FROM eval_holdout_tokens t
           JOIN eval_experiment_families f ON f.family_id = t.family_id
           WHERE t.token_id = ?''',
        <Object?>[tokenId],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationHoldoutConflict('holdout token not found');
      }
      final token = rows.single;
      if (token['state'] != 'issued' ||
          token['challenger_bundle_hash'] != challengerBundleHash ||
          token['regression_verdict_hash'] == null ||
          token['opaque_holdout_scenario_set_hash'] == null ||
          token['private_plan_hash'] == null) {
        throw const AgentEvaluationHoldoutConflict(
          'token is spent, legacy-only, or bound to another challenger',
        );
      }
      final familyId = token['family_id'] as String;
      final alphaCost = token['alpha_cost_micros'] as int;
      if (token['family_status'] != 'active' ||
          (token['used_accesses'] as int) >= (token['max_accesses'] as int) ||
          (token['alpha_spent_micros'] as int) + alphaCost >
              (token['alpha_budget_micros'] as int)) {
        throw const AgentEvaluationHoldoutConflict(
          'family access or alpha budget is exhausted',
        );
      }
      db.execute(
        '''UPDATE eval_holdout_tokens
           SET state = 'consumed', consumed_at_ms = ?
           WHERE token_id = ? AND state = 'issued' AND consumed_at_ms IS NULL''',
        <Object?>[begunAtMs, tokenId],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout token consumption raced',
        );
      }
      db.execute(
        '''UPDATE eval_experiment_families
           SET used_accesses = used_accesses + 1,
             alpha_spent_micros = alpha_spent_micros + ?,
             status = CASE
               WHEN used_accesses + 1 >= max_accesses
                 OR alpha_spent_micros + ? >= alpha_budget_micros
               THEN 'exhausted' ELSE 'active' END,
             updated_at_ms = ?
           WHERE family_id = ? AND status = 'active'
             AND used_accesses < max_accesses
             AND alpha_spent_micros + ? <= alpha_budget_micros''',
        <Object?>[alphaCost, alphaCost, begunAtMs, familyId, alphaCost],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationHoldoutConflict(
          'family budget consumption raced',
        );
      }
      db.execute(
        '''INSERT INTO eval_production_holdout_accesses (
             access_id, token_id, family_id, challenger_bundle_hash,
             trusted_runner_release_hash, alpha_cost_micros, state,
             begun_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, 'begun', ?)''',
        <Object?>[
          accessId,
          tokenId,
          familyId,
          challengerBundleHash,
          trustedRunnerReleaseHash,
          alphaCost,
          begunAtMs,
        ],
      );
      return ProductionHoldoutAccessRecord(
        accessId: accessId,
        tokenId: tokenId,
        familyId: familyId,
        challengerBundleHash: challengerBundleHash,
        trustedRunnerReleaseHash: trustedRunnerReleaseHash,
        alphaCostMicros: alphaCost,
        begunAtMs: begunAtMs,
      );
    });
  }

  /// Seals a non-diagnostic confirmation from a stored holdout gate verdict.
  /// The caller cannot choose the public result.
  Future<HoldoutConfirmationRecord> sealTrustedHoldoutConfirmation({
    required String confirmationId,
    required String accessId,
    required String gateVerdictHash,
    required int sealedAtMs,
    required AgentEvaluationTrustedHoldoutAttestation attestation,
  }) async {
    _requireIdentity(confirmationId, 'confirmationId');
    _requireIdentity(accessId, 'accessId');
    _requireDigest(gateVerdictHash, 'gateVerdictHash');
    final trustedNowMs = DateTime.now().millisecondsSinceEpoch;
    if (sealedAtMs < 0) {
      throw const AgentEvaluationHoldoutException(
        'invalid holdout confirmation time',
      );
    }
    if (!await trustedHoldoutVerifier.verify(
      attestation,
      nowMs: trustedNowMs,
    )) {
      throw const AgentEvaluationHoldoutConflict(
        'trusted holdout attestation signature, key, release, or TTL is invalid',
      );
    }
    return _inImmediateTransaction(() {
      final rows = db.select(
        '''SELECT a.*, v.verdict_kind, v.status AS verdict_status,
             v.champion_bundle_hash AS verdict_champion_bundle_hash,
             v.execution_id AS verdict_execution_id,
             v.experiment_id AS verdict_experiment_id,
             v.challenger_bundle_hash AS verdict_challenger_bundle_hash,
             v.policy_hash AS verdict_policy_hash,
             v.gate_release_hash AS verdict_gate_release_hash,
             s.scope, s.scope_key, x.status AS execution_status,
             x.experiment_id AS access_experiment_id,
             e.scenario_set_release_hash AS execution_scenario_set_release_hash,
             e.evaluation_bundle_hash AS execution_evaluation_bundle_hash,
             f.scenario_set_release_hash AS family_scenario_set_release_hash,
             f.holdout_access_policy_hash, d.authority_release_hash,
             t.regression_verdict_hash
           FROM eval_holdout_accesses a
           JOIN eval_holdout_tokens t ON t.token_id = a.token_id
           JOIN eval_release_gate_verdicts v ON v.verdict_hash = ?
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
           JOIN eval_scorecards s ON s.scorecard_hash = v.scorecard_hash
           JOIN eval_executions x ON x.execution_id = a.execution_id
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           JOIN eval_experiment_families f ON f.family_id = a.family_id
           WHERE a.access_id = ?''',
        <Object?>[gateVerdictHash, accessId],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout access or gate verdict is missing',
        );
      }
      final row = rows.single;
      if (row['state'] != 'begun' ||
          row['holdout_access_policy_hash'] != trustedHoldoutPolicyHash ||
          row['authority_release_hash'] !=
              AgentEvaluationStandardGatePolicy.gateReleaseHash ||
          row['verdict_policy_hash'] !=
              AgentEvaluationStandardGatePolicy.policyHash ||
          row['verdict_gate_release_hash'] !=
              AgentEvaluationStandardGatePolicy.gateReleaseHash ||
          row['verdict_kind'] != 'holdout' ||
          row['verdict_execution_id'] != row['execution_id'] ||
          row['verdict_experiment_id'] != row['access_experiment_id'] ||
          row['verdict_challenger_bundle_hash'] !=
              row['challenger_bundle_hash'] ||
          row['execution_scenario_set_release_hash'] !=
              row['family_scenario_set_release_hash'] ||
          row['execution_status'] != 'completed' ||
          row['scope'] != 'execution' ||
          row['scope_key'] != row['execution_id']) {
        throw const AgentEvaluationHoldoutConflict(
          'holdout verdict does not authorize this access',
        );
      }
      final verdictStatus = row['verdict_status'] as String;
      final result = switch (verdictStatus) {
        'promote' => 'pass',
        'reject' => 'fail',
        _ => 'insufficientEvidence',
      };
      if (attestation.familyId != row['family_id'] ||
          attestation.tokenId != row['token_id'] ||
          attestation.accessId != accessId ||
          attestation.regressionVerdictHash != row['regression_verdict_hash'] ||
          attestation.championBundleHash !=
              row['verdict_champion_bundle_hash'] ||
          attestation.challengerBundleHash != row['challenger_bundle_hash'] ||
          attestation.executionId != row['execution_id'] ||
          attestation.scenarioSetReleaseHash !=
              row['family_scenario_set_release_hash'] ||
          attestation.holdoutAccessPolicyHash !=
              row['holdout_access_policy_hash'] ||
          attestation.evaluationBundleHash !=
              row['execution_evaluation_bundle_hash'] ||
          attestation.gatePolicyHash !=
              AgentEvaluationStandardGatePolicy.policyHash ||
          attestation.result != result ||
          attestation.runnerReleaseHash != row['trusted_runner_release_hash']) {
        throw const AgentEvaluationHoldoutConflict(
          'trusted holdout attestation does not bind the authority graph',
        );
      }
      db.execute(
        '''UPDATE eval_holdout_accesses
           SET state = 'sealed', gate_verdict_hash = ?, sealed_at_ms = ?
           WHERE access_id = ? AND state = 'begun'
             AND gate_verdict_hash IS NULL''',
        <Object?>[gateVerdictHash, trustedNowMs, accessId],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationHoldoutConflict('holdout access seal raced');
      }
      final publicResultJson = '{"result":"$result"}';
      db.execute(
        '''INSERT INTO eval_holdout_confirmations (
             confirmation_id, token_id, family_id, challenger_bundle_hash,
             execution_id, result, public_result_json, alpha_cost_micros,
             created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          confirmationId,
          row['token_id'],
          row['family_id'],
          row['challenger_bundle_hash'],
          row['execution_id'],
          result,
          publicResultJson,
          row['alpha_cost_micros'],
          trustedNowMs,
        ],
      );
      db.execute(
        '''INSERT INTO eval_trusted_holdout_attestations (
             attestation_hash, confirmation_id, access_id, key_id,
             runner_release_hash, resolver_release_hash, fixture_release_hash,
             payload_json, signature_base64, issued_at_ms, expires_at_ms,
             created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          attestation.attestationHash,
          confirmationId,
          accessId,
          attestation.keyId,
          attestation.runnerReleaseHash,
          attestation.resolverReleaseHash,
          attestation.fixtureReleaseHash,
          attestation.payloadJson,
          attestation.signatureBase64,
          attestation.issuedAtMs,
          attestation.expiresAtMs,
          trustedNowMs,
        ],
      );
      return HoldoutConfirmationRecord(
        confirmationId: confirmationId,
        tokenId: row['token_id'] as String,
        familyId: row['family_id'] as String,
        challengerBundleHash: row['challenger_bundle_hash'] as String,
        executionId: row['execution_id'] as String,
        result: result,
        publicResultJson: publicResultJson,
        alphaCostMicros: row['alpha_cost_micros'] as int,
        createdAtMs: trustedNowMs,
      );
    });
  }

  HoldoutConfirmationRecord sealHoldoutConfirmation({
    required String confirmationId,
    required String accessId,
    required String gateVerdictHash,
    required int sealedAtMs,
  }) => throw const AgentEvaluationHoldoutConflict(
    'unsigned local holdout confirmation is disabled; use a trusted attestation',
  );

  HoldoutConfirmationRecord consumeToken({
    required String confirmationId,
    required String tokenId,
    required String challengerBundleHash,
    required String executionId,
    required String result,
    required int createdAtMs,
  }) {
    throw const AgentEvaluationHoldoutConflict(
      'legacy caller-supplied holdout results are disabled; begin and seal access instead',
    );
  }

  List<HoldoutConfirmationRecord> readConfirmations(String familyId) {
    _requireIdentity(familyId, 'familyId');
    return db
        .select(
          '''SELECT * FROM eval_holdout_confirmations
             WHERE family_id = ? ORDER BY created_at_ms, confirmation_id''',
          <Object?>[familyId],
        )
        .map(
          (row) => HoldoutConfirmationRecord(
            confirmationId: row['confirmation_id'] as String,
            tokenId: row['token_id'] as String,
            familyId: row['family_id'] as String,
            challengerBundleHash: row['challenger_bundle_hash'] as String,
            executionId: row['execution_id'] as String,
            result: row['result'] as String,
            publicResultJson: row['public_result_json'] as String,
            alphaCostMicros: row['alpha_cost_micros'] as int,
            createdAtMs: row['created_at_ms'] as int,
          ),
        )
        .toList(growable: false);
  }

  T _inImmediateTransaction<T>(T Function() body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static void _requireIdentity(String value, String field) {
    if (value.trim().isEmpty) {
      throw AgentEvaluationHoldoutException('$field is required');
    }
  }

  static void _requireDigest(String value, String field) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw AgentEvaluationHoldoutException(
        '$field must be lowercase SHA-256 hex',
      );
    }
  }

  static Map<String, Object?> _jsonObject(String value, String field) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // Converted below to the authority-specific fail-closed error.
    }
    throw AgentEvaluationHoldoutConflict('$field is malformed');
  }
}
