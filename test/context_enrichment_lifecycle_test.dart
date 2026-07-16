import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:novel_writer/app/rag/sqlite_vss_store.dart';
import 'package:novel_writer/app/rag/vector_store.dart';
import 'package:novel_writer/app/state/sqlite_write_coordinator.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_assembler.dart';
import 'package:novel_writer/features/story_generation/data/step_io.dart';
import 'package:novel_writer/features/story_generation/data/steps/context_enrichment_step.dart';
import 'package:novel_writer/features/story_generation/data/story_context_cache.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_indexer.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_io.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('ContextEnrichment owned generation lifecycle', () {
    late Database db;
    late StoryMemoryStorageIO storage;
    late HybridRetriever retriever;
    late StoryContextCache cache;
    late ContextEnrichmentStep step;
    var rejectNewEmbedding = false;

    setUp(() {
      db = sqlite3.openInMemory();
      storage = StoryMemoryStorageIO(db: db);
      retriever = HybridRetriever.local(
        db: db,
        embeddingForText: (text) async {
          if (rejectNewEmbedding && text.contains('new-generation')) {
            throw StateError('embedding failed');
          }
          return HybridRetriever.defaultEmbedding(text);
        },
      );
      cache = StoryContextCache();
      step = ContextEnrichmentStep(
        contextAssembler: SceneContextAssembler(),
        memoryStorage: storage,
        memoryRetriever: retriever,
        hybridRetriever: retriever,
        contextCache: cache,
      );
    });

    tearDown(() => db.dispose());

    test(
      'scenes replace independently, shrink to empty, and preserve other producers',
      () async {
        await _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(
            worldFacts: ['old-a-one', 'old-a-two'],
          ),
        );
        final firstAIds = _ownedChunks(
          await storage.loadChunks('project'),
          'project:scene-a',
        ).map((chunk) => chunk.id).toSet();
        expect(firstAIds, hasLength(2));
        expect(
          firstAIds.every(
            (id) =>
                id.startsWith('memory-generation-v1/') &&
                id.contains('/context-enrichment/worldFact/'),
          ),
          isTrue,
        );

        await _execute(
          step,
          sceneId: 'scene-b',
          materials: const ProjectMaterialSnapshot(worldFacts: ['only-b']),
        );
        const otherProducer = StoryMemoryChunk(
          id: 'outbox-same-scope',
          projectId: 'project',
          scopeId: 'project:scene-a',
          kind: MemorySourceKind.acceptedState,
          content: 'committed outbox memory',
          producer: 'generation-outbox',
        );
        await storage.saveChunks('project', const [otherProducer]);
        await retriever.indexChunks(const [otherProducer]);

        await _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(
            worldFacts: ['new-generation-a'],
          ),
        );

        var chunks = await storage.loadChunks('project');
        final currentA = _ownedChunks(chunks, 'project:scene-a');
        final currentB = _ownedChunks(chunks, 'project:scene-b');
        expect(currentA.map((chunk) => chunk.content), ['new-generation-a']);
        expect(currentB.map((chunk) => chunk.content), ['only-b']);
        expect(chunks.map((chunk) => chunk.id), contains('outbox-same-scope'));
        expect(
          _indexIds(db, 'rag_documents'),
          containsAll([
            ...currentA.map((chunk) => chunk.id),
            ...currentB.map((chunk) => chunk.id),
            'outbox-same-scope',
          ]),
        );
        expect(
          _indexIds(db, 'vector_embeddings'),
          containsAll([
            ...currentA.map((chunk) => chunk.id),
            ...currentB.map((chunk) => chunk.id),
            'outbox-same-scope',
          ]),
        );

        await _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(),
        );

        chunks = await storage.loadChunks('project');
        expect(_ownedChunks(chunks, 'project:scene-a'), isEmpty);
        expect(_ownedChunks(chunks, 'project:scene-b'), hasLength(1));
        expect(chunks.map((chunk) => chunk.id), contains('outbox-same-scope'));
      },
    );

    test('cache hit still repairs missing persistent generation', () async {
      const materials = ProjectMaterialSnapshot(worldFacts: ['cached-fact']);
      await _execute(step, sceneId: 'scene-a', materials: materials);
      await storage.replaceOwnedGeneration(
        projectId: 'project',
        scopeId: 'project:scene-a',
        producer: StoryMemoryIndexer.contextEnrichmentProducer,
        chunks: const [],
      );
      await retriever.replaceOwnedGeneration(
        projectId: 'project',
        scopeId: 'project:scene-a',
        producer: StoryMemoryIndexer.contextEnrichmentProducer,
        chunks: const [],
      );

      await _execute(step, sceneId: 'scene-a', materials: materials);

      expect(cache.hits, 1);
      expect(
        _ownedChunks(
          await storage.loadChunks('project'),
          'project:scene-a',
        ).single.content,
        'cached-fact',
      );
    });

    test(
      'hybrid failure rolls storage and both indexes back to old generation',
      () async {
        await _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(worldFacts: ['old-fact']),
        );
        final oldIds = _ownedChunks(
          await storage.loadChunks('project'),
          'project:scene-a',
        ).map((chunk) => chunk.id).toSet();

        rejectNewEmbedding = true;
        await expectLater(
          _execute(
            step,
            sceneId: 'scene-a',
            materials: const ProjectMaterialSnapshot(
              worldFacts: ['new-generation-fact'],
            ),
          ),
          throwsStateError,
        );

        final persisted = _ownedChunks(
          await storage.loadChunks('project'),
          'project:scene-a',
        );
        expect(persisted.map((chunk) => chunk.content), ['old-fact']);
        expect(_indexIds(db, 'rag_documents'), containsAll(oldIds));
        expect(_indexIds(db, 'vector_embeddings'), containsAll(oldIds));
      },
    );

    test(
      'legacy cleanup is limited to exact scope, ID shape, and kind',
      () async {
        const legacyOwned = StoryMemoryChunk(
          id: 'project_wf_0',
          projectId: 'project',
          scopeId: 'project:scene-a',
          kind: MemorySourceKind.worldFact,
          content: 'legacy context fact',
        );
        const legacyLookalike = StoryMemoryChunk(
          id: 'project_wf_9',
          projectId: 'project',
          scopeId: 'project:scene-a',
          kind: MemorySourceKind.sceneSummary,
          content: 'unrelated legacy-shaped memory',
        );
        await storage.saveChunks('project', const [
          legacyOwned,
          legacyLookalike,
        ]);
        await retriever.indexChunks(const [legacyOwned, legacyLookalike]);

        await _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(),
        );

        final ids = (await storage.loadChunks(
          'project',
        )).map((chunk) => chunk.id).toSet();
        expect(ids, isNot(contains('project_wf_0')));
        expect(ids, contains('project_wf_9'));
        expect(_indexIds(db, 'rag_documents'), contains('project_wf_9'));
        expect(_indexIds(db, 'vector_embeddings'), contains('project_wf_9'));
      },
    );

    test(
      'concurrent scene generations prepare in parallel and keep all stores aligned',
      () async {
        final firstEmbeddingStarted = Completer<void>();
        final secondEmbeddingStarted = Completer<void>();
        final releaseEmbeddings = Completer<void>();
        retriever = HybridRetriever.local(
          db: db,
          embeddingForText: (text) async {
            if (text == 'parallel-a') {
              firstEmbeddingStarted.complete();
              await releaseEmbeddings.future;
            } else if (text == 'parallel-b') {
              secondEmbeddingStarted.complete();
              await releaseEmbeddings.future;
            }
            return HybridRetriever.defaultEmbedding(text);
          },
        );
        step = ContextEnrichmentStep(
          contextAssembler: SceneContextAssembler(),
          memoryStorage: storage,
          memoryRetriever: retriever,
          hybridRetriever: retriever,
          contextCache: cache,
        );

        final first = _execute(
          step,
          sceneId: 'scene-parallel-a',
          materials: const ProjectMaterialSnapshot(worldFacts: ['parallel-a']),
        );
        final second = _execute(
          step,
          sceneId: 'scene-parallel-b',
          materials: const ProjectMaterialSnapshot(worldFacts: ['parallel-b']),
        );
        await Future.wait(<Future<void>>[
          firstEmbeddingStarted.future,
          secondEmbeddingStarted.future,
        ]);
        releaseEmbeddings.complete();
        await Future.wait(<Future<ContextEnrichmentOutput>>[first, second]);

        final memoryIds = (await storage.loadChunks('project'))
            .where((chunk) => chunk.producer == 'context-enrichment')
            .map((chunk) => chunk.id)
            .toSet();
        expect(memoryIds, hasLength(2));
        expect(_indexIds(db, 'rag_documents'), containsAll(memoryIds));
        expect(_indexIds(db, 'vector_embeddings'), containsAll(memoryIds));
      },
    );

    test(
      'failed generation rolls back fully and releases a queued generation',
      () async {
        await _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(worldFacts: ['stable-a']),
        );
        final failingVectorStore = _BlockingFailOnceSqliteVssStore(db);
        retriever = HybridRetriever(
          ftsStorage: LocalRagStorage(db: db),
          vectorStore: failingVectorStore,
          embeddingForText: HybridRetriever.defaultEmbedding,
        );
        step = ContextEnrichmentStep(
          contextAssembler: SceneContextAssembler(),
          memoryStorage: storage,
          memoryRetriever: retriever,
          hybridRetriever: retriever,
          contextCache: cache,
        );
        failingVectorStore.arm();

        final failing = _execute(
          step,
          sceneId: 'scene-a',
          materials: const ProjectMaterialSnapshot(worldFacts: ['broken-a']),
        );
        await failingVectorStore.started;
        final queued = _execute(
          step,
          sceneId: 'scene-b',
          materials: const ProjectMaterialSnapshot(worldFacts: ['queued-b']),
        );
        await Future<void>.delayed(Duration.zero);
        failingVectorStore.release();

        await expectLater(failing, throwsStateError);
        await queued;
        final chunks = await storage.loadChunks('project');
        final stableA = _ownedChunks(chunks, 'project:scene-a');
        final queuedB = _ownedChunks(chunks, 'project:scene-b');
        expect(stableA.map((chunk) => chunk.content), ['stable-a']);
        expect(queuedB.map((chunk) => chunk.content), ['queued-b']);
        final expectedIds = <String>{
          ...stableA.map((chunk) => chunk.id),
          ...queuedB.map((chunk) => chunk.id),
        };
        expect(_indexIds(db, 'rag_documents'), containsAll(expectedIds));
        expect(_indexIds(db, 'vector_embeddings'), containsAll(expectedIds));
      },
    );
  });
}

