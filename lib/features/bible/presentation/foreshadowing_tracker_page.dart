import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../data/foreshadowing_store.dart';

class ForeshadowingTrackerPage extends StatefulWidget {
  const ForeshadowingTrackerPage({
    super.key,
    ForeshadowingStore? store,
    this.initialRelatedChapterLabel = '第 1 章 / 场景 01',
  }) : _store = store;

  static const titleFieldKey = ValueKey<String>('foreshadowing-title-field');
  static const descriptionFieldKey = ValueKey<String>(
    'foreshadowing-description-field',
  );
  static const relatedChapterFieldKey = ValueKey<String>(
    'foreshadowing-related-chapter-field',
  );
  static const createButtonKey = ValueKey<String>(
    'foreshadowing-create-button',
  );
  static const listKey = ValueKey<String>('foreshadowing-list');
  static const remindersKey = ValueKey<String>('foreshadowing-reminders');
  static const developedStatusButtonKey = ValueKey<String>(
    'foreshadowing-status-developed',
  );
  static const abandonedStatusButtonKey = ValueKey<String>(
    'foreshadowing-status-abandoned',
  );

  final ForeshadowingStore? _store;
  final String initialRelatedChapterLabel;

  @override
  State<ForeshadowingTrackerPage> createState() =>
      _ForeshadowingTrackerPageState();
}

class _ForeshadowingTrackerPageState extends State<ForeshadowingTrackerPage> {
  late final ForeshadowingStore _store;
  late final bool _ownsStore;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  late final TextEditingController _relatedChapterController;
  String? _selectedThreadId;

