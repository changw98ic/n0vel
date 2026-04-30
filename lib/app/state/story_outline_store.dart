import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';

import 'app_project_scoped_store.dart';
import 'app_storage_clone.dart';
import 'story_outline_storage.dart';

const String _fallbackStoryOutlineProjectId = 'project-yuechao';

class StoryOutlineCastSnapshot {
  const StoryOutlineCastSnapshot({
    required this.characterId,
    required this.name,
    required this.role,
    this.metadata = const {},
  });

  final String characterId;
  final String name;
  final String role;
  final Map<String, Object?> metadata;

  StoryOutlineCastSnapshot copyWith({
    String? characterId,
    String? name,
    String? role,
    Map<String, Object?>? metadata,
  }) {
    return StoryOutlineCastSnapshot(
      characterId: characterId ?? this.characterId,
      name: name ?? this.name,
      role: role ?? this.role,
      metadata: metadata ?? this.metadata,
    );
  }

  StoryOutlineCastSnapshot deepCopy() => StoryOutlineCastSnapshot(
    characterId: characterId,
    name: name,
    role: role,
    metadata: cloneStorageMap(metadata),
  );

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'name': name,
      'role': role,
      'metadata': cloneStorageMap(metadata),
    };
  }

  static StoryOutlineCastSnapshot fromJson(Map<String, Object?> json) {
    return StoryOutlineCastSnapshot(
      characterId: json['characterId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      metadata: _asStringObjectMap(json['metadata']),
    );
  }
}

class StoryOutlineSceneSnapshot {
  const StoryOutlineSceneSnapshot({
    required this.id,
    required this.title,
    required this.summary,
    this.cast = const [],
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String summary;
  final List<StoryOutlineCastSnapshot> cast;
  final Map<String, Object?> metadata;

  StoryOutlineSceneSnapshot copyWith({
    String? id,
    String? title,
    String? summary,
    List<StoryOutlineCastSnapshot>? cast,
    Map<String, Object?>? metadata,
  }) {
    return StoryOutlineSceneSnapshot(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      cast: cast ?? this.cast,
      metadata: metadata ?? this.metadata,
    );
  }

  StoryOutlineSceneSnapshot deepCopy() => StoryOutlineSceneSnapshot(
    id: id,
    title: title,
    summary: summary,
    cast: [for (final c in cast) c.deepCopy()],
    metadata: cloneStorageMap(metadata),
  );

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'cast': [for (final entry in cast) entry.toJson()],
      'metadata': cloneStorageMap(metadata),
    };
  }

  static StoryOutlineSceneSnapshot fromJson(Map<String, Object?> json) {
    final rawCast = json['cast'] as List<Object?>? ?? const [];
    return StoryOutlineSceneSnapshot(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      cast: [
        for (final entry in rawCast)
          if (entry is Map)
            StoryOutlineCastSnapshot.fromJson(_asStringObjectMap(entry)),
      ],
      metadata: _asStringObjectMap(json['metadata']),
    );
  }
}

class StoryOutlineChapterSnapshot {
  const StoryOutlineChapterSnapshot({
    required this.id,
    required this.title,
    required this.summary,
    this.scenes = const [],
    this.metadata = const {},
  });

  final String id;
  final String title;
  final String summary;
  final List<StoryOutlineSceneSnapshot> scenes;
  final Map<String, Object?> metadata;

  StoryOutlineChapterSnapshot copyWith({
    String? id,
    String? title,
    String? summary,
    List<StoryOutlineSceneSnapshot>? scenes,
    Map<String, Object?>? metadata,
  }) {
    return StoryOutlineChapterSnapshot(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      scenes: scenes ?? this.scenes,
      metadata: metadata ?? this.metadata,
    );
  }

  StoryOutlineChapterSnapshot deepCopy() => StoryOutlineChapterSnapshot(
    id: id,
    title: title,
    summary: summary,
    scenes: [for (final s in scenes) s.deepCopy()],
    metadata: cloneStorageMap(metadata),
  );

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'scenes': [for (final scene in scenes) scene.toJson()],
      'metadata': cloneStorageMap(metadata),
    };
  }

  static StoryOutlineChapterSnapshot fromJson(Map<String, Object?> json) {
    final rawScenes = json['scenes'] as List<Object?>? ?? const [];
    return StoryOutlineChapterSnapshot(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      scenes: [
        for (final entry in rawScenes)
          if (entry is Map)
            StoryOutlineSceneSnapshot.fromJson(_asStringObjectMap(entry)),
      ],
      metadata: _asStringObjectMap(json['metadata']),
    );
  }
}

class StoryOutlineSnapshot {
  const StoryOutlineSnapshot({
    required this.projectId,
    this.chapters = const [],
    this.metadata = const {},
    this.executablePlan,
  });

  final String projectId;
  final List<StoryOutlineChapterSnapshot> chapters;
  final Map<String, Object?> metadata;

  /// Optional executable plan providing structured scene-level detail.
  /// Null for legacy snapshots that predate plan support.
  final NovelPlan? executablePlan;

