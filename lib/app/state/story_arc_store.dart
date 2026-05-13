import 'dart:async';

import '../events/app_domain_events.dart';
import '../events/app_event_bus.dart';
import 'app_store_listenable.dart';
import 'app_workspace_store.dart';
import 'persist_guard.dart';
import 'story_arc_storage.dart';
import '../../features/story_generation/data/narrative_arc_models.dart';

const String _fallbackStoryArcProjectId = 'project-yuechao';

/// 故事弧线状态快照
///
/// 包含情节线（PlotThread）、伏笔（Foreshadowing）、主题弧线等，
/// 以及场景顺序信息，支持版本管理和撤销。
class StoryArcSnapshot {
  const StoryArcSnapshot({
    required this.projectId,
    this.narrativeArcState = const _DefaultNarrativeArcState(),
    this.sceneOrder = const [],
    this.undoStack = const [],
  });

  final String projectId;
  final NarrativeArcState narrativeArcState;

  /// 场景 ID 的有序列表，拖拽排序后回写。
  final List<String> sceneOrder;

  /// 撤销栈，保存历史快照（最多保留 20 步）。
  final List<NarrativeArcState> undoStack;

  StoryArcSnapshot copyWith({
    String? projectId,
    NarrativeArcState? narrativeArcState,
    List<String>? sceneOrder,
    List<NarrativeArcState>? undoStack,
  }) {
    return StoryArcSnapshot(
      projectId: projectId ?? this.projectId,
      narrativeArcState: narrativeArcState ?? this.narrativeArcState,
      sceneOrder: sceneOrder ?? this.sceneOrder,
      undoStack: undoStack ?? this.undoStack,
    );
  }

  StoryArcSnapshot deepCopy() => StoryArcSnapshot(
    projectId: projectId,
    narrativeArcState: narrativeArcState.copyWith(
      activeThreads: List.from(narrativeArcState.activeThreads),
      closedThreads: List.from(narrativeArcState.closedThreads),
      pendingForeshadowing: List.from(narrativeArcState.pendingForeshadowing),
      thematicArcs: List.from(narrativeArcState.thematicArcs),
    ),
    sceneOrder: List.from(sceneOrder),
    undoStack: List.from(undoStack),
  );

  Map<String, Object?> toJson() {
    return {
      'projectId': projectId,
      'narrativeArcState': _encodeNarrativeArcState(narrativeArcState),
      'sceneOrder': sceneOrder,
      // undoStack 不持久化——仅在内存中保留
    };
  }

  static StoryArcSnapshot fromJson(Map<String, Object?> json) {
    final projectId = json['projectId']?.toString() ?? _fallbackStoryArcProjectId;
    final stateJson = json['narrativeArcState'];
    final NarrativeArcState state;
    if (stateJson is Map) {
      state = _decodeNarrativeArcState(
        Map<String, Object?>.from(stateJson),
      );
    } else {
      state = NarrativeArcState();
    }
    final rawOrder = json['sceneOrder'];
    final sceneOrder = rawOrder is List
        ? [for (final item in rawOrder) item.toString()]
        : const <String>[];
    return StoryArcSnapshot(
      projectId: projectId,
      narrativeArcState: state,
      sceneOrder: sceneOrder,
    );
  }

  static StoryArcSnapshot empty(String projectId) =>
      StoryArcSnapshot(projectId: projectId);

  /// 获取悬空伏笔列表（未解决的 Foreshadowing）
  List<Foreshadowing> get danglingForeshadowing => [
    for (final f in narrativeArcState.pendingForeshadowing)
      if (f.resolvedInScene == null) f,
  ];

  /// 是否有悬空伏笔告警
  bool get hasDanglingForeshadowing => danglingForeshadowing.isNotEmpty;
}

// ============================================================================
// Store
// ============================================================================

