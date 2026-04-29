import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_stub.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage_io.dart';
import 'package:novel_writer/features/story_generation/data/story_memory_storage.dart';

void main() {
  group('stub storage', () {
    late StoryMemoryStorage storage;

    setUp(() {
      storage = StoryMemoryStorageStub();
    });

    test('save and load sources by project', () async {
      const sources = [
        StoryMemorySource(
          id: 'src-1',
          projectId: 'proj-a',
          scopeId: 'scene-1',
          kind: MemorySourceKind.worldFact,
          content: 'Dragons sleep in winter.',
          createdAtMs: 100,
        ),
        StoryMemorySource(
          id: 'src-2',
          projectId: 'proj-a',
          scopeId: 'scene-2',
          kind: MemorySourceKind.characterProfile,
          content: 'Mei is a healer.',
          createdAtMs: 200,
        ),
      ];
      await storage.saveSources('proj-a', sources);
      final loaded = await storage.loadSources('proj-a');
      expect(loaded.length, 2);
      // Sorted by createdAtMs then id
      expect(loaded.first.id, 'src-1');
      expect(loaded.last.id, 'src-2');
    });

    test('save and load chunks by project', () async {
      const chunks = [
        StoryMemoryChunk(
          id: 'chunk-2',
          projectId: 'proj-a',
          scopeId: 'scene-2',
          kind: MemorySourceKind.outlineBeat,
          content: 'The hero enters the cave.',
          createdAtMs: 300,
        ),
        StoryMemoryChunk(
          id: 'chunk-1',
          projectId: 'proj-a',
          scopeId: 'scene-1',
          kind: MemorySourceKind.worldFact,
          content: 'Caves are damp.',
          createdAtMs: 200,
        ),
      ];
      await storage.saveChunks('proj-a', chunks);
      final loaded = await storage.loadChunks('proj-a');
      expect(loaded.length, 2);
      expect(loaded.first.id, 'chunk-1');
      expect(loaded.first.createdAtMs, 200);
    });

    test('save and load thoughts by project', () async {
      const thoughts = [
        ThoughtAtom(
          id: 'thought-1',
          projectId: 'proj-a',
          scopeId: 'scene-1',
          thoughtType: ThoughtType.persona,
          content: 'Hero is brave.',
          confidence: 0.9,
          sourceRefs: [
            MemorySourceRef(sourceId: 's1', sourceType: MemorySourceKind.sceneSummary),
          ],
          rootSourceIds: ['s1'],
          createdAtMs: 100,
        ),
      ];
      await storage.saveThoughts('proj-a', thoughts);
      final loaded = await storage.loadThoughts('proj-a');
      expect(loaded.length, 1);
      expect(loaded.first.thoughtType, ThoughtType.persona);
      expect(loaded.first.rootSourceIds, contains('s1'));
    });

    test('clear memory by project', () async {
      await storage.saveSources('proj-a', [
        const StoryMemorySource(
          id: 'src-1', projectId: 'proj-a', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'test',
        ),
      ]);
      await storage.saveSources('proj-b', [
        const StoryMemorySource(
          id: 'src-2', projectId: 'proj-b', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'other',
        ),
      ]);
      await storage.clearProject('proj-a');
      final a = await storage.loadSources('proj-a');
      final b = await storage.loadSources('proj-b');
      expect(a, isEmpty);
      expect(b, isNotEmpty);
    });

    test('preserve source traces through save/load', () async {
      const source = StoryMemorySource(
        id: 'src-trace',
        projectId: 'proj-a',
        scopeId: 'scene-1',
        kind: MemorySourceKind.acceptedState,
        content: 'Key is lost.',
        sourceRefs: [
          MemorySourceRef(sourceId: 'ch1:sc1', sourceType: MemorySourceKind.sceneSummary),
          MemorySourceRef(sourceId: 'ch1:sc2', sourceType: MemorySourceKind.acceptedState),
        ],
        rootSourceIds: ['ch1:sc1', 'ch1:sc2'],
      );
      await storage.saveSources('proj-a', [source]);
      final loaded = await storage.loadSources('proj-a');
      expect(loaded.first.sourceRefs.length, 2);
      expect(loaded.first.rootSourceIds, containsAll(['ch1:sc1', 'ch1:sc2']));
    });
  });

  group('sqlite storage', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'novel_writer_memory_io_test',
      );
      dbPath = '${tempDir.path}/memory.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    StoryMemoryStorageIO openStorage() {
      final db = sqlite3.open(dbPath);
      return StoryMemoryStorageIO(db: db);
    }

    test('records survive store reconstruction', () async {
      const source = StoryMemorySource(
        id: 'src-1',
        projectId: 'proj-x',
        scopeId: 'scene-1',
        kind: MemorySourceKind.worldFact,
        content: 'Magic requires a catalyst stone.',
        sourceRefs: [
          MemorySourceRef(sourceId: 'world-1', sourceType: MemorySourceKind.worldFact),
        ],
        rootSourceIds: ['world-1'],
        tags: ['magic'],
        priority: 3,
        tokenCostEstimate: 12,
        createdAtMs: 1777046400000,
      );
      await (openStorage()).saveSources('proj-x', [source]);

      final loaded = await (openStorage()).loadSources('proj-x');
      expect(loaded.length, 1);
      expect(loaded.first.id, 'src-1');
      expect(loaded.first.content, 'Magic requires a catalyst stone.');
      expect(loaded.first.sourceRefs.single.sourceId, 'world-1');
      expect(loaded.first.rootSourceIds, contains('world-1'));
      expect(loaded.first.tags, contains('magic'));
      expect(loaded.first.priority, 3);
    });

    test('different projects are isolated', () async {
      final s = openStorage();
      await s.saveSources('proj-a', [
        const StoryMemorySource(
          id: 'src-a', projectId: 'proj-a', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'Project A fact',
        ),
      ]);
      await s.saveSources('proj-b', [
        const StoryMemorySource(
          id: 'src-b', projectId: 'proj-b', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'Project B fact',
        ),
      ]);

      final a = await s.loadSources('proj-a');
      final b = await s.loadSources('proj-b');
      expect(a.length, 1);
      expect(a.first.id, 'src-a');
      expect(b.length, 1);
      expect(b.first.id, 'src-b');
    });

    test('thoughts keep rootSourceIds through persistence', () async {
      const thought = ThoughtAtom(
        id: 'thought-1',
        projectId: 'proj-x',
        scopeId: 'scene-1',
        thoughtType: ThoughtType.plotCausality,
        content: 'The key was stolen by the shadow agent.',
        confidence: 0.91,
        abstractionLevel: 2.5,
        sourceRefs: [
          MemorySourceRef(sourceId: 'scene-1', sourceType: MemorySourceKind.sceneSummary),
        ],
        rootSourceIds: ['scene-1:beat-3', 'scene-1:beat-4'],
        tags: ['plot', 'key'],
        priority: 5,
        tokenCostEstimate: 22,
        createdAtMs: 1777046500000,
      );
      await (openStorage()).saveThoughts('proj-x', [thought]);

      final loaded = await (openStorage()).loadThoughts('proj-x');
      expect(loaded.length, 1);
      expect(loaded.first.rootSourceIds, containsAll(['scene-1:beat-3', 'scene-1:beat-4']));
      expect(loaded.first.confidence, 0.91);
      expect(loaded.first.abstractionLevel, 2.5);
      expect(loaded.first.thoughtType, ThoughtType.plotCausality);
    });

    test('clearing one project does not clear another', () async {
      final s = openStorage();
      await s.saveSources('proj-a', [
        const StoryMemorySource(
          id: 'src-a', projectId: 'proj-a', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'A fact',
        ),
      ]);
      await s.saveChunks('proj-a', [
        const StoryMemoryChunk(
          id: 'chunk-a', projectId: 'proj-a', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'A chunk',
        ),
      ]);
      await s.saveSources('proj-b', [
        const StoryMemorySource(
          id: 'src-b', projectId: 'proj-b', scopeId: 's1',
          kind: MemorySourceKind.characterProfile, content: 'B fact',
        ),
      ]);
      await s.saveThoughts('proj-b', [
        const ThoughtAtom(
          id: 'thought-b', projectId: 'proj-b', scopeId: 's1',
          thoughtType: ThoughtType.persona, content: 'B thought',
          confidence: 0.8,
        ),
      ]);

      await s.clearProject('proj-a');

      final aSources = await s.loadSources('proj-a');
      final aChunks = await s.loadChunks('proj-a');
      final bSources = await s.loadSources('proj-b');
      final bThoughts = await s.loadThoughts('proj-b');

      expect(aSources, isEmpty);
      expect(aChunks, isEmpty);
      expect(bSources.length, 1);
      expect(bSources.first.id, 'src-b');
      expect(bThoughts.length, 1);
      expect(bThoughts.first.id, 'thought-b');
    });

    test('upsert updates existing records', () async {
      final s = openStorage();
      await s.saveChunks('proj-x', [
        const StoryMemoryChunk(
          id: 'chunk-1', projectId: 'proj-x', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'Original content',
          priority: 1, createdAtMs: 100,
        ),
      ]);

      await s.saveChunks('proj-x', [
        const StoryMemoryChunk(
          id: 'chunk-1', projectId: 'proj-x', scopeId: 's1',
          kind: MemorySourceKind.worldFact, content: 'Updated content',
          priority: 5, createdAtMs: 100,
        ),
      ]);

      final loaded = await s.loadChunks('proj-x');
      expect(loaded.length, 1);
      expect(loaded.first.content, 'Updated content');
      expect(loaded.first.priority, 5);
    });
  });
}
