import 'dart:convert';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';

import '../domain/contracts/settings_contract.dart';
import '../domain/literary_quality_models.dart';
import 'evaluation/agent_evaluation_trace_context.dart';
import 'generation_evidence_fingerprints.dart';
import 'literary_quality_policy.dart';
import 'story_generation_pass_retry.dart';
import 'story_prompt_registry.dart';

/// The structured evaluator needs room for provider reasoning plus its closed
/// JSON object. Keeping the ceiling equal to the initial limit avoids the
/// generic story-generation token ladder for this bounded stage.
const int literaryQualityEvaluationMaxTokens = 8192;
const int _literaryQualityMaxTransientRetries = 2;
const int _literaryQualityMaxOutputRetries = 1;

/// Trusted calibration inputs used to derive confidence locally.
///
/// The evaluator's self-reported confidence is deliberately excluded from
/// every gate-facing confidence value.
final class SceneLiteraryQualityCalibration {
  SceneLiteraryQualityCalibration({
    required this.certification,
    required this.historicalOverallLowerBound,
    required Map<QualityFindingClass, double> findingClassLowerBounds,
    required this.repeatAgreementConfidence,
  }) : findingClassLowerBounds = Map.unmodifiable(findingClassLowerBounds) {
    if (certification.status !=
            EvaluatorPolicyCertificationStatus.development &&
        certification.status != EvaluatorPolicyCertificationStatus.beta) {
      throw ArgumentError(
        'WP2 evaluator accepts development or beta calibration only',
      );
    }
    _requireUnitInterval(
      historicalOverallLowerBound,
      'historicalOverallLowerBound',
    );
    _requireUnitInterval(
      repeatAgreementConfidence,
      'repeatAgreementConfidence',
    );
    if (this.findingClassLowerBounds.keys.toSet().length !=
            QualityFindingClass.values.length ||
        !this.findingClassLowerBounds.keys.toSet().containsAll(
          QualityFindingClass.values,
        )) {
      throw ArgumentError(
        'findingClassLowerBounds must cover every finding class exactly',
      );
    }
    for (final entry in this.findingClassLowerBounds.entries) {
      _requireUnitInterval(entry.value, '${entry.key.wire}LowerBound');
    }
  }

  final EvaluatorPolicyCertification certification;
  final double historicalOverallLowerBound;
  final Map<QualityFindingClass, double> findingClassLowerBounds;
  final double repeatAgreementConfidence;

  double get overallConfidence =>
      _minimum([1, historicalOverallLowerBound, repeatAgreementConfidence]);

  double confidenceFor(QualityFindingClass findingClass) => _minimum([
    1,
    findingClassLowerBounds[findingClass]!,
    repeatAgreementConfidence,
  ]);

  void validateAuthority({
    required String rubricVersion,
    required String promptReleaseHash,
  }) {
    if (certification.rubricVersion != rubricVersion ||
        certification.promptReleaseHash != promptReleaseHash ||
        certification.thresholdPolicyVersion !=
            LiteraryQualityPolicy.thresholdPolicyVersion) {
      throw StateError('calibration authority does not match evaluator input');
    }
  }
}

/// Exact prose revision and trusted contracts evaluated by the shadow judge.
final class SceneLiteraryQualityEvaluationInput {
  SceneLiteraryQualityEvaluationInput({
    required this.prose,
    required this.contractChain,
    required this.voiceProfile,
    required this.sceneCraftContract,
    required this.ledgerSnapshotHash,
    required this.deterministicGate,
    required this.rubricVersion,
    required this.calibration,
    required this.createdAtMs,
  }) {
    if (prose.trim().isEmpty) {
      throw ArgumentError('prose must not be empty');
    }
    if (ledgerSnapshotHash.trim().isEmpty || rubricVersion.trim().isEmpty) {
      throw ArgumentError('ledgerSnapshotHash and rubricVersion are required');
    }
    if (createdAtMs < 0) {
      throw ArgumentError('createdAtMs must be non-negative');
    }
    if (voiceProfile.projectId != contractChain.projectCharter.projectId ||
        sceneCraftContract.sceneContractId !=
            contractChain.sceneContract.sceneContractId ||
        sceneCraftContract.sceneContractHash !=
            contractChain.sceneContract.sceneContractHash ||
        sceneCraftContract.voiceProfileId != voiceProfile.profileId ||
        sceneCraftContract.voiceProfileHash != voiceProfile.profileHash) {
      throw ArgumentError('literary evaluator input contracts do not align');
    }
  }

  final String prose;
  final NarrativeContractChain contractChain;
  final ProjectVoiceProfile voiceProfile;
  final SceneCraftContract sceneCraftContract;
  final String ledgerSnapshotHash;
  final DeterministicGateRef deterministicGate;
  final String rubricVersion;
  final SceneLiteraryQualityCalibration calibration;
  final int createdAtMs;

  String get proseHash =>
      AppLlmCanonicalHash.domainHash('scene-literary-prose-v1', prose);

  Set<String> get contractRefAllowlist => Set.unmodifiable({
    contractChain.chainHash,
    contractChain.projectCharter.charterId,
    contractChain.projectCharter.charterHash,
    contractChain.projectCharter.corePromiseId,
    ...contractChain.projectCharter.centralTensionIds,
    ...contractChain.projectCharter.invariantWorldRuleRefs,
    ...contractChain.projectCharter.invariantPovRules,
    contractChain.arcContract.arcContractId,
    contractChain.arcContract.arcContractHash,
    contractChain.arcContract.arcId,
    contractChain.arcContract.phaseGoalId,
    ...contractChain.arcContract.activePromiseIds,
    ...contractChain.arcContract.payoffWindowIds,
    contractChain.sceneContract.sceneContractId,
    contractChain.sceneContract.sceneContractHash,
    contractChain.sceneContract.chapterId,
    contractChain.sceneContract.sceneId,
    ...contractChain.sceneContract.worldRuleRefs,
    ...contractChain.sceneContract.requiredFactRefs,
    ...contractChain.sceneContract.activePromiseIds,
    ...contractChain.sceneContract.payoffWindowIds,
    ...contractChain.sceneContract.castIds,
    voiceProfile.profileId,
    voiceProfile.profileHash,
    sceneCraftContract.craftId,
    sceneCraftContract.craftHash,
    ...sceneCraftContract.invariantsToPreserve,
    ledgerSnapshotHash,
    deterministicGate.evidenceHash,
  });

