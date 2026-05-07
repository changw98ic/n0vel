import 'package:flutter/material.dart';

import 'di/service_registration.dart';
import 'di/service_registry.dart';
import 'di/service_scope.dart';
import 'logging/app_event_log.dart';
import 'navigation/route_registration.dart';
import 'state/app_ai_history_store.dart';
import 'state/app_auto_backup.dart';
import 'state/app_draft_store.dart';
import 'state/app_scene_context_store.dart';
import 'state/app_settings_store.dart';
import 'state/app_simulation_store.dart';
import 'state/app_version_store.dart';
import 'state/app_workspace_store.dart';
import 'state/crash_detector.dart';
import '../features/projects/presentation/project_list_page.dart';
import '../features/author_feedback/data/author_feedback_store.dart';
import '../features/review_tasks/data/review_task_store.dart';
import 'theme/app_theme.dart';
import 'widgets/crash_recovery_dialog.dart';

class NovelWriterApp extends StatefulWidget {
  const NovelWriterApp({super.key, this.home});

  final Widget? home;

  @override
  State<NovelWriterApp> createState() => _NovelWriterAppState();
}

class _NovelWriterAppState extends State<NovelWriterApp>
    with WidgetsBindingObserver {
  late final ServiceRegistry _registry;
  final CrashDetector _crashDetector = CrashDetector();
  bool _crashDetected = false;
  bool _restoringBackup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    registerAppRoutes();
    _registry = ServiceRegistry();
    registerAppServices(_registry);

    // Check for dirty shutdown before the widget tree builds.
    _crashDetected = _crashDetector.wasDirtyShutdown();
  }

  @override
  void dispose() {
    _crashDetector.markCleanShutdown();
    WidgetsBinding.instance.removeObserver(this);
    _registry.disposeAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On desktop, going to inactive/hidden means the app is being
    // backgrounded or the window is closing.  Write the marker so a
    // subsequent crash kill will be detected.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _crashDetector.markCleanShutdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventLog = _registry.resolve<AppEventLog>();
    final settingsStore = _registry.resolve<AppSettingsStore>();
    final workspaceStore = _registry.resolve<AppWorkspaceStore>();
    final aiHistoryStore = _registry.resolve<AppAiHistoryStore>();
    final sceneContextStore = _registry.resolve<AppSceneContextStore>();
    final simulationStore = _registry.resolve<AppSimulationStore>();
    final draftStore = _registry.resolve<AppDraftStore>();
    final versionStore = _registry.resolve<AppVersionStore>();
    final authorFeedbackStore = _registry.resolve<AuthorFeedbackStore>();
    final reviewTaskStore = _registry.resolve<ReviewTaskStore>();

    return ServiceScope(
      registry: _registry,
      child: AppEventLogScope(
        log: eventLog,
        child: AppDraftScope(
          store: draftStore,
          child: AppAiHistoryScope(
            store: aiHistoryStore,
            child: AppVersionScope(
              store: versionStore,
              child: AppSceneContextScope(
                store: sceneContextStore,
                child: AppSettingsScope(
                  store: settingsStore,
                  child: AuthorFeedbackScope(
                    store: authorFeedbackStore,
                    child: ReviewTaskScope(
                      store: reviewTaskStore,
                      child: AppSimulationScope(
                        store: simulationStore,
                        child: ListenableBuilder(
                          listenable: settingsStore,
                          builder: (context, child) {
                            return AppWorkspaceScope(
                              store: workspaceStore,
                              child: MaterialApp(
                                debugShowCheckedModeBanner: false,
                                title: '小说工作台',
                                theme: AppTheme.light(),
                                darkTheme: AppTheme.dark(),
                                themeMode: settingsStore.snapshot.themeMode,
                                home: widget.home ?? const ProjectListPage(),
                                builder: (context, child) {
                                  return _CrashRecoveryOverlay(
                                    crashDetected: _crashDetected,
                                    restoringBackup: _restoringBackup,
                                    onRestoreComplete: () {
                                      setState(() {
                                        _restoringBackup = false;
                                      });
                                    },
                                    child: child!,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay that intercepts the first frame after a crash-detected startup
/// and shows the recovery dialog.
class _CrashRecoveryOverlay extends StatefulWidget {
  const _CrashRecoveryOverlay({
    required this.crashDetected,
    required this.restoringBackup,
    required this.onRestoreComplete,
    required this.child,
  });

  final bool crashDetected;
  final bool restoringBackup;
  final VoidCallback onRestoreComplete;
  final Widget child;

  @override
  State<_CrashRecoveryOverlay> createState() => _CrashRecoveryOverlayState();
}

class _CrashRecoveryOverlayState extends State<_CrashRecoveryOverlay> {
  bool _dialogShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.crashDetected && !_dialogShown) {
      _dialogShown = true;
      _offerRecovery();
    }
  }

  Future<void> _offerRecovery() async {
    final backupService = createDefaultAutoBackupService();
    final backups = await backupService.listBackups();
    if (backups.isEmpty || !mounted) return;

    final shouldRestore = await showCrashRecoveryDialog(
      context,
      backups: backups,
    );
    if (!mounted) return;

    if (shouldRestore) {
      final latest = backups.first;
      await backupService.restoreBackup(latest.id);
      if (!mounted) return;
    }

    widget.onRestoreComplete();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
