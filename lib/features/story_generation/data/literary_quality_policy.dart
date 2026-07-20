import '../domain/literary_quality_models.dart';

enum LiteraryQualityPolicyAction {
  independentRescoreRequired,
  blocked,
  repairRequired,
  draftKeep,
  candidate,
  manualReview,
}

enum AutoRepairMode { off, targetedOnly, fullAllowed }

enum ReaderEffectMode { off, proxy, milestone }

final class LiteraryQualitySettings {
  const LiteraryQualitySettings({
    required this.strictness,
    required this.autoRepair,
    required this.readerEffect,
    required this.referenceUsage,
    required this.styleIntensity,
    required this.qualityGateMode,
  });

  factory LiteraryQualitySettings.fromJson(Map<String, Object?> json) {
    final rawStyleIntensity = json['styleIntensity'];
    return LiteraryQualitySettings(
      strictness: _enumFromJson(
        json,
        'strictness',
        QualityStrictness.values,
        (value) => value.wire,
        QualityStrictness.standard,
      ),
      autoRepair: _enumFromJson(
        json,
        'autoRepair',
        AutoRepairMode.values,
        (value) => value.name,
        AutoRepairMode.targetedOnly,
      ),
      readerEffect: _enumFromJson(
        json,
        'readerEffect',
        ReaderEffectMode.values,
        (value) => value.name,
        ReaderEffectMode.proxy,
      ),
      referenceUsage: _enumFromJson(
        json,
        'referenceUsage',
        ReferenceUsage.values,
        (value) => value.name,
        ReferenceUsage.abstractFeaturesOnly,
      ),
      styleIntensity: switch (rawStyleIntensity) {
        null => 50,
        final int value when value >= 0 && value <= 100 => value,
        _ => throw const FormatException('styleIntensity must be 0..100'),
      },
      qualityGateMode: _enumFromJson(
        json,
        'qualityGateMode',
        LiteraryQualityGateMode.values,
        (value) => value.wire,
        LiteraryQualityGateMode.legacy95,
      ),
    );
  }

  static const defaults = LiteraryQualitySettings(
    strictness: QualityStrictness.standard,
    autoRepair: AutoRepairMode.targetedOnly,
    readerEffect: ReaderEffectMode.proxy,
    referenceUsage: ReferenceUsage.abstractFeaturesOnly,
    styleIntensity: 50,
    qualityGateMode: LiteraryQualityGateMode.legacy95,
  );

  Map<String, Object?> toJson() => {
    'strictness': strictness.wire,
    'autoRepair': autoRepair.name,
    'readerEffect': readerEffect.name,
    'referenceUsage': referenceUsage.name,
    'styleIntensity': styleIntensity,
    'qualityGateMode': qualityGateMode.wire,
  };

  final QualityStrictness strictness;
  final AutoRepairMode autoRepair;
  final ReaderEffectMode readerEffect;
  final ReferenceUsage referenceUsage;
  final int styleIntensity;
  final LiteraryQualityGateMode qualityGateMode;
}

final class LiteraryQualityPolicyInput {
  const LiteraryQualityPolicyInput({
    required this.evaluationValid,
    required this.craftOverall,
    required this.criticalCraftMinimum,
    required this.calibratedConfidence,
    required this.findings,
    required this.styleFit,
    this.independentRescoreCompleted = false,
    this.deterministicHardGatePassed = true,
    this.semanticHardReviewPassed = true,
    this.reviewerClassConflict = false,
    this.reviewerScoreSpread = 0,
    this.maxAllowedReviewerScoreSpread = 8,
    this.explicitLowConfidence = false,
    this.repairBudgetRemaining = 1,
    this.evaluatorPolicyCertified = false,
    this.dualReviewersAgree = false,
    this.reviewerCalibratedConfidences = const <double>[],
    this.authorRequestedManualReview = false,
    this.evaluatorCertificationId = 'uncertified',
  });

