import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../core/database/database.dart';
import '../../../shared/data/base_business/base_page.dart';
import 'inspiration_logic.dart';

const Map<String, String> _categoryLabels = {
  'idea': '灵感',
  'reference': '参考资料',
  'character_sketch': '角色草稿',
  'scene_fragment': '场景片段',
  'worldbuilding': '世界设定',
  'dialogue_snippet': '对白片段',
};

const List<String> _categories = [
  'idea',
  'reference',
  'character_sketch',
  'scene_fragment',
  'worldbuilding',
  'dialogue_snippet',
];

const Map<String, IconData> _categoryIcons = {
  'idea': Icons.lightbulb_outline_rounded,
  'reference': Icons.menu_book_outlined,
  'character_sketch': Icons.person_outline_rounded,
  'scene_fragment': Icons.movie_outlined,
  'worldbuilding': Icons.public_outlined,
  'dialogue_snippet': Icons.chat_bubble_outline_rounded,
};

List<String> _decodeTags(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final decoded = jsonDecode(raw);
  if (decoded is List) return decoded.map((e) => e.toString()).toList();
  return const [];
}

/// 灵感素材库页面
class InspirationView extends GetView<InspirationLogic> with BasePage {
  const InspirationView({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = TextEditingController();
    searchController.addListener(() {
      controller.setSearchQuery(searchController.text.trim());
    });

    return AppPageScaffold(
      title: '素材库',
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inspiration_fab',
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('新建素材'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: '搜索素材...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: Obx(() => controller.state.searchQuery.value.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        searchController.clear();
                        controller.clearSearch();
                      },
                    )),
              isDense: true,
            ),
          ),
          SizedBox(height: 12.h),
          _buildCategoryChips(context),
          SizedBox(height: 16.h),
          Expanded(child: _buildContentList(context)),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return Obx(() => SizedBox(
      height: 40.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildChip(
            context,
            label: '全部',
            selected: controller.state.selectedCategory.value == null,
            onTap: () => controller.setSelectedCategory(null),
          ),
          SizedBox(width: 8.w),
          ..._categories.map(
            (category) => Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: _buildChip(
                context,
                label: _categoryLabels[category] ?? category,
                icon: _categoryIcons[category],
                selected: controller.state.selectedCategory.value == category,
                onTap: () => controller.setSelectedCategory(category),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool selected,
    IconData? icon,
    VoidCallback? onTap,
  }) {
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

  Widget _buildContentList(BuildContext context) {
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
              ? '还没有素材'
              : '没有匹配结果',
          description: controller.state.searchQuery.value.isEmpty
              ? '点击下方按钮新建素材'
              : '换个关键词试试',
          action: controller.state.searchQuery.value.isEmpty
              ? FilledButton.tonal(
                  onPressed: () => _showCreateDialog(context),
                  child: const Text('新建素材'),
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
          itemBuilder: (context, index) =>
              _buildInspirationCard(context, items[index]),
        ),
      );
    });
  }

  Widget _buildInspirationCard(BuildContext context, Inspiration item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tags = _decodeTags(item.tags);
    final categoryLabel = _categoryLabels[item.category] ?? item.category;
    final categoryIcon =
        _categoryIcons[item.category] ?? Icons.article_outlined;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context, item),
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
          onTap: () => _showDetailDialog(context, item),
          onLongPress: () => _confirmDelete(context, item),
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
                      _formatDate(item.updatedAt ?? item.createdAt),
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

  void _showDetailDialog(BuildContext context, Inspiration item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tags = _decodeTags(item.tags);
    final categoryLabel = _categoryLabels[item.category] ?? item.category;

    showDialog(
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
                Text('来源', style: theme.textTheme.labelMedium),
                SizedBox(height: 4.h),
                SelectableText(item.source!, style: theme.textTheme.bodySmall),
              ],
              if (tags.isNotEmpty) ...[
                SizedBox(height: 14.h),
                Text('标签', style: theme.textTheme.labelMedium),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  children: tags.map((tag) => AppTag(label: tag)).toList(),
                ),
              ],
              SizedBox(height: 10.h),
              Text(
                '更新于 ${_formatDate(item.updatedAt ?? item.createdAt)}',
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
              if (ctx.mounted) Get.back();
            },
            child: Text('删除', style: TextStyle(color: colorScheme.error)),
          ),
          FilledButton.tonal(
            onPressed: () => Get.back(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, Inspiration item) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除素材《${item.title}》吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await controller.deleteInspiration(item.id);
              if (ctx.mounted) Get.back(result: true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleCtl = TextEditingController();
    final contentCtl = TextEditingController();
    final tagsCtl = TextEditingController();
    final sourceCtl = TextEditingController();
    String selectedCategory = 'idea';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新建素材'),
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
                      labelText: '标题',
                      hintText: '输入素材标题',
                      isDense: true,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: contentCtl,
                    decoration: const InputDecoration(
                      labelText: '内容',
                      hintText: '输入素材内容',
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
                      labelText: '分类',
                      isDense: true,
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(_categoryLabels[cat] ?? cat),
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
                      labelText: '标签',
                      hintText: '用逗号分隔多个标签',
                      isDense: true,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  TextField(
                    controller: sourceCtl,
                    decoration: const InputDecoration(
                      labelText: '来源（可选）',
                      hintText: 'URL、书名或自创',
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
              child: const Text('取消'),
            ),
            FilledButton.tonal(
              onPressed: () async {
                final title = titleCtl.text.trim();
                final content = contentCtl.text.trim();
                if (title.isEmpty || content.isEmpty) return;

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

                if (ctx.mounted) Get.back();
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${_twoDigits(dt.month)}-${_twoDigits(dt.day)} ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
