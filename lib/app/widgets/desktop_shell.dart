import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_settings_store.dart';
import 'desktop_theme.dart';

export 'desktop_header_widgets.dart';
export 'desktop_menu_widgets.dart';
export 'desktop_status_modal.dart';
export 'desktop_theme.dart';

Future<void> copyDiagnosticToClipboard(
  BuildContext context,
  String text,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(const SnackBar(content: Text('诊断已复制')));
}

class DesktopShellFrame extends StatelessWidget {
  const DesktopShellFrame({
    super.key,
    required this.header,
    required this.body,
    this.statusBar,
  });

  final Widget header;
  final Widget body;
  final Widget? statusBar;

  static const retrySecureStoreButtonKey = ValueKey<String>(
    'desktop-shell-retry-secure-store-button',
  );
  static const copyDiagnosticButtonKey = ValueKey<String>(
    'desktop-shell-copy-diagnostic-button',
  );

  @override
  Widget build(BuildContext context) {
    final settingsStore = AppSettingsScope.maybeOf(context);
    final feedback = settingsStore?.feedback;
    final diagnosticReport = settingsStore?.diagnosticReport;
    final globalNotice =
        settingsStore != null &&
            settingsStore.hasPersistenceIssue &&
            feedback != null &&
            feedback.title != null
        ? _DesktopGlobalNotice(
            title: feedback.title!,
            message: feedback.message ?? '',
            actionLabel: settingsStore.canRetrySecureStoreAccess
                ? '重试配置'
                : null,
            actionKey: settingsStore.canRetrySecureStoreAccess
                ? retrySecureStoreButtonKey
                : null,
            onActionTap: settingsStore.canRetrySecureStoreAccess
                ? settingsStore.retrySecureStoreAccess
                : null,
            secondaryActionLabel: diagnosticReport != null ? '复制诊断' : null,
            secondaryActionKey: diagnosticReport != null
                ? copyDiagnosticButtonKey
                : null,
            onSecondaryActionTap: diagnosticReport != null
                ? () => copyDiagnosticToClipboard(context, diagnosticReport)
                : null,
          )
        : null;

    return Semantics(
      label: '应用主框架',
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: Builder(
            builder: (context) {
              final width = MediaQuery.sizeOf(context).width;
              final padding = shellPaddingFor(width);
              final spacing = panelSpacingFor(width);
              return Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  children: [
                    header,
                    if (globalNotice != null) ...[
                      SizedBox(height: spacing),
                      globalNotice,
                    ],
                    SizedBox(height: spacing),
                    Expanded(child: body),
                    if (statusBar != null) ...[
                      SizedBox(height: spacing),
                      statusBar!,
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopGlobalNotice extends StatelessWidget {
  const _DesktopGlobalNotice({
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionKey,
    this.onActionTap,
    this.secondaryActionLabel,
    this.secondaryActionKey,
    this.onSecondaryActionTap,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final Future<void> Function()? onActionTap;
  final String? secondaryActionLabel;
  final Key? secondaryActionKey;
  final Future<void> Function()? onSecondaryActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: palette.danger, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if ((actionLabel != null && onActionTap != null) ||
              (secondaryActionLabel != null &&
                  onSecondaryActionTap != null)) ...[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (actionLabel != null && onActionTap != null)
                  TextButton(
                    key: actionKey,
                    onPressed: () => onActionTap!(),
                    child: Text(actionLabel!),
                  ),
                if (secondaryActionLabel != null &&
                    onSecondaryActionTap != null)
                  TextButton(
                    key: secondaryActionKey,
                    onPressed: () => onSecondaryActionTap!(),
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