  List<DeviationAuthorizationRef> get deviationAuthorizationAllowlist {
    final values = <DeviationAuthorizationRef>[
      for (final deviation in voiceProfile.allowedDeviations)
        DeviationAuthorizationRef(
          authorizedBy: deviation.authorizedBy,
          referenceId: deviation.deviationId,
        ),
      for (final deviation in sceneCraftContract.allowedDeviations)
        DeviationAuthorizationRef(
          authorizedBy: deviation.authorizedBy,
          referenceId: deviation.deviationId,
        ),
    ];
    final byKey = <String, DeviationAuthorizationRef>{};
    for (final value in values) {
      byKey[_authorizationKey(value)] = value;
    }
    final keys = byKey.keys.toList()..sort();
    return List.unmodifiable([for (final key in keys) byKey[key]!]);
  }

  Set<String> get deviationIdAllowlist => Set.unmodifiable({
    for (final value in deviationAuthorizationAllowlist) value.referenceId,
  });

  Map<String, Object?> get promptInputJson => {
    'schemaVersion': 1,
    'prose': prose,
    'evidenceSegments': _evidenceSegments(prose),
    'narrativeContext': {
      'corePromise': contractChain.projectCharter.corePromiseStatement,
      'phaseGoal': contractChain.arcContract.phaseGoalStatement,
      'narrativeQuestion': contractChain.arcContract.currentNarrativeQuestion,
      'sceneContribution': contractChain.sceneContract.sceneContribution,
      'povPolicy': contractChain.sceneContract.povPolicy.toJson(),
      'worldRuleRefs': contractChain.sceneContract.worldRuleRefs,
      'requiredFactRefs': contractChain.sceneContract.requiredFactRefs,
      'forbiddenContradictions':
          contractChain.sceneContract.forbiddenContradictions,
      'activePromiseIds': contractChain.sceneContract.activePromiseIds,
      'payoffWindowIds': contractChain.sceneContract.payoffWindowIds,
      'castIds': contractChain.sceneContract.castIds,
    },
    'voiceContext': {
      'styleIntensity': voiceProfile.styleIntensity,
      'povMode': voiceProfile.povMode.wire,
      'narrativeDistance': voiceProfile.narrativeDistance.wire,
      'lexiconRegister': voiceProfile.lexiconRegister.wire,
      'metaphorDomains': voiceProfile.metaphorDomains,
      'sensoryPriorities': voiceProfile.sensoryPriorities,
      'rhythm': voiceProfile.rhythm.toJson(),
      'dialogue': voiceProfile.dialogue.toJson(),
      'descriptionDensity': voiceProfile.descriptionDensity.toJson(),
      'emotionalTemperature': voiceProfile.emotionalTemperature.wire,
      'voiceConstraints': [
        for (final value in voiceProfile.voiceConstraints) value.toJson(),
      ],
      'projectOwnedNotes': voiceProfile.projectOwnedNotes,
      'tabooPatterns': voiceProfile.tabooPatterns,
      'allowedDeviations': [
        for (final value in voiceProfile.allowedDeviations) value.toJson(),
      ],
    },
    'craftContext': {
      'primaryFunction': sceneCraftContract.primaryFunction.wire,
      'secondaryFunctions': [
        for (final value in sceneCraftContract.secondaryFunctions) value.wire,
      ],
      'sceneGoal': sceneCraftContract.sceneGoal,
      'blockingConflict': sceneCraftContract.blockingConflict,
      'progression': sceneCraftContract.progression,
      'exitCondition': sceneCraftContract.exitCondition,
      'plannedBeats': sceneCraftContract.plannedBeats,
      'desiredStateChanges': [
        for (final value in sceneCraftContract.desiredStateChanges)
          value.toJson(),
      ],
      'requiredReveals': sceneCraftContract.requiredReveals,
      'requiredWithholds': sceneCraftContract.requiredWithholds,
      'readerQuestionBefore': sceneCraftContract.readerQuestionBefore,
      'readerQuestionAfterTarget': sceneCraftContract.readerQuestionAfterTarget,
      'pressureCurve': sceneCraftContract.pressureCurve.wire,
      'rhythmIntent': sceneCraftContract.rhythmIntent.toJson(),
      'invariantsToPreserve': sceneCraftContract.invariantsToPreserve,
      'allowedDeviations': [
        for (final value in sceneCraftContract.allowedDeviations)
          value.toJson(),
      ],
    },
    'contractRefAllowlist': contractRefAllowlist.toList()..sort(),
    'deviationAuthorizationAllowlist': [
      for (final value in deviationAuthorizationAllowlist) value.toJson(),
    ],
  };
}

final class SceneLiteraryQualityEvaluationException implements Exception {
  const SceneLiteraryQualityEvaluationException(this.code, this.detail);

  final String code;
  final String detail;

  @override
  String toString() =>
      'SceneLiteraryQualityEvaluationException($code: $detail)';
}

/// Strict, evidence-validating parser for the evaluator transport schema.
final class SceneLiteraryQualityOutputParser {
  const SceneLiteraryQualityOutputParser();

  LayeredQualityResult parse({
    required String rawOutput,
    required SceneLiteraryQualityEvaluationInput input,
    required String promptReleaseHash,
    required String providerModel,
  }) {
    try {
      return _parse(
        rawOutput: rawOutput,
        input: input,
        promptReleaseHash: promptReleaseHash,
        providerModel: providerModel,
      );
    } on SceneLiteraryQualityEvaluationException {
      rethrow;
    } catch (error) {
      throw SceneLiteraryQualityEvaluationException(
        'invalid_model_output',
        error.toString(),
      );
    }
  }

