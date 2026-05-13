import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/app.dart';
import 'package:novel_writer/app/di/app_providers.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/state/app_ai_history_store.dart';
import 'package:novel_writer/app/state/app_auto_backup.dart';
import 'package:novel_writer/app/state/app_draft_store.dart';
import 'package:novel_writer/app/state/app_scene_context_store.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/crash_detector.dart';
import 'package:novel_writer/app/widgets/crash_recovery_dialog.dart';
import 'package:novel_writer/features/projects/presentation/project_list_page.dart';

import 'test_support/test_registry.dart';

class _FakeCrashDetector implements CrashDetector {
  _FakeCrashDetector({this.dirtyShutdown = false});

  final bool dirtyShutdown;
  var cleanShutdownMarks = 0;

  @override
  bool wasDirtyShutdown() => dirtyShutdown;

  @override
  void markCleanShutdown() {
    cleanShutdownMarks++;
  }
}

class _ThrowingRestoreBackupService implements AutoBackupService {
  var restoreAttempts = 0;

  @override
  Future<BackupEntry> createBackup() {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteBackup(String id) {
    throw UnimplementedError();
  }

  @override
  Future<List<BackupEntry>> listBackups() async {
    return const [BackupEntry(id: 'latest', sizeBytes: 3, createdAtMs: 1)];
  }

  @override
  Future<int> pruneBackups({int keepCount = 10}) {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreBackup(String id) async {
    restoreAttempts++;
    throw StateError('restore failed');
  }
}

void _installTestRegistry() {
  NovelWriterApp.debugRegistryOverride = createTestRegistry();
}

void _clearOverrides() {
  NovelWriterApp.debugRegistryOverride = null;
  NovelWriterApp.debugCreateAutoBackupService = createDefaultAutoBackupService;
  NovelWriterApp.debugShowRecoveryDialog = showCrashRecoveryDialog;
}

void main() {
  setUp(_installTestRegistry);
  tearDown(_clearOverrides);

  group('NovelWriterApp initialization', () {
    testWidgets('all eight stores resolve via Riverpod providers', (
      tester,
    ) async {
      await tester.pumpWidget(const NovelWriterApp());
      await tester.pump();

      // Use a descendant context — ProviderScope.containerOf requires a
      // context that sits *inside* the ProviderScope, not the scope itself.
      final element = tester.element(find.byType(MaterialApp));
      final container = ProviderScope.containerOf(element);

      // All eight core providers must resolve without throwing.
      expect(container.read(appEventLogProvider), isNotNull);
      expect(container.read(appDraftStoreProvider), isNotNull);
      expect(container.read(appAiHistoryStoreProvider), isNotNull);
      expect(container.read(appVersionStoreProvider), isNotNull);
      expect(container.read(appSceneContextStoreProvider), isNotNull);
      expect(container.read(appSettingsStoreProvider), isNotNull);
      expect(container.read(appSimulationStoreProvider), isNotNull);
      expect(container.read(appWorkspaceStoreProvider), isNotNull);
    });

    testWidgets('all stores are reachable from leaf widgets', (tester) async {
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
              final container = ProviderScope.containerOf(context);
              eventLog = container.read(appEventLogProvider);
              draftStore = container.read(appDraftStoreProvider);
              aiHistoryStore = container.read(appAiHistoryStoreProvider);
              versionStore = container.read(appVersionStoreProvider);
              sceneContextStore = container.read(appSceneContextStoreProvider);
              settingsStore = container.read(appSettingsStoreProvider);
              simulationStore = container.read(appSimulationStoreProvider);
              workspaceStore = container.read(appWorkspaceStoreProvider);
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
              // Access every provider to force resolution.
              final container = ProviderScope.containerOf(context);
              container.read(appAiHistoryStoreProvider);
              container.read(appSceneContextStoreProvider);
              container.read(appSimulationStoreProvider);
              container.read(appDraftStoreProvider);
              container.read(appVersionStoreProvider);
              container.read(appWorkspaceStoreProvider);
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
        const NovelWriterApp(
          home: Text('custom home', textDirection: TextDirection.ltr),
        ),
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
              final container = ProviderScope.containerOf(context);
              settingsStore = container.read(appSettingsStoreProvider);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.themeMode, settingsStore!.snapshot.themeMode);
      expect(materialApp.theme, isNotNull);
      expect(materialApp.darkTheme, isNotNull);
    });

    testWidgets('disposes all registry-owned stores without errors', (
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

    testWidgets(
      'ordinary background lifecycle states do not mark clean shutdown',
      (tester) async {
        final crashDetector = _FakeCrashDetector();

        await tester.pumpWidget(NovelWriterApp(crashDetector: crashDetector));
        await tester.pump();

        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ]) {
          binding.handleAppLifecycleStateChanged(state);
          await tester.pump();

          expect(crashDetector.cleanShutdownMarks, 0);
        }

        // Resume through valid intermediate states.
        for (final state in [
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          binding.handleAppLifecycleStateChanged(state);
          await tester.pump();
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(crashDetector.cleanShutdownMarks, 1);
      },
    );

    testWidgets('detached lifecycle waits for dispose to mark clean shutdown', (
      tester,
    ) async {
      final crashDetector = _FakeCrashDetector();

      await tester.pumpWidget(NovelWriterApp(crashDetector: crashDetector));
      await tester.pump();

      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();

      expect(crashDetector.cleanShutdownMarks, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(crashDetector.cleanShutdownMarks, 1);
    });

    testWidgets('restore backup errors do not crash startup recovery overlay', (
      tester,
    ) async {
      final crashDetector = _FakeCrashDetector(dirtyShutdown: true);
      final backupService = _ThrowingRestoreBackupService();
      NovelWriterApp.debugCreateAutoBackupService = () => backupService;
      NovelWriterApp.debugShowRecoveryDialog =
          (context, {required backups}) async {
            return true;
          };

      await tester.pumpWidget(
        NovelWriterApp(
          crashDetector: crashDetector,
          home: const Text('ready', textDirection: TextDirection.ltr),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(backupService.restoreAttempts, 1);
      expect(find.text('ready'), findsOneWidget);
    });
  });
}
