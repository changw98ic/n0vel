// ============================================================================
// CapabilityAuth
// ============================================================================
//
// Local-server capability authorization. Tokens are intentionally opaque in
// M7-06: callers present a bearer token and the server resolves it through a
// local grant store.
//
// See M7-06: Capability Auth
// See docs/local-server-api-design.md

import 'local_server_route_scope.dart';

/// Coarse-grained capability permissions exposed by the local server.
enum CapabilityPermission {
  read('read'),
  write('write'),
  generate('generate');

  const CapabilityPermission(this.id);

  final String id;
}

/// A local bearer-token grant.
class CapabilityGrant {
  const CapabilityGrant({
    required this.token,
    required this.subject,
    required this.projectId,
    required this.permissions,
    required this.issuedAt,
    required this.expiresAt,
    this.notBefore,
    this.transactionId,
    this.revokedAt,
  });

  /// Opaque token value. Do not log this.
  final String token;

  /// Local caller identity, such as an external script or Git hook.
  final String subject;

  /// Project this grant is bound to.
  final String projectId;

  /// Permissions granted to the caller.
  final Set<CapabilityPermission> permissions;

  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? notBefore;
  final String? transactionId;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;

  bool allows(CapabilityPermission permission) {
    return permissions.contains(permission);
  }

  CapabilityGrant copyWith({
    String? token,
    String? subject,
    String? projectId,
    Set<CapabilityPermission>? permissions,
    DateTime? issuedAt,
    DateTime? expiresAt,
    DateTime? notBefore,
    String? transactionId,
    DateTime? revokedAt,
  }) {
    return CapabilityGrant(
      token: token ?? this.token,
      subject: subject ?? this.subject,
      projectId: projectId ?? this.projectId,
      permissions: permissions ?? this.permissions,
      issuedAt: issuedAt ?? this.issuedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      notBefore: notBefore ?? this.notBefore,
      transactionId: transactionId ?? this.transactionId,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }
}

/// Grant lookup boundary.
abstract class CapabilityGrantStore {
  CapabilityGrant? findGrant(String token);
}

/// In-memory grant store for local server bootstrapping and tests.
class InMemoryCapabilityGrantStore implements CapabilityGrantStore {
  InMemoryCapabilityGrantStore([Iterable<CapabilityGrant> grants = const []]) {
    for (final grant in grants) {
      addGrant(grant);
    }
  }

  final Map<String, CapabilityGrant> _grantsByToken = {};

  @override
  CapabilityGrant? findGrant(String token) => _grantsByToken[token];

  void addGrant(CapabilityGrant grant) {
    _grantsByToken[grant.token] = grant;
  }

  void revoke(String token, DateTime revokedAt) {
    final grant = _grantsByToken[token];
    if (grant == null) return;
    _grantsByToken[token] = grant.copyWith(revokedAt: revokedAt);
  }
}

/// Authorization decision result.
enum CapabilityDecision {
  allowed(statusCode: 200, errorCode: null, message: 'Capability allowed'),
  missingToken(
    statusCode: 401,
    errorCode: 'capability_missing',
    message: 'Missing bearer capability token',
  ),
  invalidAuthorizationHeader(
    statusCode: 401,
    errorCode: 'capability_invalid',
    message: 'Invalid Authorization header',
  ),
  unknownToken(
    statusCode: 401,
    errorCode: 'capability_unknown',
    message: 'Unknown capability token',
  ),
  revokedToken(
    statusCode: 401,
    errorCode: 'capability_revoked',
    message: 'Capability token has been revoked',
  ),
  tokenNotYetValid(
    statusCode: 401,
    errorCode: 'capability_not_yet_valid',
    message: 'Capability token is not yet valid',
  ),
  expiredToken(
    statusCode: 401,
    errorCode: 'capability_expired',
    message: 'Capability token has expired',
  ),
  projectMismatch(
    statusCode: 403,
    errorCode: 'capability_project_mismatch',
    message: 'Capability token is not valid for this project',
  ),
  insufficientPermission(
    statusCode: 403,
    errorCode: 'capability_insufficient',
    message: 'Capability token lacks the required permission',
  );

