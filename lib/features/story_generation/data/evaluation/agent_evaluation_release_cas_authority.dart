import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_release_store.dart';

class AgentEvaluationReleaseCasAuthorityException implements Exception {
  const AgentEvaluationReleaseCasAuthorityException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationReleaseCasAuthorityException: $message';
}

final class AgentEvaluationReleaseCasWorkerRequest {
  AgentEvaluationReleaseCasWorkerRequest({
    required this.action,
    required this.authorityDatabasePath,
    required this.decisionId,
    required this.channel,
    required this.expectedBundleHash,
    required this.expectedEpoch,
    required this.challengerBundleHash,
    required this.experimentId,
    required this.regressionVerdictHash,
    required this.productionHoldoutClaimHash,
    required this.promotionDecisionId,
    required this.approver,
    required this.keyId,
    required this.publicKeyBase64,
    required this.runnerReleaseHash,
    required this.resolverReleaseHash,
  }) {
    if (!const <String>{'promote', 'rollback'}.contains(action) ||
        authorityDatabasePath.trim().isEmpty ||
        decisionId.trim().isEmpty ||
        channel.trim().isEmpty ||
        experimentId.trim().isEmpty ||
        approver.trim().isEmpty ||
        keyId.trim().isEmpty ||
        publicKeyBase64.trim().isEmpty ||
        expectedEpoch < 0 ||
        (action == 'promote' && expectedEpoch != 0) ||
        (action == 'rollback' && expectedEpoch <= 0) ||
        (action == 'rollback' && promotionDecisionId.trim().isEmpty)) {
      throw ArgumentError('release CAS worker request is incomplete');
    }
    for (final value in <(String, String)>[
      (expectedBundleHash, 'expectedBundleHash'),
      (challengerBundleHash, 'challengerBundleHash'),
      (regressionVerdictHash, 'regressionVerdictHash'),
      (productionHoldoutClaimHash, 'productionHoldoutClaimHash'),
      (runnerReleaseHash, 'runnerReleaseHash'),
      (resolverReleaseHash, 'resolverReleaseHash'),
    ]) {
      AgentEvaluationHashes.requireDigest(value.$1, value.$2);
    }
  }

  final String action;
  final String authorityDatabasePath;
  final String decisionId;
  final String channel;
  final String expectedBundleHash;
  final int expectedEpoch;
  final String challengerBundleHash;
  final String experimentId;
  final String regressionVerdictHash;
  final String productionHoldoutClaimHash;
  final String promotionDecisionId;
  final String approver;
  final String keyId;
  final String publicKeyBase64;
  final String runnerReleaseHash;
  final String resolverReleaseHash;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-release-cas-worker-request-v1',
    'action': action,
    'authorityDatabasePath': authorityDatabasePath,
    'decisionId': decisionId,
    'channel': channel,
    'expectedBundleHash': expectedBundleHash,
    'expectedEpoch': expectedEpoch,
    'challengerBundleHash': challengerBundleHash,
    'experimentId': experimentId,
    'regressionVerdictHash': regressionVerdictHash,
    'productionHoldoutClaimHash': productionHoldoutClaimHash,
    'promotionDecisionId': promotionDecisionId,
    'approver': approver,
    'keyId': keyId,
    'publicKeyBase64': publicKeyBase64,
    'runnerReleaseHash': runnerReleaseHash,
    'resolverReleaseHash': resolverReleaseHash,
  };

  String get requestHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-release-cas-worker-request-v1',
    toCanonicalMap(),
  );

  String get canonicalJson =>
      AgentEvaluationHashes.canonicalJson(toCanonicalMap());

  factory AgentEvaluationReleaseCasWorkerRequest.fromCanonicalJson(
    String source,
  ) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(value) != source ||
        value.keys.toSet().difference(_keys).isNotEmpty ||
        _keys.difference(value.keys.toSet()).isNotEmpty ||
        value['schemaVersion'] !=
            'agent-evaluation-release-cas-worker-request-v1') {
      throw const FormatException('invalid release CAS worker request');
    }
    return AgentEvaluationReleaseCasWorkerRequest(
      action: value['action'] as String,
      authorityDatabasePath: value['authorityDatabasePath'] as String,
      decisionId: value['decisionId'] as String,
      channel: value['channel'] as String,
      expectedBundleHash: value['expectedBundleHash'] as String,
      expectedEpoch: value['expectedEpoch'] as int,
      challengerBundleHash: value['challengerBundleHash'] as String,
      experimentId: value['experimentId'] as String,
      regressionVerdictHash: value['regressionVerdictHash'] as String,
      productionHoldoutClaimHash: value['productionHoldoutClaimHash'] as String,
      promotionDecisionId: value['promotionDecisionId'] as String,
      approver: value['approver'] as String,
      keyId: value['keyId'] as String,
      publicKeyBase64: value['publicKeyBase64'] as String,
      runnerReleaseHash: value['runnerReleaseHash'] as String,
      resolverReleaseHash: value['resolverReleaseHash'] as String,
    );
  }

  static const _keys = <String>{
    'schemaVersion',
    'action',
    'authorityDatabasePath',
    'decisionId',
    'channel',
    'expectedBundleHash',
    'expectedEpoch',
    'challengerBundleHash',
    'experimentId',
    'regressionVerdictHash',
    'productionHoldoutClaimHash',
    'promotionDecisionId',
    'approver',
    'keyId',
    'publicKeyBase64',
    'runnerReleaseHash',
    'resolverReleaseHash',
  };
}

