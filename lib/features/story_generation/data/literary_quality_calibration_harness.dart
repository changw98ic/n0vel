import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';

abstract final class LiteraryQualityFixtureContract {
  static const artifactVersion = 'literary-quality-development-corpus-v1';
  static const parserRelease = 'scene-literary-quality-parser-v1';
  static const sourceAdmissionPolicy =
      'synthetic-project-owned-no-named-imitation-v1';

  static const Map<String, int> primaryFamilyMinimums = {
    'causalMainlineHard': 25,
    'povKnowledge': 25,
    'worldObjectTime': 25,
    'motivationRelationship': 25,
    'craftWeakness': 50,
    'styleChoice': 50,
    'effectiveDeviation': 30,
    'prettyHollow': 30,
    'highScoreDisguisedBad': 20,
  };

  static const Map<String, int> negativeControlMinimums = {
    'unreliableNarrator': 10,
    'nonlinearTime': 10,
    'multiplePov': 10,
    'freeIndirectDiscourse': 10,
    'declaredRuleException': 10,
  };

  static const Set<int> requiredAnchorScores = {60, 75, 85, 90, 95};
}

final class LiteraryQualityWilsonInterval {
  const LiteraryQualityWilsonInterval({
    required this.point,
    required this.ci95Low,
    required this.ci95High,
    required this.sampleSize,
  });

  final double point;
  final double ci95Low;
  final double ci95High;
  final int sampleSize;

  static LiteraryQualityWilsonInterval calculate({
    required int successes,
    required int sampleSize,
  }) {
    if (sampleSize <= 0 || successes < 0 || successes > sampleSize) {
      throw ArgumentError('Wilson inputs must satisfy 0 <= successes <= n');
    }
    const z = 1.959963984540054;
    final n = sampleSize.toDouble();
    final point = successes / n;
    const zSquared = z * z;
    final denominator = 1 + zSquared / n;
    final center = (point + zSquared / (2 * n)) / denominator;
    final margin =
        z *
        math.sqrt((point * (1 - point) + zSquared / (4 * n)) / n) /
        denominator;
    return LiteraryQualityWilsonInterval(
      point: point,
      ci95Low: math.max(0, center - margin),
      ci95High: math.min(1, center + margin),
      sampleSize: sampleSize,
    );
  }

  Map<String, Object?> toJson() => {
    'point': point,
    'ci95Low': ci95Low,
    'ci95High': ci95High,
    'sampleSize': sampleSize,
  };
}

final class LiteraryQualityDevelopmentFixture {
  LiteraryQualityDevelopmentFixture._({
    required this.fixtureId,
    required this.fixtureHash,
    required this.primaryFamily,
    required this.voiceTag,
    required this.anchorScore,
    required this.negativeControl,
    required this.provenanceId,
    required this.prose,
    required this.expectedFindingClasses,
    required this.expectedSeverity,
    required this.expectedBlocked,
    required this.expectedReleaseEligible,
    required this.contractDeclaration,
    required this.defectSummary,
    required this.anchorRationale,
  });

