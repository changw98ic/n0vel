import 'dart:async';

import '../../../app/state/app_project_scoped_store.dart';
import '../domain/author_feedback_models.dart';
import 'author_feedback_storage.dart';

class AuthorFeedbackStore extends AppProjectScopedStore {
  AuthorFeedbackStore({
    AuthorFeedbackStorage? storage,
    super.workspaceStore,
    super.eventBus,
    DateTime Function()? clock,
  }) : _storage = storage ?? createDefaultAuthorFeedbackStorage(),
       _clock = clock ?? DateTime.now,
       super(
         scopeMode: AppStoreScopeMode.project,
         fallbackProjectId: 'project-yuechao',
       ) {
    _readyFuture = onRestore();
    unawaited(_readyFuture);
  }

  final AuthorFeedbackStorage _storage;
  final DateTime Function() _clock;
  final Map<String, List<AuthorFeedbackItem>> _itemsByProjectId = {};
  // Kept opaque here because V9 still stores feedback as a project JSON blob.
  // The generation commit coordinator owns its lease state in the same blob
  // and updates it through the shared SQLite transaction.
  final Map<String, Map<String, Object?>> _generationMetadataByProjectId = {};
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
      ...?_generationMetadataByProjectId[activeProjectId],
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
    _setGenerationMetadata(activeProjectId, data);
    unawaited(_persist());
    notifyListeners();
  }

  /// Mirrors a feedback document already committed by the shared authoring-db
  /// accept transaction.  It never persists independently.
  void applyCommittedJsonFromAuthoringTransaction(
    Map<String, Object?> data, {
    required String projectId,
  }) {
    if (projectId != activeProjectId) {
      return;
    }
    final rawItems = data['items'];
    if (rawItems is! List) {
      return;
    }
    markMutated();
    _itemsByProjectId[projectId] = [
      for (final raw in rawItems)
        if (raw is Map<Object?, Object?>) AuthorFeedbackItem.fromJson(raw),
    ];
    _setGenerationMetadata(projectId, data);
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
      _generationMetadataByProjectId.remove(activeProjectId);
      return;
    }
    final rawItems = restored['items'];
    if (rawItems is! List) {
      _itemsByProjectId[activeProjectId] = const [];
      _generationMetadataByProjectId.remove(activeProjectId);
      return;
    }
    _itemsByProjectId[activeProjectId] = [
      for (final raw in rawItems)
        if (raw is Map<Object?, Object?>) AuthorFeedbackItem.fromJson(raw),
    ];
    _setGenerationMetadata(activeProjectId, restored);
    notifyListeners();
  }

  Future<void> _persist() =>
      _storage.save(exportJson(), projectId: activeProjectId);

  @override
  void onProjectDeleted(String projectId) {
    _itemsByProjectId.remove(projectId);
    _generationMetadataByProjectId.remove(projectId);
  }

  @override
  Future<void> clearDeletedProjectScope(String projectId) =>
      _storage.clearProject(projectId);

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

  void _setGenerationMetadata(String projectId, Map<String, Object?> data) {
    final metadata = <String, Object?>{};
    final leases = data['generationLeases'];
    if (leases is Map) {
      metadata['generationLeases'] = Map<String, Object?>.from(leases);
    }
    if (metadata.isEmpty) {
      _generationMetadataByProjectId.remove(projectId);
    } else {
      _generationMetadataByProjectId[projectId] = metadata;
    }
  }
}
