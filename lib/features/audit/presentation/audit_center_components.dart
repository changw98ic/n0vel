import 'package:flutter/material.dart';

import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_shell.dart';

class AuditListButton extends StatelessWidget {
  const AuditListButton({
    super.key,
    this.buttonKey,
    required this.label,
    this.selected = false,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class AuditInfoRow extends StatelessWidget {
  const AuditInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}

class AuditInfoBlock extends StatelessWidget {
  const AuditInfoBlock({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class AuditSummaryStrip extends StatelessWidget {
  const AuditSummaryStrip({
    super.key,
    required this.issue,
    required this.issueCount,
  });

  final AuditIssueRecord? issue;
  final int issueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final currentIssue = issue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, size: 18, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '审计中心 · 查看一致性问题、证据与处理状态',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            currentIssue == null
                ? '当前列表 $issueCount 项'
                : '当前证据 · ${currentIssue.target}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class AuditCallToActionState extends StatelessWidget {
  const AuditCallToActionState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class AuditCenteredPanelState extends StatelessWidget {
  const AuditCenteredPanelState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      padding: const EdgeInsets.all(24),
      child: AppEmptyState(title: title, message: message),
    );
  }
}
