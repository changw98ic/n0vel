/// Provider-free prompt linter for WP0 source-safety gates.
///
/// The linter is deliberately conservative: it can redact explicit protected
/// tokens from otherwise neutral text, but it does not claim that an author or
/// work style can be safely transformed into an abstract mechanism. When a
/// request asks to imitate, reproduce, continue, or launder a protected source,
/// callers should fail closed unless a trusted source ledger has already
/// established user/project ownership from the source ledger.
enum ImitationIntentDisposition { allowed, abstracted, rejected, manualReview }

enum ImitationIntentReasonCode {
  emptyInput,
  explicitImitationIntent,
  explicitContinuationIntent,
  explicitReproductionIntent,
  explicitStyleTarget,
  protectedCreatorToken,
  protectedTitleToken,
  unsafeProtectedTokenContext,
  ambiguousProtectedToken,
  userOwnedVoice,
}

enum ImitationSourceOwnership { unknown, thirdParty, userOwned, projectOwned }

class ImitationIntentLinterResult {
  const ImitationIntentLinterResult({
    required this.disposition,
    required this.reasonCodes,
    required this.sanitizedText,
    this.requiresHumanReview = false,
  });

  final ImitationIntentDisposition disposition;
  final List<ImitationIntentReasonCode> reasonCodes;
  final String sanitizedText;

  /// True when the result is not safe for automatic prompt rendering.
  final bool requiresHumanReview;

  bool get canRender =>
      !requiresHumanReview &&
      (disposition == ImitationIntentDisposition.allowed ||
          disposition == ImitationIntentDisposition.abstracted);
}

class StructuredImitationIntentInput {
  const StructuredImitationIntentInput({
    required this.text,
    this.creatorTokens = const <String>[],
    this.titleTokens = const <String>[],
    this.ownership = ImitationSourceOwnership.unknown,
    this.userOwnsVoice = false,
  });

  final String text;
  final Iterable<String> creatorTokens;
  final Iterable<String> titleTokens;
  final ImitationSourceOwnership ownership;

  /// Use only for explicit user/project-owned voice presets, not for
  /// third-party author/work references. Callers must prove this through the
  /// source ledger before setting the flag.
  final bool userOwnsVoice;
}

class SanitizedImitationFields {
  const SanitizedImitationFields({
    required this.fields,
    required this.result,
    this.droppedFieldKeys = const <String>[],
  });

  final Map<String, String> fields;
  final ImitationIntentLinterResult result;

  /// Fields removed wholesale because they contained protected source tokens
  /// without an explicit reproduction request. Deleting the whole field is the
  /// safe abstraction; replacing a raw protected token with a placeholder is
  /// not enough to make arbitrary raw text renderable.
  final List<String> droppedFieldKeys;
}

class ImitationIntentLinter {
  ImitationIntentLinter({
    Iterable<String> protectedCreatorTokens = const <String>[],
    Iterable<String> protectedTitleTokens = const <String>[],
  }) : _protectedCreatorTokens = _normalizeTokens(protectedCreatorTokens),
       _protectedTitleTokens = _normalizeTokens(protectedTitleTokens);

  final List<String> _protectedCreatorTokens;
  final List<String> _protectedTitleTokens;

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _imitationIntent = RegExp(
    r'(模仿|仿写|仿照|效仿|照着|写得像|像.+?(文风|笔法|叙事|句子|节奏)|'
    r'(copy|imitate|in\s+the\s+style\s+of|write\s+like|sound\s+like))',
    caseSensitive: false,
  );
  static final RegExp _continuationIntent = RegExp(
    r'(续写|接着写|延续.+?(原文|剧情|章节|作品)|同人续|'
    r'(continue|sequel|next\s+chapter))',
    caseSensitive: false,
  );
  static final RegExp _reproductionIntent = RegExp(
    r'(复刻|复现|还原|洗稿|改写原句|保留原句|套用原句|照搬|贴近原文|'
    r'(reproduce|plagiar|rewrite\s+the\s+original|verbatim))',
    caseSensitive: false,
  );
  static final RegExp _styleIntent = RegExp(
    r'(文风|风格|笔法|腔调|质感|句子节奏|叙事节奏|叙事口吻|'
    r'(style|voice|prose|cadence|rhythm))',
    caseSensitive: false,
  );
  static final RegExp _evasiveCraftTarget = RegExp(r'(气口|顿挫|句式骨架|句法骨架|行文骨架)');
  static final RegExp _evasiveSourceOrRewriteAction = RegExp(
    r'(那本书|那部书|那篇|原书|参考书|参考文本|参考原句|换同义词|同义词|'
    r'续一段|续上|继续写|保持同样)',
    caseSensitive: false,
  );
  static final RegExp _evasiveContinuationAction = RegExp(
    r'(续一段|续上|继续写|保持同样)',
    caseSensitive: false,
  );

