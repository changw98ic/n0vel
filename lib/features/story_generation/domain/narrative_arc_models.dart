import 'package:novel_writer/app/state/app_storage_clone.dart';

enum NarrativeArcPhase {
  setup,
  risingAction,
  midpoint,
  fallingAction,
  climax,
  resolution;

  static NarrativeArcPhase fromString(String? value) {
    return NarrativeArcPhase.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NarrativeArcPhase.setup,
    );
  }
}

class PlotPoint {
  PlotPoint({
    required this.id,
    required this.chapterId,
    required this.title,
    required this.phase,
    this.description = '',
    double tension = 0.0,
    List<String> characterIds = const [],
    List<String> precedingPlotPointIds = const [],
    Map<String, Object?> metadata = const {},
  }) : tension = tension.clamp(0.0, 1.0),
       characterIds = List<String>.unmodifiable(characterIds),
       precedingPlotPointIds =
           List<String>.unmodifiable(precedingPlotPointIds),
       metadata = _immutableMap(metadata);

  final String id;
  final String chapterId;
  final String title;
  final NarrativeArcPhase phase;
  final String description;
  final double tension;
  final List<String> characterIds;
  final List<String> precedingPlotPointIds;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'chapterId': chapterId,
    'title': title,
    'phase': phase.name,
    'description': description,
    'tension': tension,
    'characterIds': [...characterIds],
    'precedingPlotPointIds': [...precedingPlotPointIds],
    'metadata': cloneStorageMap(metadata),
  };

  static PlotPoint fromJson(Map<String, Object?> json) {
    return PlotPoint(
      id: json['id']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      phase: NarrativeArcPhase.fromString(json['phase']?.toString()),
      description: json['description']?.toString() ?? '',
      tension: _clampDouble(json['tension'], 0.0, 1.0),
      characterIds: _stringList(json['characterIds']),
      precedingPlotPointIds: _stringList(json['precedingPlotPointIds']),
      metadata: _asStringObjectMap(json['metadata']),
    );
  }

  PlotPoint copyWith({
    String? id,
    String? chapterId,
    String? title,
    NarrativeArcPhase? phase,
    String? description,
    double? tension,
    List<String>? characterIds,
    List<String>? precedingPlotPointIds,
    Map<String, Object?>? metadata,
  }) {
    return PlotPoint(
      id: id ?? this.id,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      phase: phase ?? this.phase,
      description: description ?? this.description,
      tension: tension ?? this.tension,
      characterIds: characterIds ?? this.characterIds,
      precedingPlotPointIds:
          precedingPlotPointIds ?? this.precedingPlotPointIds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlotPoint &&
          id == other.id &&
          chapterId == other.chapterId &&
          title == other.title &&
          phase == other.phase &&
          description == other.description &&
          tension == other.tension &&
          _listEquals(characterIds, other.characterIds) &&
          _listEquals(precedingPlotPointIds, other.precedingPlotPointIds);

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    title,
    phase,
    description,
    tension,
    Object.hashAll(characterIds),
    Object.hashAll(precedingPlotPointIds),
  );
}

class CharacterArc {
  CharacterArc({
    required this.characterId,
    required this.startState,
    required this.endState,
    this.transformDescription = '',
    List<String> plotPointIds = const [],
    Map<String, Object?> metadata = const {},
  }) : plotPointIds = List<String>.unmodifiable(plotPointIds),
       metadata = _immutableMap(metadata);

  final String characterId;
  final String startState;
  final String endState;
  final String transformDescription;
  final List<String> plotPointIds;
  final Map<String, Object?> metadata;

  bool get hasTransform => startState != endState;

  Map<String, Object?> toJson() => {
    'characterId': characterId,
    'startState': startState,
    'endState': endState,
    'transformDescription': transformDescription,
    'plotPointIds': [...plotPointIds],
    'metadata': cloneStorageMap(metadata),
  };

