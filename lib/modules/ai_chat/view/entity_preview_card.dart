import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../core/services/entity_creation_service.dart';
import '../../../features/work/data/work_repository.dart';

/// AI 实体创建预览卡片
/// 显示 AI 生成的实体设定，用户确认后保存
class EntityPreviewCard extends StatelessWidget {
  final EntityCreationResult entity;
  final String workId;
  final void Function(String? createdWorkId)? onSaved;

  const EntityPreviewCard({
    super.key,
    required this.entity,
    required this.workId,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, label, color) = _getTypeInfo(entity.type);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  entity.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Fields
          if (entity.fields.isNotEmpty) ...[
            SizedBox(height: 8.h),
            ...entity.fields.entries
                .where((e) =>
                    e.key != 'name' &&
                    e.value != null &&
                    e.value.toString().isNotEmpty)
                .map((entry) => _buildFieldRow(theme, colorScheme, entry)),
          ],

          // Actions
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('取消'),
                style: OutlinedButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
              SizedBox(width: 8.w),
              FilledButton.icon(
                onPressed: _saveEntity,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('确认创建'),
                style: FilledButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(
    ThemeData theme,
    ColorScheme colorScheme,
    MapEntry<String, dynamic> entry,
  ) {
    final label = _fieldLabel(entry.key);
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60.w,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.value.toString(),
              style: theme.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _getTypeInfo(EntityType type) {
    final colorScheme = Theme.of(Get.context!).colorScheme;
    return switch (type) {
      EntityType.character =>
        (Icons.person_rounded, '角色', colorScheme.primary),
      EntityType.location =>
        (Icons.place_rounded, '地点', colorScheme.tertiary),
      EntityType.item =>
        (Icons.inventory_2_rounded, '物品', colorScheme.secondary),
      EntityType.faction =>
        (Icons.groups_rounded, '势力', colorScheme.error),
    };
  }

  String? _fieldLabel(String key) {
    return switch (key) {
      'bio' || 'description' => '描述',
      'gender' => '性别',
      'age' => '年龄',
      'identity' => '身份',
      'tier' => '等级',
      'personality' => '性格',
      'environment' => '环境',
      'significance' => '重要性',
      'appearance' => '外观',
      'function' => '功能',
      'structure' => '结构',
      'goals' => '目标',
      'rationale' => null,
      _ => key,
    };
  }

  Future<void> _saveEntity() async {
    try {
      final service = Get.find<EntityCreationService>();
      var effectiveWorkId = workId;
      String? createdWorkId;

      // 如果没有 workId，自动创建一个新作品
      if (effectiveWorkId.isEmpty) {
        final workRepo = Get.find<WorkRepository>();
        final work = await workRepo.createWork(
          CreateWorkParams(
            name: entity.fields['work_name'] as String? ??
                '${entity.name}的世界',
          ),
        );
        effectiveWorkId = work.id;
        createdWorkId = work.id;
      }

      await service.saveEntity(entity, effectiveWorkId);
      Get.snackbar(
        '创建成功',
        '${entity.name} 已添加',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      onSaved?.call(createdWorkId);
    } catch (e) {
      Get.snackbar(
        '创建失败',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
