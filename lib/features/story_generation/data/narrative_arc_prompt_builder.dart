import 'narrative_arc_models.dart';

/// Builds narrative arc context for injection into scene prompts.
///
/// Extracts active threads, urgent foreshadowing, and recent resolutions
/// from [NarrativeArcState] to provide focused, scene-relevant context.
class NarrativeArcPromptBuilder {
  NarrativeArcPromptBuilder();

  /// Build a compact narrative arc context string for the given state.
  ///
  /// Returns null when the state has no useful information.
  String? buildArcContext(NarrativeArcState arc) {
    if (arc.activeThreads.isEmpty &&
        arc.pendingForeshadowing.isEmpty &&
        arc.closedThreads.isEmpty) {
      return null;
    }

    final parts = <String>[];

    // Active plot threads
    if (arc.activeThreads.isNotEmpty) {
      parts.add('【活跃剧情线】');
      for (final thread in arc.activeThreads.take(5)) {
        parts.add(
          '- ${thread.description}'
          '${thread.involvedCharacters.isNotEmpty ? ' (涉及: ${thread.involvedCharacters.join(", ")})' : ''}',
        );
      }
    }

    // Unresolved foreshadowing — prioritize high-urgency items
    final unresolved = arc.pendingForeshadowing
        .where((f) => f.resolvedInScene == null)
        .toList();
    if (unresolved.isNotEmpty) {
      final urgent = unresolved.where((f) => f.urgency >= 3).toList();
      final items = urgent.isNotEmpty ? urgent : unresolved;
      parts.add('【待回收伏笔】');
      for (final item in items.take(4)) {
        parts.add(
          '- ${item.hint}'
          '${item.plannedPayoff.isNotEmpty ? ' (预计回收: ${item.plannedPayoff})' : ''}'
          '${item.urgency >= 3 ? ' [紧迫]' : ''}',
        );
      }
    }

    // Recently closed threads — remind what was just resolved
    if (arc.closedThreads.isNotEmpty) {
      parts.add('【近期收束】');
      for (final thread in arc.closedThreads.take(3)) {
        parts.add(
          '- ${thread.description}'
          '${thread.resolvedInScene != null ? ' (已在 ${thread.resolvedInScene} 收束)' : ''}',
        );
      }
    }

    if (parts.length <= 1) return null;
    return parts.join('\n');
  }
}
