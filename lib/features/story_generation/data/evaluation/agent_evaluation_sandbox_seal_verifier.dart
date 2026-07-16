import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

/// Private process protocol implemented by both the signed application and
/// the development AOT verifier wrapper.
const agentEvaluationSealVerifierArgument =
    '--novel-writer-private-eval-seal-verifier-v1';
const agentEvaluationSealVerificationSchema =
    'eval-sandbox-seal-verification-v2';

const agentEvaluationSealTableNames = <String>[
  'story_generation_runs',
  'story_generation_candidate_proofs',
  'story_generation_commit_receipts',
  'eval_production_prepared_results',
  'eval_production_executor_results',
  'version_entries',
];

Map<String, Object?> verifyAgentEvaluationSandboxSeal(String inputPath) {
  final input = File(inputPath).absolute;
  if (!input.existsSync()) {
    throw const FileSystemException('seal file is missing');
  }
  final path = input.resolveSymbolicLinksSync();
  final uri = Uri.file(
    path,
  ).replace(queryParameters: const <String, String>{'immutable': '1'});
  final database = sqlite3.open(
    uri.toString(),
    mode: OpenMode.readOnly,
    uri: true,
  );
  try {
    final integrity = database.select('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.single.values.single != 'ok') {
      throw StateError('seal integrity check failed');
    }
    if (database.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw StateError('seal foreign-key check failed');
    }
    final tables = <String, Object?>{};
    for (final table in agentEvaluationSealTableNames) {
      final rows = database.select('SELECT * FROM main.$table ORDER BY rowid');
      final canonicalRows = <Object?>[
        for (final row in rows)
          <String, Object?>{
            for (final column in row.keys.toList()..sort()) column: row[column],
          },
      ];
      tables[table] = <String, Object?>{
        'count': rows.length,
        'rowsHash': _sha256(utf8.encode(jsonEncode(canonicalRows))),
      };
    }
    return <String, Object?>{
      'schemaVersion': agentEvaluationSealVerificationSchema,
      'fileHash': _sha256(File(path).readAsBytesSync()),
      'tables': tables,
    };
  } finally {
    database.dispose();
  }
}

/// Returns null when [arguments] are normal application arguments. Once the
/// exact private marker is present, malformed arguments fail closed and never
/// start the UI.
int? runAgentEvaluationSealVerifierCommand(
  List<String> arguments, {
  StringSink? stdoutSink,
  StringSink? stderrSink,
}) {
  if (arguments.isEmpty ||
      arguments.first != agentEvaluationSealVerifierArgument) {
    return null;
  }
  final output = stdoutSink ?? stdout;
  final errors = stderrSink ?? stderr;
  if (arguments.length != 2 || arguments[1].trim().isEmpty) {
    errors.writeln('invalid private seal verifier arguments');
    return 64;
  }
  try {
    final result = verifyAgentEvaluationSandboxSeal(arguments[1]);
    output.writeln(jsonEncode(result));
    return 0;
  } on FileSystemException catch (error) {
    errors.writeln('seal verifier input error: ${error.message}');
    return 66;
  } on Object catch (error) {
    errors.writeln('seal verifier rejected database: $error');
    return 65;
  }
}

String _sha256(List<int> bytes) {
  final digest = const DartSha256().hashSync(bytes);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
