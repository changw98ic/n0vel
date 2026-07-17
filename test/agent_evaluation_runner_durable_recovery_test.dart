import 'dart:async';
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
        final crashBoundary = File('${caseRoot.path}/crash-boundary.txt');
        expect(
          crashBoundary.existsSync(),
          isTrue,
          reason:
              'child did not reach the intended checkpoint; '
              'exit=${crashed.exitCode}\n${crashed.stderr}\n${crashed.stdout}',
        );
        expect(
          crashed.exitCode,
          isNot(0),
          reason: '${crashed.stderr}\n${crashed.stdout}',
        );
        expect(
          crashBoundary.readAsStringSync(),
          crashStage,
          reason: 'only the intended post-checkpoint crash is recoverable',
        );
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
        expect(recovered.stdout, contains('RECOVERY_PROCESS_SEALED'));

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
      timeout: const Timeout(Duration(minutes: 4)),
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
      final crashBoundary = File('${caseRoot.path}/crash-boundary.txt');
      expect(
        crashBoundary.existsSync(),
        isTrue,
        reason:
            'child did not reach the intended checkpoint; '
            'exit=${crashed.exitCode}\n${crashed.stderr}\n${crashed.stdout}',
      );
      expect(
        crashed.exitCode,
        isNot(0),
        reason: '${crashed.stderr}\n${crashed.stdout}',
      );
      expect(
        crashBoundary.readAsStringSync(),
        'prepared',
        reason: 'only the intended post-checkpoint crash is recoverable',
      );
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
    timeout: const Timeout(Duration(minutes: 4)),
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
    timeout: const Timeout(Duration(minutes: 4)),
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
      '-r',
      'compact',
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
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutTerminal = Completer<void>();
  final stderrTerminal = Completer<void>();
  var stdoutClosed = false;
  var stderrClosed = false;
  final stdoutSubscription = process.stdout
      .transform(systemEncoding.decoder)
      .listen(
        stdoutBuffer.write,
        onError: (Object error, StackTrace stackTrace) {
          stderrBuffer.writeln('recovery child stdout error: $error');
          _completeOnce(stdoutTerminal);
        },
        onDone: () {
          stdoutClosed = true;
          _completeOnce(stdoutTerminal);
        },
        cancelOnError: true,
      );
  final stderrSubscription = process.stderr
      .transform(systemEncoding.decoder)
      .listen(
        stderrBuffer.write,
        onError: (Object error, StackTrace stackTrace) {
          stderrBuffer.writeln('recovery child stderr error: $error');
          _completeOnce(stderrTerminal);
        },
        onDone: () {
          stderrClosed = true;
          _completeOnce(stderrTerminal);
        },
        cancelOnError: true,
      );
  var timedOut = false;
  var killAccepted = false;
  var exitedAfterKill = false;
  var exitCode = -1;
  try {
    exitCode = await process.exitCode.timeout(const Duration(seconds: 90));
  } on TimeoutException {
    timedOut = true;
    killAccepted = await _killProcessTreeBounded(process, stderrBuffer);
    try {
      exitCode = await process.exitCode.timeout(const Duration(seconds: 3));
      exitedAfterKill = true;
    } on TimeoutException {
      // The bounded platform-specific tree kill already ran. Do not wait on
      // the same exit future again if the OS still has not reaped the parent.
    }
  }
  var streamsDrained = false;
  try {
    await Future.wait<void>([
      stdoutTerminal.future,
      stderrTerminal.future,
    ]).timeout(const Duration(seconds: 3));
    streamsDrained = stdoutClosed && stderrClosed;
  } on Object {
    await Future.wait<void>([
      _cancelBounded(stdoutSubscription),
      _cancelBounded(stderrSubscription),
    ]);
  }
  if (timedOut) {
    stderrBuffer.writeln(
      'recovery child exceeded 90 seconds; '
      'killAccepted=$killAccepted exitedAfterKill=$exitedAfterKill',
    );
  }
  if (!streamsDrained) {
    stderrBuffer.writeln(
      'recovery child pipes did not drain within 3 seconds; subscriptions '
      'were cancelled; treeKillAttempted=$timedOut '
      'treeKillAccepted=$killAccepted',
    );
  }
  return (
    exitCode: exitCode,
    stdout: stdoutBuffer.toString(),
    stderr: stderrBuffer.toString(),
  );
}

void _completeOnce(Completer<void> completer) {
  if (!completer.isCompleted) completer.complete();
}

Future<void> _cancelBounded(StreamSubscription<String> subscription) async {
  try {
    await subscription.cancel().timeout(const Duration(seconds: 1));
  } on Object {
    // The caller already records the bounded tree-kill/drain diagnostic.
  }
}

