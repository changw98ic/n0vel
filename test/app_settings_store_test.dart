import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_templates.dart';
import 'test_support/app_llm_authorized_request.dart';
import 'test_support/app_settings_fake_storages.dart';

void main() {
  test(
    'local CCR-compatible endpoints can be saved without placeholder token',
    () async {
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: _CapturingLlmClient(),
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: 'CCR',
        baseUrl: 'http://127.0.0.1:3456/v1',
        model: 'gpt-5.4',
        apiKey: '',
        timeoutMs: 30000,
      );

      expect(store.canSaveConfiguration, isTrue);
      expect(store.canRunConnectionTest, isTrue);
      expect(store.snapshot.hasApiKey, isFalse);
    },
  );

  test(
    'settings store surfaces read failure as persistence issue on restore',
    () async {
      final store = AppSettingsStore(
        storage: ReadFailureWarningStorage(),
        llmClient: _CapturingLlmClient(),
      );
      addTearDown(store.dispose);

      await Future<void>.delayed(Duration.zero);

      expect(store.hasPersistenceIssue, isTrue);
      expect(
        store.activePersistenceIssue,
        AppSettingsPersistenceIssue.fileReadFailed,
      );
      expect(store.canRetrySecureStoreAccess, isTrue);
      expect(store.feedback.title, '设置文件读取失败');
      expect(store.feedback.message, contains('无法读取本地配置文件'));
    },
  );

  test(
    'settings store keeps read-failure warning when restore completes after local mutation',
    () async {
      final storage = _DelayedReadWithFailureAndWriteFailureStorage();
      final store = AppSettingsStore(
        storage: storage,
        llmClient: _CapturingLlmClient(),
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: 'Draft Provider',
        baseUrl: 'https://draft.local/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-draft',
      );

      storage.completeRead();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        store.activePersistenceIssue,
        AppSettingsPersistenceIssue.fileReadFailed,
      );
      expect(store.canRetrySecureStoreAccess, isTrue);
      expect(store.feedback.title, '设置文件读取失败');
      expect(store.snapshot.providerName, 'Draft Provider');
      expect(store.feedback.message, contains('无法读取本地配置文件'));
    },
  );

  test(
    'save warning survives delayed restore success when local edits already exist',
    () async {
      final storage = _DelayedReadThenWriteRecoveryStorage();
      final store = AppSettingsStore(
        storage: storage,
        llmClient: _CapturingLlmClient(),
      );
      addTearDown(store.dispose);

      await store.saveWithFeedback(
        providerName: 'Draft Provider',
        baseUrl: 'https://draft.local/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-draft',
        timeoutMs: 30000,
      );
      expect(
        store.activePersistenceIssue,
        AppSettingsPersistenceIssue.fileWriteFailed,
      );
      expect(store.canRetrySecureStoreAccess, isTrue);
      expect(store.feedback.title, '设置保存失败');
      expect(store.snapshot.providerName, 'Draft Provider');

      storage.completeRead();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        store.activePersistenceIssue,
        AppSettingsPersistenceIssue.fileWriteFailed,
      );
      expect(store.canRetrySecureStoreAccess, isTrue);
      expect(store.feedback.title, '设置保存失败');
      expect(store.snapshot.providerName, 'Draft Provider');
      expect(store.snapshot.apiKey, 'sk-draft');

      await store.retrySecureStoreAccess();

      expect(store.activePersistenceIssue, AppSettingsPersistenceIssue.none);
      expect(store.feedback.title, '配置已重新保存');
      expect(store.snapshot.providerName, 'Draft Provider');
      expect(store.snapshot.apiKey, 'sk-draft');
    },
  );

  test(
    'successful save clears local mutation flag before read-retry restore',
    () async {
      final storage = _ReadFailureThenRecoveryStorage();
      final store = AppSettingsStore(
        storage: storage,
        llmClient: _CapturingLlmClient(),
      );
      addTearDown(store.dispose);

      await Future<void>.delayed(Duration.zero);
      expect(
        store.activePersistenceIssue,
        AppSettingsPersistenceIssue.fileReadFailed,
      );
      expect(store.snapshot.apiKey, 'sk-initial');

      await store.saveWithFeedback(
        providerName: 'Draft Provider',
        baseUrl: 'https://draft.local/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-draft',
        timeoutMs: 30000,
        maxConcurrentRequests: 4,
      );

      expect(store.activePersistenceIssue, AppSettingsPersistenceIssue.none);
      expect(store.feedback.title, '保存成功');

      await store.retrySecureStoreAccess();

      expect(store.activePersistenceIssue, AppSettingsPersistenceIssue.none);
      expect(store.snapshot.providerName, '智谱 GLM');
      expect(store.snapshot.baseUrl, 'https://api.openai.com/v1');
      expect(store.snapshot.model, 'glm-4');
      expect(store.snapshot.apiKey, 'sk-recovered');
    },
  );

  test(
    'settings store clears write blocker after secure-store retry',
    () async {
      final store = AppSettingsStore(
        storage: RecoveringWriteStorage(),
        llmClient: _CapturingLlmClient(),
      );
      addTearDown(store.dispose);

      await store.saveWithFeedback(
        providerName: 'OpenAI 兼容服务',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-warning-key',
        timeoutMs: 30000,
      );

      expect(
        store.activePersistenceIssue,
        AppSettingsPersistenceIssue.fileWriteFailed,
      );
      expect(store.canRetrySecureStoreAccess, isTrue);
      expect(store.feedback.title, '设置保存失败');

      await store.retrySecureStoreAccess();

      expect(store.activePersistenceIssue, AppSettingsPersistenceIssue.none);
      expect(store.canRetrySecureStoreAccess, isFalse);
      expect(store.feedback.title, '配置已重新保存');
    },
  );

  test('settings store recovers persisted read failure with retry', () async {
    final store = AppSettingsStore(
      storage: RecoveringReadStorage(),
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(store.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(
      store.activePersistenceIssue,
      AppSettingsPersistenceIssue.fileReadFailed,
    );
    expect(store.feedback.title, '设置文件读取失败');
    expect(store.snapshot.apiKey, isEmpty);

    await store.retrySecureStoreAccess();

    expect(store.activePersistenceIssue, AppSettingsPersistenceIssue.none);
    expect(store.feedback.title, '配置已重新加载');
    expect(store.snapshot.providerName, '智谱 GLM');
    expect(store.snapshot.baseUrl, 'https://api.openai.com/v1');
    expect(store.snapshot.model, 'glm-4');
    expect(store.snapshot.apiKey, 'sk-recovered-key');
    expect(store.snapshot.maxConcurrentRequests, 2);
    expect(store.snapshot.maxTokens, 4096);
    expect(
      store.snapshot.providerProfiles
          .singleWhere((p) => p.id == 'zhipu-fallback')
          .providerName,
      '智谱 GLM',
    );
    expect(
      store.snapshot.providerProfiles
          .singleWhere((p) => p.id == 'zhipu-fallback')
          .id,
      'zhipu-fallback',
    );
    expect(
      store.snapshot.requestProviderRoutes.single.traceNamePattern,
      'scene_review_*',
    );
    expect(
      store.snapshot.requestProviderRoutes.single.providerProfileId,
      'zhipu-fallback',
    );
    expect(store.feedback.message, contains('本地配置文件已重新读取，当前配置已同步。'));
  });

  test('local CCR-compatible endpoints accept routed model names', () async {
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(store.dispose);

    await store.save(
      providerName: 'CCR',
      baseUrl: 'http://localhost:20128/v1',
      model: 'gemini-2.5-pro',
      apiKey: '',
      timeoutMs: 30000,
    );

    expect(store.hasSupportedModel, isTrue);
    expect(store.canSaveConfiguration, isTrue);
  });

  test('Xiaomi MiMo models are accepted as supported cloud models', () async {
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(store.dispose);

    expect(store.isSupportedModel('mimo-v2.5-pro'), isTrue);
    expect(store.isSupportedModel('mimo-v2.5'), isTrue);
    expect(store.isSupportedModel('mimo-v2-pro'), isTrue);
  });

  test('Zhipu GLM models are accepted as supported cloud models', () async {
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(store.dispose);

    expect(store.isSupportedModel('glm-5.1'), isTrue);
    expect(store.isSupportedModel('glm-5'), isTrue);
    expect(store.isSupportedModel('glm-4.7'), isTrue);
    expect(store.isSupportedModel('glm-4.6'), isTrue);
  });

  test('common Chinese provider catalog models are accepted', () async {
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(store.dispose);

    expect(store.isSupportedModel('qwen-plus'), isTrue);
    expect(store.isSupportedModel('qwen3.6-plus'), isTrue);
    expect(store.isSupportedModel('qwen-plus-us'), isTrue);
    expect(store.isSupportedModel('qwen3-coder-plus'), isTrue);
    expect(store.isSupportedModel('doubao-seed-1-6-250615'), isTrue);
    expect(store.isSupportedModel('ark-code-latest'), isTrue);
    expect(store.isSupportedModel('kimi-for-coding'), isTrue);
    expect(store.isSupportedModel('MiniMax-M2.7'), isTrue);
    expect(store.isSupportedModel('codex-MiniMax-M2.7'), isTrue);
    expect(store.isSupportedModel('hunyuan-turbos-latest'), isTrue);
    expect(store.isSupportedModel('hunyuan-2.0-instruct'), isTrue);
    expect(store.isSupportedModel('LongCat-Flash-Chat'), isTrue);
    expect(store.isSupportedModel('glm-6-preview'), isTrue);
    expect(store.isSupportedModel('xiaomi/mimo-v2-pro'), isTrue);
  });

  test('provider routing config round-trips through settings json', () {
    final snapshot = AppSettingsSnapshot.fromJson({
      'providerName': '智谱 GLM',
      'baseUrl': 'https://open.bigmodel.cn/api/paas/v4',
      'model': 'glm-5.1',
      'apiKey': 'zhipu-key',
      'providerProfiles': [
        {
          'id': 'ollama-kimi',
          'providerName': 'Ollama Cloud',
          'baseUrl': 'https://ollama.com/v1',
          'model': 'kimi-k2.6',
          'apiKey': 'ollama-key',
        },
      ],
      'requestProviderRoutes': [
        {
          'traceNamePattern': 'scene_review_*',
          'providerProfileId': 'ollama-kimi',
        },
      ],
    });

    expect(
      snapshot.providerProfiles.singleWhere((p) => p.id == 'ollama-kimi').id,
      'ollama-kimi',
    );
    expect(
      snapshot.requestProviderRoutes.single.traceNamePattern,
      'scene_review_*',
    );

    final encoded = snapshot.toJson();
    final profiles = encoded['providerProfiles'] as List<Object?>;
    final routes = encoded['requestProviderRoutes'] as List<Object?>;
    expect(profiles, hasLength(2));
    expect(
      (profiles.cast<Map>().singleWhere(
        (p) => p['id'] == 'ollama-kimi',
      ))['model'],
      'kimi-k2.6',
    );
    expect((routes.single as Map)['providerProfileId'], 'ollama-kimi');
  });

  test('bigmodel base URL selects Zhipu provider for requests', () async {
    final llmClient = _CapturingLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    await store.save(
      providerName: 'OpenAI 兼容服务',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-5.1',
      apiKey: 'zhipu-key',
      timeoutMs: 30000,
    );
    await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'hi')],
    );

    expect(llmClient.lastRequest, isNotNull);
    expect(llmClient.lastRequest!.provider, AppLlmProvider.zhipu);
  });

  test('routes request traces to configured provider profiles', () async {
    final llmClient = _CapturingLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    await store.save(
      providerName: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-5.1',
      apiKey: 'zhipu-key',
      providerProfiles: const [
        AppLlmProviderProfile(
          id: 'ollama-kimi',
          providerName: 'Ollama Cloud',
          baseUrl: 'https://ollama.com/v1',
          model: 'kimi-k2.6',
          apiKey: 'ollama-key',
        ),
        AppLlmProviderProfile(
          id: 'mimo',
          providerName: 'Xiaomi MiMo',
          baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
          model: 'mimo-v2.5-pro',
          apiKey: 'mimo-key',
        ),
      ],
      requestProviderRoutes: const [
        AppLlmRequestProviderRoute(
          traceNamePattern: 'scene_review_*',
          providerProfileId: 'ollama-kimi',
        ),
        AppLlmRequestProviderRoute(
          traceNamePattern: 'scene_quality_scoring',
          providerProfileId: 'mimo',
        ),
      ],
    );

    await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
      traceName: 'scene_review_plot',
    );
    expect(llmClient.requests.last.provider, AppLlmProvider.ollama);
    expect(llmClient.requests.last.baseUrl, 'https://ollama.com/v1');
    expect(llmClient.requests.last.model, 'kimi-k2.6');
    expect(llmClient.requests.last.apiKey, 'ollama-key');

    await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'score')],
      traceName: 'scene_quality_scoring',
    );
    expect(llmClient.requests.last.provider, AppLlmProvider.mimo);
    expect(
      llmClient.requests.last.baseUrl,
      'https://token-plan-cn.xiaomimimo.com/v1',
    );
    expect(llmClient.requests.last.model, 'mimo-v2.5-pro');
    expect(llmClient.requests.last.apiKey, 'mimo-key');

    await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'draft')],
      traceName: 'scene_prose_generation',
    );
    expect(llmClient.requests.last.provider, AppLlmProvider.zhipu);
    expect(
      llmClient.requests.last.baseUrl,
      'https://open.bigmodel.cn/api/paas/v4',
    );
    expect(llmClient.requests.last.model, 'glm-5.1');
    expect(llmClient.requests.last.apiKey, 'zhipu-key');
  });

  test(
    'requestAiCompletion routes to profile and logs providerProfileId + model in event metadata',
    () async {
      final llmClient = _CapturingLlmClient(
        result: const AppLlmChatResult.success(
          text: 'review done',
          latencyMs: 5,
          promptTokens: 10,
          completionTokens: 5,
          totalTokens: 15,
        ),
      );
      final traceSink = _RecordingLlmTraceSink();
      final eventStorage = _InMemoryEventLogStorage();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
        eventLog: AppEventLog(
          storage: eventStorage,
          sessionId: 'metadata-test',
        ),
        llmTraceSink: traceSink,
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: '智谱 GLM',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        apiKey: 'zhipu-key',
        providerProfiles: const [
          AppLlmProviderProfile(
            id: 'ollama-kimi',
            providerName: 'Ollama Cloud',
            baseUrl: 'https://ollama.com/v1',
            model: 'kimi-k2.6',
            apiKey: 'ollama-key',
          ),
        ],
        requestProviderRoutes: const [
          AppLlmRequestProviderRoute(
            traceNamePattern: 'scene_review_*',
            providerProfileId: 'ollama-kimi',
          ),
        ],
      );

      await requestAuthorizedAiCompletionForTest(
        store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
        traceName: 'scene_review_plot',
      );

      expect(llmClient.requests.last.provider, AppLlmProvider.ollama);
      expect(llmClient.requests.last.model, 'kimi-k2.6');
      expect(llmClient.requests.last.baseUrl, 'https://ollama.com/v1');
      expect(llmClient.requests.last.apiKey, 'ollama-key');

      expect(traceSink.entries, hasLength(1));
      expect(
        traceSink.entries.single.metadata['providerProfileId'],
        'ollama-kimi',
      );

      final llmEvents = eventStorage.entries
          .where((entry) => entry.action == 'llm.chat')
          .toList();
      expect(llmEvents, hasLength(1));
      expect(llmEvents.single.metadata['model'], 'kimi-k2.6');
      final nestedMetadata = llmEvents.single.metadata['metadata'];
      expect(nestedMetadata, isA<Map>());
      expect((nestedMetadata as Map)['providerProfileId'], 'ollama-kimi');
    },
  );

  test(
    'falls back to default provider when a routed profile is incomplete',
    () async {
      final llmClient = _CapturingLlmClient();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: '智谱 GLM',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        apiKey: 'zhipu-key',
        providerProfiles: const [
          AppLlmProviderProfile(
            id: 'ollama-kimi',
            providerName: 'Ollama Cloud',
            baseUrl: 'https://ollama.com/v1',
            model: 'kimi-k2.6',
            apiKey: '',
          ),
        ],
        requestProviderRoutes: const [
          AppLlmRequestProviderRoute(
            traceNamePattern: 'scene_review_*',
            providerProfileId: 'ollama-kimi',
          ),
        ],
      );

      await requestAuthorizedAiCompletionForTest(
        store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
        traceName: 'scene_review_plot',
      );

      expect(llmClient.lastRequest, isNotNull);
      expect(llmClient.lastRequest!.provider, AppLlmProvider.zhipu);
      expect(llmClient.lastRequest!.model, 'glm-5.1');
    },
  );

  test(
    'connection test sends no auth token for local CCR-compatible endpoint',
    () async {
      final llmClient = _CapturingLlmClient();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
      );
      addTearDown(store.dispose);

      await store.testConnection(
        baseUrl: 'http://localhost:3456/v1',
        model: 'gpt-5.4-mini',
        apiKey: '',
        timeoutMs: 30000,
      );

      expect(llmClient.lastRequest, isNotNull);
      expect(llmClient.lastRequest!.apiKey, isEmpty);
      expect(
        store.connectionTestState.status,
        AppSettingsConnectionTestStatus.success,
      );
    },
  );

  test('remote cloud endpoints still require a real API key', () async {
    final llmClient = _CapturingLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    await store.testConnection(
      baseUrl: 'https://api.example.com/v1',
      model: 'gpt-5.4',
      apiKey: '',
      timeoutMs: 30000,
    );

    expect(llmClient.lastRequest, isNull);
    expect(
      store.connectionTestState.outcome,
      AppSettingsConnectionTestOutcome.missingApiKey,
    );
  });

  test(
    'requestAiCompletion records token usage trace and event metadata',
    () async {
      final llmClient = _CapturingLlmClient(
        result: const AppLlmChatResult.success(
          text: '生成正文',
          latencyMs: 7,
          promptTokens: 11,
          completionTokens: 3,
          totalTokens: 14,
        ),
      );
      final traceSink = _RecordingLlmTraceSink();
      final eventStorage = _InMemoryEventLogStorage();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
        eventLog: AppEventLog(
          storage: eventStorage,
          sessionId: 'settings-test',
        ),
        llmTraceSink: traceSink,
      );
      addTearDown(store.dispose);

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const [
          AppLlmChatMessage(role: 'system', content: 'system prompt'),
          AppLlmChatMessage(
            role: 'user',
            content: '任务：scene_quality_scoring\n正文：一段文字',
          ),
        ],
        maxTokens: 2048,
        traceName: 'scene_quality_scoring',
        traceMetadata: const {'sceneId': 'scene-01'},
      );

      expect(result.succeeded, isTrue);
      expect(traceSink.entries, hasLength(1));
      final trace = traceSink.entries.single;
      expect(trace.traceName, 'scene_quality_scoring');
      expect(trace.promptTokens, 11);
      expect(trace.completionTokens, 3);
      expect(trace.totalTokens, 14);
      expect(trace.maxTokens, 4096);
      expect(trace.metadata['sceneId'], 'scene-01');
      expect(trace.estimatedPromptTokens, greaterThan(0));
      expect(trace.estimatedCompletionTokens, greaterThan(0));

      final llmEvents = eventStorage.entries
          .where((entry) => entry.action == 'llm.chat')
          .toList();
      expect(llmEvents, hasLength(1));
      expect(llmEvents.single.metadata['promptTokens'], 11);
      expect(llmEvents.single.metadata['completionTokens'], 3);
      expect(llmEvents.single.metadata['totalTokens'], 14);
      expect(llmEvents.single.metadata['maxTokens'], 4096);
      expect(llmEvents.single.metadata['traceName'], 'scene_quality_scoring');
    },
  );

  test('requestAiCompletion omits max token limit by default', () async {
    final llmClient = _CapturingLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    final result = await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'hello')],
    );

    expect(result.succeeded, isTrue);
    expect(
      llmClient.lastRequest?.maxTokens,
      AppLlmChatRequest.unlimitedMaxTokens,
    );
    expect(
      llmClient.lastRequest?.effectiveMaxTokens,
      AppLlmChatRequest.unlimitedMaxTokens,
    );
  });

  test('theme and prompt-language setters await persistence', () async {
    final storage = _ControllableSettingsStorage();
    final store = AppSettingsStore(
      storage: storage,
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(store.dispose);

    final themeSave = store.setThemePreference(AppThemePreference.dark);
    await storage.saveStarted.future;

    expect(storage.savedData, isNull);

    storage.completeSave();
    final themeResult = await themeSave;

    expect(themeResult.succeededWithoutWarnings, isTrue);
    expect(storage.savedData?['themePreference'], 'dark');

    final languageSave = store.setPromptLanguage(PromptLanguage.en);
    await languageSave;

    expect(storage.savedData?['promptLanguage'], 'en');
    expect(StoryPromptTemplates.language, PromptLanguage.zh);
  });

  test(
    'settings store uses injected request pool instead of global pool',
    () async {
      final requestPool = _RecordingRequestPool(maxConcurrent: 1);
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: _CapturingLlmClient(),
        requestPool: requestPool,
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: 'OpenAI 兼容服务',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'sk-test',
        maxConcurrentRequests: 2,
      );
      await requestAuthorizedAiCompletionForTest(
        store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'hi')],
      );

      expect(requestPool.maxConcurrent, 2);
      expect(requestPool.runCount, 1);
    },
  );

  test(
    'limits concurrent requests independently per routed provider',
    () async {
      final llmClient = _BlockingByModelLlmClient();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: '智谱 GLM',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        apiKey: 'zhipu-key',
        maxConcurrentRequests: 3,
        providerProfiles: const [
          AppLlmProviderProfile(
            id: 'ollama-kimi',
            providerName: 'Ollama Cloud',
            baseUrl: 'https://ollama.com/v1',
            model: 'kimi-k2.6',
            apiKey: 'ollama-key',
          ),
          AppLlmProviderProfile(
            id: 'mimo',
            providerName: 'Xiaomi MiMo',
            baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
            model: 'mimo-v2.5-pro',
            apiKey: 'mimo-key',
          ),
        ],
        requestProviderRoutes: const [
          AppLlmRequestProviderRoute(
            traceNamePattern: 'scene_review_*',
            providerProfileId: 'ollama-kimi',
          ),
          AppLlmRequestProviderRoute(
            traceNamePattern: 'scene_quality_scoring',
            providerProfileId: 'mimo',
          ),
        ],
      );

      final futures = <Future<AppLlmChatResult>>[
        for (var index = 0; index < 3; index += 1)
          requestAuthorizedAiCompletionForTest(
            store,
            messages: [
              AppLlmChatMessage(role: 'user', content: 'review $index'),
            ],
            traceName: 'scene_review_$index',
          ),
        requestAuthorizedAiCompletionForTest(
          store,
          messages: const [AppLlmChatMessage(role: 'user', content: 'score')],
          traceName: 'scene_quality_scoring',
        ),
        requestAuthorizedAiCompletionForTest(
          store,
          messages: const [AppLlmChatMessage(role: 'user', content: 'draft')],
          traceName: 'scene_prose_generation',
        ),
      ];

      await Future<void>.delayed(const Duration(milliseconds: 50));

      try {
        expect(llmClient.activeForModel('kimi-k2.6'), 3);
        expect(llmClient.activeForModel('mimo-v2.5-pro'), 1);
        expect(llmClient.activeForModel('glm-5.1'), 1);
      } finally {
        llmClient.completeAll();
        await Future.wait(futures);
      }
    },
  );

  test('limits failover requests by fallback provider pool', () async {
    final llmClient = _FailoverBlockingLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    await store.save(
      providerName: 'Primary Cloud',
      baseUrl: 'https://primary.example.com/v1',
      model: 'primary-model',
      apiKey: 'primary-key',
      maxConcurrentRequests: 1,
      providerProfiles: const [
        AppLlmProviderProfile(
          id: 'fallback',
          providerName: 'Fallback Cloud',
          baseUrl: 'https://fallback.example.com/v1',
          model: 'fallback-model',
          apiKey: 'fallback-key',
        ),
      ],
    );

    final futures = [
      requestAuthorizedAiCompletionForTest(
        store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'first')],
      ),
      requestAuthorizedAiCompletionForTest(
        store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'second')],
      ),
    ];

    await Future<void>.delayed(const Duration(milliseconds: 50));

    try {
      expect(llmClient.callsForModel('primary-model'), 2);
      expect(llmClient.activeForModel('fallback-model'), 1);

      llmClient.completeOneFallback();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(llmClient.callsForModel('primary-model'), 2);
      expect(llmClient.activeForModel('fallback-model'), 1);
    } finally {
      llmClient.completeAllFallbacks();
      await Future.wait(futures);
    }
  });

  test('tries primary provider before local fallback provider', () async {
    final llmClient = _OrderedFailoverLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    await store.save(
      providerName: 'Primary Cloud',
      baseUrl: 'https://primary.example.com/v1',
      model: 'primary-model',
      apiKey: 'primary-key',
      providerProfiles: const [
        AppLlmProviderProfile(
          id: 'local-fallback',
          providerName: 'Local Fallback',
          baseUrl: 'http://127.0.0.1:11434/v1',
          model: 'local-model',
          apiKey: '',
        ),
      ],
    );

    final result = await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'order')],
    );

    expect(result.succeeded, isTrue);
    expect(llmClient.models, ['primary-model', 'local-model']);
  });
}

