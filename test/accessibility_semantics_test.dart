import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/widgets/app_notice_banner.dart';
import 'package:novel_writer/app/widgets/desktop_shell.dart';

void main() {
  group('DesktopHeaderBar semantics', () {
    testWidgets('wraps header with Semantics widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
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
    testWidgets('wraps breadcrumb with Semantics containing label',
      (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DesktopBreadcrumbBar(breadcrumb: '路径A > 路径B'),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label?.contains('导航路径') == true,
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('DesktopStatusStrip semantics', () {
    testWidgets('wraps status strip with Semantics containing label',
      (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
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
          home: Scaffold(
            body: DesktopStatusStrip(leftText: '数据库读取失败'),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '状态栏: 数据库读取失败',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('DesktopMenuDrawer semantics', () {
    testWidgets('wraps drawer with navigation label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DesktopMenuDrawer(
              title: '菜单',
              items: [
                DesktopMenuItemData(
                  label: '书架',
                  isSelected: true,
                  onTap: () {},
                ),
                DesktopMenuItemData(label: '设置', onTap: () {}),
              ],
            ),
          ),
        ),
      );

      final drawerSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '菜单 导航菜单',
      );
      expect(drawerSemantics, findsOneWidget);

      final itemSemantics = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.selected == true &&
            widget.properties.label?.contains('书架') == true,
      );
      expect(itemSemantics, findsOneWidget);
    });
  });

  group('AppNoticeBanner semantics', () {
    testWidgets('wraps banner with Semantics containing title and message',
      (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
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
          home: Scaffold(
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
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: DesktopShellFrame(
            header: DesktopHeaderBar(title: '测试标题'),
            body: Text('内容区域'),
            statusBar: DesktopStatusStrip(leftText: '正常'),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == '应用主框架',
      );
      expect(semanticsFinder, findsOneWidget);
    });
  });

  group('DesktopHandleBar semantics', () {
    testWidgets('interactive handle has button semantics with label',
      (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: DesktopHandleBar(onTap: () {}),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.label == '切换侧边菜单',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('non-interactive handle excludes semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: DesktopHandleBar()),
        ),
      );

      final handle = find.byType(DesktopHandleBar);
      expect(handle, findsOneWidget);

      final excludeSemantics = find.descendant(
        of: handle,
        matching: find.byType(ExcludeSemantics),
      );
      expect(excludeSemantics, findsWidgets);
    });
  });
}
