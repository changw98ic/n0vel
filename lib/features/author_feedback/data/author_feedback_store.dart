import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../app/state/app_project_scoped_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../domain/author_feedback_models.dart';
import 'author_feedback_storage.dart';

class AuthorFeedbackStore extends AppProjectScopedStore {
  // Keeping an explicit workspaceStore parameter allows the constructor to
  // pass additional base-store options in the same initializer.
  // ignore: use_super_parameters
  AuthorFeedbackStore({
    AuthorFeedbackStorage? storage,
    AppWorkspaceStore? workspaceStore,
    DateTime Function()? clock,
  }) : _storage =
           storage ??
           debugStorageOverride ??
           createDefaultAuthorFeedbackStorage(),
       _clock = clock ?? DateTime.now,
       super(
         workspaceStore: workspaceStore,
         scopeMode: AppStoreScopeMode.project,
         fallbackProjectId: 'project-yuechao',
       ) {
    _readyFuture = onRestore();
    unawaited(_readyFuture);
  }

  static AuthorFeedbackStorage? debugStorageOverride;

  final AuthorFeedbackStorage _storage;
  final DateTime Function() _clock;
  final Map<String, List<AuthorFeedbackItem>> _itemsByProjectId = {};
  Future<void> _readyFuture = Future<void>.value();

  List<AuthorFeedbackItem> get items =>
      List.unmodifiable(_itemsByProjectId[activeProjectId] ?? const []);
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

  List<AuthorFeedbackItem> itemsForScene(String sceneId) {
    return List.unmodifiable([
      for (final item in items)
        if (item.sceneId == sceneId) item,
    ]);
  }

  List<AuthorFeedbackItem> activeRevisionRequestsForScene({
    required String chapterId,
    required String sceneId,
  }) {
    return List.unmodifiable([
      for (final item in items)
        if (item.chapterId == chapterId &&
            item.sceneId == sceneId &&
            item.status == AuthorFeedbackStatus.revisionRequested)
          item,
    ]);
  }

  int activeCountForScene(String sceneId) {
    return itemsForScene(sceneId).where((item) => item.isActive).length;
  }

