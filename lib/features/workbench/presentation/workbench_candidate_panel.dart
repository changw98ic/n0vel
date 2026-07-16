import 'package:flutter/material.dart';

import '../../../app/state/story_generation_run_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../domain/workbench_orchestrator.dart';

/// The only workbench surface that can request author acceptance of a scene
/// candidate.  It deliberately receives a proof-gated projection, rather
/// than a raw `candidateProse` string.
class WorkbenchCandidatePanel extends StatefulWidget {
  const WorkbenchCandidatePanel({
    super.key,
    required this.presentation,
    required this.actionFeedback,
    required this.onAccept,
    required this.onReject,
  });

  static const panelKey = ValueKey<String>('workbench-candidate-panel');
  static const statusKey = ValueKey<String>('workbench-candidate-status');
  static const proseKey = ValueKey<String>('workbench-candidate-prose');
  static const acceptButtonKey = ValueKey<String>('workbench-candidate-accept');
  static const rejectButtonKey = ValueKey<String>('workbench-candidate-reject');
  static const noticeKey = ValueKey<String>('workbench-candidate-notice');

  final StoryGenerationCandidatePresentation presentation;
  final WorkbenchCandidateActionFeedback actionFeedback;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  @override
  State<WorkbenchCandidatePanel> createState() =>
      _WorkbenchCandidatePanelState();
}

class _WorkbenchCandidatePanelState extends State<WorkbenchCandidatePanel> {
  bool _requestInFlight = false;

  @override
  Widget build(BuildContext context) {
    final presentation = widget.presentation;
    if (presentation.state == StoryGenerationCandidatePresentationState.none) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final busy = _requestInFlight || widget.actionFeedback.isBusy;
    final notice = widget.actionFeedback.message.trim();
    final noticeIsError = widget.actionFeedback.isError;
    final canResolve = presentation.canAccept && !busy;
    return Container(
      key: WorkbenchCandidatePanel.panelKey,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        border: Border.all(
          color: presentation.canAccept
              ? const Color(0x6BC9D2C4)
              : const Color(0x30FFFFFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            presentation.headline,
            key: WorkbenchCandidatePanel.statusKey,
            style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            presentation.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFDDE5D8),
              height: 1.4,
            ),
          ),
          if (notice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notice,
              key: WorkbenchCandidatePanel.noticeKey,
              style: theme.textTheme.bodySmall?.copyWith(
                color: noticeIsError
                    ? const Color(0xFFFFB4AB)
                    : const Color(0xFFC9D2C4),
                height: 1.35,
              ),
            ),
          ],
          if (presentation.showsCandidateProse) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x12FFFFFF),
                borderRadius: BorderRadius.circular(
                  AppDesignTokens.radiusMedium,
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  // Candidate content is rendered as literal prose.  It is
                  // never parsed as instructions or used to choose an action.
                  presentation.prose,
                  key: WorkbenchCandidatePanel.proseKey,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: WorkbenchCandidatePanel.acceptButtonKey,
                  onPressed: canResolve
                      ? () => _runAction(widget.onAccept)
                      : null,
                  child: Text(busy ? '正在提交…' : '采纳候选稿'),
                ),
                OutlinedButton(
                  key: WorkbenchCandidatePanel.rejectButtonKey,
                  onPressed: canResolve
                      ? () => _runAction(widget.onReject)
                      : null,
                  child: Text(busy ? '正在处理…' : '拒绝候选稿'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_requestInFlight || widget.actionFeedback.isBusy) return;
    setState(() => _requestInFlight = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _requestInFlight = false);
    }
  }
}