  const CapabilityDecision({
    required this.statusCode,
    required this.errorCode,
    required this.message,
  });

  final int statusCode;
  final String? errorCode;
  final String message;

  bool get isAllowed => this == CapabilityDecision.allowed;
}

/// Result returned by [CapabilityAuth].
class CapabilityAuthorizationResult {
  const CapabilityAuthorizationResult({
    required this.decision,
    required this.route,
    required this.requiredPermission,
    this.grant,
  });

  final CapabilityDecision decision;
  final LocalServerRoute route;
  final CapabilityPermission? requiredPermission;
  final CapabilityGrant? grant;

  bool get allowed => decision.isAllowed;

  int get statusCode => decision.statusCode;

  String get errorCode => decision.errorCode ?? 'capability_denied';

  String get message => decision.message;
}

/// Audit event for an authorization decision.
class CapabilityAuthAuditEvent {
  const CapabilityAuthAuditEvent({
    required this.timestamp,
    required this.decision,
    required this.route,
    required this.requiredPermission,
    this.subject,
    this.transactionId,
    this.grantProjectId,
    this.targetProjectId,
  });

  final DateTime timestamp;
  final CapabilityDecision decision;
  final LocalServerRoute route;
  final CapabilityPermission? requiredPermission;
  final String? subject;
  final String? transactionId;
  final String? grantProjectId;
  final String? targetProjectId;

  bool get allowed => decision.isAllowed;
}

/// Audit sink boundary.
abstract class CapabilityAuthAuditSink {
  void record(CapabilityAuthAuditEvent event);
}

/// No-op sink for production wiring before durable audit persistence exists.
class NoopCapabilityAuthAuditSink implements CapabilityAuthAuditSink {
  const NoopCapabilityAuthAuditSink();

  @override
  void record(CapabilityAuthAuditEvent event) {}
}

/// In-memory sink for focused tests and early local-server wiring.
class InMemoryCapabilityAuthAuditSink implements CapabilityAuthAuditSink {
  final List<CapabilityAuthAuditEvent> _events = [];

  List<CapabilityAuthAuditEvent> get events => List.unmodifiable(_events);

  @override
  void record(CapabilityAuthAuditEvent event) {
    _events.add(event);
  }
}

/// Capability authorizer for local-server requests.
class CapabilityAuth {
  CapabilityAuth({
    required CapabilityGrantStore grantStore,
    CapabilityAuthAuditSink auditSink = const NoopCapabilityAuthAuditSink(),
    DateTime Function()? now,
  }) : _grantStore = grantStore,
       _auditSink = auditSink,
       _now = now ?? DateTime.now;

  factory CapabilityAuth.denyAll() {
    return CapabilityAuth(grantStore: InMemoryCapabilityGrantStore());
  }

  final CapabilityGrantStore _grantStore;
  final CapabilityAuthAuditSink _auditSink;
  final DateTime Function() _now;

