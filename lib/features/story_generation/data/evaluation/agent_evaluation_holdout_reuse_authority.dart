import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_private_holdout.dart';
import 'agent_evaluation_release_store.dart';

class AgentEvaluationHoldoutReuseAuthorityException implements Exception {
  const AgentEvaluationHoldoutReuseAuthorityException(this.message);

  final String message;

  @override
  String toString() =>
      'AgentEvaluationHoldoutReuseAuthorityException: $message';
}

/// Frozen, read-only proof that one production holdout probe authorized
/// exactly one release decision. This is a projection over the existing V24
/// authorities; it does not issue tokens, run a holdout, or sign claims.
abstract final class AgentEvaluationHoldoutReuseAuthority {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-holdout-reuse-authority-v1',
    <String, Object?>{
      'familyIdentity': 'unique-production-authority-hash-v24',
      'accessBudget': 1,
      'resume': 'same-access-id-readback-no-second-spend-v1',
      'claim': 'one-imported-signed-production-claim-per-access-v2',
      'decision': 'one-production-claim-per-promotion-authorization-v1',
      'publicProjection': 'strict-redacted-document-allowlists-v1',
      'runnerRelease': 'access-and-signed-claim-exact-match',
      'productionRunnerReleaseHash':
          AgentEvaluationProductionHoldoutPolicy.runnerReleaseHash,
      'resolverReleaseHash':
          AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash,
      'gatePolicyHash': AgentEvaluationStandardGatePolicy.policyHash,
      'gateReleaseHash': AgentEvaluationStandardGatePolicy.gateReleaseHash,
      'channelHeadReleaseHash':
          AgentEvaluationReleaseStore.channelHeadCasReleaseHash,
    },
  );

  static AgentEvaluationHoldoutReuseProjection read({
    required Database db,
    required String claimHash,
  }) {
    AgentEvaluationHashes.requireDigest(claimHash, 'claimHash');
    final rows = db.select(
      '''SELECT f.family_id, f.production_authority_hash,
           f.scenario_set_release_hash, f.opaque_holdout_scenario_set_hash,
           f.private_plan_hash, f.holdout_access_policy_hash,
           f.max_accesses, f.used_accesses, f.alpha_budget_micros,
           f.alpha_spent_micros, f.status AS family_status,
           t.token_id, t.state AS token_state,
           t.alpha_cost_micros AS token_alpha_cost_micros,
           a.access_id, a.state AS access_state,
           a.trusted_runner_release_hash,
           a.alpha_cost_micros AS access_alpha_cost_micros,
           c.claim_hash, c.result AS claim_result,
           c.runner_release_hash, c.resolver_release_hash,
           c.regression_verdict_hash, c.champion_bundle_hash,
           c.challenger_bundle_hash,
           c.redacted_execution_summary_json,
           c.redacted_scorecard_json, c.redacted_gate_verdict_json,
           c.redacted_execution_summary_hash,
           c.redacted_scorecard_hash, c.redacted_gate_verdict_hash,
           v.status AS regression_status, v.policy_hash,
           v.gate_release_hash, d.authority_release_hash,
           p.decision_id
         FROM eval_production_holdout_claims c
         JOIN eval_production_holdout_accesses a
           ON a.access_id = c.access_id AND a.token_id = c.token_id
           AND a.family_id = c.family_id
           AND a.challenger_bundle_hash = c.challenger_bundle_hash
         JOIN eval_holdout_tokens t
           ON t.token_id = c.token_id AND t.family_id = c.family_id
           AND t.challenger_bundle_hash = c.challenger_bundle_hash
         JOIN eval_experiment_families f ON f.family_id = c.family_id
         JOIN eval_family_challengers fc
           ON fc.family_id = c.family_id
           AND fc.challenger_bundle_hash = c.challenger_bundle_hash
         JOIN eval_release_gate_verdicts v
           ON v.verdict_hash = c.regression_verdict_hash
         JOIN eval_release_gate_derivations d
           ON d.verdict_hash = v.verdict_hash
         JOIN prompt_release_decision_production_authorizations p
           ON p.production_holdout_claim_hash = c.claim_hash
           AND p.regression_verdict_hash = c.regression_verdict_hash
         WHERE c.claim_hash = ?''',
      <Object?>[claimHash],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationHoldoutReuseAuthorityException(
        'holdout reuse authority is missing or ambiguous',
      );
    }
    final row = rows.single;
    final familyId = row['family_id'] as String;
    final challengerBundleHash = row['challenger_bundle_hash'] as String;
    final privatePlanHash = row['private_plan_hash'];
    final productionAuthorityHash = row['production_authority_hash'];
    if (privatePlanHash is! String || productionAuthorityHash is! String) {
      throw const AgentEvaluationHoldoutReuseAuthorityException(
        'production family commitments are missing',
      );
    }
    for (final value in <(Object?, String)>[
      (productionAuthorityHash, 'productionAuthorityHash'),
      (privatePlanHash, 'privatePlanHash'),
      (row['scenario_set_release_hash'], 'regressionScenarioSetHash'),
      (row['opaque_holdout_scenario_set_hash'], 'opaqueScenarioSetHash'),
      (row['holdout_access_policy_hash'], 'holdoutAccessPolicyHash'),
      (row['regression_verdict_hash'], 'regressionVerdictHash'),
      (row['champion_bundle_hash'], 'championBundleHash'),
      (challengerBundleHash, 'challengerBundleHash'),
    ]) {
      if (value.$1 is! String) {
        throw AgentEvaluationHoldoutReuseAuthorityException(
          '${value.$2} is missing',
        );
      }
      AgentEvaluationHashes.requireDigest(value.$1! as String, value.$2);
    }

    late final AgentEvaluationProductionHoldoutProjection redactedProjection;
    try {
      redactedProjection = AgentEvaluationProductionHoldoutProjection(
        executionSummary: _jsonObject(
          row['redacted_execution_summary_json'] as String,
        ),
        scorecard: _jsonObject(row['redacted_scorecard_json'] as String),
        gateVerdict: _jsonObject(row['redacted_gate_verdict_json'] as String),
      );
    } on Object {
      throw const AgentEvaluationHoldoutReuseAuthorityException(
        'production claim public projection is not strictly redacted',
      );
    }

    final familyCount = _count(
      db,
      'SELECT COUNT(*) AS count FROM eval_experiment_families '
      'WHERE production_authority_hash = ?',
      <Object?>[productionAuthorityHash],
    );
    final challengerCount = _count(
      db,
      'SELECT COUNT(*) AS count FROM eval_family_challengers '
      'WHERE family_id = ? AND challenger_bundle_hash = ?',
      <Object?>[familyId, challengerBundleHash],
    );
    final tokenCount = _count(
      db,
      'SELECT COUNT(*) AS count FROM eval_holdout_tokens '
      'WHERE family_id = ? AND challenger_bundle_hash = ?',
      <Object?>[familyId, challengerBundleHash],
    );
    final accessCount = _count(
      db,
      'SELECT COUNT(*) AS count FROM eval_production_holdout_accesses '
      'WHERE family_id = ? AND challenger_bundle_hash = ?',
      <Object?>[familyId, challengerBundleHash],
    );
    final claimCount = _count(
      db,
      'SELECT COUNT(*) AS count FROM eval_production_holdout_claims '
      'WHERE family_id = ? AND challenger_bundle_hash = ? '
      'AND private_plan_hash = ?',
      <Object?>[familyId, challengerBundleHash, privatePlanHash],
    );
    final authorizationCount = _count(
      db,
      'SELECT COUNT(*) AS count '
      'FROM prompt_release_decision_production_authorizations '
      'WHERE production_holdout_claim_hash = ?',
      <Object?>[claimHash],
    );
    final legacyConfirmationCount = _count(
      db,
      'SELECT COUNT(*) AS count FROM eval_holdout_confirmations '
      'WHERE family_id = ?',
      <Object?>[familyId],
    );

    if (familyCount != 1 ||
        challengerCount != 1 ||
        tokenCount != 1 ||
        accessCount != 1 ||
        claimCount != 1 ||
        authorizationCount != 1 ||
        legacyConfirmationCount != 0 ||
        row['max_accesses'] != 1 ||
        row['used_accesses'] != 1 ||
        row['family_status'] != 'exhausted' ||
        row['alpha_spent_micros'] != row['alpha_budget_micros'] ||
        row['token_state'] != 'consumed' ||
        row['token_alpha_cost_micros'] != row['alpha_spent_micros'] ||
        row['access_state'] != 'imported' ||
        row['access_alpha_cost_micros'] != row['alpha_spent_micros'] ||
        row['claim_result'] != 'pass' ||
        row['regression_status'] != 'promote' ||
        row['trusted_runner_release_hash'] != row['runner_release_hash'] ||
        row['resolver_release_hash'] !=
            AgentEvaluationProductionHoldoutPolicy.resolverReleaseHash ||
        row['policy_hash'] != AgentEvaluationStandardGatePolicy.policyHash ||
        row['gate_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash ||
        row['authority_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash ||
        redactedProjection.result != 'pass' ||
        redactedProjection.executionSummaryHash !=
            row['redacted_execution_summary_hash'] ||
        redactedProjection.scorecardHash != row['redacted_scorecard_hash'] ||
        redactedProjection.gateVerdictHash !=
            row['redacted_gate_verdict_hash']) {
      throw const AgentEvaluationHoldoutReuseAuthorityException(
        'holdout reuse authority does not prove one access, claim, and decision',
      );
    }

    return AgentEvaluationHoldoutReuseProjection._(
      familyId: familyId,
      productionAuthorityHash: productionAuthorityHash,
      tokenId: row['token_id'] as String,
      accessId: row['access_id'] as String,
      claimHash: claimHash,
      decisionId: row['decision_id'] as String,
      regressionVerdictHash: row['regression_verdict_hash'] as String,
      challengerBundleHash: challengerBundleHash,
      privatePlanHash: privatePlanHash,
      holdoutAccessPolicyHash: row['holdout_access_policy_hash'] as String,
      runnerReleaseHash: row['runner_release_hash'] as String,
      alphaBudgetMicros: row['alpha_budget_micros'] as int,
      familyCount: familyCount,
      tokenCount: tokenCount,
      accessCount: accessCount,
      claimCount: claimCount,
      authorizationCount: authorizationCount,
      legacyConfirmationCount: legacyConfirmationCount,
    );
  }

  static int _count(Database db, String sql, List<Object?> parameters) =>
      db.select(sql, parameters).single['count'] as int;

  static Map<String, Object?> _jsonObject(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(value) != source) {
      throw const FormatException('non-canonical projection');
    }
    return value;
  }
}

