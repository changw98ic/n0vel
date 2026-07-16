import 'dart:convert';
import 'dart:io';

const _argumentsEnvironmentKey = 'NOVEL_WRITER_CORPUS_IMPORT_ARGUMENTS';
const _resultEnvironmentKey = 'NOVEL_WRITER_CORPUS_IMPORT_RESULT';

Future<void> main(List<String> arguments) async {
  final projectDirectory = File.fromUri(Platform.script).parent.parent;
  final resultDirectory = await Directory.systemTemp.createTemp(
    'novel_writer_corpus_import_launcher_',
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
        'tool/novel_corpus_import_support.dart',
      ],
      workingDirectory: projectDirectory.path,
      environment: {
        ...Platform.environment,
        _argumentsEnvironmentKey: jsonEncode(arguments),
        _resultEnvironmentKey: resultFile.path,
      },
    );
    if (!resultFile.existsSync()) {
      stderr.writeln('Corpus import runtime failed before producing a report.');
      final output = '${process.stdout}\n${process.stderr}'.trim();
      if (output.isNotEmpty) stderr.writeln(output);
      exitCode = process.exitCode == 0 ? 1 : process.exitCode;
      return;
    }
    final envelope =
        jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
    final output = envelope['output']?.toString();
    if (output != null && output.isNotEmpty) stdout.writeln(output);
    final error = envelope['error']?.toString();
    if (error != null && error.isNotEmpty) stderr.writeln(error);
    exitCode = envelope['exitCode'] as int? ?? process.exitCode;
  } on ProcessException catch (error) {
    stderr.writeln('Unable to launch Flutter corpus importer: $error');
    exitCode = 69;
  } finally {
    if (resultDirectory.existsSync()) {
      await resultDirectory.delete(recursive: true);
    }
  }
}
