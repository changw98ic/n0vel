import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_supervisor_connection.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 && arguments.single == '--child') {
    await AgentEvaluationSupervisorConnection.connect(Platform.environment);
    stdout.writeln('ready');
    await stdout.flush();
    await Completer<void>().future;
  }
  if (arguments.isNotEmpty) {
    throw StateError('invalid supervisor process test arguments');
  }

  final supervisor = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  Socket? supervisedChild;
  Process? process;
  try {
    const token = 'supervisor-process-contract-token';
    final authenticated = Completer<void>();
    supervisor.listen((socket) {
      supervisedChild = socket;
      utf8.decoder.bind(socket).transform(const LineSplitter()).listen((line) {
        if (line == token && !authenticated.isCompleted) {
          authenticated.complete();
        }
      });
    });
    process = await Process.start(
      Platform.resolvedExecutable,
      <String>[Platform.script.toFilePath(), '--child'],
      environment: <String, String>{
        'AGENT_EVAL_SUPERVISOR_PORT': '${supervisor.port}',
        'AGENT_EVAL_SUPERVISOR_TOKEN': token,
      },
      includeParentEnvironment: false,
    );
    final lines = utf8.decoder
        .bind(process.stdout)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final ready = lines.first;
    final stderrFuture = _collectLimited(process.stderr, 4096);
    await authenticated.future.timeout(const Duration(seconds: 10));
    if (await ready.timeout(const Duration(seconds: 10)) != 'ready') {
      throw StateError('supervised child did not become ready');
    }
    supervisedChild?.destroy();
    final code = await process.exitCode.timeout(const Duration(seconds: 10));
    final childStderr = await stderrFuture;
    if (code != 125 || childStderr.isNotEmpty) {
      throw StateError('supervisor death did not fence the release process');
    }
    stdout.writeln('release supervisor process contract passed');
  } finally {
    supervisedChild?.destroy();
    process?.kill(ProcessSignal.sigkill);
    await supervisor.close();
  }
}

Future<String> _collectLimited(
  Stream<List<int>> source,
  int maximumBytes,
) async {
  final bytes = <int>[];
  await for (final chunk in source) {
    if (bytes.length + chunk.length > maximumBytes) {
      throw StateError('release process output exceeded the test bound');
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}
