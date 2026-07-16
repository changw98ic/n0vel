import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../app/state/authoring_db_schema.dart';
import '../../../../app/state/db_schema_manager.dart';
import 'agent_evaluation_ledger.dart';
import 'agent_evaluation_manifest.dart';

class AgentEvaluationMigrationRecoveryDrillReport {
  const AgentEvaluationMigrationRecoveryDrillReport({
    required this.sourceVersion,
    required this.targetVersion,
    required this.snapshotFileHash,
    required this.beforeAuditRoot,
    required this.afterRestoreAuditRoot,
    required this.authorityTableCount,
    required this.authorityMutationDetected,
    required this.bundleMembershipMutationDetected,
    required this.walCommitRecovered,
    required this.upgradeIdempotent,
    required this.failedMigrationRolledBack,
    required this.oldReaderRejected,
    required this.oldWriterRejected,
    required this.integrityCheck,
  });

  final int sourceVersion;
  final int targetVersion;
  final String snapshotFileHash;
  final String beforeAuditRoot;
  final String afterRestoreAuditRoot;
  final int authorityTableCount;
  final bool authorityMutationDetected;
  final bool bundleMembershipMutationDetected;
  final bool walCommitRecovered;
  final bool upgradeIdempotent;
  final bool failedMigrationRolledBack;
  final bool oldReaderRejected;
  final bool oldWriterRejected;
  final String integrityCheck;

  bool get passed =>
      sourceVersion == 26 &&
      targetVersion == 27 &&
      beforeAuditRoot == afterRestoreAuditRoot &&
      authorityTableCount >= 45 &&
      authorityMutationDetected &&
      bundleMembershipMutationDetected &&
      walCommitRecovered &&
      upgradeIdempotent &&
      failedMigrationRolledBack &&
      oldReaderRejected &&
      oldWriterRejected &&
      integrityCheck == 'ok';

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 'agent-evaluation-migration-recovery-drill-v1',
    'sourceVersion': sourceVersion,
    'targetVersion': targetVersion,
    'snapshotFileHash': snapshotFileHash,
    'beforeAuditRoot': beforeAuditRoot,
    'afterRestoreAuditRoot': afterRestoreAuditRoot,
    'authorityTableCount': authorityTableCount,
    'authorityMutationDetected': authorityMutationDetected,
    'bundleMembershipMutationDetected': bundleMembershipMutationDetected,
    'walCommitRecovered': walCommitRecovered,
    'upgradeIdempotent': upgradeIdempotent,
    'failedMigrationRolledBack': failedMigrationRolledBack,
    'oldReaderRejected': oldReaderRejected,
    'oldWriterRejected': oldWriterRejected,
    'integrityCheck': integrityCheck,
    'passed': passed,
  };

  String get reportHash => AgentEvaluationHashes.domainHash(
    'eval-migration-recovery-drill-report-v1',
    toJson(),
  );
}

abstract final class AgentEvaluationMigrationRecoveryDrill {
  static AgentEvaluationMigrationRecoveryDrillReport run({
    required Directory workingDirectory,
  }) {
    workingDirectory.createSync(recursive: true);
    final sourcePath = '${workingDirectory.path}/source-v26.sqlite';
    final snapshotPath = '${workingDirectory.path}/snapshot-v26.sqlite';
    final failedPath = '${workingDirectory.path}/failed-upgrade.sqlite';
    final mutatedPath = '${workingDirectory.path}/mutated-authority.sqlite';
    final membershipMutatedPath =
        '${workingDirectory.path}/mutated-bundle-membership.sqlite';
    final upgradedPath = '${workingDirectory.path}/upgraded-v27.sqlite';
    final restoreStagePath =
        '${workingDirectory.path}/restore-stage-v26.sqlite';
    for (final path in <String>[
      sourcePath,
      snapshotPath,
      failedPath,
      mutatedPath,
      membershipMutatedPath,
      upgradedPath,
      restoreStagePath,
    ]) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }

    final v26Migrations = authoringSchemaMigrations
        .where((migration) => migration.version <= 26)
        .toList(growable: false);
    final source = sqlite3.open(sourcePath);
    source.execute('PRAGMA foreign_keys = ON');
    DatabaseSchemaManager(migrations: v26Migrations).ensureSchema(source);
    // Fresh-table definitions describe the latest schema. Remove the V27
    // column so this generated fixture represents an on-disk V26 database.
    source.execute('ALTER TABLE story_memory_chunks DROP COLUMN owner_id');
    source.execute('PRAGMA journal_mode = WAL');
    source.execute('''
      CREATE TABLE eval_recovery_drill_payload (
        id TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    source.execute(
      "INSERT INTO eval_recovery_drill_payload VALUES ('wal-commit', 'durable')",
    );
    _seedEvaluationAuthorityGraph(source);
    final beforeAuditRoot = _auditRoot(source);
    // VACUUM INTO is an online, transactionally consistent SQLite snapshot and
    // includes committed WAL content. A raw File.copy of the main DB does not.
    source.execute('VACUUM INTO ?', <Object?>[snapshotPath]);
    source.dispose();
    final snapshotFileHash = _fileSha256(snapshotPath);

    File(snapshotPath).copySync(mutatedPath);
    final mutated = sqlite3.open(mutatedPath);
    mutated.execute(
      "UPDATE eval_trial_attempts SET lease_owner = 'mutated-worker'",
    );
    final authorityMutationDetected = _auditRoot(mutated) != beforeAuditRoot;
    mutated.dispose();

    File(snapshotPath).copySync(membershipMutatedPath);
    final membershipMutated = sqlite3.open(membershipMutatedPath);
    membershipMutated.execute(
      'DROP TRIGGER prevent_generation_bundle_releases_delete',
    );
    membershipMutated.execute('DELETE FROM generation_bundle_releases');
    final bundleMembershipMutationDetected =
        _auditRoot(membershipMutated) != beforeAuditRoot;
    membershipMutated.dispose();

    File(snapshotPath).copySync(failedPath);
    final failedDb = sqlite3.open(failedPath);
    var failedMigrationRolledBack = false;
    try {
      DatabaseSchemaManager(
        migrations: <SchemaMigration>[
          SchemaMigration(
            version: 27,
            description: 'injected crash after V27 DDL',
            migrate: (database) {
              database.execute(
                'ALTER TABLE story_memory_chunks ADD COLUMN owner_id '
                "TEXT NOT NULL DEFAULT ''",
              );
              database.execute('''
                INSERT OR IGNORE INTO schema_compatibility_contracts (
                  schema_version, min_reader_version, min_writer_version,
                  upgrade_policy_json, rollback_policy_json, created_at_ms
                ) VALUES (
                  27, 27, 27,
                  '{"policy":"forward-only-v27","requiresBackup":true}',
                  '{"policy":"restore-v26-backup","inPlaceDowngrade":false}',
                  0
                )
              ''');
              database.execute('CREATE TABLE crash_injected_partial(id INT)');
              throw StateError('injected migration crash');
            },
          ),
        ],
      ).ensureSchema(failedDb);
    } on StateError {
      final version = _version(failedDb);
      final partial = failedDb.select(
        "SELECT 1 FROM sqlite_master WHERE name = 'crash_injected_partial'",
      );
      final v27Contract = failedDb.select(
        'SELECT 1 FROM schema_compatibility_contracts '
        'WHERE schema_version = 27',
      );
      failedMigrationRolledBack =
          version == 26 &&
          partial.isEmpty &&
          !_columnExists(failedDb, 'story_memory_chunks', 'owner_id') &&
          v27Contract.isEmpty;
    } finally {
      failedDb.dispose();
    }

    File(snapshotPath).copySync(upgradedPath);
    final upgraded = sqlite3.open(upgradedPath);
    upgraded.execute('PRAGMA foreign_keys = ON');
    final currentManager = DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    );
    currentManager.ensureSchema(upgraded);
    final firstSchemaRoot = _schemaRoot(upgraded);
    currentManager.ensureSchema(upgraded);
    final upgradeIdempotent =
        _version(upgraded) == 27 && firstSchemaRoot == _schemaRoot(upgraded);
    final walCommitRecovered =
        upgraded
            .select(
              "SELECT value FROM eval_recovery_drill_payload WHERE id = 'wal-commit'",
            )
            .single['value'] ==
        'durable';
    var oldReaderRejected = false;
    final oldReader = sqlite3.open(upgradedPath, mode: OpenMode.readOnly);
    try {
      DatabaseSchemaManager(migrations: v26Migrations).ensureSchema(oldReader);
    } on UnsupportedDatabaseSchemaVersion {
      oldReaderRejected = true;
    } finally {
      oldReader.dispose();
    }
    var oldWriterRejected = false;
    try {
      DatabaseSchemaManager(migrations: v26Migrations).ensureSchema(upgraded);
    } on UnsupportedDatabaseSchemaVersion {
      oldWriterRejected = true;
    }
    upgraded.execute(
      "UPDATE eval_recovery_drill_payload SET value = 'mutated-after-upgrade'",
    );
    upgraded.dispose();

    // Restore through a validated staging database, then atomically rename.
    File(snapshotPath).copySync(restoreStagePath);
    final stage = sqlite3.open(restoreStagePath, mode: OpenMode.readOnly);
    final integrityCheck =
        stage.select('PRAGMA integrity_check').single.values.single as String;
    final afterRestoreAuditRoot = _auditRoot(stage);
    stage.dispose();
    if (integrityCheck != 'ok' || afterRestoreAuditRoot != beforeAuditRoot) {
      throw StateError('recovery snapshot validation failed before rename');
    }
    File(restoreStagePath).renameSync(upgradedPath);

    return AgentEvaluationMigrationRecoveryDrillReport(
      sourceVersion: 26,
      targetVersion: 27,
      snapshotFileHash: snapshotFileHash,
      beforeAuditRoot: beforeAuditRoot,
      afterRestoreAuditRoot: afterRestoreAuditRoot,
      authorityTableCount: _authorityTableNames(stagePath: snapshotPath).length,
      authorityMutationDetected: authorityMutationDetected,
      bundleMembershipMutationDetected: bundleMembershipMutationDetected,
      walCommitRecovered: walCommitRecovered,
      upgradeIdempotent: upgradeIdempotent,
      failedMigrationRolledBack: failedMigrationRolledBack,
      oldReaderRejected: oldReaderRejected,
      oldWriterRejected: oldWriterRejected,
      integrityCheck: integrityCheck,
    );
  }

  static int _version(Database db) =>
      db.select('PRAGMA user_version').single['user_version'] as int;

  static bool _columnExists(Database db, String table, String column) => db
      .select("SELECT name FROM pragma_table_info('$table')")
      .any((row) => row['name'] == column);

  static String _auditRoot(Database db) {
    final tables = _authorityTableNames(db: db);
    final tableRoots = <String, Object?>{};
    for (final table in tables) {
      final result = db.select('SELECT * FROM $table');
      final canonicalRows =
          result
              .map(
                (row) => <String, Object?>{
                  for (final column in result.columnNames) column: row[column],
                },
              )
              .map(AgentEvaluationHashes.canonicalJson)
              .toList()
            ..sort();
      tableRoots[table] = canonicalRows;
    }
    return AgentEvaluationHashes.domainHash(
      'eval-migration-recovery-audit-root-v3',
      <String, Object?>{'schemaVersion': _version(db), 'tables': tableRoots},
    );
  }

  static List<String> _authorityTableNames({Database? db, String? stagePath}) {
    final owned = db ?? sqlite3.open(stagePath!, mode: OpenMode.readOnly);
    try {
      return owned
          .select('''SELECT name FROM sqlite_master
               WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                 AND (
                   name LIKE 'eval_%'
                   OR name LIKE 'prompt_%'
                   OR name LIKE 'generation_%'
                   OR name LIKE 'evaluation_%'
                   OR name LIKE 'story_generation_run_%'
                   OR name = 'schema_compatibility_contracts'
                 )
               ORDER BY name''')
          .map((row) => row['name'] as String)
          .toList(growable: false);
    } finally {
      if (db == null) owned.dispose();
    }
  }

  static void _seedEvaluationAuthorityGraph(Database db) {
    final cell = AgentEvaluationCellDefinition(
      generationBundleHash: _digest('b'),
      sutModelRouteHash: _digest('a'),
      scenarioReleaseHash: _digest('c'),
      decodingConfigHash: _digest('d'),
    );
    db.execute(
      '''INSERT INTO prompt_releases (
           release_id, template_id, semantic_version, language, content_hash,
           system_template, user_template, variables_schema_json,
           output_schema_json, renderer_release, parser_release,
           repair_policy_json, variables_schema_hash, output_schema_hash,
           owner, change_note, created_at_ms
         ) VALUES ('recovery-prompt', 'recovery-template', '1.0.0', 'zh-CN',
           ?, 'system', 'user', '{}', '{}', 'renderer-v1', 'parser-v1',
           '{}', ?, ?, 'recovery-drill', 'authority membership', 1)''',
      <Object?>[_digest('7'), _digest('8'), _digest('9')],
    );
    db.execute(
      '''INSERT INTO generation_bundles
         (bundle_hash, bundle_id, releases_json, created_at_ms)
         VALUES (?, 'recovery-bundle', '[]', 1)''',
      <Object?>[cell.generationBundleHash],
    );
    db.execute(
      '''INSERT INTO generation_bundle_releases (
           bundle_hash, stage_id, call_site_id, variant_id, prompt_release_id
         ) VALUES (?, 'generation', 'recovery-call-site', 'default',
           'recovery-prompt')''',
      <Object?>[cell.generationBundleHash],
    );
    db.execute(
      '''INSERT INTO evaluation_bundles (
           evaluation_bundle_hash, evaluator_bundle_id, verifiers_json,
           judges_json, rubric_release_hash, aggregator_release_hash,
           failure_taxonomy_hash, blinding_policy_version, created_at_ms
         ) VALUES (?, 'recovery-evaluator', '[]', '[]', ?, ?, ?,
           'blind-v1', 1)''',
      <Object?>[_digest('e'), _digest('1'), _digest('2'), _digest('3')],
    );
    db.execute(
      '''INSERT INTO eval_scenario_sets (
           scenario_set_release_hash, set_id, version, manifest_hash,
           created_at_ms
         ) VALUES (?, 'recovery-set', '1.0.0', ?, 1)''',
      <Object?>[_digest('f'), _digest('4')],
    );
    db.execute(
      '''INSERT INTO eval_scenarios (
           scenario_release_hash, scenario_set_release_hash, scenario_id,
           version, fixture_hash, isolation_mode,
           verifier_release_refs_json, rubric_release_ref,
           expected_terminal_state, required_failure_codes_json,
           allowed_failure_codes_json, forbidden_failure_codes_json,
           outcome_comparator_release_ref, forbidden_side_effects_json,
           accept_expected, scenario_json, created_at_ms
         ) VALUES (?, ?, 'recovery-scenario', '1.0.0', ?, 'independent',
           '[]', 'rubric-v1', 'accepted', '[]', '[]', '[]',
           'comparator-v1', '[]', 1, '{}', 1)''',
      <Object?>[cell.scenarioReleaseHash, _digest('f'), _digest('5')],
    );
    db.execute(
      '''INSERT INTO eval_experiments (
           experiment_id, manifest_json, manifest_hash,
           scenario_set_release_hash, evaluation_bundle_hash,
           expected_cell_set_hash, expected_slot_set_hash,
           trials_per_cell, created_at_ms
         ) VALUES ('recovery-experiment', '{}', ?, ?, ?, ?, ?, 1, 1)''',
      <Object?>[
        _digest('6'),
        _digest('f'),
        _digest('e'),
        AgentEvaluationLedger.canonicalCellSetHash(<String>[cell.cellId]),
        AgentEvaluationLedger.canonicalSlotSetHash(<String>[cell.cellId], 1),
      ],
    );
    final ledger = AgentEvaluationLedger(db: db);
    ledger.createOrValidateExecution(
      executionId: 'recovery-execution',
      experimentId: 'recovery-experiment',
      cells: <AgentEvaluationCellDefinition>[cell],
      createdAtMs: 2,
    );
    final lease = ledger.claimNextSlot(
      executionId: 'recovery-execution',
      owner: 'recovery-worker',
      nowMs: 3,
      leaseDurationMs: 100,
    );
    if (lease == null) {
      throw StateError('recovery drill could not create an authority lease');
    }
    ledger.startAttempt(
      lease: lease,
      attemptNo: 1,
      runId: 'recovery-run',
      kind: 'content',
      startedAtMs: 4,
    );
  }

  static String _digest(String character) =>
      List<String>.filled(64, character).join();

  static String _schemaRoot(Database db) {
    final rows = db.select('''SELECT type, name, sql FROM sqlite_master
         WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name''');
    return AgentEvaluationHashes.domainHash(
      'eval-schema-root-v1',
      rows
          .map(
            (row) => <String, Object?>{
              'type': row['type'],
              'name': row['name'],
              'sql': row['sql'],
            },
          )
          .toList(growable: false),
    );
  }

  static String _fileSha256(String path) {
    final digest = const DartSha256().hashSync(File(path).readAsBytesSync());
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