  LayeredQualityResult _parse({
    required String rawOutput,
    required SceneLiteraryQualityEvaluationInput input,
    required String promptReleaseHash,
    required String providerModel,
  }) {
    if (providerModel.trim().isEmpty) {
      throw const FormatException('providerModel is required');
    }
    input.calibration.validateAuthority(
      rubricVersion: input.rubricVersion,
      promptReleaseHash: promptReleaseHash,
    );
    if (providerModel !=
        input.calibration.certification.evaluatorModelRelease) {
      throw const FormatException(
        'provider model does not match calibration authority',
      );
    }

    _DuplicateJsonKeyScanner(rawOutput).scan();
    final decoded = jsonDecode(rawOutput);
    final root = _asObject(decoded, r'$');
    _expectExactKeys(root, r'$', const {
      'schemaVersion',
      'semanticHardReview',
      'craft',
      'styleFit',
      'readerEffect',
      'findings',
      'evaluatorSelfConfidence',
    });
    if (_requiredInt(root, 'schemaVersion', r'$') != 1) {
      throw const FormatException('unsupported evaluator schemaVersion');
    }

    final craft = _parseCraft(_requiredObject(root, 'craft', r'$'));
    final parsedFindings = _parseFindings(
      _requiredList(root, 'findings', r'$'),
      input,
    );
    final findingIds = {
      for (final finding in parsedFindings) finding.findingId,
    };
    if (findingIds.length != parsedFindings.length) {
      throw const FormatException('findingId values must be unique');
    }

    final styleFit = _parseStyleFit(
      _requiredObject(root, 'styleFit', r'$'),
      input,
      parsedFindings,
    );
    _validateFindingConsistency(
      craft: craft,
      findings: parsedFindings,
      styleFit: styleFit,
    );

    final semanticHardReview = _parseSemanticHardReview(
      _requiredObject(root, 'semanticHardReview', r'$'),
      parsedFindings,
      input.calibration,
    );
    final readerEffect = _parseReaderEffect(
      _requiredObject(root, 'readerEffect', r'$'),
      findingIds,
      input.calibration.overallConfidence,
      providerModel,
      promptReleaseHash,
    );
    final evaluatorSelfConfidence = _requiredDouble(
      root,
      'evaluatorSelfConfidence',
      r'$',
    );
    _requireUnitInterval(evaluatorSelfConfidence, 'evaluatorSelfConfidence');

    final calibratedConfidence = input.calibration.overallConfidence;
    final evaluatorIdHash = AppLlmCanonicalHash.domainHash(
      'scene-literary-evaluator-id-v1',
      {
        'providerModel': providerModel,
        'promptReleaseHash': promptReleaseHash,
        'rubricVersion': input.rubricVersion,
        'certificationHash': input.calibration.certification.certificationHash,
      },
    );
    final evaluatorVerdict = EvaluatorVerdict(
      evaluatorIdHash: evaluatorIdHash,
      evaluatorRelease: providerModel,
      craftOverall: craft.craftOverall,
      findingIds: findingIds.toList(),
      calibratedConfidence: calibratedConfidence,
    );
    final policyOutcome = LiteraryQualityPolicy.decide(
      LiteraryQualityPolicyInput(
        evaluationValid: true,
        craftOverall: craft.craftOverall,
        criticalCraftMinimum: craft.criticalCraftMinimum,
        calibratedConfidence: calibratedConfidence,
        findings: parsedFindings,
        styleFit: styleFit,
        deterministicHardGatePassed: input.deterministicGate.passed,
        semanticHardReviewPassed: semanticHardReview.passed,
        repairBudgetRemaining: input.sceneCraftContract.targetedRepairBudget,
        evaluatorPolicyCertified: false,
        dualReviewersAgree: false,
        reviewerCalibratedConfidences: [calibratedConfidence],
        evaluatorCertificationId:
            input.calibration.certification.certificationId,
      ),
    );
    final transportHash = AppLlmCanonicalHash.domainHash(
      'scene-literary-evaluator-transport-v1',
      root,
    );
    final evidenceId =
        AppLlmCanonicalHash.domainHash('scene-literary-evidence-id-v1', {
          'proseHash': input.proseHash,
          'projectCharterHash': input.contractChain.projectCharter.charterHash,
          'arcContractHash': input.contractChain.arcContract.arcContractHash,
          'sceneContractHash':
              input.contractChain.sceneContract.sceneContractHash,
          'voiceProfileHash': input.voiceProfile.profileHash,
          'ledgerSnapshotHash': input.ledgerSnapshotHash,
          'promptReleaseHash': promptReleaseHash,
          'providerModel': providerModel,
          'transportHash': transportHash,
        });

    return LayeredQualityResult.create(
      schemaVersion: 1,
      evidenceId: evidenceId,
      proseHash: input.proseHash,
      projectCharterHash: input.contractChain.projectCharter.charterHash,
      arcContractHash: input.contractChain.arcContract.arcContractHash,
      sceneContractHash: input.contractChain.sceneContract.sceneContractHash,
      voiceProfileHash: input.voiceProfile.profileHash,
      ledgerSnapshotHash: input.ledgerSnapshotHash,
      rubricVersion: input.rubricVersion,
      promptReleaseHash: promptReleaseHash,
      thresholdPolicyVersion: LiteraryQualityPolicy.thresholdPolicyVersion,
      deterministicGate: input.deterministicGate,
      semanticHardReview: semanticHardReview,
      craft: craft,
      styleFit: styleFit,
      readerEffect: readerEffect,
      findings: parsedFindings,
      evaluatorVerdicts: [evaluatorVerdict],
      calibratedConfidence: calibratedConfidence,
      evaluatorSelfConfidence: evaluatorSelfConfidence,
      decision: policyOutcome.decision,
      createdAtMs: input.createdAtMs,
    );
  }

