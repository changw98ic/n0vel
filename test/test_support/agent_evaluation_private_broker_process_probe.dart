import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final environment = Platform.environment;
  const platformAmbientEnvironment = <String>{'__CF_USER_TEXT_ENCODING'};
  final mode = environment['PROBE_MODE'];
  final recordPath = environment['PROBE_RECORD_PATH'];
  final providerCountPath = environment['PROBE_PROVIDER_COUNT_PATH'];
  if (arguments.isNotEmpty ||
      recordPath == null ||
      providerCountPath == null ||
      (mode != 'complete' && mode != 'private')) {
    exit(2);
  }

  final openedPaths = <String>[];
  void writeRecord(Map<String, Object?> value) {
    openedPaths.add(recordPath);
    File(recordPath).writeAsStringSync(
      jsonEncode(<String, Object?>{
        ...value,
        'environmentNames': environment.keys.toList()..sort(),
        'arguments': arguments,
        'openedPaths': openedPaths,
      }),
    );
  }

  if (mode == 'complete') {
    const allowedEnvironment = <String>{
      'PROBE_MODE',
      'PROBE_RECORD_PATH',
      'PROBE_PROVIDER_COUNT_PATH',
      'PROBE_BROKER_TOKEN',
    };
    if (environment.keys.toSet().difference(<String>{
          ...allowedEnvironment,
          ...platformAmbientEnvironment,
        }).isNotEmpty ||
        environment['PROBE_BROKER_TOKEN'] != 'pinned-public-broker-v1') {
      exit(2);
    }
    final source = await stdin.transform(utf8.decoder).join();
    late final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      exit(2);
    }
    if (decoded is! Map<String, Object?> ||
        decoded.keys.toSet().difference(const <String>{
          'schemaVersion',
          'brokerToken',
          'requestedMode',
        }).isNotEmpty ||
        const <String>{
          'schemaVersion',
          'brokerToken',
          'requestedMode',
        }.difference(decoded.keys.toSet()).isNotEmpty ||
        decoded['schemaVersion'] !=
            'agent-evaluation-private-broker-probe-v1' ||
        decoded['brokerToken'] != 'pinned-public-broker-v1' ||
        decoded['requestedMode'] != 'complete') {
      exit(2);
    }
    openedPaths.add(providerCountPath);
    final count = int.parse(File(providerCountPath).readAsStringSync());
    File(providerCountPath).writeAsStringSync('${count + 1}');
    writeRecord(<String, Object?>{
      'mode': 'complete',
      'providerCountAfterValidation': count + 1,
    });
    exit(0);
  }

  const requiredPrivateEnvironment = <String>{
    'PROBE_MODE',
    'PROBE_RECORD_PATH',
    'PROBE_PROVIDER_COUNT_PATH',
    'PROBE_SUPERVISOR_LAUNCH_TOKEN',
    'AGENT_EVAL_PRIVATE_PLAN',
    'AGENT_EVAL_PRIVATE_VAULT',
    'AGENT_EVAL_PRIVATE_SEED_FILE',
    'AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE',
  };
  if (environment.keys.toSet().difference(<String>{
        ...requiredPrivateEnvironment,
        ...platformAmbientEnvironment,
      }).isNotEmpty ||
      requiredPrivateEnvironment
          .difference(environment.keys.toSet())
          .isNotEmpty ||
      environment['PROBE_SUPERVISOR_LAUNCH_TOKEN'] !=
          'supervisor-private-child-v1') {
    exit(2);
  }
  final privatePaths = <String>[
    environment['AGENT_EVAL_PRIVATE_PLAN']!,
    environment['AGENT_EVAL_PRIVATE_VAULT']!,
    environment['AGENT_EVAL_PRIVATE_SEED_FILE']!,
    environment['AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE']!,
  ];
  openedPaths.addAll(privatePaths);
  writeRecord(<String, Object?>{
    'mode': 'private',
    'privatePaths': privatePaths,
    'launchedBySupervisor': true,
  });
}
