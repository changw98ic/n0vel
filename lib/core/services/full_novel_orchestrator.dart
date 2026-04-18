import 'dart:async';
import 'dart:convert';

import '../../features/editor/data/chapter_repository.dart';
import '../../features/inspiration/data/inspiration_repository.dart';
import '../../features/pov_generation/data/pov_generation_service.dart';
import '../../features/pov_generation/domain/pov_models.dart';
import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/faction_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/settings/data/relationship_repository.dart';
import '../../features/settings/domain/character.dart';
import '../../features/settings/domain/relationship.dart';
import '../../features/work/data/volume_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../models/value_objects/emotion_dimensions.dart';
import 'ai/ai_service.dart';
import 'ai/models/model_tier.dart';
import 'batch_chapter_orchestrator.dart';
import 'full_novel_prompt_builder.dart';

// ── Domain Models ──

/// 请求参数
class FullNovelRequest {
  final String title;
  final String genre;
  final String? description;
  final int chapterCount;
  final int wordsPerChapter;
  final String? style;
  final bool generatePOV;
  final bool runQualityChecks;

  const FullNovelRequest({
    required this.title,
    required this.genre,
    this.description,
    this.chapterCount = 10,
    this.wordsPerChapter = 2500,
    this.style,
    this.generatePOV = true,
    this.runQualityChecks = true,
  });
}

/// 执行阶段
enum NovelPhase {
  foundation('基础创建'),
  worldbuilding('世界观构建'),
  characterDesign('角色设计'),
  entityCreation('实体创建'),
  plotPlanning('剧情规划'),
  chapterWriting('章节写作'),
  povGeneration('配角视角'),
  qualityCheck('质量检查'),
  completed('完成'),
  failed('失败');

  final String label;
  const NovelPhase(this.label);
}

/// 最终结果
class FullNovelResult {
  final String workId;
  final String volumeId;
  final List<String> chapterIds;
  final List<String> characterIds;
  final List<String> locationIds;
  final List<String> itemIds;
  final List<String> factionIds;
  final int totalWords;
  final String? qualityReport;

  const FullNovelResult({
    required this.workId,
    required this.volumeId,
    this.chapterIds = const [],
    this.characterIds = const [],
    this.locationIds = const [],
    this.itemIds = const [],
    this.factionIds = const [],
    this.totalWords = 0,
    this.qualityReport,
  });
}

// ── Events ──

sealed class NovelEvent {}

class NovelPhaseStart extends NovelEvent {
  final NovelPhase phase;
  final int steps;
  NovelPhaseStart(this.phase, {this.steps = 0});
}

class NovelPhaseProgress extends NovelEvent {
  final NovelPhase phase;
  final int step;
  final int total;
  final String? detail;
  NovelPhaseProgress(this.phase, {required this.step, required this.total, this.detail});
}

class NovelPhaseDone extends NovelEvent {
  final NovelPhase phase;
  NovelPhaseDone(this.phase);
}

class NovelComplete extends NovelEvent {
  final FullNovelResult result;
  NovelComplete(this.result);
}

class NovelError extends NovelEvent {
  final String error;
  final NovelPhase? phase;
  NovelError(this.error, {this.phase});
}

// ── Internal data holders ──

class _WorldData {
  final String raw;
  _WorldData(this.raw);
}

class _CharEntry {
  final String id;
  final String name;
  final CharacterTier tier;
  final String? bio;
  _CharEntry(this.id, this.name, this.tier, {this.bio});
}

class _EntityData {
  final List<({String id, String name, String? parentId})> locations;
  final List<({String id, String name})> items;
  final List<({String id, String name})> factions;

  _EntityData({
    this.locations = const [],
    this.items = const [],
    this.factions = const [],
  });
}

class _OutlineData {
  final List<ChapterOutline> outlines;
  _OutlineData(this.outlines);
}

// ── Orchestrator ──

class FullNovelOrchestrator {
  final AIService _ai;
  final WorkRepository _workRepo;
  final VolumeRepository _volRepo;
  final ChapterRepository _chapRepo;
  final CharacterRepository _charRepo;
  final RelationshipRepository _relRepo;
  final LocationRepository _locRepo;
  final ItemRepository _itemRepo;
  final FactionRepository _facRepo;
  final InspirationRepository _insRepo;
  final BatchChapterOrchestrator _batch;
  final POVGenerationService _povService;

  bool _cancelled = false;

