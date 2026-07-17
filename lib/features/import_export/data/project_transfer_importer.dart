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
import 'project_transfer_exporter.dart';
import 'project_transfer_io.dart';
import 'project_transfer_models.dart';
import 'store_payload_contributor.dart';

/// Handles project import: inspecting and applying zip packages into stores.
class ProjectTransferImporter {
  ProjectTransferImporter({
    required Directory importsDirectory,
    required String unzipExecutable,
    required AppEventLog eventLog,
    this.storyMemoryImport,
    this.roleplayStateImport,
  }) : _importsDirectory = importsDirectory,
       _unzipExecutable = unzipExecutable,
       _eventLog = eventLog;

  final Directory _importsDirectory;
  final String _unzipExecutable;
  final AppEventLog _eventLog;

  /// Optional callback to import story memory data for a project.
  final Future<void> Function(String projectId, Map<String, Object?> data)?
  storyMemoryImport;

  /// Optional callback to import roleplay sessions and character memories.
  final Future<void> Function(String projectId, Map<String, Object?> data)?
  roleplayStateImport;

  String get importPackagePath =>
      '${_importsDirectory.path}/$projectTransferPackageFilename';

  Future<ProjectPackageInspection> inspectPackage(File packageFile) async {
    final correlationId = _eventLog.newCorrelationId('project-import-inspect');
    await logTransferEvent(
      _eventLog,
      action: 'project.import.inspect.started',
      status: AppEventLogStatus.started,
      message: 'Started project package inspection.',
      correlationId: correlationId,
      metadata: {'packagePath': packageFile.path},
    );
    if (!await packageFile.exists()) {
      await logTransferEvent(
        _eventLog,
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

    final extraction = await extractTransferPackage(
      packageFile,
      _unzipExecutable,
    );
    try {
      if (extraction == null) {
        await logTransferEvent(
          _eventLog,
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
        await logTransferEvent(
          _eventLog,
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
        await logTransferEvent(
          _eventLog,
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
      if (manifest.schemaMajor != projectTransferSchemaMajor) {
        await logTransferEvent(
          _eventLog,
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

      if (manifest.schemaMinor != projectTransferSchemaMinor) {
        await logTransferEvent(
          _eventLog,
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

      await logTransferEvent(
        _eventLog,
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
      await logTransferEvent(
        _eventLog,
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
    await logTransferEvent(
      _eventLog,
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
      await logTransferEvent(
        _eventLog,
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
      await logTransferEvent(
        _eventLog,
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

    final extraction = await extractTransferPackage(
      packageFile,
      _unzipExecutable,
    );
    try {
      if (extraction == null) {
        await logTransferEvent(
          _eventLog,
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
      final requiredStorePayloads =
          ProjectTransferExporter.requiredStorePayloadContributors(
            draftStore: draftStore,
            versionStore: versionStore,
          );
      if (!await workspaceFile.exists() ||
          !await hasRequiredStorePayloads(extraction, requiredStorePayloads)) {
        await logTransferEvent(
          _eventLog,
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

      if (!await verifyPackageChecksums(extraction)) {
        await logTransferEvent(
          _eventLog,
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

      final workspaceJson = decodeProjectTransferObjectMap(
        jsonDecode(await workspaceFile.readAsString()),
      );

      final validationErrors = WorkspaceDataValidator().validateWorkspaceData(
        workspaceJson,
      );
      if (validationErrors.hasErrors) {
        await logTransferEvent(
          _eventLog,
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
      await importStorePayloads(extraction, requiredStorePayloads);
      await importStorePayloads(
        extraction,
        ProjectTransferExporter.optionalStorePayloadContributors(
          aiHistoryStore: aiHistoryStore,
          sceneContextStore: sceneContextStore,
          simulationStore: simulationStore,
          storyOutlineStore: storyOutlineStore,
          storyGenerationStore: storyGenerationStore,
        ),
      );
      await importAsyncStorePayloads(
        extraction,
        _asyncStorePayloadContributors(),
        manifest?.projectId,
      );

      await logTransferEvent(
        _eventLog,
        action: 'project.import.succeeded',
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
      await logTransferEvent(
        _eventLog,
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
      await logTransferEvent(
        _eventLog,
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

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<AsyncStorePayloadContributor> _asyncStorePayloadContributors() {
    return [
      _storyMemoryPayloadContributor(),
      _roleplayStatePayloadContributor(),
    ];
  }

  AsyncStorePayloadContributor _storyMemoryPayloadContributor() {
    return AsyncJsonStorePayloadContributor(
      filename: 'story_memory.json',
      exportJson: (projectId) async => null,
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
      exportJson: (projectId) async => null,
      importJson: (projectId, data) {
        final importer = roleplayStateImport ?? importRoleplayStateForProject;
        return importer(projectId, data);
      },
    );
  }
}
