import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_policy.dart';
import 'package:novel_writer/features/story_generation/domain/literary_quality_models.dart';

QualityFinding _majorFinding() {
  return QualityFinding(
    findingId: 'finding-major',
    findingClass: QualityFindingClass.craftWeakness,
    severity: QualitySeverity.major,
    axis: QualityAxis.prose,
    code: 'major-drift',
    claim: '节奏偏差影响整体阅读感',
    evidence: [
      TextEvidenceSpan(
        startOffset: 0,
        endOffset: 4,
        excerptDigest: 'digest-1',
        localExcerpt: '文本',
      ),
    ],
    calibratedConfidence: 0.91,
    suggestedAction: RepairAction.targetedRepair,
  );
}

QualityFinding _hardFinding() {
  return QualityFinding(
    findingId: 'finding-hard',
    findingClass: QualityFindingClass.hardError,
    severity: QualitySeverity.blocker,
    axis: QualityAxis.corePromise,
    code: 'core-promise-conflict',
    claim: '正文违背固定主线',
    contractRefs: const ['scene-contract-1'],
    calibratedConfidence: 0.93,
    suggestedAction: RepairAction.blockAndReplan,
  );
}

StyleFitResult _styleFitResult(StyleFitDecision decision) => switch (decision) {
  StyleFitDecision.aligned => StyleFitResult(decision: decision),
  StyleFitDecision.mismatch => StyleFitResult(
    decision: decision,
    axisExplanations: const {'rhythm': 'The cadence breaks the project norm.'},
    evidenceRefs: const ['style-evidence-1'],
  ),
  StyleFitDecision.plannedDeviation => StyleFitResult(
    decision: decision,
    axisExplanations: const {
      'rhythm': 'The scene contract plans a short pressure spike.',
    },
    deviationIds: const ['deviation-1'],
    evidenceRefs: const ['scene-craft-contract-1'],
    deviationAuthorizationRefs: [
      DeviationAuthorizationRef(
        authorizedBy: DeviationAuthorization.sceneContract,
        referenceId: 'deviation-1',
      ),
    ],
  ),
  StyleFitDecision.approvedDeviation => StyleFitResult(
    decision: decision,
    axisExplanations: const {
      'rhythm': 'Independent review approved the functional deviation.',
    },
    deviationIds: const ['deviation-1'],
    evidenceRefs: const ['review-1'],
    deviationAuthorizationRefs: [
      DeviationAuthorizationRef(
        authorizedBy: DeviationAuthorization.independentReview,
        referenceId: 'review-1',
      ),
    ],
  ),
};

LiteraryQualityPolicyInput _baseInput({
  bool evaluationValid = true,
  double craftOverall = 93,
  double criticalCraftMinimum = 90,
  double calibratedConfidence = 0.8,
  List<QualityFinding> findings = const [],
  StyleFitDecision styleFit = StyleFitDecision.aligned,
  bool independentRescoreCompleted = true,
  bool deterministicHardGatePassed = true,
  bool semanticHardReviewPassed = true,
  bool reviewerClassConflict = false,
  double reviewerScoreSpread = 0,
  double maxAllowedReviewerScoreSpread = 8,
  bool explicitLowConfidence = false,
  int repairBudgetRemaining = 1,
  bool evaluatorPolicyCertified = false,
  bool dualReviewersAgree = false,
  List<double> reviewerCalibratedConfidences = const [0.82, 0.84],
  bool authorRequestedManualReview = false,
  String evaluatorCertificationId = 'cert-1',
}) {
  return LiteraryQualityPolicyInput(
    evaluationValid: evaluationValid,
    craftOverall: craftOverall,
    criticalCraftMinimum: criticalCraftMinimum,
    calibratedConfidence: calibratedConfidence,
    findings: findings,
    styleFit: _styleFitResult(styleFit),
    independentRescoreCompleted: independentRescoreCompleted,
    deterministicHardGatePassed: deterministicHardGatePassed,
    semanticHardReviewPassed: semanticHardReviewPassed,
    reviewerClassConflict: reviewerClassConflict,
    reviewerScoreSpread: reviewerScoreSpread,
    maxAllowedReviewerScoreSpread: maxAllowedReviewerScoreSpread,
    explicitLowConfidence: explicitLowConfidence,
    repairBudgetRemaining: repairBudgetRemaining,
    evaluatorPolicyCertified: evaluatorPolicyCertified,
    dualReviewersAgree: dualReviewersAgree,
    reviewerCalibratedConfidences: reviewerCalibratedConfidences,
    authorRequestedManualReview: authorRequestedManualReview,
    evaluatorCertificationId: evaluatorCertificationId,
  );
}