  ImitationIntentLinterResult lint(String text) => lintStructured(
    StructuredImitationIntentInput(
      text: text,
      creatorTokens: _protectedCreatorTokens,
      titleTokens: _protectedTitleTokens,
    ),
  );

  ImitationIntentLinterResult lintStructured(
    StructuredImitationIntentInput input,
  ) {
    final normalizedText = _normalizeText(input.text);
    if (normalizedText.isEmpty) {
      return const ImitationIntentLinterResult(
        disposition: ImitationIntentDisposition.rejected,
        reasonCodes: <ImitationIntentReasonCode>[
          ImitationIntentReasonCode.emptyInput,
        ],
        sanitizedText: '',
        requiresHumanReview: true,
      );
    }

    final creatorTokens = _mergedTokens(
      _protectedCreatorTokens,
      input.creatorTokens,
    );
    final titleTokens = _mergedTokens(_protectedTitleTokens, input.titleTokens);
    final creatorHits = _tokensIn(normalizedText, creatorTokens);
    final titleHits = _tokensIn(normalizedText, titleTokens);
    final hasProtectedHits = creatorHits.isNotEmpty || titleHits.isNotEmpty;
    final reasons = <ImitationIntentReasonCode>[];

    if (_imitationIntent.hasMatch(normalizedText)) {
      reasons.add(ImitationIntentReasonCode.explicitImitationIntent);
    }
    if (_continuationIntent.hasMatch(normalizedText)) {
      reasons.add(ImitationIntentReasonCode.explicitContinuationIntent);
    }
    if (_reproductionIntent.hasMatch(normalizedText)) {
      reasons.add(ImitationIntentReasonCode.explicitReproductionIntent);
    }
    if (_styleIntent.hasMatch(normalizedText)) {
      reasons.add(ImitationIntentReasonCode.explicitStyleTarget);
    }
    if (_hasEvasiveStyleCopyIntent(normalizedText)) {
      reasons.add(ImitationIntentReasonCode.explicitReproductionIntent);
      if (_evasiveContinuationAction.hasMatch(normalizedText)) {
        reasons.add(ImitationIntentReasonCode.explicitContinuationIntent);
      }
    }
    if (creatorHits.isNotEmpty) {
      reasons.add(ImitationIntentReasonCode.protectedCreatorToken);
    }
    if (titleHits.isNotEmpty) {
      reasons.add(ImitationIntentReasonCode.protectedTitleToken);
    }

    final sanitized = _redactTokens(normalizedText, <String>[
      ...creatorHits,
      ...titleHits,
    ]);
    if (_isOwned(input)) {
      return ImitationIntentLinterResult(
        disposition: ImitationIntentDisposition.allowed,
        reasonCodes: _dedupe(<ImitationIntentReasonCode>[
          ImitationIntentReasonCode.userOwnedVoice,
          ...reasons,
        ]),
        // Ownership can authorize use, but prompt-bound fields still never
        // retain creator/title labels.
        sanitizedText: sanitized,
      );
    }
    if (hasProtectedHits && _hasUnsafeIntent(reasons)) {
      return ImitationIntentLinterResult(
        disposition: ImitationIntentDisposition.rejected,
        reasonCodes: _dedupe(<ImitationIntentReasonCode>[
          ...reasons,
          ImitationIntentReasonCode.unsafeProtectedTokenContext,
        ]),
        sanitizedText: sanitized,
        requiresHumanReview: true,
      );
    }

    if (!hasProtectedHits && _hasHighRiskIntent(reasons)) {
      return ImitationIntentLinterResult(
        disposition: ImitationIntentDisposition.manualReview,
        reasonCodes: _dedupe(reasons),
        sanitizedText: sanitized,
        requiresHumanReview: true,
      );
    }

    if (hasProtectedHits) {
      return ImitationIntentLinterResult(
        disposition: ImitationIntentDisposition.abstracted,
        reasonCodes: _dedupe(<ImitationIntentReasonCode>[
          ...reasons,
          ImitationIntentReasonCode.ambiguousProtectedToken,
        ]),
        sanitizedText: sanitized,
        requiresHumanReview: true,
      );
    }

    return ImitationIntentLinterResult(
      disposition: ImitationIntentDisposition.allowed,
      reasonCodes: _dedupe(reasons),
      sanitizedText: sanitized,
    );
  }