  CraftScore _parseCraft(Map<String, Object?> json) {
    _expectExactKeys(json, r'$.craft', const {'dimensions'});
    final rawDimensions = _requiredObject(json, 'dimensions', r'$.craft');
    _expectExactKeys(
      rawDimensions,
      r'$.craft.dimensions',
      CraftScore.weights.keys.toSet(),
    );
    return CraftScore(
      dimensions: {
        for (final key in CraftScore.weights.keys)
          key: _requiredDouble(rawDimensions, key, r'$.craft.dimensions'),
      },
    );
  }

  List<QualityFinding> _parseFindings(
    List<Object?> values,
    SceneLiteraryQualityEvaluationInput input,
  ) {
    final findings = <QualityFinding>[];
    for (var index = 0; index < values.length; index += 1) {
      final path =
          r'$.findings'
          '[$index]';
      final json = _asObject(values[index], path);
      _expectExactKeys(json, path, const {
        'findingId',
        'findingClass',
        'severity',
        'axis',
        'code',
        'claim',
        'evidence',
        'contractRefs',
        'suggestedAction',
        'effectiveFunction',
        'expectedReturnCondition',
        'deviationAuthorizationRefs',
      });
      final findingClass = _enumValue(
        _requiredString(json, 'findingClass', path),
        QualityFindingClass.values,
        (value) => value.wire,
        '$path.findingClass',
      );
      final severity = _enumValue(
        _requiredString(json, 'severity', path),
        QualitySeverity.values,
        (value) => value.wire,
        '$path.severity',
      );
      final axis = _enumValue(
        _requiredString(json, 'axis', path),
        QualityAxis.values,
        (value) => value.wire,
        '$path.axis',
      );
      final suggestedAction = _enumValue(
        _requiredString(json, 'suggestedAction', path),
        RepairAction.values,
        (value) => value.wire,
        '$path.suggestedAction',
      );
      final evidence = _parseEvidence(
        _requiredList(json, 'evidence', path),
        input.prose,
        path,
      );
      final contractRefs = _uniqueStrings(
        _requiredList(json, 'contractRefs', path),
        '$path.contractRefs',
      );
      if (!input.contractRefAllowlist.containsAll(contractRefs)) {
        throw FormatException('$path contains an unknown contractRef');
      }
      final authorizations = _parseAuthorizations(
        _requiredList(json, 'deviationAuthorizationRefs', path),
        '$path.deviationAuthorizationRefs',
        input,
      );
      if (findingClass == QualityFindingClass.hardError &&
          severity != QualitySeverity.blocker &&
          severity != QualitySeverity.major) {
        throw FormatException('$path hardError must be blocker or major');
      }
      findings.add(
        QualityFinding(
          findingId: _requiredString(json, 'findingId', path),
          findingClass: findingClass,
          severity: severity,
          axis: axis,
          code: _requiredString(json, 'code', path),
          claim: _requiredString(json, 'claim', path),
          evidence: evidence,
          contractRefs: contractRefs,
          calibratedConfidence: input.calibration.confidenceFor(findingClass),
          suggestedAction: suggestedAction,
          effectiveFunction: _nullableString(json, 'effectiveFunction', path),
          expectedReturnCondition: _nullableString(
            json,
            'expectedReturnCondition',
            path,
          ),
          deviationAuthorizationRefs: authorizations,
        ),
      );
    }
    return List.unmodifiable(findings);
  }

  List<TextEvidenceSpan> _parseEvidence(
    List<Object?> values,
    String prose,
    String parentPath,
  ) {
    final spans = <TextEvidenceSpan>[];
    final seen = <String>{};
    for (var index = 0; index < values.length; index += 1) {
      final path = '$parentPath.evidence[$index]';
      final json = _asObject(values[index], path);
      _expectExactKeys(json, path, const {
        'startOffset',
        'endOffset',
        'localExcerpt',
      });
      final excerpt = _requiredString(json, 'localExcerpt', path);
      if (excerpt.length > 240) {
        throw FormatException('$path.localExcerpt exceeds 240 code units');
      }
      final startOffset = _requiredInt(json, 'startOffset', path);
      final endOffset = _requiredInt(json, 'endOffset', path);
      if (startOffset < 0 ||
          endOffset <= startOffset ||
          endOffset > prose.length ||
          !_isUtf16Boundary(prose, startOffset) ||
          !_isUtf16Boundary(prose, endOffset) ||
          prose.substring(startOffset, endOffset) != excerpt) {
        throw FormatException('$path does not bind the exact prose revision');
      }
      final evidenceKey = '$startOffset:$endOffset:$excerpt';
      if (!seen.add(evidenceKey)) {
        throw FormatException('$path duplicates another evidence span');
      }
      spans.add(
        TextEvidenceSpan(
          startOffset: startOffset,
          endOffset: endOffset,
          excerptDigest:
              AppLlmCanonicalHash.domainHash('literary-text-evidence-span-v1', {
                'startOffset': startOffset,
                'endOffset': endOffset,
                'localExcerpt': excerpt,
              }),
          localExcerpt: excerpt,
        ),
      );
    }
    return List.unmodifiable(spans);
  }

