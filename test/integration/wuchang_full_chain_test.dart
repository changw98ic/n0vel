@Tags(['integration'])
library;


import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:writing_assistant/core/config/app_env.dart';

import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/context/context_manager.dart';
import 'package:writing_assistant/core/services/ai/models/model_config.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/ai/models/provider_config.dart';
import 'package:writing_assistant/core/services/ai/providers/openai_provider.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_registry.dart';
import 'package:writing_assistant/core/services/ai/tools/create_work_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_character_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_volume_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_chapter_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_location_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_faction_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_item_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/list_works_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/list_volumes_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/search_tool.dart';
import 'package:writing_assistant/core/services/writer_guidance_loader.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart'
    as feature_config;
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/settings/data/character_repository.dart';
import 'package:writing_assistant/features/settings/data/location_repository.dart';
import 'package:writing_assistant/features/settings/data/item_repository.dart';
import 'package:writing_assistant/features/settings/data/faction_repository.dart';
import 'package:writing_assistant/features/settings/domain/character.dart' as character_domain;
import 'package:writing_assistant/core/services/search_service.dart';
import 'package:writing_assistant/features/work/data/volume_repository.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';

// ─── 环境 ───

String get _apiKey =>
    AppEnv.testAiApiKey;
String get _endpoint => AppEnv.testAiEndpoint;
String get _modelName => AppEnv.testAiModel;

// sqlite3 loading removed






String get _realDbPath =>
    AppEnv.testDbPath;

ProviderConfig _makeProviderConfig() => ProviderConfig(
      id: 'test_provider',
      type: AIProviderType.openai,
      name: 'Test Provider',
      apiKey: _apiKey,
      apiEndpoint: _endpoint,
    );

ModelConfig _makeModelConfig({ModelTier tier = ModelTier.fast}) => ModelConfig(
      id: 'test_model_${tier.name}',
      tier: tier,
      displayName: 'Test ${tier.name}',
      providerType: 'openai',
      modelName: _modelName,
      temperature: 0.3,
      maxOutputTokens: 4096,
    );

class MockAIConfigRepository extends Mock implements AIConfigRepository {}

// ─── 角色设定 ───

const _characters = [
  {'name': '张影', 'tier': 'protagonist', 'gender': '男', 'bio': '灰无常。被系统误判的"窃命罪魂"，万化归墟体，先天混沌容器。混沌烙印在心口，锁魂链炼化为武器。信条："饿，就要吃。"'},
  {'name': '屠夫', 'tier': 'supporting', 'gender': '男', 'bio': '赵铁柱。为保护村民诛杀三十六名伪神信徒，被系统定性为凶犯。沉默的守护者，诛神之刃。绝境中主动献祭被吞噬。'},
  {'name': '老算盘', 'tier': 'supporting', 'gender': '男', 'bio': '陈账房。被定为贪墨赈灾款的贪官，实为查出伪神贪污被灭口。精算的懦夫，利用统计员身份窃取微量阴德为孙子续命。'},
  {'name': '小倩', 'tier': 'supporting', 'gender': '女', 'bio': '被生父献祭给伪河神"黑水将军"的溺死少女。诅咒载体，哼唱的童谣实为弑神咒残片。'},
  {'name': '噬心主簿', 'tier': 'majorAntagonist', 'gender': '男', 'bio': '判官副手，窃据判官位代理森罗殿。被KPI勒住的官僚，非天生恶人，而是被系统异化。'},
  {'name': '洛九川', 'tier': 'supporting', 'gender': '男', 'bio': '三百年前最后任白无常，搭档战死后携半截哭丧棒叛逃。研究不完善的小轮回收容冤魂。理想主义与逃兵耻辱永恒撕扯。'},
  {'name': '黑煞鬼将', 'tier': 'supporting', 'gender': '男', 'bio': '地府前线将领，张影前期上司。生前阳间名将，被朝廷与伪神坑杀。实用主义者，最终自爆掩护张影。'},
];

