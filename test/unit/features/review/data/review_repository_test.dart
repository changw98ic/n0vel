import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/features/review/data/review_repository.dart';
import 'package:writing_assistant/features/review/domain/review_report.dart';
import 'package:writing_assistant/features/review/domain/review_result.dart';

void main() {
  late AppDatabase database;
  late ReviewRepository repository;

  setUp(() async {
    database = _TestAppDatabase();
    repository = ReviewRepository(database);
    await _seedWork(database);
    await _seedChapter(
      database,
      id: 'chapter-1',
      title: 'Chapter One',
      sortOrder: 0,
    );
    await _seedChapter(
      database,
      id: 'chapter-2',
      title: 'Chapter Two',
      sortOrder: 1,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'getReviewResults skips malformed payloads and degrades partial data',
    () async {
      await _insertReviewTask(
        database,
        id: 'task-bad',
        result: '{"chapterId":',
      );
      await _insertReviewTask(
        database,
        id: 'task-partial',
        result: jsonEncode({'chapterId': 'chapter-1'}),
      );

      final results = await repository.getReviewResults('work-1');
      final chapterOne = results.firstWhere(
        (result) => result.chapterId == 'chapter-1',
      );
      final chapterTwo = results.firstWhere(
        (result) => result.chapterId == 'chapter-2',
      );

      expect(chapterOne.score, isNull);
      expect(chapterOne.issueCount, 0);
      expect(chapterOne.criticalCount, 0);
      expect(chapterOne.status, ReviewStatus.needsFix);
      expect(chapterOne.reviewedAt, isNotNull);

      expect(chapterTwo.status, ReviewStatus.notReviewed);
      expect(chapterTwo.score, isNull);
    },
  );

  test(
    'getReviewReport applies safe defaults for partial issue payloads',
    () async {
      await _insertReviewTask(
        database,
        id: 'task-report',
        result: jsonEncode({
          'chapterId': 'chapter-1',
          'issues': [
            {'id': 'issue-1', 'severity': 'critical'},
          ],
        }),
      );

      final report = await repository.getReviewReport('chapter-1');

      expect(report, isNotNull);
      expect(report!.overallScore, 0);
      expect(report.dimensionScores, isEmpty);
      expect(report.issues, hasLength(1));
      expect(report.issues.single.id, 'issue-1');
      expect(report.issues.single.dimension, ReviewDimension.consistency);
      expect(report.issues.single.severity, IssueSeverity.critical);
      expect(report.issues.single.status, IssueStatus.pending);
      expect(report.issues.single.description, '未提供描述');
    },
  );

  test(
    'updateIssueStatus ignores malformed tasks and updates the matching issue',
    () async {
      await _insertReviewTask(database, id: 'task-bad', result: '{"issues":');
      await _insertReviewTask(
        database,
        id: 'task-good',
        result: jsonEncode({
          'chapterId': 'chapter-1',
          'issues': [
            {
              'id': 'issue-1',
              'severity': 'major',
              'status': 'pending',
              'description': 'Needs work',
            },
          ],
        }),
      );

      await repository.updateIssueStatus(
        'issue-1',
        IssueStatus.fixed,
        fixedBy: 'tester',
      );

      final updatedTask = await (database.select(
        database.aiTasks,
      )..where((task) => task.id.equals('task-good'))).getSingle();
      final updatedJson =
          jsonDecode(updatedTask.result!) as Map<String, dynamic>;
      final issue =
          (updatedJson['issues'] as List).single as Map<String, dynamic>;

      expect(issue['status'], IssueStatus.fixed.name);
      expect(issue['fixedBy'], 'tester');
      expect(issue['fixedAt'], isA<String>());
    },
  );
}

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase()
    : super.connect(DatabaseConnection(NativeDatabase.memory()));

  @override
  Future<void> createFTSIndexes() async {}
}

Future<void> _seedWork(AppDatabase database) {
  final now = DateTime(2026, 4, 6);
  return database
      .into(database.works)
      .insert(
        WorksCompanion(
          id: const Value('work-1'),
          name: const Value('Work One'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _seedChapter(
  AppDatabase database, {
  required String id,
  required String title,
  required int sortOrder,
}) {
  final now = DateTime(2026, 4, 6, 12);
  return database
      .into(database.chapters)
      .insert(
        ChaptersCompanion(
          id: Value(id),
          volumeId: const Value('volume-1'),
          workId: const Value('work-1'),
          title: Value(title),
          sortOrder: Value(sortOrder),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _insertReviewTask(
  AppDatabase database, {
  required String id,
  required String result,
  String status = 'completed',
}) {
  final now = DateTime(2026, 4, 6, 12, 30);
  return database
      .into(database.aiTasks)
      .insert(
        AiTasksCompanion(
          id: Value(id),
          workId: const Value('work-1'),
          name: const Value('Review task'),
          type: const Value('review'),
          status: Value(status),
          progress: const Value(1),
          result: Value(result),
          createdAt: Value(now),
          updatedAt: Value(now),
          completedAt: Value(now),
        ),
      );
}
