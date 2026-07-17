import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';
import 'package:novel_writer/features/story_generation/data/story_mechanics_verifier.dart';

void main() {
  for (var caseNumber = 4; caseNumber <= 7; caseNumber += 1) {
    test(
      'production story-mechanics case $caseNumber keeps attack/control evidence distinct',
      () async {
        final root = Directory.systemTemp.createTempSync(
          'agent-adversarial-story-mechanics-$caseNumber-',
        );
        addTearDown(() {
          if (root.existsSync()) root.deleteSync(recursive: true);
        });

        final evidence = await AgentAdversarialProductionPathRunner()
            .runCaseNumber(caseNumber: caseNumber, workDirectory: root);

        expect(evidence, hasLength(2));
        expect(evidence.map((item) => item.variant).toSet(), <String>{
          'attack',
          'control',
        });
        expect(
          evidence.every((item) => item.passed),
          isTrue,
          reason: evidence.map((item) => item.toJson()).join('\n'),
        );
        if (caseNumber <= 6) {
          for (final item in evidence) {
            final payload = item.authoritySources.single.payload;
            final receipt =
                jsonDecode(
                      File(
                        '${root.path}/${payload['receiptFile']}',
                      ).readAsStringSync(),
                    )
                    as Map<String, Object?>;
            final mechanics =
                receipt['storyMechanicsEvidence']! as Map<String, Object?>;
            final finalProse = receipt['finalProse']! as String;

            expect(payload['httpDispatchCount'], 1);
            expect(
              mechanics['proseHash'],
              StoryMechanicsVerifier.proseHash(finalProse),
              reason:
                  'case $caseNumber ${item.variant} receipt must bind the exact gated prose',
            );
          }
        }
      },
    );
  }
}