  StyleFitResult _parseStyleFit(
    Map<String, Object?> json,
    SceneLiteraryQualityEvaluationInput input,
    List<QualityFinding> findings,
  ) {
    const path = r'$.styleFit';
    _expectExactKeys(json, path, const {
      'decision',
      'axisExplanations',
      'deviationIds',
      'evidenceRefs',
      'deviationAuthorizationRefs',
    });
    final decision = _enumValue(
      _requiredString(json, 'decision', path),
      StyleFitDecision.values,
      (value) => value.wire,
      '$path.decision',
    );
    final explanationJson = _requiredObject(json, 'axisExplanations', path);
    final explanations = <String, String>{};
    for (final entry in explanationJson.entries) {
      final value = entry.value;
      if (entry.key.trim().isEmpty ||
          value is! String ||
          value.trim().isEmpty) {
        throw const FormatException('style axis explanations must be strings');
      }
      explanations[entry.key] = value;
    }
    final deviationIds = _uniqueStrings(
      _requiredList(json, 'deviationIds', path),
      '$path.deviationIds',
    );
    if (!input.deviationIdAllowlist.containsAll(deviationIds)) {
      throw const FormatException(
        'style deviationIds must name admitted deviation references',
      );
    }
    final evidenceRefs = _uniqueStrings(
      _requiredList(json, 'evidenceRefs', path),
      '$path.evidenceRefs',
    );
    final findingIds = {for (final finding in findings) finding.findingId};
    if (!findingIds.containsAll(evidenceRefs)) {
      throw const FormatException('style evidenceRefs must name findings');
    }
    final authorizations = _parseAuthorizations(
      _requiredList(json, 'deviationAuthorizationRefs', path),
      '$path.deviationAuthorizationRefs',
      input,
    );
    final authorizedDeviationIds = {
      for (final value in authorizations) value.referenceId,
    };
    if (decision == StyleFitDecision.aligned &&
        (explanations.isNotEmpty ||
            deviationIds.isNotEmpty ||
            evidenceRefs.isNotEmpty ||
            authorizations.isNotEmpty)) {
      throw const FormatException('aligned styleFit must not claim deviations');
    }
    if (decision == StyleFitDecision.mismatch &&
        (deviationIds.isNotEmpty || authorizations.isNotEmpty)) {
      throw const FormatException('style mismatch cannot claim authorization');
    }
    if (decision == StyleFitDecision.plannedDeviation ||
        decision == StyleFitDecision.approvedDeviation) {
      final referencedEffectiveDeviations = findings
          .where(
            (finding) =>
                evidenceRefs.contains(finding.findingId) &&
                finding.findingClass == QualityFindingClass.effectiveDeviation,
          )
          .toList(growable: false);
      if (deviationIds.isEmpty ||
          evidenceRefs.isEmpty ||
          authorizations.isEmpty ||
          referencedEffectiveDeviations.isEmpty ||
          referencedEffectiveDeviations.length != evidenceRefs.length) {
        throw const FormatException(
          'authorized style deviation requires cross-bound ids, authority, '
          'and exclusively effectiveDeviation findings',
        );
      }
      bool authorityMatchesDecision(DeviationAuthorization value) =>
          decision == StyleFitDecision.plannedDeviation
          ? value == DeviationAuthorization.sceneContract
          : value == DeviationAuthorization.independentReview ||
                value == DeviationAuthorization.authorOverride;
      final findingAuthorizations = [
        for (final finding in referencedEffectiveDeviations)
          ...finding.deviationAuthorizationRefs,
      ];
      if (authorizations.any(
            (value) => !authorityMatchesDecision(value.authorizedBy),
          ) ||
          findingAuthorizations.any(
            (value) => !authorityMatchesDecision(value.authorizedBy),
          )) {
        throw const FormatException(
          'style decision does not match its authorization class',
        );
      }
      final styleAuthorizationKeys = {
        for (final value in authorizations) _authorizationKey(value),
      };
      final findingAuthorizationKeys = {
        for (final value in findingAuthorizations) _authorizationKey(value),
      };
      if (styleAuthorizationKeys.length != findingAuthorizationKeys.length ||
          !styleAuthorizationKeys.containsAll(findingAuthorizationKeys)) {
        throw const FormatException(
          'style and effectiveDeviation authorizations must match exactly',
        );
      }
      if (authorizedDeviationIds.length != deviationIds.length ||
          !authorizedDeviationIds.containsAll(deviationIds)) {
        throw const FormatException(
          'style deviationIds must match typed authorization references',
        );
      }
    }
    return StyleFitResult(
      decision: decision,
      axisExplanations: explanations,
      deviationIds: deviationIds,
      evidenceRefs: evidenceRefs,
      deviationAuthorizationRefs: authorizations,
    );
  }

  SemanticHardReviewResult _parseSemanticHardReview(
    Map<String, Object?> json,
    List<QualityFinding> findings,
    SceneLiteraryQualityCalibration calibration,
  ) {
    const path = r'$.semanticHardReview';
    _expectExactKeys(json, path, const {'passed', 'hardFindingIds'});
    final passed = _requiredBool(json, 'passed', path);
    final hardFindingIds = _uniqueStrings(
      _requiredList(json, 'hardFindingIds', path),
      '$path.hardFindingIds',
    );
    final actualHardFindingIds = {
      for (final finding in findings)
        if (finding.findingClass == QualityFindingClass.hardError)
          finding.findingId,
    };
    if (passed != actualHardFindingIds.isEmpty ||
        hardFindingIds.toSet().length != actualHardFindingIds.length ||
        !hardFindingIds.toSet().containsAll(actualHardFindingIds)) {
      throw const FormatException(
        'semanticHardReview contradicts hardError findings',
      );
    }
    return SemanticHardReviewResult(
      passed: passed,
      hardFindingIds: hardFindingIds,
      calibratedConfidence: actualHardFindingIds.isEmpty
          ? calibration.overallConfidence
          : calibration.confidenceFor(QualityFindingClass.hardError),
    );
  }

