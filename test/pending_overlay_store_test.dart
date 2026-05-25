import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/pending_overlay_store.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/import_export/data/markdown_exporter.dart';

void main() {
  late PendingOverlayStore store;

  setUp(() {
    store = PendingOverlayStore();
  });

  group('OverlayFingerprint', () {
    test('generates deterministic fingerprints from JSON', () {
      final json1 = {'id': 'test', 'name': '测试', 'value': 42};
      final json2 = {'id': 'test', 'name': '测试', 'value': 42};
      final json3 = {'id': 'test', 'name': '测试', 'value': 43};

      final fp1 = OverlayFingerprint.fromCanonicalJson(json1);
      final fp2 = OverlayFingerprint.fromCanonicalJson(json2);
      final fp3 = OverlayFingerprint.fromCanonicalJson(json3);

      expect(fp1.matches(fp2), isTrue);
      expect(fp1.matches(fp3), isFalse);
    });

    test('preserves UTF-8/CJK values correctly', () {
      final json = {'title': '林黛玉', 'content': '红楼梦'};

      final fp = OverlayFingerprint.fromCanonicalJson(json);

      expect(fp.value, isNotEmpty);
      expect(fp.value.length, greaterThan(0));
    });

    test('handles empty objects', () {
      final fp = OverlayFingerprint.fromCanonicalJson({});
      expect(fp.value, isNotEmpty);
    });

    test(
      'generates same fingerprint for maps with different insertion order',
      () {
        // Same logical content, different insertion order
        final json1 = {'z': 1, 'a': 2, 'm': 3};
        final json2 = {'a': 2, 'z': 1, 'm': 3};
        final json3 = {'m': 3, 'a': 2, 'z': 1};

        final fp1 = OverlayFingerprint.fromCanonicalJson(json1);
        final fp2 = OverlayFingerprint.fromCanonicalJson(json2);
        final fp3 = OverlayFingerprint.fromCanonicalJson(json3);

        expect(fp1.matches(fp2), isTrue);
        expect(fp1.matches(fp3), isTrue);
      },
    );

    test(
      'generates same fingerprint for nested structures with different key order',
      () {
        // Nested map with different key ordering at each level
        final json1 = {
          'outerZ': {'innerZ': 1, 'innerA': 2},
          'outerA': ['item2', 'item1'],
        };
        final json2 = {
          'outerA': ['item2', 'item1'],
          'outerZ': {'innerA': 2, 'innerZ': 1},
        };

        final fp1 = OverlayFingerprint.fromCanonicalJson(json1);
        final fp2 = OverlayFingerprint.fromCanonicalJson(json2);

        expect(fp1.matches(fp2), isTrue);
      },
    );
  });

  group('OverlaySummary', () {
    test('creates summaries for all entity types', () {
      final projectSummary = OverlaySummary.forProject(
        const ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '测试项目',
          genre: '悬疑',
          summary: '项目摘要',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
      );
      expect(projectSummary.kind, OverlayTargetKind.project);
      expect(projectSummary.title, '测试项目');

      final sceneSummary = OverlaySummary.forScene(
        const SceneRecord(
          id: 's1',
          chapterLabel: '第 1 章',
          title: '场景标题',
          summary: '场景摘要',
        ),
      );
      expect(sceneSummary.kind, OverlayTargetKind.scene);
      expect(sceneSummary.title, '场景标题');

      final charSummary = OverlaySummary.forCharacter(
        const CharacterRecord(id: 'c1', name: '张三', role: '主角'),
      );
      expect(charSummary.kind, OverlayTargetKind.character);
      expect(charSummary.title, '张三');

      final worldSummary = OverlaySummary.forWorldNode(
        const WorldNodeRecord(id: 'w1', title: '暗影森林', type: '地点'),
      );
      expect(worldSummary.kind, OverlayTargetKind.worldNode);
      expect(worldSummary.title, '暗影森林');

      final draftSummary = OverlaySummary.forDraft('草稿文本内容');
      expect(draftSummary.kind, OverlayTargetKind.draft);
      expect(draftSummary.title, '草稿文本');
    });

    test('truncates long text for detail', () {
      final longText = 'a' * 100;
      final summary = OverlaySummary(
        kind: OverlayTargetKind.scene,
        title: 'Scene',
        detail: longText,
      );

      expect(summary.detail?.length, lessThanOrEqualTo(103)); // 100 + '...'
    });
  });

  group('PendingOverlayStore - plan building', () {
    test('detects unchanged project metadata', () {
      const project = ProjectRecord(
        id: 'p1',
        sceneId: 's1',
        title: '测试项目',
        genre: '悬疑',
        summary: '摘要',
        recentLocation: '',
        lastOpenedAtMs: 0,
      );

      const input = PendingOverlayInput(
        sourceProject: project,
        sourceScenes: [],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: project,
        pendingScenes: [],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);

      final projectEntry = plan.entries.first;
      expect(projectEntry.status, OverlayStatus.unchanged);
      expect(projectEntry.targetRef.kind, OverlayTargetKind.project);
      expect(projectEntry.changedFields, isEmpty);
    });

    test('detects changed project metadata', () {
      const sourceProject = ProjectRecord(
        id: 'p1',
        sceneId: 's1',
        title: '原标题',
        genre: '悬疑',
        summary: '原摘要',
        recentLocation: '',
        lastOpenedAtMs: 0,
      );

      const pendingProject = ProjectRecord(
        id: 'p1',
        sceneId: 's1',
        title: '新标题',
        genre: '奇幻',
        summary: '新摘要',
        recentLocation: '',
        lastOpenedAtMs: 0,
      );

      const input = PendingOverlayInput(
        sourceProject: sourceProject,
        sourceScenes: [],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: pendingProject,
        pendingScenes: [],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);

      final projectEntry = plan.entries.first;
      expect(projectEntry.status, OverlayStatus.pending);
      expect(projectEntry.changedFields, contains('title'));
      expect(projectEntry.changedFields, contains('genre'));
      expect(projectEntry.changedFields, contains('summary'));
    });

    test('detects unchanged scenes', () {
      const scene = SceneRecord(
        id: 's1',
        chapterLabel: '第 1 章',
        title: '场景标题',
        summary: '场景摘要',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: [scene],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: [scene],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final sceneEntries = plan.entriesByKind(OverlayTargetKind.scene);
      expect(sceneEntries, hasLength(1));
      expect(sceneEntries.first.status, OverlayStatus.unchanged);
    });

    test('detects changed scenes', () {
      const sourceScene = SceneRecord(
        id: 's1',
        chapterLabel: '第 1 章',
        title: '原标题',
        summary: '原摘要',
      );

      const pendingScene = SceneRecord(
        id: 's1',
        chapterLabel: '第 1 章',
        title: '新标题',
        summary: '新摘要',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: [sourceScene],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: [pendingScene],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final sceneEntries = plan.entriesByKind(OverlayTargetKind.scene);
      expect(sceneEntries.first.status, OverlayStatus.pending);
      expect(sceneEntries.first.changedFields, contains('title'));
      expect(sceneEntries.first.changedFields, contains('summary'));
    });

    test('detects added scenes in pending', () {
      const pendingScene = SceneRecord(
        id: 's2',
        chapterLabel: '第 2 章',
        title: '新增场景',
        summary: '新增摘要',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: [pendingScene],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final sceneEntries = plan.entriesByKind(OverlayTargetKind.scene);
      expect(sceneEntries, hasLength(1));
      expect(sceneEntries.first.status, OverlayStatus.pending);
      expect(sceneEntries.first.changedFields, contains('added'));
      expect(sceneEntries.first.sourceSummary, isNull);
      expect(sceneEntries.first.pendingSummary, isNotNull);
    });

    test('detects deleted scenes (missing in pending)', () {
      const sourceScene = SceneRecord(
        id: 's1',
        chapterLabel: '第 1 章',
        title: '已删除场景',
        summary: '摘要',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: [sourceScene],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final sceneEntries = plan.entriesByKind(OverlayTargetKind.scene);
      expect(sceneEntries, hasLength(1));
      expect(sceneEntries.first.status, OverlayStatus.pending);
      expect(sceneEntries.first.changedFields, contains('deleted'));
      expect(sceneEntries.first.pendingSummary, isNull);
      expect(sceneEntries.first.sourceSummary, isNotNull);
    });

    test('detects changed characters', () {
      const sourceChar = CharacterRecord(
        id: 'c1',
        name: '原名',
        role: '原角色',
        summary: '原简介',
      );

      const pendingChar = CharacterRecord(
        id: 'c1',
        name: '新名',
        role: '新角色',
        summary: '新简介',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: [sourceChar],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: [pendingChar],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final charEntries = plan.entriesByKind(OverlayTargetKind.character);
      expect(charEntries.first.status, OverlayStatus.pending);
      expect(charEntries.first.changedFields, contains('name'));
      expect(charEntries.first.changedFields, contains('role'));
    });

    test('detects added characters in pending', () {
      const pendingChar = CharacterRecord(id: 'c2', name: '新角色');

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: [pendingChar],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final charEntries = plan.entriesByKind(OverlayTargetKind.character);
      expect(charEntries, hasLength(1));
      expect(charEntries.first.changedFields, contains('added'));
    });

    test('detects changed world nodes', () {
      const sourceNode = WorldNodeRecord(
        id: 'w1',
        title: '原地点',
        type: '原类型',
        summary: '原概要',
      );

      const pendingNode = WorldNodeRecord(
        id: 'w1',
        title: '新地点',
        type: '新类型',
        summary: '新概要',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: [sourceNode],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: [pendingNode],
      );

      final plan = store.buildPlan(input);

      final worldEntries = plan.entriesByKind(OverlayTargetKind.worldNode);
      expect(worldEntries.first.status, OverlayStatus.pending);
      expect(worldEntries.first.changedFields, contains('title'));
    });

    test('detects changed draft text', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        sourceDraftText: '原始草稿',
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
        pendingDraftText: '修改后的草稿',
      );

      final plan = store.buildPlan(input);

      final draftEntries = plan.entriesByKind(OverlayTargetKind.draft);
      expect(draftEntries, hasLength(1));
      expect(draftEntries.first.status, OverlayStatus.pending);
      expect(draftEntries.first.changedFields, contains('text'));
    });

    test('ignores draft when both are empty', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        sourceDraftText: '',
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
        pendingDraftText: '',
      );

      final plan = store.buildPlan(input);

      final draftEntries = plan.entriesByKind(OverlayTargetKind.draft);
      expect(draftEntries, isEmpty);
    });
  });

  group('PendingOverlayStore - plan counts', () {
    test('counts entries by status correctly', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [
          SceneRecord(id: 's1', title: '场景1'),
          SceneRecord(id: 's2', title: '场景2'),
        ],
        sourceCharacters: const [CharacterRecord(id: 'c1', name: '角色1')],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [
          SceneRecord(id: 's1', title: '场景1'), // Unchanged
          SceneRecord(id: 's2', title: '修改后场景2'), // Changed
          SceneRecord(id: 's3', title: '新增场景3'), // Added
        ],
        pendingCharacters: const [
          CharacterRecord(id: 'c1', name: '角色1'), // Unchanged
        ],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      // Project entry + 3 scene entries + 1 character entry
      expect(plan.totalCount, 5);
      // Only s2 changed and s3 added = 2 pending
      expect(plan.pendingCount, 2);
      expect(plan.unchangedCount, 3); // project, s1, c1
      expect(plan.conflictCount, 0);
      expect(plan.resolvedCount, 0);
    });

    test('hasUnresolved returns true when pending entries exist', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [SceneRecord(id: 's1', title: 'A')],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [SceneRecord(id: 's1', title: 'B')],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);
      expect(plan.hasUnresolved, isTrue);
      expect(plan.isFullyResolved, isFalse);
    });
  });

  group('PendingOverlayStore - deterministic ordering', () {
    test('entries are sorted by kind then id', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [
          SceneRecord(id: 's-z', title: 'Z'),
          SceneRecord(id: 's-a', title: 'A'),
        ],
        sourceCharacters: const [
          CharacterRecord(id: 'c-z', name: 'Z'),
          CharacterRecord(id: 'c-a', name: 'A'),
        ],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [
          SceneRecord(id: 's-a', title: 'A Modified'),
          SceneRecord(id: 's-z', title: 'Z Modified'),
        ],
        pendingCharacters: const [
          CharacterRecord(id: 'c-a', name: 'A Modified'),
          CharacterRecord(id: 'c-z', name: 'Z Modified'),
        ],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      // Order follows OverlayTargetKind enum: project, scene, character, worldNode, draft
      expect(plan.entries[0].targetRef.kind, OverlayTargetKind.project);
      expect(plan.entries[1].targetRef.kind, OverlayTargetKind.scene);
      expect(plan.entries[1].targetRef.id, 's-a');
      expect(plan.entries[2].targetRef.id, 's-z');
      expect(plan.entries[3].targetRef.kind, OverlayTargetKind.character);
      expect(plan.entries[3].targetRef.id, 'c-a');
      expect(plan.entries[4].targetRef.id, 'c-z');
    });

    test('entry IDs are deterministic and stable', () {
      const input = PendingOverlayInput(
        sourceProject: ProjectRecord(
          id: 'p-test',
          sceneId: 's1',
          title: 'Test',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        sourceScenes: [SceneRecord(id: 's-001', title: 'Scene')],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: ProjectRecord(
          id: 'p-test',
          sceneId: 's1',
          title: 'Test',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        pendingScenes: [SceneRecord(id: 's-001', title: 'Scene')],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan1 = store.buildPlan(input);
      final plan2 = store.buildPlan(input);

      expect(plan1.entries.map((e) => e.id), plan2.entries.map((e) => e.id));

      expect(plan1.entries[0].id, 'project-p-test');
      expect(plan1.entries[1].id, 'scene-s-001');
    });
  });

  group('PendingOverlayStore - resolution', () {
    test('keepPending uses pending values', () {
      const input = PendingOverlayInput(
        sourceProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '原标题',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        sourceScenes: [SceneRecord(id: 's1', title: '原始场景')],
        sourceCharacters: [CharacterRecord(id: 'c1', name: '原角色')],
        sourceWorldNodes: [],
        pendingProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '新标题',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        pendingScenes: [SceneRecord(id: 's1', title: '新场景')],
        pendingCharacters: [CharacterRecord(id: 'c1', name: '新角色')],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);

      // Set keepPending for each entry that should use pending values
      var updatedPlan = plan;
      for (final entry in plan.entries) {
        if (entry.isPending) {
          updatedPlan = store.updateDecision(
            updatedPlan,
            entry.id,
            OverlayDecision.keepPending,
          );
        }
      }

      final result = store.resolve(input, updatedPlan.entries);

      expect(result.project.title, '新标题');
      expect(result.scenes.first.title, '新场景');
      expect(result.characters.first.name, '新角色');
    });

    test('keepSource uses source values', () {
      const input = PendingOverlayInput(
        sourceProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '原标题',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        sourceScenes: [SceneRecord(id: 's1', title: '原始场景')],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '新标题',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        pendingScenes: [SceneRecord(id: 's1', title: '新场景')],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);

      // Default (undecided) keeps source
      final result = store.resolve(input, plan.entries);

      expect(result.project.title, '原标题');
      expect(result.scenes.first.title, '原始场景');
    });

    test('resolution preserves added entities from pending', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [SceneRecord(id: 's-new', title: '新增场景')],
        pendingCharacters: const [CharacterRecord(id: 'c-new', name: '新角色')],
        pendingWorldNodes: const [WorldNodeRecord(id: 'w-new', title: '新地点')],
      );

      final plan = store.buildPlan(input);

      // Added entities are kept by default
      final result = store.resolve(input, plan.entries);

      expect(result.scenes, hasLength(1));
      expect(result.scenes.first.id, 's-new');
      expect(result.characters, hasLength(1));
      expect(result.characters.first.id, 'c-new');
      expect(result.worldNodes, hasLength(1));
      expect(result.worldNodes.first.id, 'w-new');
    });

    test('resolution removes deleted entities when undecided', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [SceneRecord(id: 's-del', title: '待删除场景')],
        sourceCharacters: const [CharacterRecord(id: 'c-del', name: '待删除角色')],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      // Deleted entities are removed from result when undecided
      final result = store.resolve(input, plan.entries);

      expect(result.scenes, isEmpty);
      expect(result.characters, isEmpty);
    });

    test('resolution keeps deleted entities when keepSource', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [SceneRecord(id: 's-del', title: '待删除场景')],
        sourceCharacters: const [CharacterRecord(id: 'c-del', name: '待删除角色')],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);
      var updatedPlan = plan;

      for (final entry in plan.entries) {
        if (entry.isPending) {
          updatedPlan = store.updateDecision(
            updatedPlan,
            entry.id,
            OverlayDecision.keepSource,
          );
        }
      }

      final result = store.resolve(input, updatedPlan.entries);

      // When keepSource on deleted-in-pending, source entities are preserved
      expect(result.scenes, hasLength(1));
      expect(result.scenes.first.id, 's-del');
      expect(result.characters, hasLength(1));
      expect(result.characters.first.id, 'c-del');
    });

    test('resolution removes deleted entities when keepPending', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [SceneRecord(id: 's-del', title: '待删除场景')],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);
      final sceneEntry = plan.entries.firstWhere(
        (e) => e.targetRef.kind == OverlayTargetKind.scene,
      );

      final updatedPlan = store.updateDecision(
        plan,
        sceneEntry.id,
        OverlayDecision.keepPending,
      );

      final result = store.resolve(input, updatedPlan.entries);

      // When keepPending on deleted-in-pending, entity is omitted
      expect(result.scenes, isEmpty);
    });

    test('resolution includes draft text', () {
      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        sourceDraftText: '原始草稿',
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
        pendingDraftText: '修改后草稿',
      );

      final plan = store.buildPlan(input);
      final draftEntry = plan.entries.firstWhere(
        (e) => e.targetRef.kind == OverlayTargetKind.draft,
      );

      final updatedPlan = store.updateDecision(
        plan,
        draftEntry.id,
        OverlayDecision.keepPending,
      );

      final result = store.resolve(input, updatedPlan.entries);

      expect(result.draftText, '修改后草稿');
    });

    test('appliedDecisions includes only decided entries', () {
      const input = PendingOverlayInput(
        sourceProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'A',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        sourceScenes: [],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'B',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        pendingScenes: [],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);
      final updatedPlan = store.updateDecision(
        plan,
        plan.entries[0].id,
        OverlayDecision.keepPending,
      );

      final result = store.resolve(input, updatedPlan.entries);

      expect(result.appliedDecisions, hasLength(1));
      expect(
        result.appliedDecisions.first.decision,
        OverlayDecision.keepPending,
      );
    });
  });

  group('PendingOverlayStore - updateDecision', () {
    test('updates entry decision and status', () {
      const input = PendingOverlayInput(
        sourceProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'A',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        sourceScenes: [],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'B',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        pendingScenes: [],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);

      expect(plan.entries[0].decision, OverlayDecision.undecided);
      expect(plan.pendingCount, 1);
      expect(plan.resolvedCount, 0);

      final updatedPlan = store.updateDecision(
        plan,
        plan.entries[0].id,
        OverlayDecision.keepPending,
      );

      expect(updatedPlan.entries[0].decision, OverlayDecision.keepPending);
      expect(updatedPlan.entries[0].status, OverlayStatus.resolved);
      expect(updatedPlan.pendingCount, 0);
      expect(updatedPlan.resolvedCount, 1);
    });

    test('updates only the specified entry', () {
      const input = PendingOverlayInput(
        sourceProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'A',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        sourceScenes: [
          SceneRecord(id: 's1', title: 'X'),
          SceneRecord(id: 's2', title: 'Y'),
        ],
        sourceCharacters: [],
        sourceWorldNodes: [],
        pendingProject: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'B',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        pendingScenes: [
          SceneRecord(id: 's1', title: 'X Modified'),
          SceneRecord(id: 's2', title: 'Y Modified'),
        ],
        pendingCharacters: [],
        pendingWorldNodes: [],
      );

      final plan = store.buildPlan(input);

      // Update only the first scene
      final sceneEntries = plan.entriesByKind(OverlayTargetKind.scene);
      final firstSceneEntry = sceneEntries.first;

      final updatedPlan = store.updateDecision(
        plan,
        firstSceneEntry.id,
        OverlayDecision.keepSource,
      );

      final updatedSceneEntries = updatedPlan.entriesByKind(
        OverlayTargetKind.scene,
      );

      expect(updatedSceneEntries[0].decision, OverlayDecision.keepSource);
      expect(updatedSceneEntries[1].decision, OverlayDecision.undecided);
    });
  });

  group('PendingOverlayStore - CJK/UTF-8 support', () {
    test('preserves CJK content in fingerprints', () {
      const sourceChar = CharacterRecord(
        id: 'c1',
        name: '林黛玉',
        role: '女主角',
        summary: '多愁善感，聪明伶俐',
      );

      const pendingChar = CharacterRecord(
        id: 'c1',
        name: '林黛玉',
        role: '女主角',
        summary: '多愁善感，聪明伶俐',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: const [],
        sourceCharacters: [sourceChar],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: const [],
        pendingCharacters: [pendingChar],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final charEntry = plan.entriesByKind(OverlayTargetKind.character).first;
      expect(charEntry.status, OverlayStatus.unchanged);
      expect(charEntry.sourceSummary?.title, '林黛玉');
      expect(charEntry.pendingSummary?.title, '林黛玉');
    });

    test('detects CJK text changes correctly', () {
      const sourceScene = SceneRecord(
        id: 's1',
        chapterLabel: '第一章',
        title: '雨夜码头',
        summary: '柳溪在雨夜码头继续追索失效脚本的前情。',
      );

      const pendingScene = SceneRecord(
        id: 's1',
        chapterLabel: '第一章',
        title: '雨夜码头',
        summary: '柳溪在雨夜码头的仓库中发现新线索。',
      );

      final input = PendingOverlayInput(
        sourceProject: _defaultProject(),
        sourceScenes: [sourceScene],
        sourceCharacters: const [],
        sourceWorldNodes: const [],
        pendingProject: _defaultProject(),
        pendingScenes: [pendingScene],
        pendingCharacters: const [],
        pendingWorldNodes: const [],
      );

      final plan = store.buildPlan(input);

      final sceneEntry = plan.entriesByKind(OverlayTargetKind.scene).first;
      expect(sceneEntry.status, OverlayStatus.pending);
      expect(sceneEntry.changedFields, contains('summary'));
    });
  });

  group('OverlayEntry', () {
    test('copyWith creates correct copy', () {
      const ref = OverlayTargetRef(kind: OverlayTargetKind.scene, id: 's1');
      const entry = OverlayEntry(
        id: 'entry-1',
        targetRef: ref,
        status: OverlayStatus.pending,
        sourceFingerprint: OverlayFingerprint('abc'),
        pendingFingerprint: OverlayFingerprint('def'),
      );

      final copy = entry.copyWith(
        status: OverlayStatus.resolved,
        decision: OverlayDecision.keepSource,
      );

      expect(copy.id, 'entry-1');
      expect(copy.status, OverlayStatus.resolved);
      expect(copy.decision, OverlayDecision.keepSource);
      expect(entry.status, OverlayStatus.pending); // Original unchanged
    });

    test('withDecision creates resolved copy', () {
      const ref = OverlayTargetRef(kind: OverlayTargetKind.scene, id: 's1');
      const entry = OverlayEntry(
        id: 'entry-1',
        targetRef: ref,
        status: OverlayStatus.pending,
        sourceFingerprint: OverlayFingerprint('abc'),
        pendingFingerprint: OverlayFingerprint('def'),
      );

      final resolved = entry.withDecision(OverlayDecision.keepPending);

      expect(resolved.decision, OverlayDecision.keepPending);
      expect(resolved.status, OverlayStatus.resolved);
      expect(entry.decision, OverlayDecision.undecided);
    });
  });

  group('OverlayTargetRef', () {
    test('equality and hashCode work correctly', () {
      const ref1 = OverlayTargetRef(kind: OverlayTargetKind.scene, id: 's1');
      const ref2 = OverlayTargetRef(kind: OverlayTargetKind.scene, id: 's1');
      const ref3 = OverlayTargetRef(kind: OverlayTargetKind.scene, id: 's2');
      const ref4 = OverlayTargetRef(
        kind: OverlayTargetKind.character,
        id: 's1',
      );

      expect(ref1 == ref2, isTrue);
      expect(ref1 == ref3, isFalse);
      expect(ref1 == ref4, isFalse);
      expect(ref1.hashCode == ref2.hashCode, isTrue);
    });
  });

  group('Integration with MarkdownExportInput', () {
    test('buildPlan composes with MarkdownExportInput', () {
      const exportInput = MarkdownExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '测试项目',
          genre: '悬疑',
          summary: '摘要',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        scenes: [SceneRecord(id: 's1', chapterLabel: '第一章', title: '场景')],
        characters: [CharacterRecord(id: 'c1', name: '角色')],
        worldNodes: [WorldNodeRecord(id: 'w1', title: '地点')],
        draftText: '草稿',
      );

      // Use same data for both (unchanged)
      final overlayInput = PendingOverlayInput(
        sourceProject: exportInput.project,
        sourceScenes: exportInput.scenes,
        sourceCharacters: exportInput.characters,
        sourceWorldNodes: exportInput.worldNodes,
        sourceDraftText: exportInput.draftText,
        pendingProject: exportInput.project,
        pendingScenes: exportInput.scenes,
        pendingCharacters: exportInput.characters,
        pendingWorldNodes: exportInput.worldNodes,
        pendingDraftText: exportInput.draftText,
      );

      final plan = store.buildPlan(overlayInput);

      // All entries should be unchanged
      expect(plan.unchangedCount, equals(plan.totalCount));
      expect(plan.pendingCount, 0);
    });
  });
}

ProjectRecord _defaultProject() {
  return const ProjectRecord(
    id: 'p-default',
    sceneId: 's-default',
    title: '默认项目',
    genre: '',
    summary: '',
    recentLocation: '',
    lastOpenedAtMs: 0,
  );
}