ProjectNarrativeCharter _transitionCharter({
  int revision = 1,
  String? previousCharterHash,
  String corePromiseId = 'promise-1',
  String? transitionReceiptId,
}) => ProjectNarrativeCharter.create(
  schemaVersion: 1,
  charterId: 'charter-1',
  revision: revision,
  previousCharterHash: previousCharterHash,
  projectId: 'project-1',
  corePromiseId: corePromiseId,
  corePromiseStatement: 'The protagonist must choose duty or freedom.',
  centralTensionIds: const ['tension-1'],
  invariantWorldRuleRefs: const ['rule-1'],
  invariantPovRules: const ['pov-1'],
  transformationPolicy: 'Defence becomes agency.',
  transitionReceiptId: transitionReceiptId,
);

ArcContract _transitionArc(
  ProjectNarrativeCharter charter, {
  int revision = 1,
  String? previousArcContractHash,
  String phaseGoalId = 'phase-1',
  String? transitionReceiptId,
}) => ArcContract.create(
  schemaVersion: 1,
  arcContractId: 'arc-contract-1',
  revision: revision,
  projectCharterId: charter.charterId,
  projectCharterHash: charter.charterHash,
  previousArcContractHash: previousArcContractHash,
  arcId: 'arc-main',
  phaseGoalId: phaseGoalId,
  phaseGoalStatement: 'Escape the occupied district.',
  currentNarrativeQuestion: 'Can the protagonist trust the guide?',
  entryCondition: 'The bridge is sealed.',
  exitCondition: 'A route is chosen.',
  activePromiseIds: const ['promise-1'],
  payoffWindowIds: const ['payoff-1'],
  transitionReceiptId: transitionReceiptId,
);

SceneNarrativeContract _transitionScene(
  ProjectNarrativeCharter charter,
  ArcContract arc, {
  required String previousAcceptedSceneContractHash,
  String sceneContractId = 'scene-contract-1',
  String sceneId = 'scene-1',
  int sceneIndex = 1,
}) => SceneNarrativeContract.create(
  schemaVersion: 1,
  sceneContractId: sceneContractId,
  revision: 1,
  projectCharterHash: charter.charterHash,
  arcContractHash: arc.arcContractHash,
  previousAcceptedSceneContractHash: previousAcceptedSceneContractHash,
  corePromiseId: charter.corePromiseId,
  phaseGoalId: arc.phaseGoalId,
  chapterId: 'chapter-1',
  sceneId: sceneId,
  sceneIndex: sceneIndex,
  sceneContribution: 'The rivals choose a route beneath the bridge.',
  povPolicy: PovPolicy(
    mode: PovMode.thirdPersonLimited,
    allowedPovCharacterIds: const ['character-1'],
    allowFreeIndirectDiscourse: true,
    allowUnreliableNarrator: false,
    allowTimelineReordering: false,
  ),
  worldRuleRefs: const ['rule-1'],
  activePromiseIds: const ['promise-1'],
  payoffWindowIds: const ['payoff-1'],
  requiredStateChangeTypes: const ['knowledge'],
  castIds: const ['character-1'],
  sourceLedgerHash: 'ledger-1',
  repairBudget: 1,
  replanBudget: 1,
);

NarrativeContractChain _transitionChain(
  ProjectNarrativeCharter charter,
  ArcContract arc,
  SceneNarrativeContract scene,
) => NarrativeContractChain(
  projectCharter: charter,
  arcContract: arc,
  sceneContract: scene,
);

