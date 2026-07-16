import 'dart:convert';
import 'dart:io';

const _required = <String>{
  'authority-db',
  'access-id',
  'private-plan',
  'vault',
  'seed-file',
  'key-id',
};

Future<void> main(List<String> arguments) async {
  File? response;
  try {
    final options = _parse(arguments);
    final dart = File(Platform.resolvedExecutable).absolute;
    final flutterRoot = dart.parent.parent.parent.parent.parent;
    final flutter = File('${flutterRoot.path}/bin/flutter');
    final childTest = File(
      '${Directory.current.path}/test/'
      'agent_evaluation_release_coordinator_private_child_test.dart',
    );
    if (!flutter.existsSync() || !childTest.existsSync()) {
      throw const FormatException('fixed purpose child runtime is missing');
    }
    response = File(
      '${File(options['vault']!).parent.path}/purpose-response-$pid.json',
    );
    if (response.existsSync()) {
      throw const FormatException('purpose child response already exists');
    }
    final result = await Process.run(
      flutter.path,
      <String>[
        'test',
        '--no-pub',
        childTest.path,
        '--plain-name',
        'purpose-built coordinator private child process',
        '-r',
        'compact',
      ],
      workingDirectory: Directory.current.path,
      environment: <String, String>{
        ...Platform.environment,
        'AGENT_EVAL_PURPOSE_COORDINATOR_CHILD': '1',
        'AGENT_EVAL_CHILD_AUTHORITY_DB': options['authority-db']!,
        'AGENT_EVAL_CHILD_ACCESS_ID': options['access-id']!,
        'AGENT_EVAL_CHILD_PRIVATE_PLAN': options['private-plan']!,
        'AGENT_EVAL_CHILD_VAULT': options['vault']!,
        'AGENT_EVAL_CHILD_SEED_FILE': options['seed-file']!,
        'AGENT_EVAL_CHILD_KEY_ID': options['key-id']!,
        'AGENT_EVAL_CHILD_RESPONSE': response.path,
      },
    );
    if (result.exitCode != 0 || !response.existsSync()) {
      throw const FormatException('purpose child runtime failed');
    }
    final source = response.readAsStringSync();
    final decoded = jsonDecode(source);
    const keys = <String>{
      'schemaVersion',
      'payloadJson',
      'signatureBase64',
      'redactedExecutionSummaryJson',
      'redactedScorecardJson',
      'redactedGateVerdictJson',
    };
    if (decoded is! Map<String, Object?> ||
        decoded.keys.toSet().difference(keys).isNotEmpty ||
        keys.difference(decoded.keys.toSet()).isNotEmpty ||
        decoded['schemaVersion'] != 'production-holdout-process-response-v2' ||
        source.trim() != source) {
      throw const FormatException('purpose child response is malformed');
    }
    stdout.write(source);
  } catch (_) {
    stderr.writeln('purpose private holdout runner failed');
    exitCode = 2;
  } finally {
    if (response?.existsSync() ?? false) response!.deleteSync();
  }
}

Map<String, String> _parse(List<String> arguments) {
  if (arguments.length != _required.length * 2) {
    throw const FormatException('invalid purpose child options');
  }
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final option = arguments[index];
    if (!option.startsWith('--')) {
      throw const FormatException('invalid purpose child options');
    }
    final key = option.substring(2);
    final value = arguments[index + 1];
    if (!_required.contains(key) ||
        value.trim().isEmpty ||
        result.containsKey(key)) {
      throw const FormatException('invalid purpose child options');
    }
    result[key] = value;
  }
  if (_required.difference(result.keys.toSet()).isNotEmpty) {
    throw const FormatException('invalid purpose child options');
  }
  return result;
}