class _BlockingFailOnceSqliteVssStore extends SqliteVssStore {
  _BlockingFailOnceSqliteVssStore(super.db);

  Completer<void>? _started;
  Completer<void>? _release;
  bool _armed = false;

  Future<void> get started => _started!.future;

  void arm() {
    _armed = true;
    _started = Completer<void>();
    _release = Completer<void>();
  }

  void release() => _release!.complete();

  @override
  Future<void> upsertAllCoordinated(
    List<VectorStoreEntry> entries, {
    SqliteWriteLease? lease,
  }) async {
    if (_armed) {
      _armed = false;
      _started!.complete();
      await _release!.future;
      throw StateError('injected vector commit failure');
    }
    await super.upsertAllCoordinated(entries, lease: lease);
  }
}

Future<ContextEnrichmentOutput> _execute(
  ContextEnrichmentStep step, {
  required String sceneId,
  required ProjectMaterialSnapshot materials,
}) {
  return step.execute(
    ContextEnrichmentInput(
      brief: SceneBrief(
        projectId: 'project',
        chapterId: 'chapter',
        chapterTitle: 'Chapter',
        sceneId: sceneId,
        sceneTitle: sceneId,
        sceneSummary: 'summary',
      ),
      materials: materials,
    ),
    Object(),
  );
}

List<StoryMemoryChunk> _ownedChunks(
  List<StoryMemoryChunk> chunks,
  String scopeId,
) => [
  for (final chunk in chunks)
    if (chunk.scopeId == scopeId &&
        chunk.producer == StoryMemoryIndexer.contextEnrichmentProducer)
      chunk,
];

Set<String> _indexIds(Database db, String table) {
  final column = table == 'rag_documents' ? 'path' : 'id';
  return {
    for (final row in db.select('SELECT $column FROM $table'))
      row[column] as String,
  };
}