final class AgentEvaluationReleaseCasProcessReceipt {
  AgentEvaluationReleaseCasProcessReceipt({
    required this.action,
    required this.requestHash,
    required this.processIdentityHash,
    required this.decisionIdHash,
    required this.channelHash,
    required this.expectedBundleHash,
    required this.expectedEpoch,
    required this.targetBundleHash,
    required this.promotionDecisionIdHash,
    required this.status,
    required this.exitCode,
    required this.observedBundleHash,
    required this.observedEpoch,
    required this.errorCode,
  }) {
    for (final value in <(String, String)>[
      (requestHash, 'requestHash'),
      (processIdentityHash, 'processIdentityHash'),
      (decisionIdHash, 'decisionIdHash'),
      (channelHash, 'channelHash'),
      (expectedBundleHash, 'expectedBundleHash'),
      (targetBundleHash, 'targetBundleHash'),
      (observedBundleHash, 'observedBundleHash'),
    ]) {
      AgentEvaluationHashes.requireDigest(value.$1, value.$2);
    }
    if (!const <String>{'promote', 'rollback'}.contains(action) ||
        !const <String>{'applied', 'casConflict'}.contains(status) ||
        expectedEpoch < 0 ||
        observedEpoch < 0 ||
        (status == 'applied' && exitCode != 0) ||
        (status == 'casConflict' && exitCode != 21) ||
        (status == 'applied' && errorCode != 'none') ||
        (status == 'casConflict' && errorCode != 'release.cas_conflict') ||
        (action == 'rollback' && promotionDecisionIdHash.length != 64) ||
        (action == 'promote' && promotionDecisionIdHash.isNotEmpty)) {
      throw ArgumentError('release CAS process receipt is invalid');
    }
  }

