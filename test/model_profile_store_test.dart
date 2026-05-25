import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/model_profile_store.dart';

void main() {
  group('ModelProfileStore', () {
    test(
      'upsertProfile adds and edits model profiles through settings',
      () async {
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: _CapturingLlmClient(),
        );
        final store = ModelProfileStore(settingsStore: settingsStore);
        addTearDown(store.dispose);
        addTearDown(settingsStore.dispose);

        await store.upsertProfile(
          const AppLlmProviderProfile(
            id: 'review',
            providerName: ' Review Provider ',
            baseUrl: ' https://review.example.com/v1 ',
            model: ' glm-5.1 ',
            apiKey: ' review-key ',
          ),
        );

        expect(store.profiles, hasLength(1));
        expect(store.profileById('review')!.providerName, 'Review Provider');
        expect(
          store.profileById('review')!.baseUrl,
          'https://review.example.com/v1',
        );
        expect(store.profileById('review')!.model, 'glm-5.1');
        expect(store.profileById('review')!.apiKey, ' review-key ');

        await store.upsertProfile(
          const AppLlmProviderProfile(
            id: 'review',
            providerName: 'Updated Provider',
            baseUrl: 'https://updated.example.com/v1',
            model: 'gpt-5.4',
            apiKey: 'updated-key',
          ),
        );

        expect(store.profiles, hasLength(1));
        expect(store.profileById('review')!.providerName, 'Updated Provider');
        expect(store.profileById('review')!.model, 'gpt-5.4');
      },
    );

    test(
      'removeProfile deletes profiles and listener mirrors settings changes',
      () async {
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: _CapturingLlmClient(),
        );
        final store = ModelProfileStore(settingsStore: settingsStore);
        addTearDown(store.dispose);
        addTearDown(settingsStore.dispose);
        var notifications = 0;
        store.addListener(() {
          notifications += 1;
        });

        await store.upsertProfile(
          const AppLlmProviderProfile(
            id: 'draft',
            providerName: 'Draft Provider',
            baseUrl: 'https://draft.example.com/v1',
            model: 'gpt-5.4',
            apiKey: 'draft-key',
          ),
        );
        await settingsStore.upsertProviderProfile(
          const AppLlmProviderProfile(
            id: 'external',
            providerName: 'External Provider',
            baseUrl: 'https://external.example.com/v1',
            model: 'glm-5.1',
            apiKey: 'external-key',
          ),
        );

        expect(store.profileById('draft'), isNotNull);
        expect(store.profileById('external'), isNotNull);

        await store.removeProfile('draft');

        expect(store.profileById('draft'), isNull);
        expect(store.profileById('external'), isNotNull);
        expect(notifications, greaterThanOrEqualTo(3));
      },
    );

    test('profiles persist through shared settings storage restore', () async {
      final storage = InMemoryAppSettingsStorage();
      final settingsA = AppSettingsStore(
        storage: storage,
        llmClient: _CapturingLlmClient(),
      );
      final storeA = ModelProfileStore(settingsStore: settingsA);
      addTearDown(storeA.dispose);
      addTearDown(settingsA.dispose);

      await storeA.upsertProfile(
        const AppLlmProviderProfile(
          id: 'longform',
          providerName: 'Longform Provider',
          baseUrl: 'https://longform.example.com/v1',
          model: 'gpt-5.4',
          apiKey: 'longform-key',
        ),
      );

      final settingsB = AppSettingsStore(
        storage: storage,
        llmClient: _CapturingLlmClient(),
      );
      final storeB = ModelProfileStore(settingsStore: settingsB);
      addTearDown(storeB.dispose);
      addTearDown(settingsB.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(storeB.profileById('longform'), isNotNull);
      expect(storeB.profileById('longform')!.apiKey, 'longform-key');
    });

    test(
      'testProfileConnection delegates profile settings to LLM client',
      () async {
        final llmClient = _CapturingLlmClient();
        final settingsStore = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
          llmClient: llmClient,
        );
        final store = ModelProfileStore(settingsStore: settingsStore);
        addTearDown(store.dispose);
        addTearDown(settingsStore.dispose);

        await store.upsertProfile(
          const AppLlmProviderProfile(
            id: 'local',
            providerName: 'Local CCR',
            baseUrl: 'http://localhost:3456/v1',
            model: 'gpt-5.4-mini',
            apiKey: '',
          ),
        );

        await store.testProfileConnection('local');

        expect(llmClient.lastRequest, isNotNull);
        expect(llmClient.lastRequest!.baseUrl, 'http://localhost:3456/v1');
        expect(llmClient.lastRequest!.model, 'gpt-5.4-mini');
        expect(llmClient.lastRequest!.apiKey, isEmpty);
        expect(
          store.connectionTestState.status,
          AppSettingsConnectionTestStatus.success,
        );
      },
    );

    test('primary profile is addressable for connection tests', () async {
      final llmClient = _CapturingLlmClient();
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: llmClient,
      );
      final store = ModelProfileStore(settingsStore: settingsStore);
      addTearDown(store.dispose);
      addTearDown(settingsStore.dispose);

      expect(store.profileById('primary')!.providerName, 'OpenAI 兼容服务');
      expect(store.profileById('primary')!.model, store.primaryProfile.model);

      await settingsStore.save(
        providerName: 'Primary Provider',
        baseUrl: 'http://localhost:3456/v1',
        model: 'gpt-5.4-mini',
        apiKey: '',
      );

      expect(store.profileById('primary')!.providerName, 'Primary Provider');

      await store.testProfileConnection('primary');

      expect(llmClient.lastRequest, isNotNull);
      expect(llmClient.lastRequest!.baseUrl, 'http://localhost:3456/v1');
      expect(llmClient.lastRequest!.model, 'gpt-5.4-mini');
    });

    test('catalog add and primary selection delegate to settings', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: _CapturingLlmClient(),
      );
      final store = ModelProfileStore(settingsStore: settingsStore);
      addTearDown(store.dispose);
      addTearDown(settingsStore.dispose);

      await store.addFromCatalog('deepseek');
      await store.setPrimaryProfile('deepseek');

      expect(store.profileById('deepseek'), isNotNull);
      expect(store.primaryProfile.providerName, 'DeepSeek');
      expect(store.primaryProfile.model, 'deepseek-chat');
    });

    test('testProfileConnection throws for missing profile id', () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: _CapturingLlmClient(),
      );
      final store = ModelProfileStore(settingsStore: settingsStore);
      addTearDown(store.dispose);
      addTearDown(settingsStore.dispose);

      expect(
        () => store.testProfileConnection('missing'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'modelProfileStoreProvider builds over appSettingsStoreProvider',
      () async {
        final container = ProviderContainer(
          overrides: [
            appSettingsStorageProvider.overrideWith(
              (ref) => InMemoryAppSettingsStorage(),
            ),
            appLlmClientProvider.overrideWith((ref) => _CapturingLlmClient()),
          ],
        );
        addTearDown(container.dispose);

        final store = container.read(modelProfileStoreProvider);

        await store.upsertProfile(
          const AppLlmProviderProfile(
            id: 'provider-store',
            providerName: 'Provider Store',
            baseUrl: 'https://provider.example.com/v1',
            model: 'gpt-5.4',
            apiKey: 'provider-key',
          ),
        );

        final settingsStore = container.read(appSettingsStoreProvider);
        expect(
          settingsStore.snapshot.providerProfiles
              .singleWhere((p) => p.id == 'provider-store')
              .model,
          'gpt-5.4',
        );
      },
    );
  });
}

class _CapturingLlmClient implements AppLlmClient {
  AppLlmChatRequest? lastRequest;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    lastRequest = request;
    return const AppLlmChatResult.success(text: 'pong', latencyMs: 3);
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) {
    lastRequest = request;
    return Stream<String>.value('pong');
  }
}
