import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';

class StatisticsPanel extends StatefulWidget {
  final String content;

  const StatisticsPanel({super.key, required this.content});

  @override
  State<StatisticsPanel> createState() => _StatisticsPanelState();
}

class _StatisticsPanelState extends State<StatisticsPanel> {
  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 草稿速览 ──
          Text('草稿速览', style: theme.textTheme.titleSmall),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _MiniStat(label: '字数', value: '${stats.wordCount}', icon: Icons.text_fields_rounded),
              _MiniStat(label: '段落', value: '${stats.paragraphCount}', icon: Icons.view_day_rounded),
              _MiniStat(label: '对话块', value: '${stats.dialogueCount}', icon: Icons.chat_bubble_outline_rounded),
              _MiniStat(label: '标点', value: '${stats.punctuation}', icon: Icons.more_horiz_rounded),
            ],
          ),
          SizedBox(height: 10.h),
          // ── 结构平衡 ──
          Text('结构平衡', style: theme.textTheme.titleSmall),
          SizedBox(height: 4.h),
          _ProgressBand(
            label: '对话 ${(stats.dialogueRatio * 100).toStringAsFixed(0)}%',
            value: stats.dialogueRatio,
            color: theme.colorScheme.secondary,
          ),
          SizedBox(height: 4.h),
          _ProgressBand(
            label: '叙述 ${(stats.narrationRatio * 100).toStringAsFixed(0)}%',
            value: stats.narrationRatio,
            color: theme.colorScheme.primary,
          ),
          SizedBox(height: 10.h),
          // ── 语言构成 ──
          Text('语言构成', style: theme.textTheme.titleSmall),
          SizedBox(height: 4.h),
          _FactRow(label: '中文字符', value: '${stats.chineseChars}'),
          _FactRow(label: '英文单词', value: '${stats.englishWords}'),
          _FactRow(label: '预计阅读', value: '${stats.estimatedReadingTime} 分钟'),
        ],
      ),
    );
  }

  _StatsData _calculateStats() {
    final content = widget.content;
    if (content.isEmpty) {
      return _StatsData(
        wordCount: 0,
        chineseChars: 0,
        englishWords: 0,
        punctuation: 0,
        paragraphCount: 0,
        dialogueCount: 0,
        avgParagraphLength: 0,
        dialogueRatio: 0,
        narrationRatio: 0,
        estimatedReadingTime: 0,
      );
    }

    final chineseChars = RegExp(r'[\u4e00-\u9fff]').allMatches(content).length;
    final englishWords = RegExp(r'[a-zA-Z]+').allMatches(content).length;
    final punctuation = RegExp(
      r'[,.;:!?，。！？、；：""'
      '（）()《》【】]',
    ).allMatches(content).length;
    final wordCount = chineseChars + englishWords;

    final paragraphs = content
        .split(RegExp(r'\n+'))
        .where((segment) => segment.trim().isNotEmpty)
        .toList();
    final paragraphCount = paragraphs.length;
    final avgParagraphLength = paragraphCount > 0
        ? (wordCount / paragraphCount).round()
        : 0;

    final dialogueMatches = RegExp(r'["""].*?["""]|「.*?」').allMatches(content);
    final dialogueCount = dialogueMatches.length;
    var dialogueWordCount = 0;
    for (final match in dialogueMatches) {
      final value = match.group(0) ?? '';
      dialogueWordCount += RegExp(
        r'[\u4e00-\u9fff]|[a-zA-Z]+',
      ).allMatches(value).length;
    }

    final dialogueRatio = wordCount > 0 ? dialogueWordCount / wordCount : 0.0;
    final narrationRatio = 1.0 - dialogueRatio;
    final estimatedReadingTime = (wordCount / 300).ceil();

    return _StatsData(
      wordCount: wordCount,
      chineseChars: chineseChars,
      englishWords: englishWords,
      punctuation: punctuation,
      paragraphCount: paragraphCount,
      dialogueCount: dialogueCount,
      avgParagraphLength: avgParagraphLength,
      dialogueRatio: dialogueRatio,
      narrationRatio: narrationRatio,
      estimatedReadingTime: estimatedReadingTime,
    );
  }
}

class _StatsData {
  final int wordCount;
  final int chineseChars;
  final int englishWords;
  final int punctuation;
  final int paragraphCount;
  final int dialogueCount;
  final int avgParagraphLength;
  final double dialogueRatio;
  final double narrationRatio;
  final int estimatedReadingTime;

  _StatsData({
    required this.wordCount,
    required this.chineseChars,
    required this.englishWords,
    required this.punctuation,
    required this.paragraphCount,
    required this.dialogueCount,
    required this.avgParagraphLength,
    required this.dialogueRatio,
    required this.narrationRatio,
    required this.estimatedReadingTime,
  });
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: 4.w),
          Text(label, style: theme.textTheme.bodySmall),
          SizedBox(width: 4.w),
          Text(value, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ProgressBand extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ProgressBand({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(999.r),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10.h,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
