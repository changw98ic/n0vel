import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_sandbox_seal_verifier.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('private verifier emits exactly one frozen-schema line', () {
    final root = Directory.systemTemp.createTempSync('seal-verifier-test-');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final path = '${root.path}/seal.sqlite';
    final database = sqlite3.open(path);
    for (final table in agentEvaluationSealTableNames) {
      database.execute('CREATE TABLE $table(value TEXT NOT NULL)');
      database.execute('INSERT INTO $table VALUES (?)', <Object?>['evidence']);
    }
    database.dispose();
    final output = StringBuffer();
    final errors = StringBuffer();

    final code = runAgentEvaluationSealVerifierCommand(
      <String>[agentEvaluationSealVerifierArgument, path],
      stdoutSink: output,
      stderrSink: errors,
    );

    expect(code, 0);
    expect(errors.toString(), isEmpty);
    final lines = const LineSplitter()
        .convert(output.toString())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    expect(lines, hasLength(1));
    final result = jsonDecode(lines.single) as Map<String, Object?>;
    expect(result.keys.toSet(), <String>{
      'schemaVersion',
      'fileHash',
      'tables',
    });
    expect(result['schemaVersion'], agentEvaluationSealVerificationSchema);
    expect(
      (result['tables'] as Map).keys.toSet(),
      agentEvaluationSealTableNames.toSet(),
    );
  });

  test('exact private marker with malformed arguments fails closed', () {
    final output = StringBuffer();
    final errors = StringBuffer();

    final code = runAgentEvaluationSealVerifierCommand(
      const <String>[agentEvaluationSealVerifierArgument],
      stdoutSink: output,
      stderrSink: errors,
    );

    expect(code, 64);
    expect(output.toString(), isEmpty);
    expect(errors.toString(), contains('invalid private seal verifier'));
  });

  test('normal application arguments are not consumed', () {
    expect(runAgentEvaluationSealVerifierCommand(const <String>[]), isNull);
    expect(
      runAgentEvaluationSealVerifierCommand(const <String>['--normal']),
      isNull,
    );
  });
}