  final String fixtureId;
  final String fixtureHash;
  final String primaryFamily;
  final String voiceTag;
  final int anchorScore;
  final String? negativeControl;
  final String provenanceId;
  final String prose;
  final List<String> expectedFindingClasses;
  final String expectedSeverity;
  final bool expectedBlocked;
  final bool expectedReleaseEligible;
  final String contractDeclaration;
  final String defectSummary;
  final String anchorRationale;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'fixtureId': fixtureId,
    'primaryFamily': primaryFamily,
    'voiceTag': voiceTag,
    'anchorScore': anchorScore,
    'negativeControl': negativeControl,
    'provenanceId': provenanceId,
    'prose': prose,
    'expectedFindingClasses': expectedFindingClasses,
    'expectedSeverity': expectedSeverity,
    'expectedBlocked': expectedBlocked,
    'expectedReleaseEligible': expectedReleaseEligible,
    'contractDeclaration': contractDeclaration,
    'defectSummary': defectSummary,
    'anchorRationale': anchorRationale,
  };

  static LiteraryQualityDevelopmentFixture fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, 'fixture', const {
      'schemaVersion',
      'fixtureId',
      'fixtureHash',
      'primaryFamily',
      'voiceTag',
      'anchorScore',
      'negativeControl',
      'provenanceId',
      'prose',
      'expectedFindingClasses',
      'expectedSeverity',
      'expectedBlocked',
      'expectedReleaseEligible',
      'contractDeclaration',
      'defectSummary',
      'anchorRationale',
    });
    if (_int(json, 'schemaVersion') != 1) {
      throw const FormatException('unsupported fixture schemaVersion');
    }
    final fixture = LiteraryQualityDevelopmentFixture._(
      fixtureId: _string(json, 'fixtureId'),
      fixtureHash: _string(json, 'fixtureHash'),
      primaryFamily: _string(json, 'primaryFamily'),
      voiceTag: _string(json, 'voiceTag'),
      anchorScore: _int(json, 'anchorScore'),
      negativeControl: _nullableString(json, 'negativeControl'),
      provenanceId: _string(json, 'provenanceId'),
      prose: _string(json, 'prose'),
      expectedFindingClasses: _stringList(json, 'expectedFindingClasses'),
      expectedSeverity: _string(json, 'expectedSeverity'),
      expectedBlocked: _bool(json, 'expectedBlocked'),
      expectedReleaseEligible: _bool(json, 'expectedReleaseEligible'),
      contractDeclaration: _string(json, 'contractDeclaration'),
      defectSummary: _string(json, 'defectSummary'),
      anchorRationale: _string(json, 'anchorRationale'),
    );
    final expectedHash = AppLlmCanonicalHash.domainHash(
      'literary-quality-development-fixture-v1',
      fixture.identityJson,
    );
    if (fixture.fixtureHash != expectedHash) {
      throw FormatException('fixture hash mismatch: ${fixture.fixtureId}');
    }
    if (!LiteraryQualityFixtureContract.primaryFamilyMinimums.containsKey(
          fixture.primaryFamily,
        ) ||
        !LiteraryQualityFixtureContract.requiredAnchorScores.contains(
          fixture.anchorScore,
        )) {
      throw FormatException(
        'fixture labels are not admitted: ${fixture.fixtureId}',
      );
    }
    if (fixture.negativeControl != null &&
        !LiteraryQualityFixtureContract.negativeControlMinimums.containsKey(
          fixture.negativeControl,
        )) {
      throw FormatException(
        'unknown negative control: ${fixture.negativeControl}',
      );
    }
    if (fixture.negativeControl != null && fixture.expectedBlocked) {
      throw FormatException(
        'negative control must not expect blocking: ${fixture.fixtureId}',
      );
    }
    if (fixture.expectedBlocked && fixture.expectedReleaseEligible) {
      throw FormatException(
        'blocked fixture cannot be release eligible: ${fixture.fixtureId}',
      );
    }
    return fixture;
  }
}

final class LiteraryQualityFixtureProvenance {
  LiteraryQualityFixtureProvenance._({
    required this.provenanceId,
    required this.provenanceHash,
    required this.sourceKind,
    required this.licenseStatus,
    required this.allowedUses,
    required this.createdForTesting,
    required this.namedWorkImitation,
    required this.sourceBodyHash,
  });

  final String provenanceId;
  final String provenanceHash;
  final String sourceKind;
  final String licenseStatus;
  final List<String> allowedUses;
  final bool createdForTesting;
  final bool namedWorkImitation;
  final String sourceBodyHash;

  Map<String, Object?> get identityJson => {
    'schemaVersion': 1,
    'provenanceId': provenanceId,
    'sourceKind': sourceKind,
    'licenseStatus': licenseStatus,
    'allowedUses': allowedUses,
    'createdForTesting': createdForTesting,
    'namedWorkImitation': namedWorkImitation,
    'sourceBodyHash': sourceBodyHash,
  };

