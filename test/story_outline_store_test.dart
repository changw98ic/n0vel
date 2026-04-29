import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_storage_io.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';

void main() {
  test(
    'snapshot exposure and replacement do not leak mutable outline state',
    () async {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final outlineStorage = InMemoryStoryOutlineStorage();
      final outlineStore = StoryOutlineStore(
        storage: outlineStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(outlineStore.dispose);

      final sourceSnapshot = StoryOutlineSnapshot(
        projectId: workspaceStore.currentProjectId,
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'chapter-01',
            title: '第一章 雨夜码头',
            summary: '码头线索启动。',
            scenes: [
              StoryOutlineSceneSnapshot(
                id: 'scene-01',
                title: '仓库门外',
                summary: '柳溪在雨中等人。',
                cast: [
                  StoryOutlineCastSnapshot(
                    characterId: 'char-liuxi',
                    name: '柳溪',
                    role: '调查记者',
                    metadata: {
                      'action': 'waits under the leaking dock awning',
                      'flags': ['pov'],
                    },
                  ),
                ],
                metadata: {'weather': 'storm'},
              ),
            ],
          ),
        ],
        metadata: {'arc': 'dock-investigation'},
      );

      outlineStore.replaceSnapshot(sourceSnapshot);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      sourceSnapshot.chapters.first.scenes.first.cast.first.metadata['action'] =
          'tampered source';
      sourceSnapshot.chapters.first.scenes.add(
        const StoryOutlineSceneSnapshot(
          id: 'scene-02',
          title: '不应进入存储',
          summary: '外部突变',
        ),
      );

      final firstView = outlineStore.snapshot;
      expect(firstView.chapters, hasLength(1));
      expect(
        firstView.chapters.first.scenes.first.cast.first.metadata['action'],
        'waits under the leaking dock awning',
      );

      firstView.chapters.first.scenes.first.cast.first.metadata['action'] =
          'tampered view';
      firstView.chapters.add(
        const StoryOutlineChapterSnapshot(
          id: 'chapter-99',
          title: '不应进入快照',
          summary: '外部读取后突变',
        ),
      );

      final secondView = outlineStore.snapshot;
      expect(secondView.chapters, hasLength(1));
      expect(
        secondView.chapters.first.scenes.first.cast.first.metadata['action'],
        'waits under the leaking dock awning',
      );

      final persisted = await outlineStorage.load(
        projectId: workspaceStore.currentProjectId,
      );
      final chapters = persisted?['chapters'] as List<Object?>;
      final firstChapter = chapters.first as Map<String, Object?>;
      final scenes = firstChapter['scenes'] as List<Object?>;
      final firstScene = scenes.first as Map<String, Object?>;
      final cast = firstScene['cast'] as List<Object?>;
      expect((cast.first as Map<String, Object?>)['metadata'], {
        'action': 'waits under the leaking dock awning',
        'flags': ['pov'],
      });
    },
  );

  test(
    'store restores persisted outlines and switches snapshots across projects',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_story_outline_store_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final outlineStorage = SqliteStoryOutlineStorage(dbPath: dbPath);

      final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
      final outlineStore = StoryOutlineStore(
        storage: outlineStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(outlineStore.dispose);

      final firstProjectId = workspaceStore.currentProjectId;
      outlineStore.importJson({
        'chapters': [
          {
            'id': 'chapter-01',
            'title': '第一章 雨夜码头',
            'summary': '码头线索启动。',
            'scenes': [
              {
                'id': 'scene-01',
                'title': '仓库门外',
                'summary': '柳溪在雨里等线人。',
                'cast': [
                  {
                    'characterId': 'char-liuxi',
                    'name': '柳溪',
                    'role': '调查记者',
                    'metadata': {'action': 'waits'},
                  },
                ],
              },
            ],
          },
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));

      workspaceStore.createProject();
      final secondProjectId = workspaceStore.currentProjectId;
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(outlineStore.snapshot.projectId, secondProjectId);
      expect(outlineStore.snapshot.chapters, isEmpty);

      outlineStore.importJson({
        'chapters': [
          {
            'id': 'chapter-02',
            'title': '第二章 月台对峙',
            'summary': '证词开始互相冲突。',
            'scenes': [
              {
                'id': 'scene-05',
                'title': '站台边缘',
                'summary': '对峙升级。',
                'cast': [
                  {
                    'characterId': 'char-chenmo',
                    'name': '陈默',
                    'role': '线人',
                    'metadata': {'action': 'deflects'},
                  },
                ],
              },
            ],
          },
        ],
      });
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final restoredWorkspaceStore = AppWorkspaceStore(
        storage: workspaceStorage,
      );
      final restoredOutlineStore = StoryOutlineStore(
        storage: outlineStorage,
        workspaceStore: restoredWorkspaceStore,
      );
      addTearDown(restoredWorkspaceStore.dispose);
      addTearDown(restoredOutlineStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(restoredWorkspaceStore.currentProjectId, secondProjectId);
      expect(restoredOutlineStore.snapshot.projectId, secondProjectId);
      expect(restoredOutlineStore.snapshot.chapters.single.title, '第二章 月台对峙');

      restoredWorkspaceStore.openProject(firstProjectId);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(restoredOutlineStore.snapshot.projectId, firstProjectId);
      expect(restoredOutlineStore.snapshot.chapters.single.title, '第一章 雨夜码头');
      expect(
        restoredOutlineStore
            .snapshot
            .chapters
            .single
            .scenes
            .single
            .cast
            .single
            .metadata['action'],
        'waits',
      );
    },
  );

  group('executable plan compatibility', () {
    test('snapshot without executable plan has hasExecutablePlan false', () {
      const snapshot = StoryOutlineSnapshot(projectId: 'project-test');
      expect(snapshot.hasExecutablePlan, isFalse);
      expect(snapshot.scenePlans, isEmpty);
    });

    test('snapshot with executable plan has hasExecutablePlan true', () {
      final plan = NovelPlan(
        id: 'plan-01',
        projectId: 'project-test',
        title: '测试小说计划',
        premise: '一个关于测试的故事',
      );
      final snapshot = StoryOutlineSnapshot(
        projectId: 'project-test',
        executablePlan: plan,
      );
      expect(snapshot.hasExecutablePlan, isTrue);
    });

    test('scenePlans returns flat list of scenes across chapters', () {
      final plan = NovelPlan(
        id: 'plan-01',
        projectId: 'project-test',
        title: '测试小说',
        premise: '前提',
        chapters: [
          ChapterPlan(
            id: 'ch-01',
            novelPlanId: 'plan-01',
            title: '第一章',
            summary: '章节摘要',
            scenes: [
              ScenePlan(
                id: 'scene-01',
                chapterPlanId: 'ch-01',
                title: '场景一',
                summary: '场景摘要',
                povCharacterId: 'char-01',
              ),
              ScenePlan(
                id: 'scene-02',
                chapterPlanId: 'ch-01',
                title: '场景二',
                summary: '场景摘要二',
                povCharacterId: 'char-02',
              ),
            ],
          ),
          ChapterPlan(
            id: 'ch-02',
            novelPlanId: 'plan-01',
            title: '第二章',
            summary: '第二章摘要',
            scenes: [
              ScenePlan(
                id: 'scene-03',
                chapterPlanId: 'ch-02',
                title: '场景三',
                summary: '场景摘要三',
                povCharacterId: 'char-01',
              ),
            ],
          ),
        ],
      );
      final snapshot = StoryOutlineSnapshot(
        projectId: 'project-test',
        executablePlan: plan,
      );

      final scenes = snapshot.scenePlans;
      expect(scenes, hasLength(3));
      expect(scenes[0].id, 'scene-01');
      expect(scenes[1].id, 'scene-02');
      expect(scenes[2].id, 'scene-03');
    });

    test('snapshot with executable plan serializes and deserializes', () {
      final transition = StateTransitionTarget(
        id: 'trans-01',
        fromSceneId: 'scene-01',
        toSceneId: 'scene-02',
        kind: 'time_skip',
        constraints: {'minHours': 2},
      );
      final plan = NovelPlan(
        id: 'plan-01',
        projectId: 'project-test',
        title: '序列化测试',
        premise: '测试前提',
        targetChapterCount: 1,
        chapters: [
          ChapterPlan(
            id: 'ch-01',
            novelPlanId: 'plan-01',
            title: '第一章',
            summary: '摘要',
            scenes: [
              ScenePlan(
                id: 'scene-01',
                chapterPlanId: 'ch-01',
                title: '场景一',
                summary: '场景摘要',
                povCharacterId: 'char-01',
                castIds: ['char-01', 'char-02'],
                beats: [
                  BeatPlan(
                    id: 'beat-01',
                    scenePlanId: 'scene-01',
                    sequence: 1,
                    beatType: 'action',
                    content: '角色行动',
                    transitionTarget: transition,
                  ),
                ],
                metadata: {'mood': 'tense'},
              ),
            ],
          ),
        ],
        metadata: {'genre': 'mystery'},
      );
      final original = StoryOutlineSnapshot(
        projectId: 'project-test',
        executablePlan: plan,
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'ch-01',
            title: '第一章',
            summary: '旧格式摘要',
          ),
        ],
      );

      final json = original.toJson();
      final restored = StoryOutlineSnapshot.fromJson(json);

      expect(restored.executablePlan, isNotNull);
      expect(restored.executablePlan!.id, 'plan-01');
      expect(restored.executablePlan!.title, '序列化测试');
      expect(restored.executablePlan!.premise, '测试前提');
      expect(restored.executablePlan!.targetChapterCount, 1);
      expect(restored.executablePlan!.metadata['genre'], 'mystery');

      final restoredChapter = restored.executablePlan!.chapters.single;
      expect(restoredChapter.id, 'ch-01');
      expect(restoredChapter.scenes, hasLength(1));

      final restoredScene = restoredChapter.scenes.first;
      expect(restoredScene.id, 'scene-01');
      expect(restoredScene.povCharacterId, 'char-01');
      expect(restoredScene.castIds, ['char-01', 'char-02']);
      expect(restoredScene.metadata['mood'], 'tense');

      final restoredBeat = restoredScene.beats.single;
      expect(restoredBeat.id, 'beat-01');
      expect(restoredBeat.sequence, 1);
      expect(restoredBeat.beatType, 'action');
      expect(restoredBeat.content, '角色行动');

      final restoredTransition = restoredBeat.transitionTarget!;
      expect(restoredTransition.id, 'trans-01');
      expect(restoredTransition.fromSceneId, 'scene-01');
      expect(restoredTransition.toSceneId, 'scene-02');
      expect(restoredTransition.kind, 'time_skip');
      expect(restoredTransition.constraints['minHours'], 2);

      // Legacy chapters still preserved.
      expect(restored.chapters, hasLength(1));
      expect(restored.chapters.first.id, 'ch-01');
    });

    test('legacy JSON without executablePlan key loads without errors', () {
      final legacyJson = <String, Object?>{
        'projectId': 'project-legacy',
        'chapters': [
          {
            'id': 'ch-01',
            'title': '第一章',
            'summary': '旧摘要',
            'scenes': [
              {
                'id': 's-01',
                'title': '场景',
                'summary': '旧场景摘要',
              },
            ],
          },
        ],
        'metadata': {'source': 'legacy'},
      };

      final snapshot = StoryOutlineSnapshot.fromJson(legacyJson);
      expect(snapshot.projectId, 'project-legacy');
      expect(snapshot.executablePlan, isNull);
      expect(snapshot.hasExecutablePlan, isFalse);
      expect(snapshot.scenePlans, isEmpty);
      expect(snapshot.chapters, hasLength(1));
      expect(snapshot.chapters.first.title, '第一章');
    });

    test('JSON round-trip preserves executable plan data', () {
      final plan = NovelPlan(
        id: 'plan-rt',
        projectId: 'project-rt',
        title: '往返测试',
        premise: '数据完整性',
        chapters: [
          ChapterPlan(
            id: 'ch-rt',
            novelPlanId: 'plan-rt',
            title: '章',
            summary: '摘',
            scenes: [
              ScenePlan(
                id: 's-rt',
                chapterPlanId: 'ch-rt',
                title: '场',
                summary: '要',
                povCharacterId: 'p',
              ),
            ],
          ),
        ],
      );
      final original = StoryOutlineSnapshot(
        projectId: 'project-rt',
        executablePlan: plan,
      );

      // Round-trip through JSON twice to catch serialization drift.
      final firstPass = StoryOutlineSnapshot.fromJson(original.toJson());
      final secondPass = StoryOutlineSnapshot.fromJson(firstPass.toJson());

      expect(secondPass.executablePlan, equals(firstPass.executablePlan));
      expect(secondPass.executablePlan, equals(original.executablePlan));
    });

    test('fromLegacyJson ignores executablePlan key if present', () {
      final json = <Object?, Object?>{
        'projectId': 'project-guard',
        'chapters': [],
        'executablePlan': {
          'id': 'plan-sneaky',
          'projectId': 'project-guard',
          'title': '不应加载',
          'premise': '恶意数据',
        },
      };

      final snapshot = StoryOutlineSnapshot.fromLegacyJson(json);
      expect(snapshot.executablePlan, isNull);
      expect(snapshot.hasExecutablePlan, isFalse);
      expect(snapshot.projectId, 'project-guard');
    });

    test('store round-trips snapshot with executable plan via storage',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_executable_plan_store_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final outlineStorage = SqliteStoryOutlineStorage(dbPath: dbPath);

      final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
      final outlineStore = StoryOutlineStore(
        storage: outlineStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(outlineStore.dispose);

      final plan = NovelPlan(
        id: 'plan-store',
        projectId: workspaceStore.currentProjectId,
        title: '存储测试计划',
        premise: '验证持久化',
        chapters: [
          ChapterPlan(
            id: 'ch-store',
            novelPlanId: 'plan-store',
            title: '第一章',
            summary: '存储摘要',
            scenes: [
              ScenePlan(
                id: 's-store',
                chapterPlanId: 'ch-store',
                title: '持久化场景',
                summary: '存储场景摘要',
                povCharacterId: 'char-01',
              ),
            ],
          ),
        ],
      );

      final snapshot = StoryOutlineSnapshot(
        projectId: workspaceStore.currentProjectId,
        executablePlan: plan,
      );
      outlineStore.replaceSnapshot(snapshot);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Restore from a fresh store.
      final restoredWorkspaceStore = AppWorkspaceStore(
        storage: workspaceStorage,
      );
      final restoredOutlineStore = StoryOutlineStore(
        storage: outlineStorage,
        workspaceStore: restoredWorkspaceStore,
      );
      addTearDown(restoredWorkspaceStore.dispose);
      addTearDown(restoredOutlineStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final restored = restoredOutlineStore.snapshot;
      expect(restored.hasExecutablePlan, isTrue);
      expect(restored.executablePlan!.id, 'plan-store');
      expect(restored.executablePlan!.title, '存储测试计划');
      expect(restored.scenePlans, hasLength(1));
      expect(restored.scenePlans.first.id, 's-store');
    });
  });
}
