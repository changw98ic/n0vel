import 'dart:convert';
import 'dart:io';

const _argumentsEnvironmentKey = 'NOVEL_WRITER_RAG_HYBRID_ARGUMENTS';
const _resultEnvironmentKey = 'NOVEL_WRITER_RAG_HYBRID_RESULT';

Future<void> main(List<String> arguments) async {
  final projectDirectory = File.fromUri(Platform.script).parent.parent;
  final resultDirectory = await Directory.systemTemp.createTemp(
    'novel_writer_rag_hybrid_launcher_',
  );
  final resultFile = File('${resultDirectory.path}/result.json');
  try {
    final process = await Process.run(
      'flutter',
      const [
        'test',
        '--no-pub',
        '--reporter',
        'expanded',
        'tool/rag_hybrid_evaluator_support.dart',
      ],
      workingDirectory: projectDirectory.path,
      environment: {
        ...Platform.environment,
        _argumentsEnvironmentKey: jsonEncode(arguments),
        _resultEnvironmentKey: resultFile.path,
      },
    );
    if (!resultFile.existsSync()) {
      stderr.writeln(
        'Hybrid evaluator runtime failed before producing a report.',
      );
      final output = '${process.stdout}\n${process.stderr}'.trim();
      if (output.isNotEmpty) stderr.writeln(output);
      exitCode = process.exitCode == 0 ? 1 : process.exitCode;
      return;
    }

    final envelope =
        jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
    final argumentError = envelope['argumentError']?.toString();
    if (argumentError != null) {
      stderr.writeln('Invalid evaluator arguments: $argumentError');
      exitCode = 64;
      return;
    }
    final runtimeError = envelope['runtimeError']?.toString();
    if (runtimeError != null) {
      stderr.writeln('Hybrid evaluator runtime failed: $runtimeError');
      final stackTrace = envelope['stackTrace']?.toString();
      if (stackTrace != null) stderr.writeln(stackTrace);
      exitCode = 1;
      return;
    }

    final report = envelope['report'] as Map<String, dynamic>;
    stdout.writeln(
      arguments.contains('--json')
          ? jsonEncode(report)
          : const JsonEncoder.withIndent('  ').convert(report),
    );
    exitCode = envelope['exitCode'] as int? ?? process.exitCode;
  } on ProcessException catch (error) {
    stderr.writeln('Unable to launch Flutter evaluator runtime: $error');
    exitCode = 69;
  } finally {
    if (resultDirectory.existsSync()) {
      await resultDirectory.delete(recursive: true);
    }
  }
}
