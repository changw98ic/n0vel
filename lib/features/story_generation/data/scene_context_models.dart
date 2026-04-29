import 'package:novel_writer/app/state/app_storage_clone.dart';

enum SceneCastContribution { action, dialogue, interaction }

enum KnowledgeVisibility {
  truthOnly,
  editorOnly,
  resolverOnly,
  agentPrivate,
  publicObservable,
}

class SceneCastParticipation {
  const SceneCastParticipation({this.action, this.dialogue, this.interaction});

  final String? action;
  final String? dialogue;
  final String? interaction;
}

class SceneCastCandidate {
  SceneCastCandidate({
    required this.characterId,
    required this.name,
    required this.role,
    this.participation = const SceneCastParticipation(),
    Map<String, Object?> metadata = const {},
  }) : metadata = immutableMap(metadata);

  final String characterId;
  final String name;
  final String role;
  final SceneCastParticipation participation;
  final Map<String, Object?> metadata;
}

class ResolvedSceneCastMember {
  ResolvedSceneCastMember({
    required this.characterId,
    required this.name,
    required this.role,
    required List<SceneCastContribution> contributions,
    Map<String, Object?> metadata = const {},
  }) : contributions = immutableList(contributions),
       metadata = immutableMap(metadata);

  final String characterId;
  final String name;
  final String role;
  final List<SceneCastContribution> contributions;
  final Map<String, Object?> metadata;
}

class CharacterProfile {
  CharacterProfile({
    required this.characterId,
    required this.name,
    required this.role,
    List<String> coreDrives = const [],
    List<String> fears = const [],
    List<String> values = const [],
    List<String> boundaries = const [],
    List<String> speechTraits = const [],
    Map<String, Object?> metadata = const {},
  }) : coreDrives = immutableList(coreDrives),
       fears = immutableList(fears),
       values = immutableList(values),
       boundaries = immutableList(boundaries),
       speechTraits = immutableList(speechTraits),
       metadata = immutableMap(metadata);

  final String characterId;
  final String name;
  final String role;
  final List<String> coreDrives;
  final List<String> fears;
  final List<String> values;
  final List<String> boundaries;
  final List<String> speechTraits;
  final Map<String, Object?> metadata;
}

class RelationshipState {
  RelationshipState({
    required this.sourceCharacterId,
    required this.targetCharacterId,
    required this.trust,
    required this.dependence,
    required this.fear,
    required this.resentment,
    required this.desire,
    required this.powerGap,
    required this.publicAlignment,
    required this.privateAlignment,
    List<String> sharedSecrets = const [],
    List<String> recentTriggers = const [],
  }) : sharedSecrets = immutableList(sharedSecrets),
       recentTriggers = immutableList(recentTriggers);

  final String sourceCharacterId;
  final String targetCharacterId;
  final double trust;
  final double dependence;
  final double fear;
  final double resentment;
  final double desire;
  final double powerGap;
  final String publicAlignment;
  final String privateAlignment;
  final List<String> sharedSecrets;
  final List<String> recentTriggers;
}

class SocialPositionState {
  SocialPositionState({
    required this.characterId,
    required this.institution,
    required this.publicStatus,
    required this.legalExposure,
    List<String> resources = const [],
    List<String> activeConstraints = const [],
    List<String> currentLeverage = const [],
    List<String> watchers = const [],
  }) : resources = immutableList(resources),
       activeConstraints = immutableList(activeConstraints),
       currentLeverage = immutableList(currentLeverage),
       watchers = immutableList(watchers);

  final String characterId;
  final String institution;
  final String publicStatus;
  final String legalExposure;
  final List<String> resources;
  final List<String> activeConstraints;
  final List<String> currentLeverage;
  final List<String> watchers;
}

