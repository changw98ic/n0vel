import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 3) {
    stderr.writeln('usage: release_cas_worker request ready barrier');
    exitCode = 64;
    return;
  }
  final request = File(arguments[0]).absolute;
  final ready = File(arguments[1]).absolute;
  final barrier = File(arguments[2]).absolute;
  final receipt = File('${request.path}.receipt.json');
  if (receipt.existsSync()) receipt.deleteSync();
  final flutter = _flutterExecutable();
  final result = await Process.run(flutter, <String>[
    'test',
    '--no-pub',
    '--dart-define=AGENT_EVAL_CAS_REQUEST=${Uri.encodeComponent(request.path)}',
    '--dart-define=AGENT_EVAL_CAS_READY=${Uri.encodeComponent(ready.path)}',
    '--dart-define=AGENT_EVAL_CAS_BARRIER=${Uri.encodeComponent(barrier.path)}',
    '--dart-define=AGENT_EVAL_CAS_RECEIPT=${Uri.encodeComponent(receipt.path)}',
    'tool/agent_evaluation_release_cas_worker_host_test.dart',
  ], workingDirectory: Directory.current.path);
  if (result.exitCode != 0 || !receipt.existsSync()) {
    stderr.writeln('release CAS Flutter host failed (${result.exitCode})');
    final combined = '${result.stderr}\n${result.stdout}'.trim();
    final diagnostic = combined.length <= 8192
        ? combined
        : combined.substring(combined.length - 8192);
    if (diagnostic.isNotEmpty) stderr.writeln(diagnostic);
    exitCode = 70;
    return;
  }
  final source = receipt.readAsStringSync();
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?> ||
      decoded['exitCode'] is! int ||
      !const <int>{0, 21}.contains(decoded['exitCode'])) {
    stderr.writeln('release CAS Flutter host emitted an invalid receipt');
    exitCode = 70;
    return;
  }
  stdout.write(source);
  await stdout.flush();
  exitCode = decoded['exitCode'] as int;
}

String _flutterExecutable() {
  final configured = Platform.environment['FLUTTER_BIN'];
  if (configured != null && configured.trim().isNotEmpty) return configured;
  var directory = File(Platform.resolvedExecutable).parent;
  for (var index = 0; index < 3; index += 1) {
    directory = directory.parent;
  }
  final sibling = File('${directory.path}/flutter');
  return sibling.existsSync() ? sibling.path : 'flutter';
}
