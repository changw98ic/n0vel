import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/story_generation_run_store.dart';

void main() {
  group('StoryGenerationRunSessionController', () {
    test('tracks the active run token and visible scene scope', () {
      final session = StoryGenerationRunSessionController();

      final token = session.begin('project-1::scene-1');

      expect(session.hasActiveRun, isTrue);
      expect(session.activeRunToken, token);
      expect(session.activeRunSceneScopeId, 'project-1::scene-1');
      expect(session.isActiveRunForScene('project-1::scene-1'), isTrue);
      expect(
        session.isCurrent(
          runToken: token,
          runSceneScopeId: 'project-1::scene-1',
          visibleSceneScopeId: 'project-1::scene-1',
        ),
        isTrue,
      );
      expect(
        session.isCurrent(
          runToken: token,
          runSceneScopeId: 'project-1::scene-1',
          visibleSceneScopeId: 'project-1::scene-2',
        ),
        isFalse,
      );
    });

    test('ignores stale finish calls after a newer run begins', () {
      final session = StoryGenerationRunSessionController();

      final staleToken = session.begin('project-1::scene-1');
      final currentToken = session.begin('project-1::scene-2');

      session.finish(staleToken);

      expect(session.hasActiveRun, isTrue);
      expect(session.activeRunToken, currentToken);
      expect(session.activeRunSceneScopeId, 'project-1::scene-2');

      session.finish(currentToken);

      expect(session.hasActiveRun, isFalse);
      expect(session.activeRunToken, isNull);
      expect(session.activeRunSceneScopeId, isNull);
    });

    test('clears cancelled runs without advancing the token counter', () {
      final session = StoryGenerationRunSessionController();

      final cancelledToken = session.begin('project-1::scene-1');

      session.clearActiveRun();

      expect(session.hasActiveRun, isFalse);
      expect(
        session.isCurrent(
          runToken: cancelledToken,
          runSceneScopeId: 'project-1::scene-1',
          visibleSceneScopeId: 'project-1::scene-1',
        ),
        isFalse,
      );
      expect(session.begin('project-1::scene-2'), cancelledToken + 1);
    });

    test('clears and invalidates runs for a deleted project', () {
      final session = StoryGenerationRunSessionController();

      final token = session.begin('project-1::scene-1');

      expect(session.clearProject('project-2'), isFalse);
      expect(session.hasActiveRun, isTrue);

      expect(session.clearProject('project-1'), isTrue);
      expect(session.hasActiveRun, isFalse);
      expect(session.activeRunToken, isNull);
      expect(session.activeRunSceneScopeId, isNull);
      expect(session.begin('project-3::scene-1'), token + 2);
    });

    test('matches project-level active run scopes during deletion', () {
      final session = StoryGenerationRunSessionController();

      session.begin('project-1');

      expect(session.clearProject('project-1'), isTrue);
      expect(session.hasActiveRun, isFalse);
    });
  });
}
