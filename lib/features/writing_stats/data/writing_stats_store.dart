import 'dart:async';

import 'package:novel_writer/app/events/app_domain_events.dart';
import 'package:novel_writer/app/events/app_event_bus.dart';
import 'package:novel_writer/app/state/app_project_scoped_store.dart';
import 'package:novel_writer/app/state/app_workspace_store.dart';
import 'package:novel_writer/app/state/persist_guard.dart';

import '../domain/writing_stats_models.dart';
import 'writing_stats_service.dart';
import 'writing_stats_storage.dart';

/// 写作统计 Store。
///
/// 监听 [DraftUpdatedEvent] 做增量更新，对外暴露当前项目/场景的统计快照。
/// 支持可配置的目标达成提醒（通过 [reminderEnabled] 控制）。
class WritingStatsStore extends AppProjectScopedStore {
  WritingStatsStore({
    WritingStatsStorage? storage,
    AppEventBus? eventBus,
    AppWorkspaceStore? workspaceStore,
    bool reminderEnabled = true,
  }) : _service = WritingStatsService(
         storage: storage ?? createDefaultWritingStatsStorage(),
       ),
       _eventBus = eventBus,
       _reminderEnabled = reminderEnabled,
       super(
         workspaceStore: workspaceStore,
         eventBus: eventBus,
         scopeMode: AppStoreScopeMode.project,
       ) {
    _draftSubscription = eventBus?.listen<DraftUpdatedEvent>(_onDraftUpdated);
    _projectDeletedSubscription = eventBus?.listen<ProjectDeletedEvent>(
      _onProjectDeleted,
    );
    onRestore();
  }

  final WritingStatsService _service;
  final AppEventBus? _eventBus;
  StreamSubscription<DraftUpdatedEvent>? _draftSubscription;
  StreamSubscription<ProjectDeletedEvent>? _projectDeletedSubscription;

  WritingStatsSnapshot _snapshot = WritingStatsSnapshot.empty;
  List<WritingGoal> _goals = [];
  bool _reminderEnabled;

  /// 已通知过的目标 key 集合（避免重复提醒）。
  /// 格式: "goalId:date"  每天重置。
  final Set<String> _notifiedGoalKeys = {};
  String _lastNotifyDate = '';

  /// 当前统计快照。
  WritingStatsSnapshot get snapshot => _snapshot;

  /// 当前写作目标列表。
  List<WritingGoal> get goals => List.unmodifiable(_goals);

  /// 目标达成提醒是否启用。
  bool get reminderEnabled => _reminderEnabled;

  // ── 目标管理 ──────────────────────────────────────────────────────────────

  /// 创建或更新一个写作目标。
  Future<void> saveGoal(WritingGoal goal) async {
    await _service.saveGoal(goal);
    await _reloadGoals();
    notifyListeners();
  }

  /// 删除一个写作目标。
  Future<void> deleteGoal(String goalId) async {
    await _service.deleteGoal(goalId);
    _notifiedGoalKeys.removeWhere((k) => k.startsWith('$goalId:'));
    await _reloadGoals();
    notifyListeners();
  }

  /// 切换目标启用/禁用。
  Future<void> toggleGoal(String goalId) async {
    final goal = _goals.firstWhere(
      (g) => g.id == goalId,
      orElse: () => WritingGoal(
        id: '',
        projectId: '',
        goalType: WritingGoalType.dailyChars,
        targetValue: 0,
        period: WritingGoalPeriod.daily,
        enabled: false,
        createdAtMs: 0,
      ),
    );
    if (goal.id.isEmpty) return;
    await _service.saveGoal(goal.copyWith(enabled: !goal.enabled));
    await _reloadGoals();
    notifyListeners();
  }

  /// 设置提醒开关。
  set reminderEnabled(bool value) {
    _reminderEnabled = value;
    if (!value) _notifiedGoalKeys.clear();
    notifyListeners();
  }

  // ── 查询 ─────────────────────────────────────────────────────────────────