  factory LiteraryQualityPolicyInput.fromLayeredResult(
    LayeredQualityResult result, {
    bool independentRescoreCompleted = false,
    bool reviewerClassConflict = false,
    double maxAllowedReviewerScoreSpread = 8,
    bool explicitLowConfidence = false,
    int repairBudgetRemaining = 1,
    bool evaluatorPolicyCertified = false,
    bool dualReviewersAgree = false,
    bool authorRequestedManualReview = false,
  }) {
    final reviewerScores = [
      for (final verdict in result.evaluatorVerdicts) verdict.craftOverall,
    ];
    final confidences = [
      for (final verdict in result.evaluatorVerdicts)
        verdict.calibratedConfidence,
    ];
    return LiteraryQualityPolicyInput(
      evaluationValid: true,
      craftOverall: result.craft.craftOverall,
      criticalCraftMinimum: result.craft.criticalCraftMinimum,
      calibratedConfidence: result.calibratedConfidence,
      findings: result.findings,
      styleFit: result.styleFit,
      independentRescoreCompleted: independentRescoreCompleted,
      deterministicHardGatePassed: result.deterministicGate.passed,
      semanticHardReviewPassed: result.semanticHardReview.passed,
      reviewerClassConflict: reviewerClassConflict,
      reviewerScoreSpread: _scoreSpread(reviewerScores),
      maxAllowedReviewerScoreSpread: maxAllowedReviewerScoreSpread,
      explicitLowConfidence: explicitLowConfidence,
      repairBudgetRemaining: repairBudgetRemaining,
      evaluatorPolicyCertified: evaluatorPolicyCertified,
      dualReviewersAgree: dualReviewersAgree,
      reviewerCalibratedConfidences: confidences,
      authorRequestedManualReview: authorRequestedManualReview,
      evaluatorCertificationId: result.decision.evaluatorCertificationId,
    );
  }

  final bool evaluationValid;
  final double craftOverall;
  final double criticalCraftMinimum;
  final double calibratedConfidence;
  final List<QualityFinding> findings;
  final StyleFitResult styleFit;
  final bool independentRescoreCompleted;
  final bool deterministicHardGatePassed;
  final bool semanticHardReviewPassed;
  final bool reviewerClassConflict;
  final double reviewerScoreSpread;
  final double maxAllowedReviewerScoreSpread;
  final bool explicitLowConfidence;
  final int repairBudgetRemaining;
  final bool evaluatorPolicyCertified;
  final bool dualReviewersAgree;
  final List<double> reviewerCalibratedConfidences;
  final bool authorRequestedManualReview;
  final String evaluatorCertificationId;
}

final class LiteraryQualityPolicyOutcome {
  const LiteraryQualityPolicyOutcome({
    required this.decision,
    required this.action,
    this.requiresIndependentRescore = false,
  });

  final SceneCandidateDecision decision;
  final LiteraryQualityPolicyAction action;
  final bool requiresIndependentRescore;

  SceneCandidateStatus get status => decision.status;
  String get reasonCode => decision.reasonCode;
}

final class NarrativeTransitionValidationInput {
  const NarrativeTransitionValidationInput({
    required this.currentChain,
    required this.proposedChain,
    this.proposal,
    this.receipt,
  });

  final NarrativeContractChain currentChain;
  final NarrativeContractChain proposedChain;
  final NarrativeTransitionProposal? proposal;
  final AuthorTransitionReceipt? receipt;
}

final class NarrativeTransitionValidationOutcome {
  const NarrativeTransitionValidationOutcome({
    required this.structurallyValid,
    required this.reasonCode,
    this.requiredTransitionKind,
  });

  final bool structurallyValid;
  final String reasonCode;
  final NarrativeTransitionKind? requiredTransitionKind;
}

abstract final class LiteraryQualityPolicy {
  static const thresholdPolicyVersion = 'threshold-policy-v1-calibration';

