import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';

void main() {
  group('State consistency via AppEventBus', () {
    late AppEventBus bus;

    setUp(() {
      bus = AppEventBus();
    });

    tearDown(() {
      bus.dispose();
      AppSettingsStore.debugStorageOverride = null;
      AppSettingsStore.debugLlmClientOverride = null;
      StoryGenerationStore.debugStorageOverride = null;
    });

    test('AppSettingsStore.save publishes SettingsSavedEvent', () async {
      final events = <SettingsSavedEvent>[];
      bus.listen<SettingsSavedEvent>(events.add);

      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: _NoOpLlmClient(),
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: 'Test Provider',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'sk-test',
      );

      expect(events, hasLength(1));
      expect(events.first.providerName, 'Test Provider');
      expect(events.first.model, 'gpt-4.1-mini');
    });

    test('settings event carries correct provider and model', () async {
      final events = <SettingsSavedEvent>[];
      bus.listen<SettingsSavedEvent>(events.add);

      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: _NoOpLlmClient(),
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: '智谱 GLM',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        apiKey: 'sk-zhipu-key',
      );

      expect(events, hasLength(1));
      expect(events.first.providerName, '智谱 GLM');
      expect(events.first.model, 'glm-5.1');
    });

    test('settings save with persistence issue does not publish event',
        () async {
      final events = <SettingsSavedEvent>[];
      bus.listen<SettingsSavedEvent>(events.add);

      final store = AppSettingsStore(
        storage: _FailingWriteStorage(),
        llmClient: _NoOpLlmClient(),
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: 'Test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'sk-test',
      );

      expect(events, isEmpty);
    });

    test(
        'StoryGenerationStore.replaceSnapshot publishes '
        'StoryGenerationStartedEvent when generation begins', () {
      final events = <StoryGenerationStartedEvent>[];
      bus.listen<StoryGenerationStartedEvent>(events.add);

      final store = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        eventBus: bus,
      );
      addTearDown(store.dispose);

      store.replaceSnapshot(StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.inProgress,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.directing,
                judgeStatus: StoryReviewStatus.pending,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      ));

      expect(events, hasLength(1));
      expect(events.first.projectId, store.activeProjectId);
      expect(events.first.sceneId, 'scene-1');
    });

    test(
        'StoryGenerationStore.replaceSnapshot publishes '
        'StoryGenerationCompletedEvent when scene passes', () {
      final startedEvents = <StoryGenerationStartedEvent>[];
      final completedEvents = <StoryGenerationCompletedEvent>[];
      bus.listen<StoryGenerationStartedEvent>(startedEvents.add);
      bus.listen<StoryGenerationCompletedEvent>(completedEvents.add);

      final store = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        eventBus: bus,
      );
      addTearDown(store.dispose);

      // First: transition to running
      store.replaceSnapshot(StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.inProgress,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.directing,
                judgeStatus: StoryReviewStatus.pending,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      ));

      // Then: transition to passed
      store.replaceSnapshot(StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.passed,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.passed,
                judgeStatus: StoryReviewStatus.passed,
                consistencyStatus: StoryReviewStatus.passed,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      ));

      expect(startedEvents, hasLength(1));
      expect(completedEvents, hasLength(1));
      expect(completedEvents.first.projectId, store.activeProjectId);
      expect(completedEvents.first.sceneId, 'scene-1');
    });

    test(
        'StoryGenerationStore.replaceSnapshot publishes '
        'StoryGenerationFailedEvent when scene is blocked', () {
      final failedEvents = <StoryGenerationFailedEvent>[];
      bus.listen<StoryGenerationFailedEvent>(failedEvents.add);

      final store = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        eventBus: bus,
      );
      addTearDown(store.dispose);

      // First: transition to running
      store.replaceSnapshot(StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.inProgress,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.drafting,
                judgeStatus: StoryReviewStatus.pending,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      ));

      // Then: transition to blocked
      store.replaceSnapshot(StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.blocked,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.blocked,
                judgeStatus: StoryReviewStatus.failed,
                consistencyStatus: StoryReviewStatus.failed,
                proseRetryCount: 3,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      ));

      expect(failedEvents, hasLength(1));
      expect(failedEvents.first.projectId, store.activeProjectId);
      expect(failedEvents.first.sceneId, 'scene-1');
    });

    test('same phase transition does not publish duplicate events', () {
      final events = <StoryGenerationStartedEvent>[];
      bus.listen<StoryGenerationStartedEvent>(events.add);

      final store = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        eventBus: bus,
      );
      addTearDown(store.dispose);

      final runningSnapshot = StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.inProgress,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.directing,
                judgeStatus: StoryReviewStatus.pending,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      );

      // Replace with running snapshot twice
      store.replaceSnapshot(runningSnapshot);
      store.replaceSnapshot(runningSnapshot.copyWith());

      // Only first transition from idle -> running should fire
      expect(events, hasLength(1));
    });

    test('bus.dispose prevents further publish', () {
      bus.dispose();
      expect(
        () => bus.publish(const SettingsSavedEvent(
          providerName: 'test',
          model: 'test-model',
        )),
        throwsStateError,
      );
    });

    test(
        'StoryGenerationStore without eventBus does not throw '
        'on snapshot transitions', () {
      // No bus set up, so AppEventBus.current is null after dispose in tearDown
      // Create store explicitly without eventBus
      bus.dispose();

      final store = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        eventBus: null,
      );
      addTearDown(store.dispose);

      store.replaceSnapshot(StoryGenerationSnapshot(
        projectId: store.activeProjectId,
        chapters: [
          StoryChapterGenerationState(
            chapterId: 'ch1',
            status: StoryChapterGenerationStatus.inProgress,
            scenes: [
              StorySceneGenerationState(
                sceneId: 'scene-1',
                status: StorySceneGenerationStatus.directing,
                judgeStatus: StoryReviewStatus.pending,
                consistencyStatus: StoryReviewStatus.pending,
                proseRetryCount: 0,
                directorRetryCount: 0,
                upstreamFingerprint: '',
              ),
            ],
          ),
        ],
      ));

      // Should not throw
      expect(store.snapshot.chapters.first.scenes.first.status,
          StorySceneGenerationStatus.directing);
    });
  });
}

class _NoOpLlmClient implements AppLlmClient {
  const _NoOpLlmClient();
  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    return AppLlmChatResult.success(
      text: 'pong',
      latencyMs: 10,
    );
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {}
}

class _FailingWriteStorage implements AppSettingsStorage {
  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.none;

  @override
  String? get lastLoadDetail => null;

  @override
  Future<Map<String, Object?>?> load() async => null;

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult(
      issue: AppSettingsPersistenceIssue.fileWriteFailed,
      detail: 'write failed for test',
    );
  }
}
