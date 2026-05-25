// ============================================================================
// Template Installer
// ============================================================================
//
// Local bundle validation and install-plan creation. This foundation does not
// copy files, write authoring storage, or execute plugin code.
//
// See M8-03: Template Market Foundation

import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'template_manifest.dart';

class TemplateInstallException implements Exception {
  const TemplateInstallException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'TemplateInstallException(${errors.join(', ')})';
}

class TemplateBundleFile {
  const TemplateBundleFile({required this.role, required this.relativePath});

  final String role;
  final String relativePath;
}

class TemplateInstallPlan {
  const TemplateInstallPlan({
    required this.bundleRootPath,
    required this.manifest,
    required this.manifestDigest,
    required this.referencedFiles,
  });

  final String bundleRootPath;
  final TemplateManifest manifest;
  final String manifestDigest;
  final List<TemplateBundleFile> referencedFiles;
}

class TemplateInstaller {
  const TemplateInstaller();

  Future<TemplateInstallPlan> createInstallPlan(Directory bundleRoot) async {
    final errors = <String>[];
    final root = bundleRoot.absolute;
    if (!await root.exists()) {
      throw TemplateInstallException([
        'template root does not exist: ${root.path}',
      ]);
    }

    final manifestFile = File(_join(root.path, 'template.n0vel.json'));
    if (!await manifestFile.exists()) {
      throw const TemplateInstallException(['template.n0vel.json is required']);
    }

    final manifestBytes = await manifestFile.readAsBytes();
    late final TemplateManifest manifest;
    try {
      manifest = TemplateManifest.fromJsonString(utf8.decode(manifestBytes));
    } on TemplateManifestException catch (e) {
      throw TemplateInstallException(e.errors);
    } on FormatException catch (e) {
      throw TemplateInstallException([
        'manifest is not valid JSON: ${e.message}',
      ]);
    }

    final referencedFiles = <TemplateBundleFile>[];
    final seen = <String>{};

    void addReferencedFile(String role, String relativePath) {
      if (!seen.add(relativePath)) return;
      referencedFiles.add(
        TemplateBundleFile(role: role, relativePath: relativePath),
      );
    }

    addReferencedFile('manifest', 'template.n0vel.json');
    addReferencedFile('readme', 'README.md');
    for (final file in manifest.starterFiles) {
      addReferencedFile(file.role, file.relativePath);
    }

    for (final file in referencedFiles) {
      final validation = await _validateReferencedFile(root, file.relativePath);
      errors.addAll(validation);
    }

    if (errors.isNotEmpty) {
      throw TemplateInstallException(errors);
    }

    final digest = await _sha256Digest(manifestBytes);
    return TemplateInstallPlan(
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
      return ['unsafe template file reference: $relativePath'];
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
