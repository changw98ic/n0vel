import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/agentic_rag.dart';
import 'package:novel_writer/features/story_generation/data/agent_turn_controller.dart';
import 'package:novel_writer/features/story_generation/data/context_capsule_store.dart';
import 'package:novel_writer/features/story_generation/data/knowledge_tool_registry.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_assembler.dart';
import 'package:novel_writer/features/story_generation/domain/pipeline_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  // -- AgentTurnController ----------------------------------------------------

  group('AgentTurnController', () {
    test('returns text immediately when no retrieval intent', () async {
      final controller = AgentTurnController();
      final result = await controller.run(
        agentFn: (capsules) async => '立场：冷静\n动作：观察\n禁忌：冲动',
        intentExtractor: (text) => null,
        retrievalFn: (_) async => '',
      );
      expect(result.text, contains('立场'));
      expect(result.capsules, isEmpty);
      expect(result.retrievalRounds, 0);
    });

    test('loops when retrieval intent detected', () async {
      final controller = AgentTurnController(maxRetrievalRounds: 2);
      var callCount = 0;

      final result = await controller.run(
        agentFn: (capsules) async {
          callCount++;
          if (callCount == 1) {
            return 'RETRIEVE:character_profile';
          }
          return '立场：冷静\n动作：观察\n禁忌：冲动';
        },
        intentExtractor: (text) {
          if (text.contains('RETRIEVE:character_profile')) {
            return RetrievalIntent(
              characterId: 'liuxi',
              toolName: 'character_profile',
            );
          }
          return null;
        },
        retrievalFn: (_) async => '柳溪是调查记者，性格冷静理性',
      );

      expect(result.capsules.length, 1);
      expect(result.capsules.first.sourceTool, 'character_profile');
      expect(result.retrievalRounds, 1);
      expect(callCount, 2);
    });

    test('stops after max retrieval rounds', () async {
      final controller = AgentTurnController(maxRetrievalRounds: 1);
      var callCount = 0;

      final result = await controller.run(
        agentFn: (capsules) async {
          callCount++;
          return 'RETRIEVE:world_rule';
        },
        intentExtractor: (text) => RetrievalIntent(
          characterId: 'a',
          toolName: 'world_rule',
        ),
        retrievalFn: (_) async => 'world rule content',
      );

      expect(result.retrievalRounds, 1);
      expect(callCount, 2);
    });

    test('capsules accumulate across rounds', () async {
      final controller = AgentTurnController(maxRetrievalRounds: 3);
      var callCount = 0;

      final result = await controller.run(
        agentFn: (capsules) async {
          callCount++;
          if (callCount <= 2) {
            return 'RETRIEVE:scene_context';
          }
          return 'final output';
        },
        intentExtractor: (text) {
          if (text.contains('RETRIEVE:')) {
            return RetrievalIntent(
              characterId: 'a',
              toolName: 'scene_context',
            );
          }
          return null;
        },
        retrievalFn: (_) async => 'scene context data',
      );

      expect(result.capsules.length, 2);
      expect(result.retrievalRounds, 2);
    });
  });

  // -- KnowledgeToolRegistry --------------------------------------------------

  group('KnowledgeToolRegistry', () {
    test('registers and lists tools', () {
      final registry = KnowledgeToolRegistry(tools: [
        KnowledgeTool(
          name: 'character_profile',
          description: 'Character background and traits',
          retrieve: (_) async => _dummyCapsule('char'),
        ),
        KnowledgeTool(
          name: 'world_rule',
          description: 'World building rules',
          retrieve: (_) async => _dummyCapsule('world'),
        ),
      ]);

      expect(registry.availableTools, containsAll(['character_profile', 'world_rule']));
      expect(registry.hasTool('character_profile'), isTrue);
      expect(registry.hasTool('unknown'), isFalse);
    });

    test('calls registered tool and returns capsule', () async {
      final registry = KnowledgeToolRegistry(tools: [
        KnowledgeTool(
          name: 'scene_context',
          description: 'Scene context data',
          retrieve: (params) async => ContextCapsule(
            id: 'cap-1',
            sourceTool: 'scene_context',
            summary: 'Previous scene: Liu Xi found the key',
            charBudget: 200,
          ),
        ),
      ]);

      final capsule = await registry.call('scene_context', {});
      expect(capsule.sourceTool, 'scene_context');
      expect(capsule.summary, contains('Liu Xi'));
    });

    test('throws for unknown tool', () {
      final registry = KnowledgeToolRegistry();
      expect(
        () => registry.call('nonexistent', {}),
        throwsA(isA<StateError>()),
      );
    });

    test('register adds new tool dynamically', () async {
      final registry = KnowledgeToolRegistry();
      registry.register(KnowledgeTool(
        name: 'dynamic_tool',
        description: 'Added at runtime',
        retrieve: (_) async => _dummyCapsule('dynamic'),
      ));

      expect(registry.hasTool('dynamic_tool'), isTrue);
      final capsule = await registry.call('dynamic_tool', {});
      expect(capsule, isNotNull);
    });

    test('register overwrites existing tool', () async {
      final registry = KnowledgeToolRegistry(tools: [
        KnowledgeTool(
          name: 'tool_a',
          description: 'original',
          retrieve: (_) async => _dummyCapsule('v1'),
        ),
      ]);
      registry.register(KnowledgeTool(
        name: 'tool_a',
        description: 'updated',
        retrieve: (_) async => _dummyCapsule('v2'),
      ));

      expect(registry.availableTools.length, 1);
    });

    test('toolListSummary produces formatted output', () {
      final registry = KnowledgeToolRegistry(tools: [
        KnowledgeTool(
          name: 'alpha',
          description: 'First tool',
          retrieve: (_) async => _dummyCapsule('a'),
        ),
        KnowledgeTool(
          name: 'beta',
          description: 'Second tool',
          retrieve: (_) async => _dummyCapsule('b'),
        ),
      ]);

      final summary = registry.toolListSummary();
      expect(summary, contains('alpha'));
      expect(summary, contains('beta'));
      expect(summary, contains('First tool'));
    });

    test('empty registry produces empty summary', () {
      final registry = KnowledgeToolRegistry();
      expect(registry.toolListSummary(), '');
    });
  });

  // -- ContextCapsuleStore ----------------------------------------------------

  group('ContextCapsuleStore', () {
    test('inserts and queries capsules by scope', () {
      final store = ContextCapsuleStore();
      final capsule = _dummyCapsule('test');

      store.insert(capsule, 'turn-1', nowMs: 1000);
      final results = store.query('turn-1', null, nowMs: 1000);

      expect(results.length, 1);
      expect(results.first.id, capsule.id);
    });

    test('scopes are isolated', () {
      final store = ContextCapsuleStore();
      store.insert(_dummyCapsule('a'), 'scope-1', nowMs: 1000);
      store.insert(_dummyCapsule('b'), 'scope-2', nowMs: 1000);

      expect(store.query('scope-1', null, nowMs: 1000).length, 1);
      expect(store.query('scope-2', null, nowMs: 1000).length, 1);
      expect(store.query('scope-3', null, nowMs: 1000), isEmpty);
    });

    test('TTL expiration removes stale capsules', () {
      final store = ContextCapsuleStore(defaultTtlMs: 1000);
      store.insert(_dummyCapsule('exp'), 'turn-1', nowMs: 1000);

      expect(store.query('turn-1', null, nowMs: 1500).length, 1);
      expect(store.query('turn-1', null, nowMs: 2001), isEmpty);
    });

    test('capacity eviction removes oldest entries', () {
      final store = ContextCapsuleStore(maxCapsulesPerScope: 2);

      for (var i = 0; i < 3; i++) {
        store.insert(
          ContextCapsule(
            id: 'cap-$i',
            sourceTool: 'test',
            summary: 'content $i',
            charBudget: 200,
          ),
          'scope-a',
          nowMs: 1000 + i,
        );
      }

      final results = store.query('scope-a', null, nowMs: 2000);
      expect(results.length, 2);
      expect(results.any((c) => c.id == 'cap-0'), isFalse);
    });

    test('publicObservable visible to any viewer', () {
      final store = ContextCapsuleStore();
      store.insert(
        _dummyCapsule('pub'),
        'turn-1',
        visibility: KnowledgeVisibility.publicObservable,
        nowMs: 1000,
      );

      expect(store.query('turn-1', null, nowMs: 1000).length, 1);
      expect(store.query('turn-1', 'agent-x', nowMs: 1000).length, 1);
      expect(store.query('turn-1', 'agent-y', nowMs: 1000).length, 1);
    });

    test('agentPrivate only visible to owner', () {
      final store = ContextCapsuleStore();
      store.insert(
        _dummyCapsule('priv'),
        'turn-1',
        visibility: KnowledgeVisibility.agentPrivate,
        viewerId: 'agent-x',
        nowMs: 1000,
      );

      expect(store.query('turn-1', 'agent-x', nowMs: 1000).length, 1);
      expect(store.query('turn-1', 'agent-y', nowMs: 1000), isEmpty);
      expect(store.query('turn-1', null, nowMs: 1000), isEmpty);
    });

    test('clearScope only removes target scope', () {
      final store = ContextCapsuleStore();
      store.insert(_dummyCapsule('a'), 'scope-1', nowMs: 1000);
      store.insert(_dummyCapsule('b'), 'scope-2', nowMs: 1000);

      store.clearScope('scope-1');
      expect(store.query('scope-1', null, nowMs: 1000), isEmpty);
      expect(store.query('scope-2', null, nowMs: 1000).length, 1);
    });

    test('clearAll removes everything', () {
      final store = ContextCapsuleStore();
      store.insert(_dummyCapsule('a'), 's1', nowMs: 1000);
      store.insert(_dummyCapsule('b'), 's2', nowMs: 1000);

      store.clearAll();
      expect(store.size, 0);
    });
  });

  // -- SceneContextAssembler --------------------------------------------------

  group('SceneContextAssembler', () {
    test('assembles context with retrieval requirements', () {
      final assembler = SceneContextAssembler();
      final brief = SceneBrief(
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        sceneId: 'sc-1',
        sceneTitle: 'Opening',
        sceneSummary: 'Liu Xi enters the abandoned lab.',
        cast: [
          SceneCastCandidate(
            characterId: 'liuxi',
            name: '柳溪',
            role: 'protagonist',
          ),
        ],
        worldNodeIds: ['node-lab'],
      );
      final materials = ProjectMaterialSnapshot(
        worldFacts: ['The lab was abandoned in 2023.'],
        characterProfiles: ['Liu Xi is an investigative journalist.'],
        acceptedStates: ['Key found in drawer'],
      );

      final assembly = assembler.assemble(brief: brief, materials: materials);

      expect(assembly.brief.sceneId, 'sc-1');
      expect(assembly.retrievalRequirements, containsAll([
        'character_profiles',
        'world_rules',
        'state_ledger',
      ]));
      expect(assembly.materialSnapshot.worldFacts.length, 1);
    });

    test('empty brief produces minimal requirements', () {
      final assembler = SceneContextAssembler();
      final brief = SceneBrief(
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        sceneId: 'sc-1',
        sceneTitle: 'Empty',
        sceneSummary: 'Nothing happens.',
      );
      final materials = ProjectMaterialSnapshot();

      final assembly = assembler.assemble(brief: brief, materials: materials);
      expect(assembly.retrievalRequirements, isEmpty);
    });
  });

  // -- AgenticRag -------------------------------------------------------------

  group('AgenticRag', () {
    test('ranks atoms by score descending', () {
      final rag = AgenticRag(maxResults: 5);
      final atoms = [
        const RetrievalAtom(id: 'a1', content: 'low', sourceTool: 't', score: 1.0),
        const RetrievalAtom(id: 'a2', content: 'high', sourceTool: 't', score: 10.0),
        const RetrievalAtom(id: 'a3', content: 'mid', sourceTool: 't', score: 5.0),
      ];

      final ranked = rag.rank(atoms);
      expect(ranked.map((a) => a.id), ['a2', 'a3', 'a1']);
    });

    test('respects maxResults limit', () {
      final rag = AgenticRag(maxResults: 2);
      final atoms = [
        const RetrievalAtom(id: 'a1', content: '', sourceTool: 't', score: 1.0),
        const RetrievalAtom(id: 'a2', content: '', sourceTool: 't', score: 2.0),
        const RetrievalAtom(id: 'a3', content: '', sourceTool: 't', score: 3.0),
        const RetrievalAtom(id: 'a4', content: '', sourceTool: 't', score: 4.0),
      ];

      final ranked = rag.rank(atoms);
      expect(ranked.length, 2);
      expect(ranked.first.id, 'a4');
    });

    test('scoreAtom uses keyword and tag overlap', () {
      final rag = AgenticRag();
      final atom = const RetrievalAtom(
        id: 'a1',
        content: 'Liu Xi investigates the abandoned laboratory',
        sourceTool: 'test',
        tags: ['char-liuxi', 'setting-lab'],
      );

      final score = rag.scoreAtom(atom, 'Liu Xi laboratory', ['char-liuxi']);
      expect(score, greaterThan(0));
    });

    test('tag overlap scores higher than keyword only', () {
      final rag = AgenticRag();
      final atom = const RetrievalAtom(
        id: 'a1',
        content: 'Some content here',
        sourceTool: 'test',
        tags: ['char-liuxi', 'plot-key'],
      );

      final keywordOnly = rag.scoreAtom(atom, 'content', []);
      final tagOnly = rag.scoreAtom(atom, '', ['char-liuxi']);
      final both = rag.scoreAtom(atom, 'content', ['char-liuxi']);

      expect(tagOnly, greaterThan(keywordOnly));
      expect(both, greaterThan(tagOnly));
    });

    test('query scores and ranks in one pass', () {
      final rag = AgenticRag(maxResults: 3);
      final atoms = [
        const RetrievalAtom(
          id: 'a1',
          content: 'Key was hidden under the desk',
          sourceTool: 'test',
          tags: ['prop-key'],
        ),
        const RetrievalAtom(
          id: 'a2',
          content: 'Liu Xi ate noodles at the restaurant',
          sourceTool: 'test',
          tags: ['char-liuxi', 'setting-restaurant'],
        ),
        const RetrievalAtom(
          id: 'a3',
          content: 'The desk drawer contained a hidden key',
          sourceTool: 'test',
          tags: ['prop-key', 'setting-office'],
        ),
      ];

      final results = rag.query(atoms, 'key desk', ['prop-key']);
      expect(['a1', 'a3'], contains(results.first.id));
      expect(results.take(2).every((a) => a.score > 0), isTrue);
    });
  });

  // -- SceneReviewResult extended fields --------------------------------------

  group('SceneReviewResult extended fields', () {
    test('holds optional readerFlow and lexicon passes', () {
      final result = SceneReviewResult(
        judge: _passResult(SceneReviewStatus.pass),
        consistency: _passResult(SceneReviewStatus.pass),
        decision: SceneReviewDecision.pass,
        readerFlow: _passResult(SceneReviewStatus.pass),
        lexicon: _passResult(SceneReviewStatus.pass),
      );

      expect(result.readerFlow, isNotNull);
      expect(result.lexicon, isNotNull);
      expect(result.decision, SceneReviewDecision.pass);
    });

    test('backward compatible without optional passes', () {
      final result = SceneReviewResult(
        judge: _passResult(SceneReviewStatus.pass),
        consistency: _passResult(SceneReviewStatus.pass),
        decision: SceneReviewDecision.pass,
      );

      expect(result.readerFlow, isNull);
      expect(result.lexicon, isNull);
      expect(result.decision, SceneReviewDecision.pass);
    });

    test('feedback includes readerFlow and lexicon reasons', () {
      final result = SceneReviewResult(
        judge: _passResult(SceneReviewStatus.pass),
        consistency: _passResult(SceneReviewStatus.pass, reason: 'OK'),
        readerFlow: _passResult(SceneReviewStatus.rewriteProse, reason: 'Pacing too slow'),
        lexicon: _passResult(SceneReviewStatus.pass, reason: 'Clean'),
        decision: SceneReviewDecision.rewriteProse,
      );

      expect(result.feedback, contains('ReaderFlow'));
      expect(result.feedback, contains('Lexicon'));
      expect(result.feedback, contains('Pacing too slow'));
    });

    test('feedback omits null passes', () {
      final result = SceneReviewResult(
        judge: _passResult(SceneReviewStatus.pass, reason: 'All good'),
        consistency: _passResult(SceneReviewStatus.pass),
        decision: SceneReviewDecision.pass,
      );

      expect(result.feedback, isNot(contains('ReaderFlow')));
      expect(result.feedback, isNot(contains('Lexicon')));
    });
  });
}

// -- Test helpers -------------------------------------------------------------

ContextCapsule _dummyCapsule(String id) {
  return ContextCapsule(
    id: 'cap-$id',
    sourceTool: 'test',
    summary: 'test content for $id',
    charBudget: 200,
    createdAtMs: 1000,
  );
}

SceneReviewPassResult _passResult(
  SceneReviewStatus status, {
  String reason = '',
}) {
  return SceneReviewPassResult(
    status: status,
    reason: reason,
    rawText: '决定：${status == SceneReviewStatus.pass ? 'PASS' : 'REWRITE_PROSE'}\n原因：$reason',
  );
}
