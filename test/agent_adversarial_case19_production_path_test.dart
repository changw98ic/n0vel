import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/story_outline_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_adversarial_production_cases.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_manifest.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'case19 pair derives independent and episode topology from sealed production runs',
    () async {
      final root = Directory.systemTemp.createTempSync(
        'agent-adversarial-case19-',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final evidence = await AgentAdversarialProductionPathRunner()
          .runCaseNumber(caseNumber: 19, workDirectory: root);
      expect(evidence, hasLength(2));
      expect(
        evidence.every((item) => item.passed),
        isTrue,
        reason: evidence.map((item) => item.toJson()).toList().toString(),
      );
      final attack = evidence.singleWhere((item) => item.variant == 'attack');
      final control = evidence.singleWhere((item) => item.variant == 'control');
      expect(attack.actualOutcome, 'blocked');
      expect(control.actualOutcome, 'accepted');
      for (final item in evidence) {
        expect(
          item.authoritySources.single.sourceType,
          'runner-production-isolation-projection',
        );
        final payload = item.authoritySources.single.payload;
        expect(payload['generationCount'], 2);
        expect(payload['sealedSlotCount'], 2);
        expect(payload['topologyHardPass'], isTrue);
        expect(payload['productionUnchanged'], isTrue);
        expect(payload['reportCancelled'], isFalse);
        expect(payload['reportDeadlineExceeded'], isFalse);
        expect(payload['realProviderEvidence'], isFalse);
        expect(payload['providerCallCount'], 26);
        expect(payload['productionAuthorityReceiptCount'], 2);
        await _expectCanonicalFixture(root, item.variant);
        final authority = sqlite3.open(
          '${root.path}/${payload['databaseFile']}',
          mode: OpenMode.readOnly,
        );
        try {
          expect(
            authority.select(
              "SELECT trial_slot_id FROM eval_trial_slots WHERE status = 'sealed'",
            ),
            hasLength(2),
          );
          final generations = authority.select(
            'SELECT database_path FROM eval_sandbox_generations',
          );
          expect(generations, hasLength(2));
          for (final row in generations) {
            final sealed = sqlite3.open(
              row['database_path'] as String,
              mode: OpenMode.readOnly,
            );
            try {
              for (final table in const <String>[
                'story_generation_runs',
                'story_generation_candidate_proofs',
                'story_generation_commit_receipts',
                'eval_production_prepared_results',
                'eval_production_executor_results',
                'version_entries',
              ]) {
                expect(
                  sealed
                          .select('SELECT COUNT(*) AS count FROM $table')
                          .single['count']
                      as int,
                  greaterThan(0),
                );
              }
            } finally {
              sealed.dispose();
            }
          }
        } finally {
          authority.dispose();
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _expectCanonicalFixture(Directory root, String variant) async {
  const projectId = 'agent-evaluation-production-project';
  final path = '${root.path}/case-19-$variant-fixture.sqlite';
  final workspace = await SqliteAppWorkspaceStorage(dbPath: path).load();
  final outline = await SqliteStoryOutlineStorage(
    dbPath: path,
    requireExistingSchema: true,
  ).load(projectId: projectId);
  expect(workspace, isNotNull);
  expect(outline, isNotNull);
  final chapters = outline!['chapters']! as List<Object?>;
  final chapter = Map<String, Object?>.from(chapters.single! as Map);
  final scenes = chapter['scenes']! as List<Object?>;
  final scene = Map<String, Object?>.from(scenes.single! as Map);
  final metadata = Map<String, Object?>.from(scene['metadata']! as Map);
  expect(metadata['requireOutlineFidelity'], isTrue);
  final beats = metadata['requiredOutlineBeats']! as List<Object?>;
  final beat = Map<String, Object?>.from(beats.single! as Map);
  expect(beat['evidenceGroups'], <Object?>[
    <String>['林舟'],
    <String>['七号仓'],
    <String>['账本'],
  ]);

  final fixtureReleaseHash = AgentEvaluationHashes.domainHash(
    'agent-evaluation-production-fixture-release-v2',
    <String, Object?>{'workspace': workspace, 'outline': outline},
  );
  final authority = sqlite3.open(
    '${root.path}/case-19-$variant-authority.sqlite',
    mode: OpenMode.readOnly,
  );
  try {
    final rows = authority.select(
      'SELECT fixture_hash, scenario_json FROM eval_scenarios',
    );
    expect(rows, hasLength(variant == 'attack' ? 1 : 2));
    for (final row in rows) {
      final scenario = Map<String, Object?>.from(
        jsonDecode(row['scenario_json'] as String) as Map,
      );
      final inputFixture = Map<String, Object?>.from(
        scenario['inputFixture']! as Map,
      );
      expect(inputFixture['fixtureReleaseHash'], fixtureReleaseHash);
      expect(
        row['fixture_hash'],
        AppLlmCanonicalHash.domainHash(
          'case-19-fixture-v2',
          inputFixture,
        ).substring('sha256:'.length),
      );
    }
  } finally {
    authority.dispose();
  }
}
