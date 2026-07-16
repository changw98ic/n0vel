import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:sqlite3/sqlite3.dart';

import 'agent_evaluation_manifest.dart';

abstract final class AgentEvaluationTrustedHoldoutPolicy {
  static String get runnerReleaseHash => AgentEvaluationHashes.domainHash(
    'eval-trusted-holdout-runner-v2',
    <String, Object?>{
      'processBoundary': 'separate-vault-process',
      'fixtureDisclosure': 'none',
      'confirmation': 'ed25519-nondiagnostic-v1',
    },
  );

  static String get resolverReleaseHash => AgentEvaluationHashes.domainHash(
    'eval-trusted-holdout-resolver-v1',
    <String, Object?>{
      'store': 'separate-sqlite-0600',
      'accessOrder': 'spent-authority-grant-before-resolve',
      'audit': 'append-only-hash-chain-v1',
    },
  );
}

class AgentEvaluationTrustedHoldoutAttestation {
  AgentEvaluationTrustedHoldoutAttestation({
    required this.familyId,
    required this.tokenId,
    required this.accessId,
    required this.regressionVerdictHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.executionId,
    required this.scenarioSetReleaseHash,
    required this.holdoutAccessPolicyHash,
    required this.evaluationBundleHash,
    required this.gatePolicyHash,
    required this.result,
    required this.fixtureReleaseHash,
    required this.auditRootHash,
    required this.runnerReleaseHash,
    required this.resolverReleaseHash,
    required this.keyId,
    required this.nonce,
    required this.issuedAtMs,
    required this.expiresAtMs,
    required this.signatureBase64,
  }) {
    for (final digest in <String>[
      regressionVerdictHash,
      championBundleHash,
      challengerBundleHash,
      scenarioSetReleaseHash,
      holdoutAccessPolicyHash,
      evaluationBundleHash,
      gatePolicyHash,
      fixtureReleaseHash,
      auditRootHash,
      runnerReleaseHash,
      resolverReleaseHash,
    ]) {
      AgentEvaluationHashes.requireDigest(digest, 'attestation digest');
    }
    if (!<String>{'pass', 'fail', 'insufficientEvidence'}.contains(result) ||
        issuedAtMs < 0 ||
        expiresAtMs <= issuedAtMs ||
        <String>[
          familyId,
          tokenId,
          accessId,
          executionId,
          keyId,
          nonce,
          signatureBase64,
        ].any((value) => value.trim().isEmpty)) {
      throw ArgumentError('invalid trusted holdout attestation');
    }
  }

  final String familyId;
  final String tokenId;
  final String accessId;
  final String regressionVerdictHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String executionId;
  final String scenarioSetReleaseHash;
  final String holdoutAccessPolicyHash;
  final String evaluationBundleHash;
  final String gatePolicyHash;
  final String result;
  final String fixtureReleaseHash;
  final String auditRootHash;
  final String runnerReleaseHash;
  final String resolverReleaseHash;
  final String keyId;
  final String nonce;
  final int issuedAtMs;
  final int expiresAtMs;
  final String signatureBase64;

