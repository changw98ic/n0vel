import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';

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
      },
    );
  }
}
