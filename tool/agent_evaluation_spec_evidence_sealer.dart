import 'dart:io';

import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_spec_evidence.dart';

void main(List<String> arguments) {
  final archiveRootValue = _argument(arguments, '--archive-root');
  final registryValue = _argument(arguments, '--registry');
  final sealValue = _argument(arguments, '--seal');
  if (archiveRootValue == null || registryValue == null || sealValue == null) {
    stderr.writeln('usage: --archive-root PATH --registry PATH --seal PATH');
    exitCode = 64;
    return;
  }

  final archiveRoot = Directory(archiveRootValue).absolute;
  final registryFile = File(registryValue).absolute;
  final sealFile = File(sealValue).absolute;
  final sealType = FileSystemEntity.typeSync(sealFile.path, followLinks: false);
  if (!Directory(archiveRootValue).isAbsolute ||
      FileSystemEntity.typeSync(archiveRoot.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      archiveRoot.resolveSymbolicLinksSync() != archiveRoot.path ||
      !File(registryValue).isAbsolute ||
      FileSystemEntity.typeSync(registryFile.path, followLinks: false) !=
          FileSystemEntityType.file ||
      registryFile.resolveSymbolicLinksSync() != registryFile.path ||
      sealFile.parent.path != archiveRoot.path ||
      (sealType != FileSystemEntityType.notFound &&
          sealType != FileSystemEntityType.file)) {
    stderr.writeln('archive root and criteria registry must already exist');
    exitCode = 66;
    return;
  }

  try {
    final registry = AgentEvaluationSpecCriteriaRegistry.fromCanonicalJson(
      registryFile.readAsStringSync(),
    );
    final sourceTreeHashes = <String>{};
    for (final entry in registry.entries) {
      sourceTreeHashes.add(entry.sourceTreeHash);
    }
    if (sourceTreeHashes.length != 1) {
      throw const FormatException(
        'all criteria entries must bind the same source tree',
      );
    }
    verifyAgentEvaluationSpecCriteriaArtifacts(
      registry: registry,
      archiveRoot: archiveRoot,
    );

    final seal = AgentEvaluationSpecCriteriaRegistrySeal.create(registry);
    sealFile.writeAsStringSync(seal.canonicalJson, flush: true);
    if (!Platform.isWindows) {
      final chmod = Process.runSync('/bin/chmod', <String>[
        '600',
        sealFile.path,
      ]);
      if (chmod.exitCode != 0) {
        throw const FileSystemException(
          'could not secure criteria baseline seal',
        );
      }
    }
    AgentEvaluationSpecCriteriaRegistrySeal.fromCanonicalJson(
      sealFile.readAsStringSync(),
    );
    stdout.writeln(seal.sealHash);
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  }
}

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0 || index + 1 >= arguments.length) return null;
  return arguments[index + 1];
}
