import 'package:flutter/material.dart';

import '../../../app/state/app_simulation_store.dart';
import '../../../app/widgets/app_dialog.dart';
import '../../../app/widgets/desktop_shell.dart';

class SandboxMonitorPage extends StatefulWidget {
  const SandboxMonitorPage({
    super.key,
    this.failureMode = false,
    this.previewStatus,
  });

  static const agentListKey = ValueKey<String>('sandbox-agent-list');
  static const directorParticipantKey = ValueKey<String>(
    'sandbox-participant-director',
  );
  static const liuXiParticipantKey = ValueKey<String>(
    'sandbox-participant-liuxi',
  );
  static const yueRenParticipantKey = ValueKey<String>(
    'sandbox-participant-yueren',
  );
  static const fuXingzhouParticipantKey = ValueKey<String>(
    'sandbox-participant-fuxingzhou',
  );
  static const stateMachineParticipantKey = ValueKey<String>(
    'sandbox-participant-state-machine',
  );
  static const editPromptButtonKey = ValueKey<String>(
    'sandbox-edit-prompt-button',
  );
  static const editPromptFieldKey = ValueKey<String>(
    'sandbox-edit-prompt-field',
  );
  static const feedbackFieldKey = ValueKey<String>('sandbox-feedback-field');
  static const sendFeedbackButtonKey = ValueKey<String>(
    'sandbox-send-feedback-button',
  );

  final bool failureMode;
  final SimulationStatus? previewStatus;

  @override
  State<SandboxMonitorPage> createState() => _SandboxMonitorPageState();
}

class _SandboxMonitorPageState extends State<SandboxMonitorPage> {
  static const Color _modalBackground = Color(0xFF221D1A);
  static const Color _modalSurface = Color(0xFF2B2521);
  static const Color _modalBorder = Color(0xFF77695D);
  static const Color _modalTitle = Color(0xFFF1E9DE);
  static const Color _modalSubtitle = Color(0xFFA99C8E);

  late SimulationParticipant _selectedParticipant;
  final TextEditingController _feedbackController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  AppSimulationStore? _previewStore;

