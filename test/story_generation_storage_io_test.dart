import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_generation_storage_io.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';

void main() {
  test(
    'sqlite generation storage persists chapter scene statuses reviews retries and fingerprints',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_story_generation_state_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final storage = SqliteStoryGenerationStorage(dbPath: dbPath);
      const projectId = 'project-generation-a';

      await storage.save({
        'projectId': projectId,
        'chapters': [
          {
            'chapterId': 'chapter-01',
            'status': 'passed',
            'scenes': [
              {
                'sceneId': 'chapter-01-scene-01',
                'status': 'passed',
                'judgeStatus': 'passed',
                'consistencyStatus': 'softFailed',
                'proseRetryCount': 1,
                'directorRetryCount': 2,
                'castRoleIds': ['liu-xi', 'yue-ren'],
                'worldNodeIds': ['world-old-harbor-rules'],
                'upstreamFingerprint': 'world:v2|roles:v5|outline:v3',
              },
            ],
          },
        ],
      }, projectId: projectId);

      final restored = await storage.load(projectId: projectId);
      expect(restored, isNotNull);
      expect(restored?['projectId'], projectId);

      final chapters = restored?['chapters'] as List<Object?>;
      final chapter = chapters.single as Map<String, Object?>;
      final scenes = chapter['scenes'] as List<Object?>;
      final scene = scenes.single as Map<String, Object?>;

      expect(chapter['status'], 'passed');
      expect(scene['status'], 'passed');
      expect(scene['judgeStatus'], 'passed');
      expect(scene['consistencyStatus'], 'softFailed');
      expect(scene['proseRetryCount'], 1);
      expect(scene['directorRetryCount'], 2);
      expect(scene['castRoleIds'], ['liu-xi', 'yue-ren']);
      expect(scene['worldNodeIds'], ['world-old-harbor-rules']);
      expect(scene['upstreamFingerprint'], 'world:v2|roles:v5|outline:v3');
    },
  );

  test(
    'generation store restores persisted snapshots and scopes them by active project',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_story_generation_store_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/authoring.db';
      final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final generationStorage = SqliteStoryGenerationStorage(dbPath: dbPath);

      final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
      final generationStore = StoryGenerationStore(
        storage: generationStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(generationStore.dispose);
      await generationStore.waitUntilReady();

      final firstProjectId = workspaceStore.currentProjectId;
      generationStore.importJson({
        'chapters': [
          {
            'chapterId': 'chapter-01',
            'status': 'passed',
            'targetLength': 2400,
            'actualLength': 2280,
            'participatingRoleIds': ['liu-xi', 'yue-ren'],
            'worldNodeIds': ['world-storm', 'world-old-harbor-rules'],
            'scenes': [
              {
                'sceneId': 'scene-01',
                'status': 'passed',
                'judgeStatus': 'passed',
                'consistencyStatus': 'softFailed',
                'proseRetryCount': 1,
                'directorRetryCount': 2,
                'castRoleIds': ['liu-xi', 'yue-ren'],
                'worldNodeIds': ['world-storm', 'world-old-harbor-rules'],
                'upstreamFingerprint': 'world:v2|roles:v4|outline:v1',
              },
            ],
          },
        ],
      });
      await generationStore.waitUntilReady();

      final exportedFirst = generationStore.exportJson();
      expect(exportedFirst['projectId'], firstProjectId);
      final exportedFirstChapter =
          (exportedFirst['chapters'] as List<Object?>).single
              as Map<String, Object?>;
      final exportedFirstScene =
          (exportedFirstChapter['scenes'] as List<Object?>).single
              as Map<String, Object?>;
      expect(exportedFirstChapter['status'], 'passed');
      expect(exportedFirstChapter['targetLength'], 2400);
      expect(exportedFirstChapter['actualLength'], 2280);
      expect(exportedFirstChapter['participatingRoleIds'], [
        'liu-xi',
        'yue-ren',
      ]);
      expect(exportedFirstChapter['worldNodeIds'], [
        'world-storm',
        'world-old-harbor-rules',
      ]);
      expect(exportedFirstScene['status'], 'passed');
      expect(exportedFirstScene['judgeStatus'], 'passed');
      expect(exportedFirstScene['consistencyStatus'], 'softFailed');
      expect(exportedFirstScene['proseRetryCount'], 1);
      expect(exportedFirstScene['directorRetryCount'], 2);
      expect(exportedFirstScene['castRoleIds'], ['liu-xi', 'yue-ren']);
      expect(exportedFirstScene['worldNodeIds'], [
        'world-storm',
        'world-old-harbor-rules',
      ]);
      expect(
        exportedFirstScene['upstreamFingerprint'],
        'world:v2|roles:v4|outline:v1',
      );

      workspaceStore.createProject();
      final secondProjectId = workspaceStore.currentProjectId;
      await generationStore.waitUntilReady();

      expect(generationStore.snapshot.projectId, secondProjectId);
      expect(generationStore.snapshot.chapters, isEmpty);

      generationStore.importJson({
        'chapters': [
          {
            'chapterId': 'chapter-02',
            'status': 'reviewing',
            'targetLength': 2000,
            'actualLength': 870,
            'participatingRoleIds': ['fu-xingzhou'],
            'worldNodeIds': ['world-invalid-script'],
            'scenes': [
              {
                'sceneId': 'scene-05',
                'status': 'reviewing',
                'judgeStatus': 'passed',
                'consistencyStatus': 'pending',
                'proseRetryCount': 0,
                'directorRetryCount': 1,
                'castRoleIds': ['fu-xingzhou'],
                'worldNodeIds': ['world-invalid-script'],
                'upstreamFingerprint': 'world:v3|roles:v2|outline:v1',
              },
            ],
          },
        ],
      });
      await generationStore.waitUntilReady();

      final restoredWorkspaceStore = AppWorkspaceStore(
        storage: workspaceStorage,
      );
      final restoredGenerationStore = StoryGenerationStore(
        storage: generationStorage,
        workspaceStore: restoredWorkspaceStore,
      );
      addTearDown(restoredWorkspaceStore.dispose);
      addTearDown(restoredGenerationStore.dispose);
      await restoredGenerationStore.waitUntilReady();

      expect(restoredWorkspaceStore.currentProjectId, secondProjectId);
      expect(restoredGenerationStore.snapshot.projectId, secondProjectId);
      final restoredSecondChapter =
          restoredGenerationStore.snapshot.chapters.single;
      final restoredSecondScene = restoredSecondChapter.scenes.single;
      expect(restoredSecondChapter.chapterId, 'chapter-02');
      expect(
        restoredSecondChapter.status,
        StoryChapterGenerationStatus.reviewing,
      );
      expect(restoredSecondChapter.targetLength, 2000);
      expect(restoredSecondChapter.actualLength, 870);
      expect(restoredSecondChapter.participatingRoleIds, ['fu-xingzhou']);
      expect(restoredSecondChapter.worldNodeIds, ['world-invalid-script']);
      expect(restoredSecondScene.sceneId, 'scene-05');
      expect(restoredSecondScene.status, StorySceneGenerationStatus.reviewing);
      expect(restoredSecondScene.judgeStatus, StoryReviewStatus.passed);
      expect(restoredSecondScene.consistencyStatus, StoryReviewStatus.pending);
      expect(restoredSecondScene.proseRetryCount, 0);
      expect(restoredSecondScene.directorRetryCount, 1);
      expect(restoredSecondScene.castRoleIds, ['fu-xingzhou']);
      expect(restoredSecondScene.worldNodeIds, ['world-invalid-script']);
      expect(
        restoredSecondScene.upstreamFingerprint,
        'world:v3|roles:v2|outline:v1',
      );

      restoredWorkspaceStore.openProject(firstProjectId);
      await restoredGenerationStore.waitUntilReady();

      expect(restoredGenerationStore.snapshot.projectId, firstProjectId);
      final restoredFirstChapter =
          restoredGenerationStore.snapshot.chapters.single;
      final restoredFirstScene = restoredFirstChapter.scenes.single;
      expect(restoredFirstChapter.chapterId, 'chapter-01');
      expect(restoredFirstChapter.status, StoryChapterGenerationStatus.passed);
      expect(restoredFirstChapter.targetLength, 2400);
      expect(restoredFirstChapter.actualLength, 2280);
      expect(restoredFirstChapter.participatingRoleIds, ['liu-xi', 'yue-ren']);
      expect(restoredFirstChapter.worldNodeIds, [
        'world-storm',
        'world-old-harbor-rules',
      ]);
      expect(restoredFirstScene.status, StorySceneGenerationStatus.passed);
      expect(restoredFirstScene.judgeStatus, StoryReviewStatus.passed);
      expect(
        restoredFirstScene.consistencyStatus,
        StoryReviewStatus.softFailed,
      );
      expect(restoredFirstScene.proseRetryCount, 1);
      expect(restoredFirstScene.directorRetryCount, 2);
      expect(restoredFirstScene.castRoleIds, ['liu-xi', 'yue-ren']);
      expect(restoredFirstScene.worldNodeIds, [
        'world-storm',
        'world-old-harbor-rules',
      ]);
      expect(
        restoredFirstScene.upstreamFingerprint,
        'world:v2|roles:v4|outline:v1',
      );
    },
  );

  test('load returns null for non-existent project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_story_gen_missing_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteStoryGenerationStorage(
      dbPath: '${directory.path}/authoring.db',
    );

    expect(await storage.load(projectId: 'no-such-project'), isNull);
  });

  test('save upserts when called twice for the same project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_story_gen_upsert_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteStoryGenerationStorage(
      dbPath: '${directory.path}/authoring.db',
    );

    await storage.save(
      {'projectId': 'project-dock', 'chapters': []},
      projectId: 'project-dock',
    );
    await storage.save(
      {
        'projectId': 'project-dock',
        'chapters': [
          {
            'chapterId': 'chapter-03',
            'status': 'pending',
            'targetLength': 0,
            'actualLength': 0,
            'participatingRoleIds': <String>[],
            'worldNodeIds': <String>[],
            'scenes': <Object?>[],
          },
        ],
      },
      projectId: 'project-dock',
    );

    final loaded = await storage.load(projectId: 'project-dock');
    final chapters = loaded!['chapters'] as List<Object?>;
    expect(chapters, hasLength(1));
    expect(
      (chapters.first as Map<String, Object?>)['chapterId'],
      'chapter-03',
    );
  });

  test('clear isolates by project and wipes all when project is null', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_story_gen_clear_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteStoryGenerationStorage(
      dbPath: '${directory.path}/authoring.db',
    );

    await storage.save(
      {'projectId': 'project-dock', 'chapters': []},
      projectId: 'project-dock',
    );
    await storage.save(
      {'projectId': 'project-harbor', 'chapters': [{'chapterId': 'c1'}]},
      projectId: 'project-harbor',
    );

    await storage.clear(projectId: 'project-dock');
    expect(await storage.load(projectId: 'project-dock'), isNull);
    expect(await storage.load(projectId: 'project-harbor'), isNotNull);

    await storage.clear();
    expect(await storage.load(projectId: 'project-harbor'), isNull);
  });

  test('storage creates expected table and column schema', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_story_gen_schema_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final storage = SqliteStoryGenerationStorage(dbPath: dbPath);
    await storage.save(
      {'projectId': 'project-x', 'chapters': []},
      projectId: 'project-x',
    );

    final database = sqlite3.open(dbPath);
    addTearDown(database.dispose);

    final tableNames = database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    expect(tableNames, contains('story_generation_state'));

    final columns = database
        .select('PRAGMA table_info(story_generation_state)')
        .map((row) => row['name'] as String)
        .toList();
    expect(columns, containsAll(['project_id', 'payload_json', 'updated_at_ms']));
  });

  test('snapshot deep copy prevents external mutation from reaching storage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_story_gen_immutability_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
    final genStorage = SqliteStoryGenerationStorage(dbPath: dbPath);

    final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
    final genStore = StoryGenerationStore(
      storage: genStorage,
      workspaceStore: workspaceStore,
    );
    addTearDown(workspaceStore.dispose);
    addTearDown(genStore.dispose);
    await genStore.waitUntilReady();

    genStore.replaceSnapshot(
      StoryGenerationSnapshot(
        projectId: workspaceStore.currentProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'chapter-01',
            status: StoryChapterGenerationStatus.inProgress,
            targetLength: 6000,
            actualLength: 1500,
            participatingRoleIds: ['char-liuxi'],
            worldNodeIds: ['node-dock'],
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-01',
                status: StorySceneGenerationStatus.reviewing,
                judgeStatus: StoryReviewStatus.softFailed,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 2,
                directorRetryCount: 1,
                castRoleIds: ['char-liuxi', 'char-chenmo'],
                worldNodeIds: ['node-dock'],
                upstreamFingerprint: 'fp-gamma',
              ),
            ],
          ),
        ],
      ),
    );
    await genStore.waitUntilReady();

    final firstView = genStore.snapshot;
    expect(
      firstView.chapters.first.scenes.first.judgeStatus,
      StoryReviewStatus.softFailed,
    );

    final secondView = genStore.snapshot;
    expect(
      secondView.chapters.first.scenes.first.judgeStatus,
      StoryReviewStatus.softFailed,
    );

    final restoredGenStore = StoryGenerationStore(
      storage: genStorage,
      workspaceStore: workspaceStore,
    );
    addTearDown(restoredGenStore.dispose);
    await restoredGenStore.waitUntilReady();

    final restored = restoredGenStore.snapshot;
    expect(
      restored.chapters.first.scenes.first.judgeStatus,
      StoryReviewStatus.softFailed,
    );
    expect(restored.chapters.first.scenes.first.proseRetryCount, 2);
    expect(restored.chapters.first.scenes.first.castRoleIds,
        ['char-liuxi', 'char-chenmo']);
    expect(restored.chapters.first.targetLength, 6000);
    expect(restored.chapters.first.actualLength, 1500);
    expect(restored.chapters.first.participatingRoleIds, ['char-liuxi']);
  });
}
