import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';

export 'source_ledger_models.dart'
    show
        ReferenceUsage,
        SourceLicenseStatus,
        AllowedSourceUse,
        SourceLedgerEntry;

enum QualityFindingClass {
  hardError('hardError'),
  craftWeakness('craftWeakness'),
  styleChoice('styleChoice'),
  effectiveDeviation('effectiveDeviation');

  const QualityFindingClass(this.wire);
  final String wire;
}

enum QualitySeverity {
  blocker('blocker'),
  major('major'),
  minor('minor'),
  note('note');

  const QualitySeverity(this.wire);
  final String wire;
}

enum QualityAxis {
  causality('causality'),
  timeline('timeline'),
  spatialContinuity('spatialContinuity'),
  worldRule('worldRule'),
  pov('pov'),
  characterKnowledge('characterKnowledge'),
  characterMotivation('characterMotivation'),
  relationship('relationship'),
  objectState('objectState'),
  corePromise('corePromise'),
  foreshadowing('foreshadowing'),
  prose('prose'),
  paragraphFunction('paragraphFunction'),
  scenePressure('scenePressure'),
  informationControl('informationControl'),
  characterVoice('characterVoice'),
  rhythm('rhythm'),
  projectVoice('projectVoice'),
  readerEffect('readerEffect'),
  provenance('provenance');

  const QualityAxis(this.wire);
  final String wire;
}

enum PovMode {
  firstPersonLimited('firstPersonLimited'),
  thirdPersonLimited('thirdPersonLimited'),
  rotatingLimited('rotatingLimited'),
  omniscient('omniscient'),
  custom('custom');

  const PovMode(this.wire);
  final String wire;
}

enum NarrativeDistancePolicy {
  close('close'),
  medium('medium'),
  far('far'),
  variable('variable');

  const NarrativeDistancePolicy(this.wire);
  final String wire;
}

enum RegisterPolicy {
  colloquial('colloquial'),
  neutral('neutral'),
  elevated('elevated'),
  archaic('archaic'),
  technical('technical'),
  mixed('mixed'),
  custom('custom');

  const RegisterPolicy(this.wire);
  final String wire;
}

enum SceneFunction {
  advancePlot('advancePlot'),
  revealCharacter('revealCharacter'),
  alterRelationship('alterRelationship'),
  revealInformation('revealInformation'),
  buildWorldPressure('buildWorldPressure'),
  plantPromise('plantPromise'),
  pressurePromise('pressurePromise'),
  payPromise('payPromise'),
  emotionalAftermath('emotionalAftermath'),
  thematicCounterpoint('thematicCounterpoint'),
  transition('transition');

  const SceneFunction(this.wire);
  final String wire;
}

enum PressureCurve {
  rising('rising'),
  falling('falling'),
  wave('wave'),
  reversal('reversal'),
  plateauWithReason('plateauWithReason');

  const PressureCurve(this.wire);
  final String wire;
}

enum RepairAction {
  blockAndReplan('blockAndReplan'),
  targetedRepair('targetedRepair'),
  alignVoice('alignVoice'),
  accept('accept'),
  acceptWithNote('acceptWithNote'),
  rescore('rescore'),
  manualReview('manualReview');

  const RepairAction(this.wire);
  final String wire;
}

enum StyleFitDecision {
  aligned('aligned'),
  plannedDeviation('plannedDeviation'),
  approvedDeviation('approvedDeviation'),
  mismatch('mismatch');

  const StyleFitDecision(this.wire);
  final String wire;
}

enum OverrideScope {
  sceneRevision('sceneRevision'),
  scene('scene'),
  chapter('chapter'),
  project('project');

  const OverrideScope(this.wire);
  final String wire;
}

enum RepairOperation {
  replaceSpan('replaceSpan'),
  deleteSpan('deleteSpan'),
  insertBridge('insertBridge'),
  reorderParagraph('reorderParagraph'),
  alignRegister('alignRegister'),
  restoreFact('restoreFact'),
  restoreMotivation('restoreMotivation'),
  rewriteWholeScene('rewriteWholeScene');

  const RepairOperation(this.wire);
  final String wire;
}

enum LedgerKind {
  promise('promise'),
  characterArc('characterArc'),
  relationship('relationship'),
  worldForce('worldForce'),
  consequence('consequence'),
  motif('motif'),
  rule('rule'),
  informationBoundary('informationBoundary');

  const LedgerKind(this.wire);
  final String wire;
}

enum LedgerStatus {
  open('open'),
  pressured('pressured'),
  transformed('transformed'),
  paid('paid'),
  abandonedWithReason('abandonedWithReason');

  const LedgerStatus(this.wire);
  final String wire;
}

enum EmotionalTemperature {
  cold('cold'),
  restrained('restrained'),
  neutral('neutral'),
  warm('warm'),
  intense('intense'),
  variable('variable');

  const EmotionalTemperature(this.wire);
  final String wire;
}

enum LiteraryQualityGateMode {
  legacy95('legacy95'),
  shadowV2('shadowV2'),
  enforceV2('enforceV2');

  const LiteraryQualityGateMode(this.wire);
  final String wire;
}

enum QualityStrictness {
  draft('draft'),
  standard('standard'),
  strict('strict'),
  publication('publication');

  const QualityStrictness(this.wire);
  final String wire;
}

enum SceneCandidateStatus {
  blocked('blocked'),
  repairRequired('repairRequired'),
  draftKeep('draftKeep'),
  autoCandidate('autoCandidate'),
  highCandidate('highCandidate'),
  sceneReleaseCandidate('sceneReleaseCandidate'),
  manualReview('manualReview');

  const SceneCandidateStatus(this.wire);
  final String wire;
}

enum NarrativeTransitionKind {
  phaseAdvance('phaseAdvance'),
  promiseTransform('promiseTransform'),
  charterRevision('charterRevision');

  const NarrativeTransitionKind(this.wire);
  final String wire;
}

enum AuthorDecisionStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected');

  const AuthorDecisionStatus(this.wire);
  final String wire;
}

enum EvaluatorPolicyCertificationStatus {
  development('development'),
  beta('beta'),
  certified('certified'),
  revoked('revoked');

  const EvaluatorPolicyCertificationStatus(this.wire);
  final String wire;
}

enum ChapterQualityStatus {
  blocked('blocked'),
  draftEligible('draftEligible'),
  releaseEligible('releaseEligible'),
  manualReview('manualReview');

  const ChapterQualityStatus(this.wire);
  final String wire;
}

enum BookQualityStatus {
  blocked('blocked'),
  draftEligible('draftEligible'),
  releaseEvidencePassed('releaseEvidencePassed'),
  manualReview('manualReview');

  const BookQualityStatus(this.wire);
  final String wire;
}

enum RhythmCurve {
  slowBurn('slowBurn'),
  fastReward('fastReward'),
  wave('wave'),
  epicAccumulation('epicAccumulation'),
  custom('custom');

  const RhythmCurve(this.wire);
  final String wire;
}

enum DeviationAuthorization {
  sceneContract('sceneContract'),
  independentReview('independentReview'),
  authorOverride('authorOverride');

  const DeviationAuthorization(this.wire);
  final String wire;
}

enum VoiceConstraintOperator {
  prefer('prefer'),
  avoid('avoid'),
  range('range'),
  requireContrast('requireContrast');

  const VoiceConstraintOperator(this.wire);
  final String wire;
}

enum StateChangeType {
  causal('causal'),
  character('character'),
  knowledge('knowledge'),
  relationship('relationship'),
  world('world'),
  theme('theme');

  const StateChangeType(this.wire);
  final String wire;
}

enum ReaderEstimateSource {
  ledgerDerived('ledgerDerived'),
  modelProxy('modelProxy'),
  humanStudy('humanStudy');

  const ReaderEstimateSource(this.wire);
  final String wire;
}

final class DeviationAuthorizationRef {
  DeviationAuthorizationRef({
    required this.authorizedBy,
    required String referenceId,
  }) : referenceId = AppLlmCanonicalHash.normalizeNfc(referenceId) {
    _requireNonEmpty(referenceId, 'referenceId');
  }

  final DeviationAuthorization authorizedBy;
  final String referenceId;

  Map<String, Object?> toJson() => {
    'authorizedBy': authorizedBy.wire,
    'referenceId': referenceId,
  };

  factory DeviationAuthorizationRef.fromJson(Map<String, Object?> json) =>
      DeviationAuthorizationRef(
        authorizedBy: _enumValue(
          json,
          'authorizedBy',
          DeviationAuthorization.values,
          (value) => value.wire,
        ),
        referenceId: _string(json, 'referenceId'),
      );
}

final class QualityFinding {
  QualityFinding({
    required this.findingId,
    required this.findingClass,
    required this.severity,
    required this.axis,
    required this.code,
    required this.claim,
    List<TextEvidenceSpan> evidence = const [],
    List<String> contractRefs = const [],
    required this.calibratedConfidence,
    required this.suggestedAction,
    this.effectiveFunction,
    this.expectedReturnCondition,
    List<DeviationAuthorizationRef> deviationAuthorizationRefs = const [],
  }) : evidence = _immutableList(evidence),
       contractRefs = _immutableSortedStrings(contractRefs),
       deviationAuthorizationRefs = _immutableDeviationAuthorizationRefs(
         deviationAuthorizationRefs,
       ) {
    _requireNonEmpty(findingId, 'findingId');
    _requireNonEmpty(code, 'code');
    _requireNonEmpty(claim, 'claim');
    _requireUnitInterval(calibratedConfidence, 'calibratedConfidence');
    if ((severity == QualitySeverity.blocker ||
            severity == QualitySeverity.major) &&
        this.evidence.isEmpty &&
        this.contractRefs.isEmpty) {
      throw ArgumentError(
        'blocker and major findings require evidence or contractRefs',
      );
    }
    if (findingClass == QualityFindingClass.styleChoice ||
        findingClass == QualityFindingClass.effectiveDeviation) {
      if (severity == QualitySeverity.blocker ||
          severity == QualitySeverity.major) {
        throw ArgumentError(
          'style choices and effective deviations cannot be blocker or major',
        );
      }
      if (suggestedAction != RepairAction.accept &&
          suggestedAction != RepairAction.acceptWithNote) {
        throw ArgumentError(
          'style choices and effective deviations must be preserved',
        );
      }
    }
    if (findingClass == QualityFindingClass.effectiveDeviation) {
      if (effectiveFunction == null || effectiveFunction!.trim().isEmpty) {
        throw ArgumentError(
          'effective deviations require an effectiveFunction',
        );
      }
      if (expectedReturnCondition == null ||
          expectedReturnCondition!.trim().isEmpty) {
        throw ArgumentError(
          'effective deviations require an expectedReturnCondition',
        );
      }
      if (this.evidence.isEmpty) {
        throw ArgumentError('effective deviations require text evidence');
      }
      if (this.deviationAuthorizationRefs.isEmpty) {
        throw ArgumentError(
          'effective deviations require a typed authorization reference',
        );
      }
    }
  }

  final String findingId;
  final QualityFindingClass findingClass;
  final QualitySeverity severity;
  final QualityAxis axis;
  final String code;
  final String claim;
  final List<TextEvidenceSpan> evidence;
  final List<String> contractRefs;
  final double calibratedConfidence;
  final RepairAction suggestedAction;
  final String? effectiveFunction;
  final String? expectedReturnCondition;
  final List<DeviationAuthorizationRef> deviationAuthorizationRefs;

  Map<String, Object?> toJson() => _withoutNulls({
    'findingId': findingId,
    'findingClass': findingClass.wire,
    'severity': severity.wire,
    'axis': axis.wire,
    'code': code,
    'claim': claim,
    'evidence': [for (final span in evidence) span.toJson()],
    'contractRefs': contractRefs,
    'calibratedConfidence': calibratedConfidence,
    'suggestedAction': suggestedAction.wire,
    'effectiveFunction': effectiveFunction,
    'expectedReturnCondition': expectedReturnCondition,
    'deviationAuthorizationRefs': [
      for (final reference in deviationAuthorizationRefs) reference.toJson(),
    ],
  });

  factory QualityFinding.fromJson(Map<String, Object?> json) => QualityFinding(
    findingId: _string(json, 'findingId'),
    findingClass: _enumValue(
      json,
      'findingClass',
      QualityFindingClass.values,
      (value) => value.wire,
    ),
    severity: _enumValue(
      json,
      'severity',
      QualitySeverity.values,
      (value) => value.wire,
    ),
    axis: _enumValue(json, 'axis', QualityAxis.values, (value) => value.wire),
    code: _string(json, 'code'),
    claim: _string(json, 'claim'),
    evidence: _listOfMaps(
      json,
      'evidence',
    ).map(TextEvidenceSpan.fromJson).toList(growable: false),
    contractRefs: _stringList(json, 'contractRefs'),
    calibratedConfidence: _double(json, 'calibratedConfidence'),
    suggestedAction: _enumValue(
      json,
      'suggestedAction',
      RepairAction.values,
      (value) => value.wire,
    ),
    effectiveFunction: _optionalString(json, 'effectiveFunction'),
    expectedReturnCondition: _optionalString(json, 'expectedReturnCondition'),
    deviationAuthorizationRefs: _listOfMaps(
      json,
      'deviationAuthorizationRefs',
    ).map(DeviationAuthorizationRef.fromJson).toList(growable: false),
  );
}

final class TextEvidenceSpan {
  TextEvidenceSpan({
    required this.startOffset,
    required this.endOffset,
    required this.excerptDigest,
    required this.localExcerpt,
  }) {
    if (startOffset < 0 || endOffset <= startOffset) {
      throw ArgumentError('text evidence span must have valid offsets');
    }
    _requireNonEmpty(excerptDigest, 'excerptDigest');
  }

  final int startOffset;
  final int endOffset;
  final String excerptDigest;
  final String localExcerpt;

  Map<String, Object?> toJson() => {
    'startOffset': startOffset,
    'endOffset': endOffset,
    'excerptDigest': excerptDigest,
    'localExcerpt': localExcerpt,
  };

  factory TextEvidenceSpan.fromJson(Map<String, Object?> json) =>
      TextEvidenceSpan(
        startOffset: _int(json, 'startOffset'),
        endOffset: _int(json, 'endOffset'),
        excerptDigest: _string(json, 'excerptDigest'),
        localExcerpt: _string(json, 'localExcerpt'),
      );
}

final class ProjectNarrativeCharter {
  ProjectNarrativeCharter({
    required this.schemaVersion,
    required this.charterId,
    required this.revision,
    required this.charterHash,
    this.previousCharterHash,
    required this.projectId,
    required this.corePromiseId,
    required this.corePromiseStatement,
    List<String> centralTensionIds = const [],
    List<String> invariantWorldRuleRefs = const [],
    List<String> invariantPovRules = const [],
    required this.transformationPolicy,
    this.transitionReceiptId,
  }) : centralTensionIds = _immutableSortedStrings(centralTensionIds),
       invariantWorldRuleRefs = _immutableSortedStrings(invariantWorldRuleRefs),
       invariantPovRules = _immutableSortedStrings(invariantPovRules) {
    _validateVersionRevision(schemaVersion, revision);
    _requireNonEmpty(charterId, 'charterId');
    _requireNonEmpty(projectId, 'projectId');
    _requireNonEmpty(corePromiseId, 'corePromiseId');
    _requireNonEmpty(corePromiseStatement, 'corePromiseStatement');
    _requireNonEmpty(transformationPolicy, 'transformationPolicy');
    _requireHashMatches('charterHash', charterHash, canonicalHash);
  }

