import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../../domain/workspace_models.dart';

class CharacterStateUpdate {
  const CharacterStateUpdate({
    required this.currentState,
    required this.recentChange,
    required this.history,
  });

  final String currentState;
  final String recentChange;
  final List<CharacterStateHistoryEntry> history;
}

class CharacterStateHistoryEntry {
  const CharacterStateHistoryEntry({
    required this.state,
    required this.change,
    this.recordedAtLabel = '手动记录',
  });

  final String state;
  final String change;
  final String recordedAtLabel;
}

String characterCurrentStateForRecord(CharacterRecord character) {
  final summary = character.summary.trim();
  if (summary.isNotEmpty) {
    return summary;
  }
  final note = character.note.trim();
  if (note.isNotEmpty) {
    return note;
  }
  return '等待补充当前状态';
}

String characterRecentChangeForRecord(CharacterRecord character) {
  final history = characterStateHistoryForRecord(character);
  if (history.isNotEmpty) {
    return history.first.change;
  }
  final reference = character.referenceSummary.trim();
  if (reference.isNotEmpty) {
    return reference.split('\n').first.trim();
  }
  return '暂无最近变化';
}

List<CharacterStateHistoryEntry> characterStateHistoryForRecord(
  CharacterRecord character,
) {
  final currentState = characterCurrentStateForRecord(character);
  final reference = character.referenceSummary.trim();
  final entries = <CharacterStateHistoryEntry>[];
  if (reference.isNotEmpty) {
    for (final rawLine in reference.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line == '状态历史') {
        continue;
      }
      final cleaned = line.replaceFirst(RegExp(r'^[-•]\s*'), '');
      final parts = cleaned.split('|');
      if (parts.length >= 2) {
        entries.add(
          CharacterStateHistoryEntry(
            state: parts.first.trim(),
            change: parts.sublist(1).join('|').trim(),
            recordedAtLabel: '历史记录',
          ),
        );
      } else {
        entries.add(
          CharacterStateHistoryEntry(
            state: currentState,
            change: cleaned,
            recordedAtLabel: '引用摘要',
          ),
        );
      }
    }
  }
  if (entries.isEmpty && currentState.trim().isNotEmpty) {
    entries.add(
      CharacterStateHistoryEntry(
        state: currentState,
        change: character.note.trim().isEmpty ? '来自人物摘要' : character.note,
        recordedAtLabel: '当前',
      ),
    );
  }
  return List<CharacterStateHistoryEntry>.unmodifiable(entries);
}

String characterStateHistoryToReferenceSummary(
  List<CharacterStateHistoryEntry> history,
) {
  final entries = history
      .where((entry) => entry.state.trim().isNotEmpty)
      .take(8)
      .toList(growable: false);
  if (entries.isEmpty) {
    return '';
  }
  return [
    '状态历史',
    for (final entry in entries)
      '- ${entry.state.trim()} | ${entry.change.trim().isEmpty ? '手动更新' : entry.change.trim()}',
  ].join('\n');
}

class CharacterStateCard extends StatefulWidget {
  const CharacterStateCard({
    required this.characterName,
    required this.currentState,
    required this.recentChange,
    this.role = '',
    this.history = const <CharacterStateHistoryEntry>[],
    this.onStateSubmitted,
    this.compact = false,
    this.showEditor = true,
    this.historyInitiallyExpanded = false,
    super.key,
  }) : noticeTitle = null,
       noticeMessage = null,
       noticeAccent = null;

  const CharacterStateCard.notice({
    required String title,
    required String message,
    required Color accent,
    super.key,
  }) : characterName = '',
       role = '',
       currentState = '',
       recentChange = '',
       history = const <CharacterStateHistoryEntry>[],
       onStateSubmitted = null,
       compact = false,
       showEditor = false,
       historyInitiallyExpanded = false,
       noticeTitle = title,
       noticeMessage = message,
       noticeAccent = accent;

  static const cardKey = ValueKey<String>('character-state-card');
  static const stateFieldKey = ValueKey<String>(
    'character-state-card-state-field',
  );
  static const changeFieldKey = ValueKey<String>(
    'character-state-card-change-field',
  );
  static const saveButtonKey = ValueKey<String>(
    'character-state-card-save-button',
  );
  static const historyTileKey = ValueKey<String>(
    'character-state-card-history',
  );

  final String characterName;
  final String role;
  final String currentState;
  final String recentChange;
  final List<CharacterStateHistoryEntry> history;
  final ValueChanged<CharacterStateUpdate>? onStateSubmitted;
  final bool compact;
  final bool showEditor;
  final bool historyInitiallyExpanded;
  final String? noticeTitle;
  final String? noticeMessage;
  final Color? noticeAccent;

  bool get _isNotice => noticeTitle != null;

  @override
  State<CharacterStateCard> createState() => _CharacterStateCardState();
}

