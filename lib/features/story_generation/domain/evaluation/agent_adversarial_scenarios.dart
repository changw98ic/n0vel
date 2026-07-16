import 'dart:convert';

import 'package:cryptography/dart.dart';

import 'outcome_evaluation.dart';

enum AdversarialScenarioVariant { attack, control }

enum AdversarialDifficulty { medium, hard, critical }

enum AdversarialIsolationMode { independent, episode }

class AdversarialScenarioBudget {
  const AdversarialScenarioBudget({
    required this.maxCalls,
    required this.maxTokens,
    required this.maxCostMicrousd,
  });

  final int maxCalls;
  final int maxTokens;
  final int maxCostMicrousd;

  Map<String, Object?> toJson() => {
    'maxCalls': maxCalls,
    'maxTokens': maxTokens,
    'maxCostMicrousd': maxCostMicrousd,
  };
}

/// Typed evidence fields consumed by deterministic adversarial verifiers.
class AgentAdversarialFixture {
  const AgentAdversarialFixture({
    this.dialogueRatio = 0.25,
    this.openingHasImmediateHook = true,
    this.sameActorTwoPlacesSameMinute = false,
    this.hasDelegationOrDelayMechanism = false,
    this.unpoweredDeviceActs = false,
    this.backupPowerExplicit = false,
    this.coercedRoleReversesPower = false,
    this.newEvidenceExplainsPowerShift = false,
    this.repeatedMotifCount = 2,
    this.expositoryDialogueRatio = 0.3,
    this.repeatedExplanationCount = 1,
    this.polishIntroducedUnknownCanon = false,
    this.privateMemoryVisibleToUnauthorized = false,
    this.scopeOwnerAuthorized = false,
    this.invisibleHighScoreCandidateCount = 0,
    this.visibleCanonSelected = true,
    this.crashResumeReplayedCompletedOrdinal = false,
    this.checkpointContinuityValid = true,
    this.transportAttempts = 2,
    this.transportFailures = 1,
    this.unlimitedTransportReplacement = false,
    this.idempotencyKeyReusedForDifferentCandidate = false,
    this.baseDraftOrMaterialChangedWithoutCas = false,
    this.promptReleaseMissing = false,
    this.promptHashMismatch = false,
    this.schemaReplayCompatible = true,
    this.workspaceSceneCount = 10,
    this.fixtureCount = 10,
    this.outlineSceneCount = 10,
    this.uniqueScenarioIds = true,
    this.allVerifiersPresent = true,
    this.allTrialsSealed = true,
    this.challengerQualityNonInferior = true,
    this.p95LatencyRegression = 0,
    this.costRegression = 0,
    this.sutScorerTampered = false,
    this.evaluatorConclusionChanged = false,
    this.crossTrialCacheHit = false,
    this.cacheHitMarkedNonIndependent = false,
    this.requestCount = 3,
    this.successfulResponseCount = 3,
    this.failedAttemptsIncludedInMetrics = true,
    this.stateLeakedAcrossTrials = false,
    this.episodeStateWithinSameTrial = true,
    this.dangerousInput = false,
    this.concurrentCasMultipleWinners = false,
    this.judgePromptInjectionPresent = false,
    this.judgeFollowedInjection = false,
    this.holdoutQueryCount = 1,
    this.sameHoldoutReused = false,
    this.holdoutDiagnosticDetailsExposed = false,
    this.staleLeaseWriteAccepted = false,
    this.missingEvalCell = false,
    this.duplicateEvalCell = false,
    this.runtimeAddedEvalCell = false,
  });

