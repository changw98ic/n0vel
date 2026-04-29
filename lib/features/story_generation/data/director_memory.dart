import 'package:novel_writer/app/state/app_storage_clone.dart';
import 'story_generation_models.dart';

// -- Director Cue Models (Task 10) -------------------------------------------

/// A structured instruction that the director emits for scene generation.
class DirectorCue {
  DirectorCue({
    required this.id,
    required this.sceneId,
    required this.label,
    this.goal = '',
    double pressure = 0.0,
    this.pacing = '',
    List<String> beatGuidance = const [],
    this.exitCondition = '',
    this.cueBudget = 3,
    Map<String, Object?> metadata = const {},
  }) : pressure = pressure.clamp(0.0, 1.0),
       beatGuidance = immutableList(beatGuidance),
       metadata = immutableMap(metadata);

  final String id;
  final String sceneId;
  final String label;
  final String goal;
  final double pressure;
  final String pacing;
  final List<String> beatGuidance;
  final String exitCondition;
  final int cueBudget;
  final Map<String, Object?> metadata;

  DirectorCue copyWith({
    String? id,
    String? sceneId,
    String? label,
    String? goal,
    double? pressure,
    String? pacing,
    List<String>? beatGuidance,
    String? exitCondition,
    int? cueBudget,
    Map<String, Object?>? metadata,
  }) {
    return DirectorCue(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      label: label ?? this.label,
      goal: goal ?? this.goal,
      pressure: pressure ?? this.pressure,
      pacing: pacing ?? this.pacing,
      beatGuidance: beatGuidance ?? this.beatGuidance,
      exitCondition: exitCondition ?? this.exitCondition,
      cueBudget: cueBudget ?? this.cueBudget,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'label': label,
      'goal': goal,
      'pressure': pressure,
      'pacing': pacing,
      'beatGuidance': beatGuidance,
      'exitCondition': exitCondition,
      'cueBudget': cueBudget,
      'metadata': metadata,
    };
  }

