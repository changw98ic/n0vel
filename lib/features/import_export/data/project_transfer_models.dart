import 'dart:convert';
import 'dart:io';

import '../../../app/logging/app_event_log.dart';
import '../../../app/state/app_authoring_storage_io_support.dart';
import '../../../domain/workspace_models.dart';
import '../../story_generation/data/character_memory_store_io.dart';
import '../../story_generation/data/roleplay_audit_report.dart';
import '../../story_generation/data/roleplay_session_store_io.dart';
import 'store_payload_contributor.dart';

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
      packageName: (json['name'] as String?) ?? '小说工程包',
      projectId: (json['project_id'] as String?) ?? '',
      projectTitle: fallbackManifestText(
        json['project_title'],
        fallback: '导入项目',
      ),
      schemaMajor: (json['schema_major'] as int?) ?? 1,
      schemaMinor: (json['schema_minor'] as int?) ?? 0,
      exportedAtMs: (json['exported_at_ms'] as int?) ?? 0,
      contentSummary:
          (json['content_summary'] as String?) ?? '正文 / 资料 / 风格 / 版本',
    );
  }
}

String fallbackManifestText(Object? raw, {required String fallback}) {
  final trimmed = raw?.toString().trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
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
  if (homeOverride == null && Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory('$userProfile\\Documents\\NovelWriter\\exports');
    }
    return Directory('./exports');
  }
  final home = homeOverride ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return Directory('./exports');
  }
  return Directory('$home/Documents/NovelWriter/exports');
}

Directory resolveProjectTransferImportsDirectory({String? homeOverride}) {
  if (homeOverride == null && Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return Directory('$userProfile\\Documents\\NovelWriter\\imports');
    }
    return Directory('./imports');
  }
  final home = homeOverride ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return Directory('./imports');
  }
  return Directory('$home/Documents/NovelWriter/imports');
}

class DecodedStorePayload {
  const DecodedStorePayload({required this.payload, required this.data});

  final StorePayloadContributor payload;
  final Map<String, Object?> data;
}

String computePayloadChecksum(String content) {
  final bytes = utf8.encode(content);
  var hash = 0x811c9dc5;
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}

Future<Map<String, Object?>?> exportRoleplayStateForProject(
  String projectId,
) async {
  final database = openAuthoringDatabase(resolveAuthoringDbPath());
  try {
    final roleplayData = await RoleplaySessionStoreIO(
      db: database,
    ).exportProjectJson(projectId);
    final roleplayStore = RoleplaySessionStoreIO(db: database);
    final sessions = await roleplayStore.loadProjectSessions(
      projectId: projectId,
    );
    final auditReports = const RoleplayAuditReportBuilder().buildAll(sessions);
    final memoryData = await CharacterMemoryStoreIO(
      db: database,
    ).exportProjectJson(projectId);
    if (roleplayData == null && memoryData == null && auditReports.isEmpty) {
      return null;
    }
    return {
      'roleplaySessions': ?roleplayData,
      'characterMemories': ?memoryData,
      if (auditReports.isNotEmpty)
        'auditReports': [for (final report in auditReports) report.toJson()],
      if (auditReports.isNotEmpty)
        'auditMarkdown': auditReports
            .map((report) => report.toMarkdown())
            .join('\n\n'),
    };
  } finally {
    database.dispose();
  }
}

Future<void> importRoleplayStateForProject(
  String projectId,
  Map<String, Object?> data,
) async {
  final database = openAuthoringDatabase(resolveAuthoringDbPath());
  try {
    final roleplayRaw = data['roleplaySessions'];
    if (roleplayRaw is Map) {
      await RoleplaySessionStoreIO(
        db: database,
      ).importProjectJson(projectId, Map<String, Object?>.from(roleplayRaw));
    }
    final memoryRaw = data['characterMemories'];
    if (memoryRaw is Map) {
      await CharacterMemoryStoreIO(
        db: database,
      ).importProjectJson(projectId, Map<String, Object?>.from(memoryRaw));
    }
  } finally {
    database.dispose();
  }
}

// ---------------------------------------------------------------------------
// Shared transfer constants
// ---------------------------------------------------------------------------

/// Schema major version supported by this build.
const int projectTransferSchemaMajor = 1;

/// Schema minor version supported by this build.
const int projectTransferSchemaMinor = 0;

/// Default filename for the export/import zip package.
const String projectTransferPackageFilename = '月临-导出.zip';

/// Filename for the checksum manifest inside the zip package.
const String projectTransferChecksumsFilename = 'checksums.json';

// ---------------------------------------------------------------------------
// Shared transfer logging helper
// ---------------------------------------------------------------------------

/// Centralised best-effort logging for import/export transfer events.
Future<void> logTransferEvent(
  AppEventLog eventLog, {
  required String action,
  required AppEventLogStatus status,
  required String message,
  String? correlationId,
  String? projectId,
  String? sceneId,
  AppEventLogLevel level = AppEventLogLevel.info,
  String? errorCode,
  String? errorDetail,
  Map<String, Object?> metadata = const <String, Object?>{},
}) {
  return eventLog.logBestEffort(
    level: level,
    category: AppEventLogCategory.importExport,
    action: action,
    status: status,
    message: message,
    correlationId: correlationId,
    projectId: projectId,
    sceneId: sceneId,
    errorCode: errorCode,
    errorDetail: errorDetail,
    metadata: metadata,
  );
}
