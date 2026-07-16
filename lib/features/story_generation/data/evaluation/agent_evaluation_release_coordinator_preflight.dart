import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_identity.dart';

import 'agent_evaluation_release_preflight.dart';

/// Pure-Dart deployment, source-tree and app-bundle provenance preflight.

const agentEvaluationCoordinatorRequiredEnvironment = <String>{
  'AGENT_EVAL_COORDINATOR_RUN_ID',
  'AGENT_EVAL_PUBLIC_WORK_DIR',
  'AGENT_EVAL_PUBLIC_REPORT_DIR',
  'AGENT_EVAL_COORDINATOR_WORK_DIR',
  'AGENT_EVAL_COORDINATOR_REPORT_DIR',
  'AGENT_EVAL_RELEASE_CHANNEL',
  'AGENT_EVAL_RELEASE_APPROVER',
  'AGENT_EVAL_PRIVATE_TIMEOUT_MS',
  'AGENT_EVAL_PRIVATE_PLAN_HASH',
  'AGENT_EVAL_PRIVATE_SCENARIO_SET_HASH',
  'AGENT_EVAL_PRIVATE_PLAN',
  'AGENT_EVAL_PRIVATE_VAULT',
  'AGENT_EVAL_PRIVATE_SEED_FILE',
  'AGENT_EVAL_PRIVATE_KEY_ID',
  'AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64',
};

const agentEvaluationCoordinatorPublicPhaseRequiredEnvironment = <String>{
  'AGENT_EVAL_COORDINATOR_RUN_ID',
  'AGENT_EVAL_PUBLIC_WORK_DIR',
  'AGENT_EVAL_PUBLIC_REPORT_DIR',
  'AGENT_EVAL_COORDINATOR_WORK_DIR',
  'AGENT_EVAL_COORDINATOR_REPORT_DIR',
  'AGENT_EVAL_RELEASE_CHANNEL',
  'AGENT_EVAL_RELEASE_APPROVER',
  'AGENT_EVAL_PRIVATE_TIMEOUT_MS',
  'AGENT_EVAL_PRIVATE_MATERIAL_ROOT',
  'AGENT_EVAL_PRIVATE_KEY_ID',
  'AGENT_EVAL_BASELINE_CRITERIA_SEAL',
};

const agentEvaluationExternalSignerRequiredEnvironment = <String>{
  'AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE',
  'AGENT_EVAL_EXTERNAL_SIGNER_ARGUMENTS_JSON',
  'AGENT_EVAL_EXTERNAL_SIGNER_TIMEOUT_MS',
  'AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64',
  'AGENT_EVAL_CUSTODY_ATTESTATION_PAYLOAD_JSON',
  'AGENT_EVAL_CUSTODY_ATTESTATION_SIGNATURE_BASE64',
};

final class AgentEvaluationCoordinatorPreflightFailure implements Exception {
  const AgentEvaluationCoordinatorPreflightFailure();
}

const agentEvaluationBuildArtifactScheme = 'macos-app-bundle-manifest-v1';

final class AgentEvaluationMacRuntimeCodeIdentity {
  AgentEvaluationMacRuntimeCodeIdentity._({
    required this.teamIdentifier,
    required this.designatedRequirement,
    required this.cdHash,
    required this.authorityChain,
  });

