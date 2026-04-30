import 'dart:convert';
import 'dart:io';

import '../../../app/logging/app_event_log.dart';
import '../../../app/state/app_authoring_storage_io_support.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/storage_validation.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../story_generation/data/character_memory_store_io.dart';
import '../../story_generation/data/roleplay_audit_report.dart';
import '../../story_generation/data/roleplay_session_store_io.dart';

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

class ProjectTransferService {
  ProjectTransferService({
    Directory? exportsDirectory,
    Directory? importsDirectory,
    String zipExecutable = '/usr/bin/zip',
    String unzipExecutable = '/usr/bin/unzip',
    AppEventLog? eventLog,
    this.storyMemoryExport,
    this.storyMemoryImport,
    this.roleplayStateExport,
    this.roleplayStateImport,
  }) : _exportsDirectory = exportsDirectory ?? _defaultExportsDirectory(),
       _importsDirectory = importsDirectory ?? _defaultImportsDirectory(),
       _zipExecutable = zipExecutable,
       _unzipExecutable = unzipExecutable,
       _eventLog = eventLog ?? AppEventLog();

  static const int _supportedSchemaMajor = 1;
  static const int _supportedSchemaMinor = 0;
  static const String packageFilename = 'lunaris-export.zip';
  static const String checksumsFilename = 'checksums.json';

  final Directory _exportsDirectory;
  final Directory _importsDirectory;
  final String _zipExecutable;
  final String _unzipExecutable;
  final AppEventLog _eventLog;

  /// Optional callback to export story memory data for a project.
  /// Returns a JSON-serializable map of memory records, or null if none.
  final Future<Map<String, Object?>?> Function(String projectId)?
  storyMemoryExport;

  /// Optional callback to import story memory data for a project.
  final Future<void> Function(String projectId, Map<String, Object?> data)?
  storyMemoryImport;

  /// Optional callback to export roleplay sessions and character memories.
  final Future<Map<String, Object?>?> Function(String projectId)?
  roleplayStateExport;

  /// Optional callback to import roleplay sessions and character memories.
  final Future<void> Function(String projectId, Map<String, Object?> data)?
  roleplayStateImport;

  String get exportPackagePath => '${_exportsDirectory.path}/$packageFilename';
  String get importPackagePath => '${_importsDirectory.path}/$packageFilename';

