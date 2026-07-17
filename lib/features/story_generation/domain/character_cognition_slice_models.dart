import 'character_cognition_utils.dart';

// ---------------------------------------------------------------------------
// CharacterBelief — what one character believes about another.
// ---------------------------------------------------------------------------

class CharacterBelief {
  CharacterBelief({
    required this.subjectId,
    required this.targetId,
    required this.claim,
    double confidence = 1.0,
    this.source = '',
  }) : confidence = confidence.clamp(0.0, 1.0);

  final String subjectId;
  final String targetId;
  final String claim;
  final double confidence;
  final String source;

  CharacterBelief copyWith({
    String? subjectId,
    String? targetId,
    String? claim,
    double? confidence,
    String? source,
  }) {
    return CharacterBelief(
      subjectId: subjectId ?? this.subjectId,
      targetId: targetId ?? this.targetId,
      claim: claim ?? this.claim,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'subjectId': subjectId,
      'targetId': targetId,
      'claim': claim,
      'confidence': confidence,
      'source': source,
    };
  }

  static CharacterBelief fromJson(Map<Object?, Object?> json) {
    return CharacterBelief(
      subjectId: json['subjectId']?.toString() ?? '',
      targetId: json['targetId']?.toString() ?? '',
      claim: json['claim']?.toString() ?? '',
      confidence: parseClampedDouble(json['confidence'], fallback: 1.0),
      source: json['source']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CharacterBelief &&
        other.subjectId == subjectId &&
        other.targetId == targetId &&
        other.claim == claim &&
        other.confidence == confidence &&
        other.source == source;
  }

  @override
  int get hashCode =>
      Object.hash(subjectId, targetId, claim, confidence, source);
}

// ---------------------------------------------------------------------------
// RelationshipSlice — a character's view of their relationship with another.
// ---------------------------------------------------------------------------

class RelationshipSlice {
  RelationshipSlice({
    required this.characterId,
    required this.otherId,
    required this.kind,
    double trust = 0.5,
    double tension = 0.0,
    this.notes = '',
  }) : trust = trust.clamp(0.0, 1.0),
       tension = tension.clamp(0.0, 1.0);

  final String characterId;
  final String otherId;
  final String kind;
  final double trust;
  final double tension;
  final String notes;

  RelationshipSlice copyWith({
    String? characterId,
    String? otherId,
    String? kind,
    double? trust,
    double? tension,
    String? notes,
  }) {
    return RelationshipSlice(
      characterId: characterId ?? this.characterId,
      otherId: otherId ?? this.otherId,
      kind: kind ?? this.kind,
      trust: trust ?? this.trust,
      tension: tension ?? this.tension,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'otherId': otherId,
      'kind': kind,
      'trust': trust,
      'tension': tension,
      'notes': notes,
    };
  }

  static RelationshipSlice fromJson(Map<Object?, Object?> json) {
    return RelationshipSlice(
      characterId: json['characterId']?.toString() ?? '',
      otherId: json['otherId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      trust: parseClampedDouble(json['trust'], fallback: 0.5),
      tension: parseClampedDouble(json['tension'], fallback: 0.0),
      notes: json['notes']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelationshipSlice &&
        other.characterId == characterId &&
        other.otherId == otherId &&
        other.kind == kind &&
        other.trust == trust &&
        other.tension == tension &&
        other.notes == notes;
  }

  @override
  int get hashCode =>
      Object.hash(characterId, otherId, kind, trust, tension, notes);
}

// ---------------------------------------------------------------------------
// SocialPositionSlice — a character's social position in a context.
// ---------------------------------------------------------------------------

class SocialPositionSlice {
  const SocialPositionSlice({
    required this.characterId,
    required this.contextId,
    required this.role,
    this.rank = 0,
    this.notes = '',
  });

  final String characterId;
  final String contextId;
  final String role;
  final int rank;
  final String notes;

  SocialPositionSlice copyWith({
    String? characterId,
    String? contextId,
    String? role,
    int? rank,
    String? notes,
  }) {
    return SocialPositionSlice(
      characterId: characterId ?? this.characterId,
      contextId: contextId ?? this.contextId,
      role: role ?? this.role,
      rank: rank ?? this.rank,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'contextId': contextId,
      'role': role,
      'rank': rank,
      'notes': notes,
    };
  }

  static SocialPositionSlice fromJson(Map<Object?, Object?> json) {
    return SocialPositionSlice(
      characterId: json['characterId']?.toString() ?? '',
      contextId: json['contextId']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      rank: parseIntOrFallback(json['rank'], fallback: 0),
      notes: json['notes']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialPositionSlice &&
        other.characterId == characterId &&
        other.contextId == contextId &&
        other.role == role &&
        other.rank == rank &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(characterId, contextId, role, rank, notes);
}

// ---------------------------------------------------------------------------
// PresentationState — what a character shows vs. what they hide.
// ---------------------------------------------------------------------------

class PresentationState {
  const PresentationState({
    required this.characterId,
    this.displayedEmotion = '',
    this.hiddenEmotion = '',
    this.deceptionTarget = '',
    this.deceptionContent = '',
  });

  final String characterId;
  final String displayedEmotion;
  final String hiddenEmotion;
  final String deceptionTarget;
  final String deceptionContent;

  bool get isDeceiving =>
      deceptionTarget.isNotEmpty && deceptionContent.isNotEmpty;

  PresentationState copyWith({
    String? characterId,
    String? displayedEmotion,
    String? hiddenEmotion,
    String? deceptionTarget,
    String? deceptionContent,
  }) {
    return PresentationState(
      characterId: characterId ?? this.characterId,
      displayedEmotion: displayedEmotion ?? this.displayedEmotion,
      hiddenEmotion: hiddenEmotion ?? this.hiddenEmotion,
      deceptionTarget: deceptionTarget ?? this.deceptionTarget,
      deceptionContent: deceptionContent ?? this.deceptionContent,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'displayedEmotion': displayedEmotion,
      'hiddenEmotion': hiddenEmotion,
      'deceptionTarget': deceptionTarget,
      'deceptionContent': deceptionContent,
    };
  }

  static PresentationState fromJson(Map<Object?, Object?> json) {
    return PresentationState(
      characterId: json['characterId']?.toString() ?? '',
      displayedEmotion: json['displayedEmotion']?.toString() ?? '',
      hiddenEmotion: json['hiddenEmotion']?.toString() ?? '',
      deceptionTarget: json['deceptionTarget']?.toString() ?? '',
      deceptionContent: json['deceptionContent']?.toString() ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresentationState &&
        other.characterId == characterId &&
        other.displayedEmotion == displayedEmotion &&
        other.hiddenEmotion == hiddenEmotion &&
        other.deceptionTarget == deceptionTarget &&
        other.deceptionContent == deceptionContent;
  }

  @override
  int get hashCode => Object.hash(
    characterId,
    displayedEmotion,
    hiddenEmotion,
    deceptionTarget,
    deceptionContent,
  );
}
