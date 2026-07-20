/// Provider-free WP0 gate for near-reproduction risk.
///
/// This is a product safety gate, not a legal conclusion. It reports only
/// source identifiers, hashes, and numeric metrics; it must not echo compared
/// third-party text back into prompts, logs, or UI.
enum NearReproductionDisposition { allowed, manualReview, blocked }

enum NearReproductionReasonCode {
  noThirdPartyReferences,
  longestCjkMatchBlocker,
  longestCjkMatchReview,
  normalizedEightGramContainmentReview,
}

enum ReferenceOwnershipKind { thirdParty, userOwned, projectOwned }

class NearReproductionReference {
  const NearReproductionReference({
    required this.sourceId,
    required this.sourceHash,
    required this.text,
    this.ownership = ReferenceOwnershipKind.thirdParty,
  });

  final String sourceId;
  final String sourceHash;
  final String text;
  final ReferenceOwnershipKind ownership;
}

class NearReproductionSourceMetric {
  const NearReproductionSourceMetric({
    required this.sourceId,
    required this.sourceHash,
    required this.longestCommonCjkRun,
    required this.normalizedEightGramContainment,
  });

  final String sourceId;
  final String sourceHash;
  final int longestCommonCjkRun;

  /// Candidate 8-grams contained in the reference, range 0.0..1.0.
  final double normalizedEightGramContainment;

  Map<String, Object?> toJson() => <String, Object?>{
    'sourceId': sourceId,
    'sourceHash': sourceHash,
    'longestCommonCjkRun': longestCommonCjkRun,
    'normalizedEightGramContainment': normalizedEightGramContainment,
  };
}

class NearReproductionRiskResult {
  const NearReproductionRiskResult({
    required this.version,
    required this.disposition,
    required this.reasonCodes,
    required this.metrics,
  });

  final String version;
  final NearReproductionDisposition disposition;
  final List<NearReproductionReasonCode> reasonCodes;
  final List<NearReproductionSourceMetric> metrics;

  bool get canRelease => disposition == NearReproductionDisposition.allowed;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'disposition': disposition.name,
    'reasonCodes': reasonCodes.map((reason) => reason.name).toList(),
    'metrics': metrics.map((metric) => metric.toJson()).toList(),
  };
}

class NearReproductionRiskPolicy {
  const NearReproductionRiskPolicy({
    this.version = 'near-reproduction-risk-v1',
    this.blockCjkRunChars = 40,
    this.reviewCjkRunChars = 24,
    this.reviewEightGramContainment = 0.20,
    this.allowlistedPhrases = _defaultAllowlistedPhrases,
  }) : assert(blockCjkRunChars >= 1),
       assert(reviewCjkRunChars >= 1),
       assert(blockCjkRunChars >= reviewCjkRunChars),
       assert(
         reviewEightGramContainment > 0 && reviewEightGramContainment <= 1,
       );

  static const List<String> _defaultAllowlistedPhrases = <String>[
    '与此同时',
    '电光火石之间',
    '说时迟那时快',
    '一时之间',
    '下一刻',
    '深吸一口气',
    '不知为何',
    '换句话说',
  ];

  final String version;
  final int blockCjkRunChars;
  final int reviewCjkRunChars;
  final double reviewEightGramContainment;
  final Iterable<String> allowlistedPhrases;

