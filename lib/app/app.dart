import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di/app_providers.dart';
import 'di/service_registration.dart';
import 'di/service_registry.dart';
import 'navigation/route_registration.dart';
import 'state/app_auto_backup.dart';
import 'state/crash_detector.dart';
import 'theme/app_theme.dart';
import 'widgets/crash_recovery_dialog.dart';

import '../features/projects/presentation/project_list_page.dart';

typedef CrashRecoveryDialogPresenter =
    Future<bool> Function(
      BuildContext context, {
      required List<BackupEntry> backups,
    });

class NovelWriterApp extends StatefulWidget {
  const NovelWriterApp({super.key, this.home, this.crashDetector});

  final Widget? home;
  final CrashDetector? crashDetector;

  static AutoBackupService Function() debugCreateAutoBackupService =
      createDefaultAutoBackupService;
  static CrashRecoveryDialogPresenter debugShowRecoveryDialog =
      showCrashRecoveryDialog;

  /// When non-null, used by [initState] instead of creating a fresh registry.
  /// Set in test setUp / cleared in tearDown to inject in-memory storages.
  static ServiceRegistry? debugRegistryOverride;

  @override
  State<NovelWriterApp> createState() => _NovelWriterAppState();
}

class _NovelWriterAppState extends State<NovelWriterApp>
    with WidgetsBindingObserver {
  late final ServiceRegistry _registry;
  late final CrashDetector _crashDetector;
  bool _crashDetected = false;
  bool _restoringBackup = false;
  bool _cleanShutdownMarked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    registerAppRoutes();
    _registry = NovelWriterApp.debugRegistryOverride ?? ServiceRegistry();
    if (NovelWriterApp.debugRegistryOverride == null) {
      registerAppServices(_registry);
    }
    _crashDetector = widget.crashDetector ?? CrashDetector();

    // Check for dirty shutdown before the widget tree builds.
    _crashDetected = _crashDetector.wasDirtyShutdown();
  }

  @override
  void dispose() {
    _markCleanShutdownOnce();
    WidgetsBinding.instance.removeObserver(this);
    _registry.disposeAll();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding, hiding, or pausing is not a clean process shutdown.
    if (state == AppLifecycleState.detached) {
      _markCleanShutdownOnce();
    }
  }

  void _markCleanShutdownOnce() {
    if (_cleanShutdownMarked) {
      return;
    }
    _cleanShutdownMarked = true;
    _crashDetector.markCleanShutdown();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [serviceRegistryProvider.overrideWithValue(_registry)],
      child: Consumer(
        builder: (context, ref, child) {
          final settingsStore = ref.watch(appSettingsStoreProvider);
          return MaterialApp(
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
          );
        },
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
    final backupService = NovelWriterApp.debugCreateAutoBackupService();
    final backups = await backupService.listBackups();
    if (backups.isEmpty || !mounted) return;

    final shouldRestore = await NovelWriterApp.debugShowRecoveryDialog(
      context,
      backups: backups,
    );
    if (!mounted) return;

    if (shouldRestore) {
      final latest = backups.first;
      try {
        await backupService.restoreBackup(latest.id);
      } catch (_) {
        // A failed restore should leave the app running on the current data.
      }
      if (!mounted) return;
    }

    widget.onRestoreComplete();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
