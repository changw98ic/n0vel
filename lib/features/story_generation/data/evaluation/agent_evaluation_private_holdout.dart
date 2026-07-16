import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_release_store.dart';
import 'agent_evaluation_trusted_holdout.dart';

abstract final class AgentEvaluationProductionHoldoutPolicy {
  static String get runnerReleaseHash => AgentEvaluationHashes.domainHash(
    'eval-production-holdout-runner-v3',
    <String, Object?>{
      'processBoundary': 'separate-private-production-process',
      'privateInputsDisclosure': 'none',
      'publicProjection': 'allowlisted-redacted-projection-v1',
      'attestation': 'production-attestation-v2-ed25519',
      'pricing': 'compile-time-trust-price-table-and-free-route-policy-v1',
    },
  );

  static String get resolverReleaseHash => AgentEvaluationHashes.domainHash(
    'eval-production-holdout-resolver-v2',
    <String, Object?>{
      'authority': 'spent-production-holdout-access-v1',
      'projection': 'hash-bound-redacted-import-v1',
      'audit': 'private-append-only-root-v1',
    },
  );
}

class AgentEvaluationProductionHoldoutException implements Exception {
  const AgentEvaluationProductionHoldoutException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationProductionHoldoutException: $message';
}

/// The only production-holdout statement accepted by the authoring process.
///
/// All private execution products are represented by commitments. Redacted
/// documents are transported separately and must hash to the three public
/// projection commitments before they can be imported.
final class AgentEvaluationProductionHoldoutAttestation {
  AgentEvaluationProductionHoldoutAttestation({
    required this.familyId,
    required this.tokenId,
    required this.accessId,
    required this.regressionVerdictHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.regressionScenarioSetHash,
    required this.opaqueHoldoutScenarioSetHash,
    required this.privatePlanHash,
    required this.productionManifestHash,
    required this.privateExecutionSummaryHash,
    required this.privateScorecardHash,
    required this.privateGateVerdictHash,
    required this.privateProjectionHash,
    required this.redactedExecutionSummaryHash,
    required this.redactedScorecardHash,
    required this.redactedGateVerdictHash,
    required this.expectedCellSetHash,
    required this.expectedSlotSetHash,
    required this.executionBudgetPolicyHash,
    required this.executorReleaseHash,
    required this.evaluationBundleHash,
    required this.priceTableHash,
    required this.gatePolicyHash,
    required this.auditRootHash,
    required this.result,
    required this.runnerReleaseHash,
    required this.resolverReleaseHash,
    required this.keyId,
    required this.nonce,
    required this.issuedAtMs,
    required this.expiresAtMs,
    required this.signatureBase64,
  }) {
    for (final value in <String>[
      familyId,
      tokenId,
      accessId,
      keyId,
      nonce,
      signatureBase64,
    ]) {
      if (value.trim().isEmpty) {
        throw ArgumentError('production holdout identity is empty');
      }
    }
    for (final digest in <String>[
      regressionVerdictHash,
      championBundleHash,
      challengerBundleHash,
      regressionScenarioSetHash,
      opaqueHoldoutScenarioSetHash,
      privatePlanHash,
      productionManifestHash,
      privateExecutionSummaryHash,
      privateScorecardHash,
      privateGateVerdictHash,
      privateProjectionHash,
      redactedExecutionSummaryHash,
      redactedScorecardHash,
      redactedGateVerdictHash,
      expectedCellSetHash,
      expectedSlotSetHash,
      executionBudgetPolicyHash,
      executorReleaseHash,
      evaluationBundleHash,
      priceTableHash,
      gatePolicyHash,
      auditRootHash,
      runnerReleaseHash,
      resolverReleaseHash,
    ]) {
      AgentEvaluationHashes.requireDigest(digest, 'production attestation');
    }
    if (championBundleHash == challengerBundleHash ||
        !<String>{'pass', 'fail', 'insufficientEvidence'}.contains(result) ||
        issuedAtMs < 0 ||
        expiresAtMs <= issuedAtMs) {
      throw ArgumentError('invalid production holdout attestation');
    }
  }

