import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('complete runtime has no private material path capability', () {
    final completeRuntime = File(
      'lib/agent_evaluation_release_coordinator_runtime.dart',
    ).readAsStringSync();
    final verifierDispatch = completeRuntime.indexOf(
      'runAgentEvaluationSealVerifierCommand(arguments)',
    );
    final supervisorConnect = completeRuntime.indexOf(
      'AgentEvaluationSupervisorConnection.connect(environment)',
    );
    expect(verifierDispatch, greaterThanOrEqualTo(0));
    expect(supervisorConnect, greaterThan(verifierDispatch));
    for (final forbidden in <String>[
      'AGENT_EVAL_PRIVATE_PLAN',
      'AGENT_EVAL_PRIVATE_VAULT',
      'AGENT_EVAL_PRIVATE_SEED_FILE',
      'privatePlanPath',
      'vaultPath',
      'seedFilePath',
      'signerExecutablePath',
      'signerEntrypointPath',
    ]) {
      expect(completeRuntime, isNot(contains(forbidden)), reason: forbidden);
    }

    final supervisor = File(
      'lib/features/story_generation/data/evaluation/'
      'agent_evaluation_release_supervisor.dart',
    ).readAsStringSync();
    expect(supervisor, contains('AGENT_EVAL_PRIVATE_MATERIAL_ROOT'));
    expect(supervisor, contains('AGENT_EVAL_PRIVATE_PLAN'));
    expect(supervisor, contains('AGENT_EVAL_PRIVATE_VAULT'));
    expect(supervisor, contains('_runPrivateBrokerChild'));
    expect(supervisor, contains('AGENT_EVAL_RELEASE_BUDGET_DIR'));
    expect(supervisor, contains('expectedCombinedBudgetEvidence'));
    expect(supervisor, isNot(contains('AGENT_EVAL_PRIVATE_SEED_FILE')));
    final launcher = File(
      'tool/agent_evaluation_release_coordinator.dart',
    ).readAsStringSync();
    expect(
      launcher,
      contains('--novel-writer-agent-evaluation-release-supervisor-v1'),
    );
    expect(launcher, contains('includeParentEnvironment: false'));
    expect(launcher, isNot(contains('AGENT_EVAL_PRIVATE_PLAN')));
    expect(
      completeRuntime,
      contains('readAgentEvaluationCombinedReleaseBudgetEvidence'),
    );
  });

  test(
    'process boundary rejects broker forgery before provider access',
    () async {
      final root = Directory.systemTemp.createTempSync('eval-broker-probe-');
      addTearDown(() => root.deleteSync(recursive: true));
      final dart = File(
        '${Platform.environment['FLUTTER_ROOT']}/bin/cache/dart-sdk/bin/dart',
      );
      expect(dart.existsSync(), isTrue);
      const probe =
          'test/test_support/agent_evaluation_private_broker_process_probe.dart';

      Future<ProcessResult> startComplete(
        Map<String, Object?> request, {
        Map<String, String> extraEnvironment = const <String, String>{},
        required String marker,
      }) async {
        final count = File('${root.path}/$marker-count')
          ..writeAsStringSync('0');
        final process = await Process.start(
          dart.path,
          <String>[probe],
          workingDirectory: Directory.current.path,
          includeParentEnvironment: false,
          environment: <String, String>{
            'PROBE_MODE': 'complete',
            'PROBE_RECORD_PATH': '${root.path}/$marker-complete.json',
            'PROBE_PROVIDER_COUNT_PATH': count.path,
            'PROBE_BROKER_TOKEN': 'pinned-public-broker-v1',
            ...extraEnvironment,
          },
        );
        process.stdin.write(jsonEncode(request));
        await process.stdin.close();
        final values = await Future.wait<Object?>(<Future<Object?>>[
          process.exitCode,
          process.stdout.transform(utf8.decoder).join(),
          process.stderr.transform(utf8.decoder).join(),
        ]);
        return ProcessResult(
          process.pid,
          values[0]! as int,
          values[1],
          values[2],
        );
      }

      final valid = await startComplete(const <String, Object?>{
        'schemaVersion': 'agent-evaluation-private-broker-probe-v1',
        'brokerToken': 'pinned-public-broker-v1',
        'requestedMode': 'complete',
      }, marker: 'valid');
      expect(valid.exitCode, 0);
      final completeRecord =
          jsonDecode(
                File('${root.path}/valid-complete.json').readAsStringSync(),
              )
              as Map<String, Object?>;
      final completeText = jsonEncode(completeRecord);
      for (final forbidden in <String>[
        'AGENT_EVAL_PRIVATE_PLAN',
        'AGENT_EVAL_PRIVATE_VAULT',
        'AGENT_EVAL_PRIVATE_SEED_FILE',
        'AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE',
        'supervisor-private-child-v1',
      ]) {
        expect(completeText, isNot(contains(forbidden)), reason: forbidden);
      }

      for (final attack
          in <(String, Map<String, Object?>, Map<String, String>)>[
            (
              'fake-broker',
              const <String, Object?>{
                'schemaVersion': 'agent-evaluation-private-broker-probe-v1',
                'brokerToken': 'forged',
                'requestedMode': 'complete',
              },
              const <String, String>{},
            ),
            (
              'mode-switch',
              const <String, Object?>{
                'schemaVersion': 'agent-evaluation-private-broker-probe-v1',
                'brokerToken': 'pinned-public-broker-v1',
                'requestedMode': 'private',
              },
              const <String, String>{},
            ),
            (
              'extra-environment',
              const <String, Object?>{
                'schemaVersion': 'agent-evaluation-private-broker-probe-v1',
                'brokerToken': 'pinned-public-broker-v1',
                'requestedMode': 'complete',
              },
              const <String, String>{'AGENT_EVAL_PRIVATE_PLAN': '/forged-plan'},
            ),
          ]) {
        final result = await startComplete(
          attack.$2,
          extraEnvironment: attack.$3,
          marker: attack.$1,
        );
        expect(result.exitCode, isNot(0), reason: attack.$1);
        expect(File('${root.path}/${attack.$1}-count').readAsStringSync(), '0');
      }

      final privateRecordPath = '${root.path}/private.json';
      final privateResult = await Process.run(
        dart.path,
        <String>[probe],
        workingDirectory: Directory.current.path,
        includeParentEnvironment: false,
        environment: <String, String>{
          'PROBE_MODE': 'private',
          'PROBE_RECORD_PATH': privateRecordPath,
          'PROBE_PROVIDER_COUNT_PATH': '${root.path}/private-count',
          'PROBE_SUPERVISOR_LAUNCH_TOKEN': 'supervisor-private-child-v1',
          'AGENT_EVAL_PRIVATE_PLAN': '/private/plan',
          'AGENT_EVAL_PRIVATE_VAULT': '/private/vault',
          'AGENT_EVAL_PRIVATE_SEED_FILE': '/private/seed',
          'AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE': '/private/signer',
        },
      );
      expect(privateResult.exitCode, 0);
      final privateRecord =
          jsonDecode(File(privateRecordPath).readAsStringSync())
              as Map<String, Object?>;
      expect(jsonEncode(privateRecord), contains('/private/plan'));
      expect(privateRecord['launchedBySupervisor'], isTrue);

      final unsupervised = await Process.run(
        dart.path,
        <String>[probe],
        workingDirectory: Directory.current.path,
        includeParentEnvironment: false,
        environment: <String, String>{
          'PROBE_MODE': 'private',
          'PROBE_RECORD_PATH': '${root.path}/unsupervised.json',
          'PROBE_PROVIDER_COUNT_PATH': '${root.path}/unsupervised-count',
          'PROBE_SUPERVISOR_LAUNCH_TOKEN': 'forged',
          'AGENT_EVAL_PRIVATE_PLAN': '/private/plan',
          'AGENT_EVAL_PRIVATE_VAULT': '/private/vault',
          'AGENT_EVAL_PRIVATE_SEED_FILE': '/private/seed',
          'AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE': '/private/signer',
        },
      );
      expect(unsupervised.exitCode, isNot(0));
    },
  );
}
