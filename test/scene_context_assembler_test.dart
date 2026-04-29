import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_assembler.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';

void main() {
  // ── ProjectMaterialSnapshot ──────────────────────────────────────────

  group('ProjectMaterialSnapshot', () {
    test('defaults to empty lists', () {
      const snapshot = ProjectMaterialSnapshot();
      expect(snapshot.worldFacts, isEmpty);
      expect(snapshot.characterProfiles, isEmpty);
      expect(snapshot.relationshipHints, isEmpty);
      expect(snapshot.outlineBeats, isEmpty);
      expect(snapshot.sceneSummaries, isEmpty);
      expect(snapshot.acceptedStates, isEmpty);
      expect(snapshot.reviewFindings, isEmpty);
    });

    test('isEmpty is true when all lists are empty', () {
      const snapshot = ProjectMaterialSnapshot();
      expect(snapshot.isEmpty, isTrue);
    });

    test('isEmpty is false when any list has content', () {
      final snapshots = [
        ProjectMaterialSnapshot(worldFacts: ['a']),
        ProjectMaterialSnapshot(characterProfiles: ['a']),
        ProjectMaterialSnapshot(relationshipHints: ['a']),
        ProjectMaterialSnapshot(outlineBeats: ['a']),
        ProjectMaterialSnapshot(sceneSummaries: ['a']),
        ProjectMaterialSnapshot(acceptedStates: ['a']),
        ProjectMaterialSnapshot(reviewFindings: ['a']),
      ];
      for (final s in snapshots) {
        expect(s.isEmpty, isFalse, reason: '${s.runtimeType} with one element should not be empty');
      }
    });
  });

  // ── SceneContextAssembly ─────────────────────────────────────────────

  group('SceneContextAssembly', () {
    SceneBrief makeBrief() => SceneBrief(
          chapterId: 'ch1',
          chapterTitle: '第一章',
          sceneId: 'sc1',
          sceneTitle: '开篇',
          sceneSummary: '故事开始',
        );

    test('holds all fields from construction', () {
      final brief = makeBrief();
      const materials = ProjectMaterialSnapshot(worldFacts: ['gravity works']);
      final assembly = SceneContextAssembly(
        brief: brief,
        materialSnapshot: materials,
        retrievalRequirements: ['world_rules'],
        memoryChunks: [],
      );
      expect(assembly.brief.chapterId, 'ch1');
      expect(assembly.materialSnapshot.worldFacts, ['gravity works']);
      expect(assembly.retrievalRequirements, ['world_rules']);
      expect(assembly.memoryChunks, isEmpty);
      expect(assembly.retrievalPack, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: const ProjectMaterialSnapshot(),
        retrievalRequirements: ['a'],
      );
      final copied = assembly.copyWith(retrievalRequirements: ['b']);
      expect(copied.retrievalRequirements, ['b']);
      expect(copied.brief.chapterId, 'ch1');
      expect(copied.materialSnapshot.isEmpty, isTrue);
    });

    test('copyWith can attach a retrievalPack', () {
      final assembly = SceneContextAssembly(
        brief: makeBrief(),
        materialSnapshot: const ProjectMaterialSnapshot(),
      );
      expect(assembly.retrievalPack, isNull);
      final pack = StoryRetrievalPack(
        query: StoryMemoryQuery(
          projectId: 'p',
          scopeId: 's',
          queryType: StoryMemoryQueryType.concreteFact,
          text: 'test',
        ),
        hits: [],
      );
      final updated = assembly.copyWith(retrievalPack: pack);
      expect(updated.retrievalPack, isNotNull);
      expect(updated.retrievalPack!.query.text, 'test');
    });
  });

  // ── SceneContextAssembler.assemble ───────────────────────────────────

  group('SceneContextAssembler', () {
    late SceneContextAssembler assembler;

    setUp(() {
      assembler = SceneContextAssembler();
    });

    SceneBrief makeBrief({
      List<String> worldNodeIds = const [],
      List<SceneCastCandidate> cast = const [],
    }) {
      return SceneBrief(
        chapterId: 'ch1',
        chapterTitle: '第一章',
        sceneId: 'sc1',
        sceneTitle: '开篇',
        sceneSummary: '故事开始',
        worldNodeIds: worldNodeIds,
        cast: cast,
      );
    }

    test('returns empty requirements for bare brief with empty materials', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(),
      );
      expect(result.retrievalRequirements, isEmpty);
    });

    test('adds character_profiles requirement when brief has cast', () {
      final result = assembler.assemble(
        brief: makeBrief(cast: [
          SceneCastCandidate(
            characterId: 'liuxi',
            name: '柳溪',
            role: 'protagonist',
          ),
        ]),
        materials: const ProjectMaterialSnapshot(),
      );
      expect(result.retrievalRequirements, contains('character_profiles'));
      expect(result.retrievalRequirements.length, 1);
    });

    test('adds world_rules requirement when brief has worldNodeIds', () {
      final result = assembler.assemble(
        brief: makeBrief(worldNodeIds: ['node_a']),
        materials: const ProjectMaterialSnapshot(),
      );
      expect(result.retrievalRequirements, contains('world_rules'));
      expect(result.retrievalRequirements.length, 1);
    });

    test('adds state_ledger requirement when materials have acceptedStates', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(acceptedStates: ['state1']),
      );
      expect(result.retrievalRequirements, contains('state_ledger'));
      expect(result.retrievalRequirements.length, 1);
    });

    test('adds outline_beats requirement when materials have outlineBeats', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(outlineBeats: ['beat1']),
      );
      expect(result.retrievalRequirements, contains('outline_beats'));
      expect(result.retrievalRequirements.length, 1);
    });

    test('accumulates all four requirements together', () {
      final result = assembler.assemble(
        brief: makeBrief(
          worldNodeIds: ['n1'],
          cast: [
            SceneCastCandidate(
              characterId: 'x',
              name: 'X',
              role: 'lead',
            ),
          ],
        ),
        materials: const ProjectMaterialSnapshot(
          acceptedStates: ['s1'],
          outlineBeats: ['b1'],
        ),
      );
      expect(result.retrievalRequirements, containsAll([
        'character_profiles',
        'world_rules',
        'state_ledger',
        'outline_beats',
      ]));
      expect(result.retrievalRequirements.length, 4);
    });

    test('does not duplicate requirements on repeated fields', () {
      final result = assembler.assemble(
        brief: makeBrief(worldNodeIds: ['a', 'b']),
        materials: const ProjectMaterialSnapshot(),
      );
      final count = result.retrievalRequirements
          .where((r) => r == 'world_rules')
          .length;
      expect(count, 1);
    });

    // ── Memory chunks ──────────────────────────────────────────────

    test('produces zero chunks for empty materials', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(),
      );
      expect(result.memoryChunks, isEmpty);
    });

    test('indexes world facts into chunks', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['gravity pulls downward', 'magic requires incantation'],
        ),
      );
      expect(result.memoryChunks.length, 2);
      expect(result.memoryChunks.every(
        (c) => c.kind == MemorySourceKind.worldFact,
      ), isTrue);
    });

    test('indexes character profiles into chunks', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          characterProfiles: ['柳溪是冷静的调查记者'],
        ),
      );
      expect(result.memoryChunks.length, 1);
      expect(result.memoryChunks.first.kind, MemorySourceKind.characterProfile);
    });

    test('skips blank/whitespace-only material entries', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['  ', '', 'real fact'],
          characterProfiles: ['\t'],
        ),
      );
      expect(result.memoryChunks.length, 1);
      expect(result.memoryChunks.first.content, 'real fact');
    });

    test('uses chapterId:sceneId as scopeId for chunks', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          outlineBeats: ['beat A'],
        ),
      );
      expect(result.memoryChunks.first.scopeId, 'ch1:sc1');
    });

    test('indexes all material categories together', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['w1'],
          characterProfiles: ['c1'],
          relationshipHints: ['r1'],
          outlineBeats: ['o1'],
          sceneSummaries: ['ss1'],
          acceptedStates: ['as1'],
          reviewFindings: ['rf1'],
        ),
      );
      expect(result.memoryChunks.length, 7);

      final kinds = result.memoryChunks.map((c) => c.kind).toSet();
      expect(kinds, containsAll([
        MemorySourceKind.worldFact,
        MemorySourceKind.characterProfile,
        MemorySourceKind.relationshipHint,
        MemorySourceKind.outlineBeat,
        MemorySourceKind.sceneSummary,
        MemorySourceKind.acceptedState,
        MemorySourceKind.reviewFinding,
      ]));
    });

    test('each chunk has a unique id', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['a', 'b'],
          outlineBeats: ['c'],
        ),
      );
      final ids = result.memoryChunks.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('accepted state chunks have elevated priority', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          worldFacts: ['fact'],
          acceptedStates: ['state'],
        ),
      );
      final worldChunk = result.memoryChunks.firstWhere(
        (c) => c.kind == MemorySourceKind.worldFact,
      );
      final stateChunk = result.memoryChunks.firstWhere(
        (c) => c.kind == MemorySourceKind.acceptedState,
      );
      expect(stateChunk.priority, greaterThan(worldChunk.priority));
    });

    test('private profile has agentPrivate visibility', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          characterProfiles: ['@private:秘密想法'],
        ),
      );
      expect(result.memoryChunks.length, 1);
      expect(
        result.memoryChunks.first.visibility,
        MemoryVisibility.agentPrivate,
      );
      expect(result.memoryChunks.first.content, '秘密想法');
    });

    test('public profile has publicObservable visibility', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(
          characterProfiles: ['柳溪是调查记者'],
        ),
      );
      expect(result.memoryChunks.first.visibility, MemoryVisibility.publicObservable);
    });

    test('copies brief and materials into assembly unchanged', () {
      final brief = makeBrief(worldNodeIds: ['n1']);
      const materials = ProjectMaterialSnapshot(
        worldFacts: ['fact'],
      );
      final result = assembler.assemble(brief: brief, materials: materials);
      expect(identical(result.brief, brief), isTrue);
      expect(result.materialSnapshot.worldFacts, ['fact']);
    });

    test('retrievalPack is null after basic assemble', () {
      final result = assembler.assemble(
        brief: makeBrief(),
        materials: const ProjectMaterialSnapshot(),
      );
      expect(result.retrievalPack, isNull);
    });
  });
}
