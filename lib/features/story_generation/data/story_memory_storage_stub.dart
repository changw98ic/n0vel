import '../domain/memory_models.dart';
import 'story_memory_storage.dart';

/// In-memory stub for tests and non-IO contexts.
///
/// Sorts loaded records by createdAtMs then id for deterministic ordering.
class StoryMemoryStorageStub implements StoryMemoryStorage {
  final Map<String, List<StoryMemorySource>> _sources = {};
  final Map<String, List<StoryMemoryChunk>> _chunks = {};
  final Map<String, List<ThoughtAtom>> _thoughts = {};

  @override
  Future<void> saveSources(
    String projectId,
    List<StoryMemorySource> sources,
  ) async {
    _sources[projectId] = List.of(sources);
  }

  @override
  Future<List<StoryMemorySource>> loadSources(String projectId) async {
    final items = _sources[projectId] ?? const [];
    return _sorted(items, (s) => '${s.createdAtMs}'.padLeft(20, '0') + s.id);
  }

  @override
  Future<void> saveChunks(
    String projectId,
    List<StoryMemoryChunk> chunks,
  ) async {
    _chunks[projectId] = List.of(chunks);
  }

  @override
  Future<List<StoryMemoryChunk>> loadChunks(String projectId) async {
    final items = _chunks[projectId] ?? const [];
    return _sorted(items, (c) => '${c.createdAtMs}'.padLeft(20, '0') + c.id);
  }

  @override
  Future<void> saveThoughts(
    String projectId,
    List<ThoughtAtom> thoughts,
  ) async {
    _thoughts[projectId] = List.of(thoughts);
  }

  @override
  Future<List<ThoughtAtom>> loadThoughts(String projectId) async {
    final items = _thoughts[projectId] ?? const [];
    return _sorted(items, (t) => '${t.createdAtMs}'.padLeft(20, '0') + t.id);
  }

  @override
  Future<void> clearProject(String projectId) async {
    _sources.remove(projectId);
    _chunks.remove(projectId);
    _thoughts.remove(projectId);
  }

  List<T> _sorted<T>(List<T> items, String Function(T) key) {
    final copy = List<T>.of(items);
    copy.sort((a, b) => key(a).compareTo(key(b)));
    return copy;
  }
}