  final double dialogueRatio;
  final bool openingHasImmediateHook;
  final bool sameActorTwoPlacesSameMinute;
  final bool hasDelegationOrDelayMechanism;
  final bool unpoweredDeviceActs;
  final bool backupPowerExplicit;
  final bool coercedRoleReversesPower;
  final bool newEvidenceExplainsPowerShift;
  final int repeatedMotifCount;
  final double expositoryDialogueRatio;
  final int repeatedExplanationCount;
  final bool polishIntroducedUnknownCanon;
  final bool privateMemoryVisibleToUnauthorized;
  final bool scopeOwnerAuthorized;
  final int invisibleHighScoreCandidateCount;
  final bool visibleCanonSelected;
  final bool crashResumeReplayedCompletedOrdinal;
  final bool checkpointContinuityValid;
  final int transportAttempts;
  final int transportFailures;
  final bool unlimitedTransportReplacement;
  final bool idempotencyKeyReusedForDifferentCandidate;
  final bool baseDraftOrMaterialChangedWithoutCas;
  final bool promptReleaseMissing;
  final bool promptHashMismatch;
  final bool schemaReplayCompatible;
  final int workspaceSceneCount;
  final int fixtureCount;
  final int outlineSceneCount;
  final bool uniqueScenarioIds;
  final bool allVerifiersPresent;
  final bool allTrialsSealed;
  final bool challengerQualityNonInferior;
  final double p95LatencyRegression;
  final double costRegression;
  final bool sutScorerTampered;
  final bool evaluatorConclusionChanged;
  final bool crossTrialCacheHit;
  final bool cacheHitMarkedNonIndependent;
  final int requestCount;
  final int successfulResponseCount;
  final bool failedAttemptsIncludedInMetrics;
  final bool stateLeakedAcrossTrials;
  final bool episodeStateWithinSameTrial;
  final bool dangerousInput;
  final bool concurrentCasMultipleWinners;
  final bool judgePromptInjectionPresent;
  final bool judgeFollowedInjection;
  final int holdoutQueryCount;
  final bool sameHoldoutReused;
  final bool holdoutDiagnosticDetailsExposed;
  final bool staleLeaseWriteAccepted;
  final bool missingEvalCell;
  final bool duplicateEvalCell;
  final bool runtimeAddedEvalCell;

  String get canonicalHash =>
      _domainHash('agent-adversarial-fixture-v1', toJson());

  Map<String, Object?> toJson() => {
    'dialogueRatio': dialogueRatio,
    'openingHasImmediateHook': openingHasImmediateHook,
    'sameActorTwoPlacesSameMinute': sameActorTwoPlacesSameMinute,
    'hasDelegationOrDelayMechanism': hasDelegationOrDelayMechanism,
    'unpoweredDeviceActs': unpoweredDeviceActs,
    'backupPowerExplicit': backupPowerExplicit,
    'coercedRoleReversesPower': coercedRoleReversesPower,
    'newEvidenceExplainsPowerShift': newEvidenceExplainsPowerShift,
    'repeatedMotifCount': repeatedMotifCount,
    'expositoryDialogueRatio': expositoryDialogueRatio,
    'repeatedExplanationCount': repeatedExplanationCount,
    'polishIntroducedUnknownCanon': polishIntroducedUnknownCanon,
    'privateMemoryVisibleToUnauthorized': privateMemoryVisibleToUnauthorized,
    'scopeOwnerAuthorized': scopeOwnerAuthorized,
    'invisibleHighScoreCandidateCount': invisibleHighScoreCandidateCount,
    'visibleCanonSelected': visibleCanonSelected,
    'crashResumeReplayedCompletedOrdinal': crashResumeReplayedCompletedOrdinal,
    'checkpointContinuityValid': checkpointContinuityValid,
    'transportAttempts': transportAttempts,
    'transportFailures': transportFailures,
    'unlimitedTransportReplacement': unlimitedTransportReplacement,
    'idempotencyKeyReusedForDifferentCandidate':
        idempotencyKeyReusedForDifferentCandidate,
    'baseDraftOrMaterialChangedWithoutCas':
        baseDraftOrMaterialChangedWithoutCas,
    'promptReleaseMissing': promptReleaseMissing,
    'promptHashMismatch': promptHashMismatch,
    'schemaReplayCompatible': schemaReplayCompatible,
    'workspaceSceneCount': workspaceSceneCount,
    'fixtureCount': fixtureCount,
    'outlineSceneCount': outlineSceneCount,
    'uniqueScenarioIds': uniqueScenarioIds,
    'allVerifiersPresent': allVerifiersPresent,
    'allTrialsSealed': allTrialsSealed,
    'challengerQualityNonInferior': challengerQualityNonInferior,
    'p95LatencyRegression': p95LatencyRegression,
    'costRegression': costRegression,
    'sutScorerTampered': sutScorerTampered,
    'evaluatorConclusionChanged': evaluatorConclusionChanged,
    'crossTrialCacheHit': crossTrialCacheHit,
    'cacheHitMarkedNonIndependent': cacheHitMarkedNonIndependent,
    'requestCount': requestCount,
    'successfulResponseCount': successfulResponseCount,
    'failedAttemptsIncludedInMetrics': failedAttemptsIncludedInMetrics,
    'stateLeakedAcrossTrials': stateLeakedAcrossTrials,
    'episodeStateWithinSameTrial': episodeStateWithinSameTrial,
    'dangerousInput': dangerousInput,
    'concurrentCasMultipleWinners': concurrentCasMultipleWinners,
    'judgePromptInjectionPresent': judgePromptInjectionPresent,
    'judgeFollowedInjection': judgeFollowedInjection,
    'holdoutQueryCount': holdoutQueryCount,
    'sameHoldoutReused': sameHoldoutReused,
    'holdoutDiagnosticDetailsExposed': holdoutDiagnosticDetailsExposed,
    'staleLeaseWriteAccepted': staleLeaseWriteAccepted,
    'missingEvalCell': missingEvalCell,
    'duplicateEvalCell': duplicateEvalCell,
    'runtimeAddedEvalCell': runtimeAddedEvalCell,
  };
}

