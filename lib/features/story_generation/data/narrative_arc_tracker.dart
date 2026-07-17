import 'story_generation_models.dart';

class NarrativeArcTracker {
  NarrativeArcState update({
    required NarrativeArcState current,
    required SceneRuntimeOutput output,
  }) {
    final sceneKey = '${output.brief.chapterId}/${output.brief.sceneId}';
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

    // Fix 5a: prose-based thread resolution for threads created via fallback.
    _checkThreadResolution(
      prose: output.prose.text,
      sceneKey: sceneKey,
      updatedThreads: updatedThreads,
      closedThreads: closedThreads,
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
    final sceneKey = '${output.brief.chapterId}/${output.brief.sceneId}';
    final resolvedDeltas = output.sceneState?.acceptedStateDeltas ?? const [];

    for (final delta in resolvedDeltas) {
      if (delta.kind == SceneStateDeltaKind.alliance) {
        final involved = _charactersInText(delta.value, output.resolvedCast);
        final threadId =
            'thread-$sceneKey-${delta.kind.name}-${involved.join('-')}';
        newThreads.add(
          PlotThread(
            id: threadId,
            description: delta.value,
            status: PlotThreadStatus.rising,
            involvedCharacters: involved,
            introducedInScene: sceneKey,
          ),
        );
      }

      if (delta.kind == SceneStateDeltaKind.exposure) {
        final involved = _charactersInText(delta.value, output.resolvedCast);
        final threadId =
            'thread-$sceneKey-${delta.kind.name}-${involved.join('-')}';
        final existing = updatedThreads
            .where((t) => t.description.contains(delta.value))
            .toList(growable: false);
        if (existing.isNotEmpty) {
          final idx = updatedThreads.indexOf(existing.first);
          updatedThreads[idx] = existing.first.copyWith(
            status: PlotThreadStatus.climax,
          );
        } else {
          newThreads.add(
            PlotThread(
              id: threadId,
              description: delta.value,
              status: PlotThreadStatus.climax,
              involvedCharacters: involved,
              introducedInScene: sceneKey,
            ),
          );
        }
      }

      if (delta.kind == SceneStateDeltaKind.control) {
        final existing = updatedThreads
            .where(
              (t) =>
                  t.status != PlotThreadStatus.resolved &&
                  _overlapsCharacters(
                    t.involvedCharacters,
                    _charactersInText(delta.value, output.resolvedCast),
                  ),
            )
            .toList(growable: false);
        for (final thread in existing) {
          final idx = updatedThreads.indexOf(thread);
          if (thread.status == PlotThreadStatus.falling) {
            updatedThreads.removeAt(idx);
            closedThreads.add(
              thread.copyWith(
                status: PlotThreadStatus.resolved,
                resolvedInScene: sceneKey,
              ),
            );
          } else {
            updatedThreads[idx] = thread.copyWith(
              status: PlotThreadStatus.falling,
            );
          }
        }
      }
    }

    // Fallback: if no state deltas produced threads, extract from prose text
    if (newThreads.isEmpty && updatedThreads.isEmpty) {
      _extractThreadsFromProse(
        output: output,
        newThreads: newThreads,
        sceneKey: sceneKey,
      );
    }
  }

  void _extractForeshadowingChanges({
    required SceneRuntimeOutput output,
    required List<Foreshadowing> newForeshadowing,
    required List<Foreshadowing> updatedForeshadowing,
    required List<Foreshadowing> currentForeshadowing,
  }) {
    final sceneKey = '${output.brief.chapterId}/${output.brief.sceneId}';

    for (final turn in output.roleTurns) {
      for (final withheld in turn.withheldInfo) {
        if (withheld.trim().isEmpty) continue;
        newForeshadowing.add(
          Foreshadowing(
            id: 'foreshadow-$sceneKey-${turn.characterId}-${newForeshadowing.length}',
            hint: withheld.trim(),
            plantedInScene: sceneKey,
            plannedPayoff: turn.intent.trim(),
            urgency: 0,
          ),
        );
      }
      if (turn.riskTaken.trim().isNotEmpty) {
        newForeshadowing.add(
          Foreshadowing(
            id: 'foreshadow-$sceneKey-${turn.characterId}-risk-${newForeshadowing.length}',
            hint: turn.riskTaken.trim(),
            plantedInScene: sceneKey,
            plannedPayoff: turn.intent.trim(),
            urgency: 1,
          ),
        );
      }
    }

    final openThreats = output.sceneState?.openThreats ?? const [];
    for (final existing in currentForeshadowing) {
      if (existing.resolvedInScene != null) {
        updatedForeshadowing.add(existing);
        continue;
      }
      final isResolved = openThreats.any(
        (threat) =>
            threat.contains(existing.hint) || existing.hint.contains(threat),
      );
      if (isResolved) {
        updatedForeshadowing.add(existing.copyWith(resolvedInScene: sceneKey));
      } else {
        final newUrgency = existing.urgency < 2 ? existing.urgency + 1 : 2;
        updatedForeshadowing.add(existing.copyWith(urgency: newUrgency));
      }
    }

    // Fix 5b: prose-based foreshadowing extraction when roleplay fields are empty.
    if (newForeshadowing.isEmpty) {
      final text = output.prose.text;
      if (text.isNotEmpty) {
        final foreshadowPatterns = [
          RegExp(r'尚未(.{2,10})'),
          RegExp(r'还(没|未)(.{2,10})'),
          RegExp(r'隐藏.{0,4}(.{2,15})'),
          RegExp(r'不(敢|愿)说.{0,4}(.{2,15})'),
        ];
        for (final pattern in foreshadowPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            newForeshadowing.add(
              Foreshadowing(
                id: 'foreshadow-$sceneKey-prose-${newForeshadowing.length}',
                hint: match.group(0)!,
                plantedInScene: sceneKey,
                plannedPayoff: output.brief.sceneSummary,
                urgency: 1,
              ),
            );
            break;
          }
        }
      }
    }
  }

