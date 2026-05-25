// ============================================================================
// LocalServerRouteScope
// ============================================================================
//
// Route metadata seam for M7-06 capability auth. M7-05 does not implement
// auth; this enum exists to establish the capability model.
//
// See M7-05: Server Foundation, M7-06: Capability Auth

/// Capability scopes for route authorization. M7-06 implements real auth;
/// M7-05 records the scope for future use.
enum LocalServerRouteScope {
  /// Health check - no auth required
  health,

  /// Read project metadata
  projectRead,

  /// Modify project metadata (M7-06)
  projectWrite,

  /// Delete projects (M7-06)
  projectDelete,

  /// Read scenes
  sceneRead,

  /// Create/modify scenes (M7-06)
  sceneWrite,

  /// Delete scenes (M7-06)
  sceneDelete,

  /// Read characters
  characterRead,

  /// Create/modify characters (M7-06)
  characterWrite,

  /// Delete characters (M7-06)
  characterDelete,

  /// Read world nodes
  worldRead,

  /// Create/modify world nodes (M7-06)
  worldWrite,

  /// Delete world nodes (M7-06)
  worldDelete,
}

/// Route descriptor with HTTP method, path pattern, and required scope.
class LocalServerRoute {
  const LocalServerRoute({
    required this.method,
    required this.pattern,
    required this.scope,
  });

  final String method; // 'GET', 'POST', etc.
  final String pattern; // '/health', '/projects', etc.
  final LocalServerRouteScope scope;
}

/// Known routes. M7-05 implements a subset; M7-06 adds the rest.
class LocalServerRoutes {
  LocalServerRoutes._();

  static const health = LocalServerRoute(
    method: 'GET',
    pattern: '/health',
    scope: LocalServerRouteScope.health,
  );

  static const projects = LocalServerRoute(
    method: 'GET',
    pattern: '/projects',
    scope: LocalServerRouteScope.projectRead,
  );
}