  final int schemaVersion;
  final String charterId;
  final int revision;
  final String charterHash;
  final String? previousCharterHash;
  final String projectId;
  final String corePromiseId;
  final String corePromiseStatement;
  final List<String> centralTensionIds;
  final List<String> invariantWorldRuleRefs;
  final List<String> invariantPovRules;
  final String transformationPolicy;
  final String? transitionReceiptId;

  Map<String, Object?> get identityJson => _withoutNulls({
    'schemaVersion': schemaVersion,
    'charterId': charterId,
    'revision': revision,
    'previousCharterHash': previousCharterHash,
    'projectId': projectId,
    'corePromiseId': corePromiseId,
    'corePromiseStatement': corePromiseStatement,
    'centralTensionIds': centralTensionIds,
    'invariantWorldRuleRefs': invariantWorldRuleRefs,
    'invariantPovRules': invariantPovRules,
    'transformationPolicy': transformationPolicy,
    'transitionReceiptId': transitionReceiptId,
  });

  String get canonicalHash => AppLlmCanonicalHash.domainHash(
    'project-narrative-charter-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => {
    ...identityJson,
    'charterHash': charterHash,
  };

  factory ProjectNarrativeCharter.create({
    required int schemaVersion,
    required String charterId,
    required int revision,
    String? previousCharterHash,
    required String projectId,
    required String corePromiseId,
    required String corePromiseStatement,
    List<String> centralTensionIds = const [],
    List<String> invariantWorldRuleRefs = const [],
    List<String> invariantPovRules = const [],
    required String transformationPolicy,
    String? transitionReceiptId,
  }) {
    final normalizedCentralTensionIds = _immutableSortedStrings(
      centralTensionIds,
    );
    final normalizedWorldRuleRefs = _immutableSortedStrings(
      invariantWorldRuleRefs,
    );
    final normalizedPovRules = _immutableSortedStrings(invariantPovRules);
    final identityJson = _withoutNulls({
      'schemaVersion': schemaVersion,
      'charterId': charterId,
      'revision': revision,
      'previousCharterHash': previousCharterHash,
      'projectId': projectId,
      'corePromiseId': corePromiseId,
      'corePromiseStatement': corePromiseStatement,
      'centralTensionIds': normalizedCentralTensionIds,
      'invariantWorldRuleRefs': normalizedWorldRuleRefs,
      'invariantPovRules': normalizedPovRules,
      'transformationPolicy': transformationPolicy,
      'transitionReceiptId': transitionReceiptId,
    });
    return ProjectNarrativeCharter(
      schemaVersion: schemaVersion,
      charterId: charterId,
      revision: revision,
      charterHash: AppLlmCanonicalHash.domainHash(
        'project-narrative-charter-v1',
        identityJson,
      ),
      previousCharterHash: previousCharterHash,
      projectId: projectId,
      corePromiseId: corePromiseId,
      corePromiseStatement: corePromiseStatement,
      centralTensionIds: normalizedCentralTensionIds,
      invariantWorldRuleRefs: normalizedWorldRuleRefs,
      invariantPovRules: normalizedPovRules,
      transformationPolicy: transformationPolicy,
      transitionReceiptId: transitionReceiptId,
    );
  }

  factory ProjectNarrativeCharter.fromJson(Map<String, Object?> json) =>
      ProjectNarrativeCharter(
        schemaVersion: _int(json, 'schemaVersion'),
        charterId: _string(json, 'charterId'),
        revision: _int(json, 'revision'),
        charterHash: _string(json, 'charterHash'),
        previousCharterHash: _optionalString(json, 'previousCharterHash'),
        projectId: _string(json, 'projectId'),
        corePromiseId: _string(json, 'corePromiseId'),
        corePromiseStatement: _string(json, 'corePromiseStatement'),
        centralTensionIds: _stringList(json, 'centralTensionIds'),
        invariantWorldRuleRefs: _stringList(json, 'invariantWorldRuleRefs'),
        invariantPovRules: _stringList(json, 'invariantPovRules'),
        transformationPolicy: _string(json, 'transformationPolicy'),
        transitionReceiptId: _optionalString(json, 'transitionReceiptId'),
      );
}