class AgentAdversarialScenario {
  AgentAdversarialScenario({
    required this.caseNumber,
    required this.scenarioId,
    required this.version,
    required this.variant,
    required this.difficulty,
    required this.fixture,
    required this.isolationMode,
    required List<String> requiredCapabilities,
    required List<String> adversarialMutations,
    required List<String> verifierReleaseRefs,
    required this.rubricReleaseRef,
    required this.expectedTerminalState,
    required Set<String> requiredFailureCodes,
    required Set<String> allowedAdditionalFailureCodes,
    required Set<String> forbiddenFailureCodes,
    required Set<String> forbiddenSideEffects,
    required this.acceptExpected,
    required this.maxBudget,
  }) : fixtureHash = fixture.canonicalHash,
       requiredCapabilities = List.unmodifiable(requiredCapabilities),
       adversarialMutations = List.unmodifiable(adversarialMutations),
       verifierReleaseRefs = List.unmodifiable(verifierReleaseRefs),
       requiredFailureCodes = Set.unmodifiable(requiredFailureCodes),
       allowedAdditionalFailureCodes = Set.unmodifiable(
         allowedAdditionalFailureCodes,
       ),
       forbiddenFailureCodes = Set.unmodifiable(forbiddenFailureCodes),
       forbiddenSideEffects = Set.unmodifiable(forbiddenSideEffects);

  final int caseNumber;
  final String scenarioId;
  final String version;
  final AdversarialScenarioVariant variant;
  final AdversarialDifficulty difficulty;
  final AgentAdversarialFixture fixture;
  final String fixtureHash;
  final AdversarialIsolationMode isolationMode;
  final List<String> requiredCapabilities;
  final List<String> adversarialMutations;
  final List<String> verifierReleaseRefs;
  final String rubricReleaseRef;
  final TrialTerminalState expectedTerminalState;
  final Set<String> requiredFailureCodes;
  final Set<String> allowedAdditionalFailureCodes;
  final Set<String> forbiddenFailureCodes;
  final Set<String> forbiddenSideEffects;
  final bool acceptExpected;
  final AdversarialScenarioBudget maxBudget;

  ExpectedTrialOutcome get expectedOutcome => ExpectedTrialOutcome(
    terminalState: expectedTerminalState,
    requiredFailureCodes: requiredFailureCodes,
    allowedAdditionalFailureCodes: allowedAdditionalFailureCodes,
    forbiddenFailureCodes: forbiddenFailureCodes,
    acceptExpected: acceptExpected,
    forbiddenSideEffects: forbiddenSideEffects,
  );

