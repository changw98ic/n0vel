import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_arc_storage.dart';
import 'package:novel_writer/app/state/story_arc_store.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_models.dart';

void main() {
  group('StoryArcStore', () {
    late AppWorkspaceStore workspaceStore;
    late InMemoryStoryArcStorage arcStorage;
    late StoryArcStore arcStore;

    setUp(() {
      workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
      );
      arcStorage = InMemoryStoryArcStorage();
      arcStore = StoryArcStore(
        storage: arcStorage,
        workspaceStore: workspaceStore,
      );
      addTearDown(workspaceStore.dispose);
      addTearDown(arcStore.dispose);
    });

    test('初始状态为空快照', () {
      final snapshot = arcStore.snapshot;
      expect(snapshot.projectId, isNotEmpty);
      expect(snapshot.narrativeArcState.activeThreads, isEmpty);
      expect(snapshot.narrativeArcState.closedThreads, isEmpty);
      expect(snapshot.narrativeArcState.pendingForeshadowing, isEmpty);
      expect(snapshot.sceneOrder, isEmpty);
      expect(snapshot.undoStack, isEmpty);
      expect(arcStore.canUndo, isFalse);
    });

    test('updateArcState 持久化情节线并支持撤销', () async {
      final state = NarrativeArcState(
        activeThreads: [
          PlotThread(
            id: 'thread-1',
            description: '码头线索',
            status: PlotThreadStatus.rising,
            involvedCharacters: ['liuxi'],
            introducedInScene: 'scene-01',
          ),
        ],
        chapterIndex: 1,
      );

      arcStore.updateArcState(state);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 验证状态已更新
      expect(arcStore.snapshot.narrativeArcState.activeThreads.length, 1);
      expect(
        arcStore.snapshot.narrativeArcState.activeThreads.first.description,
        '码头线索',
      );

      // 验证撤销栈
      expect(arcStore.canUndo, isTrue);
      expect(arcStore.snapshot.undoStack.length, 1);

      // 执行撤销
      arcStore.undo();
      expect(arcStore.snapshot.narrativeArcState.activeThreads, isEmpty);
      expect(arcStore.canUndo, isFalse);
    });

    test('resolveForeshadowing 标记伏笔为已解决', () async {
      final foreshadowing = Foreshadowing(
        id: 'fs-1',
        hint: '密信内容',
        plantedInScene: 'scene-01',
        plannedPayoff: '第三章揭晓',
        urgency: 1,
      );
      final state = NarrativeArcState(
        pendingForeshadowing: [foreshadowing],
      );

      arcStore.updateArcState(state);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 验证有悬空伏笔
      expect(arcStore.snapshot.hasDanglingForeshadowing, isTrue);
      expect(arcStore.snapshot.danglingForeshadowing.length, 1);

      // 标记为已解决
      arcStore.resolveForeshadowing('fs-1', 'scene-03');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(arcStore.snapshot.hasDanglingForeshadowing, isFalse);
      expect(
        arcStore
            .snapshot.narrativeArcState.pendingForeshadowing.first
            .resolvedInScene,
        'scene-03',
      );
    });

    test('updateForeshadowingUrgency 调整紧急度', () async {
      final foreshadowing = Foreshadowing(
        id: 'fs-2',
        hint: '神秘人物身份',
        plantedInScene: 'scene-02',
        urgency: 0,
      );
      final state = NarrativeArcState(
        pendingForeshadowing: [foreshadowing],
      );

      arcStore.updateArcState(state);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      arcStore.updateForeshadowingUrgency('fs-2', 2);
      expect(
        arcStore
            .snapshot.narrativeArcState.pendingForeshadowing.first.urgency,
        2,
      );

      // 验证 clamping
      arcStore.updateForeshadowingUrgency('fs-2', 99);
      expect(
        arcStore
            .snapshot.narrativeArcState.pendingForeshadowing.first.urgency,
        2,
      );
    });

    test('reorderScenes 回写场景顺序', () async {
      arcStore.reorderScenes(['scene-03', 'scene-01', 'scene-02']);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(arcStore.snapshot.sceneOrder, [
        'scene-03',
        'scene-01',
        'scene-02',
      ]);

      // 验证持久化
      final loaded = await arcStorage.load(
        projectId: arcStore.activeProjectId,
      );
      expect(loaded, isNotNull);
      final restored = StoryArcSnapshot.fromJson(loaded!);
      expect(restored.sceneOrder, ['scene-03', 'scene-01', 'scene-02']);
    });

    test('insertSceneAt 在指定位置插入场景', () async {
      arcStore.reorderScenes(['scene-01', 'scene-02']);
      arcStore.insertSceneAt('scene-01b', 1);
      expect(arcStore.snapshot.sceneOrder, [
        'scene-01',
        'scene-01b',
        'scene-02',
      ]);
    });

    test('insertSceneAt 超出范围时追加到末尾', () async {
      arcStore.reorderScenes(['scene-01']);
      arcStore.insertSceneAt('scene-99', 99);
      expect(arcStore.snapshot.sceneOrder, ['scene-01', 'scene-99']);
    });

    test('removeScene 移除指定场景', () async {
      arcStore.reorderScenes(['scene-01', 'scene-02', 'scene-03']);
      arcStore.removeScene('scene-02');
      expect(arcStore.snapshot.sceneOrder, ['scene-01', 'scene-03']);
    });

    test('JSON 序列化往返保持数据完整', () async {
      final state = NarrativeArcState(
        activeThreads: [
          PlotThread(
            id: 'thread-1',
            description: '暗线',
            status: PlotThreadStatus.climax,
            involvedCharacters: ['a', 'b'],
            introducedInScene: 'ch1/scene-01',
          ),
        ],
        closedThreads: [
          PlotThread(
            id: 'thread-2',
            description: '已关闭',
            status: PlotThreadStatus.resolved,
            involvedCharacters: ['c'],
            introducedInScene: 'ch1/scene-02',
            resolvedInScene: 'ch2/scene-01',
          ),
        ],
        pendingForeshadowing: [
          Foreshadowing(
            id: 'fs-1',
            hint: '伏笔提示',
            plantedInScene: 'ch1/scene-01',
            plannedPayoff: '后续回收',
            urgency: 2,
          ),
        ],
        thematicArcs: ['信任', '背叛'],
        chapterIndex: 3,
      );

      arcStore.updateArcState(state);
      arcStore.reorderScenes(['scene-A', 'scene-B', 'scene-C']);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // 从存储重新加载
      final loaded = await arcStorage.load(
        projectId: arcStore.activeProjectId,
      );
      expect(loaded, isNotNull);
      final restored = StoryArcSnapshot.fromJson(loaded!);

      expect(restored.narrativeArcState.activeThreads.length, 1);
      expect(
        restored.narrativeArcState.activeThreads.first.description,
        '暗线',
      );
      expect(
        restored.narrativeArcState.activeThreads.first.status,
        PlotThreadStatus.climax,
      );
      expect(restored.narrativeArcState.closedThreads.length, 1);
      expect(restored.narrativeArcState.pendingForeshadowing.length, 1);
      expect(
        restored.narrativeArcState.pendingForeshadowing.first.urgency,
        2,
      );
      expect(restored.narrativeArcState.thematicArcs, ['信任', '背叛']);
      expect(restored.narrativeArcState.chapterIndex, 3);
      expect(restored.sceneOrder, ['scene-A', 'scene-B', 'scene-C']);
    });

    test('deepCopy 不泄露可变引用', () {
      final state = NarrativeArcState(
        activeThreads: [
          PlotThread(
            id: 'thread-1',
            description: '原始',
            status: PlotThreadStatus.rising,
            involvedCharacters: ['char-1'],
            introducedInScene: 'scene-01',
          ),
        ],
        pendingForeshadowing: [
          Foreshadowing(
            id: 'fs-1',
            hint: '原始伏笔',
            plantedInScene: 'scene-01',
            urgency: 0,
          ),
        ],
      );
      arcStore.updateArcState(state);

      final snapshot = arcStore.snapshot;
      // NarrativeArcState 的列表是不可变的，突变应抛出异常
      expect(
        () => snapshot.narrativeArcState.activeThreads.add(
          PlotThread(
            id: 'thread-tamper',
            description: '篡改',
            status: PlotThreadStatus.rising,
            involvedCharacters: [],
            introducedInScene: '',
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // store 数据不受影响
      expect(arcStore.snapshot.narrativeArcState.activeThreads.length, 1);
      expect(
        arcStore.snapshot.narrativeArcState.activeThreads.first.id,
        'thread-1',
      );
    });

    test('撤销栈最多保留 20 步', () {
      // 推入 25 次变更
      for (var i = 0; i < 25; i++) {
        arcStore.updateArcState(
          NarrativeArcState(chapterIndex: i),
        );
      }

      expect(arcStore.snapshot.undoStack.length, 20);
      expect(arcStore.canUndo, isTrue);

      // 撤销一次
      arcStore.undo();
      expect(arcStore.snapshot.undoStack.length, 19);
    });

    test('replaceSnapshot 覆盖整个快照', () async {
      final replacement = StoryArcSnapshot(
        projectId: arcStore.activeProjectId,
        narrativeArcState: NarrativeArcState(
          activeThreads: [
            PlotThread(
              id: 'new-thread',
              description: '新情节线',
              status: PlotThreadStatus.rising,
              involvedCharacters: [],
              introducedInScene: 'scene-X',
            ),
          ],
          chapterIndex: 10,
        ),
        sceneOrder: ['scene-X', 'scene-Y'],
      );

      arcStore.replaceSnapshot(replacement);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(arcStore.snapshot.narrativeArcState.activeThreads.length, 1);
      expect(
        arcStore.snapshot.narrativeArcState.activeThreads.first.description,
        '新情节线',
      );
      expect(arcStore.snapshot.sceneOrder, ['scene-X', 'scene-Y']);
    });
  });

  group('StoryArcSnapshot JSON 往返', () {
    test('空快照序列化和反序列化', () {
      final original = StoryArcSnapshot.empty('project-test');
      final json = original.toJson();
      final restored = StoryArcSnapshot.fromJson(json);

      expect(restored.projectId, 'project-test');
      expect(restored.narrativeArcState.activeThreads, isEmpty);
      expect(restored.sceneOrder, isEmpty);
    });

    test('完整快照序列化和反序列化', () {
      final original = StoryArcSnapshot(
        projectId: 'project-full',
        narrativeArcState: NarrativeArcState(
          activeThreads: [
            PlotThread(
              id: 't1',
              description: 'desc',
              status: PlotThreadStatus.falling,
              involvedCharacters: ['c1'],
              introducedInScene: 's1',
            ),
          ],
          closedThreads: [
            PlotThread(
              id: 't2',
              description: 'closed',
              status: PlotThreadStatus.resolved,
              involvedCharacters: ['c2'],
              introducedInScene: 's2',
              resolvedInScene: 's3',
            ),
          ],
          pendingForeshadowing: [
            Foreshadowing(
              id: 'f1',
              hint: 'hint',
              plantedInScene: 's1',
              plannedPayoff: 'payoff',
              resolvedInScene: 's3',
              urgency: 1,
            ),
            Foreshadowing(
              id: 'f2',
              hint: 'unresolved',
              plantedInScene: 's2',
              urgency: 2,
            ),
          ],
          thematicArcs: ['theme1'],
          chapterIndex: 5,
        ),
        sceneOrder: ['s1', 's2', 's3'],
      );

      final json = original.toJson();
      final restored = StoryArcSnapshot.fromJson(json);

      expect(restored.projectId, 'project-full');
      expect(restored.narrativeArcState.activeThreads.length, 1);
      expect(restored.narrativeArcState.closedThreads.length, 1);
      expect(restored.narrativeArcState.pendingForeshadowing.length, 2);
      expect(restored.narrativeArcState.thematicArcs, ['theme1']);
      expect(restored.narrativeArcState.chapterIndex, 5);
      expect(restored.sceneOrder, ['s1', 's2', 's3']);

      // 验证伏笔细节
      final resolved = restored.narrativeArcState.pendingForeshadowing[0];
      expect(resolved.id, 'f1');
      expect(resolved.resolvedInScene, 's3');
      expect(resolved.urgency, 1);

      final unresolved = restored.narrativeArcState.pendingForeshadowing[1];
      expect(unresolved.id, 'f2');
      expect(unresolved.resolvedInScene, isNull);
      expect(unresolved.urgency, 2);

      // 验证悬空伏笔筛选
      expect(restored.hasDanglingForeshadowing, isTrue);
      expect(restored.danglingForeshadowing.length, 1);
      expect(restored.danglingForeshadowing.first.id, 'f2');
    });

    test('undoStack 不持久化到 JSON', () {
      final snapshot = StoryArcSnapshot(
        projectId: 'p1',
        undoStack: [
          NarrativeArcState(chapterIndex: 0),
          NarrativeArcState(chapterIndex: 1),
        ],
      );
      final json = snapshot.toJson();
      expect(json.containsKey('undoStack'), isFalse);
    });
  });
}
