import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/pipeline_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_stub.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_retriever.dart';
import 'package:novel_writer/features/story_generation/data/knowledge_tool_registry.dart';
import 'package:novel_writer/features/story_generation/data/agentic_rag.dart';
import 'package:novel_writer/features/story_generation/data/context_capsule_store.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_assembler.dart';

void main() {
  group('tools', () {
    late StoryMemoryStorageStub storage;
    late StoryMemoryRetriever retriever;
    late List<KnowledgeTool> tools;

    setUp(() async {
      storage = StoryMemoryStorageStub();
      retriever = StoryMemoryRetriever(storage: storage);

      await storage.saveChunks('p1', [
        const StoryMemoryChunk(
          id: 'c1',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.outlineBeat,
          content: 'The hero must find the ancient key to open the gate.',
          tags: ['plot', 'key', 'outline'],
          priority: 5,
          tokenCostEstimate: 30,
          createdAtMs: 1000,
        ),
        const StoryMemoryChunk(
          id: 'c2',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.characterProfile,
          content: 'Liu Xi is cautious and analytical.',
          tags: ['character', 'liuxi'],
          priority: 3,
          tokenCostEstimate: 20,
          createdAtMs: 2000,
        ),
        const StoryMemoryChunk(
          id: 'c3',
          projectId: 'p1',
          scopeId: 'ch1:sc2',
          kind: MemorySourceKind.acceptedState,
          content: 'The ancient key was lost in the fire.',
          tags: ['state', 'key', 'fire'],
          priority: 7,
          tokenCostEstimate: 25,
          createdAtMs: 3000,
        ),
        const StoryMemoryChunk(
          id: 'c4',
          projectId: 'p1',
          scopeId: 'ch1:sc3',
          kind: MemorySourceKind.outlineBeat,
          content: 'A shadowy figure will betray the hero in chapter 3.',
          tags: ['foreshadow', 'betrayal', 'outline'],
          priority: 4,
          tokenCostEstimate: 22,
          createdAtMs: 4000,
        ),
        // Noise chunk – low priority, unrelated to plot/character queries
        const StoryMemoryChunk(
          id: 'c5',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.worldFact,
          content: 'The weather is sunny and mild in the capital.',
          tags: ['weather', 'capital'],
          priority: 1,
          tokenCostEstimate: 15,
          createdAtMs: 500,
        ),
      ]);

      await storage.saveThoughts('p1', [
        const ThoughtAtom(
          id: 't1',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          thoughtType: ThoughtType.persona,
          content: 'Liu Xi hides fear behind analysis.',
          confidence: 0.88,
          abstractionLevel: 2.0,
          tags: ['persona', 'liuxi'],
          priority: 4,
          tokenCostEstimate: 15,
          createdAtMs: 5000,
        ),
        const ThoughtAtom(
          id: 't2',
          projectId: 'p1',
          scopeId: 'ch1:sc3',
          thoughtType: ThoughtType.foreshadowing,
          content: 'The betrayal motif connects to the shadow figure.',
          confidence: 0.82,
          abstractionLevel: 2.5,
          tags: ['foreshadow', 'betrayal'],
          priority: 5,
          tokenCostEstimate: 18,
          createdAtMs: 6000,
        ),
        const ThoughtAtom(
          id: 't3',
          projectId: 'p1',
          scopeId: 'ch1:sc2',
          thoughtType: ThoughtType.plotCausality,
          content: 'The fire destroyed the key, forcing an alternative path.',
          confidence: 0.91,
          abstractionLevel: 2.0,
          tags: ['causality', 'key', 'fire'],
          priority: 6,
          tokenCostEstimate: 20,
          createdAtMs: 7000,
        ),
      ]);

      tools = createMemoryTools(retriever);
    });

    test('all five memory tools are available', () {
      final names = tools.map((t) => t.name).toList();
      expect(
        names,
        containsAll([
          'get_plot_memory',
          'get_persona_memory',
          'get_foreshadowing_memory',
          'get_state_ledger',
          'get_thought_memory',
        ]),
      );
    });

    test('get_plot_memory returns compact capsule with source refs', () async {
      final plotTool = tools.firstWhere((t) => t.name == 'get_plot_memory');
      final capsule = await plotTool.retrieve({
        'projectId': 'p1',
        'query': 'key gate fire',
      });

      expect(capsule.sourceTool, contains('causality'));
      expect(capsule.isWithinBudget, isTrue);
      expect(capsule.metadata['sourceRefIds'], isNotNull);
      expect(capsule.metadata['hitCount'], greaterThan(0));
    });

    test('get_persona_memory returns character insights', () async {
      final personaTool =
          tools.firstWhere((t) => t.name == 'get_persona_memory');
      final capsule = await personaTool.retrieve({
        'projectId': 'p1',
        'query': 'Liu Xi character',
        'tags': ['liuxi'],
      });

      expect(capsule.sourceTool, contains('persona'));
      expect(capsule.isWithinBudget, isTrue);
      expect(capsule.summary, contains('Liu Xi'));
    });

    test('get_foreshadowing_memory returns foreshadowing hints', () async {
      final foreshadowTool =
          tools.firstWhere((t) => t.name == 'get_foreshadowing_memory');
      final capsule = await foreshadowTool.retrieve({
        'projectId': 'p1',
        'query': 'betrayal shadow figure',
        'tags': ['foreshadow'],
      });

      expect(capsule.sourceTool, contains('foreshadowing'));
      expect(capsule.isWithinBudget, isTrue);
      expect(capsule.metadata['hitCount'], greaterThan(0));
      final facts = capsule.metadata['salientFacts'] as List?;
      expect(facts, isNotNull);
      expect(
        facts!.any((f) {
          final s = f.toString().toLowerCase();
          return s.contains('betray') || s.contains('shadow');
        }),
        isTrue,
      );
    });

    test('get_state_ledger returns accepted states', () async {
      final stateTool =
          tools.firstWhere((t) => t.name == 'get_state_ledger');
      final capsule = await stateTool.retrieve({
        'projectId': 'p1',
        'query': 'key lost fire',
        'tags': ['state', 'key'],
      });

      expect(capsule.sourceTool, contains('concreteFact'));
      expect(capsule.isWithinBudget, isTrue);
      expect(capsule.metadata['hitCount'], greaterThan(0));
      final facts = capsule.metadata['salientFacts'] as List?;
      expect(facts, isNotNull);
      expect(
        facts!.any((f) => f.toString().toLowerCase().contains('key')),
        isTrue,
      );
    });

    test('get_thought_memory returns thought atoms', () async {
      final thoughtTool =
          tools.firstWhere((t) => t.name == 'get_thought_memory');
      final capsule = await thoughtTool.retrieve({
        'projectId': 'p1',
        'query': 'Liu Xi persona fear',
      });

      expect(capsule.sourceTool, contains('sceneContinuity'));
      expect(capsule.isWithinBudget, isTrue);
      expect(capsule.metadata['isThought'], isTrue);
    });

    test('capsule summary is compact and salient facts are bounded', () async {
      final plotTool = tools.firstWhere((t) => t.name == 'get_plot_memory');
      final capsule = await plotTool.retrieve({
        'projectId': 'p1',
        'query': 'key gate',
      });

      expect(capsule.summary.length, lessThanOrEqualTo(capsule.charBudget));
      expect(capsule.metadata['salientFacts'], isA<List>());
      final facts = capsule.metadata['salientFacts'] as List;
      for (final fact in facts) {
        expect(fact.toString().length, lessThanOrEqualTo(103));
      }
    });

    test('tools do not inject unrelated chunks', () async {
      final stateTool =
          tools.firstWhere((t) => t.name == 'get_state_ledger');
      final capsule = await stateTool.retrieve({
        'projectId': 'p1',
        'query': 'key lost',
        'tags': ['state', 'key'],
      });

      final facts = capsule.metadata['salientFacts'] as List? ?? [];
      for (final fact in facts) {
        expect(
          fact.toString().toLowerCase(),
          isNot(contains('weather')),
        );
      }
    });

    test('viewer visibility is enforced through tools', () async {
      final privStorage = StoryMemoryStorageStub();
      await privStorage.saveChunks('p1', [
        const StoryMemoryChunk(
          id: 'pub1',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.characterProfile,
          content: 'Liu Xi is a skilled strategist.',
          tags: ['character', 'liuxi'],
          priority: 3,
          tokenCostEstimate: 20,
          createdAtMs: 1000,
        ),
        const StoryMemoryChunk(
          id: 'priv1',
          projectId: 'p1',
          scopeId: 'agent-1',
          kind: MemorySourceKind.characterProfile,
          content: 'Secret: Liu Xi fears water.',
          visibility: MemoryVisibility.agentPrivate,
          tags: ['secret'],
          priority: 5,
          tokenCostEstimate: 15,
          createdAtMs: 2000,
        ),
      ]);

      final privRetriever = StoryMemoryRetriever(storage: privStorage);
      final privTools = createMemoryTools(privRetriever);
      final personaTool =
          privTools.firstWhere((t) => t.name == 'get_persona_memory');

      final capsule = await personaTool.retrieve({
        'projectId': 'p1',
        'query': 'Liu Xi secret fear',
        'viewerId': 'agent-2',
      });

      final facts = capsule.metadata['salientFacts'] as List? ?? [];
      expect(facts.isNotEmpty, isTrue);
      expect(
        facts.every((f) => !f.toString().contains('Secret')),
        isTrue,
      );
    });

    test('registry integration routes tools correctly', () async {
      final registry = KnowledgeToolRegistry(tools: tools);

      expect(
        registry.availableTools,
        containsAll([
          'get_plot_memory',
          'get_persona_memory',
          'get_foreshadowing_memory',
          'get_state_ledger',
          'get_thought_memory',
        ]),
      );

      final capsule = await registry.call('get_state_ledger', {
        'projectId': 'p1',
        'query': 'key lost',
        'tags': ['state'],
      });

      expect(capsule, isNotNull);
      expect(capsule.sourceTool, contains('concreteFact'));
    });

    test('registry tool list summary includes all memory tools', () {
      final registry = KnowledgeToolRegistry(tools: tools);
      final summary = registry.toolListSummary();
      expect(summary, contains('get_plot_memory'));
      expect(summary, contains('get_persona_memory'));
      expect(summary, contains('get_foreshadowing_memory'));
      expect(summary, contains('get_state_ledger'));
      expect(summary, contains('get_thought_memory'));
    });
  });

  group('pre-scene', () {
    test('assembler indexes materials and computes requirements', () {
      final assembler = SceneContextAssembler();
      final assembly = assembler.assemble(
        brief: SceneBrief(
          chapterId: 'ch1',
          chapterTitle: 'Chapter 1',
          sceneId: 'sc2',
          sceneTitle: 'The Gate',
          sceneSummary: 'Liu Xi tries to open the ancient gate.',
          cast: [
            SceneCastCandidate(
              characterId: 'liuxi',
              name: 'Liu Xi',
              role: 'protagonist',
            ),
          ],
          worldNodeIds: ['world-gate'],
        ),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['The ancient gate requires a key.'],
          acceptedStates: ['The key was lost in ch1.'],
        ),
      );

      expect(assembly.memoryChunks, isNotEmpty);
      expect(
        assembly.retrievalRequirements,
        containsAll([
          'character_profiles',
          'world_rules',
          'state_ledger',
        ]),
      );
    });
  });

  group('review', () {
    test('agentic RAG converts retrieval pack to atoms', () async {
      final storage = StoryMemoryStorageStub();
      final retriever = StoryMemoryRetriever(storage: storage);
      await storage.saveChunks('p1', [
        const StoryMemoryChunk(
          id: 'c1',
          projectId: 'p1',
          scopeId: 's1',
          kind: MemorySourceKind.acceptedState,
          content: 'The key was lost in chapter 1.',
          tags: ['state', 'key'],
          priority: 7,
          tokenCostEstimate: 20,
          createdAtMs: 1000,
          sourceRefs: [
            MemorySourceRef(
              sourceId: 'c1',
              sourceType: MemorySourceKind.acceptedState,
            ),
          ],
        ),
      ]);

      final pack = await retriever.retrieve(const StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'key lost',
        tags: ['key'],
      ));

      final rag = AgenticRag();
      final atoms = rag.fromRetrievalPack(pack);
      expect(atoms, isNotEmpty);
      expect(atoms.first.sourceRefs, isNotEmpty);
    });

    test('capsule store preserves source refs', () {
      final store = ContextCapsuleStore();
      final capsule = ContextCapsule(
        id: 'cap-1',
        sourceTool: 'memory_concreteFact',
        summary: 'test content',
        charBudget: 200,
        createdAtMs: 1000,
        metadata: {'hitCount': 3},
      );

      final sourceRefs = [
        const MemorySourceRef(
          sourceId: 's1',
          sourceType: MemorySourceKind.sceneSummary,
        ),
        const MemorySourceRef(
          sourceId: 's2',
          sourceType: MemorySourceKind.acceptedState,
        ),
      ];

      store.insert(
        capsule,
        'scope-1',
        nowMs: 1000,
        sourceRefs: sourceRefs,
        thoughtPriority: 5,
      );

      final entries = store.queryEntries('scope-1', null, nowMs: 2000);
      expect(entries.length, 1);
      expect(entries.first.sourceRefs.length, 2);
      expect(entries.first.thoughtPriority, 5);
    });
  });

  group('thought retrieval', () {
    late StoryMemoryStorageStub storage;
    late StoryMemoryRetriever retriever;

    setUp(() async {
      storage = StoryMemoryStorageStub();
      retriever = StoryMemoryRetriever(storage: storage);

      await storage.saveChunks('p1', [
        const StoryMemoryChunk(
          id: 'c1',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.acceptedState,
          content: 'The ancient key was lost in the fire.',
          tags: ['state', 'key', 'fire'],
          priority: 5,
          tokenCostEstimate: 20,
          createdAtMs: 1000,
        ),
        const StoryMemoryChunk(
          id: 'c2',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.characterProfile,
          content: 'Liu Xi is cautious and analytical.',
          tags: ['character', 'liuxi'],
          priority: 3,
          tokenCostEstimate: 15,
          createdAtMs: 2000,
        ),
      ]);

      await storage.saveThoughts('p1', [
        const ThoughtAtom(
          id: 't1',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          thoughtType: ThoughtType.plotCausality,
          content: 'The fire destroyed the key, forcing an alternative path.',
          confidence: 0.91,
          abstractionLevel: 2.0,
          tags: ['causality', 'key', 'fire'],
          priority: 6,
          tokenCostEstimate: 18,
          createdAtMs: 3000,
          sourceRefs: [
            MemorySourceRef(
              sourceId: 'c1',
              sourceType: MemorySourceKind.acceptedState,
            ),
          ],
          rootSourceIds: ['c1'],
        ),
        const ThoughtAtom(
          id: 't2',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          thoughtType: ThoughtType.persona,
          content: 'Liu Xi hides fear behind analysis.',
          confidence: 0.88,
          abstractionLevel: 2.0,
          tags: ['persona', 'liuxi'],
          priority: 4,
          tokenCostEstimate: 15,
          createdAtMs: 4000,
          sourceRefs: [
            MemorySourceRef(
              sourceId: 'c2',
              sourceType: MemorySourceKind.characterProfile,
            ),
          ],
          rootSourceIds: ['c2'],
        ),
      ]);
    });

    test('abstract question retrieves thought atoms before raw chunks', () async {
      final pack = await retriever.retrieve(const StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.causality,
        text: 'fire key path',
        tags: ['key', 'fire'],
      ));

      expect(pack.hits, isNotEmpty);
      expect(pack.hits.first.isThought, isTrue);
      expect(
        pack.hits.first.thoughtAtom?.thoughtType,
        ThoughtType.plotCausality,
      );
    });

    test('concrete fact query retrieves raw chunks before thought atoms', () async {
      final pack = await retriever.retrieve(const StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.concreteFact,
        text: 'key lost fire',
        tags: ['key', 'fire'],
      ));

      expect(pack.hits, isNotEmpty);
      expect(pack.hits.first.isThought, isFalse);
      expect(
        pack.hits.first.chunk.kind,
        MemorySourceKind.acceptedState,
      );
    });

    test('thought source trace maps back to raw scene evidence', () async {
      final pack = await retriever.retrieve(const StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.causality,
        text: 'fire key',
        tags: ['key', 'fire'],
      ));

      final thoughtHits = pack.hits.where((h) => h.isThought).toList();
      expect(thoughtHits, isNotEmpty);

      final thought = thoughtHits.first;
      expect(thought.thoughtAtom?.sourceRefs, isNotEmpty);
      expect(
        thought.thoughtAtom!.sourceRefs.any((ref) => ref.sourceId == 'c1'),
        isTrue,
      );
      expect(
        thought.thoughtAtom!.rootSourceIds,
        contains('c1'),
      );
    });
  });

  group('audit', () {
    test('retrieval trace records counts correctly', () {
      const query = StoryMemoryQuery(
        projectId: 'p1',
        queryType: StoryMemoryQueryType.sceneContinuity,
        text: 'test',
      );
      const trace = RetrievalTrace(
        query: query,
        selectedHitCount: 8,
        deferredHitCount: 3,
        thoughtCreationCount: 2,
        rejectedThoughtCount: 1,
        indexedChunkCount: 25,
        sourceRefIds: ['s1', 's2', 's3'],
      );

      final json = trace.toJson();
      expect(json['selectedHitCount'], 8);
      expect(json['deferredHitCount'], 3);
      expect(json['thoughtCreationCount'], 2);
      expect(json['rejectedThoughtCount'], 1);
      expect(json['indexedChunkCount'], 25);
      expect(json['sourceRefIds'], isNotEmpty);
    });
  });
}
