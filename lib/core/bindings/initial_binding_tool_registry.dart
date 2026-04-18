import 'package:get/get.dart';

import '../../features/editor/data/chapter_repository.dart';
import '../../features/inspiration/data/inspiration_repository.dart';
import '../../features/settings/data/character_repository.dart';
import '../../features/settings/data/faction_repository.dart';
import '../../features/settings/data/item_repository.dart';
import '../../features/settings/data/location_repository.dart';
import '../../features/settings/data/relationship_repository.dart';
import '../../features/settings/domain/character.dart' as character_domain;
import '../../features/settings/domain/relationship.dart' as relationship_domain;
import '../../features/work/data/volume_repository.dart';
import '../../features/work/data/work_repository.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/models/model_tier.dart';
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
import '../services/ai/tools/list_volumes_tool.dart';
import '../services/ai/tools/list_works_tool.dart';
import '../services/ai/tools/search_tool.dart';
import '../services/ai/tools/tool_registry.dart';
import '../services/ai/tools/update_chapter_content_tool.dart';
import '../services/search_service.dart';

ToolRegistry createInitialToolRegistry() {
  final registry = ToolRegistry();
  final aiService = Get.find<AIService>();
  final searchService = Get.find<SearchService>();

  registry.register(SearchTool.withSearchService(searchService));

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

  registry.register(CheckConsistencyTool(
    checkFn: (workId, checkType, params) async {
      final content = params?['content'] as String? ?? '';
      final function = switch (checkType) {
        'character' => AIFunction.oocDetection,
        'timeline' => AIFunction.timelineExtract,
        _ => AIFunction.consistencyCheck,
      };
      final prompt = content.isNotEmpty
          ? '浣滃搧ID: $workId\n妫€鏌ョ被鍨? $checkType\n鍐呭:\n$content'
          : '妫€鏌ヤ綔鍝?$workId 鐨?checkType涓€鑷存€?';
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

  registry.register(ExtractTool(
    extractFn: (content, extractType, params) async {
      final prompt = '浠庝互涓嬫枃鏈腑鎻愬彇${extractType}璁惧畾淇℃伅:\n\n$content';
      final response = await aiService.generate(
        prompt: prompt,
        config: AIRequestConfig(
          function: AIFunction.extraction,
          userPrompt: prompt,
          useCache: false,
          stream: false,
        ),
      );
      return {'extraction': response.content};
    },
  ));

  registry.register(ListWorksTool(
    listFn: () async {
      final works = await Get.find<WorkRepository>().getAllWorks();
      return works
          .map((work) => {
                'id': work.id,
                'name': work.name,
                'type': work.type ?? '',
              })
          .toList();
    },
  ));

  registry.register(ListVolumesTool(
    listFn: (workId) async {
      final volumes =
          await Get.find<VolumeRepository>().getVolumesByWorkId(workId);
      return volumes
          .map((volume) => {
                'id': volume.id,
                'name': volume.name,
                'sort_order': volume.sortOrder.toString(),
              })
          .toList();
    },
  ));

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

  registry.register(CreateChapterTool(
    createFn: (workId, volumeId, title, {sortOrder = 0, content}) async {
      final repo = Get.find<ChapterRepository>();
      final chapter = await repo.createChapter(
        workId: workId,
        volumeId: volumeId,
        title: title,
        sortOrder: sortOrder,
      );
      if (content != null && content.trim().isNotEmpty) {
        await repo.updateContent(chapter.id, content.trim(), content.trim().length);
      }
      return (id: chapter.id, title: chapter.title);
    },
  ));

  registry.register(UpdateChapterContentTool(
    updateFn: (chapterId, content, wordCount) async {
      await Get.find<ChapterRepository>()
          .updateContent(chapterId, content, wordCount);
    },
  ));

  registry.register(CreateCharacterTool(
    createFn: (workId, name, tier,
        {aliases, gender, age, identity, bio}) async {
      final character = await Get.find<CharacterRepository>().createCharacter(
        character_domain.CreateCharacterParams(
          workId: workId,
          name: name,
          tier: character_domain.CharacterTier.values.firstWhere(
            (item) => item.name == tier,
            orElse: () => character_domain.CharacterTier.supporting,
          ),
          aliases: aliases,
          gender: gender,
          age: age,
          identity: identity,
          bio: bio,
        ),
      );
      return (
        id: character.id,
        name: character.name,
        tier: character.tier.name,
      );
    },
  ));

  registry.register(CreateRelationshipTool(
    createFn: (workId, characterAId, characterBId, relationType) async {
      final relationship =
          await Get.find<RelationshipRepository>().createRelationship(
        workId: workId,
        characterAId: characterAId,
        characterBId: characterBId,
        relationType: relationship_domain.RelationType.values.firstWhere(
          (item) => item.name == relationType,
          orElse: () => relationship_domain.RelationType.neutral,
        ),
      );
      return (id: relationship.id, relationType: relationship.relationType.name);
    },
  ));

  registry.register(CreateItemTool(
    createFn: ({
      required workId,
      required name,
      type,
      rarity,
      description,
      abilities,
      holderId,
    }) async {
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

  registry.register(CreateLocationTool(
    createFn: ({
      required workId,
      required name,
      type,
      parentId,
      description,
      importantPlaces,
    }) async {
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

  registry.register(CreateFactionTool(
    createFn: ({
      required workId,
      required name,
      type,
      description,
      traits,
      leaderId,
    }) async {
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

  registry.register(CreateInspirationTool(
    createFn: ({
      required title,
      required content,
      workId,
      required category,
      tags,
      source,
    }) async {
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
}
