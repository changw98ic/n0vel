import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_project_scoped_store.dart';
import 'app_version_storage.dart';

class VersionEntry {
  const VersionEntry({required this.label, required this.content});

  final String label;
  final String content;

  Map<String, Object?> toJson() {
    return {'label': label, 'content': content};
  }

  static VersionEntry fromJson(Map<Object?, Object?> json) {
    return VersionEntry(
      label: json['label']?.toString() ?? '未命名版本',
      content: json['content']?.toString() ?? '',
    );
  }
}

const List<VersionEntry> _defaultVersionEntries = [
  VersionEntry(
    label: '初始版本',
    content: '她推开仓库门，雨水顺着袖口滴进掌心，远处码头的雾灯像一根迟疑的针。',
  ),
];
const String _fallbackVersionProjectId = 'project-yuechao::scene-05-witness-room';

class AppVersionStore extends AppProjectScopedStore {
  AppVersionStore({
    AppVersionStorage? storage,
    super.workspaceStore,
  }) : _storage =
           storage ?? debugStorageOverride ?? createDefaultAppVersionStorage(),
       _entries = List<VersionEntry>.from(_defaultVersionEntries),
       super(
         fallbackProjectId: _fallbackVersionProjectId,
       ) {
    onRestore();
  }

  static AppVersionStorage? debugStorageOverride;

  final AppVersionStorage _storage;
  List<VersionEntry> _entries;

  List<VersionEntry> get entries => List.unmodifiable(_entries);

  Map<String, Object?> exportJson() {
    return {
      'entries': [for (final entry in _entries) entry.toJson()],
    };
  }

  void captureSnapshot({required String label, required String content}) {
    markMutated();
    _entries = [
      VersionEntry(label: label, content: content),
      ..._entries,
    ].take(5).toList();
    unawaited(_persist());
    notifyListeners();
  }

  Future<void> captureSnapshotAndPersist({
    required String label,
    required String content,
  }) async {
    final previousEntries = List<VersionEntry>.from(_entries);
    markMutated();
    _entries = [
      VersionEntry(label: label, content: content),
      ..._entries,
    ].take(5).toList();
    try {
      await _persist();
      notifyListeners();
    } catch (_) {
      _entries = previousEntries;
      rethrow;
    }
  }

  void restoreEntry(VersionEntry entry) {
    markMutated();
    _entries = [
      VersionEntry(label: '恢复版本', content: entry.content),
      ..._entries,
    ].take(5).toList();
    unawaited(_persist());
    notifyListeners();
  }

  void importJson(Map<String, Object?> data) {
    final rawEntries = data['entries'];
    if (rawEntries is! List) {
      return;
    }
    final decoded = <VersionEntry>[
      for (final item in rawEntries)
        if (item is Map<Object?, Object?>) VersionEntry.fromJson(item),
    ];
    markMutated();
    _entries = decoded.isEmpty
        ? List<VersionEntry>.from(_defaultVersionEntries)
        : decoded;
    unawaited(_persist());
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _entries = List<VersionEntry>.from(_defaultVersionEntries);
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion || restored == null) {
      return;
    }

    final entries = restored['entries'];
    if (entries is List) {
      final decoded = <VersionEntry>[
        for (final item in entries)
          if (item is Map<Object?, Object?>) VersionEntry.fromJson(item),
      ];
      if (decoded.isNotEmpty) {
        _entries = decoded;
      }
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.save(exportJson(), projectId: activeProjectId);
  }
}

class AppVersionScope extends InheritedNotifier<AppVersionStore> {
  const AppVersionScope({
    super.key,
    required AppVersionStore store,
    required super.child,
  }) : super(notifier: store);

  static AppVersionStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppVersionScope>();
    assert(scope != null, 'AppVersionScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
