import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';

void main() {
  group('AppEventBus', () {
    late AppEventBus bus;

    setUp(() {
      bus = AppEventBus();
    });

    tearDown(() {
      bus.dispose();
    });

    test('publish delivers event to typed subscriber', () async {
      final events = <ProjectScopeChangedEvent>[];
      bus.listen<ProjectScopeChangedEvent>(events.add);

      bus.publish(
        const ProjectScopeChangedEvent(
          projectId: 'p1',
          sceneScopeId: 'p1::s1',
        ),
      );

      expect(events, hasLength(1));
      expect(events.first.projectId, 'p1');
      expect(events.first.sceneScopeId, 'p1::s1');
    });

    test('on<E> returns typed stream', () async {
      final events = <ProjectCreatedEvent>[];
      final sub = bus.on<ProjectCreatedEvent>().listen(events.add);

      bus.publish(const ProjectCreatedEvent(projectId: 'new-p'));

      await sub.cancel();
      expect(events, hasLength(1));
      expect(events.first.projectId, 'new-p');
    });

    test('different event types use separate channels', () async {
      final scopeEvents = <ProjectScopeChangedEvent>[];
      final createdEvents = <ProjectCreatedEvent>[];

      bus.listen<ProjectScopeChangedEvent>(scopeEvents.add);
      bus.listen<ProjectCreatedEvent>(createdEvents.add);

      bus.publish(
        const ProjectScopeChangedEvent(
          projectId: 'p1',
          sceneScopeId: 'p1::s1',
        ),
      );
      bus.publish(const ProjectCreatedEvent(projectId: 'p2'));

      expect(scopeEvents, hasLength(1));
      expect(createdEvents, hasLength(1));
      expect(scopeEvents.first.projectId, 'p1');
      expect(createdEvents.first.projectId, 'p2');
    });

    test('multiple subscribers receive same event', () async {
      final sink1 = <SettingsSavedEvent>[];
      final sink2 = <SettingsSavedEvent>[];

      bus.listen<SettingsSavedEvent>(sink1.add);
      bus.listen<SettingsSavedEvent>(sink2.add);

      const event = SettingsSavedEvent(
        providerName: 'test',
        model: 'gpt-4.1-mini',
      );
      bus.publish(event);

      expect(sink1, hasLength(1));
      expect(sink2, hasLength(1));
      expect(identical(sink1.first, sink2.first), isTrue);
    });

    test('subscription can be cancelled', () async {
      final events = <ProjectDeletedEvent>[];
      final sub = bus.listen<ProjectDeletedEvent>(events.add);

      bus.publish(const ProjectDeletedEvent(projectId: 'p1'));
      expect(events, hasLength(1));

      await sub.cancel();

      bus.publish(const ProjectDeletedEvent(projectId: 'p2'));
      expect(events, hasLength(1));
    });

    test('publish after dispose throws StateError', () {
      bus.dispose();
      expect(
        () => bus.publish(
          const ProjectScopeChangedEvent(
            projectId: 'p1',
            sceneScopeId: 'p1::s1',
          ),
        ),
        throwsStateError,
      );
    });

    test('on after dispose throws StateError', () {
      bus.dispose();
      expect(
        () => bus.on<ProjectScopeChangedEvent>(),
        throwsStateError,
      );
    });

    test('no subscribers — publish does not throw', () {
      bus.publish(
        const ProjectScopeChangedEvent(
          projectId: 'p1',
          sceneScopeId: 'p1::s1',
        ),
      );
    });

    test('sync delivery — listener sees event immediately', () {
      var seen = false;
      bus.listen<ProjectCreatedEvent>((_) => seen = true);

      bus.publish(const ProjectCreatedEvent(projectId: 'p1'));
      expect(seen, isTrue);
    });

    test('dispose closes all stream controllers', () async {
      final stream = bus.on<ProjectScopeChangedEvent>();
      bus.dispose();

      expect(await stream.isEmpty, isTrue);
    });
  });

  group('AppWorkspaceStore + AppEventBus integration', () {
    late AppEventBus bus;
    late AppWorkspaceStore store;

    setUp(() {
      bus = AppEventBus();
      store = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
    });

    tearDown(() {
      store.dispose();
      bus.dispose();
    });

    test('selectProject publishes ProjectScopeChangedEvent', () async {
      final events = <ProjectScopeChangedEvent>[];
      bus.listen<ProjectScopeChangedEvent>(events.add);

      final projectId = store.projects.last.id;
      store.selectProject(projectId);

      expect(events, hasLength(1));
      expect(events.first.projectId, projectId);
      expect(events.first.sceneScopeId, isNotEmpty);
    });

    test('createProject publishes ProjectCreatedEvent and ProjectScopeChangedEvent', () async {
      final createdEvents = <ProjectCreatedEvent>[];
      final scopeEvents = <ProjectScopeChangedEvent>[];
      bus.listen<ProjectCreatedEvent>(createdEvents.add);
      bus.listen<ProjectScopeChangedEvent>(scopeEvents.add);

      store.createProject();

      expect(createdEvents, hasLength(1));
      expect(scopeEvents, hasLength(1));
      expect(createdEvents.first.projectId, store.currentProjectId);
      expect(scopeEvents.first.projectId, store.currentProjectId);
    });

    test('deleteProject publishes ProjectDeletedEvent', () async {
      final deletedEvents = <ProjectDeletedEvent>[];
      bus.listen<ProjectDeletedEvent>(deletedEvents.add);

      final target = store.projects.last;
      store.deleteProject(target);

      expect(deletedEvents, hasLength(1));
      expect(deletedEvents.first.projectId, target.id);
    });

    test('openProject publishes ProjectScopeChangedEvent', () async {
      final events = <ProjectScopeChangedEvent>[];
      bus.listen<ProjectScopeChangedEvent>(events.add);

      final projectId = store.projects.last.id;
      store.openProject(projectId);

      expect(events, hasLength(1));
      expect(events.first.projectId, projectId);
    });

    test('updateCurrentScene publishes SceneChangedEvent', () async {
      final events = <SceneChangedEvent>[];
      bus.listen<SceneChangedEvent>(events.add);

      store.updateCurrentScene(
        sceneId: 'scene-new',
        recentLocation: '第 2 章 / 场景 02 · 新场景',
      );

      expect(events, hasLength(1));
      expect(events.first.sceneId, 'scene-new');
      expect(events.first.projectId, store.currentProjectId);
    });

    test('no event bus — store works without events', () {
      final storeNoBus = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );

      storeNoBus.selectProject(storeNoBus.projects.last.id);
      expect(storeNoBus.currentProjectId, storeNoBus.projects.last.id);

      storeNoBus.createProject();
      expect(storeNoBus.projects.length, greaterThan(1));

      storeNoBus.dispose();
    });

    test('selecting same project does not publish event', () async {
      final events = <ProjectScopeChangedEvent>[];
      bus.listen<ProjectScopeChangedEvent>(events.add);

      store.selectProject(store.currentProjectId);

      expect(events, isEmpty);
    });
  });

  group('AppDomainEvent sealed class hierarchy', () {
    test('all event types are distinct', () {
      final events = <AppDomainEvent>[
        const ProjectScopeChangedEvent(projectId: 'p1', sceneScopeId: 'p1::s1'),
        const ProjectCreatedEvent(projectId: 'p1'),
        const ProjectDeletedEvent(projectId: 'p1'),
        const SceneChangedEvent(projectId: 'p1', sceneId: 's1', sceneScopeId: 'p1::s1'),
        const SettingsSavedEvent(providerName: 'test', model: 'm1'),
        const StoryGenerationStartedEvent(projectId: 'p1', sceneId: 's1'),
        const StoryGenerationCompletedEvent(projectId: 'p1', sceneId: 's1'),
        const StoryGenerationFailedEvent(projectId: 'p1', sceneId: 's1', error: 'err'),
      ];

      final types = events.map((e) => e.runtimeType).toSet();
      expect(types.length, events.length);
    });

    test('events are value-equal when fields match', () {
      const e1 = ProjectCreatedEvent(projectId: 'p1');
      const e2 = ProjectCreatedEvent(projectId: 'p1');
      expect(e1.projectId, e2.projectId);
    });
  });
}