  Future<ProjectTransferResult> exportPackage({
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    required AppWorkspaceStore workspaceStore,
    AppAiHistoryStore? aiHistoryStore,
    AppSceneContextStore? sceneContextStore,
    AppSimulationStore? simulationStore,
    StoryOutlineStore? storyOutlineStore,
    StoryGenerationStore? storyGenerationStore,
  }) async {
    final correlationId = _eventLog.newCorrelationId('project-export');
    await _logTransferEvent(
      action: 'project.export.started',
      status: AppEventLogStatus.started,
      message: 'Started project export package build.',
      correlationId: correlationId,
      projectId: workspaceStore.currentProjectId.isEmpty
          ? null
          : workspaceStore.currentProjectId,
      metadata: {
        'packagePath': exportPackagePath,
        'hasAiHistory': aiHistoryStore != null,
        'hasSceneContext': sceneContextStore != null,
        'hasSimulation': simulationStore != null,
        'hasOutline': storyOutlineStore != null,
        'hasGenerationState': storyGenerationStore != null,
      },
    );
    if (workspaceStore.projects.isEmpty) {
      await _logTransferEvent(
        action: 'project.export.failed',
        status: AppEventLogStatus.warning,
        message: 'Project export skipped because no project is available.',
        correlationId: correlationId,
        errorCode: 'no_exportable_project',
        metadata: {'packagePath': exportPackagePath},
      );
      return ProjectTransferResult(
        state: ProjectTransferState.noExportableProject,
        packagePath: exportPackagePath,
      );
    }

    final currentProject = workspaceStore.currentProject;
    final manifest = ProjectPackageManifest(
      packageName: 'lunarifest',
      projectId: currentProject.id,
      projectTitle: currentProject.title,
      schemaMajor: _supportedSchemaMajor,
      schemaMinor: _supportedSchemaMinor,
      exportedAtMs: DateTime.now().millisecondsSinceEpoch,
      contentSummary: '正文 / 资料 / 风格 / 版本',
    );

    final stagingDirectory = await Directory.systemTemp.createTemp(
      'novel_writer_project_export',
    );
    try {
      final exportFutures = <Future<void>>[
        File(
          '${stagingDirectory.path}/manifest.json',
        ).writeAsString(jsonEncode(manifest.toJson())),
        File(
          '${stagingDirectory.path}/workspace.json',
        ).writeAsString(jsonEncode(workspaceStore.exportCurrentProjectJson())),
        File(
          '${stagingDirectory.path}/draft.json',
        ).writeAsString(jsonEncode(draftStore.exportJson())),
        File(
          '${stagingDirectory.path}/versions.json',
        ).writeAsString(jsonEncode(versionStore.exportJson())),
        if (aiHistoryStore != null)
          File(
            '${stagingDirectory.path}/ai_history.json',
          ).writeAsString(jsonEncode(aiHistoryStore.exportJson())),
        if (sceneContextStore != null)
          File(
            '${stagingDirectory.path}/scene_context.json',
          ).writeAsString(jsonEncode(sceneContextStore.exportJson())),
        if (simulationStore != null)
          File(
            '${stagingDirectory.path}/simulation.json',
          ).writeAsString(jsonEncode(simulationStore.exportJson())),
        if (storyOutlineStore != null)
          File(
            '${stagingDirectory.path}/outline.json',
          ).writeAsString(jsonEncode(storyOutlineStore.exportJson())),
        if (storyGenerationStore != null)
          File(
            '${stagingDirectory.path}/generation_state.json',
          ).writeAsString(jsonEncode(storyGenerationStore.exportJson())),
      ];

      // Story memory: fetch async data, then append write future
      if (storyMemoryExport != null) {
        final memoryData = await storyMemoryExport!(currentProject.id);
        if (memoryData != null) {
          exportFutures.add(
            File(
              '${stagingDirectory.path}/story_memory.json',
            ).writeAsString(jsonEncode(memoryData)),
          );
        }
      }
      final roleplayExporter =
          roleplayStateExport ?? exportRoleplayStateForProject;
      final roleplayStateData = await roleplayExporter(currentProject.id);
      if (roleplayStateData != null) {
        exportFutures.add(
          File(
            '${stagingDirectory.path}/roleplay_state.json',
          ).writeAsString(jsonEncode(roleplayStateData)),
        );
        final auditReports = roleplayStateData['auditReports'];
        if (auditReports is List && auditReports.isNotEmpty) {
          exportFutures.add(
            File(
              '${stagingDirectory.path}/roleplay_audit.json',
            ).writeAsString(jsonEncode({'reports': auditReports})),
          );
        }
        final auditMarkdown = roleplayStateData['auditMarkdown'];
        if (auditMarkdown is String && auditMarkdown.trim().isNotEmpty) {
          exportFutures.add(
            File(
              '${stagingDirectory.path}/roleplay_audit.md',
            ).writeAsString(auditMarkdown),
          );
        }
      }

      await Future.wait(exportFutures);

      final checksums = <String, String>{};
      for (final entity in stagingDirectory.listSync()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name == checksumsFilename) continue;
          checksums[name] = computePayloadChecksum(await entity.readAsString());
        }
      }
      await File(
        '${stagingDirectory.path}/$checksumsFilename',
      ).writeAsString(jsonEncode(checksums));

