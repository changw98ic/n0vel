import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';
import '../../../../../shared/data/base_business/base_controller.dart';
import 'work_detail_state.dart';
import '../../../../../features/work/data/work_repository.dart';
import '../../../../../features/work/data/volume_repository.dart';
import '../../../../../features/work/domain/volume.dart';
import '../../../../../features/editor/data/chapter_repository.dart';
import '../../../../../features/editor/domain/chapter.dart';
import '../../../../../core/services/ai/ai_service.dart';
import '../../../../../core/services/ai/models/model_tier.dart' show AIFunction;

class WorkDetailLogic extends BaseController {
  final WorkDetailState state = WorkDetailState();
  late final String workId;

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id'] ?? '';
    loadData();
  }

  Future<void> loadData() async {
    state.isLoading.value = true;

    final workRepo = Get.find<WorkRepository>();
    final volumeRepo = Get.find<VolumeRepository>();
    final chapterRepo = Get.find<ChapterRepository>();

    final work = await workRepo.getWorkById(workId);
    final volumes = await volumeRepo.getVolumesByWorkId(workId);
    final chapters = await chapterRepo.getChaptersByWorkId(workId);

    final chaptersByVolume = <String, List<Chapter>>{};
    for (final volume in volumes) {
      chaptersByVolume[volume.id] =
          chapters.where((chapter) => chapter.volumeId == volume.id).toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    state.work.value = work;
    state.volumes.value = volumes..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    state.chaptersByVolume.value = chaptersByVolume;
    state.isLoading.value = false;
  }

  void selectPanel(WorkDetailPanel panel) {
    state.selectedPanel.value = panel;
  }

  Future<void> createChapter(BuildContext context) async {
    final s = S.of(context)!;
    final titleController = TextEditingController();

    final result = await showDialog<_CreateChapterResult>(
      context: context,
      builder: (context) {
        bool generateFramework = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(s.work_createChapterTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: s.work_chapterTitleHint,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setDialogState(
                    () => generateFramework = !generateFramework,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: generateFramework,
                        onChanged: (v) => setDialogState(
                          () => generateFramework = v ?? false,
                        ),
                      ),
                      const Icon(Icons.auto_awesome_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI 生成章节框架',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text(
                    '根据已有内容和章节标题，自动生成章节大纲与写作框架',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text(s.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final text = titleController.text.trim();
                  Get.back(
                    result: _CreateChapterResult(
                      title: text.isEmpty
                          ? s.work_newChapterDefault
                          : text,
                      generateFramework: generateFramework,
                    ),
                  );
                },
                child: Text(s.confirm),
              ),
            ],
          ),
        );
      },
    );

    titleController.dispose();

    if (result == null) return;

    final volumeRepo = Get.find<VolumeRepository>();
    final chapterRepo = Get.find<ChapterRepository>();

    var targetVolume = state.volumes.isNotEmpty
        ? state.volumes.first
        : await volumeRepo.createVolume(workId: workId, name: '第 1 卷');

    if (state.volumes.isEmpty) {
      state.volumes.value = [targetVolume];
    }

    final chapters = state.chaptersByVolume[targetVolume.id] ?? const <Chapter>[];
    final newChapter = await chapterRepo.createChapter(
      volumeId: targetVolume.id,
      workId: workId,
      title: result.title,
      sortOrder: chapters.length,
    );

    // AI 生成章节框架
    if (result.generateFramework) {
      await generateChapterFramework(newChapter);
    }

    await loadData();
    Get.toNamed('/work/$workId/chapter/${newChapter.id}');
  }

  Future<void> generateChapterFramework(Chapter newChapter) async {
    showSuccessSnackbar('正在生成章节框架...');

    try {
      final chapterRepo = Get.find<ChapterRepository>();
      final allChapters = await chapterRepo.getChaptersByWorkId(workId);

      // 收集上下文：作品信息 + 最近章节内容
      final workInfo = state.work.value;
      final recentChapter = allChapters
          .where((c) => c.id != newChapter.id && c.hasContent)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final lastChapter = recentChapter.isNotEmpty ? recentChapter.first : null;

      final contextBuffer = StringBuffer();
      if (workInfo != null) {
        contextBuffer.writeln('作品名称：${workInfo.name}');
        if (workInfo.description?.isNotEmpty == true) {
          contextBuffer.writeln('作品简介：${workInfo.description}');
        }
        contextBuffer.writeln();
      }
      if (lastChapter != null) {
        final lastContent = lastChapter.content!;
        contextBuffer.writeln('上一章「${lastChapter.title}」末尾内容：');
        contextBuffer.writeln(
          lastContent.length > 1500
              ? lastContent.substring(lastContent.length - 1500)
              : lastContent,
        );
        contextBuffer.writeln();
      }

      final prompt = '''请根据以下信息，为新章节「${newChapter.title}」生成一个详细的写作框架。

${contextBuffer.toString()}
要求：
- 先给出本章的【核心冲突/悬念】（1-2 句）
- 然后列出 4-6 个场景/段落的大纲要点，每个包含：
  - 场景简述（做什么）
  - 情绪/氛围提示
  - 预计字数范围
- 最后给出【本章结尾钩子】（吸引读者继续阅读的悬念或转折）
- 总字数控制在 400-600 字的框架描述

请用以下格式输出：

## 核心冲突
...

## 场景大纲
### 场景 1：[标题]
- 内容简述：...
- 氛围：...
- 预计字数：...

### 场景 2：[标题]
...

## 结尾钩子
...''';

      final aiService = Get.find<AIService>();
      final response = await aiService.generate(
        prompt: prompt,
        config: AIRequestConfig(
          function: AIFunction.continuation,
          userPrompt: prompt,
          temperature: 0.8,
          maxTokens: 1500,
          stream: false,
        ),
      );

      final framework = response.content.trim();
      if (framework.isNotEmpty) {
        final wordCount = framework.replaceAll(RegExp(r'\s'), '').length;
        await chapterRepo.updateContent(newChapter.id, framework, wordCount);
      }

      showSuccessSnackbar('章节框架已生成');
    } catch (e) {
      showErrorSnackbar('框架生成失败：$e');
    }
  }

  int get chapterCount {
    return state.chaptersByVolume.values.fold<int>(
      0,
      (sum, chapters) => sum + chapters.length,
    );
  }

  int get totalWords {
    return state.chaptersByVolume.values
        .expand((chapters) => chapters)
        .fold<int>(0, (sum, chapter) => sum + chapter.wordCount);
  }

  Future<void> deleteChapter(BuildContext context, Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除章节'),
        content: Text('确定要删除章节「${chapter.title}」吗？\n此操作不可撤销。'),
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

    try {
      final chapterRepo = Get.find<ChapterRepository>();
      await chapterRepo.deleteChapter(chapter.id);
      await loadData();
      showSuccessSnackbar('已删除章节：${chapter.title}');
    } catch (e) {
      showErrorSnackbar('删除章节失败：$e');
    }
  }

  Future<void> deleteVolume(BuildContext context, Volume volume) async {
    final chapterCount = state.chaptersByVolume[volume.id]?.length ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除卷'),
        content: Text(
          '确定要删除「${volume.name}」吗？'
          '${chapterCount > 0 ? '\n该卷下的 $chapterCount 个章节也将被一并删除。' : ''}'
          '\n此操作不可撤销。',
        ),
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

    try {
      final volumeRepo = Get.find<VolumeRepository>();
      await volumeRepo.deleteVolume(volume.id);
      await loadData();
      showSuccessSnackbar('已删除卷：${volume.name}');
    } catch (e) {
      showErrorSnackbar('删除卷失败：$e');
    }
  }
}

class _CreateChapterResult {
  final String title;
  final bool generateFramework;

  const _CreateChapterResult({
    required this.title,
    required this.generateFramework,
  });
}
