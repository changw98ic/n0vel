import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/app.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/state/app_ai_history_storage.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_draft_storage.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_storage.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_storage.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_storage.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/features/projects/presentation/project_list_page.dart';

import 'test_support/fake_app_llm_client.dart';

void _installInMemoryStorages() {
  AppAiHistoryStore.debugStorageOverride = InMemoryAppAiHistoryStorage();
  AppDraftStore.debugStorageOverride = InMemoryAppDraftStorage();
  AppSceneContextStore.debugStorageOverride = InMemoryAppSceneContextStorage();
  AppSettingsStore.debugStorageOverride = InMemoryAppSettingsStorage();
  AppSettingsStore.debugLlmClientOverride = FakeAppLlmClient();
  AppSimulationStore.debugStorageOverride = InMemoryAppSimulationStorage();
  AppVersionStore.debugStorageOverride = InMemoryAppVersionStorage();
  AppWorkspaceStore.debugStorageOverride = InMemoryAppWorkspaceStorage();
}

void _clearOverrides() {
  AppAiHistoryStore.debugStorageOverride = null;
  AppDraftStore.debugStorageOverride = null;
  AppSceneContextStore.debugStorageOverride = null;
  AppSettingsStore.debugStorageOverride = null;
  AppSettingsStore.debugLlmClientOverride = null;
  AppSimulationStore.debugStorageOverride = null;
  AppVersionStore.debugStorageOverride = null;
  AppWorkspaceStore.debugStorageOverride = null;
}

void main() {
  setUp(_installInMemoryStorages);
  tearDown(_clearOverrides);

  group('NovelWriterApp initialization', () {
    testWidgets('mounts all eight scope widgets', (tester) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      expect(find.byType(AppEventLogScope), findsOneWidget);
      expect(find.byType(AppDraftScope), findsOneWidget);
      expect(find.byType(AppAiHistoryScope), findsOneWidget);
      expect(find.byType(AppVersionScope), findsOneWidget);
      expect(find.byType(AppSceneContextScope), findsOneWidget);
      expect(find.byType(AppSettingsScope), findsOneWidget);
      expect(find.byType(AppSimulationScope), findsOneWidget);
      expect(find.byType(AppWorkspaceScope), findsOneWidget);
    });

    testWidgets('all scopes are reachable from leaf widgets', (tester) async {
      AppEventLog? eventLog;
      AppDraftStore? draftStore;
      AppAiHistoryStore? aiHistoryStore;
      AppVersionStore? versionStore;
      AppSceneContextStore? sceneContextStore;
      AppSettingsStore? settingsStore;
      AppSimulationStore? simulationStore;
      AppWorkspaceStore? workspaceStore;

      await tester.pumpWidget(
        NovelWriterApp(
          home: Builder(
            builder: (context) {
              eventLog = AppEventLogScope.of(context);
              draftStore = AppDraftScope.of(context);
              aiHistoryStore = AppAiHistoryScope.of(context);
              versionStore = AppVersionScope.of(context);
              sceneContextStore = AppSceneContextScope.of(context);
              settingsStore = AppSettingsScope.of(context);
              simulationStore = AppSimulationScope.of(context);
              workspaceStore = AppWorkspaceScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      expect(eventLog, isNotNull);
      expect(eventLog!.sessionId, isNotEmpty);

      expect(draftStore, isNotNull);
      expect(aiHistoryStore, isNotNull);
      expect(versionStore, isNotNull);
      expect(sceneContextStore, isNotNull);
      expect(settingsStore, isNotNull);
      expect(simulationStore, isNotNull);
      expect(workspaceStore, isNotNull);
    });

    testWidgets('workspaceStore-dependent stores initialize without errors', (
      tester,
    ) async {
      // If any store failed to wire its workspaceStore dependency, initState
      // would throw during build. Pumping successfully proves all constructors
      // completed with valid arguments.
      await tester.pumpWidget(
        NovelWriterApp(
          home: Builder(
            builder: (context) {
              // Access every scope to force resolution.
              AppAiHistoryScope.of(context);
              AppSceneContextScope.of(context);
              AppSimulationScope.of(context);
              AppDraftScope.of(context);
              AppVersionScope.of(context);
              AppWorkspaceScope.of(context);
              return const Text('ok', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('default home is ProjectListPage', (tester) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      expect(find.byType(ProjectListPage), findsOneWidget);
    });

    testWidgets('custom home replaces default', (tester) async {
      await tester.pumpWidget(
        const NovelWriterApp(home: Text('custom home', textDirection: TextDirection.ltr)),
      );
      await tester.pump();

      expect(find.text('custom home'), findsOneWidget);
      expect(find.byType(ProjectListPage), findsNothing);
    });

    testWidgets('MaterialApp uses settings store themeMode', (tester) async {
      AppSettingsStore? settingsStore;

      await tester.pumpWidget(
        NovelWriterApp(
          home: Builder(
            builder: (context) {
              settingsStore = AppSettingsScope.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp),
      );
      expect(
        materialApp.themeMode,
        settingsStore!.snapshot.themeMode,
      );
      expect(materialApp.theme, isNotNull);
      expect(materialApp.darkTheme, isNotNull);
    });

    testWidgets('disposes all ChangeNotifier stores without errors', (
      tester,
    ) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      // Replacing the widget triggers dispose on the StatefulWidget state.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // If dispose threw, the test framework would have already failed.
      // This test verifies no exceptions propagate during teardown.
      expect(tester.takeException(), isNull);
    });
  });
}