  static const schemaVersion = 'production-attestation-v2';

  final String familyId;
  final String tokenId;
  final String accessId;
  final String regressionVerdictHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String regressionScenarioSetHash;
  final String opaqueHoldoutScenarioSetHash;
  final String privatePlanHash;
  final String productionManifestHash;
  final String privateExecutionSummaryHash;
  final String privateScorecardHash;
  final String privateGateVerdictHash;
  final String privateProjectionHash;
  final String redactedExecutionSummaryHash;
  final String redactedScorecardHash;
  final String redactedGateVerdictHash;
  final String expectedCellSetHash;
  final String expectedSlotSetHash;
  final String executionBudgetPolicyHash;
  final String executorReleaseHash;
  final String evaluationBundleHash;
  final String priceTableHash;
  final String gatePolicyHash;
  final String auditRootHash;
  final String result;
  final String runnerReleaseHash;
  final String resolverReleaseHash;
  final String keyId;
  final String nonce;
  final int issuedAtMs;
  final int expiresAtMs;
  final String signatureBase64;

  Map<String, Object?> get payload => <String, Object?>{
    'schemaVersion': schemaVersion,
    'familyId': familyId,
    'tokenId': tokenId,
    'accessId': accessId,
    'regressionVerdictHash': regressionVerdictHash,
    'championBundleHash': championBundleHash,
    'challengerBundleHash': challengerBundleHash,
    'regressionScenarioSetHash': regressionScenarioSetHash,
    'opaqueHoldoutScenarioSetHash': opaqueHoldoutScenarioSetHash,
    'privatePlanHash': privatePlanHash,
    'productionManifestHash': productionManifestHash,
    'privateExecutionSummaryHash': privateExecutionSummaryHash,
    'privateScorecardHash': privateScorecardHash,
    'privateGateVerdictHash': privateGateVerdictHash,
    'privateProjectionHash': privateProjectionHash,
    'redactedExecutionSummaryHash': redactedExecutionSummaryHash,
    'redactedScorecardHash': redactedScorecardHash,
    'redactedGateVerdictHash': redactedGateVerdictHash,
    'expectedCellSetHash': expectedCellSetHash,
    'expectedSlotSetHash': expectedSlotSetHash,
    'executionBudgetPolicyHash': executionBudgetPolicyHash,
    'executorReleaseHash': executorReleaseHash,
    'evaluationBundleHash': evaluationBundleHash,
    'priceTableHash': priceTableHash,
    'gatePolicyHash': gatePolicyHash,
    'auditRootHash': auditRootHash,
    'result': result,
    'runnerReleaseHash': runnerReleaseHash,
    'resolverReleaseHash': resolverReleaseHash,
    'keyId': keyId,
    'nonce': nonce,
    'issuedAtMs': issuedAtMs,
    'expiresAtMs': expiresAtMs,
  };

  String get payloadJson => AgentEvaluationHashes.canonicalJson(payload);

  String get claimHash => AgentEvaluationHashes.domainHash(
    'eval-production-holdout-claim-v2',
    <String, Object?>{'payload': payload, 'signatureBase64': signatureBase64},
  );

