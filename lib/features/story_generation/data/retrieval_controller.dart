import 'scene_pipeline_models.dart';
import 'material_reference_retriever.dart';

/// Allowed retrieval tool names when writing reference is enabled.
const _allowedToolsWithWritingRef = <String>{
  LightRetrievalIntent.kToolStructuredProfile,
  LightRetrievalIntent.kToolRelationship,
  LightRetrievalIntent.kToolWorldSetting,
  LightRetrievalIntent.kToolPastEvent,
  LightRetrievalIntent.kToolWritingReference,
};

/// Allowed retrieval tool names when writing reference is disabled.
const _allowedToolsWithoutWritingRef = <String>{
  LightRetrievalIntent.kToolStructuredProfile,
  LightRetrievalIntent.kToolRelationship,
  LightRetrievalIntent.kToolWorldSetting,
  LightRetrievalIntent.kToolPastEvent,
};

/// Maximum capsules per retrieval cycle to keep prompts bounded.
const int _maxCapsulesPerCycle = 4;

/// Maximum character budget for a single capsule summary.
const int _capsuleSummaryCharBudget = 120;

/// Controller-managed pseudo toolcalling loop.
///
/// Role agents emit [LightRetrievalIntent]s; this controller:
/// 1. Filters to allowed tools only.
/// 2. Executes retrieval from [SceneTaskCard] data.
/// 3. Compresses results into [LightContextCapsule] summaries.
/// 4. Returns capsules for injection into active prompts.
class RetrievalController {
  const RetrievalController({
    MaterialReferenceRetriever? materialReferenceRetriever,
    bool? enableWritingReference,
  }) : _materialReferenceRetriever = materialReferenceRetriever,
       _enableWritingReference =
           enableWritingReference ?? materialReferenceRetriever != null;

  final MaterialReferenceRetriever? _materialReferenceRetriever;
  final bool _enableWritingReference;

  /// Process all retrieval intents from [turns] against [taskCard].
  ///
  /// Returns a deduplicated, bounded list of capsules ordered by appearance.
  /// Raw tool results never enter permanent message history.
  List<LightContextCapsule> resolve({
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> turns,
  }) {
    final seen = <String>{};
    final capsules = <LightContextCapsule>[];
    final allowedTools = _enableWritingReference
        ? _allowedToolsWithWritingRef
        : _allowedToolsWithoutWritingRef;

    for (final turn in turns) {
      for (final intent in turn.retrievalIntents) {
        if (!allowedTools.contains(intent.toolName)) continue;
        final key = '${intent.toolName}:${intent.query}';
        if (seen.contains(key)) continue;
        seen.add(key);

        final summary = _executeTool(taskCard: taskCard, intent: intent);
        if (summary.isEmpty) continue;

        capsules.add(
          LightContextCapsule(
            intent: intent,
            summary: _compress(summary),
            tokenBudget: _capsuleSummaryCharBudget,
          ),
        );

        if (capsules.length >= _maxCapsulesPerCycle) {
          return List<LightContextCapsule>.unmodifiable(capsules);
        }
      }
    }

    return List<LightContextCapsule>.unmodifiable(capsules);
  }

  /// Execute a single retrieval tool against the task card.
  String _executeTool({
    required SceneTaskCard taskCard,
    required LightRetrievalIntent intent,
  }) {
    return switch (intent.toolName) {
      LightRetrievalIntent.kToolStructuredProfile => _retrieveProfile(
        taskCard: taskCard,
        query: intent.query,
      ),
      LightRetrievalIntent.kToolRelationship => _retrieveRelationship(
        taskCard: taskCard,
        query: intent.query,
      ),
      LightRetrievalIntent.kToolWorldSetting => _retrieveWorldSetting(
        taskCard: taskCard,
        query: intent.query,
      ),
      LightRetrievalIntent.kToolPastEvent => _retrieveKnowledge(
        taskCard: taskCard,
        query: intent.query,
      ),
      LightRetrievalIntent.kToolWritingReference => _retrieveWritingReference(
        intent: intent,
      ),
      _ => '',
    };
  }

  String _retrieveWritingReference({required LightRetrievalIntent intent}) {
    if (!_enableWritingReference) return '';
    final retriever = _materialReferenceRetriever;
    if (retriever == null) return '';
    return retriever.searchToSceneSummary(intent);
  }

  String _retrieveProfile({
    required SceneTaskCard taskCard,
    required String query,
  }) {
    final parts = <String>[];
    for (final member in taskCard.cast) {
      if (_matches(query, member.name) || _matches(query, member.characterId)) {
        parts.add('${member.name}(${member.role})');
        final beliefs = taskCard.beliefsFor(member.characterId);
        if (beliefs.isNotEmpty) {
          parts.add(beliefs.map((b) => b.claim).join('；'));
        }
        final sp = taskCard.socialPositionFor(member.characterId);
        if (sp != null) {
          parts.add('地位：${sp.notes}');
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
      if (_matches(query, r.characterId) ||
          _matches(query, r.otherId) ||
          _matches(query, r.kind)) {
        parts.add(
          '${r.characterId}↔${r.otherId}：${r.kind}'
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
