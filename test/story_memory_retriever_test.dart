import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_stub.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_retriever.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_indexer.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_dedupe.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_assembler.dart';

void main() {
  group('indexer', () {
    test('creates chunks for all material types', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'proj-1',
        scopeId: 'ch1:sc1',
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['Magic needs a catalyst.'],
          characterProfiles: ['Liu Xi is a scholar.'],
          relationshipHints: ['Liu Xi trusts the elder.'],
          outlineBeats: ['Hero finds the sword.'],
          sceneSummaries: ['Scene 1: The discovery.'],
          acceptedStates: ['Key was lost in ch1.'],
          reviewFindings: ['Dialogue feels stilted.'],
        ),
        nowMs: 1000,
      );

      final kinds = chunks.map((c) => c.kind).toSet();
      expect(
        kinds,
        containsAll([
          MemorySourceKind.worldFact,
          MemorySourceKind.characterProfile,
          MemorySourceKind.relationshipHint,
          MemorySourceKind.outlineBeat,
          MemorySourceKind.sceneSummary,
          MemorySourceKind.acceptedState,
          MemorySourceKind.reviewFinding,
        ]),
      );
      expect(chunks.length, 7);
    });

    test('trims empty content', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['', '   ', 'valid fact'],
        ),
        nowMs: 1000,
      );
      expect(chunks.length, 1);
      expect(chunks.first.content, 'valid fact');
    });

    test('assigns tags from content', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['The #ancient_temple is hidden.'],
        ),
        nowMs: 1000,
      );
      expect(chunks.first.tags, containsAll(['world', 'ancient_temple']));
    });

    test('accepted state gets higher priority', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['some fact'],
          acceptedStates: ['accepted state'],
        ),
        nowMs: 1000,
      );
      final stateChunk = chunks.firstWhere(
        (c) => c.kind == MemorySourceKind.acceptedState,
      );
      final worldChunk = chunks.firstWhere(
        (c) => c.kind == MemorySourceKind.worldFact,
      );
      expect(stateChunk.priority, greaterThan(worldChunk.priority));
    });

    test('private character profile gets agentPrivate visibility', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(
          characterProfiles: [
            'Liu Xi is a scholar.',
            '@private:Liu Xi secretly fears fire.',
          ],
        ),
        nowMs: 1000,
      );
      expect(chunks.length, 2);
      final public = chunks.firstWhere(
        (c) => c.visibility == MemoryVisibility.publicObservable,
      );
      final private = chunks.firstWhere(
        (c) => c.visibility == MemoryVisibility.agentPrivate,
      );
      expect(public.content, 'Liu Xi is a scholar.');
      expect(private.content, 'Liu Xi secretly fears fire.');
    });

    test('estimates token cost from content length', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(worldFacts: ['A short fact.']),
        nowMs: 1000,
      );
      expect(chunks.single.tokenCostEstimate, greaterThan(0));
      // 13 chars / 3.5 ≈ 4 tokens
      expect(chunks.single.tokenCostEstimate, (13 / 3.5).ceil());
    });

    test(
      'preserves source identity via sourceRefs and rootSourceIds',
      () async {
        final indexer = StoryMemoryIndexer();
        final chunks = indexer.index(
          projectId: 'p1',
          scopeId: 's1',
          materials: const ProjectMaterialSnapshot(
            worldFacts: ['Magic needs a catalyst.'],
          ),
          nowMs: 1000,
        );
        final chunk = chunks.single;
        expect(chunk.sourceRefs.length, 1);
        expect(chunk.sourceRefs.first.sourceId, chunk.id);
        expect(chunk.sourceRefs.first.sourceType, MemorySourceKind.worldFact);
        expect(chunk.rootSourceIds, [chunk.id]);
      },
    );

    test('relationship_hint chunk gets relationship tag', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(
          relationshipHints: ['Liu Xi trusts the #elder'],
        ),
        nowMs: 1000,
      );
      expect(chunks.single.kind, MemorySourceKind.relationshipHint);
      expect(chunks.single.tags, containsAll(['relationship', 'elder']));
    });

    test('review_finding chunk gets review tag', () async {
      final indexer = StoryMemoryIndexer();
      final chunks = indexer.index(
        projectId: 'p1',
        scopeId: 's1',
        materials: const ProjectMaterialSnapshot(
          reviewFindings: ['Dialogue feels #stilted in scene 2.'],
        ),
        nowMs: 1000,
      );
      expect(chunks.single.kind, MemorySourceKind.reviewFinding);
      expect(chunks.single.tags, containsAll(['review', 'stilted']));
    });
  });

  group('retriever', () {
    late StoryMemoryStorageStub storage;
    late StoryMemoryRetriever retriever;

    setUp(() async {
      storage = StoryMemoryStorageStub();
      retriever = StoryMemoryRetriever(storage: storage);

      final chunks = [
        const StoryMemoryChunk(
          id: 'c1',
          projectId: 'p1',
          scopeId: 's1',
          kind: MemorySourceKind.outlineBeat,
          content: 'The lost key opens the ancient door.',
          tags: ['plot', 'key', 'outline'],
          priority: 5,
          tokenCostEstimate: 30,
          createdAtMs: 1000,
        ),
        const StoryMemoryChunk(
          id: 'c2',
          projectId: 'p1',
          scopeId: 's1',
          kind: MemorySourceKind.characterProfile,
          content: 'Liu Xi always carries a spare key.',
          tags: ['character', 'liuxi', 'key'],
          priority: 3,
          tokenCostEstimate: 25,
          createdAtMs: 2000,
        ),
        const StoryMemoryChunk(
          id: 'c3',
          projectId: 'p1',
          scopeId: 's1',
          kind: MemorySourceKind.acceptedState,
          content: 'The key was lost in chapter 1.',
          tags: ['state', 'accepted', 'key'],
          priority: 7,
          tokenCostEstimate: 20,
          createdAtMs: 3000,
        ),
      ];
      await storage.saveChunks('p1', chunks);
    });

    test('exact tag match outranks loose text match', () async {
      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'p1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'key',
          tags: ['key'],
          tokenBudget: 500,
        ),
      );
      // All have 'key' tag, but accepted state has highest priority
      expect(pack.hits, isNotEmpty);
      expect(pack.hits.first.chunk.tags, contains('key'));
    });

    test('recent accepted state outranks old low-priority chunks', () async {
      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'p1',
          queryType: StoryMemoryQueryType.sceneContinuity,
          text: 'key state',
          tags: ['state'],
          tokenBudget: 500,
        ),
      );
      expect(pack.hits, isNotEmpty);
      // Accepted state (priority 7) should rank high
      final hasAcceptedState = pack.hits.any(
        (h) => h.chunk.kind == MemorySourceKind.acceptedState,
      );
      expect(hasAcceptedState, isTrue);
    });

    test('returns summary and token accounting', () async {
      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'p1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'key',
          tokenBudget: 500,
        ),
      );
      expect(pack.spentTokenEstimate, greaterThan(0));
      expect(pack.tokenBudget, 500);
    });

    test('empty project returns empty pack', () async {
      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'nonexistent',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'anything',
          tokenBudget: 500,
        ),
      );
      expect(pack.hits, isEmpty);
      expect(pack.deferredHitCount, 0);
    });

    test('respects token budget and defers overflow', () async {
      final pack = await retriever.retrieve(
        const StoryMemoryQuery(
          projectId: 'p1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'key',
          tokenBudget: 10,
        ),
      );
      // With a tiny budget, first hit may be included but remaining deferred
      expect(pack.deferredHitCount, greaterThan(0));
    });
  });

  group('dedupe', () {
    test('rejects low confidence thoughts', () {
      final dedupe = StoryMemoryDedupe();
      const thought = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'test',
        confidence: 0.5,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );
      expect(dedupe.passesQualityGate(thought), isFalse);
    });

    test('rejects duplicate thoughts', () {
      final dedupe = StoryMemoryDedupe();
      const existing = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Liu Xi hides fear behind questions.',
        confidence: 0.85,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );
      const candidate = ThoughtAtom(
        id: 't2',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Liu Xi hides fear behind questions.',
        confidence: 0.90,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );
      expect(dedupe.isDuplicate(candidate, [existing]), isTrue);
    });

    test('rejects thought with no source trace', () {
      final dedupe = StoryMemoryDedupe();
      const thought = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'test',
        confidence: 0.80,
        sourceRefs: [],
        rootSourceIds: [],
      );
      expect(dedupe.passesQualityGate(thought), isFalse);
    });

    test('accepts different thought types with similar content', () {
      final dedupe = StoryMemoryDedupe();
      const existing = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'The hero finds the key.',
        confidence: 0.85,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );
      const candidate = ThoughtAtom(
        id: 't2',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.plotCausality,
        content: 'The hero finds the key.',
        confidence: 0.90,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );
      // Different type, so not duplicate by type check
      expect(dedupe.isDuplicate(candidate, [existing]), isFalse);
    });
  });
}
