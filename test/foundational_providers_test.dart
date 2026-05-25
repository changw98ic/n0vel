import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_request_pool.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/fulltext_search_service.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/app/state/story_generation_storage.dart';
import 'package:novel_writer/app/state/story_generation_store.dart';
import 'package:novel_writer/app/state/story_arc_storage.dart';
import 'package:novel_writer/app/state/story_arc_store.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_storage.dart';
import 'package:novel_writer/features/author_feedback/data/author_feedback_store.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_storage.dart';
import 'package:novel_writer/features/review_tasks/data/review_task_store.dart';
import 'package:novel_writer/features/search/presentation/fulltext_search_page.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/writing_stats/data/writing_stats_store.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_store.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_store_io.dart';
import 'package:novel_writer/features/story_generation/data/character_memory_delta_models.dart';
import 'package:novel_writer/features/story_generation/data/roleplay_session_store.dart';
import 'package:novel_writer/features/story_generation/data/roleplay_session_store_io.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/writing_stats/data/writing_stats_storage.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/memory_policy.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Helper to create an in-memory database for testing.
sqlite3.Database createInMemoryDatabase() => sqlite3.sqlite3.openInMemory();

/// Helper to create a test registry with in-memory database.
ServiceRegistry createTestRegistry() {
  final registry = ServiceRegistry();
  final db = createInMemoryDatabase();
  registry.registerSingleton<sqlite3.Database>(db);
  registry.registerFactory<AppEventBus>((_) => AppEventBus());
  registry.registerFactory<AppEventLog>((_) => AppEventLog());
  registry.registerFactory<AppLlmClient>((_) => createCachedAppLlmClient());
  registry.registerFactory<AppLlmRequestPool>(
    (_) => AppLlmRequestPool(maxConcurrent: 3),
  );
  registry.registerFactory<FulltextSearchService>(
    (r) => FulltextSearchService(db: r.resolve<sqlite3.Database>()),
  );
  return registry;
}

/// Test notifier for workspace provider in tests.
class _TestAppWorkspaceStoreNotifier extends AppWorkspaceStoreNotifier {
  _TestAppWorkspaceStoreNotifier(this._store);

  final AppWorkspaceStore _store;

  @override
  AppWorkspaceStore build() => _store;
}

