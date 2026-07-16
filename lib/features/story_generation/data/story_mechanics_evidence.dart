import '../../../app/llm/app_llm_canonical_hash.dart';

/// Immutable evidence for deterministic story-world mechanics and repetition.
final class StoryMechanicsEvidence {
  StoryMechanicsEvidence({
    required this.verifierReleaseHash,
    required this.proseHash,
    required Iterable<String> powerLossSpanHashes,
    required Iterable<String> deviceActionSpanHashes,
    required Iterable<String> powerMechanismSpanHashes,
    required Iterable<String> unexplainedDeviceActionSpanHashes,
    required Iterable<String> coercionSpanHashes,
    required Iterable<String> powerInversionSpanHashes,
    required Iterable<String> authorityTransferSpanHashes,
    required Iterable<String> unearnedPowerInversionSpanHashes,
    required Map<String, int> repeatedMotifCounts,
    required Map<String, int> repeatedExplanationCounts,
    required this.dialogueChars,
    required this.analyticalDialogueChars,
    required this.analyticalDialogueRatioMicros,
    required Iterable<String> failureCodes,
  }) : powerLossSpanHashes = _sortedUnique(powerLossSpanHashes),
       deviceActionSpanHashes = _sortedUnique(deviceActionSpanHashes),
       powerMechanismSpanHashes = _sortedUnique(powerMechanismSpanHashes),
       unexplainedDeviceActionSpanHashes = _sortedUnique(
         unexplainedDeviceActionSpanHashes,
       ),
       coercionSpanHashes = _sortedUnique(coercionSpanHashes),
       powerInversionSpanHashes = _sortedUnique(powerInversionSpanHashes),
       authorityTransferSpanHashes = _sortedUnique(authorityTransferSpanHashes),
       unearnedPowerInversionSpanHashes = _sortedUnique(
         unearnedPowerInversionSpanHashes,
       ),
       repeatedMotifCounts = _sortedCounts(repeatedMotifCounts),
       repeatedExplanationCounts = _sortedCounts(repeatedExplanationCounts),
       failureCodes = List<String>.unmodifiable(
         failureCodes.toSet().toList()..sort(),
       ) {
    for (final value in <String>[verifierReleaseHash, proseHash]) {
      _requireDigest(value);
    }
    for (final values in <List<String>>[
      this.powerLossSpanHashes,
      this.deviceActionSpanHashes,
      this.powerMechanismSpanHashes,
      this.unexplainedDeviceActionSpanHashes,
      this.coercionSpanHashes,
      this.powerInversionSpanHashes,
      this.authorityTransferSpanHashes,
      this.unearnedPowerInversionSpanHashes,
      this.repeatedMotifCounts.keys.toList(),
      this.repeatedExplanationCounts.keys.toList(),
    ]) {
      for (final value in values) {
        _requireDigest(value);
      }
    }
    if (dialogueChars < 0 ||
        analyticalDialogueChars < 0 ||
        analyticalDialogueChars > dialogueChars ||
        analyticalDialogueRatioMicros < 0 ||
        analyticalDialogueRatioMicros > 1000000 ||
        (dialogueChars == 0
            ? analyticalDialogueRatioMicros != 0
            : analyticalDialogueRatioMicros !=
                  ((analyticalDialogueChars / dialogueChars) * 1000000)
                      .round())) {
      throw ArgumentError('analytical dialogue measurements are invalid');
    }
    if (!this.deviceActionSpanHashes.toSet().containsAll(
          this.unexplainedDeviceActionSpanHashes,
        ) ||
        !this.powerInversionSpanHashes.toSet().containsAll(
          this.unearnedPowerInversionSpanHashes,
        ) ||
        this.repeatedMotifCounts.values.any((count) => count < 3) ||
        this.repeatedExplanationCounts.values.any((count) => count < 2)) {
      throw ArgumentError('story mechanics derived evidence is inconsistent');
    }
    final expectedFailures = <String>{
      if (this.unexplainedDeviceActionSpanHashes.isNotEmpty)
        'quality.unpowered_device_action',
      if (this.unearnedPowerInversionSpanHashes.isNotEmpty)
        'quality.unearned_power_inversion',
      if (this.repeatedMotifCounts.isNotEmpty ||
          this.repeatedExplanationCounts.isNotEmpty)
        'quality.repetition_loop',
      if (dialogueChars >= 20 && analyticalDialogueRatioMicros >= 600000)
        'quality.expository_dialogue_density',
    };
    if (expectedFailures.length != this.failureCodes.length ||
        !expectedFailures.containsAll(this.failureCodes)) {
      throw ArgumentError('story mechanics failure codes are inconsistent');
    }
  }

  static const schemaVersion = 'story-mechanics-evidence-v1';

  final String verifierReleaseHash;
  final String proseHash;
  final List<String> powerLossSpanHashes;
  final List<String> deviceActionSpanHashes;
  final List<String> powerMechanismSpanHashes;
  final List<String> unexplainedDeviceActionSpanHashes;
  final List<String> coercionSpanHashes;
  final List<String> powerInversionSpanHashes;
  final List<String> authorityTransferSpanHashes;
  final List<String> unearnedPowerInversionSpanHashes;
  final Map<String, int> repeatedMotifCounts;
  final Map<String, int> repeatedExplanationCounts;
  final int dialogueChars;
  final int analyticalDialogueChars;
  final int analyticalDialogueRatioMicros;
  final List<String> failureCodes;

