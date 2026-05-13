import 'package:flutter/material.dart';

import '../../../app/state/app_simulation_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'sandbox_monitor_page.dart';

const _modalTitle = Color(0xFFF1E9DE);
const _modalSubtitle = Color(0xFFA99C8E);

class SandboxEmptyState extends StatelessWidget {
  const SandboxEmptyState({required this.snapshot, super.key});

  final AppSimulationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(20),
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有生成过程',
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF2E2925),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '这一场还没有 AI 生成记录。你可以先回到写作工作台，让 AI 按当前场景资料试写。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF514943),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('关闭'),
            ),
          ),
        ],
      ),
    );
  }
}

class SandboxHeader extends StatelessWidget {
  const SandboxHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(foregroundColor: _modalTitle),
          child: const Text('返回正文'),
        ),
        const Spacer(),
        Column(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: _modalTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _modalSubtitle,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 84),
      ],
    );
  }
}

class SandboxParticipantPanel extends StatelessWidget {
  const SandboxParticipantPanel({
    required this.snapshot,
    required this.selectedParticipant,
    required this.onSelectParticipant,
    required this.onEditPrompt,
    super.key,
  });

  final AppSimulationSnapshot snapshot;
  final SimulationParticipant selectedParticipant;
  final ValueChanged<SimulationParticipant> onSelectParticipant;
  final VoidCallback onEditPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: SandboxMonitorPage.agentListKey,
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('参与方', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final participantSnapshot in snapshot.participants) ...[
                    SandboxParticipantTile(
                      tileKey: _tileKeyFor(participantSnapshot.participant),
                      snapshot: participantSnapshot,
                      isSelected:
                          selectedParticipant ==
                          participantSnapshot.participant,
                      onTap: () =>
                          onSelectParticipant(participantSnapshot.participant),
                      onEditPrompt: onEditPrompt,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Key _tileKeyFor(SimulationParticipant participant) {
    return switch (participant) {
      SimulationParticipant.director =>
        SandboxMonitorPage.directorParticipantKey,
      SimulationParticipant.liuXi => SandboxMonitorPage.liuXiParticipantKey,
      SimulationParticipant.yueRen => SandboxMonitorPage.yueRenParticipantKey,
      SimulationParticipant.fuXingzhou =>
        SandboxMonitorPage.fuXingzhouParticipantKey,
      SimulationParticipant.stateMachine =>
        SandboxMonitorPage.stateMachineParticipantKey,
    };
  }
}

class SandboxParticipantTile extends StatelessWidget {
  const SandboxParticipantTile({
    required this.tileKey,
    required this.snapshot,
    required this.isSelected,
    required this.onTap,
    required this.onEditPrompt,
    super.key,
  });

  final Key tileKey;
  final SimulationParticipantSnapshot snapshot;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEditPrompt;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? palette.primary : palette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? palette.primary : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.participant.displayLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '认知：${snapshot.promptSummary}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.textTheme.bodySmall?.color,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: SandboxMonitorPage.editPromptButtonKey,
                    onPressed: onEditPrompt,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.onPrimary.withValues(alpha: 0.4)
                            : palette.border,
                      ),
                      backgroundColor: isSelected
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.12)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      textStyle: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('编辑认知 Prompt'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SandboxChatroomPanel extends StatelessWidget {
  const SandboxChatroomPanel({
    required this.snapshot,
    required this.selectedParticipantSnapshot,
    required this.scrollController,
    required this.feedbackController,
    required this.onSendFeedback,
    super.key,
  });

  final AppSimulationSnapshot snapshot;
  final SimulationParticipantSnapshot selectedParticipantSnapshot;
  final ScrollController scrollController;
  final TextEditingController feedbackController;
  final VoidCallback onSendFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.subtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  snapshot.turnLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(snapshot.turnSummary, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(snapshot.headline, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(snapshot.summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(
            snapshot.stageSummary,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    child: ListView.separated(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      itemCount: snapshot.messages.length,
                      cacheExtent: 500,
                      addAutomaticKeepAlives: false,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return RepaintBoundary(
                          child: SandboxChatBubble(message: snapshot.messages[index]),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 260,
                  child: SandboxRunSummaryPanel(
                    snapshot: snapshot,
                    selectedParticipantSnapshot: selectedParticipantSnapshot,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(snapshot.footerHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  key: SandboxMonitorPage.feedbackFieldKey,
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    hintText: '给导演补充要求，例如：让岳人更强硬一点。',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                key: SandboxMonitorPage.sendFeedbackButtonKey,
                onPressed: onSendFeedback,
                child: const Text('发送给导演'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('返回正文'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SandboxRunSummaryPanel extends StatelessWidget {
  const SandboxRunSummaryPanel({
    required this.snapshot,
    required this.selectedParticipantSnapshot,
    super.key,
  });

  final AppSimulationSnapshot snapshot;
  final SimulationParticipantSnapshot selectedParticipantSnapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final speechCount = snapshot.messages
        .where((message) => message.kind == SimulationMessageKind.speech)
        .length;
    final intentCount = snapshot.messages
        .where((message) => message.kind == SimulationMessageKind.intent)
        .length;
    final verdictCount = snapshot.messages
        .where((message) => message.kind == SimulationMessageKind.verdict)
        .length;
    final latestVerdict = snapshot.messages.lastWhere(
      (message) => message.kind == SimulationMessageKind.verdict,
      orElse: () => snapshot.messages.last,
    );
    final completedStages = snapshot.stages
        .where((stage) => stage.status == SimulationStageStatus.completed)
        .length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('运行摘要', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text('当前场景', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(snapshot.sceneLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SandboxSummaryMetricChip(label: snapshot.headline),
                SandboxSummaryMetricChip(label: '阶段 $completedStages/${snapshot.stages.length}'),
                SandboxSummaryMetricChip(label: '${snapshot.participants.length} 位参与方'),
              ],
            ),
            const SizedBox(height: 16),
            Text('输出分类', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SandboxSummaryMetricChip(label: '发言 $speechCount'),
                SandboxSummaryMetricChip(label: '意图 $intentCount'),
                SandboxSummaryMetricChip(label: '裁决 $verdictCount'),
              ],
            ),
            const SizedBox(height: 16),
            Text('当前焦点', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(selectedParticipantSnapshot.participant.displayLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('认知：${selectedParticipantSnapshot.promptSummary}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(selectedParticipantSnapshot.statusSummary, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            Text('关键裁决', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(latestVerdict.title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(latestVerdict.body, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class SandboxSummaryMetricChip extends StatelessWidget {
  const SandboxSummaryMetricChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

class SandboxChatBubble extends StatelessWidget {
  const SandboxChatBubble({required this.message, super.key});

  final SimulationChatMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);

    final background = switch (message.tone) {
      SimulationChatTone.director => palette.surface,
      SimulationChatTone.focusCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2F3941) : const Color(0xFFF5F9FC),
      SimulationChatTone.supportingCharacter => palette.elevated,
      SimulationChatTone.stateMachine =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF334237) : const Color(0xFFEAF3EA),
      SimulationChatTone.user => palette.elevated,
    };

    final border = switch (message.tone) {
      SimulationChatTone.director => palette.border,
      SimulationChatTone.focusCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF50626E) : const Color(0xFFC9D8E3),
      SimulationChatTone.supportingCharacter => palette.border,
      SimulationChatTone.stateMachine => palette.border,
      SimulationChatTone.user => palette.border,
    };

    final senderChipColor = switch (message.tone) {
      SimulationChatTone.director =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3B322C) : const Color(0xFFF1E7D7),
      SimulationChatTone.focusCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF384650) : const Color(0xFFE9F1F7),
      SimulationChatTone.supportingCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3B322C) : const Color(0xFFF1E7D7),
      SimulationChatTone.stateMachine =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF334237) : const Color(0xFFEAF3EA),
      SimulationChatTone.user => palette.subtle,
    };

    return Align(
      alignment: message.alignEnd
          ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: message.alignEnd ? 430 : 560),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.alignEnd) ...[
              SandboxSenderChip(color: senderChipColor, label: message.sender),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kindLabel(message.kind),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(message.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            if (message.alignEnd) ...[
              const SizedBox(width: 10),
              SandboxSenderChip(color: senderChipColor, label: message.sender),
            ],
          ],
        ),
      ),
    );
  }

  static String _kindLabel(SimulationMessageKind kind) {
    return switch (kind) {
      SimulationMessageKind.speech => '发言',
      SimulationMessageKind.intent => '意图',
      SimulationMessageKind.verdict => '裁决',
      SimulationMessageKind.summary => '摘要',
    };
  }
}

class SandboxSenderChip extends StatelessWidget {
  const SandboxSenderChip({required this.color, required this.label, super.key});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
