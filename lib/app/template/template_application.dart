// ============================================================================
// Template Application
// ============================================================================
//
// Converts a validated template catalog entry into an app-owned project
// creation plan. The plan is intentionally inert: callers decide when to create
// the project, write starter files, and create the initialization version.

import 'dart:io';

import 'template_catalog.dart';

class TemplateApplicationException implements Exception {
  const TemplateApplicationException(this.message);

  final String message;

  @override
  String toString() => 'TemplateApplicationException($message)';
}

class TemplateApplicationFile {
  const TemplateApplicationFile({
    required this.relativePath,
    required this.role,
    this.sourcePath,
  });

  final String relativePath;
  final String role;
  final String? sourcePath;

  Map<String, Object?> toJson() => {
    'path': relativePath,
    'role': role,
    if (sourcePath != null) 'sourcePath': sourcePath,
  };
}

class TemplateApplicationPlan {
  const TemplateApplicationPlan({
    required this.templateId,
    required this.templateVersion,
    required this.templateDisplayName,
    required this.targetProjectId,
    required this.projectName,
    required this.locale,
    required this.versionAnchorLabel,
    required this.requiresVersionAnchor,
    required this.projectMetadata,
    required this.starterFiles,
    this.genre,
    this.synopsis,
    this.pipelinePreset,
    this.uiPreset,
  });

  final String templateId;
  final String templateVersion;
  final String templateDisplayName;
  final String targetProjectId;
  final String projectName;
  final String locale;
  final String? genre;
  final String? synopsis;
  final String? pipelinePreset;
  final String? uiPreset;
  final String versionAnchorLabel;
  final bool requiresVersionAnchor;
  final Map<String, Object?> projectMetadata;
  final List<TemplateApplicationFile> starterFiles;

  bool get hasStarterFiles => starterFiles.isNotEmpty;

  Map<String, Object?> toJson() => {
    'templateId': templateId,
    'templateVersion': templateVersion,
    'templateDisplayName': templateDisplayName,
    'targetProjectId': targetProjectId,
    'projectName': projectName,
    'locale': locale,
    if (genre != null) 'genre': genre,
    if (synopsis != null) 'synopsis': synopsis,
    if (pipelinePreset != null) 'pipelinePreset': pipelinePreset,
    if (uiPreset != null) 'uiPreset': uiPreset,
    'versionAnchorLabel': versionAnchorLabel,
    'requiresVersionAnchor': requiresVersionAnchor,
    'projectMetadata': projectMetadata,
    'starterFiles': starterFiles.map((file) => file.toJson()).toList(),
  };
}

class TemplateApplicationPlanner {
  const TemplateApplicationPlanner();

  TemplateApplicationPlan createPlan(
    TemplateCatalogEntry entry, {
    required String projectName,
    String? targetProjectId,
    DateTime? now,
  }) {
    final manifest = entry.manifest;
    final resolvedProjectName = projectName.trim().isNotEmpty
        ? projectName.trim()
        : manifest.projectSeed.title;
    if (resolvedProjectName == null || resolvedProjectName.trim().isEmpty) {
      throw const TemplateApplicationException('projectName is required');
    }

    final resolvedProjectId = _resolveProjectId(
      targetProjectId: targetProjectId,
      now: now,
    );
    final locale = manifest.projectSeed.language ?? manifest.locale;
    final genre = manifest.projectSeed.genre ?? manifest.genre;
    final synopsis = manifest.projectSeed.synopsis;
    final metadata = <String, Object?>{
      'projectId': resolvedProjectId,
      'title': resolvedProjectName.trim(),
      'locale': locale,
      'templateId': manifest.templateId,
      'templateVersion': manifest.version,
      'genre': ?genre,
      'synopsis': ?synopsis,
      if (manifest.projectSeed.targetWordCount != null)
        'targetWordCount': manifest.projectSeed.targetWordCount,
      if (manifest.pipelinePreset != null)
        'pipelinePreset': manifest.pipelinePreset,
      if (manifest.uiPreset != null) 'uiPreset': manifest.uiPreset,
    };

    return TemplateApplicationPlan(
      templateId: manifest.templateId,
      templateVersion: manifest.version,
      templateDisplayName: manifest.displayName,
      targetProjectId: resolvedProjectId,
      projectName: resolvedProjectName.trim(),
      locale: locale,
      genre: genre,
      synopsis: synopsis,
      pipelinePreset: manifest.pipelinePreset,
      uiPreset: manifest.uiPreset,
      versionAnchorLabel: 'Project initialization: ${manifest.displayName}',
      requiresVersionAnchor: true,
      projectMetadata: Map.unmodifiable(metadata),
      starterFiles: List.unmodifiable(
        manifest.starterFiles.map(
          (file) => TemplateApplicationFile(
            relativePath: file.relativePath,
            role: file.role,
            sourcePath: entry.bundleRootPath == null
                ? null
                : _join(entry.bundleRootPath!, file.relativePath),
          ),
        ),
      ),
    );
  }

  String _resolveProjectId({String? targetProjectId, DateTime? now}) {
    final explicit = targetProjectId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final timestamp = (now ?? DateTime.now().toUtc()).microsecondsSinceEpoch;
    return 'project_$timestamp';
  }
}

String _join(String root, String relativePath) {
  final normalized = relativePath.replaceAll('/', Platform.pathSeparator);
  if (root.endsWith(Platform.pathSeparator)) return '$root$normalized';
  return '$root${Platform.pathSeparator}$normalized';
}
