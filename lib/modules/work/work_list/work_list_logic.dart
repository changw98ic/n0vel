import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/export_service.dart';
import '../../../features/work/data/work_repository.dart';
import '../../../features/work/domain/work.dart';
import '../view/work_form_page.dart';
import '../../../shared/data/base_business/base_controller.dart';
import 'work_list_state.dart';

/// WorkList 业务逻辑
class WorkListLogic extends BaseController {
  final WorkListState state = WorkListState();
  final _workRepo = Get.find<WorkRepository>();

  @override
  void onInit() {
    super.onInit();
    loadWorks();
  }

  // ─── 数据加载 ────────────────────────────────────────────────

  Future<void> loadWorks() async {
    await runWithLoading(() async {
      final works = await _workRepo.getAllWorks(includeArchived: true);
      state.works.assignAll(works);
    });
  }

  // ─── 过滤 ────────────────────────────────────────────────────

  void toggleArchived() {
    state.showArchived.value = !state.showArchived.value;
  }

  List<Work> get visibleWorks => state.works.where((work) {
        if (!state.showArchived.value && work.isArchived) return false;
        return true;
      }).toList();

  // ─── 操作 ────────────────────────────────────────────────────

  Future<void> createNewWork() async {
    final result = await showDialog<WorkFormResult>(
      context: Get.context!,
      builder: (context) => const WorkFormDialog(),
    );

    if (result != null) {
      await loadWorks();
      showSuccessSnackbar('已创建作品：${result.work.name}');
    }
  }

  void openWorkDetail(Work work) {
    Get.toNamed('/work/${work.id}');
  }

  Future<void> togglePin(Work work) async {
    try {
      await _workRepo.togglePin(work.id);
      await loadWorks();
      showSuccessSnackbar(work.isPinned ? '已取消置顶' : '已置顶作品');
    } catch (e) {
      showErrorSnackbar('更新置顶状态失败：$e');
    }
  }

  Future<void> editWork(Work work) async {
    final result = await showDialog<WorkFormResult>(
      context: Get.context!,
      builder: (context) => WorkFormDialog(existingWork: work),
    );

    if (result != null) {
      await loadWorks();
      showSuccessSnackbar('已更新作品：${result.work.name}');
    }
  }

  Future<void> exportWork(Work work) async {
    try {
      final format = await showDialog<WorkExportFormat>(
        context: Get.context!,
        builder: (context) => const SimpleDialog(
          title: Text('导出格式'),
          children: [
            SimpleDialogOption(child: Text('ZIP 压缩包')),
            SimpleDialogOption(child: Text('纯文本')),
            SimpleDialogOption(child: Text('Markdown')),
          ],
        ),
      );

      if (format == null) return;
      showInfoSnackbar('正在导出...');

      final service = Get.find<ExportService>();
      final result =
          await service.exportWork(workId: work.id, format: format);
      showSuccessSnackbar(
          '已导出 ${result.chapterCount} 个章节到 ${result.path}');
    } catch (e) {
      showErrorSnackbar('导出失败：$e');
    }
  }

  Future<void> toggleArchive(Work work) async {
    try {
      if (work.isArchived) {
        await _workRepo.restoreWork(work.id);
      } else {
        await _workRepo.archiveWork(work.id);
      }
      await loadWorks();
      showSuccessSnackbar(work.isArchived ? '已从归档恢复' : '已归档作品');
    } catch (e) {
      showErrorSnackbar('更新归档状态失败：$e');
    }
  }

  Future<void> deleteWork(Work work) async {
    final confirmed = await showDialog<bool>(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要永久删除「${work.name}」吗？\n此操作不可撤销，所有卷和章节将被一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 立即从列表移除，让 UI 即时响应
    state.works.removeWhere((w) => w.id == work.id);

    try {
      await _workRepo.deleteWork(work.id);
      showSuccessSnackbar('已删除作品：${work.name}');
    } catch (e) {
      // 失败时恢复数据
      await loadWorks();
      showErrorSnackbar('删除失败：$e');
    }
  }

  Future<void> changeStatus(Work work, String newStatus) async {
    if (work.status == newStatus) return;
    try {
      await _workRepo.updateWork(work.id, UpdateWorkParams(status: newStatus));
      await loadWorks();
      showSuccessSnackbar('状态已更新');
    } catch (e) {
      showErrorSnackbar('更新状态失败：$e');
    }
  }
}
