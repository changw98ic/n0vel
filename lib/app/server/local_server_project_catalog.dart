// ============================================================================
// LocalServerProjectCatalog
// ============================================================================
//
// Project catalog abstraction for the local server. M7-05 uses an injected
// catalog rather than reading directly from stores.
//
// See M7-05: Server Foundation

import 'package:novel_writer/domain/workspace_models.dart' show ProjectRecord;

/// Abstract project catalog for local server endpoints.
abstract class LocalServerProjectCatalog {
  /// Get all project summaries.
  List<ProjectRecord> getProjects();

  /// Find a project by ID, or null if not found.
  ProjectRecord? getProjectById(String id);
}

/// Static test fake catalog.
class StaticLocalServerProjectCatalog implements LocalServerProjectCatalog {
  const StaticLocalServerProjectCatalog([this._projects = const []]);

  final List<ProjectRecord> _projects;

  @override
  List<ProjectRecord> getProjects() => List.unmodifiable(_projects);

  @override
  ProjectRecord? getProjectById(String id) {
    for (final project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }
}
