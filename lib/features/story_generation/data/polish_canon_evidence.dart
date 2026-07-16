import '../../../app/llm/app_llm_canonical_hash.dart';

/// Immutable, hash-bound evidence emitted by the production polish canon gate.
final class PolishCanonEvidence {
  PolishCanonEvidence({
    required this.verifierReleaseHash,
    required this.prePolishProseHash,
    required this.finalProseHash,
    required this.allowedCanonRootHash,
    required Iterable<String> allowedCanonFactHashes,
    required Iterable<PolishCanonIntroducedFact> introducedFacts,
  }) : allowedCanonFactHashes = List<String>.unmodifiable(
         allowedCanonFactHashes.toList()..sort(),
       ),
       introducedFacts = List<PolishCanonIntroducedFact>.unmodifiable(
         introducedFacts.toList()
           ..sort((left, right) => left.factHash.compareTo(right.factHash)),
       ) {
    _requireDigest(verifierReleaseHash, 'verifierReleaseHash');
    _requireDigest(prePolishProseHash, 'prePolishProseHash');
    _requireDigest(finalProseHash, 'finalProseHash');
    _requireDigest(allowedCanonRootHash, 'allowedCanonRootHash');
    if (this.allowedCanonFactHashes.toSet().length !=
        this.allowedCanonFactHashes.length) {
      throw ArgumentError('allowed canon fact hashes must be unique');
    }
    for (final value in this.allowedCanonFactHashes) {
      _requireDigest(value, 'allowedCanonFactHash');
    }
    if (this.introducedFacts.map((fact) => fact.factHash).toSet().length !=
        this.introducedFacts.length) {
      throw ArgumentError('introduced canon fact hashes must be unique');
    }
  }

  static const schemaVersion = 'polish-canon-evidence-v1';

  final String verifierReleaseHash;
  final String prePolishProseHash;
  final String finalProseHash;
  final String allowedCanonRootHash;
  final List<String> allowedCanonFactHashes;
  final List<PolishCanonIntroducedFact> introducedFacts;

  bool get passed => introducedFacts.isEmpty;

  List<String> get introducedFactHashes =>
      List<String>.unmodifiable(introducedFacts.map((fact) => fact.factHash));

  List<String> get failureCodes => List<String>.unmodifiable(
    introducedFacts.map((fact) => fact.failureCode).toSet().toList()..sort(),
  );

  String get evidenceHash => AppLlmCanonicalHash.domainHash(
    'polish-canon-evidence-v1',
    _identityJson(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    ..._identityJson(),
    'evidenceHash': evidenceHash,
  };

  static PolishCanonEvidence fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('polish canon evidence must be an object');
    }
    final value = <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    if (value.keys.toSet().difference(const <String>{
          'schemaVersion',
          'verifierReleaseHash',
          'prePolishProseHash',
          'finalProseHash',
          'allowedCanonRootHash',
          'allowedCanonFactHashes',
          'introducedFacts',
          'passed',
          'failureCodes',
          'evidenceHash',
        }).isNotEmpty ||
        value['schemaVersion'] != schemaVersion ||
        value['allowedCanonFactHashes'] is! List ||
        value['introducedFacts'] is! List ||
        value['failureCodes'] is! List) {
      throw const FormatException('polish canon evidence shape is invalid');
    }
    final evidence = PolishCanonEvidence(
      verifierReleaseHash: value['verifierReleaseHash'] as String,
      prePolishProseHash: value['prePolishProseHash'] as String,
      finalProseHash: value['finalProseHash'] as String,
      allowedCanonRootHash: value['allowedCanonRootHash'] as String,
      allowedCanonFactHashes: (value['allowedCanonFactHashes'] as List)
          .cast<String>(),
      introducedFacts: (value['introducedFacts'] as List).map(
        PolishCanonIntroducedFact.fromJson,
      ),
    );
    final encodedFailures = List<String>.of(
      (value['failureCodes'] as List).cast<String>(),
    )..sort();
    if (value['passed'] != evidence.passed ||
        AppLlmCanonicalHash.canonicalJson(encodedFailures) !=
            AppLlmCanonicalHash.canonicalJson(evidence.failureCodes) ||
        value['evidenceHash'] != evidence.evidenceHash) {
      throw const FormatException('polish canon evidence hash is invalid');
    }
    return evidence;
  }

  Map<String, Object?> _identityJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'verifierReleaseHash': verifierReleaseHash,
    'prePolishProseHash': prePolishProseHash,
    'finalProseHash': finalProseHash,
    'allowedCanonRootHash': allowedCanonRootHash,
    'allowedCanonFactHashes': allowedCanonFactHashes,
    'introducedFacts': <Object?>[
      for (final fact in introducedFacts) fact.toJson(),
    ],
    'passed': passed,
    'failureCodes': failureCodes,
  };
}

final class PolishCanonIntroducedFact {
  PolishCanonIntroducedFact({
    required this.kind,
    required this.factHash,
    required this.failureCode,
  }) {
    _requireDigest(factHash, 'introducedFactHash');
    if (failureCode != 'continuity.polish_unknown_${kind.name}') {
      throw ArgumentError('introduced fact failure code is invalid');
    }
  }

  final PolishCanonFactKind kind;
  final String factHash;
  final String failureCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    'factHash': factHash,
    'failureCode': failureCode,
  };

  static PolishCanonIntroducedFact fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('introduced polish fact must be an object');
    }
    final value = <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    if (value.keys.toSet().difference(const <String>{
      'kind',
      'factHash',
      'failureCode',
    }).isNotEmpty) {
      throw const FormatException('introduced polish fact shape is invalid');
    }
    return PolishCanonIntroducedFact(
      kind: PolishCanonFactKind.values.byName(value['kind'] as String),
      factHash: value['factHash'] as String,
      failureCode: value['failureCode'] as String,
    );
  }
}

enum PolishCanonFactKind { character, item, canon }

void _requireDigest(String value, String field) {
  if (!RegExp(r'^(?:sha256:)?[a-f0-9]{64}$').hasMatch(value)) {
    throw ArgumentError('$field must be a lowercase SHA-256 identity');
  }
}
