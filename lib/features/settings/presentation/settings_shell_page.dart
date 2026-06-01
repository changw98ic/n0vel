import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/llm/app_llm_client.dart';
import '../../../app/state/app_settings_storage.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../../app/widgets/app_loading_state.dart';
import 'settings_dialogs.dart';
import 'settings_shell_components.dart';

class SettingsShellPage extends ConsumerStatefulWidget {
  const SettingsShellPage({super.key});

  static const providerConfigKey = ValueKey<String>('settings-provider-config');
  static const baseUrlFieldKey = ValueKey<String>('settings-base-url-field');
  static const modelFieldKey = ValueKey<String>('settings-model-field');
  static const apiKeyFieldKey = ValueKey<String>('settings-api-key-field');
  static const connectTimeoutFieldKey = ValueKey<String>(
    'settings-connect-timeout-field',
  );
  static const sendTimeoutFieldKey = ValueKey<String>(
    'settings-send-timeout-field',
  );
  static const receiveTimeoutFieldKey = ValueKey<String>(
    'settings-receive-timeout-field',
  );
  static const maxConcurrentRequestsFieldKey = ValueKey<String>(
    'settings-max-concurrent-requests-field',
  );
  static const testConnectionButtonKey = ValueKey<String>(
    'settings-test-connection-button',
  );
  static const saveButtonKey = ValueKey<String>('settings-save-button');
  static const retrySecureStoreButtonKey = ValueKey<String>(
    'settings-retry-secure-store-button',
  );
  static const copyDiagnosticButtonKey = ValueKey<String>(
    'settings-copy-diagnostic-button',
  );
  static const themeLightButtonKey = ValueKey<String>('settings-theme-light');
  static const themeDarkButtonKey = ValueKey<String>('settings-theme-dark');
  static const addProfileButtonKey = ValueKey<String>(
    'settings-add-profile-button',
  );
  static const providerCatalogButtonKey = ValueKey<String>(
    'settings-provider-catalog-button',
  );
  static const profileListKey = ValueKey<String>('settings-profile-list');
  static const addRouteButtonKey = ValueKey<String>(
    'settings-add-route-button',
  );
  static const routeListKey = ValueKey<String>('settings-route-list');

  @override
  ConsumerState<SettingsShellPage> createState() => _SettingsShellPageState();
}

class _SettingsShellPageState extends ConsumerState<SettingsShellPage> {
  late final TextEditingController _providerController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _connectTimeoutController;
  late final TextEditingController _sendTimeoutController;
  late final TextEditingController _receiveTimeoutController;
  late final TextEditingController _maxConcurrentRequestsController;
  bool _hydratedFromStore = false;
  bool _apiKeyVisible = false;