  static LiteraryQualityFixtureProvenance fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, 'provenance', const {
      'schemaVersion',
      'provenanceId',
      'provenanceHash',
      'sourceKind',
      'licenseStatus',
      'allowedUses',
      'createdForTesting',
      'namedWorkImitation',
      'sourceBodyHash',
    });
    if (_int(json, 'schemaVersion') != 1) {
      throw const FormatException('unsupported provenance schemaVersion');
    }
    final provenance = LiteraryQualityFixtureProvenance._(
      provenanceId: _string(json, 'provenanceId'),
      provenanceHash: _string(json, 'provenanceHash'),
      sourceKind: _string(json, 'sourceKind'),
      licenseStatus: _string(json, 'licenseStatus'),
      allowedUses: _stringList(json, 'allowedUses'),
      createdForTesting: _bool(json, 'createdForTesting'),
      namedWorkImitation: _bool(json, 'namedWorkImitation'),
      sourceBodyHash: _string(json, 'sourceBodyHash'),
    );
    final expectedHash = AppLlmCanonicalHash.domainHash(
      'literary-quality-fixture-provenance-v1',
      provenance.identityJson,
    );
    if (provenance.provenanceHash != expectedHash ||
        provenance.sourceKind != 'synthetic' ||
        provenance.licenseStatus != 'projectOwned' ||
        !provenance.createdForTesting ||
        provenance.namedWorkImitation ||
        provenance.allowedUses.toSet().length !=
            provenance.allowedUses.length ||
        !provenance.allowedUses.toSet().containsAll(const {
          'evaluation',
          'calibration',
        })) {
      throw FormatException(
        'provenance is not admitted: ${provenance.provenanceId}',
      );
    }
    return provenance;
  }
}

final class LiteraryQualityDevelopmentCorpus {
  LiteraryQualityDevelopmentCorpus._({
    required this.corpusId,
    required this.rubricVersion,
    required this.thresholdPolicyVersion,
    required this.fixtureSetHash,
    required this.provenanceSetHash,
    required this.corpusHash,
    required this.fixtures,
    required this.provenance,
  });

  final String corpusId;
  final String rubricVersion;
  final String thresholdPolicyVersion;
  final String fixtureSetHash;
  final String provenanceSetHash;
  final String corpusHash;
  final List<LiteraryQualityDevelopmentFixture> fixtures;
  final List<LiteraryQualityFixtureProvenance> provenance;

  Map<String, int> get primaryFamilyCounts =>
      _counts(fixtures.map((fixture) => fixture.primaryFamily));

  Map<String, int> get negativeControlCounts => _counts(
    fixtures.map((fixture) => fixture.negativeControl).whereType<String>(),
  );

  Map<String, int> get voiceTagCounts =>
      _counts(fixtures.map((fixture) => fixture.voiceTag));

  Map<String, int> get anchorCounts =>
      _counts(fixtures.map((fixture) => fixture.anchorScore.toString()));