class _CapturingLlmClient implements AppLlmClient {
  _CapturingLlmClient({
    this.result = const AppLlmChatResult.success(text: 'pong', latencyMs: 1),
  });

  final AppLlmChatResult result;
  AppLlmChatRequest? lastRequest;
  final requests = <AppLlmChatRequest>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    lastRequest = request;
    requests.add(request);
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    lastRequest = request;
    requests.add(request);
    return Stream<String>.value('pong');
  }
}

class _RecordingLlmTraceSink implements AppLlmCallTraceSink {
  final entries = <AppLlmCallTraceEntry>[];

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    entries.add(entry);
  }
}

class _InMemoryEventLogStorage implements AppEventLogStorage {
  final entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}

class _ControllableSettingsStorage implements AppSettingsStorage {
  final saveStarted = Completer<void>();
  Completer<AppSettingsSaveResult>? _saveCompleter;
  Map<String, Object?>? savedData;
  bool _controlNextSave = true;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.none;

  @override
  String? get lastLoadDetail => null;

  @override
  Future<Map<String, Object?>?> load() async => null;

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    if (!_controlNextSave) {
      savedData = Map<String, Object?>.from(data);
      return const AppSettingsSaveResult();
    }

    _saveCompleter = Completer<AppSettingsSaveResult>();
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    final result = await _saveCompleter!.future;
    savedData = Map<String, Object?>.from(data);
    return result;
  }

  void completeSave() {
    _saveCompleter?.complete(const AppSettingsSaveResult());
    _controlNextSave = false;
  }
}

