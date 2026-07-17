import 'package:flutter/material.dart';

import '../../../app/logging/app_event_log.dart';
import '../../../app/logging/app_event_log_privacy.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../data/workbench_ai_controller.dart';
import 'workbench_ai_revision_helpers.dart';

class WorkbenchAiReviewDialog extends StatefulWidget {
  const WorkbenchAiReviewDialog({
    required this.reviewTitle,
    required this.blocks,
    required this.metadata,
    required this.original,
    required this.continueMode,
    required this.onAccept,
    required this.onReject,
    super.key,
  });

  final String reviewTitle;
  final List<WorkbenchAiReviewBlock> blocks;
  final AiRequestMetadata metadata;
  final String original;
  final bool continueMode;
  final Future<String?> Function(String acceptedText) onAccept;
  final VoidCallback onReject;

  @override
  State<WorkbenchAiReviewDialog> createState() =>
      _WorkbenchAiReviewDialogState();
}

class _WorkbenchAiReviewDialogState extends State<WorkbenchAiReviewDialog> {
  late final List<bool> _included;
  bool _isSaving = false;
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();
    _included = List<bool>.filled(widget.blocks.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keptCount = _included.where((v) => v).length;
    final hasIncluded = keptCount > 0;
    final uniquePrompts = {
      for (final block in widget.blocks) block.authorPrompt,
    };
    final acceptedText = WorkbenchAiRevisionHelpers.acceptedTextForBlocks(
      widget.original,
      widget.blocks,
      _included,
      continueMode: widget.continueMode,
    );

    return DesktopModalDialog(
      title: widget.reviewTitle,
      width: 760,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (uniquePrompts.length == 1) ...[
              Text('修改意图：${uniquePrompts.first}'),
              const SizedBox(height: 12),
            ],
            Text('请求配置：${widget.metadata.providerSummary}'),
            const SizedBox(height: 4),
            Text('接口：${widget.metadata.endpointLabel}'),
            const SizedBox(height: 4),
            Text('风格约束：${widget.metadata.styleSummary}'),
            const SizedBox(height: 4),
            Text('章节上下文：${widget.metadata.sceneSummary}'),
            const SizedBox(height: 4),
            Text(widget.metadata.characterSummary),
            const SizedBox(height: 4),
            Text(widget.metadata.worldSummary),
            const SizedBox(height: 4),
            Text('模拟摘要：${widget.metadata.simulationSummary}'),
            const SizedBox(height: 12),
            Text('已保留 $keptCount / ${widget.blocks.length} 个修改块'),
            const SizedBox(height: 16),
            const Text('原始正文'),
            const SizedBox(height: 8),
            Text(widget.original),
            const SizedBox(height: 16),
            for (var index = 0; index < widget.blocks.length; index += 1) ...[
              Text(widget.blocks[index].blockLabel),
              const SizedBox(height: 8),
              const Text('上一段'),
              const SizedBox(height: 4),
              Text(widget.blocks[index].previousText),
              const SizedBox(height: 8),
              const Text('当前被修改段'),
              const SizedBox(height: 4),
              Text(widget.blocks[index].originalText),
              const SizedBox(height: 8),
              const Text('下一段'),
              const SizedBox(height: 4),
              Text(widget.blocks[index].nextText),
              const SizedBox(height: 8),
              const Text('作者该段修改意见'),
              const SizedBox(height: 4),
              Text(widget.blocks[index].authorPrompt),
              const SizedBox(height: 8),
              Text(widget.blocks[index].suggestionText),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _included[index] = !_included[index];
                  });
                },
                child: Text(
                  _included[index]
                      ? '排除修改块 ${index + 1}'
                      : '恢复修改块 ${index + 1}',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!hasIncluded) const Text('至少保留 1 个修改块'),
            if (hasIncluded && acceptedText != widget.original) ...[
              const SizedBox(height: 4),
              const Text('接受后的正文预览'),
              const SizedBox(height: 8),
              Text(acceptedText),
            ],
            if (_saveErrorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveErrorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: appDangerColor,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSaving ? null : widget.onReject,
          child: const Text('拒绝变更'),
        ),
        FilledButton(
          onPressed: hasIncluded && !_isSaving
              ? () async {
                  setState(() {
                    _isSaving = true;
                    _saveErrorMessage = null;
                  });
                  final error = await widget.onAccept(acceptedText);
                  if (error != null && mounted) {
                    setState(() {
                      _isSaving = false;
                      _saveErrorMessage = error;
                    });
                  }
                }
              : null,
          child: Text(_isSaving ? '正在保存…' : '接受变更'),
        ),
      ],
    );
  }
}

Future<void> showAiReviewDialog({
  required BuildContext context,
  required String reviewTitle,
  required String historyPrompt,
  required List<WorkbenchAiReviewBlock> blocks,
  required AiRequestMetadata metadata,
  required bool continueMode,
  required bool clearSelectionsOnAccept,
  required AppDraftStore draftStore,
  required AppVersionStore versionStore,
  required AppAiHistoryStore historyStore,
  required WorkbenchAiController aiController,
  required VoidCallback onAccepted,
  VoidCallback? onRejected,
  String? correlationId,
}) async {
  historyStore.addEntry(
    mode: continueMode ? '续写' : '改写',
    prompt: historyPrompt,
  );
  final original = draftStore.snapshot.text;
  await aiController.logEvent(
    category: AppEventLogCategory.ui,
    action: 'ui.ai.review_opened.succeeded',
    status: AppEventLogStatus.succeeded,
    message: 'Opened AI review dialog.',
    correlationId: correlationId,
    metadata: {
      'reviewTitle': reviewTitle,
      'blockCount': blocks.length,
      'continueMode': continueMode,
      ...AppEventLogPrivacy.textMetadata(
        field: 'historyPrompt',
        value: historyPrompt,
      ),
    },
  );
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierLabel: '关闭',
    builder: (dialogContext) => WorkbenchAiReviewDialog(
      reviewTitle: reviewTitle,
      blocks: blocks,
      metadata: metadata,
      original: original,
      continueMode: continueMode,
      onReject: () {
        onRejected?.call();
        Navigator.of(dialogContext).pop();
      },
      onAccept: (acceptedText) async {
        if (draftStore.snapshot.text != original) {
          return '正文内容已变更，请重新打开 AI 审阅并重新生成后再接受。';
        }
        try {
          await draftStore.updateTextAndPersist(acceptedText);
          try {
            await versionStore.captureSnapshotAndPersist(
              label: continueMode ? 'AI 接受变更（续写）' : 'AI 接受变更',
              content: acceptedText,
            );
          } catch (_) {
            try {
              await draftStore.updateTextAndPersist(original);
              return '版本保存失败，正文已回滚。请稍后重试。';
            } catch (_) {
              return '版本保存失败，且正文回滚也失败。当前正文可能已部分更新，请手动确认后重试。';
            }
          }
        } catch (_) {
          return '本地保存失败，请稍后重试。';
        }
        if (!context.mounted) return null;
        onAccepted();
        Navigator.of(dialogContext).pop();
        return null;
      },
    ),
  );
}
