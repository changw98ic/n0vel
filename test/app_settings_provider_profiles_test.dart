import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

void main() {
  late AppSettingsStore store;

  setUp(() {
    store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: _CapturingLlmClient(),
    );
  });

  tearDown(() => store.dispose());

  // ---------------------------------------------------------------------------
  // Provider Profile CRUD
  // ---------------------------------------------------------------------------

  test('upsertProviderProfile adds a new profile', () async {
    expect(store.snapshot.providerProfiles, isEmpty);

    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'ollama-kimi',
        providerName: 'Ollama Cloud',
        baseUrl: 'https://ollama.com/v1',
        model: 'kimi-k2.6',
        apiKey: 'ollama-key',
      ),
    );

    expect(store.snapshot.providerProfiles, hasLength(1));
    expect(store.snapshot.providerProfiles.first.id, 'ollama-kimi');
    expect(store.snapshot.providerProfiles.first.model, 'kimi-k2.6');
  });

  test('upsertProviderProfile updates existing profile by id', () async {
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'premium',
        providerName: 'GLM',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        apiKey: 'key-1',
      ),
    );
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'premium',
        providerName: 'GLM Updated',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5',
        apiKey: 'key-2',
      ),
    );

    expect(store.snapshot.providerProfiles, hasLength(1));
    expect(store.snapshot.providerProfiles.first.model, 'glm-5');
    expect(store.snapshot.providerProfiles.first.apiKey, 'key-2');
  });

  test('removeProviderProfile removes by id', () async {
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'a',
        providerName: 'A',
        baseUrl: 'https://a.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'key-a',
      ),
    );
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'b',
        providerName: 'B',
        baseUrl: 'https://b.example.com/v1',
        model: 'glm-5.1',
        apiKey: 'key-b',
      ),
    );

    await store.removeProviderProfile('a');

    expect(store.snapshot.providerProfiles, hasLength(1));
    expect(store.snapshot.providerProfiles.first.id, 'b');
  });

  test('removeProviderProfile is no-op for unknown id', () async {
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'only',
        providerName: 'Only',
        baseUrl: 'https://only.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'key',
      ),
    );

    await store.removeProviderProfile('nonexistent');

    expect(store.snapshot.providerProfiles, hasLength(1));
  });

  // ---------------------------------------------------------------------------
  // Request Provider Route CRUD
  // ---------------------------------------------------------------------------

  test('upsertRequestProviderRoute adds a new route', () async {
    expect(store.snapshot.requestProviderRoutes, isEmpty);

    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_review_*',
        providerProfileId: 'ollama-kimi',
      ),
    );

    expect(store.snapshot.requestProviderRoutes, hasLength(1));
    expect(
      store.snapshot.requestProviderRoutes.first.traceNamePattern,
      'scene_review_*',
    );
  });

  test('upsertRequestProviderRoute updates existing route by pattern', () async {
    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_review_*',
        providerProfileId: 'old-profile',
      ),
    );
    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_review_*',
        providerProfileId: 'new-profile',
      ),
    );

    expect(store.snapshot.requestProviderRoutes, hasLength(1));
    expect(
      store.snapshot.requestProviderRoutes.first.providerProfileId,
      'new-profile',
    );
  });

  test('removeRequestProviderRoute removes by pattern', () async {
    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_review_*',
        providerProfileId: 'a',
      ),
    );
    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_editorial',
        providerProfileId: 'b',
      ),
    );

    await store.removeRequestProviderRoute('scene_review_*');

    expect(store.snapshot.requestProviderRoutes, hasLength(1));
    expect(
      store.snapshot.requestProviderRoutes.first.traceNamePattern,
      'scene_editorial',
    );
  });

  test('removeRequestProviderRoute is no-op for unknown pattern', () async {
    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_review_*',
        providerProfileId: 'a',
      ),
    );

    await store.removeRequestProviderRoute('nonexistent');

    expect(store.snapshot.requestProviderRoutes, hasLength(1));
  });

  // ---------------------------------------------------------------------------
  // Persistence round-trip
  // ---------------------------------------------------------------------------

  test('profiles and routes persist through save/restore', () async {
    final storage = InMemoryAppSettingsStorage();
    final storeA = AppSettingsStore(
      storage: storage,
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(storeA.dispose);

    await storeA.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'mimo',
        providerName: 'Xiaomi MiMo',
        baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
        model: 'mimo-v2.5-pro',
        apiKey: 'mimo-key',
      ),
    );
    await storeA.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_quality_scoring',
        providerProfileId: 'mimo',
      ),
    );

    // Create a new store reading from the same storage to simulate restart.
    final storeB = AppSettingsStore(
      storage: storage,
      llmClient: _CapturingLlmClient(),
    );
    addTearDown(storeB.dispose);

    // Allow async restore to complete.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(storeB.snapshot.providerProfiles, hasLength(2));
    expect(
      storeB.snapshot.providerProfiles.singleWhere((p) => p.id == 'mimo').id,
      'mimo',
    );
    expect(storeB.snapshot.requestProviderRoutes, hasLength(1));
    expect(
      storeB.snapshot.requestProviderRoutes.first.traceNamePattern,
      'scene_quality_scoring',
    );
  });

  // ---------------------------------------------------------------------------
  // Route routing with mutated profiles
  // ---------------------------------------------------------------------------

  test('routed request uses upserted profile', () async {
    final llmClient = _CapturingLlmClient();
    final store = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: llmClient,
    );
    addTearDown(store.dispose);

    await store.save(
      providerName: 'Default',
      baseUrl: 'https://default.example.com/v1',
      model: 'gpt-5.4',
      apiKey: 'default-key',
    );
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'review',
        providerName: 'Review Provider',
        baseUrl: 'https://review.example.com/v1',
        model: 'glm-5.1',
        apiKey: 'review-key',
      ),
    );
    await store.upsertRequestProviderRoute(
      const AppLlmRequestProviderRoute(
        traceNamePattern: 'scene_review_*',
        providerProfileId: 'review',
      ),
    );

    await store.requestAiCompletion(
      messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
      traceName: 'scene_review_plot',
    );

    expect(llmClient.lastRequest, isNotNull);
    expect(llmClient.lastRequest!.model, 'glm-5.1');
    expect(llmClient.lastRequest!.apiKey, 'review-key');
  });

  test(
    'removing profile causes fallback to default provider on next request',
    () async {
      final llmClient = _CapturingLlmClient();
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
      );
      addTearDown(store.dispose);

      await store.save(
        providerName: 'Default',
        baseUrl: 'https://default.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'default-key',
      );
      await store.upsertProviderProfile(
        const AppLlmProviderProfile(
          id: 'review',
          providerName: 'Review Provider',
          baseUrl: 'https://review.example.com/v1',
          model: 'glm-5.1',
          apiKey: 'review-key',
        ),
      );
      await store.upsertRequestProviderRoute(
        const AppLlmRequestProviderRoute(
          traceNamePattern: 'scene_review_*',
          providerProfileId: 'review',
        ),
      );

      await store.removeProviderProfile('review');

      await store.requestAiCompletion(
        messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
        traceName: 'scene_review_plot',
      );

      expect(llmClient.lastRequest!.model, 'gpt-5.4');
      expect(llmClient.lastRequest!.apiKey, 'default-key');
    },
  );
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
