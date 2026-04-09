import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/statistics/domain/statistics_models.dart';
import '../../../features/statistics/data/statistics_service.dart';

/// 写作目标组件
class WritingGoalsWidget extends StatefulWidget {
  final String workId;

  const WritingGoalsWidget({
    super.key,
    required this.workId,
  });

  @override
  State<WritingGoalsWidget> createState() => _WritingGoalsWidgetState();
}

class _WritingGoalsWidgetState extends State<WritingGoalsWidget> {
  List<WritingGoal> _goals = [];
  bool _isLoading = true;
  GoalType? _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  final _targetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    setState(() => _isLoading = true);
    try {
      final service = Get.find<StatisticsService>();
      final goals = await service.getWritingGoals(widget.workId);
      if (mounted) {
        setState(() {
          _goals = goals;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.statistics_writingGoals,
                style: theme.textTheme.titleMedium,
              ),
              ElevatedButton.icon(
                onPressed: _showAddGoalDialog,
                icon: Icon(Icons.add),
                label: Text(s.statistics_addGoal),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          if (_goals.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 64.sp, color: Colors.grey[400]),
                  SizedBox(height: 16.h),
                  Text(
                    s.statistics_noGoalsSet,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton.icon(
                    onPressed: _showAddGoalDialog,
                    icon: Icon(Icons.add),
                    label: Text(s.statistics_addFirstGoal),
                  ),
                ],
              ),
            )
          else
            ..._goals.map((goal) => _GoalCard(
                  goal: goal,
                  onDelete: () => _deleteGoal(goal.id),
                  onEdit: () => _editGoal(goal),
                )),
        ],
      ),
    );
  }

  void _showAddGoalDialog() {
    final s = S.of(context)!;
    _selectedType = null;
    _startDate = DateTime.now();
    _endDate = null;
    _targetController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24.w,
              24.h,
              24.w,
              MediaQuery.of(context).viewInsets.bottom + 24.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.statistics_addWritingGoal,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 24.h),

                // 目标类型
                DropdownButtonFormField<GoalType>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    labelText: s.statistics_goalType,
                    border: OutlineInputBorder(),
                  ),
                  items: GoalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setModalState(() => _selectedType = value);
                  },
                ),
                SizedBox(height: 16.h),

                // 目标值
                TextField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: '目标值（字数）',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16.h),

                // 日期范围
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setModalState(() => _startDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: s.statistics_startDate,
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_formatDate(_startDate ?? DateTime.now())),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setModalState(() => _endDate = date);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: s.statistics_endDate,
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_endDate != null ? _formatDate(_endDate!) : s.statistics_selectDate),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // 按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s.cancel),
                    ),
                    SizedBox(width: 16.w),
                    ElevatedButton(
                      onPressed: _saveGoal,
                      child: Text(s.save),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveGoal() async {
    final s = S.of(context)!;
    if (_selectedType == null || _targetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.statistics_pleaseFillCompleteInfo)),
      );
      return;
    }

    final goal = WritingGoal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workId: widget.workId,
      type: _selectedType!,
      targetValue: int.parse(_targetController.text),
      currentValue: 0,
      startDate: _startDate ?? DateTime.now(),
      endDate: _endDate,
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _goals = [..._goals, goal];
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.statistics_goalSaved)),
    );
  }

  void _editGoal(WritingGoal goal) {
    final s = S.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.statistics_editInDevelopment)),
    );
  }

  void _deleteGoal(String goalId) {
    final s = S.of(context)!;
    setState(() {
      _goals = _goals.where((g) => g.id != goalId).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.statistics_goalDeleted)),
    );
  }
}

/// 目标卡片
class _GoalCard extends StatelessWidget {
  final WritingGoal goal;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _GoalCard({
    required this.goal,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = goal.targetValue > 0
        ? (goal.currentValue / goal.targetValue).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_getGoalIcon(goal.type), size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      goal.type.label,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, size: 20.sp),
                      onPressed: onEdit,
                      tooltip: '编辑',
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, size: 20.sp),
                      onPressed: onDelete,
                      tooltip: '删除',
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12.h),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              borderRadius: BorderRadius.circular(4.r),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${goal.currentValue} / ${goal.targetValue} 字',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getGoalIcon(GoalType type) {
    return switch (type) {
      GoalType.dailyWords => Icons.today,
      GoalType.weeklyWords => Icons.date_range,
      GoalType.monthlyWords => Icons.calendar_month,
      GoalType.totalWords => Icons.summarize,
      GoalType.chapterCount => Icons.book,
      GoalType.completionRate => Icons.percent,
    };
  }
}