  factory AgentEvaluationTrustedHoldoutAttestation.fromStorage({
    required String payloadJson,
    required String signatureBase64,
  }) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, Object?> ||
        decoded['schemaVersion'] != 'trusted-holdout-attestation-v1') {
      throw const FormatException(
        'invalid trusted holdout attestation payload',
      );
    }
    String string(String key) {
      final value = decoded[key];
      if (value is! String) throw FormatException('invalid $key');
      return value;
    }

    int integer(String key) {
      final value = decoded[key];
      if (value is! int) throw FormatException('invalid $key');
      return value;
    }

    return AgentEvaluationTrustedHoldoutAttestation(
      familyId: string('familyId'),
      tokenId: string('tokenId'),
      accessId: string('accessId'),
      regressionVerdictHash: string('regressionVerdictHash'),
      championBundleHash: string('championBundleHash'),
      challengerBundleHash: string('challengerBundleHash'),
      executionId: string('executionId'),
      scenarioSetReleaseHash: string('scenarioSetReleaseHash'),
      holdoutAccessPolicyHash: string('holdoutAccessPolicyHash'),
      evaluationBundleHash: string('evaluationBundleHash'),
      gatePolicyHash: string('gatePolicyHash'),
      result: string('result'),
      fixtureReleaseHash: string('fixtureReleaseHash'),
      auditRootHash: string('auditRootHash'),
      runnerReleaseHash: string('runnerReleaseHash'),
      resolverReleaseHash: string('resolverReleaseHash'),
      keyId: string('keyId'),
      nonce: string('nonce'),
      issuedAtMs: integer('issuedAtMs'),
      expiresAtMs: integer('expiresAtMs'),
      signatureBase64: signatureBase64,
    );
  }

  Map<String, Object?> get payload => <String, Object?>{
    'schemaVersion': 'trusted-holdout-attestation-v1',
    'familyId': familyId,
    'tokenId': tokenId,
    'accessId': accessId,
    'regressionVerdictHash': regressionVerdictHash,
    'championBundleHash': championBundleHash,
    'challengerBundleHash': challengerBundleHash,
    'executionId': executionId,
    'scenarioSetReleaseHash': scenarioSetReleaseHash,
    'holdoutAccessPolicyHash': holdoutAccessPolicyHash,
    'evaluationBundleHash': evaluationBundleHash,
    'gatePolicyHash': gatePolicyHash,
    'result': result,
    'fixtureReleaseHash': fixtureReleaseHash,
    'auditRootHash': auditRootHash,
    'runnerReleaseHash': runnerReleaseHash,
    'resolverReleaseHash': resolverReleaseHash,
    'keyId': keyId,
    'nonce': nonce,
    'issuedAtMs': issuedAtMs,
    'expiresAtMs': expiresAtMs,
  };

  String get payloadJson => AgentEvaluationHashes.canonicalJson(payload);

  String get attestationHash => AgentEvaluationHashes.domainHash(
    'eval-trusted-holdout-attestation-v1',
    <String, Object?>{'payload': payload, 'signatureBase64': signatureBase64},
  );

  AgentEvaluationTrustedHoldoutAttestation copyWith({
    String? result,
    String? accessId,
    String? signatureBase64,
  }) => AgentEvaluationTrustedHoldoutAttestation(
    familyId: familyId,
    tokenId: tokenId,
    accessId: accessId ?? this.accessId,
    regressionVerdictHash: regressionVerdictHash,
    championBundleHash: championBundleHash,
    challengerBundleHash: challengerBundleHash,
    executionId: executionId,
    scenarioSetReleaseHash: scenarioSetReleaseHash,
    holdoutAccessPolicyHash: holdoutAccessPolicyHash,
    evaluationBundleHash: evaluationBundleHash,
    gatePolicyHash: gatePolicyHash,
    result: result ?? this.result,
    fixtureReleaseHash: fixtureReleaseHash,
    auditRootHash: auditRootHash,
    runnerReleaseHash: runnerReleaseHash,
    resolverReleaseHash: resolverReleaseHash,
    keyId: keyId,
    nonce: nonce,
    issuedAtMs: issuedAtMs,
    expiresAtMs: expiresAtMs,
    signatureBase64: signatureBase64 ?? this.signatureBase64,
  );
}

abstract interface class AgentEvaluationHoldoutSigningAuthority {
  String get keyId;
  SimplePublicKey get publicKey;

  Future<String> signCanonicalPayload(String payloadJson);
}