  static LiteraryQualityDevelopmentCorpus loadSync(Directory root) {
    final manifestFile = File('${root.path}/manifest.json');
    final manifest = _jsonObject(
      jsonDecode(manifestFile.readAsStringSync()),
      'manifest',
    );
    _expectExactKeys(manifest, 'manifest', const {
      'artifactVersion',
      'corpusId',
      'rubricVersion',
      'parserRelease',
      'thresholdPolicyVersion',
      'sourceAdmissionPolicy',
      'uniqueFixtureCount',
      'primaryFamilyMinimums',
      'negativeControlMinimums',
      'minimumVoiceCount',
      'minimumFixturesPerVoice',
      'requiredAnchorScores',
      'fixtureShards',
      'provenanceFile',
      'fixtureSetHash',
      'provenanceSetHash',
      'corpusHash',
      'certificationFence',
      'formalHumanAdjudicatedHardCount',
      'formalHumanAdjudicatedNonHardCount',
    });
    if (_string(manifest, 'artifactVersion') !=
            LiteraryQualityFixtureContract.artifactVersion ||
        _string(manifest, 'parserRelease') !=
            LiteraryQualityFixtureContract.parserRelease ||
        _string(manifest, 'sourceAdmissionPolicy') !=
            LiteraryQualityFixtureContract.sourceAdmissionPolicy ||
        _bool(manifest, 'certificationFence') ||
        _int(manifest, 'formalHumanAdjudicatedHardCount') != 0 ||
        _int(manifest, 'formalHumanAdjudicatedNonHardCount') != 0) {
      throw const FormatException('development corpus authority is invalid');
    }
    _expectIntMapEquals(
      _jsonObject(manifest['primaryFamilyMinimums'], 'primaryFamilyMinimums'),
      LiteraryQualityFixtureContract.primaryFamilyMinimums,
      'primaryFamilyMinimums',
    );
    _expectIntMapEquals(
      _jsonObject(
        manifest['negativeControlMinimums'],
        'negativeControlMinimums',
      ),
      LiteraryQualityFixtureContract.negativeControlMinimums,
      'negativeControlMinimums',
    );
    final requiredAnchors = _intList(manifest, 'requiredAnchorScores').toSet();
    if (requiredAnchors.length !=
            LiteraryQualityFixtureContract.requiredAnchorScores.length ||
        !requiredAnchors.containsAll(
          LiteraryQualityFixtureContract.requiredAnchorScores,
        )) {
      throw const FormatException('required anchor scores changed');
    }

    final fixtures = <LiteraryQualityDevelopmentFixture>[];
    for (final shard in _stringList(manifest, 'fixtureShards')) {
      fixtures.addAll(
        _readJsonLines(
          File('${root.path}/$shard'),
        ).map(LiteraryQualityDevelopmentFixture.fromJson),
      );
    }
    final provenance = _readJsonLines(
      File('${root.path}/${_string(manifest, 'provenanceFile')}'),
    ).map(LiteraryQualityFixtureProvenance.fromJson).toList(growable: false);

    final fixtureIds = fixtures.map((item) => item.fixtureId).toSet();
    final fixtureHashes = fixtures.map((item) => item.fixtureHash).toSet();
    final provenanceIds = provenance.map((item) => item.provenanceId).toSet();
    final provenanceHashes = provenance
        .map((item) => item.provenanceHash)
        .toSet();
    if (fixtureIds.length != fixtures.length ||
        fixtureHashes.length != fixtures.length ||
        provenanceIds.length != provenance.length ||
        provenanceHashes.length != provenance.length ||
        fixtures.length != provenance.length ||
        fixtures.length != _int(manifest, 'uniqueFixtureCount') ||
        fixtures.length < 300) {
      throw const FormatException('fixture/provenance uniqueness failed');
    }
    final provenanceById = {
      for (final item in provenance) item.provenanceId: item,
    };
    for (final fixture in fixtures) {
      final source = provenanceById[fixture.provenanceId];
      final sourceBodyHash = AppLlmCanonicalHash.domainHash(
        'literary-fixture-source-body-v1',
        fixture.prose,
      );
      if (source == null || source.sourceBodyHash != sourceBodyHash) {
        throw FormatException(
          'fixture provenance does not bind prose: ${fixture.fixtureId}',
        );
      }
    }

    final sortedFixtureHashes = fixtureHashes.toList()..sort();
    final sortedProvenanceHashes = provenanceHashes.toList()..sort();
    final fixtureSetHash = AppLlmCanonicalHash.domainHash(
      'literary-quality-fixture-set-v1',
      sortedFixtureHashes,
    );
    final provenanceSetHash = AppLlmCanonicalHash.domainHash(
      'literary-quality-provenance-set-v1',
      sortedProvenanceHashes,
    );
    if (fixtureSetHash != _string(manifest, 'fixtureSetHash') ||
        provenanceSetHash != _string(manifest, 'provenanceSetHash')) {
      throw const FormatException('fixture set seal mismatch');
    }
    final corpusIdentity = {
      'artifactVersion': _string(manifest, 'artifactVersion'),
      'corpusId': _string(manifest, 'corpusId'),
      'rubricVersion': _string(manifest, 'rubricVersion'),
      'parserRelease': _string(manifest, 'parserRelease'),
      'thresholdPolicyVersion': _string(manifest, 'thresholdPolicyVersion'),
      'sourceAdmissionPolicy': _string(manifest, 'sourceAdmissionPolicy'),
      'uniqueFixtureCount': fixtures.length,
      'fixtureSetHash': fixtureSetHash,
      'provenanceSetHash': provenanceSetHash,
      'certificationFence': false,
    };
    final corpusHash = AppLlmCanonicalHash.domainHash(
      'literary-quality-development-corpus-v1',
      corpusIdentity,
    );
    if (corpusHash != _string(manifest, 'corpusHash')) {
      throw const FormatException('corpus hash mismatch');
    }

    final corpus = LiteraryQualityDevelopmentCorpus._(
      corpusId: _string(manifest, 'corpusId'),
      rubricVersion: _string(manifest, 'rubricVersion'),
      thresholdPolicyVersion: _string(manifest, 'thresholdPolicyVersion'),
      fixtureSetHash: fixtureSetHash,
      provenanceSetHash: provenanceSetHash,
      corpusHash: corpusHash,
      fixtures: List.unmodifiable(fixtures),
      provenance: List.unmodifiable(provenance),
    );
    corpus._validateCoverage(
      minimumVoiceCount: _int(manifest, 'minimumVoiceCount'),
      minimumFixturesPerVoice: _int(manifest, 'minimumFixturesPerVoice'),
    );
    return corpus;
  }