  AgentEvaluationProductionHoldoutAttestation copyWith({
    String? result,
    String? accessId,
    String? signatureBase64,
  }) => AgentEvaluationProductionHoldoutAttestation(
    familyId: familyId,
    tokenId: tokenId,
    accessId: accessId ?? this.accessId,
    regressionVerdictHash: regressionVerdictHash,
    championBundleHash: championBundleHash,
    challengerBundleHash: challengerBundleHash,
    regressionScenarioSetHash: regressionScenarioSetHash,
    opaqueHoldoutScenarioSetHash: opaqueHoldoutScenarioSetHash,
    privatePlanHash: privatePlanHash,
    productionManifestHash: productionManifestHash,
    privateExecutionSummaryHash: privateExecutionSummaryHash,
    privateScorecardHash: privateScorecardHash,
    privateGateVerdictHash: privateGateVerdictHash,
    privateProjectionHash: privateProjectionHash,
    redactedExecutionSummaryHash: redactedExecutionSummaryHash,
    redactedScorecardHash: redactedScorecardHash,
    redactedGateVerdictHash: redactedGateVerdictHash,
    expectedCellSetHash: expectedCellSetHash,
    expectedSlotSetHash: expectedSlotSetHash,
    executionBudgetPolicyHash: executionBudgetPolicyHash,
    executorReleaseHash: executorReleaseHash,
    evaluationBundleHash: evaluationBundleHash,
    priceTableHash: priceTableHash,
    gatePolicyHash: gatePolicyHash,
    auditRootHash: auditRootHash,
    result: result ?? this.result,
    runnerReleaseHash: runnerReleaseHash,
    resolverReleaseHash: resolverReleaseHash,
    keyId: keyId,
    nonce: nonce,
    issuedAtMs: issuedAtMs,
    expiresAtMs: expiresAtMs,
    signatureBase64: signatureBase64 ?? this.signatureBase64,
  );

  factory AgentEvaluationProductionHoldoutAttestation.fromStorage({
    required String payloadJson,
    required String signatureBase64,
  }) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(decoded) != payloadJson ||
        decoded.keys.toSet().difference(_payloadKeys).isNotEmpty ||
        _payloadKeys.difference(decoded.keys.toSet()).isNotEmpty ||
        decoded['schemaVersion'] != schemaVersion) {
      throw const FormatException('invalid production attestation payload');
    }
    String string(String key) {
      final value = decoded[key];
      if (value is! String) throw FormatException('invalid $key');
      return value;
    }

    int integer(String key) {
      final value = decoded[key];
      if (value is! int) throw FormatException('invalid $key');
      return value;
    }

    return AgentEvaluationProductionHoldoutAttestation(
      familyId: string('familyId'),
      tokenId: string('tokenId'),
      accessId: string('accessId'),
      regressionVerdictHash: string('regressionVerdictHash'),
      championBundleHash: string('championBundleHash'),
      challengerBundleHash: string('challengerBundleHash'),
      regressionScenarioSetHash: string('regressionScenarioSetHash'),
      opaqueHoldoutScenarioSetHash: string('opaqueHoldoutScenarioSetHash'),
      privatePlanHash: string('privatePlanHash'),
      productionManifestHash: string('productionManifestHash'),
      privateExecutionSummaryHash: string('privateExecutionSummaryHash'),
      privateScorecardHash: string('privateScorecardHash'),
      privateGateVerdictHash: string('privateGateVerdictHash'),
      privateProjectionHash: string('privateProjectionHash'),
      redactedExecutionSummaryHash: string('redactedExecutionSummaryHash'),
      redactedScorecardHash: string('redactedScorecardHash'),
      redactedGateVerdictHash: string('redactedGateVerdictHash'),
      expectedCellSetHash: string('expectedCellSetHash'),
      expectedSlotSetHash: string('expectedSlotSetHash'),
      executionBudgetPolicyHash: string('executionBudgetPolicyHash'),
      executorReleaseHash: string('executorReleaseHash'),
      evaluationBundleHash: string('evaluationBundleHash'),
      priceTableHash: string('priceTableHash'),
      gatePolicyHash: string('gatePolicyHash'),
      auditRootHash: string('auditRootHash'),
      result: string('result'),
      runnerReleaseHash: string('runnerReleaseHash'),
      resolverReleaseHash: string('resolverReleaseHash'),
      keyId: string('keyId'),
      nonce: string('nonce'),
      issuedAtMs: integer('issuedAtMs'),
      expiresAtMs: integer('expiresAtMs'),
      signatureBase64: signatureBase64,
    );
  }

  static const Set<String> _payloadKeys = <String>{
    'schemaVersion',
    'familyId',
    'tokenId',
    'accessId',
    'regressionVerdictHash',
    'championBundleHash',
    'challengerBundleHash',
    'regressionScenarioSetHash',
    'opaqueHoldoutScenarioSetHash',
    'privatePlanHash',
    'productionManifestHash',
    'privateExecutionSummaryHash',
    'privateScorecardHash',
    'privateGateVerdictHash',
    'privateProjectionHash',
    'redactedExecutionSummaryHash',
    'redactedScorecardHash',
    'redactedGateVerdictHash',
    'expectedCellSetHash',
    'expectedSlotSetHash',
    'executionBudgetPolicyHash',
    'executorReleaseHash',
    'evaluationBundleHash',
    'priceTableHash',
    'gatePolicyHash',
    'auditRootHash',
    'result',
    'runnerReleaseHash',
    'resolverReleaseHash',
    'keyId',
    'nonce',
    'issuedAtMs',
    'expiresAtMs',
  };
}

