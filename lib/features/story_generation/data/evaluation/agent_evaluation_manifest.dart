import '../../../../app/llm/app_llm_canonical_hash.dart';

abstract final class AgentEvaluationHashes {
  static String domainHash(String domainTag, Object? value) {
    final valueWithPrefix = AppLlmCanonicalHash.domainHash(domainTag, value);
    return valueWithPrefix.substring('sha256:'.length);
  }

  static String canonicalJson(Object? value) =>
      AppLlmCanonicalHash.canonicalJson(value);

  static void requireDigest(String value, String field) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
      throw ArgumentError.value(value, field, 'must be lowercase SHA-256 hex');
    }
  }
}

class ScenarioRelease {
  ScenarioRelease({
    required this.scenarioId,
    required this.version,
    required this.difficulty,
    required Map<String, Object?> inputFixture,
    required this.fixtureHash,
    required this.isolationMode,
    required List<String> requiredCapabilities,
    required List<String> adversarialMutations,
    required List<String> verifierReleaseRefs,
    required this.rubricReleaseRef,
    required this.expectedTerminalState,
    required List<String> requiredFailureCodes,
    required List<String> allowedAdditionalFailureCodes,
    required List<String> forbiddenFailureCodes,
    required this.outcomeComparatorReleaseRef,
    required List<String> forbiddenSideEffects,
    required this.acceptExpected,
    required Map<String, Object?> referenceFacts,
    required Map<String, Object?> maxBudget,
    this.episodeId,
    this.episodeStep,
  }) : inputFixture = Map<String, Object?>.unmodifiable(inputFixture),
       requiredCapabilities = List<String>.unmodifiable(requiredCapabilities),
       adversarialMutations = List<String>.unmodifiable(adversarialMutations),
       verifierReleaseRefs = List<String>.unmodifiable(verifierReleaseRefs),
       requiredFailureCodes = List<String>.unmodifiable(requiredFailureCodes),
       allowedAdditionalFailureCodes = List<String>.unmodifiable(
         allowedAdditionalFailureCodes,
       ),
       forbiddenFailureCodes = List<String>.unmodifiable(forbiddenFailureCodes),
       forbiddenSideEffects = List<String>.unmodifiable(forbiddenSideEffects),
       referenceFacts = Map<String, Object?>.unmodifiable(referenceFacts),
       maxBudget = Map<String, Object?>.unmodifiable(maxBudget);

  final String scenarioId;
  final String version;
  final String difficulty;
  final Map<String, Object?> inputFixture;
  final String fixtureHash;
  final String isolationMode;
  final String? episodeId;
  final int? episodeStep;
  final List<String> requiredCapabilities;
  final List<String> adversarialMutations;
  final List<String> verifierReleaseRefs;
  final String rubricReleaseRef;
  final String expectedTerminalState;
  final List<String> requiredFailureCodes;
  final List<String> allowedAdditionalFailureCodes;
  final List<String> forbiddenFailureCodes;
  final String outcomeComparatorReleaseRef;
  final List<String> forbiddenSideEffects;
  final bool acceptExpected;
  final Map<String, Object?> referenceFacts;
  final Map<String, Object?> maxBudget;

  String get releaseHash => AgentEvaluationHashes.domainHash(
    'eval-scenario-release-v1',
    toCanonicalMap(),
  );

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'scenarioId': scenarioId,
    'version': version,
    'difficulty': difficulty,
    'inputFixture': inputFixture,
    'fixtureHash': fixtureHash,
    'isolationMode': isolationMode,
    'episodeId': episodeId,
    'episodeStep': episodeStep,
    'requiredCapabilities': requiredCapabilities,
    'adversarialMutations': adversarialMutations,
    'verifierReleaseRefs': verifierReleaseRefs,
    'rubricReleaseRef': rubricReleaseRef,
    'expectedTerminalState': expectedTerminalState,
    'requiredFailureCodes': requiredFailureCodes,
    'allowedAdditionalFailureCodes': allowedAdditionalFailureCodes,
    'forbiddenFailureCodes': forbiddenFailureCodes,
    'outcomeComparatorReleaseRef': outcomeComparatorReleaseRef,
    'forbiddenSideEffects': forbiddenSideEffects,
    'acceptExpected': acceptExpected,
    'referenceFacts': referenceFacts,
    'maxBudget': maxBudget,
  };
}