  SanitizedImitationFields sanitizeFields({
    required Map<String, String> fields,
    Iterable<String> creatorTokens = const <String>[],
    Iterable<String> titleTokens = const <String>[],
    ImitationSourceOwnership ownership = ImitationSourceOwnership.unknown,
    bool userOwnsVoice = false,
  }) {
    final sanitized = <String, String>{};
    final droppedFieldKeys = <String>[];
    final combinedReasons = <ImitationIntentReasonCode>[];
    var disposition = ImitationIntentDisposition.allowed;
    var requiresHumanReview = false;

    for (final entry in fields.entries) {
      final result = lintStructured(
        StructuredImitationIntentInput(
          text: entry.value,
          creatorTokens: creatorTokens,
          titleTokens: titleTokens,
          ownership: ownership,
          userOwnsVoice: userOwnsVoice,
        ),
      );
      if (result.disposition == ImitationIntentDisposition.abstracted) {
        sanitized[entry.key] = '';
        droppedFieldKeys.add(entry.key);
      } else {
        sanitized[entry.key] = result.sanitizedText;
      }
      combinedReasons.addAll(result.reasonCodes);
      final fieldRequiresReview =
          result.disposition != ImitationIntentDisposition.abstracted &&
          result.requiresHumanReview;
      requiresHumanReview = requiresHumanReview || fieldRequiresReview;
      disposition = _maxDisposition(disposition, result.disposition);
    }

    return SanitizedImitationFields(
      fields: Map<String, String>.unmodifiable(sanitized),
      result: ImitationIntentLinterResult(
        disposition: disposition,
        reasonCodes: _dedupe(combinedReasons),
        sanitizedText: sanitized.values.join('\n'),
        requiresHumanReview: requiresHumanReview,
      ),
      droppedFieldKeys: List<String>.unmodifiable(droppedFieldKeys),
    );
  }

  static bool _isOwned(StructuredImitationIntentInput input) =>
      input.userOwnsVoice ||
      input.ownership == ImitationSourceOwnership.userOwned ||
      input.ownership == ImitationSourceOwnership.projectOwned;

  static bool _hasEvasiveStyleCopyIntent(String text) =>
      _evasiveCraftTarget.hasMatch(text) &&
      _evasiveSourceOrRewriteAction.hasMatch(text);

  static bool _hasUnsafeIntent(Iterable<ImitationIntentReasonCode> reasons) =>
      reasons.contains(ImitationIntentReasonCode.explicitImitationIntent) ||
      reasons.contains(ImitationIntentReasonCode.explicitContinuationIntent) ||
      reasons.contains(ImitationIntentReasonCode.explicitReproductionIntent) ||
      reasons.contains(ImitationIntentReasonCode.explicitStyleTarget);

  static bool _hasHighRiskIntent(Iterable<ImitationIntentReasonCode> reasons) =>
      reasons.contains(ImitationIntentReasonCode.explicitContinuationIntent) ||
      reasons.contains(ImitationIntentReasonCode.explicitReproductionIntent);

  static ImitationIntentDisposition _maxDisposition(
    ImitationIntentDisposition left,
    ImitationIntentDisposition right,
  ) {
    const rank = <ImitationIntentDisposition, int>{
      ImitationIntentDisposition.allowed: 0,
      ImitationIntentDisposition.abstracted: 1,
      ImitationIntentDisposition.manualReview: 2,
      ImitationIntentDisposition.rejected: 3,
    };
    return rank[left]! >= rank[right]! ? left : right;
  }

  static List<String> _mergedTokens(
    Iterable<String> first,
    Iterable<String> second,
  ) => _normalizeTokens(<String>[...first, ...second]);

  static List<String> _normalizeTokens(Iterable<String> tokens) {
    final normalized = tokens
        .map(_normalizeText)
        .where((token) => token.length >= 2)
        .toSet()
        .toList(growable: false);
    normalized.sort((a, b) => b.length.compareTo(a.length));
    return normalized;
  }

  static List<String> _tokensIn(String text, Iterable<String> tokens) => tokens
      .where((token) => text.toLowerCase().contains(token.toLowerCase()))
      .toList(growable: false);

  static String _redactTokens(String text, Iterable<String> tokens) {
    var sanitized = text;
    for (final token in _normalizeTokens(tokens)) {
      sanitized = sanitized.replaceAll(
        RegExp(RegExp.escape(token), caseSensitive: false),
        '[受保护来源]',
      );
    }
    return sanitized;
  }

  static List<ImitationIntentReasonCode> _dedupe(
    Iterable<ImitationIntentReasonCode> values,
  ) => values.toSet().toList(growable: false);

  static String _normalizeText(String value) =>
      value.replaceAll(_whitespace, ' ').trim();
}