extension AgentEvaluationProductionHoldoutSigning
    on AgentEvaluationHoldoutSigningAuthority {
  Future<AgentEvaluationProductionHoldoutAttestation> signProduction(
    AgentEvaluationProductionHoldoutAttestation unsigned,
  ) async {
    if (unsigned.keyId != keyId || unsigned.signatureBase64 != 'unsigned') {
      throw ArgumentError('production attestation is not unsigned for key');
    }
    return unsigned.copyWith(
      signatureBase64: await signCanonicalPayload(unsigned.payloadJson),
    );
  }
}

extension AgentEvaluationProductionHoldoutVerification
    on AgentEvaluationTrustedHoldoutVerifier {
  /// Verifies the immutable claim identity without applying the import TTL.
  /// Use this only after the authoring DB proves the claim was imported inside
  /// its signed window. A completed import remains valid after that window.
  Future<bool> verifyProductionSignature(
    AgentEvaluationProductionHoldoutAttestation attestation,
  ) async {
    if (attestation.keyId != keyId ||
        attestation.runnerReleaseHash != runnerReleaseHash ||
        attestation.resolverReleaseHash != resolverReleaseHash) {
      return false;
    }
    return verifyCanonicalPayload(
      payloadJson: attestation.payloadJson,
      signatureBase64: attestation.signatureBase64,
    );
  }

  Future<bool> verifyProduction(
    AgentEvaluationProductionHoldoutAttestation attestation, {
    required int nowMs,
  }) async {
    if (nowMs < attestation.issuedAtMs || nowMs >= attestation.expiresAtMs) {
      return false;
    }
    return verifyProductionSignature(attestation);
  }
}

