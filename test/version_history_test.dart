import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/main.dart';

void main() {
  setUp(() {
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
  });

  testWidgets('shows version history with multiple versions', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: VersionHistoryPage()));
    await tester.pumpAndSettle();

    // The default store starts with one entry ("初始版本").
    // Use the version store to capture a second snapshot before rendering.
    final versionStore = AppVersionScope.of(
      tester.element(find.byType(VersionHistoryPage)),
    );
    versionStore.captureSnapshot(
      label: '手动保存',
      content: '第二个版本的内容',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(VersionHistoryPage.versionListKey), findsOneWidget);
    expect(find.text('版本池'), findsOneWidget);
    expect(find.text('版本信息'), findsOneWidget);
    expect(find.text('手动保存'), findsOneWidget);
    expect(find.text('初始版本'), findsOneWidget);
    expect(find.text('恢复此版本'), findsOneWidget);
  });

  testWidgets('disables restore when only one version exists', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: VersionHistoryPage()));
    await tester.pumpAndSettle();

    expect(find.text('当前章节只有 1 个版本'), findsOneWidget);
    expect(
      find.text(
        '当前只有一个章节版本，因此暂时不可恢复或对比历史版本。',
      ),
      findsOneWidget,
    );
    expect(find.text('暂不可恢复'), findsOneWidget);

    // The restore button must be disabled (OutlinedButton with onPressed: null).
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '暂不可恢复'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('enables restore for older versions', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: VersionHistoryPage()));
    await tester.pumpAndSettle();

    // Add two more versions so there are 3 total.
    final versionStore = AppVersionScope.of(
      tester.element(find.byType(VersionHistoryPage)),
    );
    versionStore.captureSnapshot(
      label: '手动保存',
      content: '第二个版本的内容',
    );
    await tester.pump();
    versionStore.captureSnapshot(
      label: 'AI 接受变更',
      content: '第三个版本的内容',
    );
    await tester.pumpAndSettle();

    // Select the second entry ("手动保存") and verify the restore button.
    await tester.tap(find.text('手动保存'));
    await tester.pumpAndSettle();

    expect(find.text('恢复此版本'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '恢复此版本'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('restores a previous version on tap', (tester) async {
    await tester.pumpWidget(const NovelWriterApp(home: VersionHistoryPage()));
    await tester.pumpAndSettle();

    // Add a second version so restore becomes available.
    final versionStore = AppVersionScope.of(
      tester.element(find.byType(VersionHistoryPage)),
    );
    versionStore.captureSnapshot(
      label: '手动保存',
      content: '新的草稿内容',
    );
    await tester.pumpAndSettle();

    // The first entry is now "手动保存". Tap "初始版本" (the older entry).
    await tester.tap(find.text('初始版本'));
    await tester.pumpAndSettle();

    // The detail panel should show the initial version content.
    expect(find.text('来源：初始版本'), findsOneWidget);

    // Tap the restore button.
    await tester.tap(find.text('恢复此版本'));
    await tester.pumpAndSettle();

    // After restore, a new "恢复版本" entry is prepended and the index resets to 0.
    expect(find.text('恢复版本'), findsOneWidget);
    // The version list now has 3 entries: 恢复版本, 手动保存, 初始版本.
    expect(find.text('手动保存'), findsOneWidget);
    expect(find.text('初始版本'), findsOneWidget);
  });
}
