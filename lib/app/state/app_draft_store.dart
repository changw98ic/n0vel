import 'dart:async';

import '../events/app_domain_events.dart';
import 'app_draft_storage.dart';
import 'app_project_scoped_store.dart';
import 'project_storage.dart';

const String _defaultDraftText = '';
const String _fallbackDraftProjectId = 'project-yuechao::scene-05-witness-room';

/// Describes the durability of the draft currently shown in the editor.
///
/// The editor updates its in-memory snapshot synchronously, while the
/// storage decorator may debounce the physical write. Keeping this state in
/// the store prevents the UI from claiming a draft is saved before the
/// storage Future has completed.
enum DraftPersistenceStatus { saved, saving, failed }

class AppDraftSnapshot {
  const AppDraftSnapshot({required this.text});

  final String text;

  AppDraftSnapshot copyWith({String? text}) {
    return AppDraftSnapshot(text: text ?? this.text);
  }

  Map<String, Object?> toJson() {
    return {'text': text};
  }

  static AppDraftSnapshot fromJson(Map<String, Object?> json) {
    return AppDraftSnapshot(
      text: (json['text'] as String?) ?? _defaultDraftText,
    );
  }
}

class AppDraftStore extends AppProjectScopedStore {
  AppDraftStore({
    AppDraftStorage? storage,
    super.workspaceStore,
    super.eventBus,
  }) : _storage = storage ?? createDefaultAppDraftStorage(),
       _snapshot = const AppDraftSnapshot(text: _defaultDraftText),
       super(fallbackProjectId: _fallbackDraftProjectId) {
    onRestore();
  }

  final AppDraftStorage _storage;
  AppDraftSnapshot _snapshot;
  bool _isRestoring = false;
  DraftPersistenceStatus _persistenceStatus = DraftPersistenceStatus.saved;
  Object? _persistenceError;
  int _persistRevision = 0;

  @override
  ProjectStorage get persistenceStorage => _storage;

  AppDraftSnapshot get snapshot => _snapshot;

  DraftPersistenceStatus get persistenceStatus => _persistenceStatus;

  Object? get persistenceError => _persistenceError;

  bool get hasPersistenceIssue =>
      _persistenceStatus == DraftPersistenceStatus.failed;

  Map<String, Object?> exportJson() => _snapshot.toJson();

  Future<String> readTextForScope(String sceneScopeId) async {
    if (sceneScopeId == activeProjectId && !_isRestoring) {
      return _snapshot.text;
    }
    final restored = await _storage.load(projectId: sceneScopeId);
    return AppDraftSnapshot.fromJson(
      restored ?? const {'text': _defaultDraftText},
    ).text;
  }

  void updateText(String text) {
    final previousText = _snapshot.text;
    markMutated();
    _isRestoring = false;
    _snapshot = _snapshot.copyWith(text: text);
    _publishDraftUpdated(previousText, text);
    final revision = ++_persistRevision;
    _persistenceStatus = DraftPersistenceStatus.saving;
    _persistenceError = null;
    unawaited(
      _persistSnapshot(
        revision: revision,
        projectId: activeProjectId,
        data: _snapshot.toJson(),
        rethrowOnFailure: false,
      ),
    );
    notifyListeners();
  }

  Future<void> updateTextAndPersist(String text) async {
    final previousSnapshot = _snapshot;
    final previousText = _snapshot.text;
    markMutated();
    _isRestoring = false;
    _snapshot = _snapshot.copyWith(text: text);
    _publishDraftUpdated(previousText, text);
    final revision = ++_persistRevision;
    final projectId = activeProjectId;
    _persistenceStatus = DraftPersistenceStatus.saving;
    _persistenceError = null;
    try {
      await _persistSnapshot(
        revision: revision,
        projectId: projectId,
        data: _snapshot.toJson(),
        notifyOnCompletion: false,
      );
      notifyListeners();
    } catch (error) {
      final isLatest =
          revision == _persistRevision && projectId == activeProjectId;
      if (isLatest) {
        _snapshot = previousSnapshot;
        _persistenceStatus = DraftPersistenceStatus.failed;
        _persistenceError = error;
        // Cached storage deliberately retains a failed write for a later
        // retry. Replace that retained snapshot with the rolled-back value so
        // a future flush cannot resurrect the rejected transaction.
        try {
          await _storage.save(previousSnapshot.toJson(), projectId: projectId);
        } catch (_) {
          // The original transaction error remains the actionable failure.
        }
        notifyListeners();
      }
      // A stale failure still belongs to the caller that awaited this
      // operation, but it must never roll back a newer edit or overwrite its
      // visible persistence state.
      rethrow;
    }
  }

