import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_project_scoped_store.dart';
import 'app_scene_context_storage.dart';
import 'app_workspace_store.dart';

class AppSceneContextSnapshot {
  const AppSceneContextSnapshot({
    required this.sceneSummary,
    required this.characterSummary,
    required this.worldSummary,
  });

  final String sceneSummary;
  final String characterSummary;
  final String worldSummary;

  AppSceneContextSnapshot copyWith({
    String? sceneSummary,
    String? characterSummary,
    String? worldSummary,
  }) {
    return AppSceneContextSnapshot(
      sceneSummary: sceneSummary ?? this.sceneSummary,
      characterSummary: characterSummary ?? this.characterSummary,
      worldSummary: worldSummary ?? this.worldSummary,
    );
  }
}

class AppSceneContextStore extends AppProjectScopedStore {
  AppSceneContextStore({
    AppSceneContextStorage? storage,
    super.workspaceStore,
  }) : _storage =
           storage ??
           debugStorageOverride ??
           createDefaultAppSceneContextStorage(),
       super(fallbackProjectId: _defaultSceneScopeId) {
    _snapshot = _snapshotForScope(activeProjectId);
    onRestore();
  }

  @visibleForTesting
  static AppSceneContextStorage? debugStorageOverride;

  final AppSceneContextStorage _storage;
  final Map<String, AppSceneContextSnapshot> _snapshotsByProjectId = {};
  late AppSceneContextSnapshot _snapshot;

  AppSceneContextSnapshot get snapshot => _snapshot;

  void syncContext() {
    markMutated();
    final nextSnapshot = switch (activeProjectId) {
      _defaultSceneScopeId => const AppSceneContextSnapshot(
        sceneSummary: '当前场景：场景 03 · 仓库门外',
        characterSummary: '角色摘要：柳溪 · 已重新同步',
        worldSummary: '世界观摘要：旧码头规则 · 已刷新',
      ),
      _ => AppSceneContextSnapshot(
        sceneSummary: '当前场景：${_currentProject().recentLocation}',
        characterSummary:
            '角色摘要：${_currentCharacter().name} · 已重新同步',
        worldSummary:
            '世界观摘要：${_currentWorldNode().title} · 已刷新',
      ),
    };
    _snapshotsByProjectId[activeProjectId] = nextSnapshot;
    _snapshot = nextSnapshot;
    unawaited(_persist());
    notifyListeners();
  }

  Map<String, Object?> exportJson() {
    return {
      'sceneSummary': _snapshot.sceneSummary,
      'characterSummary': _snapshot.characterSummary,
      'worldSummary': _snapshot.worldSummary,
    };
  }

  void importJson(Map<String, Object?> data) {
    markMutated();
    _snapshot = AppSceneContextSnapshot(
      sceneSummary: data['sceneSummary']?.toString() ?? _defaultSceneSummary,
      characterSummary:
          data['characterSummary']?.toString() ?? _defaultCharacterSummary,
      worldSummary: data['worldSummary']?.toString() ?? _defaultWorldSummary,
    );
    _snapshotsByProjectId[activeProjectId] = _snapshot;
    unawaited(_persist());
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _snapshot = _snapshotForScope(nextProjectId);
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion) {
      return;
    }
    if (restored == null) {
      return;
    }
    _snapshot = AppSceneContextSnapshot(
      sceneSummary:
          restored['sceneSummary']?.toString() ?? _defaultSceneSummary,
      characterSummary:
          restored['characterSummary']?.toString() ?? _defaultCharacterSummary,
      worldSummary:
          restored['worldSummary']?.toString() ?? _defaultWorldSummary,
    );
    _snapshotsByProjectId[activeProjectId] = _snapshot;
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(exportJson(), projectId: activeProjectId);

  AppSceneContextSnapshot _snapshotForScope(String projectId) {
    return _snapshotsByProjectId.putIfAbsent(
      projectId,
      () => switch (projectId) {
        _defaultSceneScopeId => const AppSceneContextSnapshot(
          sceneSummary: _defaultSceneSummary,
          characterSummary: _defaultCharacterSummary,
          worldSummary: _defaultWorldSummary,
        ),
        _ => AppSceneContextSnapshot(
          sceneSummary: '当前场景：${_currentProject().recentLocation} · 等待同步',
          characterSummary:
              '角色摘要：${_currentCharacter().name} · ${_currentCharacter().role}',
          worldSummary:
              '世界观摘要：${_currentWorldNode().title} · ${_currentWorldNode().type}',
        ),
      },
    );
  }

  ProjectRecord _currentProject() =>
      workspaceStore?.currentProject ??
      const ProjectRecord(
        id: 'project-yuechao',
        sceneId: 'scene-03-rainy-dock',
        title: '月潮回声',
        genre: '悬疑 / 8.7 万字',
        summary: '',
        recentLocation: '场景 03 · 雨夜码头',
        lastOpenedAtMs: 0,
      );

  CharacterRecord _currentCharacter() {
    final characters = workspaceStore?.characters ?? const <CharacterRecord>[];
    return characters.isEmpty
        ? const CharacterRecord(
            id: 'placeholder-character',
            name: '柳溪',
            role: '调查记者',
            note: '',
            need: '',
            summary: '',
          )
        : characters.first;
  }

  WorldNodeRecord _currentWorldNode() {
    final worldNodes = workspaceStore?.worldNodes ?? const <WorldNodeRecord>[];
    return worldNodes.isEmpty
        ? const WorldNodeRecord(
            id: 'placeholder-world-node',
            title: '旧港规则',
            location: '',
            type: '规则',
            detail: '',
            summary: '',
          )
        : worldNodes.first;
  }
}

const String _defaultSceneSummary = '当前场景：场景 03 · 雨夜码头';
const String _defaultCharacterSummary = '角色摘要：柳溪 · 调查记者';
const String _defaultWorldSummary = '世界观摘要：港城旧码头 · 风暴预警';
const String _defaultSceneScopeId = 'project-yuechao::scene-05-witness-room';

class AppSceneContextScope extends InheritedNotifier<AppSceneContextStore> {
  const AppSceneContextScope({
    super.key,
    required AppSceneContextStore store,
    required super.child,
  }) : super(notifier: store);

  static AppSceneContextStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSceneContextScope>();
    assert(
      scope != null,
      'AppSceneContextScope is missing in the widget tree.',
    );
    return scope!.notifier!;
  }
}