void main() {
  setUpAll(() {
    // sqlite3 loading removed
    registerFallbackValue(feature_config.ModelTier.fast);
    registerFallbackValue('');
  });

  group('黑神话：无常 — 全链路测试', () {
    late AppDatabase db;
    late WorkRepository workRepo;
    late VolumeRepository volumeRepo;
    late ChapterRepository chapterRepo;
    late CharacterRepository characterRepo;
    late LocationRepository locationRepo;
    late ItemRepository itemRepo;
    late FactionRepository factionRepo;
    late AIService aiService;
    late AgentService agentService;
    late ToolRegistry toolRegistry;
    late MockAIConfigRepository mockConfigRepo;

    setUp(() async {
      // 删除旧库，创建新库
      final file = File(_realDbPath);
      if (await file.exists()) {
        await file.delete();
      }
      db = AppDatabase.connect(
        DatabaseConnection(NativeDatabase(file)),
      );

      workRepo = WorkRepository(db);
      volumeRepo = VolumeRepository(db);
      chapterRepo = ChapterRepository(db);
      characterRepo = CharacterRepository(db);
      locationRepo = LocationRepository(db);
      itemRepo = ItemRepository(db);
      factionRepo = FactionRepository(db);

      // Mock AI 配置
      mockConfigRepo = MockAIConfigRepository();
      when(() => mockConfigRepo.getCoreModelConfig(any<feature_config.ModelTier>()))
          .thenAnswer((_) async => _makeModelConfig());
      when(() => mockConfigRepo.getCoreProviderConfig(any<feature_config.ModelTier>()))
          .thenAnswer((_) async => _makeProviderConfig());
      when(() => mockConfigRepo.getFunctionOverrideTier(any<String>()))
          .thenAnswer((_) async => null);

      Get.put<AIConfigRepository>(mockConfigRepo);

      // 注册真实服务
      aiService = AIService();

      toolRegistry = ToolRegistry();
      toolRegistry.clear();
      toolRegistry.register(CreateWorkTool(
        createFn: (name, {type, description, targetWords}) async {
          final w = await workRepo.createWork(CreateWorkParams(
            name: name, type: type, description: description, targetWords: targetWords,
          ));
          return (id: w.id, name: w.name);
        },
      ));
      toolRegistry.register(CreateVolumeTool(
        createFn: (workId, name, {sortOrder}) async {
          final v = await volumeRepo.createVolume(workId: workId, name: name, sortOrder: sortOrder);
          return (id: v.id, name: v.name);
        },
      ));
      toolRegistry.register(CreateChapterTool(
        createFn: (workId, volumeId, title, {sortOrder, content}) async {
          var ch = await chapterRepo.createOrGetChapterByTitle(
            workId: workId, volumeId: volumeId, title: title, sortOrder: sortOrder,
          );
          if (content != null && content.isNotEmpty) {
            await chapterRepo.updateContent(ch.id, content, content.length);
            ch = (await chapterRepo.getChapterById(ch.id))!;
          }
          return (id: ch.id, title: ch.title);
        },
      ));
      toolRegistry.register(CreateCharacterTool(
        createFn: (workId, name, tier, {aliases, gender, age, identity, bio}) async {
          final c = await characterRepo.createCharacter(character_domain.CreateCharacterParams(
            workId: workId, name: name,
            tier: character_domain.CharacterTier.values.firstWhere(
              (e) => e.name == tier, orElse: () => character_domain.CharacterTier.supporting),
            aliases: aliases, gender: gender, age: age, identity: identity, bio: bio,
          ));
          return (id: c.id, name: c.name, tier: c.tier.name);
        },
      ));
      toolRegistry.register(CreateLocationTool(
        createFn: ({required workId, required name, type, parentId, description, importantPlaces}) async {
          final loc = await locationRepo.createLocation(
            workId: workId, name: name, type: type, parentId: parentId,
            description: description, importantPlaces: importantPlaces,
          );
          return (id: loc.id, name: loc.name);
        },
      ));
      toolRegistry.register(CreateFactionTool(
        createFn: ({required workId, required name, type, description, traits, leaderId}) async {
          final fac = await factionRepo.createFaction(
            workId: workId, name: name, type: type, description: description,
            traits: traits, leaderId: leaderId,
          );
          return (id: fac.id, name: fac.name);
        },
      ));
      toolRegistry.register(CreateItemTool(
        createFn: ({required workId, required name, type, rarity, description, abilities, holderId}) async {
          final item = await itemRepo.createItem(
            workId: workId, name: name, type: type, rarity: rarity,
            description: description, abilities: abilities, holderId: holderId,
          );
          return (id: item.id, name: item.name);
        },
      ));
      toolRegistry.register(ListWorksTool(
        listFn: () async {
          final works = await workRepo.getAllWorks();
          return works.map((w) => {'id': w.id, 'name': w.name}).toList();
        },
      ));
      toolRegistry.register(ListVolumesTool(
        listFn: (workId) async {
          final vols = await volumeRepo.getVolumesByWorkId(workId);
          return vols.map((v) => {'id': v.id, 'name': v.name}).toList();
        },
      ));
      toolRegistry.register(SearchTool.withSearchService(SearchService(
        workRepository: workRepo,
        chapterRepository: chapterRepo,
        characterRepository: characterRepo,
        itemRepository: itemRepo,
        locationRepository: locationRepo,
        factionRepository: factionRepo,
      )));

      agentService = AgentService(
        aiService: aiService,
        toolRegistry: toolRegistry,
        contextManager: ContextManager(aiService: aiService),
      );
    });

    tearDown(() async {
      await db.close();
      Get.reset();
    });

    test('Step 1: 创建作品《黑神话：无常》', timeout: const Timeout(Duration(seconds: 120)), () async {
      final events = <AgentEvent>[];
      await for (final event in agentService.run(
        task: '请创建一部作品，名称为"黑神话：无常"，类型为"暗黑玄幻"，简介为"真神佛为抵御宇宙归墟潮息集体献祭，神位空悬。域外神魔窃据其位，建立僵化虚伪的统治秩序。被系统误判的窃命罪魂张影，以混沌之力吞噬一切，自封灰无常，向伪神宣战。"',
        workId: '',
        tier: ModelTier.middle,
      )) {
        events.add(event);
        if (event is AgentAction) {
          print('  [TOOL] ${event.toolName}(${event.input})');
        } else if (event is AgentObservation) {
          print('  [OBS] success=${event.result.success}');
        } else if (event is AgentResponse) {
          print('  [DONE] iterations=${event.iterations}, tokens=${event.totalInputTokens}/${event.totalOutputTokens}');
        } else if (event is AgentError) {
          print('  [ERROR] ${event.error}');
        }
      }

      // 验证：作品应该已创建
      final works = await workRepo.getAllWorks();
      print('\n=== 作品列表 ===');
      for (final w in works) {
        print('  ${w.name} | ${w.type} | ${w.currentWords}字');
      }
      expect(works, isNotEmpty, reason: '应至少创建一部作品');
      expect(works.first.name, contains('无常'), reason: '作品名应包含"无常"');
    });

    test('Step 2: 创建核心角色群像', timeout: const Timeout(Duration(seconds: 300)), () async {
      // 先确保有作品
      final works = await workRepo.getAllWorks();
      expect(works, isNotEmpty, reason: '需要先有作品');
      final workId = works.first.id;
      print('使用作品: ${works.first.name} ($workId)\n');

      // 分批创建角色（每批2-3个，避免 token 过多）
      final batches = <List<Map<String, String>>>[
        _characters.sublist(0, 3), // 张影、屠夫、老算盘
        _characters.sublist(3, 5), // 小倩、噬心主簿
        _characters.sublist(5),    // 洛九川、黑煞鬼将
      ];

      for (var i = 0; i < batches.length; i++) {
        final batch = batches[i];
        final charDesc = batch.map((c) =>
          '- ${c['name']}（${c['tier']}）：${c['bio']}'
        ).join('\n');

        print('--- 批次 ${i + 1}/${batches.length} ---');
        final events = <AgentEvent>[];
        await for (final event in agentService.run(
          task: '请在作品 $workId 中创建以下角色：\n$charDesc',
          workId: workId,
          tier: ModelTier.middle,
        )) {
          events.add(event);
          if (event is AgentAction) {
            print('  [TOOL] ${event.toolName}');
          } else if (event is AgentObservation) {
            print('  [OBS] success=${event.result.success}');
          } else if (event is AgentResponse) {
            print('  [DONE] iterations=${event.iterations}');
          } else if (event is AgentError) {
            print('  [ERROR] ${event.error}');
          }
        }
      }

      // 验证：角色应该已创建
      final characters = await characterRepo.getCharactersByWorkId(workId);
      print('\n=== 角色列表 ===');
      for (final c in characters) {
        print('  ${c.name} | ${c.tier.name} | ${c.gender ?? "未知"}');
      }
      expect(characters.length, greaterThanOrEqualTo(5), reason: '应至少创建5个角色');

      // 验证关键角色存在
      final names = characters.map((c) => c.name).toSet();
      expect(names, contains('张影'), reason: '主角张影必须存在');
    });

    test('Step 3: 创建第一卷和第一章大纲', timeout: const Timeout(Duration(seconds: 120)), () async {
      final works = await workRepo.getAllWorks();
      expect(works, isNotEmpty);
      final workId = works.first.id;

      final events = <AgentEvent>[];
      await for (final event in agentService.run(
        task: '请在作品 $workId 中创建一卷，名称为"第一卷：灰烬新生"。然后在该卷下创建第一章，标题为"灰烬"，正文内容为第一章的开篇：张影在车祸中死亡，被押送至森罗殿，被定罪为"窃命"。混沌烙印在心口觉醒，吞噬业火导致刑具宕机。',
        workId: workId,
        tier: ModelTier.middle,
      )) {
        events.add(event);
        if (event is AgentAction) {
          print('  [TOOL] ${event.toolName}');
        } else if (event is AgentObservation) {
          print('  [OBS] success=${event.result.success}');
        } else if (event is AgentResponse) {
          print('  [DONE] iterations=${event.iterations}');
        } else if (event is AgentError) {
          print('  [ERROR] ${event.error}');
        }
      }

      // 验证卷和章节
      final volumes = await volumeRepo.getVolumesByWorkId(workId);
      print('\n=== 卷列表 ===');
      for (final v in volumes) {
        print('  ${v.name}');
      }
      expect(volumes, isNotEmpty, reason: '应至少创建一卷');

      final chapters = await chapterRepo.getChaptersByWorkId(workId);
      print('\n=== 章节列表 ===');
      for (final ch in chapters) {
        print('  ${ch.title} | ${ch.wordCount}字 | ${ch.content?.substring(0, ch.content!.length.clamp(0, 50))}...');
      }
      expect(chapters, isNotEmpty, reason: '应至少创建一章');
      expect(chapters.first.content, isNotNull, reason: '章节内容不能为空');
      expect(chapters.first.content!.length, greaterThan(50), reason: '章节正文应超过50字');
    });

    test('Step 4: 搜索验证 — 数据完整性', timeout: const Timeout(Duration(seconds: 30)), () async {
      final works = await workRepo.getAllWorks();
      expect(works, isNotEmpty);
      final workId = works.first.id;

      // 搜索张影
      final chars = await characterRepo.getCharactersByWorkId(workId);
      print('\n=== 最终数据统计 ===');
      print('  作品数: ${(await workRepo.getAllWorks()).length}');
      print('  角色数: ${chars.length}');
      print('  卷数: ${(await volumeRepo.getVolumesByWorkId(workId)).length}');
      print('  章节数: ${(await chapterRepo.getChaptersByWorkId(workId)).length}');
      print('  总字数: ${works.first.currentWords}');

      // 搜索功能验证
      final searchResults = await chapterRepo.searchChapters(workId, '张影');
      print('  搜索"张影"命中章节: ${searchResults.length}');

      final charSearch = chars.where((c) => c.name.contains('张')).toList();
      print('  搜索"张"姓角色: ${charSearch.map((c) => c.name).join(", ")}');

      expect(chars.length, greaterThanOrEqualTo(5), reason: '最终角色数应>=5');
    });
  });
}
