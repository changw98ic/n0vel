import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';

import 'scene_pipeline_models.dart';

enum SceneTransitionStatus { passed, missed }

class SceneTransitionRequirement {
  SceneTransitionRequirement({
    required this.id,
    required this.description,
    required this.isRequired,
    List<String> matchTerms = const [],
  }) : matchTerms = List.unmodifiable([
         for (final term in matchTerms)
           if (term.trim().isNotEmpty) term.trim(),
       ]);

  final String id;
  final String description;
  final bool isRequired;
  final List<String> matchTerms;
}

class SceneTransitionCheck {
  SceneTransitionCheck({
    required this.requirement,
    required this.status,
    List<int> matchedBeatOrders = const [],
    List<String> evidence = const [],
  }) : matchedBeatOrders = List.unmodifiable(matchedBeatOrders),
       evidence = List.unmodifiable(evidence);

  final SceneTransitionRequirement requirement;
  final SceneTransitionStatus status;
  final List<int> matchedBeatOrders;
  final List<String> evidence;

  String get id => requirement.id;
  String get description => requirement.description;
  bool get isRequired => requirement.isRequired;
  bool get passed => status == SceneTransitionStatus.passed;
}

class SceneTransitionReport {
  SceneTransitionReport({List<SceneTransitionCheck> checks = const []})
    : checks = List.unmodifiable(checks);

  final List<SceneTransitionCheck> checks;

  List<SceneTransitionCheck> get requiredChecks => [
    for (final check in checks)
      if (check.isRequired) check,
  ];

  List<SceneTransitionCheck> get optionalChecks => [
    for (final check in checks)
      if (!check.isRequired) check,
  ];

  List<SceneTransitionCheck> get missingRequired => [
    for (final check in requiredChecks)
      if (!check.passed) check,
  ];

  List<SceneTransitionCheck> get missingOptional => [
    for (final check in optionalChecks)
      if (!check.passed) check,
  ];

  bool get hasMissedRequired => missingRequired.isNotEmpty;
  bool get allRequiredPassed => missingRequired.isEmpty;
  bool get allTransitionsPassed =>
      checks.every((check) => check.status == SceneTransitionStatus.passed);

  String get blockingReason {
    if (!hasMissedRequired) return '';
    return 'Missing required transitions: '
        '${missingRequired.map((check) => check.id).join(', ')}';
  }
}

/// Tracks the resolution status of a single state transition between scenes.
class TransitionStatus {
  const TransitionStatus({
    required this.transitionId,
    required this.fromSceneId,
    required this.toSceneId,
    required this.isResolved,
    this.resolvedValue,
  });

  final String transitionId;
  final String fromSceneId;
  final String toSceneId;
  final bool isResolved;
  final String? resolvedValue;

  TransitionStatus copyWith({
    String? transitionId,
    String? fromSceneId,
    String? toSceneId,
    bool? isResolved,
    String? resolvedValue,
  }) {
    return TransitionStatus(
      transitionId: transitionId ?? this.transitionId,
      fromSceneId: fromSceneId ?? this.fromSceneId,
      toSceneId: toSceneId ?? this.toSceneId,
      isResolved: isResolved ?? this.isResolved,
      resolvedValue: resolvedValue ?? this.resolvedValue,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'transitionId': transitionId,
      'fromSceneId': fromSceneId,
      'toSceneId': toSceneId,
      'isResolved': isResolved,
      if (resolvedValue != null) 'resolvedValue': resolvedValue,
    };
  }

  static TransitionStatus fromJson(Map<Object?, Object?> json) {
    return TransitionStatus(
      transitionId: json['transitionId']?.toString() ?? '',
      fromSceneId: json['fromSceneId']?.toString() ?? '',
      toSceneId: json['toSceneId']?.toString() ?? '',
      isResolved: json['isResolved'] == true,
      resolvedValue: json['resolvedValue']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransitionStatus) return false;
    return other.transitionId == transitionId &&
        other.fromSceneId == fromSceneId &&
        other.toSceneId == toSceneId &&
        other.isResolved == isResolved &&
        other.resolvedValue == resolvedValue;
  }

  @override
  int get hashCode => Object.hash(
    transitionId,
    fromSceneId,
    toSceneId,
    isResolved,
    resolvedValue,
  );
}

/// Tracks required transitions for a scene and reports which are resolved
/// versus pending.
class SceneTransitionTracker {
  /// Track required transitions for a scene.
  ///
  /// Returns a map of [transitionId] to [TransitionStatus] indicating which
  /// transitions are resolved vs pending, based on the provided
  /// [resolvedValues] mapping.
  Map<String, TransitionStatus> trackTransitions({
    required List<StateTransitionTarget> targets,
    required Map<String, String> resolvedValues,
  }) {
    return {
      for (final target in targets)
        target.id: TransitionStatus(
          transitionId: target.id,
          fromSceneId: target.fromSceneId,
          toSceneId: target.toSceneId,
          isResolved: resolvedValues.containsKey(target.id),
          resolvedValue: resolvedValues[target.id],
        ),
    };
  }

