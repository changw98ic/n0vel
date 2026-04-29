import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/chapter_context_bridge.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

class _InMemoryStorage implements StoryMemoryStorage {
  final Map<String, List<StoryMemorySource>> _sources = {};
  final Map<String, List<StoryMemoryChunk>> _chunks = {};
  final Map<String, List<ThoughtAtom>> _thoughts = {};

  @override
  Future<void> saveSources(
    String projectId,
    List<StoryMemorySource> sources,
  ) async {
    _sources[projectId] = List.of(sources);
  }

  @override
  Future<List<StoryMemorySource>> loadSources(String projectId) async {
    return _sources[projectId] ?? const [];
  }

  @override
  Future<void> saveChunks(
    String projectId,
    List<StoryMemoryChunk> chunks,
  ) async {
    _chunks[projectId] = List.of(chunks);
  }

  @override
  Future<List<StoryMemoryChunk>> loadChunks(String projectId) async {
    return _chunks[projectId] ?? const [];
  }

  @override
  Future<void> saveThoughts(
    String projectId,
    List<ThoughtAtom> thoughts,
  ) async {
    _thoughts[projectId] = List.of(thoughts);
  }

  @override
  Future<List<ThoughtAtom>> loadThoughts(String projectId) async {
    return _thoughts[projectId] ?? const [];
  }

  @override
  Future<void> clearProject(String projectId) async {
    _sources.remove(projectId);
    _chunks.remove(projectId);
    _thoughts.remove(projectId);
  }
}

SceneRuntimeOutput _sceneOutput({
  String sceneId = 'scene-01',
  String sceneTitle = '仓库门外',
  String chapterId = 'chapter-01',
  String chapterTitle = '第一章',
  String directorText = '目标：逼问线索',
  SceneReviewDecision decision = SceneReviewDecision.pass,
  List<String> castNames = const ['柳溪'],
}) {
  return SceneRuntimeOutput(
    brief: SceneBrief(
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      sceneId: sceneId,
      sceneTitle: sceneTitle,
      sceneSummary: '摘要',
    ),
    resolvedCast: [
      for (final name in castNames)
        ResolvedSceneCastMember(
          characterId: 'char-$name',
          name: name,
          role: '角色',
          contributions: const [SceneCastContribution.action],
        ),
    ],
    director: SceneDirectorOutput(text: directorText),
    roleOutputs: const [],
    prose: const SceneProseDraft(text: '正文内容', attempt: 1),
    review: SceneReviewResult(
      judge: const SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '通过',
        rawText: '决定：PASS',
      ),
      consistency: const SceneReviewPassResult(
        status: SceneReviewStatus.pass,
        reason: '一致',
        rawText: '决定：PASS',
      ),
      decision: decision,
    ),
    proseAttempts: 1,
    softFailureCount: 0,
  );
}