  ReaderEffectProbeResult _parseReaderEffect(
    Map<String, Object?> json,
    Set<String> findingIds,
    double calibratedConfidence,
    String providerModel,
    String promptReleaseHash,
  ) {
    const path = r'$.readerEffect';
    _expectExactKeys(json, path, const {'effectEstimates', 'warnings'});
    final rawEstimates = _requiredObject(json, 'effectEstimates', path);
    _expectExactKeys(rawEstimates, '$path.effectEstimates', const {
      'tension',
      'clarity',
      'curiosity',
      'emotionalImpact',
      'momentum',
    });
    final estimates = <String, ReaderEstimate<double>>{};
    for (final entry in rawEstimates.entries) {
      final estimatePath = '$path.effectEstimates.${entry.key}';
      final estimate = _asObject(entry.value, estimatePath);
      _expectExactKeys(estimate, estimatePath, const {'value', 'evidenceRefs'});
      final value = _requiredDouble(estimate, 'value', estimatePath);
      if (value < 0 || value > 100) {
        throw FormatException('$estimatePath.value must be 0..100');
      }
      final evidenceRefs = _uniqueStrings(
        _requiredList(estimate, 'evidenceRefs', estimatePath),
        '$estimatePath.evidenceRefs',
      );
      if (!findingIds.containsAll(evidenceRefs)) {
        throw FormatException('$estimatePath contains an unknown evidenceRef');
      }
      estimates[entry.key] = ReaderEstimate<double>(
        value: value,
        source: ReaderEstimateSource.modelProxy,
        method: 'literary-evaluator:$providerModel:$promptReleaseHash',
        sampleSize: 1,
        calibratedConfidence: calibratedConfidence,
        evidenceRefs: evidenceRefs,
      );
    }
    return ReaderEffectProbeResult(
      effectEstimates: estimates,
      warnings: _uniqueStrings(
        _requiredList(json, 'warnings', path),
        '$path.warnings',
      ),
    );
  }

  List<DeviationAuthorizationRef> _parseAuthorizations(
    List<Object?> values,
    String parentPath,
    SceneLiteraryQualityEvaluationInput input,
  ) {
    final trusted = {
      for (final value in input.deviationAuthorizationAllowlist)
        _authorizationKey(value),
    };
    final seen = <String>{};
    final result = <DeviationAuthorizationRef>[];
    for (var index = 0; index < values.length; index += 1) {
      final path = '$parentPath[$index]';
      final json = _asObject(values[index], path);
      _expectExactKeys(json, path, const {'authorizedBy', 'referenceId'});
      final value = DeviationAuthorizationRef(
        authorizedBy: _enumValue(
          _requiredString(json, 'authorizedBy', path),
          DeviationAuthorization.values,
          (authorization) => authorization.wire,
          '$path.authorizedBy',
        ),
        referenceId: _requiredString(json, 'referenceId', path),
      );
      final key = _authorizationKey(value);
      if (!seen.add(key)) {
        throw FormatException('$path duplicates an authorization');
      }
      if (!trusted.contains(key)) {
        throw FormatException('$path is not a trusted authorization');
      }
      result.add(value);
    }
    return List.unmodifiable(result);
  }

  void _validateFindingConsistency({
    required CraftScore craft,
    required List<QualityFinding> findings,
    required StyleFitResult styleFit,
  }) {
    final lowCraft = craft.craftOverall < 85 || craft.criticalCraftMinimum < 80;
    final craftWeaknesses = findings.where(
      (finding) => finding.findingClass == QualityFindingClass.craftWeakness,
    );
    final hasActionableCraftFinding = findings.any(
      (finding) =>
          finding.findingClass == QualityFindingClass.craftWeakness &&
          finding.severity != QualitySeverity.note &&
          finding.evidence.isNotEmpty &&
          (finding.suggestedAction == RepairAction.targetedRepair ||
              finding.suggestedAction == RepairAction.alignVoice ||
              finding.suggestedAction == RepairAction.blockAndReplan),
    );
    if (lowCraft && !hasActionableCraftFinding) {
      throw const FormatException(
        'low craft score requires an evidence-backed actionable finding',
      );
    }
    if (craft.craftOverall >= 93 &&
        (craft.criticalCraftMinimum < 93 || craftWeaknesses.isNotEmpty)) {
      throw const FormatException(
        'near-final craft score conflicts with a sub-93 dimension or '
        'craftWeakness finding',
      );
    }
    if (styleFit.decision == StyleFitDecision.mismatch &&
        !findings.any(
          (finding) =>
              finding.findingClass == QualityFindingClass.craftWeakness,
        )) {
      throw const FormatException(
        'style mismatch requires a craftWeakness finding',
      );
    }
  }
}

/// Additive shadow evaluator. It is not wired into the legacy 95/90 gate.
final class SceneLiteraryQualityEvaluator {
  SceneLiteraryQualityEvaluator({
    required this.settingsStore,
    StoryPromptRegistry? promptRegistry,
    this.parser = const SceneLiteraryQualityOutputParser(),
  }) : promptRegistry =
           promptRegistry ?? StoryPromptRegistry.literaryEvaluation();

  final StoryGenerationSettingsContract settingsStore;
  final StoryPromptRegistry promptRegistry;
  final SceneLiteraryQualityOutputParser parser;

  StoryPromptInvocation get promptInvocation => promptRegistry.invocation(
    stageId: 'literary-quality',
    callSiteId: 'scene-evaluator',
  );