  /// Check if all required transitions are resolved.
  ///
  /// A transition is considered resolved when [TransitionStatus.isResolved]
  /// is true. Returns true only when every status in [statuses] is resolved.
  bool allRequiredResolved(List<TransitionStatus> statuses) {
    return statuses.every((status) => status.isResolved);
  }
}

// ---------------------------------------------------------------------------
// Transition requirement parsing helpers
// ---------------------------------------------------------------------------

/// Parse mixed-metadata transition requirements from raw metadata maps.
List<SceneTransitionRequirement> requirementsFromMixedMetadata(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        _requirementFromMap(
          item,
          isRequired:
              _boolFromRaw(item['required']) ??
              !_isOptionalRaw(item['optional']),
        )
      else
        _requirementFromRaw(item, isRequired: true),
  ].whereType<SceneTransitionRequirement>().toList(growable: false);
}

/// Parse a list of transition requirements from raw metadata.
List<SceneTransitionRequirement> requirementsFromMetadata(
  Object? raw, {
  required bool isRequired,
}) {
  if (raw is! List) return const [];
  return [
    for (final item in raw) _requirementFromRaw(item, isRequired: isRequired),
  ].whereType<SceneTransitionRequirement>().toList(growable: false);
}

/// Check a single transition requirement against resolved beats.
SceneTransitionCheck checkTransition(
  SceneTransitionRequirement requirement,
  List<SceneBeat> resolvedBeats,
) {
  final terms = requirement.matchTerms.isEmpty
      ? [requirement.description, requirement.id]
      : requirement.matchTerms;
  final matchedOrders = <int>[];
  final evidence = <String>[];

  for (final beat in resolvedBeats) {
    if (matchesAnyTerm(beat.content, terms)) {
      matchedOrders.add(beat.order);
      evidence.add(beat.content);
    }
  }

  return SceneTransitionCheck(
    requirement: requirement,
    status: matchedOrders.isEmpty
        ? SceneTransitionStatus.missed
        : SceneTransitionStatus.passed,
    matchedBeatOrders: matchedOrders,
    evidence: evidence,
  );
}

/// Check if [content] contains any of the given [terms] (case-insensitive).
bool matchesAnyTerm(String content, List<String> terms) {
  final normalizedContent = content.toLowerCase();
  for (final term in terms) {
    final normalizedTerm = term.trim().toLowerCase();
    if (normalizedTerm.isNotEmpty &&
        normalizedContent.contains(normalizedTerm)) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

SceneTransitionRequirement? _requirementFromRaw(
  Object? raw, {
  required bool isRequired,
}) {
  if (raw is Map) {
    return _requirementFromMap(raw, isRequired: isRequired);
  }
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  return SceneTransitionRequirement(
    id: value,
    description: value,
    isRequired: isRequired,
    matchTerms: [value],
  );
}

SceneTransitionRequirement? _requirementFromMap(
  Map<Object?, Object?> raw, {
  required bool isRequired,
}) {
  final id =
      _stringFromRaw(raw['id']) ??
      _stringFromRaw(raw['transitionId']) ??
      _stringFromRaw(raw['targetId']);
  final description =
      _stringFromRaw(raw['description']) ??
      _stringFromRaw(raw['summary']) ??
      _stringFromRaw(raw['label']) ??
      id;
  if (id == null || description == null) return null;

  return SceneTransitionRequirement(
    id: id,
    description: description,
    isRequired: isRequired,
    matchTerms: [
      ..._stringListFromRaw(raw['match']),
      ..._stringListFromRaw(raw['matches']),
      ..._stringListFromRaw(raw['matchTerms']),
      ..._stringListFromRaw(raw['aliases']),
    ],
  );
}

String? _stringFromRaw(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  return value.isEmpty ? null : value;
}

List<String> _stringListFromRaw(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (_stringFromRaw(item) != null) _stringFromRaw(item)!,
    ];
  }
  final value = _stringFromRaw(raw);
  return value == null ? const [] : [value];
}

bool? _boolFromRaw(Object? raw) {
  if (raw is bool) return raw;
  final value = raw?.toString().trim().toLowerCase();
  return switch (value) {
    'true' || 'yes' || 'required' => true,
    'false' || 'no' || 'optional' => false,
    _ => null,
  };
}

bool _isOptionalRaw(Object? raw) => _boolFromRaw(raw) == true;
