import 'package:flutter/material.dart';

import '../../../app/logging/app_event_log.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'workbench_ai_controller.dart';
import 'workbench_ai_paragraph_adoption.dart';
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
  late final List<AiAdoptableUnit> _units;
  bool _isSaving = false;
  String? _saveErrorMessage;

  @override
  void initState() {
    super.initState();
    _units = AiParagraphAdoptionHelpers.buildAdoptableUnits(
      blocks: widget.blocks,
      continueMode: widget.continueMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final acceptedCount = AiParagraphAdoptionHelpers.countAcceptedCandidates(_units);
    final candidateCount = _units.where((u) => u.candidateText.isNotEmpty && u.candidateText != u.originalText).length;
    final uniquePrompts = {
      for (final block in widget.blocks) block.authorPrompt,
    };
    final acceptedText = AiParagraphAdoptionHelpers.acceptedTextForUnits(
      original: widget.original,
      units: _units,
      continueMode: widget.continueMode,
    );
    // hasAcceptedChanges is true when at least one candidate with actual changes is accepted
    final hasAcceptedChanges = acceptedCount > 0;

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
            Text('已采纳 $acceptedCount / $candidateCount 个建议段落'),
            const SizedBox(height: 16),
            for (var index = 0; index < _units.length; index += 1) ...[
              _buildUnitCard(context, index, theme),
              const SizedBox(height: 12),
            ],
            if (!hasAcceptedChanges) const Text('至少采纳 1 个建议段落'),
            if (hasAcceptedChanges) ...[
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
          onPressed: hasAcceptedChanges && !_isSaving
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

  Widget _buildUnitCard(BuildContext context, int index, ThemeData theme) {
    final unit = _units[index];
    final hasOriginal = unit.originalText.isNotEmpty;
    final hasCandidate = unit.candidateText.isNotEmpty && unit.candidateText != unit.originalText;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x5CD6DDD0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unit.blockLabel != null) ...[
            Text(unit.blockLabel!, style: theme.textTheme.labelSmall),
            const SizedBox(height: 8),
          ],
          if (hasOriginal && unit.originalText != unit.candidateText) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('原文', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                      Text(unit.originalText),
                    ],
                  ),
                ),
                if (hasCandidate) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('建议', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Text(unit.candidateText),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ] else if (hasCandidate) ...[
            Text('建议', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(unit.candidateText),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (hasOriginal && hasCandidate) ...[
                OutlinedButton(
                  onPressed: unit.isAccepted
                      ? null
                      : () {
                          setState(() {
                            _units[index] = unit.copyWith(isAccepted: true);
                          });
                        },
                  child: const Text('采纳建议'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: !unit.isAccepted
                      ? null
                      : () {
                          setState(() {
                            _units[index] = unit.copyWith(isAccepted: false);
                          });
                        },
                  child: const Text('保留原文'),
                ),
              ] else if (hasCandidate) ...[
                OutlinedButton(
                  onPressed: unit.isAccepted
                      ? null
                      : () {
                          setState(() {
                            _units[index] = unit.copyWith(isAccepted: true);
                          });
                        },
                  child: const Text('采纳'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: !unit.isAccepted
                      ? null
                      : () {
                          setState(() {
                            _units[index] = unit.copyWith(isAccepted: false);
                          });
                        },
                  child: const Text('忽略'),
                ),
              ] else ...[
                Text('无变更', style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ],
      ),
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
      'historyPromptPreview': WorkbenchAiRevisionHelpers.previewText(
        historyPrompt,
        160,
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
