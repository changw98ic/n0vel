import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_templates.dart';

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

      final result = await store.requestAiCompletion(
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
      expect(trace.maxTokens, 2048);
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
      expect(llmEvents.single.metadata['maxTokens'], 2048);
      expect(llmEvents.single.metadata['traceName'], 'scene_quality_scoring');
    },
  );

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
      await store.requestAiCompletion(
        messages: const [AppLlmChatMessage(role: 'user', content: 'hi')],
      );

      expect(requestPool.maxConcurrent, 2);
      expect(requestPool.runCount, 1);
    },
  );
}

class _CapturingLlmClient implements AppLlmClient {
  _CapturingLlmClient({
    this.result = const AppLlmChatResult.success(text: 'pong', latencyMs: 1),
  });

  final AppLlmChatResult result;
  AppLlmChatRequest? lastRequest;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    lastRequest = request;
    return result;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    lastRequest = request;
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

class _RecordingRequestPool extends AppLlmRequestPool {
  _RecordingRequestPool({required super.maxConcurrent});

  int runCount = 0;

  @override
  Future<T> run<T>(Future<T> Function() operation) {
    runCount += 1;
    return super.run(operation);
  }
}
