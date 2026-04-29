import 'character_visible_context_models.dart';

enum CharacterMemoryDeltaKind {
  observation,
  belief,
  emotion,
  intention,
  relationship,
  worldFact,
}

class CharacterMemoryDelta {
  const CharacterMemoryDelta({
    required this.deltaId,
    required this.kind,
    required this.content,
    required this.acl,
    required this.sourceRound,
    this.characterId = '',
    this.sourceTurnId = '',
    this.confidence = 1,
    this.accepted = false,
    this.rejectionReason = '',
  });

  final String deltaId;
  final String characterId;
  final CharacterMemoryDeltaKind kind;
  final String content;
  final VisibilityAcl acl;
  final int sourceRound;
  final String sourceTurnId;
  final double confidence;
  final bool accepted;
  final String rejectionReason;

  CharacterMemoryDelta accept() {
    return CharacterMemoryDelta(
      deltaId: deltaId,
      characterId: characterId,
      kind: kind,
      content: content,
      acl: acl,
      sourceRound: sourceRound,
      sourceTurnId: sourceTurnId,
      confidence: confidence,
      accepted: true,
    );
  }

  CharacterMemoryDelta reject(String reason) {
    return CharacterMemoryDelta(
      deltaId: deltaId,
      characterId: characterId,
      kind: kind,
      content: content,
      acl: acl,
      sourceRound: sourceRound,
      sourceTurnId: sourceTurnId,
      confidence: confidence,
      rejectionReason: reason,
    );
  }

  String toPromptLine() {
    final target = characterId.isEmpty ? 'public' : characterId;
    final status = accepted ? 'accepted' : 'proposed';
    return '$status/$target/${kind.name}/$deltaId：$content';
  }

  Map<String, Object?> toJson() {
    return {
      'deltaId': deltaId,
      'characterId': characterId,
      'kind': kind.name,
      'content': content,
      'acl': acl.toJson(),
      'sourceRound': sourceRound,
      'sourceTurnId': sourceTurnId,
      'confidence': confidence,
      'accepted': accepted,
      'rejectionReason': rejectionReason,
    };
  }

  factory CharacterMemoryDelta.fromJson(Map<String, Object?> json) {
    return CharacterMemoryDelta(
      deltaId: _string(json['deltaId']),
      characterId: _string(json['characterId']),
      kind: _kindFromJson(json['kind']),
      content: _string(json['content']),
      acl: json['acl'] is Map
          ? VisibilityAcl.fromJson(
              Map<String, Object?>.from(json['acl'] as Map),
            )
          : VisibilityAcl.authorOnly(),
      sourceRound: _int(json['sourceRound']),
      sourceTurnId: _string(json['sourceTurnId']),
      confidence: _double(json['confidence']) ?? 1,
      accepted: json['accepted'] == true,
      rejectionReason: _string(json['rejectionReason']),
    );
  }

  static CharacterMemoryDeltaKind _kindFromJson(Object? raw) {
    final value = _string(raw);
    for (final kind in CharacterMemoryDeltaKind.values) {
      if (kind.name == value) return kind;
    }
    return CharacterMemoryDeltaKind.observation;
  }

  static String _string(Object? raw) => raw is String ? raw : '';

  static int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  static double? _double(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
