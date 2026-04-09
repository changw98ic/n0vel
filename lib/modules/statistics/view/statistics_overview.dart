import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/statistics/domain/statistics_models.dart';

/// 统计概览组件
class StatisticsOverview extends StatelessWidget {
  final WorkStatistics stats;

  const StatisticsOverview({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 核心指标
        Text(
          s.statistics_coreMetrics,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: s.statistics_totalWords,
                value: _formatNumber(stats.totalWords),
                subtitle: '${s.statistics_publishedChapters(stats.publishedChapters)} ${_formatNumber(stats.publishedWords)} ${s.statistics_characters}',
                icon: Icons.text_fields,
                color: theme.colorScheme.primary,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _MetricCard(
                title: s.statistics_chapterCount,
                value: '${stats.totalChapters}',
                subtitle: '${s.statistics_completedChapters} ${stats.publishedChapters} ${s.statistics_chapters}',
                icon: Icons.book,
                color: Colors.green,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: s.statistics_dailyAverageWords,
                value: _formatNumber(stats.dailyAverageWords),
                subtitle: s.statistics_writingDays(stats.writingDays),
                icon: Icons.today,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: _MetricCard(
                title: s.statistics_completionRate,
                value: '${(stats.completionRate * 100).toStringAsFixed(1)}%',
                subtitle: stats.estimatedCompletionDate != null
                    ? s.statistics_estimatedDate(_formatDate(stats.estimatedCompletionDate!))
                    : s.statistics_noGoalSet,
                icon: Icons.flag,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),

        // 章节统计
        Text(
          s.statistics_chapterStatistics,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(height: 16.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                _StatRow(
                  label: s.statistics_maxChapterWords,
                  value: '${stats.maxChapterWords}${s.statistics_characters}',
                ),
                const Divider(),
                _StatRow(
                  label: s.statistics_minChapterWords,
                  value: '${stats.minChapterWords}${s.statistics_characters}',
                ),
                const Divider(),
                _StatRow(
                  label: s.statistics_averageChapterWords,
                  value: '${stats.averageChapterWords.toStringAsFixed(0)}${s.statistics_characters}',
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24.h),

        // 角色统计
        Text(
          s.statistics_characterStatistics,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(height: 16.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CharacterStat(
                  label: s.statistics_protagonist,
                  count: stats.protagonistCount,
                  color: Colors.amber,
                ),
                _CharacterStat(
                  label: s.statistics_supportingCharacter,
                  count: stats.supportingCount,
                  color: Colors.blue,
                ),
                _CharacterStat(
                  label: s.statistics_minorCharacter,
                  count: stats.minorCount,
                  color: Colors.grey,
                ),
                _CharacterStat(
                  label: s.statistics_total,
                  count: stats.totalCharacters,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    }
    return number.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}

/// 指标卡片
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统计行
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// 角色统计
class _CharacterStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CharacterStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
