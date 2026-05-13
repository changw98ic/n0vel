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

  testWidgets('renders reading mode with chapter content', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ReadingModePage(
          session: ReadingSessionData(
            projectTitle: '月潮回声',
            initialSceneId: 'scene-01',
            documents: [
              ReadingSceneDocument(
                sceneId: 'scene-01',
                locationLabel: '第 1 章 · 风暴前夜',
                text: '她推开仓库门，雨水顺着袖口滴进掌心。',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ReadingModePage.pageBodyKey), findsOneWidget);
    expect(find.text('她推开仓库门，雨水顺着袖口滴进掌心。'), findsOneWidget);
    expect(find.text('月潮回声 · 第 1 章 · 风暴前夜'), findsOneWidget);
    expect(find.text('返回写作'), findsOneWidget);
    expect(find.text('单页'), findsOneWidget);
  });

  testWidgets('closes reading mode on button tap', (tester) async {
    await tester.pumpWidget(
      const NovelWriterApp(
        home: ReadingModePage(
          session: ReadingSessionData(
            projectTitle: '月潮回声',
            initialSceneId: 'scene-01',
            documents: [
              ReadingSceneDocument(
                sceneId: 'scene-01',
                locationLabel: '第 1 章 · 风暴前夜',
                text: '测试关闭',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试关闭'), findsOneWidget);

    // Tap close button — since this is the root route, Navigator.pop removes it.
    // We wrap in a navigator to verify the pop occurred.
    const closeKey = ReadingModePage.closeButtonKey;
    expect(find.byKey(closeKey), findsOneWidget);
    await tester.tap(find.byKey(closeKey));
    await tester.pumpAndSettle();

    // After pop, the ReadingModePage should be gone.
    expect(find.byKey(ReadingModePage.pageBodyKey), findsNothing);
    expect(find.text('测试关闭'), findsNothing);
  });

  testWidgets('navigates to next page via hotzone', (tester) async {
    final longText = '甲' * 500;
    await tester.pumpWidget(
      NovelWriterApp(
        home: ReadingModePage(
          session: ReadingSessionData(
            projectTitle: '月潮回声',
            initialSceneId: 'scene-01',
            documents: [
              ReadingSceneDocument(
                sceneId: 'scene-01',
                locationLabel: '第 1 章 · 风暴前夜',
                text: longText,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Start on page 1 of 3.
    expect(find.text('第 1 / 3 页'), findsOneWidget);

    // Tap the next hotzone.
    await tester.tap(find.byKey(ReadingModePage.nextHotzoneKey));
    await tester.pumpAndSettle();

    // Should advance to page 2.
    expect(find.text('第 2 / 3 页'), findsOneWidget);
  });

  testWidgets('navigates to previous page via hotzone', (tester) async {
    final longText = '甲' * 500;
    await tester.pumpWidget(
      NovelWriterApp(
        home: ReadingModePage(
          session: ReadingSessionData(
            projectTitle: '月潮回声',
            initialSceneId: 'scene-01',
            documents: [
              ReadingSceneDocument(
                sceneId: 'scene-01',
                locationLabel: '第 1 章 · 风暴前夜',
                text: longText,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to page 3 first.
    await tester.tap(find.byKey(ReadingModePage.nextHotzoneKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ReadingModePage.nextHotzoneKey));
    await tester.pumpAndSettle();
    expect(find.text('第 3 / 3 页'), findsOneWidget);

    // Now navigate back via the previous hotzone.
    await tester.tap(find.byKey(ReadingModePage.previousHotzoneKey));
    await tester.pumpAndSettle();

    expect(find.text('第 2 / 3 页'), findsOneWidget);
  });
}