class AgentEvaluationTrustedHoldoutSigner
    implements AgentEvaluationHoldoutSigningAuthority {
  AgentEvaluationTrustedHoldoutSigner._({
    required this.keyId,
    required SimpleKeyPair keyPair,
    required this.publicKey,
  }) : _keyPair = keyPair;

  static Future<AgentEvaluationTrustedHoldoutSigner> fromSeed({
    required String keyId,
    required List<int> seed,
  }) async {
    if (keyId.trim().isEmpty || seed.length != 32) {
      throw ArgumentError('trusted holdout Ed25519 key identity is invalid');
    }
    final algorithm = DartEd25519();
    final keyPair = await algorithm.newKeyPairFromSeed(seed);
    return AgentEvaluationTrustedHoldoutSigner._(
      keyId: keyId,
      keyPair: keyPair,
      publicKey: await keyPair.extractPublicKey(),
    );
  }

  static Future<AgentEvaluationTrustedHoldoutSigner> fromSeedFile({
    required String keyId,
    required String path,
  }) async {
    final file = File(path).absolute;
    if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('trusted holdout signing seed must be a regular file');
    }
    if (!Platform.isWindows && (file.statSync().mode & 0x3f) != 0) {
      throw StateError('trusted holdout signing seed must have mode 0600');
    }
    final seed = file.readAsBytesSync();
    if (seed.length != 32) {
      throw StateError('trusted holdout signing seed must contain 32 bytes');
    }
    return fromSeed(keyId: keyId, seed: seed);
  }

  @override
  final String keyId;
  final SimpleKeyPair _keyPair;
  @override
  final SimplePublicKey publicKey;

  /// Signs an already-canonical authority payload. This is intentionally
  /// lower-level than [sign] so newer, domain-separated holdout envelopes can
  /// share the pinned Ed25519 root without exposing the private key.
  @override
  Future<String> signCanonicalPayload(String payloadJson) async {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, Object?> ||
        AgentEvaluationHashes.canonicalJson(decoded) != payloadJson) {
      throw ArgumentError('holdout payload must be a canonical JSON object');
    }
    final signature = await DartEd25519().sign(
      utf8.encode(payloadJson),
      keyPair: _keyPair,
    );
    return base64Encode(signature.bytes);
  }

  Future<AgentEvaluationTrustedHoldoutAttestation> sign(
    AgentEvaluationTrustedHoldoutAttestation unsigned,
  ) async {
    if (unsigned.keyId != keyId || unsigned.signatureBase64 != 'unsigned') {
      throw ArgumentError(
        'attestation is not an unsigned payload for this key',
      );
    }
    return unsigned.copyWith(
      signatureBase64: await signCanonicalPayload(unsigned.payloadJson),
    );
  }
}

final class AgentEvaluationTrustedHoldoutVerifier {
  factory AgentEvaluationTrustedHoldoutVerifier({
    required String keyId,
    required SimplePublicKey publicKey,
    required String runnerReleaseHash,
    required String resolverReleaseHash,
  }) {
    if (keyId.trim().isEmpty ||
        publicKey.type != KeyPairType.ed25519 ||
        publicKey.bytes.length != 32) {
      throw ArgumentError('trusted holdout verifier must use Ed25519');
    }
    AgentEvaluationHashes.requireDigest(runnerReleaseHash, 'runnerReleaseHash');
    AgentEvaluationHashes.requireDigest(
      resolverReleaseHash,
      'resolverReleaseHash',
    );
    return AgentEvaluationTrustedHoldoutVerifier._(
      keyId: keyId,
      publicKey: publicKey,
      runnerReleaseHash: runnerReleaseHash,
      resolverReleaseHash: resolverReleaseHash,
    );
  }

  const AgentEvaluationTrustedHoldoutVerifier._({
    required this.keyId,
    required this.publicKey,
    required this.runnerReleaseHash,
    required this.resolverReleaseHash,
  });

  final String keyId;
  final SimplePublicKey publicKey;
  final String runnerReleaseHash;
  final String resolverReleaseHash;

  /// Immutable identity pinned into each experiment family's holdout policy.
  /// A verifier replacement therefore changes the policy hash and cannot be
  /// used to validate an already-frozen family or promotion graph.
  String get trustPolicyHash => AgentEvaluationHashes.domainHash(
    'eval-trusted-holdout-trust-policy-v1',
    <String, Object?>{
      'keyId': keyId,
      'publicKeyBase64': base64Encode(publicKey.bytes),
      'runnerReleaseHash': runnerReleaseHash,
      'resolverReleaseHash': resolverReleaseHash,
      'clockPolicy': 'system-wall-clock-v1',
      'signature': 'ed25519',
    },
  );

  Future<bool> verify(
    AgentEvaluationTrustedHoldoutAttestation attestation, {
    required int nowMs,
  }) async {
    if (attestation.keyId != keyId ||
        attestation.runnerReleaseHash != runnerReleaseHash ||
        attestation.resolverReleaseHash != resolverReleaseHash ||
        nowMs < attestation.issuedAtMs ||
        nowMs >= attestation.expiresAtMs) {
      return false;
    }
    return verifyCanonicalPayload(
      payloadJson: attestation.payloadJson,
      signatureBase64: attestation.signatureBase64,
    );
  }

