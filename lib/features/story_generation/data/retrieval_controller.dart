import 'scene_pipeline_models.dart';

/// Allowed retrieval tool names.
const _allowedTools = <String>{
  RetrievalIntent.kToolCharacterProfile,
  RetrievalIntent.kToolRelationship,
  RetrievalIntent.kToolWorldSetting,
  RetrievalIntent.kToolPastEvent,
};

/// Maximum capsules per retrieval cycle to keep prompts bounded.
const int _maxCapsulesPerCycle = 4;

/// Maximum character budget for a single capsule summary.
const int _capsuleSummaryCharBudget = 120;

/// Controller-managed pseudo toolcalling loop.
///
/// Role agents emit [RetrievalIntent]s; this controller:
/// 1. Filters to allowed tools only.
/// 2. Executes retrieval from [SceneTaskCard] data.
/// 3. Compresses results into [ContextCapsule] summaries.
/// 4. Returns capsules for injection into active prompts.
class RetrievalController {
  const RetrievalController();

  /// Process all retrieval intents from [turns] against [taskCard].
  ///
  /// Returns a deduplicated, bounded list of capsules ordered by appearance.
  /// Raw tool results never enter permanent message history.
  List<ContextCapsule> resolve({
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> turns,
  }) {
    final seen = <String>{};
    final capsules = <ContextCapsule>[];

    for (final turn in turns) {
      for (final intent in turn.retrievalIntents) {
        if (!_allowedTools.contains(intent.toolName)) continue;
        final key = '${intent.toolName}:${intent.query}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final summary = _executeTool(taskCard: taskCard, intent: intent);
        if (summary.isEmpty) continue;

        capsules.add(ContextCapsule(
          intent: intent,
          summary: _compress(summary),
          tokenBudget: _capsuleSummaryCharBudget,
        ));

        if (capsules.length >= _maxCapsulesPerCycle) {
          return List<ContextCapsule>.unmodifiable(capsules);
        }
      }
    }

    return List<ContextCapsule>.unmodifiable(capsules);
  }

  /// Execute a single retrieval tool against the task card.
  String _executeTool({
    required SceneTaskCard taskCard,
    required RetrievalIntent intent,
  }) {
    return switch (intent.toolName) {
      RetrievalIntent.kToolCharacterProfile => _retrieveProfile(
        taskCard: taskCard,
        query: intent.query,
      ),
      RetrievalIntent.kToolRelationship => _retrieveRelationship(
        taskCard: taskCard,
        query: intent.query,
      ),
      RetrievalIntent.kToolWorldSetting => _retrieveWorldSetting(
        taskCard: taskCard,
        query: intent.query,
      ),
      RetrievalIntent.kToolPastEvent => _retrieveKnowledge(
        taskCard: taskCard,
        query: intent.query,
      ),
      _ => '',
    };
  }

  String _retrieveProfile({
    required SceneTaskCard taskCard,
    required String query,
  }) {
    final parts = <String>[];
    for (final member in taskCard.cast) {
      if (_matches(query, member.name) ||
          _matches(query, member.characterId)) {
        parts.add('${member.name}(${member.role})');
        final beliefs = taskCard.beliefsFor(member.characterId);
        if (beliefs.isNotEmpty) {
          parts.add(beliefs
              .map((b) => '${b.aspect}：${b.value}')
              .join('；'));
        }
        final sp = taskCard.socialPositionFor(member.characterId);
        if (sp != null) {
          parts.add('地位：${sp.formalRank}/影响力：${sp.actualInfluence}');
        }
      }
    }
    return parts.join('\n');
  }

  String _retrieveRelationship({
    required SceneTaskCard taskCard,
    required String query,
  }) {
    final parts = <String>[];
    for (final r in taskCard.relationships) {
      if (_matches(query, r.characterA) ||
          _matches(query, r.characterB) ||
          _matches(query, r.label)) {
        parts.add(
          '${r.characterA}↔${r.characterB}：${r.label}'
          '（张力${r.tension}/信任${r.trust}）',
        );
      }
    }
    return parts.join('\n');
  }

  String _retrieveWorldSetting({
    required SceneTaskCard taskCard,
    required String query,
  }) {
    final parts = <String>[];
    for (final nodeId in taskCard.brief.worldNodeIds) {
      if (_matches(query, nodeId)) {
        parts.add('世界设定：$nodeId');
      }
    }
    if (taskCard.directorPlan.isNotEmpty) {
      parts.add('导演计划：${taskCard.directorPlan}');
    }
    return parts.join('\n');
  }

  String _retrieveKnowledge({
    required SceneTaskCard taskCard,
    required String query,
  }) {
    final parts = <String>[];
    for (final atom in taskCard.knowledge) {
      if (_matches(query, atom.content) ||
          _matches(query, atom.category) ||
          _matches(query, atom.sourceId)) {
        parts.add(atom.content);
      }
    }
    return parts.join('\n');
  }

  bool _matches(String query, String target) {
    final q = query.trim().toLowerCase();
    final t = target.trim().toLowerCase();
    return q.isNotEmpty && t.contains(q);
  }

  String _compress(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _capsuleSummaryCharBudget) return normalized;
    return '${normalized.substring(0, _capsuleSummaryCharBudget - 3)}...';
  }
}