  AuthorFeedbackItem createFeedback({
    required String chapterId,
    required String sceneId,
    required String sceneLabel,
    required String note,
    AuthorFeedbackPriority priority = AuthorFeedbackPriority.normal,
    AuthorFeedbackStatus status = AuthorFeedbackStatus.open,
    String? sourceRunId,
    String? sourceRunLabel,
    String? sourceReviewId,
  }) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(note, 'note', 'Feedback note cannot be empty.');
    }
    markMutated();
    final now = _clock();
    final item = AuthorFeedbackItem(
      id: _newId(now),
      projectId: activeProjectId,
      chapterId: chapterId,
      sceneId: sceneId,
      sceneLabel: sceneLabel,
      note: trimmed,
      priority: priority,
      status: status,
      createdAt: now,
      updatedAt: now,
      sourceRunId: _blankToNull(sourceRunId),
      sourceRunLabel: _blankToNull(sourceRunLabel),
      sourceReviewId: _blankToNull(sourceReviewId),
      decisions: [
        AuthorFeedbackDecision(
          status: status,
          note: _initialDecisionNote(status),
          createdAt: now,
          sourceRunId: _blankToNull(sourceRunId),
          sourceReviewId: _blankToNull(sourceReviewId),
        ),
      ],
    );
    _itemsByProjectId[activeProjectId] = [item, ...items];
    unawaited(_persist());
    notifyListeners();
    return item;
  }

  void updateStatus(
    String id,
    AuthorFeedbackStatus status, {
    String note = '',
    String? sourceRunId,
    String? sourceReviewId,
  }) {
    _updateItem(id, (item, now) {
      final decisionNote = note.trim().isEmpty
          ? _statusDecisionNote(status)
          : note.trim();
      return item.copyWith(
        status: status,
        updatedAt: now,
        decisions: [
          AuthorFeedbackDecision(
            status: status,
            note: decisionNote,
            createdAt: now,
            sourceRunId: _blankToNull(sourceRunId),
            sourceReviewId: _blankToNull(sourceReviewId),
          ),
          ...item.decisions,
        ],
      );
    });
  }

  void requestRevision(String id, {String note = '', String? sourceRunId}) {
    updateStatus(
      id,
      AuthorFeedbackStatus.revisionRequested,
      note: note.trim().isEmpty
          ? 'Requested a revision from this feedback.'
          : note,
      sourceRunId: sourceRunId,
    );
  }

  void markRevisionRequestsInProgress(
    List<AuthorFeedbackItem> revisionRequests, {
    String? sourceRunId,
  }) {
    final ids = {
      for (final request in revisionRequests)
        if (request.status == AuthorFeedbackStatus.revisionRequested)
          request.id,
    };
    if (ids.isEmpty) {
      return;
    }
    markMutated();
    final now = _clock();
    final currentItems = items;
    _itemsByProjectId[activeProjectId] = [
      for (final item in currentItems)
        if (ids.contains(item.id))
          item.copyWith(
            status: AuthorFeedbackStatus.inProgress,
            updatedAt: now,
            decisions: [
              AuthorFeedbackDecision(
                status: AuthorFeedbackStatus.inProgress,
                note: 'Included in the next scene generation run.',
                createdAt: now,
                sourceRunId: _blankToNull(sourceRunId),
                sourceReviewId: item.sourceReviewId,
              ),
              ...item.decisions,
            ],
          )
        else
          item,
    ];
    unawaited(_persist());
    notifyListeners();
  }

  void resolve(String id, {String note = ''}) {
    updateStatus(id, AuthorFeedbackStatus.resolved, note: note);
  }

  void accept(String id, {String note = ''}) {
    updateStatus(id, AuthorFeedbackStatus.accepted, note: note);
  }

  void reject(String id, {String note = ''}) {
    updateStatus(id, AuthorFeedbackStatus.rejected, note: note);
  }

  void remove(String id) {
    final currentItems = items;
    final nextItems = currentItems
        .where((item) => item.id != id)
        .toList(growable: false);
    if (nextItems.length == currentItems.length) {
      return;
    }
    markMutated();
    _itemsByProjectId[activeProjectId] = nextItems;
    unawaited(_persist());
    notifyListeners();
  }

  Map<String, Object?> exportJson() {
    return {
      'items': [for (final item in items) item.toJson()],
    };
  }

  void importJson(Map<String, Object?> data) {
    final rawItems = data['items'];
    if (rawItems is! List) {
      return;
    }
    markMutated();
    _itemsByProjectId[activeProjectId] = [
      for (final raw in rawItems)
        if (raw is Map<Object?, Object?>) AuthorFeedbackItem.fromJson(raw),
    ];
    unawaited(_persist());
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    // Project-scoped data is cached by _itemsByProjectId.
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion) {
      return;
    }
    if (restored == null) {
      _itemsByProjectId[activeProjectId] = const [];
      return;
    }
    final rawItems = restored['items'];
    if (rawItems is! List) {
      _itemsByProjectId[activeProjectId] = const [];
      return;
    }
    _itemsByProjectId[activeProjectId] = [
      for (final raw in rawItems)
        if (raw is Map<Object?, Object?>) AuthorFeedbackItem.fromJson(raw),
    ];
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(exportJson(), projectId: activeProjectId);

  void _updateItem(
    String id,
    AuthorFeedbackItem Function(AuthorFeedbackItem item, DateTime now) update,
  ) {
    final currentItems = items;
    final index = currentItems.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    markMutated();
    final nextItems = currentItems.toList();
    nextItems[index] = update(nextItems[index], _clock());
    _itemsByProjectId[activeProjectId] = nextItems;
    unawaited(_persist());
    notifyListeners();
  }

  String _newId(DateTime now) {
    final existingCount =
        (_itemsByProjectId[activeProjectId] ?? const []).length;
    return 'feedback-${now.microsecondsSinceEpoch}-$existingCount';
  }

  String _initialDecisionNote(AuthorFeedbackStatus status) {
    return status == AuthorFeedbackStatus.open
        ? 'Captured author feedback.'
        : _statusDecisionNote(status);
  }

  String _statusDecisionNote(AuthorFeedbackStatus status) {
    return switch (status) {
      AuthorFeedbackStatus.open => 'Reopened feedback.',
      AuthorFeedbackStatus.revisionRequested =>
        'Requested a revision from this feedback.',
      AuthorFeedbackStatus.inProgress => 'Included feedback in a revision run.',
      AuthorFeedbackStatus.resolved => 'Marked feedback resolved.',
      AuthorFeedbackStatus.accepted => 'Marked feedback accepted.',
      AuthorFeedbackStatus.rejected => 'Marked feedback rejected.',
    };
  }

  String? _blankToNull(String? text) {
    final trimmed = text?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

class AuthorFeedbackScope extends InheritedNotifier<AuthorFeedbackStore> {
  const AuthorFeedbackScope({
    super.key,
    required AuthorFeedbackStore store,
    required super.child,
  }) : super(notifier: store);

  static AuthorFeedbackStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AuthorFeedbackScope>();
    assert(scope != null, 'AuthorFeedbackScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
