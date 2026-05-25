// ============================================================================
// Plugin Installer
// ============================================================================
//
// Local bundle validation and install-plan creation. This skeleton does not
// copy files or execute plugin code.
//
// See M8-02: Plugin System Core

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'plugin_manifest.dart';

class PluginInstallException implements Exception {
  const PluginInstallException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'PluginInstallException(${errors.join(', ')})';
}

class PluginBundleFile {
  const PluginBundleFile({required this.role, required this.relativePath});

  final String role;
  final String relativePath;
}

class PluginInstallPlan {
  const PluginInstallPlan({
    required this.bundleRootPath,
    required this.manifest,
    required this.manifestDigest,
    required this.referencedFiles,
  });

  final String bundleRootPath;
  final PluginManifest manifest;
  final String manifestDigest;
  final List<PluginBundleFile> referencedFiles;
}

class PluginInstaller {
  const PluginInstaller({this.allowProcessRuntime = false});

  /// Developer-mode escape hatch. Disabled by default.
  final bool allowProcessRuntime;

  Future<PluginInstallPlan> createInstallPlan(Directory bundleRoot) async {
    final errors = <String>[];
    final root = bundleRoot.absolute;
    if (!await root.exists()) {
      throw PluginInstallException([
        'bundle root does not exist: ${root.path}',
      ]);
    }

    final manifestFile = File(_join(root.path, 'plugin.n0vel.json'));
    if (!await manifestFile.exists()) {
      throw const PluginInstallException(['plugin.n0vel.json is required']);
    }

    final manifestBytes = await manifestFile.readAsBytes();
    late final PluginManifest manifest;
    try {
      manifest = PluginManifest.fromJsonString(utf8.decode(manifestBytes));
    } on PluginManifestException catch (e) {
      throw PluginInstallException(e.errors);
    } on FormatException catch (e) {
      throw PluginInstallException([
        'manifest is not valid JSON: ${e.message}',
      ]);
    }

    if (manifest.runtime.kind == PluginRuntimeKind.process &&
        !allowProcessRuntime) {
      errors.add('process runtime is disabled outside developer mode');
    }

    final referencedFiles = <PluginBundleFile>[
      const PluginBundleFile(
        role: 'manifest',
        relativePath: 'plugin.n0vel.json',
      ),
      const PluginBundleFile(role: 'readme', relativePath: 'README.md'),
    ];

    for (final relativePath in manifest.referencedPaths) {
      referencedFiles.add(
        PluginBundleFile(
          role: 'manifest-reference',
          relativePath: relativePath,
        ),
      );
    }

    for (final file in referencedFiles) {
      final validation = await _validateReferencedFile(root, file.relativePath);
      errors.addAll(validation);
    }

    if (errors.isNotEmpty) {
      throw PluginInstallException(errors);
    }

    final digest = await _sha256Digest(manifestBytes);
    return PluginInstallPlan(
      bundleRootPath: root.path,
      manifest: manifest,
      manifestDigest: digest,
      referencedFiles: List.unmodifiable(referencedFiles),
    );
  }

  Future<List<String>> _validateReferencedFile(
    Directory root,
    String relativePath,
  ) async {
    final errors = <String>[];
    if (!_isSafeRelativePath(relativePath)) {
      return ['unsafe plugin file reference: $relativePath'];
    }

    final file = File(_join(root.path, relativePath));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      errors.add('referenced file does not exist: $relativePath');
    } else if (type == FileSystemEntityType.link) {
      errors.add('symlink references are not allowed: $relativePath');
    } else if (type != FileSystemEntityType.file) {
      errors.add('referenced path must be a file: $relativePath');
    }
    return errors;
  }

  Future<String> _sha256Digest(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    return 'sha256:${base64Encode(hash.bytes)}';
  }
}

String _join(String root, String relativePath) {
  final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
  if (root.endsWith(Platform.pathSeparator)) return '$root$normalized';
  return '$root${Platform.pathSeparator}$normalized';
}

bool _isSafeRelativePath(String value) {
  if (value.trim().isEmpty) return false;
  if (value.startsWith('/') || value.startsWith(r'\')) return false;
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) return false;
  if (value.contains(r'\')) return false;

  final segments = value.split('/');
  if (segments.any((segment) => segment.isEmpty)) return false;
  for (final segment in segments) {
    if (segment == '.' || segment == '..') return false;
  }
  return true;
}
