import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/material.dart';

import '../../../features/settings/domain/character.dart';

/// 角色卡片组件
class CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CharacterCard({
    super.key,
    required this.character,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // 头像
              _Avatar(character: character),
              SizedBox(width: 12.w),

              // 信息区
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称和生命状态
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            character.name,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (character.lifeStatus != LifeStatus.alive)
                          _LifeStatusBadge(status: character.lifeStatus),
                      ],
                    ),

                    // 别名
                    if (character.aliases.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        character.aliases.take(3).join(' / '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // 身份/简介
                    if (character.identity != null ||
                        character.bio != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        character.identity ?? character.bio ?? '',
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 箭头
              Icon(
                Icons.chevron_right,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 头像组件
class _Avatar extends StatelessWidget {
  final Character character;

  const _Avatar({required this.character});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 根据角色分级选择颜色
    final color = switch (character.tier) {
      CharacterTier.protagonist => Colors.amber,
      CharacterTier.majorAntagonist => Colors.red,
      CharacterTier.antagonist => Colors.orange,
      CharacterTier.supporting => Colors.blue,
      CharacterTier.minor => Colors.grey,
    };

    return Stack(
      children: [
        // 头像
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.2),
          backgroundImage: character.avatarPath != null
              ? NetworkImage(character.avatarPath!)
              : null,
          child: character.avatarPath == null
              ? Text(
                  character.name.isNotEmpty ? character.name[0] : '?',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                )
              : null,
        ),

        // 生命状态指示器
        if (character.lifeStatus != LifeStatus.alive)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: character.lifeStatus == LifeStatus.dead
                    ? Colors.red
                    : Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 2),
              ),
              child: Icon(
                character.lifeStatus == LifeStatus.dead
                    ? Icons.close
                    : Icons.help_outline,
                size: 12.sp,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// 生命状态徽章
class _LifeStatusBadge extends StatelessWidget {
  final LifeStatus status;

  const _LifeStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      LifeStatus.alive => (Colors.green, Icons.favorite),
      LifeStatus.dead => (Colors.red, Icons.close),
      LifeStatus.missing => (Colors.orange, Icons.help_outline),
      LifeStatus.unknown => (Colors.grey, Icons.question_mark),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 2.w),
          Text(
            status.label,
            style: TextStyle(fontSize: 10.sp, color: color),
          ),
        ],
      ),
    );
  }
}

/// 角色选择器组件
class CharacterSelector extends StatelessWidget {
  final List<Character> characters;
  final Set<String> selectedIds;
  final void Function(Set<String>) onSelectionChanged;
  final bool multiSelect;

  const CharacterSelector({
    super.key,
    required this.characters,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.multiSelect = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: characters.length,
      itemBuilder: (context, index) {
        final character = characters[index];
        final isSelected = selectedIds.contains(character.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (checked) {
            final newSelection = Set<String>.from(selectedIds);
            if (checked == true) {
              if (multiSelect) {
                newSelection.add(character.id);
              } else {
                newSelection.clear();
                newSelection.add(character.id);
              }
            } else {
              newSelection.remove(character.id);
            }
            onSelectionChanged(newSelection);
          },
          secondary: CircleAvatar(
            child: Text(character.name[0]),
          ),
          title: Text(character.name),
          subtitle: character.identity != null
              ? Text(character.identity!)
              : null,
        );
      },
    );
  }
}
