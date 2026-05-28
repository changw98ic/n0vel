import 'dart:async';

import '../events/app_domain_events.dart';
import 'app_draft_storage.dart';
import 'app_project_scoped_store.dart';
import 'persist_guard.dart';

const String _defaultDraftText = '';
const String _fallbackDraftProjectId = 'project-yuechao::scene-05-witness-room';

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
  AppDraftStore({AppDraftStorage? storage, super.workspaceStore, super.eventBus})
    : _storage =
          storage ?? createDefaultAppDraftStorage(),
      _snapshot = const AppDraftSnapshot(text: _defaultDraftText),
      super(fallbackProjectId: _fallbackDraftProjectId) {
    onRestore();
  }

  
  final AppDraftStorage _storage;
  AppDraftSnapshot _snapshot;
  bool _isRestoring = false;

  AppDraftSnapshot get snapshot => _snapshot;

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
    unawaited(safePersist(_persist, eventBus: eventBus));
    notifyListeners();
  }

  Future<void> updateTextAndPersist(String text) async {
    final previousSnapshot = _snapshot;
    final previousText = _snapshot.text;
    markMutated();
    _isRestoring = false;
    _snapshot = _snapshot.copyWith(text: text);
    _publishDraftUpdated(previousText, text);
    try {
      await _persist();
      notifyListeners();
    } catch (_) {
      _snapshot = previousSnapshot;
      rethrow;
    }
  }

  void importJson(Map<String, Object?> data) {
    markMutated();
    _isRestoring = false;
    _snapshot = AppDraftSnapshot.fromJson(data);
    unawaited(safePersist(_persist, eventBus: eventBus));
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _isRestoring = true;
    _snapshot = const AppDraftSnapshot(text: _defaultDraftText);
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
      return;
    }
    _isRestoring = false;
    _snapshot = AppDraftSnapshot.fromJson(restored);
    notifyListeners();
  }

  void _publishDraftUpdated(String previousText, String currentText) {
    try {
      eventBus?.publish(DraftUpdatedEvent(
        projectId: activeProjectId.split('::').first,
        sceneScopeId: activeProjectId,
        previousText: previousText,
        currentText: currentText,
      ));
    } on StateError {
      // eventBus 可能已 disposed
    }
  }

  Future<void> _persist() =>
      _storage.save(_snapshot.toJson(), projectId: activeProjectId);

  @override
  Future<void> clearDeletedProjectScope(String projectId) =>
      _storage.clearProject(projectId);
}
