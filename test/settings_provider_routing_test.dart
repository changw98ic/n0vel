import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/widgets/desktop_shell.dart';
import 'package:novel_writer/main.dart';
import 'test_support/test_registry.dart';

void main() {
  setUp(() {
    NovelWriterApp.debugRegistryOverride = createTestRegistry();
  });

  tearDown(() {
    NovelWriterApp.debugRegistryOverride = null;
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

  /// Find the OutlinedButton containing "取消" text (used in dialogs).
  Finder dialogCancelButton() => find.widgetWithText(OutlinedButton, '取消');

  Future<void> tapVisibleKey(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Open the add-provider dialog, fill fields, and save.
  Future<void> addProviderProfile(
    WidgetTester tester, {
    required String id,
    required String name,
    required String url,
    required String model,
    required String key,
  }) async {
    await tapVisibleKey(tester, SettingsShellPage.addProfileButtonKey);

    await tester.enterText(find.widgetWithText(TextField, '标识（英文，唯一）'), id);
    await tester.enterText(find.widgetWithText(TextField, '模型服务名称'), name);
    await tester.enterText(find.widgetWithText(TextField, '接口地址'), url);
    await tester.enterText(find.widgetWithText(TextField, '模型'), model);
    await tester.enterText(find.widgetWithText(TextField, '密钥'), key);
    await tester.pump();

    await tester.tap(dialogSaveButton());
    await tester.pumpAndSettle();
  }

  group('multi-provider section', () {
    testWidgets('shows empty state when no profiles exist', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      expect(find.text('多模型服务配置'), findsOneWidget);
      expect(find.text('暂无额外模型服务。'), findsOneWidget);
      expect(find.byKey(SettingsShellPage.addProfileButtonKey), findsOneWidget);
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
      expect(find.text('暂无额外模型服务。'), findsNothing);
    });

    testWidgets('provider catalog adds a provider without manual fields', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await tester.ensureVisible(
        find.byKey(SettingsShellPage.providerCatalogButtonKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SettingsShellPage.providerCatalogButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('DeepSeek · deepseek-chat'), findsOneWidget);
      await tester.tap(find.text('添加').first);
      await tester.pumpAndSettle();

      expect(find.text('智谱 GLM 中国按量 API · glm-5.1'), findsOneWidget);
      expect(find.text('https://open.bigmodel.cn/api/paas/v4'), findsOneWidget);
    });

    testWidgets('provider catalog lists common Chinese service templates', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await tester.ensureVisible(
        find.byKey(SettingsShellPage.providerCatalogButtonKey),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SettingsShellPage.providerCatalogButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('智谱 GLM 中国按量 API · glm-5.1'), findsOneWidget);
      expect(find.text('Z.AI GLM 国际按量 API · glm-5.1'), findsOneWidget);
      expect(find.text('智谱 GLM Coding Plan 中国 · glm-4.7'), findsOneWidget);
      expect(find.text('Z.AI GLM Coding Plan 国际 · glm-4.7'), findsOneWidget);
      expect(
        find.text('Kimi Code 会员 Coding API · kimi-for-coding'),
        findsOneWidget,
      );
      expect(find.text('阿里百炼 中国按量 API · qwen-plus'), findsOneWidget);
      expect(find.text('阿里百炼 国际按量 API · qwen-plus'), findsOneWidget);
      expect(find.text('阿里百炼 美国按量 API · qwen-plus-us'), findsOneWidget);
      expect(
        find.text('阿里百炼 Coding Plan 中国 · qwen3-coder-plus'),
        findsOneWidget,
      );
      expect(find.text('火山方舟 Coding Plan · ark-code-latest'), findsOneWidget);
      expect(find.text('MiniMax 国际 · MiniMax-M2.7'), findsOneWidget);
      expect(find.text('MiniMax 中国 · MiniMax-M2.7'), findsOneWidget);
      expect(
        find.text('MiniMax Coding Plan 国际 · codex-MiniMax-M2.7'),
        findsOneWidget,
      );
      expect(
        find.text('MiniMax Coding Plan 中国 · codex-MiniMax-M2.7'),
        findsOneWidget,
      );
      expect(
        find.text('腾讯 TokenHub Token Plan · hunyuan-2.0-instruct'),
        findsOneWidget,
      );
      expect(
        find.text('腾讯 TokenHub 企业版 · hunyuan-2.0-instruct'),
        findsOneWidget,
      );
      expect(find.text('美团 LongCat · LongCat-Flash-Chat'), findsOneWidget);
      expect(find.text('Xiaomi MiMo 按量 API · mimo-v2-pro'), findsOneWidget);
      expect(
        find.text('Xiaomi MiMo Token Plan CN · mimo-v2.5-pro'),
        findsOneWidget,
      );
    });

    testWidgets('add provider dialog dismisses on cancel', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 600);

      await tapVisibleKey(tester, SettingsShellPage.addProfileButtonKey);

      expect(find.byType(DesktopModalDialog), findsOneWidget);

      await tester.tap(dialogCancelButton());
      await tester.pumpAndSettle();

      expect(find.byType(DesktopModalDialog), findsNothing);
      expect(find.text('暂无额外模型服务。'), findsOneWidget);
    });
  });

  group('route rules section', () {
    testWidgets('shows empty state when no routes exist', (tester) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 800);

      expect(find.text('路由规则'), findsOneWidget);
      expect(find.text('暂无路由规则。'), findsOneWidget);
      expect(find.byKey(SettingsShellPage.addRouteButtonKey), findsOneWidget);
    });

    testWidgets('add route dialog is blocked when no profiles exist', (
      tester,
    ) async {
      await pumpSettingsPage(tester);
      await scrollProviderPanel(tester, 800);

      await tapVisibleKey(tester, SettingsShellPage.addRouteButtonKey);

      // No dialog should appear.
      expect(find.byType(DesktopModalDialog), findsNothing);
    });

    testWidgets('add route dialog creates a route card after profile exists', (
      tester,
    ) async {
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
      await tapVisibleKey(tester, SettingsShellPage.addRouteButtonKey);

      expect(find.byType(DesktopModalDialog), findsOneWidget);

      await tester.tap(dialogSaveButton());
      await tester.pumpAndSettle();

      expect(find.byType(DesktopModalDialog), findsNothing);
      expect(find.text('暂无路由规则。'), findsNothing);
      expect(find.text('散文生成 (scene_prose_generation)'), findsOneWidget);
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

    testWidgets('profile card can switch the default provider', (tester) async {
      await pumpSettingsPage(tester);
      await addProviderProfile(
        tester,
        id: 'deepseek',
        name: 'DeepSeek',
        url: 'https://api.deepseek.com',
        model: 'deepseek-chat',
        key: 'deepseek-key',
      );

      await tester.tap(find.byTooltip('设为默认').first);
      await tester.pumpAndSettle();

      expect(find.text('DeepSeek'), findsWidgets);
      expect(find.text('https://api.deepseek.com'), findsWidgets);
      expect(find.text('deepseek-chat'), findsWidgets);
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
      expect(find.text('暂无额外模型服务。'), findsOneWidget);
    });
  });
}
