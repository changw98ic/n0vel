import 'package:get/get.dart';

import '../../features/chat/data/chat_repository.dart';
import '../../features/editor/data/chapter_repository.dart';
import '../../features/inspiration/data/inspiration_repository.dart';
import '../../features/pov_generation/data/pov_generation_service.dart';
import '../../features/pov_generation/data/pov_repository.dart';
import '../../features/reading_mode/data/reading_service.dart';
import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/faction_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/settings/data/relationship_repository.dart';
import '../../features/statistics/data/statistics_service.dart';
import '../../features/story_arc/data/story_arc_repository.dart';
import '../../features/timeline/data/timeline_repository.dart';
import '../../features/work/data/volume_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../../features/workflow/data/workflow_execution_service.dart';
import '../../features/workflow/data/workflow_repository.dart';
import '../../features/workflow/data/workflow_task_runner.dart';
import '../../modules/ai_config/ai_config/ai_config_logic.dart';
import '../database/database.dart';
import '../services/ai/agent/agent_service.dart' show AgentService;
import '../services/ai/ai_service.dart';
import '../services/ai/context/context_manager.dart';
import '../services/ai/models/model_tier.dart' as ai_models;
import '../services/ai/tools/tool_registry.dart';
import '../services/chapter_version_service.dart';
import '../services/chat_service.dart';
import '../services/character_simulation_service.dart';
import '../services/enhanced_export_service.dart';
import '../services/entity_creation_service.dart';
import '../services/export_service.dart';
import '../services/extraction_service.dart';
import '../services/search_service.dart';
import '../services/stats_service.dart';
import '../services/workflow_service.dart';
import '../services/writing_assist_service.dart';
import '../services/writing_stats_service.dart';
import 'initial_binding_tool_registry.dart';

void registerInitialRepositories(AppDatabase db) {
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
  Get.lazyPut<StoryArcRepository>(() => StoryArcRepository(db), fenix: true);
  Get.lazyPut<ChatRepository>(() => ChatRepository(db), fenix: true);
  Get.lazyPut<InspirationRepository>(() => InspirationRepository(db), fenix: true);
  Get.lazyPut<TimelineRepository>(() => TimelineRepository(db), fenix: true);
}

void registerInitialServices(AppDatabase db) {
  Get.lazyPut<SearchService>(
    () => SearchService(
      workRepository: Get.find(),
      chapterRepository: Get.find(),
      characterRepository: Get.find(),
      itemRepository: Get.find(),
      locationRepository: Get.find(),
      factionRepository: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<StatsService>(
    () => StatsService(
      workRepository: Get.find(),
      chapterRepository: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<ExportService>(
    () => ExportService(
      workRepository: Get.find(),
      volumeRepository: Get.find(),
      chapterRepository: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<WorkflowService>(
    () => WorkflowService(
      aiExecutor: (node, context) async {
        final aiService = Get.find<AIService>();
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
            function: node.function,
            userPrompt: resolvedPrompt,
            overrideTier: parseInitialBindingModelTier(node.modelTier),
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
        final config = context.get('config');
        final configMap = config is Map<String, dynamic> ? config : null;
        final decision = configMap?.remove('reviewDecision');
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
      clarificationHandler: (node, context) async {
        final config = context.get('config');
        final configMap = config is Map<String, dynamic> ? config : null;
        final rawAnswersValue = configMap?['clarificationAnswers'];
        final rawAnswers = rawAnswersValue is Map
            ? Map<String, dynamic>.from(rawAnswersValue)
            : null;
        if (rawAnswers == null) {
          return null;
        }

        final scopedAnswers = rawAnswers[node.responseKey];
        if (scopedAnswers is Map) {
          return Map<String, dynamic>.from(scopedAnswers);
        }

        final fallbackAnswers = rawAnswers[node.id];
        if (fallbackAnswers is Map) {
          return Map<String, dynamic>.from(fallbackAnswers);
        }

        return null;
      },
    ),
    fenix: true,
  );

  Get.lazyPut<WorkflowExecutionService>(
    () => WorkflowExecutionService(
      repository: Get.find(),
      workflowService: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<WorkflowTaskRunner>(
    () => WorkflowTaskRunner(
      workflowRepository: Get.find(),
      workflowExecutionService: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<POVGenerationService>(() => POVGenerationService(Get.find()), fenix: true);
  Get.lazyPut<ReadingService>(() => ReadingService(Get.find()), fenix: true);
  Get.lazyPut<StatisticsService>(() => StatisticsService(Get.find()), fenix: true);
  Get.lazyPut<ContextManager>(() => ContextManager(aiService: Get.find()), fenix: true);
  Get.lazyPut<ToolRegistry>(() => createInitialToolRegistry(), fenix: true);

  Get.lazyPut<AgentService>(
    () => AgentService(
      aiService: Get.find(),
      toolRegistry: Get.find(),
      contextManager: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<WritingAssistService>(
    () => WritingAssistService(aiService: Get.find()),
    fenix: true,
  );

  Get.lazyPut<CharacterSimulationService>(
    () => CharacterSimulationService(aiService: Get.find()),
    fenix: true,
  );

  Get.lazyPut<ChatService>(
    () => ChatService(
      aiService: Get.find(),
      contextManager: Get.find(),
      chatRepository: Get.find(),
      agentService: Get.find<AgentService>(),
    ),
    fenix: true,
  );

  Get.lazyPut<ExtractionService>(
    () => ExtractionService(
      aiService: Get.find(),
      characterRepository: Get.find(),
      locationRepository: Get.find(),
      itemRepository: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<EntityCreationService>(
    () => EntityCreationService(
      aiService: Get.find(),
      characterRepository: Get.find(),
      locationRepository: Get.find(),
      itemRepository: Get.find(),
      factionRepository: Get.find(),
    ),
    fenix: true,
  );

  Get.lazyPut<WritingStatsService>(() => WritingStatsService(db), fenix: true);
  Get.lazyPut<ChapterVersionService>(() => ChapterVersionService(db), fenix: true);
  Get.lazyPut<EnhancedExportService>(() => EnhancedExportService(), fenix: true);
  Get.lazyPut<AIConfigLogic>(() => AIConfigLogic(), fenix: true);
}

ai_models.ModelTier parseInitialBindingModelTier(String value) {
  return switch (value.toLowerCase()) {
    'thinking' => ai_models.ModelTier.thinking,
    'fast' => ai_models.ModelTier.fast,
    _ => ai_models.ModelTier.middle,
  };
}