  static LiteraryQualityPolicyOutcome decide(LiteraryQualityPolicyInput input) {
    final invalidReason = _invalidReason(input);
    if (invalidReason != null) {
      if (!input.independentRescoreCompleted) {
        return _outcome(
          input,
          SceneCandidateStatus.manualReview,
          LiteraryQualityPolicyAction.independentRescoreRequired,
          invalidReason,
          requiresIndependentRescore: true,
        );
      }
      return _outcome(
        input,
        SceneCandidateStatus.manualReview,
        LiteraryQualityPolicyAction.manualReview,
        'invalidAfterIndependentRescore',
      );
    }

    if (!input.deterministicHardGatePassed ||
        !input.semanticHardReviewPassed ||
        input.findings.any(_isHardError)) {
      return _outcome(
        input,
        SceneCandidateStatus.blocked,
        LiteraryQualityPolicyAction.blocked,
        'hardGateOrHardError',
      );
    }

    if (input.authorRequestedManualReview ||
        input.reviewerClassConflict ||
        input.reviewerScoreSpread > input.maxAllowedReviewerScoreSpread ||
        input.explicitLowConfidence) {
      return _outcome(
        input,
        SceneCandidateStatus.manualReview,
        LiteraryQualityPolicyAction.manualReview,
        'reviewerConflictOrLowConfidence',
      );
    }

    final majorCount = _majorCount(input);
    final repairReason = _repairReason(input, majorCount);
    if (repairReason != null) {
      if (input.repairBudgetRemaining <= 0) {
        return _outcome(
          input,
          SceneCandidateStatus.manualReview,
          LiteraryQualityPolicyAction.manualReview,
          'repairBudgetExhausted',
        );
      }
      return _outcome(
        input,
        SceneCandidateStatus.repairRequired,
        LiteraryQualityPolicyAction.repairRequired,
        repairReason,
      );
    }

    final overall = input.craftOverall;
    final critical = input.criticalCraftMinimum;
    if (overall >= 95 && critical >= 90) {
      if (input.calibratedConfidence < 0.75) {
        return _outcome(
          input,
          SceneCandidateStatus.manualReview,
          LiteraryQualityPolicyAction.manualReview,
          'highCandidateConfidenceTooLow',
        );
      }
      if (_publicationPrerequisitesMet(input)) {
        return _outcome(
          input,
          SceneCandidateStatus.sceneReleaseCandidate,
          LiteraryQualityPolicyAction.candidate,
          'sceneReleaseCandidate',
        );
      }
      return _outcome(
        input,
        SceneCandidateStatus.highCandidate,
        LiteraryQualityPolicyAction.candidate,
        'publicationReviewPending',
      );
    }
    if (overall >= 92 && critical >= 88) {
      if (input.calibratedConfidence < 0.75) {
        return _outcome(
          input,
          SceneCandidateStatus.manualReview,
          LiteraryQualityPolicyAction.manualReview,
          'highCandidateConfidenceTooLow',
        );
      }
      return _outcome(
        input,
        SceneCandidateStatus.highCandidate,
        LiteraryQualityPolicyAction.candidate,
        'highCandidate',
      );
    }
    if (overall >= 90 && critical >= 85) {
      if (input.calibratedConfidence < 0.70) {
        return _outcome(
          input,
          SceneCandidateStatus.manualReview,
          LiteraryQualityPolicyAction.manualReview,
          'autoCandidateConfidenceTooLow',
        );
      }
      return _outcome(
        input,
        SceneCandidateStatus.autoCandidate,
        LiteraryQualityPolicyAction.candidate,
        'autoCandidate',
      );
    }
    return _outcome(
      input,
      SceneCandidateStatus.draftKeep,
      LiteraryQualityPolicyAction.draftKeep,
      'draftKeep',
    );
  }

  /// Pure policy query. It neither calls the finalizer nor establishes proof.
  static bool v2BlocksCandidateFinalization({
    required LiteraryQualityGateMode gateMode,
    required SceneCandidateStatus status,
  }) =>
      gateMode == LiteraryQualityGateMode.enforceV2 &&
      status != SceneCandidateStatus.autoCandidate &&
      status != SceneCandidateStatus.highCandidate &&
      status != SceneCandidateStatus.sceneReleaseCandidate;

  /// Pure policy query. Production wiring remains a later gated work package.
  static bool v2AllowsAutomaticFinalization({
    required LiteraryQualityGateMode gateMode,
    required SceneCandidateStatus status,
    required QualityStrictness strictness,
  }) =>
      gateMode == LiteraryQualityGateMode.enforceV2 &&
      strictness != QualityStrictness.draft &&
      _rank(status) >= _automaticFinalizationMinimum(strictness);

  /// Pure policy query. Author acceptance still requires existing proof/receipt.
  static bool v2AllowsExplicitAcceptance({
    required LiteraryQualityGateMode gateMode,
    required SceneCandidateStatus status,
  }) =>
      gateMode == LiteraryQualityGateMode.enforceV2 &&
      _rank(status) >= _rank(SceneCandidateStatus.autoCandidate);