final class AgentEvaluationHoldoutReuseProjection {
  AgentEvaluationHoldoutReuseProjection._({
    required this.familyId,
    required this.productionAuthorityHash,
    required this.tokenId,
    required this.accessId,
    required this.claimHash,
    required this.decisionId,
    required this.regressionVerdictHash,
    required this.challengerBundleHash,
    required this.privatePlanHash,
    required this.holdoutAccessPolicyHash,
    required this.runnerReleaseHash,
    required this.alphaBudgetMicros,
    required this.familyCount,
    required this.tokenCount,
    required this.accessCount,
    required this.claimCount,
    required this.authorizationCount,
    required this.legacyConfirmationCount,
  });

  final String familyId;
  final String productionAuthorityHash;
  final String tokenId;
  final String accessId;
  final String claimHash;
  final String decisionId;
  final String regressionVerdictHash;
  final String challengerBundleHash;
  final String privatePlanHash;
  final String holdoutAccessPolicyHash;
  final String runnerReleaseHash;
  final int alphaBudgetMicros;
  final int familyCount;
  final int tokenCount;
  final int accessCount;
  final int claimCount;
  final int authorizationCount;
  final int legacyConfirmationCount;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-holdout-reuse-projection-v1',
    'authorityReleaseHash': AgentEvaluationHoldoutReuseAuthority.releaseHash,
    'familyIdHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-holdout-family-id-v1',
      familyId,
    ),
    'productionAuthorityHash': productionAuthorityHash,
    'tokenIdHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-holdout-token-id-v1',
      tokenId,
    ),
    'accessIdHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-holdout-access-id-v1',
      accessId,
    ),
    'claimHash': claimHash,
    'decisionIdHash': AgentEvaluationHashes.domainHash(
      'agent-evaluation-release-decision-id-v1',
      decisionId,
    ),
    'regressionVerdictHash': regressionVerdictHash,
    'challengerBundleHash': challengerBundleHash,
    'privatePlanHash': privatePlanHash,
    'holdoutAccessPolicyHash': holdoutAccessPolicyHash,
    'runnerReleaseHash': runnerReleaseHash,
    'accessBudget': 1,
    'alphaBudgetMicros': alphaBudgetMicros,
    'familyCount': familyCount,
    'tokenCount': tokenCount,
    'accessCount': accessCount,
    'claimCount': claimCount,
    'authorizationCount': authorizationCount,
    'legacyConfirmationCount': legacyConfirmationCount,
    'familyState': 'exhausted',
    'tokenState': 'consumed',
    'accessState': 'imported',
    'claimResult': 'pass',
    'regressionStatus': 'promote',
  };

  String get projectionHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-holdout-reuse-projection-v1',
    toCanonicalMap(),
  );

  Map<String, Object?> toReportMap() => <String, Object?>{
    ...toCanonicalMap(),
    'projectionHash': projectionHash,
  };
}
