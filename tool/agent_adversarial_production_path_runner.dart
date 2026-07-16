import 'dart:io';

Future<void> main(List<String> arguments) async {
  String? value(String name) {
    final index = arguments.indexOf(name);
    if (index < 0 || index + 1 >= arguments.length) return null;
    return arguments[index + 1];
  }

  final output = value('--output');
  final work = value('--work-dir');
  if (output == null || work == null) {
    stderr.writeln('usage: --output PATH --work-dir PATH');
    exitCode = 64;
    return;
  }

  final flutter = _flutterExecutable();
  final result = await Process.start(flutter, <String>[
    'test',
    '--no-pub',
    '--dart-define=AGENT_ADVERSARIAL_OUTPUT=${Uri.encodeComponent(output)}',
    '--dart-define=AGENT_ADVERSARIAL_WORK=${Uri.encodeComponent(work)}',
    'tool/agent_adversarial_production_path_host_test.dart',
  ], mode: ProcessStartMode.inheritStdio);
  exitCode = await result.exitCode;
  if (exitCode == 0) stdout.writeln(File(output).absolute.path);
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
