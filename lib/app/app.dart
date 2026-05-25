import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'di/app_providers.dart';
import 'di/service_registration.dart';
import 'di/service_registry.dart';
import 'navigation/route_registration.dart';
import 'state/app_authoring_storage_io_support.dart';
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

  /// Test-only switch for exercising native Riverpod provider bootstrapping
  /// without ServiceRegistry-owned overrides.
  static bool debugUseProviderBootstrap = false;

  /// Test-only provider overrides used with [debugUseProviderBootstrap].
  static List<Override> debugProviderOverrides = const <Override>[];

  @override
  State<NovelWriterApp> createState() => _NovelWriterAppState();
}

class _NovelWriterAppState extends State<NovelWriterApp>
    with WidgetsBindingObserver {
  ServiceRegistry? _registry;
  late final CrashDetector _crashDetector;
  bool _crashDetected = false;
  bool _dbCorrupted = false;
  bool _restoringBackup = false;
  bool _cleanShutdownMarked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    registerAppRoutes();

    _crashDetector = widget.crashDetector ?? CrashDetector();
    _crashDetected = _crashDetector.wasDirtyShutdown();

    final debugRegistry = NovelWriterApp.debugRegistryOverride;
    final useRegistryBootstrap =
        debugRegistry != null || !NovelWriterApp.debugUseProviderBootstrap;
    if (useRegistryBootstrap) {
      final registry = debugRegistry ?? ServiceRegistry();
      _registry = registry;
    }
    if (debugRegistry == null && useRegistryBootstrap) {
      try {
        registerAppServices(_registry!);
      } on DatabaseCorruptedException {
        // DB corruption triggers the same recovery flow as a crash.
        _crashDetected = true;
        _dbCorrupted = true;
      }
    }
  }

  @override
  void dispose() {
    _markCleanShutdownOnce();
    WidgetsBinding.instance.removeObserver(this);
    _registry?.disposeAll();
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
    if (_dbCorrupted) {
      return _buildCorruptionRecovery(context);
    }
    final registry = _registry;
    final overrides = <Override>[
      if (registry != null) ...appProviderOverridesForRegistry(registry),
      ...NovelWriterApp.debugProviderOverrides,
    ];
    return ProviderScope(
      overrides: overrides,
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

  Widget _buildCorruptionRecovery(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '小说工作台',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _CorruptionRecoveryScreen(
        onRestoreComplete: () {
          // After backup restore, user must restart the app.
          // A full hot-restart is needed to re-register services.
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

/// Full-screen recovery UI shown when the authoring database is corrupted.
///
/// Lists available backups and offers one-click restore + restart.
class _CorruptionRecoveryScreen extends StatefulWidget {
  const _CorruptionRecoveryScreen({required this.onRestoreComplete});

  final VoidCallback onRestoreComplete;

  @override
  State<_CorruptionRecoveryScreen> createState() =>
      _CorruptionRecoveryScreenState();
}

class _CorruptionRecoveryScreenState extends State<_CorruptionRecoveryScreen> {
  List<BackupEntry> _backups = const [];
  bool _loading = true;
  bool _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    final service = NovelWriterApp.debugCreateAutoBackupService();
    try {
      final backups = await service.listBackups();
      if (!mounted) return;
      setState(() {
        _backups = backups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _restore(BackupEntry backup) async {
    setState(() => _restoring = true);
    final service = NovelWriterApp.debugCreateAutoBackupService();
    try {
      await service.restoreBackup(backup.id);
      if (!mounted) return;
      setState(() => _restoring = false);
      widget.onRestoreComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _error = '恢复失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数据库损坏', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    '应用检测到数据库文件已损坏，无法正常启动。\n'
                    '请从备份恢复后重启应用。',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_backups.isEmpty)
                    Text(
                      '未找到可用备份。请联系技术支持。',
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  else ...[
                    Text('可用备份：', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ..._backups
                        .take(5)
                        .map(
                          (b) => ListTile(
                            dense: true,
                            title: Text(_formatBackupTime(b.createdAtMs)),
                            subtitle: Text(_formatSize(b.sizeBytes)),
                            trailing: _restoring
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : FilledButton(
                                    onPressed: () => _restore(b),
                                    child: const Text('恢复'),
                                  ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBackupTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.year}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
