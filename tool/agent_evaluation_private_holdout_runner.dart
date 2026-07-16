import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'agent_evaluation_release_preflight.dart';

const _runtimeExecutable =
    'build/macos/Build/Products/Release/'
    'novel_writer.app/Contents/MacOS/novel_writer';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseOptions(arguments);
    final environment = Platform.environment;
    if (!Platform.isMacOS ||
        !validateAgentEvaluationPaidRelease(environment).passed) {
      throw const _PreflightFailure();
    }
    final deadlineMs = int.tryParse(environment['AGENT_EVAL_DEADLINE_MS']!);
    if (deadlineMs == null || deadlineMs <= 0) {
      throw const _PreflightFailure();
    }
    // The release worker is built before the experiment and pinned by the
    // frozen artifact hash. Rebuilding here would make the thing being
    // attested depend on mutable source/toolchain state after authorization.
    final executable = File(_runtimeExecutable).absolute;
    if (FileSystemEntity.typeSync(executable.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const _RuntimeFailure();
    }
    final digest = await _runFixedProcess(
      executable: '/usr/bin/shasum',
      arguments: <String>['-a', '256', executable.path],
      environment: const <String, String>{},
      timeout: const Duration(minutes: 1),
      retainStdout: true,
    );
    final digestValue = digest.stdout.trim().split(RegExp(r'\s+')).first;
    if (digest.exitCode != 0 ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digestValue) ||
        digestValue != environment['AGENT_EVAL_BUILD_ARTIFACT_HASH']) {
      throw const _RuntimeFailure();
    }

    final runtimeEnvironment = <String, String>{
      ...environment,
      'AGENT_EVAL_PRIVATE_AUTHORITY_DB': options['authority-db']!,
      'AGENT_EVAL_PRIVATE_ACCESS_ID': options['access-id']!,
      'AGENT_EVAL_PRIVATE_PLAN': options['private-plan']!,
      'AGENT_EVAL_PRIVATE_VAULT': options['vault']!,
      'AGENT_EVAL_PRIVATE_SEED_FILE': options['seed-file']!,
      'AGENT_EVAL_PRIVATE_KEY_ID': options['key-id']!,
      'AGENT_EVAL_PRIVATE_RUNTIME_BOOTSTRAPPED': '1',
    };
    final runtime = await _runFixedProcess(
      executable: executable.path,
      arguments: const <String>[],
      environment: runtimeEnvironment,
      timeout: Duration(milliseconds: deadlineMs + 60000),
      retainStdout: true,
    );
    if (runtime.exitCode != 0 || !_isStrictResponse(runtime.stdout)) {
      throw const _RuntimeFailure();
    }
    stdout.write(runtime.stdout);
  } on _PreflightFailure {
    stderr.writeln('private production holdout preflight failed');
    exitCode = 64;
  } catch (_) {
    stderr.writeln('private production holdout failed');
    exitCode = 2;
  }
}

Future<_FixedProcessResult> _runFixedProcess({
  required String executable,
  required List<String> arguments,
  required Map<String, String> environment,
  required Duration timeout,
  required bool retainStdout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    includeParentEnvironment: false,
  );
  final stdoutFuture = retainStdout
      ? _collectLimited(process.stdout, 4 * 1024 * 1024)
      : process.stdout.drain<void>().then((_) => '');
  final stderrFuture = process.stderr.drain<void>();
  try {
    final exit = await process.exitCode.timeout(timeout);
    final values = await Future.wait<Object?>(<Future<Object?>>[
      stdoutFuture,
      stderrFuture,
    ]);
    return _FixedProcessResult(exitCode: exit, stdout: values.first! as String);
  } on TimeoutException {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    throw const _RuntimeFailure();
  }
}

Future<String> _collectLimited(Stream<List<int>> source, int maxBytes) async {
  final bytes = <int>[];
  await for (final chunk in source) {
    if (bytes.length + chunk.length > maxBytes) {
      throw const _RuntimeFailure();
    }
    bytes.addAll(chunk);
  }
  return utf8.decode(bytes);
}

bool _isStrictResponse(String source) {
  try {
    final decoded = jsonDecode(source);
    const keys = <String>{
      'schemaVersion',
      'payloadJson',
      'signatureBase64',
      'redactedExecutionSummaryJson',
      'redactedScorecardJson',
      'redactedGateVerdictJson',
    };
    return decoded is Map<String, Object?> &&
        decoded['schemaVersion'] == 'production-holdout-process-response-v2' &&
        decoded.keys.toSet().difference(keys).isEmpty &&
        keys.difference(decoded.keys.toSet()).isEmpty &&
        decoded.values.every((value) => value is String);
  } on Object {
    return false;
  }
}

Map<String, String> _parseOptions(List<String> arguments) {
  const required = <String>{
    'authority-db',
    'access-id',
    'private-plan',
    'vault',
    'seed-file',
    'key-id',
  };
  if (arguments.length != required.length * 2) {
    throw const FormatException('invalid private holdout runner options');
  }
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final option = arguments[index];
    if (!option.startsWith('--')) {
      throw const FormatException('invalid private holdout runner options');
    }
    final key = option.substring(2);
    final value = arguments[index + 1];
    if (!required.contains(key) ||
        value.trim().isEmpty ||
        result.containsKey(key)) {
      throw const FormatException('invalid private holdout runner options');
    }
    result[key] = value;
  }
  if (required.difference(result.keys.toSet()).isNotEmpty) {
    throw const FormatException('invalid private holdout runner options');
  }
  return result;
}

final class _FixedProcessResult {
  const _FixedProcessResult({required this.exitCode, required this.stdout});

  final int exitCode;
  final String stdout;
}

final class _PreflightFailure implements Exception {
  const _PreflightFailure();
}

final class _RuntimeFailure implements Exception {
  const _RuntimeFailure();
}
