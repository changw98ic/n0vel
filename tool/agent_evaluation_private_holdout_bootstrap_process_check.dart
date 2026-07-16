import 'dart:io';

Future<void> main() async {
  final bootstrap = await Process.run(
    Platform.resolvedExecutable,
    <String>[
      'run',
      'tool/agent_evaluation_private_holdout_runner.dart',
      '--authority-db',
      '/missing/authority.sqlite',
      '--access-id',
      'process-check',
      '--private-plan',
      '/missing/private-plan.json',
      '--vault',
      '/missing/vault.sqlite',
      '--seed-file',
      '/missing/seed',
      '--key-id',
      'process-check-key',
    ],
    environment: <String, String>{
      'PATH': Platform.environment['PATH'] ?? '',
      'HOME': Platform.environment['HOME'] ?? '',
    },
    includeParentEnvironment: false,
  );
  if (bootstrap.exitCode != 64 ||
      bootstrap.stdout.toString().isNotEmpty ||
      bootstrap.stderr.toString().trim() !=
          'private production holdout preflight failed') {
    throw StateError('pure-Dart bootstrap process contract failed');
  }

  final runtime = File(
    'build/macos/Build/Products/Release/'
    'novel_writer.app/Contents/MacOS/novel_writer',
  ).absolute;
  if (runtime.existsSync() &&
      Platform.environment['RUN_PRIVATE_HOLDOUT_RUNTIME_PROCESS_CHECK'] ==
          '1') {
    final process = await Process.start(
      runtime.path,
      const <String>[],
      environment: const <String, String>{},
      includeParentEnvironment: false,
    );
    final stdoutResult = process.stdout.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final stderrResult = process.stderr.fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final exit = await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    final directStdout = String.fromCharCodes(await stdoutResult);
    final directStderr = String.fromCharCodes(await stderrResult);
    if (exit != 2 ||
        directStdout.isNotEmpty ||
        !directStderr.trim().endsWith('private production holdout failed')) {
      throw StateError('fixed Flutter runtime process contract failed');
    }
  }
  stdout.writeln('private holdout bootstrap process contract passed');
}
