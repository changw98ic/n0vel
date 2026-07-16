import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/polish_canon_evidence.dart';
import 'package:novel_writer/features/story_generation/data/polish_canon_verifier.dart';
import 'package:novel_writer/features/story_generation/data/production_pre_quality_gate.dart';
import 'package:novel_writer/features/story_generation/data/story_mechanics_verifier.dart';
import 'package:novel_writer/features/story_generation/data/story_mechanics_evidence.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  group('production polish canon boundary', () {
    for (final attack in <({String label, String prose, String failure})>[
      (
        label: 'unknown character',
        prose: '名叫沈墨的陌生人推门而入，柳溪立即把账本交给了他。',
        failure: 'continuity.polish_unknown_character',
      ),
      (
        label: 'unknown item',
        prose: '柳溪掏出黑曜钥匙，打开了仓库里从未出现过的暗门。',
        failure: 'continuity.polish_unknown_item',
      ),
      (
        label: 'unknown canon rule',
        prose: '柳溪盯着钟楼。夜城铁律是日落后所有人都会失去记忆。',
        failure: 'continuity.polish_unknown_canon',
      ),
    ]) {
      test('${attack.label} introduced by actual polish blocks', () async {
        final fixture = _PipelineFixture(attack.prose);
        addTearDown(fixture.dispose);
        final materials = _attackMaterials(attack.label);
        final directEvidence = PolishCanonVerifier.standard.verify(
          prePolishProse: '柳溪在仓库里追问账本去向。',
          polishedProse: attack.prose,
          brief: _brief(),
          materials: materials,
        );
        expect(directEvidence.failureCodes, contains(attack.failure));

        await expectLater(
          fixture.runner.runScene(_brief(), materials: materials),
          throwsA(
            isA<PolishCanonViolation>().having(
              (error) => error.evidence.failureCodes,
              'failureCodes',
              contains(attack.failure),
            ),
          ),
        );

        expect(
          fixture.runner.eventLog.query(
            stageId: 'deterministic_gate',
            eventType: 'polish_canon_blocked',
          ),
          hasLength(1),
        );
        expect(
          fixture.runner.eventLog.query(
            stageId: 'finalization',
            eventType: 'stage_completed',
          ),
          isEmpty,
        );
      });
    }

    test('rephrasing known character item and canon facts passes', () async {
      const polished =
          '柳溪说：“沈墨，把话说清楚。日落后不能鸣钟。”'
          '名叫沈墨的守钟人点了点头：“夜城铁律就是如此。”'
          '她拿出黑曜钥匙：“那我现在开门。”';
      const predecessor =
          '柳溪说：“沈墨，交代钟楼的规矩。”'
          '名叫沈墨的守钟人答道：“日落后不能鸣钟。”'
          '柳溪握紧黑曜钥匙：“我知道了。”';
      final brief = _brief().copyWith(
        sceneIndex: 1,
        totalScenesInChapter: 3,
        metadata: const <String, Object?>{
          'localStructuredRoleplayOnly': true,
          'enableFinalPolish': true,
        },
      );
      final fixture = _PipelineFixture(
        polished,
        captureCheckpoints: true,
        hardGatesEnabled: true,
        editorialText: predecessor,
      );
      addTearDown(fixture.dispose);

      final output = await fixture.runner.runScene(
        brief,
        materials: _materials(),
      );

      expect(output.prose.text, polished);
      expect(output.polishCanonEvidence, isNotNull);
      expect(output.polishCanonEvidence!.passed, isTrue);
      expect(
        output.polishCanonEvidence!.verifierReleaseHash,
        PolishCanonVerifier.releaseHash,
      );
      final checkpoint = fixture.checkpoints.singleWhere(
        (value) => value.ordinal == 8,
      );
      final payload = checkpoint.artifactJson['payload'] as Map;
      final evidence = PolishCanonEvidence.fromJson(
        payload['polishCanonEvidence'],
      );
      final mechanics = StoryMechanicsEvidence.fromJson(
        payload['storyMechanicsEvidence'],
      );
      final preQuality = ProductionPreQualityEvidence.fromJson(
        payload['productionPreQualityEvidence'],
      );
      expect(payload['algorithm'], 'deterministic-gate-v4');
      expect(payload['passed'], isTrue);
      expect(preQuality.hardGatesEnabled, isTrue);
      expect(
        preQuality.briefRequirementsHash,
        payload['briefRequirementsHash'],
      );
      expect(
        preQuality.polishCanonEvidence.evidenceHash,
        evidence.evidenceHash,
      );
      expect(
        preQuality.storyMechanicsEvidence.evidenceHash,
        mechanics.evidenceHash,
      );
      expect(evidence.prePolishProseHash, isNot(evidence.finalProseHash));
      expect(evidence.allowedCanonFactHashes, isNotEmpty);
      expect(evidence.introducedFactHashes, isEmpty);
      expect(mechanics.passed, isTrue);
      expect(mechanics.proseHash, output.storyMechanicsEvidence!.proseHash);
    });
  });

  group('production story mechanics boundary', () {
    test('frozen evidence records spans counts and ratios', () {
      final power = StoryMechanicsVerifier.standard.verify('仓库断电。终端启动。');
      final inversion = StoryMechanicsVerifier.standard.verify(
        '甲胁迫乙交出账本。下一秒乙命令甲服从。',
      );
      final motif = StoryMechanicsVerifier.standard.verify(
        '红灯再次闪烁。红灯再次闪烁。红灯再次闪烁。',
      );
      final dialogue = StoryMechanicsVerifier.standard.verify(
        '“因为编号连续，所以货物来自同一仓库，这意味着记录被人改过。”',
      );

      expect(power.unexplainedDeviceActionSpanHashes, hasLength(1));
      expect(inversion.unearnedPowerInversionSpanHashes, hasLength(1));
      expect(motif.repeatedMotifCounts.values, contains(3));
      expect(dialogue.analyticalDialogueRatioMicros, 1000000);
      expect(
        StoryMechanicsEvidence.fromJson(power.toJson()).evidenceHash,
        power.evidenceHash,
      );
    });

    for (final fixture
        in <({String label, String attack, String control, String failure})>[
          (
            label: 'unpowered device action',
            attack: '仓库突然断电。终端启动，门禁打开。柳溪停在原地。',
            control: '仓库突然断电。备用电源接管。终端启动，门禁打开。',
            failure: 'quality.unpowered_device_action',
          ),
          (
            label: 'unearned power inversion',
            attack: '甲胁迫乙交出账本。下一秒乙命令甲服从。',
            control: '甲胁迫乙交出账本。乙夺下武器，反制成功。乙命令甲服从。',
            failure: 'quality.unearned_power_inversion',
          ),
          (
            label: 'repeated explanation',
            attack: '柳溪说：“因为编号连续，所以货物来自同一仓库。”她翻了一页。岳刃重复：“因为编号连续，所以货物来自同一仓库。”',
            control: '柳溪说：“因为编号连续，所以货物来自同一仓库。”岳刃没有回答。',
            failure: 'quality.repetition_loop',
          ),
          (
            label: 'analytical dialogue density',
            attack: '“因为账本编号连续，所以货物来自同一仓库，这意味着守门人伪造了记录，结论就是他在说谎。”',
            control: '“账本给我。”柳溪敲了敲桌面。“你可以现在开口，也可以等警察来。”',
            failure: 'quality.expository_dialogue_density',
          ),
        ]) {
      test(
        '${fixture.label} blocks while its mechanism control passes',
        () async {
          final directAttack = StoryMechanicsVerifier.standard.verify(
            fixture.attack,
          );
          final directControl = StoryMechanicsVerifier.standard.verify(
            fixture.control,
          );
          expect(directAttack.failureCodes, contains(fixture.failure));
          expect(directControl.failureCodes, isNot(contains(fixture.failure)));

          final attackPipeline = _PipelineFixture(fixture.attack);
          addTearDown(attackPipeline.dispose);
          await expectLater(
            attackPipeline.runner.runScene(_brief(), materials: _materials()),
            throwsA(
              isA<StoryMechanicsViolation>().having(
                (error) => error.evidence.failureCodes,
                'failureCodes',
                contains(fixture.failure),
              ),
            ),
          );
          expect(
            attackPipeline.runner.eventLog.query(
              stageId: 'deterministic_gate',
              eventType: 'story_mechanics_blocked',
            ),
            hasLength(1),
          );

          final controlPipeline = _PipelineFixture(fixture.control);
          addTearDown(controlPipeline.dispose);
          final output = await controlPipeline.runner.runScene(
            _brief(),
            materials: _materials(),
          );
          expect(output.storyMechanicsEvidence, isNotNull);
          expect(output.storyMechanicsEvidence!.passed, isTrue);
        },
      );
    }
  });

  test(
    'post-polish hard-gate regression retries then typed-blocks before quality',
    () async {
      final preliminaryProse = File(
        'artifacts/real_validation/three_chapter_repaired/chapters/chapter-02.md',
      ).readAsStringSync().split('## 封存柜检索\n').last.split('\n## ').first.trim();
      const regressedPolish = '柳溪沿走廊慢慢前行。四周很安静。她继续向前。';
      final review = _CountingPassReview();
      final quality = _CountingQuality();
      final fixture = _PipelineFixture(
        regressedPolish,
        hardGatesEnabled: true,
        editorialText: preliminaryProse,
        reviewCoordinator: review,
        qualityScorer: quality,
      );
      addTearDown(fixture.dispose);

      await expectLater(
        fixture.runner.runScene(_hardGateBrief(), materials: _materials()),
        throwsA(
          isA<ProductionPreQualityGateViolation>().having(
            (error) => error.evidence.hardGateViolationHashes,
            'hardGateViolationHashes',
            isNotEmpty,
          ),
        ),
      );

      expect(
        fixture.runner.eventLog.query(
          stageId: 'deterministic_gate',
          eventType: 'pre_quality_hard_gate_repair_scheduled',
        ),
        hasLength(2),
      );
      expect(
        fixture.runner.eventLog.query(
          stageId: 'deterministic_gate',
          eventType: 'pre_quality_hard_gate_blocked',
        ),
        hasLength(1),
      );
      expect(
        review.calls,
        3,
        reason: 'Only three preliminary reviews may run.',
      );
      expect(quality.calls, 0);
      expect(
        fixture.runner.eventLog.query(
          stageId: 'quality_gate',
          eventType: 'quality_passed',
        ),
        isEmpty,
      );
      expect(
        fixture.runner.eventLog.query(
          stageId: 'finalization',
          eventType: 'stage_completed',
        ),
        isEmpty,
      );
    },
  );
}

