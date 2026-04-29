import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

void main() {
  group('MemorySourceRef', () {
    test('preserves sourceId and sourceType through JSON round trip', () {
      const ref = MemorySourceRef(
        sourceId: 'scene-1',
        sourceType: MemorySourceKind.sceneSummary,
      );
      final restored = MemorySourceRef.fromJson(ref.toJson());
      expect(restored.sourceId, 'scene-1');
      expect(restored.sourceType, MemorySourceKind.sceneSummary);
    });

    test('equality works', () {
      const a = MemorySourceRef(
        sourceId: 'x',
        sourceType: MemorySourceKind.worldFact,
      );
      const b = MemorySourceRef(
        sourceId: 'x',
        sourceType: MemorySourceKind.worldFact,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('StoryMemorySource', () {
    test('preserves all fields through JSON round trip', () {
      const source = StoryMemorySource(
        id: 'src-1',
        projectId: 'project-a',
        scopeId: 'scene-1',
        kind: MemorySourceKind.worldFact,
        content: 'Magic requires a catalyst stone.',
        sourceRefs: [
          MemorySourceRef(sourceId: 'world-1', sourceType: MemorySourceKind.worldFact),
        ],
        rootSourceIds: ['world-1'],
        visibility: MemoryVisibility.publicObservable,
        tags: ['world', 'magic'],
        priority: 3,
        tokenCostEstimate: 12,
        createdAtMs: 1777046400000,
      );
      final restored = StoryMemorySource.fromJson(source.toJson());
      expect(restored.id, 'src-1');
      expect(restored.projectId, 'project-a');
      expect(restored.kind, MemorySourceKind.worldFact);
      expect(restored.content, 'Magic requires a catalyst stone.');
      expect(restored.sourceRefs.single.sourceId, 'world-1');
      expect(restored.rootSourceIds, contains('world-1'));
      expect(restored.visibility, MemoryVisibility.publicObservable);
      expect(restored.tags, containsAll(['world', 'magic']));
      expect(restored.priority, 3);
      expect(restored.tokenCostEstimate, 12);
      expect(restored.createdAtMs, 1777046400000);
    });
  });

  group('StoryMemoryChunk', () {
    test('preserves kind and content through JSON round trip', () {
      const chunk = StoryMemoryChunk(
        id: 'chunk-1',
        projectId: 'project-a',
        scopeId: 'scene-1',
        kind: MemorySourceKind.characterProfile,
        content: 'Liu Xi is a scholar from the north.',
        tags: ['character', 'liuxi'],
        priority: 5,
      );
      final restored = StoryMemoryChunk.fromJson(chunk.toJson());
      expect(restored.kind, MemorySourceKind.characterProfile);
      expect(restored.content, contains('Liu Xi'));
      expect(restored.tags, contains('liuxi'));
      expect(restored.priority, 5);
    });
  });

  group('ThoughtAtom', () {
    test('thought atom preserves source trace and confidence', () {
      const atom = ThoughtAtom(
        id: 'thought-1',
        projectId: 'project-a',
        scopeId: 'scene-1',
        thoughtType: ThoughtType.persona,
        content: 'Liu Xi hides fear by asking procedural questions.',
        confidence: 0.86,
        abstractionLevel: 2.0,
        sourceRefs: [
          MemorySourceRef(sourceId: 'scene-1', sourceType: MemorySourceKind.sceneSummary),
        ],
        rootSourceIds: ['scene-1:beat-2'],
        tags: ['char-liuxi', 'persona'],
        priority: 3,
        tokenCostEstimate: 18,
        createdAtMs: 1777046400000,
      );

      final restored = ThoughtAtom.fromJson(atom.toJson());

      expect(restored.id, atom.id);
      expect(restored.thoughtType, ThoughtType.persona);
      expect(restored.sourceRefs.single.sourceId, 'scene-1');
      expect(restored.rootSourceIds, contains('scene-1:beat-2'));
      expect(restored.confidence, 0.86);
      expect(restored.abstractionLevel, 2.0);
      expect(restored.priority, 3);
    });

    test('parses missing fields with defaults', () {
      final restored = ThoughtAtom.fromJson(const {});
      expect(restored.id, '');
      expect(restored.confidence, 0.0);
      expect(restored.thoughtType, ThoughtType.persona);
      expect(restored.sourceRefs, isEmpty);
    });
  });

  group('StoryMemoryQuery', () {
    test('constructs with all fields', () {
      const query = StoryMemoryQuery(
        projectId: 'proj-1',
        queryType: StoryMemoryQueryType.causality,
        text: 'why did the key disappear',
        tags: ['plot', 'key'],
        viewerId: 'agent-1',
        maxResults: 5,
        tokenBudget: 300,
      );
      expect(query.queryType, StoryMemoryQueryType.causality);
      expect(query.tags, containsAll(['plot', 'key']));
      expect(query.maxResults, 5);
    });
  });

  group('StoryMemoryHit', () {
    test('copyWith updates score', () {
      const chunk = StoryMemoryChunk(
        id: 'c1',
        projectId: 'p1',
        scopeId: 's1',
        kind: MemorySourceKind.worldFact,
        content: 'test',
      );
      const hit = StoryMemoryHit(chunk: chunk, score: 5.0);
      final updated = hit.copyWith(score: 10.0);
      expect(updated.score, 10.0);
      expect(updated.chunk.id, 'c1');
    });
  });

  group('StoryRetrievalPack', () {
    test('holds query, hits, and deferred count', () {
      const query = StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'test',
      );
      const pack = StoryRetrievalPack(
        query: query,
        hits: [],
        summary: 'no results',
        tokenBudget: 500,
        spentTokenEstimate: 0,
        deferredHitCount: 3,
      );
      expect(pack.deferredHitCount, 3);
      expect(pack.summary, 'no results');
    });
  });

  group('RetrievalTrace', () {
    test('toJson preserves counts', () {
      const query = StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'test',
      );
      const trace = RetrievalTrace(
        query: query,
        selectedHitCount: 5,
        deferredHitCount: 2,
        thoughtCreationCount: 3,
        rejectedThoughtCount: 1,
        indexedChunkCount: 20,
        sourceRefIds: ['s1', 's2'],
      );
      final json = trace.toJson();
      expect(json['selectedHitCount'], 5);
      expect(json['thoughtCreationCount'], 3);
      expect(json['rejectedThoughtCount'], 1);
    });
  });
}
