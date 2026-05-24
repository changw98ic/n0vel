import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/di/service_registry.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/theme/app_theme.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_controller.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_review_dialog.dart';
import 'package:novel_writer/features/workbench/presentation/workbench_ai_revision_helpers.dart';

void main() {
  group('WorkbenchAiReviewDialog', () {
    late ServiceRegistry registry;
    late AppWorkspaceStore workspaceStore;
    late AppDraftStore draftStore;
    late AppVersionStore versionStore;
    late AppAiHistoryStore historyStore;

    setUp(() {
      registry = ServiceRegistry();
      final eventBus = AppEventBus();
      final eventLog = AppEventLog();
      workspaceStore = AppWorkspaceStore(
        storage: InMemoryAppWorkspaceStorage(),
        eventBus: eventBus,
      );
      workspaceStore.createProject(projectName: '测试项目');
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
      );
      draftStore = AppDraftStore(
        storage: InMemoryAppDraftStorage(),
        workspaceStore: workspaceStore,
      );
      versionStore = AppVersionStore(
        storage: InMemoryAppVersionStorage(),
        workspaceStore: workspaceStore,
      );
      historyStore = AppAiHistoryStore(
        storage: InMemoryAppAiHistoryStorage(),
        workspaceStore: workspaceStore,
      );
      final sceneContextStore = AppSceneContextStore(
        storage: InMemoryAppSceneContextStorage(),
        workspaceStore: workspaceStore,
      );

      registry
        ..registerSingleton<AppEventBus>(eventBus)
        ..registerSingleton<AppEventLog>(eventLog)
        ..registerSingleton<AppWorkspaceStore>(workspaceStore)
        ..registerSingleton<AppSettingsStore>(settingsStore)
        ..registerSingleton<AppDraftStore>(draftStore)
        ..registerSingleton<AppVersionStore>(versionStore)
        ..registerSingleton<AppAiHistoryStore>(historyStore)
        ..registerSingleton<AppSceneContextStore>(sceneContextStore);
    });

    tearDown(() {
      registry.disposeAll();
    });

    testWidgets('displays adoptable units with accept/keep-original buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: 'Previous text.',
          originalText: 'Original text.',
          nextText: 'Next text.',
          authorPrompt: 'Make it better',
          suggestionText: 'Suggested text.',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) => Future.value(null),
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the adoptable unit
      expect(find.text('原文'), findsOneWidget);
      expect(find.text('建议'), findsOneWidget);
      expect(find.text('采纳建议'), findsOneWidget);
      expect(find.text('保留原文'), findsOneWidget);
    });

    testWidgets('toggling unit acceptance updates the accepted text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: '',
          originalText: 'Original text.',
          nextText: '',
          authorPrompt: 'Rewrite',
          suggestionText: 'Suggested text.',
        ),
      ];

      String? acceptedText;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) {
                  acceptedText = text;
                  return Future.value(null);
                },
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, the candidate should be accepted
      expect(find.text('采纳建议'), findsOneWidget);
      expect(find.text('保留原文'), findsOneWidget);

      // Tap "接受变更" to save with candidate accepted
      await tester.tap(find.text('接受变更'));
      await tester.pumpAndSettle();

      // The accepted text should be the suggestion
      expect(acceptedText, 'Suggested text.');
    });

    testWidgets('shows paragraph-level units for rewrite blocks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: '',
          originalText: 'First paragraph.\n\nSecond paragraph.',
          nextText: '',
          authorPrompt: 'Rewrite',
          suggestionText: 'Rewritten first.\n\nRewritten second.',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) => Future.value(null),
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show two paragraph-level units
      expect(find.text('原文'), findsNWidgets(2));
      expect(find.text('建议'), findsNWidgets(2));
    });

    testWidgets('shows metadata in dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: '',
          originalText: 'Original text.',
          nextText: '',
          authorPrompt: 'Rewrite',
          suggestionText: 'Suggested text.',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) => Future.value(null),
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show metadata
      expect(find.text('请求配置：Test Provider · model'), findsOneWidget);
      expect(find.text('接口：api.test.com'), findsOneWidget);
      expect(find.text('风格约束：Test Style'), findsOneWidget);
    });

    testWidgets('disables accept button when all candidates are rejected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: '',
          originalText: 'Original text.',
          nextText: '',
          authorPrompt: 'Rewrite',
          suggestionText: 'Suggested text.',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) => Future.value(null),
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially one candidate is accepted, so accept button is enabled
      expect(find.text('接受变更'), findsOneWidget);
      final acceptButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('接受变更'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(acceptButton.onPressed, isNotNull);

      // Tap "保留原文" to reject the only candidate
      await tester.tap(find.text('保留原文'));
      await tester.pumpAndSettle();

      // Accept button should now be disabled
      final disabledButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('接受变更'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(disabledButton.onPressed, isNull);

      // Warning text should be visible
      expect(find.text('至少采纳 1 个建议段落'), findsOneWidget);
    });

    testWidgets('re-enables accept button when re-accepting a candidate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: '',
          originalText: 'Original text.',
          nextText: '',
          authorPrompt: 'Rewrite',
          suggestionText: 'Suggested text.',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) => Future.value(null),
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reject the only candidate
      await tester.tap(find.text('保留原文'));
      await tester.pumpAndSettle();

      // Accept button should be disabled
      var button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('接受变更'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      // Re-accept the candidate
      await tester.tap(find.text('采纳建议'));
      await tester.pumpAndSettle();

      // Accept button should be enabled again
      button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('接受变更'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);

      // Warning text should be gone
      expect(find.text('至少采纳 1 个建议段落'), findsNothing);
    });

    testWidgets('onAccept not called when accept button is disabled', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final blocks = [
        const WorkbenchAiReviewBlock(
          blockLabel: '修改块 1',
          previousText: '',
          originalText: 'Original text.',
          nextText: '',
          authorPrompt: 'Rewrite',
          suggestionText: 'Suggested text.',
        ),
      ];

      var onAcceptCalled = false;
      String? capturedText;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [serviceRegistryProvider.overrideWithValue(registry)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: WorkbenchAiReviewDialog(
                reviewTitle: 'AI 修改确认',
                blocks: blocks,
                metadata: const AiRequestMetadata(
                  providerSummary: 'Test Provider · model',
                  endpointLabel: 'api.test.com',
                  styleSummary: 'Test Style',
                  sceneSummary: 'Test Scene',
                  characterSummary: 'Test Character',
                  worldSummary: 'Test World',
                  simulationSummary: 'Test Simulation',
                ),
                original: draftStore.snapshot.text,
                continueMode: false,
                onAccept: (text) {
                  onAcceptCalled = true;
                  capturedText = text;
                  return Future.value(null);
                },
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reject the only candidate
      await tester.tap(find.text('保留原文'));
      await tester.pumpAndSettle();

      // Try to tap the disabled accept button (should do nothing)
      await tester.tap(find.text('接受变更'));
      await tester.pumpAndSettle();

      // onAccept should not have been called
      expect(onAcceptCalled, isFalse);
      expect(capturedText, isNull);
    });
  });
}
