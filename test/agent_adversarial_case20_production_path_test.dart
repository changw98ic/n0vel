import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';

void main() {
  test(
    'case20 real runner accepts expected safety block without production writes',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'agent-adversarial-case20-',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final evidence = await AgentAdversarialProductionPathRunner()
          .runCaseNumber(caseNumber: 20, workDirectory: root);
      expect(evidence, hasLength(2));
      expect(
        evidence.every((item) => item.passed),
        isTrue,
        reason: evidence.map((item) => item.toJson()).toList().toString(),
      );
      final attack = evidence.singleWhere((item) => item.variant == 'attack');
      final control = evidence.singleWhere((item) => item.variant == 'control');
      for (final item in evidence) {
        final payload = item.authoritySources.single.payload;
        expect(payload['comparisonHardPass'], isTrue);
        expect(payload['productionAuthorityReceiptCount'], 1);
        expect(payload['candidateProofCount'], 1);
        expect(payload['transactionReceiptCount'], 1);
        expect(payload['productionCommitReceiptCount'], 0);
        expect(payload['productionOutboxCount'], 0);
        expect(payload['productionAuthoritativeWriteCount'], 0);
        expect(payload['comparatorInEvaluationBundle'], isTrue);
      }
      expect(attack.actualOutcome, 'blocked');
      expect(attack.authoritySources.single.payload['accepted'], isFalse);
      expect(
        attack.authoritySources.single.payload['failureCodes'],
        contains('safety.blocked'),
      );
      expect(control.actualOutcome, 'accepted');
      expect(control.authoritySources.single.payload['accepted'], isTrue);
      expect(control.authoritySources.single.payload['failureCodes'], isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
