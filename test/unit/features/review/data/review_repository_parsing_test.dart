import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/features/review/data/review_repository.dart';
import 'package:writing_assistant/features/review/domain/review_report.dart';
import 'package:writing_assistant/features/review/domain/review_result.dart';

void main() {
  group('decodeReviewJson', () {
    test('returns null for malformed json', () {
      final decoded = decodeReviewJson('{bad json');

      expect(decoded, isNull);
    });

    test('returns null for non-object payloads', () {
      final decoded = decodeReviewJson('["not","an","object"]');

      expect(decoded, isNull);
    });
  });

  group('buildReviewReport', () {
    test('fills safe defaults for partial payloads', () {
      final report = buildReviewReport(
        taskId: 'task-1',
        chapterId: 'chapter-1',
        json: {
          'issues': [
            {'dimension': 'unknown', 'severity': 'unknown'},
          ],
        },
      );

      expect(report.overallScore, 0);
      expect(report.dimensionScores, isEmpty);
      expect(report.issues, hasLength(1));
      expect(report.issues.single.dimension, ReviewDimension.consistency);
      expect(report.issues.single.severity, IssueSeverity.minor);
      expect(report.issues.single.status, IssueStatus.pending);
      expect(report.issues.single.description, '未提供描述');
      expect(report.minorCount, 1);
    });

    test('preserves valid issue fields when payload is complete', () {
      final report = buildReviewReport(
        taskId: 'task-2',
        chapterId: 'chapter-2',
        json: {
          'overallScore': 88,
          'dimensionScores': {'consistency': 91},
          'issues': [
            {
              'id': 'issue-1',
              'dimension': 'plotLogic',
              'severity': 'critical',
              'status': 'fixed',
              'description': '冲突',
              'suggestion': '修正逻辑',
            },
          ],
        },
      );

      expect(report.overallScore, 88);
      expect(report.dimensionScores['consistency'], 91);
      expect(report.issues.single.id, 'issue-1');
      expect(report.issues.single.dimension, ReviewDimension.plotLogic);
      expect(report.issues.single.severity, IssueSeverity.critical);
      expect(report.issues.single.status, IssueStatus.fixed);
      expect(report.criticalCount, 1);
    });
  });
}
