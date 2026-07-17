/// How a character typically makes decisions.
enum DecisionPattern { principled, emotional, strategic, impulsive }

/// A violation of a character's soul contract.
class SoulViolation {
  const SoulViolation({
    required this.rule,
    required this.description,
    this.severity = 1.0,
  });

  final String rule;
  final String description;
  final double severity;

  @override
  String toString() => 'SoulViolation($rule: $description, severity=$severity)';
}

/// The immutable soul of a character — values, boundaries, and identity.
///
/// A [SoulContract] defines what a character will and will not do. It is
/// checked at every decision point in the pipeline to ensure the character
/// acts consistently with their established nature.
class SoulContract {
  const SoulContract({
    this.coreValues = const [],
    this.forbiddenActions = const [],
    this.emotionalRange = const EmotionalContract(),
    this.decisionPattern = DecisionPattern.principled,
    this.unbreakablePromises = const [],
    this.identityAnchors = const [],
  });

  /// Core values the character holds — actions opposing these trigger violations.
  final List<String> coreValues;

  /// Actions the character will never take (exact + substring match).
  final List<String> forbiddenActions;

  /// Emotional range constraints.
  final EmotionalContract emotionalRange;

  /// Default decision-making pattern.
  final DecisionPattern decisionPattern;

  /// Promises the character will never break.
  final List<String> unbreakablePromises;

  /// Identity anchors — phrases that define who this character is.
  final List<String> identityAnchors;

  /// Validate a [proposedAction] against this soul contract.
  ///
  /// Returns a list of violations. An empty list means the action is valid.
  List<SoulViolation> validate(
    String proposedAction, {
    Map<String, Object?> context = const {},
  }) {
    final violations = <SoulViolation>[];

    // 1. Check forbidden actions (exact + substring).
    for (final forbidden in forbiddenActions) {
      if (proposedAction.contains(forbidden)) {
        violations.add(
          SoulViolation(
            rule: 'forbidden:$forbidden',
            description:
                'Action "$proposedAction" matches forbidden "$forbidden"',
            severity: 1.0,
          ),
        );
      }
    }

    // 2. Check core value anti-patterns.
    // An action that directly contradicts a core value is a violation.
    for (final value in coreValues) {
      final antiPattern = '不$value';
      if (proposedAction.contains(antiPattern)) {
        violations.add(
          SoulViolation(
            rule: 'coreValue:$value',
            description: 'Action contradicts core value "$value"',
            severity: 0.8,
          ),
        );
      }
    }

    // 3. Check emotional range bounds.
    if (emotionalRange.forbiddenEmotions.isNotEmpty) {
      for (final emotion in emotionalRange.forbiddenEmotions) {
        if (proposedAction.contains(emotion)) {
          violations.add(
            SoulViolation(
              rule: 'emotion:$emotion',
              description: 'Action expresses forbidden emotion "$emotion"',
              severity: 0.6,
            ),
          );
        }
      }
    }

    // 4. Check unbreakable promises.
    for (final promise in unbreakablePromises) {
      final breakPattern = '违背$promise';
      if (proposedAction.contains(breakPattern)) {
        violations.add(
          SoulViolation(
            rule: 'promise:$promise',
            description: 'Action breaks promise "$promise"',
            severity: 1.0,
          ),
        );
      }
    }

    return violations;
  }

  Map<String, Object?> toJson() => {
    'coreValues': coreValues,
    'forbiddenActions': forbiddenActions,
    'emotionalRange': emotionalRange.toJson(),
    'decisionPattern': decisionPattern.name,
    'unbreakablePromises': unbreakablePromises,
    'identityAnchors': identityAnchors,
  };

  factory SoulContract.fromJson(Map<String, Object?> json) {
    return SoulContract(
      coreValues: _asStringList(json['coreValues']),
      forbiddenActions: _asStringList(json['forbiddenActions']),
      emotionalRange: EmotionalContract.fromJson(
        _asMap(json['emotionalRange']),
      ),
      decisionPattern: _parseDecisionPattern(json['decisionPattern']),
      unbreakablePromises: _asStringList(json['unbreakablePromises']),
      identityAnchors: _asStringList(json['identityAnchors']),
    );
  }
}

/// Emotional constraints for a soul contract.
class EmotionalContract {
  const EmotionalContract({
    this.maxIntensity = 1.0,
    this.forbiddenEmotions = const [],
    this.defaultState = 'neutral',
  });

  final double maxIntensity;
  final List<String> forbiddenEmotions;
  final String defaultState;

  Map<String, Object?> toJson() => {
    'maxIntensity': maxIntensity,
    'forbiddenEmotions': forbiddenEmotions,
    'defaultState': defaultState,
  };

  factory EmotionalContract.fromJson(Map<String, Object?> json) {
    return EmotionalContract(
      maxIntensity: _asDouble(json['maxIntensity']),
      forbiddenEmotions: _asStringList(json['forbiddenEmotions']),
      defaultState: json['defaultState']?.toString() ?? 'neutral',
    );
  }
}

// -- Parse helpers ------------------------------------------------------------

Map<String, Object?> _asMap(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  if (raw is Map) return Map<String, Object?>.from(raw);
  return const {};
}

List<String> _asStringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null) item.toString(),
  ];
}

double _asDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 1.0;
}

final _decisionPatternByName = {
  for (final v in DecisionPattern.values) v.name: v,
};

DecisionPattern _parseDecisionPattern(Object? raw) {
  return _decisionPatternByName[raw?.toString()] ?? DecisionPattern.principled;
}
