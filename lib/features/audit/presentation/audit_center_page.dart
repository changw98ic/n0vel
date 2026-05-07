import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_shell.dart';

enum AuditCenterUiState {
  ready,
  empty,
  filterNoResults,
  relatedDraftMissing,
  jumpFailed,
}

class AuditCenterPage extends StatefulWidget {
  const AuditCenterPage({super.key, this.uiState = AuditCenterUiState.ready});

  static const markResolvedKey = ValueKey<String>('audit-center-mark-resolved');
  static const ignoreIssueKey = ValueKey<String>('audit-center-ignore-issue');
  static const warehouseIssueKey = ValueKey<String>(
    'audit-center-warehouse-issue',
  );
  static const ignoreReasonFieldKey = ValueKey<String>(
    'audit-center-ignore-reason',
  );

  final AuditCenterUiState uiState;

  @override
  State<AuditCenterPage> createState() => _AuditCenterPageState();
}

class _AuditCenterPageState extends State<AuditCenterPage> {
  bool _isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppWorkspaceScope.of(context);
    final issues = store.filteredAuditIssues;
    final selectedIssueId = issues.isEmpty ? '' : store.selectedAuditIssue.id;
    final currentIssue =
        issues.where((issue) => issue.id == selectedIssueId).isNotEmpty
        ? issues.firstWhere((issue) => issue.id == selectedIssueId)
        : (issues.isEmpty ? null : issues.first);
    final body = Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopMenuDrawerRegion(
                isOpen: _isDrawerOpen,
                onHandleTap: () {
                  setState(() {
                    _isDrawerOpen = !_isDrawerOpen;
                  });
                },
                items: _menuItems(context),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 260,
                child: Container(
                  decoration: appPanelDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: _buildIssueList(
                    theme,
                    store,
                    issues,
                    store.selectedAuditIssueIndex,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: appPanelDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: _buildEvidence(theme, currentIssue),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 280,
                child: Container(
                  decoration: appPanelDecoration(context),
                  padding: const EdgeInsets.all(16),
                  child: _buildActions(theme, store, currentIssue),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AuditSummaryStrip(issue: currentIssue, issueCount: issues.length),
      ],
    );
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: '改稿 · 一致性检查',
        subtitle: '需要作者核对的线索与依据',
        showBackButton: true,
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in AuditIssueFilter.values)
                ChoiceChip(
                  label: Text(_filterLabel(filter)),
                  selected: store.auditIssueFilter == filter,
                  onSelected: (_) => store.setAuditFilter(filter),
                ),
            ],
          ),
        ],
      ),
      body: body,
      statusBar: DesktopStatusStrip(
        leftText: '改稿 · 核对线索已更新',
        rightText: currentIssue?.target ?? '场景 05',
      ),
    );
  }

  Widget _buildIssueList(
    ThemeData theme,
    AppWorkspaceStore store,
    List<AuditIssueRecord> issues,
    int selectedIndex,
  ) {
    if (widget.uiState == AuditCenterUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('问题列表', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('当前项目暂无问题', style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (_showFilterNoResults(issues)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('问题列表', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('0 个匹配', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          const _InfoBlock(
            title: '当前筛选没有命中问题',
            message: '试试放宽筛选条件，或切换到问题列表查看全部结果。',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => store.setAuditFilter(AuditIssueFilter.all),
              child: const Text('清空筛选'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('问题列表', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _InfoBlock(
          title: '当前筛选',
          message:
              '${_filterLabel(store.auditIssueFilter)} · 共 ${issues.length} 个问题\n待处理 ${_countByStatus(store, AuditIssueStatus.open)} · 已处理 ${_countByStatus(store, AuditIssueStatus.resolved)} · 已忽略 ${_countByStatus(store, AuditIssueStatus.ignored)}',
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < issues.length; index++) ...[
          _ListButton(
            buttonKey: issues[index].title == '误把仓库当一层'
                ? AuditCenterPage.warehouseIssueKey
                : null,
            label:
                '${issues[index].title} · ${_statusLabel(issues[index].status)}',
            selected: store.selectedAuditIssue.id == issues[index].id,
            onPressed: () => store.selectAuditIssueById(issues[index].id),
          ),
          if (index < issues.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildEvidence(ThemeData theme, AuditIssueRecord? currentIssue) {
    if (widget.uiState == AuditCenterUiState.empty) {
      return const _CallToActionState(
        title: '暂无一致性问题',
        message: '当前作品没有发现角色、规则、道具或时间线冲突。',
      );
    }
    if (_showFilterNoResults(const <AuditIssueRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('证据详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Expanded(
            child: _CenteredPanelState(
              title: '未选中问题',
              message: '当前筛选没有结果，因此这里不展示证据详情。',
            ),
          ),
        ],
      );
    }
    if (widget.uiState == AuditCenterUiState.relatedDraftMissing) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('证据详情', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _InfoBlock(title: '问题摘要', message: currentIssue?.title ?? '角色称谓冲突'),
            const SizedBox(height: 8),
            const _InfoBlock(
              title: '无法定位关联草稿',
              message: '原始场景草稿已被删除或位置失效，因此这里暂时无法展示对应文本片段。',
            ),
            const SizedBox(height: 8),
            const _InfoBlock(
              title: '建议动作',
              message: '可返回工作台检查当前章节正文，或重新检查以刷新最新依据。',
            ),
          ],
        ),
      );
    }
    if (widget.uiState == AuditCenterUiState.jumpFailed) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('证据详情', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _InfoBlock(title: '问题摘要', message: currentIssue?.title ?? '时间线冲突'),
            const SizedBox(height: 8),
            const _InfoBlock(
              title: '跳转失败',
              message: '目标场景 `Scene 05` 已被删除、重命名，或当前索引已失效，因此无法从一致性检查直接跳回原位置。',
            ),
            const SizedBox(height: 8),
            const _InfoBlock(
              title: '建议动作',
              message: '可返回工作台手动定位当前章节，或重新检查以刷新最新场景位置。',
            ),
          ],
        ),
      );
    }
    if (currentIssue == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('证据详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Expanded(
            child: _CenteredPanelState(title: '暂无证据详情', message: '请先选择一个问题项。'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('证据详情', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        _InfoBlock(title: '证据详情', message: currentIssue.evidence),
        const SizedBox(height: 8),
        _InfoRow(label: '引用目标', value: currentIssue.target),
      ],
    );
  }

  Widget _buildActions(
    ThemeData theme,
    AppWorkspaceStore store,
    AuditIssueRecord? currentIssue,
  ) {
    if (widget.uiState == AuditCenterUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理动作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(
            title: '处理动作',
            message: '当前无需处理。后续完成一致性检查后，需要核对的线索会出现在这里。',
          ),
        ],
      );
    }
    if (_showFilterNoResults(const <AuditIssueRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理动作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(
            title: '无可用动作',
            message: '当前没有命中的问题，因此这里不显示跳转、处理或忽略操作。',
          ),
        ],
      );
    }
    if (widget.uiState == AuditCenterUiState.relatedDraftMissing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理动作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                AppNavigator.push(context, AppRoutes.workbench);
              },
              child: const Text('返回工作台'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: () {}, child: const Text('重新检查')),
          ),
          const SizedBox(height: 8),
          const _InfoBlock(title: '当前限制', message: '由于关联草稿不存在，当前无法直接跳转到原证据位置。'),
        ],
      );
    }
    if (widget.uiState == AuditCenterUiState.jumpFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理动作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                AppNavigator.push(context, AppRoutes.workbench);
              },
              child: const Text('返回工作台'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: () {}, child: const Text('重新检查')),
          ),
          const SizedBox(height: 8),
          const _InfoBlock(title: '当前限制', message: '当前无法直接跳转到原证据位置。'),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store.auditActionFeedback.isEmpty ? '处理动作' : '处理结果',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: currentIssue == null
                    ? null
                    : () {
                        store.jumpToSelectedAuditScene();
                        AppNavigator.push(context, AppRoutes.workbench);
                      },
                child: const Text('跳转到场景'),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: currentIssue == null
                  ? null
                  : ValueKey<String>(
                      '${AuditCenterPage.ignoreReasonFieldKey.value}-${currentIssue.id}',
                    ),
              initialValue: currentIssue?.ignoreReason ?? '',
              onChanged: currentIssue == null
                  ? null
                  : store.updateSelectedAuditIgnoreReason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '忽略原因',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: AuditCenterPage.markResolvedKey,
                onPressed: currentIssue == null
                    ? null
                    : AppWorkspaceScope.of(
                        context,
                      ).markSelectedAuditIssueResolved,
                child: const Text('标记已处理'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: AuditCenterPage.ignoreIssueKey,
                onPressed: currentIssue == null
                    ? null
                    : AppWorkspaceScope.of(context).ignoreSelectedAuditIssue,
                child: const Text('忽略'),
              ),
            ),
            const SizedBox(height: 12),
            _InfoBlock(title: '处理反馈', message: store.auditActionFeedback),
            if (currentIssue != null) ...[
              const SizedBox(height: 8),
              _InfoBlock(
                title: '当前状态',
                message:
                    '${_statusLabel(currentIssue.status)} · ${currentIssue.lastAction}',
              ),
            ],
          ],
        ],
      ),
    );
  }

  bool _showFilterNoResults(List<AuditIssueRecord> issues) {
    if (widget.uiState == AuditCenterUiState.filterNoResults) {
      return true;
    }
    return issues.isEmpty && _selectedAuditIssueFilterIsActive();
  }

  bool _selectedAuditIssueFilterIsActive() {
    final store = AppWorkspaceScope.of(context);
    return store.auditIssueFilter != AuditIssueFilter.all;
  }

  int _countByStatus(AppWorkspaceStore store, AuditIssueStatus status) {
    var count = 0;
    for (final issue in store.auditIssues) {
      if (issue.status == status) {
        count++;
      }
    }
    return count;
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return buildDesktopWorkspaceMenuItems(
      selected: DesktopWorkspaceSection.audit,
      onShelf: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onWorkbench: () => AppNavigator.push(context, AppRoutes.workbench),
      onWorkSettings: () =>
          AppNavigator.push(context, AppRoutes.workSettingsHub),
      onRevision: () {
        setState(() {
          _isDrawerOpen = false;
        });
      },
      onReading: () => AppNavigator.push(context, AppRoutes.scenes),
      onSettings: () => AppNavigator.push(context, AppRoutes.settings),
    );
  }

  String _filterLabel(AuditIssueFilter filter) {
    return switch (filter) {
      AuditIssueFilter.all => '全部',
      AuditIssueFilter.open => '待处理',
      AuditIssueFilter.resolved => '已处理',
      AuditIssueFilter.ignored => '已忽略',
    };
  }

  String _statusLabel(AuditIssueStatus status) {
    return switch (status) {
      AuditIssueStatus.open => '待处理',
      AuditIssueStatus.resolved => '已处理',
      AuditIssueStatus.ignored => '已忽略',
    };
  }
}

class _ListButton extends StatelessWidget {
  const _ListButton({
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.message});

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

class _AuditSummaryStrip extends StatelessWidget {
  const _AuditSummaryStrip({required this.issue, required this.issueCount});

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

class _CallToActionState extends StatelessWidget {
  const _CallToActionState({required this.title, required this.message});

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

class _CenteredPanelState extends StatelessWidget {
  const _CenteredPanelState({required this.title, required this.message});

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
