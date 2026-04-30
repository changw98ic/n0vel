import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_draft_storage.dart';
import 'app_project_scoped_store.dart';

const String _defaultDraftText =
    '她推开仓库门，雨水顺着袖口滴进掌心，远处码头的雾灯像一根迟疑的针。';
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
  AppDraftStore({
    AppDraftStorage? storage,
    super.workspaceStore,
  })
    : _storage =
          storage ?? debugStorageOverride ?? createDefaultAppDraftStorage(),
      _snapshot = const AppDraftSnapshot(text: _defaultDraftText),
      super(fallbackProjectId: _fallbackDraftProjectId) {
    onRestore();
  }

  @visibleForTesting
  static AppDraftStorage? debugStorageOverride;

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
    markMutated();
    _isRestoring = false;
    _snapshot = _snapshot.copyWith(text: text);
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> updateTextAndPersist(String text) async {
    final previousSnapshot = _snapshot;
    markMutated();
    _isRestoring = false;
    _snapshot = _snapshot.copyWith(text: text);
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
    unawaited(_persist());
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

  Future<void> _persist() =>
      _storage.save(_snapshot.toJson(), projectId: activeProjectId);
}

class AppDraftScope extends InheritedNotifier<AppDraftStore> {
  const AppDraftScope({
    super.key,
    required AppDraftStore store,
    required super.child,
  }) : super(notifier: store);

  static AppDraftStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppDraftScope>();
    assert(scope != null, 'AppDraftScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
