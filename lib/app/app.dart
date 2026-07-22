import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

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
  late ServiceRegistry _registry;
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

    final debugRegistry = NovelWriterApp.debugRegistryOverride;
    if (debugRegistry != null) {
      _registry = debugRegistry;
    } else if (_crashDetected) {
      // Keep the owned registry dormant until recovery has finished. Even a
      // lazily-created store can retain a pre-restore snapshot and later write
      // it over the restored database.
      _registry = ServiceRegistry();
    } else {
      try {
        _registry = _createInitializedRegistry();
      } on DatabaseCorruptedException {
        _registry = ServiceRegistry();
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

  ServiceRegistry _createInitializedRegistry() {
    final registry = ServiceRegistry();
    try {
      registerAppServices(registry);
      // Registrations are lazy, so explicitly open the authoring database
      // before mounting providers. This makes corruption enter recovery
      // instead of surfacing later from an arbitrary store build.
      registry.resolve<sqlite3.Database>();
      return registry;
    } on Object {
      registry.disposeAll();
      rethrow;
    }
  }

  void _activateRegistryAfterRecovery() {
    if (NovelWriterApp.debugRegistryOverride != null) {
      setState(() {
        _dbCorrupted = false;
        _crashDetected = false;
      });
      return;
    }

    _registry.disposeAll();
    try {
      final replacement = _createInitializedRegistry();
      setState(() {
        _registry = replacement;
        _dbCorrupted = false;
        _crashDetected = false;
      });
    } on DatabaseCorruptedException {
      setState(() {
        _registry = ServiceRegistry();
        _dbCorrupted = true;
        _crashDetected = true;
      });
    }
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
    if (_crashDetected) {
      return _buildCrashRecovery();
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
          );
        },
      ),
    );
  }

  Widget _buildCrashRecovery() {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '小说工作台',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _CrashRecoveryOverlay(
        prepareForRestore: _prepareForRecovery,
        onRecoveryComplete: _completeRecovery,
        onContinueWithoutRestore: _activateRegistryAfterRecovery,
        child: const Scaffold(body: Center(child: Text('正在检查可用备份…'))),
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

/// Startup gate that completes crash recovery before the application providers
/// and their database-backed stores are mounted.
class _CrashRecoveryOverlay extends StatefulWidget {
  const _CrashRecoveryOverlay({
    required this.prepareForRestore,
    required this.onRecoveryComplete,
    required this.onContinueWithoutRestore,
    required this.child,
  });

  final Future<void> Function() prepareForRestore;
  final ValueChanged<BackupRecoveryState> onRecoveryComplete;
  final VoidCallback onContinueWithoutRestore;
  final Widget child;

  @override
  State<_CrashRecoveryOverlay> createState() => _CrashRecoveryOverlayState();
}

class _CrashRecoveryOverlayState extends State<_CrashRecoveryOverlay> {
  bool _dialogShown = false;
  String? _restoreError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dialogShown) {
      _dialogShown = true;
      _offerRecovery();
    }
  }

  Future<void> _offerRecovery() async {
    final backupService = NovelWriterApp.debugCreateAutoBackupService();
    final List<BackupEntry> backups;
    try {
      backups = await backupService.listBackups();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _restoreError = '读取备份失败：$e';
      });
      return;
    }
    if (!mounted) return;
    if (backups.isEmpty) {
      widget.onContinueWithoutRestore();
      return;
    }

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
      return;
    }

    widget.onContinueWithoutRestore();
  }

  @override
  Widget build(BuildContext context) {
    if (_restoreError != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: ExcludeSemantics(child: widget.child)),
          Material(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('恢复失败', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      _restoreError!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _restoreError = null;
                        });
                        widget.onContinueWithoutRestore();
                      },
                      child: const Text('继续使用当前数据'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        final data = ClipboardData(text: _restoreError!);
                        Clipboard.setData(data);
                      },
                      child: const Text('复制错误信息'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
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
                    '请从备份恢复；完成后应用会重新初始化数据服务。',
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
