import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest_store.dart';

void main() {
  late Database db;
  late AgentEvaluationManifestStore store;
  var providerCalls = 0;

  setUp(() {
    db = sqlite3.openInMemory();
    db.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    _seedBundles(db);
    store = AgentEvaluationManifestStore(db: db);
    providerCalls = 0;
  });

  tearDown(() => db.dispose());

  test('nine scenarios with ten fixtures fails before provider', () {
    final scenarios = List<ScenarioRelease>.generate(
      9,
      (index) => _scenario(index + 1),
    );
    final manifest = _manifest(
      scenarios: scenarios,
      fixtureCount: 10,
      outlineSceneCount: 9,
    );

    _expectPreflightFailure(store, manifest, () => providerCalls++);
    expect(providerCalls, 0);
  });

  test('duplicate scenario release fails before provider', () {
    final scenario = _scenario(1);
    final manifest = _manifest(
      scenarios: <ScenarioRelease>[scenario, scenario],
      fixtureCount: 2,
      outlineSceneCount: 2,
    );

    _expectPreflightFailure(store, manifest, () => providerCalls++);
    expect(providerCalls, 0);
  });

  test('missing cross-product cell fails before provider', () {
    final scenario = _scenario(1);
    final fullCells = ExperimentManifest.expandCanonicalCells(
      generationBundleHashes: <String>[_digest('a'), _digest('b')],
      modelRouteHashes: <String>[_digest('1')],
      scenarios: <ScenarioRelease>[scenario],
      decodingConfigHashes: <String>[_digest('d')],
    );
    final manifest = _manifest(
      scenarios: <ScenarioRelease>[scenario],
      generationBundles: <String>[_digest('a'), _digest('b')],
      cells: fullCells.take(1).toList(),
    );

    _expectPreflightFailure(store, manifest, () => providerCalls++);
    expect(providerCalls, 0);
  });

  test('actual dirty build hash fails before provider', () {
    final manifest = _manifest(scenarios: <ScenarioRelease>[_scenario(1)]);

    expect(
      () => store.preflightAndRun<void>(
        manifest: manifest,
        actualBuildArtifactHash: _digest('0'),
        verifierExists: (_) => true,
        providerCall: () => providerCalls++,
      ),
      throwsA(isA<AgentEvaluationPreflightException>()),
    );
    expect(providerCalls, 0);
  });

  test('missing verifier release fails before provider', () {
    final manifest = _manifest(
      scenarios: <ScenarioRelease>[_scenario(1, verifier: 'missing-v1')],
    );

    expect(
      () => store.preflightAndRun<void>(
        manifest: manifest,
        actualBuildArtifactHash: manifest.buildArtifactHash,
        verifierExists: (ref) => ref != 'missing-v1',
        providerCall: () => providerCalls++,
      ),
      throwsA(isA<AgentEvaluationPreflightException>()),
    );
    expect(providerCalls, 0);
  });

  test('invalid holdout access policy fails before provider', () {
    final manifest = _manifest(
      scenarios: <ScenarioRelease>[_scenario(1)],
      holdout: true,
      holdoutPolicy: HoldoutAccessPolicy(
        policyHash: _digest('7'),
        accessBudget: 1,
        accessOrdinal: 1,
      ),
    );

    _expectPreflightFailure(store, manifest, () => providerCalls++);
    expect(providerCalls, 0);
  });

  test('gapped or duplicate episode steps fail before provider', () {
    final gapped = _manifest(
      scenarios: <ScenarioRelease>[
        _scenario(1, isolationMode: 'episode', episodeStep: 1),
        _scenario(2, isolationMode: 'episode', episodeStep: 3),
      ],
    );
    _expectPreflightFailure(store, gapped, () => providerCalls++);

    final duplicated = _manifest(
      scenarios: <ScenarioRelease>[
        _scenario(1, isolationMode: 'episode', episodeStep: 1),
        _scenario(2, isolationMode: 'episode', episodeStep: 1),
      ],
    );
    _expectPreflightFailure(store, duplicated, () => providerCalls++);

    expect(providerCalls, 0);
  });

  test('valid manifest persists immutable releases before provider call', () {
    final manifest = _manifest(
      scenarios: <ScenarioRelease>[_scenario(1)],
      holdout: true,
    );

    final result = store.preflightAndRun<String>(
      manifest: manifest,
      actualBuildArtifactHash: manifest.buildArtifactHash,
      verifierExists: (_) => true,
      providerCall: () {
        providerCalls += 1;
        return 'provider-result';
      },
    );

    expect(result, 'provider-result');
    expect(providerCalls, 1);
    expect(db.select('SELECT * FROM eval_scenarios'), hasLength(1));
    expect(db.select('SELECT * FROM eval_experiments'), hasLength(1));
    final publicScenario =
        db
                .select('SELECT scenario_json FROM eval_scenarios')
                .single['scenario_json']
            as String;
    final publicManifest =
        db
                .select('SELECT manifest_json FROM eval_experiments')
                .single['manifest_json']
            as String;
    expect(publicScenario, isNot(contains('"fixture":1')));
    expect(publicScenario, isNot(contains('"canon":"fixed"')));
    expect(publicManifest, isNot(contains('"fixture":1')));
    expect(publicManifest, isNot(contains('"canon":"fixed"')));
    expect(publicManifest, contains('opaque-holdout-authority-v1'));
    expect(
      db.select('SELECT * FROM eval_experiment_cells'),
      hasLength(manifest.cells.length),
    );
    expect(
      () => db.execute(
        "UPDATE eval_experiments SET manifest_json = '{}' "
        "WHERE experiment_id = 'experiment-1'",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('release preflight rejects bundles that differ only by labels', () {
    final manifest = _manifest(
      scenarios: <ScenarioRelease>[_scenario(1)],
      generationBundles: <String>[_digest('a'), _digest('b')],
    );

    expect(
      () => store.preflightAndRun<void>(
        manifest: manifest,
        actualBuildArtifactHash: manifest.buildArtifactHash,
        verifierExists: (_) => true,
        requireExecutableBundles: true,
        providerCall: () => providerCalls += 1,
      ),
      throwsA(
        isA<AgentEvaluationPreflightException>().having(
          (error) => error.message,
          'message',
          contains('differ only by labels'),
        ),
      ),
    );
    expect(providerCalls, 0);
  });
}

void _expectPreflightFailure(
  AgentEvaluationManifestStore store,
  ExperimentManifest manifest,
  void Function() providerCall,
) {
  expect(
    () => store.preflightAndRun<void>(
      manifest: manifest,
      actualBuildArtifactHash: manifest.buildArtifactHash,
      verifierExists: (_) => true,
      providerCall: providerCall,
    ),
    throwsA(isA<AgentEvaluationPreflightException>()),
  );
}

ScenarioRelease _scenario(
  int number, {
  String verifier = 'verifier-v1',
  String isolationMode = 'independent',
  int? episodeStep,
}) => ScenarioRelease(
  scenarioId: 'scenario-$number',
  version: '1.0.0',
  difficulty: 'adversarial',
  inputFixture: <String, Object?>{'fixture': number},
  fixtureHash: _digest(number.toRadixString(16)),
  isolationMode: isolationMode,
  episodeId: isolationMode == 'episode' ? 'episode-1' : null,
  episodeStep: episodeStep,
  requiredCapabilities: const <String>['story-generation'],
  adversarialMutations: const <String>['continuity-conflict'],
  verifierReleaseRefs: <String>[verifier],
  rubricReleaseRef: 'rubric-v1',
  expectedTerminalState: 'accepted',
  requiredFailureCodes: const <String>[],
  allowedAdditionalFailureCodes: const <String>[],
  forbiddenFailureCodes: const <String>['harness.invalid_fixture'],
  outcomeComparatorReleaseRef: 'comparator-v1',
  forbiddenSideEffects: const <String>['preaccept-authority-write'],
  acceptExpected: true,
  referenceFacts: const <String, Object?>{'canon': 'fixed'},
  maxBudget: const <String, Object?>{'calls': 20, 'tokens': 20000},
);

ExperimentManifest _manifest({
  required List<ScenarioRelease> scenarios,
  int? fixtureCount,
  int? outlineSceneCount,
  List<String>? generationBundles,
  List<AgentEvaluationCellManifest>? cells,
  bool holdout = false,
  HoldoutAccessPolicy? holdoutPolicy,
}) {
  final bundles = generationBundles ?? <String>[_digest('b')];
  final modelRoutes = <String>[_digest('1')];
  final decoding = <String>[_digest('d')];
  final scenarioSet = ScenarioSetRelease(
    setId: 'scenario-set-1',
    version: '1.0.0',
    scenarios: scenarios,
    fixtureCount: fixtureCount ?? scenarios.length,
    outlineSceneCount: outlineSceneCount ?? scenarios.length,
    holdout: holdout,
    createdAtMs: 1,
  );
  return ExperimentManifest(
    experimentId: 'experiment-1',
    scenarioSet: scenarioSet,
    generationBundleHashes: bundles,
    evaluationBundleHash: _digest('e'),
    modelRouteHashes: modelRoutes,
    decodingConfigHashes: decoding,
    cells:
        cells ??
        ExperimentManifest.expandCanonicalCells(
          generationBundleHashes: bundles,
          modelRouteHashes: modelRoutes,
          scenarios: scenarios,
          decodingConfigHashes: decoding,
        ),
    pipelineConfigHash: _digest('2'),
    providerConfigHashWithoutSecrets: _digest('3'),
    providerApiRevision: 'glm-api-2026-07',
    sdkAdapterReleaseHash: _digest('4'),
    tokenizerReleaseHash: _digest('5'),
    priceTableHash: _digest('6'),
    codeCommit: 'deadbeef',
    sourceTreeHash: _digest('8'),
    buildArtifactHash: _digest('9'),
    runtimeReleaseHash: _digest('a'),
    trialsPerCell: 3,
    seedPolicy: const <String, Object?>{'mode': 'provider-recorded'},
    trialIsolationPolicy: const <String, Object?>{'mode': 'independent-db'},
    transportAttemptPolicy: const <String, Object?>{'maxAttempts': 2},
    performanceSamplingPolicy: const <String, Object?>{'minimum': 20},
    qualityComparisonPolicyHash: _digest('c'),
    holdoutAccessPolicy:
        holdoutPolicy ??
        HoldoutAccessPolicy(
          policyHash: _digest('7'),
          accessBudget: 2,
          accessOrdinal: 0,
          confirmationToken: holdout ? 'confirmation-1' : null,
        ),
    budgets: const <String, Object?>{'calls': 100, 'tokens': 100000},
    qualityThresholds: const <String, Object?>{'overall': 95, 'critical': 90},
    createdAtMs: 1,
  );
}

void _seedBundles(Database db) {
  for (final bundle in <String>[_digest('a'), _digest('b')]) {
    final suffix = bundle[0];
    db.execute(
      '''INSERT INTO generation_bundles (
           bundle_hash, bundle_id, releases_json, created_at_ms
         ) VALUES (?, ?, '[{}]', 1)''',
      <Object?>[bundle, 'bundle-${bundle[0]}'],
    );
    db.execute(
      '''INSERT INTO prompt_releases (
           release_id, template_id, semantic_version, language, content_hash,
           system_template, user_template, variables_schema_json,
           output_schema_json, renderer_release, parser_release,
           repair_policy_json, variables_schema_hash, output_schema_hash,
           owner, change_note, created_at_ms
         ) VALUES (?, ?, '1.0.0', 'zh', ?, 'same executable system',
           'same executable user', '{}', '{}', 'renderer-v1', 'parser-v1',
           '{}', ?, ?, 'test', 'identity-only variant', 1)''',
      <Object?>[
        'manifest-release-$suffix',
        'manifest-template-$suffix',
        _digest(suffix == 'a' ? '4' : '5'),
        _digest('6'),
        _digest('7'),
      ],
    );
    db.execute(
      '''INSERT INTO generation_bundle_releases (
           bundle_hash, stage_id, call_site_id, variant_id, prompt_release_id
         ) VALUES (?, 'stage', 'call', 'zh', ?)''',
      <Object?>[bundle, 'manifest-release-$suffix'],
    );
  }
  db.execute(
    '''INSERT INTO evaluation_bundles (
         evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
         judges_json, rubric_release_hash, aggregator_release_hash,
         failure_taxonomy_hash, blinding_policy_version, created_at_ms
       ) VALUES (?, 'evaluator-v1', '[]', '[]', ?, ?, ?, 'blind-v1', 1)''',
    <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
  );
}

String _digest(String character) => List<String>.filled(64, character).join();
