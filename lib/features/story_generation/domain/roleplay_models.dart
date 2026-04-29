/// Structured output from a role agent for a single character's turn.
class RoleplayTurn {
  const RoleplayTurn({
    required this.characterId,
    required this.name,
    required this.stance,
    required this.action,
    required this.taboo,
  });

  final String characterId;
  final String name;
  final String stance;
  final String action;
  final String taboo;

  /// Parses from the structured 3-line text the role agent emits.
  /// Expected lines: 立场：... / 动作：... / 禁忌：...
  static RoleplayTurn parse({
    required String characterId,
    required String name,
    required String text,
  }) {
    String stance = '';
    String action = '';
    String taboo = '';

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('立场：') || trimmed.startsWith('立场:')) {
        stance = trimmed.substring(trimmed.indexOf('：') > 0
                ? trimmed.indexOf('：') + 1
                : trimmed.indexOf(':') + 1)
            .trim();
      } else if (trimmed.startsWith('动作：') || trimmed.startsWith('动作:')) {
        action = trimmed.substring(trimmed.indexOf('：') > 0
                ? trimmed.indexOf('：') + 1
                : trimmed.indexOf(':') + 1)
            .trim();
      } else if (trimmed.startsWith('禁忌：') || trimmed.startsWith('禁忌:')) {
        taboo = trimmed.substring(trimmed.indexOf('：') > 0
                ? trimmed.indexOf('：') + 1
                : trimmed.indexOf(':') + 1)
            .trim();
      }
    }

    return RoleplayTurn(
      characterId: characterId,
      name: name,
      stance: stance,
      action: action,
      taboo: taboo,
    );
  }

  String toStructuredText() => '立场：$stance\n动作：$action\n禁忌：$taboo';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleplayTurn &&
          other.characterId == characterId &&
          other.name == name &&
          other.stance == stance &&
          other.action == action &&
          other.taboo == taboo;

  @override
  int get hashCode =>
      Object.hash(characterId, name, stance, action, taboo);
}

/// A proposed action from a character within a scene beat.
class SceneBeat {
  const SceneBeat({
    required this.characterId,
    required this.action,
    this.targetId,
  });

  final String characterId;
  final String action;
  final String? targetId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneBeat &&
          other.characterId == characterId &&
          other.action == action &&
          other.targetId == targetId;

  @override
  int get hashCode => Object.hash(characterId, action, targetId);
}

/// Resolution status for a scene beat.
enum BeatResolution { accepted, rejected }

/// A resolved (accepted or rejected) scene beat with an explicit reason.
class ResolvedBeat {
  const ResolvedBeat({
    required this.beat,
    required this.resolution,
    required this.reason,
  });

  final SceneBeat beat;
  final BeatResolution resolution;
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedBeat &&
          other.beat == beat &&
          other.resolution == resolution &&
          other.reason == reason;

  @override
  int get hashCode => Object.hash(beat, resolution, reason);
}

/// A belief update resulting from scene resolution.
class BeliefUpdate {
  const BeliefUpdate({
    required this.characterId,
    required this.targetId,
    required this.oldClaim,
    required this.newClaim,
    required this.reason,
  });

  final String characterId;
  final String targetId;
  final String oldClaim;
  final String newClaim;
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeliefUpdate &&
          other.characterId == characterId &&
          other.targetId == targetId &&
          other.oldClaim == oldClaim &&
          other.newClaim == newClaim &&
          other.reason == reason;

  @override
  int get hashCode =>
      Object.hash(characterId, targetId, oldClaim, newClaim, reason);
}

/// A role prompt packet assembled from character cognition atoms.
///
/// This is a positive-only, small, deterministic snapshot of what a character
/// knows, feels, and intends — suitable for injection into a role-play prompt.
class RolePromptPacket {
  const RolePromptPacket({
    required this.characterId,
    required this.characterName,
    required this.characterRole,
    this.currentUnderstanding = '',
    this.currentFeeling = '',
    this.viewOfOthers = '',
    this.surfaceBehavior = '',
    this.unspokenThoughts = '',
    this.actionIntent = '',
    this.dialogueTendency = '',
    this.sourceAtomIds = const [],
    this.metadata = const {},
  });

  final String characterId;
  final String characterName;
  final String characterRole;

  /// 当前理解 — what the character perceives or has been told.
  final String currentUnderstanding;

  /// 当前感受 — the character's internal emotional state.
  final String currentFeeling;

  /// 对他人的看法 — beliefs and inferences about other characters.
  final String viewOfOthers;

  /// 表层表现 — outward behaviour and presentation.
  final String surfaceBehavior;

  /// 未出口念头 — suspicions and uncertainties the character holds privately.
  final String unspokenThoughts;

