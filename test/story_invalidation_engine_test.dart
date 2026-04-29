import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/features/story_generation/data/scene_review_models.dart';
import 'package:novel_writer/features/story_generation/data/story_invalidation_engine.dart';

void main() {
  test('changed role invalidates only passed scenes containing that role', () {
    final engine = StoryInvalidationEngine();
    final chapters = [
      StoryChapterGenerationState(
        chapterId: 'chapter-01',
        status: StoryChapterGenerationStatus.passed,
        scenes: [
          StorySceneGenerationState(
            sceneId: 'chapter-01-scene-01',
            status: StorySceneGenerationStatus.passed,
            judgeStatus: StoryReviewStatus.passed,
            consistencyStatus: StoryReviewStatus.passed,
            proseRetryCount: 1,
            directorRetryCount: 0,
            castRoleIds: const ['liu-xi', 'yue-ren'],
            worldNodeIds: const ['world-storm'],
            upstreamFingerprint: 'roles:v1',
          ),
          StorySceneGenerationState(
            sceneId: 'chapter-01-scene-02',
            status: StorySceneGenerationStatus.passed,
            judgeStatus: StoryReviewStatus.passed,
            consistencyStatus: StoryReviewStatus.passed,
            proseRetryCount: 0,
            directorRetryCount: 0,
            castRoleIds: const ['fu-xingzhou'],
            worldNodeIds: const ['world-old-harbor-rules'],
            upstreamFingerprint: 'roles:v1',
          ),
          StorySceneGenerationState(
            sceneId: 'chapter-01-scene-03',
            status: StorySceneGenerationStatus.pending,
            judgeStatus: StoryReviewStatus.pending,
            consistencyStatus: StoryReviewStatus.pending,
            proseRetryCount: 0,
            directorRetryCount: 0,
            castRoleIds: const ['liu-xi'],
            worldNodeIds: const ['world-storm'],
            upstreamFingerprint: 'roles:v1',
          ),
        ],
      ),
    ];

    final result = engine.invalidateForChangedRole(
      roleId: 'liu-xi',
      chapters: chapters,
    );

    expect(result.single, isNot(same(chapters.single)));
    expect(
      result.single.scenes.first,
      isNot(same(chapters.single.scenes.first)),
    );
    expect(result.single.scenes[1], isNot(same(chapters.single.scenes[1])));
    expect(result.single.status, StoryChapterGenerationStatus.invalidated);
    expect(
      result.single.scenes.first.status,
      StorySceneGenerationStatus.invalidated,
    );
    expect(result.single.scenes.first.judgeStatus, StoryReviewStatus.pending);
    expect(
      result.single.scenes.first.consistencyStatus,
      StoryReviewStatus.pending,
    );
    expect(result.single.scenes[1].status, StorySceneGenerationStatus.passed);
    expect(
      result.single.scenes.last.status,
      StorySceneGenerationStatus.pending,
    );
  });

  test(
    'changed role does not invalidate a passed chapter without impacted scene dependencies',
    () {
      final engine = StoryInvalidationEngine();
      final chapters = [
        StoryChapterGenerationState(
          chapterId: 'chapter-aux',
          status: StoryChapterGenerationStatus.passed,
          participatingRoleIds: const ['liu-xi', 'fu-xingzhou'],
          scenes: [
            StorySceneGenerationState(
              sceneId: 'chapter-aux-scene-01',
              status: StorySceneGenerationStatus.reviewing,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.pending,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['fu-xingzhou'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'roles:v1',
            ),
          ],
        ),
      ];

      final result = engine.invalidateForChangedRole(
        roleId: 'liu-xi',
        chapters: chapters,
      );

      expect(result.single, isNot(same(chapters.single)));
      expect(result.single.status, StoryChapterGenerationStatus.passed);
      expect(
        result.single.scenes.single.status,
        StorySceneGenerationStatus.reviewing,
      );
    },
  );

  test(
    'changed cognition input invalidates only scenes with matching edge',
    () {
      final engine = StoryInvalidationEngine();
      final chapters = [
        StoryChapterGenerationState(
          chapterId: 'chapter-01',
          status: StoryChapterGenerationStatus.passed,
          scenes: [
            StorySceneGenerationState(
              sceneId: 'scene-prose-liuxi',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['char-liuxi', 'char-yueren'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'cognition:v1',
              invalidationEdges: const ['cognition:char-liuxi'],
            ),
            StorySceneGenerationState(
              sceneId: 'scene-plan-yueren',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['char-liuxi', 'char-yueren'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'cognition:v1',
              invalidationEdges: const ['cognition:char-yueren'],
            ),
          ],
        ),
      ];

      final result = engine.invalidateForChangedCognition(
        characterId: 'char-liuxi',
        chapters: chapters,
      );

      expect(result.single.status, StoryChapterGenerationStatus.invalidated);
      expect(
        result.single.scenes.first.status,
        StorySceneGenerationStatus.invalidated,
      );
      expect(
        result.single.scenes.last.status,
        StorySceneGenerationStatus.passed,
      );
    },
  );

  test(
    'changed world setting invalidates only passed scenes linked to that world node',
    () {
      final engine = StoryInvalidationEngine();
      final chapters = [
        StoryChapterGenerationState(
          chapterId: 'chapter-01',
          status: StoryChapterGenerationStatus.passed,
          scenes: [
            StorySceneGenerationState(
              sceneId: 'chapter-01-scene-01',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['liu-xi'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'world:v1',
            ),
            StorySceneGenerationState(
              sceneId: 'chapter-01-scene-02',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['fu-xingzhou'],
              worldNodeIds: const ['world-old-harbor-rules'],
              upstreamFingerprint: 'world:v1',
            ),
          ],
        ),
        StoryChapterGenerationState(
          chapterId: 'chapter-02',
          status: StoryChapterGenerationStatus.reviewing,
          scenes: [
            StorySceneGenerationState(
              sceneId: 'chapter-02-scene-01',
              status: StorySceneGenerationStatus.reviewing,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.pending,
              proseRetryCount: 1,
              directorRetryCount: 0,
              castRoleIds: const ['yue-ren'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'world:v1',
            ),
          ],
        ),
      ];

      final result = engine.invalidateForChangedWorldSetting(
        worldNodeId: 'world-storm',
        chapters: chapters,
      );

      expect(result.first, isNot(same(chapters.first)));
      expect(result.last, isNot(same(chapters.last)));
      expect(result.first.status, StoryChapterGenerationStatus.invalidated);
      expect(
        result.first.scenes.first.status,
        StorySceneGenerationStatus.invalidated,
      );
      expect(result.first.scenes.first.judgeStatus, StoryReviewStatus.pending);
      expect(
        result.first.scenes.first.consistencyStatus,
        StoryReviewStatus.pending,
      );
      expect(
        result.first.scenes.last.status,
        StorySceneGenerationStatus.passed,
      );
      expect(result.last.status, StoryChapterGenerationStatus.reviewing);
      expect(
        result.last.scenes.single.status,
        StorySceneGenerationStatus.reviewing,
      );
    },
  );

  test(
    'changed world setting does not invalidate an entire chapter from chapter dependencies alone',
    () {
      final engine = StoryInvalidationEngine();
      final chapters = [
        StoryChapterGenerationState(
          chapterId: 'chapter-summary',
          status: StoryChapterGenerationStatus.passed,
          worldNodeIds: const ['world-storm'],
          scenes: [
            StorySceneGenerationState(
              sceneId: 'chapter-summary-scene-01',
              status: StorySceneGenerationStatus.blocked,
              judgeStatus: StoryReviewStatus.failed,
              consistencyStatus: StoryReviewStatus.hardFailed,
              proseRetryCount: 2,
              directorRetryCount: 2,
              castRoleIds: const ['liu-xi'],
              worldNodeIds: const ['world-invalid-script'],
              upstreamFingerprint: 'world:v1',
            ),
          ],
        ),
      ];

      final result = engine.invalidateForChangedWorldSetting(
        worldNodeId: 'world-storm',
        chapters: chapters,
      );

      expect(result.single, isNot(same(chapters.single)));
      expect(result.single.status, StoryChapterGenerationStatus.passed);
      expect(
        result.single.scenes.single.status,
        StorySceneGenerationStatus.blocked,
      );
    },
  );

  test(
    'changed world setting prefers explicit dependency edges when present',
    () {
      final engine = StoryInvalidationEngine();
      final chapters = [
        StoryChapterGenerationState(
          chapterId: 'chapter-01',
          status: StoryChapterGenerationStatus.passed,
          scenes: [
            StorySceneGenerationState(
              sceneId: 'scene-world-edge',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['liu-xi'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'world:v1',
              invalidationEdges: const ['world:world-storm'],
            ),
            StorySceneGenerationState(
              sceneId: 'scene-broad-world-only',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 0,
              directorRetryCount: 0,
              castRoleIds: const ['fu-xingzhou'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'world:v1',
              invalidationEdges: const ['world:old-harbor-rules'],
            ),
          ],
        ),
      ];

      final result = engine.invalidateForChangedWorldSetting(
        worldNodeId: 'world-storm',
        chapters: chapters,
      );

      expect(result.single.status, StoryChapterGenerationStatus.invalidated);
      expect(
        result.single.scenes.first.status,
        StorySceneGenerationStatus.invalidated,
      );
      expect(
        result.single.scenes.last.status,
        StorySceneGenerationStatus.passed,
      );
    },
  );

  test(
    'changed transitions invalidate only scenes depending on those transitions',
    () {
      final engine = StoryInvalidationEngine();
      final chapters = [
        StoryChapterGenerationState(
          chapterId: 'chapter-01',
          status: StoryChapterGenerationStatus.passed,
          scenes: [
            StorySceneGenerationState(
              sceneId: 'scene-ledger',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 1,
              directorRetryCount: 0,
              castRoleIds: const ['liu-xi'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'transition:v1',
              invalidationEdges: const ['transition:ledger-located'],
            ),
            StorySceneGenerationState(
              sceneId: 'scene-ally',
              status: StorySceneGenerationStatus.passed,
              judgeStatus: StoryReviewStatus.passed,
              consistencyStatus: StoryReviewStatus.passed,
              proseRetryCount: 1,
              directorRetryCount: 0,
              castRoleIds: const ['shen-du'],
              worldNodeIds: const ['world-storm'],
              upstreamFingerprint: 'transition:v1',
              invalidationEdges: const ['transition:ally-joins'],
            ),
          ],
        ),
      ];

      final result = engine.invalidateForChangedTransitions(
        transitionIds: const ['ledger-located'],
        chapters: chapters,
      );

      expect(
        result.single.scenes.first.status,
        StorySceneGenerationStatus.invalidated,
      );
      expect(
        result.single.scenes.last.status,
        StorySceneGenerationStatus.passed,
      );
    },
  );

  // =========================================================================
  // computeInvalidation
  // =========================================================================
  group('computeInvalidation', () {
    test('changing a transition invalidates only dependent scenes', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {'ledger-located'},
        changedWorldNodeIds: {},
        changedCognitionInputs: {},
        sceneToTransitions: {
          'scene-ledger': ['ledger-located'],
          'scene-ally': ['ally-joins'],
        },
        sceneToWorldNodes: const {},
        sceneToCognitionInputs: const {},
      );

      expect(scope.sceneIds, {'scene-ledger'});
      expect(scope.sceneIds, isNot(contains('scene-ally')));
      expect(scope.isGlobal, isFalse);
    });

    test('changing a world node invalidates scenes using that node', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {},
        changedWorldNodeIds: {'world-storm'},
        changedCognitionInputs: {},
        sceneToTransitions: const {},
        sceneToWorldNodes: {
          'scene-storm-a': ['world-storm'],
          'scene-harbor': ['world-old-harbor-rules'],
        },
        sceneToCognitionInputs: const {},
      );

      expect(scope.sceneIds, {'scene-storm-a'});
      expect(scope.sceneIds, isNot(contains('scene-harbor')));
      expect(scope.isGlobal, isFalse);
    });

    test('changing cognition invalidates relevant scenes', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {},
        changedWorldNodeIds: {},
        changedCognitionInputs: {'char-liuxi'},
        sceneToTransitions: const {},
        sceneToWorldNodes: const {},
        sceneToCognitionInputs: {
          'scene-liuxi': ['char-liuxi'],
          'scene-yueren': ['char-yueren'],
        },
      );

      expect(scope.sceneIds, {'scene-liuxi'});
      expect(scope.sceneIds, isNot(contains('scene-yueren')));
    });

    test('empty changes produce empty scope', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {},
        changedWorldNodeIds: {},
        changedCognitionInputs: {},
        sceneToTransitions: const {},
        sceneToWorldNodes: const {},
        sceneToCognitionInputs: const {},
      );

      expect(scope.isEmpty, isTrue);
      expect(scope.sceneIds, isEmpty);
      expect(scope.chapterIds, isEmpty);
      expect(scope.categories, isEmpty);
    });

    test('multiple changes produce merged scope', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {'ledger-located'},
        changedWorldNodeIds: {'world-storm'},
        changedCognitionInputs: {'char-liuxi'},
        sceneToTransitions: {
          'scene-ledger': ['ledger-located'],
        },
        sceneToWorldNodes: {
          'scene-storm': ['world-storm'],
        },
        sceneToCognitionInputs: {
          'scene-liuxi': ['char-liuxi'],
        },
      );

      expect(scope.sceneIds, {'scene-ledger', 'scene-storm', 'scene-liuxi'});
      expect(scope.categories, contains(SceneReviewCategory.continuity));
      expect(scope.categories, contains(SceneReviewCategory.scenePlan));
      expect(scope.categories, contains(SceneReviewCategory.worldState));
      expect(scope.categories, contains(SceneReviewCategory.characterState));
      expect(scope.categories, contains(SceneReviewCategory.prose));
    });

    test('invalidated scope is not global when specific scenes affected', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {'t1'},
        changedWorldNodeIds: {},
        changedCognitionInputs: {},
        sceneToTransitions: {
          'scene-a': ['t1'],
        },
        sceneToWorldNodes: const {},
        sceneToCognitionInputs: const {},
      );

      expect(scope.isGlobal, isFalse);
      expect(scope.sceneIds, isNotEmpty);
    });

    test('global invalidation when no specific mapping exists', () {
      final engine = StoryInvalidationEngine();
      final scope = engine.computeInvalidation(
        changedTransitionIds: {'t1'},
        changedWorldNodeIds: {},
        changedCognitionInputs: {},
        sceneToTransitions: {},
        sceneToWorldNodes: {},
        sceneToCognitionInputs: {},
      );

      expect(scope.isGlobal, isTrue);
      expect(scope.categories, isNotEmpty);
    });
  });
}
