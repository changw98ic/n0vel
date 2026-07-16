import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/service_registration.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/chapter_context_bridge.dart';
import 'package:novel_writer/features/story_generation/data/generation_outbox_worker.dart';
import 'package:novel_writer/features/story_generation/data/story_pipeline_factory.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test('default app registration includes the complete story pipeline', () {
    final registry = ServiceRegistry();
    addTearDown(registry.disposeAll);

    registerAppServices(registry);

    expect(registry.isRegistered<StoryMemoryStorage>(), isTrue);
    expect(registry.isRegistered<HybridRetriever>(), isTrue);
    expect(registry.isRegistered<StoryMemoryRetrievalService>(), isTrue);
    expect(registry.isRegistered<StoryPipelineFactory>(), isTrue);
    expect(registry.isRegistered<ChapterGenerationService>(), isTrue);
    expect(registry.isRegistered<GenerationOutboxWorker>(), isTrue);
  });

  test('default factory shares infrastructure and creates fresh runners', () {
    final registry = ServiceRegistry();
    final db = sqlite3.sqlite3.openInMemory();
    registry.registerSingleton<sqlite3.Database>(db);
    registry.registerSingleton<AppWorkspaceStore>(
      AppWorkspaceStore(storage: InMemoryAppWorkspaceStorage()),
    );
    registry.registerSingleton<AppSettingsStore>(
      AppSettingsStore(storage: InMemoryAppSettingsStorage()),
    );
    addTearDown(registry.disposeAll);
    registerAppServices(registry);

    final storage = registry.resolve<StoryMemoryStorage>();
    expect(storage, isA<StoryMemoryStorageIO>());
    expect((storage as StoryMemoryStorageIO).db, same(db));

    final factory = registry.resolve<StoryPipelineFactory>();
    final first = factory.create();
    final second = factory.create();
    expect(second, isNot(same(first)));

    final bridge = registry.resolve<ChapterContextBridgeService>();
    expect(bridge, isA<ChapterContextBridge>());
    expect((bridge as ChapterContextBridge).authorityDb, same(db));
  });
}