final class AgentEvaluationProductionHoldoutProjection {
  AgentEvaluationProductionHoldoutProjection({
    required this.executionSummary,
    required this.scorecard,
    required this.gateVerdict,
  }) {
    _validateDocument(
      executionSummary,
      schema: 'production-holdout-redacted-execution-summary-v1',
      keys: const <String>{
        'schemaVersion',
        'status',
        'releaseConfigurationHash',
        'executionCommitmentHash',
        'expectedSlotCount',
        'completedSlotCount',
      },
    );
    _validateDocument(
      scorecard,
      schema: 'production-holdout-redacted-scorecard-v1',
      keys: const <String>{
        'schemaVersion',
        'inputSetHash',
        'expectedCellSetHash',
        'expectedSlotSetHash',
        'aggregateCommitmentHash',
      },
    );
    _validateDocument(
      gateVerdict,
      schema: 'production-holdout-redacted-gate-v1',
      keys: const <String>{
        'schemaVersion',
        'status',
        'scorecardHash',
        'projectionHash',
        'policyHash',
        'reasonCodes',
      },
    );
    if (executionSummary['status'] != 'completed' ||
        executionSummary['expectedSlotCount'] is! int ||
        executionSummary['completedSlotCount'] !=
            executionSummary['expectedSlotCount'] ||
        (executionSummary['expectedSlotCount'] as int) <= 0) {
      throw const FormatException('redacted execution is incomplete');
    }
    for (final key in <String>[
      'executionCommitmentHash',
      'releaseConfigurationHash',
      'inputSetHash',
      'expectedCellSetHash',
      'expectedSlotSetHash',
      'aggregateCommitmentHash',
      'scorecardHash',
      'projectionHash',
      'policyHash',
    ]) {
      final value = executionSummary[key] ?? scorecard[key] ?? gateVerdict[key];
      if (value is! String) throw FormatException('invalid $key');
      AgentEvaluationHashes.requireDigest(value, key);
    }
    final status = gateVerdict['status'];
    if (!<String>{
      'promote',
      'reject',
      'insufficientEvidence',
    }.contains(status)) {
      throw const FormatException('invalid redacted gate status');
    }
    final reasons = gateVerdict['reasonCodes'];
    if (reasons is! List<Object?> ||
        reasons.any(
          (value) =>
              value is! String ||
              value.length > 64 ||
              !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value),
        )) {
      throw const FormatException('invalid redacted gate reason codes');
    }
  }

  final Map<String, Object?> executionSummary;
  final Map<String, Object?> scorecard;
  final Map<String, Object?> gateVerdict;

  String get executionSummaryJson =>
      AgentEvaluationHashes.canonicalJson(executionSummary);
  String get scorecardJson => AgentEvaluationHashes.canonicalJson(scorecard);
  String get gateVerdictJson =>
      AgentEvaluationHashes.canonicalJson(gateVerdict);

  String get executionSummaryHash => AgentEvaluationHashes.domainHash(
    'eval-production-holdout-redacted-execution-summary-v1',
    executionSummary,
  );
  String get scorecardHash => AgentEvaluationHashes.domainHash(
    'eval-production-holdout-redacted-scorecard-v1',
    scorecard,
  );
  String get gateVerdictHash => AgentEvaluationHashes.domainHash(
    'eval-production-holdout-redacted-gate-v1',
    gateVerdict,
  );

  String get result => switch (gateVerdict['status']) {
    'promote' => 'pass',
    'reject' => 'fail',
    _ => 'insufficientEvidence',
  };

  static void _validateDocument(
    Map<String, Object?> value, {
    required String schema,
    required Set<String> keys,
  }) {
    if (value['schemaVersion'] != schema ||
        value.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(value.keys.toSet()).isNotEmpty ||
        _containsPrivateMaterial(value)) {
      throw FormatException('invalid or non-redacted $schema document');
    }
  }

  static bool _containsPrivateMaterial(Object? value) {
    const forbidden = <String>{
      'prompt',
      'fact',
      'path',
      'prose',
      'evidence',
      'evaluator',
      'judgeoutput',
      'scenario',
      'response',
    };
    if (value is Map<Object?, Object?>) {
      return value.entries.any((entry) {
        final normalized = entry.key.toString().toLowerCase().replaceAll(
          RegExp('[^a-z0-9]'),
          '',
        );
        return forbidden.any(normalized.contains) ||
            _containsPrivateMaterial(entry.value);
      });
    }
    if (value is Iterable<Object?>) return value.any(_containsPrivateMaterial);
    return false;
  }
}

final class AgentEvaluationProductionHoldoutClaimRecord {
  const AgentEvaluationProductionHoldoutClaimRecord({
    required this.claimHash,
    required this.accessId,
    required this.familyId,
    required this.result,
    required this.importedAtMs,
  });