  void _extractThreadsFromProse({
    required SceneRuntimeOutput output,
    required List<PlotThread> newThreads,
    required String sceneKey,
  }) {
    final text = output.prose.text;
    if (text.isEmpty) return;

    // Narrative development keywords and their implied thread status
    final plotMarkers = <(String, PlotThreadStatus)>[
      ('发现', PlotThreadStatus.rising),
      ('揭露', PlotThreadStatus.rising),
      ('暴露', PlotThreadStatus.climax),
      ('冲突', PlotThreadStatus.climax),
      ('解决', PlotThreadStatus.falling),
      ('真相', PlotThreadStatus.rising),
      ('背叛', PlotThreadStatus.climax),
      ('威胁', PlotThreadStatus.rising),
      ('追击', PlotThreadStatus.climax),
      ('逃亡', PlotThreadStatus.climax),
      ('计划', PlotThreadStatus.rising),
      ('行动', PlotThreadStatus.rising),
      ('对峙', PlotThreadStatus.climax),
      ('陷阱', PlotThreadStatus.climax),
      ('线索', PlotThreadStatus.rising),
      ('证据', PlotThreadStatus.rising),
    ];

    final involved = _charactersInText(text, output.resolvedCast);
    if (involved.isEmpty) return;

    for (final (keyword, status) in plotMarkers) {
      if (text.contains(keyword)) {
        final threadId =
            'thread-$sceneKey-prose-$keyword-${involved.join('-')}';
        if (!newThreads.any((t) => t.id == threadId)) {
          newThreads.add(
            PlotThread(
              id: threadId,
              description: '$keyword: ${output.brief.sceneSummary}',
              status: status,
              involvedCharacters: involved,
              introducedInScene: sceneKey,
            ),
          );
        }
        break; // One prose-derived thread per scene is sufficient
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

  /// Fix 5a: Check if active threads can be advanced/resolved via prose text.
  void _checkThreadResolution({
    required String prose,
    required String sceneKey,
    required List<PlotThread> updatedThreads,
    required List<PlotThread> closedThreads,
  }) {
    const resolutionMarkers = [
      '真相大白',
      '水落石出',
      '终于明白',
      '谜底揭晓',
      '原来如此',
      '一切都清楚了',
      '找到了答案',
      '尘埃落定',
    ];
    const fallingMarkers = ['撤退', '放弃', '妥协', '让步', '逃离', '消失在'];

    final hasResolution = resolutionMarkers.any((m) => prose.contains(m));
    final hasFalling = fallingMarkers.any((m) => prose.contains(m));
    if (!hasResolution && !hasFalling) return;

    for (int i = updatedThreads.length - 1; i >= 0; i--) {
      final thread = updatedThreads[i];
      if (thread.resolvedInScene != null) continue;
      if (hasResolution && thread.status == PlotThreadStatus.falling) {
        updatedThreads.removeAt(i);
        closedThreads.add(
          thread.copyWith(
            status: PlotThreadStatus.resolved,
            resolvedInScene: sceneKey,
          ),
        );
      } else if (hasFalling && thread.status == PlotThreadStatus.climax) {
        updatedThreads[i] = thread.copyWith(status: PlotThreadStatus.falling);
      }
    }
  }

  bool _overlapsCharacters(List<String> a, List<String> b) {
    return a.any((id) => b.contains(id));
  }
}
