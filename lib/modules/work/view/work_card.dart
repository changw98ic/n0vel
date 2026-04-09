import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/theme.dart';
import '../../../app/widgets/app_shell.dart';
import '../../../features/work/domain/work.dart';

class WorkCard extends StatelessWidget {
  final Work work;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const WorkCard({
    super.key,
    required this.work,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCover = work.coverPath != null && work.coverPath!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── background ──
                if (hasCover)
                  Image.file(
                    File(work.coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _fallbackGradient(colorScheme),
                  )
                else
                  _fallbackGradient(colorScheme),

                // ── dark overlay ──
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.65),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // ── text overlay ──
                Padding(
                  padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // top: type badge + pin
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              _labelForType(work.type),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (work.isPinned)
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // title
                      Text(
                        work.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4.h),
                      // description
                      Text(
                        _descriptionText(s),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.3,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8.h),
                      // bottom: status + word count + date
                      Row(
                        children: [
                          AppTag(
                            label: _labelForStatus(s, work.status),
                            icon: _iconForStatus(work.status),
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            work.progressText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDate(s, work.updatedAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackGradient(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.6),
            colorScheme.tertiary.withValues(alpha: 0.5),
          ],
        ),
      ),
    );
  }

  IconData _iconForStatus(String value) {
    return switch (value) {
      'draft' => Icons.edit_note_rounded,
      'ongoing' => Icons.bolt_rounded,
      'completed' => Icons.check_circle_rounded,
      _ => Icons.label_rounded,
    };
  }

  String _descriptionText(S s) {
    final description = work.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }

    return switch (work.status) {
      'draft' => s.work_dartStatusDesc,
      'ongoing' => s.work_ongoingStatusDesc,
      'completed' => s.work_completedStatusDesc,
      _ => s.work_defaultStatusDesc,
    };
  }

  String _formatDate(S s, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      return s.work_today;
    }
    if (diff.inDays == 1) {
      return s.work_yesterday;
    }
    if (diff.inDays < 7) {
      return s.work_daysAgo('${diff.inDays}');
    }
    return '${date.month}/${date.day}';
  }

  String _labelForType(String? value) {
    if (value == null || value.isEmpty) {
      return WorkType.other.label;
    }

    return WorkType.values
        .firstWhere(
          (entry) => entry.name == value,
          orElse: () => WorkType.other,
        )
        .label;
  }

  String _labelForStatus(S s, String value) {
    return switch (value) {
      'draft' => s.work_draftStatus,
      'ongoing' => s.work_ongoingStatus,
      'completed' => s.work_completedStatus,
      _ => value,
    };
  }
}