      await _exportsDirectory.create(recursive: true);
      final packageFile = File(exportPackagePath).absolute;
      if (await packageFile.exists()) {
        await packageFile.delete();
      }
      final zipResult = await Process.run(_zipExecutable, [
        '-qr',
        packageFile.path,
        '.',
      ], workingDirectory: stagingDirectory.path);
      if (zipResult.exitCode != 0) {
        await _logTransferEvent(
          action: 'project.export.failed',
          status: AppEventLogStatus.failed,
          message: 'Project export zip command failed.',
          correlationId: correlationId,
          projectId: currentProject.id,
          errorCode: 'export_zip_failed',
          errorDetail: zipResult.stderr?.toString(),
          metadata: {
            'packagePath': packageFile.path,
            'exitCode': zipResult.exitCode,
          },
        );
        return ProjectTransferResult(
          state: ProjectTransferState.invalidPackage,
          packagePath: packageFile.path,
          manifest: manifest,
        );
      }
      await _logTransferEvent(
        action: 'project.export.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'Project export package was created.',
        correlationId: correlationId,
        projectId: currentProject.id,
        metadata: {
          'packagePath': packageFile.path,
          'schemaLabel': manifest.schemaLabel,
        },
      );
      return ProjectTransferResult(
        state: ProjectTransferState.exportSuccess,
        packagePath: packageFile.path,
        manifest: manifest,
      );
    } catch (error) {
      await _logTransferEvent(
        action: 'project.export.failed',
        status: AppEventLogStatus.failed,
        message: 'Project export failed unexpectedly.',
        correlationId: correlationId,
        projectId: currentProject.id,
        errorCode: 'export_exception',
        errorDetail: error.toString(),
        metadata: {'packagePath': exportPackagePath},
      );
      rethrow;
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }
  }

  Future<ProjectPackageInspection> inspectPackage(File packageFile) async {
    final correlationId = _eventLog.newCorrelationId('project-import-inspect');
    await _logTransferEvent(
      action: 'project.import.inspect.started',
      status: AppEventLogStatus.started,
      message: 'Started project package inspection.',
      correlationId: correlationId,
      metadata: {'packagePath': packageFile.path},
    );
    if (!await packageFile.exists()) {
      await _logTransferEvent(
        action: 'project.import.inspect.failed',
        status: AppEventLogStatus.failed,
        message:
            'Project package inspection failed because the package is missing.',
        correlationId: correlationId,
        errorCode: 'invalid_package',
        metadata: {'packagePath': packageFile.path},
      );
      return ProjectPackageInspection(
        state: ProjectTransferState.invalidPackage,
        packagePath: packageFile.path,
      );
    }

    final extraction = await _extractPackage(packageFile);
    try {
      if (extraction == null) {
        await _logTransferEvent(
          action: 'project.import.inspect.failed',
          status: AppEventLogStatus.failed,
          message: 'Project package inspection failed during extraction.',
          correlationId: correlationId,
          errorCode: 'invalid_package',
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectPackageInspection(
          state: ProjectTransferState.invalidPackage,
          packagePath: packageFile.path,
        );
      }

      final manifestFile = File('${extraction.path}/manifest.json');
      if (!await manifestFile.exists()) {
        await _logTransferEvent(
          action: 'project.import.inspect.failed',
          status: AppEventLogStatus.failed,
          message:
              'Project package inspection failed because manifest.json is missing.',
          correlationId: correlationId,
          errorCode: 'missing_manifest',
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectPackageInspection(
          state: ProjectTransferState.missingManifest,
          packagePath: packageFile.path,
        );
      }

      final manifestRaw = await manifestFile.readAsString();
      final manifestJson = jsonDecode(manifestRaw);
      if (manifestJson is! Map<String, Object?>) {
        await _logTransferEvent(
          action: 'project.import.inspect.failed',
          status: AppEventLogStatus.failed,
          message:
              'Project package inspection failed because the manifest is malformed.',
          correlationId: correlationId,
          errorCode: 'invalid_package',
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectPackageInspection(
          state: ProjectTransferState.invalidPackage,
          packagePath: packageFile.path,
        );
      }

      final manifest = ProjectPackageManifest.fromJson(manifestJson);
      if (manifest.schemaMajor != _supportedSchemaMajor) {
        await _logTransferEvent(
          action: 'project.import.inspect.failed',
          status: AppEventLogStatus.failed,
          message:
              'Project package inspection blocked due to unsupported schema major version.',
          correlationId: correlationId,
          projectId: manifest.projectId,
          errorCode: 'schema_major_blocked',
          metadata: {
            'packagePath': packageFile.path,
            'schemaMajor': manifest.schemaMajor,
          },
        );
        return ProjectPackageInspection(
          state: ProjectTransferState.majorVersionBlocked,
          packagePath: packageFile.path,
          manifest: manifest,
        );
      }

      if (manifest.schemaMinor != _supportedSchemaMinor) {
        await _logTransferEvent(
          action: 'project.import.inspect.warning',
          status: AppEventLogStatus.warning,
          message:
              'Project package inspection detected a schema minor-version mismatch.',
          correlationId: correlationId,
          projectId: manifest.projectId,
          metadata: {
            'packagePath': packageFile.path,
            'schemaMinor': manifest.schemaMinor,
          },
        );
        return ProjectPackageInspection(
          state: ProjectTransferState.minorVersionWarning,
          packagePath: packageFile.path,
          manifest: manifest,
        );
      }

      await _logTransferEvent(
        action: 'project.import.inspect.succeeded',
        status: AppEventLogStatus.succeeded,
        message: 'Project package inspection completed successfully.',
        correlationId: correlationId,
        projectId: manifest.projectId,
        metadata: {
          'packagePath': packageFile.path,
          'schemaLabel': manifest.schemaLabel,
        },
      );
      return ProjectPackageInspection(
        state: ProjectTransferState.ready,
        packagePath: packageFile.path,
        manifest: manifest,
      );
    } on FormatException {
      await _logTransferEvent(
        action: 'project.import.inspect.failed',
        status: AppEventLogStatus.failed,
        message:
            'Project package inspection failed because the package payload is malformed.',
        correlationId: correlationId,
        errorCode: 'invalid_package',
        metadata: {'packagePath': packageFile.path},
      );
      return ProjectPackageInspection(
        state: ProjectTransferState.invalidPackage,
        packagePath: packageFile.path,
      );
    } finally {
      if (extraction != null && await extraction.exists()) {
        await extraction.delete(recursive: true);
      }
    }
  }

  Future<ProjectTransferResult> importPackage({
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    required AppWorkspaceStore workspaceStore,
    AppAiHistoryStore? aiHistoryStore,
    AppSceneContextStore? sceneContextStore,
    AppSimulationStore? simulationStore,
    StoryOutlineStore? storyOutlineStore,
    StoryGenerationStore? storyGenerationStore,
    bool overwriteExisting = false,
  }) async {
    final correlationId = _eventLog.newCorrelationId('project-import');
    await _logTransferEvent(
      action: 'project.import.started',
      status: AppEventLogStatus.started,
      message: 'Started project import package apply.',
      correlationId: correlationId,
      metadata: {
        'packagePath': importPackagePath,
        'overwriteExisting': overwriteExisting,
      },
    );
    final packageFile = File(importPackagePath);
    final inspection = await inspectPackage(packageFile);
    if (inspection.state != ProjectTransferState.ready &&
        inspection.state != ProjectTransferState.minorVersionWarning) {
      await _logTransferEvent(
        action: 'project.import.failed',
        status: inspection.state == ProjectTransferState.overwriteConfirm
            ? AppEventLogStatus.warning
            : AppEventLogStatus.failed,
        message:
            'Project import stopped before apply because inspection did not pass.',
        correlationId: correlationId,
        projectId: inspection.manifest?.projectId,
        errorCode: inspection.state.name,
        metadata: {
          'packagePath': inspection.packagePath,
          'inspectionState': inspection.state.name,
        },
      );
      return ProjectTransferResult(
        state: inspection.state,
        packagePath: inspection.packagePath,
        manifest: inspection.manifest,
      );
    }

    final manifest = inspection.manifest;
    if (manifest != null &&
        manifest.projectId.isNotEmpty &&
        workspaceStore.hasProjectWithId(manifest.projectId) &&
        !overwriteExisting) {
      await _logTransferEvent(
        action: 'project.import.warning',
        status: AppEventLogStatus.warning,
        message: 'Project import requires overwrite confirmation.',
        correlationId: correlationId,
        projectId: manifest.projectId,
        metadata: {'packagePath': packageFile.path},
      );
      return ProjectTransferResult(
        state: ProjectTransferState.overwriteConfirm,
        packagePath: packageFile.path,
        manifest: manifest,
      );
    }

    final extraction = await _extractPackage(packageFile);
    try {
      if (extraction == null) {
        await _logTransferEvent(
          action: 'project.import.failed',
          status: AppEventLogStatus.failed,
          message: 'Project import failed during package extraction.',
          correlationId: correlationId,
          projectId: inspection.manifest?.projectId,
          errorCode: 'invalid_package',
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectTransferResult(
          state: ProjectTransferState.invalidPackage,
          packagePath: packageFile.path,
        );
      }

      final workspaceFile = File('${extraction.path}/workspace.json');
      final draftFile = File('${extraction.path}/draft.json');
      final versionsFile = File('${extraction.path}/versions.json');
      if (!await workspaceFile.exists() ||
          !await draftFile.exists() ||
          !await versionsFile.exists()) {
        await _logTransferEvent(
          action: 'project.import.failed',
          status: AppEventLogStatus.failed,
          message:
              'Project import failed because required payload files are missing.',
          correlationId: correlationId,
          projectId: inspection.manifest?.projectId,
          errorCode: 'invalid_package',
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectTransferResult(
          state: ProjectTransferState.invalidPackage,
          packagePath: packageFile.path,
          manifest: inspection.manifest,
        );
      }

      if (!await _verifyPackageChecksums(extraction)) {
        await _logTransferEvent(
          action: 'project.import.failed',
          status: AppEventLogStatus.failed,
          message:
              'Project import failed because payload checksum verification failed.',
          correlationId: correlationId,
          projectId: inspection.manifest?.projectId,
          errorCode: 'integrity_check_failed',
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectTransferResult(
          state: ProjectTransferState.integrityCheckFailed,
          packagePath: packageFile.path,
          manifest: inspection.manifest,
        );
      }

      final requiredJson = await Future.wait([
        workspaceFile.readAsString(),
        draftFile.readAsString(),
        versionsFile.readAsString(),
      ]);
      final workspaceJson = _decodeObjectMap(jsonDecode(requiredJson[0]));
      final draftJson = _decodeObjectMap(jsonDecode(requiredJson[1]));
      final versionsJson = _decodeObjectMap(jsonDecode(requiredJson[2]));

      final validationErrors = WorkspaceDataValidator().validateWorkspaceData(
        workspaceJson,
      );
      if (validationErrors.hasErrors) {
        await _logTransferEvent(
          action: 'project.import.failed',
          status: AppEventLogStatus.failed,
          message:
              'Project import failed because workspace data validation detected errors.',
          correlationId: correlationId,
          projectId: inspection.manifest?.projectId,
          errorCode: 'integrity_validation_failed',
          errorDetail: validationErrors.errors
              .map((e) => e.toString())
              .join('; '),
          metadata: {'packagePath': packageFile.path},
        );
        return ProjectTransferResult(
          state: ProjectTransferState.integrityCheckFailed,
          packagePath: packageFile.path,
          manifest: inspection.manifest,
        );
      }

      workspaceStore.importProjectJson(
        workspaceJson,
        overwriteExisting: overwriteExisting,
      );
      draftStore.importJson(draftJson);
      versionStore.importJson(versionsJson);

      // Read and apply optional stores in parallel
      final optionalImports = await Future.wait([
        _readOptionalImport(extraction, 'ai_history.json'),
        _readOptionalImport(extraction, 'scene_context.json'),
        _readOptionalImport(extraction, 'simulation.json'),
        _readOptionalImport(extraction, 'outline.json'),
        _readOptionalImport(extraction, 'generation_state.json'),
      ]);
      if (aiHistoryStore != null && optionalImports[0] != null) {
        aiHistoryStore.importJson(optionalImports[0]!);
      }
      if (sceneContextStore != null && optionalImports[1] != null) {
        sceneContextStore.importJson(optionalImports[1]!);
      }
      if (simulationStore != null && optionalImports[2] != null) {
        simulationStore.importJson(optionalImports[2]!);
      }
      if (storyOutlineStore != null && optionalImports[3] != null) {
        storyOutlineStore.importJson(optionalImports[3]!);
      }
      if (storyGenerationStore != null && optionalImports[4] != null) {
        storyGenerationStore.importJson(optionalImports[4]!);
      }

      // Story memory section (backward compatible: absent = empty)
      final memoryFile = File('${extraction.path}/story_memory.json');
      if (storyMemoryImport != null &&
          manifest != null &&
          await memoryFile.exists()) {
        await storyMemoryImport!(
          manifest.projectId,
          _decodeObjectMap(jsonDecode(await memoryFile.readAsString())),
        );
      }
      final roleplayStateFile = File('${extraction.path}/roleplay_state.json');
      final roleplayImporter =
          roleplayStateImport ?? importRoleplayStateForProject;
      if (manifest != null && await roleplayStateFile.exists()) {
        await roleplayImporter(
          manifest.projectId,
          _decodeObjectMap(jsonDecode(await roleplayStateFile.readAsString())),
        );
      }

      await _logTransferEvent(
        action: overwriteExisting
            ? 'project.import.succeeded'
            : 'project.import.succeeded',
        status: AppEventLogStatus.succeeded,
        message: overwriteExisting
            ? 'Project import overwrite completed successfully.'
            : 'Project import completed successfully.',
        correlationId: correlationId,
        projectId: inspection.manifest?.projectId,
        metadata: {
          'packagePath': packageFile.path,
          'overwriteExisting': overwriteExisting,
        },
      );
      return ProjectTransferResult(
        state: overwriteExisting
            ? ProjectTransferState.overwriteSuccess
            : ProjectTransferState.importSuccess,
        packagePath: packageFile.path,
        manifest: inspection.manifest,
      );
    } on FormatException catch (error) {
      await _logTransferEvent(
        action: 'project.import.failed',
        status: AppEventLogStatus.failed,
        message: 'Project import failed because one payload file is malformed.',
        correlationId: correlationId,
        projectId: inspection.manifest?.projectId,
        errorCode: 'invalid_package',
        errorDetail: error.toString(),
        metadata: {'packagePath': packageFile.path},
      );
      return ProjectTransferResult(
        state: ProjectTransferState.invalidPackage,
        packagePath: packageFile.path,
        manifest: inspection.manifest,
      );
    } catch (error) {
      await _logTransferEvent(
        action: 'project.import.failed',
        status: AppEventLogStatus.failed,
        message: 'Project import failed unexpectedly.',
        correlationId: correlationId,
        projectId: inspection.manifest?.projectId,
        errorCode: 'import_exception',
        errorDetail: error.toString(),
        metadata: {'packagePath': packageFile.path},
      );
      rethrow;
    } finally {
      if (extraction != null && await extraction.exists()) {
        await extraction.delete(recursive: true);
      }
    }
  }

  Future<Directory?> _extractPackage(File packageFile) async {
    final extraction = await Directory.systemTemp.createTemp(
      'novel_writer_project_import',
    );
    final unzipResult = await Process.run(_unzipExecutable, [
      '-oq',
      packageFile.path,
      '-d',
      extraction.path,
    ]);
    if (unzipResult.exitCode != 0) {
      if (await extraction.exists()) {
        await extraction.delete(recursive: true);
      }
      return null;
    }
    return extraction;
  }

  Future<bool> _verifyPackageChecksums(Directory extraction) async {
    final checksumsFile = File('${extraction.path}/$checksumsFilename');
    if (!await checksumsFile.exists()) return true;
    final checksumsMap = _decodeObjectMap(
      jsonDecode(await checksumsFile.readAsString()),
    );
    for (final entry in checksumsMap.entries) {
      final payloadFile = File('${extraction.path}/${entry.key}');
      if (!await payloadFile.exists()) continue;
      final actual = computePayloadChecksum(await payloadFile.readAsString());
      if (actual != entry.value.toString()) return false;
    }
    return true;
  }

  Map<String, Object?> _decodeObjectMap(Object? raw) {
    return decodeProjectTransferObjectMap(raw);
  }

  Future<Map<String, Object?>?> _readOptionalImport(
    Directory extraction,
    String filename,
  ) async {
    final file = File('${extraction.path}/$filename');
    if (!await file.exists()) return null;
    return _decodeObjectMap(jsonDecode(await file.readAsString()));
  }

  static Directory _defaultExportsDirectory() {
    return resolveProjectTransferExportsDirectory();
  }

  static Directory _defaultImportsDirectory() {
    return resolveProjectTransferImportsDirectory();
  }

  Future<void> _logTransferEvent({
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
    return _eventLog.logBestEffort(
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
      if (roleplayData != null) 'roleplaySessions': roleplayData,
      if (memoryData != null) 'characterMemories': memoryData,
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

Map<String, Object?> decodeProjectTransferObjectMap(Object? raw) {
  if (raw is Map<String, Object?>) {
    return raw;
  }
  if (raw is Map) {
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }
  throw const FormatException('Expected object map payload.');
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