class _CharacterStateCardState extends State<CharacterStateCard> {
  late String _currentState;
  late String _recentChange;
  late List<CharacterStateHistoryEntry> _history;
  late TextEditingController _stateController;
  late TextEditingController _changeController;

  @override
  void initState() {
    super.initState();
    _currentState = widget.currentState;
    _recentChange = widget.recentChange;
    _history = List<CharacterStateHistoryEntry>.from(widget.history);
    _stateController = TextEditingController(text: widget.currentState);
    _changeController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant CharacterStateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentState != oldWidget.currentState ||
        widget.recentChange != oldWidget.recentChange ||
        widget.history != oldWidget.history) {
      _currentState = widget.currentState;
      _recentChange = widget.recentChange;
      _history = List<CharacterStateHistoryEntry>.from(widget.history);
      if (_stateController.text != widget.currentState) {
        _stateController.text = widget.currentState;
      }
    }
  }

  @override
  void dispose() {
    _stateController.dispose();
    _changeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._isNotice) {
      return _buildNotice(context);
    }
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      key: CharacterStateCard.cardKey,
      width: double.infinity,
      padding: EdgeInsets.all(
        widget.compact ? AppDesignTokens.space12 : AppDesignTokens.space16,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
        border: Border.all(color: palette.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: palette.primary),
              const SizedBox(width: AppDesignTokens.space8),
              Expanded(child: Text('角色状态', style: theme.textTheme.titleSmall)),
            ],
          ),
          const SizedBox(height: AppDesignTokens.space8),
          Text(widget.characterName, style: theme.textTheme.titleMedium),
          if (widget.role.trim().isNotEmpty) ...[
            const SizedBox(height: AppDesignTokens.space4),
            Text(
              widget.role,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: AppDesignTokens.space12),
          _LabeledText(label: '当前状态', value: _currentState),
          const SizedBox(height: AppDesignTokens.space8),
          _LabeledText(label: '最近变化', value: _recentChange),
          if (widget.showEditor) ...[
            const SizedBox(height: AppDesignTokens.space12),
            TextField(
              key: CharacterStateCard.stateFieldKey,
              controller: _stateController,
              minLines: 1,
              maxLines: widget.compact ? 2 : 3,
              decoration: const InputDecoration(
                labelText: '更新当前状态',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDesignTokens.space8),
            TextField(
              key: CharacterStateCard.changeFieldKey,
              controller: _changeController,
              minLines: 1,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '记录变化',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDesignTokens.space8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: CharacterStateCard.saveButtonKey,
                onPressed: _submitUpdate,
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('保存状态'),
              ),
            ),
          ],
          const SizedBox(height: AppDesignTokens.space8),
          ExpansionTile(
            key: CharacterStateCard.historyTileKey,
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: widget.historyInitiallyExpanded,
            title: Text('状态历史', style: theme.textTheme.titleSmall),
            childrenPadding: EdgeInsets.zero,
            children: [
              if (_history.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('暂无状态历史', style: theme.textTheme.bodySmall),
                )
              else
                for (final entry in _history) _HistoryEntryView(entry: entry),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: desktopPalette(context).subtle,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        border: Border.all(
          color: widget.noticeAccent ?? desktopPalette(context).borderStrong,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.noticeTitle!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppDesignTokens.space8),
          Text(
            widget.noticeMessage!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _submitUpdate() {
    final nextState = _stateController.text.trim();
    if (nextState.isEmpty) {
      return;
    }
    final nextChange = _changeController.text.trim().isEmpty
        ? '手动更新'
        : _changeController.text.trim();
    final nextEntry = CharacterStateHistoryEntry(
      state: nextState,
      change: nextChange,
      recordedAtLabel: '刚刚',
    );
    final nextHistory = [
      nextEntry,
      ..._history,
    ].take(8).toList(growable: false);
    setState(() {
      _currentState = nextState;
      _recentChange = nextChange;
      _history = nextHistory;
      _changeController.clear();
    });
    widget.onStateSubmitted?.call(
      CharacterStateUpdate(
        currentState: nextState,
        recentChange: nextChange,
        history: List<CharacterStateHistoryEntry>.unmodifiable(nextHistory),
      ),
    );
  }
}

class _LabeledText extends StatelessWidget {
  const _LabeledText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: appPanelDecoration(context, color: palette.subtle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.secondaryText,
            ),
          ),
          const SizedBox(height: AppDesignTokens.space4),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HistoryEntryView extends StatelessWidget {
  const _HistoryEntryView({required this.entry});

  final CharacterStateHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignTokens.space8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDesignTokens.space12),
        decoration: BoxDecoration(
          color: palette.subtle,
          borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.state, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppDesignTokens.space4),
            Text(entry.change, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppDesignTokens.space4),
            Text(
              entry.recordedAtLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