  void _validateCoverage({
    required int minimumVoiceCount,
    required int minimumFixturesPerVoice,
  }) {
    for (final entry
        in LiteraryQualityFixtureContract.primaryFamilyMinimums.entries) {
      if ((primaryFamilyCounts[entry.key] ?? 0) < entry.value) {
        throw FormatException('primary family below minimum: ${entry.key}');
      }
    }
    for (final entry
        in LiteraryQualityFixtureContract.negativeControlMinimums.entries) {
      if ((negativeControlCounts[entry.key] ?? 0) < entry.value) {
        throw FormatException('negative control below minimum: ${entry.key}');
      }
    }
    if (voiceTagCounts.length < minimumVoiceCount ||
        voiceTagCounts.values.any((count) => count < minimumFixturesPerVoice)) {
      throw const FormatException('voice coverage below minimum');
    }
    if (!anchorCounts.keys
        .map(int.parse)
        .toSet()
        .containsAll(LiteraryQualityFixtureContract.requiredAnchorScores)) {
      throw const FormatException('anchor coverage below minimum');
    }
  }
}

final class LiteraryQualityDevelopmentCalibrationArtifact {
  LiteraryQualityDevelopmentCalibrationArtifact._({
    required this.corpusHash,
    required this.uniqueItemCount,
    required this.metricStatus,
    required this.humanAdjudicatedHardDecisions,
    required this.humanAdjudicatedNonHardDecisions,
    required this.formalCertificationEligible,
    required this.limitation,
    required this.artifactHash,
  });

  final String corpusHash;
  final int uniqueItemCount;
  final String metricStatus;
  final int humanAdjudicatedHardDecisions;
  final int humanAdjudicatedNonHardDecisions;
  final bool formalCertificationEligible;
  final String limitation;
  final String artifactHash;