class BeliefState {
  BeliefState({
    required this.ownerCharacterId,
    required this.aboutCharacterId,
    required this.perceivedGoal,
    required this.perceivedLoyalty,
    required this.perceivedCompetence,
    required this.perceivedRisk,
    required this.perceivedEmotionalState,
    List<String> perceivedKnowledge = const [],
    List<String> suspectedSecrets = const [],
    List<String> misreadPoints = const [],
    required this.confidence,
  }) : perceivedKnowledge = immutableList(perceivedKnowledge),
       suspectedSecrets = immutableList(suspectedSecrets),
       misreadPoints = immutableList(misreadPoints);

  final String ownerCharacterId;
  final String aboutCharacterId;
  final String perceivedGoal;
  final String perceivedLoyalty;
  final String perceivedCompetence;
  final String perceivedRisk;
  final String perceivedEmotionalState;
  final List<String> perceivedKnowledge;
  final List<String> suspectedSecrets;
  final List<String> misreadPoints;
  final double confidence;

  Map<String, Object?> toJson() {
    return {
      'ownerCharacterId': ownerCharacterId,
      'aboutCharacterId': aboutCharacterId,
      'perceivedGoal': perceivedGoal,
      'perceivedLoyalty': perceivedLoyalty,
      'perceivedCompetence': perceivedCompetence,
      'perceivedRisk': perceivedRisk,
      'perceivedEmotionalState': perceivedEmotionalState,
      'perceivedKnowledge': [...perceivedKnowledge],
      'suspectedSecrets': [...suspectedSecrets],
      'misreadPoints': [...misreadPoints],
      'confidence': confidence,
    };
  }

  static BeliefState fromJson(Map<String, Object?> json) {
    return BeliefState(
      ownerCharacterId: json['ownerCharacterId']?.toString() ?? '',
      aboutCharacterId: json['aboutCharacterId']?.toString() ?? '',
      perceivedGoal: json['perceivedGoal']?.toString() ?? '',
      perceivedLoyalty: json['perceivedLoyalty']?.toString() ?? '',
      perceivedCompetence: json['perceivedCompetence']?.toString() ?? '',
      perceivedRisk: json['perceivedRisk']?.toString() ?? '',
      perceivedEmotionalState:
          json['perceivedEmotionalState']?.toString() ?? '',
      perceivedKnowledge: _stringListFromRaw(json['perceivedKnowledge']),
      suspectedSecrets: _stringListFromRaw(json['suspectedSecrets']),
      misreadPoints: _stringListFromRaw(json['misreadPoints']),
      confidence: _doubleFromRaw(json['confidence']),
    );
  }
}

class PresentationState {
  PresentationState({
    required this.characterId,
    required this.projectedPersona,
    List<String> concealments = const [],
    List<String> deceptionGoals = const [],
  }) : concealments = immutableList(concealments),
       deceptionGoals = immutableList(deceptionGoals);

  final String characterId;
  final String projectedPersona;
  final List<String> concealments;
  final List<String> deceptionGoals;

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'projectedPersona': projectedPersona,
      'concealments': [...concealments],
      'deceptionGoals': [...deceptionGoals],
    };
  }

  static PresentationState fromJson(Map<String, Object?> json) {
    return PresentationState(
      characterId: json['characterId']?.toString() ?? '',
      projectedPersona: json['projectedPersona']?.toString() ?? '',
      concealments: _stringListFromRaw(json['concealments']),
      deceptionGoals: _stringListFromRaw(json['deceptionGoals']),
    );
  }
}

class KnowledgeAtom {
  KnowledgeAtom({
    required this.id,
    required this.type,
    required this.content,
    required this.ownerScope,
    required this.visibility,
    this.priority = 0,
    this.tokenCostEstimate = 0,
    List<String> tags = const [],
    Map<String, Object?> unlockCondition = const {},
  }) : tags = immutableList(tags),
       unlockCondition = immutableMap(unlockCondition);

  final String id;
  final String type;
  final String content;
  final String ownerScope;
  final KnowledgeVisibility visibility;
  final int priority;
  final int tokenCostEstimate;
  final List<String> tags;
  final Map<String, Object?> unlockCondition;
}

List<String> _stringListFromRaw(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null && item.toString().trim().isNotEmpty) item.toString(),
  ];
}

double _doubleFromRaw(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
