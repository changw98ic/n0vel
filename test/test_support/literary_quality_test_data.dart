import 'package:novel_writer/features/story_generation/data/scene_literary_quality_evaluator.dart';
import 'package:novel_writer/features/story_generation/domain/literary_quality_models.dart';

final class LiteraryQualityTestAuthority {
  const LiteraryQualityTestAuthority({
    required this.contractChain,
    required this.voiceProfile,
    required this.sceneCraftContract,
  });

  final NarrativeContractChain contractChain;
  final ProjectVoiceProfile voiceProfile;
  final SceneCraftContract sceneCraftContract;
}

LiteraryQualityTestAuthority buildLiteraryQualityTestAuthority({
  DeviationAuthorization deviationAuthorization =
      DeviationAuthorization.sceneContract,
}) {
  final charter = ProjectNarrativeCharter.create(
    schemaVersion: 1,
    charterId: 'charter-1',
    revision: 1,
    projectId: 'project-1',
    corePromiseId: 'promise-1',
    corePromiseStatement: '柳溪必须在零点前公开港务底册。',
    centralTensionIds: const ['tension-1'],
    invariantWorldRuleRefs: const ['rule-1'],
    invariantPovRules: const ['pov-1'],
    transformationPolicy: '从自保转向承担证据公开的代价。',
  );
  final arc = ArcContract.create(
    schemaVersion: 1,
    arcContractId: 'arc-contract-1',
    revision: 1,
    projectCharterId: charter.charterId,
    projectCharterHash: charter.charterHash,
    arcId: 'arc-1',
    phaseGoalId: 'phase-1',
    phaseGoalStatement: '穿过封锁线，把底册送上云端。',
    currentNarrativeQuestion: '柳溪是否愿意把沈渡置于风险中？',
    entryCondition: '码头出口被封。',
    exitCondition: '底册离开本地控制。',
    activePromiseIds: const ['promise-1'],
    payoffWindowIds: const ['payoff-1'],
  );
  final scene = SceneNarrativeContract.create(
    schemaVersion: 1,
    sceneContractId: 'scene-contract-1',
    revision: 1,
    projectCharterHash: charter.charterHash,
    arcContractHash: arc.arcContractHash,
    previousAcceptedSceneContractHash: 'scene-contract-previous',
    corePromiseId: charter.corePromiseId,
    phaseGoalId: arc.phaseGoalId,
    chapterId: 'chapter-1',
    sceneId: 'scene-1',
    sceneIndex: 1,
    sceneContribution: '柳溪以暴露位置为代价取到底册。',
    povPolicy: PovPolicy(
      mode: PovMode.thirdPersonLimited,
      allowedPovCharacterIds: const ['liuxi'],
      allowFreeIndirectDiscourse: true,
      allowUnreliableNarrator: false,
      allowTimelineReordering: false,
    ),
    worldRuleRefs: const ['rule-1'],
    requiredFactRefs: const ['fact-blue-locker'],
    forbiddenContradictions: const ['底册不得凭空转移'],
    activePromiseIds: const ['promise-1'],
    payoffWindowIds: const ['payoff-1'],
    requiredStateChangeTypes: const ['knowledge', 'relationship'],
    castIds: const ['liuxi', 'shendu'],
    sourceLedgerHash: 'ledger-snapshot-1',
    repairBudget: 2,
    replanBudget: 1,
  );
  final deviation = AllowedDeviation(
    deviationId: 'deviation-pressure-burst',
    axis: 'rhythm',
    intendedFunction: '在追兵抵达时短暂压缩句长。',
    startCondition: '脚步进入走廊。',
    endCondition: '柳溪离开柜机巷。',
    authorizedBy: deviationAuthorization,
  );
  final voice = ProjectVoiceProfile.create(
    schemaVersion: 1,
    profileId: 'voice-1',
    projectId: charter.projectId,
    displayName: '克制的都市悬疑',
    styleIntensity: 67,
    genreTags: const ['suspense'],
    povMode: PovMode.thirdPersonLimited,
    narrativeDistance: NarrativeDistancePolicy.close,
    lexiconRegister: RegisterPolicy.neutral,
    metaphorDomains: const ['weather', 'machinery'],
    sensoryPriorities: const ['sound', 'touch'],
    rhythm: RhythmPolicy(curve: RhythmCurve.wave),
    dialogue: DialoguePolicy(
      ratio: NumericRange(minimum: 0.2, maximum: 0.45, unit: 'ratio'),
      cadence: '短促但不碎裂',
    ),
    descriptionDensity: DensityPolicy(
      descriptionRatio: NumericRange(minimum: 0.2, maximum: 0.4, unit: 'ratio'),
      interiorityRatio: NumericRange(
        minimum: 0.15,
        maximum: 0.35,
        unit: 'ratio',
      ),
      expositionRatio: NumericRange(minimum: 0.05, maximum: 0.2, unit: 'ratio'),
    ),
    emotionalTemperature: EmotionalTemperature.restrained,
    voiceConstraints: [
      VoiceConstraint(
        axis: 'cadence',
        operator: VoiceConstraintOperator.requireContrast,
        value: '压力段短，决策段舒展',
      ),
    ],
    projectOwnedNotes: '避免仿古；让物理动作承担情绪。',
    tabooPatterns: const ['空泛顿悟', '连续排比'],
    allowedDeviations: [deviation],
    promptReleaseHash: 'voice-prompt-release-1',
  );
  final craft = SceneCraftContract.create(
    schemaVersion: 1,
    craftId: 'craft-1',
    sceneContractId: scene.sceneContractId,
    sceneContractHash: scene.sceneContractHash,
    voiceProfileId: voice.profileId,
    voiceProfileHash: voice.profileHash,
    revision: 1,
    primaryFunction: SceneFunction.advancePlot,
    secondaryFunctions: const [SceneFunction.alterRelationship],
    sceneGoal: '从蓝色柜机取出底册。',
    blockingConflict: '柜机开锁会向追兵暴露位置。',
    progression: '潜入转为公开追逐。',
    exitCondition: '柳溪拿到底册并接受暴露位置的代价。',
    plannedBeats: const ['确认追兵距离', '开锁', '警报触发', '携册撤离'],
    desiredStateChanges: [
      StateChangeTarget(
        targetId: 'relationship-liuxi-shendu',
        type: StateChangeType.relationship,
        beforeRef: '互相试探',
        intendedAfter: '条件性信任',
        required: true,
      ),
    ],
    requiredReveals: const ['柜机报警器仍在工作'],
    requiredWithholds: const ['沈渡真实雇主'],
    readerQuestionBefore: '开锁是否会暴露柳溪？',
    readerQuestionAfterTarget: '沈渡会不会利用她暴露的位置？',
    pressureCurve: PressureCurve.rising,
    rhythmIntent: RhythmIntent(
      sceneFunction: SceneFunction.advancePlot,
      pressureMovement: '持续上升，开锁时陡增',
      intendedReaderEffect: '紧张后带着不完全释放',
      allowedDeviationIds: const ['deviation-pressure-burst'],
    ),
    invariantsToPreserve: const ['promise-1', 'rule-1'],
    allowedDeviations: [deviation],
    targetedRepairBudget: 2,
    fullRewriteBudget: 0,
  );
  return LiteraryQualityTestAuthority(
    contractChain: NarrativeContractChain(
      projectCharter: charter,
      arcContract: arc,
      sceneContract: scene,
    ),
    voiceProfile: voice,
    sceneCraftContract: craft,
  );
}

