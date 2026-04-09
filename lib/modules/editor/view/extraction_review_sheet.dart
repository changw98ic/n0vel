import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../core/services/extraction_service.dart';

/// 提取结果审查底部弹窗
class ExtractionReviewSheet extends StatefulWidget {
  final List<NewEntityCandidate> candidates;
  final String workId;
  final VoidCallback onDone;

  const ExtractionReviewSheet({
    super.key,
    required this.candidates,
    required this.workId,
    required this.onDone,
  });

  /// 显示审查弹窗
  static Future<void> show({
    required List<NewEntityCandidate> candidates,
    required String workId,
    required VoidCallback onDone,
  }) {
    return Get.bottomSheet(
      ExtractionReviewSheet(
        candidates: candidates,
        workId: workId,
        onDone: onDone,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<ExtractionReviewSheet> createState() => _ExtractionReviewSheetState();
}

class _ExtractionReviewSheetState extends State<ExtractionReviewSheet> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 只显示新实体
    final newCandidates =
        widget.candidates.where((c) => c.isNew).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: 0.7.sh),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: colorScheme.primary, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '发现 ${newCandidates.length} 个新实体',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    for (final c in newCandidates) {
                      c.accepted = true;
                    }
                    setState(() {});
                  },
                  child: const Text('全选'),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),

          // Entity list
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              itemCount: newCandidates.length,
              itemBuilder: (context, index) {
                final candidate = newCandidates[index];
                return _EntityTile(
                  candidate: candidate,
                  onChanged: () => setState(() {}),
                );
              },
            ),
          ),

          // Save button
          Padding(
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveEntities,
                child: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : Text(_getButtonText(newCandidates)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getButtonText(List<NewEntityCandidate> candidates) {
    final accepted = candidates.where((c) => c.accepted).length;
    if (accepted == 0) return '跳过';
    return '接受 $accepted 个实体';
  }

  Future<void> _saveEntities() async {
    setState(() => _isSaving = true);
    try {
      final extractionService = Get.find<ExtractionService>();
      final saved = await extractionService.saveAcceptedEntities(
        widget.candidates,
        widget.workId,
      );
      if (mounted) {
        Get.back();
        if (saved > 0) {
          Get.snackbar('完成', '已保存 $saved 个实体', snackPosition: SnackPosition.BOTTOM);
        }
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('保存失败', e.toString(), snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Entity tile
// ---------------------------------------------------------------------------

class _EntityTile extends StatelessWidget {
  final NewEntityCandidate candidate;
  final VoidCallback onChanged;

  const _EntityTile({
    required this.candidate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final entity = candidate.entity;

    final (icon, label, color) = switch (entity.type) {
      'character' =>
        (Icons.person_outline_rounded, '角色', colorScheme.primary),
      'location' =>
        (Icons.place_outlined, '地点', colorScheme.tertiary),
      'item' =>
        (Icons.inventory_2_outlined, '物品', colorScheme.secondary),
      _ => (Icons.label_outline_rounded, entity.type, colorScheme.onSurfaceVariant),
    };

    return CheckboxListTile(
      value: candidate.accepted,
      onChanged: (val) {
        candidate.accepted = val ?? false;
        onChanged();
      },
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.sp, color: color),
            SizedBox(width: 2.w),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
      title: Text(
        entity.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: entity.description.isNotEmpty
          ? Text(
              entity.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}
