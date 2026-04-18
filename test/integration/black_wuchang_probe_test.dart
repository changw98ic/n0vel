@Tags(['integration'])
library;

import 'dart:convert';
// dart:ffi removed
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:writing_assistant/core/config/app_env.dart';
// sqlite3/open.dart removed (v3.x)

import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/context/context_manager.dart';
import 'package:writing_assistant/core/services/ai/models/model_config.dart'
    as core_model;
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/ai/models/provider_config.dart';
import 'package:writing_assistant/core/services/ai/tools/create_chapter_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_character_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_inspiration_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_relationship_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_volume_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_work_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/list_volumes_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/list_works_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_registry.dart';
import 'package:writing_assistant/core/services/chat_service.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart'
    as feature_model;
import 'package:writing_assistant/features/chat/data/chat_repository.dart';
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/inspiration/data/inspiration_repository.dart';
import 'package:writing_assistant/features/settings/data/character_repository.dart';
import 'package:writing_assistant/features/settings/data/relationship_repository.dart';
import 'package:writing_assistant/features/settings/domain/character.dart'
    as character_domain;
import 'package:writing_assistant/features/settings/domain/relationship.dart'
    as relationship_domain;
import 'package:writing_assistant/features/work/data/volume_repository.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';

const _workName = '黑神话：无常';

String get _apiKey => AppEnv.testAiApiKey;
String get _endpoint => AppEnv.testAiEndpoint;
String get _modelName => AppEnv.testAiModel;

// sqlite3 loading removed

class ProbeAIConfigRepository extends AIConfigRepository {
  final core_model.ModelConfig modelConfig;
  final ProviderConfig providerConfig;

  ProbeAIConfigRepository({
    required this.modelConfig,
    required this.providerConfig,
  });

  @override
  Future<core_model.ModelConfig?> getCoreModelConfig(
    feature_model.ModelTier tier,
  ) async {
    return modelConfig.copyWith(
      id: 'probe_${tier.name}_$_modelName',
      tier: switch (tier) {
        feature_model.ModelTier.thinking => ModelTier.thinking,
        feature_model.ModelTier.middle => ModelTier.middle,
        feature_model.ModelTier.fast => ModelTier.fast,
      },
    );
  }

  @override
  Future<ProviderConfig?> getCoreProviderConfig(feature_model.ModelTier tier) {
    return Future.value(providerConfig);
  }

  @override
  Future<feature_model.ModelTier?> getFunctionOverrideTier(
    String functionKey,
  ) async {
    return null;
  }
}