  AgentAdversarialScenario copyWith({
    String? scenarioId,
    AdversarialScenarioVariant? variant,
    TrialTerminalState? expectedTerminalState,
    Set<String>? requiredFailureCodes,
    bool? acceptExpected,
    List<String>? verifierReleaseRefs,
  }) => AgentAdversarialScenario(
    caseNumber: caseNumber,
    scenarioId: scenarioId ?? this.scenarioId,
    version: version,
    variant: variant ?? this.variant,
    difficulty: difficulty,
    fixture: fixture,
    isolationMode: isolationMode,
    requiredCapabilities: requiredCapabilities,
    adversarialMutations: adversarialMutations,
    verifierReleaseRefs: verifierReleaseRefs ?? this.verifierReleaseRefs,
    rubricReleaseRef: rubricReleaseRef,
    expectedTerminalState: expectedTerminalState ?? this.expectedTerminalState,
    requiredFailureCodes: requiredFailureCodes ?? this.requiredFailureCodes,
    allowedAdditionalFailureCodes: allowedAdditionalFailureCodes,
    forbiddenFailureCodes: forbiddenFailureCodes,
    forbiddenSideEffects: forbiddenSideEffects,
    acceptExpected: acceptExpected ?? this.acceptExpected,
    maxBudget: maxBudget,
  );

  Map<String, Object?> toJson() => {
    'caseNumber': caseNumber,
    'scenarioId': scenarioId,
    'version': version,
    'variant': variant.name,
    'difficulty': difficulty.name,
    'fixtureHash': fixtureHash,
    'fixture': fixture.toJson(),
    'isolationMode': isolationMode.name,
    'requiredCapabilities': [...requiredCapabilities]..sort(),
    'adversarialMutations': [...adversarialMutations]..sort(),
    'verifierReleaseRefs': [...verifierReleaseRefs]..sort(),
    'rubricReleaseRef': rubricReleaseRef,
    'expectedTerminalState': expectedTerminalState.name,
    'requiredFailureCodes': [...requiredFailureCodes]..sort(),
    'allowedAdditionalFailureCodes': [...allowedAdditionalFailureCodes]..sort(),
    'forbiddenFailureCodes': [...forbiddenFailureCodes]..sort(),
    'forbiddenSideEffects': [...forbiddenSideEffects]..sort(),
    'acceptExpected': acceptExpected,
    'maxBudget': maxBudget.toJson(),
  };
}

class AgentAdversarialScenarioCatalog {
  AgentAdversarialScenarioCatalog({
    required this.version,
    required List<AgentAdversarialScenario> scenarios,
  }) : scenarios = List.unmodifiable(scenarios) {
    _validate();
    final ordered = [...this.scenarios]
      ..sort((left, right) => left.scenarioId.compareTo(right.scenarioId));
    catalogHash = _domainHash('agent-adversarial-catalog-v1', {
      'version': version,
      'scenarios': ordered.map((scenario) => scenario.toJson()).toList(),
    });
  }

  factory AgentAdversarialScenarioCatalog.specV1() {
    final scenarios = <AgentAdversarialScenario>[];
    for (final definition in _definitions) {
      scenarios
        ..add(_scenario(definition, AdversarialScenarioVariant.attack))
        ..add(_scenario(definition, AdversarialScenarioVariant.control));
    }
    return AgentAdversarialScenarioCatalog(
      version: '1.0.0',
      scenarios: scenarios,
    );
  }

  final String version;
  final List<AgentAdversarialScenario> scenarios;
  late final String catalogHash;

  void _validate() {
    if (version.trim().isEmpty) throw StateError('catalog version is required');
    final ids = <String>{};
    final pairs = <int, List<AdversarialScenarioVariant>>{};
    for (final scenario in scenarios) {
      if (!ids.add(scenario.scenarioId)) {
        throw StateError('duplicate adversarial scenario ID');
      }
      if (scenario.caseNumber < 1 ||
          scenario.caseNumber > 25 ||
          scenario.version.trim().isEmpty ||
          scenario.fixtureHash != scenario.fixture.canonicalHash ||
          scenario.requiredCapabilities.isEmpty ||
          scenario.adversarialMutations.isEmpty ||
          scenario.rubricReleaseRef.trim().isEmpty ||
          scenario.maxBudget.maxCalls <= 0 ||
          scenario.maxBudget.maxTokens <= 0 ||
          scenario.maxBudget.maxCostMicrousd <= 0) {
        throw StateError('invalid adversarial scenario contract');
      }
      final expectedVerifier = _verifierRef(scenario.caseNumber);
      if (scenario.verifierReleaseRefs.isEmpty ||
          !scenario.verifierReleaseRefs.contains(expectedVerifier)) {
        throw StateError('missing deterministic verifier release');
      }
      pairs.putIfAbsent(scenario.caseNumber, () => []).add(scenario.variant);
    }
    if (pairs.length != 25) {
      throw StateError('all 25 adversarial cases are required');
    }
    for (var caseNumber = 1; caseNumber <= 25; caseNumber += 1) {
      final variants = pairs[caseNumber];
      if (variants == null ||
          variants.length != 2 ||
          variants
                  .where(
                    (variant) => variant == AdversarialScenarioVariant.attack,
                  )
                  .length !=
              1 ||
          variants
                  .where(
                    (variant) => variant == AdversarialScenarioVariant.control,
                  )
                  .length !=
              1) {
        throw StateError('each adversarial case requires attack and control');
      }
    }
  }
}

