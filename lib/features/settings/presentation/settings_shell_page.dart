import 'package:flutter/material.dart';

import '../../../app/llm/app_llm_client.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_settings_storage.dart';
import '../../../app/state/app_settings_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../../app/widgets/app_loading_state.dart';

class SettingsShellPage extends StatefulWidget {
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

  @override
  State<SettingsShellPage> createState() => _SettingsShellPageState();
}

class _SettingsShellPageState extends State<SettingsShellPage> {
  late final TextEditingController _providerController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _connectTimeoutController;
  late final TextEditingController _sendTimeoutController;
  late final TextEditingController _receiveTimeoutController;
  late final TextEditingController _maxConcurrentRequestsController;
  bool _hydratedFromStore = false;
  bool _isDrawerOpen = false;

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
    _synchronizeControllers(AppSettingsScope.of(context).snapshot);
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
    final settingsStore = AppSettingsScope.of(context);
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
    final parsedMaxConcurrentRequests =
        int.tryParse(_maxConcurrentRequestsController.text.trim()) ?? 0;
    final hasSupportedModel = settingsStore.isSupportedModel(
      _modelController.text.trim(),
    );
    final canRunConnectionTestUi =
        _apiKeyController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty &&
        hasSupportedModel &&
        (Uri.tryParse(_baseUrlController.text.trim())?.hasAuthority ?? false) &&
        parsedConnectTimeout > 0 &&
        parsedSendTimeout > 0 &&
        parsedReceiveTimeout > 0 &&
        parsedMaxConcurrentRequests > 0;
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
    Widget buildConnectionActions({required bool includeKeys}) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton(
            key: includeKeys ? SettingsShellPage.testConnectionButtonKey : null,
            onPressed: canRunConnectionTestUi
                ? () {
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
                    settingsStore.testConnection(
                      baseUrl: _baseUrlController.text,
                      model: _modelController.text,
                      apiKey: _apiKeyController.text,
                      timeout: currentTimeout,
                      maxConcurrentRequests: currentMaxConcurrentRequests,
                    );
                  }
                : null,
            child: const Text('测试连接'),
          ),
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
                    await settingsStore.saveWithFeedback(
                      providerName: _providerController.text.trim(),
                      baseUrl: _baseUrlController.text.trim(),
                      model: _modelController.text.trim(),
                      apiKey: _apiKeyController.text.trim(),
                      timeout: currentTimeout,
                      maxConcurrentRequests: currentMaxConcurrentRequests,
                    );
                    if (!mounted) {
                      return;
                    }
                    _synchronizeControllers(settingsStore.snapshot);
                  }
                : null,
            child: const Text('保存配置'),
          ),
          if (settingsStore.canRetrySecureStoreAccess)
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

    Widget? buildVisibleStatusMessage() {
      final message = statusMessage;
      if (message == null || message.isEmpty) {
        return null;
      }
      return Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: statusTitle == null ? null : feedbackColor,
        ),
      );
    }

    final providerPanel = Container(
      key: SettingsShellPage.providerConfigKey,
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('模型提供方', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('界面模式', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _ThemeButton(
                buttonKey: SettingsShellPage.themeLightButtonKey,
                label: '浅色',
                selected: settings.themePreference == AppThemePreference.light,
                onTap: () {
                  AppSettingsScope.of(
                    context,
                  ).setThemePreference(AppThemePreference.light);
                },
              ),
              _ThemeButton(
                buttonKey: SettingsShellPage.themeDarkButtonKey,
                label: '深色',
                selected: settings.themePreference == AppThemePreference.dark,
                onTap: () {
                  AppSettingsScope.of(
                    context,
                  ).setThemePreference(AppThemePreference.dark);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldInputBox(label: '提供方', controller: _providerController),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '接口地址',
            controller: _baseUrlController,
            fieldKey: SettingsShellPage.baseUrlFieldKey,
          ),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '模型',
            controller: _modelController,
            fieldKey: SettingsShellPage.modelFieldKey,
          ),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '密钥',
            controller: _apiKeyController,
            fieldKey: SettingsShellPage.apiKeyFieldKey,
            obscureText: true,
            placeholder: '输入 API Key',
          ),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '连接超时',
            controller: _connectTimeoutController,
            fieldKey: SettingsShellPage.connectTimeoutFieldKey,
            suffix: 'ms',
          ),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '发送超时',
            controller: _sendTimeoutController,
            fieldKey: SettingsShellPage.sendTimeoutFieldKey,
            suffix: 'ms',
          ),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '接收超时',
            controller: _receiveTimeoutController,
            fieldKey: SettingsShellPage.receiveTimeoutFieldKey,
            suffix: 'ms',
          ),
          const SizedBox(height: 12),
          _FieldInputBox(
            label: '并发上限',
            controller: _maxConcurrentRequestsController,
            fieldKey: SettingsShellPage.maxConcurrentRequestsFieldKey,
          ),
        ],
      ),
    );
    final connectionPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: Stack(
        children: [
          Opacity(
            opacity: showPersistenceOverlay ? 0.38 : 1,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  _statusPanelTitle(
                    statusTitle: statusTitle,
                    activeIssue: settingsStore.activePersistenceIssue,
                  ),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                buildConnectionActions(includeKeys: !showPersistenceOverlay),
                if (!showPersistenceOverlay &&
                    buildVisibleStatusMessage() != null) ...[
                  const SizedBox(height: 12),
                  buildVisibleStatusMessage()!,
                ],
                const SizedBox(height: 16),
                ..._buildStatusCards(
                  context: context,
                  statusTitle: statusTitle,
                  statusMessage: statusMessage,
                  settingsStore: settingsStore,
                ),
                const SizedBox(height: 12),
                _ConfigSummaryRow(label: '状态', value: statusTitle ?? '尚未验证'),
                const SizedBox(height: 8),
                _ConfigSummaryRow(
                  label: '上次连接',
                  value: feedback.title == null ? '还没有记录' : '刚刚',
                ),
                const SizedBox(height: 8),
                _ConfigSummaryRow(
                  label: '已连接主机',
                  value: _baseUrlController.text.trim(),
                ),
                const SizedBox(height: 8),
                _ConfigSummaryRow(
                  label: '已选模型',
                  value: _modelController.text.trim(),
                ),
              ],
            ),
          ),
          if (showPersistenceOverlay)
            Positioned.fill(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 728),
                  child: _PersistenceOverlayCard(
                    title: feedback.title ?? '设置状态异常',
                    diagnosticReport: diagnosticReport,
                    explanation: _persistenceOverlayExplanation(
                      settingsStore.activePersistenceIssue,
                    ),
                    onCopyDiagnostic: () =>
                        copyDiagnosticToClipboard(context, diagnosticReport),
                    onRetry: settingsStore.canRetrySecureStoreAccess
                        ? _retrySecureStoreAccess
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final helpPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('说明', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(
            _helpHeadline(
              statusTitle: statusTitle,
              activeIssue: settingsStore.activePersistenceIssue,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: statusTitle == null ? null : feedbackColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _helpBody(
              statusMessage: statusMessage,
              activeIssue: settingsStore.activePersistenceIssue,
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    return DesktopShellFrame(
      header: const DesktopHeaderBar(
        title: '设置与模型密钥',
        subtitle: '连接你自己的模型服务，其余写作流程保持本地运行',
        showBackButton: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final handleRegion = DesktopMenuDrawerRegion(
            isOpen: _isDrawerOpen,
            onHandleTap: () {
              setState(() {
                _isDrawerOpen = !_isDrawerOpen;
              });
            },
            items: _menuItems(context),
          );

          if (compact) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                handleRegion,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: appPanelDecoration(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildConnectionActions(includeKeys: true),
                            if (buildVisibleStatusMessage() != null) ...[
                              const SizedBox(height: 12),
                              buildVisibleStatusMessage()!,
                            ],
                            if (!showPersistenceOverlay) ...[
                              const SizedBox(height: 12),
                              ..._buildStatusCards(
                                context: context,
                                statusTitle: statusTitle,
                                statusMessage: statusMessage,
                                settingsStore: settingsStore,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            providerPanel,
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: appPanelDecoration(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _statusPanelTitle(
                                      statusTitle: statusTitle,
                                      activeIssue:
                                          settingsStore.activePersistenceIssue,
                                    ),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  ..._buildStatusCards(
                                    context: context,
                                    statusTitle: statusTitle,
                                    statusMessage: statusMessage,
                                    settingsStore: settingsStore,
                                  ),
                                  const SizedBox(height: 12),
                                  _ConfigSummaryRow(
                                    label: '状态',
                                    value: statusTitle ?? '尚未验证',
                                  ),
                                  const SizedBox(height: 8),
                                  _ConfigSummaryRow(
                                    label: '上次连接',
                                    value: feedback.title == null
                                        ? '还没有记录'
                                        : '刚刚',
                                  ),
                                  const SizedBox(height: 8),
                                  _ConfigSummaryRow(
                                    label: '已连接主机',
                                    value: _baseUrlController.text.trim(),
                                  ),
                                  const SizedBox(height: 8),
                                  _ConfigSummaryRow(
                                    label: '已选模型',
                                    value: _modelController.text.trim(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            helpPanel,
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              handleRegion,
              const SizedBox(width: 16),
              SizedBox(width: 420, child: providerPanel),
              const SizedBox(width: 16),
              Expanded(child: connectionPanel),
              const SizedBox(width: 16),
              SizedBox(width: 300, child: helpPanel),
            ],
          );
        },
      ),
      statusBar: DesktopStatusStrip(
        leftText: statusTitle ?? '配置保存在本地 · 导出包不包含 API 密钥',
        rightText: settings.themePreference == AppThemePreference.dark
            ? '深色模式'
            : '浅色模式',
      ),
    );
  }

  Future<void> _retrySecureStoreAccess() async {
    final settingsStore = AppSettingsScope.of(context);
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

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return [
      DesktopMenuItemData(
        label: '书架',
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
      DesktopMenuItemData(
        label: '编辑工作台',
        onTap: () {
          AppNavigator.push(context, AppRoutes.workbench);
        },
      ),
      DesktopMenuItemData(
        label: '设置',
        isSelected: true,
        onTap: () {
          setState(() {
            _isDrawerOpen = false;
          });
        },
      ),
    ];
  }

  Color _feedbackColor(AppSettingsFeedbackTone tone) {
    return switch (tone) {
      AppSettingsFeedbackTone.info => appInfoColor,
      AppSettingsFeedbackTone.success => appSuccessColor,
      AppSettingsFeedbackTone.error => appDangerColor,
    };
  }

  String _statusPanelTitle({
    required String? statusTitle,
    required AppSettingsPersistenceIssue activeIssue,
  }) {
    if (activeIssue != AppSettingsPersistenceIssue.none) {
      return '配置异常';
    }
    return switch (statusTitle) {
      '保存成功' => '保存结果',
      '配置已重新加载' || '配置已重新保存' => '恢复结果',
      _ => '连接测试',
    };
  }

  List<Widget> _buildStatusCards({
    required BuildContext context,
    required String? statusTitle,
    required String? statusMessage,
    required AppSettingsStore settingsStore,
  }) {
    final theme = Theme.of(context);

    switch (statusTitle) {
      case '配置已重新加载':
        return [
          _StatusHeadlineCard(
            label: statusTitle!,
            message: statusMessage ?? 'settings.json 已重新读取，当前配置已同步。',
          ),
          const SizedBox(height: 8),
          const _StatusDetailRow(label: '恢复内容', value: '密钥与本地配置'),
          const SizedBox(height: 8),
          const _StatusDetailRow(label: '未保存的非密钥编辑', value: '已保留'),
        ];
      case '配置已重新保存':
        return [
          _StatusHeadlineCard(
            label: statusTitle!,
            message: statusMessage ?? 'settings.json 已更新。',
          ),
          const SizedBox(height: 8),
          const _StatusDetailRow(label: '下一次生效', value: '下一个 AI 请求'),
          const SizedBox(height: 8),
          const _StatusDetailRow(label: '当前请求', value: '不自动重试'),
          const SizedBox(height: 8),
          const _StatusDetailRow(label: '建议动作', value: '返回工作台后手动重试'),
        ];
      case '保存成功':
        return [
          _StatusHeadlineCard(
            label: statusTitle!,
            message: statusMessage ?? '新配置会从下一次 AI 请求开始生效。',
          ),
          const SizedBox(height: 8),
          const _StatusDetailRow(label: '下一次生效', value: '下一个 AI 请求'),
        ];
      default:
        return [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 160),
            padding: const EdgeInsets.all(16),
            decoration: appPanelDecoration(
              context,
              color: desktopPalette(context).elevated,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusTitle ?? '尚未验证', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  statusMessage ?? '连接验证结果、最近一次状态和模型可用性会显示在这里。',
                  style: theme.textTheme.bodySmall,
                ),
                if (settingsStore.activePersistenceIssue ==
                        AppSettingsPersistenceIssue.none &&
                    statusTitle != null &&
                    statusTitle.startsWith('连接测试失败')) ...[
                  const SizedBox(height: 12),
                  const _StatusDetailRow(label: '建议动作', value: '修正配置后再次测试'),
                ],
              ],
            ),
          ),
        ];
    }
  }

  String _persistenceOverlayExplanation(AppSettingsPersistenceIssue issue) {
    return switch (issue) {
      AppSettingsPersistenceIssue.fileReadFailed =>
        '无法恢复上一次保存的连接配置。请重试读取，或复制诊断信息继续排查。',
      AppSettingsPersistenceIssue.fileWriteFailed =>
        '连接参数草稿仍保留在当前页面，可复制诊断或再次尝试保存。',
      AppSettingsPersistenceIssue.none => '',
    };
  }

  String _helpHeadline({
    required String? statusTitle,
    required AppSettingsPersistenceIssue activeIssue,
  }) {
    if (activeIssue == AppSettingsPersistenceIssue.fileReadFailed) {
      return '可先复制诊断，再重试读取本地配置。';
    }
    if (activeIssue == AppSettingsPersistenceIssue.fileWriteFailed) {
      return '当前表单草稿仍保留，可先排查后再次保存。';
    }
    return statusTitle ?? 'API 密钥仅保存在本地。';
  }

  String _helpBody({
    required String? statusMessage,
    required AppSettingsPersistenceIssue activeIssue,
  }) {
    return switch (activeIssue) {
      AppSettingsPersistenceIssue.fileReadFailed =>
        '读取失败不会阻塞当前写作工作区。复制诊断后，可检查 settings.json 是否损坏或权限异常。',
      AppSettingsPersistenceIssue.fileWriteFailed =>
        '保存失败不会丢失当前表单编辑。修复磁盘或目录权限后，可直接使用重试配置再次写入。',
      AppSettingsPersistenceIssue.none => switch (statusMessage) {
        'settings.json 已重新读取，当前配置已同步。' =>
          '系统已重新读取本地配置，并恢复最近一次可用的密钥内容。未保存的 base_url、model 等编辑仍保留在当前表单中。',
        'settings.json 已更新。' =>
          '最新配置已经持久化到 settings.json。返回工作台后，下一次 AI 请求会使用新配置；当前失败请求不会自动重试。',
        _ => statusMessage ?? '如果连接失败，写作工作区仍可继续使用。\n\n切换模型只会影响下一次 AI 请求。',
      },
    };
  }
}

class _FieldInputBox extends StatelessWidget {
  const _FieldInputBox({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.obscureText = false,
    this.placeholder,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final bool obscureText;
  final String? placeholder;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: placeholder,
            suffixText: suffix,
          ),
        ),
      ],
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton(key: buttonKey, onPressed: onTap, child: Text(label));
    }
    return OutlinedButton(key: buttonKey, onPressed: onTap, child: Text(label));
  }
}

class _ConfigSummaryRow extends StatelessWidget {
  const _ConfigSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeadlineCard extends StatelessWidget {
  const _StatusHeadlineCard({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StatusDetailRow extends StatelessWidget {
  const _StatusDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersistenceOverlayCard extends StatelessWidget {
  const _PersistenceOverlayCard({
    required this.title,
    required this.diagnosticReport,
    required this.explanation,
    this.onCopyDiagnostic,
    this.onRetry,
  });

  final String title;
  final String? diagnosticReport;
  final String explanation;
  final VoidCallback? onCopyDiagnostic;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: desktopPalette(context).border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (diagnosticReport case final report?) ...[
            const SizedBox(height: 12),
            Text(report, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(explanation, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onCopyDiagnostic != null)
                OutlinedButton(
                  key: SettingsShellPage.copyDiagnosticButtonKey,
                  onPressed: onCopyDiagnostic,
                  child: const Text('复制诊断'),
                ),
              if (onRetry != null)
                FilledButton(
                  key: SettingsShellPage.retrySecureStoreButtonKey,
                  onPressed: onRetry,
                  child: const Text('重试配置'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
