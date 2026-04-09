import 'dart:convert';

import 'package:get/get.dart' hide Value;

import '../../../core/database/database.dart' hide Character, CharacterProfile;
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/models/model_tier.dart';
import '../../settings/data/character_repository.dart';
import '../../settings/domain/character.dart';
import '../../settings/domain/character_profile.dart';
import '../domain/pov_models.dart';
import '../data/pov_repository.dart';
import '../../editor/data/chapter_repository.dart';

class POVGenerationService {
  final AIService _aiService;

  POVGenerationService(this._aiService);

  Future<POVAnalysis> analyzeChapter({
    required String workId,
    required String chapterId,
    required String characterId,
    required String chapterContent,
  }) async {
    final characterRepo = Get.find<CharacterRepository>();
    final character = await characterRepo.getCharacterById(characterId);
    if (character == null) {
      throw Exception('Character not found');
    }

    final profile = await characterRepo.getProfile(characterId);
    final prompt = _buildAnalysisPrompt(
      chapterContent: chapterContent,
      character: character,
      profile: profile,
    );

    final response = await _aiService.generate(
      prompt: prompt,
      config: AIRequestConfig(
        function: AIFunction.povGeneration,
        userPrompt: prompt,
        overrideTier: ModelTier.middle,
        maxTokens: 4000,
        temperature: 0.3,
        stream: false,
      ),
    );

    return _parseAnalysisResult(response.content);
  }