class _ReadFailureThenRecoveryStorage implements AppSettingsStorage {
  int _loadCount = 0;
  AppSettingsPersistenceIssue _lastLoadIssue =
      AppSettingsPersistenceIssue.fileReadFailed;
  String? _lastLoadDetail;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue => _lastLoadIssue;

  @override
  String? get lastLoadDetail => _lastLoadDetail;

  @override
  Future<Map<String, Object?>?> load() async {
    _loadCount += 1;
    if (_loadCount == 1) {
      _lastLoadIssue = AppSettingsPersistenceIssue.fileReadFailed;
      _lastLoadDetail = 'settings.json is unreadable';
      return {
        'providerName': 'OpenAI 兼容服务',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-5.4',
        'apiKey': 'sk-initial',
        'themePreference': 'light',
      };
    }

    _lastLoadIssue = AppSettingsPersistenceIssue.none;
    _lastLoadDetail = null;
    return {
      'providerName': '智谱 GLM',
      'baseUrl': 'https://api.openai.com/v1',
      'model': 'glm-4',
      'apiKey': 'sk-recovered',
      'themePreference': 'dark',
      'maxConcurrentRequests': 2,
      'maxTokens': 800,
    };
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult();
  }
}

class _DelayedReadThenWriteRecoveryStorage implements AppSettingsStorage {
  final Completer<Map<String, Object?>?> _loadCompleter = Completer();
  int _saveCallCount = 0;
  AppSettingsPersistenceIssue _lastLoadIssue =
      AppSettingsPersistenceIssue.fileReadFailed;
  String? _lastLoadDetail;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue => _lastLoadIssue;