  @override
  void initState() {
    super.initState();
    _selectedParticipant = widget.failureMode
        ? SimulationParticipant.stateMachine
        : SimulationParticipant.liuXi;
    final previewStatus =
        widget.previewStatus ??
        (widget.failureMode ? SimulationStatus.failed : null);
    if (previewStatus != null) {
      _previewStore = AppSimulationStore.preview(previewStatus);
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _chatScrollController.dispose();
    _previewStore?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulationStore = _previewStore ?? AppSimulationScope.of(context);
    return ListenableBuilder(
      listenable: simulationStore,
      builder: (context, child) {
        final snapshot = simulationStore.snapshot;
        return Scaffold(
          backgroundColor: snapshot.status == SimulationStatus.none
              ? const Color(0xFFF6F0E6)
              : _modalBackground,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: snapshot.status == SimulationStatus.none
                      ? 816
                      : 1080,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: snapshot.status == SimulationStatus.none
                      ? _SandboxEmptyState(snapshot: snapshot)
                      : Container(
                          decoration: BoxDecoration(
                            color: _modalSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _modalBorder),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _SandboxHeader(
                                title: '模拟聊天室',
                                subtitle: '多角色协作流 · 导演调度视图',
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _ParticipantPanel(
                                      snapshot: snapshot,
                                      selectedParticipant: _selectedParticipant,
                                      onSelectParticipant: _selectParticipant,
                                      onEditPrompt: () => _showPromptEditor(
                                        context,
                                        snapshot,
                                        simulationStore,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _ChatroomPanel(
                                        snapshot: snapshot,
                                        selectedParticipantSnapshot: snapshot
                                            .participantSnapshot(
                                              _selectedParticipant,
                                            ),
                                        scrollController: _chatScrollController,
                                        feedbackController: _feedbackController,
                                        onSendFeedback: () =>
                                            _sendFeedback(simulationStore),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectParticipant(SimulationParticipant participant) {
    setState(() {
      _selectedParticipant = participant;
    });
  }

  Future<void> _showPromptEditor(
    BuildContext context,
    AppSimulationSnapshot snapshot,
    AppSimulationStore store,
  ) async {
    final participantSnapshot = snapshot.participantSnapshot(
      _selectedParticipant,
    );

    final updatedPrompt = await showAppTextInputDialog(
      context: context,
      title: '编辑 ${participantSnapshot.participant.shortName} 的认知 Prompt',
      hintText: '输入新的认知 Prompt',
      initialValue: participantSnapshot.promptSummary,
      fieldKey: SandboxMonitorPage.editPromptFieldKey,
      maxLines: 4,
    );

    if (updatedPrompt == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    store.updateParticipantPrompt(_selectedParticipant, updatedPrompt);
  }

  void _sendFeedback(AppSimulationStore store) {
    final feedback = _feedbackController.text.trim();
    if (feedback.isEmpty) {
      return;
    }
    store.sendDirectorFeedback(feedback);
    _feedbackController.clear();
  }
}

class _SandboxEmptyState extends StatelessWidget {
  const _SandboxEmptyState({required this.snapshot});

  final AppSimulationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFB7AA9A)),
      ),
      padding: const EdgeInsets.all(20),
      alignment: Alignment.topLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有模拟过程',
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF2E2925),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '当前章节还没有运行过 SimulationRun，因此暂时没有多 agent 输出可查看。请先在写作工作台发起一次模拟。',
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

class _SandboxHeader extends StatelessWidget {
  const _SandboxHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
            foregroundColor: _SandboxMonitorPageState._modalTitle,
          ),
          child: const Text('返回正文'),
        ),
        const Spacer(),
        Column(
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: _SandboxMonitorPageState._modalTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _SandboxMonitorPageState._modalSubtitle,
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

class _ParticipantPanel extends StatelessWidget {
  const _ParticipantPanel({
    required this.snapshot,
    required this.selectedParticipant,
    required this.onSelectParticipant,
    required this.onEditPrompt,
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
                    _ParticipantTile(
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

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.tileKey,
    required this.snapshot,
    required this.isSelected,
    required this.onTap,
    required this.onEditPrompt,
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

class _ChatroomPanel extends StatelessWidget {
  const _ChatroomPanel({
    required this.snapshot,
    required this.selectedParticipantSnapshot,
    required this.scrollController,
    required this.feedbackController,
    required this.onSendFeedback,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
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
                          child: _ChatBubble(message: snapshot.messages[index]),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 260,
                  child: _RunSummaryPanel(
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

class _RunSummaryPanel extends StatelessWidget {
  const _RunSummaryPanel({
    required this.snapshot,
    required this.selectedParticipantSnapshot,
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
            Text(
              '当前场景',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(snapshot.sceneLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryMetricChip(label: snapshot.headline),
                _SummaryMetricChip(
                  label: '阶段 $completedStages/${snapshot.stages.length}',
                ),
                _SummaryMetricChip(
                  label: '${snapshot.participants.length} 位参与方',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '输出分类',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryMetricChip(label: '发言 $speechCount'),
                _SummaryMetricChip(label: '意图 $intentCount'),
                _SummaryMetricChip(label: '裁决 $verdictCount'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '当前焦点',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              selectedParticipantSnapshot.participant.displayLabel,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '认知：${selectedParticipantSnapshot.promptSummary}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              selectedParticipantSnapshot.statusSummary,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '关键裁决',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
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

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip({required this.label});

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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final SimulationChatMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final theme = Theme.of(context);

    final background = switch (message.tone) {
      SimulationChatTone.director => palette.surface,
      SimulationChatTone.focusCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2F3941)
            : const Color(0xFFF5F9FC),
      SimulationChatTone.supportingCharacter => palette.elevated,
      SimulationChatTone.stateMachine =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF334237)
            : const Color(0xFFEAF3EA),
      SimulationChatTone.user => palette.elevated,
    };

    final border = switch (message.tone) {
      SimulationChatTone.director => palette.border,
      SimulationChatTone.focusCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF50626E)
            : const Color(0xFFC9D8E3),
      SimulationChatTone.supportingCharacter => palette.border,
      SimulationChatTone.stateMachine => palette.border,
      SimulationChatTone.user => palette.border,
    };

    final senderChipColor = switch (message.tone) {
      SimulationChatTone.director =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3B322C)
            : const Color(0xFFF1E7D7),
      SimulationChatTone.focusCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF384650)
            : const Color(0xFFE9F1F7),
      SimulationChatTone.supportingCharacter =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3B322C)
            : const Color(0xFFF1E7D7),
      SimulationChatTone.stateMachine =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF334237)
            : const Color(0xFFEAF3EA),
      SimulationChatTone.user => palette.subtle,
    };

    return Align(
      alignment: message.alignEnd
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: message.alignEnd ? 430 : 560),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.alignEnd) ...[
              _SenderChip(color: senderChipColor, label: message.sender),
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _kindLabel(message.kind),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.78,
                        ),
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
              _SenderChip(color: senderChipColor, label: message.sender),
            ],
          ],
        ),
      ),
    );
  }

  String _kindLabel(SimulationMessageKind kind) {
    return switch (kind) {
      SimulationMessageKind.speech => '发言',
      SimulationMessageKind.intent => '意图',
      SimulationMessageKind.verdict => '裁决',
      SimulationMessageKind.summary => '摘要',
    };
  }
}

class _SenderChip extends StatelessWidget {
  const _SenderChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
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