  bool get passed => failureCodes.isEmpty;

  String get evidenceHash => AppLlmCanonicalHash.domainHash(
    'story-mechanics-evidence-v1',
    _identityJson(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    ..._identityJson(),
    'evidenceHash': evidenceHash,
  };

  static StoryMechanicsEvidence fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('story mechanics evidence must be an object');
    }
    final value = <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
    const expectedKeys = <String>{
      'schemaVersion',
      'verifierReleaseHash',
      'proseHash',
      'powerLossSpanHashes',
      'deviceActionSpanHashes',
      'powerMechanismSpanHashes',
      'unexplainedDeviceActionSpanHashes',
      'coercionSpanHashes',
      'powerInversionSpanHashes',
      'authorityTransferSpanHashes',
      'unearnedPowerInversionSpanHashes',
      'repeatedMotifCounts',
      'repeatedExplanationCounts',
      'dialogueChars',
      'analyticalDialogueChars',
      'analyticalDialogueRatioMicros',
      'failureCodes',
      'passed',
      'evidenceHash',
    };
    final actualKeys = value.keys.toSet();
    if (value['schemaVersion'] != schemaVersion ||
        actualKeys.difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(actualKeys).isNotEmpty) {
      throw const FormatException('story mechanics schema is invalid');
    }
    final evidence = StoryMechanicsEvidence(
      verifierReleaseHash: value['verifierReleaseHash'] as String,
      proseHash: value['proseHash'] as String,
      powerLossSpanHashes: _strings(value['powerLossSpanHashes']),
      deviceActionSpanHashes: _strings(value['deviceActionSpanHashes']),
      powerMechanismSpanHashes: _strings(value['powerMechanismSpanHashes']),
      unexplainedDeviceActionSpanHashes: _strings(
        value['unexplainedDeviceActionSpanHashes'],
      ),
      coercionSpanHashes: _strings(value['coercionSpanHashes']),
      powerInversionSpanHashes: _strings(value['powerInversionSpanHashes']),
      authorityTransferSpanHashes: _strings(
        value['authorityTransferSpanHashes'],
      ),
      unearnedPowerInversionSpanHashes: _strings(
        value['unearnedPowerInversionSpanHashes'],
      ),
      repeatedMotifCounts: _counts(value['repeatedMotifCounts']),
      repeatedExplanationCounts: _counts(value['repeatedExplanationCounts']),
      dialogueChars: value['dialogueChars'] as int,
      analyticalDialogueChars: value['analyticalDialogueChars'] as int,
      analyticalDialogueRatioMicros:
          value['analyticalDialogueRatioMicros'] as int,
      failureCodes: _strings(value['failureCodes']),
    );
    if (value['passed'] != evidence.passed ||
        value['evidenceHash'] != evidence.evidenceHash) {
      throw const FormatException('story mechanics evidence hash is invalid');
    }
    return evidence;
  }

  Map<String, Object?> _identityJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'verifierReleaseHash': verifierReleaseHash,
    'proseHash': proseHash,
    'powerLossSpanHashes': powerLossSpanHashes,
    'deviceActionSpanHashes': deviceActionSpanHashes,
    'powerMechanismSpanHashes': powerMechanismSpanHashes,
    'unexplainedDeviceActionSpanHashes': unexplainedDeviceActionSpanHashes,
    'coercionSpanHashes': coercionSpanHashes,
    'powerInversionSpanHashes': powerInversionSpanHashes,
    'authorityTransferSpanHashes': authorityTransferSpanHashes,
    'unearnedPowerInversionSpanHashes': unearnedPowerInversionSpanHashes,
    'repeatedMotifCounts': repeatedMotifCounts,
    'repeatedExplanationCounts': repeatedExplanationCounts,
    'dialogueChars': dialogueChars,
    'analyticalDialogueChars': analyticalDialogueChars,
    'analyticalDialogueRatioMicros': analyticalDialogueRatioMicros,
    'failureCodes': failureCodes,
    'passed': passed,
  };
}

List<String> _sortedUnique(Iterable<String> source) =>
    List<String>.unmodifiable(source.toSet().toList()..sort());

Map<String, int> _sortedCounts(Map<String, int> source) {
  if (source.values.any((count) => count <= 0)) {
    throw ArgumentError('story mechanics repetition counts must be positive');
  }
  final keys = source.keys.toList()..sort();
  return Map<String, int>.unmodifiable({
    for (final key in keys) key: source[key]!,
  });
}

List<String> _strings(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('story mechanics string list is invalid');
  }
  return value.cast<String>();
}

Map<String, int> _counts(Object? value) {
  if (value is! Map ||
      value.keys.any((key) => key is! String) ||
      value.values.any((count) => count is! int)) {
    throw const FormatException('story mechanics count map is invalid');
  }
  return <String, int>{
    for (final entry in value.entries) entry.key as String: entry.value as int,
  };
}

void _requireDigest(String value) {
  if (!RegExp(r'^(?:sha256:)?[a-f0-9]{64}$').hasMatch(value)) {
    throw ArgumentError('story mechanics identity must be SHA-256');
  }
}
