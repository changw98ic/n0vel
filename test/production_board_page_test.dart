import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.byKey(ProductionBoardPage.recentRunKey), findsOneWidget);
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
}