  NearReproductionRiskResult evaluate({
    required String candidateText,
    required Iterable<NearReproductionReference> references,
  }) {
    final thirdPartyReferences = references
        .where(
          (reference) =>
              reference.ownership == ReferenceOwnershipKind.thirdParty,
        )
        .toList(growable: false);
    if (thirdPartyReferences.isEmpty) {
      return NearReproductionRiskResult(
        version: version,
        disposition: NearReproductionDisposition.allowed,
        reasonCodes: const <NearReproductionReasonCode>[
          NearReproductionReasonCode.noThirdPartyReferences,
        ],
        metrics: const <NearReproductionSourceMetric>[],
      );
    }

    final reducedCandidateText = _removeAllowlistedPhrases(candidateText);
    final candidateNormalized = _normalizeForContainment(reducedCandidateText);
    final candidateCjk = _normalizeCjkOnly(reducedCandidateText);
    final candidateEightGrams = _eightGrams(candidateNormalized);
    final metrics = <NearReproductionSourceMetric>[];
    final reasons = <NearReproductionReasonCode>{};
    var disposition = NearReproductionDisposition.allowed;

    for (final reference in thirdPartyReferences) {
      final referenceText = _removeAllowlistedPhrases(reference.text);
      final referenceNormalized = _normalizeForContainment(referenceText);
      final referenceCjk = _normalizeCjkOnly(referenceText);
      final longestCjkRun = _longestCommonSubstringLength(
        candidateCjk,
        referenceCjk,
      );
      final containment = _containment(
        candidateEightGrams,
        _eightGrams(referenceNormalized),
      );
      metrics.add(
        NearReproductionSourceMetric(
          sourceId: reference.sourceId,
          sourceHash: reference.sourceHash,
          longestCommonCjkRun: longestCjkRun,
          normalizedEightGramContainment: containment,
        ),
      );

      if (longestCjkRun >= blockCjkRunChars) {
        disposition = NearReproductionDisposition.blocked;
        reasons.add(NearReproductionReasonCode.longestCjkMatchBlocker);
      } else if (longestCjkRun >= reviewCjkRunChars) {
        if (disposition != NearReproductionDisposition.blocked) {
          disposition = NearReproductionDisposition.manualReview;
        }
        reasons.add(NearReproductionReasonCode.longestCjkMatchReview);
      }
      if (containment >= reviewEightGramContainment) {
        if (disposition != NearReproductionDisposition.blocked) {
          disposition = NearReproductionDisposition.manualReview;
        }
        reasons.add(
          NearReproductionReasonCode.normalizedEightGramContainmentReview,
        );
      }
    }

    return NearReproductionRiskResult(
      version: version,
      disposition: disposition,
      reasonCodes: reasons.toList(growable: false),
      metrics: List<NearReproductionSourceMetric>.unmodifiable(metrics),
    );
  }

  String _removeAllowlistedPhrases(String value) {
    var result = value;
    for (final phrase in allowlistedPhrases) {
      if (phrase.trim().isEmpty) continue;
      result = result.replaceAll(phrase, '');
    }
    return result;
  }

  static String _normalizeForContainment(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (_isCjk(rune) || _isAsciiLetterOrDigit(rune)) {
        buffer.write(String.fromCharCode(rune).toLowerCase());
      }
    }
    return buffer.toString();
  }

  static String _normalizeCjkOnly(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (_isCjk(rune)) buffer.write(String.fromCharCode(rune));
    }
    return buffer.toString();
  }

  static Set<String> _eightGrams(String value) {
    if (value.length < 8) return const <String>{};
    final grams = <String>{};
    for (var index = 0; index <= value.length - 8; index += 1) {
      grams.add(value.substring(index, index + 8));
    }
    return grams;
  }

  static double _containment(Set<String> candidate, Set<String> reference) {
    if (candidate.isEmpty || reference.isEmpty) return 0;
    var hits = 0;
    for (final gram in candidate) {
      if (reference.contains(gram)) hits += 1;
    }
    return hits / candidate.length;
  }

  /// Longest common substring length using two rolling DP rows.
  ///
  /// Complexity is O(candidateCjk.length * referenceCjk.length) time and
  /// O(referenceCjk.length) memory. Inputs are expected to be admitted
  /// reference excerpts or chunks, not full corpora.
  static int _longestCommonSubstringLength(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    var previous = List<int>.filled(right.length + 1, 0);
    var best = 0;
    for (var leftIndex = 1; leftIndex <= left.length; leftIndex += 1) {
      final current = List<int>.filled(right.length + 1, 0);
      for (var rightIndex = 1; rightIndex <= right.length; rightIndex += 1) {
        if (left.codeUnitAt(leftIndex - 1) ==
            right.codeUnitAt(rightIndex - 1)) {
          final value = previous[rightIndex - 1] + 1;
          current[rightIndex] = value;
          if (value > best) best = value;
        }
      }
      previous = current;
    }
    return best;
  }

  static bool _isAsciiLetterOrDigit(int rune) =>
      (rune >= 0x30 && rune <= 0x39) ||
      (rune >= 0x41 && rune <= 0x5a) ||
      (rune >= 0x61 && rune <= 0x7a);

  static bool _isCjk(int rune) =>
      (rune >= 0x3400 && rune <= 0x4dbf) ||
      (rune >= 0x4e00 && rune <= 0x9fff) ||
      (rune >= 0xf900 && rune <= 0xfaff);
}
