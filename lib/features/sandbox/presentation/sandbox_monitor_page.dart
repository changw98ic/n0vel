import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/widgets/app_dialog.dart';
import 'sandbox_monitor_components.dart';

class SandboxMonitorPage extends ConsumerStatefulWidget {
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
  ConsumerState<SandboxMonitorPage> createState() => _SandboxMonitorPageState();
}

class _SandboxMonitorPageState extends ConsumerState<SandboxMonitorPage> {
  static const Color _modalBackground = Color(0xFF221D1A);
  static const Color _modalSurface = Color(0xFF2B2521);
  static const Color _modalBorder = Color(0xFF77695D);

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
    final AppSimulationStore simulationStore;
    if (_previewStore != null) {
      simulationStore = _previewStore!;
    } else {
      simulationStore = ref.watch(appSimulationStoreProvider);
    }
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
                      ? SandboxEmptyState(snapshot: snapshot)
                      : Container(
                          decoration: BoxDecoration(
                            color: _modalSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _modalBorder),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const SandboxHeader(
                                title: 'AI 生成过程',
                                subtitle: '多角色协作流 · 导演调度视图',
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SandboxParticipantPanel(
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
                                      child: SandboxChatroomPanel(
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
