import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/widgets/app_notice_banner.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';

void main() {
  group('DesktopHeaderBar semantics', () {
    testWidgets('wraps header with Semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: DesktopHeaderBar(title: '项目列表', subtitle: '管理你的作品'),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.header == true,
      );
      expect(semanticsFinder, findsWidgets);
    });
  });

  group('DesktopBreadcrumbBar semantics', () {
    testWidgets('wraps breadcrumb with Semantics containing label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: DesktopBreadcrumbBar(breadcrumb: '路径A > 路径B'),
          ),
        ),
      );

      final textFinder = find.text('路径A > 路径B');
      expect(textFinder, findsOneWidget);
    });
  });

  group('DesktopStatusStrip semantics', () {
    testWidgets('wraps status strip with Semantics containing label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: DesktopStatusStrip(
              leftText: '本地数据库正常',
              rightText: '书架共 5 部作品',
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.contains('状态栏') == true,
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('status strip without right text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DesktopStatusStrip(leftText: '数据库读取失败')),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '状态栏: 数据库读取失败',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('AppNoticeBanner semantics', () {
    testWidgets('wraps banner with Semantics containing title and message', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppNoticeBanner(
              title: '导入失败',
              message: '工程包结构不完整',
              severity: AppNoticeSeverity.error,
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label?.contains('导入失败') == true &&
            widget.properties.label?.contains('工程包结构不完整') == true,
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('banner without message has title in label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AppNoticeBanner(
              title: '操作成功',
              severity: AppNoticeSeverity.success,
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.liveRegion == true &&
            widget.properties.label == '操作成功',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('DesktopShellFrame semantics', () {
    testWidgets('wraps shell frame with app label', (tester) async {
      final registry = ServiceRegistry();
      registry.registerSingleton<AppSettingsStore>(
        AppSettingsStore(storage: InMemoryAppSettingsStorage()),
      );
      addTearDown(() => registry.disposeAll());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const DesktopShellFrame(
              header: DesktopHeaderBar(title: '测试标题'),
              body: Text('内容区域'),
              statusBar: DesktopStatusStrip(leftText: '正常'),
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == '应用主框架',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });
}
