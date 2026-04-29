import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_ai_history_storage.dart';
import 'app_project_scoped_store.dart';

class AiHistoryEntry {
  const AiHistoryEntry({
    required this.sequence,
    required this.mode,
    required this.prompt,
  });

  final int sequence;
  final String mode;
  final String prompt;

  Map<String, Object?> toJson() {
    return {
      'sequence': sequence,
      'mode': mode,
      'prompt': prompt,
    };
  }

  static AiHistoryEntry fromJson(Map<Object?, Object?> json) {
    return AiHistoryEntry(
      sequence: int.tryParse(json['sequence']?.toString() ?? '') ?? 0,
      mode: json['mode']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
    );
  }
}

class AppAiHistoryStore extends AppProjectScopedStore {
  AppAiHistoryStore({
    AppAiHistoryStorage? storage,
    super.workspaceStore,
  }) : _storage =
           storage ??
           debugStorageOverride ??
           createDefaultAppAiHistoryStorage(),
       super(
         fallbackProjectId: 'project-yuechao::scene-05-witness-room',
       ) {
    onRestore();
  }

  static AppAiHistoryStorage? debugStorageOverride;

  final AppAiHistoryStorage _storage;
  final Map<String, List<AiHistoryEntry>> _entriesByProjectId = {};
  final Map<String, int> _nextSequenceByProjectId = {};

  List<AiHistoryEntry> get entries =>
      List.unmodifiable(_entriesByProjectId[activeProjectId] ?? const []);

  void addEntry({required String mode, required String prompt}) {
    markMutated();
    final currentEntries = _entriesByProjectId[activeProjectId] ?? const [];
    final nextSequence = _nextSequenceByProjectId[activeProjectId] ?? 1;
    _entriesByProjectId[activeProjectId] = [
      AiHistoryEntry(sequence: nextSequence, mode: mode, prompt: prompt),
      ...currentEntries,
    ].take(5).toList();
    _nextSequenceByProjectId[activeProjectId] = nextSequence + 1;
    unawaited(_persist());
    notifyListeners();
  }

  void clear() {
    markMutated();
    _entriesByProjectId[activeProjectId] = const [];
    _nextSequenceByProjectId[activeProjectId] = 1;
    unawaited(_persist());
    notifyListeners();
  }

  void removeEntry(int sequence) {
    markMutated();
    final currentEntries = _entriesByProjectId[activeProjectId] ?? const [];
    final nextEntries = currentEntries
        .where((entry) => entry.sequence != sequence)
        .toList(growable: false);
    if (nextEntries.length == currentEntries.length) {
      return;
    }
    _entriesByProjectId[activeProjectId] = nextEntries;
    unawaited(_persist());
    notifyListeners();
  }

  Map<String, Object?> exportJson() {
    return {
      'entries': [for (final entry in entries) entry.toJson()],
    };
  }

  void importJson(Map<String, Object?> data) {
    markMutated();
    final rawEntries = data['entries'];
    if (rawEntries is! List) {
      return;
    }
    final decoded = <AiHistoryEntry>[
      for (final item in rawEntries)
        if (item is Map<Object?, Object?>) AiHistoryEntry.fromJson(item),
    ];
    _entriesByProjectId[activeProjectId] = decoded;
    _nextSequenceByProjectId[activeProjectId] =
        decoded.isEmpty ? 1 : decoded.first.sequence + 1;
    unawaited(_persist());
    notifyListeners();
  }

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    // Data is cached per project in _entriesByProjectId, no reset needed.
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final restored = await _storage.load(projectId: activeProjectId);
    if (restoreVersion != mutationVersion) {
      return;
    }
    if (restored == null) {
      _entriesByProjectId[activeProjectId] = const [];
      _nextSequenceByProjectId[activeProjectId] = 1;
      return;
    }
    final rawEntries = restored['entries'];
    if (rawEntries is! List) {
      _entriesByProjectId[activeProjectId] = const [];
      _nextSequenceByProjectId[activeProjectId] = 1;
      return;
    }
    final decoded = <AiHistoryEntry>[
      for (final item in rawEntries)
        if (item is Map<Object?, Object?>) AiHistoryEntry.fromJson(item),
    ];
    _entriesByProjectId[activeProjectId] = decoded;
    _nextSequenceByProjectId[activeProjectId] =
        decoded.isEmpty ? 1 : decoded.first.sequence + 1;
  }

  Future<void> _persist() =>
      _storage.save(exportJson(), projectId: activeProjectId);
}

class AppAiHistoryScope extends InheritedNotifier<AppAiHistoryStore> {
  const AppAiHistoryScope({
    super.key,
    required AppAiHistoryStore store,
    required super.child,
  }) : super(notifier: store);

  static AppAiHistoryStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppAiHistoryScope>();
    assert(scope != null, 'AppAiHistoryScope is missing in the widget tree.');
    return scope!.notifier!;
  }
}
