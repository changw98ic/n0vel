import 'dart:io';

import '../../../app/state/app_workspace_records.dart';

class ProjectPackageManifest {
  const ProjectPackageManifest({
    required this.packageName,
    required this.projectId,
    required this.projectTitle,
    required this.schemaMajor,
    required this.schemaMinor,
    required this.exportedAtMs,
    required this.contentSummary,
  });

  final String packageName;
  final String projectId;
  final String projectTitle;
  final int schemaMajor;
  final int schemaMinor;
  final int exportedAtMs;
  final String contentSummary;

  String get schemaLabel => 'v$schemaMajor.$schemaMinor';

  Map<String, Object?> toJson() {
    return {
      'name': packageName,
      'project_id': projectId,
      'project_title': projectTitle,
      'schema_major': schemaMajor,
      'schema_minor': schemaMinor,
      'exported_at_ms': exportedAtMs,
      'content_summary': contentSummary,
    };
  }

  static ProjectPackageManifest fromJson(Map<String, Object?> json) {
    return ProjectPackageManifest(
      packageName: (json['name'] as String?) ?? 'lunarifest',
      projectId: (json['project_id'] as String?) ?? '',
      projectTitle: (json['project_title'] as String?) ?? '未命名项目',
      schemaMajor: (json['schema_major'] as int?) ?? 1,
      schemaMinor: (json['schema_minor'] as int?) ?? 0,
      exportedAtMs: (json['exported_at_ms'] as int?) ?? 0,
      contentSummary:
          (json['content_summary'] as String?) ?? '正文 / 资料 / 风格 / 版本',
    );
  }
}

class ProjectPackageInspection {
  const ProjectPackageInspection({
    required this.state,
    required this.packagePath,
    this.manifest,
  });

  final ProjectTransferState state;
  final String packagePath;
  final ProjectPackageManifest? manifest;
}

class ProjectTransferResult {
  const ProjectTransferResult({
    required this.state,
    required this.packagePath,
    this.manifest,
  });

  final ProjectTransferState state;
  final String packagePath;
  final ProjectPackageManifest? manifest;
}

Map<String, Object?> decodeProjectTransferObjectMap(Object? raw) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  if (raw is Map) {
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }
  throw const FormatException('Expected object map payload.');
}

Directory resolveProjectTransferExportsDirectory({String? homeOverride}) {
  final home = homeOverride ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return Directory('./exports');
  }
  return Directory('$home/Documents/NovelWriter/exports');
}

Directory resolveProjectTransferImportsDirectory({String? homeOverride}) {
  final home = homeOverride ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return Directory('./imports');
  }
  return Directory('$home/Documents/NovelWriter/imports');
}
