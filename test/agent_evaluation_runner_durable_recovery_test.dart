import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync(
      'agent-evaluation-runner-recovery-',
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  for (final crashStage in <String>[
    'prepared',
    'accepted',
    'outboxCompleted',
    'finalPersisted',
  ]) {
    test(
      'successor lease resumes $crashStage snapshot without provider replay',
      () async {
        final caseRoot = Directory('${root.path}/$crashStage')..createSync();
        _seedFixture('${caseRoot.path}/fixture.sqlite');
        sqlite3.open('${caseRoot.path}/production.sqlite').dispose();

        final crashed = await _runProcess(
          mode: 'crash',
          crashStage: crashStage,
          root: caseRoot,
        );
        expect(crashed.exitCode, isNot(0), reason: crashed.stderr);
        expect(
          File('${caseRoot.path}/crash-database-path.txt').existsSync(),
          isTrue,
        );
        final preSealAuthority = sqlite3.open(
          '${caseRoot.path}/authority.sqlite',
          mode: OpenMode.readOnly,
        );
        try {
          final preSealCheckpoints = preSealAuthority.select(
            '''SELECT database_path FROM eval_sandbox_recovery_checkpoints
               ORDER BY checkpoint_no''',
          );
          expect(preSealCheckpoints, isNotEmpty);
          expect(
            preSealCheckpoints.every(
              (row) => File(row['database_path'] as String).existsSync(),
            ),
            isTrue,
          );
        } finally {
          preSealAuthority.dispose();
        }
        await Future<void>.delayed(const Duration(milliseconds: 220));

        final recovered = await _runProcess(
          mode: 'recover',
          crashStage: crashStage,
          root: caseRoot,
        );
        expect(
          recovered.exitCode,
          0,
          reason: '${recovered.stderr}\n${recovered.stdout}',
        );
        expect(recovered.stdout, contains('All tests passed'));

        final providerCalls = File(
          '${caseRoot.path}/provider-calls.log',
        ).readAsLinesSync();
        expect(providerCalls, hasLength(1));
        final crashedPath = File(
          '${caseRoot.path}/crash-database-path.txt',
        ).readAsStringSync();
        final recoveredPath = File(
          '${caseRoot.path}/recover-database-path.txt',
        ).readAsStringSync();
        expect(recoveredPath, isNot(crashedPath));
        expect(File(crashedPath).existsSync(), isFalse);
        expect(File(recoveredPath).existsSync(), isFalse);

        final authority = sqlite3.open(
          '${caseRoot.path}/authority.sqlite',
          mode: OpenMode.readOnly,
        );
        try {
          final checkpoints = authority.select(
            '''SELECT * FROM eval_sandbox_recovery_checkpoints
               ORDER BY checkpoint_no''',
          );
          expect(checkpoints, hasLength(4));
          expect(checkpoints.map((row) => row['stage']).toList(), <String>[
            'prepared',
            'accepted',
            'outboxCompleted',
            'finalPersisted',
          ]);
          expect(
            checkpoints.map((row) => row['database_path']).toSet(),
            hasLength(4),
          );
          expect(
            checkpoints.every(
              (row) => !File(row['database_path'] as String).existsSync(),
            ),
            isTrue,
          );
          expect(
            checkpoints.every(
              (row) => row['original_lease_owner'] == 'worker-a',
            ),
            isTrue,
          );
          expect(
            authority.select('SELECT * FROM eval_sandbox_recovery_seals'),
            hasLength(1),
          );
          final generations = authority.select(
            'SELECT * FROM eval_sandbox_generations',
          );
          expect(generations, hasLength(1));
          final generationPath = generations.single['database_path'] as String;
          expect(File(generationPath).existsSync(), isTrue);
          final epochArtifacts = File(generationPath).parent
              .listSync(followLinks: false)
              .where(
                (entity) => entity.uri.pathSegments
                    .where((segment) => segment.isNotEmpty)
                    .last
                    .startsWith('epoch-'),
              )
              .map((entity) => entity.absolute.path)
              .toList(growable: false);
          expect(epochArtifacts, <String>[File(generationPath).absolute.path]);
          final slot = authority
              .select('SELECT * FROM eval_trial_slots')
              .single;
          expect(slot['status'], 'sealed');
          expect(slot['lease_epoch'], 2);
        } finally {
          authority.dispose();
        }
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  }

  test(
    'tampered recovery file fails closed before provider replay',
    () async {
      final caseRoot = Directory('${root.path}/tampered')..createSync();
      _seedFixture('${caseRoot.path}/fixture.sqlite');
      sqlite3.open('${caseRoot.path}/production.sqlite').dispose();
      final crashed = await _runProcess(
        mode: 'crash',
        crashStage: 'prepared',
        root: caseRoot,
      );
      expect(crashed.exitCode, isNot(0), reason: crashed.stderr);
      final authority = sqlite3.open(
        '${caseRoot.path}/authority.sqlite',
        mode: OpenMode.readOnly,
      );
      final snapshotPath =
          authority.select(
                '''SELECT database_path FROM eval_sandbox_recovery_checkpoints
             WHERE stage = 'prepared' ''',
              ).single['database_path']
              as String;
      authority.dispose();
      File(
        snapshotPath,
      ).writeAsBytesSync(<int>[1, 2, 3, 4], mode: FileMode.append, flush: true);
      await Future<void>.delayed(const Duration(milliseconds: 220));

      final recovered = await _runProcess(
        mode: 'recover',
        crashStage: 'prepared',
        root: caseRoot,
      );
      expect(recovered.exitCode, isNot(0));
      expect(
        '${recovered.stdout}\n${recovered.stderr}',
        contains('hash mismatch'),
      );
      expect(
        File('${caseRoot.path}/provider-calls.log').readAsLinesSync(),
        hasLength(1),
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'terminal cleanup failure retains files without provider replay',
    () async {
      final caseRoot = Directory('${root.path}/cleanup-failure')..createSync();
      _seedFixture('${caseRoot.path}/fixture.sqlite');
      sqlite3.open('${caseRoot.path}/production.sqlite').dispose();

      final completed = await _runProcess(
        mode: 'recover',
        crashStage: 'prepared',
        root: caseRoot,
        cleanupFault: true,
      );
      expect(completed.exitCode, 0, reason: completed.stderr);
      final blockers = Directory('${caseRoot.path}/durable')
          .listSync(recursive: true, followLinks: false)
          .whereType<Directory>()
          .where((directory) => directory.path.endsWith('.cleanup-fault'))
          .toList(growable: false);
      expect(blockers, hasLength(1));

      final rerun = await _runProcess(
        mode: 'recover',
        crashStage: 'prepared',
        root: caseRoot,
      );
      expect(rerun.exitCode, 0, reason: rerun.stderr);
      expect(
        File('${caseRoot.path}/provider-calls.log').readAsLinesSync(),
        hasLength(1),
      );
      final authority = sqlite3.open(
        '${caseRoot.path}/authority.sqlite',
        mode: OpenMode.readOnly,
      );
      try {
        expect(
          authority
              .select('SELECT status FROM eval_trial_slots')
              .single['status'],
          'sealed',
        );
      } finally {
        authority.dispose();
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

void _seedFixture(String path) {
  final database = sqlite3.open(path);
  try {
    database.execute(
      'CREATE TABLE recovery_state(stage TEXT PRIMARY KEY NOT NULL)',
    );
  } finally {
    database.dispose();
  }
}

Future<({int exitCode, String stdout, String stderr})> _runProcess({
  required String mode,
  required String crashStage,
  required Directory root,
  bool cleanupFault = false,
}) async {
  final process = await Process.start(
    _flutterExecutable(),
    <String>[
      'test',
      '--no-pub',
      '--concurrency=1',
      'test/test_support/agent_evaluation_runner_recovery_process.dart',
    ],
    workingDirectory: Directory.current.path,
    environment: <String, String>{
      ...Platform.environment,
      'AGENT_EVAL_RECOVERY_MODE': mode,
      'AGENT_EVAL_RECOVERY_STAGE': crashStage,
      'AGENT_EVAL_RECOVERY_ROOT': root.path,
      if (cleanupFault) 'AGENT_EVAL_RECOVERY_CLEANUP_FAULT': '1',
    },
  );
  final stdout = process.stdout.transform(systemEncoding.decoder).join();
  final stderr = process.stderr.transform(systemEncoding.decoder).join();
  final exitCode = await process.exitCode;
  return (exitCode: exitCode, stdout: await stdout, stderr: await stderr);
}

String _flutterExecutable() {
  final resolved = File(Platform.resolvedExecutable).absolute;
  if (resolved.uri.pathSegments.last == 'flutter_tester') {
    final cache = resolved.parent.parent.parent.parent;
    final flutter = File('${cache.parent.path}/flutter');
    if (flutter.existsSync()) return flutter.path;
  }
  return 'flutter';
}
