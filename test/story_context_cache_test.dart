import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/story_context_cache.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

void main() {
  group('StoryContextCache', () {
    late StoryContextCache cache;

    setUp(() {
      cache = StoryContextCache();
    });

    SceneBrief makeBrief({String sceneId = 'sc1'}) => SceneBrief(
          chapterId: 'ch1',
          chapterTitle: '第一章',
          sceneId: sceneId,
          sceneTitle: '开篇',
          sceneSummary: '故事开始',
        );

    SceneContextAssembly makeAssembly({
      String sceneId = 'sc1',
      List<String> worldFacts = const ['gravity works'],
    }) {
      return SceneContextAssembly(
        brief: makeBrief(sceneId: sceneId),
        materialSnapshot: ProjectMaterialSnapshot(worldFacts: worldFacts),
        retrievalRequirements: ['world_rules'],
        memoryChunks: [
          StoryMemoryChunk(
            id: 'ch1_wf_0',
            projectId: 'ch1',
            scopeId: 'ch1:$sceneId',
            kind: MemorySourceKind.worldFact,
            content: worldFacts.first,
            sourceRefs: [
              MemorySourceRef(
                sourceId: 'ch1_wf_0',
                sourceType: MemorySourceKind.worldFact,
              ),
            ],
            rootSourceIds: ['ch1_wf_0'],
          ),
        ],
      );
    }

    test('returns null on empty cache', () {
      expect(
        cache.lookup('ch1', 'ch1:sc1', const ProjectMaterialSnapshot()),
        isNull,
      );
      expect(cache.hits, 0);
      expect(cache.misses, 1);
    });

    test('stores and retrieves an assembly', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly = makeAssembly();

      cache.store('ch1', 'ch1:sc1', assembly, materials);

      final result = cache.lookup('ch1', 'ch1:sc1', materials);
      expect(result, isNotNull);
      expect(result!.brief.sceneId, 'sc1');
      expect(result.memoryChunks.length, 1);
      expect(cache.hits, 1);
      expect(cache.misses, 0);
    });

    test('returns null when materials change', () {
      const materials1 = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      const materials2 = ProjectMaterialSnapshot(
        worldFacts: ['gravity works', 'magic exists'],
      );
      final assembly = makeAssembly();

      cache.store('ch1', 'ch1:sc1', assembly, materials1);

      expect(cache.lookup('ch1', 'ch1:sc1', materials2), isNull);
      expect(cache.misses, 1);
    });

    test('returns null after TTL expiry', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly = makeAssembly();
      final shortTtlCache = StoryContextCache(defaultTtlMs: 100);

      shortTtlCache.store(
        'ch1',
        'ch1:sc1',
        assembly,
        materials,
        nowMs: 1000,
      );

      // Before expiry
      expect(
        shortTtlCache.lookup('ch1', 'ch1:sc1', materials, nowMs: 1050),
        isNotNull,
      );

      // After expiry
      expect(
        shortTtlCache.lookup('ch1', 'ch1:sc1', materials, nowMs: 1101),
        isNull,
      );
    });

    test('caches multiple scopes within same project', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly1 = makeAssembly(sceneId: 'sc1');
      final assembly2 = makeAssembly(sceneId: 'sc2');

      cache.store('ch1', 'ch1:sc1', assembly1, materials);
      cache.store('ch1', 'ch1:sc2', assembly2, materials);

      expect(cache.lookup('ch1', 'ch1:sc1', materials), isNotNull);
      expect(cache.lookup('ch1', 'ch1:sc2', materials), isNotNull);
      expect(cache.size, 2);
      expect(cache.projectCount, 1);
    });

    test('caches across different projects', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly = makeAssembly();

      cache.store('ch1', 'ch1:sc1', assembly, materials);
      cache.store('ch2', 'ch2:sc1', assembly, materials);

      expect(cache.lookup('ch1', 'ch1:sc1', materials), isNotNull);
      expect(cache.lookup('ch2', 'ch2:sc1', materials), isNotNull);
      expect(cache.projectCount, 2);
    });

    test('invalidateProject removes only entries for that project', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly = makeAssembly();

      cache.store('ch1', 'ch1:sc1', assembly, materials);
      cache.store('ch2', 'ch2:sc1', assembly, materials);

      cache.invalidateProject('ch1');

      expect(cache.lookup('ch1', 'ch1:sc1', materials), isNull);
      expect(cache.lookup('ch2', 'ch2:sc1', materials), isNotNull);
      expect(cache.size, 1);
    });

    test('clearAll removes everything and resets counters', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly = makeAssembly();

      cache.store('ch1', 'ch1:sc1', assembly, materials);
      cache.lookup('ch1', 'ch1:sc1', materials);

      cache.clearAll();

      expect(cache.size, 0);
      expect(cache.projectCount, 0);
      expect(cache.hits, 0);
      expect(cache.misses, 0);
    });

    test('overwrites entry when same scope is stored twice', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['old']);
      final assembly1 = makeAssembly(worldFacts: ['old']);
      final assembly2 = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: const ProjectMaterialSnapshot(worldFacts: ['old']),
        retrievalRequirements: ['world_rules', 'character_profiles'],
      );

      cache.store('ch1', 'ch1:sc1', assembly1, materials);
      cache.store('ch1', 'ch1:sc1', assembly2, materials);

      final result = cache.lookup('ch1', 'ch1:sc1', materials);
      expect(result, isNotNull);
      expect(
        result!.retrievalRequirements,
        ['world_rules', 'character_profiles'],
      );
      expect(cache.size, 1);
    });

    test('fingerprint detects changes in any material category', () {
      final base = const ProjectMaterialSnapshot(worldFacts: ['a']);
      final variants = [
        const ProjectMaterialSnapshot(worldFacts: ['b']),
        const ProjectMaterialSnapshot(characterProfiles: ['c']),
        const ProjectMaterialSnapshot(relationshipHints: ['d']),
        const ProjectMaterialSnapshot(outlineBeats: ['e']),
        const ProjectMaterialSnapshot(sceneSummaries: ['f']),
        const ProjectMaterialSnapshot(acceptedStates: ['g']),
        const ProjectMaterialSnapshot(reviewFindings: ['h']),
      ];

      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: base,
      );
      cache.store('ch1', 'ch1:sc1', assembly, base);

      for (final variant in variants) {
        expect(
          cache.lookup('ch1', 'ch1:sc1', variant),
          isNull,
          reason: 'Materials change in ${variant.runtimeType} should invalidate',
        );
      }
      expect(cache.misses, variants.length);
    });

    test('same materials with different order produce same fingerprint', () {
      const materialsA = ProjectMaterialSnapshot(
        worldFacts: ['alpha', 'beta'],
      );
      const materialsB = ProjectMaterialSnapshot(
        worldFacts: ['beta', 'alpha'],
      );

      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: materialsA,
      );
      cache.store('ch1', 'ch1:sc1', assembly, materialsA);

      // Reversed order should still hit (unordered hash)
      expect(cache.lookup('ch1', 'ch1:sc1', materialsB), isNotNull);
      expect(cache.hits, 1);
    });

    test('empty materials match each other', () {
      const empty1 = ProjectMaterialSnapshot();
      const empty2 = ProjectMaterialSnapshot();

      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: empty1,
      );
      cache.store('ch1', 'ch1:sc1', assembly, empty1);

      expect(cache.lookup('ch1', 'ch1:sc1', empty2), isNotNull);
      expect(cache.hits, 1);
    });

    test('tracks hit and miss counters correctly', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['x']);
      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: materials,
      );

      // 2 misses on empty cache
      cache.lookup('ch1', 'ch1:sc1', materials);
      cache.lookup('ch2', 'ch2:sc1', materials);
      expect(cache.misses, 2);

      // Store one, hit it
      cache.store('ch1', 'ch1:sc1', assembly, materials);
      cache.lookup('ch1', 'ch1:sc1', materials);
      expect(cache.hits, 1);

      // Miss on changed materials
      const changed = ProjectMaterialSnapshot(worldFacts: ['y']);
      cache.lookup('ch1', 'ch1:sc1', changed);
      expect(cache.misses, 3);
    });

    test('invalidated entry is re-storable', () {
      const materials = ProjectMaterialSnapshot(worldFacts: ['x']);
      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: materials,
      );

      cache.store('ch1', 'ch1:sc1', assembly, materials);
      cache.invalidateProject('ch1');
      expect(cache.lookup('ch1', 'ch1:sc1', materials), isNull);

      cache.store('ch1', 'ch1:sc1', assembly, materials);
      expect(cache.lookup('ch1', 'ch1:sc1', materials), isNotNull);
    });
  });
}