final class _PipelineFixture {
  _PipelineFixture(
    this.polishedText, {
    bool captureCheckpoints = false,
    bool hardGatesEnabled = false,
    String? editorialText,
    SceneReviewService? reviewCoordinator,
    SceneQualityScorerService? qualityScorer,
  }) {
    client = FakeAppLlmClient(
      responder: (request) {
        if (request.messages.last.content.contains('任务：scene_editorial')) {
          if (editorialText == null) {
            throw StateError('editorial response was not configured');
          }
          return AppLlmChatResult.success(text: editorialText);
        }
        if (request.messages.last.content.contains('任务：language_polish')) {
          return AppLlmChatResult.success(text: polishedText);
        }
        throw StateError('unexpected provider call in polish fixture');
      },
    );
    settings = AppSettingsStore(
      storage: InMemoryAppSettingsStorage(),
      llmClient: client,
    );
    runner = PipelineStageRunnerImpl(
      settingsStore: settings,
      pipelineConfig: GenerationPipelineConfig(
        hardGatesEnabled: hardGatesEnabled,
      ),
      directorOrchestrator: const _Director(),
      reviewCoordinator: reviewCoordinator ?? const _PassReview(),
      qualityScorer: qualityScorer ?? const _PassingQuality(),
    );
    if (captureCheckpoints) {
      runner
        ..checkpointRunId = 'polish-canon-control'
        ..checkpointStore = _CheckpointStore(checkpoints);
    }
  }

