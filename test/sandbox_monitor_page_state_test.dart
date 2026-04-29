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
    AppSceneContextStore.debugStorageOverride = InMemoryAppSceneContextStorage();
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

  group('preview status rendering', () {
    testWidgets('running preview shows active stage summary', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.running),
        ),
      );

      expect(find.text('模拟进行中'), findsWidgets);
      expect(find.text('准备上下文进行中'), findsOneWidget);
      expect(find.text('模拟聊天室'), findsOneWidget);
    });

    testWidgets('completed preview shows all stages done', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      expect(find.text('模拟已完成'), findsWidgets);
      expect(find.text('叙述改写已完成'), findsOneWidget);
      expect(find.text('模拟聊天室'), findsOneWidget);
    });

    testWidgets('failed preview shows failure headline and summary', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.failed),
        ),
      );

      expect(find.text('运行失败摘要'), findsWidgets);
      expect(find.text('多角色讨论失败'), findsOneWidget);
      expect(find.text('模拟聊天室'), findsOneWidget);
    });

    testWidgets('none preview renders the empty state card', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.none),
        ),
      );

      expect(find.text('还没有模拟过程'), findsOneWidget);
      expect(find.text('关闭'), findsOneWidget);
    });
  });

  group('default participant selection', () {
    testWidgets('selects liuXi by default in non-failure mode', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      expect(
        find.byKey(SandboxMonitorPage.liuXiParticipantKey),
        findsOneWidget,
      );
      expect(
        find.byKey(SandboxMonitorPage.editPromptButtonKey),
        findsOneWidget,
      );
    });

    testWidgets('selects stateMachine by default in failure mode', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(home: SandboxMonitorPage(failureMode: true)),
      );

      expect(
        find.byKey(SandboxMonitorPage.stateMachineParticipantKey),
        findsOneWidget,
      );
      expect(
        find.byKey(SandboxMonitorPage.editPromptButtonKey),
        findsOneWidget,
      );
    });

    testWidgets('all five participant tiles appear in the agent list', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      expect(
        find.byKey(SandboxMonitorPage.directorParticipantKey),
        findsOneWidget,
      );
      expect(
        find.byKey(SandboxMonitorPage.liuXiParticipantKey),
        findsOneWidget,
      );
      expect(
        find.byKey(SandboxMonitorPage.yueRenParticipantKey),
        findsOneWidget,
      );
      expect(
        find.byKey(SandboxMonitorPage.fuXingzhouParticipantKey),
        findsOneWidget,
      );
      expect(
        find.byKey(SandboxMonitorPage.stateMachineParticipantKey),
        findsOneWidget,
      );
    });
  });

  group('participant switching', () {
    testWidgets('tapping yueRen updates the run summary focus label', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.yueRenParticipantKey));
      await tester.pump();

      expect(find.text('岳人 · 对峙'), findsWidgets);
      expect(
        find.byKey(SandboxMonitorPage.editPromptButtonKey),
        findsOneWidget,
      );
    });

    testWidgets('tapping fuXingzhou updates the run summary focus label', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.fuXingzhouParticipantKey));
      await tester.pump();

      expect(find.text('傅行舟 · 压力'), findsWidgets);
    });

    testWidgets('tapping director updates the run summary focus label', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.directorParticipantKey));
      await tester.pump();

      expect(find.text('导演 · 调度'), findsWidgets);
    });

    testWidgets('tapping stateMachine updates the run summary focus label', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.stateMachineParticipantKey));
      await tester.pump();

      expect(find.text('状态机 · 裁决'), findsWidgets);
    });

    testWidgets('re-selecting the same participant keeps focus unchanged', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      expect(find.text('柳溪 · 焦点'), findsWidgets);

      await tester.tap(find.byKey(SandboxMonitorPage.liuXiParticipantKey));
      await tester.pump();

      expect(find.text('柳溪 · 焦点'), findsWidgets);
    });
  });

  group('feedback input', () {
    testWidgets('send button does nothing when feedback is empty', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      final beforeMessages = find.textContaining('任务调整').evaluate().length;

      await tester.tap(find.byKey(SandboxMonitorPage.sendFeedbackButtonKey));
      await tester.pump();

      expect(
        find.textContaining('任务调整').evaluate().length,
        beforeMessages,
      );
    });

    testWidgets('feedback text field clears after sending', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.enterText(
        find.byKey(SandboxMonitorPage.feedbackFieldKey),
        '让柳溪更主动',
      );
      await tester.pump();

      final before = tester.widget<TextField>(
        find.byKey(SandboxMonitorPage.feedbackFieldKey),
      );
      expect(before.controller?.text, '让柳溪更主动');

      await tester.tap(find.byKey(SandboxMonitorPage.sendFeedbackButtonKey));
      await tester.pump();

      final after = tester.widget<TextField>(
        find.byKey(SandboxMonitorPage.feedbackFieldKey),
      );
      expect(after.controller?.text, '');
    });

    testWidgets('sent feedback reorders task assignment in the chat', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.enterText(
        find.byKey(SandboxMonitorPage.feedbackFieldKey),
        '让岳人先说话',
      );
      await tester.tap(find.byKey(SandboxMonitorPage.sendFeedbackButtonKey));
      await tester.pump();

      expect(find.textContaining('任务 1：岳人围绕'), findsWidgets);
    });
  });

  group('prompt editing', () {
    testWidgets('canceling the prompt dialog leaves the prompt unchanged', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      final originalPrompt = find.descendant(
        of: find.byKey(SandboxMonitorPage.liuXiParticipantKey),
        matching: find.textContaining('先抬出异常'),
      );
      expect(originalPrompt, findsOneWidget);

      await tester.tap(find.byKey(SandboxMonitorPage.editPromptButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(SandboxMonitorPage.liuXiParticipantKey),
          matching: find.textContaining('先抬出异常'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('saving an empty prompt removes the custom override', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      await tester.tap(find.byKey(SandboxMonitorPage.editPromptButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(SandboxMonitorPage.editPromptFieldKey),
        '',
      );
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // Falls back to default prompt
      expect(
        find.descendant(
          of: find.byKey(SandboxMonitorPage.liuXiParticipantKey),
          matching: find.textContaining('先抬出异常'),
        ),
        findsOneWidget,
      );
    });
  });

  group('run summary panel', () {
    testWidgets('completed run shows output category chips', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      expect(find.text('运行摘要'), findsOneWidget);
      expect(find.text('输出分类'), findsOneWidget);
      expect(find.textContaining('发言'), findsWidgets);
      expect(find.textContaining('意图'), findsWidgets);
      expect(find.textContaining('裁决'), findsWidgets);
    });

    testWidgets('completed run shows completed stage count', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.completed),
        ),
      );

      expect(find.textContaining('阶段 3/3'), findsOneWidget);
    });

    testWidgets('failed run shows stage breakdown', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(home: SandboxMonitorPage(failureMode: true)),
      );

      expect(find.text('运行失败摘要'), findsWidgets);
      expect(find.textContaining('阶段'), findsWidgets);
    });

    testWidgets('running state shows initial stage progress', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(
          home: SandboxMonitorPage(previewStatus: SimulationStatus.running),
        ),
      );

      expect(find.textContaining('阶段'), findsWidgets);
      expect(find.text('当前场景'), findsOneWidget);
    });
  });
}
