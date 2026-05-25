import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/app_providers.dart';
import '../app_workspace_store.dart';

final workspaceCatalogProjectionProvider =
    NotifierProvider<
      WorkspaceCatalogProjectionNotifier,
      WorkspaceCatalogProjection
    >(WorkspaceCatalogProjectionNotifier.new);

class WorkspaceCatalogProjectionNotifier
    extends Notifier<WorkspaceCatalogProjection> {
  @override
  WorkspaceCatalogProjection build() {
    final workspaceStore = ref.read(appWorkspaceStoreProvider);
    void listener() =>
        state = WorkspaceCatalogProjection.fromStore(workspaceStore);
    workspaceStore.addListener(listener);
    ref.onDispose(() => workspaceStore.removeListener(listener));
    return WorkspaceCatalogProjection.fromStore(workspaceStore);
  }
}

final currentProjectProjectionProvider =
    NotifierProvider<
      CurrentProjectProjectionNotifier,
      CurrentProjectProjection
    >(CurrentProjectProjectionNotifier.new);

class CurrentProjectProjectionNotifier
    extends Notifier<CurrentProjectProjection> {
  @override
  CurrentProjectProjection build() {
    final workspaceStore = ref.read(appWorkspaceStoreProvider);
    void listener() =>
        state = CurrentProjectProjection.fromStore(workspaceStore);
    workspaceStore.addListener(listener);
    ref.onDispose(() => workspaceStore.removeListener(listener));
    return CurrentProjectProjection.fromStore(workspaceStore);
  }
}

final sceneCursorProjectionProvider =
    NotifierProvider<SceneCursorProjectionNotifier, SceneCursorProjection>(
      SceneCursorProjectionNotifier.new,
    );

class SceneCursorProjectionNotifier extends Notifier<SceneCursorProjection> {
  @override
  SceneCursorProjection build() {
    final workspaceStore = ref.read(appWorkspaceStoreProvider);
    void listener() => state = SceneCursorProjection.fromStore(workspaceStore);
    workspaceStore.addListener(listener);
    ref.onDispose(() => workspaceStore.removeListener(listener));
    return SceneCursorProjection.fromStore(workspaceStore);
  }
}

class WorkspaceCatalogProjection {
  const WorkspaceCatalogProjection({
    required this.projects,
    required this.projectCount,
    required this.hasProjects,
    required this.lastOpenedAtMs,
  });

  factory WorkspaceCatalogProjection.fromStore(AppWorkspaceStore store) {
    final projects = store.projects;
    final lastOpenedAtMs = projects.isEmpty
        ? 0
        : projects.map((p) => p.lastOpenedAtMs).reduce((a, b) => a > b ? a : b);
    return WorkspaceCatalogProjection(
      projects: [
        for (final project in projects)
          ProjectSummaryProjection(
            id: project.id,
            title: project.title,
            genre: project.genre,
            recentLocation: project.displayRecentLocation,
            lastOpenedAtMs: project.lastOpenedAtMs,
          ),
      ],
      projectCount: projects.length,
      hasProjects: projects.isNotEmpty,
      lastOpenedAtMs: lastOpenedAtMs,
    );
  }

  final List<ProjectSummaryProjection> projects;
  final int projectCount;
  final bool hasProjects;
  final int lastOpenedAtMs;

  @override
  bool operator ==(Object other) {
    return other is WorkspaceCatalogProjection &&
        other.projectCount == projectCount &&
        other.hasProjects == hasProjects &&
        other.lastOpenedAtMs == lastOpenedAtMs &&
        listEquals(other.projects, projects);
  }

  @override
  int get hashCode => Object.hash(
    projectCount,
    hasProjects,
    lastOpenedAtMs,
    Object.hashAll(projects),
  );
}

class ProjectSummaryProjection {
  const ProjectSummaryProjection({
    required this.id,
    required this.title,
    required this.genre,
    required this.recentLocation,
    required this.lastOpenedAtMs,
  });

  final String id;
  final String title;
  final String genre;
  final String recentLocation;
  final int lastOpenedAtMs;

  @override
  bool operator ==(Object other) {
    return other is ProjectSummaryProjection &&
        other.id == id &&
        other.title == title &&
        other.genre == genre &&
        other.recentLocation == recentLocation &&
        other.lastOpenedAtMs == lastOpenedAtMs;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, genre, recentLocation, lastOpenedAtMs);
}

class CurrentProjectProjection {
  const CurrentProjectProjection({
    required this.projectId,
    required this.title,
    required this.genre,
    required this.summary,
    required this.breadcrumb,
    required this.hasCurrentProject,
    required this.characterCount,
    required this.sceneCount,
    required this.worldNodeCount,
    required this.auditIssueCount,
  });

