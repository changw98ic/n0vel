import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  const expectedCandidateProse =
      '柳溪合上账本，指出门框上的新划痕与仓门编号互相印证。'
      '她说：“账本就在七号仓，编号不会说谎。”';

  test(
    'case16 scorer isolation finalizes only enabled pre-quality evidence',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'agent-adversarial-case16-',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });

      final evidence = await AgentAdversarialProductionPathRunner()
          .runCaseNumber(caseNumber: 16, workDirectory: root);

      expect(evidence, hasLength(2));
      expect(
        evidence.every((item) => item.passed),
        isTrue,
        reason: evidence.map((item) => item.toJson()).toList().toString(),
      );
      final attack = evidence.singleWhere((item) => item.variant == 'attack');
      final control = evidence.singleWhere((item) => item.variant == 'control');
      expect(attack.actualOutcome, 'blocked');
      expect(control.actualOutcome, 'accepted');
      expect(
        attack.authoritySources.single.payload['sutOverallMicros'],
        100000000,
      );
      expect(attack.authoritySources.single.payload['judgeAccepted'], isFalse);
      expect(
        control.authoritySources.single.payload['sutOverallMicros'],
        96000000,
      );
      expect(control.authoritySources.single.payload['judgeAccepted'], isTrue);

      for (final item in evidence) {
        final payload = item.authoritySources.single.payload;
        expect(payload['pipelinePhysicalRequests'], 3);
        expect(payload['sutPhysicalRequests'], 1);
        expect(payload['judgePhysicalRequests'], 1);
        final db = sqlite3.open(
          '${root.path}/${payload['databaseFile']}',
          mode: OpenMode.readOnly,
        );
        try {
          final proofRows = db.select(
            'SELECT run_id FROM story_generation_candidate_proofs',
          );
          expect(proofRows, hasLength(1));
          final candidateRows = db.select(
            'SELECT final_prose, quality_payload_json '
            'FROM story_generation_candidate_payloads',
          );
          expect(candidateRows, hasLength(1));
          expect(candidateRows.single['final_prose'], expectedCandidateProse);
          final qualityPayload =
              jsonDecode(candidateRows.single['quality_payload_json'] as String)
                  as Map<String, Object?>;
          final deterministicGate =
              qualityPayload['deterministicGate']! as Map<String, Object?>;
          final preQuality =
              deterministicGate['productionPreQualityEvidence']!
                  as Map<String, Object?>;
          expect(preQuality['passed'], isTrue);
          expect(preQuality['hardGatesEnabled'], isTrue);
          expect(preQuality['candidateFinalizationEligible'], isTrue);
        } finally {
          db.dispose();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