void main() {
  group('ChapterSummary', () {
    test('serializes to and from JSON', () {
      final summary = ChapterSummary(
        chapterId: 'chapter-01',
        chapterTitle: '第一章 雨夜码头',
        sceneCount: 3,
        plotProgress: '柳溪逼近岳刃 → 账单线索浮出水面',
        characterStateChanges: ['柳溪(调查记者)', '岳刃(联络人)'],
        unresolvedThreads: ['账本去向未明'],
        createdAtMs: 1700000000000,
      );

      final json = summary.toJson();
      final restored = ChapterSummary.fromJson(json);

      expect(restored.chapterId, 'chapter-01');
      expect(restored.chapterTitle, '第一章 雨夜码头');
      expect(restored.sceneCount, 3);
      expect(restored.plotProgress, '柳溪逼近岳刃 → 账单线索浮出水面');
      expect(restored.characterStateChanges, ['柳溪(调查记者)', '岳刃(联络人)']);
      expect(restored.unresolvedThreads, ['账本去向未明']);
      expect(restored.createdAtMs, 1700000000000);
    });

    test('handles missing JSON fields gracefully', () {
      final restored = ChapterSummary.fromJson(const {});
      expect(restored.chapterId, '');
      expect(restored.sceneCount, 0);
      expect(restored.plotProgress, '');
      expect(restored.characterStateChanges, isEmpty);
    });
  });

  group('CrossChapterContext', () {
    test('isEmpty when both lists are empty', () {
      const context = CrossChapterContext(
        previousSummaries: [],
        carryOverThoughts: [],
      );
      expect(context.isEmpty, isTrue);
    });

    test('is not empty when summaries exist', () {
      final context = CrossChapterContext(
        previousSummaries: [
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 1,
            plotProgress: '剧情进展',
          ),
        ],
        carryOverThoughts: const [],
      );
      expect(context.isEmpty, isFalse);
    });
  });

  group('ChapterContextBridge', () {
    late _InMemoryStorage storage;
    late ChapterContextBridge bridge;

    setUp(() {
      storage = _InMemoryStorage();
      bridge = ChapterContextBridge(storage: storage);
    });

    group('summarizeFromOutputs', () {
      test('creates summary from scene outputs', () {
        final outputs = [
          _sceneOutput(
            sceneId: 'scene-01',
            directorText: '目标：逼问线索',
            castNames: ['柳溪', '岳刃'],
          ),
          _sceneOutput(
            sceneId: 'scene-02',
            directorText: '目标：拿到账本',
            castNames: ['柳溪'],
            decision: SceneReviewDecision.rewriteProse,
          ),
        ];

        final summary = bridge.summarizeFromOutputs(
          chapterId: 'chapter-01',
          chapterTitle: '第一章 雨夜码头',
          outputs: outputs,
          nowMs: 1000,
        );

        expect(summary.chapterId, 'chapter-01');
        expect(summary.chapterTitle, '第一章 雨夜码头');
        expect(summary.sceneCount, 2);
        expect(summary.plotProgress, contains('逼问线索'));
        expect(summary.plotProgress, contains('拿到账本'));
        expect(summary.characterStateChanges, containsAll(['柳溪(角色)', '岳刃(角色)']));
        expect(summary.unresolvedThreads, hasLength(1));
        expect(summary.unresolvedThreads.first, contains('review='));
        expect(summary.createdAtMs, 1000);
      });

      test('handles empty outputs', () {
        final summary = bridge.summarizeFromOutputs(
          chapterId: 'chapter-02',
          chapterTitle: '第二章',
          outputs: const [],
          nowMs: 2000,
        );

        expect(summary.sceneCount, 0);
        expect(summary.plotProgress, isEmpty);
        expect(summary.characterStateChanges, isEmpty);
      });
    });

    group('saveChapterSummary / loadChapterSummaries', () {
      test('persists and loads chapter summaries', () async {
        final summary = ChapterSummary(
          chapterId: 'chapter-01',
          chapterTitle: '第一章',
          sceneCount: 3,
          plotProgress: '剧情进展',
          createdAtMs: 1000,
        );

        await bridge.saveChapterSummary('project-1', summary);

        final loaded = await bridge.loadChapterSummaries('project-1');
        expect(loaded, hasLength(1));
        expect(loaded.first.chapterId, 'chapter-01');
        expect(loaded.first.plotProgress, '剧情进展');
      });

      test('updates existing summary for same chapter', () async {
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 2,
            plotProgress: '旧进展',
            createdAtMs: 1000,
          ),
        );
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章(修订)',
            sceneCount: 3,
            plotProgress: '新进展',
            createdAtMs: 2000,
          ),
        );

        final loaded = await bridge.loadChapterSummaries('project-1');
        expect(loaded, hasLength(1));
        expect(loaded.first.plotProgress, '新进展');
        expect(loaded.first.sceneCount, 3);
      });

      test('loads summaries ordered by creation time', () async {
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-02',
            chapterTitle: '第二章',
            sceneCount: 1,
            plotProgress: 'B',
            createdAtMs: 2000,
          ),
        );
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 1,
            plotProgress: 'A',
            createdAtMs: 1000,
          ),
        );

        final loaded = await bridge.loadChapterSummaries('project-1');
        expect(loaded.first.chapterId, 'ch-01');
        expect(loaded.last.chapterId, 'ch-02');
      });

      test('returns empty list for unknown project', () async {
        final loaded = await bridge.loadChapterSummaries('unknown');
        expect(loaded, isEmpty);
      });

      test('isolates summaries between projects', () async {
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 1,
            plotProgress: 'P1',
            createdAtMs: 1000,
          ),
        );
        await bridge.saveChapterSummary(
          'project-2',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 2,
            plotProgress: 'P2',
            createdAtMs: 1000,
          ),
        );

        final p1 = await bridge.loadChapterSummaries('project-1');
        final p2 = await bridge.loadChapterSummaries('project-2');
        expect(p1, hasLength(1));
        expect(p2, hasLength(1));
        expect(p1.first.plotProgress, 'P1');
        expect(p2.first.plotProgress, 'P2');
      });
    });

    group('buildCrossChapterContext', () {
      test('returns empty context when no previous chapters', () async {
        final context = await bridge.buildCrossChapterContext(
          projectId: 'project-1',
          currentChapterId: 'ch-01',
        );

        expect(context.isEmpty, isTrue);
      });

      test('loads summaries from previous chapters', () async {
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 3,
            plotProgress: '柳溪逼近岳刃',
            createdAtMs: 1000,
          ),
        );

        final context = await bridge.buildCrossChapterContext(
          projectId: 'project-1',
          currentChapterId: 'ch-02',
        );

        expect(context.isEmpty, isFalse);
        expect(context.previousSummaries, hasLength(1));
        expect(context.previousSummaries.first.chapterId, 'ch-01');
      });

      test('excludes current chapter from previous summaries', () async {
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 1,
            plotProgress: 'A',
            createdAtMs: 1000,
          ),
        );

        final context = await bridge.buildCrossChapterContext(
          projectId: 'project-1',
          currentChapterId: 'ch-01',
        );

        expect(context.previousSummaries, isEmpty);
        expect(context.isEmpty, isTrue);
      });

      test('respects maxPreviousChapters limit', () async {
        for (var i = 1; i <= 5; i++) {
          await bridge.saveChapterSummary(
            'project-1',
            ChapterSummary(
              chapterId: 'ch-0$i',
              chapterTitle: '第$i章',
              sceneCount: 1,
              plotProgress: '进展$i',
              createdAtMs: i * 1000,
            ),
          );
        }

        final context = await bridge.buildCrossChapterContext(
          projectId: 'project-1',
          currentChapterId: 'ch-06',
          maxPreviousChapters: 2,
        );

        expect(context.previousSummaries, hasLength(2));
      });

      test('carries over high-confidence thoughts from previous chapters',
          () async {
        await bridge.saveChapterSummary(
          'project-1',
          ChapterSummary(
            chapterId: 'ch-01',
            chapterTitle: '第一章',
            sceneCount: 1,
            plotProgress: 'A',
            createdAtMs: 1000,
          ),
        );

        await storage.saveThoughts('ch-01', [
          ThoughtAtom(
            id: 't1',
            projectId: 'ch-01',
            scopeId: 'ch-01:scene-01',
            thoughtType: ThoughtType.plotCausality,
            content: '岳刃暴露了货单线索',
            confidence: 0.9,
            abstractionLevel: 2.0,
            createdAtMs: 1100,
          ),
          ThoughtAtom(
            id: 't2',
            projectId: 'ch-01',
            scopeId: 'ch-01:scene-01',
            thoughtType: ThoughtType.persona,
            content: '低置信度',
            confidence: 0.3,
            abstractionLevel: 1.0,
            createdAtMs: 1200,
          ),
        ]);

        final context = await bridge.buildCrossChapterContext(
          projectId: 'project-1',
          currentChapterId: 'ch-02',
        );

        expect(context.carryOverThoughts, hasLength(1));
        expect(context.carryOverThoughts.first.content, '岳刃暴露了货单线索');
      });
    });

    group('enrichMaterialSnapshot', () {
      test('returns base snapshot when context is empty', () {
        const base = ProjectMaterialSnapshot(
          worldFacts: ['世界规则1'],
        );
        const context = CrossChapterContext(
          previousSummaries: [],
          carryOverThoughts: [],
        );

        final enriched = bridge.enrichMaterialSnapshot(base, context);
        expect(identical(enriched, base), isTrue);
      });

      test('injects chapter summaries into scene summaries', () {
        const base = ProjectMaterialSnapshot(
          sceneSummaries: ['场景1'],
        );
        final context = CrossChapterContext(
          previousSummaries: [
            ChapterSummary(
              chapterId: 'ch-01',
              chapterTitle: '第一章 雨夜码头',
              sceneCount: 3,
              plotProgress: '柳溪逼近岳刃，账单线索浮现',
            ),
          ],
          carryOverThoughts: const [],
        );

        final enriched = bridge.enrichMaterialSnapshot(base, context);

        expect(enriched.sceneSummaries, hasLength(2));
        expect(enriched.sceneSummaries.first, '场景1');
        expect(enriched.sceneSummaries.last, contains('前章概要'));
        expect(enriched.sceneSummaries.last, contains('雨夜码头'));
      });

      test('injects character states and unresolved threads', () {
        const base = ProjectMaterialSnapshot(
          acceptedStates: ['现有状态'],
        );
        final context = CrossChapterContext(
          previousSummaries: [
            ChapterSummary(
              chapterId: 'ch-01',
              chapterTitle: '第一章',
              sceneCount: 1,
              plotProgress: '进展',
              characterStateChanges: ['柳溪(调查记者)'],
              unresolvedThreads: ['账本去向'],
            ),
          ],
          carryOverThoughts: const [],
        );

        final enriched = bridge.enrichMaterialSnapshot(base, context);

        expect(enriched.acceptedStates, contains('现有状态'));
        expect(
          enriched.acceptedStates.any((s) => s.contains('前章角色')),
          isTrue,
        );
        expect(
          enriched.acceptedStates.any((s) => s.contains('前章悬念')),
          isTrue,
        );
      });

      test('injects carry-over thoughts as scene summaries', () {
        const base = ProjectMaterialSnapshot();
        final context = CrossChapterContext(
          previousSummaries: const [],
          carryOverThoughts: [
            ThoughtAtom(
              id: 't1',
              projectId: 'p1',
              scopeId: 'ch-01:s1',
              thoughtType: ThoughtType.foreshadowing,
              content: '伏笔：岳刃的犹豫暗示双重身份',
              confidence: 0.85,
              abstractionLevel: 2.0,
              createdAtMs: 1000,
            ),
          ],
        );

        final enriched = bridge.enrichMaterialSnapshot(base, context);

        expect(enriched.sceneSummaries, hasLength(1));
        expect(
          enriched.sceneSummaries.first,
          contains('跨章记忆'),
        );
        expect(
          enriched.sceneSummaries.first,
          contains('foreshadowing'),
        );
      });

      test('preserves base fields that are not enriched', () {
        const base = ProjectMaterialSnapshot(
          worldFacts: ['规则1'],
          characterProfiles: ['角色1'],
          relationshipHints: ['关系1'],
          outlineBeats: ['大纲1'],
          reviewFindings: ['评审1'],
        );
        final context = CrossChapterContext(
          previousSummaries: [
            ChapterSummary(
              chapterId: 'ch-01',
              chapterTitle: '第一章',
              sceneCount: 1,
              plotProgress: '进展',
            ),
          ],
          carryOverThoughts: const [],
        );

        final enriched = bridge.enrichMaterialSnapshot(base, context);

        expect(enriched.worldFacts, ['规则1']);
        expect(enriched.characterProfiles, ['角色1']);
        expect(enriched.relationshipHints, ['关系1']);
        expect(enriched.outlineBeats, ['大纲1']);
        expect(enriched.reviewFindings, ['评审1']);
      });
    });

    group('summarizeExit', () {
      test('produces correct transition summaries', () {
        const transitions = [
          StateTransitionTarget(
            id: 't1',
            fromSceneId: 'scene-01',
            toSceneId: 'scene-02',
            kind: 'time_skip',
          ),
          StateTransitionTarget(
            id: 't2',
            fromSceneId: 'scene-02',
            toSceneId: 'scene-03',
            kind: 'exit',
          ),
        ];

        final exitState = bridge.summarizeExit(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
          transitions: transitions,
          unresolvedThreads: ['账本去向未明'],
          cognitionDeltas: const [
            CognitionDelta(
              characterId: 'char-01',
              characterName: '柳溪',
              kind: 'belief',
              description: '开始怀疑岳刃',
              sourceSceneId: 'scene-01',
            ),
          ],
        );

        expect(exitState.chapterId, 'ch-01');
        expect(exitState.chapterTitle, '第一章');
        expect(exitState.outgoingTransitions, hasLength(2));

        final t0 = exitState.outgoingTransitions[0];
        expect(t0.transitionId, 't1');
        expect(t0.kind, 'time_skip');
        expect(t0.fromSceneId, 'scene-01');
        expect(t0.toSceneId, 'scene-02');
        expect(t0.summary, contains('时间跳转'));

        final t1 = exitState.outgoingTransitions[1];
        expect(t1.transitionId, 't2');
        expect(t1.kind, 'exit');
        expect(t1.summary, contains('退出场景'));
      });

      test('includes unresolved threads', () {
        final exitState = bridge.summarizeExit(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
          transitions: const [],
          unresolvedThreads: ['账本去向未明', '岳刃真实身份'],
          cognitionDeltas: const [],
        );

        expect(exitState.unresolvedThreads, hasLength(2));
        expect(exitState.unresolvedThreads, contains('账本去向未明'));
        expect(exitState.unresolvedThreads, contains('岳刃真实身份'));
      });

      test('produces valid but minimal exit state with empty inputs', () {
        final exitState = bridge.summarizeExit(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
          transitions: const [],
          unresolvedThreads: const [],
          cognitionDeltas: const [],
        );

        expect(exitState.chapterId, 'ch-01');
        expect(exitState.outgoingTransitions, isEmpty);
        expect(exitState.unresolvedThreads, isEmpty);
        expect(exitState.unresolvedCognitionDeltas, isEmpty);
      });
    });

    group('validateEntry', () {
      test('passes for consistent state', () {
        final exitState = ChapterExitState(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
          outgoingTransitions: [
            const TransitionSummary(
              transitionId: 't1',
              kind: 'time_skip',
              fromSceneId: 'scene-02',
              toSceneId: 'scene-03',
              summary: '跳转',
            ),
          ],
        );

        final validation = bridge.validateEntry(
          previousExit: exitState,
          nextChapterId: 'ch-02',
        );

        expect(validation.chapterId, 'ch-02');
        expect(validation.isConsistent, isTrue);
        expect(validation.issues, isEmpty);
      });

      test('detects chapter ID mismatch when same chapter', () {
        final exitState = ChapterExitState(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
        );

        final validation = bridge.validateEntry(
          previousExit: exitState,
          nextChapterId: 'ch-01',
        );

        expect(validation.isConsistent, isFalse);
        expect(validation.issues, anyElement(contains('mismatch')));
      });

      test('detects empty nextChapterId', () {
        final exitState = ChapterExitState(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
        );

        final validation = bridge.validateEntry(
          previousExit: exitState,
          nextChapterId: '',
        );

        expect(validation.isConsistent, isFalse);
        expect(validation.issues, anyElement(contains('empty')));
      });

      test('detects empty previousExit chapterId', () {
        const exitState = ChapterExitState(
          chapterId: '',
          chapterTitle: '',
        );

        final validation = bridge.validateEntry(
          previousExit: exitState,
          nextChapterId: 'ch-02',
        );

        expect(validation.isConsistent, isFalse);
        expect(validation.issues, anyElement(contains('empty chapterId')));
      });
    });
  });

  group('TransitionSummary', () {
    test('serializes to and from JSON', () {
      const summary = TransitionSummary(
        transitionId: 't1',
        kind: 'time_skip',
        fromSceneId: 'scene-01',
        toSceneId: 'scene-02',
        summary: '时间跳转到第二天',
        isResolved: true,
      );

      final json = summary.toJson();
      final restored = TransitionSummary.fromJson(json);

      expect(restored, equals(summary));
      expect(restored.transitionId, 't1');
      expect(restored.kind, 'time_skip');
      expect(restored.fromSceneId, 'scene-01');
      expect(restored.toSceneId, 'scene-02');
      expect(restored.summary, '时间跳转到第二天');
      expect(restored.isResolved, isTrue);
    });

    test('handles missing JSON fields gracefully', () {
      final restored = TransitionSummary.fromJson(const {});
      expect(restored.transitionId, isEmpty);
      expect(restored.kind, isEmpty);
      expect(restored.isResolved, isFalse);
    });

    test('supports equality and hashCode', () {
      const a = TransitionSummary(
        transitionId: 't1',
        kind: 'exit',
        fromSceneId: 's1',
        toSceneId: 's2',
        summary: 'test',
      );
      const b = TransitionSummary(
        transitionId: 't1',
        kind: 'exit',
        fromSceneId: 's1',
        toSceneId: 's2',
        summary: 'test',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith produces modified copy', () {
      const original = TransitionSummary(
        transitionId: 't1',
        kind: 'exit',
        fromSceneId: 's1',
        toSceneId: 's2',
        summary: 'old',
        isResolved: false,
      );
      final modified = original.copyWith(summary: 'new', isResolved: true);
      expect(modified.summary, 'new');
      expect(modified.isResolved, isTrue);
      expect(modified.transitionId, 't1');
    });
  });

  group('CognitionDelta', () {
    test('serializes to and from JSON', () {
      const delta = CognitionDelta(
        characterId: 'char-01',
        characterName: '柳溪',
        kind: 'belief',
        description: '开始怀疑岳刃的真实意图',
        sourceSceneId: 'scene-01',
      );

      final json = delta.toJson();
      final restored = CognitionDelta.fromJson(json);

      expect(restored, equals(delta));
      expect(restored.characterId, 'char-01');
      expect(restored.characterName, '柳溪');
      expect(restored.kind, 'belief');
      expect(restored.description, '开始怀疑岳刃的真实意图');
      expect(restored.sourceSceneId, 'scene-01');
    });

    test('handles missing JSON fields gracefully', () {
      final restored = CognitionDelta.fromJson(const {});
      expect(restored.characterId, isEmpty);
      expect(restored.characterName, isEmpty);
      expect(restored.kind, isEmpty);
      expect(restored.description, isEmpty);
      expect(restored.sourceSceneId, isEmpty);
    });

    test('supports equality and hashCode', () {
      const a = CognitionDelta(
        characterId: 'c1',
        characterName: 'A',
        kind: 'goal',
        description: 'x',
        sourceSceneId: 's1',
      );
      const b = CognitionDelta(
        characterId: 'c1',
        characterName: 'A',
        kind: 'goal',
        description: 'x',
        sourceSceneId: 's1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith produces modified copy', () {
      const original = CognitionDelta(
        characterId: 'c1',
        characterName: 'A',
        kind: 'goal',
        description: 'old desc',
        sourceSceneId: 's1',
      );
      final modified = original.copyWith(description: 'new desc');
      expect(modified.description, 'new desc');
      expect(modified.characterId, 'c1');
    });
  });

  group('ChapterExitState', () {
    test('serializes to and from JSON (round-trip)', () {
      final exitState = ChapterExitState(
        chapterId: 'ch-01',
        chapterTitle: '第一章 雨夜码头',
        outgoingTransitions: const [
          TransitionSummary(
            transitionId: 't1',
            kind: 'time_skip',
            fromSceneId: 'scene-02',
            toSceneId: 'scene-03',
            summary: '第二天清晨',
          ),
        ],
        unresolvedThreads: ['账本去向未明'],
        unresolvedCognitionDeltas: const [
          CognitionDelta(
            characterId: 'char-01',
            characterName: '柳溪',
            kind: 'belief',
            description: '怀疑岳刃',
            sourceSceneId: 'scene-01',
          ),
        ],
        metadata: {'customKey': 'customValue'},
      );

      final json = exitState.toJson();
      final restored = ChapterExitState.fromJson(json);

      expect(restored.chapterId, 'ch-01');
      expect(restored.chapterTitle, '第一章 雨夜码头');
      expect(restored.outgoingTransitions, hasLength(1));
      expect(restored.outgoingTransitions.first.transitionId, 't1');
      expect(restored.unresolvedThreads, ['账本去向未明']);
      expect(restored.unresolvedCognitionDeltas, hasLength(1));
      expect(restored.unresolvedCognitionDeltas.first.characterName, '柳溪');
      expect(restored.metadata['customKey'], 'customValue');
    });

    test('handles missing JSON fields gracefully', () {
      final restored = ChapterExitState.fromJson(const {});
      expect(restored.chapterId, isEmpty);
      expect(restored.chapterTitle, isEmpty);
      expect(restored.outgoingTransitions, isEmpty);
      expect(restored.unresolvedThreads, isEmpty);
      expect(restored.unresolvedCognitionDeltas, isEmpty);
    });

    test('copyWith produces modified copy', () {
      const original = ChapterExitState(
        chapterId: 'ch-01',
        chapterTitle: '第一章',
      );
      final modified = original.copyWith(
        chapterTitle: '第二章',
        unresolvedThreads: ['new thread'],
      );
      expect(modified.chapterId, 'ch-01');
      expect(modified.chapterTitle, '第二章');
      expect(modified.unresolvedThreads, ['new thread']);
    });
  });

  group('ChapterEntryValidation', () {
    test('serializes to and from JSON', () {
      const validation = ChapterEntryValidation(
        chapterId: 'ch-02',
        isConsistent: true,
        issues: [],
      );

      final json = validation.toJson();
      final restored = ChapterEntryValidation.fromJson(json);

      expect(restored.chapterId, 'ch-02');
      expect(restored.isConsistent, isTrue);
      expect(restored.issues, isEmpty);
    });

    test('handles missing JSON fields gracefully', () {
      final restored = ChapterEntryValidation.fromJson(const {});
      expect(restored.chapterId, isEmpty);
      expect(restored.isConsistent, isFalse);
      expect(restored.issues, isEmpty);
    });
  });

  group('ChapterHandoffPayload', () {
    test('serializes to and from JSON (round-trip)', () {
      final payload = ChapterHandoffPayload(
        exitState: ChapterExitState(
          chapterId: 'ch-01',
          chapterTitle: '第一章',
          outgoingTransitions: const [
            TransitionSummary(
              transitionId: 't1',
              kind: 'exit',
              fromSceneId: 's1',
              toSceneId: 's2',
              summary: '场景转换',
            ),
          ],
          unresolvedThreads: ['悬念1'],
          unresolvedCognitionDeltas: const [
            CognitionDelta(
              characterId: 'c1',
              characterName: '柳溪',
              kind: 'goal',
              description: '追查真相',
              sourceSceneId: 's1',
            ),
          ],
        ),
        entryValidation: const ChapterEntryValidation(
          chapterId: 'ch-02',
          isConsistent: true,
          issues: [],
        ),
      );

      final json = payload.toJson();
      final restored = ChapterHandoffPayload.fromJson(json);

      expect(restored.exitState.chapterId, 'ch-01');
      expect(restored.exitState.outgoingTransitions, hasLength(1));
      expect(restored.exitState.unresolvedThreads, ['悬念1']);
      expect(restored.exitState.unresolvedCognitionDeltas, hasLength(1));
      expect(restored.entryValidation.chapterId, 'ch-02');
      expect(restored.entryValidation.isConsistent, isTrue);
    });

    test('handles missing JSON fields with fallback defaults', () {
      final restored = ChapterHandoffPayload.fromJson(const {});
      expect(restored.exitState.chapterId, isEmpty);
      expect(restored.entryValidation.isConsistent, isFalse);
      expect(restored.entryValidation.issues, isNotEmpty);
    });
  });
}