  Future<POVTask> generatePOV({
    required POVTask task,
    required Character character,
    CharacterProfile? profile,
  }) async {
    try {
      task = task.copyWith(status: POVTaskStatus.analyzing);

      final analysis = await analyzeChapter(
        workId: task.workId,
        chapterId: task.chapterId,
        characterId: task.characterId,
        chapterContent: task.originalContent,
      );

      task = task.copyWith(
        status: POVTaskStatus.generating,
        analysis: jsonEncode(analysis.toJson()),
      );

      final prompt = _buildGenerationPrompt(
        originalContent: task.originalContent,
        character: character,
        profile: profile,
        config: task.config,
        analysis: analysis,
      );

      final response = await _aiService.generate(
        prompt: prompt,
        config: AIRequestConfig(
          function: AIFunction.povGeneration,
          userPrompt: prompt,
          overrideTier: _getModelTierForMode(task.config.mode),
          maxTokens: _getMaxTokensForMode(
            task.config.mode,
            task.originalContent.length,
          ),
          temperature: 0.7,
          stream: false,
        ),
      );

      return task.copyWith(
        status: POVTaskStatus.completed,
        generatedContent: response.content,
        tokenUsage: response.inputTokens + response.outputTokens,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      return task.copyWith(
        status: POVTaskStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  String _buildAnalysisPrompt({
    required String chapterContent,
    required Character character,
    CharacterProfile? profile,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# Character POV analysis');
    buffer.writeln();
    buffer.writeln('## Character');
    buffer.writeln('- Name: ${character.name}');
    if (character.aliases.isNotEmpty) {
      buffer.writeln('- Aliases: ${character.aliases.join(', ')}');
    }
    buffer.writeln('- Tier: ${character.tier.label}');

    if (profile != null) {
      buffer.writeln();
      buffer.writeln('## Profile');
      if (profile.mbti != null) {
        buffer.writeln('- MBTI: ${profile.mbti!.code}');
      }
      if (profile.bigFive != null) {
        buffer.writeln('- Big Five: ${profile.bigFive}');
      }
      if (profile.speechStyle != null) {
        buffer.writeln('- Speech: ${profile.speechStyle}');
      }
    }

    buffer.writeln();
    buffer.writeln('## Chapter content');
    buffer.writeln('```');
    buffer.writeln(chapterContent);
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('Return JSON with:');
    buffer.writeln('- appearances');
    buffer.writeln('- emotionCurve');
    buffer.writeln('- observations');
    buffer.writeln('- interactions');
    buffer.writeln('- suggestedThoughts');
    buffer.writeln('- suggestions');

    return buffer.toString();
  }

  String _buildGenerationPrompt({
    required String originalContent,
    required Character character,
    CharacterProfile? profile,
    required POVConfig config,
    required POVAnalysis analysis,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('# Generate POV content');
    buffer.writeln();
    buffer.writeln('## Task');
    buffer.writeln(
      'Rewrite or extend the content from ${character.name} perspective.',
    );
    buffer.writeln();
    buffer.writeln('## Config');
    buffer.writeln('- Mode: ${config.mode.label}');
    buffer.writeln('- Style: ${config.style.label}');
    buffer.writeln('- Keep dialogue: ${config.keepDialogue}');
    buffer.writeln('- Add inner thoughts: ${config.addInnerThoughts}');
    buffer.writeln('- Expand observations: ${config.expandObservations}');
    buffer.writeln(
      '- Emotional intensity: ${(config.emotionalIntensity * 100).toInt()}%',
    );
    buffer.writeln('- Use character voice: ${config.useCharacterVoice}');
    if (config.targetWordCount != null) {
      buffer.writeln('- Target words: ${config.targetWordCount}');
    }
    if (config.customInstructions != null &&
        config.customInstructions!.trim().isNotEmpty) {
      buffer.writeln('- Extra instructions: ${config.customInstructions}');
    }

    buffer.writeln();
    buffer.writeln('## Character');
    buffer.writeln('- Name: ${character.name}');
    buffer.writeln('- Identity: ${character.identity ?? 'unknown'}');
    buffer.writeln('- Bio: ${character.bio ?? 'unknown'}');

    if (profile != null) {
      if (profile.mbti != null) {
        buffer.writeln('- MBTI: ${profile.mbti!.code}');
      }
      if (profile.speechStyle != null) {
        buffer.writeln('- Speech speed: ${profile.speechStyle!.speed}');
      }
    }

    if (analysis.suggestions.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('## Suggestions');
      for (final suggestion in analysis.suggestions) {
        buffer.writeln('- $suggestion');
      }
    }

    buffer.writeln();
    buffer.writeln('## Original content');
    buffer.writeln('```');
    buffer.writeln(originalContent);
    buffer.writeln('```');
    buffer.writeln();
    buffer.writeln('Output only the final prose. No explanation.');

    return buffer.toString();
  }

  POVAnalysis _parseAnalysisResult(String content) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        return POVAnalysis.fromJson(json);
      }
    } catch (_) {}

    return const POVAnalysis(
      appearances: [],
      emotionCurve: [],
      observations: [],
      interactions: [],
      suggestedThoughts: [],
      suggestions: ['Failed to parse analysis result.'],
    );
  }

  ModelTier _getModelTierForMode(POVMode mode) {
    return switch (mode) {
      POVMode.rewrite => ModelTier.thinking,
      POVMode.supplement => ModelTier.middle,
      POVMode.summary => ModelTier.middle,
      POVMode.fragment => ModelTier.fast,
    };
  }

  int _getMaxTokensForMode(POVMode mode, int originalLength) {
    final estimatedTokens = (originalLength / 1.5).ceil();

    return switch (mode) {
      POVMode.rewrite => estimatedTokens * 2,
      POVMode.supplement => estimatedTokens + 2000,
      POVMode.summary => 2000,
      POVMode.fragment => 3000,
    };
  }

  // ========== POV 结果保存功能 ==========

  /// 保存 POV 结果为草稿
  Future<String> saveAsDraft({
    required String workId,
    required String chapterId,
    required String characterId,
    required String generatedContent,
    required POVConfig config,
    String? analysis,
  }) async {
    final now = DateTime.now();

    // 使用 POV repository 创建任务记录
    final povRepo = Get.find<POVRepository>();
    final task = await povRepo.createTask(
      workId: workId,
      chapterId: chapterId,
      characterId: characterId,
      originalContent: '',
      config: config,
    );

    // 更新任务状态为已完成
    await povRepo.updateTask(
      task.copyWith(
        generatedContent: generatedContent,
        analysis: analysis,
        status: POVTaskStatus.completed,
        completedAt: now,
      ),
    );

    return task.id;
  }

  /// 保存 POV 结果为新章节
  Future<String> saveAsNewChapter({
    required String workId,
    required String volumeId,
    required String chapterId,
    required String characterId,
    required String generatedContent,
    required String chapterTitle,
    int sortOrder = 0,
  }) async {
    final chapterRepo = Get.find<ChapterRepository>();

    // 创建新章节
    final newChapter = await chapterRepo.createChapter(
      volumeId: volumeId,
      workId: workId,
      title: chapterTitle,
      sortOrder: sortOrder,
    );

    // 更新章节内容
    final wordCount = _countWords(generatedContent);
    await chapterRepo.updateContent(newChapter.id, generatedContent, wordCount);

    // 同时保存为 POV 任务记录（用于追踪）
    final povRepo = Get.find<POVRepository>();
    final task = await povRepo.createTask(
      workId: workId,
      chapterId: chapterId,
      characterId: characterId,
      originalContent: '',
      config: const POVConfig(),
    );

    await povRepo.updateTask(
      task.copyWith(
        generatedContent: generatedContent,
        status: POVTaskStatus.completed,
        completedAt: DateTime.now(),
      ),
    );

    return newChapter.id;
  }

  /// 替换现有章节内容
  Future<void> replaceChapterContent({
    required String chapterId,
    required String generatedContent,
  }) async {
    final chapterRepo = Get.find<ChapterRepository>();
    final wordCount = _countWords(generatedContent);

    await chapterRepo.updateContent(chapterId, generatedContent, wordCount);
  }

  /// 保存 POV 结果并返回可用的保存选项
  Future<POVSaveOptions> getSaveOptions({
    required String workId,
    required String chapterId,
    required String characterId,
  }) async {
    final chapterRepo = Get.find<ChapterRepository>();

    // 获取当前章节信息
    final currentChapter = await chapterRepo.getChapterById(chapterId);

    // 检查是否有下一章（用于确定 sortOrder）
    final chapters = await chapterRepo.getChaptersByWorkId(workId);
    final currentChapterIndex = chapters.indexWhere((c) => c.id == chapterId);
    final nextSortOrder = currentChapterIndex >= 0
        ? (chapters[currentChapterIndex].sortOrder + 1)
        : chapters.length;

    // 获取第一个卷ID（如果没有指定）
    final db = Get.find<AppDatabase>();
    final volumes = await (db.select(
      db.volumes,
    )..where((v) => v.workId.equals(workId))).get();
    final defaultVolumeId = volumes.isNotEmpty ? volumes.first.id : null;

    return POVSaveOptions(
      canSaveAsDraft: true,
      canReplaceChapter: currentChapter != null,
      canCreateNewChapter: defaultVolumeId != null,
      currentChapterTitle: currentChapter?.title,
      suggestedSortOrder: nextSortOrder,
      defaultVolumeId: defaultVolumeId,
    );
  }

  /// 统计字数（支持中文和英文混合内容）
  int _countWords(String text) {
    final chineseCount = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final englishCount = RegExp(r'[a-zA-Z]+').allMatches(text).length;
    return chineseCount + englishCount;
  }
}

class BuiltInPOVTemplates {
  static List<POVTemplate> get all => [
    POVTemplate(
      id: 'first_person_standard',
      name: 'Standard first person',
      description: 'Full rewrite in first person while keeping plot beats.',
      config: const POVConfig(
        mode: POVMode.rewrite,
        style: POVStyle.firstPerson,
        keepDialogue: true,
        addInnerThoughts: true,
        expandObservations: true,
        emotionalIntensity: 0.5,
        useCharacterVoice: true,
      ),
      isBuiltIn: true,
    ),
    POVTemplate(
      id: 'inner_focus',
      name: 'Inner focus',
      description: 'Emphasize inner thoughts and emotional change.',
      config: const POVConfig(
        mode: POVMode.supplement,
        style: POVStyle.firstPerson,
        keepDialogue: true,
        addInnerThoughts: true,
        expandObservations: false,
        emotionalIntensity: 0.8,
        useCharacterVoice: true,
      ),
      isBuiltIn: true,
    ),
    POVTemplate(
      id: 'observer',
      name: 'Observer',
      description: 'Use a more distant and restrained observer lens.',
      config: const POVConfig(
        mode: POVMode.rewrite,
        style: POVStyle.thirdPersonLimited,
        keepDialogue: true,
        addInnerThoughts: false,
        expandObservations: true,
        emotionalIntensity: 0.3,
        useCharacterVoice: true,
      ),
      isBuiltIn: true,
    ),
    POVTemplate(
      id: 'diary',
      name: 'Diary',
      description: 'Summarize the chapter as a diary entry.',
      config: const POVConfig(
        mode: POVMode.summary,
        style: POVStyle.diary,
        keepDialogue: false,
        addInnerThoughts: true,
        expandObservations: false,
        emotionalIntensity: 0.6,
        useCharacterVoice: true,
      ),
      isBuiltIn: true,
    ),
    POVTemplate(
      id: 'memoir',
      name: 'Memoir',
      description: 'Narrate with reflective hindsight.',
      config: const POVConfig(
        mode: POVMode.summary,
        style: POVStyle.memoir,
        keepDialogue: true,
        addInnerThoughts: true,
        expandObservations: false,
        emotionalIntensity: 0.4,
        useCharacterVoice: true,
      ),
      isBuiltIn: true,
    ),
  ];
}
