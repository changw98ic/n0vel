import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/projection/workspace_projection.dart';

void main() {
  group('WorkspaceCatalogProjection', () {
    test('reads default seeded workspace state', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final projection = container.read(workspaceCatalogProjectionProvider);

      // Default workspace is seeded with 3 sample projects
      expect(projection.hasProjects, isTrue);
      expect(projection.projectCount, equals(3));
      expect(projection.projects, isNotEmpty);
      expect(projection.lastOpenedAtMs, greaterThan(0));
    });

    test('reads default project summaries', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final projection = container.read(workspaceCatalogProjectionProvider);

      // Default seeded projects should be present
      expect(projection.projectCount, equals(3));
      final titles = projection.projects.map((p) => p.title).toSet();
      expect(titles, contains('月潮回声'));
      expect(titles, contains('盐港档案'));
      expect(titles, contains('灰烬天气'));
    });

    test('project count increases after creating new project', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final before = container.read(workspaceCatalogProjectionProvider);
      final initialCount = before.projectCount;

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '测试项目');
      await container.pump();

      final after = container.read(workspaceCatalogProjectionProvider);
      expect(after.projectCount, equals(initialCount + 1));
      expect(after.projects.map((p) => p.title), contains('测试项目'));
    });

    test('provider updates when AppWorkspaceStore notifies', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      var notificationCount = 0;
      container.listen<WorkspaceCatalogProjection>(
        workspaceCatalogProjectionProvider,
        (_, _) => notificationCount++,
      );

      expect(notificationCount, equals(0));

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '新建项目');
      await container.pump();

      expect(notificationCount, greaterThan(0));
    });

    test('provider can resolve without serviceRegistryProvider', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(workspaceCatalogProjectionProvider),
        returnsNormally,
      );
    });
  });

  group('CurrentProjectProjection', () {
    test('reads default current project from seeded workspace', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final projection = container.read(currentProjectProjectionProvider);

      // Default workspace has a current project set
      expect(projection.hasCurrentProject, isTrue);
      expect(projection.projectId, isNotEmpty);
      expect(projection.title, isNotEmpty);
      expect(projection.breadcrumb, isNotEmpty);
      expect(projection.characterCount, greaterThanOrEqualTo(0));
      expect(projection.sceneCount, greaterThanOrEqualTo(0));
    });

    test('reads current project summary after project creation', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '当前项目');
      await container.pump();

      final projection = container.read(currentProjectProjectionProvider);

      expect(projection.hasCurrentProject, isTrue);
      expect(projection.title, contains('当前项目'));
      expect(projection.breadcrumb, isNotEmpty);
      expect(projection.characterCount, greaterThanOrEqualTo(0));
      expect(projection.sceneCount, greaterThanOrEqualTo(0));
    });

    test('reads project and scene list summaries', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '多场景项目');
      await container.pump();

      final projection = container.read(currentProjectProjectionProvider);

      expect(projection.hasCurrentProject, isTrue);
      expect(projection.characterCount, greaterThanOrEqualTo(0));
      expect(projection.sceneCount, greaterThan(0));
      expect(projection.worldNodeCount, greaterThanOrEqualTo(0));
      expect(projection.auditIssueCount, greaterThanOrEqualTo(0));
    });

    test('provider updates when workspace state changes', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      var notificationCount = 0;
      container.listen<CurrentProjectProjection>(
        currentProjectProjectionProvider,
        (_, _) => notificationCount++,
      );

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '新项目');
      await container.pump();

      expect(notificationCount, greaterThan(0));
    });

    test('provider can resolve without serviceRegistryProvider', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(currentProjectProjectionProvider),
        returnsNormally,
      );
    });
  });

  group('SceneCursorProjection', () {
    test('reads default current scene from seeded workspace', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final projection = container.read(sceneCursorProjectionProvider);

      // Default workspace has a current scene set
      expect(projection.hasCurrentScene, isTrue);
      expect(projection.sceneScopeId, isNotEmpty);
      expect(projection.sceneId, isNotEmpty);
      expect(projection.chapterLabel, isNotEmpty);
      expect(projection.scenes, isNotEmpty);
    });

    test('reads current scene/scope summary after project creation', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '场景项目');
      await container.pump();

      final projection = container.read(sceneCursorProjectionProvider);

      expect(projection.hasCurrentScene, isTrue);
      expect(projection.sceneScopeId, isNotEmpty);
      expect(projection.sceneId, isNotEmpty);
      expect(projection.chapterLabel, isNotEmpty);
      expect(projection.displayLocation, isNotEmpty);
    });

    test('reads scene list summaries', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '多场景项目');
      await container.pump();

      final projection = container.read(sceneCursorProjectionProvider);

      expect(projection.hasCurrentScene, isTrue);
      expect(projection.scenes, isNotEmpty);
      expect(projection.scenes.first.chapterLabel, isNotEmpty);
      expect(projection.scenes.first.displayLocation, isNotEmpty);
    });

    test('provider updates when scene selection changes', () async {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      var notificationCount = 0;
      container.listen<SceneCursorProjection>(
        sceneCursorProjectionProvider,
        (_, _) => notificationCount++,
      );

      final store = container.read(appWorkspaceStoreProvider);
      store.createProject(projectName: '项目A');
      await container.pump();

      expect(notificationCount, greaterThan(0));

      final before = container.read(sceneCursorProjectionProvider);
      store.createProject(projectName: '项目B');
      await container.pump();

      final after = container.read(sceneCursorProjectionProvider);
      expect(after.sceneId, isNot(equals(before.sceneId)));
    });

    test('provider can resolve without serviceRegistryProvider', () {
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        () => container.read(sceneCursorProjectionProvider),
        returnsNormally,
      );
    });
  });

  group('Projection equality', () {
    test('WorkspaceCatalogProjection equality works', () {
      const p1 = WorkspaceCatalogProjection(
        projects: [],
        projectCount: 0,
        hasProjects: false,
        lastOpenedAtMs: 0,
      );
      const p2 = WorkspaceCatalogProjection(
        projects: [],
        projectCount: 0,
        hasProjects: false,
        lastOpenedAtMs: 0,
      );
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('CurrentProjectProjection equality works', () {
      const p1 = CurrentProjectProjection(
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
      const p2 = CurrentProjectProjection(
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
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
    });

    test('SceneCursorProjection equality works', () {
      const p1 = SceneCursorProjection(
        sceneScopeId: '',
        sceneId: '',
        chapterLabel: '',
        sceneTitle: '',
        sceneSummary: '',
        displayLocation: '',
        hasCurrentScene: false,
        scenes: [],
      );
      const p2 = SceneCursorProjection(
        sceneScopeId: '',
        sceneId: '',
        chapterLabel: '',
        sceneTitle: '',
        sceneSummary: '',
        displayLocation: '',
        hasCurrentScene: false,
        scenes: [],
      );
      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
    });
  });
}
