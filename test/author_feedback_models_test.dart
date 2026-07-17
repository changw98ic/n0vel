import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/features/author_feedback/domain/author_feedback_models.dart';

void main() {
  // =========================================================================
  // AuthorFeedbackItem JSON round-trip
  // =========================================================================

  group('AuthorFeedbackItem JSON round-trip', () {
    test('toJson and fromJson produce identical item', () {
      final createdAt = DateTime.utc(2026, 2, 10, 14, 30);
      final updatedAt = DateTime.utc(2026, 2, 10, 15, 0);
      final original = AuthorFeedbackItem(
        id: 'feedback-123',
        projectId: 'project-1',
        chapterId: 'chapter-1',
        sceneId: 'scene-1',
        sceneLabel: '第 1 章 / 场景 01 · 雨夜',
        note: 'Add stronger emotional beat before the reveal.',
        priority: AuthorFeedbackPriority.high,
        status: AuthorFeedbackStatus.revisionRequested,
        createdAt: createdAt,
        updatedAt: updatedAt,
        sourceRunId: 'run-1',
        sourceRunLabel: 'Generation run completed',
        sourceReviewId: 'review-1',
        decisions: [
          AuthorFeedbackDecision(
            status: AuthorFeedbackStatus.open,
            note: 'Captured author feedback.',
            createdAt: createdAt,
            sourceRunId: 'run-1',
            sourceReviewId: 'review-1',
          ),
          AuthorFeedbackDecision(
            status: AuthorFeedbackStatus.revisionRequested,
            note: 'Ask the model for a tighter pass.',
            createdAt: updatedAt,
          ),
        ],
      );

      final json = original.toJson();
      final restored = AuthorFeedbackItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.projectId, 'project-1');
      expect(restored.chapterId, 'chapter-1');
      expect(restored.sceneId, 'scene-1');
      expect(restored.sceneLabel, '第 1 章 / 场景 01 · 雨夜');
      expect(restored.note, original.note);
      expect(restored.priority, AuthorFeedbackPriority.high);
      expect(restored.status, AuthorFeedbackStatus.revisionRequested);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
      expect(restored.sourceRunId, 'run-1');
      expect(restored.sourceRunLabel, 'Generation run completed');
      expect(restored.sourceReviewId, 'review-1');
      expect(restored.decisions, hasLength(2));
      expect(restored.decisions.first.status, AuthorFeedbackStatus.open);
      expect(
        restored.decisions.last.status,
        AuthorFeedbackStatus.revisionRequested,
      );
      expect(restored.decisions.last.note, 'Ask the model for a tighter pass.');
    });

    test('fromJson falls back to defaults for empty JSON', () {
      final restored = AuthorFeedbackItem.fromJson(const {});

      expect(restored.id, '');
      expect(restored.projectId, '');
      expect(restored.priority, AuthorFeedbackPriority.normal);
      expect(restored.status, AuthorFeedbackStatus.open);
      expect(restored.decisions, isEmpty);
    });

    test('fromJson handles null optional fields', () {
      final restored = AuthorFeedbackItem.fromJson(const {
        'id': 'fb-1',
        'projectId': 'p1',
        'chapterId': 'ch1',
        'sceneId': 's1',
        'sceneLabel': 'label',
        'note': 'A note',
        'priority': 'high',
        'status': 'open',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
      });

      expect(restored.sourceRunId, isNull);
      expect(restored.sourceRunLabel, isNull);
      expect(restored.sourceReviewId, isNull);
      expect(restored.decisions, isEmpty);
    });
  });

  // =========================================================================
  // AuthorFeedbackDecision JSON round-trip
  // =========================================================================

  group('AuthorFeedbackDecision JSON round-trip', () {
    test('toJson and fromJson produce identical decision', () {
      final createdAt = DateTime.utc(2026, 3, 1, 8, 0);
      final original = AuthorFeedbackDecision(
        status: AuthorFeedbackStatus.accepted,
        note: 'The revision is satisfactory.',
        createdAt: createdAt,
        sourceRunId: 'run-5',
        sourceReviewId: 'review-3',
      );

      final json = original.toJson();
      final restored = AuthorFeedbackDecision.fromJson(json);

      expect(restored.status, AuthorFeedbackStatus.accepted);
      expect(restored.note, 'The revision is satisfactory.');
      expect(restored.createdAt, createdAt);
      expect(restored.sourceRunId, 'run-5');
      expect(restored.sourceReviewId, 'review-3');
    });

    test('fromJson falls back to open status for unknown names', () {
      final restored = AuthorFeedbackDecision.fromJson(const {
        'status': 'nonexistent',
        'note': 'test',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      expect(restored.status, AuthorFeedbackStatus.open);
    });
  });

  // =========================================================================
  // AuthorFeedbackItem isActive
  // =========================================================================

  group('AuthorFeedbackItem isActive', () {
    test('open status is active', () {
      final item = AuthorFeedbackItem(
        id: 'fb-1',
        projectId: 'p1',
        chapterId: 'ch1',
        sceneId: 's1',
        sceneLabel: 'label',
        note: 'Note',
        priority: AuthorFeedbackPriority.normal,
        status: AuthorFeedbackStatus.open,
        createdAt: _dummyDate,
        updatedAt: _dummyDate,
      );

      expect(item.isActive, isTrue);
    });

    test('revisionRequested status is active', () {
      final item = AuthorFeedbackItem(
        id: 'fb-1',
        projectId: 'p1',
        chapterId: 'ch1',
        sceneId: 's1',
        sceneLabel: 'label',
        note: 'Note',
        priority: AuthorFeedbackPriority.normal,
        status: AuthorFeedbackStatus.revisionRequested,
        createdAt: _dummyDate,
        updatedAt: _dummyDate,
      );

      expect(item.isActive, isTrue);
    });

    test('inProgress status is active', () {
      final item = AuthorFeedbackItem(
        id: 'fb-1',
        projectId: 'p1',
        chapterId: 'ch1',
        sceneId: 's1',
        sceneLabel: 'label',
        note: 'Note',
        priority: AuthorFeedbackPriority.normal,
        status: AuthorFeedbackStatus.inProgress,
        createdAt: _dummyDate,
        updatedAt: _dummyDate,
      );

      expect(item.isActive, isTrue);
    });

    test('resolved, accepted, and rejected are not active', () {
      final statuses = [
        AuthorFeedbackStatus.resolved,
        AuthorFeedbackStatus.accepted,
        AuthorFeedbackStatus.rejected,
      ];
      for (final status in statuses) {
        final item = AuthorFeedbackItem(
          id: 'fb-1',
          projectId: 'p1',
          chapterId: 'ch1',
          sceneId: 's1',
          sceneLabel: 'label',
          note: 'Note',
          priority: AuthorFeedbackPriority.normal,
          status: status,
          createdAt: _dummyDate,
          updatedAt: _dummyDate,
        );

        expect(item.isActive, isFalse, reason: '$status should not be active');
      }
    });
  });

  // =========================================================================
  // AuthorFeedbackItem copyWith
  // =========================================================================

  group('AuthorFeedbackItem copyWith', () {
    test('updates only specified fields', () {
      final original = AuthorFeedbackItem(
        id: 'fb-1',
        projectId: 'p1',
        chapterId: 'ch1',
        sceneId: 's1',
        sceneLabel: 'Scene A',
        note: 'Original note',
        priority: AuthorFeedbackPriority.normal,
        status: AuthorFeedbackStatus.open,
        createdAt: _dummyDate,
        updatedAt: _dummyDate,
      );

      final modified = original.copyWith(
        note: 'Updated note',
        status: AuthorFeedbackStatus.rejected,
      );

      expect(modified.id, 'fb-1');
      expect(modified.projectId, 'p1');
      expect(modified.sceneId, 's1');
      expect(modified.sceneLabel, 'Scene A');
      expect(modified.note, 'Updated note');
      expect(modified.status, AuthorFeedbackStatus.rejected);
      expect(modified.priority, AuthorFeedbackPriority.normal);
    });

    test('preserves decisions when not overridden', () {
      final original = AuthorFeedbackItem(
        id: 'fb-1',
        projectId: 'p1',
        chapterId: 'ch1',
        sceneId: 's1',
        sceneLabel: 'label',
        note: 'Note',
        priority: AuthorFeedbackPriority.normal,
        status: AuthorFeedbackStatus.open,
        createdAt: _dummyDate,
        updatedAt: _dummyDate,
        decisions: [
          AuthorFeedbackDecision(
            status: AuthorFeedbackStatus.open,
            note: 'Initial',
            createdAt: _dummyDate,
          ),
        ],
      );

      final modified = original.copyWith(status: AuthorFeedbackStatus.resolved);

      expect(modified.decisions, hasLength(1));
      expect(modified.decisions.first.note, 'Initial');
    });
  });
}

final _dummyDate = DateTime.utc(2026, 1, 1);
