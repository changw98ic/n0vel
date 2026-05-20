import 'soul_contract.dart';
import 'typed_artifact.dart';

/// A structured character profile replacing free-text descriptions.
///
/// Contains quantifiable personality traits, voice patterns, behavioral
/// boundaries, and relationship edges — all machine-verifiable.
class StructuredProfile extends TypedArtifact {
  const StructuredProfile({
    required this.id,
    required this.name,
    required this.personality,
    required this.voicePrint,
    required this.behaviorBounds,
    this.soul = const SoulContract(),
    this.backstory = '',
    this.relationships = const [],
    this.metadata = const {},
  });

  final String id;
  final String name;
  final PersonalityVector personality;
  final VoicePrint voicePrint;
  final BehaviorBounds behaviorBounds;
  final SoulContract soul;
  final String backstory;
  final List<RelationshipEdge> relationships;
  final Map<String, Object?> metadata;

  @override
  ArtifactType get type => ArtifactType.sceneOutput;

  @override
  int get tokenEstimate {
    var tokens = 50; // base overhead
    tokens += backstory.length ~/ 2;
    tokens += relationships.length * 10;
    return tokens;
  }

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'personality': personality.toJson(),
    'voicePrint': voicePrint.toJson(),
    'behaviorBounds': behaviorBounds.toJson(),
    'soul': soul.toJson(),
    'backstory': backstory,
    'relationships': [for (final r in relationships) r.toJson()],
    'metadata': metadata,
  };

  factory StructuredProfile.fromJson(Map<String, Object?> json) {
    return StructuredProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      personality: PersonalityVector.fromJson(
        _asMap(json['personality']),
      ),
      voicePrint: VoicePrint.fromJson(_asMap(json['voicePrint'])),
      behaviorBounds: BehaviorBounds.fromJson(
        _asMap(json['behaviorBounds']),
      ),
      soul: json['soul'] is Map
          ? SoulContract.fromJson(_asMap(json['soul']))
          : const SoulContract(),
      backstory: json['backstory']?.toString() ?? '',
      relationships: _parseEdges(json['relationships']),
      metadata: _asMap(json['metadata']),
    );
  }
}

/// Big Five personality traits as a numerical vector.
class PersonalityVector {
  const PersonalityVector({
    this.openness = 0.5,
    this.conscientiousness = 0.5,
    this.extraversion = 0.5,
    this.agreeableness = 0.5,
    this.neuroticism = 0.5,
  });

  final double openness;
  final double conscientiousness;
  final double extraversion;
  final double agreeableness;
  final double neuroticism;

  Map<String, Object?> toJson() => {
    'openness': openness,
    'conscientiousness': conscientiousness,
    'extraversion': extraversion,
    'agreeableness': agreeableness,
    'neuroticism': neuroticism,
  };

  factory PersonalityVector.fromJson(Map<String, Object?> json) {
    return PersonalityVector(
      openness: _asDoubleOrDefault(json['openness'], 0.5),
      conscientiousness: _asDoubleOrDefault(json['conscientiousness'], 0.5),
      extraversion: _asDoubleOrDefault(json['extraversion'], 0.5),
      agreeableness: _asDoubleOrDefault(json['agreeableness'], 0.5),
      neuroticism: _asDoubleOrDefault(json['neuroticism'], 0.5),
    );
  }
}

/// Captured speaking patterns for a character.
class VoicePrint {
  const VoicePrint({
    this.vocabularyLevel = 'standard',
    this.sentenceLength = 'medium',
    this.speakingPatterns = const [],
    this.catchphrases = const [],
    this.toneModifiers = const [],
  });

  final String vocabularyLevel;
  final String sentenceLength;
  final List<String> speakingPatterns;
  final List<String> catchphrases;
  final List<String> toneModifiers;

  Map<String, Object?> toJson() => {
    'vocabularyLevel': vocabularyLevel,
    'sentenceLength': sentenceLength,
    'speakingPatterns': speakingPatterns,
    'catchphrases': catchphrases,
    'toneModifiers': toneModifiers,
  };

  factory VoicePrint.fromJson(Map<String, Object?> json) {
    return VoicePrint(
      vocabularyLevel: json['vocabularyLevel']?.toString() ?? 'standard',
      sentenceLength: json['sentenceLength']?.toString() ?? 'medium',
      speakingPatterns: _asStringList(json['speakingPatterns']),
      catchphrases: _asStringList(json['catchphrases']),
      toneModifiers: _asStringList(json['toneModifiers']),
    );
  }
}

/// Hard boundaries a character will never cross.
class BehaviorBounds {
  const BehaviorBounds({
    this.forbiddenActions = const [],
    this.mandatoryResponses = const [],
    this.emotionalRange = const EmotionalRange(),
  });

  final List<String> forbiddenActions;
  final List<String> mandatoryResponses;
  final EmotionalRange emotionalRange;

  Map<String, Object?> toJson() => {
    'forbiddenActions': forbiddenActions,
    'mandatoryResponses': mandatoryResponses,
    'emotionalRange': emotionalRange.toJson(),
  };

  factory BehaviorBounds.fromJson(Map<String, Object?> json) {
    return BehaviorBounds(
      forbiddenActions: _asStringList(json['forbiddenActions']),
      mandatoryResponses: _asStringList(json['mandatoryResponses']),
      emotionalRange: EmotionalRange.fromJson(
        _asMap(json['emotionalRange']),
      ),
    );
  }
}

/// Allowed emotional range for a character.
class EmotionalRange {
  const EmotionalRange({
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

  factory EmotionalRange.fromJson(Map<String, Object?> json) {
    return EmotionalRange(
      maxIntensity: _asDouble(json['maxIntensity']),
      forbiddenEmotions: _asStringList(json['forbiddenEmotions']),
      defaultState: json['defaultState']?.toString() ?? 'neutral',
    );
  }
}

/// A directed relationship edge between two characters.
class RelationshipEdge {
  const RelationshipEdge({
    required this.targetId,
    required this.type,
    this.strength = 0.5,
  });

  final String targetId;
  final String type;
  final double strength;

  Map<String, Object?> toJson() => {
    'targetId': targetId,
    'type': type,
    'strength': strength,
  };

  factory RelationshipEdge.fromJson(Map<String, Object?> json) {
    return RelationshipEdge(
      targetId: json['targetId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      strength: _asDouble(json['strength']),
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
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}

double _asDoubleOrDefault(Object? raw, double defaultValue) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw == null) return defaultValue;
  return double.tryParse(raw.toString()) ?? defaultValue;
}

List<RelationshipEdge> _parseEdges(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) RelationshipEdge.fromJson(Map<String, Object?>.from(item)),
  ];
}
