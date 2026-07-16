import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_cas_authority.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trusted_holdout.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('executes one release CAS request in an independent process', () async {
    String path(String name, String encoded) {
      final value = Uri.decodeComponent(encoded);
      if (value.isEmpty || !File(value).isAbsolute) {
        throw StateError('$name is missing');
      }
      return value;
    }

    final requestFile = File(
      path(
        'AGENT_EVAL_CAS_REQUEST',
        const String.fromEnvironment('AGENT_EVAL_CAS_REQUEST'),
      ),
    );
    final readyFile = File(
      path(
        'AGENT_EVAL_CAS_READY',
        const String.fromEnvironment('AGENT_EVAL_CAS_READY'),
      ),
    );
    final barrierFile = File(
      path(
        'AGENT_EVAL_CAS_BARRIER',
        const String.fromEnvironment('AGENT_EVAL_CAS_BARRIER'),
      ),
    );
    final receiptFile = File(
      path(
        'AGENT_EVAL_CAS_RECEIPT',
        const String.fromEnvironment('AGENT_EVAL_CAS_RECEIPT'),
      ),
    );
    final request = AgentEvaluationReleaseCasWorkerRequest.fromCanonicalJson(
      requestFile.readAsStringSync(),
    );
    readyFile.createSync(exclusive: true);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!barrierFile.existsSync()) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('release CAS barrier timed out');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final verifier = AgentEvaluationTrustedHoldoutVerifier(
      keyId: request.keyId,
      publicKey: SimplePublicKey(
        base64Decode(request.publicKeyBase64),
        type: KeyPairType.ed25519,
      ),
      runnerReleaseHash: request.runnerReleaseHash,
      resolverReleaseHash: request.resolverReleaseHash,
    );
    final db = sqlite3.open(request.authorityDatabasePath);
    try {
      db.execute('PRAGMA foreign_keys = ON');
      db.execute('PRAGMA busy_timeout = 10000');
      final store = AgentEvaluationReleaseStore(
        db: db,
        trustedHoldoutVerifier: verifier,
      );
      late final String status;
      late final int receiptExitCode;
      late final String errorCode;
      try {
        if (request.action == 'promote') {
          await store.promoteVerified(
            decisionId: request.decisionId,
            channel: request.channel,
            expectedBundleHash: request.expectedBundleHash,
            expectedEpoch: request.expectedEpoch,
            challengerBundleHash: request.challengerBundleHash,
            experimentId: request.experimentId,
            regressionVerdictHash: request.regressionVerdictHash,
            productionHoldoutClaimHash: request.productionHoldoutClaimHash,
            approver: request.approver,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          );
        } else {
          store.rollbackVerified(
            decisionId: request.decisionId,
            channel: request.channel,
            expectedBundleHash: request.expectedBundleHash,
            expectedEpoch: request.expectedEpoch,
            promotionDecisionId: request.promotionDecisionId,
            approver: request.approver,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          );
        }
        status = 'applied';
        receiptExitCode = 0;
        errorCode = 'none';
      } on AgentEvaluationPromotionConflict catch (error) {
        if (!error.message.contains('compare-and-swap failed')) rethrow;
        status = 'casConflict';
        receiptExitCode = 21;
        errorCode = 'release.cas_conflict';
      }
      final head = store.readChannelHead(request.channel);
      final receipt = AgentEvaluationReleaseCasProcessReceipt(
        action: request.action,
        requestHash: request.requestHash,
        processIdentityHash: AgentEvaluationHashes.domainHash(
          'agent-evaluation-release-cas-process-identity-v1',
          <String, Object?>{'pid': pid, 'requestHash': request.requestHash},
        ),
        decisionIdHash: AgentEvaluationReleaseCasAuthority.decisionIdHash(
          request.decisionId,
        ),
        channelHash: AgentEvaluationHashes.domainHash(
          'agent-evaluation-release-cas-channel-v1',
          request.channel,
        ),
        expectedBundleHash: request.expectedBundleHash,
        expectedEpoch: request.expectedEpoch,
        targetBundleHash: request.challengerBundleHash,
        promotionDecisionIdHash: request.action == 'rollback'
            ? AgentEvaluationReleaseCasAuthority.decisionIdHash(
                request.promotionDecisionId,
              )
            : '',
        status: status,
        exitCode: receiptExitCode,
        observedBundleHash: head.bundleHash,
        observedEpoch: head.epoch,
        errorCode: errorCode,
      );
      receiptFile.writeAsStringSync(receipt.canonicalJson, flush: true);
    } finally {
      db.dispose();
    }
  });
}
