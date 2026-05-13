import 'scene_pipeline_models.dart' show SceneTaskCard;
import 'scene_roleplay_session_models.dart';
import '../domain/scene_models.dart';

class SceneRoleplaySpeakerPlan {
  SceneRoleplaySpeakerPlan({
    required this.strategy,
    required List<ResolvedSceneCastMember> speakers,
  }) : speakers = List.unmodifiable(speakers);

  final String strategy;
  final List<ResolvedSceneCastMember> speakers;
}

class SceneRoleplaySpeakerScheduler {
  const SceneRoleplaySpeakerScheduler();

  SceneRoleplaySpeakerPlan planRound({
    required SceneBrief brief,
    required SceneTaskCard? taskCard,
    required List<ResolvedSceneCastMember> cast,
    required int round,
    required List<SceneRoleplayTurn> transcript,
  }) {
    final metadata = _mergedMetadata(brief: brief, taskCard: taskCard);
    final strategy =
        (_metadataString(metadata['roleplaySpeakerStrategy']) ??
                _metadataString(metadata['groupReplyStrategy']) ??
                'list')
            .toLowerCase()
            .replaceAll(RegExp(r'[\s_-]+'), '');
    final muted = _stringSet(
      metadata['roleplayMutedCharacterIds'] ??
          metadata['mutedRoleIds'] ??
          metadata['disabledRoleIds'],
    );
    final maxSpeakers = _metadataInt(metadata['roleplayMaxSpeakersPerRound']);
    final enabled = [
      for (final member in cast)
        if (!muted.contains(member.characterId) && !muted.contains(member.name))
          member,
    ];
    final explicitlyOrdered = _applyExplicitOrder(
      enabled,
      metadata['roleplaySpeakerOrder'] ?? metadata['speakerOrder'],
    );
    final scheduled = switch (strategy) {
      'pooled' => _pooledOrder(explicitlyOrdered, transcript),
      'single' => explicitlyOrdered.take(1).toList(),
      'manual' => explicitlyOrdered.take(1).toList(),
      'naturalorder' => explicitlyOrdered,
      'listorder' => explicitlyOrdered,
      _ => explicitlyOrdered,
    };
    final limited = maxSpeakers == null || maxSpeakers <= 0
        ? scheduled
        : scheduled.take(maxSpeakers).toList();
    return SceneRoleplaySpeakerPlan(strategy: strategy, speakers: limited);
  }

  Map<String, Object?> _mergedMetadata({
    required SceneBrief brief,
    required SceneTaskCard? taskCard,
  }) {
    return <String, Object?>{
      ...brief.metadata,
      if (taskCard != null) ...taskCard.metadata,
    };
  }

  List<ResolvedSceneCastMember> _applyExplicitOrder(
    List<ResolvedSceneCastMember> cast,
    Object? rawOrder,
  ) {
    final order = _stringList(rawOrder);
    if (order.isEmpty) return cast;
    final remaining = [...cast];
    final ordered = <ResolvedSceneCastMember>[];
    for (final key in order) {
      final index = remaining.indexWhere(
        (member) => member.characterId == key || member.name == key,
      );
      if (index < 0) continue;
      ordered.add(remaining.removeAt(index));
    }
    ordered.addAll(remaining);
    return ordered;
  }

  List<ResolvedSceneCastMember> _pooledOrder(
    List<ResolvedSceneCastMember> cast,
    List<SceneRoleplayTurn> transcript,
  ) {
    if (cast.isEmpty) return const <ResolvedSceneCastMember>[];
    final turnCounts = <String, int>{
      for (final member in cast) member.characterId: 0,
    };
    for (final turn in transcript) {
      if (turnCounts.containsKey(turn.characterId)) {
        turnCounts[turn.characterId] = turnCounts[turn.characterId]! + 1;
      }
    }
    final leastTurns = turnCounts.values.fold<int?>(
      null,
      (least, value) => least == null || value < least ? value : least,
    );
    return [
      for (final member in cast)
        if (turnCounts[member.characterId] == leastTurns) member,
    ].take(1).toList();
  }

  String? _metadataString(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  int? _metadataInt(Object? raw) {
    return switch (raw) {
      final int value => value,
      final num value => value.toInt(),
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
  }

  Set<String> _stringSet(Object? raw) => _stringList(raw).toSet();

  List<String> _stringList(Object? raw) {
    if (raw is String) {
      return raw
          .split(RegExp(r'[,，\n]'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (raw is List) {
      return [
        for (final value in raw)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      ];
    }
    return const <String>[];
  }
}