  static DirectorCue fromJson(Map<Object?, Object?> json) {
    return DirectorCue(
      id: json['id']?.toString() ?? '',
      sceneId: json['sceneId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      goal: json['goal']?.toString() ?? '',
      pressure: _parseClampedDouble(json['pressure'], fallback: 0.0),
      pacing: json['pacing']?.toString() ?? '',
      beatGuidance: json['beatGuidance'] is List
          ? List<String>.from(
              (json['beatGuidance'] as List).map((e) => e?.toString() ?? ''),
            )
          : const [],
      exitCondition: json['exitCondition']?.toString() ?? '',
      cueBudget: _parseIntOrFallback(json['cueBudget'], fallback: 3),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectorCue &&
        other.id == id &&
        other.sceneId == sceneId &&
        other.label == label &&
        other.goal == goal &&
        other.pressure == pressure &&
        other.pacing == pacing &&
        _listEquals(other.beatGuidance, beatGuidance) &&
        other.exitCondition == exitCondition &&
        other.cueBudget == cueBudget &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    sceneId,
    label,
    goal,
    pressure,
    pacing,
    Object.hashAll(beatGuidance),
    exitCondition,
    cueBudget,
    Object.hashAllUnordered(metadata.entries),
  );

  String toPromptText() {
    final parts = <String>[
      '指令[$label]: $goal',
      if (pacing.isNotEmpty) '节奏: $pacing',
      if (pressure > 0) '张力: ${(pressure * 100).round()}%',
      if (beatGuidance.isNotEmpty) '拍点指引: ${beatGuidance.join(' → ')}',
      if (exitCondition.isNotEmpty) '退出条件: $exitCondition',
    ];
    return parts.join('\n');
  }
}

/// A task card summarizing the director's plan for a scene round.
class DirectorTaskCard {
  DirectorTaskCard({
    required this.sceneId,
    required this.sceneTitle,
    required this.objective,
    double pressure = 0.5,
    this.pacing = '',
    this.cueBudget = 3,
    List<DirectorCue> cues = const [],
    this.exitCondition = '',
    Map<String, Object?> metadata = const {},
  }) : pressure = pressure.clamp(0.0, 1.0),
       cues = immutableList(cues),
       metadata = immutableMap(metadata);

  final String sceneId;
  final String sceneTitle;
  final String objective;
  final double pressure;
  final String pacing;
  final int cueBudget;
  final List<DirectorCue> cues;
  final String exitCondition;
  final Map<String, Object?> metadata;

  DirectorTaskCard copyWith({
    String? sceneId,
    String? sceneTitle,
    String? objective,
    double? pressure,
    String? pacing,
    int? cueBudget,
    List<DirectorCue>? cues,
    String? exitCondition,
    Map<String, Object?>? metadata,
  }) {
    return DirectorTaskCard(
      sceneId: sceneId ?? this.sceneId,
      sceneTitle: sceneTitle ?? this.sceneTitle,
      objective: objective ?? this.objective,
      pressure: pressure ?? this.pressure,
      pacing: pacing ?? this.pacing,
      cueBudget: cueBudget ?? this.cueBudget,
      cues: cues ?? this.cues,
      exitCondition: exitCondition ?? this.exitCondition,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sceneId': sceneId,
      'sceneTitle': sceneTitle,
      'objective': objective,
      'pressure': pressure,
      'pacing': pacing,
      'cueBudget': cueBudget,
      'cues': [for (final c in cues) c.toJson()],
      'exitCondition': exitCondition,
      'metadata': metadata,
    };
  }

  static DirectorTaskCard fromJson(Map<Object?, Object?> json) {
    return DirectorTaskCard(
      sceneId: json['sceneId']?.toString() ?? '',
      sceneTitle: json['sceneTitle']?.toString() ?? '',
      objective: json['objective']?.toString() ?? '',
      pressure: _parseClampedDouble(json['pressure'], fallback: 0.5),
      pacing: json['pacing']?.toString() ?? '',
      cueBudget: _parseIntOrFallback(json['cueBudget'], fallback: 3),
      cues: json['cues'] is List
          ? [
              for (final item in json['cues'] as List)
                if (item is Map)
                  DirectorCue.fromJson(Map<Object?, Object?>.from(item)),
            ]
          : const [],
      exitCondition: json['exitCondition']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectorTaskCard &&
        other.sceneId == sceneId &&
        other.sceneTitle == sceneTitle &&
        other.objective == objective &&
        other.pressure == pressure &&
        other.pacing == pacing &&
        other.cueBudget == cueBudget &&
        _listEquals(other.cues, cues) &&
        other.exitCondition == exitCondition &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    sceneId,
    sceneTitle,
    objective,
    pressure,
    pacing,
    cueBudget,
    Object.hashAll(cues),
    exitCondition,
    Object.hashAllUnordered(metadata.entries),
  );
}

/// Tracks director round state for a scene generation pass.
class DirectorRoundState {
  DirectorRoundState({
    required this.sceneId,
    this.round = 0,
    this.maxRounds = 3,
    this.taskCard,
    List<DirectorCue> appliedCues = const [],
    this.outcome = '',
    Map<String, Object?> metadata = const {},
  }) : appliedCues = immutableList(appliedCues),
       metadata = immutableMap(metadata);

  final String sceneId;
  final int round;
  final int maxRounds;
  final DirectorTaskCard? taskCard;
  final List<DirectorCue> appliedCues;
  final String outcome;
  final Map<String, Object?> metadata;

  bool get isExhausted => round >= maxRounds;
  bool get hasTaskCard => taskCard != null;

  DirectorRoundState copyWith({
    String? sceneId,
    int? round,
    int? maxRounds,
    DirectorTaskCard? taskCard,
    List<DirectorCue>? appliedCues,
    String? outcome,
    Map<String, Object?>? metadata,
  }) {
    return DirectorRoundState(
      sceneId: sceneId ?? this.sceneId,
      round: round ?? this.round,
      maxRounds: maxRounds ?? this.maxRounds,
      taskCard: taskCard ?? this.taskCard,
      appliedCues: appliedCues ?? this.appliedCues,
      outcome: outcome ?? this.outcome,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'sceneId': sceneId,
      'round': round,
      'maxRounds': maxRounds,
      'taskCard': taskCard?.toJson(),
      'appliedCues': [for (final c in appliedCues) c.toJson()],
      'outcome': outcome,
      'metadata': metadata,
    };
  }

  static DirectorRoundState fromJson(Map<Object?, Object?> json) {
    return DirectorRoundState(
      sceneId: json['sceneId']?.toString() ?? '',
      round: _parseIntOrFallback(json['round'], fallback: 0),
      maxRounds: _parseIntOrFallback(json['maxRounds'], fallback: 3),
      taskCard: json['taskCard'] is Map
          ? DirectorTaskCard.fromJson(
              Map<Object?, Object?>.from(json['taskCard'] as Map),
            )
          : null,
      appliedCues: json['appliedCues'] is List
          ? [
              for (final item in json['appliedCues'] as List)
                if (item is Map)
                  DirectorCue.fromJson(Map<Object?, Object?>.from(item)),
            ]
          : const [],
      outcome: json['outcome']?.toString() ?? '',
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DirectorRoundState &&
        other.sceneId == sceneId &&
        other.round == round &&
        other.maxRounds == maxRounds &&
        other.taskCard == taskCard &&
        _listEquals(other.appliedCues, appliedCues) &&
        other.outcome == outcome &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    sceneId,
    round,
    maxRounds,
    taskCard,
    Object.hashAll(appliedCues),
    outcome,
    Object.hashAllUnordered(metadata.entries),
  );
}

// -- Helpers for director cue models -----------------------------------------

double _parseClampedDouble(Object? raw, {required double fallback}) {
  final parsed = double.tryParse(raw?.toString() ?? '');
  if (parsed == null) return fallback;
  return parsed.clamp(0.0, 1.0);
}

int _parseIntOrFallback(Object? raw, {required int fallback}) {
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

class SceneReviewDigest {
  SceneReviewDigest({
    required this.sceneId,
    required this.decision,
    List<String> issues = const [],
    List<String> strengths = const [],
    this.proseAttempts = 1,
  }) : issues = immutableList(issues),
       strengths = immutableList(strengths);

  final String sceneId;
  final SceneReviewDecision decision;
  final List<String> issues;
  final List<String> strengths;
  final int proseAttempts;
}

class DirectorMemory {
  DirectorMemory({
    List<SceneReviewDigest> recentReviews = const [],
    List<String> learnedConstraints = const [],
    this.strategyAdjustment = '',
    this.activeRoundState,
  }) : recentReviews = immutableList(recentReviews),
       learnedConstraints = immutableList(learnedConstraints);

  final List<SceneReviewDigest> recentReviews;
  final List<String> learnedConstraints;
  final String strategyAdjustment;
  final DirectorRoundState? activeRoundState;

  DirectorMemory withActiveRoundState(DirectorRoundState? roundState) {
    return DirectorMemory(
      recentReviews: recentReviews,
      learnedConstraints: learnedConstraints,
      strategyAdjustment: strategyAdjustment,
      activeRoundState: roundState,
    );
  }

  DirectorMemory incorporate(SceneReviewDigest digest) {
    final updatedReviews = [digest, ...recentReviews.take(7)];
    final newConstraints = <String>[...learnedConstraints];
    for (final issue in digest.issues) {
      final constraint = _issueToConstraintOrNull(issue);
      if (constraint != null &&
          !newConstraints.contains(constraint) &&
          newConstraints.length < 20) {
        newConstraints.add(constraint);
      }
    }
    return DirectorMemory(
      recentReviews: updatedReviews,
      learnedConstraints: newConstraints,
      strategyAdjustment: _deriveStrategy(updatedReviews),
      activeRoundState: activeRoundState,
    );
  }

  String toPromptText() {
    final parts = <String>[];

    // Include active round cue metadata if present
    if (activeRoundState != null) {
      final round = activeRoundState!;
      parts.add('导演轮次: ${round.round}/${round.maxRounds}');
      if (round.taskCard != null) {
        final card = round.taskCard!;
        parts.add('场景任务: ${card.objective}');
        if (card.pacing.isNotEmpty) parts.add('节奏: ${card.pacing}');
        if (card.exitCondition.isNotEmpty) {
          parts.add('退出条件: ${card.exitCondition}');
        }
      }
      for (final cue in round.appliedCues) {
        parts.add(cue.toPromptText());
      }
    }

    if (recentReviews.isEmpty && parts.isEmpty) return '';
    final recentFailures = recentReviews
        .where((r) => r.decision != SceneReviewDecision.pass)
        .toList(growable: false);
    if (recentFailures.isNotEmpty) {
      parts.add(
        '历史教训：${recentFailures.take(3).map((r) => '${r.sceneId}遇到${r.issues.take(2).join("和")}').join('；')}',
      );
    }
    if (learnedConstraints.isNotEmpty) {
      parts.add('额外约束：${learnedConstraints.take(5).join('；')}');
    }
    if (strategyAdjustment.isNotEmpty) {
      parts.add('策略调整：$strategyAdjustment');
    }
    return parts.join('\n');
  }

  String _issueToConstraint(String issue) {
    final trimmed = issue.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.length > 40) return '${trimmed.substring(0, 37)}...';
    return trimmed;
  }

  String? _issueToConstraintOrNull(String issue) {
    final result = _issueToConstraint(issue);
    return result.isEmpty ? null : result;
  }

  String _deriveStrategy(List<SceneReviewDigest> reviews) {
    if (reviews.isEmpty) return '';
    final recent = reviews.take(5).toList(growable: false);
    final rewriteCount = recent
        .where((r) => r.decision == SceneReviewDecision.rewriteProse)
        .length;
    final replanCount = recent
        .where((r) => r.decision == SceneReviewDecision.replanScene)
        .length;
    if (replanCount >= 2) {
      return '近期场景多次被重规划，请更保守地规划冲突和目标。';
    }
    if (rewriteCount >= 3) {
      return '近期场景多次被重写，请给出更具体的拍点指引。';
    }
    return '';
  }
}