  Future<LayeredQualityResult> evaluate(
    SceneLiteraryQualityEvaluationInput input,
  ) async {
    final promptIdentity = promptInvocation;
    input.calibration.validateAuthority(
      rubricVersion: input.rubricVersion,
      promptReleaseHash: promptIdentity.release.contentHash,
    );
    final variables = <String, Object?>{
      'evaluationInputJson': AppLlmCanonicalHash.canonicalJson(
        input.promptInputJson,
      ),
    };
    final messages = promptIdentity.render(variables).messages;
    final evaluationTrace = AgentEvaluationTraceContext.current;
    final evaluationBundleHash =
        evaluationTrace?.evaluationBundleHash ??
        AppLlmCanonicalHash.domainHash(
          'scene-literary-evaluation-bundle-v1',
          <String, Object?>{
            'promptReleaseHash': promptIdentity.release.contentHash,
            'rubricVersion': input.rubricVersion,
            'evaluatorCertificationHash':
                input.calibration.certification.certificationHash,
            'thresholdPolicyVersion':
                LiteraryQualityPolicy.thresholdPolicyVersion,
          },
        );
    final rubricHash = AppLlmCanonicalHash.domainHash(
      'scene-literary-rubric-v1',
      <String, Object?>{
        'rubricVersion': input.rubricVersion,
        'evaluatorCertificationHash':
            input.calibration.certification.certificationHash,
        'thresholdPolicyVersion': LiteraryQualityPolicy.thresholdPolicyVersion,
      },
    );
    final result = await requestFormalStoryGenerationPassWithRetry(
      settingsStore: settingsStore,
      messages: messages,
      initialMaxTokens: literaryQualityEvaluationMaxTokens,
      maxEscalatedTokens: literaryQualityEvaluationMaxTokens,
      maxTransientRetries: _literaryQualityMaxTransientRetries,
      maxOutputRetries: _literaryQualityMaxOutputRetries,
      evaluationFingerprintSeed: StoryGenerationEvaluationFingerprintSeed(
        artifactDigest: ArtifactDigest.fromUtf8String(input.prose),
        evaluationBundleHash: evaluationBundleHash,
        judgeInput: <String, Object?>{
          'evaluationInputDigest': AppLlmCanonicalHash.domainHash(
            'scene-literary-evaluation-input-v1',
            input.promptInputJson,
          ),
        },
        rubricHash: rubricHash,
        blindingPolicy: evaluationTrace == null
            ? 'shadow-evaluator-not-blinded-v1'
            : 'formal-evaluation-context-v1',
      ),
      shouldRetryOutput: (text) {
        try {
          parser.parse(
            rawOutput: text,
            input: input,
            promptReleaseHash: promptIdentity.release.contentHash,
            providerModel:
                input.calibration.certification.evaluatorModelRelease,
          );
          return false;
        } catch (_) {
          return true;
        }
      },
      traceName: 'scene_literary_quality_evaluation',
      traceMetadata: {
        'shadowOnly': true,
        'proseHash': input.proseHash,
        'rubricVersion': input.rubricVersion,
        'evaluatorCertificationHash':
            input.calibration.certification.certificationHash,
      },
      promptInvocation: promptIdentity,
      promptInvocationEvidence: promptIdentity.evidence(
        messages,
        resolvedVariables: variables,
      ),
    );
    if (!result.succeeded) {
      throw SceneLiteraryQualityEvaluationException(
        'provider_failure',
        '${result.failureKind}: ${result.detail ?? 'no detail'}',
      );
    }
    final providerModel = result.providerModel?.trim();
    if (providerModel == null || providerModel.isEmpty) {
      throw const SceneLiteraryQualityEvaluationException(
        'missing_provider_model',
        'provider response did not bind the actual evaluator model',
      );
    }
    return parser.parse(
      rawOutput: result.text!,
      input: input,
      promptReleaseHash: promptIdentity.release.contentHash,
      providerModel: providerModel,
    );
  }
}

bool _isUtf16Boundary(String value, int offset) {
  if (offset <= 0 || offset >= value.length) return true;
  final previous = value.codeUnitAt(offset - 1);
  final current = value.codeUnitAt(offset);
  return !(previous >= 0xd800 &&
      previous <= 0xdbff &&
      current >= 0xdc00 &&
      current <= 0xdfff);
}

List<Map<String, Object?>> _evidenceSegments(String prose) {
  final segments = <Map<String, Object?>>[];
  var start = 0;
  for (var offset = 0; offset < prose.length; offset += 1) {
    final unit = prose.codeUnitAt(offset);
    final closesSentence =
        unit == 0x3002 || unit == 0xff01 || unit == 0xff1f || unit == 0x0a;
    final reachesLimit = offset + 1 - start >= 200;
    if (!closesSentence && !reachesLimit) continue;
    var end = offset + 1;
    if (!_isUtf16Boundary(prose, end)) {
      end += 1;
      offset += 1;
    }
    _appendEvidenceSegment(segments, prose, start, end);
    start = end;
  }
  _appendEvidenceSegment(segments, prose, start, prose.length);
  return List.unmodifiable(segments);
}

void _appendEvidenceSegment(
  List<Map<String, Object?>> segments,
  String prose,
  int rawStart,
  int rawEnd,
) {
  var start = rawStart;
  var end = rawEnd;
  while (start < end && _isJsonWhitespace(prose.codeUnitAt(start))) {
    start += 1;
  }
  while (end > start && _isJsonWhitespace(prose.codeUnitAt(end - 1))) {
    end -= 1;
  }
  if (start == end) return;
  segments.add({
    'startOffset': start,
    'endOffset': end,
    'localExcerpt': prose.substring(start, end),
  });
}

bool _isJsonWhitespace(int unit) =>
    unit == 0x20 || unit == 0x0a || unit == 0x0d || unit == 0x09;

String _authorizationKey(DeviationAuthorizationRef value) =>
    '${value.authorizedBy.wire}\u0000${value.referenceId}';

double _minimum(Iterable<num> values) {
  var minimum = double.infinity;
  for (final value in values) {
    if (value < minimum) minimum = value.toDouble();
  }
  return minimum;
}

void _requireUnitInterval(double value, String field) {
  if (!value.isFinite || value < 0 || value > 1) {
    throw ArgumentError('$field must be between 0 and 1');
  }
}

Map<String, Object?> _asObject(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object');
  return value.map((key, item) {
    if (key is! String) throw FormatException('$path keys must be strings');
    return MapEntry(key, item);
  });
}

Map<String, Object?> _requiredObject(
  Map<String, Object?> json,
  String key,
  String path,
) => _asObject(json[key], '$path.$key');

List<Object?> _requiredList(
  Map<String, Object?> json,
  String key,
  String path,
) {
  final value = json[key];
  if (value is! List) throw FormatException('$path.$key must be an array');
  return value;
}

String _requiredString(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path.$key must be a non-empty string');
  }
  return value;
}