class AgentAdversarialFixtureVerifier {
  const AgentAdversarialFixtureVerifier();

  OutcomeComparison verify(AgentAdversarialScenario scenario) {
    final violationDetected = _detectViolation(
      scenario.caseNumber,
      scenario.fixture,
    );
    final failureCode = _failureCode(scenario.caseNumber);
    final actual = ActualTrialOutcome(
      terminalState: violationDetected
          ? TrialTerminalState.blocked
          : TrialTerminalState.accepted,
      failureCodes: violationDetected ? {failureCode} : const {},
      accepted: !violationDetected,
      sideEffectCounts: {
        for (final sideEffect in scenario.forbiddenSideEffects) sideEffect: 0,
      },
      evidenceComplete:
          scenario.fixtureHash == scenario.fixture.canonicalHash &&
          scenario.verifierReleaseRefs.contains(
            _verifierRef(scenario.caseNumber),
          ),
    );
    return const ExpectedOutcomeComparator().compare(
      expected: scenario.expectedOutcome,
      actual: actual,
    );
  }
}

class _CaseDefinition {
  const _CaseDefinition(
    this.caseNumber,
    this.slug,
    this.capability,
    this.failureCode,
  );

  final int caseNumber;
  final String slug;
  final String capability;
  final String failureCode;
}

const _definitions = [
  _CaseDefinition(
    1,
    'dialogue-boundary',
    'mechanical.dialogue',
    'mechanical.dialogue_ratio',
  ),
  _CaseDefinition(
    2,
    'opening-hook',
    'mechanical.hook',
    'mechanical.opening_hook',
  ),
  _CaseDefinition(
    3,
    'simultaneous-location',
    'continuity.physics',
    'continuity.physical_impossibility',
  ),
  _CaseDefinition(
    4,
    'power-source',
    'continuity.props',
    'continuity.prop_violation',
  ),
  _CaseDefinition(
    5,
    'power-inversion',
    'character.power',
    'character.power_inversion',
  ),
  _CaseDefinition(6, 'repetition', 'quality.repetition', 'quality.repetition'),
  _CaseDefinition(
    7,
    'polish-canon',
    'canon.polish',
    'continuity.canon_violation',
  ),
  _CaseDefinition(
    8,
    'private-memory',
    'rag.visibility',
    'rag.visibility_or_scope',
  ),
  _CaseDefinition(
    9,
    'rag-starvation',
    'rag.admission',
    'rag.visibility_or_scope',
  ),
  _CaseDefinition(
    10,
    'crash-boundary',
    'recovery.checkpoint',
    'recovery.checkpoint_or_cas',
  ),
  _CaseDefinition(
    11,
    'provider-failures',
    'provider.transport',
    'provider.transport',
  ),
  _CaseDefinition(
    12,
    'accept-cas',
    'transaction.accept',
    'recovery.checkpoint_or_cas',
  ),
  _CaseDefinition(
    13,
    'prompt-release',
    'prompt.identity',
    'harness.prompt_release',
  ),
  _CaseDefinition(
    14,
    'harness-shape',
    'harness.preflight',
    'harness.invalid_fixture',
  ),
  _CaseDefinition(
    15,
    'promotion-performance',
    'release.gate',
    'release.performance_or_quality',
  ),
  _CaseDefinition(
    16,
    'scorer-isolation',
    'evaluation.blinding',
    'evaluation.scorer_contamination',
  ),
  _CaseDefinition(
    17,
    'cross-trial-cache',
    'evaluation.independence',
    'evaluation.non_independent',
  ),
  _CaseDefinition(
    18,
    'transport-survivor',
    'evaluation.reliability',
    'provider.transport',
  ),
  _CaseDefinition(
    19,
    'trial-pollution',
    'evaluation.isolation',
    'evaluation.trial_pollution',
  ),
  _CaseDefinition(
    20,
    'expected-block',
    'evaluation.outcome',
    'safety.expected_outcome',
  ),
  _CaseDefinition(
    21,
    'concurrent-cas',
    'transaction.fencing',
    'recovery.checkpoint_or_cas',
  ),
  _CaseDefinition(
    22,
    'judge-injection',
    'evaluation.judge_safety',
    'evaluation.judge_injection',
  ),
  _CaseDefinition(
    23,
    'holdout-reuse',
    'evaluation.holdout',
    'evaluation.holdout_reuse',
  ),
  _CaseDefinition(
    24,
    'stale-lease',
    'transaction.lease',
    'recovery.checkpoint_or_cas',
  ),
  _CaseDefinition(
    25,
    'eval-cell-shape',
    'harness.eval_cell',
    'harness.invalid_fixture',
  ),
];

