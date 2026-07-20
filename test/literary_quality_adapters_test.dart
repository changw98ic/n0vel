import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_adapters.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_models.dart'
    show SceneCastCandidate;
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart'
    as pipeline;
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart'
    as runtime;
import 'package:novel_writer/features/story_generation/domain/literary_quality_models.dart';

void main() {
  test('default pipeline config keeps legacy literary quality gate mode', () {
    const config = GenerationPipelineConfig();
    expect(config.literaryQualityGateMode, LiteraryQualityGateMode.legacy95);
  });

  test(
    'brief adapter maps explicit canonical parents and ignores metadata',
    () {
      final brief = _brief(
        metadata: {
          'projectCharterHash': 'metadata-charter',
          'arcContractHash': 'metadata-arc',
          'previousAcceptedSceneContractHash': 'metadata-prev-scene',
          'corePromiseId': 'metadata-promise',
          'phaseGoalId': 'metadata-phase',
          'sourceLedgerHash': 'metadata-source-ledger',
          'repairBudget': 99,
          'replanBudget': 99,
          'castIds': ['metadata-cast'],
        },
      );

      final contract = sceneNarrativeContractFromBrief(
        brief,
        sceneContractId: 'scene-contract-1',
        projectCharterHash: 'explicit-charter',
        arcContractHash: 'explicit-arc',
        previousAcceptedSceneContractHash: 'explicit-prev-scene',
        corePromiseId: 'explicit-promise',
        phaseGoalId: 'explicit-phase',
        sceneContribution: 'explicit scene contribution',
        povPolicy: _povPolicy(),
        worldRuleRefs: ['rule-b', 'rule-a'],
        requiredFactRefs: ['fact-1'],
        forbiddenContradictions: ['no-contradiction'],
        activePromiseIds: ['promise-a'],
        payoffWindowIds: ['payoff-a'],
        requiredStateChangeTypes: ['relationship'],
        sourceLedgerHash: 'explicit-source-ledger',
        repairBudget: 2,
        replanBudget: 1,
      );

      expect(contract.chapterId, 'chapter-1');
      expect(contract.sceneId, 'scene-1');
      expect(contract.sceneIndex, 3);
      expect(contract.projectCharterHash, 'explicit-charter');
      expect(contract.arcContractHash, 'explicit-arc');
      expect(contract.previousAcceptedSceneContractHash, 'explicit-prev-scene');
      expect(contract.corePromiseId, 'explicit-promise');
      expect(contract.phaseGoalId, 'explicit-phase');
      expect(contract.sourceLedgerHash, 'explicit-source-ledger');
      expect(contract.repairBudget, 2);
      expect(contract.replanBudget, 1);
      expect(contract.castIds, ['char-a', 'char-b']);
      expect(contract.worldRuleRefs, ['rule-a', 'rule-b']);
      expect(contract.sceneContractHash, contract.canonicalHash);

      final roundTripped = SceneNarrativeContract.fromJson(
        jsonDecode(jsonEncode(contract.toJson())) as Map<String, Object?>,
      );
      expect(roundTripped.toJson(), contract.toJson());

      final tampered = Map<String, Object?>.from(contract.toJson())
        ..['sceneContractHash'] = 'tampered';
      expect(
        () => SceneNarrativeContract.fromJson(tampered),
        throwsArgumentError,
      );
    },
  );

  test(
    'director task-card adapter maps task fields and explicit craft facts',
    () {
      final taskCard = runtime.SceneTaskCard(
        sceneGoal: 'force the heir to choose',
        blockingConflict: 'the witness refuses to speak',
        progression: 'the lie collapses into public pressure',
        requiredReveals: ['reveal-witness'],
        requiredWithholds: ['withhold-culprit'],
        constraints: ['metadata-looking voiceProfileHash=wrong'],
        exitCondition: 'heir accepts the cost',
      );

      final contract = sceneCraftContractFromDirectorTaskCard(
        taskCard,
        craftId: 'craft-director',
        sceneContractId: 'scene-contract-1',
        sceneContractHash: 'scene-hash-1',
        voiceProfileId: 'voice-1',
        voiceProfileHash: 'voice-hash-1',
        primaryFunction: SceneFunction.pressurePromise,
        secondaryFunctions: [SceneFunction.revealInformation],
        plannedBeats: ['beat-1', 'beat-2'],
        desiredStateChanges: [_stateChange()],
        readerQuestionBefore: 'will the witness break?',
        readerQuestionAfterTarget: 'what did the heir trade away?',
        pressureCurve: PressureCurve.rising,
        rhythmIntent: _rhythmIntent(),
        invariantsToPreserve: ['keep limited POV'],
        allowedDeviations: [_allowedDeviation()],
        targetedRepairBudget: 1,
        fullRewriteBudget: 0,
      );

      expect(contract.sceneGoal, taskCard.sceneGoal);
      expect(contract.blockingConflict, taskCard.blockingConflict);
      expect(contract.progression, taskCard.progression);
      expect(contract.exitCondition, taskCard.exitCondition);
      expect(contract.requiredReveals, ['reveal-witness']);
      expect(contract.requiredWithholds, ['withhold-culprit']);
      expect(contract.invariantsToPreserve, [
        'keep limited POV',
        'metadata-looking voiceProfileHash=wrong',
      ]);
      expect(contract.voiceProfileHash, 'voice-hash-1');
      expect(contract.readerQuestionBefore, 'will the witness break?');
      expect(
        contract.readerQuestionAfterTarget,
        'what did the heir trade away?',
      );
      expect(contract.pressureCurve, PressureCurve.rising);
      expect(contract.rhythmIntent.pressureMovement, 'tighten');
      expect(contract.craftHash, contract.canonicalHash);

      final roundTripped = SceneCraftContract.fromJson(
        jsonDecode(jsonEncode(contract.toJson())) as Map<String, Object?>,
      );
      expect(roundTripped.toJson(), contract.toJson());

      final tampered = Map<String, Object?>.from(contract.toJson())
        ..['craftHash'] = 'tampered';
      expect(() => SceneCraftContract.fromJson(tampered), throwsArgumentError);
    },
  );

  test('pipeline task-card adapter uses parsed plan and ignores metadata', () {
    final plan = pipeline.SceneDirectorPlan(
      target: 'draw the guard into a mistake',
      conflict: 'the guard knows the corridor better',
      progression: 'a false retreat exposes the patrol rhythm',
      constraints: 'no exposition / keep tension local',
    );
    final taskCard = pipeline.SceneTaskCard(
      brief: _brief(),
      cast: const [],
      directorPlan: 'untrusted text plan',
      directorPlanParsed: plan,
      metadata: {
        'voiceProfileHash': 'metadata-voice',
        'readerQuestionBefore': 'metadata-question',
        'exitCondition': 'metadata-exit',
      },
    );

    final contract = sceneCraftContractFromPipelineTaskCard(
      taskCard,
      craftId: 'craft-pipeline',
      sceneContractId: 'scene-contract-2',
      sceneContractHash: 'scene-hash-2',
      voiceProfileId: 'voice-2',
      voiceProfileHash: 'explicit-voice-hash',
      primaryFunction: SceneFunction.advancePlot,
      requiredReveals: ['reveal-patrol'],
      requiredWithholds: ['withhold-map'],
      exitCondition: 'guard leaves the west gate',
      readerQuestionBefore: 'can the retreat work?',
      readerQuestionAfterTarget: 'who noticed the pattern?',
      pressureCurve: PressureCurve.wave,
      rhythmIntent: _rhythmIntent(sceneFunction: SceneFunction.advancePlot),
      invariantsToPreserve: ['no omniscient knowledge'],
      targetedRepairBudget: 2,
      fullRewriteBudget: 1,
    );

    expect(contract.sceneGoal, plan.target);
    expect(contract.blockingConflict, plan.conflict);
    expect(contract.progression, plan.progression);
    expect(contract.exitCondition, 'guard leaves the west gate');
    expect(contract.voiceProfileHash, 'explicit-voice-hash');
    expect(contract.readerQuestionBefore, 'can the retreat work?');
    expect(contract.requiredReveals, ['reveal-patrol']);
    expect(contract.requiredWithholds, ['withhold-map']);
    expect(contract.invariantsToPreserve, [
      'keep tension local',
      'no exposition',
      'no omniscient knowledge',
    ]);
  });

  test('director-plan adapter preserves plan fields and requires a plan', () {
    final plan = pipeline.SceneDirectorPlan(
      target: 'make the promise visible',
      conflict: 'the ally wants a quieter path',
      progression: 'argument turns into a shared risk',
      constraints: 'short paragraphs；no lore dump',
    );

    final contract = sceneCraftContractFromDirectorPlan(
      plan,
      craftId: 'craft-plan',
      sceneContractId: 'scene-contract-3',
      sceneContractHash: 'scene-hash-3',
      voiceProfileId: 'voice-3',
      voiceProfileHash: 'voice-hash-3',
      primaryFunction: SceneFunction.plantPromise,
      exitCondition: 'ally accepts the promise',
      readerQuestionBefore: 'will the ally refuse?',
      readerQuestionAfterTarget: 'what promise now matters?',
      pressureCurve: PressureCurve.plateauWithReason,
      rhythmIntent: _rhythmIntent(sceneFunction: SceneFunction.plantPromise),
      targetedRepairBudget: 1,
      fullRewriteBudget: 1,
    );

    expect(contract.sceneGoal, plan.target);
    expect(contract.blockingConflict, plan.conflict);
    expect(contract.progression, plan.progression);
    expect(contract.invariantsToPreserve, ['no lore dump', 'short paragraphs']);

    final missingPlanCard = pipeline.SceneTaskCard(
      brief: _brief(),
      cast: const [],
      directorPlan: 'text-only',
    );
    expect(
      () => sceneCraftContractFromPipelineTaskCard(
        missingPlanCard,
        craftId: 'craft-missing',
        sceneContractId: 'scene-contract-4',
        sceneContractHash: 'scene-hash-4',
        voiceProfileId: 'voice-4',
        voiceProfileHash: 'voice-hash-4',
        primaryFunction: SceneFunction.transition,
        exitCondition: 'done',
        readerQuestionBefore: 'before?',
        readerQuestionAfterTarget: 'after?',
        pressureCurve: PressureCurve.falling,
        rhythmIntent: _rhythmIntent(sceneFunction: SceneFunction.transition),
        targetedRepairBudget: 0,
        fullRewriteBudget: 0,
      ),
      throwsArgumentError,
    );
  });
}