  final String action;
  final String requestHash;
  final String processIdentityHash;
  final String decisionIdHash;
  final String channelHash;
  final String expectedBundleHash;
  final int expectedEpoch;
  final String targetBundleHash;
  final String promotionDecisionIdHash;
  final String status;
  final int exitCode;
  final String observedBundleHash;
  final int observedEpoch;
  final String errorCode;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-release-cas-process-receipt-v1',
    'authorityReleaseHash': AgentEvaluationReleaseCasAuthority.releaseHash,
    'evidenceLevel': 'purpose-built-audit',
    'releaseAuthorityEligible': false,
    'action': action,
    'requestHash': requestHash,
    'processIdentityHash': processIdentityHash,
    'decisionIdHash': decisionIdHash,
    'channelHash': channelHash,
    'expectedBundleHash': expectedBundleHash,
    'expectedEpoch': expectedEpoch,
    'targetBundleHash': targetBundleHash,
    'promotionDecisionIdHash': promotionDecisionIdHash,
    'status': status,
    'exitCode': exitCode,
    'observedBundleHash': observedBundleHash,
    'observedEpoch': observedEpoch,
    'errorCode': errorCode,
  };

  String get receiptHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-release-cas-process-receipt-v1',
    toCanonicalMap(),
  );

  String get canonicalJson => AgentEvaluationHashes.canonicalJson(
    <String, Object?>{...toCanonicalMap(), 'receiptHash': receiptHash},
  );

  factory AgentEvaluationReleaseCasProcessReceipt.fromCanonicalJson(
    String source,
  ) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(value) != source ||
        value.keys.toSet().difference(_keys).isNotEmpty ||
        _keys.difference(value.keys.toSet()).isNotEmpty ||
        value['schemaVersion'] !=
            'agent-evaluation-release-cas-process-receipt-v1' ||
        value['authorityReleaseHash'] !=
            AgentEvaluationReleaseCasAuthority.releaseHash ||
        value['evidenceLevel'] != 'purpose-built-audit' ||
        value['releaseAuthorityEligible'] != false) {
      throw const FormatException('invalid release CAS process receipt');
    }
    final receipt = AgentEvaluationReleaseCasProcessReceipt(
      action: value['action'] as String,
      requestHash: value['requestHash'] as String,
      processIdentityHash: value['processIdentityHash'] as String,
      decisionIdHash: value['decisionIdHash'] as String,
      channelHash: value['channelHash'] as String,
      expectedBundleHash: value['expectedBundleHash'] as String,
      expectedEpoch: value['expectedEpoch'] as int,
      targetBundleHash: value['targetBundleHash'] as String,
      promotionDecisionIdHash: value['promotionDecisionIdHash'] as String,
      status: value['status'] as String,
      exitCode: value['exitCode'] as int,
      observedBundleHash: value['observedBundleHash'] as String,
      observedEpoch: value['observedEpoch'] as int,
      errorCode: value['errorCode'] as String,
    );
    if (receipt.receiptHash != value['receiptHash']) {
      throw const FormatException('release CAS receipt hash mismatch');
    }
    return receipt;
  }

  static const _keys = <String>{
    'schemaVersion',
    'authorityReleaseHash',
    'evidenceLevel',
    'releaseAuthorityEligible',
    'action',
    'requestHash',
    'processIdentityHash',
    'decisionIdHash',
    'channelHash',
    'expectedBundleHash',
    'expectedEpoch',
    'targetBundleHash',
    'promotionDecisionIdHash',
    'status',
    'exitCode',
    'observedBundleHash',
    'observedEpoch',
    'errorCode',
    'receiptHash',
  };
}