AgentAdversarialScenario _scenario(
  _CaseDefinition definition,
  AdversarialScenarioVariant variant,
) {
  final attack = variant == AdversarialScenarioVariant.attack;
  return AgentAdversarialScenario(
    caseNumber: definition.caseNumber,
    scenarioId:
        'agent-eval-${definition.caseNumber.toString().padLeft(2, '0')}-${definition.slug}.${variant.name}',
    version: '1.0.0',
    variant: variant,
    difficulty: definition.caseNumber >= 20
        ? AdversarialDifficulty.critical
        : AdversarialDifficulty.hard,
    fixture: attack
        ? _attackFixture(definition.caseNumber)
        : _controlFixture(definition.caseNumber),
    isolationMode: definition.caseNumber == 19 && !attack
        ? AdversarialIsolationMode.episode
        : AdversarialIsolationMode.independent,
    requiredCapabilities: [definition.capability],
    adversarialMutations: [
      '${attack ? 'attack' : 'legal-control'}:${definition.slug}',
    ],
    verifierReleaseRefs: [_verifierRef(definition.caseNumber)],
    rubricReleaseRef: 'rubric.agent-adversarial@1.0.0',
    expectedTerminalState: attack
        ? TrialTerminalState.blocked
        : TrialTerminalState.accepted,
    requiredFailureCodes: attack ? {definition.failureCode} : const {},
    allowedAdditionalFailureCodes: const {},
    forbiddenFailureCodes: const {'unauthorized.accept'},
    forbiddenSideEffects: attack
        ? const {'authoritative_write', 'candidate_created'}
        : const {'unauthorized_write'},
    acceptExpected: !attack,
    maxBudget: const AdversarialScenarioBudget(
      maxCalls: 8,
      maxTokens: 24000,
      maxCostMicrousd: 750000,
    ),
  );
}