  FullNovelOrchestrator({
    required AIService ai,
    required WorkRepository workRepo,
    required VolumeRepository volRepo,
    required ChapterRepository chapRepo,
    required CharacterRepository charRepo,
    required RelationshipRepository relRepo,
    required LocationRepository locRepo,
    required ItemRepository itemRepo,
    required FactionRepository facRepo,
    required InspirationRepository insRepo,
    required BatchChapterOrchestrator batch,
    required POVGenerationService povService,
  })  : _ai = ai,
        _workRepo = workRepo,
        _volRepo = volRepo,
        _chapRepo = chapRepo,
        _charRepo = charRepo,
        _relRepo = relRepo,
        _locRepo = locRepo,
        _itemRepo = itemRepo,
        _facRepo = facRepo,
        _insRepo = insRepo,
        _batch = batch,
        _povService = povService;

  void cancel() => _cancelled = true;

  /// 执行完整流水线，返回事件流
  Stream<NovelEvent> execute(FullNovelRequest request) {
    _cancelled = false;
    final controller = StreamController<NovelEvent>();
    _runPipeline(request, controller);
    return controller.stream;
  }

  // ── Pipeline ──

  Future<void> _runPipeline(
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    try {
      // Phase 1: Foundation
      final (workId, volumeId) = await _phaseFoundation(request, c);
      if (_cancelled) { _fail(c, NovelPhase.foundation); return; }

      // Phase 2: World Building
      final world = await _phaseWorldbuilding(workId, request, c);
      if (_cancelled) { _fail(c, NovelPhase.worldbuilding); return; }

      // Phase 3: Character Design
      final chars = await _phaseCharacterDesign(workId, world, request, c);
      if (_cancelled) { _fail(c, NovelPhase.characterDesign); return; }

      // Phase 4: Entity Creation
      final entities = await _phaseEntityCreation(workId, chars, world, request, c);
      if (_cancelled) { _fail(c, NovelPhase.entityCreation); return; }

      // Phase 5: Plot Planning
      final outline = await _phasePlotPlanning(workId, chars, world, request, c);
      if (_cancelled) { _fail(c, NovelPhase.plotPlanning); return; }

      // Phase 6: Chapter Writing
      final chapterIds = await _phaseChapterWriting(
        workId, volumeId, outline, chars, world, request, c,
      );
      if (_cancelled) { _fail(c, NovelPhase.chapterWriting); return; }

      // Phase 7: POV Generation
      if (request.generatePOV && chars.isNotEmpty && chapterIds.isNotEmpty) {
        await _phasePOV(workId, chapterIds, chars, c);
        if (_cancelled) { _fail(c, NovelPhase.povGeneration); return; }
      }

      // Phase 8: Quality Checks
      String? qualityReport;
      if (request.runQualityChecks && chapterIds.isNotEmpty) {
        qualityReport = await _phaseQualityCheck(workId, chapterIds, chars, c);
        if (_cancelled) { _fail(c, NovelPhase.qualityCheck); return; }
      }

      // Complete
      final totalWords = await _countWords(chapterIds);
      c.add(NovelComplete(FullNovelResult(
        workId: workId,
        volumeId: volumeId,
        chapterIds: chapterIds,
        characterIds: chars.map((e) => e.id).toList(),
        locationIds: entities.locations.map((e) => e.id).toList(),
        itemIds: entities.items.map((e) => e.id).toList(),
        factionIds: entities.factions.map((e) => e.id).toList(),
        totalWords: totalWords,
        qualityReport: qualityReport,
      )));
      await c.close();
    } catch (e) {
      c.add(NovelError(e.toString()));
      await c.close();
    }
  }

  void _fail(StreamController<NovelEvent> c, NovelPhase phase) {
    c.add(NovelError('已取消', phase: phase));
    c.close();
  }

  // ── Phase 1: Foundation ──

