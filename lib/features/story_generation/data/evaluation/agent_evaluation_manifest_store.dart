import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../../../app/llm/app_llm_prompt_release_store.dart';
import 'agent_evaluation_manifest.dart';
import 'agent_evaluation_production_authorities.dart';
import 'agent_evaluation_production_evidence.dart';
import 'agent_evaluation_production_side_effects.dart';

class AgentEvaluationManifestException implements Exception {
  const AgentEvaluationManifestException(this.message);

  final String message;

  @override
  String toString() => 'AgentEvaluationManifestException: $message';
}

class AgentEvaluationPreflightException
    extends AgentEvaluationManifestException {
  const AgentEvaluationPreflightException(super.message);
}

/// Persists immutable evaluation releases and enforces all harness invariants
/// before a provider callback can run.
class AgentEvaluationManifestStore {
  AgentEvaluationManifestStore({required this.db});

  static const String releaseDomain =
      'agent-evaluation-manifest-store-release-v2';
  static final String releaseHash =
      'sha256:${AgentEvaluationHashes.domainHash(releaseDomain, const <String, Object?>{
        'preflight': 'scenario-fixture-verifier-cell-build-bundle-authority-side-effect-before-provider-v2',
        'persistence': 'immutable-manifest-and-canonical-cell-cross-product',
        'productionSideEffects': <String, Object?>{
          'contractVersion': AgentEvaluationProductionSideEffectKeys.contractVersion,
          'supported': AgentEvaluationProductionSideEffectKeys.supportedList,
          'strictNamespaces': <String>['production.', 'production-'],
          'customNamespaces': 'allowed',
        },
      })}';

  final Database db;

  T preflightAndRun<T>({
    required ExperimentManifest manifest,
    required String actualBuildArtifactHash,
    required bool Function(String releaseRef) verifierExists,
    required T Function() providerCall,
    bool requireExecutableBundles = false,
    bool requireProductionAuthorities = false,
  }) {
    _validatePreflight(
      manifest: manifest,
      actualBuildArtifactHash: actualBuildArtifactHash,
      verifierExists: verifierExists,
      requireExecutableBundles: requireExecutableBundles,
      requireProductionAuthorities: requireProductionAuthorities,
    );
    _persistManifest(manifest);
    return providerCall();
  }

  void _validatePreflight({
    required ExperimentManifest manifest,
    required String actualBuildArtifactHash,
    required bool Function(String releaseRef) verifierExists,
    required bool requireExecutableBundles,
    required bool requireProductionAuthorities,
  }) {
    final scenarioSet = manifest.scenarioSet;
    if (scenarioSet.scenarios.isEmpty ||
        scenarioSet.scenarios.length != scenarioSet.fixtureCount ||
        scenarioSet.scenarios.length != scenarioSet.outlineSceneCount) {
      throw const AgentEvaluationPreflightException(
        'scenario, fixture, and outline scene counts must match',
      );
    }
    final scenarioIdentities = <String>{};
    final scenarioHashes = <String>{};
    final episodeSteps = <String, Set<int>>{};
    for (final scenario in scenarioSet.scenarios) {
      final identity = '${scenario.scenarioId}@${scenario.version}';
      if (!scenarioIdentities.add(identity) ||
          !scenarioHashes.add(scenario.releaseHash)) {
        throw const AgentEvaluationPreflightException(
          'scenario set contains a duplicate release',
        );
      }
      AgentEvaluationHashes.requireDigest(scenario.fixtureHash, 'fixtureHash');
      if (!<String>{
        'independent',
        'episode',
      }.contains(scenario.isolationMode)) {
        throw const AgentEvaluationPreflightException(
          'scenario isolation mode is invalid',
        );
      }
      if (scenario.isolationMode == 'independent') {
        if (scenario.episodeId != null || scenario.episodeStep != null) {
          throw const AgentEvaluationPreflightException(
            'independent scenario cannot declare episode metadata',
          );
        }
      } else {
        final episodeId = scenario.episodeId;
        final episodeStep = scenario.episodeStep;
        if (episodeId == null ||
            episodeId.trim().isEmpty ||
            episodeStep == null ||
            episodeStep <= 0 ||
            !(episodeSteps[episodeId] ??= <int>{}).add(episodeStep)) {
          throw const AgentEvaluationPreflightException(
            'episode scenario metadata is missing or duplicated',
          );
        }
      }
      final verifierRefs = <String>{
        ...scenario.verifierReleaseRefs,
        scenario.rubricReleaseRef,
        scenario.outcomeComparatorReleaseRef,
      };
      for (final releaseRef in verifierRefs) {
        if (releaseRef.trim().isEmpty || !verifierExists(releaseRef)) {
          throw AgentEvaluationPreflightException(
            'required verifier release is missing: $releaseRef',
          );
        }
      }
      if (requireProductionAuthorities) {
        try {
          AgentEvaluationProductionSideEffectKeys.validateStrict(
            scenario.forbiddenSideEffects,
          );
        } on FormatException catch (error) {
          throw AgentEvaluationPreflightException(error.message.toString());
        }
      }
    }
    for (final steps in episodeSteps.values) {
      final ordered = steps.toList()..sort();
      for (var index = 0; index < ordered.length; index += 1) {
        if (ordered[index] != index + 1) {
          throw const AgentEvaluationPreflightException(
            'episode steps must be contiguous and start at one',
          );
        }
      }
    }
    if (manifest.trialsPerCell <= 0) {
      throw const AgentEvaluationPreflightException(
        'trialsPerCell must be positive',
      );
    }
    for (final digest in <(String, String)>[
      (manifest.evaluationBundleHash, 'evaluationBundleHash'),
      (manifest.pipelineConfigHash, 'pipelineConfigHash'),
      (
        manifest.providerConfigHashWithoutSecrets,
        'providerConfigHashWithoutSecrets',
      ),
      (manifest.sdkAdapterReleaseHash, 'sdkAdapterReleaseHash'),
      (manifest.tokenizerReleaseHash, 'tokenizerReleaseHash'),
      (manifest.priceTableHash, 'priceTableHash'),
      (manifest.sourceTreeHash, 'sourceTreeHash'),
      (manifest.buildArtifactHash, 'buildArtifactHash'),
      (manifest.runtimeReleaseHash, 'runtimeReleaseHash'),
      (manifest.qualityComparisonPolicyHash, 'qualityComparisonPolicyHash'),
      (manifest.holdoutAccessPolicy.policyHash, 'holdoutAccessPolicyHash'),
    ]) {
      AgentEvaluationHashes.requireDigest(digest.$1, digest.$2);
    }
    AgentEvaluationHashes.requireDigest(
      actualBuildArtifactHash,
      'actualBuildArtifactHash',
    );
    if (actualBuildArtifactHash != manifest.buildArtifactHash) {
      throw const AgentEvaluationPreflightException(
        'actual build artifact does not match the frozen manifest',
      );
    }
    _requireUniqueDigests(
      manifest.generationBundleHashes,
      'generation bundles',
    );
    _requireUniqueDigests(manifest.modelRouteHashes, 'model routes');
    _requireUniqueDigests(manifest.decodingConfigHashes, 'decoding configs');
    final expectedCells = ExperimentManifest.expandCanonicalCells(
      generationBundleHashes: manifest.generationBundleHashes,
      modelRouteHashes: manifest.modelRouteHashes,
      scenarios: scenarioSet.scenarios,
      decodingConfigHashes: manifest.decodingConfigHashes,
    );
    final expectedIds = expectedCells.map((cell) => cell.cellId).toList();
    final actualIds = manifest.cells.map((cell) => cell.cellId).toList();
    if (actualIds.toSet().length != actualIds.length ||
        !_sameList(actualIds, expectedIds)) {
      throw const AgentEvaluationPreflightException(
        'declared cells are duplicated, missing, or not the canonical cross-product',
      );
    }
    final holdoutPolicy = manifest.holdoutAccessPolicy;
    if (scenarioSet.holdout &&
        (holdoutPolicy.accessBudget <= 0 ||
            holdoutPolicy.accessOrdinal < 0 ||
            holdoutPolicy.accessOrdinal >= holdoutPolicy.accessBudget ||
            holdoutPolicy.confirmationToken == null ||
            holdoutPolicy.confirmationToken!.trim().isEmpty)) {
      throw const AgentEvaluationPreflightException(
        'holdout execution lacks a valid confirmation token or access budget',
      );
    }
    if (manifest.providerApiRevision.trim().isEmpty ||
        manifest.codeCommit.trim().isEmpty) {
      throw const AgentEvaluationPreflightException(
        'provider revision and code commit must be frozen',
      );
    }

    for (final bundleHash in manifest.generationBundleHashes) {
      final rows = db.select(
        'SELECT 1 FROM generation_bundles WHERE bundle_hash = ?',
        <Object?>[bundleHash],
      );
      if (rows.length != 1) {
        throw AgentEvaluationPreflightException(
          'generation bundle is not published: $bundleHash',
        );
      }
    }
    if (requireExecutableBundles) {
      _validateExecutableBundleDifference(manifest.generationBundleHashes);
      if (manifest.decodingConfigHashes.length != 1) {
        throw const AgentEvaluationPreflightException(
          'release evaluation cannot declare decoding variants until the '
          'provider request executes the frozen decoding config',
        );
      }
    }
    final evaluatorRows = db.select(
      '''SELECT 1 FROM evaluation_bundles
         WHERE evaluation_bundle_hash = ?''',
      <Object?>[manifest.evaluationBundleHash],
    );
    if (evaluatorRows.length != 1) {
      throw const AgentEvaluationPreflightException(
        'evaluation bundle is not published',
      );
    }
    if (requireProductionAuthorities) {
      _validateProductionAuthorities(manifest);
    }
  }

  void _validateProductionAuthorities(ExperimentManifest manifest) {
    try {
      final rows = db.select(
        '''SELECT evaluator_bundle_id FROM evaluation_bundles
           WHERE evaluation_bundle_hash = ?''',
        <Object?>[manifest.evaluationBundleHash],
      );
      if (rows.length != 1) {
        throw const FormatException('evaluation bundle row');
      }
      final bundle = AppLlmPromptReleaseStore(
        db: db,
      ).getEvaluationBundle(rows.single['evaluator_bundle_id'] as String);
      final reconstructedHash = bundle.evaluatorBundleHash.startsWith('sha256:')
          ? bundle.evaluatorBundleHash.substring(7)
          : bundle.evaluatorBundleHash;
      if (reconstructedHash != manifest.evaluationBundleHash ||
          bundle.judgePromptReleases.length != 1 ||
          bundle.judgeModelRoutes.length != 1 ||
          bundle.deterministicVerifierReleases.isEmpty) {
        throw const FormatException('evaluation authority membership');
      }
      final verifierHashes = bundle.deterministicVerifierReleases.map((value) {
        return value.startsWith('sha256:') ? value.substring(7) : value;
      }).toSet();
      if (!verifierHashes.contains(
            AgentEvaluationProductionTransactionPolicy.releaseHash,
          ) ||
          !verifierHashes.contains(
            AgentEvaluationFrozenSafetyVerifier.standard().releaseHash,
          ) ||
          !verifierHashes.containsAll(
            AgentEvaluationDeterministicQualityPolicy
                .verifierReleaseHashes
                .values,
          )) {
        throw const FormatException('required verifier membership');
      }
      final priceTable = AgentEvaluationFrozenProviderPriceTable.load(
        db,
        releaseHash: manifest.priceTableHash,
      );
      final judgeRoute = bundle.judgeModelRoutes.single;
      final rawJudgeRoute = judgeRoute.startsWith('sha256:')
          ? judgeRoute.substring(7)
          : judgeRoute;
      if (!<String>{
        ...manifest.modelRouteHashes,
        rawJudgeRoute,
      }.every(priceTable.containsModelRoute)) {
        throw const FormatException('price table route membership');
      }
      final budgets = manifest.budgets;
      final maxAttempts = manifest.transportAttemptPolicy['maxAttempts'];
      final evaluatorCalls = budgets['evaluatorCalls'];
      final evaluatorTokens = budgets['evaluatorTokens'];
      final evaluatorCost = budgets['evaluatorCostMicrousd'];
      final evaluatorTokensPerCall = budgets['evaluatorTokensPerCall'];
      final evaluatorCostPerCall = budgets['evaluatorCostMicrousdPerCall'];
      if (budgets['evaluatorCalls'] is! int ||
          (budgets['evaluatorCalls'] as int) <= 0 ||
          budgets['evaluatorTokens'] is! int ||
          (budgets['evaluatorTokens'] as int) <= 0 ||
          budgets['evaluatorCostMicrousd'] is! int ||
          (budgets['evaluatorCostMicrousd'] as int) < 0 ||
          maxAttempts is! int ||
          maxAttempts <= 0 ||
          evaluatorTokensPerCall is! int ||
          evaluatorTokensPerCall <= 0 ||
          evaluatorCostPerCall is! int ||
          evaluatorCostPerCall < 0) {
        throw const FormatException('external evaluator budget');
      }
      final maximumAttemptCount =
          manifest.cells.length * manifest.trialsPerCell * maxAttempts;
      if ((evaluatorCalls as int) < maximumAttemptCount ||
          (evaluatorTokens as int) <
              maximumAttemptCount * evaluatorTokensPerCall ||
          (evaluatorCost as int) < maximumAttemptCount * evaluatorCostPerCall) {
        throw const FormatException(
          'execution evaluator budget does not cover the frozen attempt set',
        );
      }
    } on Object {
      throw const AgentEvaluationPreflightException(
        'production evaluation authorities cannot be reconstructed',
      );
    }
  }

  void _validateExecutableBundleDifference(List<String> bundleHashes) {
    final behaviorHashes = <String, String>{};
    for (final bundleHash in bundleHashes) {
      final bundleRows = db.select(
        'SELECT releases_json FROM generation_bundles WHERE bundle_hash = ?',
        <Object?>[bundleHash],
      );
      final rows = db.select(
        '''SELECT m.stage_id, m.call_site_id, m.variant_id,
             p.system_template, p.user_template, p.renderer_release,
             p.parser_release, p.output_schema_json, p.repair_policy_json
           FROM generation_bundle_releases m
           JOIN prompt_releases p ON p.release_id = m.prompt_release_id
           WHERE m.bundle_hash = ?
           ORDER BY m.stage_id, m.call_site_id, m.variant_id''',
        <Object?>[bundleHash],
      );
      if (rows.isEmpty) {
        throw AgentEvaluationPreflightException(
          'release generation bundle has no executable prompt releases: '
          '$bundleHash',
        );
      }
      try {
        final declared = jsonDecode(
          bundleRows.single['releases_json'] as String,
        );
        if (declared is! List || declared.length != rows.length) {
          throw const FormatException();
        }
      } on Object {
        throw AgentEvaluationPreflightException(
          'release generation bundle membership is empty or inconsistent: '
          '$bundleHash',
        );
      }
      final behaviorHash = AgentEvaluationHashes.domainHash(
        'eval-executable-generation-bundle-v1',
        <Object?>[
          for (final row in rows)
            <String, Object?>{
              'stageId': row['stage_id'],
              'callSiteId': row['call_site_id'],
              'variantId': row['variant_id'],
              'systemTemplate': row['system_template'],
              'userTemplate': row['user_template'],
              'rendererRelease': row['renderer_release'],
              'parserRelease': row['parser_release'],
              'outputSchemaJson': row['output_schema_json'],
              'repairPolicyJson': row['repair_policy_json'],
            },
        ],
      );
      final duplicate = behaviorHashes[behaviorHash];
      if (duplicate != null) {
        throw AgentEvaluationPreflightException(
          'generation bundles differ only by labels or non-executed identity: '
          '$duplicate and $bundleHash',
        );
      }
      behaviorHashes[behaviorHash] = bundleHash;
    }
  }

  void _persistManifest(ExperimentManifest manifest) {
    _inImmediateTransaction(() {
      final scenarioSet = manifest.scenarioSet;
      _insertOrValidate(
        table: 'eval_scenario_sets',
        keyColumn: 'scenario_set_release_hash',
        keyValue: scenarioSet.releaseHash,
        insert: () => db.execute(
          '''INSERT INTO eval_scenario_sets (
               scenario_set_release_hash, set_id, version, manifest_hash,
               created_at_ms
             ) VALUES (?, ?, ?, ?, ?)''',
          <Object?>[
            scenarioSet.releaseHash,
            scenarioSet.setId,
            scenarioSet.version,
            scenarioSet.releaseHash,
            scenarioSet.createdAtMs,
          ],
        ),
      );
      for (final scenario in scenarioSet.scenarios) {
        final opaqueHoldout = scenarioSet.holdout;
        _insertOrValidate(
          table: 'eval_scenarios',
          keyColumn: 'scenario_release_hash',
          keyValue: scenario.releaseHash,
          insert: () => db.execute(
            '''INSERT INTO eval_scenarios (
                 scenario_release_hash, scenario_set_release_hash, scenario_id,
                 version, fixture_hash, isolation_mode, episode_id, episode_step,
                 verifier_release_refs_json, rubric_release_ref,
                 expected_terminal_state, required_failure_codes_json,
                 allowed_failure_codes_json, forbidden_failure_codes_json,
                 outcome_comparator_release_ref, forbidden_side_effects_json,
                 accept_expected, scenario_json, created_at_ms
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            <Object?>[
              scenario.releaseHash,
              scenarioSet.releaseHash,
              opaqueHoldout
                  ? 'opaque-${scenario.releaseHash}'
                  : scenario.scenarioId,
              opaqueHoldout ? 'opaque' : scenario.version,
              scenario.fixtureHash,
              scenario.isolationMode,
              scenario.episodeId,
              scenario.episodeStep,
              AgentEvaluationHashes.canonicalJson(
                opaqueHoldout ? const <String>[] : scenario.verifierReleaseRefs,
              ),
              opaqueHoldout ? 'opaque-holdout' : scenario.rubricReleaseRef,
              opaqueHoldout ? 'opaque' : scenario.expectedTerminalState,
              AgentEvaluationHashes.canonicalJson(
                opaqueHoldout
                    ? const <String>[]
                    : scenario.requiredFailureCodes,
              ),
              AgentEvaluationHashes.canonicalJson(
                opaqueHoldout
                    ? const <String>[]
                    : scenario.allowedAdditionalFailureCodes,
              ),
              AgentEvaluationHashes.canonicalJson(
                opaqueHoldout
                    ? const <String>[]
                    : scenario.forbiddenFailureCodes,
              ),
              opaqueHoldout
                  ? 'opaque-holdout'
                  : scenario.outcomeComparatorReleaseRef,
              AgentEvaluationHashes.canonicalJson(
                opaqueHoldout
                    ? const <String>[]
                    : scenario.forbiddenSideEffects,
              ),
              opaqueHoldout ? 0 : (scenario.acceptExpected ? 1 : 0),
              AgentEvaluationHashes.canonicalJson(
                opaqueHoldout
                    ? <String, Object?>{
                        'schemaVersion': 'opaque-holdout-scenario-v1',
                        'scenarioReleaseHash': scenario.releaseHash,
                        'fixtureHash': scenario.fixtureHash,
                      }
                    : scenario.toCanonicalMap(),
              ),
              scenarioSet.createdAtMs,
            ],
          ),
        );
      }
      for (final cell in manifest.cells) {
        _insertOrValidate(
          table: 'eval_cells',
          keyColumn: 'cell_id',
          keyValue: cell.cellId,
          insert: () => db.execute(
            '''INSERT INTO eval_cells (
                 cell_id, generation_bundle_hash, sut_model_route_hash,
                 scenario_release_hash, decoding_config_hash, created_at_ms
               ) VALUES (?, ?, ?, ?, ?, ?)''',
            <Object?>[
              cell.cellId,
              cell.generationBundleHash,
              cell.modelRouteHash,
              cell.scenarioReleaseHash,
              cell.decodingConfigHash,
              manifest.createdAtMs,
            ],
          ),
        );
      }
      _insertOrValidate(
        table: 'eval_experiments',
        keyColumn: 'experiment_id',
        keyValue: manifest.experimentId,
        insert: () => db.execute(
          '''INSERT INTO eval_experiments (
               experiment_id, manifest_json, manifest_hash,
               scenario_set_release_hash, evaluation_bundle_hash,
               expected_cell_set_hash, expected_slot_set_hash, trials_per_cell,
               created_at_ms
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          <Object?>[
            manifest.experimentId,
            AgentEvaluationHashes.canonicalJson(_publicManifestMap(manifest)),
            manifest.manifestHash,
            scenarioSet.releaseHash,
            manifest.evaluationBundleHash,
            manifest.expectedCellSetHash,
            manifest.expectedSlotSetHash,
            manifest.trialsPerCell,
            manifest.createdAtMs,
          ],
        ),
      );
      final memberships = db.select(
        '''SELECT cell_id, ordinal FROM eval_experiment_cells
           WHERE experiment_id = ? ORDER BY ordinal''',
        <Object?>[manifest.experimentId],
      );
      if (memberships.isEmpty) {
        for (var ordinal = 0; ordinal < manifest.cells.length; ordinal += 1) {
          db.execute(
            '''INSERT INTO eval_experiment_cells (experiment_id, cell_id, ordinal)
               VALUES (?, ?, ?)''',
            <Object?>[
              manifest.experimentId,
              manifest.cells[ordinal].cellId,
              ordinal,
            ],
          );
        }
      } else if (memberships.length != manifest.cells.length ||
          List<int>.generate(memberships.length, (index) => index).any(
            (index) =>
                memberships[index]['ordinal'] != index ||
                memberships[index]['cell_id'] != manifest.cells[index].cellId,
          )) {
        throw const AgentEvaluationManifestException(
          'stored experiment cell membership conflicts with manifest',
        );
      }
    });
  }

  static Map<String, Object?> _publicManifestMap(ExperimentManifest manifest) {
    final value = Map<String, Object?>.from(manifest.toCanonicalMap());
    if (!manifest.scenarioSet.holdout) return value;
    value['scenarioSet'] = <String, Object?>{
      'schemaVersion': 'opaque-holdout-scenario-set-v1',
      'releaseHash': manifest.scenarioSet.releaseHash,
      'setId': manifest.scenarioSet.setId,
      'version': manifest.scenarioSet.version,
      'holdout': true,
      'scenarioReleaseHashes': manifest.scenarioSet.scenarios
          .map((scenario) => scenario.releaseHash)
          .toList(growable: false),
      'fixtureCount': manifest.scenarioSet.fixtureCount,
      'outlineSceneCount': manifest.scenarioSet.outlineSceneCount,
    };
    value['manifestStorageScope'] = 'opaque-holdout-authority-v1';
    return value;
  }

  void _insertOrValidate({
    required String table,
    required String keyColumn,
    required String keyValue,
    required void Function() insert,
  }) {
    final rows = db.select(
      'SELECT 1 FROM $table WHERE $keyColumn = ?',
      <Object?>[keyValue],
    );
    if (rows.isEmpty) insert();
  }

  T _inImmediateTransaction<T>(T Function() body) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  static void _requireUniqueDigests(List<String> values, String field) {
    if (values.isEmpty || values.toSet().length != values.length) {
      throw AgentEvaluationPreflightException(
        '$field must be non-empty and unique',
      );
    }
    for (final value in values) {
      AgentEvaluationHashes.requireDigest(value, field);
    }
  }

  static bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}
