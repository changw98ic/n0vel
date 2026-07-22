import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/story_outline_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_promotion_performance_authority.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'case15 pair reopens both sealed matrices through the frozen authority',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'agent-adversarial-case15-',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final evidence = await AgentAdversarialProductionPathRunner()
          .runCaseNumber(caseNumber: 15, workDirectory: root);
      expect(evidence, hasLength(2));
      expect(evidence.every((item) => item.passed), isTrue);
      for (final item in evidence) {
        final payload = item.authoritySources.single.payload;
        expect(
          payload['sutProviderCallCount'],
          AgentEvaluationPromotionPerformanceScenario
              .expectedSutProviderCallCount,
          reason:
              '60 sealed slots must each complete all 13 exact-schema production calls',
        );
        expect(
          payload['sutBaselineCallCount'],
          AgentEvaluationPromotionPerformanceScenario.expectedBaselineCalls,
        );
        expect(
          payload['sutPricedChallengerCallCount'],
          AgentEvaluationPromotionPerformanceScenario
              .expectedPricedChallengerCalls,
        );
        final db = sqlite3.open(
          '${root.path}/${payload['databaseFile']}',
          mode: OpenMode.readOnly,
        );
        try {
          final report =
              jsonDecode(
                    File(
                      '${root.path}/${payload['reportFile']}',
                    ).readAsStringSync(),
                  )
                  as Map<String, Object?>;
          final projection =
              AgentEvaluationPromotionPerformanceAuthority.verifyReportMap(
                db: db,
                reportMap: report,
              );
          expect(projection.projectionHash, report['projectionHash']);
          expect(projection.performanceSampleCount, greaterThanOrEqualTo(20));
        } finally {
          db.dispose();
        }
      }
      for (final variant in <String>['control', 'attack']) {
        await _expectCanonicalPublicFixture(root, variant);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<void> _expectCanonicalPublicFixture(
  Directory root,
  String variant,
) async {
  const projectId = 'real-release-public-project-v2';
  const sceneId = 'real-release-public-scene-v2';
  const sceneScopeId = '$projectId::$sceneId';
  final fixturePath = '${root.path}/case-15-$variant-work/fixture.sqlite';
  final workspace = await SqliteAppWorkspaceStorage(dbPath: fixturePath).load();
  final outline = await SqliteStoryOutlineStorage(
    dbPath: fixturePath,
    requireExistingSchema: true,
  ).load(projectId: projectId);
  expect(workspace, isNotNull);
  expect(outline, isNotNull);

  final workspaceMap = workspace!;
  final projects = workspaceMap['projects']! as List<Object?>;
  final project = Map<String, Object?>.from(projects.single! as Map);
  expect(project['id'], projectId);
  expect(project['sceneId'], sceneId);
  final charactersByProject = Map<String, Object?>.from(
    workspaceMap['charactersByProject']! as Map,
  );
  final characters = charactersByProject[projectId]! as List<Object?>;
  final character = Map<String, Object?>.from(characters.single! as Map);
  expect(character['name'], '林舟');
  final scenesByProject = Map<String, Object?>.from(
    workspaceMap['scenesByProject']! as Map,
  );
  final scenes = scenesByProject[projectId]! as List<Object?>;
  expect(scenes, hasLength(1));
  expect(Map<String, Object?>.from(scenes.single! as Map)['id'], sceneId);
  expect(workspaceMap['currentProjectId'], projectId);

  final chapters = outline!['chapters']! as List<Object?>;
  final chapter = Map<String, Object?>.from(chapters.single! as Map);
  final outlineScenes = chapter['scenes']! as List<Object?>;
  final outlineScene = Map<String, Object?>.from(outlineScenes.single! as Map);
  expect(outlineScene['id'], sceneId);
  final metadata = Map<String, Object?>.from(outlineScene['metadata']! as Map);
  expect(metadata['requireOutlineFidelity'], isTrue);
  final requiredBeats = metadata['requiredOutlineBeats']! as List<Object?>;
  final requiredBeat = Map<String, Object?>.from(requiredBeats.single! as Map);
  expect(requiredBeat['evidenceGroups'], <Object?>[
    <String>['林舟'],
    <String>['七号仓'],
    <String>['账本'],
  ]);

  final fixtureReleaseHash = AgentEvaluationHashes.domainHash(
    'real-release-public-fixture-release-v2',
    <String, Object?>{'workspace': workspaceMap, 'outline': outline},
  );
  final authority = sqlite3.open(
    '${root.path}/case-15-$variant-authority.sqlite',
    mode: OpenMode.readOnly,
  );
  try {
    final set = authority
        .select('SELECT set_id, version FROM eval_scenario_sets')
        .single;
    expect(set['set_id'], 'real-provider-release-episode-v2');
    expect(set['version'], '2.0.0');
    final rows = authority.select(
      'SELECT fixture_hash, scenario_json FROM eval_scenarios '
      'ORDER BY scenario_id ASC',
    );
    expect(rows, hasLength(10));
    for (final row in rows) {
      final scenario = Map<String, Object?>.from(
        jsonDecode(row['scenario_json'] as String) as Map,
      );
      final inputFixture = Map<String, Object?>.from(
        scenario['inputFixture']! as Map,
      );
      expect(inputFixture['fixtureReleaseHash'], fixtureReleaseHash);
      expect(inputFixture['projectId'], projectId);
      expect(inputFixture['sceneId'], sceneId);
      expect(inputFixture['sceneScopeId'], sceneScopeId);
      expect(
        row['fixture_hash'],
        AgentEvaluationHashes.domainHash(
          'real-release-public-scenario-fixture-v2',
          inputFixture,
        ),
      );
    }
  } finally {
    authority.dispose();
  }
}