class StoryArcStore extends AppStoreListenable {
  StoryArcStore({
    StoryArcStorage? storage,
    AppWorkspaceStore? workspaceStore,
    AppEventBus? eventBus,
  }) : _storage = storage ?? createDefaultStoryArcStorage(),
       _workspaceStore = workspaceStore,
       _eventBus = eventBus {
    _activeProjectId = _resolveProjectId(workspaceStore);
    _snapshot = StoryArcSnapshot.empty(_activeProjectId);
    _workspaceStore?.addListener(_handleWorkspaceChanged);
    _projectDeletedSubscription = _eventBus?.listen<ProjectDeletedEvent>(
      _handleProjectDeleted,
    );
    _readyFuture = _restore();
    unawaited(_readyFuture);
  }

  final StoryArcStorage _storage;
  final AppWorkspaceStore? _workspaceStore;
  final AppEventBus? _eventBus;
  final Map<String, StoryArcSnapshot> _snapshotsByProjectId = {};
  late String _activeProjectId;
  late StoryArcSnapshot _snapshot;
  Future<void> _readyFuture = Future<void>.value();
  int _mutationVersion = 0;
  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;

  StoryArcSnapshot get snapshot => _snapshot.deepCopy();
  String get activeProjectId => _activeProjectId;
  Future<void> get ready => _readyFuture;

  // ---------------------------------------------------------------------------
  // 撤销
  // ---------------------------------------------------------------------------

  /// 是否可撤销
  bool get canUndo => _snapshot.undoStack.isNotEmpty;