class ScenarioSetRelease {
  ScenarioSetRelease({
    required this.setId,
    required this.version,
    required List<ScenarioRelease> scenarios,
    required this.fixtureCount,
    required this.outlineSceneCount,
    required this.holdout,
    required this.createdAtMs,
  }) : scenarios = List<ScenarioRelease>.unmodifiable(scenarios);

  final String setId;
  final String version;
  final List<ScenarioRelease> scenarios;
  final int fixtureCount;
  final int outlineSceneCount;
  final bool holdout;
  final int createdAtMs;

  String get releaseHash => AgentEvaluationHashes.domainHash(
    'eval-scenario-set-release-v1',
    toCanonicalMap(),
  );

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'setId': setId,
    'version': version,
    'scenarioReleaseHashes': scenarios
        .map((scenario) => scenario.releaseHash)
        .toList(growable: false),
    'fixtureCount': fixtureCount,
    'outlineSceneCount': outlineSceneCount,
    'holdout': holdout,
    'createdAtMs': createdAtMs,
  };
}

class AgentEvaluationCellManifest {
  const AgentEvaluationCellManifest({
    required this.generationBundleHash,
    required this.modelRouteHash,
    required this.scenarioReleaseHash,
    required this.decodingConfigHash,
  });

  final String generationBundleHash;
  final String modelRouteHash;
  final String scenarioReleaseHash;
  final String decodingConfigHash;

  String get cellId =>
      AgentEvaluationHashes.domainHash('eval-cell-v1', <String>[
        generationBundleHash,
        modelRouteHash,
        scenarioReleaseHash,
        decodingConfigHash,
      ]);

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'cellId': cellId,
    'generationBundleHash': generationBundleHash,
    'modelRouteHash': modelRouteHash,
    'scenarioReleaseHash': scenarioReleaseHash,
    'decodingConfigHash': decodingConfigHash,
  };
}

class HoldoutAccessPolicy {
  const HoldoutAccessPolicy({
    required this.policyHash,
    required this.accessBudget,
    required this.accessOrdinal,
    this.confirmationToken,
  });

  final String policyHash;
  final int accessBudget;
  final int accessOrdinal;
  final String? confirmationToken;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'policyHash': policyHash,
    'accessBudget': accessBudget,
    'accessOrdinal': accessOrdinal,
    'confirmationToken': confirmationToken,
  };
}

class ExperimentManifest {
  ExperimentManifest({
    required this.experimentId,
    required this.scenarioSet,
    required List<String> generationBundleHashes,
    required this.evaluationBundleHash,
    required List<String> modelRouteHashes,
    required List<String> decodingConfigHashes,
    required List<AgentEvaluationCellManifest> cells,
    required this.pipelineConfigHash,
    required this.providerConfigHashWithoutSecrets,
    required this.providerApiRevision,
    required this.sdkAdapterReleaseHash,
    required this.tokenizerReleaseHash,
    required this.priceTableHash,
    required this.codeCommit,
    required this.sourceTreeHash,
    required this.buildArtifactHash,
    required this.runtimeReleaseHash,
    required this.trialsPerCell,
    required Map<String, Object?> seedPolicy,
    required Map<String, Object?> trialIsolationPolicy,
    required Map<String, Object?> transportAttemptPolicy,
    required Map<String, Object?> performanceSamplingPolicy,
    required this.qualityComparisonPolicyHash,
    required this.holdoutAccessPolicy,
    required Map<String, Object?> budgets,
    required Map<String, Object?> qualityThresholds,
    required this.createdAtMs,
  }) : generationBundleHashes = List<String>.unmodifiable(
         generationBundleHashes,
       ),
       modelRouteHashes = List<String>.unmodifiable(modelRouteHashes),
       decodingConfigHashes = List<String>.unmodifiable(decodingConfigHashes),
       cells = List<AgentEvaluationCellManifest>.unmodifiable(cells),
       seedPolicy = Map<String, Object?>.unmodifiable(seedPolicy),
       trialIsolationPolicy = Map<String, Object?>.unmodifiable(
         trialIsolationPolicy,
       ),
       transportAttemptPolicy = Map<String, Object?>.unmodifiable(
         transportAttemptPolicy,
       ),
       performanceSamplingPolicy = Map<String, Object?>.unmodifiable(
         performanceSamplingPolicy,
       ),
       budgets = Map<String, Object?>.unmodifiable(budgets),
       qualityThresholds = Map<String, Object?>.unmodifiable(qualityThresholds);

