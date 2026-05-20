import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/agentic_rag_ranker.dart';
import 'package:novel_writer/app/rag/hybrid_retriever.dart';
import 'package:novel_writer/features/story_generation/data/context_capsule_store.dart';
import 'package:novel_writer/features/story_generation/data/knowledge_tool_registry.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_assembler.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/rag_retrieval_policy.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/pipeline_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('tools', () {
    late Database db;
    late HybridRetriever retriever;
    late List<KnowledgeTool> tools;

    setUp(() async {
      db = sqlite3.openInMemory();
      retriever = HybridRetriever.local(db: db);
      await retriever.indexChunks(const [
        StoryMemoryChunk(
          id: 'c1',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.outlineBeat,
          content: 'The hero must find the ancient key to open the gate.',
          tags: ['plot', 'key', 'outline'],
          priority: 5,
          tokenCostEstimate: 30,
          createdAtMs: 1000,
          rootSourceIds: ['c1'],
        ),
        StoryMemoryChunk(
          id: 'c2',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.characterProfile,
          content: 'Liu Xi is cautious and analytical.',
          tags: ['character', 'liuxi'],
          priority: 3,
          tokenCostEstimate: 20,
          createdAtMs: 2000,
          rootSourceIds: ['c2'],
        ),
        StoryMemoryChunk(
          id: 'c3',
          projectId: 'p1',
          scopeId: 'ch1:sc2',
          kind: MemorySourceKind.acceptedState,
          content: 'The ancient key was lost in the fire.',
          tags: ['state', 'key', 'fire'],
          priority: 7,
          tokenCostEstimate: 25,
          createdAtMs: 3000,
          rootSourceIds: ['c3'],
        ),
        StoryMemoryChunk(
          id: 'c4',
          projectId: 'p1',
          scopeId: 'ch1:sc3',
          kind: MemorySourceKind.outlineBeat,
          content: 'A shadowy figure will betray the hero in chapter 3.',
          tags: ['foreshadow', 'betrayal', 'outline'],
          priority: 4,
          tokenCostEstimate: 22,
          createdAtMs: 4000,
          rootSourceIds: ['c4'],
        ),
        StoryMemoryChunk(
          id: 'c5',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.reviewFinding,
          content: 'Liu Xi hides fear behind analysis.',
          tags: ['thought', 'persona', 'liuxi'],
          priority: 4,
          tokenCostEstimate: 15,
          createdAtMs: 5000,
          rootSourceIds: ['c5'],
        ),
        StoryMemoryChunk(
          id: 'noise',
          projectId: 'p1',
          scopeId: 'ch1:sc1',
          kind: MemorySourceKind.worldFact,
          content: 'The weather is sunny and mild in the capital.',
          tags: ['weather', 'capital'],
          priority: 1,
          tokenCostEstimate: 15,
          createdAtMs: 500,
          rootSourceIds: ['noise'],
        ),
      ]);
      tools = createMemoryTools(retriever);
    });

    tearDown(() => db.dispose());

    test('all five memory tools are available', () {
      final names = tools.map((tool) => tool.name).toList();
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
      final tool = tools.firstWhere((tool) => tool.name == 'get_plot_memory');
      final capsule = await tool.retrieve({
        'projectId': 'p1',
        'query': 'ancient key gate',
        'tags': ['key'],
      });

      expect(capsule.summary, contains('key'));
      expect(capsule.metadata['hitCount'], greaterThan(0));
      expect(capsule.metadata['sourceRefIds'], contains('c1'));
    });

    test('get_persona_memory returns character insights', () async {
      final tool = tools.firstWhere(
        (tool) => tool.name == 'get_persona_memory',
      );
      final capsule = await tool.retrieve({
        'projectId': 'p1',
        'query': 'Liu Xi cautious analysis',
        'tags': ['liuxi'],
      });

      expect(capsule.summary, contains('Liu Xi'));
      expect(capsule.metadata['hitCount'], greaterThan(0));
    });

    test('get_state_ledger returns accepted states', () async {
      final tool = tools.firstWhere((tool) => tool.name == 'get_state_ledger');
      final capsule = await tool.retrieve({
        'projectId': 'p1',
        'query': 'key lost fire',
        'tags': ['state'],
      });

      expect(capsule.summary, contains('key'));
      expect(capsule.metadata['salientFacts'].toString(), contains('fire'));
    });

    test('registry integration routes tools correctly', () async {
      final registry = KnowledgeToolRegistry.roleplayDefaults(
        memoryRetriever: retriever,
        enableWritingReference: false,
      );

      expect(registry.hasTool('get_plot_memory'), isTrue);
      final capsule = await registry.call('get_plot_memory', {
        'projectId': 'p1',
        'query': 'ancient key',
      });
      expect(capsule.summary, contains('key'));
    });

    test('registry tool list summary includes all memory tools', () {
      final registry = KnowledgeToolRegistry.roleplayDefaults(
        memoryRetriever: retriever,
        enableWritingReference: false,
      );

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
          sceneId: 'sc1',
          sceneTitle: 'Gate',
          sceneSummary: 'Hero opens the gate.',
          cast: [
            SceneCastCandidate(
              characterId: 'liuxi',
              name: 'Liu Xi',
              role: 'investigator',
            ),
          ],
          worldNodeIds: const ['world-rule-1'],
        ),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['Magic needs a catalyst.'],
          characterProfiles: ['Liu Xi is a scholar.'],
          acceptedStates: ['The key was lost.'],
        ),
      );

      expect(assembly.memoryChunks, isNotEmpty);
      expect(
        assembly.retrievalRequirements,
        containsAll(['character_profiles', 'world_rules', 'state_ledger']),
      );
    });
  });

  group('review', () {
    test('ranker scores retrieval-pack hits as generic rank inputs', () {
      const pack = StoryRetrievalPack(
        query: StoryMemoryQuery(
          projectId: 'p1',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'key lost',
          tags: ['key'],
        ),
        hits: [
          StoryMemoryHit(
            chunk: StoryMemoryChunk(
              id: 'c1',
              projectId: 'p1',
              scopeId: 's1',
              kind: MemorySourceKind.acceptedState,
              content: 'The key was lost in chapter 1.',
              tags: ['state', 'key'],
              sourceRefs: [
                MemorySourceRef(
                  sourceId: 'c1',
                  sourceType: MemorySourceKind.acceptedState,
                ),
              ],
            ),
            score: 0.7,
          ),
        ],
      );

      final inputs = [
        for (final hit in pack.hits)
          AgenticRagRankInput(
            id: hit.chunk.id,
            content: hit.chunk.content,
            tags: hit.chunk.tags,
            semanticScore: hit.score,
          ),
      ];
      const ranker = AgenticRagRanker();
      final ranked = ranker.rank(
        inputs,
        pack.query.text,
        pack.query.tags,
        const RagRetrievalPolicy(roleId: 'review'),
      );

      expect(ranked, isNotEmpty);
      expect(ranked.first.input.id, 'c1');
      expect(pack.hits.first.chunk.sourceRefs, isNotEmpty);
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
    test(
      'hybrid retrieval preserves source trace for thought-like chunks',
      () async {
        final db = sqlite3.openInMemory();
        addTearDown(db.dispose);
        final retriever = HybridRetriever.local(db: db);
        await retriever.indexChunks(const [
          StoryMemoryChunk(
            id: 'thought-causality',
            projectId: 'p1',
            scopeId: 'ch1:sc1',
            kind: MemorySourceKind.reviewFinding,
            content: 'The fire destroyed the key, forcing an alternative path.',
            tags: ['causality', 'key', 'fire'],
            sourceRefs: [
              MemorySourceRef(
                sourceId: 'c1',
                sourceType: MemorySourceKind.acceptedState,
              ),
            ],
            rootSourceIds: ['c1'],
          ),
        ]);

        final pack = await retriever.retrieve(
          const StoryMemoryQuery(
            projectId: 'p1',
            queryType: StoryMemoryQueryType.causality,
            text: 'fire key path',
            tags: ['key', 'fire'],
          ),
        );

        expect(pack.hits, isNotEmpty);
        expect(pack.hits.first.chunk.sourceRefs, isNotEmpty);
        expect(pack.hits.first.chunk.rootSourceIds, contains('c1'));
      },
    );
  });

  group('CJK keyword overlap', () {
    const ranker = AgenticRagRanker();
    const policy = RagRetrievalPolicy(
      roleId: 'test',
      rankingStrategy: RankingStrategy.keyword,
    );

    double score(AgenticRagRankInput input, String query) =>
        ranker.score(input, query, const [], policy);

    test('CJK bigram tokens score Chinese content above zero', () {
      const input = AgenticRagRankInput(
        id: 'cjk-1',
        content: '黑塔是古老的建筑，隐藏在深山之中。黑塔蕴含神秘力量。',
      );

      expect(score(input, '黑塔神秘'), greaterThan(0));
    });

    test('CJK query matches semantically overlapping content', () {
      const input = AgenticRagRankInput(
        id: 'cjk-2',
        content: '刘锡是一位谨慎而富有分析力的学者。',
      );

      expect(score(input, '谨慎的学者'), greaterThan(0));
    });

    test('CJK atoms rank through full query pipeline', () {
      const inputs = [
        AgenticRagRankInput(id: 'cjk-world', content: '黑塔蕴含神秘力量，是世界的中心。'),
        AgenticRagRankInput(id: 'cjk-char', content: '刘锡经常在黑塔附近散步，观察古老的符文。'),
        AgenticRagRankInput(id: 'cjk-noise', content: '今天天气晴朗，适合外出旅行。'),
      ];

      final ranked = ranker.rank(inputs, '黑塔古老符文', const [], policy);
      expect(ranked, isNotEmpty);
      expect(ranked.first.input.id, isNot(equals('cjk-noise')));
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
      expect(json['sourceRefIds'], ['s1', 's2', 's3']);
    });
  });
}