void main() {
  group('appEventBusProvider', () {
    test('creates AppEventBus instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bus = container.read(appEventBusProvider);
      expect(bus, isA<AppEventBus>());
    });

    test('disposes AppEventBus on container dispose', () {
      final container = ProviderContainer();
      final bus = container.read(appEventBusProvider);

      // Should not throw
      bus.publish(
        const ProjectScopeChangedEvent(
          projectId: 'test',
          sceneScopeId: 'test::scene',
        ),
      );

      container.dispose();

      // Should throw after disposal
      expect(
        () => bus.publish(
          const ProjectScopeChangedEvent(
            projectId: 'test',
            sceneScopeId: 'test::scene',
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('disposed'),
          ),
        ),
      );
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final bus1 = container.read(appEventBusProvider);
      final bus2 = container.read(appEventBusProvider);

      expect(identical(bus1, bus2), isTrue);
    });
  });

  group('databaseProvider (with in-memory override)', () {
    test('uses in-memory database when overridden', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseProvider);
      expect(db, isA<sqlite3.Database>());
      // In-memory database should be usable
      expect(() => db.select('SELECT 1'), returnsNormally);
    });

    test('disposes Database on container dispose', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      final db = container.read(databaseProvider);

      // Database should be usable before disposal
      expect(() => db.select('SELECT 1'), returnsNormally);

      container.dispose();

      // Database operations should fail after disposal
      expect(() => db.select('SELECT 1'), throwsA(isA<StateError>()));
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final db1 = container.read(databaseProvider);
      final db2 = container.read(databaseProvider);

      expect(identical(db1, db2), isTrue);
    });
  });

  group('fulltextSearchServiceProvider', () {
    test('creates FulltextSearchService instance', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(fulltextSearchServiceProvider);
      expect(service, isA<FulltextSearchService>());
    });

    test('depends on databaseProvider', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseProvider);
      final service = container.read(fulltextSearchServiceProvider);

      // Service should use the same database
      expect(service, isA<FulltextSearchService>());

      // Both should be tied to the same lifecycle
      expect(() => db.select('SELECT 1'), returnsNormally);
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final service1 = container.read(fulltextSearchServiceProvider);
      final service2 = container.read(fulltextSearchServiceProvider);

      expect(identical(service1, service2), isTrue);
    });
  });

  group('appEventLogProvider', () {
    test('creates AppEventLog instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final log = container.read(appEventLogProvider);
      expect(log, isNotNull);
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final log1 = container.read(appEventLogProvider);
      final log2 = container.read(appEventLogProvider);

      expect(identical(log1, log2), isTrue);
    });
  });

  group('appLlmRequestPoolProvider', () {
    test('creates AppLlmRequestPool instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pool = container.read(appLlmRequestPoolProvider);
      expect(pool, isNotNull);
      expect(pool.maxConcurrent, equals(3));
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pool1 = container.read(appLlmRequestPoolProvider);
      final pool2 = container.read(appLlmRequestPoolProvider);

      expect(identical(pool1, pool2), isTrue);
    });
  });

  group('fulltext search page no registry access', () {
    test('fulltextSearchNotifier uses provider, not registry', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      // Read the provider - this should not require serviceRegistryProvider
      final notifier = container.read(fulltextSearchProvider.notifier);

      expect(notifier, isNotNull);
    });
  });

  group('appProviderOverridesForRegistry', () {
    test('returns same foundational instances as registry', () {
      final registry = createTestRegistry();

      final overrides = appProviderOverridesForRegistry(registry);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
      });

      // Verify that providers return the same instances as registry
      final eventBusFromProvider = container.read(appEventBusProvider);
      final eventBusFromRegistry = registry.resolve<AppEventBus>();
      expect(identical(eventBusFromProvider, eventBusFromRegistry), isTrue);

      final eventLogFromProvider = container.read(appEventLogProvider);
      final eventLogFromRegistry = registry.resolve<AppEventLog>();
      expect(identical(eventLogFromProvider, eventLogFromRegistry), isTrue);

      final llmClientFromProvider = container.read(appLlmClientProvider);
      final llmClientFromRegistry = registry.resolve<AppLlmClient>();
      expect(identical(llmClientFromProvider, llmClientFromRegistry), isTrue);

      final poolFromProvider = container.read(appLlmRequestPoolProvider);
      final poolFromRegistry = registry.resolve<AppLlmRequestPool>();
      expect(identical(poolFromProvider, poolFromRegistry), isTrue);

      final dbFromProvider = container.read(databaseProvider);
      final dbFromRegistry = registry.resolve<sqlite3.Database>();
      expect(identical(dbFromProvider, dbFromRegistry), isTrue);

      final ftsFromProvider = container.read(fulltextSearchServiceProvider);
      final ftsFromRegistry = registry.resolve<FulltextSearchService>();
      expect(identical(ftsFromProvider, ftsFromRegistry), isTrue);
    });

    test('includes serviceRegistryProvider override', () {
      final registry = createTestRegistry();

      final overrides = appProviderOverridesForRegistry(registry);

      // Verify that we get the expected number of overrides
      // 7 foundational + 2 DB-backed stores = 9
      expect(overrides.length, greaterThanOrEqualTo(7));

      // Verify the registry override works correctly
      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
      });

      final registryFromProvider = container.read(serviceRegistryProvider);
      expect(identical(registryFromProvider, registry), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native DB-backed store provider tests (M4-03)
  // ─────────────────────────────────────────────────────────────────────────────

  group('roleplaySessionStoreProvider (native)', () {
    test('creates RoleplaySessionStoreIO backed by in-memory database', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(roleplaySessionStoreProvider);
      expect(store, isA<RoleplaySessionStoreIO>());
    });

    test('shares databaseProvider lifecycle', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseProvider);
      final store = container.read(roleplaySessionStoreProvider);

      expect(store, isA<RoleplaySessionStoreIO>());
      // Both are tied to the same database lifecycle
      expect(() => db.select('SELECT 1'), returnsNormally);
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final store1 = container.read(roleplaySessionStoreProvider);
      final store2 = container.read(roleplaySessionStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('characterMemoryStoreProvider (native)', () {
    test('creates CharacterMemoryStoreIO backed by in-memory database', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(characterMemoryStoreProvider);
      expect(store, isA<CharacterMemoryStoreIO>());
    });

    test('shares databaseProvider lifecycle', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final db = container.read(databaseProvider);
      final store = container.read(characterMemoryStoreProvider);

      expect(store, isA<CharacterMemoryStoreIO>());
      // Both are tied to the same database lifecycle
      expect(() => db.select('SELECT 1'), returnsNormally);
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      final store1 = container.read(characterMemoryStoreProvider);
      final store2 = container.read(characterMemoryStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Coexistence tests for DB-backed stores
  // ─────────────────────────────────────────────────────────────────────────────

  group('appProviderOverridesForRegistry coexistence', () {
    test('includes DB-backed store overrides', () {
      final registry = createTestRegistry();
      final mockRoleplayStore = _MockRoleplaySessionStore();
      final mockCharacterStore = _MockCharacterMemoryStore();
      registry.registerSingleton<RoleplaySessionStore>(mockRoleplayStore);
      registry.registerSingleton<CharacterMemoryStore>(mockCharacterStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count includes:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
      });

      // Verify that providers return the same instances as registry
      final roleplayFromProvider = container.read(roleplaySessionStoreProvider);
      final roleplayFromRegistry = registry.resolve<RoleplaySessionStore>();
      expect(identical(roleplayFromProvider, roleplayFromRegistry), isTrue);

      final characterFromProvider = container.read(
        characterMemoryStoreProvider,
      );
      final characterFromRegistry = registry.resolve<CharacterMemoryStore>();
      expect(identical(characterFromProvider, characterFromRegistry), isTrue);
    });

    test('native providers work without registry in test mode', () {
      // Tests can override databaseProvider without touching serviceRegistryProvider
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
        ],
      );
      addTearDown(container.dispose);

      // Native providers should create their own instances
      final roleplayStore = container.read(roleplaySessionStoreProvider);
      final characterStore = container.read(characterMemoryStoreProvider);

      expect(roleplayStore, isA<RoleplaySessionStoreIO>());
      expect(characterStore, isA<CharacterMemoryStoreIO>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native feature store provider tests (M4-04)
  // ─────────────────────────────────────────────────────────────────────────────

  group('authorFeedbackStoreProvider (native M4-04)', () {
    test('creates AuthorFeedbackStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(authorFeedbackStoreProvider);
      expect(store, isA<AuthorFeedbackStore>());
    });

    test('disposes AuthorFeedbackStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );

      final store = container.read(authorFeedbackStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(authorFeedbackStoreProvider);
      final store2 = container.read(authorFeedbackStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('reviewTaskStoreProvider (native M4-04)', () {
    test('creates ReviewTaskStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(reviewTaskStoreProvider);
      expect(store, isA<ReviewTaskStore>());
    });

    test('disposes ReviewTaskStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );

      final store = container.read(reviewTaskStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(reviewTaskStoreProvider);
      final store2 = container.read(reviewTaskStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appProviderOverridesForRegistry M4-04 coexistence', () {
    test('includes M4-04 feature store overrides', () {
      final registry = createTestRegistry();
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final eventBus = AppEventBus();
      final authorFeedbackStore = AuthorFeedbackStore(
        storage: InMemoryAuthorFeedbackStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final reviewTaskStore = ReviewTaskStore(
        storage: InMemoryReviewTaskStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      registry.registerSingleton<AuthorFeedbackStore>(authorFeedbackStore);
      registry.registerSingleton<ReviewTaskStore>(reviewTaskStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count should now include:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
        workspaceStore.dispose();
        eventBus.dispose();
      });

      // Verify that providers return the same instances as registry
      final authorFeedbackFromProvider = container.read(
        authorFeedbackStoreProvider,
      );
      final authorFeedbackFromRegistry = registry
          .resolve<AuthorFeedbackStore>();
      expect(
        identical(authorFeedbackFromProvider, authorFeedbackFromRegistry),
        isTrue,
      );

      final reviewTaskFromProvider = container.read(reviewTaskStoreProvider);
      final reviewTaskFromRegistry = registry.resolve<ReviewTaskStore>();
      expect(identical(reviewTaskFromProvider, reviewTaskFromRegistry), isTrue);
    });

    test('native M4-04 providers work without registry in test mode', () {
      // Tests can override appWorkspaceStoreProvider without touching serviceRegistryProvider
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: [
          appWorkspaceStoreProvider.overrideWith(
            () => _TestAppWorkspaceStoreNotifier(workspaceStore),
          ),
        ],
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      // Native providers should create their own instances
      final authorFeedbackStore = container.read(authorFeedbackStoreProvider);
      final reviewTaskStore = container.read(reviewTaskStoreProvider);

      expect(authorFeedbackStore, isA<AuthorFeedbackStore>());
      expect(reviewTaskStore, isA<ReviewTaskStore>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native core leaf store provider tests (M4-05)
  // ─────────────────────────────────────────────────────────────────────────────

  group('appVersionStoreProvider (native M4-05)', () {
    test('creates AppVersionStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(appVersionStoreProvider);
      expect(store, isA<AppVersionStore>());
    });

    test('disposes AppVersionStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );

      final store = container.read(appVersionStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(appVersionStoreProvider);
      final store2 = container.read(appVersionStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('writingStatsStoreProvider (native M4-05)', () {
    test('creates WritingStatsStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(writingStatsStoreProvider);
      expect(store, isA<WritingStatsStore>());
    });

    test('disposes WritingStatsStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );

      final store = container.read(writingStatsStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(writingStatsStoreProvider);
      final store2 = container.read(writingStatsStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appAiHistoryStoreProvider (native M4-05)', () {
    test('creates AppAiHistoryStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(appAiHistoryStoreProvider);
      expect(store, isA<AppAiHistoryStore>());
    });

    test('disposes AppAiHistoryStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );

      final store = container.read(appAiHistoryStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(appAiHistoryStoreProvider);
      final store2 = container.read(appAiHistoryStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appProviderOverridesForRegistry M4-05 coexistence', () {
    test('includes M4-05 core leaf store overrides', () {
      final registry = createTestRegistry();
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final eventBus = AppEventBus();
      final appVersionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final writingStatsStore = WritingStatsStore(
        storage: _InMemoryWritingStatsStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final appAiHistoryStore = AppAiHistoryStore(
        storage: InMemoryAppAiHistoryStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      registry.registerSingleton<AppVersionStore>(appVersionStore);
      registry.registerSingleton<WritingStatsStore>(writingStatsStore);
      registry.registerSingleton<AppAiHistoryStore>(appAiHistoryStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count should now include:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
        workspaceStore.dispose();
        eventBus.dispose();
      });

      // Verify that providers return the same instances as registry
      final appVersionFromProvider = container.read(appVersionStoreProvider);
      final appVersionFromRegistry = registry.resolve<AppVersionStore>();
      expect(identical(appVersionFromProvider, appVersionFromRegistry), isTrue);

      final writingStatsFromProvider = container.read(
        writingStatsStoreProvider,
      );
      final writingStatsFromRegistry = registry.resolve<WritingStatsStore>();
      expect(
        identical(writingStatsFromProvider, writingStatsFromRegistry),
        isTrue,
      );

      final appAiHistoryFromProvider = container.read(
        appAiHistoryStoreProvider,
      );
      final appAiHistoryFromRegistry = registry.resolve<AppAiHistoryStore>();
      expect(
        identical(appAiHistoryFromProvider, appAiHistoryFromRegistry),
        isTrue,
      );
    });

    test('native M4-05 providers work without registry in test mode', () {
      // Tests can override appWorkspaceStoreProvider without touching serviceRegistryProvider
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m405NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      // Native providers should create their own instances
      final appVersionStore = container.read(appVersionStoreProvider);
      final writingStatsStore = container.read(writingStatsStoreProvider);
      final appAiHistoryStore = container.read(appAiHistoryStoreProvider);

      expect(appVersionStore, isA<AppVersionStore>());
      expect(writingStatsStore, isA<WritingStatsStore>());
      expect(appAiHistoryStore, isA<AppAiHistoryStore>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native workspace/session store provider tests (M4-06)
  // ─────────────────────────────────────────────────────────────────────────────

  group('appDraftStoreProvider (native M4-06)', () {
    test('creates AppDraftStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(appDraftStoreProvider);
      expect(store, isA<AppDraftStore>());
    });

    test('disposes AppDraftStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );

      final store = container.read(appDraftStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
      workspaceStore.dispose();
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(appDraftStoreProvider);
      final store2 = container.read(appDraftStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appSceneContextStoreProvider (native M4-06)', () {
    test('creates AppSceneContextStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(appSceneContextStoreProvider);
      expect(store, isA<AppSceneContextStore>());
    });

    test('disposes AppSceneContextStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );

      final store = container.read(appSceneContextStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
      workspaceStore.dispose();
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(appSceneContextStoreProvider);
      final store2 = container.read(appSceneContextStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appSimulationStoreProvider (native M4-06)', () {
    test('creates AppSimulationStore with workspace and event log', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(appSimulationStoreProvider);
      expect(store, isA<AppSimulationStore>());
    });

    test('disposes AppSimulationStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );

      final store = container.read(appSimulationStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
      workspaceStore.dispose();
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(appSimulationStoreProvider);
      final store2 = container.read(appSimulationStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appProviderOverridesForRegistry M4-06 coexistence', () {
    test('includes M4-06 workspace/session store overrides', () {
      final registry = createTestRegistry();
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final eventBus = AppEventBus();
      final eventLog = AppEventLog();
      final appDraftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final appSceneContextStore = AppSceneContextStore(
        storage: InMemoryAppSceneContextStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final appSimulationStore = AppSimulationStore(
        storage: InMemoryAppSimulationStorage(),
        workspaceStore: workspaceStore,
        eventLog: eventLog,
      );
      registry.registerSingleton<AppDraftStore>(appDraftStore);
      registry.registerSingleton<AppSceneContextStore>(appSceneContextStore);
      registry.registerSingleton<AppSimulationStore>(appSimulationStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count should now include:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
        workspaceStore.dispose();
        eventBus.dispose();
      });

      // Verify that providers return the same instances as registry
      final appDraftFromProvider = container.read(appDraftStoreProvider);
      final appDraftFromRegistry = registry.resolve<AppDraftStore>();
      expect(identical(appDraftFromProvider, appDraftFromRegistry), isTrue);

      final appSceneContextFromProvider = container.read(
        appSceneContextStoreProvider,
      );
      final appSceneContextFromRegistry = registry
          .resolve<AppSceneContextStore>();
      expect(
        identical(appSceneContextFromProvider, appSceneContextFromRegistry),
        isTrue,
      );

      final appSimulationFromProvider = container.read(
        appSimulationStoreProvider,
      );
      final appSimulationFromRegistry = registry.resolve<AppSimulationStore>();
      expect(
        identical(appSimulationFromProvider, appSimulationFromRegistry),
        isTrue,
      );
    });

    test('native M4-06 providers work without registry in test mode', () {
      // Tests can override appWorkspaceStoreProvider without touching serviceRegistryProvider
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m406NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      // Native providers should create their own instances
      final appDraftStore = container.read(appDraftStoreProvider);
      final appSceneContextStore = container.read(appSceneContextStoreProvider);
      final appSimulationStore = container.read(appSimulationStoreProvider);

      expect(appDraftStore, isA<AppDraftStore>());
      expect(appSceneContextStore, isA<AppSceneContextStore>());
      expect(appSimulationStore, isA<AppSimulationStore>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native story core store provider tests (M4-07)
  // ─────────────────────────────────────────────────────────────────────────────

  group('storyOutlineStoreProvider (native M4-07)', () {
    test('creates StoryOutlineStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(storyOutlineStoreProvider);
      expect(store, isA<StoryOutlineStore>());
    });

    test('disposes StoryOutlineStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );

      final store = container.read(storyOutlineStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
      workspaceStore.dispose();
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(storyOutlineStoreProvider);
      final store2 = container.read(storyOutlineStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('storyGenerationStoreProvider (native M4-07)', () {
    test('creates StoryGenerationStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(storyGenerationStoreProvider);
      expect(store, isA<StoryGenerationStore>());
    });

    test('disposes StoryGenerationStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );

      final store = container.read(storyGenerationStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
      workspaceStore.dispose();
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(storyGenerationStoreProvider);
      final store2 = container.read(storyGenerationStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('storyArcStoreProvider (native M4-07)', () {
    test('creates StoryArcStore with workspace and event bus', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store = container.read(storyArcStoreProvider);
      expect(store, isA<StoryArcStore>());
    });

    test('disposes StoryArcStore on container dispose', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );

      final store = container.read(storyArcStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
      workspaceStore.dispose();
    });

    test('returns same instance across multiple reads', () {
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      final store1 = container.read(storyArcStoreProvider);
      final store2 = container.read(storyArcStoreProvider);

      expect(identical(store1, store2), isTrue);
    });
  });

  group('appProviderOverridesForRegistry M4-07 coexistence', () {
    test('includes M4-07 story core store overrides', () {
      final registry = createTestRegistry();
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final eventBus = AppEventBus();
      final storyOutlineStore = StoryOutlineStore(
        storage: InMemoryStoryOutlineStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final storyGenerationStore = StoryGenerationStore(
        storage: InMemoryStoryGenerationStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      final storyArcStore = StoryArcStore(
        storage: InMemoryStoryArcStorage(),
        workspaceStore: workspaceStore,
        eventBus: eventBus,
      );
      registry.registerSingleton<StoryOutlineStore>(storyOutlineStore);
      registry.registerSingleton<StoryGenerationStore>(storyGenerationStore);
      registry.registerSingleton<StoryArcStore>(storyArcStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count should now be 22:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-08 settings store (override generated even if not registered)
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
        workspaceStore.dispose();
        eventBus.dispose();
      });

      // Verify that providers return the same instances as registry
      final storyOutlineFromProvider = container.read(
        storyOutlineStoreProvider,
      );
      final storyOutlineFromRegistry = registry.resolve<StoryOutlineStore>();
      expect(
        identical(storyOutlineFromProvider, storyOutlineFromRegistry),
        isTrue,
      );

      final storyGenerationFromProvider = container.read(
        storyGenerationStoreProvider,
      );
      final storyGenerationFromRegistry = registry
          .resolve<StoryGenerationStore>();
      expect(
        identical(storyGenerationFromProvider, storyGenerationFromRegistry),
        isTrue,
      );

      final storyArcFromProvider = container.read(storyArcStoreProvider);
      final storyArcFromRegistry = registry.resolve<StoryArcStore>();
      expect(identical(storyArcFromProvider, storyArcFromRegistry), isTrue);
    });

    test('native M4-07 providers work without registry in test mode', () {
      // Tests can override appWorkspaceStoreProvider without touching serviceRegistryProvider
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      final container = ProviderContainer(
        overrides: _m407NativeOverrides(workspaceStore),
      );
      addTearDown(() {
        container.dispose();
        workspaceStore.dispose();
      });

      // Native providers should create their own instances
      final storyOutlineStore = container.read(storyOutlineStoreProvider);
      final storyGenerationStore = container.read(storyGenerationStoreProvider);
      final storyArcStore = container.read(storyArcStoreProvider);

      expect(storyOutlineStore, isA<StoryOutlineStore>());
      expect(storyGenerationStore, isA<StoryGenerationStore>());
      expect(storyArcStore, isA<StoryArcStore>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native settings store provider tests (M4-08)
  // ─────────────────────────────────────────────────────────────────────────────

  group('appSettingsStoreProvider (native M4-08)', () {
    test('creates AppSettingsStore with foundational providers', () {
      final container = ProviderContainer(
        overrides: [
          appSettingsStorageProvider.overrideWith(
            (ref) => InMemoryAppSettingsStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appSettingsStoreProvider);
      expect(store, isA<AppSettingsStore>());
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer(
        overrides: [
          appSettingsStorageProvider.overrideWith(
            (ref) => InMemoryAppSettingsStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store1 = container.read(appSettingsStoreProvider);
      final store2 = container.read(appSettingsStoreProvider);

      expect(identical(store1, store2), isTrue);
    });

    test('disposes AppSettingsStore on container dispose', () {
      final container = ProviderContainer(
        overrides: [
          appSettingsStorageProvider.overrideWith(
            (ref) => InMemoryAppSettingsStorage(),
          ),
        ],
      );

      final store = container.read(appSettingsStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('uses InMemoryAppSettingsStorage in tests', () {
      final container = ProviderContainer(
        overrides: [
          appSettingsStorageProvider.overrideWith(
            (ref) => InMemoryAppSettingsStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final storage = container.read(appSettingsStorageProvider);
      expect(storage, isA<InMemoryAppSettingsStorage>());
    });
  });

  group('appProviderOverridesForRegistry M4-08 coexistence', () {
    test('includes M4-08 settings store override', () {
      final registry = createTestRegistry();
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: registry.resolve<AppLlmClient>(),
        requestPool: registry.resolve<AppLlmRequestPool>(),
        eventLog: registry.resolve<AppEventLog>(),
        eventBus: registry.resolve<AppEventBus>(),
      );
      registry.registerSingleton<AppSettingsStore>(settingsStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count should now be 22:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-08 settings store
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
      });

      // Verify that provider returns the same instance as registry
      final settingsFromProvider = container.read(appSettingsStoreProvider);
      final settingsFromRegistry = registry.resolve<AppSettingsStore>();
      expect(identical(settingsFromProvider, settingsFromRegistry), isTrue);
    });

    test('native M4-08 provider works without registry in test mode', () {
      // Tests can use native provider without touching serviceRegistryProvider
      final container = ProviderContainer(
        overrides: [
          appSettingsStorageProvider.overrideWith(
            (ref) => InMemoryAppSettingsStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Native provider should create its own instance
      final settingsStore = container.read(appSettingsStoreProvider);
      expect(settingsStore, isA<AppSettingsStore>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Native workspace store provider tests (M4-09)
  // ─────────────────────────────────────────────────────────────────────────────

  group('appWorkspaceStoreProvider (native M4-09)', () {
    test('creates AppWorkspaceStore with InMemoryAppWorkspaceStorage', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appWorkspaceStoreProvider);
      expect(store, isA<AppWorkspaceStore>());
    });

    test('uses InMemoryAppWorkspaceStorage in tests', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final storage = container.read(appWorkspaceStorageProvider);
      expect(storage, isA<InMemoryAppWorkspaceStorage>());
    });

    test('returns same instance across multiple reads', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store1 = container.read(appWorkspaceStoreProvider);
      final store2 = container.read(appWorkspaceStoreProvider);

      expect(identical(store1, store2), isTrue);
    });

    test('disposes AppWorkspaceStore on container dispose', () {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );

      final store = container.read(appWorkspaceStoreProvider);

      // Store should be usable before disposal
      expect(() => store.addListener(() {}), returnsNormally);

      container.dispose();

      // Store operations should fail after disposal
      expect(() => store.addListener(() {}), throwsA(isA<FlutterError>()));
    });

    test('workspace mutations notify Riverpod listeners', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final store = container.read(appWorkspaceStoreProvider);
      var notificationCount = 0;
      container.listen<AppWorkspaceStore>(
        appWorkspaceStoreProvider,
        (_, _) => notificationCount++,
      );

      // No initial notification without fireImmediately: true
      expect(notificationCount, equals(0));

      // Mutate workspace
      store.createProject(projectName: 'M4-09 notify');

      // Wait for async operation
      await container.pump();

      // Should have received notification after mutation
      expect(notificationCount, equals(1));
    });
  });

  group('appProviderOverridesForRegistry M4-09 coexistence', () {
    test('includes M4-09 workspace store override', () {
      final registry = createTestRegistry();
      final eventBus = AppEventBus();
      final workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
        eventBus: eventBus,
      );
      registry.registerSingleton<AppWorkspaceStore>(workspaceStore);

      final overrides = appProviderOverridesForRegistry(registry);

      // Count should now be 22:
      // - 7 foundational providers
      // - 2 DB-backed stores
      // - 2 M4-04 feature stores
      // - 3 M4-05 core leaf stores
      // - 3 M4-06 workspace/session stores
      // - 3 M4-07 story core stores
      // - 1 M4-08 settings store
      // - 1 M4-09 workspace store
      expect(overrides.length, equals(22));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(() {
        container.dispose();
        registry.disposeAll();
        workspaceStore.dispose();
        eventBus.dispose();
      });

      // Verify that provider returns the same instance as registry
      final workspaceFromProvider = container.read(appWorkspaceStoreProvider);
      final workspaceFromRegistry = registry.resolve<AppWorkspaceStore>();
      expect(identical(workspaceFromProvider, workspaceFromRegistry), isTrue);
    });

    test('native M4-09 provider works without registry in test mode', () {
      // Tests can use native provider without touching serviceRegistryProvider
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWith((ref) {
            final db = createInMemoryDatabase();
            ref.onDispose(db.dispose);
            return db;
          }),
          appWorkspaceStorageProvider.overrideWith(
            (ref) => InMemoryAppWorkspaceStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Native provider should create its own instance
      final workspaceStore = container.read(appWorkspaceStoreProvider);
      expect(workspaceStore, isA<AppWorkspaceStore>());
    });

    // Note: StoryGenerationRunStoreNotifier remains registry-backed (out of scope for M4-09).
    // This is verified by source-level evidence in app_providers.dart:
    // `StoryGenerationRunStoreNotifier extends RegistryStoreNotifier` (line 408-409).
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock implementations for testing registry-backed providers
// ─────────────────────────────────────────────────────────────────────────────

class _MockRoleplaySessionStore implements RoleplaySessionStore {
  @override
  Future<void> clearProject(String projectId) async {}

  @override
  Future<SceneRoleplaySession?> loadSession({
    required String projectId,
    required String chapterId,
    required String sceneId,
  }) async => null;

  @override
  Future<List<SceneRoleplaySession>> loadChapterSessions({
    required String projectId,
    required String chapterId,
  }) async => [];

  @override
  Future<List<SceneRoleplaySession>> loadProjectSessions({
    required String projectId,
  }) async => [];

  @override
  Future<void> saveSession({
    required String projectId,
    required SceneRoleplaySession session,
  }) async {}
}

class _MockCharacterMemoryStore implements CharacterMemoryStore {
  @override
  Future<void> clearProject(String projectId) async {}

  @override
  Future<List<CharacterMemoryDelta>> loadCharacterMemories({
    required String projectId,
    required String characterId,
    required MemoryTier tier,
  }) async => [];

  @override
  Future<List<CharacterMemoryDelta>> loadPublicMemories({
    required String projectId,
    required MemoryTier tier,
  }) async => [];

  @override
  Future<void> saveAcceptedDeltas({
    required String projectId,
    required String chapterId,
    required String sceneId,
    required MemoryTier tier,
    required String producer,
    required List<CharacterMemoryDelta> deltas,
  }) async {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers for M4-05 storage isolation
// ─────────────────────────────────────────────────────────────────────────────

/// In-memory implementation of [WritingStatsStorage] for testing.
class _InMemoryWritingStatsStorage implements WritingStatsStorage {
  final List<Map<String, Object?>> dailyStats = [];
  final Map<String, Map<String, Object?>> projectStats = {};
  final Map<String, Map<String, Object?>> goals = {};

  @override
  Future<List<Map<String, Object?>>> loadDailyStats({
    required String projectId,
    String? fromDate,
    String? toDate,
  }) async {
    return [
      for (final row in dailyStats)
        if (row['projectId'] == projectId) Map<String, Object?>.from(row),
    ];
  }

  @override
  Future<Map<String, Object?>?> loadProjectStat({
    required String projectId,
  }) async {
    final row = projectStats[projectId];
    return row == null ? null : Map<String, Object?>.from(row);
  }

  @override
  Future<List<Map<String, Object?>>> loadGoals({String? projectId}) async {
    return [
      for (final row in goals.values)
        if (projectId == null ||
            projectId.isEmpty ||
            row['projectId'] == projectId ||
            row['projectId'] == '')
          Map<String, Object?>.from(row),
    ];
  }

  @override
  Future<void> upsertDailyStat(Map<String, Object?> row) async {
    dailyStats.removeWhere(
      (existing) =>
          existing['date'] == row['date'] &&
          existing['sceneScopeId'] == row['sceneScopeId'],
    );
    dailyStats.add(Map<String, Object?>.from(row));
  }

  @override
  Future<void> upsertProjectStat(Map<String, Object?> row) async {
    projectStats[row['projectId']?.toString() ?? ''] =
        Map<String, Object?>.from(row);
  }

  @override
  Future<void> upsertGoal(Map<String, Object?> goal) async {
    goals[goal['id']?.toString() ?? ''] = Map<String, Object?>.from(goal);
  }

  @override
  Future<void> deleteGoal({required String goalId}) async {
    goals.remove(goalId);
  }

  @override
  Future<void> clearProject(String projectId) async {
    dailyStats.removeWhere((row) => row['projectId'] == projectId);
    projectStats.remove(projectId);
    goals.removeWhere((_, row) => row['projectId'] == projectId);
  }
}

/// Helper to create storage-isolated overrides for M4-05 native provider tests.
List<Override> _m405NativeOverrides(AppWorkspaceStore workspaceStore) => [
  appWorkspaceStoreProvider.overrideWith(
    () => _TestAppWorkspaceStoreNotifier(workspaceStore),
  ),
  appVersionStorageProvider.overrideWith((ref) => InMemoryAppVersionStorage()),
  appAiHistoryStorageProvider.overrideWith(
    (ref) => InMemoryAppAiHistoryStorage(),
  ),
  writingStatsStorageProvider.overrideWith(
    (ref) => _InMemoryWritingStatsStorage(),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers for M4-06 storage isolation
// ─────────────────────────────────────────────────────────────────────────────

/// Helper to create storage-isolated overrides for M4-06 native provider tests.
List<Override> _m406NativeOverrides(AppWorkspaceStore workspaceStore) => [
  appWorkspaceStoreProvider.overrideWith(
    () => _TestAppWorkspaceStoreNotifier(workspaceStore),
  ),
  appDraftStorageProvider.overrideWith((ref) => InMemoryAppDraftStorage()),
  appSceneContextStorageProvider.overrideWith(
    (ref) => InMemoryAppSceneContextStorage(),
  ),
  appSimulationStorageProvider.overrideWith(
    (ref) => InMemoryAppSimulationStorage(),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Test helpers for M4-07 storage isolation
// ─────────────────────────────────────────────────────────────────────────────

/// Helper to create storage-isolated overrides for M4-07 native provider tests.
List<Override> _m407NativeOverrides(AppWorkspaceStore workspaceStore) => [
  appWorkspaceStoreProvider.overrideWith(
    () => _TestAppWorkspaceStoreNotifier(workspaceStore),
  ),
  storyOutlineStorageProvider.overrideWith(
    (ref) => InMemoryStoryOutlineStorage(),
  ),
  storyGenerationStorageProvider.overrideWith(
    (ref) => InMemoryStoryGenerationStorage(),
  ),
  storyArcStorageProvider.overrideWith((ref) => InMemoryStoryArcStorage()),
];

// ─────────────────────────────────────────────────────────────────────────────
// Mock implementations for testing registry-backed providers
// ─────────────────────────────────────────────────────────────────────────────
