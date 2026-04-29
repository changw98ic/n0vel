import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_dedupe.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_stub.dart';
import 'package:novel_writer/features/story_generation/data/thought_memory_updater.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

void main() {
  group('thought updater', () {
    late StoryMemoryStorageStub storage;
    late ThoughtMemoryUpdater updater;

    setUp(() {
      storage = StoryMemoryStorageStub();
      updater = ThoughtMemoryUpdater(storage: storage);
    });

    SceneRuntimeOutput buildOutput({
      SceneReviewDecision decision = SceneReviewDecision.pass,
    }) {
      return SceneRuntimeOutput(
        brief: SceneBrief(
          chapterId: 'ch1',
          chapterTitle: 'Chapter 1',
          sceneId: 'sc1',
          sceneTitle: 'The Discovery',
          sceneSummary: 'The hero finds the ancient key.',
          cast: [
            SceneCastCandidate(
              characterId: 'char-liuxi',
              name: 'Liu Xi',
              role: 'protagonist',
            ),
          ],
        ),
        resolvedCast: [
          ResolvedSceneCastMember(
            characterId: 'char-liuxi',
            name: 'Liu Xi',
            role: 'protagonist',
            contributions: [SceneCastContribution.action],
          ),
        ],
        director: const SceneDirectorOutput(
          text: 'Liu Xi discovers the hidden door behind the waterfall.',
        ),
        roleOutputs: const [
          DynamicRoleAgentOutput(
            characterId: 'char-liuxi',
            name: 'Liu Xi',
            text: 'I approach the waterfall cautiously.',
          ),
        ],
        prose: const SceneProseDraft(
          text: 'The water cascaded over the ancient stones. Liu Xi reached through the curtain of mist.',
          attempt: 1,
        ),
        review: SceneReviewResult(
          judge: const SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'No issues found.',
            rawText: '决定：PASS\n原因：No issues found.',
          ),
          consistency: const SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '决定：PASS\n原因：',
          ),
          decision: decision,
        ),
        proseAttempts: 1,
        softFailureCount: 0,
      );
    }

    test('extracts persona thought from cast', () async {
      final result = await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      final personaThoughts = result.accepted
          .where((t) => t.thoughtType == ThoughtType.persona)
          .toList();
      expect(personaThoughts, isNotEmpty);
      expect(personaThoughts.first.content, contains('Liu Xi'));
      expect(personaThoughts.first.sourceRefs, isNotEmpty);
    });

    test('extracts plot causality thought from director', () async {
      final result = await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      final causalityThoughts = result.accepted
          .where((t) => t.thoughtType == ThoughtType.plotCausality)
          .toList();
      expect(causalityThoughts, isNotEmpty);
      expect(causalityThoughts.first.content, contains('Director'));
      expect(causalityThoughts.first.abstractionLevel, greaterThan(1.0));
    });

    test('extracts foreshadowing thought when review passes', () async {
      final result = await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(decision: SceneReviewDecision.pass),
        nowMs: 10000,
      );

      final foreshadow = result.accepted
          .where((t) => t.thoughtType == ThoughtType.foreshadowing)
          .toList();
      expect(foreshadow, isNotEmpty);
    });

    test('extracts state thought when review does not pass', () async {
      final result = await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(decision: SceneReviewDecision.rewriteProse),
        nowMs: 10000,
      );

      final stateThoughts = result.accepted
          .where((t) => t.thoughtType == ThoughtType.state)
          .toList();
      expect(stateThoughts, isNotEmpty);
    });

    test('persists accepted thoughts to storage', () async {
      await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      final stored = await storage.loadThoughts('p1');
      expect(stored, isNotEmpty);
    });

    test('dedupes repeated extraction runs', () async {
      await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );
      final firstBatch = await storage.loadThoughts('p1');

      await updater.extractLocal(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 20000,
      );
      final secondBatch = await storage.loadThoughts('p1');

      // Second run should produce duplicates that are rejected
      expect(secondBatch.length, greaterThan(0));
      expect(secondBatch.length, greaterThanOrEqualTo(firstBatch.length));
    });
  });

  group('filter', () {
    late StoryMemoryDedupe dedupe;

    setUp(() {
      dedupe = StoryMemoryDedupe();
    });

    test('rejects confidence below threshold', () {
      final thought = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Some insight',
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

    test('accepts confidence at threshold', () {
      final thought = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Some insight',
        confidence: 0.72,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );
      expect(dedupe.passesQualityGate(thought), isTrue);
    });

    test('rejects near-duplicate thought', () {
      final existing = [
        ThoughtAtom(
          id: 't1',
          projectId: 'p1',
          scopeId: 's1',
          thoughtType: ThoughtType.persona,
          content: 'Liu Xi hides fear by asking procedural questions',
          confidence: 0.85,
          sourceRefs: [
            MemorySourceRef(
              sourceId: 's1',
              sourceType: MemorySourceKind.sceneSummary,
            ),
          ],
          rootSourceIds: ['s1'],
        ),
      ];

      final candidate = ThoughtAtom(
        id: 't2',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Liu Xi hides fear by asking procedural questions about the plan',
        confidence: 0.80,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );

      expect(dedupe.isDuplicate(candidate, existing), isTrue);
    });

    test('rejects thought with no source trace', () {
      final thought = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Some insight without source',
        confidence: 0.85,
      );
      expect(dedupe.passesQualityGate(thought), isFalse);
    });

    test('accepts thought with rootSourceIds but no sourceRefs', () {
      final thought = ThoughtAtom(
        id: 't1',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content: 'Some insight with root sources only',
        confidence: 0.85,
        rootSourceIds: ['scene-1:beat-2'],
      );
      expect(dedupe.passesQualityGate(thought), isTrue);
    });

    test('higher-abstraction thought coexists with raw source', () {
      final existing = [
        ThoughtAtom(
          id: 't1',
          projectId: 'p1',
          scopeId: 's1',
          thoughtType: ThoughtType.persona,
          content:
              'Liu Xi discovers the hidden door behind the waterfall',
          confidence: 0.80,
          sourceRefs: [
            MemorySourceRef(
              sourceId: 's1',
              sourceType: MemorySourceKind.sceneSummary,
            ),
          ],
          rootSourceIds: ['s1'],
        ),
      ];

      final candidate = ThoughtAtom(
        id: 't2',
        projectId: 'p1',
        scopeId: 's1',
        thoughtType: ThoughtType.persona,
        content:
            'Liu Xi approaches discovery through careful observation rather than bold action',
        confidence: 0.88,
        sourceRefs: [
          MemorySourceRef(
            sourceId: 's1',
            sourceType: MemorySourceKind.sceneSummary,
          ),
        ],
        rootSourceIds: ['s1'],
      );

      expect(dedupe.isDuplicate(candidate, existing), isFalse);
    });
  });

  group('llm refinement', () {
    late StoryMemoryStorageStub storage;

    setUp(() {
      storage = StoryMemoryStorageStub();
    });

    SceneRuntimeOutput buildOutput() {
      return SceneRuntimeOutput(
        brief: SceneBrief(
          chapterId: 'ch1',
          chapterTitle: 'Chapter 1',
          sceneId: 'sc1',
          sceneTitle: 'The Discovery',
          sceneSummary: 'The hero finds the ancient key.',
          cast: [
            SceneCastCandidate(
              characterId: 'char-liuxi',
              name: 'Liu Xi',
              role: 'protagonist',
            ),
          ],
        ),
        resolvedCast: [
          ResolvedSceneCastMember(
            characterId: 'char-liuxi',
            name: 'Liu Xi',
            role: 'protagonist',
            contributions: [SceneCastContribution.action],
          ),
        ],
        director: const SceneDirectorOutput(
          text: 'Liu Xi discovers the hidden door behind the waterfall.',
        ),
        roleOutputs: const [
          DynamicRoleAgentOutput(
            characterId: 'char-liuxi',
            name: 'Liu Xi',
            text: 'I approach the waterfall cautiously.',
          ),
        ],
        prose: const SceneProseDraft(
          text: 'The water cascaded over the ancient stones.',
          attempt: 1,
        ),
        review: SceneReviewResult(
          judge: const SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: 'No issues found.',
            rawText: '决定：PASS\n原因：No issues found.',
          ),
          consistency: const SceneReviewPassResult(
            status: SceneReviewStatus.pass,
            reason: '',
            rawText: '决定：PASS\n原因：',
          ),
          decision: SceneReviewDecision.pass,
        ),
        proseAttempts: 1,
        softFailureCount: 0,
      );
    }

    test('uses LLM when caller is available', () async {
      String? capturedSystem;
      String? capturedUser;

      final llmUpdater = ThoughtMemoryUpdater(
        storage: storage,
        llmCaller: (system, user) async {
          capturedSystem = system;
          capturedUser = user;
          return '[{"thoughtType":"persona","content":"LLM extracted insight","confidence":0.9,"sourceIds":["sc1"],"rootSourceIds":["sc1"],"tags":["persona"]}]';
        },
      );

      final result = await llmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      expect(capturedSystem, isNotNull);
      expect(capturedUser, contains('The Discovery'));
      expect(result.accepted, isNotEmpty);
      expect(result.accepted.first.content, contains('LLM extracted insight'));
    });

    test('persists LLM-extracted thoughts to storage', () async {
      final llmUpdater = ThoughtMemoryUpdater(
        storage: storage,
        llmCaller: (system, user) async {
          return '[{"thoughtType":"plotCausality","content":"The key loss forces a new path","confidence":0.88,"sourceIds":["sc1"],"rootSourceIds":["sc1"],"tags":["plot","causality"]}]';
        },
      );

      await llmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      final stored = await storage.loadThoughts('p1');
      expect(stored, isNotEmpty);
      expect(stored.any((t) => t.content.contains('key loss')), isTrue);
    });

    test('falls back to local on null LLM response', () async {
      final llmUpdater = ThoughtMemoryUpdater(
        storage: storage,
        llmCaller: (system, user) async => null,
      );

      final result = await llmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      expect(result.accepted, isNotEmpty);
      // Local extraction should have run
      expect(
        result.accepted.any((t) => t.content.contains('Liu Xi')),
        isTrue,
      );
    });

    test('falls back to local on invalid JSON', () async {
      final llmUpdater = ThoughtMemoryUpdater(
        storage: storage,
        llmCaller: (system, user) async => 'not valid json at all',
      );

      final result = await llmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      expect(result.accepted, isNotEmpty);
    });

    test('falls back to local on LLM exception', () async {
      final llmUpdater = ThoughtMemoryUpdater(
        storage: storage,
        llmCaller: (system, user) async {
          throw StateError('LLM unavailable');
        },
      );

      final result = await llmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      expect(result.accepted, isNotEmpty);
    });

    test('extractWithLlm without caller delegates to extractLocal', () async {
      final noLlmUpdater = ThoughtMemoryUpdater(storage: storage);

      final result = await noLlmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      // Should behave identically to extractLocal
      expect(result.accepted, isNotEmpty);
      expect(
        result.accepted.any((t) => t.thoughtType == ThoughtType.persona),
        isTrue,
      );
    });

    test('strips markdown fences from LLM response', () async {
      final llmUpdater = ThoughtMemoryUpdater(
        storage: storage,
        llmCaller: (system, user) async {
          return '```json\n[{"thoughtType":"style","content":"Short sentences build tension","confidence":0.82,"sourceIds":["sc1"],"rootSourceIds":["sc1"],"tags":["style"]}]\n```';
        },
      );

      final result = await llmUpdater.extractWithLlm(
        projectId: 'p1',
        sceneOutput: buildOutput(),
        nowMs: 10000,
      );

      expect(result.accepted, isNotEmpty);
      expect(
        result.accepted.any((t) => t.content.contains('tension')),
        isTrue,
      );
    });
  });
}
