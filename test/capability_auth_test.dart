import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/server/capability_auth.dart';
import 'package:novel_writer/app/server/local_server_route_scope.dart';

void main() {
  group('CapabilityPermission mapping', () {
    test('maps route scopes to read, write, and generate permissions', () {
      expect(
        capabilityPermissionForRouteScope(LocalServerRouteScope.health),
        isNull,
      );
      expect(
        capabilityPermissionForRouteScope(LocalServerRouteScope.projectRead),
        CapabilityPermission.read,
      );
      expect(
        capabilityPermissionForRouteScope(LocalServerRouteScope.sceneWrite),
        CapabilityPermission.write,
      );
      expect(
        capabilityPermissionForRouteScope(LocalServerRouteScope.generate),
        CapabilityPermission.generate,
      );
    });
  });

  group('CapabilityAuth', () {
    final now = DateTime.utc(2026, 5, 25, 12);
    const route = LocalServerRoutes.projects;

    CapabilityGrant grant({
      String token = 'token-read',
      String projectId = 'project-1',
      Set<CapabilityPermission> permissions = const {CapabilityPermission.read},
      DateTime? expiresAt,
      DateTime? notBefore,
      DateTime? revokedAt,
    }) {
      return CapabilityGrant(
        token: token,
        subject: 'external-agent',
        projectId: projectId,
        permissions: permissions,
        issuedAt: now.subtract(const Duration(minutes: 1)),
        expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
        notBefore: notBefore,
        transactionId: 'txn-1',
        revokedAt: revokedAt,
      );
    }

    CapabilityAuth authFor(
      Iterable<CapabilityGrant> grants,
      InMemoryCapabilityAuthAuditSink auditSink,
    ) {
      return CapabilityAuth(
        grantStore: InMemoryCapabilityGrantStore(grants),
        auditSink: auditSink,
        now: () => now,
      );
    }

    test('allows a bearer token with the required permission', () {
      final auditSink = InMemoryCapabilityAuthAuditSink();
      final auth = authFor([grant()], auditSink);

      final result = auth.authorize(
        authorizationHeader: 'Bearer token-read',
        route: route,
        targetProjectId: 'project-1',
      );

      expect(result.allowed, isTrue);
      expect(result.decision, CapabilityDecision.allowed);
      expect(result.requiredPermission, CapabilityPermission.read);
      expect(result.grant?.subject, 'external-agent');
      expect(auditSink.events, hasLength(1));
      expect(auditSink.events.single.allowed, isTrue);
      expect(auditSink.events.single.transactionId, 'txn-1');
    });

    test('does not require a token for health route', () {
      final auditSink = InMemoryCapabilityAuthAuditSink();
      final auth = authFor(const [], auditSink);

      final result = auth.authorize(
        authorizationHeader: null,
        route: LocalServerRoutes.health,
      );

      expect(result.allowed, isTrue);
      expect(result.requiredPermission, isNull);
      expect(auditSink.events.single.route.scope, LocalServerRouteScope.health);
    });

    test('rejects missing, malformed, and unknown tokens', () {
      final auditSink = InMemoryCapabilityAuthAuditSink();
      final auth = authFor([grant()], auditSink);

      expect(
        auth.authorize(authorizationHeader: null, route: route).decision,
        CapabilityDecision.missingToken,
      );
      expect(
        auth
            .authorize(authorizationHeader: 'Basic token-read', route: route)
            .decision,
        CapabilityDecision.invalidAuthorizationHeader,
      );
      expect(
        auth
            .authorize(authorizationHeader: 'Bearer nope', route: route)
            .decision,
        CapabilityDecision.unknownToken,
      );

      expect(auditSink.events, hasLength(3));
      expect(auditSink.events.every((event) => !event.allowed), isTrue);
    });

    test('rejects revoked, not-yet-valid, and expired tokens', () {
      final auditSink = InMemoryCapabilityAuthAuditSink();
      final auth = authFor([
        grant(
          token: 'revoked',
          revokedAt: now.subtract(const Duration(seconds: 1)),
        ),
        grant(token: 'future', notBefore: now.add(const Duration(seconds: 1))),
        grant(
          token: 'expired',
          expiresAt: now.subtract(const Duration(seconds: 1)),
        ),
      ], auditSink);

      expect(
        auth
            .authorize(authorizationHeader: 'Bearer revoked', route: route)
            .decision,
        CapabilityDecision.revokedToken,
      );
      expect(
        auth
            .authorize(authorizationHeader: 'Bearer future', route: route)
            .decision,
        CapabilityDecision.tokenNotYetValid,
      );
      expect(
        auth
            .authorize(authorizationHeader: 'Bearer expired', route: route)
            .decision,
        CapabilityDecision.expiredToken,
      );
    });

    test('rejects project mismatch and insufficient permission', () {
      final auditSink = InMemoryCapabilityAuthAuditSink();
      final auth = authFor([
        grant(),
        grant(
          token: 'generate-only',
          permissions: const {CapabilityPermission.generate},
        ),
      ], auditSink);

      expect(
        auth
            .authorize(
              authorizationHeader: 'Bearer token-read',
              route: route,
              targetProjectId: 'project-2',
            )
            .decision,
        CapabilityDecision.projectMismatch,
      );
      expect(
        auth
            .authorize(
              authorizationHeader: 'Bearer generate-only',
              route: route,
              targetProjectId: 'project-1',
            )
            .decision,
        CapabilityDecision.insufficientPermission,
      );

      expect(
        auditSink.events.last.requiredPermission,
        CapabilityPermission.read,
      );
      expect(auditSink.events.last.subject, 'external-agent');
    });

    test('in-memory grant store can revoke grants', () {
      final store = InMemoryCapabilityGrantStore([grant()]);

      expect(store.findGrant('token-read')?.isRevoked, isFalse);

      store.revoke('token-read', now);

      expect(store.findGrant('token-read')?.isRevoked, isTrue);
    });
  });
}
