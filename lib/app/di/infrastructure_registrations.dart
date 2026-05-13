import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../events/app_event_bus.dart';
import '../logging/app_event_log.dart';
import '../llm/app_llm_client.dart';
import '../llm/app_llm_request_pool.dart';
import '../state/app_authoring_storage_io_support.dart';
import '../state/fulltext_search_service.dart';
import '../../features/story_generation/data/character_memory_store.dart';
import '../../features/story_generation/data/character_memory_store_io.dart';
import '../../features/story_generation/data/roleplay_session_store.dart';
import '../../features/story_generation/data/roleplay_session_store_io.dart';
import 'service_registry.dart';

void registerInfrastructureServices(ServiceRegistry registry) {
  registry.registerFactory<AppEventBus>((_) => AppEventBus());
  registry.registerFactory<AppEventLog>((_) => AppEventLog());
  registry.registerFactory<AppLlmClient>(
    (_) => createCachedAppLlmClient(),
  );
  registry.registerFactory<AppLlmRequestPool>(
    (_) => AppLlmRequestPool(maxConcurrent: 3),
  );
  registry.registerFactory<sqlite3.Database>(
    (_) => openAuthoringDatabase(resolveAuthoringDbPath()),
  );
  registry.registerFactory<RoleplaySessionStore>(
    (r) => RoleplaySessionStoreIO(db: r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<CharacterMemoryStore>(
    (r) => CharacterMemoryStoreIO(db: r.resolve<sqlite3.Database>()),
  );
  registry.registerFactory<FulltextSearchService>(
    (r) => FulltextSearchService(db: r.resolve<sqlite3.Database>()),
  );
}
