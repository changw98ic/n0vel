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
import 'test_support/fake_app_llm_client.dart';

void main() {
  setUp(() {
    AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
    AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
    AppSceneContextStore.debugStorageOverride =
        InMemoryAppSceneContextStorage();
    AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
    AppSettingsStore.debugLlmClientOverride = FakeAppLlmClient();
    AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
    AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
    AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
  });

  tearDown(() {
    AppAiHistoryStore.debugStorageOverride = null;
    AppDraftStore.debugStorageOverride = null;
    AppSceneContextStore.debugStorageOverride = null;
    AppSettingsStore.debugStorageOverride = null;
    AppSettingsStore.debugLlmClientOverride = null;
    AppSimulationStore.debugStorageOverride = null;
    AppVersionStore.debugStorageOverride = null;
    AppWorkspaceStore.debugStorageOverride = null;
  });

  Future<void> pumpSettingsPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpWidget(const NovelWriterApp(home: SettingsShellPage()));
    await tester.pump();
  }

  /// Scroll the first ListView (provider panel) down by [delta] pixels.
  Future<void> scrollProviderPanel(WidgetTester tester, double delta) async {
    final listViews = find.byType(ListView);
    if (listViews.evaluate().isNotEmpty) {
      await tester.drag(listViews.first, Offset(0, -delta));
      await tester.pump();
    }
  }

  /// Find the FilledButton containing "保存" text (used in dialogs).
  Finder dialogSaveButton() => find.widgetWithText(FilledButton, '保存');

  /// Find the TextButton containing "取消" text (used in dialogs).
  Finder dialogCancelButton() => find.widgetWithText(TextButton, '取消');

  /// Open the add-provider dialog, fill fields, and save.
  Future<void> addProviderProfile(
    WidgetTester tester, {
    required String id,
    required String name,
    required String url,
    required String model,
    required String key,
  }) async {
    await tester.tap(find.byKey(SettingsShellPage.addProfileButtonKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '标识（英文，唯一）'),
      id,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '提供方名称'),
      name,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '接口地址'),
      url,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '模型'),
      model,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '密钥'),
      key,
    );
    await tester.pump();

    await tester.tap(dialogSaveButton());
    await tester.pumpAndSettle();
  }

  group('multi-provider section', () {
    testWidgets('shows empty state when no profiles exist', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      expect(find.text('多提供方配置'), findsOneWidget);
      expect(find.text('暂无额外提供方。'), findsOneWidget);
      expect(
        find.byKey(SettingsShellPage.addProfileButtonKey),
        findsOneWidget,
      );
    });

    testWidgets('add provider dialog creates a profile card', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      await addProviderProfile(
        tester,
        id: 'glm-review',
        name: '智谱 GLM',
        url: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        key: 'test-key',
      );

      expect(find.text('智谱 GLM · glm-5.1'), findsOneWidget);
      expect(find.text('暂无额外提供方。'), findsNothing);
    });

    testWidgets('add provider dialog dismisses on cancel', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      await tester.tap(find.byKey(SettingsShellPage.addProfileButtonKey));
      await tester.pumpAndSettle();

      // Dialog should be visible via its specific title widget (AlertDialog).
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(dialogCancelButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('暂无额外提供方。'), findsOneWidget);
    });
  });

  group('route rules section', () {
    testWidgets('shows empty state when no routes exist', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 800);

      expect(find.text('路由规则'), findsOneWidget);
      expect(find.text('暂无路由规则。'), findsOneWidget);
      expect(
        find.byKey(SettingsShellPage.addRouteButtonKey),
        findsOneWidget,
      );
    });

    testWidgets('add route dialog is blocked when no profiles exist',
        (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 800);

      await tester.tap(find.byKey(SettingsShellPage.addRouteButtonKey));
      await tester.pumpAndSettle();

      // No dialog should appear.
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('add route dialog creates a route card after profile exists',
        (tester) async {
      await pumpSettingsPage(tester);

      // First, add a provider profile.
      await scrollProviderPanel(tester, 600);
      await addProviderProfile(
        tester,
        id: 'glm-review',
        name: '智谱 GLM',
        url: 'https://open.bigmodel.cn/api/paas/v4',
        model: 'glm-5.1',
        key: 'test-key',
      );

      // Scroll further to reach the route section.
      await scrollProviderPanel(tester, 400);

      // Add a route.
      await tester.tap(find.byKey(SettingsShellPage.addRouteButtonKey));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Trace 名称模式'),
        'scene_review_*',
      );
      await tester.pump();

      await tester.tap(dialogSaveButton());
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('暂无路由规则。'), findsNothing);
      expect(find.text('scene_review_*'), findsOneWidget);
      expect(find.textContaining('智谱 GLM'), findsWidgets);
    });
  });

  group('profile and route display', () {
    testWidgets('profile card shows provider name and model', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      await addProviderProfile(
        tester,
        id: 'mimo',
        name: 'Xiaomi MiMo',
        url: 'https://token-plan-cn.xiaomimimo.com/v1',
        model: 'mimo-v2.5-pro',
        key: 'mimo-key',
      );

      // Scroll to make the new profile card visible.
      await scrollProviderPanel(tester, 200);

      expect(find.text('Xiaomi MiMo · mimo-v2.5-pro'), findsOneWidget);
    });

    testWidgets('deleting a profile removes its card', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      await addProviderProfile(
        tester,
        id: 'tmp',
        name: 'Temp',
        url: 'https://tmp.example.com/v1',
        model: 'glm-5.1',
        key: 'key',
      );

      expect(find.text('Temp · glm-5.1'), findsOneWidget);

      final deleteButtons = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Temp · glm-5.1'), findsNothing);
      expect(find.text('暂无额外提供方。'), findsOneWidget);
    });
  });
}