  final String polishedText;
  late final FakeAppLlmClient client;
  late final AppSettingsStore settings;
  late final PipelineStageRunnerImpl runner;
  final List<PipelineStageCheckpoint> checkpoints = [];

  void dispose() => settings.dispose();
}

SceneBrief _brief() => SceneBrief(
  projectId: 'project',
  chapterId: 'chapter',
  chapterTitle: '第一章',
  sceneId: 'scene',
  sceneTitle: '雨夜仓库',
  sceneSummary: '柳溪逼问线人，确认账本去向。',
  targetBeat: '柳溪拿到账本线索。',
  cast: [
    SceneCastCandidate(characterId: 'character-liuxi', name: '柳溪', role: '调查者'),
  ],
  metadata: const <String, Object?>{
    'localStructuredRoleplayOnly': true,
    'localEditorialOnly': true,
    'enableFinalPolish': true,
  },
);

SceneBrief _hardGateBrief() => SceneBrief(
  projectId: 'project',
  chapterId: 'chapter-02',
  chapterTitle: '第二章 档案楼暗门',
  sceneId: 'scene-02',
  sceneTitle: '封存柜检索',
  sceneSummary: '找到旧航运底册并争执证据去向。',
  targetLength: 450,
  targetBeat: '找到底册并形成拍摄与销毁冲突。',
  sceneIndex: 1,
  totalScenesInChapter: 4,
  cast: <SceneCastCandidate>[
    SceneCastCandidate(characterId: 'liuxi', name: '柳溪', role: '调查记者'),
    SceneCastCandidate(characterId: 'shendu', name: '沈渡', role: '港区向导'),
  ],
  metadata: const <String, Object?>{
    'localStructuredRoleplayOnly': true,
    'enableFinalPolish': true,
  },
);

