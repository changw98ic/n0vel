import 'package:novel_writer/app/state/app_storage_clone.dart';

enum PlotThreadStatus { rising, climax, falling, resolved }

class PlotThread {
  PlotThread({
    required this.id,
    required this.description,
    required this.status,
    List<String> involvedCharacters = const [],
    required this.introducedInScene,
    this.resolvedInScene,
  }) : involvedCharacters = immutableList(involvedCharacters);

  final String id;
  final String description;
  final PlotThreadStatus status;
  final List<String> involvedCharacters;
  final String introducedInScene;
  final String? resolvedInScene;

  PlotThread copyWith({
    PlotThreadStatus? status,
    String? resolvedInScene,
  }) {
    return PlotThread(
      id: id,
      description: description,
      status: status ?? this.status,
      involvedCharacters: involvedCharacters,
      introducedInScene: introducedInScene,
      resolvedInScene: resolvedInScene ?? this.resolvedInScene,
    );
  }
}

class Foreshadowing {
  Foreshadowing({
    required this.id,
    required this.hint,
    required this.plantedInScene,
    this.plannedPayoff = '',
    this.resolvedInScene,
    this.urgency = 0,
  });

  final String id;
  final String hint;
  final String plannedPayoff;
  final String plantedInScene;
  final String? resolvedInScene;
  final int urgency;

  Foreshadowing copyWith({
    String? resolvedInScene,
    int? urgency,
  }) {
    return Foreshadowing(
      id: id,
      hint: hint,
      plannedPayoff: plannedPayoff,
      plantedInScene: plantedInScene,
      resolvedInScene: resolvedInScene ?? this.resolvedInScene,
      urgency: urgency ?? this.urgency,
    );
  }
}

class NarrativeArcState {
  NarrativeArcState({
    List<PlotThread> activeThreads = const [],
    List<PlotThread> closedThreads = const [],
    List<Foreshadowing> pendingForeshadowing = const [],
    List<String> thematicArcs = const [],
    this.chapterIndex = 0,
  }) : activeThreads = immutableList(activeThreads),
       closedThreads = immutableList(closedThreads),
       pendingForeshadowing = immutableList(pendingForeshadowing),
       thematicArcs = immutableList(thematicArcs);

  final List<PlotThread> activeThreads;
  final List<PlotThread> closedThreads;
  final List<Foreshadowing> pendingForeshadowing;
  final List<String> thematicArcs;
  final int chapterIndex;

  NarrativeArcState copyWith({
    List<PlotThread>? activeThreads,
    List<PlotThread>? closedThreads,
    List<Foreshadowing>? pendingForeshadowing,
    List<String>? thematicArcs,
    int? chapterIndex,
  }) {
    return NarrativeArcState(
      activeThreads: activeThreads ?? this.activeThreads,
      closedThreads: closedThreads ?? this.closedThreads,
      pendingForeshadowing: pendingForeshadowing ?? this.pendingForeshadowing,
      thematicArcs: thematicArcs ?? this.thematicArcs,
      chapterIndex: chapterIndex ?? this.chapterIndex,
    );
  }

  String toPromptText() {
    final parts = <String>[];
    if (activeThreads.isNotEmpty) {
      parts.add('活跃情节线：${activeThreads.map((t) => '${t.description}(${t.status.name})').join('；')}');
    }
    if (pendingForeshadowing.isNotEmpty) {
      final unresolved = pendingForeshadowing
          .where((f) => f.resolvedInScene == null)
          .toList(growable: false);
      if (unresolved.isNotEmpty) {
        parts.add(
          '待回收伏笔：${unresolved.map((f) => f.urgency >= 2 ? '【紧急】${f.hint}' : f.urgency == 1 ? '${f.hint}(应尽快回收)' : f.hint).join('；')}',
        );
      }
    }
    if (thematicArcs.isNotEmpty) {
      parts.add('主题弧线：${thematicArcs.join('；')}');
    }
    return parts.isEmpty ? '' : parts.join('\n');
  }
}
