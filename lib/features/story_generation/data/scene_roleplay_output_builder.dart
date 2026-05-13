import 'scene_roleplay_session_models.dart';
import '../domain/scene_models.dart';

/// Builds the final [DynamicRoleAgentOutput] for each cast member from the
/// accumulated roleplay turns and scene state.
class SceneRoleplayOutputBuilder {
  const SceneRoleplayOutputBuilder();

  DynamicRoleAgentOutput build({
    required ResolvedSceneCastMember member,
    required List<SceneRoleplayTurn> turns,
    required String sceneState,
  }) {
    final last = turns.isNotEmpty ? turns.last : null;
    final stance = firstNonEmpty([
      last?.intent,
      turns.map((t) => t.intent).where((v) => v.isNotEmpty).join('；'),
      '${member.name}维持${member.role}的场内立场',
    ]);
    final action = firstNonEmpty([
      last == null ? '' : visibleAction(last),
      turns.map(visibleAction).where((v) => v.isNotEmpty).join('；'),
      '参与场景冲突推进',
    ]);
    final taboo = firstNonEmpty([
      last?.taboo,
      turns.map((t) => t.taboo).where((v) => v.isNotEmpty).join('；'),
      '脱离角色当前认知边界',
    ]);
    final process = turns
        .map(
          (turn) =>
              'R${turn.round}:${compact(visibleAction(turn), maxChars: 64)}',
        )
        .where((line) => !line.endsWith(':'))
        .join(' / ');

    return DynamicRoleAgentOutput(
      characterId: member.characterId,
      name: member.name,
      text: [
        '立场：$stance',
        '动作：$action',
        '禁忌：$taboo',
        if (turns.map((t) => t.proseFragment).any((v) => v.trim().isNotEmpty))
          '正文片段：${turns.map((t) => t.proseFragment.trim()).where((v) => v.isNotEmpty).join('\n\n')}',
        if (process.isNotEmpty) '过程：$process',
        '局面：${compact(sceneState, maxChars: 120)}',
      ].join('\n'),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared formatting helpers (used across multiple roleplay classes)
  // ---------------------------------------------------------------------------

  /// Combines [SceneRoleplayTurn.visibleAction] and dialogue into a single
  /// readable action string.
  static String visibleAction(SceneRoleplayTurn turn) {
    final parts = <String>[
      if (turn.visibleAction.trim().isNotEmpty) turn.visibleAction.trim(),
      if (turn.dialogue.trim().isNotEmpty) '说"${turn.dialogue.trim()}"',
    ];
    return parts.join('，');
  }

  /// Returns the Chinese label for a [SceneCastContribution] value.
  static String contributionLabel(SceneCastContribution contribution) {
    return switch (contribution) {
      SceneCastContribution.action => '行动',
      SceneCastContribution.dialogue => '对白',
      SceneCastContribution.interaction => '互动',
    };
  }

  /// Joins a member's contributions into a slash-separated label string.
  static String partsForContributions(ResolvedSceneCastMember member) {
    if (member.contributions.isEmpty) return '';
    return member.contributions.map(contributionLabel).join('/');
  }

  /// Returns the first non-empty, non-whitespace string in [values].
  static String firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  /// Truncates [value] to [maxChars], appending `...` when truncated.
  static String compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }

  /// FNV-1a 32-bit hash for generating stable content hashes.
  static String stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  // ---------------------------------------------------------------------------
  // Metadata parsing helpers
  // ---------------------------------------------------------------------------

  /// Extracts a non-empty trimmed string from [raw], or `null`.
  static String? metadataString(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  /// Parses [raw] as an `int`, or returns `null`.
  static int? metadataInt(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  /// Parses [raw] as a `bool`, or returns `null`.
  static bool? metadataBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      return switch (normalized) {
        '1' => true,
        'true' => true,
        'yes' => true,
        'on' => true,
        '0' => false,
        'false' => false,
        'no' => false,
        'off' => false,
        _ => null,
      };
    }
    return null;
  }
}
