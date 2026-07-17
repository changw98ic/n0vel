import 'dart:convert';
import 'dart:io';

import '../../../app/logging/app_event_log.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_generation_store.dart';
import '../../../app/state/story_outline_store.dart';
import 'export_config.dart';
import 'export_dtos.dart';
import 'project_transfer_models.dart';
import 'store_payload_contributor.dart';

/// Handles project export: building the zip package from store payloads.
class ProjectTransferExporter {
  ProjectTransferExporter({
    required Directory exportsDirectory,
    required String zipExecutable,
    required AppEventLog eventLog,
    this.storyMemoryExport,
    this.roleplayStateExport,
  }) : _exportsDirectory = exportsDirectory,
       _zipExecutable = zipExecutable,
       _eventLog = eventLog;

  final Directory _exportsDirectory;
  final String _zipExecutable;
  final AppEventLog _eventLog;

  /// Optional callback to export story memory data for a project.
  final Future<Map<String, Object?>?> Function(String projectId)?
  storyMemoryExport;

  /// Optional callback to export roleplay sessions and character memories.
  final Future<Map<String, Object?>?> Function(String projectId)?
  roleplayStateExport;

  String get exportPackagePath =>
      '${_exportsDirectory.path}/$projectTransferPackageFilename';

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
    await logTransferEvent(
      _eventLog,
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
      await logTransferEvent(
        _eventLog,
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
      schemaMajor: projectTransferSchemaMajor,
      schemaMinor: projectTransferSchemaMinor,
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

      final rawWorkspaceJson = workspaceStore.exportCurrentProjectJson();
      final filteredWorkspaceJson = ExportFilter.filterWorkspaceJson(
        rawWorkspaceJson,
        config,
      );

      final filteredPayloads = _filterPayloadsByConfig(storePayloads, config);

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
          if (name == projectTransferChecksumsFilename) continue;
          checksums[name] = computePayloadChecksum(await entity.readAsString());
        }
      }
      await File(
        '${stagingDirectory.path}/$projectTransferChecksumsFilename',
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
        await logTransferEvent(
          _eventLog,
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
      await logTransferEvent(
        _eventLog,
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
      await logTransferEvent(
        _eventLog,
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

  // ---------------------------------------------------------------------------
  // Payload contributor factories (public for reuse by importer)
  // ---------------------------------------------------------------------------

  static List<StorePayloadContributor> requiredStorePayloadContributors({
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

  static List<StorePayloadContributor> optionalStorePayloadContributors({
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

  // ---------------------------------------------------------------------------
  // Config-aware payload filtering
  // ---------------------------------------------------------------------------

  static ExportEntityType? entityTypeForFilename(String filename) {
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

  static ExportEntityType? asyncEntityTypeForFilename(String filename) {
    return switch (filename) {
      'story_memory.json' => ExportEntityType.storyMemory,
      'roleplay_state.json' => ExportEntityType.roleplayState,
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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
      ...requiredStorePayloadContributors(
        draftStore: draftStore,
        versionStore: versionStore,
      ),
      ...optionalStorePayloadContributors(
        aiHistoryStore: aiHistoryStore,
        sceneContextStore: sceneContextStore,
        simulationStore: simulationStore,
        storyOutlineStore: storyOutlineStore,
        storyGenerationStore: storyGenerationStore,
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
        // Import handled by ProjectTransferImporter.
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
      importJson: (projectId, data) async {
        // Import handled by ProjectTransferImporter.
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

  List<StorePayloadContributor> _filterPayloadsByConfig(
    List<StorePayloadContributor> payloads,
    ExportConfig config,
  ) {
    return [
      for (final payload in payloads)
        if (entityTypeForFilename(payload.filename) case final type?
            when config.shouldExport(type))
          payload,
    ];
  }

  List<AsyncStorePayloadContributor> _filterAsyncPayloadsByConfig(
    List<AsyncStorePayloadContributor> payloads,
    ExportConfig config,
  ) {
    return [
      for (final payload in payloads)
        if (asyncEntityTypeForFilename(payload.filename) case final type?
            when config.shouldExport(type))
          payload,
    ];
  }

  Future<void> _writeFilteredStorePayload(
    Directory stagingDirectory,
    StorePayloadContributor payload,
    ExportConfig config,
  ) async {
    final entityType = entityTypeForFilename(payload.filename);
    if (entityType == null) {
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

  Future<void> _writeFilteredAsyncStorePayloads(
    Directory stagingDirectory,
    List<AsyncStorePayloadContributor> payloads,
    String projectId,
    ExportConfig config,
  ) async {
    for (final payload in payloads) {
      final data = await payload.exportJson(projectId);
      if (data == null) continue;

      final entityType = asyncEntityTypeForFilename(payload.filename);
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
}