  CapabilityAuthorizationResult authorize({
    required String? authorizationHeader,
    required LocalServerRoute route,
    String? targetProjectId,
  }) {
    final requiredPermission = capabilityPermissionForRouteScope(route.scope);
    if (requiredPermission == null) {
      return _record(
        decision: CapabilityDecision.allowed,
        route: route,
        requiredPermission: null,
        targetProjectId: targetProjectId,
      );
    }

    final parsedToken = _parseBearerToken(authorizationHeader);
    if (parsedToken.decision != null) {
      return _record(
        decision: parsedToken.decision!,
        route: route,
        requiredPermission: requiredPermission,
        targetProjectId: targetProjectId,
      );
    }

    final grant = _grantStore.findGrant(parsedToken.token!);
    if (grant == null) {
      return _record(
        decision: CapabilityDecision.unknownToken,
        route: route,
        requiredPermission: requiredPermission,
        targetProjectId: targetProjectId,
      );
    }

    final now = _now();
    if (grant.isRevoked) {
      return _record(
        decision: CapabilityDecision.revokedToken,
        route: route,
        requiredPermission: requiredPermission,
        grant: grant,
        targetProjectId: targetProjectId,
      );
    }
    if (grant.notBefore != null && now.isBefore(grant.notBefore!)) {
      return _record(
        decision: CapabilityDecision.tokenNotYetValid,
        route: route,
        requiredPermission: requiredPermission,
        grant: grant,
        targetProjectId: targetProjectId,
      );
    }
    if (!now.isBefore(grant.expiresAt)) {
      return _record(
        decision: CapabilityDecision.expiredToken,
        route: route,
        requiredPermission: requiredPermission,
        grant: grant,
        targetProjectId: targetProjectId,
      );
    }
    if (targetProjectId != null && grant.projectId != targetProjectId) {
      return _record(
        decision: CapabilityDecision.projectMismatch,
        route: route,
        requiredPermission: requiredPermission,
        grant: grant,
        targetProjectId: targetProjectId,
      );
    }
    if (!grant.allows(requiredPermission)) {
      return _record(
        decision: CapabilityDecision.insufficientPermission,
        route: route,
        requiredPermission: requiredPermission,
        grant: grant,
        targetProjectId: targetProjectId,
      );
    }

    return _record(
      decision: CapabilityDecision.allowed,
      route: route,
      requiredPermission: requiredPermission,
      grant: grant,
      targetProjectId: targetProjectId,
    );
  }

  CapabilityAuthorizationResult _record({
    required CapabilityDecision decision,
    required LocalServerRoute route,
    required CapabilityPermission? requiredPermission,
    CapabilityGrant? grant,
    String? targetProjectId,
  }) {
    _auditSink.record(
      CapabilityAuthAuditEvent(
        timestamp: _now(),
        decision: decision,
        route: route,
        requiredPermission: requiredPermission,
        subject: grant?.subject,
        transactionId: grant?.transactionId,
        grantProjectId: grant?.projectId,
        targetProjectId: targetProjectId,
      ),
    );
    return CapabilityAuthorizationResult(
      decision: decision,
      route: route,
      requiredPermission: requiredPermission,
      grant: grant,
    );
  }

  _ParsedBearerToken _parseBearerToken(String? authorizationHeader) {
    if (authorizationHeader == null || authorizationHeader.trim().isEmpty) {
      return const _ParsedBearerToken(
        decision: CapabilityDecision.missingToken,
      );
    }

    final parts = authorizationHeader.trim().split(RegExp(r'\s+'));
    if (parts.length != 2 || parts.first.toLowerCase() != 'bearer') {
      return const _ParsedBearerToken(
        decision: CapabilityDecision.invalidAuthorizationHeader,
      );
    }

    final token = parts.last.trim();
    if (token.isEmpty) {
      return const _ParsedBearerToken(
        decision: CapabilityDecision.invalidAuthorizationHeader,
      );
    }
    return _ParsedBearerToken(token: token);
  }
}

class _ParsedBearerToken {
  const _ParsedBearerToken({this.token, this.decision});

  final String? token;
  final CapabilityDecision? decision;
}

/// Map route-specific scopes to the M7-06 coarse permission model.
CapabilityPermission? capabilityPermissionForRouteScope(
  LocalServerRouteScope scope,
) {
  switch (scope) {
    case LocalServerRouteScope.health:
      return null;
    case LocalServerRouteScope.projectRead:
    case LocalServerRouteScope.sceneRead:
    case LocalServerRouteScope.characterRead:
    case LocalServerRouteScope.worldRead:
      return CapabilityPermission.read;
    case LocalServerRouteScope.projectWrite:
    case LocalServerRouteScope.projectDelete:
    case LocalServerRouteScope.sceneWrite:
    case LocalServerRouteScope.sceneDelete:
    case LocalServerRouteScope.characterWrite:
    case LocalServerRouteScope.characterDelete:
    case LocalServerRouteScope.worldWrite:
    case LocalServerRouteScope.worldDelete:
      return CapabilityPermission.write;
    case LocalServerRouteScope.generate:
      return CapabilityPermission.generate;
  }
}
