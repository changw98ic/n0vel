import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/state/app_project_scoped_store.dart';
import '../domain/review_task_models.dart';
import 'review_task_storage.dart';

class ReviewTaskStore extends AppProjectScopedStore {
  ReviewTaskStore({
    ReviewTaskStorage? storage,
    super.workspaceStore,
    List<ReviewTask> initialTasks = const [],
  }) : _storage =
           storage ?? debugStorageOverride ?? createDefaultReviewTaskStorage(),
       super(
         scopeMode: AppStoreScopeMode.project,
         fallbackProjectId: 'project-yuechao',
       ) {
    _tasksByProjectId[activeProjectId] = List<ReviewTask>.from(initialTasks);
    _readyFuture = initialTasks.isEmpty ? onRestore() : Future<void>.value();
    if (initialTasks.isEmpty) {
      unawaited(_readyFuture);
    }
  }

  @visibleForTesting
  static ReviewTaskStorage? debugStorageOverride;

  final ReviewTaskStorage _storage;
  final Map<String, List<ReviewTask>> _tasksByProjectId = {};
  Future<void> _readyFuture = Future<void>.value();

  List<ReviewTask> get _tasks =>
      _tasksByProjectId[activeProjectId] ?? const <ReviewTask>[];

  List<ReviewTask> get tasks => List<ReviewTask>.unmodifiable(_tasks);
  Future<void> get ready => _readyFuture;

  Future<void> waitUntilReady() async {
    while (true) {
      final currentReadyFuture = _readyFuture;
      await currentReadyFuture;
      if (identical(currentReadyFuture, _readyFuture)) {
        return;
      }
    }
  }

  List<ReviewTask> tasksForStatus(ReviewTaskStatus status) {
    return [
      for (final task in _tasks)
        if (task.status == status) task,
    ];
  }

  Map<ReviewTaskStatus, List<ReviewTask>> groupedByStatus() {
    return {
      for (final status in ReviewTaskStatus.values)
        status: tasksForStatus(status),
    };
  }

  int get openCount => _tasks
      .where(
        (task) =>
            task.status == ReviewTaskStatus.open ||
            task.status == ReviewTaskStatus.inProgress,
      )
      .length;

  void replaceAll(List<ReviewTask> tasks) {
    markMutated();
    _tasksByProjectId[activeProjectId] = List<ReviewTask>.from(tasks);
    unawaited(_persist());
    notifyListeners();
  }

  void upsertAll(List<ReviewTask> tasks) {
    if (tasks.isEmpty) {
      return;
    }
    markMutated();
    final byId = {for (final task in _tasks) task.id: task};
    for (final task in tasks) {
      final existing = byId[task.id];
      byId[task.id] = existing == null
          ? task
          : task.copyWith(
              status: existing.status,
              createdAt: existing.createdAt,
              updatedAt: existing.updatedAt,
            );
    }
    _tasksByProjectId[activeProjectId] = byId.values.toList(growable: false);
    unawaited(_persist());
    notifyListeners();
  }

  bool updateStatus(
    String taskId,
    ReviewTaskStatus status, {
    DateTime? updatedAt,
  }) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      return false;
    }
    markMutated();
    _tasksByProjectId[activeProjectId] = List<ReviewTask>.from(_tasks)
      ..[index] = _tasks[index].copyWith(
        status: status,
        updatedAt: updatedAt ?? DateTime.now(),
      );
    unawaited(_persist());
    notifyListeners();
    return true;
  }

  List<Map<String, Object?>> toJson() {
    return [for (final task in _tasks) task.toJson()];
  }

  static ReviewTaskStore fromJson(List<Object?> json) {
    return ReviewTaskStore(
      initialTasks: [
        for (final raw in json)
          if (raw is Map) ReviewTask.fromJson(Map<Object?, Object?>.from(raw)),
      ],
    );
  }

  Map<String, Object?> exportJson() {
    return {'tasks': toJson()};
  }

  void importJson(Map<String, Object?> data) {
    final rawTasks = data['tasks'];
    if (rawTasks is! List) {
      return;
    }
    replaceAll([
      for (final raw in rawTasks)
        if (raw is Map<Object?, Object?>) ReviewTask.fromJson(raw),
    ]);
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    // Project-scoped data remains cached by _tasksByProjectId.
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion) {
      return;
    }
    if (restored == null) {
      _tasksByProjectId[activeProjectId] = const [];
      return;
    }
    final rawTasks = restored['tasks'];
    if (rawTasks is! List) {
      _tasksByProjectId[activeProjectId] = const [];
      return;
    }
    _tasksByProjectId[activeProjectId] = [
      for (final raw in rawTasks)
        if (raw is Map<Object?, Object?>) ReviewTask.fromJson(raw),
    ];
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(exportJson(), projectId: activeProjectId);
}

class ReviewTaskScope extends InheritedNotifier<ReviewTaskStore> {
  const ReviewTaskScope({
    super.key,
    required ReviewTaskStore store,
    required super.child,
  }) : super(notifier: store);

  static ReviewTaskStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ReviewTaskScope>();
    assert(scope != null, 'ReviewTaskScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
