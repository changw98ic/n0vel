import 'dart:convert';
import 'dart:io';

import '../../../app/logging/app_event_log.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/storage_validation.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import 'export_config.dart';
import 'export_dtos.dart';
import 'project_transfer_models.dart';
import 'store_payload_contributor.dart';

export 'project_transfer_models.dart';

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
  static const String packageFilename = '月临-导出.zip';
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
    ExportConfig config = ExportConfig.full,
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
      packageName: '小说工程包',
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
      final storePayloads = _storePayloadContributors(
        draftStore: draftStore,
        versionStore: versionStore,
        aiHistoryStore: aiHistoryStore,
        sceneContextStore: sceneContextStore,
        simulationStore: simulationStore,
        storyOutlineStore: storyOutlineStore,
        storyGenerationStore: storyGenerationStore,
      );

      // Apply ExportConfig filtering to workspace JSON.
      final rawWorkspaceJson = workspaceStore.exportCurrentProjectJson();
      final filteredWorkspaceJson = ExportFilter.filterWorkspaceJson(
        rawWorkspaceJson,
        config,
      );

      // Build sync payload contributors filtered by config.
      final filteredPayloads = _filterPayloadsByConfig(storePayloads, config);

      // Build async payload contributors filtered by config.
      final asyncPayloads = _asyncStorePayloadContributors();
      final filteredAsyncPayloads = _filterAsyncPayloadsByConfig(
        asyncPayloads,
        config,
      );

      final exportFutures = <Future<void>>[
        File(
          '${stagingDirectory.path}/manifest.json',
        ).writeAsString(jsonEncode(manifest.toJson())),
        File(
          '${stagingDirectory.path}/workspace.json',
        ).writeAsString(jsonEncode(filteredWorkspaceJson)),
        for (final payload in filteredPayloads)
          _writeFilteredStorePayload(stagingDirectory, payload, config),
        _writeFilteredAsyncStorePayloads(
          stagingDirectory,
          filteredAsyncPayloads,
          currentProject.id,
          config,
        ),
      ];

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
      final requiredStorePayloads = _requiredStorePayloadContributors(
        draftStore: draftStore,
        versionStore: versionStore,
      );
      if (!await workspaceFile.exists() ||
          !await _hasRequiredStorePayloads(extraction, requiredStorePayloads)) {
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

      final workspaceJson = _decodeObjectMap(
        jsonDecode(await workspaceFile.readAsString()),
      );

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
      await _importStorePayloads(extraction, requiredStorePayloads);
      await _importStorePayloads(
        extraction,
        _optionalStorePayloadContributors(
          aiHistoryStore: aiHistoryStore,
          sceneContextStore: sceneContextStore,
          simulationStore: simulationStore,
          storyOutlineStore: storyOutlineStore,
          storyGenerationStore: storyGenerationStore,
        ),
      );
      await _importAsyncStorePayloads(
        extraction,
        _asyncStorePayloadContributors(),
        manifest?.projectId,
      );

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

  List<StorePayloadContributor> _storePayloadContributors({
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
    AppAiHistoryStore? aiHistoryStore,
    AppSceneContextStore? sceneContextStore,
    AppSimulationStore? simulationStore,
    StoryOutlineStore? storyOutlineStore,
    StoryGenerationStore? storyGenerationStore,
  }) {
    return [
      ..._requiredStorePayloadContributors(
        draftStore: draftStore,
        versionStore: versionStore,
      ),
      ..._optionalStorePayloadContributors(
        aiHistoryStore: aiHistoryStore,
        sceneContextStore: sceneContextStore,
        simulationStore: simulationStore,
        storyOutlineStore: storyOutlineStore,
        storyGenerationStore: storyGenerationStore,
      ),
    ];
  }

  List<StorePayloadContributor> _requiredStorePayloadContributors({
    required AppDraftStore draftStore,
    required AppVersionStore versionStore,
  }) {
    return [
      JsonStorePayloadContributor(
        filename: 'draft.json',
        exportJson: draftStore.exportJson,
        importJson: draftStore.importJson,
      ),
      JsonStorePayloadContributor(
        filename: 'versions.json',
        exportJson: versionStore.exportJson,
        importJson: versionStore.importJson,
      ),
    ];
  }

  List<StorePayloadContributor> _optionalStorePayloadContributors({
    AppAiHistoryStore? aiHistoryStore,
    AppSceneContextStore? sceneContextStore,
    AppSimulationStore? simulationStore,
    StoryOutlineStore? storyOutlineStore,
    StoryGenerationStore? storyGenerationStore,
  }) {
    return [
      if (aiHistoryStore != null)
        JsonStorePayloadContributor(
          filename: 'ai_history.json',
          exportJson: aiHistoryStore.exportJson,
          importJson: aiHistoryStore.importJson,
        ),
      if (sceneContextStore != null)
        JsonStorePayloadContributor(
          filename: 'scene_context.json',
          exportJson: sceneContextStore.exportJson,
          importJson: sceneContextStore.importJson,
        ),
      if (simulationStore != null)
        JsonStorePayloadContributor(
          filename: 'simulation.json',
          exportJson: simulationStore.exportJson,
          importJson: simulationStore.importJson,
        ),
      if (storyOutlineStore != null)
        JsonStorePayloadContributor(
          filename: 'outline.json',
          exportJson: storyOutlineStore.exportJson,
          importJson: storyOutlineStore.importJson,
        ),
      if (storyGenerationStore != null)
        JsonStorePayloadContributor(
          filename: 'generation_state.json',
          exportJson: storyGenerationStore.exportJson,
          importJson: storyGenerationStore.importJson,
        ),
    ];
  }

  List<AsyncStorePayloadContributor> _asyncStorePayloadContributors() {
    return [
      _storyMemoryPayloadContributor(),
      _roleplayStatePayloadContributor(),
    ];
  }

  AsyncStorePayloadContributor _storyMemoryPayloadContributor() {
    return AsyncJsonStorePayloadContributor(
      filename: 'story_memory.json',
      exportJson: (projectId) async {
        final exporter = storyMemoryExport;
        if (exporter == null) return null;
        return exporter(projectId);
      },
      importJson: (projectId, data) async {
        final importer = storyMemoryImport;
        if (importer == null) return;
        await importer(projectId, data);
      },
    );
  }

  AsyncStorePayloadContributor _roleplayStatePayloadContributor() {
    return AsyncJsonStorePayloadContributor(
      filename: 'roleplay_state.json',
      exportJson: (projectId) {
        final exporter = roleplayStateExport ?? exportRoleplayStateForProject;
        return exporter(projectId);
      },
      importJson: (projectId, data) {
        final importer = roleplayStateImport ?? importRoleplayStateForProject;
        return importer(projectId, data);
      },
      exportSidecars: _roleplayStateSidecars,
    );
  }

  Iterable<StorePayloadSidecar> _roleplayStateSidecars(
    Map<String, Object?> data,
  ) {
    final auditReports = data['auditReports'];
    final auditMarkdown = data['auditMarkdown'];
    return [
      if (auditReports is List && auditReports.isNotEmpty)
        StorePayloadSidecar.json(
          filename: 'roleplay_audit.json',
          data: {'reports': auditReports},
        ),
      if (auditMarkdown is String && auditMarkdown.trim().isNotEmpty)
        StorePayloadSidecar.text(
          filename: 'roleplay_audit.md',
          content: auditMarkdown,
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Config-aware payload filtering
  // ---------------------------------------------------------------------------

  /// Map each sync payload filename to its [ExportEntityType].
  static ExportEntityType? _entityTypeForFilename(String filename) {
    return switch (filename) {
      'draft.json' => ExportEntityType.drafts,
      'versions.json' => ExportEntityType.versions,
      'ai_history.json' => ExportEntityType.aiHistory,
      'scene_context.json' => ExportEntityType.sceneContext,
      'simulation.json' => ExportEntityType.simulations,
      'outline.json' => ExportEntityType.outlines,
      'generation_state.json' => ExportEntityType.generationState,
      _ => null,
    };
  }

  /// Map each async payload filename to its [ExportEntityType].
  static ExportEntityType? _asyncEntityTypeForFilename(String filename) {
    return switch (filename) {
      'story_memory.json' => ExportEntityType.storyMemory,
      'roleplay_state.json' => ExportEntityType.roleplayState,
      _ => null,
    };
  }

  /// Filter sync payloads by [config], excluding entities the config skips.
  List<StorePayloadContributor> _filterPayloadsByConfig(
    List<StorePayloadContributor> payloads,
    ExportConfig config,
  ) {
    return [
      for (final payload in payloads)
        if (_entityTypeForFilename(payload.filename)
            case final type?
            when config.shouldExport(type))
          payload,
    ];
  }

  /// Filter async payloads by [config], excluding entities the config skips.
  List<AsyncStorePayloadContributor> _filterAsyncPayloadsByConfig(
    List<AsyncStorePayloadContributor> payloads,
    ExportConfig config,
  ) {
    return [
      for (final payload in payloads)
        if (_asyncEntityTypeForFilename(payload.filename)
            case final type?
            when config.shouldExport(type))
          payload,
    ];
  }

  /// Write a sync payload, applying field filtering from [config].
  Future<void> _writeFilteredStorePayload(
    Directory stagingDirectory,
    StorePayloadContributor payload,
    ExportConfig config,
  ) async {
    final entityType = _entityTypeForFilename(payload.filename);
    if (entityType == null) {
      // Unknown payload type – write unfiltered for forward compatibility.
      return _writeStorePayload(stagingDirectory, payload);
    }
    final rawJson = payload.exportJson();
    final filteredJson = ExportFilter.filterStorePayload(
      rawJson,
      entityType,
      config,
    );
    if (filteredJson.isEmpty) return;
    await File(
      '${stagingDirectory.path}/${payload.filename}',
    ).writeAsString(jsonEncode(filteredJson));
  }

  /// Write async payloads with filtering.
  Future<void> _writeFilteredAsyncStorePayloads(
    Directory stagingDirectory,
    List<AsyncStorePayloadContributor> payloads,
    String projectId,
    ExportConfig config,
  ) async {
    for (final payload in payloads) {
      final data = await payload.exportJson(projectId);
      if (data == null) continue;

      final entityType = _asyncEntityTypeForFilename(payload.filename);
      final filteredData = entityType != null
          ? ExportFilter.filterStorePayload(data, entityType, config)
          : data;
      if (filteredData.isEmpty) continue;

      await Future.wait([
        File(
          '${stagingDirectory.path}/${payload.filename}',
        ).writeAsString(jsonEncode(filteredData)),
        for (final sidecar in payload.exportSidecars(data))
          _writeStorePayloadSidecar(stagingDirectory, sidecar),
      ]);
    }
  }

  // ---------------------------------------------------------------------------
  // Store payload I/O
  // ---------------------------------------------------------------------------

  Future<void> _writeStorePayload(
    Directory stagingDirectory,
    StorePayloadContributor payload,
  ) {
    return File(
      '${stagingDirectory.path}/${payload.filename}',
    ).writeAsString(jsonEncode(payload.exportJson()));
  }

  Future<void> _writeStorePayloadSidecar(
    Directory stagingDirectory,
    StorePayloadSidecar sidecar,
  ) {
    final content = switch (sidecar.encoding) {
      StorePayloadSidecarEncoding.json => jsonEncode(sidecar.jsonData),
      StorePayloadSidecarEncoding.text => sidecar.text ?? '',
    };
    return File(
      '${stagingDirectory.path}/${sidecar.filename}',
    ).writeAsString(content);
  }

  Future<bool> _hasRequiredStorePayloads(
    Directory extraction,
    List<StorePayloadContributor> payloads,
  ) async {
    for (final payload in payloads) {
      final file = File('${extraction.path}/${payload.filename}');
      if (!await file.exists()) {
        return false;
      }
    }
    return true;
  }

  Future<void> _importStorePayloads(
    Directory extraction,
    List<StorePayloadContributor> payloads,
  ) async {
    final imports = await Future.wait([
      for (final payload in payloads) _readStorePayload(extraction, payload),
    ]);
    for (final item in imports) {
      if (item == null) {
        continue;
      }
      item.payload.importJson(item.data);
    }
  }

  Future<void> _importAsyncStorePayloads(
    Directory extraction,
    List<AsyncStorePayloadContributor> payloads,
    String? projectId,
  ) async {
    if (projectId == null || projectId.isEmpty) return;
    for (final payload in payloads) {
      await _readAsyncStorePayload(extraction, payload, projectId);
    }
  }

  Future<DecodedStorePayload?> _readStorePayload(
    Directory extraction,
    StorePayloadContributor payload,
  ) async {
    final file = File('${extraction.path}/${payload.filename}');
    if (!await file.exists()) return null;
    return DecodedStorePayload(
      payload: payload,
      data: _decodeObjectMap(jsonDecode(await file.readAsString())),
    );
  }

  Future<void> _readAsyncStorePayload(
    Directory extraction,
    AsyncStorePayloadContributor payload,
    String projectId,
  ) async {
    final file = File('${extraction.path}/${payload.filename}');
    if (!await file.exists()) return;
    await payload.importJson(
      projectId,
      _decodeObjectMap(jsonDecode(await file.readAsString())),
    );
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
