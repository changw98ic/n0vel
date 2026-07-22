import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_project_scoped_store.dart';
import 'app_scene_context_storage.dart';
import 'app_workspace_store.dart';
import 'persist_guard.dart';
import 'project_storage.dart';

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
    super.eventBus,
  }) : _storage = storage ?? createDefaultAppSceneContextStorage(),
       super(fallbackProjectId: _defaultSceneScopeId) {
    _snapshot = _snapshotForScope(activeProjectId);
    onRestore();
  }

  final AppSceneContextStorage _storage;
  final Map<String, AppSceneContextSnapshot> _snapshotsByProjectId = {};
  late AppSceneContextSnapshot _snapshot;

  @override
  ProjectStorage get persistenceStorage => _storage;

  AppSceneContextSnapshot get snapshot => _snapshot;

  void syncContext() {
    markMutated();
    final nextSnapshot = switch (activeProjectId) {
      '' => const AppSceneContextSnapshot(
        sceneSummary: '',
        characterSummary: '',
        worldSummary: '',
      ),
      _ => AppSceneContextSnapshot(
        sceneSummary:
            '当前章节：${chapterLocationLabel(_currentProject().displayRecentLocation)}',
        characterSummary: '角色摘要：${_currentCharacter().name} · 已重新同步',
        worldSummary: '世界观摘要：${_currentWorldNode().title} · 已刷新',
      ),
    };
    _snapshotsByProjectId[activeProjectId] = nextSnapshot;
    _snapshot = nextSnapshot;
    unawaited(safePersist(_persist, eventBus: eventBus));
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
    unawaited(safePersist(_persist, eventBus: eventBus));
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

  @override
  void onProjectDeleted(String projectId) {
    final sceneScopePrefix = '$projectId::';
    _snapshotsByProjectId.removeWhere(
      (key, _) => key == projectId || key.startsWith(sceneScopePrefix),
    );
  }

  @override
  Future<void> clearDeletedProjectScope(String projectId) =>
      _storage.clearProject(projectId);

  AppSceneContextSnapshot _snapshotForScope(String projectId) {
    return _snapshotsByProjectId.putIfAbsent(
      projectId,
      () => switch (projectId) {
        '' => const AppSceneContextSnapshot(
          sceneSummary: _defaultSceneSummary,
          characterSummary: _defaultCharacterSummary,
          worldSummary: _defaultWorldSummary,
        ),
        _ => AppSceneContextSnapshot(
          sceneSummary:
              '当前章节：${chapterLocationLabel(_currentProject().displayRecentLocation)} · 等待同步',
          characterSummary:
              '角色摘要：${_currentCharacter().name} · ${_currentCharacter().role}',
          worldSummary:
              '世界观摘要：${_currentWorldNode().title} · ${_currentWorldNode().type}',
        ),
      },
    );
  }

  ProjectRecord _currentProject() =>
      workspaceStore?.currentProjectOrNull ??
      const ProjectRecord(
        id: '',
        sceneId: '',
        title: '',
        genre: '',
        summary: '',
        recentLocation: '',
        lastOpenedAtMs: 0,
      );

  CharacterRecord _currentCharacter() {
    final characters = workspaceStore?.characters ?? const <CharacterRecord>[];
    return characters.isEmpty
        ? const CharacterRecord(id: '', name: '')
        : characters.first;
  }

  WorldNodeRecord _currentWorldNode() {
    final worldNodes = workspaceStore?.worldNodes ?? const <WorldNodeRecord>[];
    return worldNodes.isEmpty
        ? const WorldNodeRecord(id: '', title: '')
        : worldNodes.first;
  }
}

const String _defaultSceneSummary = '';
const String _defaultCharacterSummary = '';
const String _defaultWorldSummary = '';
const String _defaultSceneScopeId = '';

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
