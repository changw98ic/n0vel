import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/literary_quality_models.dart';

Map<String, Object?> _jsonCopy(Map<String, Object?> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

ProjectNarrativeCharter _charter() => ProjectNarrativeCharter.create(
  schemaVersion: 1,
  charterId: 'charter-1',
  revision: 1,
  projectId: 'project-1',
  corePromiseId: 'promise-1',
  corePromiseStatement: 'The protagonist must choose duty or freedom.',
  centralTensionIds: ['tension-b', 'tension-a'],
  invariantWorldRuleRefs: ['rule-1'],
  invariantPovRules: ['pov-1'],
  transformationPolicy: 'Defence becomes agency.',
  transitionReceiptId: 'receipt-1',
);

ArcContract _arc(
  ProjectNarrativeCharter charter, {
  String? projectCharterId,
  String? projectCharterHash,
  String phaseGoalId = 'phase-1',
}) => ArcContract.create(
  schemaVersion: 1,
  arcContractId: 'arc-contract-1',
  revision: 1,
  projectCharterId: projectCharterId ?? charter.charterId,
  projectCharterHash: projectCharterHash ?? charter.charterHash,
  arcId: 'arc-main',
  phaseGoalId: phaseGoalId,
  phaseGoalStatement: 'Escape the occupied district.',
  currentNarrativeQuestion: 'Can the protagonist trust the guide?',
  entryCondition: 'The bridge is sealed.',
  exitCondition: 'A route is chosen.',
  activePromiseIds: ['promise-1'],
  payoffWindowIds: ['payoff-1'],
);

PovPolicy _povPolicy({List<String> characterIds = const ['char-a']}) =>
    PovPolicy(
      mode: PovMode.thirdPersonLimited,
      allowedPovCharacterIds: characterIds,
      allowFreeIndirectDiscourse: true,
      allowUnreliableNarrator: false,
      allowTimelineReordering: false,
      declaredKnowledgeExceptions: const ['knowledge-exception-1'],
    );

SceneNarrativeContract _sceneContract(
  ProjectNarrativeCharter charter,
  ArcContract arc, {
  String? projectCharterHash,
  String? arcContractHash,
  String? corePromiseId,
  String? phaseGoalId,
}) => SceneNarrativeContract.create(
  schemaVersion: 1,
  sceneContractId: 'scene-contract-1',
  revision: 1,
  projectCharterHash: projectCharterHash ?? charter.charterHash,
  arcContractHash: arcContractHash ?? arc.arcContractHash,
  previousAcceptedSceneContractHash: 'scene-contract-previous',
  corePromiseId: corePromiseId ?? charter.corePromiseId,
  phaseGoalId: phaseGoalId ?? arc.phaseGoalId,
  chapterId: 'chapter-1',
  sceneId: 'scene-1',
  sceneIndex: 2,
  sceneContribution: 'The rivals confront each other beneath the bridge.',
  povPolicy: _povPolicy(),
  worldRuleRefs: ['rule-2', 'rule-1'],
  requiredFactRefs: ['fact-1'],
  forbiddenContradictions: ['contradiction-1'],
  activePromiseIds: ['promise-1'],
  payoffWindowIds: ['payoff-1'],
  requiredStateChangeTypes: ['relationship', 'knowledge'],
  castIds: ['char-b', 'char-a'],
  sourceLedgerHash: 'ledger-1',
  repairBudget: 1,
  replanBudget: 0,
);

AllowedDeviation _deviation() => AllowedDeviation(
  deviationId: 'deviation-1',
  axis: 'rhythm',
  intendedFunction: 'Increase pressure.',
  startCondition: 'The confrontation begins.',
  endCondition: 'The confrontation resolves.',
  authorizedBy: DeviationAuthorization.independentReview,
);

ProjectVoiceProfile _voiceProfile({
  String displayName = 'Voice profile',
  String projectOwnedNotes = 'Private project notes',
  List<String> provenanceRefs = const ['source-1'],
}) => ProjectVoiceProfile.create(
  schemaVersion: 1,
  profileId: 'voice-1',
  projectId: 'project-1',
  displayName: displayName,
  styleIntensity: 67,
  genreTags: ['speculative'],
  povMode: PovMode.thirdPersonLimited,
  narrativeDistance: NarrativeDistancePolicy.close,
  lexiconRegister: RegisterPolicy.elevated,
  metaphorDomains: ['weather'],
  sensoryPriorities: ['sound'],
  rhythm: RhythmPolicy(curve: RhythmCurve.wave),
  dialogue: DialoguePolicy(
    ratio: NumericRange(minimum: 0.35, maximum: 0.55, unit: 'ratio'),
    cadence: 'short exchanges',
  ),
  descriptionDensity: DensityPolicy(
    descriptionRatio: NumericRange(minimum: 0.20, maximum: 0.35, unit: 'ratio'),
    interiorityRatio: NumericRange(minimum: 0.25, maximum: 0.45, unit: 'ratio'),
    expositionRatio: NumericRange(minimum: 0.10, maximum: 0.20, unit: 'ratio'),
  ),
  emotionalTemperature: EmotionalTemperature.intense,
  voiceConstraints: [
    VoiceConstraint(
      axis: 'tone',
      operator: VoiceConstraintOperator.requireContrast,
      value: 'restrained but sharp',
      sourceIds: ['source-1'],
    ),
  ],
  projectOwnedNotes: projectOwnedNotes,
  tabooPatterns: ['generic cadence'],
  allowedDeviations: [_deviation()],
  provenanceRefs: provenanceRefs,
  promptReleaseHash: 'prompt-release-1',
);

const _craftDimensions = <String, double>{
  'prosePrecision': 100,
  'paragraphFunction': 80,
  'scenePressure': 60,
  'characterVoice': 40,
  'informationControl': 20,
  'coherence': 0,
  'completenessAndTurn': 50,
};

CraftScore _craftScore() => CraftScore(dimensions: _craftDimensions);

SceneCandidateDecision _candidateDecision() => SceneCandidateDecision(
  status: SceneCandidateStatus.highCandidate,
  reasonCode: 'highCandidate',
  craftOverall: _craftScore().craftOverall,
  criticalCraftMinimum: _craftScore().criticalCraftMinimum,
  styleFit: StyleFitDecision.aligned,
  findingIds: ['finding-b', 'finding-a'],
  evaluatorCertificationId: 'certification-1',
);

SceneCraftContract _sceneCraftContract() {
  final charter = _charter();
  final arc = _arc(charter);
  final scene = _sceneContract(charter, arc);
  final voice = _voiceProfile();
  return SceneCraftContract.create(
    schemaVersion: 1,
    craftId: 'craft-1',
    sceneContractId: scene.sceneContractId,
    sceneContractHash: scene.sceneContractHash,
    voiceProfileId: voice.profileId,
    voiceProfileHash: voice.profileHash,
    revision: 1,
    primaryFunction: SceneFunction.alterRelationship,
    secondaryFunctions: [SceneFunction.revealInformation],
    sceneGoal: 'Force the rivals to negotiate.',
    blockingConflict: 'Neither rival trusts the other.',
    progression: 'Threat becomes a conditional bargain.',
    exitCondition: 'Both accept the same route.',
    plannedBeats: ['threat', 'counteroffer', 'bargain'],
    desiredStateChanges: [
      StateChangeTarget(
        targetId: 'relationship-1',
        type: StateChangeType.relationship,
        beforeRef: 'hostile',
        intendedAfter: 'conditional cooperation',
        required: true,
      ),
    ],
    requiredReveals: ['reveal-b', 'reveal-a'],
    requiredWithholds: ['withhold-1'],
    readerQuestionBefore: 'Will either rival yield?',
    readerQuestionAfterTarget: 'Who will betray the bargain first?',
    pressureCurve: PressureCurve.reversal,
    rhythmIntent: RhythmIntent(
      sceneFunction: SceneFunction.alterRelationship,
      pressureMovement: 'rising then released',
      intendedReaderEffect: 'guarded relief',
      allowedDeviationIds: ['deviation-1'],
    ),
    invariantsToPreserve: ['promise-1', 'rule-1'],
    allowedDeviations: [_deviation()],
    targetedRepairBudget: 2,
    fullRewriteBudget: 1,
  );
}

LayeredQualityResult _layeredResult({
  required int createdAtMs,
  StyleFitResult? styleFit,
  List<QualityFinding> findings = const [],
}) {
  final charter = _charter();
  final arc = _arc(charter);
  final scene = _sceneContract(charter, arc);
  final score = _craftScore();
  return LayeredQualityResult.create(
    schemaVersion: 1,
    evidenceId: 'evidence-1',
    proseHash: 'prose-1',
    projectCharterHash: charter.charterHash,
    arcContractHash: arc.arcContractHash,
    sceneContractHash: scene.sceneContractHash,
    voiceProfileHash: _voiceProfile().profileHash,
    ledgerSnapshotHash: 'ledger-1',
    rubricVersion: 'rubric-1',
    promptReleaseHash: 'prompt-release-1',
    thresholdPolicyVersion: 'threshold-policy-1',
    deterministicGate: DeterministicGateRef(
      evidenceHash: 'deterministic-evidence-1',
      passed: true,
    ),
    semanticHardReview: SemanticHardReviewResult(
      passed: true,
      calibratedConfidence: 0.91,
    ),
    craft: score,
    styleFit: styleFit ?? StyleFitResult(decision: StyleFitDecision.aligned),
    readerEffect: ReaderEffectProbeResult(),
    findings: findings,
    evaluatorVerdicts: [
      EvaluatorVerdict(
        evaluatorIdHash: 'evaluator-1',
        evaluatorRelease: 'release-1',
        craftOverall: score.craftOverall,
        calibratedConfidence: 0.83,
      ),
    ],
    calibratedConfidence: 0.88,
    decision: _candidateDecision(),
    createdAtMs: createdAtMs,
  );
}

void main() {
  group('wire parsing and canonical string sets', () {
    test('unknown enum values fail closed', () {
      final povJson = _povPolicy().toJson()..['mode'] = 'futurePovMode';
      expect(
        () => PovPolicy.fromJson(povJson),
        throwsA(isA<FormatException>()),
      );

      final decisionJson = _candidateDecision().toJson()
        ..['status'] = 'futureDecision';
      expect(
        () => SceneCandidateDecision.fromJson(decisionJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('canonical string sets normalize NFC, dedupe, and scalar-sort', () {
      final policy = _povPolicy(
        characterIds: ['\u{10000}', 'e\u0301', '\uE000', '\u00E9', '\u{10000}'],
      );

      expect(policy.allowedPovCharacterIds, ['\u00E9', '\uE000', '\u{10000}']);
      expect(
        () => policy.allowedPovCharacterIds.add('another'),
        throwsUnsupportedError,
      );
      expect(
        () => _povPolicy(characterIds: ['valid', '']),
        throwsArgumentError,
      );
    });
  });

  group('canonical identity and hashes', () {
    test('narrative contract hashes round-trip and reject tampering', () {
      final charter = _charter();
      final arc = _arc(charter);
      final scene = _sceneContract(charter, arc);

      final restoredCharter = ProjectNarrativeCharter.fromJson(
        _jsonCopy(charter.toJson()),
      );
      final restoredArc = ArcContract.fromJson(_jsonCopy(arc.toJson()));
      final restoredScene = SceneNarrativeContract.fromJson(
        _jsonCopy(scene.toJson()),
      );
      expect(restoredCharter.charterHash, charter.charterHash);
      expect(restoredArc.arcContractHash, arc.arcContractHash);
      expect(restoredScene.sceneContractHash, scene.sceneContractHash);

      final tampered = _jsonCopy(charter.toJson())
        ..['corePromiseStatement'] = 'A different promise.';
      expect(
        () => ProjectNarrativeCharter.fromJson(tampered),
        throwsArgumentError,
      );
    });

    test(
      'voice identity includes semantic notes but excludes UI provenance',
      () {
        final left = _voiceProfile(
          displayName: 'UI label A',
          projectOwnedNotes: 'shared notes',
          provenanceRefs: ['source-1'],
        );
        final right = _voiceProfile(
          displayName: 'UI label B',
          projectOwnedNotes: 'shared notes',
          provenanceRefs: ['source-1'],
        );

        expect(left.profileHash, right.profileHash);
        expect(left.identityJson, isNot(contains('displayName')));
        expect(left.identityJson['projectOwnedNotes'], 'shared notes');
        expect(left.identityJson, isNot(contains('provenanceRefs')));

        final semanticNotesLeft = _voiceProfile(
          displayName: 'UI label A',
          projectOwnedNotes: 'private notes A',
          provenanceRefs: ['/Users/alice/private/reference-a.txt'],
        );
        final semanticNotesRight = _voiceProfile(
          displayName: 'UI label A',
          projectOwnedNotes: 'private notes B',
          provenanceRefs: ['C:\\private\\reference-b.txt'],
        );

        expect(
          semanticNotesLeft.profileHash,
          isNot(semanticNotesRight.profileHash),
        );

        final provenanceOnlyLeft = _voiceProfile(
          displayName: 'UI label A',
          projectOwnedNotes: 'same notes',
          provenanceRefs: ['/Users/alice/private/reference-a.txt'],
        );
        final provenanceOnlyRight = _voiceProfile(
          displayName: 'UI label A',
          projectOwnedNotes: 'same notes',
          provenanceRefs: ['C:\\private\\reference-b.txt'],
        );
        expect(provenanceOnlyLeft.profileHash, provenanceOnlyRight.profileHash);

        final tampered = _jsonCopy(left.toJson())..['styleIntensity'] = 68;
        expect(
          () => ProjectVoiceProfile.fromJson(tampered),
          throwsArgumentError,
        );

        final notesTampered = _jsonCopy(left.toJson())
          ..['projectOwnedNotes'] = 'changed without a new profile hash';
        expect(
          () => ProjectVoiceProfile.fromJson(notesTampered),
          throwsArgumentError,
        );
      },
    );
  });

  group('narrative chain and transitions', () {
    test(
      'chain verifies parent identities, facts, and optional chain hash',
      () {
        final charter = _charter();
        final arc = _arc(charter);
        final scene = _sceneContract(charter, arc);
        final chain = NarrativeContractChain(
          projectCharter: charter,
          arcContract: arc,
          sceneContract: scene,
        );

        final serialized = _jsonCopy(chain.toJson());
        expect(
          NarrativeContractChain.fromJson(serialized).chainHash,
          chain.chainHash,
        );
        final legacy = _jsonCopy(serialized)..remove('chainHash');
        expect(
          NarrativeContractChain.fromJson(legacy).chainHash,
          chain.chainHash,
        );
        final tamperedHash = _jsonCopy(serialized)
          ..['chainHash'] = 'wrong-hash';
        expect(
          () => NarrativeContractChain.fromJson(tamperedHash),
          throwsArgumentError,
        );

        final mismatches = <void Function()>[
          () => NarrativeContractChain(
            projectCharter: charter,
            arcContract: _arc(charter, projectCharterId: 'other-charter'),
            sceneContract: scene,
          ),
          () => NarrativeContractChain(
            projectCharter: charter,
            arcContract: _arc(charter, projectCharterHash: 'other-hash'),
            sceneContract: scene,
          ),
          () => NarrativeContractChain(
            projectCharter: charter,
            arcContract: arc,
            sceneContract: _sceneContract(
              charter,
              arc,
              projectCharterHash: 'other-hash',
            ),
          ),
          () => NarrativeContractChain(
            projectCharter: charter,
            arcContract: arc,
            sceneContract: _sceneContract(
              charter,
              arc,
              arcContractHash: 'other-hash',
            ),
          ),
          () => NarrativeContractChain(
            projectCharter: charter,
            arcContract: arc,
            sceneContract: _sceneContract(
              charter,
              arc,
              corePromiseId: 'other-promise',
            ),
          ),
          () => NarrativeContractChain(
            projectCharter: charter,
            arcContract: arc,
            sceneContract: _sceneContract(
              charter,
              arc,
              phaseGoalId: 'other-phase',
            ),
          ),
        ];
        for (final mismatch in mismatches) {
          expect(mismatch, throwsArgumentError);
        }
      },
    );

    test('proposal hash remains stable across author decision state', () {
      final pending = NarrativeTransitionProposal(
        proposalId: 'proposal-1',
        fromContractHash: 'contract-before',
        proposedContractHash: 'contract-after',
        transitionKind: NarrativeTransitionKind.phaseAdvance,
        reason: 'The phase exit condition was met.',
        affectedPromiseIds: ['promise-b', 'promise-a'],
        affectedLedgerEntryIds: ['ledger-b', 'ledger-a'],
        authorDecision: AuthorDecisionStatus.pending,
      );
      final accepted = NarrativeTransitionProposal(
        proposalId: 'proposal-1',
        fromContractHash: 'contract-before',
        proposedContractHash: 'contract-after',
        transitionKind: NarrativeTransitionKind.phaseAdvance,
        reason: 'The phase exit condition was met.',
        affectedPromiseIds: ['promise-a', 'promise-b'],
        affectedLedgerEntryIds: ['ledger-a', 'ledger-b'],
        authorDecision: AuthorDecisionStatus.accepted,
        authorReceiptId: 'author-receipt-1',
      );

      expect(pending.proposalHash, accepted.proposalHash);
      expect(pending.identityJson, isNot(contains('authorDecision')));
      expect(pending.identityJson, isNot(contains('authorReceiptId')));
      expect(pending.toJson()['authorDecision'], 'pending');
      expect(pending.toJson(), isNot(contains('authorReceiptId')));
      expect(accepted.toJson()['authorDecision'], 'accepted');
      expect(accepted.toJson()['authorReceiptId'], 'author-receipt-1');

      final changedReason = NarrativeTransitionProposal(
        proposalId: 'proposal-1',
        fromContractHash: 'contract-before',
        proposedContractHash: 'contract-after',
        transitionKind: NarrativeTransitionKind.phaseAdvance,
        reason: 'A different immutable reason.',
        affectedPromiseIds: ['promise-a', 'promise-b'],
        affectedLedgerEntryIds: ['ledger-a', 'ledger-b'],
        authorDecision: AuthorDecisionStatus.pending,
      );
      expect(changedReason.proposalHash, isNot(pending.proposalHash));
    });
  });

  group('findings and craft score', () {
    test('blocker and major findings require evidence or contract refs', () {
      QualityFinding finding(
        QualitySeverity severity, {
        List<TextEvidenceSpan> evidence = const [],
        List<String> contractRefs = const [],
      }) => QualityFinding(
        findingId: 'finding-${severity.wire}',
        findingClass: QualityFindingClass.hardError,
        severity: severity,
        axis: QualityAxis.causality,
        code: 'missing-cause',
        claim: 'The causal bridge is missing.',
        evidence: evidence,
        contractRefs: contractRefs,
        calibratedConfidence: 0.9,
        suggestedAction: RepairAction.manualReview,
      );

      expect(() => finding(QualitySeverity.blocker), throwsArgumentError);
      expect(() => finding(QualitySeverity.major), throwsArgumentError);
      expect(finding(QualitySeverity.minor), isA<QualityFinding>());
      expect(
        finding(
          QualitySeverity.major,
          evidence: [
            TextEvidenceSpan(
              startOffset: 10,
              endOffset: 20,
              excerptDigest: 'excerpt-digest-1',
              localExcerpt: 'missing link',
            ),
          ],
        ),
        isA<QualityFinding>(),
      );
      expect(
        finding(QualitySeverity.blocker, contractRefs: ['contract-1']),
        isA<QualityFinding>(),
      );
    });

    test('style choices and effective deviations cannot self-excuse', () {
      expect(
        () => QualityFinding(
          findingId: 'style-choice-major',
          findingClass: QualityFindingClass.styleChoice,
          severity: QualitySeverity.major,
          axis: QualityAxis.rhythm,
          code: 'slow-burn',
          claim: 'The scene deliberately slows down.',
          contractRefs: const ['voice-profile-1'],
          calibratedConfidence: 0.9,
          suggestedAction: RepairAction.accept,
        ),
        throwsArgumentError,
      );

      QualityFinding deviation({
        String? effectiveFunction = 'Increase confrontation pressure.',
        String? expectedReturnCondition = 'The confrontation resolves.',
        List<TextEvidenceSpan> evidence = const [],
        List<DeviationAuthorizationRef> authorizationRefs = const [],
      }) => QualityFinding(
        findingId: 'effective-deviation-1',
        findingClass: QualityFindingClass.effectiveDeviation,
        severity: QualitySeverity.minor,
        axis: QualityAxis.rhythm,
        code: 'planned-rhythm-break',
        claim: 'Short fragments intentionally depart from the project norm.',
        evidence: evidence,
        calibratedConfidence: 0.9,
        suggestedAction: RepairAction.acceptWithNote,
        effectiveFunction: effectiveFunction,
        expectedReturnCondition: expectedReturnCondition,
        deviationAuthorizationRefs: authorizationRefs,
      );

      final span = TextEvidenceSpan(
        startOffset: 10,
        endOffset: 20,
        excerptDigest: 'excerpt-digest-deviation',
        localExcerpt: 'short beats',
      );
      final authorization = DeviationAuthorizationRef(
        authorizedBy: DeviationAuthorization.sceneContract,
        referenceId: 'deviation-1',
      );
      expect(() => deviation(), throwsArgumentError);
      expect(
        () => deviation(evidence: [span], effectiveFunction: null),
        throwsArgumentError,
      );
      expect(
        () => deviation(evidence: [span], expectedReturnCondition: null),
        throwsArgumentError,
      );
      expect(() => deviation(evidence: [span]), throwsArgumentError);

      final valid = deviation(
        evidence: [span],
        authorizationRefs: [authorization],
      );
      expect(
        QualityFinding.fromJson(_jsonCopy(valid.toJson())).toJson(),
        valid.toJson(),
      );
    });

    test('style deviation decisions require evidence and typed authority', () {
      expect(
        () => StyleFitResult(decision: StyleFitDecision.mismatch),
        throwsArgumentError,
      );
      expect(
        () => StyleFitResult(
          decision: StyleFitDecision.plannedDeviation,
          axisExplanations: const {'rhythm': 'Planned pressure spike.'},
          deviationIds: const ['deviation-1'],
          evidenceRefs: const ['scene-craft-1'],
        ),
        throwsArgumentError,
      );
      expect(
        () => StyleFitResult(
          decision: StyleFitDecision.approvedDeviation,
          axisExplanations: const {'rhythm': 'Approved after review.'},
          deviationIds: const ['deviation-1'],
          evidenceRefs: const ['scene-craft-1'],
          deviationAuthorizationRefs: [
            DeviationAuthorizationRef(
              authorizedBy: DeviationAuthorization.sceneContract,
              referenceId: 'deviation-1',
            ),
          ],
        ),
        throwsArgumentError,
      );

      final authorization = DeviationAuthorizationRef(
        authorizedBy: DeviationAuthorization.sceneContract,
        referenceId: 'deviation-1',
      );
      final styleFit = StyleFitResult(
        decision: StyleFitDecision.plannedDeviation,
        axisExplanations: const {'rhythm': 'Planned pressure spike.'},
        deviationIds: const ['deviation-1'],
        evidenceRefs: const ['scene-craft-1'],
        deviationAuthorizationRefs: [authorization],
      );
      final finding = QualityFinding(
        findingId: 'effective-deviation-layered',
        findingClass: QualityFindingClass.effectiveDeviation,
        severity: QualitySeverity.minor,
        axis: QualityAxis.rhythm,
        code: 'planned-rhythm-break',
        claim: 'Short fragments implement the planned pressure spike.',
        evidence: [
          TextEvidenceSpan(
            startOffset: 10,
            endOffset: 20,
            excerptDigest: 'excerpt-digest-deviation',
            localExcerpt: 'short beats',
          ),
        ],
        calibratedConfidence: 0.9,
        suggestedAction: RepairAction.acceptWithNote,
        effectiveFunction: 'Increase confrontation pressure.',
        expectedReturnCondition: 'The confrontation resolves.',
        deviationAuthorizationRefs: [authorization],
      );
      expect(
        _layeredResult(createdAtMs: 1, styleFit: styleFit, findings: [finding]),
        isA<LayeredQualityResult>(),
      );

      final mismatchedAuthorization = QualityFinding(
        findingId: 'effective-deviation-unbound',
        findingClass: QualityFindingClass.effectiveDeviation,
        severity: QualitySeverity.minor,
        axis: QualityAxis.rhythm,
        code: 'unbound-rhythm-break',
        claim: 'The evaluator cites an unrelated override.',
        evidence: [
          TextEvidenceSpan(
            startOffset: 10,
            endOffset: 20,
            excerptDigest: 'excerpt-digest-unbound',
            localExcerpt: 'short beats',
          ),
        ],
        calibratedConfidence: 0.9,
        suggestedAction: RepairAction.acceptWithNote,
        effectiveFunction: 'Increase confrontation pressure.',
        expectedReturnCondition: 'The confrontation resolves.',
        deviationAuthorizationRefs: [
          DeviationAuthorizationRef(
            authorizedBy: DeviationAuthorization.authorOverride,
            referenceId: 'override-not-in-style-fit',
          ),
        ],
      );
      expect(
        () => _layeredResult(
          createdAtMs: 1,
          styleFit: styleFit,
          findings: [mismatchedAuthorization],
        ),
        throwsArgumentError,
      );
    });

    test('craft score enforces seven weighted bounded dimensions', () {
      expect(CraftScore.weights, const {
        'prosePrecision': 0.18,
        'paragraphFunction': 0.12,
        'scenePressure': 0.18,
        'characterVoice': 0.15,
        'informationControl': 0.15,
        'coherence': 0.12,
        'completenessAndTurn': 0.10,
      });
      expect(
        CraftScore.weights.values.reduce((left, right) => left + right),
        closeTo(1, 0.000000001),
      );
      final score = _craftScore();
      expect(score.craftOverall, closeTo(52.4, 0.000000001));
      expect(score.criticalCraftMinimum, 0);

      final missing = Map<String, double>.from(_craftDimensions)
        ..remove('coherence');
      final extra = Map<String, double>.from(_craftDimensions)
        ..['unsupported'] = 50;
      expect(() => CraftScore(dimensions: missing), throwsArgumentError);
      expect(() => CraftScore(dimensions: extra), throwsArgumentError);
      for (final invalid in [-0.1, 100.1, double.nan, double.infinity]) {
        expect(
          () => CraftScore(
            dimensions: {..._craftDimensions, 'prosePrecision': invalid},
          ),
          throwsArgumentError,
        );
      }

      final tampered = _jsonCopy(score.toJson())..['craftOverall'] = 99.0;
      expect(
        () => CraftScore.fromJson(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('legacy style intensity mapping clamps to the canonical scale', () {
      expect(ProjectVoiceProfile.styleIntensityFromLegacy(-10), 0);
      expect(ProjectVoiceProfile.styleIntensityFromLegacy(0), 0);
      expect(ProjectVoiceProfile.styleIntensityFromLegacy(1), 34);
      expect(ProjectVoiceProfile.styleIntensityFromLegacy(2), 67);
      expect(ProjectVoiceProfile.styleIntensityFromLegacy(3), 100);
      expect(ProjectVoiceProfile.styleIntensityFromLegacy(100), 100);
    });
  });

  group('stored evidence hashes', () {
    test(
      'scene craft hash persists, supports legacy JSON, and rejects drift',
      () {
        final craft = _sceneCraftContract();
        final serialized = _jsonCopy(craft.toJson());

        expect(craft.craftHash, craft.canonicalHash);
        expect(serialized['craftHash'], craft.craftHash);
        expect(
          SceneCraftContract.fromJson(serialized).toJson(),
          craft.toJson(),
        );

        final legacy = _jsonCopy(serialized)..remove('craftHash');
        final legacyRestored = SceneCraftContract.fromJson(legacy);
        expect(legacyRestored.craftHash, craft.craftHash);
        expect(legacyRestored.toJson()['craftHash'], craft.craftHash);

        final contentTamper = _jsonCopy(serialized)
          ..['sceneGoal'] = 'A changed scene goal.';
        final hashTamper = _jsonCopy(serialized)..['craftHash'] = 'wrong-hash';
        expect(
          () => SceneCraftContract.fromJson(contentTamper),
          throwsArgumentError,
        );
        expect(
          () => SceneCraftContract.fromJson(hashTamper),
          throwsArgumentError,
        );
      },
    );

    test('layered result excludes time and rejects identity tampering', () {
      final early = _layeredResult(createdAtMs: 1111);
      final late = _layeredResult(createdAtMs: 9999);

      expect(early.evidenceHash, early.canonicalHash);
      expect(early.evidenceHash, late.evidenceHash);
      expect(early.identityJson, isNot(contains('createdAtMs')));
      expect(early.toJson()['createdAtMs'], 1111);
      expect(
        LayeredQualityResult.fromJson(_jsonCopy(early.toJson())).toJson(),
        early.toJson(),
      );

      final tampered = _jsonCopy(early.toJson())
        ..['proseHash'] = 'different-prose';
      expect(
        () => LayeredQualityResult.fromJson(tampered),
        throwsArgumentError,
      );
    });
  });

  test('release decision and certification DTOs serialize losslessly', () {
    final sceneDecision = _candidateDecision();
    expect(
      SceneCandidateDecision.fromJson(
        _jsonCopy(sceneDecision.toJson()),
      ).toJson(),
      sceneDecision.toJson(),
    );
    expect(sceneDecision.toJson()['status'], 'highCandidate');
    expect(sceneDecision.toJson()['findingIds'], ['finding-a', 'finding-b']);

    final certification = EvaluatorPolicyCertification(
      certificationId: 'certification-1',
      rubricVersion: 'rubric-1',
      promptReleaseHash: 'prompt-release-1',
      evaluatorModelRelease: 'evaluator-release-1',
      thresholdPolicyVersion: 'threshold-policy-1',
      status: EvaluatorPolicyCertificationStatus.certified,
      calibrationArtifactHash: 'calibration-1',
      blindReviewArtifactHash: 'blind-review-1',
      metrics: {
        'majorPrecision': MetricWithInterval(
          point: 0.91,
          ci95Low: 0.88,
          ci95High: 0.94,
          sampleSize: 300,
        ),
      },
      certifiedAtMs: 1234,
    );
    final certificationJson = _jsonCopy(certification.toJson());
    final restoredCertification = EvaluatorPolicyCertification.fromJson(
      certificationJson,
    );
    expect(restoredCertification.toJson(), certification.toJson());
    expect(
      restoredCertification.certificationHash,
      certification.certificationHash,
    );
    final laterCertification = EvaluatorPolicyCertification.fromJson(
      _jsonCopy(certificationJson)..['certifiedAtMs'] = 5678,
    );
    expect(
      laterCertification.certificationHash,
      certification.certificationHash,
    );

    final chapter = ChapterQualityDecision(
      chapterId: 'chapter-1',
      status: ChapterQualityStatus.releaseEligible,
      sceneEvidenceHashes: ['scene-evidence-b', 'scene-evidence-a'],
      narrativeChainHash: 'narrative-chain-1',
      unresolvedMajorFindingIds: const [],
      chapterAuditHash: 'chapter-audit-1',
    );
    final restoredChapter = ChapterQualityDecision.fromJson(
      _jsonCopy(chapter.toJson()),
    );
    expect(restoredChapter.toJson(), chapter.toJson());
    expect(restoredChapter.decisionHash, chapter.decisionHash);

    final book = BookQualityDecision(
      projectId: 'project-1',
      status: BookQualityStatus.releaseEvidencePassed,
      chapterDecisionHashes: ['chapter-b', 'chapter-a'],
      evaluatorCertificationId: 'certification-1',
      blindReviewArtifactHash: 'blind-review-1',
      longFormAuditArtifactHash: 'long-form-audit-1',
    );
    final restoredBook = BookQualityDecision.fromJson(_jsonCopy(book.toJson()));
    expect(restoredBook.toJson(), book.toJson());
    expect(restoredBook.decisionHash, book.decisionHash);
  });

  test('release aggregates reject locally contradictory states', () {
    expect(
      () => ChapterQualityDecision(
        chapterId: 'chapter-1',
        status: ChapterQualityStatus.releaseEligible,
        sceneEvidenceHashes: const [],
        narrativeChainHash: 'narrative-chain-1',
        unresolvedMajorFindingIds: const [],
        chapterAuditHash: 'chapter-audit-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => ChapterQualityDecision(
        chapterId: 'chapter-1',
        status: ChapterQualityStatus.releaseEligible,
        sceneEvidenceHashes: const ['scene-evidence-1'],
        narrativeChainHash: 'narrative-chain-1',
        unresolvedMajorFindingIds: const ['finding-major-1'],
        chapterAuditHash: 'chapter-audit-1',
      ),
      throwsArgumentError,
    );
    expect(
      () => BookQualityDecision(
        projectId: 'project-1',
        status: BookQualityStatus.releaseEvidencePassed,
        chapterDecisionHashes: const [],
        evaluatorCertificationId: 'certification-1',
        blindReviewArtifactHash: 'blind-review-1',
        longFormAuditArtifactHash: 'long-form-audit-1',
      ),
      throwsArgumentError,
    );
  });
}