  @override
  String? get lastLoadDetail => _lastLoadDetail;

  @override
  Future<Map<String, Object?>?> load() async {
    return _loadCompleter.future;
  }

  void completeRead() {
    _lastLoadIssue = AppSettingsPersistenceIssue.none;
    _lastLoadDetail = null;
    _loadCompleter.complete({
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': 'sk-persisted',
      'themePreference': 'light',
      'maxConcurrentRequests': 2,
      'maxTokens': 1200,
    });
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    _saveCallCount += 1;
    return AppSettingsSaveResult(
      issue: _saveCallCount == 1
          ? AppSettingsPersistenceIssue.fileWriteFailed
          : AppSettingsPersistenceIssue.none,
      detail: _saveCallCount == 1 ? 'settings.json write denied' : null,
    );
  }
}

class _DelayedReadWithFailureAndWriteFailureStorage
    implements AppSettingsStorage {
  final Completer<Map<String, Object?>?> _loadCompleter = Completer();

  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.fileReadFailed;

  @override
  String? get lastLoadDetail => 'settings.json is unreadable';

  @override
  Future<Map<String, Object?>?> load() async {
    return _loadCompleter.future;
  }

  void completeRead() {
    _loadCompleter.complete({
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': 'sk-initial',
      'themePreference': 'light',
    });
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult(
      issue: AppSettingsPersistenceIssue.fileWriteFailed,
      detail: 'settings.json write denied',
    );
  }
}

