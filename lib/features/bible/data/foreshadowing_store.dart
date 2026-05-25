import '../../../app/state/app_store_listenable.dart';

enum ForeshadowingStatus {
  undeveloped,
  developed,
  abandoned;

  String get label {
    return switch (this) {
      ForeshadowingStatus.undeveloped => '未展开',
      ForeshadowingStatus.developed => '已展开',
      ForeshadowingStatus.abandoned => '已废弃',
    };
  }
}

class ForeshadowingThread {
  const ForeshadowingThread({
    required this.id,
    required this.title,
    required this.description,
    required this.relatedChapterLabel,
    required this.status,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String title;
  final String description;
  final String relatedChapterLabel;
  final ForeshadowingStatus status;
  final int createdAtMs;
  final int updatedAtMs;

  bool get hasReminder =>
      status != ForeshadowingStatus.abandoned &&
      relatedChapterLabel.trim().isNotEmpty;

  ForeshadowingThread copyWith({
    String? id,
    String? title,
    String? description,
    String? relatedChapterLabel,
    ForeshadowingStatus? status,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return ForeshadowingThread(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      relatedChapterLabel: relatedChapterLabel ?? this.relatedChapterLabel,
      status: status ?? this.status,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

class ForeshadowingStore extends AppStoreListenable {
  ForeshadowingStore({
    Iterable<ForeshadowingThread> initialThreads =
        const <ForeshadowingThread>[],
    DateTime Function()? now,
  }) : _threads = List<ForeshadowingThread>.from(initialThreads),
       _now = now ?? DateTime.now {
    _nextSequence = _threads.length + 1;
  }

  final DateTime Function() _now;
  late int _nextSequence;
  List<ForeshadowingThread> _threads;

  List<ForeshadowingThread> get threads =>
      List<ForeshadowingThread>.unmodifiable(_threads);

  List<ForeshadowingThread> get reminders =>
      List<ForeshadowingThread>.unmodifiable(
        _threads.where((thread) => thread.hasReminder),
      );

  ForeshadowingThread? threadById(String id) {
    final normalized = id.trim();
    for (final thread in _threads) {
      if (thread.id == normalized) {
        return thread;
      }
    }
    return null;
  }

  List<ForeshadowingThread> remindersForChapter(String chapterLabel) {
    final normalized = chapterLabel.trim();
    if (normalized.isEmpty) {
      return const <ForeshadowingThread>[];
    }
    return List<ForeshadowingThread>.unmodifiable(
      reminders.where(
        (thread) => thread.relatedChapterLabel.trim() == normalized,
      ),
    );
  }

  ForeshadowingThread createForeshadowing({
    required String title,
    required String description,
    required String relatedChapterLabel,
  }) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'title must not be empty');
    }
    final nowMs = _now().millisecondsSinceEpoch;
    final thread = ForeshadowingThread(
      id: 'foreshadowing-${_nextSequence++}',
      title: normalizedTitle,
      description: description.trim(),
      relatedChapterLabel: relatedChapterLabel.trim(),
      status: ForeshadowingStatus.undeveloped,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );
    _threads = [thread, ..._threads];
    notifyListeners();
    return thread;
  }

  bool updateStatus(String id, ForeshadowingStatus status) {
    final normalized = id.trim();
    var changed = false;
    final nowMs = _now().millisecondsSinceEpoch;
    _threads = [
      for (final thread in _threads)
        if (thread.id == normalized)
          () {
            if (thread.status == status) {
              return thread;
            }
            changed = true;
            return thread.copyWith(status: status, updatedAtMs: nowMs);
          }()
        else
          thread,
    ];
    if (changed) {
      notifyListeners();
    }
    return changed;
  }
}