  void _handleFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _providerController = TextEditingController(text: 'OpenAI 兼容服务');
    _baseUrlController = TextEditingController(
      text: 'https://api.example.com/v1',
    );
    _modelController = TextEditingController(text: 'gpt-4.1-mini');
    _apiKeyController = TextEditingController();
    _connectTimeoutController = TextEditingController(text: '10000');
    _sendTimeoutController = TextEditingController(text: '30000');
    _receiveTimeoutController = TextEditingController(text: '60000');
    _maxConcurrentRequestsController = TextEditingController(text: '1');
    _providerController.addListener(_handleFormChanged);
    _baseUrlController.addListener(_handleFormChanged);
    _modelController.addListener(_handleFormChanged);
    _apiKeyController.addListener(_handleFormChanged);
    _connectTimeoutController.addListener(_handleFormChanged);
    _sendTimeoutController.addListener(_handleFormChanged);
    _receiveTimeoutController.addListener(_handleFormChanged);
    _maxConcurrentRequestsController.addListener(_handleFormChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydratedFromStore) {
      return;
    }
    _synchronizeControllers(ref.read(appSettingsStoreProvider).snapshot);
    _hydratedFromStore = true;
  }

  @override
  void dispose() {
    _providerController.removeListener(_handleFormChanged);
    _baseUrlController.removeListener(_handleFormChanged);
    _modelController.removeListener(_handleFormChanged);
    _apiKeyController.removeListener(_handleFormChanged);
    _connectTimeoutController.removeListener(_handleFormChanged);
    _sendTimeoutController.removeListener(_handleFormChanged);
    _receiveTimeoutController.removeListener(_handleFormChanged);
    _maxConcurrentRequestsController.removeListener(_handleFormChanged);
    _providerController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    _connectTimeoutController.dispose();
    _sendTimeoutController.dispose();
    _receiveTimeoutController.dispose();
    _maxConcurrentRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsStore = ref.watch(appSettingsStoreProvider);
    final settings = settingsStore.snapshot;
    final feedback = settingsStore.feedback;
    final connectionTestState = settingsStore.connectionTestState;
    final diagnosticReport = settingsStore.diagnosticReport;
    final feedbackColor = _feedbackColor(feedback.tone);
    final parsedConnectTimeout =
        int.tryParse(_connectTimeoutController.text.trim()) ?? 0;
    final parsedSendTimeout =
        int.tryParse(_sendTimeoutController.text.trim()) ?? 0;
    final parsedReceiveTimeout =
        int.tryParse(_receiveTimeoutController.text.trim()) ?? 0;
    final hasSupportedModel = settingsStore.isSupportedModel(
      _modelController.text.trim(),
    );
    final canSaveConfigurationUi =
        _modelController.text.trim().isEmpty || hasSupportedModel;
    final statusTitle =
        connectionTestState.status == AppSettingsConnectionTestStatus.idle
        ? feedback.title
        : connectionTestState.title;
    final statusMessage =
        connectionTestState.status == AppSettingsConnectionTestStatus.idle
        ? feedback.message
        : connectionTestState.message;
    final showPersistenceOverlay =
        settingsStore.hasPersistenceIssue && diagnosticReport != null;

    final providerPanel = _buildProviderPanel(
      context: context,
      theme: theme,
      settingsStore: settingsStore,
      settings: settings,
      feedbackColor: feedbackColor,
      parsedConnectTimeout: parsedConnectTimeout,
      parsedSendTimeout: parsedSendTimeout,
      parsedReceiveTimeout: parsedReceiveTimeout,
      canSaveConfigurationUi: canSaveConfigurationUi,
      statusTitle: statusTitle,
      statusMessage: statusMessage,
      diagnosticReport: diagnosticReport,
      showPersistenceOverlay: showPersistenceOverlay,
    );

    return PopScope(
      canPop: !_isFormDirty(settings),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          barrierLabel: '关闭',
          builder: (dialogContext) => DesktopModalDialog(
            title: '未保存的修改',
            description: '当前设置有未保存的修改，确定要离开吗？',
            body: const SizedBox.shrink(),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('继续编辑'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('离开'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: DesktopShellFrame(
        header: const DesktopHeaderBar(
          title: '设置',
          subtitle: '管理模型连接、界面偏好与高级选项',
          showBackButton: true,
        ),
        body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: providerPanel,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        leftText: statusTitle ?? '配置保存在本地 · 导出包不包含接口密钥',
        rightText: settings.themePreference == AppThemePreference.dark
            ? '深色模式'
            : '浅色模式',
      ),
    ),
    );
  }

  Widget _buildProviderPanel({
    required BuildContext context,
    required ThemeData theme,
    required AppSettingsStore settingsStore,
    required AppSettingsSnapshot settings,
    required Color feedbackColor,
    required int parsedConnectTimeout,
    required int parsedSendTimeout,
    required int parsedReceiveTimeout,
    required bool canSaveConfigurationUi,
    required String? statusTitle,
    required String? statusMessage,
    required String? diagnosticReport,
    required bool showPersistenceOverlay,
  }) {
    return Container(
      key: SettingsShellPage.providerConfigKey,
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('设置', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '设置与模型密钥',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text('连接你自己的模型服务，其余写作流程保持本地运行。', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          SettingsGroup(
            title: '外观',
            subtitle: '只影响当前界面阅读感，不改变作品内容。',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SettingsThemeButton(
                    buttonKey: SettingsShellPage.themeLightButtonKey,
                    label: '浅色',
                    selected: settings.themePreference == AppThemePreference.light,
                    onTap: () {
                      ref.read(appSettingsStoreProvider)
                          .setThemePreference(AppThemePreference.light);
                    },
                  ),
                  SettingsThemeButton(
                    buttonKey: SettingsShellPage.themeDarkButtonKey,
                    label: '深色',
                    selected: settings.themePreference == AppThemePreference.dark,
                    onTap: () {
                      ref.read(appSettingsStoreProvider)
                          .setThemePreference(AppThemePreference.dark);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            title: '默认模型',
            subtitle: '用于未被路由规则覆盖的写作、检查和改稿请求。',
            children: [
              SettingsFieldInputBox(label: '模型服务', controller: _providerController),
              const SizedBox(height: 12),
              SettingsFieldInputBox(
                label: '接口地址',
                controller: _baseUrlController,
                fieldKey: SettingsShellPage.baseUrlFieldKey,
              ),
              const SizedBox(height: 12),
              SettingsFieldInputBox(
                label: '模型',
                controller: _modelController,
                fieldKey: SettingsShellPage.modelFieldKey,
              ),
              const SizedBox(height: 12),
              SettingsFieldInputBox(
                label: '密钥',
                controller: _apiKeyController,
                fieldKey: SettingsShellPage.apiKeyFieldKey,
                obscureText: !_apiKeyVisible,
                placeholder: '输入密钥',
                onToggleObscure: () {
                  setState(() {
                    _apiKeyVisible = !_apiKeyVisible;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            title: '请求节奏',
            subtitle: '建议先保持默认值；网络较慢时再放宽等待时间。',
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 156,
                    child: SettingsFieldInputBox(
                      label: '连接超时',
                      controller: _connectTimeoutController,
                      fieldKey: SettingsShellPage.connectTimeoutFieldKey,
                      suffix: 'ms',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(
                    width: 156,
                    child: SettingsFieldInputBox(
                      label: '发送超时',
                      controller: _sendTimeoutController,
                      fieldKey: SettingsShellPage.sendTimeoutFieldKey,
                      suffix: 'ms',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(
                    width: 156,
                    child: SettingsFieldInputBox(
                      label: '接收超时',
                      controller: _receiveTimeoutController,
                      fieldKey: SettingsShellPage.receiveTimeoutFieldKey,
                      suffix: 'ms',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  SizedBox(
                    width: 156,
                    child: SettingsFieldInputBox(
                      label: '并发上限',
                      controller: _maxConcurrentRequestsController,
                      fieldKey: SettingsShellPage.maxConcurrentRequestsFieldKey,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            title: '多模型服务配置',
            subtitle: '为不同 AI 阶段指定独立服务；未匹配时使用默认模型。',
            children: [
              if (settings.providerProfiles.isEmpty)
                Text('暂无额外模型服务。', style: theme.textTheme.bodySmall)
              else ...[
                for (final profile in settings.providerProfiles) ...[
                  SettingsProfileCard(
                    profile: profile,
                    onTest: () => _testProfileConnection(context, profile),
                    onSetPrimary: profile.id == 'primary'
                        ? null
                        : () {
                            ref.read(appSettingsStoreProvider)
                                .setPrimaryProviderProfile(profile.id);
                            _synchronizeControllers(
                              ref.read(appSettingsStoreProvider).snapshot,
                            );
                          },
                    onEdit: profile.id == 'primary'
                        ? null
                        : () => showProfileDialog(
                              context: context,
                              store: ref.read(appSettingsStoreProvider),
                              existing: profile,
                            ),
                    onDelete: profile.id == 'primary'
                        ? null
                        : () {
                            ref.read(appSettingsStoreProvider)
                                .removeProviderProfile(profile.id);
                          },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: SettingsShellPage.providerCatalogButtonKey,
                    onPressed: () => showProviderCatalogDialog(
                      context: context,
                      store: settingsStore,
                      onSynchronizeControllers: _synchronizeControllers,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('一键添加供应商'),
                  ),
                  OutlinedButton.icon(
                    key: SettingsShellPage.addProfileButtonKey,
                    onPressed: () => showProfileDialog(
                      context: context,
                      store: ref.read(appSettingsStoreProvider),
                    ),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('手动配置'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(appSettingsStoreProvider)
                      .applySingleChapterGenerationProviderPreset();
                },
                icon: const Icon(Icons.route_outlined, size: 18),
                label: const Text('应用单章生成路由预设'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SettingsGroup(
            title: '路由规则',
            subtitle: '按请求类型匹配到指定模型服务，留空使用默认模型。',
            children: [
              if (settings.requestProviderRoutes.isEmpty)
                Text('暂无路由规则。', style: theme.textTheme.bodySmall)
              else ...[
                for (final route in settings.requestProviderRoutes) ...[
                  SettingsRouteCard(
                    route: route,
                    profiles: settings.providerProfiles,
                    onEdit: () => showRouteDialog(
                      context: context,
                      settingsStore: ref.read(appSettingsStoreProvider),
                      existing: route,
                    ),
                    onDelete: () {
                      ref.read(appSettingsStoreProvider)
                          .removeRequestProviderRoute(route.traceNamePattern);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 4),
              OutlinedButton(
                key: SettingsShellPage.addRouteButtonKey,
                onPressed: () => showRouteDialog(
                  context: context,
                  settingsStore: ref.read(appSettingsStoreProvider),
                ),
                child: const Text('添加路由'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildConnectionActions(
            feedbackColor: feedbackColor,
            canSaveConfigurationUi: canSaveConfigurationUi,
            parsedConnectTimeout: parsedConnectTimeout,
            parsedSendTimeout: parsedSendTimeout,
            parsedReceiveTimeout: parsedReceiveTimeout,
            statusTitle: statusTitle,
            diagnosticReport: diagnosticReport,
            includeKeys: true,
          ),
          if (!showPersistenceOverlay && statusMessage != null && statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: statusTitle == null ? null : feedbackColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionActions({
    required Color feedbackColor,
    required bool canSaveConfigurationUi,
    required int parsedConnectTimeout,
    required int parsedSendTimeout,
    required int parsedReceiveTimeout,
    required String? statusTitle,
    required String? diagnosticReport,
    required bool includeKeys,
  }) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppLoadingButton(
          key: includeKeys ? SettingsShellPage.saveButtonKey : null,
          onPressed: canSaveConfigurationUi
              ? () async {
                  final currentTimeout = AppLlmTimeoutConfig(
                    connectTimeoutMs: parsedConnectTimeout,
                    sendTimeoutMs: parsedSendTimeout,
                    receiveTimeoutMs: parsedReceiveTimeout,
                  );
                  final currentMaxConcurrentRequests =
                      int.tryParse(
                        _maxConcurrentRequestsController.text.trim(),
                      ) ??
                      0;
                  await ref.read(appSettingsStoreProvider).saveWithFeedback(
                    providerName: _providerController.text.trim(),
                    baseUrl: _baseUrlController.text.trim(),
                    model: _modelController.text.trim(),
                    apiKey: _apiKeyController.text.trim(),
                    timeout: currentTimeout,
                    maxConcurrentRequests: currentMaxConcurrentRequests,
                  );
                  if (!mounted) return;
                  _synchronizeControllers(
                    ref.read(appSettingsStoreProvider).snapshot,
                  );
                }
              : null,
          child: const Text('保存配置'),
        ),
        if (ref.read(appSettingsStoreProvider).canRetrySecureStoreAccess)
          OutlinedButton(
            key: includeKeys
                ? SettingsShellPage.retrySecureStoreButtonKey
                : null,
            onPressed: _retrySecureStoreAccess,
            child: const Text('重试配置'),
          ),
        if (diagnosticReport != null)
          OutlinedButton(
            key: includeKeys
                ? SettingsShellPage.copyDiagnosticButtonKey
                : null,
            onPressed: () =>
                copyDiagnosticToClipboard(context, diagnosticReport),
            child: const Text('复制诊断'),
          ),
        if (statusTitle != null)
          Text(
            statusTitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: feedbackColor,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Future<void> _retrySecureStoreAccess() async {
    final settingsStore = ref.read(appSettingsStoreProvider);
    final issue = settingsStore.activePersistenceIssue;
    if (issue == AppSettingsPersistenceIssue.none) {
      return;
    }

    if (issue == AppSettingsPersistenceIssue.fileReadFailed) {
      await settingsStore.retrySecureStoreAccess();
      _synchronizeRecoveredApiKey(settingsStore.snapshot);
      return;
    }

    await settingsStore.retrySecureStoreAccessWithValues(
      providerName: _providerController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      timeout: AppLlmTimeoutConfig(
        connectTimeoutMs:
            int.tryParse(_connectTimeoutController.text.trim()) ?? 0,
        sendTimeoutMs: int.tryParse(_sendTimeoutController.text.trim()) ?? 0,
        receiveTimeoutMs:
            int.tryParse(_receiveTimeoutController.text.trim()) ?? 0,
      ),
      maxConcurrentRequests:
          int.tryParse(_maxConcurrentRequestsController.text.trim()) ?? 0,
    );
  }

  bool _isFormDirty(AppSettingsSnapshot settings) {
    return _providerController.text.trim() != settings.providerName ||
        _baseUrlController.text.trim() != settings.baseUrl ||
        _modelController.text.trim() != settings.model ||
        _apiKeyController.text.trim() != settings.apiKey ||
        _connectTimeoutController.text.trim() !=
            settings.timeout.connectTimeoutMs.toString() ||
        _sendTimeoutController.text.trim() !=
            settings.timeout.sendTimeoutMs.toString() ||
        _receiveTimeoutController.text.trim() !=
            settings.timeout.receiveTimeoutMs.toString() ||
        _maxConcurrentRequestsController.text.trim() !=
            settings.maxConcurrentRequests.toString();
  }

  void _synchronizeControllers(AppSettingsSnapshot settings) {
    _providerController.text = settings.providerName;
    _baseUrlController.text = settings.baseUrl;
    _modelController.text = settings.model;
    _apiKeyController.text = settings.apiKey;
    _connectTimeoutController.text = settings.timeout.connectTimeoutMs
        .toString();
    _sendTimeoutController.text = settings.timeout.sendTimeoutMs.toString();
    _receiveTimeoutController.text = settings.timeout.receiveTimeoutMs
        .toString();
    _maxConcurrentRequestsController.text = settings.maxConcurrentRequests
        .toString();
  }

  void _synchronizeRecoveredApiKey(AppSettingsSnapshot settings) {
    if (_apiKeyController.text == settings.apiKey) {
      return;
    }
    _apiKeyController.text = settings.apiKey;
    _apiKeyController.selection = TextSelection.collapsed(
      offset: settings.apiKey.length,
    );
  }

  void _testProfileConnection(
    BuildContext context,
    AppLlmProviderProfile profile,
  ) {
    final settingsStore = ref.read(appSettingsStoreProvider);
    settingsStore.testConnection(
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: profile.apiKey,
      providerName: profile.providerName,
      timeout: const AppLlmTimeoutConfig.uniform(30000),
    );
  }

  Color _feedbackColor(AppSettingsFeedbackTone tone) {
    final palette = desktopPalette(context);
    return switch (tone) {
      AppSettingsFeedbackTone.info => palette.info,
      AppSettingsFeedbackTone.success => palette.success,
      AppSettingsFeedbackTone.error => palette.danger,
    };
  }
}