  Future<bool> verifyCanonicalPayload({
    required String payloadJson,
    required String signatureBase64,
  }) async {
    late final List<int> signatureBytes;
    try {
      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map<String, Object?> ||
          AgentEvaluationHashes.canonicalJson(decoded) != payloadJson) {
        return false;
      }
      signatureBytes = base64Decode(signatureBase64);
    } on Object {
      return false;
    }
    return DartEd25519().verify(
      utf8.encode(payloadJson),
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
  }
}

class AgentEvaluationTrustedHoldoutGrant {
  const AgentEvaluationTrustedHoldoutGrant({
    required this.familyId,
    required this.tokenId,
    required this.accessId,
    required this.regressionVerdictHash,
    required this.championBundleHash,
    required this.challengerBundleHash,
    required this.executionId,
    required this.scenarioSetReleaseHash,
    required this.holdoutAccessPolicyHash,
    required this.evaluationBundleHash,
    required this.gatePolicyHash,
  });

  final String familyId;
  final String tokenId;
  final String accessId;
  final String regressionVerdictHash;
  final String championBundleHash;
  final String challengerBundleHash;
  final String executionId;
  final String scenarioSetReleaseHash;
  final String holdoutAccessPolicyHash;
  final String evaluationBundleHash;
  final String gatePolicyHash;

  factory AgentEvaluationTrustedHoldoutGrant.fromJson(
    Map<String, Object?> json,
  ) {
    String string(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('invalid trusted holdout grant $key');
      }
      return value;
    }

    return AgentEvaluationTrustedHoldoutGrant(
      familyId: string('familyId'),
      tokenId: string('tokenId'),
      accessId: string('accessId'),
      regressionVerdictHash: string('regressionVerdictHash'),
      championBundleHash: string('championBundleHash'),
      challengerBundleHash: string('challengerBundleHash'),
      executionId: string('executionId'),
      scenarioSetReleaseHash: string('scenarioSetReleaseHash'),
      holdoutAccessPolicyHash: string('holdoutAccessPolicyHash'),
      evaluationBundleHash: string('evaluationBundleHash'),
      gatePolicyHash: string('gatePolicyHash'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'familyId': familyId,
    'tokenId': tokenId,
    'accessId': accessId,
    'regressionVerdictHash': regressionVerdictHash,
    'championBundleHash': championBundleHash,
    'challengerBundleHash': challengerBundleHash,
    'executionId': executionId,
    'scenarioSetReleaseHash': scenarioSetReleaseHash,
    'holdoutAccessPolicyHash': holdoutAccessPolicyHash,
    'evaluationBundleHash': evaluationBundleHash,
    'gatePolicyHash': gatePolicyHash,
  };
}

class AgentEvaluationTrustedHoldoutProcessRequest {
  const AgentEvaluationTrustedHoldoutProcessRequest({
    required this.grant,
    required this.fixtureReleaseHash,
    required this.candidateEvidence,
    required this.nonce,
    required this.issuedAtMs,
    required this.expiresAtMs,
  });

  final AgentEvaluationTrustedHoldoutGrant grant;
  final String fixtureReleaseHash;
  final Map<String, Object?> candidateEvidence;
  final String nonce;
  final int issuedAtMs;
  final int expiresAtMs;