String? _nullableString(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path.$key must be null or a non-empty string');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! int) throw FormatException('$path.$key must be an integer');
  return value;
}

double _requiredDouble(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw FormatException('$path.$key must be a finite number');
  }
  return value.toDouble();
}

bool _requiredBool(Map<String, Object?> json, String key, String path) {
  final value = json[key];
  if (value is! bool) throw FormatException('$path.$key must be a boolean');
  return value;
}

List<String> _uniqueStrings(List<Object?> values, String path) {
  final result = <String>[];
  final seen = <String>{};
  for (var index = 0; index < values.length; index += 1) {
    final value = values[index];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$path[$index] must be a non-empty string');
    }
    if (!seen.add(value)) {
      throw FormatException('$path contains a duplicate string');
    }
    result.add(value);
  }
  return List.unmodifiable(result);
}

T _enumValue<T>(
  String wire,
  Iterable<T> values,
  String Function(T value) toWire,
  String path,
) {
  for (final value in values) {
    if (toWire(value) == wire) return value;
  }
  throw FormatException('$path has unknown value: $wire');
}

void _expectExactKeys(
  Map<String, Object?> json,
  String path,
  Set<String> expected,
) {
  final actual = json.keys.toSet();
  final missing = expected.difference(actual).toList()..sort();
  final unknown = actual.difference(expected).toList()..sort();
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException(
      '$path schema mismatch; missing=${missing.join(',')}; '
      'unknown=${unknown.join(',')}',
    );
  }
}

/// Detects duplicate object keys before [jsonDecode] can overwrite them.
final class _DuplicateJsonKeyScanner {
  _DuplicateJsonKeyScanner(this.source);

  final String source;
  int _index = 0;

  void scan() {
    _skipWhitespace();
    _scanValue(r'$');
    _skipWhitespace();
    if (_index != source.length) {
      throw FormatException('trailing content after JSON at $_index');
    }
  }

  void _scanValue(String path) {
    if (_index >= source.length) {
      throw FormatException('unexpected end of JSON at $path');
    }
    switch (source.codeUnitAt(_index)) {
      case 0x7b:
        _scanObject(path);
      case 0x5b:
        _scanArray(path);
      case 0x22:
        _scanString();
      case 0x74:
        _scanLiteral('true');
      case 0x66:
        _scanLiteral('false');
      case 0x6e:
        _scanLiteral('null');
      default:
        _scanNumber();
    }
  }

  void _scanObject(String path) {
    _expectCodeUnit(0x7b);
    _skipWhitespace();
    if (_consumeCodeUnit(0x7d)) return;
    final keys = <String>{};
    var memberIndex = 0;
    while (true) {
      if (_index >= source.length || source.codeUnitAt(_index) != 0x22) {
        throw FormatException('object key expected at $path');
      }
      final key = AppLlmCanonicalHash.normalizeNfc(_scanString());
      if (!keys.add(key)) {
        throw FormatException('duplicate JSON key at $path: $key');
      }
      _skipWhitespace();
      _expectCodeUnit(0x3a);
      _skipWhitespace();
      _scanValue('$path.$key#$memberIndex');
      memberIndex += 1;
      _skipWhitespace();
      if (_consumeCodeUnit(0x7d)) return;
      _expectCodeUnit(0x2c);
      _skipWhitespace();
    }
  }

  void _scanArray(String path) {
    _expectCodeUnit(0x5b);
    _skipWhitespace();
    if (_consumeCodeUnit(0x5d)) return;
    var index = 0;
    while (true) {
      _scanValue('$path[$index]');
      index += 1;
      _skipWhitespace();
      if (_consumeCodeUnit(0x5d)) return;
      _expectCodeUnit(0x2c);
      _skipWhitespace();
    }
  }

  String _scanString() {
    final start = _index;
    _expectCodeUnit(0x22);
    var escaped = false;
    while (_index < source.length) {
      final unit = source.codeUnitAt(_index);
      _index += 1;
      if (escaped) {
        escaped = false;
        continue;
      }
      if (unit == 0x5c) {
        escaped = true;
        continue;
      }
      if (unit == 0x22) {
        final raw = source.substring(start, _index);
        final decoded = jsonDecode(raw);
        if (decoded is! String) {
          throw const FormatException('JSON string did not decode to string');
        }
        return decoded;
      }
    }
    throw const FormatException('unterminated JSON string');
  }

  void _scanLiteral(String literal) {
    if (!source.startsWith(literal, _index)) {
      throw FormatException('invalid JSON literal at $_index');
    }
    _index += literal.length;
  }

  void _scanNumber() {
    final start = _index;
    while (_index < source.length) {
      final unit = source.codeUnitAt(_index);
      final isNumberUnit =
          (unit >= 0x30 && unit <= 0x39) ||
          unit == 0x2d ||
          unit == 0x2b ||
          unit == 0x2e ||
          unit == 0x65 ||
          unit == 0x45;
      if (!isNumberUnit) break;
      _index += 1;
    }
    if (_index == start) {
      throw FormatException('JSON value expected at $_index');
    }
    final raw = source.substring(start, _index);
    final decoded = jsonDecode(raw);
    if (decoded is! num) {
      throw FormatException('invalid JSON number at $start');
    }
  }

  void _skipWhitespace() {
    while (_index < source.length) {
      final unit = source.codeUnitAt(_index);
      if (unit != 0x20 && unit != 0x0a && unit != 0x0d && unit != 0x09) {
        return;
      }
      _index += 1;
    }
  }

  bool _consumeCodeUnit(int expected) {
    if (_index < source.length && source.codeUnitAt(_index) == expected) {
      _index += 1;
      return true;
    }
    return false;
  }

  void _expectCodeUnit(int expected) {
    if (!_consumeCodeUnit(expected)) {
      throw FormatException(
        'expected ${String.fromCharCode(expected)} at $_index',
      );
    }
  }
}
