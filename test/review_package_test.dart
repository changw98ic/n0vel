import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/workspace_types.dart';
import 'package:novel_writer/features/audit/data/review_package.dart';
import 'package:novel_writer/features/review_tasks/domain/review_task_models.dart';

void main() {
  group('ReviewPackageExporter', () {
    test('exports audit issues, suggestions, and metadata', () {
      final exportedAt = DateTime.utc(2026, 5, 25, 17, 45);
      final package = const ReviewPackageExporter().exportPackage(
        metadata: ReviewPackageMetadata(
          packageId: 'review-package-1',
          projectId: 'project-1',
          projectTitle: '雨港档案',
          exportedAt: exportedAt,
          sourceBranch: 'feature/review',
          sourceCommit: 'abc123',
        ),
        auditIssues: const [
          AuditIssueRecord(
            id: 'audit-floor',
            title: '误把仓库当一层',
            evidence: '仓库层数认知与旧港地图不一致。',
            target: '场景 99',
            status: AuditIssueStatus.open,
            lastAction: '等待处理',
          ),
        ],
        reviewTasks: [
          ReviewTask(
            id: 'task-dialog',
            severity: ReviewTaskSeverity.critical,
            status: ReviewTaskStatus.open,
            title: '补强对白压力',
            body: '对话需要更明确的攻防变化。',
            reference: ReviewTaskReference(
              projectId: 'project-1',
              chapterId: 'chapter-1',
              chapterTitle: '第一章',
              sceneId: 'scene-1',
              sceneTitle: '雨夜码头',
            ),
            source: ReviewTaskSource(
              kind: 'scene_review',
              reviewId: 'review-1',
              runId: 'run-1',
              passName: 'judge',
              metadata: {'decision': 'revise'},
            ),
            createdAt: DateTime.utc(2026, 5, 25, 16),
            updatedAt: DateTime.utc(2026, 5, 25, 16, 30),
          ),
        ],
      );

      expect(package.kind, 'n0vel.reviewPackage');
      expect(package.schemaVersion, 1);
      expect(package.metadata.projectTitle, '雨港档案');
      expect(package.issues.single.title, '误把仓库当一层');
      expect(package.issues.single.source.kind, 'audit_issue');
      expect(package.suggestions.single.title, '补强对白压力');
      expect(package.suggestions.single.severity, 'critical');
      expect(package.suggestions.single.source.runId, 'run-1');
      expect(package.summary.issueCount, 1);
      expect(package.summary.suggestionCount, 1);
      expect(package.summary.openCount, 2);
    });

    test(
      'serializes to stable shareable JSON with a self-describing format',
      () {
        final package = const ReviewPackageExporter().exportPackage(
          metadata: ReviewPackageMetadata(
            packageId: 'review-package-1',
            projectId: 'project-1',
            projectTitle: '雨港档案',
            exportedAt: DateTime.utc(2026, 5, 25, 17, 45),
          ),
          auditIssues: const [
            AuditIssueRecord(
              id: 'audit-floor',
              title: '误把仓库当一层',
              evidence: '仓库层数认知与旧港地图不一致。',
              target: '场景 99',
            ),
          ],
        );

        final jsonText = package.toShareableJson();
        final decoded = jsonDecode(jsonText) as Map<String, Object?>;

        expect(decoded['kind'], 'n0vel.reviewPackage');
        expect(decoded['schemaVersion'], 1);
        expect(decoded['format'], isA<Map<String, Object?>>());
        expect(
          decoded['format'],
          containsPair('description', contains('Review package export')),
        );
        expect(decoded['metadata'], containsPair('projectId', 'project-1'));
        expect(decoded['summary'], containsPair('issueCount', 1));
        expect(decoded['issues'], isA<List<Object?>>());
        expect(jsonText, contains('\n  "kind": "n0vel.reviewPackage"'));
      },
    );
  });
}
