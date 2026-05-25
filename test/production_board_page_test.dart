import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/production_board/domain/production_board_models.dart';
import 'package:novel_writer/features/production_board/presentation/production_board_components.dart';
import 'package:novel_writer/main.dart';
import 'test_support/test_registry.dart';

void main() {
  setUp(() {
    NovelWriterApp.debugRegistryOverride = createTestRegistry();
  });

  tearDown(() {
    NovelWriterApp.debugRegistryOverride = null;
  });

  testWidgets('production board renders progress, lanes, run, and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NovelWriterApp(home: ProductionBoardPage()));
    await tester.pump();

    expect(find.byKey(ProductionBoardPage.titleKey), findsOneWidget);
    expect(find.byKey(ProductionBoardPage.progressKey), findsOneWidget);
    expect(find.byKey(ProductionBoardPage.dailyTrendKey), findsOneWidget);
    expect(find.byKey(ProductionBoardPage.recentRunKey), findsOneWidget);
    expect(find.text('总字数 0'), findsOneWidget);
    expect(find.text('每日字数趋势'), findsOneWidget);
    expect(find.text('继续写作'), findsOneWidget);
    expect(find.text('打开工作台'), findsAtLeastNWidgets(1));
    expect(find.text('改稿清单'), findsOneWidget);
    expect(find.text('打开改稿清单'), findsOneWidget);
    expect(find.text('作者反馈'), findsOneWidget);
    expect(find.text('导出'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.byKey(ProductionBoardPage.lanesKey),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(ProductionBoardPage.lanesKey), findsOneWidget);
  });

  testWidgets('production chapter tiles expose chapter jump callback', (
    tester,
  ) async {
    ProductionBoardChapterCard? openedChapter;
    const chapter = ProductionBoardChapterCard(
      id: 'chapter-01',
      title: '第 1 章',
      statusLabel: '生成中',
      completedScenes: 1,
      totalScenes: 3,
      firstSceneId: 'scene-a',
      firstSceneLocation: '第 1 章 · 码头截停',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            height: 260,
            child: ProductionChapterList(
              chapters: const [chapter],
              onOpenChapter: (chapter) => openedChapter = chapter,
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(ProductionBoardPage.chapterTileKey('chapter-01')),
    );
    await tester.pump();

    expect(openedChapter, chapter);
  });
}