  @override
  void initState() {
    super.initState();
    _store = widget._store ?? ForeshadowingStore();
    _ownsStore = widget._store == null;
    _relatedChapterController = TextEditingController(
      text: widget.initialRelatedChapterLabel,
    );
    _store.addListener(_handleStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_handleStoreChanged);
    if (_ownsStore) {
      _store.dispose();
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _relatedChapterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 860;
    final content = compact
        ? ListView(
            padding: const EdgeInsets.all(AppDesignTokens.space16),
            children: [
              _buildCreatePanel(theme),
              const SizedBox(height: AppDesignTokens.space16),
              _buildReminderPanel(theme),
              const SizedBox(height: AppDesignTokens.space16),
              _buildThreadList(theme),
            ],
          )
        : Padding(
            padding: const EdgeInsets.all(AppDesignTokens.space20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 340,
                  child: Column(
                    children: [
                      _buildCreatePanel(theme),
                      const SizedBox(height: AppDesignTokens.space16),
                      Expanded(child: _buildReminderPanel(theme)),
                    ],
                  ),
                ),
                const SizedBox(width: AppDesignTokens.space20),
                Expanded(child: _buildThreadList(theme)),
              ],
            ),
          );
    return Scaffold(backgroundColor: Colors.transparent, body: content);
  }

  Widget _buildCreatePanel(ThemeData theme) {
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space16),
      decoration: appPanelDecoration(context, color: palette.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('新增伏笔', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space12),
          TextField(
            key: ForeshadowingTrackerPage.titleFieldKey,
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '名称',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDesignTokens.space8),
          TextField(
            key: ForeshadowingTrackerPage.descriptionFieldKey,
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '描述',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDesignTokens.space8),
          TextField(
            key: ForeshadowingTrackerPage.relatedChapterFieldKey,
            controller: _relatedChapterController,
            decoration: const InputDecoration(
              labelText: '关联章节',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppDesignTokens.space12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: ForeshadowingTrackerPage.createButtonKey,
              onPressed: _titleController.text.trim().isEmpty
                  ? null
                  : _createThread,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('创建伏笔'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderPanel(ThemeData theme) {
    final palette = desktopPalette(context);
    final reminders = _store.reminders;
    return Container(
      key: ForeshadowingTrackerPage.remindersKey,
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space16),
      decoration: appPanelDecoration(context, color: palette.subtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_outlined, color: palette.primary),
              const SizedBox(width: AppDesignTokens.space8),
              Text('相关章节提醒', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppDesignTokens.space12),
          if (reminders.isEmpty)
            Text('暂无需要提醒的伏笔', style: theme.textTheme.bodySmall)
          else
            for (final thread in reminders) ...[
              _ReminderRow(thread: thread),
              if (thread != reminders.last)
                const SizedBox(height: AppDesignTokens.space8),
            ],
        ],
      ),
    );
  }

  Widget _buildThreadList(ThemeData theme) {
    final palette = desktopPalette(context);
    final threads = _store.threads;
    return Container(
      key: ForeshadowingTrackerPage.listKey,
      padding: const EdgeInsets.all(AppDesignTokens.space16),
      decoration: appPanelDecoration(context, color: palette.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('伏笔追踪', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space4),
          Text('手动管理埋设、推进和废弃状态。', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppDesignTokens.space12),
          if (threads.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDesignTokens.space32),
              child: Center(child: Text('还没有伏笔')),
            )
          else
            for (final thread in threads) ...[
              _ForeshadowingThreadCard(
                thread: thread,
                selected: thread.id == _selectedThreadId,
                onSelect: () => setState(() {
                  _selectedThreadId = thread.id;
                }),
                onStatusChanged: (status) {
                  setState(() {
                    _selectedThreadId = thread.id;
                  });
                  _store.updateStatus(thread.id, status);
                },
              ),
              if (thread != threads.last)
                const SizedBox(height: AppDesignTokens.space12),
            ],
        ],
      ),
    );
  }

  void _handleStoreChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _createThread() {
    final thread = _store.createForeshadowing(
      title: _titleController.text,
      description: _descriptionController.text,
      relatedChapterLabel: _relatedChapterController.text,
    );
    setState(() {
      _selectedThreadId = thread.id;
      _titleController.clear();
      _descriptionController.clear();
    });
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.thread});

  final ForeshadowingThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(thread.relatedChapterLabel, style: theme.textTheme.labelSmall),
          const SizedBox(height: AppDesignTokens.space4),
          Text(thread.title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppDesignTokens.space4),
          Text(thread.status.label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ForeshadowingThreadCard extends StatelessWidget {
  const _ForeshadowingThreadCard({
    required this.thread,
    required this.selected,
    required this.onSelect,
    required this.onStatusChanged,
  });

  final ForeshadowingThread thread;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<ForeshadowingStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDesignTokens.space16),
        decoration: BoxDecoration(
          color: selected ? palette.elevated : palette.subtle,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
          border: Border.all(
            color: selected ? palette.primary : palette.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(thread.title, style: theme.textTheme.titleSmall),
                ),
                _StatusPill(status: thread.status),
              ],
            ),
            const SizedBox(height: AppDesignTokens.space8),
            Text(thread.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppDesignTokens.space8),
            Text(
              '关联章节：${thread.relatedChapterLabel}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppDesignTokens.space12),
            Wrap(
              spacing: AppDesignTokens.space8,
              runSpacing: AppDesignTokens.space8,
              children: [
                ChoiceChip(
                  label: const Text('未展开'),
                  selected: thread.status == ForeshadowingStatus.undeveloped,
                  onSelected: (_) =>
                      onStatusChanged(ForeshadowingStatus.undeveloped),
                ),
                ChoiceChip(
                  key: ForeshadowingTrackerPage.developedStatusButtonKey,
                  label: const Text('已展开'),
                  selected: thread.status == ForeshadowingStatus.developed,
                  onSelected: (_) =>
                      onStatusChanged(ForeshadowingStatus.developed),
                ),
                ChoiceChip(
                  key: ForeshadowingTrackerPage.abandonedStatusButtonKey,
                  label: const Text('已废弃'),
                  selected: thread.status == ForeshadowingStatus.abandoned,
                  onSelected: (_) =>
                      onStatusChanged(ForeshadowingStatus.abandoned),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ForeshadowingStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);
    final color = switch (status) {
      ForeshadowingStatus.undeveloped => palette.primary,
      ForeshadowingStatus.developed => palette.success,
      ForeshadowingStatus.abandoned => palette.secondaryText,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignTokens.space8,
        vertical: AppDesignTokens.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
