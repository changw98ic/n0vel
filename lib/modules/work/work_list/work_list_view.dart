import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/widgets/app_shell.dart';
import '../../../features/work/domain/work.dart';
import '../view/work_card.dart';
import '../../../shared/data/base_business/base_page.dart';
import 'work_list_logic.dart';

/// 作品列表页
class WorkListView extends GetView<WorkListLogic> with BasePage {
  const WorkListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: '作品',
      actions: [
        Obx(() => IconButton(
              tooltip: controller.state.showArchived.value ? '隐藏归档' : '显示归档',
              icon: Icon(
                controller.state.showArchived.value
                    ? Icons.archive_rounded
                    : Icons.archive_outlined,
              ),
              onPressed: controller.toggleArchived,
            )),
        SizedBox(width: 12.w),
      ],
      child: Obx(() {
        if (controller.isLoading.value) {
          return loadingIndicator();
        }
        if (controller.hasError) {
          return errorState(
            controller.errorMessage.value,
            onRetry: controller.loadWorks,
          );
        }
        return _buildContent(context, theme);
      }),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    final visibleWorks = controller.visibleWorks;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Header row: title + new button
        Row(
          children: [
            Expanded(
              child: Text(
                controller.state.showArchived.value ? '全部作品' : '作品库',
                style: theme.textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: controller.createNewWork,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('新建作品'),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        // Work grid
        if (visibleWorks.isEmpty)
          AppEmptyState(
            icon: Icons.menu_book_outlined,
            title: '还没有作品',
            description: '点击上方按钮创建。',
            action: FilledButton.icon(
              onPressed: controller.createNewWork,
              icon: const Icon(Icons.add_rounded),
              label: const Text('创建第一部作品'),
            ),
          )
        else
          _buildWorkGrid(visibleWorks, controller),
      ],
    );
  }

  Widget _buildWorkGrid(List<Work> works, WorkListLogic controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: works.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            mainAxisSpacing: 18.h,
            crossAxisSpacing: 18.w,
            childAspectRatio: 300 / 500,
          ),
          itemBuilder: (context, index) => WorkCard(
            work: works[index],
            onTap: () => controller.openWorkDetail(works[index]),
            onLongPress: () => _showWorkOptions(works[index], controller),
          ),
        );
      },
    );
  }

  void _showWorkOptions(Work work, WorkListLogic controller) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Theme.of(Get.context!).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                child: Text(
                  work.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('更改状态'),
                subtitle: Text(work.statusText),
                onTap: () {
                  Get.back();
                  _showStatusPicker(work, controller);
                },
              ),
              ListTile(
                leading: Icon(
                  work.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                ),
                title: Text(work.isPinned ? '取消置顶' : '置顶作品'),
                onTap: () {
                  Get.back();
                  controller.togglePin(work);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('编辑信息'),
                onTap: () {
                  Get.back();
                  controller.editWork(work);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_download_rounded),
                title: const Text('导出作品'),
                onTap: () {
                  Get.back();
                  controller.exportWork(work);
                },
              ),
              ListTile(
                leading: Icon(
                  work.isArchived
                      ? Icons.unarchive_rounded
                      : Icons.archive_rounded,
                ),
                title: Text(work.isArchived ? '恢复归档' : '归档作品'),
                onTap: () {
                  Get.back();
                  controller.toggleArchive(work);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  '删除作品',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Get.back();
                  controller.deleteWork(work);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusPicker(Work work, WorkListLogic controller) {
    final statuses = [
      ('draft', '草稿', Icons.edit_note_rounded),
      ('ongoing', '连载中', Icons.bolt_rounded),
      ('completed', '已完结', Icons.check_circle_rounded),
    ];

    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Theme.of(Get.context!).colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
                child: Text('选择状态', style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(),
              ...statuses.map((s) => ListTile(
                    leading: Icon(
                      s.$3,
                      color: work.status == s.$1
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(s.$2),
                    trailing: work.status == s.$1
                        ? Icon(Icons.check_rounded,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      Get.back();
                      controller.changeStatus(work, s.$1);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
