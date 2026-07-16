import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_external_custody_trust_store.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_release_coordinator_preflight.dart';

void main() {
  group('runtime app code identity', () {
    const details = '''
Executable=/Applications/Novel Writer.app/Contents/MacOS/novel_writer
Identifier=com.example.novelWriter
Authority=Developer ID Application: Runtime Test (RUNTIME001)
Authority=Developer ID Certification Authority
Authority=Apple Root CA
TeamIdentifier=RUNTIME001
CDHash=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
''';
    const requirement =
        'designated => identifier "com.example.novelWriter" and anchor apple';
    const entitlements = '''
<plist><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.get-task-allow</key><false/>
</dict></plist>
''';

    test('requires and verifies an independently pinned identity', () {
      AgentEvaluationMacRuntimeCodeIdentity.parse(
        details: details,
        requirement: requirement,
        entitlements: entitlements,
      ).verifyPinned(_trustEntry());
    });

    test('rejects ad-hoc, missing team, debug, and unsandboxed apps', () {
      for (final invalid in <({String details, String entitlements})>[
        (details: '$details\nSignature=adhoc', entitlements: entitlements),
        (
          details: details.replaceAll('TeamIdentifier=RUNTIME001\n', ''),
          entitlements: entitlements,
        ),
        (
          details: details,
          entitlements: entitlements.replaceAll('<false/>', '<true/>'),
        ),
        (
          details: details,
          entitlements: entitlements.replaceAll(
            '<key>com.apple.security.app-sandbox</key><true/>',
            '<key>com.apple.security.app-sandbox</key><false/>',
          ),
        ),
      ]) {
        expect(
          () => AgentEvaluationMacRuntimeCodeIdentity.parse(
            details: invalid.details,
            requirement: requirement,
            entitlements: invalid.entitlements,
          ),
          throwsFormatException,
        );
      }
    });

    test('rejects changes to every independently pinned app field', () {
      final identity = AgentEvaluationMacRuntimeCodeIdentity.parse(
        details: details,
        requirement: requirement,
        entitlements: entitlements,
      );
      for (final changed in <AgentEvaluationExternalCustodyTrustEntry>[
        _trustEntry(runtimeTeam: 'RUNTIME002'),
        _trustEntry(runtimeRequirement: 'identifier "other.runtime"'),
        _trustEntry(runtimeCdHash: 'C' * 40),
        _trustEntry(runtimeAuthorities: const <String>['Other Authority']),
      ]) {
        expect(() => identity.verifyPinned(changed), throwsFormatException);
      }
    });
  });

  group('app sandbox paths', () {
    late Directory root;

    setUp(() {
      root = Directory(
        '${Directory.current.path}/.dart_tool/'
        'agent-evaluation-runtime-gate-$pid-${DateTime.now().microsecondsSinceEpoch}',
      )..createSync(recursive: true);
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('accepts only descendants of the canonical controlled root', () {
      final work = '${root.path}/work/public';
      final report = '${root.path}/reports/public';
      final privateFile = '${root.path}/private/holdout.sqlite';
      validateAgentEvaluationSandboxPaths(
        containerRoot: root,
        directoryPaths: <String>[work, report],
        filePaths: <String>[privateFile],
      );
      expect(Directory(work).existsSync(), isTrue);
      expect(Directory(report).existsSync(), isTrue);
      expect(Directory(privateFile).parent.existsSync(), isTrue);
      if (!Platform.isWindows) {
        expect(Directory(work).statSync().mode & 0x1ff, 0x1c0);
        expect(Directory(report).statSync().mode & 0x1ff, 0x1c0);
      }
    });

    test('rejects temporary, outside, traversal, and linked paths', () {
      expect(
        () => validateAgentEvaluationSandboxPaths(
          containerRoot: Directory('/tmp'),
          directoryPaths: const <String>['/tmp/agent-evaluation-work'],
        ),
        throwsA(isA<AgentEvaluationCoordinatorPreflightFailure>()),
      );
      expect(
        () => validateAgentEvaluationSandboxPaths(
          containerRoot: root,
          directoryPaths: <String>[root.parent.path],
        ),
        throwsA(isA<AgentEvaluationCoordinatorPreflightFailure>()),
      );
      expect(
        () => validateAgentEvaluationSandboxPaths(
          containerRoot: root,
          directoryPaths: <String>['${root.path}/work/../escape'],
        ),
        throwsA(isA<AgentEvaluationCoordinatorPreflightFailure>()),
      );
      if (!Platform.isWindows) {
        final outside = Directory(
          '${root.parent.path}/outside-${root.path.hashCode}',
        )..createSync();
        addTearDown(() {
          if (outside.existsSync()) outside.deleteSync(recursive: true);
        });
        final link = Link('${root.path}/linked')..createSync(outside.path);
        expect(
          () => validateAgentEvaluationSandboxPaths(
            containerRoot: root,
            directoryPaths: <String>['${link.path}/work'],
          ),
          throwsA(isA<AgentEvaluationCoordinatorPreflightFailure>()),
        );
        final fileLink = Link('${root.path}/private-link')
          ..createSync('${outside.path}/private.sqlite');
        expect(
          () => validateAgentEvaluationSandboxPaths(
            containerRoot: root,
            directoryPaths: const <String>[],
            filePaths: <String>[fileLink.path],
          ),
          throwsA(isA<AgentEvaluationCoordinatorPreflightFailure>()),
        );
      }
    });
  });
}

AgentEvaluationExternalCustodyTrustEntry _trustEntry({
  String runtimeTeam = 'RUNTIME001',
  String runtimeRequirement =
      'identifier "com.example.novelWriter" and anchor apple',
  String runtimeCdHash = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
  List<String> runtimeAuthorities = const <String>[
    'Developer ID Application: Runtime Test (RUNTIME001)',
    'Developer ID Certification Authority',
    'Apple Root CA',
  ],
}) => AgentEvaluationExternalCustodyTrustEntry(
  rootKeyId: 'audit-root-v1',
  rootPublicKeyBase64: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  kmsProviderReleaseHash: 'sha256:${'1' * 64}',
  kmsKeyResourceHash: 'sha256:${'2' * 64}',
  allowedRunnerPrincipalHashes: <String>['sha256:${'3' * 64}'],
  allowedSigningKeyIds: const <String>['audit-key-v1'],
  macTeamIdentifier: 'AUDITTEST1',
  macDesignatedRequirement: 'identifier "audit.signer"',
  macCdHash: 'A' * 40,
  runtimeAppTeamIdentifier: runtimeTeam,
  runtimeAppDesignatedRequirement: runtimeRequirement,
  runtimeAppCdHash: runtimeCdHash,
  runtimeAppAuthorityChain: runtimeAuthorities,
);
