import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_private_material_builder.dart';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isEmpty) throw const FormatException('missing command');
    final command = arguments.first;
    final options = _options(arguments.skip(1).toList(growable: false));
    const builder = AgentEvaluationPrivateMaterialBuilder();
    switch (command) {
      case 'generate-scenarios':
        _require(options, const <String>{'output'});
        final scenarioSetHash = builder.generateScenarios(
          outputPath: options['output']!,
        );
        stdout.writeln('opaqueScenarioSetHash=$scenarioSetHash');
        return;
      case 'prepare':
        _require(options, const <String>{
          'root',
          'authority-db',
          'scenario-source',
          'release-configuration',
          'release-configuration-hash',
          'app-artifact-hash',
          'champion-bundle-hash',
          'challenger-bundle-hash',
          'regression-verdict-hash',
          'key-id',
        });
        final result = await builder.prepare(
          rootPath: options['root']!,
          authorityDatabasePath: options['authority-db']!,
          scenarioSourcePath: options['scenario-source']!,
          releaseConfigurationPath: options['release-configuration']!,
          releaseConfigurationHash: options['release-configuration-hash']!,
          appArtifactHash: options['app-artifact-hash']!,
          championBundleHash: options['champion-bundle-hash']!,
          challengerBundleHash: options['challenger-bundle-hash']!,
          regressionVerdictHash: options['regression-verdict-hash']!,
          keyId: options['key-id']!,
        );
        stdout.writeln('prepared=${result.metadataHash}');
        return;
      case 'bind':
        _require(options, const <String>{'root', 'authority-db', 'access-id'});
        final result = await builder.bind(
          rootPath: options['root']!,
          authorityDatabasePath: options['authority-db']!,
          accessId: options['access-id']!,
        );
        stdout.writeln('bound=${result.bindingHash}');
        return;
      default:
        throw const FormatException('unknown command');
    }
  } catch (_) {
    stderr.writeln('private material preparation failed');
    exitCode = 2;
  }
}

Map<String, String> _options(List<String> arguments) {
  if (arguments.length.isOdd) {
    throw const FormatException('invalid material builder options');
  }
  final result = <String, String>{};
  for (var index = 0; index < arguments.length; index += 2) {
    final option = arguments[index];
    if (!option.startsWith('--')) {
      throw const FormatException('invalid material builder options');
    }
    final key = option.substring(2);
    final value = arguments[index + 1];
    if (key.isEmpty || value.trim().isEmpty || result.containsKey(key)) {
      throw const FormatException('invalid material builder options');
    }
    result[key] = value;
  }
  return result;
}

void _require(Map<String, String> options, Set<String> required) {
  if (options.keys.toSet().difference(required).isNotEmpty ||
      required.difference(options.keys.toSet()).isNotEmpty) {
    throw const FormatException('invalid material builder options');
  }
}
