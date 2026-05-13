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
import 'project_transfer_exporter.dart';
import 'project_transfer_importer.dart';
import 'project_transfer_models.dart';

export 'project_transfer_models.dart';

/// Facade for project import/export operations.
///
/// Delegates to [ProjectTransferExporter] and [ProjectTransferImporter].
/// The public API is identical to the pre-refactor monolithic implementation.
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
  }) : _exporter = ProjectTransferExporter(
         exportsDirectory:
             exportsDirectory ?? resolveProjectTransferExportsDirectory(),
         zipExecutable: zipExecutable,
         eventLog: eventLog ?? AppEventLog(),
         storyMemoryExport: storyMemoryExport,
         roleplayStateExport: roleplayStateExport,
       ),
       _importer = ProjectTransferImporter(
         importsDirectory:
             importsDirectory ?? resolveProjectTransferImportsDirectory(),
         unzipExecutable: unzipExecutable,
         eventLog: eventLog ?? AppEventLog(),
         storyMemoryImport: storyMemoryImport,
         roleplayStateImport: roleplayStateImport,
       );

  static const int supportedSchemaMajor = projectTransferSchemaMajor;
  static const int supportedSchemaMinor = projectTransferSchemaMinor;
  static const String packageFilename = projectTransferPackageFilename;
  static const String checksumsFilename = projectTransferChecksumsFilename;

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

  final ProjectTransferExporter _exporter;
  final ProjectTransferImporter _importer;

  String get exportPackagePath => _exporter.exportPackagePath;
  String get importPackagePath => _importer.importPackagePath;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

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
  }) {
    return _exporter.exportPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
      aiHistoryStore: aiHistoryStore,
      sceneContextStore: sceneContextStore,
      simulationStore: simulationStore,
      storyOutlineStore: storyOutlineStore,
      storyGenerationStore: storyGenerationStore,
      config: config,
    );
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<ProjectPackageInspection> inspectPackage(File packageFile) {
    return _importer.inspectPackage(packageFile);
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
  }) {
    return _importer.importPackage(
      draftStore: draftStore,
      versionStore: versionStore,
      workspaceStore: workspaceStore,
      aiHistoryStore: aiHistoryStore,
      sceneContextStore: sceneContextStore,
      simulationStore: simulationStore,
      storyOutlineStore: storyOutlineStore,
      storyGenerationStore: storyGenerationStore,
      overwriteExisting: overwriteExisting,
    );
  }
}
