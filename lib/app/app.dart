import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  State<NovelWriterApp> createState() => _NovelWriterAppState();
}

class _NovelWriterAppState extends State<NovelWriterApp>
    with WidgetsBindingObserver {
  late final ServiceRegistry _registry;
  late final CrashDetector _crashDetector;
  bool _crashDetected = false;
  bool _dbCorrupted = false;
  bool _cleanShutdownMarked = false;
  bool _servicesClosedForRecovery = false;
  Future<void>? _shutdownFuture;
  BackupRecoveryState? _recoveryState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    registerAppRoutes();

    _crashDetector = widget.crashDetector ?? CrashDetector();
    _crashDetected = _crashDetector.wasDirtyShutdown();

    _registry = NovelWriterApp.debugRegistryOverride ?? ServiceRegistry();
    if (NovelWriterApp.debugRegistryOverride == null) {
      try {
        // Establish an integrity-checked authoring connection before any
        // lazy provider can open a secondary connection with the fast
        // `verifyIntegrity: false` path. Corruption must select the recovery
        // surface synchronously instead of escaping from an unawaited store
        // restore later in the first frame.
        final startupDatabase = openAuthoringDatabase(resolveAuthoringDbPath());
        startupDatabase.dispose();
        registerAppServices(_registry);
      } on DatabaseCorruptedException {
        // DB corruption triggers the same recovery flow as a crash.
        _crashDetected = true;
        _dbCorrupted = true;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_servicesClosedForRecovery) {
      _beginNormalShutdown();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding, hiding, or pausing is not a clean process shutdown.
    if (state == AppLifecycleState.detached) {
      _beginNormalShutdown();
    }
  }

  /// Flushes debounced project writes before closing the registry.  The
  /// clean-shutdown marker is written only after that Future succeeds; a
  /// failed flush therefore remains eligible for crash recovery on the next
  /// startup.
  void _beginNormalShutdown() {
    if (_shutdownFuture != null || _servicesClosedForRecovery) {
      return;
    }
    final future = _registry.shutdown();
    _shutdownFuture = future.then<void>(
      (_) => _markCleanShutdownOnce(),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('正常关闭时持久化失败，保留崩溃恢复标记：$error');
      },
    );
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
    final recoveryState = _recoveryState;
    if (recoveryState?.isTerminal ?? false) {
      return _buildRecoveryOutcome(context, recoveryState!);
    }
    if (_dbCorrupted) {
      return _buildCorruptionRecovery(context);
    }
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
                prepareForRestore: _prepareForRecovery,
                onRecoveryComplete: _completeRecovery,
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
        prepareForRestore: _prepareForRecovery,
        onRecoveryComplete: _completeRecovery,
      ),
    );
  }

  Widget _buildRecoveryOutcome(
    BuildContext context,
    BackupRecoveryState recoveryState,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '小说工作台恢复',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _RecoveryOutcomeScreen(state: recoveryState),
    );
  }

  Future<void> _prepareForRecovery() async {
    if (_servicesClosedForRecovery) return;
    _servicesClosedForRecovery = true;
    // Disaster recovery deliberately does not flush pending writes. The
    // selected backup is authoritative, and writes that were in flight may
    // be the corrupted state we are discarding.
    try {
      await _registry.quiesceAll();
    } finally {
      _registry.disposeAll();
    }
  }

  void _completeRecovery(BackupRecoveryState state) {
    if (!mounted) return;
    setState(() {
      _recoveryState = state;
      if (state.phase == BackupRecoveryPhase.succeeded) {
        _dbCorrupted = false;
        // The restored target has been integrity-checked and no old registry
        // remains in use. Mark this recovery session clean so closing the
        // terminal screen does not trigger the same crash prompt again.
        _markCleanShutdownOnce();
      }
    });
  }
}

/// Overlay that intercepts the first frame after a crash-detected startup
/// and shows the recovery dialog.
class _CrashRecoveryOverlay extends StatefulWidget {
  const _CrashRecoveryOverlay({
    required this.crashDetected,
    required this.prepareForRestore,
    required this.onRecoveryComplete,
    required this.child,
  });

  final bool crashDetected;
  final Future<void> Function() prepareForRestore;
  final ValueChanged<BackupRecoveryState> onRecoveryComplete;
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
    late final List<BackupEntry> backups;
    try {
      backups = await backupService.listBackups();
    } catch (error, stackTrace) {
      if (mounted) {
        widget.onRecoveryComplete(
          BackupRecoveryState(
            phase: BackupRecoveryPhase.failed,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }
      return;
    }
    if (backups.isEmpty || !mounted) return;

    final shouldRestore = await NovelWriterApp.debugShowRecoveryDialog(
      context,
      backups: backups,
    );
    if (!mounted) return;

    if (shouldRestore) {
      final latest = backups.first;
      final coordinator = BackupRecoveryCoordinator(
        prepare: widget.prepareForRestore,
        restore: () => backupService.restoreBackup(latest.id),
      );
      final result = await coordinator.recover();
      if (mounted) widget.onRecoveryComplete(result);
    }
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
  const _CorruptionRecoveryScreen({
    required this.prepareForRestore,
    required this.onRecoveryComplete,
  });

  final Future<void> Function() prepareForRestore;
  final ValueChanged<BackupRecoveryState> onRecoveryComplete;

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
    final coordinator = BackupRecoveryCoordinator(
      prepare: widget.prepareForRestore,
      restore: () => service.restoreBackup(backup.id),
    );
    final result = await coordinator.recover();
    if (result.phase == BackupRecoveryPhase.succeeded) {
      if (mounted) widget.onRecoveryComplete(result);
    } else {
      if (!mounted) return;
      setState(() {
        _restoring = false;
        _error = '恢复失败：${result.error}';
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

/// Terminal screen shown after a recovery attempt.
///
/// The old ProviderScope and its stores are intentionally not rebuilt after a
/// restore. A process restart is required to create fresh SQLite connections
/// and reload store snapshots from the restored database.
class _RecoveryOutcomeScreen extends StatelessWidget {
  const _RecoveryOutcomeScreen({required this.state});

  final BackupRecoveryState state;

  @override
  Widget build(BuildContext context) {
    final succeeded = state.phase == BackupRecoveryPhase.succeeded;
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    succeeded ? '恢复完成' : '恢复未完成',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    succeeded
                        ? '备份已通过完整性校验并替换当前数据库。请重新打开应用以加载恢复后的内容。'
                        : '应用已停止使用当前工作台状态。请重新打开应用后重试恢复；恢复错误如下：',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (!succeeded && state.error != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      state.error.toString(),
                      style: TextStyle(color: theme.colorScheme.error),
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
}