  final String experimentId;
  final ScenarioSetRelease scenarioSet;
  final List<String> generationBundleHashes;
  final String evaluationBundleHash;
  final List<String> modelRouteHashes;
  final List<String> decodingConfigHashes;
  final List<AgentEvaluationCellManifest> cells;
  final String pipelineConfigHash;
  final String providerConfigHashWithoutSecrets;
  final String providerApiRevision;
  final String sdkAdapterReleaseHash;
  final String tokenizerReleaseHash;
  final String priceTableHash;
  final String codeCommit;
  final String sourceTreeHash;
  final String buildArtifactHash;
  final String runtimeReleaseHash;
  final int trialsPerCell;
  final Map<String, Object?> seedPolicy;
  final Map<String, Object?> trialIsolationPolicy;
  final Map<String, Object?> transportAttemptPolicy;
  final Map<String, Object?> performanceSamplingPolicy;
  final String qualityComparisonPolicyHash;
  final HoldoutAccessPolicy holdoutAccessPolicy;
  final Map<String, Object?> budgets;
  final Map<String, Object?> qualityThresholds;
  final int createdAtMs;

  String get manifestHash => AgentEvaluationHashes.domainHash(
    'eval-experiment-manifest-v1',
    toCanonicalMap(),
  );

  String get expectedCellSetHash {
    final ids = cells.map((cell) => cell.cellId).toList()..sort();
    return AgentEvaluationHashes.domainHash('eval-cell-set-v1', ids);
  }

  String get expectedSlotSetHash {
    final ids = cells.map((cell) => cell.cellId).toList()..sort();
    final slots = <List<Object>>[];
    for (final id in ids) {
      for (var trialNo = 1; trialNo <= trialsPerCell; trialNo += 1) {
        slots.add(<Object>[id, trialNo]);
      }
    }
    return AgentEvaluationHashes.domainHash('eval-slot-set-v1', slots);
  }

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'experimentId': experimentId,
    'scenarioSetReleaseHash': scenarioSet.releaseHash,
    'generationBundleHashes': generationBundleHashes,
    'evaluationBundleHash': evaluationBundleHash,
    'modelRouteHashes': modelRouteHashes,
    'decodingConfigHashes': decodingConfigHashes,
    'cells': cells.map((cell) => cell.toCanonicalMap()).toList(growable: false),
    'pipelineConfigHash': pipelineConfigHash,
    'providerConfigHashWithoutSecrets': providerConfigHashWithoutSecrets,
    'providerApiRevision': providerApiRevision,
    'sdkAdapterReleaseHash': sdkAdapterReleaseHash,
    'tokenizerReleaseHash': tokenizerReleaseHash,
    'priceTableHash': priceTableHash,
    'codeCommit': codeCommit,
    'sourceTreeHash': sourceTreeHash,
    'buildArtifactHash': buildArtifactHash,
    'runtimeReleaseHash': runtimeReleaseHash,
    'trialsPerCell': trialsPerCell,
    'seedPolicy': seedPolicy,
    'trialIsolationPolicy': trialIsolationPolicy,
    'transportAttemptPolicy': transportAttemptPolicy,
    'performanceSamplingPolicy': performanceSamplingPolicy,
    'qualityComparisonPolicyHash': qualityComparisonPolicyHash,
    'holdoutAccessPolicy': holdoutAccessPolicy.toCanonicalMap(),
    'budgets': budgets,
    'qualityThresholds': qualityThresholds,
    'createdAtMs': createdAtMs,
  };

  static List<AgentEvaluationCellManifest> expandCanonicalCells({
    required Iterable<String> generationBundleHashes,
    required Iterable<String> modelRouteHashes,
    required Iterable<ScenarioRelease> scenarios,
    required Iterable<String> decodingConfigHashes,
  }) {
    final result = <AgentEvaluationCellManifest>[];
    for (final bundle in generationBundleHashes) {
      for (final model in modelRouteHashes) {
        for (final scenario in scenarios) {
          for (final decoding in decodingConfigHashes) {
            result.add(
              AgentEvaluationCellManifest(
                generationBundleHash: bundle,
                modelRouteHash: model,
                scenarioReleaseHash: scenario.releaseHash,
                decodingConfigHash: decoding,
              ),
            );
          }
        }
      }
    }
    result.sort((left, right) => left.cellId.compareTo(right.cellId));
    return List<AgentEvaluationCellManifest>.unmodifiable(result);
  }
}
