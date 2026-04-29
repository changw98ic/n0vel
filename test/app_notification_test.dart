import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/events/app_event_bus_scope.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/app/widgets/app_notification.dart';

void main() {
  late AppEventBus eventBus;

  setUp(() {
    eventBus = AppEventBus();
  });

  tearDown(() {
    eventBus.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      AppEventBusScope(
        bus: eventBus,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              AppNotificationOverlay(child: child!),
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows success notification', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(
      context,
      title: '保存成功',
      severity: AppNoticeSeverity.success,
    );
    await tester.pumpAndSettle();

    expect(find.text('保存成功'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('shows error notification with message', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(
      context,
      title: '操作失败',
      message: '网络连接超时',
      severity: AppNoticeSeverity.error,
    );
    await tester.pumpAndSettle();

    expect(find.text('操作失败'), findsOneWidget);
    expect(find.text('网络连接超时'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('shows warning notification', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(
      context,
      title: '存储空间不足',
      severity: AppNoticeSeverity.warning,
    );
    await tester.pumpAndSettle();

    expect(find.text('存储空间不足'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('shows info notification', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(
      context,
      title: '新版本可用',
      severity: AppNoticeSeverity.info,
    );
    await tester.pumpAndSettle();

    expect(find.text('新版本可用'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('notification auto-dismisses after duration', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(
      context,
      title: '临时提示',
      duration: const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('临时提示'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('临时提示'), findsNothing);
  });

  testWidgets('dismisses notification on close button tap', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(context, title: '可关闭通知');
    await tester.pumpAndSettle();

    expect(find.text('可关闭通知'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('可关闭通知'), findsNothing);
  });

  testWidgets('stacks multiple notifications', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(context, title: '第一条通知');
    await tester.pumpAndSettle();
    showAppNotification(context, title: '第二条通知');
    await tester.pumpAndSettle();

    expect(find.text('第一条通知'), findsOneWidget);
    expect(find.text('第二条通知'), findsOneWidget);
  });

  testWidgets('notification card has semantic label', (tester) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(Scaffold).first);
    showAppNotification(
      context,
      title: '无障碍测试',
      message: '详细信息',
    );
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.text('无障碍测试').first);
    expect(semantics.label, contains('无障碍测试'));
    expect(semantics.label, contains('详细信息'));
  });

  testWidgets('publishes event via event bus directly', (tester) async {
    await tester.pumpWidget(
      AppEventBusScope(
        bus: eventBus,
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              AppNotificationOverlay(child: child!),
          home: const Scaffold(body: Text('test')),
        ),
      ),
    );
    await tester.pump();

    eventBus.publish(const NotificationRequestedEvent(title: '直接事件'));
    await tester.pumpAndSettle();

    expect(find.text('直接事件'), findsOneWidget);
  });
}