  factory AgentEvaluationTrustedHoldoutProcessRequest.fromJson(
    Map<String, Object?> json,
  ) {
    final grant = json['grant'];
    final fixtureReleaseHash = json['fixtureReleaseHash'];
    final candidateEvidence = json['candidateEvidence'];
    final nonce = json['nonce'];
    final issuedAtMs = json['issuedAtMs'];
    final expiresAtMs = json['expiresAtMs'];
    if (json['schemaVersion'] != 'trusted-holdout-process-request-v1' ||
        grant is! Map<String, Object?> ||
        fixtureReleaseHash is! String ||
        candidateEvidence is! Map<String, Object?> ||
        nonce is! String ||
        nonce.trim().isEmpty ||
        issuedAtMs is! int ||
        expiresAtMs is! int) {
      throw const FormatException('invalid trusted holdout process request');
    }
    return AgentEvaluationTrustedHoldoutProcessRequest(
      grant: AgentEvaluationTrustedHoldoutGrant.fromJson(grant),
      fixtureReleaseHash: fixtureReleaseHash,
      candidateEvidence: candidateEvidence,
      nonce: nonce,
      issuedAtMs: issuedAtMs,
      expiresAtMs: expiresAtMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 'trusted-holdout-process-request-v1',
    'grant': grant.toJson(),
    'fixtureReleaseHash': fixtureReleaseHash,
    'candidateEvidence': candidateEvidence,
    'nonce': nonce,
    'issuedAtMs': issuedAtMs,
    'expiresAtMs': expiresAtMs,
  };
}

/// Separate SQLite vault used by the trusted-runner process only.
///
/// The authoring process receives a signed pass/fail envelope and never the
/// fixture or reference facts. Production deployments should place [path] in
/// an OS ACL/KMS-protected location and load the signing seed from KMS.
class AgentEvaluationTrustedHoldoutVault {
  AgentEvaluationTrustedHoldoutVault._({
    required this.path,
    required Database db,
    required this.signer,
  }) : _db = db;

  factory AgentEvaluationTrustedHoldoutVault.open({
    required String path,
    required AgentEvaluationTrustedHoldoutSigner signer,
  }) {
    final file = File(path).absolute;
    file.parent.createSync(recursive: true);
    final db = sqlite3.open(file.path);
    db.execute('PRAGMA foreign_keys = ON');
    // DELETE journaling avoids leaving raw holdout facts in separately
    // permissioned WAL/SHM sidecars; the vault file itself is chmod 0600.
    db.execute('PRAGMA journal_mode = DELETE');
    db.execute('''
      CREATE TABLE IF NOT EXISTS trusted_holdout_fixtures (
        fixture_release_hash TEXT PRIMARY KEY,
        scenario_set_release_hash TEXT NOT NULL,
        fixture_json TEXT NOT NULL,
        reference_facts_json TEXT NOT NULL,
        resolver_release_hash TEXT NOT NULL,
        created_at_ms INTEGER NOT NULL,
        expires_at_ms INTEGER NOT NULL
      )
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS trusted_holdout_audit_events (
        event_hash TEXT PRIMARY KEY,
        event_ordinal INTEGER NOT NULL UNIQUE,
        access_id TEXT NOT NULL UNIQUE,
        fixture_release_hash TEXT NOT NULL,
        result TEXT NOT NULL,
        previous_event_hash TEXT,
        created_at_ms INTEGER NOT NULL
      )
    ''');
    if (!Platform.isWindows) {
      final chmod = Process.runSync('chmod', <String>['600', file.path]);
      if (chmod.exitCode != 0) {
        db.dispose();
        throw StateError('trusted holdout vault ACL could not be restricted');
      }
    }
    return AgentEvaluationTrustedHoldoutVault._(
      path: file.path,
      db: db,
      signer: signer,
    );
  }

  final String path;
  final Database _db;
  final AgentEvaluationTrustedHoldoutSigner signer;

