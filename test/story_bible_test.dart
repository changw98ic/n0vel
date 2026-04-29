import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/di/service_scope.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/story_outline_storage.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/story_bible/domain/story_bible_models.dart';
import 'package:novel_writer/features/story_bible/presentation/story_bible_page.dart';

void main() {
  tearDown(() {
    AppWorkspaceStore.debugStorageOverride = null;
    StoryOutlineStore.debugStorageOverride = null;
  });

  test('aggregates project facts without inventing generation status', () {
    const aggregator = StoryBibleAggregator();
    const project = ProjectRecord(
      id: 'project-a',
      sceneId: 'scene-a',
      title: '谐振之城',
      genre: '都市奇幻',
      summary: '倒悬城市与亡者回声的调查故事。',
      recentLocation: '第 1 章 / 场景 01 · 凌晨出警',
      lastOpenedAtMs: 1,
    );

    final bible = aggregator.build(
      project: project,
      characters: const [
        CharacterRecord(
          id: 'char-lu',
          name: '陆沉',
          role: '调查员',
          need: '查清回声源头',
          summary: '能听见低频亡者回响。',
        ),
      ],
      worldNodes: const [
        WorldNodeRecord(
          id: 'world-city',
          title: '倒悬城市',
          type: '地点',
          location: '盐港上空',
          summary: '城市在异常频率中上下翻转。',
          ruleSummary: '谐振器会放大亡者呼名。',
        ),
      ],
      scenes: const [
        SceneRecord(
          id: 'scene-01',
          chapterLabel: '第 1 章 / 场景 01',
          title: '凌晨出警',
          summary: '陆沉赶赴第一处回声现场。',
        ),
      ],
      auditIssues: const [
        AuditIssueRecord(id: 'audit-open', title: '动机不足'),
        AuditIssueRecord(
          id: 'audit-done',
          title: '语气不稳',
          status: AuditIssueStatus.resolved,
        ),
      ],
      outline: const StoryOutlineSnapshot(
        projectId: 'project-a',
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'chapter-01',
            title: '第一章 回声醒来',
            summary: '主角进入异常调查。',
            scenes: [
              StoryOutlineSceneSnapshot(
                id: 'scene-01',
                title: '凌晨出警',
                summary: '接到谐振器警报。',
              ),
            ],
          ),
        ],
      ),
    );

    expect(bible.projectTitle, '谐振之城');
    expect(
      bible.factSections
          .singleWhere((section) => section.title == '项目 Brief')
          .entries
          .single
          .body,
      contains('倒悬城市'),
    );
    expect(
      bible.factSections
          .singleWhere((section) => section.title == '角色设定事实')
          .entries
          .single
          .title,
      '陆沉',
    );
    expect(
      bible.factSections
          .singleWhere((section) => section.title == '世界观设定事实')
          .entries
          .single
          .body,
      contains('谐振器'),
    );
    expect(
      bible.factSections
          .singleWhere((section) => section.title == '场景 / 章节摘要')
          .entries
          .single
          .meta,
      '第 1 章 / 场景 01',
    );
    expect(
      bible.factSections
          .singleWhere((section) => section.title == '大纲摘要')
          .entries
          .single
          .body,
      contains('接到谐振器警报'),
    );

    final generation = bible.statusSections.singleWhere(
      (section) => section.title == '生成状态占位',
    );
    expect(generation.entries.first.meta, '未推断');
    expect(generation.entries.last.body, contains('不提供完整伏笔系统'));

    final review = bible.statusSections.singleWhere(
      (section) => section.title == '审稿状态占位',
    );
    expect(review.entries.single.meta, '开放 1 / 已处理 1');
  });

  testWidgets('renders fact and status columns as separate surfaces', (
    tester,
  ) async {
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
    StoryOutlineStore.debugStorageOverride = InMemoryStoryOutlineStorage();

    final registry = ServiceRegistry();
    final workspaceStore = AppWorkspaceStore();
    final outlineStore = StoryOutlineStore(workspaceStore: workspaceStore);
    registry.registerSingleton<AppWorkspaceStore>(workspaceStore);
    registry.registerSingleton<StoryOutlineStore>(outlineStore);
    addTearDown(registry.disposeAll);

    await tester.pumpWidget(
      ServiceScope(
        registry: registry,
        child: AppWorkspaceScope(
          store: workspaceStore,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const StoryBiblePage(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(StoryBiblePage.factsKey), findsOneWidget);
    expect(find.byKey(StoryBiblePage.statusKey), findsOneWidget);
    expect(find.text('设定事实'), findsNothing);
    expect(find.text('生成状态占位'), findsOneWidget);
    expect(find.text('审稿状态占位'), findsOneWidget);
    expect(find.textContaining('不会把缺失的生成流水线状态伪装成已完成'), findsOneWidget);
  });
}
