import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/authoring_db_schema.dart';
import 'package:novel_writer/app/state/db_schema_manager.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_migration_recovery_drill.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('V26 to V27 upgrade, WAL snapshot, rollback and restore are proven', () {
    final root = Directory.systemTemp.createTempSync('eval-recovery-drill-');
    addTearDown(() => root.deleteSync(recursive: true));

    final report = AgentEvaluationMigrationRecoveryDrill.run(
      workingDirectory: root,
    );

    expect(report.passed, isTrue);
    expect(report.sourceVersion, 26);
    expect(report.targetVersion, 27);
    expect(report.snapshotFileHash, matches(r'^[a-f0-9]{64}$'));
    expect(report.beforeAuditRoot, report.afterRestoreAuditRoot);
    expect(report.authorityTableCount, greaterThanOrEqualTo(45));
    expect(report.authorityMutationDetected, isTrue);
    expect(report.bundleMembershipMutationDetected, isTrue);
    expect(report.oldReaderRejected, isTrue);
    expect(report.oldWriterRejected, isTrue);
    expect(report.reportHash, matches(r'^[a-f0-9]{64}$'));
  });

  test('compatibility JSON, migration list and SQLite contracts agree', () {
    final matrix =
        jsonDecode(
              File('docs/schema-compatibility-matrix.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    final releases = (matrix['releases'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    DatabaseSchemaManager(
      migrations: authoringSchemaMigrations,
    ).ensureSchema(db);
    final contracts = db.select(
      'SELECT * FROM schema_compatibility_contracts ORDER BY schema_version',
    );

    expect(matrix['currentVersion'], authoringSchemaMigrations.last.version);
    expect(releases, hasLength(contracts.length));
    for (var index = 0; index < contracts.length; index += 1) {
      expect(releases[index]['version'], contracts[index]['schema_version']);
      expect(
        releases[index]['minReaderVersion'],
        contracts[index]['min_reader_version'],
      );
      expect(
        releases[index]['minWriterVersion'],
        contracts[index]['min_writer_version'],
      );
    }
  });

  test(
    'SIGKILL during a SQLite migration transaction leaves V25 intact',
    () async {
      if (Platform.isWindows) return;
      final root = Directory.systemTemp.createTempSync('eval-kill-drill-');
      addTearDown(() => root.deleteSync(recursive: true));
      final databasePath = '${root.path}/kill.sqlite';
      final db = sqlite3.open(databasePath);
      DatabaseSchemaManager(
        migrations: authoringSchemaMigrations
            .where((migration) => migration.version <= 25)
            .toList(growable: false),
      ).ensureSchema(db);
      db.dispose();
      final script = File('${root.path}/kill_migration.dart');
      script.writeAsStringSync('''
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
void main(List<String> args) {
  final db = sqlite3.open(args.single);
  db.execute('BEGIN IMMEDIATE');
  db.execute('CREATE TABLE crash_partial(id INTEGER)');
  db.execute('PRAGMA user_version = 26');
  Process.killPid(pid, ProcessSignal.sigkill);
}
''', flush: true);
      final process = await Process.run('dart', <String>[
        '--packages=.dart_tool/package_config.json',
        script.path,
        databasePath,
      ], workingDirectory: Directory.current.path);
      expect(process.exitCode, isNot(0));

      final recovered = sqlite3.open(databasePath);
      addTearDown(recovered.dispose);
      expect(
        recovered.select('PRAGMA user_version').single['user_version'],
        25,
      );
      expect(
        recovered.select(
          "SELECT 1 FROM sqlite_master WHERE name = 'crash_partial'",
        ),
        isEmpty,
      );
      expect(
        recovered.select('PRAGMA integrity_check').single.values.single,
        'ok',
      );
    },
  );
}
