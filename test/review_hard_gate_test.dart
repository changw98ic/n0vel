import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/prose_style_analyzer.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart' as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';
import 'package:novel_writer/features/story_generation/data/steps/review_step.dart';
import 'package:novel_writer/features/story_generation/data/step_io.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';

/// A [SceneReviewService] that throws if [review] is called.
/// Used to prove that hard gates intercept BEFORE reaching LLM review.
class _SentryReviewService implements SceneReviewService {
  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    void Function(String)? onStatus,
  }) {
    throw StateError(
      'LLM review should not be called when a hard gate triggers.',
    );
  }
}

pipeline.SceneTaskCard _stubTaskCard(SceneBrief brief) => pipeline.SceneTaskCard(
      brief: brief,
      cast: [],
    );

/// Minimal stubs to satisfy ReviewInput fields.
ScenePlanningOutput _stubPlan(SceneBrief brief) => ScenePlanningOutput(
      resolvedCast: [],
      director: SceneDirectorOutput(
        text: 'director plan text',
        taskCard: null,
      ),
      taskCard: _stubTaskCard(brief),
    );

RoleplayOutput _stubRoleplay() => RoleplayOutput(
      roleOutputs: [],
      session: null,
      roleTurns: [],
    );

EditorialOutput _stubEditorial(String proseText) => EditorialOutput(
      draft: pipeline.SceneEditorialDraft(text: 'draft', beatCount: 1, attempt: 1),
      prose: SceneProseDraft(text: proseText, attempt: 1),
    );

ContextEnrichmentOutput _stubContext() => ContextEnrichmentOutput(
      effectiveMaterials: ProjectMaterialSnapshot(),
      retrievalPack: null,
    );