abstract final class AgentEvaluationReleaseCasAuthority {
  static String get releaseHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-release-cas-authority-v1',
    <String, Object?>{
      'processes': 'independent-sqlite-connections-with-barrier-v1',
      'promotion': 'promote-verified-production-claim-v1',
      'rollback': 'authorized-predecessor-cas-v1',
      'expectedOutcome': 'one-applied-one-cas-conflict-per-phase',
      'receipt': 'canonical-hashed-purpose-built-audit-v1',
      'channelHeadReleaseHash':
          AgentEvaluationReleaseStore.channelHeadCasReleaseHash,
      'gatePolicyHash': AgentEvaluationStandardGatePolicy.policyHash,
      'gateReleaseHash': AgentEvaluationStandardGatePolicy.gateReleaseHash,
    },
  );

  static AgentEvaluationReleaseCasProjection verify({
    required Database db,
    required String claimHash,
    required List<AgentEvaluationReleaseCasWorkerRequest> promotionRequests,
    required List<AgentEvaluationReleaseCasProcessReceipt> promotionReceipts,
    required List<AgentEvaluationReleaseCasWorkerRequest> rollbackRequests,
    required List<AgentEvaluationReleaseCasProcessReceipt> rollbackReceipts,
  }) {
    AgentEvaluationHashes.requireDigest(claimHash, 'claimHash');
    _verifyReceiptPair(
      promotionReceipts,
      requests: promotionRequests,
      action: 'promote',
      claimHash: claimHash,
    );
    _verifyReceiptPair(
      rollbackReceipts,
      requests: rollbackRequests,
      action: 'rollback',
      claimHash: claimHash,
    );
    final allProcessHashes = <String>{
      for (final receipt in <AgentEvaluationReleaseCasProcessReceipt>[
        ...promotionReceipts,
        ...rollbackReceipts,
      ])
        receipt.processIdentityHash,
    };
    if (allProcessHashes.length != 4) {
      throw const AgentEvaluationReleaseCasAuthorityException(
        'release CAS evidence did not use four independent processes',
      );
    }
    final promotionApplied = promotionReceipts.singleWhere(
      (receipt) => receipt.status == 'applied',
    );
    final rollbackApplied = rollbackReceipts.singleWhere(
      (receipt) => receipt.status == 'applied',
    );
    if (promotionApplied.observedEpoch != 1 ||
        rollbackApplied.observedEpoch != 2 ||
        rollbackApplied.expectedBundleHash !=
            promotionApplied.targetBundleHash ||
        rollbackApplied.promotionDecisionIdHash !=
            promotionApplied.decisionIdHash ||
        rollbackApplied.channelHash != promotionApplied.channelHash) {
      throw const AgentEvaluationReleaseCasAuthorityException(
        'release CAS phase receipts do not form a promotion/rollback chain',
      );
    }

    final rows = db.select(
      '''SELECT c.claim_hash, c.result AS claim_result,
           c.runner_release_hash, c.resolver_release_hash,
           v.verdict_hash, v.status AS regression_status,
           v.policy_hash, v.gate_release_hash,
           x.status AS execution_status, d.authority_release_hash,
           a.decision_id AS promotion_decision_id,
           pd.channel, pd.from_bundle_hash AS champion_bundle_hash,
           pd.to_bundle_hash AS challenger_bundle_hash,
           pd.from_epoch AS promotion_from_epoch,
           pd.to_epoch AS promotion_to_epoch,
           rd.decision_id AS rollback_decision_id,
           rd.from_epoch AS rollback_from_epoch,
           rd.to_epoch AS rollback_to_epoch,
           h.bundle_hash AS head_bundle_hash, h.epoch AS head_epoch
         FROM eval_production_holdout_claims c
         JOIN prompt_release_decision_production_authorizations a
           ON a.production_holdout_claim_hash = c.claim_hash
           AND a.regression_verdict_hash = c.regression_verdict_hash
         JOIN prompt_release_decisions pd
           ON pd.decision_id = a.decision_id AND pd.action = 'promote'
         JOIN prompt_release_decisions rd
           ON rd.channel = pd.channel AND rd.action = 'rollback'
           AND rd.from_bundle_hash = pd.to_bundle_hash
           AND rd.to_bundle_hash = pd.from_bundle_hash
           AND rd.from_epoch = pd.to_epoch
           AND rd.to_epoch = pd.to_epoch + 1
         JOIN prompt_channel_heads h ON h.channel = pd.channel
         JOIN eval_release_gate_verdicts v
           ON v.verdict_hash = c.regression_verdict_hash
         JOIN eval_release_gate_derivations d
           ON d.verdict_hash = v.verdict_hash
         JOIN eval_executions x ON x.execution_id = v.execution_id
         WHERE c.claim_hash = ?''',
      <Object?>[claimHash],
    );
    if (rows.length != 1) {
      throw const AgentEvaluationReleaseCasAuthorityException(
        'release CAS database authority is missing or ambiguous',
      );
    }
    final row = rows.single;
    final channel = row['channel'] as String;
    final channelDecisionCount =
        db.select(
              'SELECT COUNT(*) AS count FROM prompt_release_decisions '
              'WHERE channel = ?',
              <Object?>[channel],
            ).single['count']
            as int;
    final claimAuthorizationCount =
        db.select(
              'SELECT COUNT(*) AS count '
              'FROM prompt_release_decision_production_authorizations '
              'WHERE production_holdout_claim_hash = ?',
              <Object?>[claimHash],
            ).single['count']
            as int;
    final promotionDecisionIdHash = _decisionIdHash(
      row['promotion_decision_id'] as String,
    );
    final rollbackDecisionIdHash = _decisionIdHash(
      row['rollback_decision_id'] as String,
    );
    if (row['claim_result'] != 'pass' ||
        row['regression_status'] != 'promote' ||
        row['execution_status'] != 'completed' ||
        row['policy_hash'] != AgentEvaluationStandardGatePolicy.policyHash ||
        row['gate_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash ||
        row['authority_release_hash'] !=
            AgentEvaluationStandardGatePolicy.gateReleaseHash ||
        row['promotion_from_epoch'] != 0 ||
        row['promotion_to_epoch'] != 1 ||
        row['rollback_from_epoch'] != 1 ||
        row['rollback_to_epoch'] != 2 ||
        row['head_epoch'] != 2 ||
        row['head_bundle_hash'] != row['champion_bundle_hash'] ||
        channelDecisionCount != 2 ||
        claimAuthorizationCount != 1 ||
        promotionDecisionIdHash != promotionApplied.decisionIdHash ||
        rollbackDecisionIdHash != rollbackApplied.decisionIdHash ||
        promotionApplied.expectedBundleHash != row['champion_bundle_hash'] ||
        promotionApplied.targetBundleHash != row['challenger_bundle_hash'] ||
        rollbackApplied.targetBundleHash != row['champion_bundle_hash']) {
      throw const AgentEvaluationReleaseCasAuthorityException(
        'release CAS database state contradicts its process receipts',
      );
    }
    return AgentEvaluationReleaseCasProjection._(
      claimHash: claimHash,
      regressionVerdictHash: row['verdict_hash'] as String,
      channelHash: promotionApplied.channelHash,
      championBundleHash: row['champion_bundle_hash'] as String,
      challengerBundleHash: row['challenger_bundle_hash'] as String,
      promotionDecisionIdHash: promotionDecisionIdHash,
      rollbackDecisionIdHash: rollbackDecisionIdHash,
      processReceiptHashes: <String>[
        ...promotionReceipts.map((receipt) => receipt.receiptHash),
        ...rollbackReceipts.map((receipt) => receipt.receiptHash),
      ]..sort(),
      processIdentityHashes: allProcessHashes.toList()..sort(),
      decisionCount: channelDecisionCount,
      authorizationCount: claimAuthorizationCount,
    );
  }

  static void _verifyReceiptPair(
    List<AgentEvaluationReleaseCasProcessReceipt> receipts, {
    required List<AgentEvaluationReleaseCasWorkerRequest> requests,
    required String action,
    required String claimHash,
  }) {
    if (receipts.length != 2 ||
        requests.length != 2 ||
        receipts.any((receipt) => receipt.action != action) ||
        requests.any(
          (request) =>
              request.action != action ||
              request.productionHoldoutClaimHash != claimHash,
        ) ||
        receipts.map((receipt) => receipt.status).toSet().length != 2 ||
        receipts.map((receipt) => receipt.decisionIdHash).toSet().length != 2 ||
        receipts.map((receipt) => receipt.processIdentityHash).toSet().length !=
            2 ||
        receipts.map((receipt) => receipt.channelHash).toSet().length != 1 ||
        receipts.map((receipt) => receipt.expectedBundleHash).toSet().length !=
            1 ||
        receipts.map((receipt) => receipt.expectedEpoch).toSet().length != 1 ||
        receipts.map((receipt) => receipt.targetBundleHash).toSet().length !=
            1 ||
        !receipts.any((receipt) => receipt.status == 'applied') ||
        !receipts.any((receipt) => receipt.status == 'casConflict')) {
      throw AgentEvaluationReleaseCasAuthorityException(
        '$action receipts do not prove one applied CAS and one conflict',
      );
    }
    for (final request in requests) {
      final decisionIdHash = _decisionIdHash(request.decisionId);
      final receipt = receipts.singleWhere(
        (candidate) => candidate.decisionIdHash == decisionIdHash,
      );
      final promotionDecisionIdHash = action == 'rollback'
          ? _decisionIdHash(request.promotionDecisionId)
          : '';
      if (receipt.requestHash != request.requestHash ||
          receipt.channelHash !=
              AgentEvaluationHashes.domainHash(
                'agent-evaluation-release-cas-channel-v1',
                request.channel,
              ) ||
          receipt.expectedBundleHash != request.expectedBundleHash ||
          receipt.expectedEpoch != request.expectedEpoch ||
          receipt.targetBundleHash != request.challengerBundleHash ||
          receipt.promotionDecisionIdHash != promotionDecisionIdHash) {
        throw AgentEvaluationReleaseCasAuthorityException(
          '$action receipt does not bind its exact worker request',
        );
      }
    }
  }

  static String _decisionIdHash(String decisionId) =>
      AgentEvaluationHashes.domainHash(
        'agent-evaluation-release-cas-decision-id-v1',
        decisionId,
      );

  static String decisionIdHash(String decisionId) =>
      _decisionIdHash(decisionId);
}