void main() {
  test('settings round-trip and unknown enum values fail closed', () {
    final defaults = LiteraryQualitySettings.fromJson(const {});
    expect(defaults.toJson(), LiteraryQualitySettings.defaults.toJson());
    expect(defaults.qualityGateMode, LiteraryQualityGateMode.legacy95);

    const settings = LiteraryQualitySettings(
      strictness: QualityStrictness.publication,
      autoRepair: AutoRepairMode.fullAllowed,
      readerEffect: ReaderEffectMode.milestone,
      referenceUsage: ReferenceUsage.abstractFeaturesOnly,
      styleIntensity: 88,
      qualityGateMode: LiteraryQualityGateMode.enforceV2,
    );

    final json = settings.toJson();
    final restored = LiteraryQualitySettings.fromJson(json);
    expect(restored.toJson(), json);

    expect(
      () => LiteraryQualitySettings.fromJson({'qualityGateMode': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => LiteraryQualitySettings.fromJson({'strictness': 'nearlyStrict'}),
      throwsFormatException,
    );
    expect(
      () => LiteraryQualitySettings.fromJson({'styleIntensity': 101}),
      throwsFormatException,
    );
  });

  test('default pipeline config keeps the legacy gate mode', () {
    const config = GenerationPipelineConfig();
    expect(config.literaryQualityGateMode, LiteraryQualityGateMode.legacy95);
    expect(config.hardGatesEnabled, isTrue);
  });

  test('invalid evaluation requires rescore before manual review', () {
    final withoutRescore = LiteraryQualityPolicy.decide(
      _baseInput(evaluationValid: false, independentRescoreCompleted: false),
    );
    expect(
      withoutRescore.action,
      LiteraryQualityPolicyAction.independentRescoreRequired,
    );
    expect(withoutRescore.status, SceneCandidateStatus.manualReview);
    expect(withoutRescore.requiresIndependentRescore, isTrue);

    final afterRescore = LiteraryQualityPolicy.decide(
      _baseInput(evaluationValid: false, independentRescoreCompleted: true),
    );
    expect(afterRescore.action, LiteraryQualityPolicyAction.manualReview);
    expect(afterRescore.status, SceneCandidateStatus.manualReview);
    expect(afterRescore.requiresIndependentRescore, isFalse);
  });

  test('incoherent and non-finite policy inputs fail closed', () {
    for (final input in [
      _baseInput(craftOverall: 90, criticalCraftMinimum: 91),
      _baseInput(reviewerScoreSpread: double.nan),
      _baseInput(maxAllowedReviewerScoreSpread: double.infinity),
    ]) {
      final outcome = LiteraryQualityPolicy.decide(input);
      expect(outcome.status, SceneCandidateStatus.manualReview);
      expect(outcome.reasonCode, 'invalidAfterIndependentRescore');
      expect(
        LiteraryQualityPolicy.v2BlocksCandidateFinalization(
          gateMode: LiteraryQualityGateMode.enforceV2,
          status: outcome.status,
        ),
        isTrue,
      );
    }
  });

  test('hard gates and hard findings beat otherwise releasable scores', () {
    final blocked = LiteraryQualityPolicy.decide(
      _baseInput(deterministicHardGatePassed: false),
    );
    expect(blocked.action, LiteraryQualityPolicyAction.blocked);
    expect(blocked.status, SceneCandidateStatus.blocked);
    expect(
      LiteraryQualityPolicy.v2BlocksCandidateFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: blocked.status,
      ),
      isTrue,
    );

    final hardFinding = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 99,
        criticalCraftMinimum: 99,
        findings: [_hardFinding()],
        evaluatorPolicyCertified: true,
        dualReviewersAgree: true,
      ),
    );
    expect(hardFinding.status, SceneCandidateStatus.blocked);
    expect(hardFinding.reasonCode, 'hardGateOrHardError');
  });

  test('reviewer conflict and low confidence route to manual review', () {
    final conflict = LiteraryQualityPolicy.decide(
      _baseInput(reviewerClassConflict: true),
    );
    expect(conflict.action, LiteraryQualityPolicyAction.manualReview);
    expect(conflict.status, SceneCandidateStatus.manualReview);

    final spread = LiteraryQualityPolicy.decide(
      _baseInput(reviewerScoreSpread: 10),
    );
    expect(spread.status, SceneCandidateStatus.manualReview);
    expect(spread.reasonCode, 'reviewerConflictOrLowConfidence');

    final lowConfidence = LiteraryQualityPolicy.decide(
      _baseInput(explicitLowConfidence: true),
    );
    expect(lowConfidence.action, LiteraryQualityPolicyAction.manualReview);
    expect(lowConfidence.status, SceneCandidateStatus.manualReview);
  });

  test(
    'low scores without actionable evidence require independent rescore',
    () {
      final lowCraft = LiteraryQualityPolicy.decide(
        _baseInput(
          craftOverall: 84.9,
          criticalCraftMinimum: 84.9,
          independentRescoreCompleted: false,
        ),
      );
      expect(
        lowCraft.action,
        LiteraryQualityPolicyAction.independentRescoreRequired,
      );
      expect(lowCraft.status, SceneCandidateStatus.manualReview);
      expect(lowCraft.reasonCode, 'invalidEvaluation');
      expect(lowCraft.requiresIndependentRescore, isTrue);

      final lowCriticalAfterRescore = LiteraryQualityPolicy.decide(
        _baseInput(craftOverall: 90, criticalCraftMinimum: 79.9),
      );
      expect(
        lowCriticalAfterRescore.action,
        LiteraryQualityPolicyAction.manualReview,
      );
      expect(
        lowCriticalAfterRescore.reasonCode,
        'invalidAfterIndependentRescore',
      );
    },
  );

  test(
    'repair requires actionable low-score evidence or a concrete mismatch',
    () {
      final lowCraft = LiteraryQualityPolicy.decide(
        _baseInput(
          craftOverall: 84.9,
          criticalCraftMinimum: 84.9,
          findings: [_majorFinding()],
        ),
      );
      expect(lowCraft.action, LiteraryQualityPolicyAction.repairRequired);
      expect(lowCraft.status, SceneCandidateStatus.repairRequired);

      final lowCritical = LiteraryQualityPolicy.decide(
        _baseInput(
          craftOverall: 90,
          criticalCraftMinimum: 79.9,
          findings: [_majorFinding()],
        ),
      );
      expect(lowCritical.action, LiteraryQualityPolicyAction.repairRequired);
      expect(lowCritical.reasonCode, 'criticalCraftBelow80');

      final styleMismatch = LiteraryQualityPolicy.decide(
        _baseInput(styleFit: StyleFitDecision.mismatch),
      );
      expect(styleMismatch.status, SceneCandidateStatus.repairRequired);
      expect(styleMismatch.reasonCode, 'unapprovedStyleMismatch');

      final majorFinding = LiteraryQualityPolicy.decide(
        _baseInput(
          craftOverall: 95,
          criticalCraftMinimum: 95,
          findings: [_majorFinding()],
        ),
      );
      expect(majorFinding.status, SceneCandidateStatus.repairRequired);
      expect(majorFinding.reasonCode, 'majorFindingLimitExceeded');
    },
  );

  test('repair budget exhaustion falls back to manual review', () {
    final outcome = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 84.9,
        criticalCraftMinimum: 84.9,
        findings: [_majorFinding()],
        repairBudgetRemaining: 0,
      ),
    );
    expect(outcome.action, LiteraryQualityPolicyAction.manualReview);
    expect(outcome.status, SceneCandidateStatus.manualReview);
    expect(outcome.reasonCode, 'repairBudgetExhausted');
  });

  test('candidate statuses follow the published score bands', () {
    final draftKeep = LiteraryQualityPolicy.decide(
      _baseInput(craftOverall: 89.9, criticalCraftMinimum: 89.9),
    );
    expect(draftKeep.status, SceneCandidateStatus.draftKeep);
    expect(draftKeep.action, LiteraryQualityPolicyAction.draftKeep);

    final autoCandidate = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 90,
        criticalCraftMinimum: 90,
        calibratedConfidence: 0.70,
      ),
    );
    expect(autoCandidate.status, SceneCandidateStatus.autoCandidate);
    expect(
      LiteraryQualityPolicy.v2BlocksCandidateFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: autoCandidate.status,
      ),
      isFalse,
    );

    final highCandidate = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 92,
        criticalCraftMinimum: 92,
        calibratedConfidence: 0.75,
      ),
    );
    expect(highCandidate.status, SceneCandidateStatus.highCandidate);
    expect(highCandidate.action, LiteraryQualityPolicyAction.candidate);

    final releaseCandidate = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 95,
        criticalCraftMinimum: 90,
        calibratedConfidence: 0.8,
        evaluatorPolicyCertified: true,
        dualReviewersAgree: true,
        reviewerCalibratedConfidences: const [0.80, 0.81],
      ),
    );
    expect(releaseCandidate.status, SceneCandidateStatus.sceneReleaseCandidate);
    expect(
      LiteraryQualityPolicy.v2BlocksCandidateFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: releaseCandidate.status,
      ),
      isFalse,
    );

    final pendingPublication = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 95,
        criticalCraftMinimum: 90,
        calibratedConfidence: 0.8,
      ),
    );
    expect(pendingPublication.status, SceneCandidateStatus.highCandidate);
    expect(pendingPublication.reasonCode, 'publicationReviewPending');
  });

  test('critical minima downgrade to the highest eligible score band', () {
    final cases =
        <
          ({
            double overall,
            double critical,
            SceneCandidateStatus status,
            String reason,
          })
        >[
          (
            overall: 90,
            critical: 84.99,
            status: SceneCandidateStatus.draftKeep,
            reason: 'draftKeep',
          ),
          (
            overall: 90,
            critical: 85,
            status: SceneCandidateStatus.autoCandidate,
            reason: 'autoCandidate',
          ),
          (
            overall: 92,
            critical: 87.99,
            status: SceneCandidateStatus.autoCandidate,
            reason: 'autoCandidate',
          ),
          (
            overall: 92,
            critical: 88,
            status: SceneCandidateStatus.highCandidate,
            reason: 'highCandidate',
          ),
          (
            overall: 95,
            critical: 89.99,
            status: SceneCandidateStatus.highCandidate,
            reason: 'highCandidate',
          ),
          (
            overall: 95,
            critical: 90,
            status: SceneCandidateStatus.highCandidate,
            reason: 'publicationReviewPending',
          ),
        ];

    for (final item in cases) {
      final outcome = LiteraryQualityPolicy.decide(
        _baseInput(
          craftOverall: item.overall,
          criticalCraftMinimum: item.critical,
        ),
      );
      expect(outcome.status, item.status);
      expect(outcome.reasonCode, item.reason);
    }
  });

  test('candidate bands enforce confidence and major-finding limits', () {
    for (final input in [
      _baseInput(
        craftOverall: 90,
        criticalCraftMinimum: 85,
        calibratedConfidence: 0.69,
      ),
      _baseInput(
        craftOverall: 92,
        criticalCraftMinimum: 88,
        calibratedConfidence: 0.74,
      ),
      _baseInput(
        craftOverall: 95,
        criticalCraftMinimum: 90,
        calibratedConfidence: 0.74,
      ),
    ]) {
      expect(
        LiteraryQualityPolicy.decide(input).status,
        SceneCandidateStatus.manualReview,
      );
    }

    for (final input in [
      _baseInput(
        craftOverall: 90,
        criticalCraftMinimum: 85,
        findings: [_majorFinding(), _majorFinding(), _majorFinding()],
      ),
      _baseInput(
        craftOverall: 92,
        criticalCraftMinimum: 88,
        findings: [_majorFinding(), _majorFinding()],
      ),
      _baseInput(
        craftOverall: 95,
        criticalCraftMinimum: 90,
        findings: [_majorFinding()],
      ),
    ]) {
      final outcome = LiteraryQualityPolicy.decide(input);
      expect(outcome.status, SceneCandidateStatus.repairRequired);
      expect(outcome.reasonCode, 'majorFindingLimitExceeded');
    }
  });

  test('major limits follow the critical-downgraded candidate band', () {
    final autoCandidate = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 95,
        criticalCraftMinimum: 85,
        findings: [_majorFinding(), _majorFinding()],
      ),
    );
    expect(autoCandidate.status, SceneCandidateStatus.autoCandidate);

    final highCandidate = LiteraryQualityPolicy.decide(
      _baseInput(
        craftOverall: 95,
        criticalCraftMinimum: 88,
        findings: [_majorFinding()],
      ),
    );
    expect(highCandidate.status, SceneCandidateStatus.highCandidate);
    expect(highCandidate.reasonCode, 'highCandidate');
  });

  test('planned and approved style deviations remain candidate-eligible', () {
    for (final styleFit in [
      StyleFitDecision.plannedDeviation,
      StyleFitDecision.approvedDeviation,
    ]) {
      final outcome = LiteraryQualityPolicy.decide(
        _baseInput(
          craftOverall: 95,
          criticalCraftMinimum: 90,
          styleFit: styleFit,
        ),
      );
      expect(outcome.status, SceneCandidateStatus.highCandidate);
      expect(outcome.reasonCode, 'publicationReviewPending');
    }
  });

  test('gate-mode-aware policy queries stay additive and shadow-safe', () {
    expect(
      LiteraryQualityPolicy.productionDecisionUsesV2(
        LiteraryQualityGateMode.enforceV2,
      ),
      isTrue,
    );
    expect(
      LiteraryQualityPolicy.productionDecisionUsesV2(
        LiteraryQualityGateMode.legacy95,
      ),
      isFalse,
    );

    expect(
      LiteraryQualityPolicy.v2AllowsAutomaticFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: SceneCandidateStatus.autoCandidate,
        strictness: QualityStrictness.standard,
      ),
      isTrue,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsAutomaticFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: SceneCandidateStatus.sceneReleaseCandidate,
        strictness: QualityStrictness.publication,
      ),
      isTrue,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsAutomaticFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: SceneCandidateStatus.sceneReleaseCandidate,
        strictness: QualityStrictness.draft,
      ),
      isFalse,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsAutomaticFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: SceneCandidateStatus.autoCandidate,
        strictness: QualityStrictness.strict,
      ),
      isFalse,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsAutomaticFinalization(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: SceneCandidateStatus.highCandidate,
        strictness: QualityStrictness.publication,
      ),
      isFalse,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsExplicitAcceptance(
        gateMode: LiteraryQualityGateMode.enforceV2,
        status: SceneCandidateStatus.autoCandidate,
      ),
      isTrue,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsAutomaticFinalization(
        gateMode: LiteraryQualityGateMode.shadowV2,
        status: SceneCandidateStatus.sceneReleaseCandidate,
        strictness: QualityStrictness.standard,
      ),
      isFalse,
    );
    expect(
      LiteraryQualityPolicy.v2AllowsExplicitAcceptance(
        gateMode: LiteraryQualityGateMode.legacy95,
        status: SceneCandidateStatus.sceneReleaseCandidate,
      ),
      isFalse,
    );
    expect(
      LiteraryQualityPolicy.v2BlocksCandidateFinalization(
        gateMode: LiteraryQualityGateMode.shadowV2,
        status: SceneCandidateStatus.blocked,
      ),
      isFalse,
    );
  });

  test('transition changes are derived from typed old and new chains', () {
    final charter = _transitionCharter();
    final arc = _transitionArc(charter);
    final scene = _transitionScene(
      charter,
      arc,
      previousAcceptedSceneContractHash: 'genesis-scene',
    );
    final current = _transitionChain(charter, arc, scene);

    final ordinaryScene = _transitionScene(
      charter,
      arc,
      previousAcceptedSceneContractHash: scene.sceneContractHash,
      sceneContractId: 'scene-contract-2',
      sceneId: 'scene-2',
      sceneIndex: 2,
    );
    final ordinary = LiteraryQualityPolicy.validateNarrativeTransitionStructure(
      NarrativeTransitionValidationInput(
        currentChain: current,
        proposedChain: _transitionChain(charter, arc, ordinaryScene),
      ),
    );
    expect(ordinary.structurallyValid, isTrue);
    expect(ordinary.reasonCode, 'ordinarySceneAdvance');

    final nextArc = _transitionArc(
      charter,
      revision: 2,
      previousArcContractHash: arc.arcContractHash,
      phaseGoalId: 'phase-2',
    );
    final nextScene = _transitionScene(
      charter,
      nextArc,
      previousAcceptedSceneContractHash: scene.sceneContractHash,
      sceneContractId: 'scene-contract-2',
      sceneId: 'scene-2',
      sceneIndex: 2,
    );
    final hiddenPhaseChange =
        LiteraryQualityPolicy.validateNarrativeTransitionStructure(
          NarrativeTransitionValidationInput(
            currentChain: current,
            proposedChain: _transitionChain(charter, nextArc, nextScene),
          ),
        );
    expect(hiddenPhaseChange.structurallyValid, isFalse);
    expect(hiddenPhaseChange.reasonCode, 'missingAcceptedTransitionReceipt');
    expect(
      hiddenPhaseChange.requiredTransitionKind,
      NarrativeTransitionKind.phaseAdvance,
    );
  });

  test(
    'transition validation rejects broken parent and revision continuity',
    () {
      final charter = _transitionCharter();
      final arc = _transitionArc(charter);
      final scene = _transitionScene(
        charter,
        arc,
        previousAcceptedSceneContractHash: 'genesis-scene',
      );
      final current = _transitionChain(charter, arc, scene);

      NarrativeTransitionValidationOutcome validate(ArcContract proposedArc) {
        final proposedScene = _transitionScene(
          charter,
          proposedArc,
          previousAcceptedSceneContractHash: scene.sceneContractHash,
          sceneContractId: 'scene-contract-2',
          sceneId: 'scene-2',
          sceneIndex: 2,
        );
        return LiteraryQualityPolicy.validateNarrativeTransitionStructure(
          NarrativeTransitionValidationInput(
            currentChain: current,
            proposedChain: _transitionChain(
              charter,
              proposedArc,
              proposedScene,
            ),
          ),
        );
      }

      expect(
        validate(
          _transitionArc(
            charter,
            revision: 2,
            previousArcContractHash: 'wrong-parent',
            phaseGoalId: 'phase-2',
          ),
        ).reasonCode,
        'transitionParentContinuityMismatch',
      );
      expect(
        validate(
          _transitionArc(
            charter,
            revision: 1,
            previousArcContractHash: arc.arcContractHash,
            phaseGoalId: 'phase-2',
          ),
        ).reasonCode,
        'transitionRevisionMismatch',
      );

      final ordinarySceneWithWrongParent = _transitionScene(
        charter,
        arc,
        previousAcceptedSceneContractHash: 'wrong-scene-parent',
        sceneContractId: 'scene-contract-2',
        sceneId: 'scene-2',
        sceneIndex: 2,
      );
      final wrongSceneParent =
          LiteraryQualityPolicy.validateNarrativeTransitionStructure(
            NarrativeTransitionValidationInput(
              currentChain: current,
              proposedChain: _transitionChain(
                charter,
                arc,
                ordinarySceneWithWrongParent,
              ),
            ),
          );
      expect(wrongSceneParent.reasonCode, 'sceneParentContinuityMismatch');
    },
  );

  test(
    'accepted phase transition binds proposal, receipt, and parent contract',
    () {
      final charter = _transitionCharter();
      final arc = _transitionArc(charter);
      final scene = _transitionScene(
        charter,
        arc,
        previousAcceptedSceneContractHash: 'genesis-scene',
      );
      final current = _transitionChain(charter, arc, scene);
      final nextArc = _transitionArc(
        charter,
        revision: 2,
        previousArcContractHash: arc.arcContractHash,
        phaseGoalId: 'phase-2',
        transitionReceiptId: 'receipt-1',
      );
      final nextScene = _transitionScene(
        charter,
        nextArc,
        previousAcceptedSceneContractHash: scene.sceneContractHash,
        sceneContractId: 'scene-contract-2',
        sceneId: 'scene-2',
        sceneIndex: 2,
      );
      final proposed = _transitionChain(charter, nextArc, nextScene);
      final proposal = NarrativeTransitionProposal(
        proposalId: 'proposal-1',
        fromContractHash: arc.arcContractHash,
        proposedContractHash: nextArc.arcContractHash,
        transitionKind: NarrativeTransitionKind.phaseAdvance,
        reason: 'The first phase is complete.',
        affectedPromiseIds: const ['promise-1'],
        affectedLedgerEntryIds: const ['ledger-1'],
        authorDecision: AuthorDecisionStatus.accepted,
        authorReceiptId: 'receipt-1',
      );
      final receipt = AuthorTransitionReceipt(
        receiptId: 'receipt-1',
        proposalId: proposal.proposalId,
        fromContractHash: proposal.fromContractHash,
        proposedContractHash: proposal.proposedContractHash,
        transitionKind: proposal.transitionKind,
        proposalHash: proposal.proposalHash,
        decision: AuthorDecisionStatus.accepted,
        authorIdHash: 'author-1',
        createdAtMs: 100,
      );

      final valid = LiteraryQualityPolicy.validateNarrativeTransitionStructure(
        NarrativeTransitionValidationInput(
          currentChain: current,
          proposedChain: proposed,
          proposal: proposal,
          receipt: receipt,
        ),
      );
      expect(valid.structurallyValid, isTrue);
      expect(valid.reasonCode, 'acceptedTransitionStructure');

      final receiptHashMismatch =
          LiteraryQualityPolicy.validateNarrativeTransitionStructure(
            NarrativeTransitionValidationInput(
              currentChain: current,
              proposedChain: proposed,
              proposal: proposal,
              receipt: AuthorTransitionReceipt(
                receiptId: receipt.receiptId,
                proposalId: receipt.proposalId,
                fromContractHash: receipt.fromContractHash,
                proposedContractHash: receipt.proposedContractHash,
                transitionKind: receipt.transitionKind,
                proposalHash: 'wrong-proposal-hash',
                decision: AuthorDecisionStatus.accepted,
                authorIdHash: 'author-1',
                createdAtMs: 100,
              ),
            ),
          );
      expect(receiptHashMismatch.structurallyValid, isFalse);
      expect(
        receiptHashMismatch.reasonCode,
        'transitionReceiptBindingMismatch',
      );

      final otherReceiptArc = _transitionArc(
        charter,
        revision: 2,
        previousArcContractHash: arc.arcContractHash,
        phaseGoalId: 'phase-2',
        transitionReceiptId: 'other-receipt',
      );
      final otherReceiptScene = _transitionScene(
        charter,
        otherReceiptArc,
        previousAcceptedSceneContractHash: scene.sceneContractHash,
        sceneContractId: 'scene-contract-2',
        sceneId: 'scene-2',
        sceneIndex: 2,
      );
      final otherReceiptProposal = NarrativeTransitionProposal(
        proposalId: 'proposal-2',
        fromContractHash: arc.arcContractHash,
        proposedContractHash: otherReceiptArc.arcContractHash,
        transitionKind: NarrativeTransitionKind.phaseAdvance,
        reason: 'The first phase is complete.',
        authorDecision: AuthorDecisionStatus.accepted,
        authorReceiptId: 'receipt-1',
      );
      final contractReceiptMismatch =
          LiteraryQualityPolicy.validateNarrativeTransitionStructure(
            NarrativeTransitionValidationInput(
              currentChain: current,
              proposedChain: _transitionChain(
                charter,
                otherReceiptArc,
                otherReceiptScene,
              ),
              proposal: otherReceiptProposal,
              receipt: AuthorTransitionReceipt(
                receiptId: 'receipt-1',
                proposalId: otherReceiptProposal.proposalId,
                fromContractHash: otherReceiptProposal.fromContractHash,
                proposedContractHash: otherReceiptProposal.proposedContractHash,
                transitionKind: otherReceiptProposal.transitionKind,
                proposalHash: otherReceiptProposal.proposalHash,
                decision: AuthorDecisionStatus.accepted,
                authorIdHash: 'author-1',
                createdAtMs: 100,
              ),
            ),
          );
      expect(contractReceiptMismatch.structurallyValid, isFalse);
      expect(
        contractReceiptMismatch.reasonCode,
        'transitionContractReceiptMismatch',
      );
    },
  );

  test('core promise changes derive and bind promiseTransform', () {
    final charter = _transitionCharter();
    final arc = _transitionArc(charter);
    final scene = _transitionScene(
      charter,
      arc,
      previousAcceptedSceneContractHash: 'genesis-scene',
    );
    final current = _transitionChain(charter, arc, scene);
    final nextCharter = _transitionCharter(
      revision: 2,
      previousCharterHash: charter.charterHash,
      corePromiseId: 'promise-2',
      transitionReceiptId: 'receipt-1',
    );
    final nextArc = _transitionArc(
      nextCharter,
      revision: 2,
      previousArcContractHash: arc.arcContractHash,
      transitionReceiptId: 'receipt-1',
    );
    final nextScene = _transitionScene(
      nextCharter,
      nextArc,
      previousAcceptedSceneContractHash: scene.sceneContractHash,
      sceneContractId: 'scene-contract-2',
      sceneId: 'scene-2',
      sceneIndex: 2,
    );
    final proposed = _transitionChain(nextCharter, nextArc, nextScene);

    final bundledPhaseArc = _transitionArc(
      nextCharter,
      revision: 2,
      previousArcContractHash: arc.arcContractHash,
      phaseGoalId: 'phase-2',
      transitionReceiptId: 'receipt-1',
    );
    final bundledPhaseScene = _transitionScene(
      nextCharter,
      bundledPhaseArc,
      previousAcceptedSceneContractHash: scene.sceneContractHash,
      sceneContractId: 'scene-contract-2',
      sceneId: 'scene-2',
      sceneIndex: 2,
    );
    final bundledTransition =
        LiteraryQualityPolicy.validateNarrativeTransitionStructure(
          NarrativeTransitionValidationInput(
            currentChain: current,
            proposedChain: _transitionChain(
              nextCharter,
              bundledPhaseArc,
              bundledPhaseScene,
            ),
          ),
        );
    expect(bundledTransition.structurallyValid, isFalse);
    expect(
      bundledTransition.reasonCode,
      'multipleProtectedTransitionsRequireSeparateReceipts',
    );

    final missingReceipt =
        LiteraryQualityPolicy.validateNarrativeTransitionStructure(
          NarrativeTransitionValidationInput(
            currentChain: current,
            proposedChain: proposed,
          ),
        );
    expect(missingReceipt.structurallyValid, isFalse);
    expect(
      missingReceipt.requiredTransitionKind,
      NarrativeTransitionKind.promiseTransform,
    );

    final proposal = NarrativeTransitionProposal(
      proposalId: 'proposal-promise',
      fromContractHash: charter.charterHash,
      proposedContractHash: nextCharter.charterHash,
      transitionKind: NarrativeTransitionKind.promiseTransform,
      reason: 'The author approved a transformed central promise.',
      affectedPromiseIds: const ['promise-1', 'promise-2'],
      authorDecision: AuthorDecisionStatus.accepted,
      authorReceiptId: 'receipt-1',
    );
    final receipt = AuthorTransitionReceipt(
      receiptId: 'receipt-1',
      proposalId: proposal.proposalId,
      fromContractHash: proposal.fromContractHash,
      proposedContractHash: proposal.proposedContractHash,
      transitionKind: proposal.transitionKind,
      proposalHash: proposal.proposalHash,
      decision: AuthorDecisionStatus.accepted,
      authorIdHash: 'author-1',
      createdAtMs: 101,
    );
    final valid = LiteraryQualityPolicy.validateNarrativeTransitionStructure(
      NarrativeTransitionValidationInput(
        currentChain: current,
        proposedChain: proposed,
        proposal: proposal,
        receipt: receipt,
      ),
    );
    expect(valid.structurallyValid, isTrue);
    expect(valid.reasonCode, 'acceptedTransitionStructure');
  });
}