  Future<(String, String)> _phaseFoundation(
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.foundation, steps: 2));

    final work = await _workRepo.createWork(
      CreateWorkParams(
        name: request.title,
        type: request.genre,
        description: request.description,
        targetWords: request.chapterCount * request.wordsPerChapter,
      ),
    );
    c.add(NovelPhaseProgress(NovelPhase.foundation, step: 1, total: 2, detail: '作品已创建'));

    final volume = await _volRepo.createVolume(
      workId: work.id,
      name: '第一卷',
    );
    c.add(NovelPhaseProgress(NovelPhase.foundation, step: 2, total: 2, detail: '卷已创建'));
    c.add(NovelPhaseDone(NovelPhase.foundation));

    return (work.id, volume.id);
  }

  // ── Phase 2: World Building ──

  Future<_WorldData> _phaseWorldbuilding(
    String workId,
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.worldbuilding, steps: 1));
    final prompt = FullNovelPromptBuilder.buildWorldbuildingPrompt(
      title: request.title,
      genre: request.genre,
      style: request.style,
      description: request.description,
    );

    final response = await _callAI(prompt, AIFunction.chat, ModelTier.thinking);

    await _insRepo.create(
      title: '${request.title} - 世界观设定',
      content: response,
      workId: workId,
      category: 'worldbuilding',
      tags: [request.genre, '世界观'],
    );

    c.add(NovelPhaseProgress(NovelPhase.worldbuilding, step: 1, total: 1, detail: '世界观已生成'));
    c.add(NovelPhaseDone(NovelPhase.worldbuilding));
    return _WorldData(response);
  }

  // ── Phase 3: Character Design ──

  Future<List<_CharEntry>> _phaseCharacterDesign(
    String workId,
    _WorldData world,
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.characterDesign, steps: request.chapterCount > 8 ? 8 : 7));
    final prompt = FullNovelPromptBuilder.buildCharacterDesignPrompt(
      title: request.title,
      genre: request.genre,
      worldRaw: world.raw,
    );

    final response = await _callAI(prompt, AIFunction.entityCreation, ModelTier.thinking);
    final chars = <_CharEntry>[];

    // 解析 JSON
    final jsonStr = FullNovelParsing.extractJsonArray(response);
    if (jsonStr != null) {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (var i = 0; i < list.length; i++) {
        final item = list[i] as Map<String, dynamic>;
        final tierStr = item['tier'] as String? ?? 'minor';
        final tier = FullNovelParsing.parseTier(tierStr);

        final character = await _charRepo.createCharacter(
          CreateCharacterParams(
            workId: workId,
            name: item['name'] as String? ?? '未命名',
            tier: tier,
            gender: item['gender'] as String?,
            age: item['age'] as String?,
            identity: item['identity'] as String?,
            bio: item['bio'] as String?,
            aliases: (item['aliases'] as List<dynamic>?)?.cast<String>(),
          ),
        );
        chars.add(_CharEntry(
          character.id, character.name, tier,
          bio: item['bio'] as String?,
        ));
        c.add(NovelPhaseProgress(
          NovelPhase.characterDesign,
          step: i + 1,
          total: list.length,
          detail: '角色「${character.name}」已创建',
        ));
      }
    }

    // 创建关键关系
    if (chars.length >= 2) {
      final mainPairs = <(int, int, RelationType, EmotionDimensions)>[
        // 主角 vs 反派
        (0, 1, RelationType.enemy, const EmotionDimensions(affection: 10, trust: 5, respect: 30, fear: 40)),
      ];
      // 主角 vs 配角们
      for (var i = 2; i < chars.length && i < 5; i++) {
        final relations = [RelationType.friend, RelationType.mentor, RelationType.rival];
        mainPairs.add((0, i, relations[i - 2], const EmotionDimensions(affection: 70, trust: 60, respect: 55)));
      }

      for (final (a, b, relType, emotion) in mainPairs) {
        if (a < chars.length && b < chars.length) {
          try {
            await _relRepo.createRelationship(
              workId: workId,
              characterAId: chars[a].id,
              characterBId: chars[b].id,
              relationType: relType,
              emotionDimensions: emotion,
              changeReason: '初始关系设定',
            );
          } catch (_) {
            // 关系可能已存在（normalized id 冲突），忽略
          }
        }
      }
    }

    c.add(NovelPhaseDone(NovelPhase.characterDesign));
    return chars;
  }

  // ── Phase 4: Entity Creation ──

  Future<_EntityData> _phaseEntityCreation(
    String workId,
    List<_CharEntry> chars,
    _WorldData world,
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.entityCreation, steps: 3));
    final charNames = FullNovelPromptBuilder.buildCharacterNameSummary(
      chars.map((e) => (name: e.name, tier: e.tier)),
    );
    final prompt = FullNovelPromptBuilder.buildEntityCreationPrompt(
      title: request.title,
      genre: request.genre,
      worldRaw: world.raw,
      characterNames: charNames,
    );

    final response = await _callAI(prompt, AIFunction.entityCreation, ModelTier.thinking);
    final jsonStr = FullNovelParsing.extractJsonObject(response);

    final locations = <({String id, String name, String? parentId})>[];
    final items = <({String id, String name})>[];
    final factions = <({String id, String name})>[];

    if (jsonStr != null) {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final nameToCharId = {for (final c in chars) c.name: c.id};

      // Locations
      final locationNameToId = <String, String>{};
      final locList = data['locations'] as List<dynamic>? ?? [];
      for (final loc in locList) {
        final m = loc as Map<String, dynamic>;
        final parentName = m['parentName'] as String?;
        final parentId = parentName != null ? locationNameToId[parentName] : null;
        final location = await _locRepo.createLocation(
          workId: workId,
          name: m['name'] as String? ?? '未命名',
          type: m['type'] as String?,
          parentId: parentId,
          description: m['description'] as String?,
          importantPlaces: (m['importantPlaces'] as List<dynamic>?)?.cast<String>(),
        );
        locationNameToId[location.name] = location.id;
        locations.add((id: location.id, name: location.name, parentId: parentId));
      }
      c.add(NovelPhaseProgress(NovelPhase.entityCreation, step: 1, total: 3, detail: '已创建 ${locations.length} 个地点'));

      // Items
      final itemList = data['items'] as List<dynamic>? ?? [];
      for (final item in itemList) {
        final m = item as Map<String, dynamic>;
        final holderName = m['holderName'] as String?;
        final itemResult = await _itemRepo.createItem(
          workId: workId,
          name: m['name'] as String? ?? '未命名',
          type: m['type'] as String?,
          rarity: m['rarity'] as String?,
          description: m['description'] as String?,
          abilities: (m['abilities'] as List<dynamic>?)?.cast<String>(),
          holderId: holderName != null ? nameToCharId[holderName] : null,
        );
        items.add((id: itemResult.id, name: itemResult.name));
      }
      c.add(NovelPhaseProgress(NovelPhase.entityCreation, step: 2, total: 3, detail: '已创建 ${items.length} 个物品'));

      // Factions
      final facList = data['factions'] as List<dynamic>? ?? [];
      for (final fac in facList) {
        final m = fac as Map<String, dynamic>;
        final leaderName = m['leaderName'] as String?;
        final faction = await _facRepo.createFaction(
          workId: workId,
          name: m['name'] as String? ?? '未命名',
          type: m['type'] as String?,
          description: m['description'] as String?,
          traits: (m['traits'] as List<dynamic>?)?.cast<String>(),
          leaderId: leaderName != null ? nameToCharId[leaderName] : null,
        );
        // Add members
        final memberNames = (m['memberNames'] as List<dynamic>?)?.cast<String>() ?? [];
        for (final memberName in memberNames) {
          final memberId = nameToCharId[memberName];
          if (memberId != null) {
            try {
              await _facRepo.addMember(factionId: faction.id, characterId: memberId);
            } catch (_) {}
          }
        }
        factions.add((id: faction.id, name: faction.name));
      }
      c.add(NovelPhaseProgress(NovelPhase.entityCreation, step: 3, total: 3, detail: '已创建 ${factions.length} 个势力'));
    }

    c.add(NovelPhaseDone(NovelPhase.entityCreation));
    return _EntityData(locations: locations, items: items, factions: factions);
  }

  // ── Phase 5: Plot Planning ──

  Future<_OutlineData> _phasePlotPlanning(
    String workId,
    List<_CharEntry> chars,
    _WorldData world,
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.plotPlanning, steps: 2));
    final charDesc = FullNovelPromptBuilder.buildCharacterBioSummary(
      chars.map((e) => (name: e.name, tier: e.tier, bio: e.bio)),
    );
    final prompt = FullNovelPromptBuilder.buildPlotPlanningPrompt(
      title: request.title,
      genre: request.genre,
      chapterCount: request.chapterCount,
      worldRaw: world.raw,
      characterDescription: charDesc,
    );

    final response = await _callAI(prompt, AIFunction.chat, ModelTier.thinking);
    final jsonStr = FullNovelParsing.extractJsonArray(response);
    final outlines = <ChapterOutline>[];

    if (jsonStr != null) {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        outlines.add(ChapterOutline(
          index: (m['index'] as num?)?.toInt() ?? outlines.length + 1,
          title: m['title'] as String? ?? '第${outlines.length + 1}章',
          plotSummary: m['plotSummary'] as String? ?? '',
          keyEvents: m['keyEvents'] as String? ?? '',
          hook: m['hook'] as String? ?? '',
        ));
      }
    }

    c.add(NovelPhaseProgress(NovelPhase.plotPlanning, step: 1, total: 2, detail: '大纲已生成'));

    // Save outline as inspiration
    final outlineText = FullNovelPromptBuilder.buildOutlineText(outlines);
    await _insRepo.create(
      title: '${request.title} - 章节大纲',
      content: outlineText,
      workId: workId,
      category: 'reference',
      tags: ['大纲', request.genre],
    );

    c.add(NovelPhaseProgress(NovelPhase.plotPlanning, step: 2, total: 2, detail: '大纲已保存'));
    c.add(NovelPhaseDone(NovelPhase.plotPlanning));
    return _OutlineData(outlines);
  }

  // ── Phase 6: Chapter Writing ──

  Future<List<String>> _phaseChapterWriting(
    String workId,
    String volumeId,
    _OutlineData outline,
    List<_CharEntry> chars,
    _WorldData world,
    FullNovelRequest request,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.chapterWriting, steps: request.chapterCount));

    // Build story context for BatchChapterOrchestrator
    final charDesc = FullNovelPromptBuilder.buildStoryCharacterSummary(
      chars.map((e) => (name: e.name, tier: e.tier)),
    );
    final outlineDesc = FullNovelPromptBuilder.buildOutlineDescription(
      outline.outlines,
    );

    final storyContext = FullNovelPromptBuilder.buildStoryContext(
      title: request.title,
      genre: request.genre,
      style: request.style,
      characterDescription: charDesc,
      worldRaw: world.raw,
      outlineDescription: outlineDesc,
    );

    final batchRequest = BatchChapterRequest(
      workId: workId,
      volumeId: volumeId,
      chapterCount: request.chapterCount,
      storyContext: storyContext,
      genre: request.genre,
      style: request.style,
      wordsPerChapter: request.wordsPerChapter,
    );

    final chapterIds = <String>[];

    // Run BatchChapterOrchestrator and translate events
    await for (final event in _batch.execute(batchRequest)) {
      if (_cancelled) break;

      switch (event) {
        case BatchPhaseStart():
          // Don't emit new NovelPhaseStart — we already did
          break;
        case BatchChapterProgress():
          c.add(NovelPhaseProgress(
            NovelPhase.chapterWriting,
            step: event.completed,
            total: event.total,
            detail: event.title,
          ));
        case BatchSingleChapterDone():
          if (event.chapterId != null) {
            chapterIds.add(event.chapterId!);
          }
        case BatchAllComplete():
          break;
        case BatchChapterError():
          c.add(NovelError(event.error, phase: NovelPhase.chapterWriting));
      }
    }

    c.add(NovelPhaseDone(NovelPhase.chapterWriting));
    return chapterIds;
  }

  // ── Phase 7: POV Generation ──

  Future<void> _phasePOV(
    String workId,
    List<String> chapterIds,
    List<_CharEntry> chars,
    StreamController<NovelEvent> c,
  ) async {
    // Select up to 3 chapters: first, middle-climax, and one other

    final supportings = chars.where((e) =>
      e.tier == CharacterTier.supporting).toList();
    if (supportings.isEmpty) {
      c.add(NovelPhaseDone(NovelPhase.povGeneration));
      return;
    }

    final selectedChapters = FullNovelParsing.selectPovChapterIndices(
      chapterIds.length,
    );
    c.add(NovelPhaseStart(NovelPhase.povGeneration, steps: selectedChapters.length));

    for (var i = 0; i < selectedChapters.length; i++) {
      if (_cancelled) break;
      final chIdx = selectedChapters[i];
      if (chIdx >= chapterIds.length) continue;

      final chapterId = chapterIds[chIdx];
      final chapter = await _chapRepo.getChapterById(chapterId);
      if (chapter?.content == null) continue;

      final supportingChar = supportings[i % supportings.length];
      final character = await _charRepo.getCharacterById(supportingChar.id);
      if (character == null) continue;

      try {
        final povTask = POVTask(
          id: '',
          workId: workId,
          chapterId: chapterId,
          characterId: supportingChar.id,
          originalContent: chapter!.content!,
          config: const POVConfig(
            mode: POVMode.supplement,
            style: POVStyle.firstPerson,
            keepDialogue: true,
            addInnerThoughts: true,
            expandObservations: true,
            emotionalIntensity: 0.7,
            useCharacterVoice: true,
          ),
          status: POVTaskStatus.pending,
          createdAt: DateTime.now(),
        );

        final result = await _povService.generatePOV(
          task: povTask,
          character: character,
        );

        if (result.generatedContent != null && result.generatedContent!.isNotEmpty) {
          await _insRepo.create(
            title: '${supportingChar.name}视角 - ${chapter.title}',
            content: result.generatedContent!,
            workId: workId,
            category: 'scene_fragment',
            tags: ['pov', supportingChar.name],
          );
        }
      } catch (_) {
        // POV generation failure is non-fatal
      }

      c.add(NovelPhaseProgress(
        NovelPhase.povGeneration,
        step: i + 1,
        total: selectedChapters.length,
        detail: '${supportingChar.name}视角 - 第${chIdx + 1}章',
      ));
    }

    c.add(NovelPhaseDone(NovelPhase.povGeneration));
  }

  // ── Phase 8: Quality Checks ──

  Future<String> _phaseQualityCheck(
    String workId,
    List<String> chapterIds,
    List<_CharEntry> chars,
    StreamController<NovelEvent> c,
  ) async {
    c.add(NovelPhaseStart(NovelPhase.qualityCheck, steps: 3));

    // Gather all chapter content
    final chapters = await Future.wait(
      chapterIds.map((id) => _chapRepo.getChapterById(id)),
    );
    final content = chapters
        .where((c) => c?.content != null)
        .map((c) => '## ${c!.title}\n${c.content}')
        .join('\n\n');

    if (content.trim().isEmpty) {
      c.add(NovelPhaseDone(NovelPhase.qualityCheck));
      return '无章节内容可供检查。';
    }

    final truncated = content.length > 8000 ? content.substring(0, 8000) : content;
    final mainChars = chars.where((e) =>
      e.tier == CharacterTier.protagonist ||
      e.tier == CharacterTier.majorAntagonist,
    ).toList();
    final charDesc = FullNovelPromptBuilder.buildMainCharacterDescription(
      mainChars.map((e) => (name: e.name, bio: e.bio)),
    );

    // 1. Consistency check
    final consistencyPrompt = FullNovelPromptBuilder.buildConsistencyPrompt(truncated);
    final consistency = await _callAI(consistencyPrompt, AIFunction.consistencyCheck, ModelTier.middle);
    c.add(NovelPhaseProgress(NovelPhase.qualityCheck, step: 1, total: 3, detail: '一致性检查完成'));

    // 2. OOC detection
    final oocPrompt = FullNovelPromptBuilder.buildOocPrompt(
      characterDescription: charDesc,
      content: truncated,
    );
    final ooc = await _callAI(oocPrompt, AIFunction.oocDetection, ModelTier.middle);
    c.add(NovelPhaseProgress(NovelPhase.qualityCheck, step: 2, total: 3, detail: 'OOC 检查完成'));

    // 3. Pacing analysis
    final pacingPrompt = FullNovelPromptBuilder.buildPacingPrompt(truncated);
    final pacing = await _callAI(pacingPrompt, AIFunction.pacingAnalysis, ModelTier.middle);
    c.add(NovelPhaseProgress(NovelPhase.qualityCheck, step: 3, total: 3, detail: '节奏分析完成'));

    // Combine into report
    final report = FullNovelPromptBuilder.buildQualityReport(
      consistency: consistency,
      ooc: ooc,
      pacing: pacing,
    );

    await _insRepo.create(
      title: '${chars.firstOrNull?.name ?? ''}小说质量审查报告',
      content: report,
      workId: workId,
      category: 'reference',
      tags: ['审查', '质量分析'],
    );

    c.add(NovelPhaseDone(NovelPhase.qualityCheck));
    return report;
  }

  // ── Helpers ──

  Future<String> _callAI(String prompt, AIFunction function, ModelTier tier) async {
    final response = await _ai.generate(
      prompt: prompt,
      config: AIRequestConfig(
        function: function,
        userPrompt: prompt,
        overrideTier: tier,
        useCache: false,
        stream: false,
      ),
    );
    return response.content;
  }

  Future<int> _countWords(List<String> chapterIds) async {
    final chapters = await Future.wait(
      chapterIds.map((id) => _chapRepo.getChapterById(id)),
    );
    var total = 0;
    for (final c in chapters) {
      total += c?.wordCount ?? 0;
    }
    return total;
  }

}