  /// Returns true when an executable plan is available.
  bool get hasExecutablePlan => executablePlan != null;

  /// Returns scene plans from the executable plan, or empty list.
  List<ScenePlan> get scenePlans {
    if (executablePlan == null) return const [];
    return [
      for (final chapter in executablePlan!.chapters)
        for (final scene in chapter.scenes) scene,
    ];
  }

  StoryOutlineSnapshot copyWith({
    String? projectId,
    List<StoryOutlineChapterSnapshot>? chapters,
    Map<String, Object?>? metadata,
    NovelPlan? executablePlan,
    bool clearExecutablePlan = false,
  }) {
    return StoryOutlineSnapshot(
      projectId: projectId ?? this.projectId,
      chapters: chapters ?? this.chapters,
      metadata: metadata ?? this.metadata,
      executablePlan: clearExecutablePlan
          ? null
          : (executablePlan ?? this.executablePlan),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'projectId': projectId,
      'chapters': [for (final chapter in chapters) chapter.toJson()],
      'metadata': cloneStorageMap(metadata),
      if (executablePlan != null) 'executablePlan': executablePlan!.toJson(),
    };
  }

  static StoryOutlineSnapshot empty(String projectId) {
    return StoryOutlineSnapshot(projectId: projectId);
  }

  StoryOutlineSnapshot deepCopy() => StoryOutlineSnapshot(
    projectId: projectId,
    chapters: [for (final chapter in chapters) chapter.deepCopy()],
    metadata: cloneStorageMap(metadata),
    executablePlan: executablePlan,
  );

  static StoryOutlineSnapshot fromJson(Map<String, Object?> json) {
    final projectId =
        json['projectId']?.toString() ?? _fallbackStoryOutlineProjectId;
    final rawChapters = json['chapters'] as List<Object?>? ?? const [];
    return StoryOutlineSnapshot(
      projectId: projectId,
      chapters: [
        for (final entry in rawChapters)
          if (entry is Map)
            StoryOutlineChapterSnapshot.fromJson(_asStringObjectMap(entry)),
      ],
      metadata: _asStringObjectMap(json['metadata']),
      executablePlan: json['executablePlan'] is Map
          ? NovelPlan.fromJson(
              Map<Object?, Object?>.from(json['executablePlan'] as Map),
            )
          : null,
    );
  }

  /// Ensure legacy data still loads correctly.
  /// If executablePlan is null, the snapshot is legacy format.
  static StoryOutlineSnapshot fromLegacyJson(Map<Object?, Object?> json) {
    final projectId =
        json['projectId']?.toString() ?? _fallbackStoryOutlineProjectId;
    final rawChapters = json['chapters'] as List<Object?>? ?? const [];
    return StoryOutlineSnapshot(
      projectId: projectId,
      chapters: [
        for (final entry in rawChapters)
          if (entry is Map)
            StoryOutlineChapterSnapshot.fromJson(_asStringObjectMap(entry)),
      ],
      metadata: json['metadata'] is Map
          ? _asStringObjectMap(json['metadata'])
          : const {},
    );
  }
}

class StoryOutlineStore extends AppProjectScopedStore {
  StoryOutlineStore({StoryOutlineStorage? storage, super.workspaceStore})
    : _storage =
          storage ?? debugStorageOverride ?? createDefaultStoryOutlineStorage(),
      super(
        scopeMode: AppStoreScopeMode.project,
        fallbackProjectId: _fallbackStoryOutlineProjectId,
      ) {
    _snapshot = StoryOutlineSnapshot.empty(activeProjectId);
    onRestore();
  }

  @visibleForTesting
  static StoryOutlineStorage? debugStorageOverride;

  final StoryOutlineStorage _storage;
  final Map<String, StoryOutlineSnapshot> _snapshotsByProjectId = {};
  late StoryOutlineSnapshot _snapshot;

  StoryOutlineSnapshot get snapshot => _snapshot.deepCopy();

  Map<String, Object?> exportJson() => _snapshot.toJson();

  void importJson(Map<String, Object?> data) {
    replaceSnapshot(
      StoryOutlineSnapshot.fromJson({
        for (final entry in data.entries) entry.key: entry.value,
        'projectId': activeProjectId,
      }),
    );
  }

  void replaceSnapshot(StoryOutlineSnapshot snapshot) {
    markMutated();
    _snapshot = snapshot.deepCopy().copyWith(projectId: activeProjectId);
    _snapshotsByProjectId[activeProjectId] = _snapshot.deepCopy();
    unawaited(_persist());
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _snapshot =
        _snapshotsByProjectId[nextProjectId]?.deepCopy() ??
        StoryOutlineSnapshot.empty(nextProjectId);
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion || restored == null) {
      return;
    }
    _snapshot = StoryOutlineSnapshot.fromJson({
      for (final entry in restored.entries) entry.key: entry.value,
      'projectId': activeProjectId,
    });
    _snapshotsByProjectId[activeProjectId] = _snapshot.deepCopy();
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(_snapshot.toJson(), projectId: activeProjectId);
}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {for (final entry in value.entries) entry.key.toString(): entry.value};
}