SceneLiteraryQualityEvaluationInput buildLiteraryQualityEvaluationInput({
  required String prose,
  required String promptReleaseHash,
  String evaluatorModelRelease = 'evaluator-model-1',
  double historicalOverallLowerBound = 0.82,
  double repeatAgreementConfidence = 0.80,
  DeviationAuthorization deviationAuthorization =
      DeviationAuthorization.sceneContract,
}) {
  final authority = buildLiteraryQualityTestAuthority(
    deviationAuthorization: deviationAuthorization,
  );
  final certification = EvaluatorPolicyCertification(
    certificationId: 'development-cert-1',
    rubricVersion: 'scene-literary-quality-rubric-v1',
    promptReleaseHash: promptReleaseHash,
    evaluatorModelRelease: evaluatorModelRelease,
    thresholdPolicyVersion: 'threshold-policy-v1-calibration',
    status: EvaluatorPolicyCertificationStatus.development,
    calibrationArtifactHash: 'development-calibration-artifact-1',
    blindReviewArtifactHash: 'development-blind-review-pending-1',
    certifiedAtMs: 0,
  );
  return SceneLiteraryQualityEvaluationInput(
    prose: prose,
    contractChain: authority.contractChain,
    voiceProfile: authority.voiceProfile,
    sceneCraftContract: authority.sceneCraftContract,
    ledgerSnapshotHash: 'ledger-snapshot-1',
    deterministicGate: DeterministicGateRef(
      evidenceHash: 'deterministic-evidence-1',
      passed: true,
    ),
    rubricVersion: 'scene-literary-quality-rubric-v1',
    calibration: SceneLiteraryQualityCalibration(
      certification: certification,
      historicalOverallLowerBound: historicalOverallLowerBound,
      findingClassLowerBounds: const {
        QualityFindingClass.hardError: 0.91,
        QualityFindingClass.craftWeakness: 0.84,
        QualityFindingClass.styleChoice: 0.88,
        QualityFindingClass.effectiveDeviation: 0.86,
      },
      repeatAgreementConfidence: repeatAgreementConfidence,
    ),
    createdAtMs: 1,
  );
}

Map<String, Object?> cleanLiteraryQualityModelOutput({
  double evaluatorSelfConfidence = 0.99,
}) => {
  'schemaVersion': 1,
  'semanticHardReview': {'passed': true, 'hardFindingIds': <String>[]},
  'craft': <String, Object?>{
    'dimensions': <String, Object?>{
      'prosePrecision': 96,
      'paragraphFunction': 95,
      'scenePressure': 96,
      'characterVoice': 95,
      'informationControl': 95,
      'coherence': 97,
      'completenessAndTurn': 96,
    },
  },
  'styleFit': {
    'decision': 'aligned',
    'axisExplanations': <String, String>{},
    'deviationIds': <String>[],
    'evidenceRefs': <String>[],
    'deviationAuthorizationRefs': <Object?>[],
  },
  'readerEffect': {
    'effectEstimates': {
      for (final key in const [
        'tension',
        'clarity',
        'curiosity',
        'emotionalImpact',
        'momentum',
      ])
        key: {'value': 90, 'evidenceRefs': <String>[]},
    },
    'warnings': <String>[],
  },
  'findings': <Object?>[],
  'evaluatorSelfConfidence': evaluatorSelfConfidence,
};
