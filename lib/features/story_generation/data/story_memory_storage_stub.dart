import '../domain/memory_models.dart';
import 'story_memory_indexer.dart';
import 'story_memory_storage.dart';

/// In-memory stub for tests and non-IO contexts.
///
/// Sorts loaded records by createdAtMs then id for deterministic ordering.
class StoryMemoryStorageStub
    implements StoryMemoryStorage, OwnedGenerationMemoryStorage {
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
  Future<void> replaceOwnedGeneration({
    required String projectId,
    required String scopeId,
    required String producer,
    required List<StoryMemoryChunk> chunks,
    bool includeLegacyContextRows = false,
  }) async {
    final normalizedProducer = producer.trim();
    if (normalizedProducer.isEmpty) {
      throw ArgumentError.value(producer, 'producer', 'must not be empty');
    }
    final ids = <String>{};
    for (final chunk in chunks) {
      if (chunk.projectId != projectId ||
          chunk.scopeId != scopeId ||
          chunk.producer != normalizedProducer ||
          !StoryMemoryIndexer.ownsGenerationChunkId(
            id: chunk.id,
            projectId: projectId,
            scopeId: scopeId,
            producer: normalizedProducer,
            kind: chunk.kind,
          ) ||
          !ids.add(chunk.id)) {
        throw StateError(
          'All chunks must have unique IDs in the canonical requested '
          'project, scope, producer, and kind namespace',
        );
      }
      for (final existing in _chunks.values.expand((items) => items)) {
        if (existing.id == chunk.id &&
            (existing.projectId != projectId ||
                existing.scopeId != scopeId ||
                existing.producer.trim() != normalizedProducer)) {
          throw StateError(
            'Owned generation chunk ID ${chunk.id} is already used by another '
            'project, scope, or producer',
          );
        }
      }
    }
    final retained = [
      for (final chunk in _chunks[projectId] ?? const <StoryMemoryChunk>[])
        if (!_stubOwnsGenerationChunk(
          chunk,
          projectId: projectId,
          scopeId: scopeId,
          producer: normalizedProducer,
          includeLegacyContextRows: includeLegacyContextRows,
        ))
          chunk,
    ];
    _chunks[projectId] = [...retained, ...chunks];
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

bool _stubOwnsGenerationChunk(
  StoryMemoryChunk chunk, {
  required String projectId,
  required String scopeId,
  required String producer,
  required bool includeLegacyContextRows,
}) {
  if (chunk.projectId != projectId || chunk.scopeId != scopeId) return false;
  if (chunk.producer.trim() == producer.trim()) return true;
  if (!includeLegacyContextRows || chunk.producer.trim().isNotEmpty) {
    return false;
  }
  final code = switch (chunk.kind) {
    MemorySourceKind.worldFact => 'wf',
    MemorySourceKind.characterProfile => 'cp',
    MemorySourceKind.relationshipHint => 'rh',
    MemorySourceKind.outlineBeat => 'ob',
    MemorySourceKind.sceneSummary => 'ss',
    MemorySourceKind.acceptedState => 'as',
    MemorySourceKind.reviewFinding => 'rf',
    MemorySourceKind.draft => null,
  };
  if (code == null) return false;
  return RegExp(
    '^${RegExp.escape(projectId)}_${code}_[0-9]+\$',
  ).hasMatch(chunk.id);
}
