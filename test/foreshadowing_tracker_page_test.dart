import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/bible/data/foreshadowing_store.dart';
import 'package:novel_writer/features/bible/presentation/foreshadowing_tracker_page.dart';

void main() {
  testWidgets('creates foreshadowing and updates status reminders', (
    tester,
  ) async {
    final store = ForeshadowingStore(
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    addTearDown(store.dispose);

    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ForeshadowingTrackerPage(
          store: store,
          initialRelatedChapterLabel: '第 3 章 / 场景 05',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('新增伏笔'), findsOneWidget);
    expect(find.text('伏笔追踪'), findsOneWidget);
    expect(find.text('暂无需要提醒的伏笔'), findsOneWidget);

    await tester.enterText(
      find.byKey(ForeshadowingTrackerPage.titleFieldKey),
      '码头门禁异常',
    );
    await tester.enterText(
      find.byKey(ForeshadowingTrackerPage.descriptionFieldKey),
      '门禁记录与真实通行不一致，后续需要兑现。',
    );
    await tester.enterText(
      find.byKey(ForeshadowingTrackerPage.relatedChapterFieldKey),
      '第 3 章 / 场景 05',
    );
    await tester.tap(find.byKey(ForeshadowingTrackerPage.createButtonKey));
    await tester.pumpAndSettle();

    expect(store.threads, hasLength(1));
    expect(store.threads.first.status, ForeshadowingStatus.undeveloped);
    expect(find.text('码头门禁异常'), findsWidgets);
    expect(find.text('第 3 章 / 场景 05'), findsWidgets);
    expect(find.text('未展开'), findsWidgets);
    expect(find.text('暂无需要提醒的伏笔'), findsNothing);

    await tester.tap(
      find.byKey(ForeshadowingTrackerPage.developedStatusButtonKey),
    );
    await tester.pumpAndSettle();

    expect(store.threads.first.status, ForeshadowingStatus.developed);
    expect(find.text('已展开'), findsWidgets);
    expect(store.reminders, hasLength(1));

    await tester.tap(
      find.byKey(ForeshadowingTrackerPage.abandonedStatusButtonKey),
    );
    await tester.pumpAndSettle();

    expect(store.threads.first.status, ForeshadowingStatus.abandoned);
    expect(store.reminders, isEmpty);
    expect(find.text('已废弃'), findsWidgets);
    expect(find.text('暂无需要提醒的伏笔'), findsOneWidget);
  });
}