  final String claimHash;
  final String accessId;
  final String familyId;
  final String result;
  final int importedAtMs;
}

/// Authoring-side importer for a private production run. It deliberately has
/// no caller result, evaluator, path, raw evidence, or timestamp parameters.
final class AgentEvaluationProductionHoldoutImporter {
  AgentEvaluationProductionHoldoutImporter({
    required this.db,
    required this.verifier,
  });

  final Database db;
  final AgentEvaluationTrustedHoldoutVerifier verifier;

  Future<AgentEvaluationProductionHoldoutClaimRecord> import({
    required AgentEvaluationProductionHoldoutAttestation attestation,
    required AgentEvaluationProductionHoldoutProjection projection,
  }) async {
    if (!await verifier.verifyProductionSignature(attestation)) {
      throw const AgentEvaluationProductionHoldoutException(
        'production attestation signature or release is invalid',
      );
    }
    // Capture the trusted import time after signature verification so a slow
    // verifier cannot start inside the window and commit after it expired.
    final trustedNowMs = DateTime.now().millisecondsSinceEpoch;
    if (trustedNowMs < attestation.issuedAtMs ||
        trustedNowMs >= attestation.expiresAtMs) {
      throw const AgentEvaluationProductionHoldoutException(
        'production attestation import TTL is invalid',
      );
    }
    if (attestation.redactedExecutionSummaryHash !=
            projection.executionSummaryHash ||
        attestation.redactedScorecardHash != projection.scorecardHash ||
        attestation.redactedGateVerdictHash != projection.gateVerdictHash ||
        attestation.result != projection.result ||
        projection.scorecard['expectedCellSetHash'] !=
            attestation.expectedCellSetHash ||
        projection.scorecard['expectedSlotSetHash'] !=
            attestation.expectedSlotSetHash ||
        projection.gateVerdict['scorecardHash'] !=
            attestation.privateScorecardHash ||
        projection.gateVerdict['projectionHash'] !=
            attestation.privateProjectionHash ||
        projection.gateVerdict['policyHash'] != attestation.gatePolicyHash) {
      throw const AgentEvaluationProductionHoldoutException(
        'redacted projection does not bind the signed private authority',
      );
    }

    db.execute('BEGIN IMMEDIATE');
    try {
      final rows = db.select(
        '''SELECT a.*, t.regression_verdict_hash,
             f.scenario_set_release_hash AS regression_scenario_set_hash,
             f.opaque_holdout_scenario_set_hash, f.private_plan_hash,
             f.holdout_access_policy_hash,
             v.champion_bundle_hash, v.challenger_bundle_hash,
             v.status AS regression_status, v.policy_hash,
             v.gate_release_hash, d.authority_release_hash
           FROM eval_production_holdout_accesses a
           JOIN eval_holdout_tokens t ON t.token_id = a.token_id
           JOIN eval_experiment_families f ON f.family_id = a.family_id
           JOIN eval_release_gate_verdicts v
             ON v.verdict_hash = t.regression_verdict_hash
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
           WHERE a.access_id = ?''',
        <Object?>[attestation.accessId],
      );
      if (rows.length != 1) {
        throw const AgentEvaluationProductionHoldoutException(
          'spent production holdout authority is missing',
        );
      }
      final row = rows.single;
      if (row['state'] != 'begun' ||
          row['token_id'] != attestation.tokenId ||
          row['family_id'] != attestation.familyId ||
          row['challenger_bundle_hash'] != attestation.challengerBundleHash ||
          row['trusted_runner_release_hash'] != attestation.runnerReleaseHash ||
          row['regression_verdict_hash'] != attestation.regressionVerdictHash ||
          row['regression_scenario_set_hash'] !=
              attestation.regressionScenarioSetHash ||
          row['opaque_holdout_scenario_set_hash'] !=
              attestation.opaqueHoldoutScenarioSetHash ||
          row['private_plan_hash'] != attestation.privatePlanHash ||
          row['holdout_access_policy_hash'] != verifier.trustPolicyHash ||
          row['champion_bundle_hash'] != attestation.championBundleHash ||
          row['challenger_bundle_hash'] != attestation.challengerBundleHash ||
          row['regression_status'] != 'promote' ||
          row['policy_hash'] != AgentEvaluationStandardGatePolicy.policyHash ||
          row['gate_release_hash'] !=
              AgentEvaluationStandardGatePolicy.gateReleaseHash ||
          row['authority_release_hash'] !=
              AgentEvaluationStandardGatePolicy.gateReleaseHash) {
        throw const AgentEvaluationProductionHoldoutException(
          'production attestation does not bind the frozen authority graph',
        );
      }

      db.execute(
        '''INSERT INTO eval_production_holdout_claims (
             claim_hash, access_id, family_id, token_id,
             regression_verdict_hash, champion_bundle_hash,
             challenger_bundle_hash, regression_scenario_set_hash,
             opaque_holdout_scenario_set_hash, private_plan_hash,
             production_manifest_hash, redacted_execution_summary_hash,
             private_execution_summary_hash, redacted_execution_summary_json,
             private_scorecard_hash, redacted_scorecard_hash,
             redacted_scorecard_json, private_gate_verdict_hash,
             redacted_gate_verdict_hash, redacted_gate_verdict_json,
             private_projection_hash, expected_cell_set_hash,
             expected_slot_set_hash, execution_budget_policy_hash,
             executor_release_hash, evaluation_bundle_hash, price_table_hash,
             gate_policy_hash, audit_root_hash, result, key_id,
             runner_release_hash, resolver_release_hash, payload_json,
             signature_base64, issued_at_ms, expires_at_ms, imported_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
             ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          attestation.claimHash,
          attestation.accessId,
          attestation.familyId,
          attestation.tokenId,
          attestation.regressionVerdictHash,
          attestation.championBundleHash,
          attestation.challengerBundleHash,
          attestation.regressionScenarioSetHash,
          attestation.opaqueHoldoutScenarioSetHash,
          attestation.privatePlanHash,
          attestation.productionManifestHash,
          attestation.redactedExecutionSummaryHash,
          attestation.privateExecutionSummaryHash,
          projection.executionSummaryJson,
          attestation.privateScorecardHash,
          attestation.redactedScorecardHash,
          projection.scorecardJson,
          attestation.privateGateVerdictHash,
          attestation.redactedGateVerdictHash,
          projection.gateVerdictJson,
          attestation.privateProjectionHash,
          attestation.expectedCellSetHash,
          attestation.expectedSlotSetHash,
          attestation.executionBudgetPolicyHash,
          attestation.executorReleaseHash,
          attestation.evaluationBundleHash,
          attestation.priceTableHash,
          attestation.gatePolicyHash,
          attestation.auditRootHash,
          attestation.result,
          attestation.keyId,
          attestation.runnerReleaseHash,
          attestation.resolverReleaseHash,
          attestation.payloadJson,
          attestation.signatureBase64,
          attestation.issuedAtMs,
          attestation.expiresAtMs,
          trustedNowMs,
        ],
      );
      db.execute(
        '''UPDATE eval_production_holdout_accesses
           SET state = 'imported', imported_at_ms = ?
           WHERE access_id = ? AND state = 'begun' AND imported_at_ms IS NULL''',
        <Object?>[trustedNowMs, attestation.accessId],
      );
      if (db.updatedRows != 1) {
        throw const AgentEvaluationProductionHoldoutException(
          'production holdout import raced',
        );
      }
      db.execute('COMMIT');
      return AgentEvaluationProductionHoldoutClaimRecord(
        claimHash: attestation.claimHash,
        accessId: attestation.accessId,
        familyId: attestation.familyId,
        result: attestation.result,
        importedAtMs: trustedNowMs,
      );
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}
