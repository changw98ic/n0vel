import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../app/widgets/app_shell.dart';
import '../view/pov_config_panel.dart';
import '../view/pov_result_viewer.dart';
import '../../../features/pov_generation/domain/pov_models.dart';
import '../../../features/pov_generation/data/pov_repository.dart';
import '../../../features/settings/domain/character.dart';
import '../../../shared/data/base_business/base_page.dart';
import 'pov_generation_logic.dart';

/// POV 视角生成页面
class POVGenerationView extends GetView<POVGenerationLogic> with BasePage {
  const POVGenerationView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return AppPageScaffold(
      title: s.povGeneration_title,
      constrainWidth: false,
      bodyPadding: EdgeInsets.zero,
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => _showHistory(context),
          tooltip: s.povGeneration_history,
        ),
      ],
      child: Row(
        children: [
          SizedBox(width: 40.w, child: _buildLeftPanel(context)),
          const VerticalDivider(width: 1),
          Expanded(child: _buildRightPanel(context)),
        ],
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final s = S.of(context)!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterSelector(context),
          SizedBox(height: 24.h),
          _buildCharacterSelector(context),
          SizedBox(height: 24.h),
          Obx(() => POVConfigPanel(
            config: controller.state.config.value,
            onChanged: controller.setConfig,
          )),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: Obx(() => ElevatedButton.icon(
              onPressed: controller.canGenerate() &&
                      !controller.state.isGenerating.value
                  ? () => controller.startGeneration(context)
                  : null,
              icon: controller.state.isGenerating.value
                  ? SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.auto_awesome),
              label: Text(controller.state.isGenerating.value
                  ? s.povGeneration_generating
                  : s.povGeneration_startGeneration),
            )),
          ),
          SizedBox(height: 24.h),
          _buildTemplateQuickSelect(context),
        ],
      ),
    );
  }

  Widget _buildChapterSelector(BuildContext context) {
    final s = S.of(context)!;
    return Obx(() {
      if (controller.state.chaptersError.value != null) {
        return Text('${s.povGeneration_loadFailed}: ${controller.state.chaptersError.value}');
      }
      if (controller.state.chapters.value == null) {
        return const CircularProgressIndicator();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.povGeneration_selectChapter,
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: controller.state.selectedChapterId.value,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: controller.state.chapters.value!.map((c) =>
                DropdownMenuItem(
                  value: c.id,
                  child: Text('第 ${c.sortOrder} 章：${c.title}'),
                )).toList(),
            onChanged: (v) => controller.setSelectedChapterId(v),
          ),
        ],
      );
    });
  }

  Widget _buildCharacterSelector(BuildContext context) {
    final s = S.of(context)!;
    return Obx(() {
      if (controller.state.charactersError.value != null) {
        return Text('${s.povGeneration_loadFailed}: ${controller.state.charactersError.value}');
      }
      if (controller.state.characters.value == null) {
        return const CircularProgressIndicator();
      }

      final supporting = controller.state.characters.value!
          .where((c) =>
              c.tier == CharacterTier.supporting ||
              c.tier == CharacterTier.minor)
          .toList();
      if (supporting.isEmpty) {
        return Card(
            child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(s.povGeneration_noSupportingCharacters)));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.povGeneration_selectCharacter,
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8.h),
          DropdownButtonFormField<String>(
            value: controller.state.selectedCharacterId.value,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: supporting.map((c) => DropdownMenuItem(
              value: c.id,
              child: Row(children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage:
                      c.avatarPath != null ? NetworkImage(c.avatarPath!) : null,
                  child: c.avatarPath == null && c.name.isNotEmpty
                      ? Text(c.name[0])
                      : null,
                ),
                SizedBox(width: 8.w),
                Text(c.name),
                if (c.identity != null) ...[
                  SizedBox(width: 4.w),
                  Text('(${c.identity})',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12.sp)),
                ],
              ]),
            )).toList(),
            onChanged: (v) => controller.setSelectedCharacterId(v),
          ),
        ],
      );
    });
  }

  Widget _buildTemplateQuickSelect(BuildContext context) {
    final s = S.of(context)!;
    return Obx(() {
      if (controller.state.templatesError.value != null) {
        return Text('${s.povGeneration_loadFailed}: ${controller.state.templatesError.value}');
      }
      if (controller.state.templates.value == null) {
        return const CircularProgressIndicator();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.povGeneration_quickTemplates,
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.state.templates.value!.map((t) => ActionChip(
              avatar: controller.state.config.value == t.config
                  ? Icon(Icons.check, size: 18.sp)
                  : null,
              label: Text(t.name),
              onPressed: () => controller.setConfig(t.config),
            )).toList(),
          ),
        ],
      );
    });
  }

  Widget _buildRightPanel(BuildContext context) {
    final s = S.of(context)!;
    return Obx(() {
      if (controller.state.currentTask.value == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories,
                  size: 64.sp,
                  color: Theme.of(context).colorScheme.outline),
              SizedBox(height: 16.h),
              Text(s.povGeneration_placeholder,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        );
      }

      return POVResultViewer(
        task: controller.state.currentTask.value!,
        onAccept: (content) => controller.acceptResult(context, content),
        onRegenerate: () => controller.startGeneration(context),
        onEdit: (content) => controller.editResult(context, content),
      );
    });
  }

  void _showHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HistoryBottomSheet(
        workId: controller.workId,
        onTaskSelected: (task) {
          controller.setCurrentTask(task);
          Get.back();
        },
      ),
    );
  }
}