void main() {
  group('ReviewStep hard gates', () {
    late ReviewStep reviewStep;

    setUp(() {
      reviewStep = ReviewStep(
        reviewCoordinator: _SentryReviewService(),
        maxProseRetries: 2,
      );
    });

    // -------------------------------------------------------------------------
    // Dialogue ratio gate (already implemented — should PASS)
    // -------------------------------------------------------------------------
    test('dialogue ratio below 20% triggers rewrite without LLM review', () async {
      // Prose with very little dialogue: ~5% dialogue ratio
      const lowDialogueProse =
          '街道上一片寂静。张三沿着墙根慢慢走着，心中充满了疑惑。'
          '他想起了昨晚发生的一切，那些不可思议的事情让他无法释怀。'
          '远处的灯光忽明忽暗，映照着破旧的门面。'
          '他停下脚步，仔细观察着周围的环境。'
          '空气中弥漫着一股奇怪的味道。';

      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '测试章节',
        sceneId: 'ch-01-sc-01',
        sceneTitle: '测试场景',
        sceneSummary: '测试',
        sceneIndex: 0,
        totalScenesInChapter: 2,
        targetLength: 200,
      );

      final input = ReviewInput(
        brief: brief,
        plan: _stubPlan(brief),
        roleplay: _stubRoleplay(),
        editorial: _stubEditorial(lowDialogueProse),
        context: _stubContext(),
        attempt: 1,
        softFailureCount: 0,
      );

      final output = await reviewStep.execute(input);

      expect(output.action, SceneReviewDecision.rewriteProse);
      expect(output.review.refinementGuidance?.toPromptText(), contains('对话占比'));
    });

    // -------------------------------------------------------------------------
    // Opening hook gate (NOT yet implemented — should FAIL)
    // -------------------------------------------------------------------------
    test('first scene with weak opening triggers rewrite without LLM review', () async {
      // Prose that opens with pure environmental description (no hook keywords)
      const weakOpeningProse =
          '清晨的阳光透过窗帘洒进房间。空气中弥漫着淡淡的花香。'
          '「你来了。」张三看着门外的人说道。'
          '「是的，我来了。」李四点了点头。'
          '「事情比你想象的要复杂。」张三叹了口气。'
          '「我知道，但我别无选择。」李四的目光变得坚定。'
          '「那我们走吧。」张三站起身来。'
          '「好，现在就走。」李四转身向门口走去。'
          '两人走出了房间，消失在清晨的薄雾中。';

      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '测试章节',
        sceneId: 'ch-01-sc-01',
        sceneTitle: '测试场景',
        sceneSummary: '测试',
        sceneIndex: 0,
        totalScenesInChapter: 3,
        targetLength: 200,
      );

      final input = ReviewInput(
        brief: brief,
        plan: _stubPlan(brief),
        roleplay: _stubRoleplay(),
        editorial: _stubEditorial(weakOpeningProse),
        context: _stubContext(),
        attempt: 1,
        softFailureCount: 0,
      );

      // Should return rewriteProse without calling LLM review.
      // Will currently throw StateError because the gate doesn't exist yet.
      final output = await reviewStep.execute(input);

      expect(output.action, SceneReviewDecision.rewriteProse);
      expect(output.review.refinementGuidance?.toPromptText(), contains('悬念'));
    });

    // -------------------------------------------------------------------------
    // Closing hook gate (NOT yet implemented — should FAIL)
    // -------------------------------------------------------------------------
    test('last scene with neat resolution triggers rewrite without LLM review', () async {
      // Prose for last scene of chapter with a neat, resolved ending
      const neatEndingProse =
          '「终于结束了。」张三松了一口气说道。'
          '「是的，一切都解决了。」李四笑了笑。'
          '「我们可以安心回家了。」张三看着远方。'
          '「没错，从此以后再也不会有麻烦了。」李四点头。'
          '两人相视一笑，转身走向回家的路。'
          '阳光温暖地洒在他们身上，一切都恢复了平静。'
          '这个小镇又回到了往日的安宁。'
          '所有的谜团都解开了，所有人都得到了应有的结局。';

      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '测试章节',
        sceneId: 'ch-01-sc-03',
        sceneTitle: '测试场景',
        sceneSummary: '测试',
        sceneIndex: 2,
        totalScenesInChapter: 3,
        targetLength: 200,
      );

      final input = ReviewInput(
        brief: brief,
        plan: _stubPlan(brief),
        roleplay: _stubRoleplay(),
        editorial: _stubEditorial(neatEndingProse),
        context: _stubContext(),
        attempt: 1,
        softFailureCount: 0,
      );

      // Should return rewriteProse without calling LLM review.
      // Will currently throw StateError because the gate doesn't exist yet.
      final output = await reviewStep.execute(input);

      expect(output.action, SceneReviewDecision.rewriteProse);
      expect(output.review.refinementGuidance?.toPromptText(), contains('悬念'));
    });

    // -------------------------------------------------------------------------
    // Scorer-aligned gate: "environment + 却" bypass must now be caught
    // -------------------------------------------------------------------------
    test('environment opening with 却 keyword still triggers rewrite', () async {
      // Old gate passed this because "却" was a keyword.
      // New scorer-aligned gate should reject: no action verbs, no suspense
      // words, no dialogue opening, no question/exclamation.
      const gamedProse =
          '清晨的阳光透过窗帘洒进房间，却照不亮他心中的阴霾。'
          '空气中弥漫着昨夜未散的潮气，远处的钟声悠远而沉闷。'
          '「你来了。」张三看着门外的人说道。'
          '「是的。」李四点了点头。'
          '「事情比你想象的要复杂。」张三叹了口气。'
          '「我知道。」李四的目光变得坚定。'
          '「那我们走吧。」张三站起身来。'
          '「好。」李四转身向门口走去。';

      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '测试章节',
        sceneId: 'ch-01-sc-01',
        sceneTitle: '测试场景',
        sceneSummary: '测试',
        sceneIndex: 0,
        totalScenesInChapter: 3,
        targetLength: 200,
      );

      final input = ReviewInput(
        brief: brief,
        plan: _stubPlan(brief),
        roleplay: _stubRoleplay(),
        editorial: _stubEditorial(gamedProse),
        context: _stubContext(),
        attempt: 1,
        softFailureCount: 0,
      );

      final output = await reviewStep.execute(input);

      expect(output.action, SceneReviewDecision.rewriteProse);
      final guidance = output.review.refinementGuidance?.toPromptText() ?? '';
      // Must show the computed hook strength, not the old keyword list.
      expect(guidance, contains('钩子强度'));
      // Must report missing action verbs or suspense words.
      expect(guidance, anyOf(contains('动作动词'), contains('悬念词')));
    });

    test('strong action opening passes hook gate', () async {
      // Action verb + suspense word + short sentence → score >= 0.30
      const strongOpeningProse =
          '苏薇冲进办公室，手里攥着一份失踪报告。「你看看这个。」'
          '她把文件拍在桌上。林默接过来看了一眼，眉头紧锁。'
          '「这个编号……和码头仓库的完全一致。」'
          '「所以不是巧合。」苏薇压低了声音。'
          '「有人在用空壳公司转运东西。」林默的目光变得锐利。'
          '「而且已经持续了至少半年。」苏薇补充道。'
          '两人对视一眼，都从对方眼中看到了同样的判断。'
          '这件事远比他们想象的要深。';

      final brief = SceneBrief(
        chapterId: 'ch-01',
        chapterTitle: '测试章节',
        sceneId: 'ch-01-sc-01',
        sceneTitle: '测试场景',
        sceneSummary: '测试',
        sceneIndex: 0,
        totalScenesInChapter: 3,
        targetLength: 200,
      );

      final input = ReviewInput(
        brief: brief,
        plan: _stubPlan(brief),
        roleplay: _stubRoleplay(),
        editorial: _stubEditorial(strongOpeningProse),
        context: _stubContext(),
        attempt: 1,
        softFailureCount: 0,
      );

      // Should NOT trigger rewrite — falls through to LLM review (which throws).
      // Since the hook gate passes, but the LLM review service throws,
      // this proves the hook gate did NOT intercept.
      expect(
        () => reviewStep.execute(input),
        throwsStateError,
      );
    });
  });

  group('ProseStyleAnalyzer dialogue detection', () {
    test('correctly identifies Chinese dialogue in brackets', () {
      const text = '「你好」他说。「我来了。」她回答道。这是测试。';
      final fingerprint = ProseStyleAnalyzer().analyze(text);
      expect(fingerprint.dialogueRatio, greaterThan(0));
    });

    test('returns zero for pure narration', () {
      const text = '街道上一片寂静。张三沿着墙根走着。远处灯光忽明忽暗。';
      final fingerprint = ProseStyleAnalyzer().analyze(text);
      expect(fingerprint.dialogueRatio, lessThan(0.05));
    });
  });
}