final class ArcContract {
  ArcContract({
    required this.schemaVersion,
    required this.arcContractId,
    required this.revision,
    required this.arcContractHash,
    required this.projectCharterId,
    required this.projectCharterHash,
    this.previousArcContractHash,
    required this.arcId,
    required this.phaseGoalId,
    required this.phaseGoalStatement,
    required this.currentNarrativeQuestion,
    required this.entryCondition,
    required this.exitCondition,
    List<String> activePromiseIds = const [],
    List<String> payoffWindowIds = const [],
    this.transitionReceiptId,
  }) : activePromiseIds = _immutableSortedStrings(activePromiseIds),
       payoffWindowIds = _immutableSortedStrings(payoffWindowIds) {
    _validateVersionRevision(schemaVersion, revision);
    for (final entry in {
      'arcContractId': arcContractId,
      'projectCharterId': projectCharterId,
      'projectCharterHash': projectCharterHash,
      'arcId': arcId,
      'phaseGoalId': phaseGoalId,
      'phaseGoalStatement': phaseGoalStatement,
      'currentNarrativeQuestion': currentNarrativeQuestion,
      'entryCondition': entryCondition,
      'exitCondition': exitCondition,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    _requireHashMatches('arcContractHash', arcContractHash, canonicalHash);
  }

  final int schemaVersion;
  final String arcContractId;
  final int revision;
  final String arcContractHash;
  final String projectCharterId;
  final String projectCharterHash;
  final String? previousArcContractHash;
  final String arcId;
  final String phaseGoalId;
  final String phaseGoalStatement;
  final String currentNarrativeQuestion;
  final String entryCondition;
  final String exitCondition;
  final List<String> activePromiseIds;
  final List<String> payoffWindowIds;
  final String? transitionReceiptId;

  Map<String, Object?> get identityJson => _withoutNulls({
    'schemaVersion': schemaVersion,
    'arcContractId': arcContractId,
    'revision': revision,
    'projectCharterId': projectCharterId,
    'projectCharterHash': projectCharterHash,
    'previousArcContractHash': previousArcContractHash,
    'arcId': arcId,
    'phaseGoalId': phaseGoalId,
    'phaseGoalStatement': phaseGoalStatement,
    'currentNarrativeQuestion': currentNarrativeQuestion,
    'entryCondition': entryCondition,
    'exitCondition': exitCondition,
    'activePromiseIds': activePromiseIds,
    'payoffWindowIds': payoffWindowIds,
    'transitionReceiptId': transitionReceiptId,
  });

  String get canonicalHash =>
      AppLlmCanonicalHash.domainHash('arc-contract-v1', identityJson);

  Map<String, Object?> toJson() => {
    ...identityJson,
    'arcContractHash': arcContractHash,
  };

  factory ArcContract.create({
    required int schemaVersion,
    required String arcContractId,
    required int revision,
    required String projectCharterId,
    required String projectCharterHash,
    String? previousArcContractHash,
    required String arcId,
    required String phaseGoalId,
    required String phaseGoalStatement,
    required String currentNarrativeQuestion,
    required String entryCondition,
    required String exitCondition,
    List<String> activePromiseIds = const [],
    List<String> payoffWindowIds = const [],
    String? transitionReceiptId,
  }) {
    final normalizedActivePromiseIds = _immutableSortedStrings(
      activePromiseIds,
    );
    final normalizedPayoffWindowIds = _immutableSortedStrings(payoffWindowIds);
    final identityJson = _withoutNulls({
      'schemaVersion': schemaVersion,
      'arcContractId': arcContractId,
      'revision': revision,
      'projectCharterId': projectCharterId,
      'projectCharterHash': projectCharterHash,
      'previousArcContractHash': previousArcContractHash,
      'arcId': arcId,
      'phaseGoalId': phaseGoalId,
      'phaseGoalStatement': phaseGoalStatement,
      'currentNarrativeQuestion': currentNarrativeQuestion,
      'entryCondition': entryCondition,
      'exitCondition': exitCondition,
      'activePromiseIds': normalizedActivePromiseIds,
      'payoffWindowIds': normalizedPayoffWindowIds,
      'transitionReceiptId': transitionReceiptId,
    });
    return ArcContract(
      schemaVersion: schemaVersion,
      arcContractId: arcContractId,
      revision: revision,
      arcContractHash: AppLlmCanonicalHash.domainHash(
        'arc-contract-v1',
        identityJson,
      ),
      projectCharterId: projectCharterId,
      projectCharterHash: projectCharterHash,
      previousArcContractHash: previousArcContractHash,
      arcId: arcId,
      phaseGoalId: phaseGoalId,
      phaseGoalStatement: phaseGoalStatement,
      currentNarrativeQuestion: currentNarrativeQuestion,
      entryCondition: entryCondition,
      exitCondition: exitCondition,
      activePromiseIds: normalizedActivePromiseIds,
      payoffWindowIds: normalizedPayoffWindowIds,
      transitionReceiptId: transitionReceiptId,
    );
  }

  factory ArcContract.fromJson(Map<String, Object?> json) => ArcContract(
    schemaVersion: _int(json, 'schemaVersion'),
    arcContractId: _string(json, 'arcContractId'),
    revision: _int(json, 'revision'),
    arcContractHash: _string(json, 'arcContractHash'),
    projectCharterId: _string(json, 'projectCharterId'),
    projectCharterHash: _string(json, 'projectCharterHash'),
    previousArcContractHash: _optionalString(json, 'previousArcContractHash'),
    arcId: _string(json, 'arcId'),
    phaseGoalId: _string(json, 'phaseGoalId'),
    phaseGoalStatement: _string(json, 'phaseGoalStatement'),
    currentNarrativeQuestion: _string(json, 'currentNarrativeQuestion'),
    entryCondition: _string(json, 'entryCondition'),
    exitCondition: _string(json, 'exitCondition'),
    activePromiseIds: _stringList(json, 'activePromiseIds'),
    payoffWindowIds: _stringList(json, 'payoffWindowIds'),
    transitionReceiptId: _optionalString(json, 'transitionReceiptId'),
  );
}

final class SceneNarrativeContract {
  SceneNarrativeContract({
    required this.schemaVersion,
    required this.sceneContractId,
    required this.revision,
    required this.sceneContractHash,
    required this.projectCharterHash,
    required this.arcContractHash,
    required this.previousAcceptedSceneContractHash,
    required this.corePromiseId,
    required this.phaseGoalId,
    required this.chapterId,
    required this.sceneId,
    required this.sceneIndex,
    required this.sceneContribution,
    required this.povPolicy,
    List<String> worldRuleRefs = const [],
    List<String> requiredFactRefs = const [],
    List<String> forbiddenContradictions = const [],
    List<String> activePromiseIds = const [],
    List<String> payoffWindowIds = const [],
    List<String> requiredStateChangeTypes = const [],
    List<String> castIds = const [],
    required this.sourceLedgerHash,
    required this.repairBudget,
    required this.replanBudget,
  }) : worldRuleRefs = _immutableSortedStrings(worldRuleRefs),
       requiredFactRefs = _immutableSortedStrings(requiredFactRefs),
       forbiddenContradictions = _immutableSortedStrings(
         forbiddenContradictions,
       ),
       activePromiseIds = _immutableSortedStrings(activePromiseIds),
       payoffWindowIds = _immutableSortedStrings(payoffWindowIds),
       requiredStateChangeTypes = _immutableSortedStrings(
         requiredStateChangeTypes,
       ),
       castIds = _immutableSortedStrings(castIds) {
    _validateVersionRevision(schemaVersion, revision);
    if (sceneIndex < 0 || repairBudget < 0 || replanBudget < 0) {
      throw ArgumentError('sceneIndex and budgets must be non-negative');
    }
    for (final entry in {
      'sceneContractId': sceneContractId,
      'projectCharterHash': projectCharterHash,
      'arcContractHash': arcContractHash,
      'previousAcceptedSceneContractHash': previousAcceptedSceneContractHash,
      'corePromiseId': corePromiseId,
      'phaseGoalId': phaseGoalId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'sceneContribution': sceneContribution,
      'sourceLedgerHash': sourceLedgerHash,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    _requireHashMatches('sceneContractHash', sceneContractHash, canonicalHash);
  }

  final int schemaVersion;
  final String sceneContractId;
  final int revision;
  final String sceneContractHash;
  final String projectCharterHash;
  final String arcContractHash;
  final String previousAcceptedSceneContractHash;
  final String corePromiseId;
  final String phaseGoalId;
  final String chapterId;
  final String sceneId;
  final int sceneIndex;
  final String sceneContribution;
  final PovPolicy povPolicy;
  final List<String> worldRuleRefs;
  final List<String> requiredFactRefs;
  final List<String> forbiddenContradictions;
  final List<String> activePromiseIds;
  final List<String> payoffWindowIds;
  final List<String> requiredStateChangeTypes;
  final List<String> castIds;
  final String sourceLedgerHash;
  final int repairBudget;
  final int replanBudget;

  Map<String, Object?> get identityJson => {
    'schemaVersion': schemaVersion,
    'sceneContractId': sceneContractId,
    'revision': revision,
    'projectCharterHash': projectCharterHash,
    'arcContractHash': arcContractHash,
    'previousAcceptedSceneContractHash': previousAcceptedSceneContractHash,
    'corePromiseId': corePromiseId,
    'phaseGoalId': phaseGoalId,
    'chapterId': chapterId,
    'sceneId': sceneId,
    'sceneIndex': sceneIndex,
    'sceneContribution': sceneContribution,
    'povPolicy': povPolicy.toJson(),
    'worldRuleRefs': worldRuleRefs,
    'requiredFactRefs': requiredFactRefs,
    'forbiddenContradictions': forbiddenContradictions,
    'activePromiseIds': activePromiseIds,
    'payoffWindowIds': payoffWindowIds,
    'requiredStateChangeTypes': requiredStateChangeTypes,
    'castIds': castIds,
    'sourceLedgerHash': sourceLedgerHash,
    'repairBudget': repairBudget,
    'replanBudget': replanBudget,
  };

  String get canonicalHash => AppLlmCanonicalHash.domainHash(
    'scene-narrative-contract-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => {
    ...identityJson,
    'sceneContractHash': sceneContractHash,
  };

  factory SceneNarrativeContract.create({
    required int schemaVersion,
    required String sceneContractId,
    required int revision,
    required String projectCharterHash,
    required String arcContractHash,
    required String previousAcceptedSceneContractHash,
    required String corePromiseId,
    required String phaseGoalId,
    required String chapterId,
    required String sceneId,
    required int sceneIndex,
    required String sceneContribution,
    required PovPolicy povPolicy,
    List<String> worldRuleRefs = const [],
    List<String> requiredFactRefs = const [],
    List<String> forbiddenContradictions = const [],
    List<String> activePromiseIds = const [],
    List<String> payoffWindowIds = const [],
    List<String> requiredStateChangeTypes = const [],
    List<String> castIds = const [],
    required String sourceLedgerHash,
    required int repairBudget,
    required int replanBudget,
  }) {
    final normalizedWorldRuleRefs = _immutableSortedStrings(worldRuleRefs);
    final normalizedRequiredFactRefs = _immutableSortedStrings(
      requiredFactRefs,
    );
    final normalizedForbiddenContradictions = _immutableSortedStrings(
      forbiddenContradictions,
    );
    final normalizedActivePromiseIds = _immutableSortedStrings(
      activePromiseIds,
    );
    final normalizedPayoffWindowIds = _immutableSortedStrings(payoffWindowIds);
    final normalizedRequiredStateChangeTypes = _immutableSortedStrings(
      requiredStateChangeTypes,
    );
    final normalizedCastIds = _immutableSortedStrings(castIds);
    final identityJson = {
      'schemaVersion': schemaVersion,
      'sceneContractId': sceneContractId,
      'revision': revision,
      'projectCharterHash': projectCharterHash,
      'arcContractHash': arcContractHash,
      'previousAcceptedSceneContractHash': previousAcceptedSceneContractHash,
      'corePromiseId': corePromiseId,
      'phaseGoalId': phaseGoalId,
      'chapterId': chapterId,
      'sceneId': sceneId,
      'sceneIndex': sceneIndex,
      'sceneContribution': sceneContribution,
      'povPolicy': povPolicy.toJson(),
      'worldRuleRefs': normalizedWorldRuleRefs,
      'requiredFactRefs': normalizedRequiredFactRefs,
      'forbiddenContradictions': normalizedForbiddenContradictions,
      'activePromiseIds': normalizedActivePromiseIds,
      'payoffWindowIds': normalizedPayoffWindowIds,
      'requiredStateChangeTypes': normalizedRequiredStateChangeTypes,
      'castIds': normalizedCastIds,
      'sourceLedgerHash': sourceLedgerHash,
      'repairBudget': repairBudget,
      'replanBudget': replanBudget,
    };
    return SceneNarrativeContract(
      schemaVersion: schemaVersion,
      sceneContractId: sceneContractId,
      revision: revision,
      sceneContractHash: AppLlmCanonicalHash.domainHash(
        'scene-narrative-contract-v1',
        identityJson,
      ),
      projectCharterHash: projectCharterHash,
      arcContractHash: arcContractHash,
      previousAcceptedSceneContractHash: previousAcceptedSceneContractHash,
      corePromiseId: corePromiseId,
      phaseGoalId: phaseGoalId,
      chapterId: chapterId,
      sceneId: sceneId,
      sceneIndex: sceneIndex,
      sceneContribution: sceneContribution,
      povPolicy: povPolicy,
      worldRuleRefs: normalizedWorldRuleRefs,
      requiredFactRefs: normalizedRequiredFactRefs,
      forbiddenContradictions: normalizedForbiddenContradictions,
      activePromiseIds: normalizedActivePromiseIds,
      payoffWindowIds: normalizedPayoffWindowIds,
      requiredStateChangeTypes: normalizedRequiredStateChangeTypes,
      castIds: normalizedCastIds,
      sourceLedgerHash: sourceLedgerHash,
      repairBudget: repairBudget,
      replanBudget: replanBudget,
    );
  }

  factory SceneNarrativeContract.fromJson(Map<String, Object?> json) =>
      SceneNarrativeContract(
        schemaVersion: _int(json, 'schemaVersion'),
        sceneContractId: _string(json, 'sceneContractId'),
        revision: _int(json, 'revision'),
        sceneContractHash: _string(json, 'sceneContractHash'),
        projectCharterHash: _string(json, 'projectCharterHash'),
        arcContractHash: _string(json, 'arcContractHash'),
        previousAcceptedSceneContractHash: _string(
          json,
          'previousAcceptedSceneContractHash',
        ),
        corePromiseId: _string(json, 'corePromiseId'),
        phaseGoalId: _string(json, 'phaseGoalId'),
        chapterId: _string(json, 'chapterId'),
        sceneId: _string(json, 'sceneId'),
        sceneIndex: _int(json, 'sceneIndex'),
        sceneContribution: _string(json, 'sceneContribution'),
        povPolicy: PovPolicy.fromJson(_map(json, 'povPolicy')),
        worldRuleRefs: _stringList(json, 'worldRuleRefs'),
        requiredFactRefs: _stringList(json, 'requiredFactRefs'),
        forbiddenContradictions: _stringList(json, 'forbiddenContradictions'),
        activePromiseIds: _stringList(json, 'activePromiseIds'),
        payoffWindowIds: _stringList(json, 'payoffWindowIds'),
        requiredStateChangeTypes: _stringList(json, 'requiredStateChangeTypes'),
        castIds: _stringList(json, 'castIds'),
        sourceLedgerHash: _string(json, 'sourceLedgerHash'),
        repairBudget: _int(json, 'repairBudget'),
        replanBudget: _int(json, 'replanBudget'),
      );
}

final class NarrativeContractChain {
  NarrativeContractChain({
    required this.projectCharter,
    required this.arcContract,
    required this.sceneContract,
  }) {
    if (arcContract.projectCharterId != projectCharter.charterId ||
        arcContract.projectCharterHash != projectCharter.charterHash ||
        sceneContract.projectCharterHash != projectCharter.charterHash ||
        sceneContract.arcContractHash != arcContract.arcContractHash ||
        sceneContract.corePromiseId != projectCharter.corePromiseId ||
        sceneContract.phaseGoalId != arcContract.phaseGoalId) {
      throw ArgumentError('narrative contract chain does not align');
    }
  }

  final ProjectNarrativeCharter projectCharter;
  final ArcContract arcContract;
  final SceneNarrativeContract sceneContract;

  Map<String, Object?> get identityJson => {
    'schemaVersion': sceneContract.schemaVersion,
    'projectCharterHash': projectCharter.charterHash,
    'arcContractHash': arcContract.arcContractHash,
    'sceneContractHash': sceneContract.sceneContractHash,
  };

  String get chainHash => AppLlmCanonicalHash.domainHash(
    'narrative-contract-chain-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => {
    'projectCharter': projectCharter.toJson(),
    'arcContract': arcContract.toJson(),
    'sceneContract': sceneContract.toJson(),
    'chainHash': chainHash,
  };

  factory NarrativeContractChain.fromJson(Map<String, Object?> json) {
    final chain = NarrativeContractChain(
      projectCharter: ProjectNarrativeCharter.fromJson(
        _map(json, 'projectCharter'),
      ),
      arcContract: ArcContract.fromJson(_map(json, 'arcContract')),
      sceneContract: SceneNarrativeContract.fromJson(
        _map(json, 'sceneContract'),
      ),
    );
    if (json.containsKey('chainHash')) {
      _requireHashMatches(
        'chainHash',
        _string(json, 'chainHash'),
        chain.chainHash,
      );
    }
    return chain;
  }
}

final class NarrativeTransitionProposal {
  NarrativeTransitionProposal({
    required this.proposalId,
    required this.fromContractHash,
    required this.proposedContractHash,
    required this.transitionKind,
    required this.reason,
    List<String> affectedPromiseIds = const [],
    List<String> affectedLedgerEntryIds = const [],
    required this.authorDecision,
    this.authorReceiptId,
  }) : affectedPromiseIds = _immutableSortedStrings(affectedPromiseIds),
       affectedLedgerEntryIds = _immutableSortedStrings(
         affectedLedgerEntryIds,
       ) {
    for (final entry in {
      'proposalId': proposalId,
      'fromContractHash': fromContractHash,
      'proposedContractHash': proposedContractHash,
      'reason': reason,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    if (authorDecision == AuthorDecisionStatus.accepted &&
        (authorReceiptId == null || authorReceiptId!.isEmpty)) {
      throw ArgumentError('accepted transition requires authorReceiptId');
    }
  }

  final String proposalId;
  final String fromContractHash;
  final String proposedContractHash;
  final NarrativeTransitionKind transitionKind;
  final String reason;
  final List<String> affectedPromiseIds;
  final List<String> affectedLedgerEntryIds;
  final AuthorDecisionStatus authorDecision;
  final String? authorReceiptId;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'proposalId': proposalId,
    'fromContractHash': fromContractHash,
    'proposedContractHash': proposedContractHash,
    'transitionKind': transitionKind.wire,
    'reason': reason,
    'affectedPromiseIds': affectedPromiseIds,
    'affectedLedgerEntryIds': affectedLedgerEntryIds,
  };

  String get proposalHash => AppLlmCanonicalHash.domainHash(
    'narrative-transition-proposal-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => _withoutNulls({
    ...identityJson,
    'authorDecision': authorDecision.wire,
    'authorReceiptId': authorReceiptId,
  });

  factory NarrativeTransitionProposal.fromJson(Map<String, Object?> json) =>
      NarrativeTransitionProposal(
        proposalId: _string(json, 'proposalId'),
        fromContractHash: _string(json, 'fromContractHash'),
        proposedContractHash: _string(json, 'proposedContractHash'),
        transitionKind: _enumValue(
          json,
          'transitionKind',
          NarrativeTransitionKind.values,
          (value) => value.wire,
        ),
        reason: _string(json, 'reason'),
        affectedPromiseIds: _stringList(json, 'affectedPromiseIds'),
        affectedLedgerEntryIds: _stringList(json, 'affectedLedgerEntryIds'),
        authorDecision: _enumValue(
          json,
          'authorDecision',
          AuthorDecisionStatus.values,
          (value) => value.wire,
        ),
        authorReceiptId: _optionalString(json, 'authorReceiptId'),
      );
}

final class AuthorTransitionReceipt {
  AuthorTransitionReceipt({
    required this.receiptId,
    required this.proposalId,
    required this.fromContractHash,
    required this.proposedContractHash,
    required this.transitionKind,
    required this.proposalHash,
    required this.decision,
    required this.authorIdHash,
    required this.createdAtMs,
  }) {
    if (createdAtMs < 0) {
      throw ArgumentError('createdAtMs must be non-negative');
    }
    for (final entry in {
      'receiptId': receiptId,
      'proposalId': proposalId,
      'fromContractHash': fromContractHash,
      'proposedContractHash': proposedContractHash,
      'proposalHash': proposalHash,
      'authorIdHash': authorIdHash,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
  }

  final String receiptId;
  final String proposalId;
  final String fromContractHash;
  final String proposedContractHash;
  final NarrativeTransitionKind transitionKind;
  final String proposalHash;
  final AuthorDecisionStatus decision;
  final String authorIdHash;
  final int createdAtMs;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'receiptId': receiptId,
    'proposalId': proposalId,
    'fromContractHash': fromContractHash,
    'proposedContractHash': proposedContractHash,
    'transitionKind': transitionKind.wire,
    'proposalHash': proposalHash,
    'decision': decision.wire,
    'authorIdHash': authorIdHash,
  };

  String get receiptHash => AppLlmCanonicalHash.domainHash(
    'author-transition-receipt-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => {
    ...identityJson,
    'createdAtMs': createdAtMs,
  };

  factory AuthorTransitionReceipt.fromJson(Map<String, Object?> json) =>
      AuthorTransitionReceipt(
        receiptId: _string(json, 'receiptId'),
        proposalId: _string(json, 'proposalId'),
        fromContractHash: _string(json, 'fromContractHash'),
        proposedContractHash: _string(json, 'proposedContractHash'),
        transitionKind: _enumValue(
          json,
          'transitionKind',
          NarrativeTransitionKind.values,
          (value) => value.wire,
        ),
        proposalHash: _string(json, 'proposalHash'),
        decision: _enumValue(
          json,
          'decision',
          AuthorDecisionStatus.values,
          (value) => value.wire,
        ),
        authorIdHash: _string(json, 'authorIdHash'),
        createdAtMs: _int(json, 'createdAtMs'),
      );
}

final class ProjectVoiceProfile {
  ProjectVoiceProfile({
    required this.schemaVersion,
    required this.profileId,
    required this.projectId,
    required this.profileHash,
    required this.displayName,
    required this.styleIntensity,
    List<String> genreTags = const [],
    required this.povMode,
    required this.narrativeDistance,
    required this.lexiconRegister,
    List<String> metaphorDomains = const [],
    List<String> sensoryPriorities = const [],
    required this.rhythm,
    required this.dialogue,
    required this.descriptionDensity,
    required this.emotionalTemperature,
    List<VoiceConstraint> voiceConstraints = const [],
    required this.projectOwnedNotes,
    List<String> tabooPatterns = const [],
    List<AllowedDeviation> allowedDeviations = const [],
    List<String> provenanceRefs = const [],
    required this.promptReleaseHash,
  }) : genreTags = _immutableSortedStrings(genreTags),
       metaphorDomains = _immutableSortedStrings(metaphorDomains),
       sensoryPriorities = _immutableSortedStrings(sensoryPriorities),
       voiceConstraints = _immutableList(voiceConstraints),
       tabooPatterns = _immutableSortedStrings(tabooPatterns),
       allowedDeviations = _immutableList(allowedDeviations),
       provenanceRefs = _immutableSortedStrings(provenanceRefs) {
    _validateVersionRevision(schemaVersion, 0);
    _requireRange(styleIntensity, 0, 100, 'styleIntensity');
    for (final entry in {
      'profileId': profileId,
      'projectId': projectId,
      'promptReleaseHash': promptReleaseHash,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    _requireHashMatches('profileHash', profileHash, canonicalHash);
  }

  final int schemaVersion;
  final String profileId;
  final String projectId;
  final String profileHash;
  final String displayName;
  final int styleIntensity;
  final List<String> genreTags;
  final PovMode povMode;
  final NarrativeDistancePolicy narrativeDistance;
  final RegisterPolicy lexiconRegister;
  final List<String> metaphorDomains;
  final List<String> sensoryPriorities;
  final RhythmPolicy rhythm;
  final DialoguePolicy dialogue;
  final DensityPolicy descriptionDensity;
  final EmotionalTemperature emotionalTemperature;
  final List<VoiceConstraint> voiceConstraints;
  final String projectOwnedNotes;
  final List<String> tabooPatterns;
  final List<AllowedDeviation> allowedDeviations;
  final List<String> provenanceRefs;
  final String promptReleaseHash;

  static int styleIntensityFromLegacy(int legacyIntensity) {
    if (legacyIntensity <= 0) return 0;
    if (legacyIntensity == 1) return 34;
    if (legacyIntensity == 2) return 67;
    return 100;
  }

  Map<String, Object?> get identityJson => {
    'schemaVersion': schemaVersion,
    'profileId': profileId,
    'projectId': projectId,
    'styleIntensity': styleIntensity,
    'genreTags': genreTags,
    'povMode': povMode.wire,
    'narrativeDistance': narrativeDistance.wire,
    'lexiconRegister': lexiconRegister.wire,
    'metaphorDomains': metaphorDomains,
    'sensoryPriorities': sensoryPriorities,
    'rhythm': rhythm.toJson(),
    'dialogue': dialogue.toJson(),
    'descriptionDensity': descriptionDensity.toJson(),
    'emotionalTemperature': emotionalTemperature.wire,
    'voiceConstraints': [for (final item in voiceConstraints) item.toJson()],
    'projectOwnedNotes': projectOwnedNotes,
    'tabooPatterns': tabooPatterns,
    'allowedDeviations': [for (final item in allowedDeviations) item.toJson()],
    'provenanceRefs': provenanceRefs,
    'promptReleaseHash': promptReleaseHash,
  };

  String get canonicalHash =>
      AppLlmCanonicalHash.domainHash('project-voice-profile-v1', identityJson);

  Map<String, Object?> toJson() => {
    ...identityJson,
    'profileHash': profileHash,
    'displayName': displayName,
    'projectOwnedNotes': projectOwnedNotes,
    'provenanceRefs': provenanceRefs,
  };

  factory ProjectVoiceProfile.create({
    required int schemaVersion,
    required String profileId,
    required String projectId,
    required String displayName,
    required int styleIntensity,
    List<String> genreTags = const [],
    required PovMode povMode,
    required NarrativeDistancePolicy narrativeDistance,
    required RegisterPolicy lexiconRegister,
    List<String> metaphorDomains = const [],
    List<String> sensoryPriorities = const [],
    required RhythmPolicy rhythm,
    required DialoguePolicy dialogue,
    required DensityPolicy descriptionDensity,
    required EmotionalTemperature emotionalTemperature,
    List<VoiceConstraint> voiceConstraints = const [],
    required String projectOwnedNotes,
    List<String> tabooPatterns = const [],
    List<AllowedDeviation> allowedDeviations = const [],
    List<String> provenanceRefs = const [],
    required String promptReleaseHash,
  }) {
    final normalizedGenreTags = _immutableSortedStrings(genreTags);
    final normalizedMetaphorDomains = _immutableSortedStrings(metaphorDomains);
    final normalizedSensoryPriorities = _immutableSortedStrings(
      sensoryPriorities,
    );
    final normalizedVoiceConstraints = _immutableList(voiceConstraints);
    final normalizedTabooPatterns = _immutableSortedStrings(tabooPatterns);
    final normalizedAllowedDeviations = _immutableList(allowedDeviations);
    final identityJson = {
      'schemaVersion': schemaVersion,
      'profileId': profileId,
      'projectId': projectId,
      'styleIntensity': styleIntensity,
      'genreTags': normalizedGenreTags,
      'povMode': povMode.wire,
      'narrativeDistance': narrativeDistance.wire,
      'lexiconRegister': lexiconRegister.wire,
      'metaphorDomains': normalizedMetaphorDomains,
      'sensoryPriorities': normalizedSensoryPriorities,
      'rhythm': rhythm.toJson(),
      'dialogue': dialogue.toJson(),
      'descriptionDensity': descriptionDensity.toJson(),
      'emotionalTemperature': emotionalTemperature.wire,
      'voiceConstraints': [
        for (final item in normalizedVoiceConstraints) item.toJson(),
      ],
      'projectOwnedNotes': projectOwnedNotes,
      'tabooPatterns': normalizedTabooPatterns,
      'allowedDeviations': [
        for (final item in normalizedAllowedDeviations) item.toJson(),
      ],
      'provenanceRefs': _immutableSortedStrings(provenanceRefs),
      'promptReleaseHash': promptReleaseHash,
    };
    return ProjectVoiceProfile(
      schemaVersion: schemaVersion,
      profileId: profileId,
      projectId: projectId,
      profileHash: AppLlmCanonicalHash.domainHash(
        'project-voice-profile-v1',
        identityJson,
      ),
      displayName: displayName,
      styleIntensity: styleIntensity,
      genreTags: normalizedGenreTags,
      povMode: povMode,
      narrativeDistance: narrativeDistance,
      lexiconRegister: lexiconRegister,
      metaphorDomains: normalizedMetaphorDomains,
      sensoryPriorities: normalizedSensoryPriorities,
      rhythm: rhythm,
      dialogue: dialogue,
      descriptionDensity: descriptionDensity,
      emotionalTemperature: emotionalTemperature,
      voiceConstraints: normalizedVoiceConstraints,
      projectOwnedNotes: projectOwnedNotes,
      tabooPatterns: normalizedTabooPatterns,
      allowedDeviations: normalizedAllowedDeviations,
      provenanceRefs: provenanceRefs,
      promptReleaseHash: promptReleaseHash,
    );
  }

  factory ProjectVoiceProfile.fromJson(Map<String, Object?> json) =>
      ProjectVoiceProfile(
        schemaVersion: _int(json, 'schemaVersion'),
        profileId: _string(json, 'profileId'),
        projectId: _string(json, 'projectId'),
        profileHash: _string(json, 'profileHash'),
        displayName: _string(json, 'displayName'),
        styleIntensity: _int(json, 'styleIntensity'),
        genreTags: _stringList(json, 'genreTags'),
        povMode: _enumValue(
          json,
          'povMode',
          PovMode.values,
          (value) => value.wire,
        ),
        narrativeDistance: _enumValue(
          json,
          'narrativeDistance',
          NarrativeDistancePolicy.values,
          (value) => value.wire,
        ),
        lexiconRegister: _enumValue(
          json,
          'lexiconRegister',
          RegisterPolicy.values,
          (value) => value.wire,
        ),
        metaphorDomains: _stringList(json, 'metaphorDomains'),
        sensoryPriorities: _stringList(json, 'sensoryPriorities'),
        rhythm: RhythmPolicy.fromJson(_map(json, 'rhythm')),
        dialogue: DialoguePolicy.fromJson(_map(json, 'dialogue')),
        descriptionDensity: DensityPolicy.fromJson(
          _map(json, 'descriptionDensity'),
        ),
        emotionalTemperature: _enumValue(
          json,
          'emotionalTemperature',
          EmotionalTemperature.values,
          (value) => value.wire,
        ),
        voiceConstraints: _listOfMaps(
          json,
          'voiceConstraints',
        ).map(VoiceConstraint.fromJson).toList(growable: false),
        projectOwnedNotes: _string(json, 'projectOwnedNotes'),
        tabooPatterns: _stringList(json, 'tabooPatterns'),
        allowedDeviations: _listOfMaps(
          json,
          'allowedDeviations',
        ).map(AllowedDeviation.fromJson).toList(growable: false),
        provenanceRefs: _stringList(json, 'provenanceRefs'),
        promptReleaseHash: _string(json, 'promptReleaseHash'),
      );
}

final class SceneCraftContract {
  SceneCraftContract({
    required this.schemaVersion,
    required this.craftId,
    required this.craftHash,
    required this.sceneContractId,
    required this.sceneContractHash,
    required this.voiceProfileId,
    required this.voiceProfileHash,
    required this.revision,
    required this.primaryFunction,
    List<SceneFunction> secondaryFunctions = const [],
    required this.sceneGoal,
    required this.blockingConflict,
    required this.progression,
    required this.exitCondition,
    List<String> plannedBeats = const [],
    List<StateChangeTarget> desiredStateChanges = const [],
    List<String> requiredReveals = const [],
    List<String> requiredWithholds = const [],
    required this.readerQuestionBefore,
    required this.readerQuestionAfterTarget,
    required this.pressureCurve,
    required this.rhythmIntent,
    List<String> invariantsToPreserve = const [],
    List<AllowedDeviation> allowedDeviations = const [],
    required this.targetedRepairBudget,
    required this.fullRewriteBudget,
  }) : secondaryFunctions = _immutableList(secondaryFunctions),
       plannedBeats = _immutableList(plannedBeats),
       desiredStateChanges = _immutableList(desiredStateChanges),
       requiredReveals = _immutableSortedStrings(requiredReveals),
       requiredWithholds = _immutableSortedStrings(requiredWithholds),
       invariantsToPreserve = _immutableSortedStrings(invariantsToPreserve),
       allowedDeviations = _immutableList(allowedDeviations) {
    _validateVersionRevision(schemaVersion, revision);
    if (targetedRepairBudget < 0 || fullRewriteBudget < 0) {
      throw ArgumentError('repair budgets must be non-negative');
    }
    for (final entry in {
      'craftId': craftId,
      'sceneContractId': sceneContractId,
      'sceneContractHash': sceneContractHash,
      'voiceProfileId': voiceProfileId,
      'voiceProfileHash': voiceProfileHash,
      'sceneGoal': sceneGoal,
      'blockingConflict': blockingConflict,
      'progression': progression,
      'exitCondition': exitCondition,
      'readerQuestionBefore': readerQuestionBefore,
      'readerQuestionAfterTarget': readerQuestionAfterTarget,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    _requireHashMatches('craftHash', craftHash, canonicalHash);
  }

  final int schemaVersion;
  final String craftId;
  final String craftHash;
  final String sceneContractId;
  final String sceneContractHash;
  final String voiceProfileId;
  final String voiceProfileHash;
  final int revision;
  final SceneFunction primaryFunction;
  final List<SceneFunction> secondaryFunctions;
  final String sceneGoal;
  final String blockingConflict;
  final String progression;
  final String exitCondition;
  final List<String> plannedBeats;
  final List<StateChangeTarget> desiredStateChanges;
  final List<String> requiredReveals;
  final List<String> requiredWithholds;
  final String readerQuestionBefore;
  final String readerQuestionAfterTarget;
  final PressureCurve pressureCurve;
  final RhythmIntent rhythmIntent;
  final List<String> invariantsToPreserve;
  final List<AllowedDeviation> allowedDeviations;
  final int targetedRepairBudget;
  final int fullRewriteBudget;

  Map<String, Object?> get identityJson => {
    'schemaVersion': schemaVersion,
    'craftId': craftId,
    'sceneContractId': sceneContractId,
    'sceneContractHash': sceneContractHash,
    'voiceProfileId': voiceProfileId,
    'voiceProfileHash': voiceProfileHash,
    'revision': revision,
    'primaryFunction': primaryFunction.wire,
    'secondaryFunctions': [for (final value in secondaryFunctions) value.wire],
    'sceneGoal': sceneGoal,
    'blockingConflict': blockingConflict,
    'progression': progression,
    'exitCondition': exitCondition,
    'plannedBeats': plannedBeats,
    'desiredStateChanges': [
      for (final value in desiredStateChanges) value.toJson(),
    ],
    'requiredReveals': requiredReveals,
    'requiredWithholds': requiredWithholds,
    'readerQuestionBefore': readerQuestionBefore,
    'readerQuestionAfterTarget': readerQuestionAfterTarget,
    'pressureCurve': pressureCurve.wire,
    'rhythmIntent': rhythmIntent.toJson(),
    'invariantsToPreserve': invariantsToPreserve,
    'allowedDeviations': [
      for (final value in allowedDeviations) value.toJson(),
    ],
    'targetedRepairBudget': targetedRepairBudget,
    'fullRewriteBudget': fullRewriteBudget,
  };

  String get canonicalHash =>
      AppLlmCanonicalHash.domainHash('scene-craft-contract-v1', identityJson);

  Map<String, Object?> toJson() => {...identityJson, 'craftHash': craftHash};

  factory SceneCraftContract.create({
    required int schemaVersion,
    required String craftId,
    required String sceneContractId,
    required String sceneContractHash,
    required String voiceProfileId,
    required String voiceProfileHash,
    required int revision,
    required SceneFunction primaryFunction,
    List<SceneFunction> secondaryFunctions = const [],
    required String sceneGoal,
    required String blockingConflict,
    required String progression,
    required String exitCondition,
    List<String> plannedBeats = const [],
    List<StateChangeTarget> desiredStateChanges = const [],
    List<String> requiredReveals = const [],
    List<String> requiredWithholds = const [],
    required String readerQuestionBefore,
    required String readerQuestionAfterTarget,
    required PressureCurve pressureCurve,
    required RhythmIntent rhythmIntent,
    List<String> invariantsToPreserve = const [],
    List<AllowedDeviation> allowedDeviations = const [],
    required int targetedRepairBudget,
    required int fullRewriteBudget,
  }) {
    final normalizedSecondaryFunctions = _immutableList(secondaryFunctions);
    final normalizedPlannedBeats = _immutableList(plannedBeats);
    final normalizedDesiredStateChanges = _immutableList(desiredStateChanges);
    final normalizedRequiredReveals = _immutableSortedStrings(requiredReveals);
    final normalizedRequiredWithholds = _immutableSortedStrings(
      requiredWithholds,
    );
    final normalizedInvariants = _immutableSortedStrings(invariantsToPreserve);
    final normalizedAllowedDeviations = _immutableList(allowedDeviations);
    final identityJson = {
      'schemaVersion': schemaVersion,
      'craftId': craftId,
      'sceneContractId': sceneContractId,
      'sceneContractHash': sceneContractHash,
      'voiceProfileId': voiceProfileId,
      'voiceProfileHash': voiceProfileHash,
      'revision': revision,
      'primaryFunction': primaryFunction.wire,
      'secondaryFunctions': [
        for (final value in normalizedSecondaryFunctions) value.wire,
      ],
      'sceneGoal': sceneGoal,
      'blockingConflict': blockingConflict,
      'progression': progression,
      'exitCondition': exitCondition,
      'plannedBeats': normalizedPlannedBeats,
      'desiredStateChanges': [
        for (final value in normalizedDesiredStateChanges) value.toJson(),
      ],
      'requiredReveals': normalizedRequiredReveals,
      'requiredWithholds': normalizedRequiredWithholds,
      'readerQuestionBefore': readerQuestionBefore,
      'readerQuestionAfterTarget': readerQuestionAfterTarget,
      'pressureCurve': pressureCurve.wire,
      'rhythmIntent': rhythmIntent.toJson(),
      'invariantsToPreserve': normalizedInvariants,
      'allowedDeviations': [
        for (final value in normalizedAllowedDeviations) value.toJson(),
      ],
      'targetedRepairBudget': targetedRepairBudget,
      'fullRewriteBudget': fullRewriteBudget,
    };
    return SceneCraftContract(
      schemaVersion: schemaVersion,
      craftId: craftId,
      craftHash: AppLlmCanonicalHash.domainHash(
        'scene-craft-contract-v1',
        identityJson,
      ),
      sceneContractId: sceneContractId,
      sceneContractHash: sceneContractHash,
      voiceProfileId: voiceProfileId,
      voiceProfileHash: voiceProfileHash,
      revision: revision,
      primaryFunction: primaryFunction,
      secondaryFunctions: normalizedSecondaryFunctions,
      sceneGoal: sceneGoal,
      blockingConflict: blockingConflict,
      progression: progression,
      exitCondition: exitCondition,
      plannedBeats: normalizedPlannedBeats,
      desiredStateChanges: normalizedDesiredStateChanges,
      requiredReveals: normalizedRequiredReveals,
      requiredWithholds: normalizedRequiredWithholds,
      readerQuestionBefore: readerQuestionBefore,
      readerQuestionAfterTarget: readerQuestionAfterTarget,
      pressureCurve: pressureCurve,
      rhythmIntent: rhythmIntent,
      invariantsToPreserve: normalizedInvariants,
      allowedDeviations: normalizedAllowedDeviations,
      targetedRepairBudget: targetedRepairBudget,
      fullRewriteBudget: fullRewriteBudget,
    );
  }

  factory SceneCraftContract.fromJson(Map<String, Object?> json) {
    final contract = SceneCraftContract.create(
      schemaVersion: _int(json, 'schemaVersion'),
      craftId: _string(json, 'craftId'),
      sceneContractId: _string(json, 'sceneContractId'),
      sceneContractHash: _string(json, 'sceneContractHash'),
      voiceProfileId: _string(json, 'voiceProfileId'),
      voiceProfileHash: _string(json, 'voiceProfileHash'),
      revision: _int(json, 'revision'),
      primaryFunction: _enumValue(
        json,
        'primaryFunction',
        SceneFunction.values,
        (value) => value.wire,
      ),
      secondaryFunctions: _enumList(
        json,
        'secondaryFunctions',
        SceneFunction.values,
        (value) => value.wire,
      ),
      sceneGoal: _string(json, 'sceneGoal'),
      blockingConflict: _string(json, 'blockingConflict'),
      progression: _string(json, 'progression'),
      exitCondition: _string(json, 'exitCondition'),
      plannedBeats: _stringList(json, 'plannedBeats'),
      desiredStateChanges: _listOfMaps(
        json,
        'desiredStateChanges',
      ).map(StateChangeTarget.fromJson).toList(growable: false),
      requiredReveals: _stringList(json, 'requiredReveals'),
      requiredWithholds: _stringList(json, 'requiredWithholds'),
      readerQuestionBefore: _string(json, 'readerQuestionBefore'),
      readerQuestionAfterTarget: _string(json, 'readerQuestionAfterTarget'),
      pressureCurve: _enumValue(
        json,
        'pressureCurve',
        PressureCurve.values,
        (value) => value.wire,
      ),
      rhythmIntent: RhythmIntent.fromJson(_map(json, 'rhythmIntent')),
      invariantsToPreserve: _stringList(json, 'invariantsToPreserve'),
      allowedDeviations: _listOfMaps(
        json,
        'allowedDeviations',
      ).map(AllowedDeviation.fromJson).toList(growable: false),
      targetedRepairBudget: _int(json, 'targetedRepairBudget'),
      fullRewriteBudget: _int(json, 'fullRewriteBudget'),
    );
    if (json.containsKey('craftHash')) {
      _requireHashMatches(
        'craftHash',
        _string(json, 'craftHash'),
        contract.craftHash,
      );
    }
    return contract;
  }
}

final class PovPolicy {
  PovPolicy({
    required this.mode,
    List<String> allowedPovCharacterIds = const [],
    required this.allowFreeIndirectDiscourse,
    required this.allowUnreliableNarrator,
    required this.allowTimelineReordering,
    List<String> declaredKnowledgeExceptions = const [],
  }) : allowedPovCharacterIds = _immutableSortedStrings(allowedPovCharacterIds),
       declaredKnowledgeExceptions = _immutableSortedStrings(
         declaredKnowledgeExceptions,
       );

  final PovMode mode;
  final List<String> allowedPovCharacterIds;
  final bool allowFreeIndirectDiscourse;
  final bool allowUnreliableNarrator;
  final bool allowTimelineReordering;
  final List<String> declaredKnowledgeExceptions;

  Map<String, Object?> toJson() => {
    'mode': mode.wire,
    'allowedPovCharacterIds': allowedPovCharacterIds,
    'allowFreeIndirectDiscourse': allowFreeIndirectDiscourse,
    'allowUnreliableNarrator': allowUnreliableNarrator,
    'allowTimelineReordering': allowTimelineReordering,
    'declaredKnowledgeExceptions': declaredKnowledgeExceptions,
  };

  factory PovPolicy.fromJson(Map<String, Object?> json) => PovPolicy(
    mode: _enumValue(json, 'mode', PovMode.values, (value) => value.wire),
    allowedPovCharacterIds: _stringList(json, 'allowedPovCharacterIds'),
    allowFreeIndirectDiscourse: _bool(json, 'allowFreeIndirectDiscourse'),
    allowUnreliableNarrator: _bool(json, 'allowUnreliableNarrator'),
    allowTimelineReordering: _bool(json, 'allowTimelineReordering'),
    declaredKnowledgeExceptions: _stringList(
      json,
      'declaredKnowledgeExceptions',
    ),
  );
}

final class AllowedDeviation {
  AllowedDeviation({
    required this.deviationId,
    required this.axis,
    required this.intendedFunction,
    required this.startCondition,
    required this.endCondition,
    required this.authorizedBy,
  }) {
    for (final entry in {
      'deviationId': deviationId,
      'axis': axis,
      'intendedFunction': intendedFunction,
      'startCondition': startCondition,
      'endCondition': endCondition,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
  }

  final String deviationId;
  final String axis;
  final String intendedFunction;
  final String startCondition;
  final String endCondition;
  final DeviationAuthorization authorizedBy;

  Map<String, Object?> toJson() => {
    'deviationId': deviationId,
    'axis': axis,
    'intendedFunction': intendedFunction,
    'startCondition': startCondition,
    'endCondition': endCondition,
    'authorizedBy': authorizedBy.wire,
  };

  factory AllowedDeviation.fromJson(Map<String, Object?> json) =>
      AllowedDeviation(
        deviationId: _string(json, 'deviationId'),
        axis: _string(json, 'axis'),
        intendedFunction: _string(json, 'intendedFunction'),
        startCondition: _string(json, 'startCondition'),
        endCondition: _string(json, 'endCondition'),
        authorizedBy: _enumValue(
          json,
          'authorizedBy',
          DeviationAuthorization.values,
          (value) => value.wire,
        ),
      );
}

final class VoiceConstraint {
  VoiceConstraint({
    required this.axis,
    required this.operator,
    required Object? value,
    List<String> sourceIds = const [],
  }) : value = AppLlmCanonicalHash.immutableSnapshot(value),
       sourceIds = _immutableSortedStrings(sourceIds) {
    _requireNonEmpty(axis, 'axis');
    if (this.value == null) throw ArgumentError('value must not be null');
  }

  final String axis;
  final VoiceConstraintOperator operator;
  final Object? value;
  final List<String> sourceIds;

  Map<String, Object?> toJson() => {
    'axis': axis,
    'operator': operator.wire,
    'value': value,
    'sourceIds': sourceIds,
  };

  factory VoiceConstraint.fromJson(Map<String, Object?> json) =>
      VoiceConstraint(
        axis: _string(json, 'axis'),
        operator: _enumValue(
          json,
          'operator',
          VoiceConstraintOperator.values,
          (value) => value.wire,
        ),
        value: json['value'],
        sourceIds: _stringList(json, 'sourceIds'),
      );
}

final class NumericRange {
  NumericRange({
    required this.minimum,
    required this.maximum,
    required this.unit,
  }) {
    _requireFinite(minimum, 'minimum');
    _requireFinite(maximum, 'maximum');
    if (minimum > maximum) throw ArgumentError('minimum must be <= maximum');
    _requireNonEmpty(unit, 'unit');
  }

  final double minimum;
  final double maximum;
  final String unit;

  Map<String, Object?> toJson() => {
    'minimum': minimum,
    'maximum': maximum,
    'unit': unit,
  };

  factory NumericRange.fromJson(Map<String, Object?> json) => NumericRange(
    minimum: _double(json, 'minimum'),
    maximum: _double(json, 'maximum'),
    unit: _string(json, 'unit'),
  );
}

final class RhythmPolicy {
  RhythmPolicy({
    required this.curve,
    Map<String, NumericRange> sentenceLengthBySceneFunction = const {},
    Map<String, NumericRange> paragraphDensityBySceneFunction = const {},
    Map<String, NumericRange> informationDensityBySceneFunction = const {},
    List<AllowedDeviation> allowedDeviations = const [],
  }) : sentenceLengthBySceneFunction = _immutableTypedMap(
         sentenceLengthBySceneFunction,
       ),
       paragraphDensityBySceneFunction = _immutableTypedMap(
         paragraphDensityBySceneFunction,
       ),
       informationDensityBySceneFunction = _immutableTypedMap(
         informationDensityBySceneFunction,
       ),
       allowedDeviations = _immutableList(allowedDeviations);

  final RhythmCurve curve;
  final Map<String, NumericRange> sentenceLengthBySceneFunction;
  final Map<String, NumericRange> paragraphDensityBySceneFunction;
  final Map<String, NumericRange> informationDensityBySceneFunction;
  final List<AllowedDeviation> allowedDeviations;

  Map<String, Object?> toJson() => {
    'curve': curve.wire,
    'sentenceLengthBySceneFunction': {
      for (final entry in sentenceLengthBySceneFunction.entries)
        entry.key: entry.value.toJson(),
    },
    'paragraphDensityBySceneFunction': {
      for (final entry in paragraphDensityBySceneFunction.entries)
        entry.key: entry.value.toJson(),
    },
    'informationDensityBySceneFunction': {
      for (final entry in informationDensityBySceneFunction.entries)
        entry.key: entry.value.toJson(),
    },
    'allowedDeviations': [
      for (final value in allowedDeviations) value.toJson(),
    ],
  };

  factory RhythmPolicy.fromJson(Map<String, Object?> json) => RhythmPolicy(
    curve: _enumValue(json, 'curve', RhythmCurve.values, (value) => value.wire),
    sentenceLengthBySceneFunction: _numericRangeMap(
      json,
      'sentenceLengthBySceneFunction',
    ),
    paragraphDensityBySceneFunction: _numericRangeMap(
      json,
      'paragraphDensityBySceneFunction',
    ),
    informationDensityBySceneFunction: _numericRangeMap(
      json,
      'informationDensityBySceneFunction',
    ),
    allowedDeviations: _listOfMaps(
      json,
      'allowedDeviations',
    ).map(AllowedDeviation.fromJson).toList(growable: false),
  );
}

final class DialoguePolicy {
  DialoguePolicy({
    required this.ratio,
    required this.cadence,
    List<String> speakerDifferentiationRules = const [],
  }) : speakerDifferentiationRules = _immutableSortedStrings(
         speakerDifferentiationRules,
       ) {
    _requireNonEmpty(cadence, 'cadence');
  }

  final NumericRange ratio;
  final String cadence;
  final List<String> speakerDifferentiationRules;

  Map<String, Object?> toJson() => {
    'ratio': ratio.toJson(),
    'cadence': cadence,
    'speakerDifferentiationRules': speakerDifferentiationRules,
  };

  factory DialoguePolicy.fromJson(Map<String, Object?> json) => DialoguePolicy(
    ratio: NumericRange.fromJson(_map(json, 'ratio')),
    cadence: _string(json, 'cadence'),
    speakerDifferentiationRules: _stringList(
      json,
      'speakerDifferentiationRules',
    ),
  );
}

final class DensityPolicy {
  DensityPolicy({
    required this.descriptionRatio,
    required this.interiorityRatio,
    required this.expositionRatio,
  });

  final NumericRange descriptionRatio;
  final NumericRange interiorityRatio;
  final NumericRange expositionRatio;

  Map<String, Object?> toJson() => {
    'descriptionRatio': descriptionRatio.toJson(),
    'interiorityRatio': interiorityRatio.toJson(),
    'expositionRatio': expositionRatio.toJson(),
  };

  factory DensityPolicy.fromJson(Map<String, Object?> json) => DensityPolicy(
    descriptionRatio: NumericRange.fromJson(_map(json, 'descriptionRatio')),
    interiorityRatio: NumericRange.fromJson(_map(json, 'interiorityRatio')),
    expositionRatio: NumericRange.fromJson(_map(json, 'expositionRatio')),
  );
}

final class StateChangeTarget {
  StateChangeTarget({
    required this.targetId,
    required this.type,
    required this.beforeRef,
    required this.intendedAfter,
    required this.required,
  }) {
    for (final entry in {
      'targetId': targetId,
      'beforeRef': beforeRef,
      'intendedAfter': intendedAfter,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
  }

  final String targetId;
  final StateChangeType type;
  final String beforeRef;
  final String intendedAfter;
  final bool required;

  Map<String, Object?> toJson() => {
    'targetId': targetId,
    'type': type.wire,
    'beforeRef': beforeRef,
    'intendedAfter': intendedAfter,
    'required': required,
  };

  factory StateChangeTarget.fromJson(Map<String, Object?> json) =>
      StateChangeTarget(
        targetId: _string(json, 'targetId'),
        type: _enumValue(
          json,
          'type',
          StateChangeType.values,
          (value) => value.wire,
        ),
        beforeRef: _string(json, 'beforeRef'),
        intendedAfter: _string(json, 'intendedAfter'),
        required: _bool(json, 'required'),
      );
}

final class RhythmIntent {
  RhythmIntent({
    required this.sceneFunction,
    required this.pressureMovement,
    required this.intendedReaderEffect,
    List<String> allowedDeviationIds = const [],
  }) : allowedDeviationIds = _immutableSortedStrings(allowedDeviationIds) {
    _requireNonEmpty(pressureMovement, 'pressureMovement');
    _requireNonEmpty(intendedReaderEffect, 'intendedReaderEffect');
  }

  final SceneFunction sceneFunction;
  final String pressureMovement;
  final String intendedReaderEffect;
  final List<String> allowedDeviationIds;

  Map<String, Object?> toJson() => {
    'sceneFunction': sceneFunction.wire,
    'pressureMovement': pressureMovement,
    'intendedReaderEffect': intendedReaderEffect,
    'allowedDeviationIds': allowedDeviationIds,
  };

  factory RhythmIntent.fromJson(Map<String, Object?> json) => RhythmIntent(
    sceneFunction: _enumValue(
      json,
      'sceneFunction',
      SceneFunction.values,
      (value) => value.wire,
    ),
    pressureMovement: _string(json, 'pressureMovement'),
    intendedReaderEffect: _string(json, 'intendedReaderEffect'),
    allowedDeviationIds: _stringList(json, 'allowedDeviationIds'),
  );
}

final class CraftScore {
  CraftScore({required Map<String, double> dimensions})
    : dimensions = _validatedCraftDimensions(dimensions),
      craftOverall = _weightedCraftOverall(dimensions),
      criticalCraftMinimum = _criticalCraftMinimum(dimensions);

  static const Map<String, double> weights = {
    'prosePrecision': 0.18,
    'paragraphFunction': 0.12,
    'scenePressure': 0.18,
    'characterVoice': 0.15,
    'informationControl': 0.15,
    'coherence': 0.12,
    'completenessAndTurn': 0.10,
  };

  final Map<String, double> dimensions;
  final double craftOverall;
  final double criticalCraftMinimum;

  Map<String, Object?> toJson() => {
    'dimensions': dimensions,
    'craftOverall': craftOverall,
    'criticalCraftMinimum': criticalCraftMinimum,
  };

  factory CraftScore.fromJson(Map<String, Object?> json) {
    final dimensions = _doubleMap(json, 'dimensions');
    final score = CraftScore(dimensions: dimensions);
    final providedOverall = _double(json, 'craftOverall');
    final providedCritical = _double(json, 'criticalCraftMinimum');
    _requireClose(providedOverall, score.craftOverall, 'craftOverall');
    _requireClose(
      providedCritical,
      score.criticalCraftMinimum,
      'criticalCraftMinimum',
    );
    return score;
  }
}

final class StyleFitResult {
  StyleFitResult({
    required this.decision,
    Map<String, String> axisExplanations = const {},
    List<String> deviationIds = const [],
    List<String> evidenceRefs = const [],
    List<DeviationAuthorizationRef> deviationAuthorizationRefs = const [],
  }) : axisExplanations = _immutableStringMap(axisExplanations),
       deviationIds = _immutableSortedStrings(deviationIds),
       evidenceRefs = _immutableSortedStrings(evidenceRefs),
       deviationAuthorizationRefs = _immutableDeviationAuthorizationRefs(
         deviationAuthorizationRefs,
       ) {
    for (final entry in this.axisExplanations.entries) {
      _requireNonEmpty(entry.key, 'style axis');
      _requireNonEmpty(entry.value, 'style axis explanation');
    }
    if (decision != StyleFitDecision.aligned &&
        (this.axisExplanations.isEmpty || this.evidenceRefs.isEmpty)) {
      throw ArgumentError(
        'non-aligned style fit requires axis explanations and evidence',
      );
    }
    if (decision == StyleFitDecision.plannedDeviation) {
      if (this.deviationIds.isEmpty ||
          !this.deviationAuthorizationRefs.any(
            (reference) =>
                reference.authorizedBy ==
                    DeviationAuthorization.sceneContract &&
                this.deviationIds.contains(reference.referenceId),
          )) {
        throw ArgumentError(
          'planned deviations require a scene-contract authorization',
        );
      }
    }
    if (decision == StyleFitDecision.approvedDeviation) {
      if (this.deviationIds.isEmpty ||
          !this.deviationAuthorizationRefs.any(
            (reference) =>
                reference.authorizedBy ==
                    DeviationAuthorization.independentReview ||
                reference.authorizedBy == DeviationAuthorization.authorOverride,
          )) {
        throw ArgumentError(
          'approved deviations require review or author authorization',
        );
      }
    }
  }

  final StyleFitDecision decision;
  final Map<String, String> axisExplanations;
  final List<String> deviationIds;
  final List<String> evidenceRefs;
  final List<DeviationAuthorizationRef> deviationAuthorizationRefs;

  Map<String, Object?> toJson() => {
    'decision': decision.wire,
    'axisExplanations': axisExplanations,
    'deviationIds': deviationIds,
    'evidenceRefs': evidenceRefs,
    'deviationAuthorizationRefs': [
      for (final reference in deviationAuthorizationRefs) reference.toJson(),
    ],
  };

  factory StyleFitResult.fromJson(Map<String, Object?> json) => StyleFitResult(
    decision: _enumValue(
      json,
      'decision',
      StyleFitDecision.values,
      (value) => value.wire,
    ),
    axisExplanations: _stringMap(json, 'axisExplanations'),
    deviationIds: _stringList(json, 'deviationIds'),
    evidenceRefs: _stringList(json, 'evidenceRefs'),
    deviationAuthorizationRefs: _listOfMaps(
      json,
      'deviationAuthorizationRefs',
    ).map(DeviationAuthorizationRef.fromJson).toList(growable: false),
  );
}

final class DeterministicGateRef {
  DeterministicGateRef({
    required this.evidenceHash,
    required this.passed,
    List<String> failureCodes = const [],
  }) : failureCodes = _immutableSortedStrings(failureCodes) {
    _requireNonEmpty(evidenceHash, 'evidenceHash');
    if (!passed && this.failureCodes.isEmpty) {
      throw ArgumentError('failed deterministic gate requires failureCodes');
    }
  }

  final String evidenceHash;
  final bool passed;
  final List<String> failureCodes;

  Map<String, Object?> toJson() => {
    'evidenceHash': evidenceHash,
    'passed': passed,
    'failureCodes': failureCodes,
  };

  factory DeterministicGateRef.fromJson(Map<String, Object?> json) =>
      DeterministicGateRef(
        evidenceHash: _string(json, 'evidenceHash'),
        passed: _bool(json, 'passed'),
        failureCodes: _stringList(json, 'failureCodes'),
      );
}

final class SemanticHardReviewResult {
  SemanticHardReviewResult({
    required this.passed,
    List<String> hardFindingIds = const [],
    required this.calibratedConfidence,
  }) : hardFindingIds = _immutableSortedStrings(hardFindingIds) {
    _requireUnitInterval(calibratedConfidence, 'calibratedConfidence');
    if (!passed && this.hardFindingIds.isEmpty) {
      throw ArgumentError('failed semantic hard review requires findings');
    }
  }

  final bool passed;
  final List<String> hardFindingIds;
  final double calibratedConfidence;

  Map<String, Object?> toJson() => {
    'passed': passed,
    'hardFindingIds': hardFindingIds,
    'calibratedConfidence': calibratedConfidence,
  };

  factory SemanticHardReviewResult.fromJson(Map<String, Object?> json) =>
      SemanticHardReviewResult(
        passed: _bool(json, 'passed'),
        hardFindingIds: _stringList(json, 'hardFindingIds'),
        calibratedConfidence: _double(json, 'calibratedConfidence'),
      );
}

final class ReaderEffectProbeResult {
  ReaderEffectProbeResult({
    Map<String, ReaderEstimate<double>> effectEstimates = const {},
    List<String> warnings = const [],
  }) : effectEstimates = _immutableTypedMap(effectEstimates),
       warnings = _immutableSortedStrings(warnings);

  final Map<String, ReaderEstimate<double>> effectEstimates;
  final List<String> warnings;

  Map<String, Object?> toJson() => {
    'effectEstimates': {
      for (final entry in effectEstimates.entries)
        entry.key: entry.value.toJson(),
    },
    'warnings': warnings,
  };

  factory ReaderEffectProbeResult.fromJson(Map<String, Object?> json) =>
      ReaderEffectProbeResult(
        effectEstimates: {
          for (final entry in _map(json, 'effectEstimates').entries)
            entry.key: ReaderEstimate.doubleFromJson(_asMap(entry.value)),
        },
        warnings: _stringList(json, 'warnings'),
      );
}

final class LongFormEvidenceRef {
  LongFormEvidenceRef({
    required this.artifactHash,
    required this.chapterRange,
    required this.committedLedgerHash,
  }) {
    _requireNonEmpty(artifactHash, 'artifactHash');
    _requireNonEmpty(chapterRange, 'chapterRange');
    _requireNonEmpty(committedLedgerHash, 'committedLedgerHash');
  }

  final String artifactHash;
  final String chapterRange;
  final String committedLedgerHash;

  Map<String, Object?> toJson() => {
    'artifactHash': artifactHash,
    'chapterRange': chapterRange,
    'committedLedgerHash': committedLedgerHash,
  };

  factory LongFormEvidenceRef.fromJson(Map<String, Object?> json) =>
      LongFormEvidenceRef(
        artifactHash: _string(json, 'artifactHash'),
        chapterRange: _string(json, 'chapterRange'),
        committedLedgerHash: _string(json, 'committedLedgerHash'),
      );
}

final class EvaluatorVerdict {
  EvaluatorVerdict({
    required this.evaluatorIdHash,
    required this.evaluatorRelease,
    required this.craftOverall,
    List<String> findingIds = const [],
    required this.calibratedConfidence,
  }) : findingIds = _immutableSortedStrings(findingIds) {
    _requireNonEmpty(evaluatorIdHash, 'evaluatorIdHash');
    _requireNonEmpty(evaluatorRelease, 'evaluatorRelease');
    _requireScore(craftOverall, 'craftOverall');
    _requireUnitInterval(calibratedConfidence, 'calibratedConfidence');
  }

  final String evaluatorIdHash;
  final String evaluatorRelease;
  final double craftOverall;
  final List<String> findingIds;
  final double calibratedConfidence;

  Map<String, Object?> toJson() => {
    'evaluatorIdHash': evaluatorIdHash,
    'evaluatorRelease': evaluatorRelease,
    'craftOverall': craftOverall,
    'findingIds': findingIds,
    'calibratedConfidence': calibratedConfidence,
  };

  factory EvaluatorVerdict.fromJson(Map<String, Object?> json) =>
      EvaluatorVerdict(
        evaluatorIdHash: _string(json, 'evaluatorIdHash'),
        evaluatorRelease: _string(json, 'evaluatorRelease'),
        craftOverall: _double(json, 'craftOverall'),
        findingIds: _stringList(json, 'findingIds'),
        calibratedConfidence: _double(json, 'calibratedConfidence'),
      );
}

final class MetricWithInterval {
  MetricWithInterval({
    required this.point,
    required this.ci95Low,
    required this.ci95High,
    required this.sampleSize,
  }) {
    _requireUnitInterval(point, 'point');
    _requireUnitInterval(ci95Low, 'ci95Low');
    _requireUnitInterval(ci95High, 'ci95High');
    if (ci95Low > ci95High) throw ArgumentError('invalid confidence interval');
    if (point < ci95Low || point > ci95High) {
      throw ArgumentError('point must be inside confidence interval');
    }
    if (sampleSize < 0) throw ArgumentError('sampleSize must be non-negative');
  }

  final double point;
  final double ci95Low;
  final double ci95High;
  final int sampleSize;

  Map<String, Object?> toJson() => {
    'point': point,
    'ci95Low': ci95Low,
    'ci95High': ci95High,
    'sampleSize': sampleSize,
  };

  factory MetricWithInterval.fromJson(Map<String, Object?> json) =>
      MetricWithInterval(
        point: _double(json, 'point'),
        ci95Low: _double(json, 'ci95Low'),
        ci95High: _double(json, 'ci95High'),
        sampleSize: _int(json, 'sampleSize'),
      );
}

final class ReaderEstimate<T extends num> {
  ReaderEstimate({
    required this.value,
    required this.source,
    required this.method,
    required this.sampleSize,
    required this.calibratedConfidence,
    List<String> evidenceRefs = const [],
  }) : evidenceRefs = _immutableSortedStrings(evidenceRefs) {
    _requireFinite(value.toDouble(), 'value');
    _requireNonEmpty(method, 'method');
    if (sampleSize < 0) throw ArgumentError('sampleSize must be non-negative');
    _requireUnitInterval(calibratedConfidence, 'calibratedConfidence');
  }

  final T value;
  final ReaderEstimateSource source;
  final String method;
  final int sampleSize;
  final double calibratedConfidence;
  final List<String> evidenceRefs;

  Map<String, Object?> toJson() => {
    'value': value,
    'source': source.wire,
    'method': method,
    'sampleSize': sampleSize,
    'calibratedConfidence': calibratedConfidence,
    'evidenceRefs': evidenceRefs,
  };

  static ReaderEstimate<double> doubleFromJson(Map<String, Object?> json) =>
      ReaderEstimate<double>(
        value: _double(json, 'value'),
        source: _enumValue(
          json,
          'source',
          ReaderEstimateSource.values,
          (value) => value.wire,
        ),
        method: _string(json, 'method'),
        sampleSize: _int(json, 'sampleSize'),
        calibratedConfidence: _double(json, 'calibratedConfidence'),
        evidenceRefs: _stringList(json, 'evidenceRefs'),
      );
}

final class AuthorStyleOverride {
  AuthorStyleOverride({
    required this.overrideId,
    required this.projectId,
    this.sceneId,
    required this.findingCode,
    required this.voiceProfileHash,
    required this.reason,
    required this.scope,
    required this.createdAtMs,
    this.expiresAtMs,
  }) {
    if (createdAtMs < 0 ||
        (expiresAtMs != null && expiresAtMs! <= createdAtMs)) {
      throw ArgumentError('invalid override timestamps');
    }
    for (final entry in {
      'overrideId': overrideId,
      'projectId': projectId,
      'findingCode': findingCode,
      'voiceProfileHash': voiceProfileHash,
      'reason': reason,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
  }

  final String overrideId;
  final String projectId;
  final String? sceneId;
  final String findingCode;
  final String voiceProfileHash;
  final String reason;
  final OverrideScope scope;
  final int createdAtMs;
  final int? expiresAtMs;

  Map<String, Object?> toJson() => _withoutNulls({
    'overrideId': overrideId,
    'projectId': projectId,
    'sceneId': sceneId,
    'findingCode': findingCode,
    'voiceProfileHash': voiceProfileHash,
    'reason': reason,
    'scope': scope.wire,
    'createdAtMs': createdAtMs,
    'expiresAtMs': expiresAtMs,
  });

  factory AuthorStyleOverride.fromJson(Map<String, Object?> json) =>
      AuthorStyleOverride(
        overrideId: _string(json, 'overrideId'),
        projectId: _string(json, 'projectId'),
        sceneId: _optionalString(json, 'sceneId'),
        findingCode: _string(json, 'findingCode'),
        voiceProfileHash: _string(json, 'voiceProfileHash'),
        reason: _string(json, 'reason'),
        scope: _enumValue(
          json,
          'scope',
          OverrideScope.values,
          (value) => value.wire,
        ),
        createdAtMs: _int(json, 'createdAtMs'),
        expiresAtMs: _optionalInt(json, 'expiresAtMs'),
      );
}

final class RepairDirective {
  RepairDirective({
    required this.directiveId,
    List<String> findingIds = const [],
    List<TextEvidenceSpan> targetSpans = const [],
    Set<RepairOperation> allowedOperations = const {},
    List<String> invariantsToPreserve = const [],
    List<String> forbiddenChanges = const [],
    List<String> requiredRevalidationStages = const [],
    required this.expectedImprovement,
    required this.maxAttempts,
    required this.fullRewriteAllowed,
    required this.planHash,
  }) : findingIds = _immutableSortedStrings(findingIds),
       targetSpans = _immutableList(targetSpans),
       allowedOperations = Set.unmodifiable(
         (allowedOperations.toList()
               ..sort((left, right) => left.wire.compareTo(right.wire)))
             .toSet(),
       ),
       invariantsToPreserve = _immutableSortedStrings(invariantsToPreserve),
       forbiddenChanges = _immutableSortedStrings(forbiddenChanges),
       requiredRevalidationStages = _immutableSortedStrings(
         requiredRevalidationStages,
       ) {
    _requireNonEmpty(directiveId, 'directiveId');
    _requireNonEmpty(expectedImprovement, 'expectedImprovement');
    _requireNonEmpty(planHash, 'planHash');
    if (this.findingIds.isEmpty || this.allowedOperations.isEmpty) {
      throw ArgumentError('repair directive requires findings and operations');
    }
    if (maxAttempts < 0) {
      throw ArgumentError('maxAttempts must be non-negative');
    }
  }

  final String directiveId;
  final List<String> findingIds;
  final List<TextEvidenceSpan> targetSpans;
  final Set<RepairOperation> allowedOperations;
  final List<String> invariantsToPreserve;
  final List<String> forbiddenChanges;
  final List<String> requiredRevalidationStages;
  final String expectedImprovement;
  final int maxAttempts;
  final bool fullRewriteAllowed;
  final String planHash;

  Map<String, Object?> toJson() => {
    'directiveId': directiveId,
    'findingIds': findingIds,
    'targetSpans': [for (final span in targetSpans) span.toJson()],
    'allowedOperations': [
      for (final operation in allowedOperations) operation.wire,
    ],
    'invariantsToPreserve': invariantsToPreserve,
    'forbiddenChanges': forbiddenChanges,
    'requiredRevalidationStages': requiredRevalidationStages,
    'expectedImprovement': expectedImprovement,
    'maxAttempts': maxAttempts,
    'fullRewriteAllowed': fullRewriteAllowed,
    'planHash': planHash,
  };

  factory RepairDirective.fromJson(Map<String, Object?> json) =>
      RepairDirective(
        directiveId: _string(json, 'directiveId'),
        findingIds: _stringList(json, 'findingIds'),
        targetSpans: _listOfMaps(
          json,
          'targetSpans',
        ).map(TextEvidenceSpan.fromJson).toList(growable: false),
        allowedOperations: _enumList(
          json,
          'allowedOperations',
          RepairOperation.values,
          (value) => value.wire,
        ).toSet(),
        invariantsToPreserve: _stringList(json, 'invariantsToPreserve'),
        forbiddenChanges: _stringList(json, 'forbiddenChanges'),
        requiredRevalidationStages: _stringList(
          json,
          'requiredRevalidationStages',
        ),
        expectedImprovement: _string(json, 'expectedImprovement'),
        maxAttempts: _int(json, 'maxAttempts'),
        fullRewriteAllowed: _bool(json, 'fullRewriteAllowed'),
        planHash: _string(json, 'planHash'),
      );
}

final class SceneCandidateDecision {
  SceneCandidateDecision({
    required this.status,
    required this.reasonCode,
    required this.craftOverall,
    required this.criticalCraftMinimum,
    required this.styleFit,
    List<String> findingIds = const [],
    required this.evaluatorCertificationId,
  }) : findingIds = _immutableSortedStrings(findingIds) {
    _requireNonEmpty(reasonCode, 'reasonCode');
    _requireScore(craftOverall, 'craftOverall');
    _requireScore(criticalCraftMinimum, 'criticalCraftMinimum');
    _requireNonEmpty(evaluatorCertificationId, 'evaluatorCertificationId');
  }

  final SceneCandidateStatus status;
  final String reasonCode;
  final double craftOverall;
  final double criticalCraftMinimum;
  final StyleFitDecision styleFit;
  final List<String> findingIds;
  final String evaluatorCertificationId;

  Map<String, Object?> toJson() => {
    'status': status.wire,
    'reasonCode': reasonCode,
    'craftOverall': craftOverall,
    'criticalCraftMinimum': criticalCraftMinimum,
    'styleFit': styleFit.wire,
    'findingIds': findingIds,
    'evaluatorCertificationId': evaluatorCertificationId,
  };

  factory SceneCandidateDecision.fromJson(Map<String, Object?> json) =>
      SceneCandidateDecision(
        status: _enumValue(
          json,
          'status',
          SceneCandidateStatus.values,
          (value) => value.wire,
        ),
        reasonCode: _string(json, 'reasonCode'),
        craftOverall: _double(json, 'craftOverall'),
        criticalCraftMinimum: _double(json, 'criticalCraftMinimum'),
        styleFit: _enumValue(
          json,
          'styleFit',
          StyleFitDecision.values,
          (value) => value.wire,
        ),
        findingIds: _stringList(json, 'findingIds'),
        evaluatorCertificationId: _string(json, 'evaluatorCertificationId'),
      );
}

final class LayeredQualityResult {
  LayeredQualityResult({
    required this.schemaVersion,
    required this.evidenceId,
    required this.evidenceHash,
    required this.proseHash,
    required this.projectCharterHash,
    required this.arcContractHash,
    required this.sceneContractHash,
    required this.voiceProfileHash,
    required this.ledgerSnapshotHash,
    required this.rubricVersion,
    required this.promptReleaseHash,
    required this.thresholdPolicyVersion,
    required this.deterministicGate,
    required this.semanticHardReview,
    required this.craft,
    required this.styleFit,
    required this.readerEffect,
    this.longForm,
    List<QualityFinding> findings = const [],
    List<EvaluatorVerdict> evaluatorVerdicts = const [],
    required this.calibratedConfidence,
    this.evaluatorSelfConfidence,
    required this.decision,
    this.repair,
    required this.createdAtMs,
  }) : findings = _immutableList(findings),
       evaluatorVerdicts = _immutableList(evaluatorVerdicts) {
    _validateVersionRevision(schemaVersion, 0);
    if (createdAtMs < 0) {
      throw ArgumentError('createdAtMs must be non-negative');
    }
    _requireUnitInterval(calibratedConfidence, 'calibratedConfidence');
    if (evaluatorSelfConfidence != null) {
      _requireUnitInterval(evaluatorSelfConfidence!, 'evaluatorSelfConfidence');
    }
    for (final entry in {
      'evidenceId': evidenceId,
      'proseHash': proseHash,
      'projectCharterHash': projectCharterHash,
      'arcContractHash': arcContractHash,
      'sceneContractHash': sceneContractHash,
      'voiceProfileHash': voiceProfileHash,
      'ledgerSnapshotHash': ledgerSnapshotHash,
      'rubricVersion': rubricVersion,
      'promptReleaseHash': promptReleaseHash,
      'thresholdPolicyVersion': thresholdPolicyVersion,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    _validateEffectiveDeviationBindings(findings, styleFit);
    _requireHashMatches('evidenceHash', evidenceHash, canonicalHash);
  }

  final int schemaVersion;
  final String evidenceId;
  final String evidenceHash;
  final String proseHash;
  final String projectCharterHash;
  final String arcContractHash;
  final String sceneContractHash;
  final String voiceProfileHash;
  final String ledgerSnapshotHash;
  final String rubricVersion;
  final String promptReleaseHash;
  final String thresholdPolicyVersion;
  final DeterministicGateRef deterministicGate;
  final SemanticHardReviewResult semanticHardReview;
  final CraftScore craft;
  final StyleFitResult styleFit;
  final ReaderEffectProbeResult readerEffect;
  final LongFormEvidenceRef? longForm;
  final List<QualityFinding> findings;
  final List<EvaluatorVerdict> evaluatorVerdicts;
  final double calibratedConfidence;
  final double? evaluatorSelfConfidence;
  final SceneCandidateDecision decision;
  final RepairDirective? repair;
  final int createdAtMs;

  Map<String, Object?> get identityJson => _withoutNulls({
    'schemaVersion': schemaVersion,
    'evidenceId': evidenceId,
    'proseHash': proseHash,
    'projectCharterHash': projectCharterHash,
    'arcContractHash': arcContractHash,
    'sceneContractHash': sceneContractHash,
    'voiceProfileHash': voiceProfileHash,
    'ledgerSnapshotHash': ledgerSnapshotHash,
    'rubricVersion': rubricVersion,
    'promptReleaseHash': promptReleaseHash,
    'thresholdPolicyVersion': thresholdPolicyVersion,
    'deterministicGate': deterministicGate.toJson(),
    'semanticHardReview': semanticHardReview.toJson(),
    'craft': craft.toJson(),
    'styleFit': styleFit.toJson(),
    'readerEffect': readerEffect.toJson(),
    'longForm': longForm?.toJson(),
    'findings': [for (final finding in findings) finding.toJson()],
    'evaluatorVerdicts': [
      for (final verdict in evaluatorVerdicts) verdict.toJson(),
    ],
    'calibratedConfidence': calibratedConfidence,
    'evaluatorSelfConfidence': evaluatorSelfConfidence,
    'decision': decision.toJson(),
    'repair': repair?.toJson(),
  });

  String get canonicalHash =>
      AppLlmCanonicalHash.domainHash('layered-quality-result-v1', identityJson);

  Map<String, Object?> toJson() => {
    ...identityJson,
    'evidenceHash': evidenceHash,
    'createdAtMs': createdAtMs,
  };

  factory LayeredQualityResult.create({
    required int schemaVersion,
    required String evidenceId,
    required String proseHash,
    required String projectCharterHash,
    required String arcContractHash,
    required String sceneContractHash,
    required String voiceProfileHash,
    required String ledgerSnapshotHash,
    required String rubricVersion,
    required String promptReleaseHash,
    required String thresholdPolicyVersion,
    required DeterministicGateRef deterministicGate,
    required SemanticHardReviewResult semanticHardReview,
    required CraftScore craft,
    required StyleFitResult styleFit,
    required ReaderEffectProbeResult readerEffect,
    LongFormEvidenceRef? longForm,
    List<QualityFinding> findings = const [],
    List<EvaluatorVerdict> evaluatorVerdicts = const [],
    required double calibratedConfidence,
    double? evaluatorSelfConfidence,
    required SceneCandidateDecision decision,
    RepairDirective? repair,
    required int createdAtMs,
  }) {
    final normalizedFindings = _immutableList(findings);
    final normalizedEvaluatorVerdicts = _immutableList(evaluatorVerdicts);
    final identityJson = _withoutNulls({
      'schemaVersion': schemaVersion,
      'evidenceId': evidenceId,
      'proseHash': proseHash,
      'projectCharterHash': projectCharterHash,
      'arcContractHash': arcContractHash,
      'sceneContractHash': sceneContractHash,
      'voiceProfileHash': voiceProfileHash,
      'ledgerSnapshotHash': ledgerSnapshotHash,
      'rubricVersion': rubricVersion,
      'promptReleaseHash': promptReleaseHash,
      'thresholdPolicyVersion': thresholdPolicyVersion,
      'deterministicGate': deterministicGate.toJson(),
      'semanticHardReview': semanticHardReview.toJson(),
      'craft': craft.toJson(),
      'styleFit': styleFit.toJson(),
      'readerEffect': readerEffect.toJson(),
      'longForm': longForm?.toJson(),
      'findings': [for (final finding in normalizedFindings) finding.toJson()],
      'evaluatorVerdicts': [
        for (final verdict in normalizedEvaluatorVerdicts) verdict.toJson(),
      ],
      'calibratedConfidence': calibratedConfidence,
      'evaluatorSelfConfidence': evaluatorSelfConfidence,
      'decision': decision.toJson(),
      'repair': repair?.toJson(),
    });
    return LayeredQualityResult(
      schemaVersion: schemaVersion,
      evidenceId: evidenceId,
      evidenceHash: AppLlmCanonicalHash.domainHash(
        'layered-quality-result-v1',
        identityJson,
      ),
      proseHash: proseHash,
      projectCharterHash: projectCharterHash,
      arcContractHash: arcContractHash,
      sceneContractHash: sceneContractHash,
      voiceProfileHash: voiceProfileHash,
      ledgerSnapshotHash: ledgerSnapshotHash,
      rubricVersion: rubricVersion,
      promptReleaseHash: promptReleaseHash,
      thresholdPolicyVersion: thresholdPolicyVersion,
      deterministicGate: deterministicGate,
      semanticHardReview: semanticHardReview,
      craft: craft,
      styleFit: styleFit,
      readerEffect: readerEffect,
      longForm: longForm,
      findings: normalizedFindings,
      evaluatorVerdicts: normalizedEvaluatorVerdicts,
      calibratedConfidence: calibratedConfidence,
      evaluatorSelfConfidence: evaluatorSelfConfidence,
      decision: decision,
      repair: repair,
      createdAtMs: createdAtMs,
    );
  }

  factory LayeredQualityResult.fromJson(
    Map<String, Object?> json,
  ) => LayeredQualityResult(
    schemaVersion: _int(json, 'schemaVersion'),
    evidenceId: _string(json, 'evidenceId'),
    evidenceHash: _string(json, 'evidenceHash'),
    proseHash: _string(json, 'proseHash'),
    projectCharterHash: _string(json, 'projectCharterHash'),
    arcContractHash: _string(json, 'arcContractHash'),
    sceneContractHash: _string(json, 'sceneContractHash'),
    voiceProfileHash: _string(json, 'voiceProfileHash'),
    ledgerSnapshotHash: _string(json, 'ledgerSnapshotHash'),
    rubricVersion: _string(json, 'rubricVersion'),
    promptReleaseHash: _string(json, 'promptReleaseHash'),
    thresholdPolicyVersion: _string(json, 'thresholdPolicyVersion'),
    deterministicGate: DeterministicGateRef.fromJson(
      _map(json, 'deterministicGate'),
    ),
    semanticHardReview: SemanticHardReviewResult.fromJson(
      _map(json, 'semanticHardReview'),
    ),
    craft: CraftScore.fromJson(_map(json, 'craft')),
    styleFit: StyleFitResult.fromJson(_map(json, 'styleFit')),
    readerEffect: ReaderEffectProbeResult.fromJson(_map(json, 'readerEffect')),
    longForm: json['longForm'] == null
        ? null
        : LongFormEvidenceRef.fromJson(_map(json, 'longForm')),
    findings: _listOfMaps(
      json,
      'findings',
    ).map(QualityFinding.fromJson).toList(growable: false),
    evaluatorVerdicts: _listOfMaps(
      json,
      'evaluatorVerdicts',
    ).map(EvaluatorVerdict.fromJson).toList(growable: false),
    calibratedConfidence: _double(json, 'calibratedConfidence'),
    evaluatorSelfConfidence: _optionalDouble(json, 'evaluatorSelfConfidence'),
    decision: SceneCandidateDecision.fromJson(_map(json, 'decision')),
    repair: json['repair'] == null
        ? null
        : RepairDirective.fromJson(_map(json, 'repair')),
    createdAtMs: _int(json, 'createdAtMs'),
  );
}

final class EvaluatorPolicyCertification {
  EvaluatorPolicyCertification({
    required this.certificationId,
    required this.rubricVersion,
    required this.promptReleaseHash,
    required this.evaluatorModelRelease,
    required this.thresholdPolicyVersion,
    required this.status,
    required this.calibrationArtifactHash,
    required this.blindReviewArtifactHash,
    Map<String, MetricWithInterval> metrics = const {},
    required this.certifiedAtMs,
  }) : metrics = _immutableTypedMap(metrics) {
    if (certifiedAtMs < 0) {
      throw ArgumentError('certifiedAtMs must be non-negative');
    }
    for (final entry in {
      'certificationId': certificationId,
      'rubricVersion': rubricVersion,
      'promptReleaseHash': promptReleaseHash,
      'evaluatorModelRelease': evaluatorModelRelease,
      'thresholdPolicyVersion': thresholdPolicyVersion,
      'calibrationArtifactHash': calibrationArtifactHash,
      'blindReviewArtifactHash': blindReviewArtifactHash,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
  }

  final String certificationId;
  final String rubricVersion;
  final String promptReleaseHash;
  final String evaluatorModelRelease;
  final String thresholdPolicyVersion;
  final EvaluatorPolicyCertificationStatus status;
  final String calibrationArtifactHash;
  final String blindReviewArtifactHash;
  final Map<String, MetricWithInterval> metrics;
  final int certifiedAtMs;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'certificationId': certificationId,
    'rubricVersion': rubricVersion,
    'promptReleaseHash': promptReleaseHash,
    'evaluatorModelRelease': evaluatorModelRelease,
    'thresholdPolicyVersion': thresholdPolicyVersion,
    'status': status.wire,
    'calibrationArtifactHash': calibrationArtifactHash,
    'blindReviewArtifactHash': blindReviewArtifactHash,
    'metrics': {
      for (final entry in metrics.entries) entry.key: entry.value.toJson(),
    },
  };

  String get certificationHash => AppLlmCanonicalHash.domainHash(
    'evaluator-policy-certification-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => {
    ...identityJson,
    'certifiedAtMs': certifiedAtMs,
  };

  factory EvaluatorPolicyCertification.fromJson(Map<String, Object?> json) =>
      EvaluatorPolicyCertification(
        certificationId: _string(json, 'certificationId'),
        rubricVersion: _string(json, 'rubricVersion'),
        promptReleaseHash: _string(json, 'promptReleaseHash'),
        evaluatorModelRelease: _string(json, 'evaluatorModelRelease'),
        thresholdPolicyVersion: _string(json, 'thresholdPolicyVersion'),
        status: _enumValue(
          json,
          'status',
          EvaluatorPolicyCertificationStatus.values,
          (value) => value.wire,
        ),
        calibrationArtifactHash: _string(json, 'calibrationArtifactHash'),
        blindReviewArtifactHash: _string(json, 'blindReviewArtifactHash'),
        metrics: {
          for (final entry in _map(json, 'metrics').entries)
            entry.key: MetricWithInterval.fromJson(_asMap(entry.value)),
        },
        certifiedAtMs: _int(json, 'certifiedAtMs'),
      );
}

final class ChapterQualityDecision {
  ChapterQualityDecision({
    required this.chapterId,
    required this.status,
    List<String> sceneEvidenceHashes = const [],
    required this.narrativeChainHash,
    List<String> unresolvedMajorFindingIds = const [],
    required this.chapterAuditHash,
  }) : sceneEvidenceHashes = _immutableSortedStrings(sceneEvidenceHashes),
       unresolvedMajorFindingIds = _immutableSortedStrings(
         unresolvedMajorFindingIds,
       ) {
    _requireNonEmpty(chapterId, 'chapterId');
    _requireNonEmpty(narrativeChainHash, 'narrativeChainHash');
    _requireNonEmpty(chapterAuditHash, 'chapterAuditHash');
    if (status == ChapterQualityStatus.releaseEligible) {
      if (this.sceneEvidenceHashes.isEmpty) {
        throw ArgumentError(
          'release-eligible chapters require scene evidence hashes',
        );
      }
      if (this.unresolvedMajorFindingIds.isNotEmpty) {
        throw ArgumentError(
          'release-eligible chapters cannot have unresolved major findings',
        );
      }
    }
  }

  final String chapterId;
  final ChapterQualityStatus status;
  final List<String> sceneEvidenceHashes;
  final String narrativeChainHash;
  final List<String> unresolvedMajorFindingIds;
  final String chapterAuditHash;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'chapterId': chapterId,
    'status': status.wire,
    'sceneEvidenceHashes': sceneEvidenceHashes,
    'narrativeChainHash': narrativeChainHash,
    'unresolvedMajorFindingIds': unresolvedMajorFindingIds,
    'chapterAuditHash': chapterAuditHash,
  };

  String get decisionHash => AppLlmCanonicalHash.domainHash(
    'chapter-quality-decision-v1',
    identityJson,
  );

  Map<String, Object?> toJson() => identityJson;

  factory ChapterQualityDecision.fromJson(Map<String, Object?> json) =>
      ChapterQualityDecision(
        chapterId: _string(json, 'chapterId'),
        status: _enumValue(
          json,
          'status',
          ChapterQualityStatus.values,
          (value) => value.wire,
        ),
        sceneEvidenceHashes: _stringList(json, 'sceneEvidenceHashes'),
        narrativeChainHash: _string(json, 'narrativeChainHash'),
        unresolvedMajorFindingIds: _stringList(
          json,
          'unresolvedMajorFindingIds',
        ),
        chapterAuditHash: _string(json, 'chapterAuditHash'),
      );
}

final class BookQualityDecision {
  BookQualityDecision({
    required this.projectId,
    required this.status,
    List<String> chapterDecisionHashes = const [],
    required this.evaluatorCertificationId,
    required this.blindReviewArtifactHash,
    required this.longFormAuditArtifactHash,
  }) : chapterDecisionHashes = _immutableSortedStrings(chapterDecisionHashes) {
    for (final entry in {
      'projectId': projectId,
      'evaluatorCertificationId': evaluatorCertificationId,
      'blindReviewArtifactHash': blindReviewArtifactHash,
      'longFormAuditArtifactHash': longFormAuditArtifactHash,
    }.entries) {
      _requireNonEmpty(entry.value, entry.key);
    }
    if (status == BookQualityStatus.releaseEvidencePassed &&
        this.chapterDecisionHashes.isEmpty) {
      throw ArgumentError(
        'release-evidence-passed books require chapter decisions',
      );
    }
  }

  final String projectId;
  final BookQualityStatus status;
  final List<String> chapterDecisionHashes;
  final String evaluatorCertificationId;
  final String blindReviewArtifactHash;
  final String longFormAuditArtifactHash;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'projectId': projectId,
    'status': status.wire,
    'chapterDecisionHashes': chapterDecisionHashes,
    'evaluatorCertificationId': evaluatorCertificationId,
    'blindReviewArtifactHash': blindReviewArtifactHash,
    'longFormAuditArtifactHash': longFormAuditArtifactHash,
  };

  String get decisionHash =>
      AppLlmCanonicalHash.domainHash('book-quality-decision-v1', identityJson);

  Map<String, Object?> toJson() => identityJson;

  factory BookQualityDecision.fromJson(Map<String, Object?> json) =>
      BookQualityDecision(
        projectId: _string(json, 'projectId'),
        status: _enumValue(
          json,
          'status',
          BookQualityStatus.values,
          (value) => value.wire,
        ),
        chapterDecisionHashes: _stringList(json, 'chapterDecisionHashes'),
        evaluatorCertificationId: _string(json, 'evaluatorCertificationId'),
        blindReviewArtifactHash: _string(json, 'blindReviewArtifactHash'),
        longFormAuditArtifactHash: _string(json, 'longFormAuditArtifactHash'),
      );
}

Map<String, Object?> _withoutNulls(Map<String, Object?> value) => {
  for (final entry in value.entries)
    if (entry.value != null) entry.key: entry.value,
};

Map<String, Object?> _asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  throw const FormatException('expected JSON object');
}

Map<String, Object?> _map(Map<String, Object?> json, String key) {
  if (!json.containsKey(key)) throw FormatException('missing field: $key');
  return _asMap(json[key]);
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('field $key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw FormatException('field $key must be a non-empty string when present');
  }
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('field $key must be an int');
  return value;
}

int? _optionalInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw FormatException('field $key must be an int');
  return value;
}

double _double(Map<String, Object?> json, String key) {
  final value = json[key];
  final result = value is int ? value.toDouble() : value;
  if (result is! double || !result.isFinite) {
    throw FormatException('field $key must be a finite number');
  }
  return result;
}

double? _optionalDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final result = value is int ? value.toDouble() : value;
  if (result is! double || !result.isFinite) {
    throw FormatException('field $key must be a finite number');
  }
  return result;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('field $key must be a bool');
  return value;
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('field $key must be a list');
  return [
    for (final item in value)
      if (item is String && item.isNotEmpty)
        item
      else
        throw FormatException('field $key must contain only non-empty strings'),
  ];
}

Map<String, String> _stringMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const {};
  if (value is! Map) throw FormatException('field $key must be an object');
  final result = <String, String>{};
  for (final entry in value.entries) {
    final entryValue = entry.value;
    if (entryValue is! String) {
      throw FormatException('field $key must contain only strings');
    }
    result[entry.key.toString()] = entryValue;
  }
  return result;
}

Map<String, double> _doubleMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('field $key must be an object');
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value is int
          ? (entry.value as int).toDouble()
          : entry.value is double && (entry.value as double).isFinite
          ? entry.value as double
          : throw FormatException('field $key must contain finite numbers'),
  };
}

List<Map<String, Object?>> _listOfMaps(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('field $key must be a list');
  return [for (final item in value) _asMap(item)];
}

T _enumValue<T>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  String Function(T value) wire,
) {
  final raw = _string(json, key);
  for (final value in values) {
    if (wire(value) == raw) return value;
  }
  throw FormatException('unknown enum value for $key: $raw');
}

List<T> _enumList<T>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  String Function(T value) wire,
) {
  final raw = _stringList(json, key);
  return [
    for (final item in raw)
      values.firstWhere(
        (value) => wire(value) == item,
        orElse: () =>
            throw FormatException('unknown enum value for $key: $item'),
      ),
  ];
}

List<T> _immutableList<T>(Iterable<T> values) => List<T>.unmodifiable(values);

List<DeviationAuthorizationRef> _immutableDeviationAuthorizationRefs(
  Iterable<DeviationAuthorizationRef> values,
) {
  final unique = <String, DeviationAuthorizationRef>{};
  for (final value in values) {
    final key = '${value.authorizedBy.wire}\u0000${value.referenceId}';
    unique[key] = value;
  }
  final sortedKeys = unique.keys.toList()..sort(_compareUnicodeScalars);
  return List<DeviationAuthorizationRef>.unmodifiable([
    for (final key in sortedKeys) unique[key]!,
  ]);
}

List<String> _immutableSortedStrings(Iterable<String> values) {
  final unique = <String>{};
  for (final value in values) {
    _requireNonEmpty(value, 'string list item');
    unique.add(AppLlmCanonicalHash.normalizeNfc(value));
  }
  final sorted = unique.toList()..sort(_compareUnicodeScalars);
  return List<String>.unmodifiable(sorted);
}

int _compareUnicodeScalars(String left, String right) {
  final leftScalars = left.runes.iterator;
  final rightScalars = right.runes.iterator;
  while (true) {
    final hasLeft = leftScalars.moveNext();
    final hasRight = rightScalars.moveNext();
    if (!hasLeft || !hasRight) {
      if (hasLeft == hasRight) return 0;
      return hasLeft ? 1 : -1;
    }
    final scalarComparison = leftScalars.current.compareTo(
      rightScalars.current,
    );
    if (scalarComparison != 0) return scalarComparison;
  }
}

Map<String, T> _immutableTypedMap<T>(Map<String, T> values) =>
    Map<String, T>.unmodifiable(Map<String, T>.from(values));

Map<String, String> _immutableStringMap(Map<String, String> values) =>
    Map<String, String>.unmodifiable(Map<String, String>.from(values));

Map<String, NumericRange> _numericRangeMap(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) return const {};
  if (value is! Map) throw FormatException('field $key must be an object');
  return {
    for (final entry in value.entries)
      entry.key.toString(): NumericRange.fromJson(_asMap(entry.value)),
  };
}

void _requireNonEmpty(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$fieldName must not be empty');
  }
}

void _requireFinite(double value, String fieldName) {
  if (!value.isFinite) throw ArgumentError('$fieldName must be finite');
}

void _requireUnitInterval(double value, String fieldName) {
  _requireFinite(value, fieldName);
  if (value < 0 || value > 1) {
    throw ArgumentError('$fieldName must be between 0 and 1');
  }
}

void _requireScore(double value, String fieldName) {
  _requireFinite(value, fieldName);
  if (value < 0 || value > 100) {
    throw ArgumentError('$fieldName must be between 0 and 100');
  }
}

void _requireRange(int value, int minimum, int maximum, String fieldName) {
  if (value < minimum || value > maximum) {
    throw ArgumentError('$fieldName must be between $minimum and $maximum');
  }
}

void _validateVersionRevision(int schemaVersion, int revision) {
  if (schemaVersion <= 0) throw ArgumentError('schemaVersion must be positive');
  if (revision < 0) throw ArgumentError('revision must be non-negative');
}

void _requireHashMatches(String fieldName, String stored, String computed) {
  _requireNonEmpty(stored, fieldName);
  if (stored != computed) {
    throw ArgumentError('$fieldName does not match canonical identity hash');
  }
}

void _requireClose(double actual, double expected, String fieldName) {
  if ((actual - expected).abs() > 0.000000001) {
    throw FormatException('$fieldName does not match canonical calculation');
  }
}

Map<String, double> _validatedCraftDimensions(Map<String, double> dimensions) {
  final expectedKeys = CraftScore.weights.keys.toSet();
  if (dimensions.keys.toSet().length != expectedKeys.length ||
      !dimensions.keys.toSet().containsAll(expectedKeys)) {
    throw ArgumentError(
      'craft dimensions must contain exactly ${CraftScore.weights.keys.join(', ')}',
    );
  }
  for (final entry in dimensions.entries) {
    _requireScore(entry.value, 'craft dimension ${entry.key}');
  }
  return Map<String, double>.unmodifiable({
    for (final key in CraftScore.weights.keys) key: dimensions[key]!,
  });
}

double _weightedCraftOverall(Map<String, double> dimensions) {
  _validatedCraftDimensions(dimensions);
  var total = 0.0;
  for (final entry in CraftScore.weights.entries) {
    total += dimensions[entry.key]! * entry.value;
  }
  return total;
}

double _criticalCraftMinimum(Map<String, double> dimensions) {
  _validatedCraftDimensions(dimensions);
  return dimensions.values.reduce((left, right) => left < right ? left : right);
}

void _validateEffectiveDeviationBindings(
  List<QualityFinding> findings,
  StyleFitResult styleFit,
) {
  final effectiveDeviations = findings.where(
    (finding) => finding.findingClass == QualityFindingClass.effectiveDeviation,
  );
  for (final finding in effectiveDeviations) {
    if (styleFit.decision != StyleFitDecision.plannedDeviation &&
        styleFit.decision != StyleFitDecision.approvedDeviation) {
      throw ArgumentError(
        'effective deviation findings require a deviation style-fit decision',
      );
    }
    final hasMatchingAuthorization = finding.deviationAuthorizationRefs.any(
      (findingReference) => styleFit.deviationAuthorizationRefs.any(
        (styleReference) =>
            styleReference.authorizedBy == findingReference.authorizedBy &&
            styleReference.referenceId == findingReference.referenceId,
      ),
    );
    if (!hasMatchingAuthorization) {
      throw ArgumentError(
        'effective deviation finding authorization is not bound to style fit',
      );
    }
  }
}