class _RecordingRequestPool extends AppLlmRequestPool {
  _RecordingRequestPool({required super.maxConcurrent});

  int runCount = 0;

  @override
  Future<T> run<T>(Future<T> Function() operation) {
    runCount += 1;
    return super.run(operation);
  }
}

class _BlockingByModelLlmClient implements AppLlmClient {
  final _activeByModel = <String, int>{};
  final _pending = <Completer<AppLlmChatResult>>[];
  bool _completeImmediately = false;

  int activeForModel(String model) => _activeByModel[model] ?? 0;

  void completeAll() {
    _completeImmediately = true;
    for (final completer in List<Completer<AppLlmChatResult>>.from(_pending)) {
      if (!completer.isCompleted) {
        completer.complete(const AppLlmChatResult.success(text: 'done'));
      }
    }
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    _activeByModel.update(
      request.model,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    try {
      if (_completeImmediately) {
        return const AppLlmChatResult.success(text: 'done');
      }
      final completer = Completer<AppLlmChatResult>();
      _pending.add(completer);
      return await completer.future;
    } finally {
      _activeByModel.update(request.model, (count) => count - 1);
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

class _FailoverBlockingLlmClient implements AppLlmClient {
  final _callsByModel = <String, int>{};
  final _activeByModel = <String, int>{};
  final _pendingFallbacks = <Completer<AppLlmChatResult>>[];
  bool _completeFallbacksImmediately = false;

  int callsForModel(String model) => _callsByModel[model] ?? 0;
  int activeForModel(String model) => _activeByModel[model] ?? 0;

  void completeOneFallback() {
    if (_pendingFallbacks.isEmpty) return;
    final completer = _pendingFallbacks.removeAt(0);
    if (!completer.isCompleted) {
      completer.complete(const AppLlmChatResult.success(text: 'fallback done'));
    }
  }

  void completeAllFallbacks() {
    _completeFallbacksImmediately = true;
    for (final completer in List<Completer<AppLlmChatResult>>.from(
      _pendingFallbacks,
    )) {
      if (!completer.isCompleted) {
        completer.complete(
          const AppLlmChatResult.success(text: 'fallback done'),
        );
      }
    }
    _pendingFallbacks.clear();
  }

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    _callsByModel.update(
      request.model,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    _activeByModel.update(
      request.model,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    try {
      if (request.model == 'primary-model') {
        return const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.invalidResponse,
          detail: 'primary returned invalid response',
        );
      }
      if (_completeFallbacksImmediately) {
        return const AppLlmChatResult.success(text: 'fallback done');
      }
      final completer = Completer<AppLlmChatResult>();
      _pendingFallbacks.add(completer);
      return await completer.future;
    } finally {
      _activeByModel.update(request.model, (count) => count - 1);
    }
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}

class _OrderedFailoverLlmClient implements AppLlmClient {
  final models = <String>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    models.add(request.model);
    if (request.model == 'primary-model') {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
        detail: 'primary returned invalid response',
      );
    }
    return const AppLlmChatResult.success(text: 'fallback done');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    throw UnimplementedError('chatStream');
  }
}