  static bool productionDecisionUsesV2(LiteraryQualityGateMode mode) =>
      mode == LiteraryQualityGateMode.enforceV2;

  /// Validates typed contract continuity and receipt binding only.
  ///
  /// A structurally valid result does not prove that the receipt came from the
  /// authoritative author-action store. Production consumers must load the
  /// receipt through that authority boundary before applying the transition.
  static NarrativeTransitionValidationOutcome
  validateNarrativeTransitionStructure(
    NarrativeTransitionValidationInput input,
  ) {
    final current = input.currentChain;
    final proposed = input.proposedChain;
    final currentCharter = current.projectCharter;
    final proposedCharter = proposed.projectCharter;
    final currentArc = current.arcContract;
    final proposedArc = proposed.arcContract;

    if (currentCharter.projectId != proposedCharter.projectId ||
        currentCharter.charterId != proposedCharter.charterId ||
        currentArc.arcContractId != proposedArc.arcContractId ||
        currentArc.arcId != proposedArc.arcId) {
      return const NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'transitionContractIdentityMismatch',
      );
    }
    if (proposed.sceneContract.previousAcceptedSceneContractHash !=
        current.sceneContract.sceneContractHash) {
      return const NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'sceneParentContinuityMismatch',
      );
    }

    final charterChanged =
        currentCharter.charterHash != proposedCharter.charterHash;
    final arcChanged =
        currentArc.arcContractHash != proposedArc.arcContractHash;
    final phaseChanged =
        currentArc.phaseGoalId != proposedArc.phaseGoalId ||
        currentArc.phaseGoalStatement != proposedArc.phaseGoalStatement;
    if (charterChanged) {
      if (proposedCharter.revision != currentCharter.revision + 1) {
        return const NarrativeTransitionValidationOutcome(
          structurallyValid: false,
          reasonCode: 'transitionRevisionMismatch',
        );
      }
      if (proposedCharter.previousCharterHash != currentCharter.charterHash) {
        return const NarrativeTransitionValidationOutcome(
          structurallyValid: false,
          reasonCode: 'transitionParentContinuityMismatch',
        );
      }
    }
    if (arcChanged) {
      if (proposedArc.revision != currentArc.revision + 1) {
        return const NarrativeTransitionValidationOutcome(
          structurallyValid: false,
          reasonCode: 'transitionRevisionMismatch',
        );
      }
      if (proposedArc.previousArcContractHash != currentArc.arcContractHash) {
        return const NarrativeTransitionValidationOutcome(
          structurallyValid: false,
          reasonCode: 'transitionParentContinuityMismatch',
        );
      }
    }
    if (charterChanged && phaseChanged) {
      return const NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'multipleProtectedTransitionsRequireSeparateReceipts',
      );
    }

    final requiredKind = _requiredTransitionKind(
      current: current,
      proposed: proposed,
      charterChanged: charterChanged,
      arcChanged: arcChanged,
    );
    if (requiredKind == null) {
      if (input.proposal != null || input.receipt != null) {
        return const NarrativeTransitionValidationOutcome(
          structurallyValid: false,
          reasonCode: 'unexpectedTransitionAuthorization',
        );
      }
      return const NarrativeTransitionValidationOutcome(
        structurallyValid: true,
        reasonCode: 'ordinarySceneAdvance',
      );
    }

    final proposal = input.proposal;
    final receipt = input.receipt;
    if (proposal == null || receipt == null) {
      return NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'missingAcceptedTransitionReceipt',
        requiredTransitionKind: requiredKind,
      );
    }

    final expectedFromHash = switch (requiredKind) {
      NarrativeTransitionKind.promiseTransform ||
      NarrativeTransitionKind.charterRevision => currentCharter.charterHash,
      NarrativeTransitionKind.phaseAdvance => currentArc.arcContractHash,
    };
    final expectedProposedHash = switch (requiredKind) {
      NarrativeTransitionKind.promiseTransform ||
      NarrativeTransitionKind.charterRevision => proposedCharter.charterHash,
      NarrativeTransitionKind.phaseAdvance => proposedArc.arcContractHash,
    };
    if (proposal.fromContractHash != expectedFromHash ||
        proposal.proposedContractHash != expectedProposedHash ||
        proposal.transitionKind != requiredKind) {
      return NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'transitionProposalBindingMismatch',
        requiredTransitionKind: requiredKind,
      );
    }
    if (receipt.proposalId != proposal.proposalId ||
        receipt.fromContractHash != proposal.fromContractHash ||
        receipt.proposedContractHash != proposal.proposedContractHash ||
        receipt.transitionKind != proposal.transitionKind ||
        receipt.proposalHash != proposal.proposalHash ||
        receipt.decision != AuthorDecisionStatus.accepted ||
        receipt.receiptId.trim().isEmpty) {
      return NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'transitionReceiptBindingMismatch',
        requiredTransitionKind: requiredKind,
      );
    }
    if (proposal.authorDecision != AuthorDecisionStatus.accepted ||
        proposal.authorReceiptId != receipt.receiptId) {
      return NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'transitionAuthorDecisionNotAccepted',
        requiredTransitionKind: requiredKind,
      );
    }
    if ((charterChanged &&
            proposedCharter.transitionReceiptId != receipt.receiptId) ||
        (arcChanged && proposedArc.transitionReceiptId != receipt.receiptId)) {
      return NarrativeTransitionValidationOutcome(
        structurallyValid: false,
        reasonCode: 'transitionContractReceiptMismatch',
        requiredTransitionKind: requiredKind,
      );
    }
    return NarrativeTransitionValidationOutcome(
      structurallyValid: true,
      reasonCode: 'acceptedTransitionStructure',
      requiredTransitionKind: requiredKind,
    );
  }

  static String? _invalidReason(LiteraryQualityPolicyInput input) {
    if (!input.evaluationValid ||
        !_isScore(input.craftOverall) ||
        !_isScore(input.criticalCraftMinimum) ||
        !_isConfidence(input.calibratedConfidence) ||
        input.criticalCraftMinimum > input.craftOverall + 0.000000001 ||
        input.evaluatorCertificationId.trim().isEmpty) {
      return 'invalidEvaluation';
    }
    if (!input.reviewerScoreSpread.isFinite ||
        !input.maxAllowedReviewerScoreSpread.isFinite ||
        input.reviewerScoreSpread < 0 ||
        input.maxAllowedReviewerScoreSpread < 0 ||
        input.repairBudgetRemaining < 0) {
      return 'invalidEvaluation';
    }
    if (input.reviewerCalibratedConfidences.any(
      (value) => !_isConfidence(value),
    )) {
      return 'invalidEvaluation';
    }
    if ((input.craftOverall < 85 || input.criticalCraftMinimum < 80) &&
        !input.findings.any(_isActionableLowScoreFinding)) {
      return 'invalidEvaluation';
    }
    return null;
  }

  static String? _repairReason(
    LiteraryQualityPolicyInput input,
    int majorCount,
  ) {
    if (input.craftOverall < 85) return 'craftOverallBelow85';
    if (input.criticalCraftMinimum < 80) return 'criticalCraftBelow80';
    if (input.styleFit.decision == StyleFitDecision.mismatch) {
      return 'unapprovedStyleMismatch';
    }
    final majorLimit = _majorFindingLimit(input);
    if (majorLimit != null && majorCount > majorLimit) {
      return 'majorFindingLimitExceeded';
    }
    return null;
  }

  static int? _majorFindingLimit(LiteraryQualityPolicyInput input) {
    if (input.craftOverall >= 95 && input.criticalCraftMinimum >= 90) return 0;
    if (input.craftOverall >= 92 && input.criticalCraftMinimum >= 88) return 1;
    if (input.craftOverall >= 90 && input.criticalCraftMinimum >= 85) return 2;
    return null;
  }

  static bool _publicationPrerequisitesMet(LiteraryQualityPolicyInput input) {
    if (input.criticalCraftMinimum < 90 ||
        _majorCount(input) > 0 ||
        !input.evaluatorPolicyCertified ||
        !input.dualReviewersAgree ||
        input.reviewerCalibratedConfidences.length < 2) {
      return false;
    }
    return input.reviewerCalibratedConfidences.every(
      (confidence) => confidence >= 0.80,
    );
  }

  static bool _isHardError(QualityFinding finding) =>
      finding.findingClass == QualityFindingClass.hardError;

  static int _majorCount(LiteraryQualityPolicyInput input) => input.findings
      .where(
        (finding) =>
            finding.findingClass == QualityFindingClass.craftWeakness &&
            finding.severity == QualitySeverity.major,
      )
      .length;

  static bool _isActionableLowScoreFinding(QualityFinding finding) =>
      finding.findingClass == QualityFindingClass.craftWeakness &&
      finding.severity != QualitySeverity.note &&
      finding.evidence.isNotEmpty &&
      (finding.suggestedAction == RepairAction.targetedRepair ||
          finding.suggestedAction == RepairAction.alignVoice ||
          finding.suggestedAction == RepairAction.blockAndReplan);

  static bool _isScore(double value) =>
      value.isFinite && value >= 0 && value <= 100;

  static bool _isConfidence(double value) =>
      value.isFinite && value >= 0 && value <= 1;

  static int _automaticFinalizationMinimum(QualityStrictness strictness) =>
      switch (strictness) {
        QualityStrictness.draft =>
          _rank(SceneCandidateStatus.sceneReleaseCandidate) + 1,
        QualityStrictness.standard => _rank(SceneCandidateStatus.autoCandidate),
        QualityStrictness.strict => _rank(SceneCandidateStatus.highCandidate),
        QualityStrictness.publication => _rank(
          SceneCandidateStatus.sceneReleaseCandidate,
        ),
      };

  static int _rank(SceneCandidateStatus status) => switch (status) {
    SceneCandidateStatus.blocked => 0,
    SceneCandidateStatus.repairRequired => 1,
    SceneCandidateStatus.draftKeep => 2,
    SceneCandidateStatus.manualReview => 2,
    SceneCandidateStatus.autoCandidate => 3,
    SceneCandidateStatus.highCandidate => 4,
    SceneCandidateStatus.sceneReleaseCandidate => 5,
  };

  static NarrativeTransitionKind? _requiredTransitionKind({
    required NarrativeContractChain current,
    required NarrativeContractChain proposed,
    required bool charterChanged,
    required bool arcChanged,
  }) {
    if (current.projectCharter.corePromiseId !=
        proposed.projectCharter.corePromiseId) {
      return NarrativeTransitionKind.promiseTransform;
    }
    if (charterChanged) return NarrativeTransitionKind.charterRevision;
    if (arcChanged) {
      return NarrativeTransitionKind.phaseAdvance;
    }
    return null;
  }

  static LiteraryQualityPolicyOutcome _outcome(
    LiteraryQualityPolicyInput input,
    SceneCandidateStatus status,
    LiteraryQualityPolicyAction action,
    String reasonCode, {
    bool requiresIndependentRescore = false,
  }) => LiteraryQualityPolicyOutcome(
    decision: SceneCandidateDecision(
      status: status,
      reasonCode: reasonCode,
      craftOverall: _safeScore(input.craftOverall),
      criticalCraftMinimum: _safeScore(input.criticalCraftMinimum),
      styleFit: input.styleFit.decision,
      findingIds: [for (final finding in input.findings) finding.findingId],
      evaluatorCertificationId: input.evaluatorCertificationId,
    ),
    action: action,
    requiresIndependentRescore: requiresIndependentRescore,
  );
}

double _safeScore(double value) {
  if (!value.isFinite) return 0;
  return value.clamp(0, 100).toDouble();
}

T _enumFromJson<T extends Enum>(
  Map<String, Object?> json,
  String key,
  List<T> values,
  String Function(T value) wire,
  T missingDefault,
) {
  final raw = json[key];
  if (raw == null) return missingDefault;
  if (raw is! String) {
    throw FormatException('$key must be a string enum value');
  }
  for (final value in values) {
    if (wire(value) == raw) return value;
  }
  throw FormatException('unknown $key enum value: $raw');
}

double _scoreSpread(List<double> scores) {
  if (scores.length < 2) return 0;
  var min = scores.first;
  var max = scores.first;
  for (final score in scores.skip(1)) {
    if (score < min) min = score;
    if (score > max) max = score;
  }
  return max - min;
}
