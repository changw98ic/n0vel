import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

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
}

class _CapturingLlmClient implements AppLlmClient {
  AppLlmChatRequest? lastRequest;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    lastRequest = request;
    return const AppLlmChatResult.success(text: 'pong', latencyMs: 1);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    lastRequest = request;
    return Stream<String>.value('pong');
  }
}