  String publishFixture({
    required String scenarioSetReleaseHash,
    required Map<String, Object?> fixture,
    required Map<String, Object?> referenceFacts,
    required int createdAtMs,
    required int expiresAtMs,
  }) {
    AgentEvaluationHashes.requireDigest(
      scenarioSetReleaseHash,
      'scenarioSetReleaseHash',
    );
    if (createdAtMs < 0 || expiresAtMs <= createdAtMs) {
      throw ArgumentError('invalid trusted holdout fixture TTL');
    }
    final fixtureJson = AgentEvaluationHashes.canonicalJson(fixture);
    final factsJson = AgentEvaluationHashes.canonicalJson(referenceFacts);
    final releaseHash = AgentEvaluationHashes.domainHash(
      'eval-private-holdout-fixture-v1',
      <String, Object?>{
        'scenarioSetReleaseHash': scenarioSetReleaseHash,
        'fixture': fixture,
        'referenceFacts': referenceFacts,
        'resolverReleaseHash':
            AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
        'expiresAtMs': expiresAtMs,
      },
    );
    _db.execute(
      '''INSERT INTO trusted_holdout_fixtures (
           fixture_release_hash, scenario_set_release_hash, fixture_json,
           reference_facts_json, resolver_release_hash, created_at_ms,
           expires_at_ms
         ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
      <Object?>[
        releaseHash,
        scenarioSetReleaseHash,
        fixtureJson,
        factsJson,
        AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
        createdAtMs,
        expiresAtMs,
      ],
    );
    return releaseHash;
  }

  Future<AgentEvaluationTrustedHoldoutAttestation> evaluateAndAttest({
    required String authorityDatabasePath,
    required AgentEvaluationTrustedHoldoutGrant grant,
    required String fixtureReleaseHash,
    required Map<String, Object?> candidateEvidence,
    required String nonce,
    required int issuedAtMs,
    required int expiresAtMs,
  }) async {
    _verifySpentAuthorityGrant(
      authorityDatabasePath: authorityDatabasePath,
      grant: grant,
    );
    final rows = _db.select(
      '''SELECT * FROM trusted_holdout_fixtures
         WHERE fixture_release_hash = ? AND scenario_set_release_hash = ?
           AND resolver_release_hash = ? AND created_at_ms <= ?
           AND expires_at_ms >= ?''',
      <Object?>[
        fixtureReleaseHash,
        grant.scenarioSetReleaseHash,
        AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
        issuedAtMs,
        expiresAtMs,
      ],
    );
    if (rows.length != 1 || expiresAtMs <= issuedAtMs) {
      throw StateError(
        'trusted holdout fixture is missing, expired, or misbound',
      );
    }
    final row = rows.single;
    final fixture = _jsonObject(row['fixture_json'] as String);
    final facts = _jsonObject(row['reference_facts_json'] as String);
    final result = _evaluateCandidateEvidence(
      fixture: fixture,
      referenceFacts: facts,
      candidateEvidence: candidateEvidence,
    );
    _db.execute('BEGIN IMMEDIATE');
    try {
      final previousRows = _db.select(
        '''SELECT event_hash, event_ordinal FROM trusted_holdout_audit_events
           ORDER BY event_ordinal DESC LIMIT 1''',
      );
      final ordinal = previousRows.isEmpty
          ? 0
          : (previousRows.single['event_ordinal'] as int) + 1;
      final previous = previousRows.isEmpty
          ? null
          : previousRows.single['event_hash'] as String;
      final auditRoot = AgentEvaluationHashes.domainHash(
        'eval-trusted-holdout-audit-event-v1',
        <String, Object?>{
          'ordinal': ordinal,
          'accessId': grant.accessId,
          'fixtureReleaseHash': fixtureReleaseHash,
          'result': result,
          'previousEventHash': previous,
          'createdAtMs': issuedAtMs,
        },
      );
      final signed = await signer.sign(
        AgentEvaluationTrustedHoldoutAttestation(
          familyId: grant.familyId,
          tokenId: grant.tokenId,
          accessId: grant.accessId,
          regressionVerdictHash: grant.regressionVerdictHash,
          championBundleHash: grant.championBundleHash,
          challengerBundleHash: grant.challengerBundleHash,
          executionId: grant.executionId,
          scenarioSetReleaseHash: grant.scenarioSetReleaseHash,
          holdoutAccessPolicyHash: grant.holdoutAccessPolicyHash,
          evaluationBundleHash: grant.evaluationBundleHash,
          gatePolicyHash: grant.gatePolicyHash,
          result: result,
          fixtureReleaseHash: fixtureReleaseHash,
          auditRootHash: auditRoot,
          runnerReleaseHash:
              AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash,
          resolverReleaseHash:
              AgentEvaluationTrustedHoldoutPolicy.resolverReleaseHash,
          keyId: signer.keyId,
          nonce: nonce,
          issuedAtMs: issuedAtMs,
          expiresAtMs: expiresAtMs,
          signatureBase64: 'unsigned',
        ),
      );
      _db.execute(
        '''INSERT INTO trusted_holdout_audit_events (
             event_hash, event_ordinal, access_id, fixture_release_hash, result,
             previous_event_hash, created_at_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
        <Object?>[
          auditRoot,
          ordinal,
          grant.accessId,
          fixtureReleaseHash,
          result,
          previous,
          issuedAtMs,
        ],
      );
      _db.execute('COMMIT');
      return signed;
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void dispose() => _db.dispose();

  static Map<String, Object?> _jsonObject(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?>) {
      throw StateError('trusted holdout vault payload is malformed');
    }
    return decoded;
  }

  static String _evaluateCandidateEvidence({
    required Map<String, Object?> fixture,
    required Map<String, Object?> referenceFacts,
    required Map<String, Object?> candidateEvidence,
  }) {
    final schema = fixture['candidateEvidenceSchema'];
    if (schema != null && schema != 'exact-reference-facts-v1') {
      return 'insufficientEvidence';
    }
    final nestedExpected = referenceFacts['expectedCandidateEvidence'];
    final expected = nestedExpected is Map<String, Object?>
        ? nestedExpected
        : referenceFacts;
    return AgentEvaluationHashes.canonicalJson(candidateEvidence) ==
            AgentEvaluationHashes.canonicalJson(expected)
        ? 'pass'
        : 'fail';
  }

  static void _verifySpentAuthorityGrant({
    required String authorityDatabasePath,
    required AgentEvaluationTrustedHoldoutGrant grant,
  }) {
    final authorityFile = File(authorityDatabasePath).absolute;
    if (!authorityFile.existsSync()) {
      throw StateError('trusted holdout authority database is missing');
    }
    final authority = sqlite3.open(authorityFile.path, mode: OpenMode.readOnly);
    try {
      final rows = authority.select(
        '''SELECT a.*, t.regression_verdict_hash,
             t.family_id AS token_family_id,
             t.challenger_bundle_hash AS token_challenger_bundle_hash,
             t.state AS token_state, t.consumed_at_ms,
             f.scenario_set_release_hash, f.holdout_access_policy_hash,
             e.evaluation_bundle_hash,
             v.verdict_kind, v.status AS regression_status,
             v.champion_bundle_hash AS regression_champion_bundle_hash,
             v.challenger_bundle_hash AS regression_challenger_bundle_hash,
             v.policy_hash AS regression_policy_hash,
             v.gate_release_hash AS regression_gate_release_hash,
             d.authority_release_hash
           FROM eval_holdout_accesses a
           JOIN eval_holdout_tokens t ON t.token_id = a.token_id
           JOIN eval_experiment_families f ON f.family_id = a.family_id
           JOIN eval_executions x ON x.execution_id = a.execution_id
           JOIN eval_experiments e ON e.experiment_id = x.experiment_id
           JOIN eval_release_gate_verdicts v
             ON v.verdict_hash = t.regression_verdict_hash
           JOIN eval_release_gate_derivations d
             ON d.verdict_hash = v.verdict_hash
             AND d.authority_release_hash = v.gate_release_hash
           WHERE a.access_id = ?''',
        <Object?>[grant.accessId],
      );
      if (rows.length != 1) {
        throw StateError('trusted holdout access authority is missing');
      }
      final row = rows.single;
      if (row['state'] != 'begun' ||
          row['token_state'] != 'consumed' ||
          row['consumed_at_ms'] == null ||
          row['begun_at_ms'] != row['consumed_at_ms'] ||
          row['token_id'] != grant.tokenId ||
          row['family_id'] != grant.familyId ||
          row['token_family_id'] != grant.familyId ||
          row['challenger_bundle_hash'] != grant.challengerBundleHash ||
          row['token_challenger_bundle_hash'] != grant.challengerBundleHash ||
          row['execution_id'] != grant.executionId ||
          row['trusted_runner_release_hash'] !=
              AgentEvaluationTrustedHoldoutPolicy.runnerReleaseHash ||
          row['regression_verdict_hash'] != grant.regressionVerdictHash ||
          row['scenario_set_release_hash'] != grant.scenarioSetReleaseHash ||
          row['holdout_access_policy_hash'] != grant.holdoutAccessPolicyHash ||
          row['evaluation_bundle_hash'] != grant.evaluationBundleHash ||
          row['verdict_kind'] != 'regression' ||
          row['regression_status'] != 'promote' ||
          row['regression_champion_bundle_hash'] != grant.championBundleHash ||
          row['regression_challenger_bundle_hash'] !=
              grant.challengerBundleHash ||
          row['regression_policy_hash'] != grant.gatePolicyHash ||
          row['regression_gate_release_hash'] !=
              row['authority_release_hash']) {
        throw StateError(
          'trusted holdout access does not bind the supplied authority graph',
        );
      }
    } finally {
      authority.dispose();
    }
  }
}
