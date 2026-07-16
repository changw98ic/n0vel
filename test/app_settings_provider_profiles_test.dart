import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'test_support/app_llm_authorized_request.dart';

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

  test(
    'upsertRequestProviderRoute updates existing route by pattern',
    () async {
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
    },
  );

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

  test('single chapter preset adds routed providers and routes', () async {
    await store.save(
      providerName: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-4.5',
      apiKey: 'zhipu-key',
    );
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'ollama-kimi',
        providerName: 'Old',
        baseUrl: 'https://old.example.com/v1',
        model: 'old-model',
        apiKey: 'keep-this-key',
      ),
    );

    await store.applySingleChapterGenerationProviderPreset();

    expect(store.snapshot.providerName, '智谱 GLM');
    expect(store.snapshot.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
    expect(store.snapshot.model, 'glm-5.1');
    expect(store.snapshot.apiKey, 'zhipu-key');

    final profiles = store.snapshot.providerProfiles;
    final primary = profiles.singleWhere((p) => p.id == 'primary');
    final kimi = profiles.singleWhere((p) => p.id == 'ollama-kimi');
    final mimo = profiles.singleWhere((p) => p.id == 'mimo');
    expect(primary.providerName, '智谱 GLM');
    expect(primary.model, 'glm-5.1');
    expect(kimi.providerName, 'Ollama Cloud');
    expect(kimi.baseUrl, 'https://ollama.com/v1');
    expect(kimi.model, 'kimi-k2.6');
    expect(kimi.apiKey, 'keep-this-key');
    expect(mimo.providerName, 'Xiaomi MiMo');
    expect(mimo.model, 'mimo-v2.5-pro');

    final routes = store.snapshot.requestProviderRoutes;
    expect(routes, hasLength(9));
    expect(
      routes
          .singleWhere((r) => r.traceNamePattern == 'scene_roleplay_turn')
          .providerProfileId,
      'ollama-kimi',
    );
    expect(
      routes
          .singleWhere((r) => r.traceNamePattern == 'scene_quality_scoring')
          .providerProfileId,
      'mimo',
    );
  });

  test(
    'provider catalog adds a provider without manual base URL entry',
    () async {
      await store.addProviderFromCatalog('deepseek');

      final profile = store.snapshot.providerProfiles.singleWhere(
        (p) => p.id == 'deepseek',
      );
      expect(profile.providerName, 'DeepSeek');
      expect(profile.baseUrl, 'https://api.deepseek.com');
      expect(profile.model, 'deepseek-chat');
      expect(profile.apiKey, isEmpty);
    },
  );

  test('provider catalog includes common Chinese service templates', () {
    final expected = {
      'zhipu': (
        name: '智谱 GLM 中国按量 API',
        baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
      ),
      'zhipu-global': (
        name: 'Z.AI GLM 国际按量 API',
        baseUrl: 'https://api.z.ai/api/paas/v4',
        model: 'glm-5.1',
      ),
      'zhipu-coding-plan-cn': (
        name: '智谱 GLM Coding Plan 中国',
        baseUrl: 'https://open.bigmodel.cn/api/coding/paas/v4',
        model: 'glm-4.7',
      ),
      'zhipu-coding-plan-global': (
        name: 'Z.AI GLM Coding Plan 国际',
        baseUrl: 'https://api.z.ai/api/coding/paas/v4',
        model: 'glm-4.7',
      ),
      'kimi-coding-plan': (
        name: 'Kimi Code 会员 Coding API',
        baseUrl: 'https://api.kimi.com/coding/v1',
        model: 'kimi-for-coding',
      ),
      'aliyun-dashscope': (
        name: '阿里百炼 中国按量 API',
        baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
        model: 'qwen-plus',
      ),
      'aliyun-dashscope-intl': (
        name: '阿里百炼 国际按量 API',
        baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
        model: 'qwen-plus',
      ),
      'aliyun-dashscope-us': (
        name: '阿里百炼 美国按量 API',
        baseUrl: 'https://dashscope-us.aliyuncs.com/compatible-mode/v1',
        model: 'qwen-plus-us',
      ),
      'aliyun-coding-plan': (
        name: '阿里百炼 Coding Plan 中国',
        baseUrl: 'https://coding.dashscope.aliyuncs.com/v1',
        model: 'qwen3-coder-plus',
      ),
      'volcengine-ark': (
        name: '火山方舟 (Doubao)',
        baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
        model: 'doubao-seed-1-6-250615',
      ),
      'volcengine-coding-plan': (
        name: '火山方舟 Coding Plan',
        baseUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3',
        model: 'ark-code-latest',
      ),
      'minimax': (
        name: 'MiniMax 国际',
        baseUrl: 'https://api.minimax.io/v1',
        model: 'MiniMax-M2.7',
      ),
      'minimax-cn': (
        name: 'MiniMax 中国',
        baseUrl: 'https://api.minimaxi.com/v1',
        model: 'MiniMax-M2.7',
      ),
      'minimax-coding-plan': (
        name: 'MiniMax Coding Plan 国际',
        baseUrl: 'https://api.minimax.io/v1',
        model: 'codex-MiniMax-M2.7',
      ),
      'minimax-coding-plan-cn': (
        name: 'MiniMax Coding Plan 中国',
        baseUrl: 'https://api.minimaxi.com/v1',
        model: 'codex-MiniMax-M2.7',
      ),
      'tencent-hunyuan': (
        name: '腾讯混元',
        baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
        model: 'hunyuan-turbos-latest',
      ),
      'tencent-tokenhub-plan': (
        name: '腾讯 TokenHub Token Plan',
        baseUrl: 'https://api.lkeap.cloud.tencent.com/plan/v3',
        model: 'hunyuan-2.0-instruct',
      ),
      'tencent-tokenhub-enterprise': (
        name: '腾讯 TokenHub 企业版',
        baseUrl: 'https://tokenhub.tencentmaas.com/plan/v3',
        model: 'hunyuan-2.0-instruct',
      ),
      'meituan-longcat': (
        name: '美团 LongCat',
        baseUrl: 'https://api.longcat.chat/openai/v1',
        model: 'LongCat-Flash-Chat',
      ),
      'mimo-usage': (
        name: 'Xiaomi MiMo 按量 API',
        baseUrl: 'https://api.xiaomimimo.com/v1',
        model: 'mimo-v2-pro',
      ),
      'mimo': (
        name: 'Xiaomi MiMo Token Plan CN',
        baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
        model: 'mimo-v2.5-pro',
      ),
    };

    for (final entry in expected.entries) {
      final catalogEntry = appLlmProviderCatalogEntries.singleWhere(
        (item) => item.id == entry.key,
      );
      expect(catalogEntry.providerName, entry.value.name);
      expect(catalogEntry.baseUrl, entry.value.baseUrl);
      expect(catalogEntry.model, entry.value.model);
      expect(catalogEntry.requiresApiKey, isTrue);
    }
  });

  test('common Chinese provider catalog entries add usable profiles', () async {
    const ids = [
      'zhipu',
      'zhipu-global',
      'zhipu-coding-plan-cn',
      'zhipu-coding-plan-global',
      'kimi-coding-plan',
      'aliyun-dashscope',
      'aliyun-dashscope-intl',
      'aliyun-dashscope-us',
      'aliyun-coding-plan',
      'volcengine-ark',
      'volcengine-coding-plan',
      'minimax',
      'minimax-cn',
      'minimax-coding-plan',
      'minimax-coding-plan-cn',
      'tencent-hunyuan',
      'tencent-tokenhub-plan',
      'tencent-tokenhub-enterprise',
      'meituan-longcat',
      'mimo-usage',
      'mimo',
    ];

    for (final id in ids) {
      await store.addProviderFromCatalog(id);
    }

    expect(
      store.snapshot.providerProfiles.map((profile) => profile.id),
      containsAll(ids),
    );
    expect(
      store.snapshot.providerProfiles
          .singleWhere((profile) => profile.id == 'volcengine-coding-plan')
          .model,
      'ark-code-latest',
    );
  });

  test(
    'provider catalog can promote a preset to the default provider',
    () async {
      await store.save(
        providerName: '旧默认',
        baseUrl: 'https://old.example.com/v1',
        model: 'gpt-5.4',
        apiKey: 'old-key',
      );

      await store.addProviderFromCatalog('zhipu', setAsPrimary: true);

      expect(store.snapshot.providerName, '智谱 GLM 中国按量 API');
      expect(store.snapshot.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      expect(store.snapshot.model, 'glm-5.1');
      expect(store.snapshot.providerProfiles.first.id, 'primary');
      expect(
        store.snapshot.providerProfiles.first.providerName,
        '智谱 GLM 中国按量 API',
      );
    },
  );

  test('existing provider profile can become the default provider', () async {
    await store.save(
      providerName: '默认',
      baseUrl: 'https://default.example.com/v1',
      model: 'gpt-5.4',
      apiKey: 'default-key',
    );
    await store.upsertProviderProfile(
      const AppLlmProviderProfile(
        id: 'deepseek',
        providerName: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        apiKey: 'deepseek-key',
      ),
    );

    await store.setPrimaryProviderProfile('deepseek');

    expect(store.snapshot.providerName, 'DeepSeek');
    expect(store.snapshot.baseUrl, 'https://api.deepseek.com');
    expect(store.snapshot.model, 'deepseek-chat');
    expect(store.snapshot.apiKey, 'deepseek-key');
    expect(store.snapshot.providerProfiles.first.id, 'primary');
    expect(store.snapshot.providerProfiles.first.providerName, 'DeepSeek');
    expect(
      store.snapshot.providerProfiles.singleWhere((p) => p.id == 'deepseek'),
      isA<AppLlmProviderProfile>(),
    );
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

    await requestAuthorizedAiCompletionForTest(
      store,
      messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
      traceName: 'scene_review_plot',
    );

    expect(llmClient.lastRequest, isNotNull);
    expect(llmClient.lastRequest!.model, 'glm-5.1');
    expect(llmClient.lastRequest!.apiKey, 'review-key');
  });

  test(
    'synced primary profile does not create a hidden gateway retry',
    () async {
      final llmClient = _ThrowingLlmClient();
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
      expect(store.snapshot.providerProfiles.single.id, 'primary');

      await expectLater(
        requestAuthorizedAiCompletionForTest(
          store,
          messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
          traceName: 'scene_review_plot',
        ),
        throwsStateError,
      );

      expect(llmClient.calls, 1);
    },
  );

  test(
    'a distinct provider profile remains a real failover endpoint',
    () async {
      final llmClient = _RouteAwareFailoverClient();
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
          id: 'review-fallback',
          providerName: 'Review fallback',
          baseUrl: 'https://fallback.example.com/v1',
          model: 'glm-5.1',
          apiKey: 'fallback-key',
        ),
      );

      final result = await requestAuthorizedAiCompletionForTest(
        store,
        messages: const [AppLlmChatMessage(role: 'user', content: 'review')],
        traceName: 'scene_review_plot',
      );

      expect(result.succeeded, isTrue);
      expect(llmClient.baseUrls, <String>[
        'https://default.example.com/v1',
        'https://fallback.example.com/v1',
      ]);
    },
  );

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

      await requestAuthorizedAiCompletionForTest(
        store,
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

final class _ThrowingLlmClient implements AppLlmClient {
  int calls = 0;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    calls += 1;
    throw StateError('provider failed');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}

final class _RouteAwareFailoverClient implements AppLlmClient {
  final List<String> baseUrls = <String>[];

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    baseUrls.add(request.baseUrl);
    if (request.baseUrl == 'https://default.example.com/v1') {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.invalidResponse,
      );
    }
    return const AppLlmChatResult.success(text: 'fallback');
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) => const Stream.empty();
}
