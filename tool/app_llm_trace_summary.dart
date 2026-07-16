import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_trace_summary.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }

  final inputPath = _requiredFlag(arguments, '--input');
  final configuredSceneConcurrency = _positiveIntFlag(
    arguments,
    '--scene-concurrency',
  );
  final configuredRequestConcurrency = _positiveIntFlag(
    arguments,
    '--request-concurrency',
  );
  final file = File(inputPath);
  if (!await file.exists()) {
    throw ArgumentError.value(inputPath, '--input', 'file does not exist');
  }

  final entries = <Map<String, Object?>>[];
  var lineNumber = 0;
  await for (final line
      in file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    lineNumber++;
    if (line.trim().isEmpty) continue;
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      throw FormatException('trace line $lineNumber is not a JSON object');
    }
    entries.add(<String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key is String) entry.key as String: entry.value,
    });
  }

  final summary = AppLlmTraceSummary.fromJsonEntries(
    entries,
    configuredSceneConcurrency: configuredSceneConcurrency,
    configuredRequestConcurrency: configuredRequestConcurrency,
  );
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'input': file.absolute.path,
      'summary': summary.toJson(),
    }),
  );
}

String _requiredFlag(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) {
    throw ArgumentError('missing required $name\n$_usage');
  }
  final value = arguments[index + 1].trim();
  if (value.isEmpty || value.startsWith('--')) {
    throw ArgumentError('missing value for $name\n$_usage');
  }
  return value;
}

int _positiveIntFlag(List<String> arguments, String name) {
  final raw = _requiredFlag(arguments, name);
  final value = int.tryParse(raw);
  if (value == null || value <= 0) {
    throw ArgumentError.value(raw, name, 'must be a positive integer');
  }
  return value;
}

const _usage = '''
Usage:
  dart run tool/app_llm_trace_summary.dart \\
    --input <llm-call-trace.jsonl> \\
    --scene-concurrency <configured scenes> \\
    --request-concurrency <configured requests>

The JSON output keeps configured concurrency separate from concurrency observed
from exact or explicitly labelled inferred timing intervals.
''';