  static LiteraryQualityDevelopmentCalibrationArtifact loadSync(
    File file,
    LiteraryQualityDevelopmentCorpus corpus,
  ) {
    final json = _jsonObject(
      jsonDecode(file.readAsStringSync()),
      'calibration',
    );
    _expectExactKeys(json, 'calibration', const {
      'artifactVersion',
      'corpusHash',
      'uniqueItemCount',
      'primaryClassCounts',
      'voiceTagCounts',
      'negativeControlCounts',
      'anchorCounts',
      'metricStatus',
      'metrics',
      'humanAdjudicatedHardDecisions',
      'humanAdjudicatedNonHardDecisions',
      'formalCertificationEligible',
      'limitation',
      'artifactHash',
    });
    if (_string(json, 'artifactVersion') !=
            'literary-calibration-development-v1' ||
        _string(json, 'corpusHash') != corpus.corpusHash ||
        _int(json, 'uniqueItemCount') != corpus.fixtures.length) {
      throw const FormatException('calibration corpus binding failed');
    }
    _expectIntMapEquals(
      _jsonObject(json['primaryClassCounts'], 'primaryClassCounts'),
      corpus.primaryFamilyCounts,
      'primaryClassCounts',
    );
    _expectIntMapEquals(
      _jsonObject(json['voiceTagCounts'], 'voiceTagCounts'),
      corpus.voiceTagCounts,
      'voiceTagCounts',
    );
    _expectIntMapEquals(
      _jsonObject(json['negativeControlCounts'], 'negativeControlCounts'),
      corpus.negativeControlCounts,
      'negativeControlCounts',
    );
    _expectIntMapEquals(
      _jsonObject(json['anchorCounts'], 'anchorCounts'),
      corpus.anchorCounts,
      'anchorCounts',
    );
    final metricStatus = _string(json, 'metricStatus');
    final metrics = _jsonObject(json['metrics'], 'metrics');
    final hard = _int(json, 'humanAdjudicatedHardDecisions');
    final nonHard = _int(json, 'humanAdjudicatedNonHardDecisions');
    final formalEligible = _bool(json, 'formalCertificationEligible');
    if (metricStatus != 'pendingRealEvaluatorRun' ||
        metrics.isNotEmpty ||
        hard != 0 ||
        nonHard != 0 ||
        formalEligible) {
      throw const FormatException(
        'development artifact must not claim formal calibration',
      );
    }
    final identity = {
      for (final entry in json.entries)
        if (entry.key != 'artifactHash') entry.key: entry.value,
    };
    final artifactHash = AppLlmCanonicalHash.domainHash(
      'literary-calibration-development-v1',
      identity,
    );
    if (artifactHash != _string(json, 'artifactHash')) {
      throw const FormatException('calibration artifact hash mismatch');
    }
    return LiteraryQualityDevelopmentCalibrationArtifact._(
      corpusHash: corpus.corpusHash,
      uniqueItemCount: corpus.fixtures.length,
      metricStatus: metricStatus,
      humanAdjudicatedHardDecisions: hard,
      humanAdjudicatedNonHardDecisions: nonHard,
      formalCertificationEligible: formalEligible,
      limitation: _string(json, 'limitation'),
      artifactHash: artifactHash,
    );
  }
}

List<Map<String, Object?>> _readJsonLines(File file) {
  final values = <Map<String, Object?>>[];
  var lineNumber = 0;
  for (final rawLine in file.readAsLinesSync()) {
    lineNumber += 1;
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    values.add(_jsonObject(jsonDecode(line), '${file.path}:$lineNumber'));
  }
  return values;
}

Map<String, int> _counts(Iterable<String> values) {
  final result = <String, int>{};
  for (final value in values) {
    result[value] = (result[value] ?? 0) + 1;
  }
  return Map.unmodifiable(result);
}

Map<String, Object?> _jsonObject(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object');
  return value.map((key, item) {
    if (key is! String) throw FormatException('$path keys must be strings');
    return MapEntry(key, item);
  });
}

void _expectExactKeys(
  Map<String, Object?> json,
  String path,
  Set<String> expected,
) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    final missing = expected.difference(actual).toList()..sort();
    final unknown = actual.difference(expected).toList()..sort();
    throw FormatException(
      '$path schema mismatch; missing=$missing; unknown=$unknown',
    );
  }
}

void _expectIntMapEquals(
  Map<String, Object?> actual,
  Map<String, int> expected,
  String path,
) {
  if (actual.length != expected.length) {
    throw FormatException('$path key count mismatch');
  }
  for (final entry in expected.entries) {
    if (actual[entry.key] != entry.value) {
      throw FormatException('$path differs at ${entry.key}');
    }
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer');
  return value;
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be an array');
  final result = <String>[];
  final seen = <String>{};
  for (final item in value) {
    if (item is! String || item.trim().isEmpty || !seen.add(item)) {
      throw FormatException('$key must contain unique non-empty strings');
    }
    result.add(item);
  }
  return List.unmodifiable(result);
}

List<int> _intList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! int)) {
    throw FormatException('$key must contain integers');
  }
  return List.unmodifiable(value.cast<int>());
}