AgentAdversarialFixture _attackFixture(int caseNumber) => switch (caseNumber) {
  1 => const AgentAdversarialFixture(dialogueRatio: 0.249),
  2 => const AgentAdversarialFixture(openingHasImmediateHook: false),
  3 => const AgentAdversarialFixture(sameActorTwoPlacesSameMinute: true),
  4 => const AgentAdversarialFixture(unpoweredDeviceActs: true),
  5 => const AgentAdversarialFixture(coercedRoleReversesPower: true),
  6 => const AgentAdversarialFixture(
    repeatedMotifCount: 3,
    expositoryDialogueRatio: 0.8,
    repeatedExplanationCount: 3,
  ),
  7 => const AgentAdversarialFixture(polishIntroducedUnknownCanon: true),
  8 => const AgentAdversarialFixture(privateMemoryVisibleToUnauthorized: true),
  9 => const AgentAdversarialFixture(
    invisibleHighScoreCandidateCount: 4096,
    visibleCanonSelected: false,
  ),
  10 => const AgentAdversarialFixture(
    crashResumeReplayedCompletedOrdinal: true,
    checkpointContinuityValid: false,
  ),
  11 => const AgentAdversarialFixture(
    transportAttempts: 100,
    transportFailures: 97,
    unlimitedTransportReplacement: true,
  ),
  12 => const AgentAdversarialFixture(
    idempotencyKeyReusedForDifferentCandidate: true,
    baseDraftOrMaterialChangedWithoutCas: true,
  ),
  13 => const AgentAdversarialFixture(
    promptReleaseMissing: true,
    promptHashMismatch: true,
    schemaReplayCompatible: false,
  ),
  14 => const AgentAdversarialFixture(
    workspaceSceneCount: 9,
    fixtureCount: 10,
    outlineSceneCount: 9,
    uniqueScenarioIds: false,
    allVerifiersPresent: false,
    allTrialsSealed: false,
  ),
  15 => const AgentAdversarialFixture(
    challengerQualityNonInferior: false,
    p95LatencyRegression: 0.11,
    costRegression: 0.16,
  ),
  16 => const AgentAdversarialFixture(
    sutScorerTampered: true,
    evaluatorConclusionChanged: true,
  ),
  17 => const AgentAdversarialFixture(
    crossTrialCacheHit: true,
    cacheHitMarkedNonIndependent: false,
  ),
  18 => const AgentAdversarialFixture(
    requestCount: 100,
    successfulResponseCount: 3,
    failedAttemptsIncludedInMetrics: false,
  ),
  19 => const AgentAdversarialFixture(stateLeakedAcrossTrials: true),
  20 => const AgentAdversarialFixture(dangerousInput: true),
  21 => const AgentAdversarialFixture(concurrentCasMultipleWinners: true),
  22 => const AgentAdversarialFixture(
    judgePromptInjectionPresent: true,
    judgeFollowedInjection: true,
  ),
  23 => const AgentAdversarialFixture(
    holdoutQueryCount: 2,
    sameHoldoutReused: true,
    holdoutDiagnosticDetailsExposed: true,
  ),
  24 => const AgentAdversarialFixture(staleLeaseWriteAccepted: true),
  25 => const AgentAdversarialFixture(
    missingEvalCell: true,
    duplicateEvalCell: true,
    runtimeAddedEvalCell: true,
  ),
  _ => throw StateError('unknown adversarial case'),
};

AgentAdversarialFixture _controlFixture(int caseNumber) => switch (caseNumber) {
  1 => const AgentAdversarialFixture(dialogueRatio: 0.25),
  2 => const AgentAdversarialFixture(openingHasImmediateHook: true),
  3 => const AgentAdversarialFixture(
    sameActorTwoPlacesSameMinute: true,
    hasDelegationOrDelayMechanism: true,
  ),
  4 => const AgentAdversarialFixture(
    unpoweredDeviceActs: true,
    backupPowerExplicit: true,
  ),
  5 => const AgentAdversarialFixture(
    coercedRoleReversesPower: true,
    newEvidenceExplainsPowerShift: true,
  ),
  6 => const AgentAdversarialFixture(),
  7 => const AgentAdversarialFixture(),
  8 => const AgentAdversarialFixture(
    privateMemoryVisibleToUnauthorized: true,
    scopeOwnerAuthorized: true,
  ),
  9 => const AgentAdversarialFixture(
    invisibleHighScoreCandidateCount: 4096,
    visibleCanonSelected: true,
  ),
  10 => const AgentAdversarialFixture(),
  11 => const AgentAdversarialFixture(),
  12 => const AgentAdversarialFixture(),
  13 => const AgentAdversarialFixture(),
  14 => const AgentAdversarialFixture(),
  15 => const AgentAdversarialFixture(
    challengerQualityNonInferior: true,
    p95LatencyRegression: 0.10,
    costRegression: 0.15,
  ),
  16 => const AgentAdversarialFixture(
    sutScorerTampered: true,
    evaluatorConclusionChanged: false,
  ),
  17 => const AgentAdversarialFixture(
    crossTrialCacheHit: true,
    cacheHitMarkedNonIndependent: true,
  ),
  18 => const AgentAdversarialFixture(
    requestCount: 100,
    successfulResponseCount: 3,
    failedAttemptsIncludedInMetrics: true,
  ),
  19 => const AgentAdversarialFixture(
    stateLeakedAcrossTrials: false,
    episodeStateWithinSameTrial: true,
  ),
  20 => const AgentAdversarialFixture(),
  21 => const AgentAdversarialFixture(),
  22 => const AgentAdversarialFixture(
    judgePromptInjectionPresent: true,
    judgeFollowedInjection: false,
  ),
  23 => const AgentAdversarialFixture(),
  24 => const AgentAdversarialFixture(),
  25 => const AgentAdversarialFixture(),
  _ => throw StateError('unknown adversarial case'),
};

