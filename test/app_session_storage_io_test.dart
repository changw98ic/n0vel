import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage_io.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage_io.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  test('AI history and scene context persist by project across store rebuilds', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_session_storage_io_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
    final aiHistoryStorage = SqliteAppAiHistoryStorage(dbPath: dbPath);
    final sceneContextStorage = SqliteAppSceneContextStorage(dbPath: dbPath);

    final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
    final aiHistoryStore = AppAiHistoryStore(
      storage: aiHistoryStorage,
      workspaceStore: workspaceStore,
    );
    final sceneContextStore = AppSceneContextStore(
      storage: sceneContextStorage,
      workspaceStore: workspaceStore,
    );
    addTearDown(workspaceStore.dispose);
    addTearDown(aiHistoryStore.dispose);
    addTearDown(sceneContextStore.dispose);

    final firstProjectId = workspaceStore.currentProjectId;
    aiHistoryStore.addEntry(mode: '改写', prompt: '项目一历史');
    sceneContextStore.syncContext();

    workspaceStore.createProject();
    final secondProjectId = workspaceStore.currentProjectId;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    aiHistoryStore.addEntry(mode: '续写', prompt: '项目二历史');
    sceneContextStore.syncContext();

    final restoredWorkspaceStore = AppWorkspaceStore(storage: workspaceStorage);
    final restoredAiHistoryStore = AppAiHistoryStore(
      storage: aiHistoryStorage,
      workspaceStore: restoredWorkspaceStore,
    );
    final restoredSceneContextStore = AppSceneContextStore(
      storage: sceneContextStorage,
      workspaceStore: restoredWorkspaceStore,
    );
    addTearDown(restoredWorkspaceStore.dispose);
    addTearDown(restoredAiHistoryStore.dispose);
    addTearDown(restoredSceneContextStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(restoredWorkspaceStore.currentProjectId, secondProjectId);
    expect(restoredAiHistoryStore.entries.first.prompt, '项目二历史');

    restoredWorkspaceStore.openProject(firstProjectId);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(restoredAiHistoryStore.entries.first.prompt, '项目一历史');
    expect(restoredSceneContextStore.snapshot.sceneSummary, contains('仓库门外'));
  });

  test('AI history and scene context persist by scene scope within a project', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_scene_session_storage_io_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final dbPath = '${directory.path}/authoring.db';
    final workspaceStorage = SqliteAppWorkspaceStorage(dbPath: dbPath);
    final aiHistoryStorage = SqliteAppAiHistoryStorage(dbPath: dbPath);
    final sceneContextStorage = SqliteAppSceneContextStorage(dbPath: dbPath);

    final workspaceStore = AppWorkspaceStore(storage: workspaceStorage);
    final aiHistoryStore = AppAiHistoryStore(
      storage: aiHistoryStorage,
      workspaceStore: workspaceStore,
    );
    final sceneContextStore = AppSceneContextStore(
      storage: sceneContextStorage,
      workspaceStore: workspaceStore,
    );
    addTearDown(workspaceStore.dispose);
    addTearDown(aiHistoryStore.dispose);
    addTearDown(sceneContextStore.dispose);

    aiHistoryStore.addEntry(mode: '改写', prompt: '场景 05 历史');
    sceneContextStore.syncContext();

    workspaceStore.updateCurrentScene(
      sceneId: 'scene-07-balcony-conflict',
      recentLocation: '第 3 章 / 场景 07 · 阳台争执',
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    aiHistoryStore.addEntry(mode: '续写', prompt: '场景 07 历史');
    sceneContextStore.syncContext();

    final restoredWorkspaceStore = AppWorkspaceStore(storage: workspaceStorage);
    final restoredAiHistoryStore = AppAiHistoryStore(
      storage: aiHistoryStorage,
      workspaceStore: restoredWorkspaceStore,
    );
    final restoredSceneContextStore = AppSceneContextStore(
      storage: sceneContextStorage,
      workspaceStore: restoredWorkspaceStore,
    );
    addTearDown(restoredWorkspaceStore.dispose);
    addTearDown(restoredAiHistoryStore.dispose);
    addTearDown(restoredSceneContextStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(restoredAiHistoryStore.entries.first.prompt, '场景 07 历史');
    expect(restoredSceneContextStore.snapshot.sceneSummary, contains('阳台争执'));

    restoredWorkspaceStore.updateCurrentScene(
      sceneId: 'scene-05-witness-room',
      recentLocation: '第 3 章 / 场景 05 · 证人房间对峙',
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(restoredAiHistoryStore.entries.first.prompt, '场景 05 历史');
    expect(restoredSceneContextStore.snapshot.sceneSummary, contains('仓库门外'));
  });
}