  /// 执行撤销，恢复到上一个 NarrativeArcState
  void undo() {
    if (!canUndo) return;
    final stack = List<NarrativeArcState>.from(_snapshot.undoStack);
    final previous = stack.removeLast();
    _snapshot = _snapshot.copyWith(
      narrativeArcState: previous,
      undoStack: stack,
    );
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _mutationVersion += 1;
    unawaited(safePersist(_persist, eventBus: _eventBus));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 情节线 / 伏笔更新
  // ---------------------------------------------------------------------------

  /// 用 NarrativeArcTracker 的输出更新弧线状态
  void updateArcState(NarrativeArcState next) {
    _pushUndo();
    _snapshot = _snapshot.copyWith(narrativeArcState: next);
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _mutationVersion += 1;
    unawaited(safePersist(_persist, eventBus: _eventBus));
    notifyListeners();
  }

  /// 手动修正伏笔状态（标记为已解决或调整 urgency）
  void resolveForeshadowing(String foreshadowingId, String resolvedInScene) {
    _pushUndo();
    final current = _snapshot.narrativeArcState;
    final updated = [
      for (final f in current.pendingForeshadowing)
        if (f.id == foreshadowingId)
          f.copyWith(resolvedInScene: resolvedInScene)
        else
          f,
    ];
    _snapshot = _snapshot.copyWith(
      narrativeArcState: current.copyWith(pendingForeshadowing: updated),
    );
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _mutationVersion += 1;
    unawaited(safePersist(_persist, eventBus: _eventBus));
    notifyListeners();
  }

  /// 手动调整伏笔紧急度
  void updateForeshadowingUrgency(String foreshadowingId, int urgency) {
    _pushUndo();
    final current = _snapshot.narrativeArcState;
    final updated = [
      for (final f in current.pendingForeshadowing)
        if (f.id == foreshadowingId)
          f.copyWith(urgency: urgency.clamp(0, 2))
        else
          f,
    ];
    _snapshot = _snapshot.copyWith(
      narrativeArcState: current.copyWith(pendingForeshadowing: updated),
    );
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _mutationVersion += 1;
    unawaited(safePersist(_persist, eventBus: _eventBus));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 场景排序（拖拽回写）
  // ---------------------------------------------------------------------------

  /// 重排场景顺序
  ///
  /// [newOrder] 为新的场景 ID 有序列表。
  void reorderScenes(List<String> newOrder) {
    _pushUndo();
    _snapshot = _snapshot.copyWith(sceneOrder: List.unmodifiable(newOrder));
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _mutationVersion += 1;
    unawaited(safePersist(_persist, eventBus: _eventBus));
    notifyListeners();
  }

  /// 在指定位置插入场景
  void insertSceneAt(String sceneId, int index) {
    final current = List<String>.from(_snapshot.sceneOrder);
    if (index < 0 || index > current.length) {
      current.add(sceneId);
    } else {
      current.insert(index, sceneId);
    }
    reorderScenes(current);
  }

  /// 移除场景
  void removeScene(String sceneId) {
    final current = [
      for (final id in _snapshot.sceneOrder)
        if (id != sceneId) id,
    ];
    reorderScenes(current);
  }

  // ---------------------------------------------------------------------------
  // 导入 / 导出
  // ---------------------------------------------------------------------------

  Map<String, Object?> exportJson() => _snapshot.toJson();

  void importJson(Map<String, Object?> data) {
    replaceSnapshot(StoryArcSnapshot.fromJson({
      for (final entry in data.entries) entry.key: entry.value,
      'projectId': _activeProjectId,
    }));
  }

  void replaceSnapshot(StoryArcSnapshot snapshot) {
    _mutationVersion += 1;
    _snapshot = snapshot.deepCopy().copyWith(projectId: _activeProjectId);
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    _readyFuture = safePersist(_persist, eventBus: _eventBus);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 内部实现
  // ---------------------------------------------------------------------------

  void _pushUndo() {
    final stack = List<NarrativeArcState>.from(_snapshot.undoStack);
    // 保留最近 20 步
    if (stack.length >= 20) {
      stack.removeAt(0);
    }
    stack.add(_snapshot.narrativeArcState);
    _snapshot = _snapshot.copyWith(undoStack: stack);
  }

  void _handleWorkspaceChanged() {
    final nextProjectId = _resolveProjectId(_workspaceStore);
    if (nextProjectId == _activeProjectId) return;
    _mutationVersion += 1;
    _activeProjectId = nextProjectId;
    _snapshot =
        _snapshotsByProjectId[nextProjectId]?.deepCopy() ??
        StoryArcSnapshot.empty(nextProjectId);
    _readyFuture = _restore();
    unawaited(_readyFuture);
    notifyListeners();
  }

  Future<void> _restore() async {
    final restoreVersion = _mutationVersion;
    final restored = await _storage.load(projectId: _activeProjectId);
    if (restoreVersion != _mutationVersion || restored == null) return;
    _snapshot = StoryArcSnapshot.fromJson({
      for (final entry in restored.entries) entry.key: entry.value,
      'projectId': _activeProjectId,
    });
    _snapshotsByProjectId[_activeProjectId] = _snapshot.deepCopy();
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(_snapshot.toJson(), projectId: _activeProjectId);

  void _handleProjectDeleted(ProjectDeletedEvent event) {
    _mutationVersion += 1;
    _snapshotsByProjectId.remove(event.projectId);
    unawaited(_storage.clearProject(event.projectId));
  }

  static String _resolveProjectId(AppWorkspaceStore? workspaceStore) {
    if (workspaceStore == null || workspaceStore.currentProjectId.isEmpty) {
      return _fallbackStoryArcProjectId;
    }
    return workspaceStore.currentProjectId;
  }

  @override
  void dispose() {
    _workspaceStore?.removeListener(_handleWorkspaceChanged);
    unawaited(_projectDeletedSubscription?.cancel());
    _projectDeletedSubscription = null;
    super.dispose();
  }
}

// ============================================================================
// JSON 编解码
// ============================================================================

NarrativeArcState _decodeNarrativeArcState(Map<String, Object?> json) {
  final activeThreads = _decodeThreads(json['activeThreads']);
  final closedThreads = _decodeThreads(json['closedThreads']);
  final foreshadowing = _decodeForeshadowing(json['pendingForeshadowing']);
  final thematicArcs = json['thematicArcs'] is List
      ? [for (final item in json['thematicArcs'] as List) item.toString()]
      : const <String>[];
  final chapterIndex = json['chapterIndex'] is int
      ? json['chapterIndex'] as int
      : int.tryParse(json['chapterIndex']?.toString() ?? '') ?? 0;

  return NarrativeArcState(
    activeThreads: activeThreads,
    closedThreads: closedThreads,
    pendingForeshadowing: foreshadowing,
    thematicArcs: thematicArcs,
    chapterIndex: chapterIndex,
  );
}

Map<String, Object?> _encodeNarrativeArcState(NarrativeArcState state) {
  return {
    'activeThreads': [for (final t in state.activeThreads) _encodeThread(t)],
    'closedThreads': [for (final t in state.closedThreads) _encodeThread(t)],
    'pendingForeshadowing': [
      for (final f in state.pendingForeshadowing) _encodeForeshadowing(f),
    ],
    'thematicArcs': state.thematicArcs,
    'chapterIndex': state.chapterIndex,
  };
}

List<PlotThread> _decodeThreads(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) _decodeThread(Map<String, Object?>.from(item)),
  ];
}

PlotThread _decodeThread(Map<String, Object?> json) {
  return PlotThread(
    id: json['id']?.toString() ?? '',
    description: json['description']?.toString() ?? '',
    status: _decodeThreadStatus(json['status']),
    involvedCharacters: json['involvedCharacters'] is List
        ? [for (final c in json['involvedCharacters'] as List) c.toString()]
        : const [],
    introducedInScene: json['introducedInScene']?.toString() ?? '',
    resolvedInScene: json['resolvedInScene']?.toString(),
  );
}

Map<String, Object?> _encodeThread(PlotThread t) {
  return {
    'id': t.id,
    'description': t.description,
    'status': t.status.name,
    'involvedCharacters': t.involvedCharacters,
    'introducedInScene': t.introducedInScene,
    'resolvedInScene': t.resolvedInScene,
  };
}

PlotThreadStatus _decodeThreadStatus(Object? raw) {
  return switch (raw?.toString()) {
    'rising' => PlotThreadStatus.rising,
    'climax' => PlotThreadStatus.climax,
    'falling' => PlotThreadStatus.falling,
    'resolved' => PlotThreadStatus.resolved,
    _ => PlotThreadStatus.rising,
  };
}

List<Foreshadowing> _decodeForeshadowing(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        _decodeSingleForeshadowing(Map<String, Object?>.from(item)),
  ];
}

Foreshadowing _decodeSingleForeshadowing(Map<String, Object?> json) {
  return Foreshadowing(
    id: json['id']?.toString() ?? '',
    hint: json['hint']?.toString() ?? '',
    plantedInScene: json['plantedInScene']?.toString() ?? '',
    plannedPayoff: json['plannedPayoff']?.toString() ?? '',
    resolvedInScene: json['resolvedInScene']?.toString(),
    urgency: json['urgency'] is int
        ? json['urgency'] as int
        : int.tryParse(json['urgency']?.toString() ?? '') ?? 0,
  );
}

Map<String, Object?> _encodeForeshadowing(Foreshadowing f) {
  return {
    'id': f.id,
    'hint': f.hint,
    'plantedInScene': f.plantedInScene,
    'plannedPayoff': f.plannedPayoff,
    'resolvedInScene': f.resolvedInScene,
    'urgency': f.urgency,
  };
}

/// 默认空的 NarrativeArcState 实现，避免引入额外构造
class _DefaultNarrativeArcState implements NarrativeArcState {
  const _DefaultNarrativeArcState();

  @override
  List<PlotThread> get activeThreads => const [];
  @override
  List<PlotThread> get closedThreads => const [];
  @override
  List<Foreshadowing> get pendingForeshadowing => const [];
  @override
  List<String> get thematicArcs => const [];
  @override
  int get chapterIndex => 0;

  @override
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

  @override
  String toPromptText() => '';
}