  factory AgentEvaluationMacRuntimeCodeIdentity.parse({
    required String details,
    required String requirement,
    required String entitlements,
  }) {
    final teams = RegExp(r'^TeamIdentifier=(.+)$', multiLine: true)
        .allMatches(details)
        .map((match) => match.group(1)!.trim())
        .toList(growable: false);
    final cdHashes = RegExp(r'^CDHash=(.+)$', multiLine: true)
        .allMatches(details)
        .map((match) => match.group(1)!.trim().toUpperCase())
        .toList(growable: false);
    final team = teams.length == 1 ? teams.single : null;
    final cdHash = cdHashes.length == 1 ? cdHashes.single : null;
    final authorities = RegExp(r'^Authority=(.+)$', multiLine: true)
        .allMatches(details)
        .map((match) => match.group(1)!.trim())
        .toList(growable: false);
    const marker = 'designated => ';
    final markerIndex = requirement.indexOf(marker);
    final designated = markerIndex < 0
        ? null
        : requirement.substring(markerIndex + marker.length).trim();
    final sandboxValues = _entitlementBooleanValues(
      entitlements,
      'com.apple.security.app-sandbox',
    );
    final debugValues = _entitlementBooleanValues(
      entitlements,
      'com.apple.security.get-task-allow',
    );
    if (details.contains('Signature=adhoc') ||
        team == null ||
        team == 'not set' ||
        !RegExp(r'^[A-Z0-9]{10}$').hasMatch(team) ||
        cdHash == null ||
        !RegExp(r'^[A-F0-9]{40,64}$').hasMatch(cdHash) ||
        designated == null ||
        designated.isEmpty ||
        authorities.isEmpty ||
        authorities.length > 8 ||
        authorities.any((value) => value.isEmpty) ||
        sandboxValues.length != 1 ||
        sandboxValues.single != true ||
        debugValues.length > 1 ||
        (debugValues.isNotEmpty && debugValues.single)) {
      throw const FormatException('runtime app code identity is invalid');
    }
    return AgentEvaluationMacRuntimeCodeIdentity._(
      teamIdentifier: team,
      designatedRequirement: designated,
      cdHash: cdHash,
      authorityChain: List<String>.unmodifiable(authorities),
    );
  }

  final String teamIdentifier;
  final String designatedRequirement;
  final String cdHash;
  final List<String> authorityChain;

  void verifyPinned(AgentEvaluationExternalCustodyTrustEntry trustEntry) {
    if (teamIdentifier != trustEntry.runtimeAppTeamIdentifier ||
        designatedRequirement != trustEntry.runtimeAppDesignatedRequirement ||
        cdHash != trustEntry.runtimeAppCdHash ||
        !_sameStrings(authorityChain, trustEntry.runtimeAppAuthorityChain)) {
      throw const FormatException('runtime app code identity changed');
    }
  }
}