final class AgentEvaluationReleaseCasProjection {
  AgentEvaluationReleaseCasProjection._({
    required this.claimHash,
    required this.regressionVerdictHash,
    required this.channelHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.promotionDecisionIdHash,
    required this.rollbackDecisionIdHash,
    required this.processReceiptHashes,
    required this.processIdentityHashes,
    required this.decisionCount,
    required this.authorizationCount,
  });

  final String claimHash;
  final String regressionVerdictHash;
  final String channelHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String promotionDecisionIdHash;
  final String rollbackDecisionIdHash;
  final List<String> processReceiptHashes;
  final List<String> processIdentityHashes;
  final int decisionCount;
  final int authorizationCount;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-release-cas-projection-v1',
    'authorityReleaseHash': AgentEvaluationReleaseCasAuthority.releaseHash,
    'evidenceLevel': 'purpose-built-audit',
    'releaseAuthorityEligible': false,
    'claimHash': claimHash,
    'regressionVerdictHash': regressionVerdictHash,
    'channelHash': channelHash,
    'championBundleHash': championBundleHash,
    'challengerBundleHash': challengerBundleHash,
    'promotionDecisionIdHash': promotionDecisionIdHash,
    'rollbackDecisionIdHash': rollbackDecisionIdHash,
    'processReceiptHashes': processReceiptHashes,
    'processIdentityHashes': processIdentityHashes,
    'processCount': processIdentityHashes.length,
    'decisionCount': decisionCount,
    'authorizationCount': authorizationCount,
    'promotionOutcome': 'one-applied-one-cas-conflict',
    'rollbackOutcome': 'one-applied-one-cas-conflict',
    'finalEpoch': 2,
  };

  String get projectionHash => AgentEvaluationHashes.domainHash(
    'agent-evaluation-release-cas-projection-v1',
    toCanonicalMap(),
  );

  Map<String, Object?> toReportMap() => <String, Object?>{
    ...toCanonicalMap(),
    'projectionHash': projectionHash,
  };
}