  /// Mirrors a draft already committed by the shared authoring-db
  /// transaction.  It deliberately does not persist: persisting here would
  /// open a second connection and turn an atomic accept into a best-effort
  /// pair of writes.
  void applyCommittedTextFromAuthoringTransaction({
    required String sceneScopeId,
    required String text,
  }) {
    if (sceneScopeId != activeProjectId) {
      return;
    }
    final previousText = _snapshot.text;
    markMutated();
    _isRestoring = false;
    _snapshot = _snapshot.copyWith(text: text);
    _publishDraftUpdated(previousText, text);
    notifyListeners();
  }

  void importJson(Map<String, Object?> data) {
    markMutated();
    _isRestoring = false;
    _snapshot = AppDraftSnapshot.fromJson(data);
    final revision = ++_persistRevision;
    _persistenceStatus = DraftPersistenceStatus.saving;
    _persistenceError = null;
    unawaited(
      _persistSnapshot(
        revision: revision,
        projectId: activeProjectId,
        data: _snapshot.toJson(),
        rethrowOnFailure: false,
      ),
    );
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _persistRevision++;
    _isRestoring = true;
    _snapshot = const AppDraftSnapshot(text: _defaultDraftText);
    _persistenceStatus = DraftPersistenceStatus.saved;
    _persistenceError = null;
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    _isRestoring = true;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion) {
      return;
    }
    if (restored == null) {
      _isRestoring = false;
      return;
    }
    _isRestoring = false;
    _snapshot = AppDraftSnapshot.fromJson(restored);
    _persistenceStatus = DraftPersistenceStatus.saved;
    _persistenceError = null;
    notifyListeners();
  }

  void _publishDraftUpdated(String previousText, String currentText) {
    try {
      eventBus?.publish(
        DraftUpdatedEvent(
          projectId: activeProjectId.split('::').first,
          sceneScopeId: activeProjectId,
          previousText: previousText,
          currentText: currentText,
        ),
      );
    } on StateError {
      // eventBus 可能已 disposed
    }
  }

  Future<void> _persistSnapshot({
    required int revision,
    required String projectId,
    required Map<String, Object?> data,
    bool notifyOnCompletion = true,
    bool rethrowOnFailure = true,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _storage.save(data, projectId: projectId);
        lastError = null;
        break;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          // A newer edit supersedes this attempt. Retrying the old payload
          // would enqueue it after the newer snapshot and could resurrect
          // stale text in the durable store.
          if (revision != _persistRevision || projectId != activeProjectId) {
            return;
          }
        }
      }
    }

    final isLatest =
        revision == _persistRevision && projectId == activeProjectId;
    if (lastError != null) {
      if (isLatest) {
        _persistenceStatus = DraftPersistenceStatus.failed;
        _persistenceError = lastError;
        _notifyPersistenceFailure();
        if (notifyOnCompletion) notifyListeners();
        if (rethrowOnFailure) {
          Error.throwWithStackTrace(lastError, lastStackTrace!);
        }
      }
      // A newer revision owns the user-visible result. The stale write may
      // fail while the newer waiter is still retrying, but must not surface
      // as an unhandled asynchronous error.
      return;
    }

    if (isLatest) {
      _persistenceStatus = DraftPersistenceStatus.saved;
      _persistenceError = null;
      if (notifyOnCompletion) notifyListeners();
    }
  }

  void _notifyPersistenceFailure() {
    try {
      eventBus?.publish(
        const NotificationRequestedEvent(
          title: '正文保存失败',
          message: '最新正文仍保留在当前编辑器中，请重试保存。',
          severity: AppNoticeSeverity.error,
        ),
      );
    } on StateError {
      // eventBus 可能已 disposed
    }
  }

  @override
  Future<void> clearDeletedProjectScope(String projectId) =>
      _storage.clearProject(projectId);
}
