import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../features/editor/data/chapter_repository.dart';
import '../../../features/settings/data/character_repository.dart';
import '../../../features/pov_generation/data/pov_repository.dart';
import '../../../features/pov_generation/data/pov_generation_service.dart';
import '../../../features/pov_generation/domain/pov_models.dart';
import '../../../core/database/database.dart' hide Character;
import '../../../shared/data/base_business/base_controller.dart';
import 'pov_generation_state.dart';

/// POVGeneration 业务逻辑
class POVGenerationLogic extends BaseController {
  final POVGenerationState state = POVGenerationState();

  final ChapterRepository _chapterRepository = Get.find<ChapterRepository>();
  final CharacterRepository _characterRepository = Get.find<CharacterRepository>();
  final POVRepository _povRepository = Get.find<POVRepository>();
  final POVGenerationService _povService = Get.find<POVGenerationService>();

  late final String workId;
  String? initialChapterId;
  String? initialCharacterId;

  POVGenerationLogic();

  @override
  void onInit() {
    super.onInit();
    workId = Get.parameters['id']!;
    initialChapterId = Get.parameters['chapter'];
    initialCharacterId = Get.parameters['character'];
    state.selectedChapterId.value = initialChapterId;
    state.selectedCharacterId.value = initialCharacterId;
    loadChapters();
    loadCharacters();
    loadTemplates();
  }

  Future<void> loadChapters() async {
    try {
      final chapters = await _chapterRepository.getChaptersByWorkId(workId);
      state.chapters.value = chapters;
      state.chaptersError.value = null;
    } catch (e) {
      state.chaptersError.value = e;
    }
  }

  Future<void> loadCharacters() async {
    try {
      final characters = await _characterRepository.getCharactersByWorkId(workId);
      state.characters.value = characters;
      state.charactersError.value = null;
    } catch (e) {
      state.charactersError.value = e;
    }
  }

  Future<void> loadTemplates() async {
    try {
      final templates = await _povRepository.getAllTemplates(workId: workId);
      state.templates.value = templates;
      state.templatesError.value = null;
    } catch (e) {
      state.templatesError.value = e;
    }
  }

  void setSelectedChapterId(String? id) {
    state.selectedChapterId.value = id;
  }

  void setSelectedCharacterId(String? id) {
    state.selectedCharacterId.value = id;
  }

  void setConfig(POVConfig config) {
    state.config.value = config;
  }

  bool canGenerate() {
    return state.selectedChapterId.value != null &&
        state.selectedCharacterId.value != null;
  }

  Future<void> startGeneration(BuildContext context) async {
    if (!canGenerate()) return;

    state.isGenerating.value = true;

    try {
      final chapter = await _chapterRepository.getChapterById(
        state.selectedChapterId.value!,
      );
      if (chapter == null || chapter.content == null) {
        throw Exception('章节内容为空');
      }

      final character = await _characterRepository.getCharacterById(
        state.selectedCharacterId.value!,
      );
      if (character == null) {
        throw Exception('角色不存在');
      }
      final profile = await _characterRepository.getProfile(
        state.selectedCharacterId.value!,
      );

      var task = await _povRepository.createTask(
        workId: workId,
        chapterId: state.selectedChapterId.value!,
        characterId: state.selectedCharacterId.value!,
        originalContent: chapter.content!,
        config: state.config.value,
      );

      state.currentTask.value = task;

      task = await _povService.generatePOV(
        task: task,
        character: character,
        profile: profile,
      );
      await _povRepository.updateTask(task);

      state.currentTask.value = task;
      showSuccessSnackbar('POV 生成完成');
    } catch (e) {
      showErrorSnackbar('生成失败: $e');
    } finally {
      state.isGenerating.value = false;
    }
  }

  Future<void> acceptResult(
    BuildContext context,
    String content,
  ) async {
    final option = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存POV结果'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: 'draft'),
            child: const Text('保存为草稿'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: 'new'),
            child: const Text('新建章节'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (option == null) return;

    try {
      if (option == 'draft') {
        if (state.selectedChapterId.value != null) {
          await _chapterRepository.updateContent(
            state.selectedChapterId.value!,
            content,
            content.length,
          );
          showSuccessSnackbar('已保存到草稿');
        }
      } else if (option == 'new') {
        await _createNewChapterWithContent(context, content);
      }
    } catch (e) {
      showErrorSnackbar('保存失败: $e');
    }
  }

  Future<void> _createNewChapterWithContent(
    BuildContext context,
    String content,
  ) async {
    final db = Get.find<AppDatabase>();
    final volumes = await (db.select(db.volumes)
          ..where((v) => v.workId.equals(workId)))
        .get();

    if (volumes.isEmpty) {
      showErrorSnackbar('请先创建卷');
      return;
    }

    final volumeId = volumes.first.id;
    final currentChapter = state.selectedChapterId.value != null
        ? await _chapterRepository
            .getChapterById(state.selectedChapterId.value!)
        : null;
    final sortOrder = (currentChapter?.sortOrder ?? 0) + 1;

    final newChapter = await _chapterRepository.createChapter(
      volumeId: volumeId,
      workId: workId,
      title: 'POV视角章节',
      sortOrder: sortOrder,
    );
    await _chapterRepository.updateContent(
      newChapter.id,
      content,
      content.length,
    );

    Get.snackbar(
      '成功',
      '已创建新章节：${newChapter.title}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> editResult(BuildContext context, String content) async {
    if (state.selectedChapterId.value != null) {
      await _chapterRepository.updateContent(
        state.selectedChapterId.value!,
        content,
        content.length,
      );
      Get.offAllNamed('/work/$workId/chapter/${state.selectedChapterId.value}');
    } else {
      showErrorSnackbar('请先选择章节');
    }
  }

  void setCurrentTask(POVTask task) {
    state.currentTask.value = task;
  }
}
