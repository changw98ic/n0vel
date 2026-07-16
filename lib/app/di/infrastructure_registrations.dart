import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_authoring_storage_io_support.dart';
import '../state/app_draft_store.dart';
import '../state/app_version_store.dart';
import '../state/fulltext_search_service.dart';
import '../state/sqlite_write_coordinator.dart';
import '../rag/hybrid_retriever.dart';
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/character_memory_store_io.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/story_generation/data/roleplay_session_store_io.dart';
import '../../features/story_generation/data/story_memory_storage.dart';
import '../../features/story_generation/data/story_memory_storage_io.dart';
import '../../features/story_generation/data/generation_commit_coordinator.dart';
import '../../features/story_generation/data/generation_ledger.dart';
import '../../features/story_generation/data/generation_outbox_worker.dart';
import '../../features/author_feedback/data/author_feedback_store.dart';
import 'service_registry.dart';

void registerInfrastructureServices(ServiceRegistry registry) {
  registry.registerFactory<AppEventBus>((_) => AppEventBus());
  registry.registerFactory<AppEventLog>((_) => AppEventLog());
  registry.registerFactory<AppLlmClient>((_) => createCachedAppLlmClient());
  registry.registerFactory<AppLlmRequestPool>(
    (_) => AppLlmRequestPool(maxConcurrent: 3),
  );
  registry.registerFactory<sqlite3.Database>(
    (_) => openAuthoringDatabase(resolveAuthoringDbPath()),
  );
  registry.registerFactory<SqliteWriteCoordinator>(
    (r) => SqliteWriteCoordinator.forDatabase(r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<GenerationLedgerSqliteStore>(
    (r) => GenerationLedgerSqliteStore(db: r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<GenerationCommitCoordinator>(
    (r) => GenerationCommitCoordinator(
      db: r.resolve<sqlite3.Database>(),
      draftStore: r.resolve<AppDraftStore>(),
      versionStore: r.resolve<AppVersionStore>(),
      authorFeedbackStore: r.resolve<AuthorFeedbackStore>(),
    ),
  );
  registry.registerFactory<GenerationOutboxWorker>(
    (r) => GenerationOutboxWorker(
      ledger: r.resolve<GenerationLedgerSqliteStore>(),
      db: r.resolve<sqlite3.Database>(),
      retriever: r.resolve<HybridRetriever>(),
    ),
  );
  registry.registerFactory<RoleplaySessionStore>(
    (r) => RoleplaySessionStoreIO(db: r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<CharacterMemoryStore>(
    (r) => CharacterMemoryStoreIO(db: r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<StoryMemoryStorage>(
    (r) => StoryMemoryStorageIO(
      db: r.resolve<sqlite3.Database>(),
      writeCoordinator: r.resolve<SqliteWriteCoordinator>(),
    ),
  );
  registry.registerFactory<HybridRetriever>(
    (r) => HybridRetriever.local(
      db: r.resolve<sqlite3.Database>(),
      writeCoordinator: r.resolve<SqliteWriteCoordinator>(),
    ),
  );
  registry.registerFactory<FulltextSearchService>(
    (r) => FulltextSearchService(db: r.resolve<sqlite3.Database>()),
  );
}
