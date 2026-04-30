import 'character_memory_delta_models.dart';

class CharacterMemoryConflict {
  const CharacterMemoryConflict({
    required this.incoming,
    required this.existing,
    required this.reason,
  });

  final CharacterMemoryDelta incoming;
  final CharacterMemoryDelta existing;
  final String reason;
}

class CharacterMemoryConflictPolicy {
  const CharacterMemoryConflictPolicy();

  CharacterMemoryConflict? findConflict({
    required CharacterMemoryDelta incoming,
    required Iterable<CharacterMemoryDelta> existing,
  }) {
    final incomingContent = _normalize(incoming.content);
    if (incomingContent.isEmpty) return null;
    for (final memory in existing) {
      if (memory.characterId != incoming.characterId) continue;
      if (memory.kind != incoming.kind) continue;
      final existingContent = _normalize(memory.content);
      if (existingContent.isEmpty) continue;
      final reason = _oppositionReason(incomingContent, existingContent);
      if (reason == null) continue;
      return CharacterMemoryConflict(
        incoming: incoming,
        existing: memory,
        reason: reason,
      );
    }
    return null;
  }

  String? _oppositionReason(String incoming, String existing) {
    for (final pair in _opposedTerms) {
      if (_hasOpposition(incoming, existing, pair.$1, pair.$2)) {
        return 'opposed terms "${pair.$1}" and "${pair.$2}"';
      }
    }
    return null;
  }

  bool _hasOpposition(
    String incoming,
    String existing,
    String positive,
    String negative,
  ) {
    return (incoming.contains(positive) && existing.contains(negative)) ||
        (incoming.contains(negative) && existing.contains(positive));
  }

  String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }

  static const List<(String, String)> _opposedTerms = [
    ('相信', '不相信'),
    ('信任', '不信任'),
    ('信任', '怀疑'),
    ('愿意', '不愿'),
    ('接受', '拒绝'),
    ('知道', '不知道'),
    ('想要', '不想'),
    ('害怕', '不怕'),
    ('靠近', '远离'),
    ('保护', '伤害'),
    ('承认', '否认'),
    ('loyal', 'disloyal'),
    ('trust', 'distrust'),
    ('accept', 'reject'),
    ('knows', 'does not know'),
  ];
}