Future<bool> _killProcessTreeBounded(
  Process process,
  StringBuffer diagnostics,
) async {
  if (Platform.isWindows) {
    final taskkill = await _runBoundedCommand('taskkill', <String>[
      '/PID',
      '${process.pid}',
      '/T',
      '/F',
    ], timeout: const Duration(seconds: 3));
    if (taskkill == null || taskkill.exitCode != 0) {
      diagnostics.writeln(
        'recovery child taskkill tree failed: '
        '${taskkill?.stderr ?? 'bounded taskkill timeout'}',
      );
    }
    final parentKill = _killPid(process.pid);
    return taskkill?.exitCode == 0 || parentKill;
  }

  final descendants = await _posixDescendantPids(process.pid, diagnostics);
  var accepted = false;
  for (final pid in descendants.reversed) {
    accepted = _killPid(pid) || accepted;
  }
  final parentKill = _killPid(process.pid);
  if (!parentKill && descendants.isEmpty) {
    diagnostics.writeln(
      'recovery child process tree SIGKILL was not accepted for pid '
      '${process.pid}',
    );
  }
  return accepted || parentKill;
}

Future<List<int>> _posixDescendantPids(
  int rootPid,
  StringBuffer diagnostics,
) async {
  final psExecutable = File('/bin/ps').existsSync() ? '/bin/ps' : 'ps';
  final result = await _runBoundedCommand(psExecutable, const <String>[
    '-axo',
    'pid=,ppid=',
  ], timeout: const Duration(seconds: 2));
  if (result == null || result.exitCode != 0 || !result.streamsClosed) {
    diagnostics.writeln(
      'recovery child descendant discovery failed: '
      '${result?.stderr ?? 'bounded ps timeout'}',
    );
    return const <int>[];
  }
  final childrenByParent = <int, List<int>>{};
  for (final line in result.stdout.split('\n')) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length != 2) continue;
    final pid = int.tryParse(fields[0]);
    final parentPid = int.tryParse(fields[1]);
    if (pid == null || parentPid == null || pid <= 0) continue;
    childrenByParent.putIfAbsent(parentPid, () => <int>[]).add(pid);
  }
  final descendants = <int>[];
  void collect(int parentPid) {
    for (final childPid in childrenByParent[parentPid] ?? const <int>[]) {
      descendants.add(childPid);
      collect(childPid);
    }
  }

  collect(rootPid);
  return descendants;
}

bool _killPid(int pid) {
  try {
    return Process.killPid(pid, ProcessSignal.sigkill);
  } on ProcessException {
    return false;
  }
}

Future<({int exitCode, String stdout, String stderr, bool streamsClosed})?>
_runBoundedCommand(
  String executable,
  List<String> arguments, {
  required Duration timeout,
}) async {
  late final Process process;
  try {
    process = await Process.start(executable, arguments).timeout(timeout);
  } on Object {
    return null;
  }
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutTerminal = Completer<void>();
  final stderrTerminal = Completer<void>();
  var stdoutClosed = false;
  var stderrClosed = false;
  final stdoutSubscription = process.stdout
      .transform(systemEncoding.decoder)
      .listen(
        stdoutBuffer.write,
        onError: (Object error, StackTrace stackTrace) {
          stderrBuffer.writeln('bounded command stdout error: $error');
          _completeOnce(stdoutTerminal);
        },
        onDone: () {
          stdoutClosed = true;
          _completeOnce(stdoutTerminal);
        },
        cancelOnError: true,
      );
  final stderrSubscription = process.stderr
      .transform(systemEncoding.decoder)
      .listen(
        stderrBuffer.write,
        onError: (Object error, StackTrace stackTrace) {
          stderrBuffer.writeln('bounded command stderr error: $error');
          _completeOnce(stderrTerminal);
        },
        onDone: () {
          stderrClosed = true;
          _completeOnce(stderrTerminal);
        },
        cancelOnError: true,
      );
  int exitCode;
  try {
    exitCode = await process.exitCode.timeout(timeout);
  } on TimeoutException {
    _killPid(process.pid);
    try {
      await process.exitCode.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      // The command is auxiliary; its caller handles missing output.
    }
    await Future.wait<void>([
      _cancelBounded(stdoutSubscription),
      _cancelBounded(stderrSubscription),
    ]);
    return null;
  }
  try {
    await Future.wait<void>([
      stdoutTerminal.future,
      stderrTerminal.future,
    ]).timeout(const Duration(seconds: 1));
  } on Object {
    await Future.wait<void>([
      _cancelBounded(stdoutSubscription),
      _cancelBounded(stderrSubscription),
    ]);
  }
  return (
    exitCode: exitCode,
    stdout: stdoutBuffer.toString(),
    stderr: stderrBuffer.toString(),
    streamsClosed: stdoutClosed && stderrClosed,
  );
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