ProjectMaterialSnapshot _materials() => const ProjectMaterialSnapshot(
  worldFacts: <String>['夜城铁律是日落后不得鸣钟。'],
  characterProfiles: <String>['沈墨是夜城守钟人。'],
  acceptedStates: <String>['柳溪持有黑曜钥匙。'],
);

ProjectMaterialSnapshot _attackMaterials(String label) =>
    ProjectMaterialSnapshot(
      worldFacts: const <String>['夜城铁律是日落后不得鸣钟。'],
      characterProfiles: label == 'unknown character'
          ? const <String>[]
          : const <String>['沈墨是夜城守钟人。'],
      acceptedStates: label == 'unknown item'
          ? const <String>[]
          : const <String>['柳溪持有黑曜钥匙。'],
    );

final class _CheckpointStore implements PipelineCheckpointStore {
  const _CheckpointStore(this.values);

  final List<PipelineStageCheckpoint> values;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async =>
      List<PipelineStageCheckpoint>.unmodifiable(
        values.where((value) => value.runId == runId),
      );

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    values.removeWhere(
      (value) =>
          value.runId == checkpoint.runId &&
          value.ordinal == checkpoint.ordinal &&
          value.stageAttempt == checkpoint.stageAttempt,
    );
    values.add(checkpoint);
  }
}

final class _Director implements SceneDirectorService {
  const _Director();

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async => const SceneDirectorOutput(text: '柳溪逼问线人。');
}

final class _PassReview implements SceneReviewService {
  const _PassReview();

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
    List<StoryMemoryChunk> canonFacts = const <StoryMemoryChunk>[],
  }) async {
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '通过。',
      rawText: 'PASS',
    );
    return const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    );
  }
}

final class _PassingQuality implements SceneQualityScorerService {
  const _PassingQuality();

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async => const SceneQualityScore(
    overall: 96,
    prose: 96,
    coherence: 96,
    character: 96,
    completeness: 96,
    summary: '通过。',
  );
}

final class _CountingPassReview implements SceneReviewService {
  int calls = 0;

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
    List<StoryMemoryChunk> canonFacts = const <StoryMemoryChunk>[],
  }) async {
    calls += 1;
    return const _PassReview().review(
      brief: brief,
      director: director,
      roleOutputs: roleOutputs,
      prose: prose,
      roleplaySession: roleplaySession,
      retrievalPack: retrievalPack,
      enableReaderFlowReview: enableReaderFlowReview,
      enableLexiconReview: enableLexiconReview,
      canonFacts: canonFacts,
    );
  }
}

final class _CountingQuality implements SceneQualityScorerService {
  int calls = 0;

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async {
    calls += 1;
    return const _PassingQuality().score(
      brief: brief,
      director: director,
      prose: prose,
      review: review,
    );
  }
}
