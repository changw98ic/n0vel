import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../core/database/database.dart';
import 'inspiration_logic.dart';

const Map<String, String> inspirationCategoryLabels = {
  'idea': '鐏垫劅',
  'reference': '鍙傝€冭祫鏂?',
  'character_sketch': '瑙掕壊鑽夌',
  'scene_fragment': '鍦烘櫙鐗囨',
  'worldbuilding': '涓栫晫璁惧畾',
  'dialogue_snippet': '瀵圭櫧鐗囨',
};

const List<String> inspirationCategories = [
  'idea',
  'reference',
  'character_sketch',
  'scene_fragment',
  'worldbuilding',
  'dialogue_snippet',
];

const Map<String, IconData> inspirationCategoryIcons = {
  'idea': Icons.lightbulb_outline_rounded,
  'reference': Icons.menu_book_outlined,
  'character_sketch': Icons.person_outline_rounded,
  'scene_fragment': Icons.movie_outlined,
  'worldbuilding': Icons.public_outlined,
  'dialogue_snippet': Icons.chat_bubble_outline_rounded,
};

List<String> decodeInspirationTags(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  final decoded = jsonDecode(raw);
  if (decoded is List) {
    return decoded.map((e) => e.toString()).toList();
  }
  return const [];
}

String formatInspirationDate(DateTime dt) {
  return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class InspirationSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String searchQuery;
  final VoidCallback onClear;

  const InspirationSearchField({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: '鎼滅储绱犳潗...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: searchQuery.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: onClear,
              ),
        isDense: true,
      ),
    );
  }
}

class InspirationCategoryChips extends StatelessWidget {
  final InspirationLogic controller;

  const InspirationCategoryChips({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SizedBox(
        height: 40.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            InspirationCategoryChip(
              label: '鍏ㄩ儴',
              selected: controller.state.selectedCategory.value == null,
              onTap: () => controller.setSelectedCategory(null),
            ),
            SizedBox(width: 8.w),
            ...inspirationCategories.map(
              (category) => Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: InspirationCategoryChip(
                  label: inspirationCategoryLabels[category] ?? category,
                  icon: inspirationCategoryIcons[category],
                  selected: controller.state.selectedCategory.value == category,
                  onTap: () => controller.setSelectedCategory(category),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InspirationCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;

  const InspirationCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surfaceContainerLow.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16.sp,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 6.w),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InspirationContentList extends StatelessWidget {
  final InspirationLogic controller;
  final VoidCallback onCreate;

  const InspirationContentList({
    super.key,
    required this.controller,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = controller.state.isLoading.value;
      final items = controller.state.inspirations;

      if (isLoading && items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (items.isEmpty) {
        return AppEmptyState(
          icon: Icons.lightbulb_outline_rounded,
          title: controller.state.searchQuery.value.isEmpty
              ? '杩樻病鏈夌礌鏉?'
              : '娌℃湁鍖归厤缁撴灉',
          description: controller.state.searchQuery.value.isEmpty
              ? '鐐瑰嚮涓嬫柟鎸夐挳鏂板缓绱犳潗'
              : '鎹釜鍏抽敭璇嶈瘯璇?',
          action: controller.state.searchQuery.value.isEmpty
              ? FilledButton.tonal(
                  onPressed: onCreate,
                  child: const Text('鏂板缓绱犳潗'),
                )
              : null,
        );
      }

      return RefreshIndicator(
        onRefresh: () => controller.loadData(),
        child: ListView.separated(
          padding: EdgeInsets.only(bottom: 80.h),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (context, index) => InspirationCard(
            item: items[index],
            onTap: () => showInspirationDetailDialog(context, controller, items[index]),
            onLongPress: () => showInspirationDeleteDialog(context, controller, items[index]),
          ),
        ),
      );
    });
  }
}

class InspirationCard extends StatelessWidget {
  final Inspiration item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const InspirationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tags = decodeInspirationTags(item.tags);
    final categoryLabel = inspirationCategoryLabels[item.category] ?? item.category;
    final categoryIcon =
        inspirationCategoryIcons[item.category] ?? Icons.article_outlined;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showInspirationDeleteDialog(context, Get.find<InspirationLogic>(), item),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colorScheme.error),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppTag(
                      label: categoryLabel,
                      icon: categoryIcon,
                      color: colorScheme.primary,
                    ),
                    if (item.priority > 0) ...[
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.priority_high_rounded,
                        size: 16.sp,
                        color: item.priority >= 2
                            ? colorScheme.error
                            : colorScheme.tertiary,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatInspirationDate(item.updatedAt ?? item.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.h),
                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                Text(
                  item.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tags.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: tags.map((tag) => AppTag(label: tag)).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showInspirationDetailDialog(
  BuildContext context,
  InspirationLogic controller,
  Inspiration item,
) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final tags = decodeInspirationTags(item.tags);
  final categoryLabel = inspirationCategoryLabels[item.category] ?? item.category;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(item.title, overflow: TextOverflow.ellipsis)),
          AppTag(label: categoryLabel),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(item.content, style: theme.textTheme.bodyLarge),
            if (item.source != null && item.source!.isNotEmpty) ...[
              SizedBox(height: 14.h),
              Text('鏉ユ簮', style: theme.textTheme.labelMedium),
              SizedBox(height: 4.h),
              SelectableText(item.source!, style: theme.textTheme.bodySmall),
            ],
            if (tags.isNotEmpty) ...[
              SizedBox(height: 14.h),
              Text('鏍囩', style: theme.textTheme.labelMedium),
              SizedBox(height: 6.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 4.h,
                children: tags.map((tag) => AppTag(label: tag)).toList(),
              ),
            ],
            SizedBox(height: 10.h),
            Text(
              '鏇存柊浜?${formatInspirationDate(item.updatedAt ?? item.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await controller.deleteInspiration(item.id);
            if (ctx.mounted) {
              Get.back();
            }
          },
          child: Text('鍒犻櫎', style: TextStyle(color: colorScheme.error)),
        ),
        FilledButton.tonal(
          onPressed: () => Get.back(),
          child: const Text('鍏抽棴'),
        ),
      ],
    ),
  );
}

Future<bool?> showInspirationDeleteDialog(
  BuildContext context,
  InspirationLogic controller,
  Inspiration item,
) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('纭鍒犻櫎'),
      content: Text('纭畾瑕佸垹闄ょ礌鏉愩€?${item.title}銆嬪悧锛熸鎿嶄綔涓嶅彲鎾ら攢銆?'),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('鍙栨秷'),
        ),
        FilledButton(
          onPressed: () async {
            await controller.deleteInspiration(item.id);
            if (ctx.mounted) {
              Get.back(result: true);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('鍒犻櫎'),
        ),
      ],
    ),
  );
}

