import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_promotion_performance_authority.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'case15 pair reopens both sealed matrices through the frozen authority',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'agent-adversarial-case15-',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final evidence = await AgentAdversarialProductionPathRunner()
          .runCaseNumber(caseNumber: 15, workDirectory: root);
      expect(evidence, hasLength(2));
      expect(evidence.every((item) => item.passed), isTrue);
      for (final item in evidence) {
        final payload = item.authoritySources.single.payload;
        expect(
          payload['sutProviderCallCount'],
          540,
          reason:
              '60 sealed slots must each complete all 9 exact-schema production calls',
        );
        final db = sqlite3.open(
          '${root.path}/${payload['databaseFile']}',
          mode: OpenMode.readOnly,
        );
        try {
          final report =
              jsonDecode(
                    File(
                      '${root.path}/${payload['reportFile']}',
                    ).readAsStringSync(),
                  )
                  as Map<String, Object?>;
          final projection =
              AgentEvaluationPromotionPerformanceAuthority.verifyReportMap(
                db: db,
                reportMap: report,
              );
          expect(projection.projectionHash, report['projectionHash']);
          expect(projection.performanceSampleCount, greaterThanOrEqualTo(20));
        } finally {
          db.dispose();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