bool _detectViolation(
  int caseNumber,
  AgentAdversarialFixture fixture,
) => switch (caseNumber) {
  1 => fixture.dialogueRatio < 0.25,
  2 => !fixture.openingHasImmediateHook,
  3 =>
    fixture.sameActorTwoPlacesSameMinute &&
        !fixture.hasDelegationOrDelayMechanism,
  4 => fixture.unpoweredDeviceActs && !fixture.backupPowerExplicit,
  5 =>
    fixture.coercedRoleReversesPower && !fixture.newEvidenceExplainsPowerShift,
  6 =>
    fixture.repeatedMotifCount >= 3 ||
        fixture.expositoryDialogueRatio >= 0.6 ||
        fixture.repeatedExplanationCount >= 2,
  7 => fixture.polishIntroducedUnknownCanon,
  8 =>
    fixture.privateMemoryVisibleToUnauthorized && !fixture.scopeOwnerAuthorized,
  9 =>
    fixture.invisibleHighScoreCandidateCount >= 4096 &&
        !fixture.visibleCanonSelected,
  10 =>
    fixture.crashResumeReplayedCompletedOrdinal ||
        !fixture.checkpointContinuityValid,
  11 =>
    fixture.unlimitedTransportReplacement ||
        fixture.transportFailures >= fixture.transportAttempts,
  12 =>
    fixture.idempotencyKeyReusedForDifferentCandidate ||
        fixture.baseDraftOrMaterialChangedWithoutCas,
  13 =>
    fixture.promptReleaseMissing ||
        fixture.promptHashMismatch ||
        !fixture.schemaReplayCompatible,
  14 =>
    fixture.workspaceSceneCount != fixture.fixtureCount ||
        fixture.outlineSceneCount != fixture.fixtureCount ||
        !fixture.uniqueScenarioIds ||
        !fixture.allVerifiersPresent ||
        !fixture.allTrialsSealed,
  15 =>
    !fixture.challengerQualityNonInferior ||
        fixture.p95LatencyRegression > 0.10 ||
        fixture.costRegression > 0.15,
  16 => fixture.sutScorerTampered && fixture.evaluatorConclusionChanged,
  17 => fixture.crossTrialCacheHit && !fixture.cacheHitMarkedNonIndependent,
  18 =>
    fixture.requestCount >= 100 &&
        fixture.successfulResponseCount <= 3 &&
        !fixture.failedAttemptsIncludedInMetrics,
  19 => fixture.stateLeakedAcrossTrials,
  20 => fixture.dangerousInput,
  21 => fixture.concurrentCasMultipleWinners,
  22 => fixture.judgePromptInjectionPresent && fixture.judgeFollowedInjection,
  23 =>
    fixture.holdoutQueryCount > 1 ||
        fixture.sameHoldoutReused ||
        fixture.holdoutDiagnosticDetailsExposed,
  24 => fixture.staleLeaseWriteAccepted,
  25 =>
    fixture.missingEvalCell ||
        fixture.duplicateEvalCell ||
        fixture.runtimeAddedEvalCell,
  _ => throw StateError('unknown adversarial case'),
};

String _failureCode(int caseNumber) => _definitions
    .firstWhere((definition) => definition.caseNumber == caseNumber)
    .failureCode;

String _verifierRef(int caseNumber) =>
    'deterministic.agent-adversarial.${caseNumber.toString().padLeft(2, '0')}@1.0.0';

String _domainHash(String domain, Object? value) {
  final preimage = '$domain\u0000${jsonEncode(_canonicalize(value))}';
  final digest = const DartSha256().hashSync(utf8.encode(preimage));
  final hex = digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'sha256:$hex';
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
