import 'story_generation_models.dart';

class NarrativeArcTracker {
  NarrativeArcState update({
    required NarrativeArcState current,
    required SceneRuntimeOutput output,
  }) {
    final newThreads = <PlotThread>[];
    final updatedThreads = <PlotThread>[...current.activeThreads];
    final closedThreads = <PlotThread>[...current.closedThreads];
    final newForeshadowing = <Foreshadowing>[];
    final updatedForeshadowing = <Foreshadowing>[];

    _extractThreadChanges(
      output: output,
      newThreads: newThreads,
      updatedThreads: updatedThreads,
      closedThreads: closedThreads,
    );

    _extractForeshadowingChanges(
      output: output,
      newForeshadowing: newForeshadowing,
      updatedForeshadowing: updatedForeshadowing,
      currentForeshadowing: current.pendingForeshadowing,
    );

    return current.copyWith(
      activeThreads: [...updatedThreads, ...newThreads],
      closedThreads: closedThreads,
      pendingForeshadowing: [...updatedForeshadowing, ...newForeshadowing],
      chapterIndex: current.chapterIndex,
    );
  }

  void _extractThreadChanges({
    required SceneRuntimeOutput output,
    required List<PlotThread> newThreads,
    required List<PlotThread> updatedThreads,
    required List<PlotThread> closedThreads,
  }) {
    final sceneKey =
        '${output.brief.chapterId}/${output.brief.sceneId}';
    final resolvedDeltas =
        output.sceneState?.acceptedStateDeltas ?? const [];

    for (final delta in resolvedDeltas) {
      if (delta.kind == SceneStateDeltaKind.alliance) {
        final involved = _charactersInText(
          delta.value,
          output.resolvedCast,
        );
        final threadId = 'thread-$sceneKey-${delta.kind.name}-${involved.join('-')}';
        newThreads.add(PlotThread(
          id: threadId,
          description: delta.value,
          status: PlotThreadStatus.rising,
          involvedCharacters: involved,
          introducedInScene: sceneKey,
        ));
      }

      if (delta.kind == SceneStateDeltaKind.exposure) {
        final involved = _charactersInText(
          delta.value,
          output.resolvedCast,
        );
        final threadId = 'thread-$sceneKey-${delta.kind.name}-${involved.join('-')}';
        final existing = updatedThreads
            .where((t) => t.description.contains(delta.value))
            .toList(growable: false);
        if (existing.isNotEmpty) {
          final idx = updatedThreads.indexOf(existing.first);
          updatedThreads[idx] = existing.first.copyWith(
            status: PlotThreadStatus.climax,
          );
        } else {
          newThreads.add(PlotThread(
            id: threadId,
            description: delta.value,
            status: PlotThreadStatus.climax,
            involvedCharacters: involved,
            introducedInScene: sceneKey,
          ));
        }
      }

      if (delta.kind == SceneStateDeltaKind.control) {
        final existing = updatedThreads
            .where((t) =>
                t.status != PlotThreadStatus.resolved &&
                _overlapsCharacters(
                  t.involvedCharacters,
                  _charactersInText(
                    delta.value,
                    output.resolvedCast,
                  ),
                ))
            .toList(growable: false);
        for (final thread in existing) {
          final idx = updatedThreads.indexOf(thread);
          if (thread.status == PlotThreadStatus.falling) {
            updatedThreads.removeAt(idx);
            closedThreads.add(thread.copyWith(
              status: PlotThreadStatus.resolved,
              resolvedInScene: sceneKey,
            ));
          } else {
            updatedThreads[idx] = thread.copyWith(
              status: PlotThreadStatus.falling,
            );
          }
        }
      }
    }
  }

  void _extractForeshadowingChanges({
    required SceneRuntimeOutput output,
    required List<Foreshadowing> newForeshadowing,
    required List<Foreshadowing> updatedForeshadowing,
    required List<Foreshadowing> currentForeshadowing,
  }) {
    final sceneKey =
        '${output.brief.chapterId}/${output.brief.sceneId}';

    for (final turn in output.roleTurns) {
      for (final withheld in turn.withheldInfo) {
        if (withheld.trim().isEmpty) continue;
        newForeshadowing.add(Foreshadowing(
          id: 'foreshadow-$sceneKey-${turn.characterId}-${newForeshadowing.length}',
          hint: withheld.trim(),
          plantedInScene: sceneKey,
          plannedPayoff: turn.intent.trim(),
          urgency: 0,
        ));
      }
      if (turn.riskTaken.trim().isNotEmpty) {
        newForeshadowing.add(Foreshadowing(
          id: 'foreshadow-$sceneKey-${turn.characterId}-risk-${newForeshadowing.length}',
          hint: turn.riskTaken.trim(),
          plantedInScene: sceneKey,
          plannedPayoff: turn.intent.trim(),
          urgency: 1,
        ));
      }
    }

    final openThreats = output.sceneState?.openThreats ?? const [];
    for (final existing in currentForeshadowing) {
      if (existing.resolvedInScene != null) {
        updatedForeshadowing.add(existing);
        continue;
      }
      final isResolved = openThreats.any(
        (threat) => threat.contains(existing.hint) || existing.hint.contains(threat),
      );
      if (isResolved) {
        updatedForeshadowing.add(existing.copyWith(
          resolvedInScene: sceneKey,
        ));
      } else {
        final newUrgency = existing.urgency < 2 ? existing.urgency + 1 : 2;
        updatedForeshadowing.add(existing.copyWith(urgency: newUrgency));
      }
    }
  }

  List<String> _charactersInText(
    String text,
    List<ResolvedSceneCastMember> cast,
  ) {
    return cast
        .where((member) => text.contains(member.name))
        .map((member) => member.characterId)
        .toList(growable: false);
  }

  bool _overlapsCharacters(List<String> a, List<String> b) {
    return a.any((id) => b.contains(id));
  }
}