void main() {
  setUpAll(() {});

  test(
    'probe black myth wuchang long-form chat creation',
    () async {
      Get.reset();
      final tempDir = await Directory.systemTemp.createTemp(
        'black_wuchang_probe_',
      );
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}probe.db');
      final db = AppDatabase.connect(
        DatabaseConnection(NativeDatabase(dbFile)),
      );

      try {
        final providerConfig = ProviderConfig(
          id: 'probe_provider',
          type: core_model.AIProviderType.openai,
          name: 'Local LM Studio',
          apiKey: _apiKey,
          apiEndpoint: _endpoint,
          timeoutSeconds: 1800,
          maxRetries: 1,
        );

        final modelConfig = core_model.ModelConfig(
          id: 'probe_model',
          tier: ModelTier.thinking,
          displayName: _modelName,
          providerType: 'openai',
          modelName: _modelName,
          temperature: 0.4,
          maxOutputTokens: 8192,
        );

        Get.put<AppDatabase>(db);
        Get.put<AIConfigRepository>(
          ProbeAIConfigRepository(
            modelConfig: modelConfig,
            providerConfig: providerConfig,
          ),
        );

        final aiService = AIService();
        final contextManager = ContextManager(aiService: aiService);
        final toolRegistry = ToolRegistry()..clear();

        final workRepo = WorkRepository(db);
        final volumeRepo = VolumeRepository(db);
        final chapterRepo = ChapterRepository(db);
        final characterRepo = CharacterRepository(db);
        final relationshipRepo = RelationshipRepository(db);
        final inspirationRepo = InspirationRepository(db);
        final chatRepo = ChatRepository(db);

        toolRegistry.register(
          CreateWorkTool(
            createFn: (name, {type, description, targetWords}) async {
              final work = await workRepo.createWork(
                CreateWorkParams(
                  name: name,
                  type: type,
                  description: description,
                  targetWords: targetWords,
                ),
              );
              return (id: work.id, name: work.name);
            },
          ),
        );

        toolRegistry.register(
          CreateVolumeTool(
            createFn: (workId, name, {sortOrder = 0}) async {
              final volume = await volumeRepo.createVolume(
                workId: workId,
                name: name,
                sortOrder: sortOrder,
              );
              return (id: volume.id, name: volume.name);
            },
          ),
        );

        toolRegistry.register(
          CreateChapterTool(
            createFn:
                (workId, volumeId, title, {sortOrder = 0, content}) async {
                  final chapter = await chapterRepo.createOrGetChapterByTitle(
                    workId: workId,
                    volumeId: volumeId,
                    title: title,
                    sortOrder: sortOrder,
                  );
                  if (content != null && content.trim().isNotEmpty) {
                    await chapterRepo.updateContent(
                      chapter.id,
                      content.trim(),
                      content.trim().length,
                    );
                  }
                  return (id: chapter.id, title: chapter.title);
                },
          ),
        );

        toolRegistry.register(
          CreateCharacterTool(
            createFn:
                (
                  workId,
                  name,
                  tier, {
                  aliases,
                  gender,
                  age,
                  identity,
                  bio,
                }) async {
                  final character = await characterRepo.createCharacter(
                    character_domain.CreateCharacterParams(
                      workId: workId,
                      name: name,
                      tier: character_domain.CharacterTier.values.firstWhere(
                        (t) => t.name.toLowerCase() == tier.toLowerCase(),
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
          ),
        );

        toolRegistry.register(
          CreateRelationshipTool(
            createFn: (workId, characterAId, characterBId, relationType) async {
              final relation = await relationshipRepo.createRelationship(
                workId: workId,
                characterAId: characterAId,
                characterBId: characterBId,
                relationType: relationship_domain.RelationType.values
                    .firstWhere(
                      (t) => t.name.toLowerCase() == relationType.toLowerCase(),
                      orElse: () => relationship_domain.RelationType.neutral,
                    ),
              );
              return (
                id: relation.id,
                relationType: relation.relationType.name,
              );
            },
          ),
        );

        toolRegistry.register(
          CreateInspirationTool(
            createFn:
                ({
                  required title,
                  required content,
                  workId,
                  required category,
                  tags,
                  source,
                }) async {
                  final inspiration = await inspirationRepo.create(
                    title: title,
                    content: content,
                    workId: workId,
                    category: category,
                    tags: tags,
                    source: source,
                  );
                  return (id: inspiration.id, title: inspiration.title);
                },
          ),
        );

        toolRegistry.register(
          ListWorksTool(
            listFn: () async {
              final works = await workRepo.getAllWorks();
              return works
                  .map(
                    (w) => {'id': w.id, 'name': w.name, 'type': w.type ?? ''},
                  )
                  .toList();
            },
          ),
        );

        toolRegistry.register(
          ListVolumesTool(
            listFn: (workId) async {
              final volumes = await volumeRepo.getVolumesByWorkId(workId);
              return volumes
                  .map(
                    (v) => {
                      'id': v.id,
                      'name': v.name,
                      'sort_order': v.sortOrder.toString(),
                    },
                  )
                  .toList();
            },
          ),
        );

        final agentService = AgentService(
          aiService: aiService,
          toolRegistry: toolRegistry,
          contextManager: contextManager,
        );
        
        final chatService = ChatService(
          aiService: aiService,
          contextManager: contextManager,
          chatRepository: chatRepo,
          
          agentService: agentService,
        );

        final conversation = await chatService.createConversation(
          title: '黑神话无常压力测试',
          source: 'probe',
        );

        Future<void> runTurn(String message, {required String workId}) async {
          print('\n===== TURN =====\n${_clip(message, 240)}');
          final stream = chatService.sendMessageStreamWithTools(
            conversationId: conversation.id,
            userMessage: message,
            workId: workId,
          );

          String? lastError;
          await for (final event in stream) {
            switch (event) {
              case ChatThinking(:final thought):
                print('[thinking] ${_clip(thought, 180)}');
              case ChatToolStatus(:final toolName, :final statusMessage):
                print('[tool] $toolName :: $statusMessage');
              case ChatToolResult(
                :final toolName,
                :final summary,
                :final success,
              ):
                print(
                  '[tool-result] $toolName :: ${success ? "OK" : "FAIL"} :: ${_clip(summary, 220)}',
                );
              case ChatChunk(:final chunk):
                print('[chunk] ${_clip(chunk, 120)}');
              case ChatComplete(:final fullContent):
                print('[complete] ${_clip(fullContent, 320)}');
              case ChatError(:final error):
                lastError = error;
                print('[error] $error');
              case ChatEntityProposal():
                break;
              case ChatBatchProgress():
                break;
              case ChatBatchChapterDone():
                break;
              case ChatBatchComplete():
                break;
            }
          }

          expect(lastError, equals(null), reason: '对话回合出现错误: $lastError');
        }

        const chapterBeats = <String>[
          '第一章写男主车祸身亡、魂魄离体、第一次被鬼差押往地府，结尾揭示生死簿上他本应十六岁就死。',
          '第二章写地府审判，主簿发现他是漏网之鱼，宣判要经历十年涤罪，押送鬼差提出让他带罪上岗。',
          '第三章写男主第一次以鬼差临时工身份执行勾魂任务，体验第一个被害者视角，建立赎罪机制。',
          '第四章写他在执行任务时发现自己多活十年的第一条线索，怀疑有人改动过阳寿簿。',
          '第五章写第二段重要被害者记忆，强化他的负罪感，并让他与押送鬼差的关系明显拉近。',
          '第六章写男主调查十六岁那年的旧案，找到与自己命格被改有关的人物或证物。',
          '第七章写地府内部阻力或追查者出现，让主簿、鬼差、男主三方立场更加复杂。',
          '第八章写真相逼近，男主在赎罪与自证之间做艰难选择，并补一段关键配角的反向视角信息。',
          '第九章写他完成第十年涤罪的最后一环，查明自己多活十年的真正原因与幕后代价。',
          '第十章写最终告别、功过裁定、投胎转世，情感收束但保留余韵。',
        ];

        await runTurn('''
请直接使用工具创建作品，不要只给建议。

作品名：$_workName
题材：中式志怪、地府悬疑、成长赎罪

请在这一回合完成这些事：
1. 创建作品。
2. 保存一份完整世界设定素材，分类用 worldbuilding。
3. 保存一份剧情总纲素材，概括 10 章主线。
4. 创建至少 4 个角色，至少包含：男主、押送他的鬼差、地府主簿、与多活十年真相有关的重要角色。
5. 创建至少 2 条关系。
6. 创建第一卷，卷名贴合“漏命十年、地府赎罪、追查真相”。
7. 再保存 1 条配角视角相关素材。

故事基础设定：
一个本该在十六岁时就死去的男子，在二十六岁时才车祸身亡。到地府投胎时被发现是漏网之鱼，主簿判决他必须经历被害者记忆整整十年进行涤罪。押送他的鬼差不忍心，提议让他成为鬼差临时工，带罪上岗，打工赎罪。故事要围绕他找到自己多活十年的原因、完成十年赎罪生活、最终成功投胎转世。
''', workId: '');

        final worksAfterSetup = await workRepo.getAllWorks();
        final createdWork = worksAfterSetup.firstWhere(
          (w) => w.name.contains(_workName),
          orElse: () => throw StateError('未创建目标作品'),
        );

        for (var i = 0; i < chapterBeats.length; i++) {
          await runTurn('''
请继续在当前作品中直接创建第${i + 1}章，必须真实调用 create_chapter 写入正文 content。

硬性要求：
1. 正文不少于 4000 字。
2. 标题格式请使用“第${i + 1}章：自拟标题”。
3. 必须承接前文，不要重置世界观。
4. 结尾要给下一章留钩子。

本章任务：
${chapterBeats[i]}
''', workId: createdWork.id);
        }

        final works = await workRepo.getAllWorks();
        final targetWork = works
            .where((w) => w.name.contains(_workName))
            .toList();
        final finalWork = targetWork.isEmpty ? null : targetWork.first;

        final volumes = finalWork == null
            ? const []
            : await volumeRepo.getVolumesByWorkId(finalWork.id);
        final chapters = finalWork == null
            ? const []
            : await chapterRepo.getChaptersByWorkId(finalWork.id);
        final characters = finalWork == null
            ? const []
            : await characterRepo.getCharactersByWorkId(finalWork.id);
        final relationships = finalWork == null
            ? const []
            : await relationshipRepo.getRelationshipsByWorkId(finalWork.id);
        final inspirations = finalWork == null
            ? const []
            : await inspirationRepo.getByWorkId(finalWork.id);

        final chapterLengths = chapters
            .map((c) => (c.content ?? '').trim().length)
            .toList();
        final shortChapters = <Map<String, dynamic>>[];
        for (final chapter in chapters) {
          final length = (chapter.content ?? '').trim().length;
          if (length < 4000) {
            shortChapters.add({'title': chapter.title, 'length': length});
          }
        }

        final worldbuildingCount = inspirations
            .where((i) => i.category == 'worldbuilding')
            .length;
        final supportingPovCount = inspirations
            .where(
              (i) =>
                  i.category == 'scene_fragment' ||
                  i.category == 'dialogue_snippet' ||
                  i.category == 'character_sketch' ||
                  i.title.contains('视角') ||
                  i.content.contains('视角'),
            )
            .length;

        final acceptance = {
          'has_work': finalWork != null,
          'worldbuilding_saved': worldbuildingCount >= 1,
          'supporting_pov_saved': supportingPovCount >= 1,
          'character_count_gte_4': characters.length >= 4,
          'relationship_count_gte_2': relationships.length >= 2,
          'volume_count_gte_1': volumes.isNotEmpty,
          'chapter_count_gte_10': chapters.length >= 10,
          'all_chapters_gte_4000': shortChapters.isEmpty && chapters.isNotEmpty,
        };

        final summary = {
          'model': _modelName,
          'endpoint': _endpoint,
          'work_found': finalWork?.name,
          'work_id': finalWork?.id,
          'volume_count': volumes.length,
          'chapter_count': chapters.length,
          'character_count': characters.length,
          'relationship_count': relationships.length,
          'inspiration_count': inspirations.length,
          'worldbuilding_count': worldbuildingCount,
          'supporting_pov_count': supportingPovCount,
          'min_chapter_length': chapterLengths.isEmpty
              ? 0
              : chapterLengths.reduce((a, b) => a < b ? a : b),
          'max_chapter_length': chapterLengths.isEmpty
              ? 0
              : chapterLengths.reduce((a, b) => a > b ? a : b),
          'short_chapters': shortChapters,
          'chapter_titles': chapters.map((c) => c.title).toList(),
          'acceptance': acceptance,
        };

        print(
          '===== BLACK WUCHANG SUMMARY =====\n'
          '${const JsonEncoder.withIndent('  ').convert(summary)}',
        );

        expect(finalWork, isNotNull, reason: '作品未创建');
        expect(worldbuildingCount, greaterThanOrEqualTo(1), reason: '世界设定未保存');
        expect(
          supportingPovCount,
          greaterThanOrEqualTo(1),
          reason: '配角视角素材未保存',
        );
        expect(characters.length, greaterThanOrEqualTo(4), reason: '角色数量不足');
        expect(
          relationships.length,
          greaterThanOrEqualTo(2),
          reason: '角色关系数量不足',
        );
        expect(volumes, isNotEmpty, reason: '卷未创建');
        expect(chapters.length, greaterThanOrEqualTo(10), reason: '章节数量不足 10');
        expect(shortChapters, isEmpty, reason: '存在少于 4000 字的章节');
      } finally {
        ToolRegistry().clear();
        await db.close();
        Get.reset();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

String _clip(String text, int max) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= max) return normalized;
  return '${normalized.substring(0, max)}...';
}