  static CharacterArc fromJson(Map<String, Object?> json) {
    return CharacterArc(
      characterId: json['characterId']?.toString() ?? '',
      startState: json['startState']?.toString() ?? '',
      endState: json['endState']?.toString() ?? '',
      transformDescription:
          json['transformDescription']?.toString() ?? '',
      plotPointIds: _stringList(json['plotPointIds']),
      metadata: _asStringObjectMap(json['metadata']),
    );
  }

  CharacterArc copyWith({
    String? characterId,
    String? startState,
    String? endState,
    String? transformDescription,
    List<String>? plotPointIds,
    Map<String, Object?>? metadata,
  }) {
    return CharacterArc(
      characterId: characterId ?? this.characterId,
      startState: startState ?? this.startState,
      endState: endState ?? this.endState,
      transformDescription:
          transformDescription ?? this.transformDescription,
      plotPointIds: plotPointIds ?? this.plotPointIds,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterArc &&
          characterId == other.characterId &&
          startState == other.startState &&
          endState == other.endState &&
          transformDescription == other.transformDescription &&
          _listEquals(plotPointIds, other.plotPointIds);

  @override
  int get hashCode => Object.hash(
    characterId,
    startState,
    endState,
    transformDescription,
    Object.hashAll(plotPointIds),
  );
}

class NarrativeTensionCurve {
  NarrativeTensionCurve({
    List<NarrativeTensionPoint> points = const [],
  }) : points = List<NarrativeTensionPoint>.unmodifiable(points);

  final List<NarrativeTensionPoint> points;

  double get peakTension =>
      points.isEmpty ? 0.0 : points.map((p) => p.tension).reduce(mathMax);

  double get averageTension => points.isEmpty
      ? 0.0
      : points.map((p) => p.tension).reduce((a, b) => a + b) /
            points.length;

  NarrativeTensionPoint? pointAtChapter(String chapterId) {
    for (final p in points) {
      if (p.chapterId == chapterId) return p;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'points': [for (final p in points) p.toJson()],
  };

  static NarrativeTensionCurve fromJson(Map<String, Object?> json) {
    final rawPoints = json['points'] as List<Object?>? ?? const [];
    return NarrativeTensionCurve(
      points: [
        for (final entry in rawPoints)
          if (entry is Map)
            NarrativeTensionPoint.fromJson(_asStringObjectMap(entry)),
      ],
    );
  }
}

class NarrativeTensionPoint {
  const NarrativeTensionPoint({
    required this.chapterId,
    required this.tension,
    this.label = '',
  });

  final String chapterId;
  final double tension;
  final String label;

  Map<String, Object?> toJson() => {
    'chapterId': chapterId,
    'tension': tension,
    'label': label,
  };

  static NarrativeTensionPoint fromJson(Map<String, Object?> json) {
    return NarrativeTensionPoint(
      chapterId: json['chapterId']?.toString() ?? '',
      tension: _clampDouble(json['tension'], 0.0, 1.0),
      label: json['label']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NarrativeTensionPoint &&
          chapterId == other.chapterId &&
          tension == other.tension &&
          label == other.label;

  @override
  int get hashCode => Object.hash(chapterId, tension, label);
}

class NarrativeArc {
  NarrativeArc({
    required this.projectId,
    this.id = '',
    this.title = '',
    this.theme = '',
    this.centralConflict = '',
    this.currentPhase = NarrativeArcPhase.setup,
    List<PlotPoint> plotPoints = const [],
    List<CharacterArc> characterArcs = const [],
    NarrativeTensionCurve? tensionCurve,
    Map<String, Object?> metadata = const {},
  }) : plotPoints = List<PlotPoint>.unmodifiable(plotPoints),
       characterArcs = List<CharacterArc>.unmodifiable(characterArcs),
       tensionCurve = tensionCurve ?? NarrativeTensionCurve(),
       metadata = _immutableMap(metadata);

  final String projectId;
  final String id;
  final String title;
  final String theme;
  final String centralConflict;
  final NarrativeArcPhase currentPhase;
  final List<PlotPoint> plotPoints;
  final List<CharacterArc> characterArcs;
  final NarrativeTensionCurve tensionCurve;
  final Map<String, Object?> metadata;

  List<PlotPoint> plotPointsInPhase(NarrativeArcPhase phase) =>
      [for (final p in plotPoints) if (p.phase == phase) p];

  CharacterArc? arcForCharacter(String characterId) {
    for (final arc in characterArcs) {
      if (arc.characterId == characterId) return arc;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'projectId': projectId,
    'id': id,
    'title': title,
    'theme': theme,
    'centralConflict': centralConflict,
    'currentPhase': currentPhase.name,
    'plotPoints': [for (final p in plotPoints) p.toJson()],
    'characterArcs': [for (final a in characterArcs) a.toJson()],
    'tensionCurve': tensionCurve.toJson(),
    'metadata': cloneStorageMap(metadata),
  };

  static NarrativeArc fromJson(Map<String, Object?> json) {
    final rawPlotPoints = json['plotPoints'] as List<Object?>? ?? const [];
    final rawCharacterArcs =
        json['characterArcs'] as List<Object?>? ?? const [];
    final rawTensionCurve =
        json['tensionCurve'] as Map<String, Object?>? ?? const {};
    return NarrativeArc(
      projectId: json['projectId']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      theme: json['theme']?.toString() ?? '',
      centralConflict: json['centralConflict']?.toString() ?? '',
      currentPhase: NarrativeArcPhase.fromString(
        json['currentPhase']?.toString(),
      ),
      plotPoints: [
        for (final entry in rawPlotPoints)
          if (entry is Map)
            PlotPoint.fromJson(_asStringObjectMap(entry)),
      ],
      characterArcs: [
        for (final entry in rawCharacterArcs)
          if (entry is Map)
            CharacterArc.fromJson(_asStringObjectMap(entry)),
      ],
      tensionCurve: NarrativeTensionCurve.fromJson(
        _asStringObjectMap(rawTensionCurve),
      ),
      metadata: _asStringObjectMap(json['metadata']),
    );
  }

  NarrativeArc copyWith({
    String? projectId,
    String? id,
    String? title,
    String? theme,
    String? centralConflict,
    NarrativeArcPhase? currentPhase,
    List<PlotPoint>? plotPoints,
    List<CharacterArc>? characterArcs,
    NarrativeTensionCurve? tensionCurve,
    Map<String, Object?>? metadata,
  }) {
    return NarrativeArc(
      projectId: projectId ?? this.projectId,
      id: id ?? this.id,
      title: title ?? this.title,
      theme: theme ?? this.theme,
      centralConflict: centralConflict ?? this.centralConflict,
      currentPhase: currentPhase ?? this.currentPhase,
      plotPoints: plotPoints ?? this.plotPoints,
      characterArcs: characterArcs ?? this.characterArcs,
      tensionCurve: tensionCurve ?? this.tensionCurve,
      metadata: metadata ?? this.metadata,
    );
  }
}

// -- helpers --

double _clampDouble(Object? value, double min, double max) {
  final d = value is num ? value.toDouble() : 0.0;
  return d.clamp(min, max);
}

double mathMax(double a, double b) => a > b ? a : b;

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item?.toString() ?? ''];
}

Map<String, Object?> _immutableMap(Map<String, Object?> value) {
  return Map<String, Object?>.unmodifiable({
    for (final entry in cloneStorageMap(value).entries)
      entry.key: _immutableValue(entry.value),
  });
}

Object? _immutableValue(Object? value) {
  if (value is Map<String, Object?>) return _immutableMap(value);
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _immutableValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (final item in value) _immutableValue(item),
    ]);
  }
  return value;
}

Map<String, Object?> _asStringObjectMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): cloneStorageValue(entry.value),
  };
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
