import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  test('AI history, scene context, and simulation are scoped by current project', () async {
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    final aiHistoryStore = AppAiHistoryStore(
      storage: InMemoryAppAiHistoryStorage(),
      workspaceStore: workspaceStore,
    );
    final sceneContextStore = AppSceneContextStore(
      storage: InMemoryAppSceneContextStorage(),
      workspaceStore: workspaceStore,
    );
    final simulationStore = AppSimulationStore(
      storage: InMemoryAppSimulationStorage(),
      workspaceStore: workspaceStore,
    );
    addTearDown(workspaceStore.dispose);
    addTearDown(aiHistoryStore.dispose);
    addTearDown(sceneContextStore.dispose);
    addTearDown(simulationStore.dispose);

    final firstProjectId = workspaceStore.currentProjectId;
    aiHistoryStore.addEntry(mode: '改写', prompt: '项目一意图');
    sceneContextStore.syncContext();
    simulationStore.startSuccessfulRun();
    await Future<void>.delayed(const Duration(milliseconds: 900));

    workspaceStore.createProject();
    final secondProjectId = workspaceStore.currentProjectId;
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(secondProjectId, isNot(firstProjectId));
    expect(aiHistoryStore.entries, isEmpty);
    expect(sceneContextStore.snapshot.sceneSummary, contains('等待同步'));
    expect(simulationStore.snapshot.status, SimulationStatus.none);

    aiHistoryStore.addEntry(mode: '续写', prompt: '项目二意图');
    sceneContextStore.syncContext();
    simulationStore.startFailureRun();
    await Future<void>.delayed(const Duration(milliseconds: 650));

    workspaceStore.openProject(firstProjectId);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(aiHistoryStore.entries.first.prompt, '项目一意图');
    expect(sceneContextStore.snapshot.sceneSummary, contains('仓库门外'));
    expect(simulationStore.snapshot.status, SimulationStatus.completed);

    workspaceStore.openProject(secondProjectId);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(aiHistoryStore.entries.first.prompt, '项目二意图');
    expect(sceneContextStore.snapshot.sceneSummary, contains('等待命名'));
    expect(simulationStore.snapshot.status, SimulationStatus.failed);
  });

  test('scene context and simulation are scoped by current scene id', () async {
    final workspaceStore = AppWorkspaceStore(
      storage: InMemoryAppWorkspaceStorage(),
    );
    final aiHistoryStore = AppAiHistoryStore(
      storage: InMemoryAppAiHistoryStorage(),
      workspaceStore: workspaceStore,
    );
    final sceneContextStore = AppSceneContextStore(
      storage: InMemoryAppSceneContextStorage(),
      workspaceStore: workspaceStore,
    );
    final simulationStore = AppSimulationStore(
      storage: InMemoryAppSimulationStorage(),
      workspaceStore: workspaceStore,
    );
    addTearDown(workspaceStore.dispose);
    addTearDown(aiHistoryStore.dispose);
    addTearDown(sceneContextStore.dispose);
    addTearDown(simulationStore.dispose);

    aiHistoryStore.addEntry(mode: '改写', prompt: '场景 05 历史');
    sceneContextStore.syncContext();
    simulationStore.startSuccessfulRun();
    await Future<void>.delayed(const Duration(milliseconds: 900));

    workspaceStore.updateCurrentScene(
      sceneId: 'scene-07-balcony-conflict',
      recentLocation: '第 3 章 / 场景 07 · 阳台争执',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(aiHistoryStore.entries, isEmpty);
    expect(sceneContextStore.snapshot.sceneSummary, contains('阳台争执'));
    expect(simulationStore.snapshot.status, SimulationStatus.none);

    aiHistoryStore.addEntry(mode: '续写', prompt: '场景 07 历史');
    simulationStore.startFailureRun();
    await Future<void>.delayed(const Duration(milliseconds: 650));

    workspaceStore.updateCurrentScene(
      sceneId: 'scene-05-witness-room',
      recentLocation: '第 3 章 / 场景 05 · 证人房间对峙',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(aiHistoryStore.entries.first.prompt, '场景 05 历史');
    expect(sceneContextStore.snapshot.sceneSummary, contains('仓库门外'));
    expect(simulationStore.snapshot.status, SimulationStatus.completed);
  });
}
