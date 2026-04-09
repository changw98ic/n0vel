import 'package:get/get.dart';

import '../database/database.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/agent/agent_service.dart';
import '../services/ai/context/context_manager.dart';
import '../services/character_simulation_service.dart';
import '../services/writing_assist_service.dart';
import '../services/ai/tools/analyze_tool.dart';
import '../services/ai/tools/check_consistency_tool.dart';
import '../services/ai/tools/create_chapter_tool.dart';
import '../services/ai/tools/create_character_tool.dart';
import '../services/ai/tools/create_faction_tool.dart';
import '../services/ai/tools/create_inspiration_tool.dart';
import '../services/ai/tools/create_item_tool.dart';
import '../services/ai/tools/create_location_tool.dart';
import '../services/ai/tools/create_relationship_tool.dart';
import '../services/ai/tools/create_volume_tool.dart';
import '../services/ai/tools/create_work_tool.dart';
import '../services/ai/tools/extract_tool.dart';
import '../services/ai/tools/generate_tool.dart';
import '../services/ai/tools/search_tool.dart';
import '../services/ai/tools/tool_registry.dart';
import '../services/ai/tools/list_works_tool.dart';
import '../services/ai/tools/list_volumes_tool.dart';
import '../services/ai/tools/update_chapter_content_tool.dart';
import '../services/export_service.dart';
import '../services/search_service.dart';
import '../services/stats_service.dart';
import '../services/workflow_service.dart';
import '../../features/ai_config/data/ai_config_repository.dart';
import '../../features/editor/data/chapter_repository.dart';
import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/faction_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/settings/data/relationship_repository.dart';
import '../../features/settings/domain/character.dart' as character_domain;
import '../../features/settings/domain/relationship.dart' as relationship_domain;
import '../../features/work/data/work_repository.dart';
import '../../features/work/data/volume_repository.dart';
import '../../features/workflow/data/workflow_repository.dart';
import '../../features/workflow/data/workflow_execution_service.dart';
import '../../features/pov_generation/data/pov_repository.dart';
import '../../features/pov_generation/data/pov_generation_service.dart';
import '../../features/reading_mode/data/reading_service.dart';
import '../../features/statistics/data/statistics_service.dart';
import '../../features/story_arc/data/story_arc_repository.dart';
import '../services/ai/models/model_tier.dart';
import '../services/writing_stats_service.dart';
import '../services/chapter_version_service.dart';
import '../services/enhanced_export_service.dart';
import '../../features/inspiration/data/inspiration_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import '../services/chat_service.dart';
import '../services/extraction_service.dart';
import '../services/entity_creation_service.dart';
import '../../modules/ai_config/ai_config/ai_config_logic.dart';
import '../../features/timeline/data/timeline_repository.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Database
    Get.lazyPut<AppDatabase>(() => AppDatabase(), fenix: true);

    // AI Configuration
    Get.lazyPut<AIConfigRepository>(() => AIConfigRepository(), fenix: true);

    // Core AI Service
    Get.lazyPut<AIService>(() => AIService(), fenix: true);

    // Repositories
    final db = Get.find<AppDatabase>();
    Get.lazyPut<WorkRepository>(() => WorkRepository(db), fenix: true);
    Get.lazyPut<VolumeRepository>(() => VolumeRepository(db), fenix: true);
    Get.lazyPut<ChapterRepository>(() => ChapterRepository(db), fenix: true);
    Get.lazyPut<CharacterRepository>(() => CharacterRepository(db), fenix: true);
    Get.lazyPut<ItemRepository>(() => ItemRepository(db), fenix: true);
    Get.lazyPut<LocationRepository>(() => LocationRepository(db), fenix: true);
    Get.lazyPut<FactionRepository>(() => FactionRepository(db), fenix: true);
    Get.lazyPut<RelationshipRepository>(() => RelationshipRepository(db), fenix: true);
    Get.lazyPut<WorkflowRepository>(() => WorkflowRepository(db), fenix: true);
    Get.lazyPut<POVRepository>(() => POVRepository(db), fenix: true);

    // Core Services
    Get.lazyPut<SearchService>(() => SearchService(
      workRepository: Get.find(),
      chapterRepository: Get.find(),
      characterRepository: Get.find(),
      itemRepository: Get.find(),
      locationRepository: Get.find(),
      factionRepository: Get.find(),
    ), fenix: true);

    Get.lazyPut<StatsService>(() => StatsService(
      workRepository: Get.find(),
      chapterRepository: Get.find(),
    ), fenix: true);

    Get.lazyPut<ExportService>(() => ExportService(
      workRepository: Get.find(),
      volumeRepository: Get.find(),
      chapterRepository: Get.find(),
    ), fenix: true);

    Get.lazyPut<WorkflowService>(() => WorkflowService(
      aiExecutor: (node, context) async {
        final aiService = Get.find<AIService>();
        // Resolve {variable} placeholders from workflow context
        var resolvedPrompt = node.promptTemplate;
        for (final entry in context.variables.entries) {
          resolvedPrompt = resolvedPrompt.replaceAll(
            '{${entry.key}}',
            entry.value.toString(),
          );
        }
        final response = await aiService.generate(
          prompt: resolvedPrompt,
          config: AIRequestConfig(
            function: AIFunction.continuation,
            userPrompt: resolvedPrompt,
            overrideTier: _parseModelTier(node.modelTier),
            useCache: false,
            stream: false,
          ),
        );
        return WorkflowAIExecution(
          output: response.content,
          inputTokens: response.inputTokens,
          outputTokens: response.outputTokens,
        );
      },
      reviewHandler: (node, context) async {
        final config = context.get<Map<String, dynamic>>('config');
        final decision = config?.remove('reviewDecision');
        if (decision is bool) {
          return decision;
        }
        if (decision is String) {
          switch (decision.trim().toLowerCase()) {
            case 'approve':
            case 'approved':
            case 'pass':
            case 'passed':
            case 'true':
              return true;
            case 'reject':
            case 'rejected':
            case 'redo':
            case 'retry':
            case 'false':
              return false;
            default:
              return null;
          }
        }
        return null;
      },
    ), fenix: true);

    Get.lazyPut<WorkflowExecutionService>(() => WorkflowExecutionService(
      repository: Get.find(),
      workflowService: Get.find(),
    ), fenix: true);

    Get.lazyPut<POVGenerationService>(() => POVGenerationService(
      Get.find(),
    ), fenix: true);

    Get.lazyPut<ReadingService>(() => ReadingService(
      Get.find(),
    ), fenix: true);

    Get.lazyPut<StatisticsService>(() => StatisticsService(
      Get.find(),
    ), fenix: true);

    // Context Manager（上下文压缩）
    Get.lazyPut<ContextManager>(() => ContextManager(
      aiService: Get.find(),
    ), fenix: true);

    // Tool Registry（工具注册）
    Get.lazyPut<ToolRegistry>(() {
      final registry = ToolRegistry();
      final aiService = Get.find<AIService>();
      final searchService = Get.find<SearchService>();

      // 搜索工具
      registry.register(SearchTool.withSearchService(searchService));

      // 生成工具
      registry.register(GenerateTool(
        generateFn: (prompt, mode, params) async {
          final aiFunction = switch (mode) {
            'continuation' => AIFunction.continuation,
            'dialogue' => AIFunction.dialogue,
            _ => AIFunction.continuation,
          };
          final response = await aiService.generate(
            prompt: prompt,
            config: AIRequestConfig(
              function: aiFunction,
              userPrompt: prompt,
              useCache: false,
              stream: false,
            ),
          );
          return response.content;
        },
      ));

      // 分析工具
      registry.register(AnalyzeTool(
        analyzeFn: (content, analysisType, params) async {
          final function = switch (analysisType) {
            'style' => AIFunction.aiStyleDetection,
            'pacing' => AIFunction.pacingAnalysis,
            'perspective' => AIFunction.perspectiveCheck,
            _ => AIFunction.review,
          };
          final response = await aiService.generate(
            prompt: content,
            config: AIRequestConfig(
              function: function,
              userPrompt: content,
              useCache: false,
              stream: false,
            ),
          );
          return {'analysis': response.content};
        },
      ));

      // 一致性检查工具
      registry.register(CheckConsistencyTool(
        checkFn: (workId, checkType, params) async {
          final content = params?['content'] as String? ?? '';
          final function = switch (checkType) {
            'character' => AIFunction.oocDetection,
            'timeline' => AIFunction.timelineExtract,
            _ => AIFunction.consistencyCheck,
          };
          final prompt = content.isNotEmpty
              ? '作品ID: $workId\n检查类型: $checkType\n内容:\n$content'
              : '检查作品 $workId 的$checkType一致性';
          final response = await aiService.generate(
            prompt: prompt,
            config: AIRequestConfig(
              function: function,
              userPrompt: prompt,
              useCache: false,
              stream: false,
            ),
          );
          return {'result': response.content};
        },
      ));

      // 提取工具
      registry.register(ExtractTool(
        extractFn: (content, extractType, params) async {
          final response = await aiService.generate(
            prompt: '从以下文本中提取${extractType}设定信息:\n\n$content',
            config: AIRequestConfig(
              function: AIFunction.extraction,
              userPrompt: '从以下文本中提取${extractType}设定信息:\n\n$content',
              useCache: false,
              stream: false,
            ),
          );
          return {'extraction': response.content};
        },
      ));

      // ---- 查询类工具 ----

      // 列出所有作品
      registry.register(ListWorksTool(
        listFn: () async {
          final works = await Get.find<WorkRepository>().getAllWorks();
          return works
              .map((w) => {
                    'id': w.id,
                    'name': w.name,
                    'type': w.type ?? '',
                  })
              .toList();
        },
      ));

      // 列出作品下的卷
      registry.register(ListVolumesTool(
        listFn: (workId) async {
          final volumes =
              await Get.find<VolumeRepository>().getVolumesByWorkId(workId);
          return volumes
              .map((v) => {
                    'id': v.id,
                    'name': v.name,
                    'sort_order': v.sortOrder.toString(),
                  })
              .toList();
        },
      ));

      // ---- 创建类工具 ----

      // 创建作品
      registry.register(CreateWorkTool(
        createFn: (name, {type, description, targetWords}) async {
          final work = await Get.find<WorkRepository>().createWork(
            CreateWorkParams(
              name: name,
              type: type,
              description: description,
              targetWords: targetWords,
            ),
          );
          return (id: work.id, name: work.name);
        },
      ));

      // 创建卷
      registry.register(CreateVolumeTool(
        createFn: (workId, name, {sortOrder = 0}) async {
          final volume = await Get.find<VolumeRepository>().createVolume(
            workId: workId,
            name: name,
            sortOrder: sortOrder,
          );
          return (id: volume.id, name: volume.name);
        },
      ));

      // 创建章节
      registry.register(CreateChapterTool(
        createFn: (workId, volumeId, title, {sortOrder = 0, content}) async {
          final repo = Get.find<ChapterRepository>();
          final chapter = await repo.createChapter(
            workId: workId,
            volumeId: volumeId,
            title: title,
            sortOrder: sortOrder,
          );
          // 如果同时提供了内容，直接写入
          if (content != null && content.trim().isNotEmpty) {
            await repo.updateContent(
                chapter.id, content.trim(), content.trim().length);
          }
          return (id: chapter.id, title: chapter.title);
        },
      ));

      // 写入章节内容
      registry.register(UpdateChapterContentTool(
        updateFn: (chapterId, content, wordCount) async {
          await Get.find<ChapterRepository>()
              .updateContent(chapterId, content, wordCount);
        },
      ));

      // 创建角色
      registry.register(CreateCharacterTool(
        createFn: (workId, name, tier, {aliases, gender, age, identity, bio}) async {
          final character = await Get.find<CharacterRepository>().createCharacter(
            character_domain.CreateCharacterParams(
              workId: workId,
              name: name,
              tier: character_domain.CharacterTier.values.firstWhere(
                (t) => t.name == tier,
                orElse: () => character_domain.CharacterTier.supporting,
              ),
              aliases: aliases,
              gender: gender,
              age: age,
              identity: identity,
              bio: bio,
            ),
          );
          return (id: character.id, name: character.name, tier: character.tier.name);
        },
      ));

      // 创建角色关系
      registry.register(CreateRelationshipTool(
        createFn: (workId, characterAId, characterBId, relationType) async {
          final rel = await Get.find<RelationshipRepository>().createRelationship(
            workId: workId,
            characterAId: characterAId,
            characterBId: characterBId,
            relationType: relationship_domain.RelationType.values.firstWhere(
              (t) => t.name == relationType,
              orElse: () => relationship_domain.RelationType.neutral,
            ),
          );
          return (id: rel.id, relationType: rel.relationType.name);
        },
      ));

      // 创建物品
      registry.register(CreateItemTool(
        createFn: ({required workId, required name, type, rarity, description, abilities, holderId}) async {
          final item = await Get.find<ItemRepository>().createItem(
            workId: workId,
            name: name,
            type: type,
            rarity: rarity,
            description: description,
            abilities: abilities,
            holderId: holderId,
          );
          return (id: item.id, name: item.name);
        },
      ));

      // 创建地点
      registry.register(CreateLocationTool(
        createFn: ({required workId, required name, type, parentId, description, importantPlaces}) async {
          final location = await Get.find<LocationRepository>().createLocation(
            workId: workId,
            name: name,
            type: type,
            parentId: parentId,
            description: description,
            importantPlaces: importantPlaces,
          );
          return (id: location.id, name: location.name);
        },
      ));

      // 创建势力
      registry.register(CreateFactionTool(
        createFn: ({required workId, required name, type, description, traits, leaderId}) async {
          final faction = await Get.find<FactionRepository>().createFaction(
            workId: workId,
            name: name,
            type: type,
            description: description,
            traits: traits,
            leaderId: leaderId,
          );
          return (id: faction.id, name: faction.name);
        },
      ));

      // 创建素材/片段
      registry.register(CreateInspirationTool(
        createFn: ({required title, required content, workId, required category, tags, source}) async {
          final inspiration = await Get.find<InspirationRepository>().create(
            title: title,
            content: content,
            workId: workId,
            category: category,
            tags: tags,
            source: source,
          );
          return (id: inspiration.id, title: inspiration.title);
        },
      ));

      return registry;
    }, fenix: true);

    // Agent Service（ReAct 循环）
    Get.lazyPut<AgentService>(() => AgentService(
      aiService: Get.find(),
      toolRegistry: Get.find(),
      contextManager: Get.find(),
    ), fenix: true);

    // 写作辅助服务（续写/对话/场景描写）
    Get.lazyPut<WritingAssistService>(() => WritingAssistService(
      aiService: Get.find(),
    ), fenix: true);

    // 角色模拟服务（行为/对话/心理推演）
    Get.lazyPut<CharacterSimulationService>(() => CharacterSimulationService(
      aiService: Get.find(),
    ), fenix: true);

    // 故事弧线仓库（弧线/伏笔 CRUD）
    Get.lazyPut<StoryArcRepository>(() => StoryArcRepository(db), fenix: true);

    // 对话仓库
    Get.lazyPut<ChatRepository>(() => ChatRepository(db), fenix: true);

    // 对话服务
    Get.lazyPut<ChatService>(() => ChatService(
      aiService: Get.find(),
      contextManager: Get.find(),
      chatRepository: Get.find(),
      agentService: Get.find<AgentService>(),
    ), fenix: true);

    // 实体提取服务
    Get.lazyPut<ExtractionService>(() => ExtractionService(
      aiService: Get.find(),
      characterRepository: Get.find(),
      locationRepository: Get.find(),
      itemRepository: Get.find(),
    ), fenix: true);

    // 实体创建服务
    Get.lazyPut<EntityCreationService>(() => EntityCreationService(
      aiService: Get.find(),
      characterRepository: Get.find(),
      locationRepository: Get.find(),
      itemRepository: Get.find(),
      factionRepository: Get.find(),
    ), fenix: true);

    // 写作统计服务（会话/趋势/热力图）
    Get.lazyPut<WritingStatsService>(() => WritingStatsService(db), fenix: true);

    // 章节版本管理服务
    Get.lazyPut<ChapterVersionService>(() => ChapterVersionService(db), fenix: true);

    // 灵感素材仓库
    Get.lazyPut<InspirationRepository>(() => InspirationRepository(db), fenix: true);

    // 增强导出服务（TXT/Markdown/HTML）
    Get.lazyPut<EnhancedExportService>(() => EnhancedExportService(), fenix: true);

    // AI 设置页面逻辑（嵌入主 Shell）
    Get.lazyPut<AIConfigLogic>(() => AIConfigLogic(), fenix: true);

    // 时间线仓库
    Get.lazyPut<TimelineRepository>(() => TimelineRepository(db), fenix: true);
  }
}

ModelTier _parseModelTier(String value) {
  return switch (value.toLowerCase()) {
    'thinking' => ModelTier.thinking,
    'fast' => ModelTier.fast,
    _ => ModelTier.middle,
  };
}