void showInspirationCreateDialog(
  BuildContext context,
  InspirationLogic controller,
) {
  final titleCtl = TextEditingController();
  final contentCtl = TextEditingController();
  final tagsCtl = TextEditingController();
  final sourceCtl = TextEditingController();
  String selectedCategory = 'idea';

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('鏂板缓绱犳潗'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 480.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(
                    labelText: '鏍囬',
                    hintText: '杈撳叆绱犳潗鏍囬',
                    isDense: true,
                  ),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: contentCtl,
                  decoration: const InputDecoration(
                    labelText: '鍐呭',
                    hintText: '杈撳叆绱犳潗鍐呭',
                    alignLabelWithHint: true,
                    isDense: true,
                  ),
                  maxLines: 5,
                  minLines: 3,
                ),
                SizedBox(height: 14.h),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '鍒嗙被',
                    isDense: true,
                  ),
                  items: inspirationCategories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(inspirationCategoryLabels[cat] ?? cat),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: tagsCtl,
                  decoration: const InputDecoration(
                    labelText: '鏍囩',
                    hintText: '鐢ㄩ€楀彿鍒嗛殧澶氫釜鏍囩',
                    isDense: true,
                  ),
                ),
                SizedBox(height: 14.h),
                TextField(
                  controller: sourceCtl,
                  decoration: const InputDecoration(
                    labelText: '鏉ユ簮锛堝彲閫夛級',
                    hintText: 'URL銆佷功鍚嶆垨鑷垱',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('鍙栨秷'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              final title = titleCtl.text.trim();
              final content = contentCtl.text.trim();
              if (title.isEmpty || content.isEmpty) {
                return;
              }

              final tags = tagsCtl.text
                  .split(',')
                  .map((tag) => tag.trim())
                  .where((tag) => tag.isNotEmpty)
                  .toList();

              await controller.createInspiration(
                title: title,
                content: content,
                category: selectedCategory,
                tags: tags.isNotEmpty ? tags : null,
                source: sourceCtl.text.trim().isNotEmpty
                    ? sourceCtl.text.trim()
                    : null,
              );

              if (ctx.mounted) {
                Get.back();
              }
            },
            child: const Text('鍒涘缓'),
          ),
        ],
      ),
    ),
  );
}
