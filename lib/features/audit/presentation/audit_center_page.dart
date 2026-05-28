import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_scrollbar.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'audit_center_components.dart';

enum AuditCenterUiState {
  ready,
  empty,
  filterNoResults,
  relatedDraftMissing,
  jumpFailed,
}

class AuditCenterPage extends ConsumerStatefulWidget {
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
  ConsumerState<AuditCenterPage> createState() => _AuditCenterPageState();
}

class _AuditCenterPageState extends ConsumerState<AuditCenterPage> {
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _evidenceScrollController = ScrollController();
  final ScrollController _actionsScrollController = ScrollController();

  @override
  void dispose() {
    _listScrollController.dispose();
    _evidenceScrollController.dispose();
    _actionsScrollController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = ref.watch(appWorkspaceStoreProvider).auditFacade;
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
        AuditSummaryStrip(issue: currentIssue, issueCount: issues.length),
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
        rightText: currentIssue?.target ?? '第 3 章',
      ),
    );
  }

  Widget _buildIssueList(
    ThemeData theme,
    WorkspaceAuditFacade store,
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
          const AuditInfoBlock(
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
        AuditInfoBlock(
          title: '当前筛选',
          message:
              '${_filterLabel(store.auditIssueFilter)} · 共 ${issues.length} 个问题\n待处理 ${_countByStatus(store, AuditIssueStatus.open)} · 已处理 ${_countByStatus(store, AuditIssueStatus.resolved)} · 已忽略 ${_countByStatus(store, AuditIssueStatus.ignored)}',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AppPremiumScrollbar(
            controller: _listScrollController,
            child: SingleChildScrollView(
              controller: _listScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < issues.length; index++) ...[
                    AuditListButton(
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEvidence(ThemeData theme, AuditIssueRecord? currentIssue) {
    if (widget.uiState == AuditCenterUiState.empty) {
      return const AuditCallToActionState(
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
            child: AuditCenteredPanelState(
              title: '未选中问题',
              message: '当前筛选没有结果，因此这里不展示证据详情。',
            ),
          ),
        ],
      );
    }
    if (widget.uiState == AuditCenterUiState.relatedDraftMissing) {
      return AppPremiumScrollbar(
        controller: _evidenceScrollController,
        child: SingleChildScrollView(
          controller: _evidenceScrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('证据详情', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              AuditInfoBlock(
                title: '问题摘要',
                message: currentIssue?.title ?? '角色称谓冲突',
              ),
              const SizedBox(height: 8),
              const AuditInfoBlock(
                title: '无法定位关联草稿',
                message: '原始场景草稿已被删除或位置失效，因此这里暂时无法展示对应文本片段。',
              ),
              const SizedBox(height: 8),
              const AuditInfoBlock(
                title: '建议动作',
                message: '可返回工作台检查当前场景正文，或重新检查以刷新最新依据。',
              ),
            ],
          ),
        ),
      );
    }
    if (widget.uiState == AuditCenterUiState.jumpFailed) {
      return AppPremiumScrollbar(
        controller: _evidenceScrollController,
        child: SingleChildScrollView(
          controller: _evidenceScrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('证据详情', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              AuditInfoBlock(
                title: '问题摘要',
                message: currentIssue?.title ?? '时间线冲突',
              ),
              const SizedBox(height: 8),
              const AuditInfoBlock(
                title: '跳转失败',
                message: '目标场景已被删除、重命名，或当前索引已失效，因此无法从一致性检查直接跳回原位置。',
              ),
              const SizedBox(height: 8),
              const AuditInfoBlock(
                title: '建议动作',
                message: '可返回工作台手动定位当前场景，或重新检查以刷新最新场景位置。',
              ),
            ],
          ),
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
            child: AuditCenteredPanelState(
              title: '暂无证据详情',
              message: '请先选择一个问题项。',
            ),
          ),
        ],
      );
    }
    return AppPremiumScrollbar(
      controller: _evidenceScrollController,
      child: SingleChildScrollView(
        controller: _evidenceScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('证据详情', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            AuditInfoBlock(title: '证据详情', message: currentIssue.evidence),
            const SizedBox(height: 8),
            AuditInfoRow(label: '引用目标', value: currentIssue.target),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    ThemeData theme,
    WorkspaceAuditFacade store,
    AuditIssueRecord? currentIssue,
  ) {
    if (widget.uiState == AuditCenterUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('处理动作', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const AuditInfoBlock(
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
          const AuditInfoBlock(
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
          const AuditInfoBlock(
            title: '当前限制',
            message: '由于关联草稿不存在，当前无法直接跳转到原证据位置。',
          ),
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
          const AuditInfoBlock(title: '当前限制', message: '当前无法直接跳转到原证据位置。'),
        ],
      );
    }
    return AppPremiumScrollbar(
      controller: _actionsScrollController,
      child: SingleChildScrollView(
        controller: _actionsScrollController,
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
                      : store.markSelectedAuditIssueResolved,
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
                      : store.ignoreSelectedAuditIssue,
                  child: const Text('忽略'),
                ),
              ),
              const SizedBox(height: 12),
              AuditInfoBlock(title: '处理反馈', message: store.auditActionFeedback),
              if (currentIssue != null) ...[
                const SizedBox(height: 8),
                AuditInfoBlock(
                  title: '当前状态',
                  message:
                      '${_statusLabel(currentIssue.status)} · ${currentIssue.lastAction}',
                ),
              ],
            ],
          ],
        ),
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
    final store = ref.read(appWorkspaceStoreProvider).auditFacade;
    return store.auditIssueFilter != AuditIssueFilter.all;
  }

  int _countByStatus(WorkspaceAuditFacade store, AuditIssueStatus status) {
    var count = 0;
    for (final issue in store.auditIssues) {
      if (issue.status == status) {
        count++;
      }
    }
    return count;
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