  /// 行动意图 — the character's goals.
  final String actionIntent;

  /// 对白倾向 — the character's declared conversational intent.
  final String dialogueTendency;

  /// IDs of the atoms that contributed to this packet (trace back).
  final List<String> sourceAtomIds;

  /// Arbitrary metadata for extensibility.
  final Map<String, Object?> metadata;

  RolePromptPacket copyWith({
    String? characterId,
    String? characterName,
    String? characterRole,
    String? currentUnderstanding,
    String? currentFeeling,
    String? viewOfOthers,
    String? surfaceBehavior,
    String? unspokenThoughts,
    String? actionIntent,
    String? dialogueTendency,
    List<String>? sourceAtomIds,
    Map<String, Object?>? metadata,
  }) {
    return RolePromptPacket(
      characterId: characterId ?? this.characterId,
      characterName: characterName ?? this.characterName,
      characterRole: characterRole ?? this.characterRole,
      currentUnderstanding: currentUnderstanding ?? this.currentUnderstanding,
      currentFeeling: currentFeeling ?? this.currentFeeling,
      viewOfOthers: viewOfOthers ?? this.viewOfOthers,
      surfaceBehavior: surfaceBehavior ?? this.surfaceBehavior,
      unspokenThoughts: unspokenThoughts ?? this.unspokenThoughts,
      actionIntent: actionIntent ?? this.actionIntent,
      dialogueTendency: dialogueTendency ?? this.dialogueTendency,
      sourceAtomIds: sourceAtomIds ?? this.sourceAtomIds,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'characterId': characterId,
      'characterName': characterName,
      'characterRole': characterRole,
      'currentUnderstanding': currentUnderstanding,
      'currentFeeling': currentFeeling,
      'viewOfOthers': viewOfOthers,
      'surfaceBehavior': surfaceBehavior,
      'unspokenThoughts': unspokenThoughts,
      'actionIntent': actionIntent,
      'dialogueTendency': dialogueTendency,
      'sourceAtomIds': sourceAtomIds,
      'metadata': metadata,
    };
  }

  static RolePromptPacket fromJson(Map<Object?, Object?> json) {
    return RolePromptPacket(
      characterId: json['characterId']?.toString() ?? '',
      characterName: json['characterName']?.toString() ?? '',
      characterRole: json['characterRole']?.toString() ?? '',
      currentUnderstanding: json['currentUnderstanding']?.toString() ?? '',
      currentFeeling: json['currentFeeling']?.toString() ?? '',
      viewOfOthers: json['viewOfOthers']?.toString() ?? '',
      surfaceBehavior: json['surfaceBehavior']?.toString() ?? '',
      unspokenThoughts: json['unspokenThoughts']?.toString() ?? '',
      actionIntent: json['actionIntent']?.toString() ?? '',
      dialogueTendency: json['dialogueTendency']?.toString() ?? '',
      sourceAtomIds: _parseStringList(json['sourceAtomIds']),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const <String, Object?>{},
    );
  }

  static List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item != null && item.toString().trim().isNotEmpty)
          item.toString().trim(),
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RolePromptPacket &&
        other.characterId == characterId &&
        other.characterName == characterName &&
        other.characterRole == characterRole &&
        other.currentUnderstanding == currentUnderstanding &&
        other.currentFeeling == currentFeeling &&
        other.viewOfOthers == viewOfOthers &&
        other.surfaceBehavior == surfaceBehavior &&
        other.unspokenThoughts == unspokenThoughts &&
        other.actionIntent == actionIntent &&
        other.dialogueTendency == dialogueTendency &&
        _listEquals(other.sourceAtomIds, sourceAtomIds) &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
        characterId,
        characterName,
        characterRole,
        currentUnderstanding,
        currentFeeling,
        viewOfOthers,
        surfaceBehavior,
        unspokenThoughts,
        actionIntent,
        dialogueTendency,
        Object.hashAll(sourceAtomIds),
        Object.hashAllUnordered(metadata.entries),
      );

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Changes to scene state after resolving all beats.
class SceneStateDelta {
  const SceneStateDelta({
    required this.resolvedBeats,
    this.beliefUpdates = const [],
  });

  final List<ResolvedBeat> resolvedBeats;
  final List<BeliefUpdate> beliefUpdates;

  List<ResolvedBeat> get acceptedBeats => [
        for (final rb in resolvedBeats)
          if (rb.resolution == BeatResolution.accepted) rb,
      ];

  List<ResolvedBeat> get rejectedBeats => [
        for (final rb in resolvedBeats)
          if (rb.resolution == BeatResolution.rejected) rb,
      ];
}