  /// 加载指定日期范围的日级统计（供趋势图使用）。
  Future<List<WritingDailyStat>> loadDailyStats({
    String? fromDate,
    String? toDate,
  }) async {
    return _service.loadDailyStats(
      projectId: activeProjectId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  // ── 事件处理 ──────────────────────────────────────────────────────────────

  void _onDraftUpdated(DraftUpdatedEvent event) {
    if (event.projectId != activeProjectId) return;
    unawaited(
      safePersist(
        () => _service.handleDraftUpdated(event),
        eventBus: _eventBus,
      ),
    );
    unawaited(_refreshSnapshot());
  }

  void _onProjectDeleted(ProjectDeletedEvent event) {
    unawaited(_service.clearProject(event.projectId));
  }

  Future<void> _refreshSnapshot() async {
    _snapshot = await _service.loadSnapshot(projectId: activeProjectId);
    _goals = _snapshot.goals;
    _checkGoalReminders();
    notifyListeners();
  }

  Future<void> _reloadGoals() async {
    _goals = await _service.loadGoals(projectId: activeProjectId);
    _snapshot = WritingStatsSnapshot(
      dailyStats: _snapshot.dailyStats,
      projectStat: _snapshot.projectStat,
      goals: _goals,
      todayCharCount: _snapshot.todayCharCount,
      todayDeltaChars: _snapshot.todayDeltaChars,
      weekCharCount: _snapshot.weekCharCount,
    );
  }

  /// 检查目标达成情况，发送提醒通知。
  void _checkGoalReminders() {
    if (!_reminderEnabled) return;

    final today = _todayString();
    // 每天重置已通知集合
    if (today != _lastNotifyDate) {
      _notifiedGoalKeys.clear();
      _lastNotifyDate = today;
    }

    for (final goal in _goals) {
      if (!goal.enabled) continue;
      final key = '${goal.id}:$today';
      if (_notifiedGoalKeys.contains(key)) continue;

      final progress = _snapshot.goalProgress(goal);
      if (progress >= 1.0) {
        _notifiedGoalKeys.add(key);
        _publishGoalReached(goal, progress);
      }
    }
  }

  void _publishGoalReached(WritingGoal goal, double progress) {
    final label = switch (goal.goalType) {
      WritingGoalType.dailyChars => '每日${goal.targetValue}字',
      WritingGoalType.weeklyChars => '每周${goal.targetValue}字',
      WritingGoalType.projectTotalChars => '项目${goal.targetValue}字',
      WritingGoalType.dailyChapters => '每日${goal.targetValue}章',
    };
    try {
      _eventBus?.publish(NotificationRequestedEvent(
        title: '写作目标达成!',
        message: '$label — 已完成 ${(progress * 100).toInt()}%',
        severity: AppNoticeSeverity.success,
        duration: const Duration(seconds: 6),
      ));
    } on StateError {
      // eventBus 可能已 disposed
    }
  }

  // ── AppProjectScopedStore 实现 ────────────────────────────────────────────

  @override
  void onProjectScopeChanged(String previousProjectId, String nextProjectId) {
    _snapshot = WritingStatsSnapshot.empty;
    _goals = [];
    _notifiedGoalKeys.clear();
  }

  @override
  Future<void> onRestore() async {
    final restoreVersion = mutationVersion;
    final snapshot = await _service.loadSnapshot(
      projectId: activeProjectId,
    );
    if (restoreVersion != mutationVersion) return;
    _snapshot = snapshot;
    _goals = snapshot.goals;
    _checkGoalReminders();
    notifyListeners();
  }

  @override
  Future<void> clearDeletedProjectScope(String projectId) =>
      _service.clearProject(projectId);

  @override
  void dispose() {
    unawaited(_draftSubscription?.cancel());
    unawaited(_projectDeletedSubscription?.cancel());
    _draftSubscription = null;
    _projectDeletedSubscription = null;
    super.dispose();
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