/// 历史记录底部弹窗
class _HistoryBottomSheet extends StatefulWidget {
  final String workId;
  final ValueChanged<POVTask> onTaskSelected;

  const _HistoryBottomSheet({
    required this.workId,
    required this.onTaskSelected,
  });

  @override
  State<_HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends State<_HistoryBottomSheet> {
  List<POVTask>? _tasks;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final povRepo = Get.find<POVRepository>();
      final tasks = await povRepo.getTasksByWork(widget.workId);
      setState(() {
        _tasks = tasks;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            ListTile(
              title: const Text('历史记录'),
              trailing: TextButton(
                onPressed: () => Get.back(),
                child: const Text('关闭'),
              ),
            ),
            const Divider(),
            Expanded(
              child: _buildContent(scrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    if (_error != null) return Center(child: Text('加载失败: $_error'));
    if (_tasks == null) return const Center(child: CircularProgressIndicator());
    if (_tasks!.isEmpty) return const Center(child: Text('暂无历史记录'));

    return ListView.builder(
      controller: scrollController,
      itemCount: _tasks!.length,
      itemBuilder: (context, index) => _TaskHistoryTile(
        task: _tasks![index],
        onTap: () => widget.onTaskSelected(_tasks![index]),
      ),
    );
  }
}

/// 任务历史列表项
class _TaskHistoryTile extends StatelessWidget {
  final POVTask task;
  final VoidCallback onTap;

  const _TaskHistoryTile({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        _getStatusIcon(task.status),
        color: _getStatusColor(context, task.status),
      ),
      title: Text('任务 ${task.id.substring(0, 12)}...'),
      subtitle: Text('${task.status.label} · ${_formatTime(task.createdAt)}'),
      trailing: Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  IconData _getStatusIcon(POVTaskStatus status) {
    return switch (status) {
      POVTaskStatus.pending => Icons.schedule,
      POVTaskStatus.analyzing => Icons.analytics,
      POVTaskStatus.generating => Icons.auto_awesome,
      POVTaskStatus.completed => Icons.check_circle,
      POVTaskStatus.failed => Icons.error,
      POVTaskStatus.cancelled => Icons.cancel,
    };
  }

  static Color _getStatusColor(BuildContext context, POVTaskStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      POVTaskStatus.pending => colorScheme.outline,
      POVTaskStatus.analyzing => colorScheme.primary,
      POVTaskStatus.generating => colorScheme.secondary,
      POVTaskStatus.completed => colorScheme.primary,
      POVTaskStatus.failed => colorScheme.error,
      POVTaskStatus.cancelled => colorScheme.tertiary,
    };
  }

  String _formatTime(DateTime time) {
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