List<bool> _entitlementBooleanValues(String source, String key) {
  final escaped = RegExp.escape(key);
  return RegExp(
    '<key>\\s*$escaped\\s*</key>\\s*<(true|false)\\s*/>',
    multiLine: true,
  ).allMatches(source).map((match) => match.group(1) == 'true').toList();
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void validateAgentEvaluationMacRuntimeAppCodeSignature(
  Directory appBundle,
  AgentEvaluationExternalCustodyTrustEntry trustEntry,
) {
  if (!Platform.isMacOS) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final absolute = appBundle.absolute;
  if (FileSystemEntity.typeSync(absolute.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      absolute.resolveSymbolicLinksSync() != absolute.path) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final verified = Process.runSync('/usr/bin/codesign', <String>[
    '--verify',
    '--deep',
    '--strict',
    '--verbose=2',
    absolute.path,
  ]);
  final details = Process.runSync('/usr/bin/codesign', <String>[
    '-d',
    '--verbose=4',
    absolute.path,
  ]);
  final requirement = Process.runSync('/usr/bin/codesign', <String>[
    '-d',
    '-r-',
    absolute.path,
  ]);
  final entitlements = Process.runSync('/usr/bin/codesign', <String>[
    '-d',
    '--entitlements',
    ':-',
    absolute.path,
  ]);
  if (verified.exitCode != 0 ||
      details.exitCode != 0 ||
      requirement.exitCode != 0 ||
      entitlements.exitCode != 0) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  try {
    AgentEvaluationMacRuntimeCodeIdentity.parse(
      details: '${details.stdout}\n${details.stderr}',
      requirement: '${requirement.stdout}\n${requirement.stderr}',
      entitlements: '${entitlements.stdout}\n${entitlements.stderr}',
    ).verifyPinned(trustEntry);
  } on FormatException {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

String readAgentEvaluationMacAppBundleIdentifier(Directory appBundle) {
  if (!Platform.isMacOS) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final plist = File('${appBundle.absolute.path}/Contents/Info.plist');
  final result = Process.runSync('/usr/bin/plutil', <String>[
    '-extract',
    'CFBundleIdentifier',
    'raw',
    '-o',
    '-',
    plist.path,
  ]);
  final identifier = result.stdout.toString().trim();
  if (result.exitCode != 0 ||
      !RegExp(
        r'^[A-Za-z0-9](?:[A-Za-z0-9.-]{1,126}[A-Za-z0-9])?$',
      ).hasMatch(identifier) ||
      !identifier.contains('.')) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  return identifier;
}

Directory resolveAgentEvaluationMacAppContainerRoot({
  required String bundleIdentifier,
}) {
  if (!Platform.isMacOS) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final account = Process.runSync('/usr/bin/id', const <String>['-P']);
  final fields = account.stdout.toString().trim().split(':');
  final userId = fields.length == 10 ? int.tryParse(fields[2]) : null;
  final home = fields.length == 10 ? fields[8] : '';
  final suffix = '/Library/Containers/$bundleIdentifier/Data';
  final raw = '$home$suffix';
  final root = Directory(raw).absolute;
  final owner = Process.runSync('/usr/bin/stat', <String>[
    '-f',
    '%u',
    root.path,
  ]);
  if (account.exitCode != 0 ||
      userId == null ||
      userId == 0 ||
      home.isEmpty ||
      !Directory(raw).isAbsolute ||
      !root.path.endsWith(suffix) ||
      FileSystemEntity.typeSync(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      root.resolveSymbolicLinksSync() != root.path ||
      owner.exitCode != 0 ||
      int.tryParse(owner.stdout.toString().trim()) != userId) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  _validateControlledRoot(root);
  return root;
}

void validateAgentEvaluationSandboxPaths({
  required Directory containerRoot,
  required Iterable<String> directoryPaths,
  Iterable<String> filePaths = const <String>[],
}) {
  final root = _validateControlledRoot(containerRoot);
  for (final path in directoryPaths) {
    _secureDirectoryWithinRoot(path, root);
  }
  for (final path in filePaths) {
    _validateFileWithinRoot(path, root);
  }
}

Directory _validateControlledRoot(Directory supplied) {
  final root = supplied.absolute;
  if (!Directory(supplied.path).isAbsolute ||
      FileSystemEntity.typeSync(root.path, followLinks: false) !=
          FileSystemEntityType.directory ||
      root.resolveSymbolicLinksSync() != root.path ||
      _isTemporaryRoot(root.path)) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  return root;
}

bool _isTemporaryRoot(String path) => <String>[
  '/tmp',
  '/private/tmp',
  '/var/tmp',
  '/private/var/tmp',
].any((root) => path == root || path.startsWith('$root/'));

void _secureDirectoryWithinRoot(String raw, Directory root) {
  final directory = Directory(raw);
  if (!directory.isAbsolute) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final normalized = _normalizeAbsolutePath(directory.absolute.path);
  if (normalized != directory.absolute.path ||
      !_isDescendantPath(normalized, root.path)) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  _rejectLinkedPathChain(normalized, root.path, allowFinalFile: false);
  _secureDirectory(Directory(normalized));
  _rejectLinkedPathChain(normalized, root.path, allowFinalFile: false);
}

void _validateFileWithinRoot(String raw, Directory root) {
  final file = File(raw);
  if (!file.isAbsolute) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final normalized = _normalizeAbsolutePath(file.absolute.path);
  if (normalized != file.absolute.path ||
      !_isDescendantPath(normalized, root.path)) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  if (file.parent.absolute.path != root.path) {
    _secureDirectoryWithinRoot(file.parent.path, root);
  }
  _rejectLinkedPathChain(normalized, root.path, allowFinalFile: true);
}

void _rejectLinkedPathChain(
  String target,
  String root, {
  required bool allowFinalFile,
}) {
  final relative = target.substring(root.length + 1);
  var cursor = root;
  final segments = relative.split('/');
  for (var index = 0; index < segments.length; index += 1) {
    cursor = '$cursor/${segments[index]}';
    final type = FileSystemEntity.typeSync(cursor, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    if (type == FileSystemEntityType.notFound) return;
    final isFinal = index == segments.length - 1;
    if (type != FileSystemEntityType.directory &&
        !(allowFinalFile && isFinal && type == FileSystemEntityType.file)) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
  }
}

bool _isDescendantPath(String path, String root) =>
    path.startsWith('$root/') && path.length > root.length + 1;

String _normalizeAbsolutePath(String path) {
  if (!path.startsWith('/')) return path;
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isEmpty) {
        throw const AgentEvaluationCoordinatorPreflightFailure();
      }
      segments.removeLast();
    } else {
      segments.add(segment);
    }
  }
  return '/${segments.join('/')}';
}

/// Hashes the complete signed macOS application bundle used by the release
/// coordinator. The manifest has no exclusions: the launcher, Dart AOT
/// framework, Flutter engine, resources, plist files and code-signing
/// envelopes all participate in one identity.
String computeAgentEvaluationMacAppBundleHash(Directory appBundle) {
  final supplied = appBundle.absolute;
  if (FileSystemEntity.typeSync(supplied.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  late final Directory root;
  try {
    root = Directory(supplied.resolveSymbolicLinksSync());
  } on FileSystemException {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final entries =
      <({FileSystemEntity entity, String path, FileSystemEntityType type})>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type != FileSystemEntityType.file &&
        type != FileSystemEntityType.directory &&
        type != FileSystemEntityType.link) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    final relativePath = entity.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (relativePath.isEmpty || relativePath.startsWith('/')) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    entries.add((entity: entity, path: relativePath, type: type));
  }
  entries.sort((left, right) => left.path.compareTo(right.path));

  const requiredFiles = <String>{
    'Contents/MacOS/novel_writer',
    'Contents/Frameworks/App.framework/Versions/A/App',
    'Contents/Frameworks/FlutterMacOS.framework/Versions/A/FlutterMacOS',
    'Contents/Info.plist',
    'Contents/_CodeSignature/CodeResources',
  };
  final regularFiles = <String>{
    for (final entry in entries)
      if (entry.type == FileSystemEntityType.file) entry.path,
  };
  if (!regularFiles.containsAll(requiredFiles)) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }

  final bytes = BytesBuilder(copy: false)
    ..add(utf8.encode('agent-evaluation-macos-app-bundle-manifest-v1'))
    ..add(_fixedWidth(entries.length));
  for (final entry in entries) {
    final pathBytes = utf8.encode(entry.path);
    bytes
      ..add(_fixedWidth(pathBytes.length))
      ..add(pathBytes);
    switch (entry.type) {
      case FileSystemEntityType.file:
        final file = File(entry.entity.path);
        final content = file.readAsBytesSync();
        bytes
          ..addByte(1)
          ..add(_fixedWidth(file.statSync().mode & 0x1ff))
          ..add(_fixedWidth(content.length))
          ..add(content);
        break;
      case FileSystemEntityType.directory:
        final directory = Directory(entry.entity.path);
        bytes
          ..addByte(2)
          ..add(_fixedWidth(directory.statSync().mode & 0x1ff));
        break;
      case FileSystemEntityType.link:
        final link = Link(entry.entity.path);
        late final String target;
        late final String resolved;
        try {
          target = link.targetSync();
          if (File(target).isAbsolute) {
            throw const AgentEvaluationCoordinatorPreflightFailure();
          }
          resolved = link.resolveSymbolicLinksSync();
        } on FileSystemException {
          throw const AgentEvaluationCoordinatorPreflightFailure();
        }
        if (resolved != root.path && !resolved.startsWith('${root.path}/')) {
          throw const AgentEvaluationCoordinatorPreflightFailure();
        }
        final targetBytes = utf8.encode(target);
        bytes
          ..addByte(3)
          ..add(_fixedWidth(targetBytes.length))
          ..add(targetBytes);
        break;
      default:
        throw const AgentEvaluationCoordinatorPreflightFailure();
    }
  }
  final digest = const DartSha256().hashSync(bytes.takeBytes());
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

void validateAgentEvaluationMacAppBundle(
  Directory appBundle,
  String expectedHash,
) {
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedHash) ||
      computeAgentEvaluationMacAppBundleHash(appBundle) != expectedHash) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

String computeAgentEvaluationReleaseSourceTreeHash(Directory repository) {
  final root = repository.absolute;
  final selected = <File>[];
  for (final relativePath in const <String>['pubspec.yaml', 'pubspec.lock']) {
    final entity = File('${root.path}/$relativePath');
    if (FileSystemEntity.typeSync(entity.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    selected.add(entity);
  }
  for (final relativePath in const <String>[
    'lib',
    'tool',
    'macos',
    'assets',
    'scripts',
  ]) {
    _addReleaseSourceDirectory(
      root: root,
      relativePath: relativePath,
      selected: selected,
    );
  }
  selected.sort((left, right) => left.path.compareTo(right.path));
  final bytes = BytesBuilder(copy: false)
    ..add(utf8.encode('agent-evaluation-release-source-manifest-v2'))
    ..add(_fixedWidth(selected.length));
  for (final file in selected) {
    final relativePath = file.path.substring(root.path.length + 1);
    final pathBytes = utf8.encode(relativePath);
    final content = file.readAsBytesSync();
    bytes
      ..add(_fixedWidth(pathBytes.length))
      ..add(pathBytes)
      ..add(_fixedWidth(file.statSync().mode & 0x1ff))
      ..add(_fixedWidth(content.length))
      ..add(content);
  }
  final digest = const DartSha256().hashSync(bytes.takeBytes());
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

void _addReleaseSourceDirectory({
  required Directory root,
  required String relativePath,
  required List<File> selected,
}) {
  final directory = Directory('${root.path}/$relativePath');
  if (FileSystemEntity.typeSync(directory.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    final manifestPath = entity.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (_isGeneratedReleaseSourcePath(manifestPath)) continue;
    final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
    if (type == FileSystemEntityType.link) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    if (type == FileSystemEntityType.file) selected.add(File(entity.path));
  }
}

bool _isGeneratedReleaseSourcePath(String relativePath) =>
    relativePath == 'macos/Flutter/ephemeral' ||
    relativePath.startsWith('macos/Flutter/ephemeral/') ||
    relativePath.contains('/xcuserdata/');

void validateAgentEvaluationReleaseSourceTree(
  Directory repository,
  String expectedHash,
) {
  if (computeAgentEvaluationReleaseSourceTreeHash(repository) != expectedHash) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

Uint8List _fixedWidth(int value) {
  final data = ByteData(8)..setUint64(0, value, Endian.big);
  return data.buffer.asUint8List();
}

void validateAgentEvaluationCoordinatorDeployment(
  Map<String, String> environment,
) {
  if (!validateAgentEvaluationPaidRelease(environment).passed ||
      agentEvaluationCoordinatorRequiredEnvironment.any(
        (name) => (environment[name] ?? '').trim().isEmpty,
      )) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final digestPattern = RegExp(r'^[a-f0-9]{64}$');
  final timeoutMs = int.tryParse(environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!);
  List<int> publicKey;
  try {
    publicKey = base64Decode(
      environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']!,
    );
  } on FormatException {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  if (timeoutMs == null ||
      timeoutMs <= 0 ||
      timeoutMs > const Duration(hours: 24).inMilliseconds ||
      !digestPattern.hasMatch(environment['AGENT_EVAL_PRIVATE_PLAN_HASH']!) ||
      !digestPattern.hasMatch(
        environment['AGENT_EVAL_PRIVATE_SCENARIO_SET_HASH']!,
      ) ||
      publicKey.length != 32 ||
      base64Encode(publicKey) !=
          environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final planRaw = environment['AGENT_EVAL_PRIVATE_PLAN']!;
  final seedRaw = environment['AGENT_EVAL_PRIVATE_SEED_FILE']!;
  final vaultRaw = environment['AGENT_EVAL_PRIVATE_VAULT']!;
  final plan = File(planRaw).absolute;
  final seed = File(seedRaw).absolute;
  final vault = File(vaultRaw).absolute;
  if (!File(planRaw).isAbsolute ||
      !File(seedRaw).isAbsolute ||
      !File(vaultRaw).isAbsolute ||
      !_isPrivateRegularFile(plan) ||
      !_isPrivateRegularFile(seed) ||
      plan.path == seed.path ||
      vault.path == plan.path ||
      vault.path == seed.path) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  _secureDirectory(vault.parent);
  final vaultType = FileSystemEntity.typeSync(vault.path, followLinks: false);
  if (vaultType != FileSystemEntityType.notFound &&
      (vaultType != FileSystemEntityType.file ||
          !_isPrivateRegularFile(vault))) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  for (final name in <String>[
    'AGENT_EVAL_PUBLIC_WORK_DIR',
    'AGENT_EVAL_PUBLIC_REPORT_DIR',
    'AGENT_EVAL_COORDINATOR_WORK_DIR',
    'AGENT_EVAL_COORDINATOR_REPORT_DIR',
  ]) {
    final raw = environment[name]!;
    if (!Directory(raw).isAbsolute) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    _secureDirectory(Directory(raw).absolute);
  }
}

void validateAgentEvaluationCoordinatorPublicPhaseDeployment(
  Map<String, String> environment,
) {
  if (!validateAgentEvaluationPaidRelease(environment).passed ||
      agentEvaluationCoordinatorPublicPhaseRequiredEnvironment.any(
        (name) => (environment[name] ?? '').trim().isEmpty,
      )) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final timeoutMs = int.tryParse(environment['AGENT_EVAL_PRIVATE_TIMEOUT_MS']!);
  final baselineSeal = File(environment['AGENT_EVAL_BASELINE_CRITERIA_SEAL']!);
  if (timeoutMs == null ||
      timeoutMs <= 0 ||
      timeoutMs > const Duration(hours: 24).inMilliseconds ||
      !baselineSeal.isAbsolute ||
      !RegExp(
        r'^[A-Za-z0-9_.:-]{1,128}$',
      ).hasMatch(environment['AGENT_EVAL_PRIVATE_KEY_ID']!)) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  for (final name in <String>[
    'AGENT_EVAL_PUBLIC_WORK_DIR',
    'AGENT_EVAL_PUBLIC_REPORT_DIR',
    'AGENT_EVAL_COORDINATOR_WORK_DIR',
    'AGENT_EVAL_COORDINATOR_REPORT_DIR',
  ]) {
    final raw = environment[name]!;
    if (!Directory(raw).isAbsolute) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
    _secureDirectory(Directory(raw).absolute);
  }
  final materialRootRaw = environment['AGENT_EVAL_PRIVATE_MATERIAL_ROOT']!;
  final materialRoot = Directory(materialRootRaw).absolute;
  if (!Directory(materialRootRaw).isAbsolute ||
      FileSystemEntity.typeSync(materialRoot.path, followLinks: false) ==
          FileSystemEntityType.link) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  _secureDirectory(materialRoot.parent);
}

void validateAgentEvaluationDerivedReleaseIdentities(
  Map<String, String> environment,
) {
  try {
    final sourceTreeHash = environment['AGENT_EVAL_SOURCE_TREE_HASH']!;
    final buildArtifactHash = environment['AGENT_EVAL_BUILD_ARTIFACT_HASH']!;
    if (environment['AGENT_EVAL_RUNTIME_RELEASE_HASH'] !=
            AgentEvaluationDerivedReleaseIdentity.runtimeReleaseHash(
              sourceTreeHash: sourceTreeHash,
              buildArtifactHash: buildArtifactHash,
            ) ||
        environment['AGENT_EVAL_SDK_ADAPTER_RELEASE_HASH'] !=
            AgentEvaluationDerivedReleaseIdentity.sdkAdapterReleaseHash(
              sourceTreeHash: sourceTreeHash,
              buildArtifactHash: buildArtifactHash,
              providerApiRevision:
                  environment['AGENT_EVAL_PROVIDER_API_REVISION']!,
            ) ||
        environment['AGENT_EVAL_TOKENIZER_RELEASE_HASH'] !=
            AgentEvaluationDerivedReleaseIdentity.tokenizerReleaseHash(
              sourceTreeHash: sourceTreeHash,
              buildArtifactHash: buildArtifactHash,
            )) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
  } on Object {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

void validateAgentEvaluationRepositoryCommit(
  Directory repository,
  String expectedCommit,
) {
  final normalized = expectedCommit.trim();
  if (!RegExp(r'^(?:[a-f0-9]{40}|[a-f0-9]{64})$').hasMatch(normalized)) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final result = Process.runSync('/usr/bin/git', const <String>[
    'rev-parse',
    '--verify',
    'HEAD^{commit}',
  ], workingDirectory: repository.absolute.path);
  if (result.exitCode != 0 || result.stdout.toString().trim() != normalized) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

void validateAgentEvaluationExternalSignerDeployment(
  Map<String, String> environment,
) {
  if (agentEvaluationExternalSignerRequiredEnvironment.any(
    (name) => (environment[name] ?? '').trim().isEmpty,
  )) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  final executableRaw = environment['AGENT_EVAL_EXTERNAL_SIGNER_EXECUTABLE']!;
  final executable = File(executableRaw).absolute;
  final entrypointRaw =
      (environment['AGENT_EVAL_EXTERNAL_SIGNER_ENTRYPOINT'] ?? '').trim();
  final entrypoint = entrypointRaw.isEmpty
      ? null
      : File(entrypointRaw).absolute;
  final timeoutMs = int.tryParse(
    environment['AGENT_EVAL_EXTERNAL_SIGNER_TIMEOUT_MS']!,
  );
  late final List<int> signingPublicKey;
  late final Object? arguments;
  try {
    signingPublicKey = base64Decode(
      environment['AGENT_EVAL_HOLDOUT_PUBLIC_KEY_BASE64']!,
    );
    arguments = jsonDecode(
      environment['AGENT_EVAL_EXTERNAL_SIGNER_ARGUMENTS_JSON']!,
    );
  } on FormatException {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  if (!File(executableRaw).isAbsolute ||
      FileSystemEntity.typeSync(executable.path, followLinks: false) !=
          FileSystemEntityType.file ||
      (entrypoint != null &&
          (!File(entrypointRaw).isAbsolute ||
              FileSystemEntity.typeSync(entrypoint.path, followLinks: false) !=
                  FileSystemEntityType.file)) ||
      timeoutMs == null ||
      timeoutMs <= 0 ||
      timeoutMs > const Duration(minutes: 5).inMilliseconds ||
      signingPublicKey.length != 32 ||
      arguments is! List<Object?> ||
      arguments.length > 16 ||
      arguments.any(
        (item) =>
            item is! String ||
            item.isEmpty ||
            item.length > 128 ||
            !RegExp(r'^[A-Za-z0-9_.=:+-]+$').hasMatch(item),
      )) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
}

bool _isPrivateRegularFile(File file) =>
    FileSystemEntity.typeSync(file.path, followLinks: false) ==
        FileSystemEntityType.file &&
    (Platform.isWindows || (file.statSync().mode & 0x1ff) == 0x180);

void _secureDirectory(Directory directory) {
  final type = FileSystemEntity.typeSync(directory.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw const AgentEvaluationCoordinatorPreflightFailure();
  }
  directory.createSync(recursive: true);
  if (!Platform.isWindows) {
    final chmod = Process.runSync('chmod', <String>['700', directory.path]);
    if (chmod.exitCode != 0 || (directory.statSync().mode & 0x1ff) != 0x1c0) {
      throw const AgentEvaluationCoordinatorPreflightFailure();
    }
  }
}