  factory CurrentProjectProjection.fromStore(AppWorkspaceStore store) {
    final project = store.currentProjectOrNull;
    if (project == null) {
      return const CurrentProjectProjection(
        projectId: '',
        title: '',
        genre: '',
        summary: '',
        breadcrumb: '',
        hasCurrentProject: false,
        characterCount: 0,
        sceneCount: 0,
        worldNodeCount: 0,
        auditIssueCount: 0,
      );
    }
    return CurrentProjectProjection(
      projectId: project.id,
      title: project.title,
      genre: project.genre,
      summary: project.summary,
      breadcrumb: store.currentProjectBreadcrumb,
      hasCurrentProject: project.id.isNotEmpty,
      characterCount: store.characters.length,
      sceneCount: store.scenes.length,
      worldNodeCount: store.worldNodes.length,
      auditIssueCount: store.auditIssues.length,
    );
  }

  final String projectId;
  final String title;
  final String genre;
  final String summary;
  final String breadcrumb;
  final bool hasCurrentProject;
  final int characterCount;
  final int sceneCount;
  final int worldNodeCount;
  final int auditIssueCount;

  @override
  bool operator ==(Object other) {
    return other is CurrentProjectProjection &&
        other.projectId == projectId &&
        other.title == title &&
        other.genre == genre &&
        other.summary == summary &&
        other.breadcrumb == breadcrumb &&
        other.hasCurrentProject == hasCurrentProject &&
        other.characterCount == characterCount &&
        other.sceneCount == sceneCount &&
        other.worldNodeCount == worldNodeCount &&
        other.auditIssueCount == auditIssueCount;
  }

  @override
  int get hashCode => Object.hash(
    projectId,
    title,
    genre,
    summary,
    breadcrumb,
    hasCurrentProject,
    characterCount,
    sceneCount,
    worldNodeCount,
    auditIssueCount,
  );
}

class SceneCursorProjection {
  const SceneCursorProjection({
    required this.sceneScopeId,
    required this.sceneId,
    required this.chapterLabel,
    required this.sceneTitle,
    required this.sceneSummary,
    required this.displayLocation,
    required this.hasCurrentScene,
    required this.scenes,
  });

  factory SceneCursorProjection.fromStore(AppWorkspaceStore store) {
    final scene = store.currentSceneOrNull;
    if (scene == null) {
      return const SceneCursorProjection(
        sceneScopeId: '',
        sceneId: '',
        chapterLabel: '',
        sceneTitle: '',
        sceneSummary: '',
        displayLocation: '',
        hasCurrentScene: false,
        scenes: [],
      );
    }
    final scenes = store.scenes;
    return SceneCursorProjection(
      sceneScopeId: store.currentSceneScopeId,
      sceneId: scene.id,
      chapterLabel: scene.chapterLabel,
      sceneTitle: scene.title,
      sceneSummary: scene.summary,
      displayLocation: scene.displayLocation,
      hasCurrentScene: scene.id.isNotEmpty,
      scenes: [
        for (final s in scenes)
          SceneSummaryProjection(
            id: s.id,
            chapterLabel: s.chapterLabel,
            title: s.title,
            summary: s.summary,
            displayLocation: s.displayLocation,
          ),
      ],
    );
  }

  final String sceneScopeId;
  final String sceneId;
  final String chapterLabel;
  final String sceneTitle;
  final String sceneSummary;
  final String displayLocation;
  final bool hasCurrentScene;
  final List<SceneSummaryProjection> scenes;

  @override
  bool operator ==(Object other) {
    return other is SceneCursorProjection &&
        other.sceneScopeId == sceneScopeId &&
        other.sceneId == sceneId &&
        other.chapterLabel == chapterLabel &&
        other.sceneTitle == sceneTitle &&
        other.sceneSummary == sceneSummary &&
        other.displayLocation == displayLocation &&
        other.hasCurrentScene == hasCurrentScene &&
        listEquals(other.scenes, scenes);
  }

  @override
  int get hashCode => Object.hash(
    sceneScopeId,
    sceneId,
    chapterLabel,
    sceneTitle,
    sceneSummary,
    displayLocation,
    hasCurrentScene,
    Object.hashAll(scenes),
  );
}

class SceneSummaryProjection {
  const SceneSummaryProjection({
    required this.id,
    required this.chapterLabel,
    required this.title,
    required this.summary,
    required this.displayLocation,
  });

  final String id;
  final String chapterLabel;
  final String title;
  final String summary;
  final String displayLocation;

  @override
  bool operator ==(Object other) {
    return other is SceneSummaryProjection &&
        other.id == id &&
        other.chapterLabel == chapterLabel &&
        other.title == title &&
        other.summary == summary &&
        other.displayLocation == displayLocation;
  }

  @override
  int get hashCode =>
      Object.hash(id, chapterLabel, title, summary, displayLocation);
}