runtime.SceneBrief _brief({Map<String, Object?> metadata = const {}}) {
  return runtime.SceneBrief(
    chapterId: 'chapter-1',
    chapterTitle: '第一章',
    sceneId: 'scene-1',
    sceneTitle: '旧桥',
    sceneSummary: '角色在旧桥下交锋。',
    sceneIndex: 3,
    cast: [
      SceneCastCandidate(characterId: 'char-b', name: '乙', role: '对手'),
      SceneCastCandidate(characterId: 'char-a', name: '甲', role: '主角'),
    ],
    metadata: metadata,
  );
}

PovPolicy _povPolicy() {
  return PovPolicy(
    mode: PovMode.thirdPersonLimited,
    allowedPovCharacterIds: ['char-a'],
    allowFreeIndirectDiscourse: true,
    allowUnreliableNarrator: false,
    allowTimelineReordering: false,
  );
}

RhythmIntent _rhythmIntent({
  SceneFunction sceneFunction = SceneFunction.pressurePromise,
}) {
  return RhythmIntent(
    sceneFunction: sceneFunction,
    pressureMovement: 'tighten',
    intendedReaderEffect: 'anticipation',
    allowedDeviationIds: ['dev-1'],
  );
}

StateChangeTarget _stateChange() {
  return StateChangeTarget(
    targetId: 'relationship-a-b',
    type: StateChangeType.relationship,
    beforeRef: 'before-rel',
    intendedAfter: 'public trust cracks',
    required: true,
  );
}

AllowedDeviation _allowedDeviation() {
  return AllowedDeviation(
    deviationId: 'dev-1',
    axis: 'rhythm',
    intendedFunction: 'pressure spike',
    startCondition: 'witness enters',
    endCondition: 'witness exits',
    authorizedBy: DeviationAuthorization.independentReview,
  );
}
