import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_identity.dart';

import 'agent_evaluation_release_coordinator_preflight.dart';
import 'agent_evaluation_release_preflight.dart';

Future<void> main() async {
  final root = Directory.systemTemp.createTempSync(
    'agent-evaluation-release-preflight-',
  );
  try {
    _chmod(root.path, '700');
    final plan = File('${root.path}/private-plan.json')
      ..writeAsStringSync('{}', flush: true);
    final seed = File('${root.path}/private-seed.bin')
      ..writeAsBytesSync(List<int>.generate(32, (index) => index), flush: true);
    _chmod(plan.path, '600');
    _chmod(seed.path, '600');
    final environment = <String, String>{
      for (final name in agentEvaluationPaidReleaseRequiredEnvironment)
        name: '1',
      for (final name in agentEvaluationCoordinatorRequiredEnvironment)
        name: 'value',
      'RUN_REAL_AGENT_EVAL': '1',
      'REAL_LLM_COST_ACK': 'YES',
      'ZHIPU_API_KEY': 'process-test-secret',
      'ZHIPU_BASE_URL': 'https://open.bigmodel.cn/api/paas/v4',
      'AGENT_EVAL_EXECUTION_ID': 'preflight-process-v1',
      'AGENT_EVAL_REQUIRED_MODELS': 'glm-sut',
      'AGENT_EVAL_JUDGE_MODEL': 'glm-judge',
      'AGENT_EVAL_DEADLINE_MS': '600000',
      'AGENT_EVAL_MAX_ATTEMPTS_PER_TRIAL': '3',
      'AGENT_EVAL_MAX_CALLS_PER_TRIAL': '24',
      'AGENT_EVAL_MAX_TOKENS_PER_TRIAL': '2500000',
      'AGENT_EVAL_MAX_PROMPT_TOKENS_PER_CALL': '100000',
      'AGENT_EVAL_MAX_COMPLETION_TOKENS_PER_CALL': '4096',
      'AGENT_EVAL_MAX_CALLS': '9000',
      'AGENT_EVAL_MAX_TOKENS': '936864000',
      'AGENT_EVAL_MAX_COST_MICROUSD': '1',
      'AGENT_EVAL_JUDGE_MAX_CALLS': '360',
      'AGENT_EVAL_JUDGE_MAX_TOKENS': '37474560',
      'AGENT_EVAL_JUDGE_MAX_COST_MICROUSD': '360',
      'AGENT_EVAL_JUDGE_MAX_TOKENS_PER_CALL': '4096',
      'AGENT_EVAL_JUDGE_MAX_COST_MICROUSD_PER_CALL': '1',
      'AGENT_EVAL_PROMPT_PRICE_MICROUSD_PER_MTOK': '0',
      'AGENT_EVAL_COMPLETION_PRICE_MICROUSD_PER_MTOK': '0',
      'AGENT_EVAL_JUDGE_PROMPT_PRICE_MICROUSD_PER_MTOK': '0',
      'AGENT_EVAL_JUDGE_COMPLETION_PRICE_MICROUSD_PER_MTOK': '0',
      'AGENT_EVAL_SOURCE_TREE_HASH': _digest('3'),
      'AGENT_EVAL_BUILD_ARTIFACT_HASH': _digest('4'),
      'AGENT_EVAL_CODE_COMMIT': List<String>.filled(40, 'a').join(),
      'AGENT_EVAL_COORDINATOR_RUN_ID': 'coordinator-process-v1',
      'AGENT_EVAL_PUBLIC_WORK_DIR': '${root.path}/public-work',
      'AGENT_EVAL_PUBLIC_REPORT_DIR': '${root.path}/public-reports',
      'AGENT_EVAL_COORDINATOR_WORK_DIR': '${root.path}/coordinator-work',
      'AGENT_EVAL_COORDINATOR_REPORT_DIR': '${root.path}/coordinator-reports',
      'AGENT_EVAL_RELEASE_CHANNEL': 'stable',
      'AGENT_EVAL_RELEASE_APPROVER': 'preflight-process-test',
      'AGENT_EVAL_PRIVATE_TIMEOUT_MS': '600000',
      'AGENT_EVAL_PRIVATE_PLAN_HASH': _digest('6'),
      'AGENT_EVAL_PRIVATE_SCENARIO_SET_HASH': _digest('7'),
      'AGENT_EVAL_PRIVATE_PLAN': plan.path,
      'AGENT_EVAL_PRIVATE_VAULT': '${root.path}/vault/private.sqlite',
      'AGENT_EVAL_PRIVATE_SEED_FILE': seed.path,
      'AGENT_EVAL_PRIVATE_KEY_ID': 'preflight-key-v1',
      'AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64': base64Encode(
        List<int>.generate(32, (index) => 31 - index),
      ),
    };
    environment['AGENT_EVAL_SDK_ADAPTER_RELEASE_HASH'] =
        AgentEvaluationDerivedReleaseIdentity.sdkAdapterReleaseHash(
          sourceTreeHash: environment['AGENT_EVAL_SOURCE_TREE_HASH']!,
          buildArtifactHash: environment['AGENT_EVAL_BUILD_ARTIFACT_HASH']!,
          providerApiRevision: environment['AGENT_EVAL_PROVIDER_API_REVISION']!,
        );
    environment['AGENT_EVAL_TOKENIZER_RELEASE_HASH'] =
        AgentEvaluationDerivedReleaseIdentity.tokenizerReleaseHash(
          sourceTreeHash: environment['AGENT_EVAL_SOURCE_TREE_HASH']!,
          buildArtifactHash: environment['AGENT_EVAL_BUILD_ARTIFACT_HASH']!,
        );
    environment['AGENT_EVAL_RUNTIME_RELEASE_HASH'] =
        AgentEvaluationDerivedReleaseIdentity.runtimeReleaseHash(
          sourceTreeHash: environment['AGENT_EVAL_SOURCE_TREE_HASH']!,
          buildArtifactHash: environment['AGENT_EVAL_BUILD_ARTIFACT_HASH']!,
        );
    final probe = File(
      '${Directory.current.path}/tool/'
      'agent_evaluation_release_coordinator_preflight_probe.dart',
    ).absolute;

    await _expectExit(probe, environment, 0, 'valid frozen deployment');
    for (final directory in <String>[
      environment['AGENT_EVAL_PUBLIC_WORK_DIR']!,
      environment['AGENT_EVAL_PUBLIC_REPORT_DIR']!,
      environment['AGENT_EVAL_COORDINATOR_WORK_DIR']!,
      environment['AGENT_EVAL_COORDINATOR_REPORT_DIR']!,
      File(environment['AGENT_EVAL_PRIVATE_VAULT']!).parent.path,
    ]) {
      if (!Directory(directory).existsSync() ||
          (!Platform.isWindows &&
              (Directory(directory).statSync().mode & 0x1ff) != 0x1c0)) {
        throw StateError('preflight did not secure deployment directory');
      }
    }

    await _expectInvalid(probe, environment, 'RUN_REAL_AGENT_EVAL', '0');
    await _expectInvalid(probe, environment, 'REAL_LLM_COST_ACK', 'NO');
    await _expectMissing(probe, environment, 'AGENT_EVAL_EXECUTION_ID');
    await _expectInvalid(probe, environment, 'AGENT_EVAL_MAX_CALLS', '-1');
    await _expectInvalid(probe, environment, 'AGENT_EVAL_MAX_CALLS', '4500');
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_MAX_TOKENS',
      '500000000',
    );
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_JUDGE_MAX_CALLS',
      '180',
    );
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_SOURCE_TREE_HASH',
      'not-a-digest',
    );
    validateAgentEvaluationDerivedReleaseIdentities(environment);
    var rejectedCallerChosenIdentity = false;
    try {
      validateAgentEvaluationDerivedReleaseIdentities(<String, String>{
        ...environment,
        'AGENT_EVAL_RUNTIME_RELEASE_HASH': _digest('5'),
      });
    } on AgentEvaluationCoordinatorPreflightFailure {
      rejectedCallerChosenIdentity = true;
    }
    if (!rejectedCallerChosenIdentity) {
      throw StateError('caller-chosen release identity was accepted');
    }
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_JUDGE_MODEL',
      'glm-sut',
    );
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_PRIVATE_TIMEOUT_MS',
      '${const Duration(hours: 24).inMilliseconds + 1}',
    );
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_PRIVATE_PLAN',
      'relative-private-plan.json',
    );
    await _expectInvalid(
      probe,
      environment,
      'AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64',
      base64Encode(<int>[1, 2, 3]),
    );
    if (!Platform.isWindows) {
      _chmod(plan.path, '644');
      await _expectExit(probe, environment, 64, 'world-readable private plan');
      _chmod(plan.path, '600');
      final link = Link('${root.path}/seed-link')..createSync(seed.path);
      await _expectInvalid(
        probe,
        environment,
        'AGENT_EVAL_PRIVATE_SEED_FILE',
        link.path,
      );
    }
    _exerciseSourceManifest(Directory('${root.path}/source-manifest'));
    _exerciseBuildArtifactManifest(Directory('${root.path}/novel_writer.app'));
  } finally {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

void _exerciseSourceManifest(Directory repository) {
  Directory('${repository.path}/lib').createSync(recursive: true);
  Directory('${repository.path}/tool').createSync();
  Directory('${repository.path}/macos/Runner').createSync(recursive: true);
  Directory('${repository.path}/assets').createSync();
  Directory('${repository.path}/scripts').createSync();
  final files = <File, String>{
    File('${repository.path}/pubspec.yaml'): 'name: fixture\n',
    File('${repository.path}/pubspec.lock'): 'packages: {}\n',
    File('${repository.path}/lib/release.dart'): 'const release = 1;\n',
    File('${repository.path}/tool/agent_evaluation_fixture.dart'):
        'void main() {}\n',
    File('${repository.path}/tool/release_helper.dart'):
        'const helper = true;\n',
    File('${repository.path}/macos/Runner/Release.entitlements'): '<plist/>\n',
    File('${repository.path}/assets/release-fixture.txt'): 'asset-v1\n',
    File('${repository.path}/scripts/release_helper.sh'): '#!/bin/sh\n',
  };
  for (final entry in files.entries) {
    entry.key.writeAsStringSync(entry.value);
  }
  final expected = computeAgentEvaluationReleaseSourceTreeHash(repository);
  validateAgentEvaluationReleaseSourceTree(repository, expected);
  for (final entry in files.entries) {
    entry.key.writeAsStringSync('${entry.value}tampered\n');
    try {
      validateAgentEvaluationReleaseSourceTree(repository, expected);
    } on AgentEvaluationCoordinatorPreflightFailure {
      entry.key.writeAsStringSync(entry.value);
      continue;
    }
    throw StateError('source manifest tamper was accepted: ${entry.key.path}');
  }
  validateAgentEvaluationReleaseSourceTree(repository, expected);

  final modeTarget = files.keys.first;
  final originalMode = modeTarget.statSync().mode & 0x1ff;
  _chmod(modeTarget.path, originalMode == 0x180 ? '700' : '600');
  _expectSourceManifestRejected(repository, expected, 'mode mutation');
  _chmod(modeTarget.path, originalMode.toRadixString(8));

  final added = File('${repository.path}/lib/added.dart')
    ..writeAsStringSync('const added = true;\n');
  _expectSourceManifestRejected(repository, expected, 'added source');
  added.deleteSync();

  final removed = files.keys.last;
  final removedContent = files[removed]!;
  removed.deleteSync();
  _expectSourceManifestRejected(repository, expected, 'removed source');
  removed.writeAsStringSync(removedContent);

  Directory(
    '${repository.path}/macos/Flutter/ephemeral',
  ).createSync(recursive: true);
  File(
    '${repository.path}/macos/Flutter/ephemeral/generated.txt',
  ).writeAsStringSync('ignored\n');
  Directory(
    '${repository.path}/macos/Runner.xcodeproj/xcuserdata/user',
  ).createSync(recursive: true);
  File(
    '${repository.path}/macos/Runner.xcodeproj/xcuserdata/user/state',
  ).writeAsStringSync('ignored\n');
  validateAgentEvaluationReleaseSourceTree(repository, expected);

  if (!Platform.isWindows) {
    final link = Link('${repository.path}/lib/source-link')
      ..createSync(files.keys.first.path);
    _expectSourceManifestRejected(repository, expected, 'source symlink');
    link.deleteSync();
  }
  validateAgentEvaluationReleaseSourceTree(repository, expected);
}

void _expectSourceManifestRejected(
  Directory repository,
  String expected,
  String label,
) {
  try {
    validateAgentEvaluationReleaseSourceTree(repository, expected);
  } on AgentEvaluationCoordinatorPreflightFailure {
    return;
  }
  throw StateError('$label was accepted by the source manifest');
}

void _exerciseBuildArtifactManifest(Directory appBundle) {
  final files = <File, String>{
    File('${appBundle.path}/Contents/MacOS/novel_writer'): 'runner-v1\n',
    File(
      '${appBundle.path}/Contents/Frameworks/'
      'App.framework/Versions/A/App',
    ): 'dart-aot-v1\n',
    File(
      '${appBundle.path}/Contents/Frameworks/'
      'FlutterMacOS.framework/Versions/A/FlutterMacOS',
    ): 'flutter-engine-v1\n',
    File('${appBundle.path}/Contents/Info.plist'): '<plist>v1</plist>\n',
    File('${appBundle.path}/Contents/_CodeSignature/CodeResources'):
        'signature-v1\n',
    File('${appBundle.path}/Contents/Resources/AppIcon.icns'): 'icon-v1\n',
  };
  for (final entry in files.entries) {
    entry.key.parent.createSync(recursive: true);
    entry.key.writeAsStringSync(entry.value);
    _chmod(
      entry.key.path,
      entry.key.path.endsWith('/novel_writer') ||
              entry.key.path.endsWith('/App') ||
              entry.key.path.endsWith('/FlutterMacOS')
          ? '700'
          : '600',
    );
  }
  if (!Platform.isWindows) {
    Link(
      '${appBundle.path}/Contents/Frameworks/'
      'App.framework/Versions/Current',
    ).createSync('A');
    Link(
      '${appBundle.path}/Contents/Frameworks/App.framework/App',
    ).createSync('Versions/Current/App');
  }

  final expected = computeAgentEvaluationMacAppBundleHash(appBundle);
  validateAgentEvaluationMacAppBundle(appBundle, expected);
  if (computeAgentEvaluationMacAppBundleHash(appBundle) != expected) {
    throw StateError('app bundle manifest is not deterministic');
  }
  for (final entry in files.entries) {
    entry.key.writeAsStringSync('${entry.value}tampered\n');
    _expectBuildManifestRejected(appBundle, expected, entry.key.path);
    entry.key.writeAsStringSync(entry.value);
  }

  final runner = files.keys.first;
  final originalMode = runner.statSync().mode & 0x1ff;
  _chmod(runner.path, originalMode == 0x1c0 ? '600' : '700');
  _expectBuildManifestRejected(appBundle, expected, 'runner mode');
  _chmod(runner.path, originalMode.toRadixString(8));

  final added = File('${appBundle.path}/Contents/Resources/added.bin')
    ..writeAsStringSync('added\n');
  _expectBuildManifestRejected(appBundle, expected, 'added bundle file');
  added.deleteSync();

  final aot = files.keys.elementAt(1);
  final aotContent = files[aot]!;
  aot.deleteSync();
  _expectBuildManifestRejected(appBundle, expected, 'removed Dart AOT');
  aot.writeAsStringSync(aotContent);
  _chmod(aot.path, '700');

  if (!Platform.isWindows) {
    final absolute = Link('${appBundle.path}/Contents/absolute-link')
      ..createSync('/tmp');
    _expectBuildManifestRejected(appBundle, expected, 'absolute symlink');
    absolute.deleteSync();

    final dangling = Link('${appBundle.path}/Contents/dangling-link')
      ..createSync('missing-target');
    _expectBuildManifestRejected(appBundle, expected, 'dangling symlink');
    dangling.deleteSync();
  }
  validateAgentEvaluationMacAppBundle(appBundle, expected);
}

void _expectBuildManifestRejected(
  Directory appBundle,
  String expected,
  String label,
) {
  try {
    validateAgentEvaluationMacAppBundle(appBundle, expected);
  } on AgentEvaluationCoordinatorPreflightFailure {
    return;
  }
  throw StateError('$label was accepted by the build manifest');
}

Future<void> _expectInvalid(
  File probe,
  Map<String, String> base,
  String name,
  String value,
) {
  final environment = <String, String>{...base, name: value};
  if (agentEvaluationPaidReleaseRequiredEnvironment.contains(name) &&
      validateAgentEvaluationPaidRelease(environment).passed) {
    throw StateError('paid release preflight accepted invalid $name=$value');
  }
  return _expectExit(probe, environment, 64, name);
}

Future<void> _expectMissing(File probe, Map<String, String> base, String name) {
  final environment = <String, String>{...base}..remove(name);
  return _expectExit(probe, environment, 64, name);
}

Future<void> _expectExit(
  File probe,
  Map<String, String> environment,
  int expected,
  String label,
) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    <String>[probe.path],
    workingDirectory: Directory.current.path,
    environment: environment,
    includeParentEnvironment: false,
  );
  if (result.exitCode != expected || result.stdout.toString().isNotEmpty) {
    throw StateError(
      'unexpected preflight result for $label: exit=${result.exitCode}, '
      'stdout=${result.stdout}, stderr=${result.stderr}',
    );
  }
  if (expected == 64 &&
      result.stderr.toString().trim() !=
          'agent evaluation release coordinator preflight failed') {
    throw StateError('preflight diagnostic was not fixed for $label');
  }
}

void _chmod(String path, String mode) {
  if (Platform.isWindows) return;
  final result = Process.runSync('chmod', <String>[mode, path]);
  if (result.exitCode != 0) throw StateError('preflight test chmod failed');
}

String _digest(String value) => List<String>.filled(64, value).join();
