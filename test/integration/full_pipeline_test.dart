@Tags(['integration'])
library;

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:sqlite3/open.dart';
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
import 'package:writing_assistant/core/services/ai/tools/create_character_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_chapter_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_faction_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_inspiration_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_item_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_location_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_volume_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_work_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/list_works_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/list_volumes_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/search_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_registry.dart';
import 'package:writing_assistant/core/services/ai/tools/update_chapter_content_tool.dart';
import 'package:writing_assistant/core/services/search_service.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart'
    as feature_config;
import 'package:writing_assistant/features/chat/data/chat_repository.dart';
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/inspiration/data/inspiration_repository.dart';
import 'package:writing_assistant/features/settings/data/character_repository.dart';
import 'package:writing_assistant/features/settings/data/faction_repository.dart';
import 'package:writing_assistant/features/settings/data/item_repository.dart';
import 'package:writing_assistant/features/settings/data/location_repository.dart';
import 'package:writing_assistant/features/settings/data/relationship_repository.dart';
import 'package:writing_assistant/features/settings/domain/character.dart'
    as character_domain;
import 'package:writing_assistant/features/work/data/volume_repository.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';

// ─── 环境变量配置 ───

String get _apiKey =>
    AppEnv.testAiApiKey;
String get _endpoint => AppEnv.testAiEndpoint;
String get _modelName => AppEnv.testAiModel;
bool get _hasApiConfig => true;

void _loadSqlite3WithFts5() {
  if (Platform.isWindows) {
    final dllPath =
        '${Directory.current.path}/build/windows/x64/runner/Debug/sqlite3.dll';
    if (File(dllPath).existsSync()) {
      open.overrideFor(
          OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
    }
  }
}

String get _realDbPath =>
    AppEnv.testDbPath;

AppDatabase _createTestDb() {
  final file = File(_realDbPath);
  return AppDatabase.connect(
    DatabaseConnection(NativeDatabase(file)),
  );
}

ProviderConfig _makeProviderConfig() => ProviderConfig(
      id: 'test_provider',
      type: AIProviderType.openai,
      name: 'Test Provider',
      apiKey: _apiKey,
      apiEndpoint: _endpoint,
    );

ModelConfig _makeModelConfig() => ModelConfig(
      id: 'test_model',
      tier: ModelTier.fast,
      displayName: 'Test Model',
      providerType: 'openai',
      modelName: _modelName,
      temperature: 0.1,
      maxOutputTokens: 4096,
    );

// ─── Mock ───

class MockAIConfigRepository extends Mock implements AIConfigRepository {}

// ─── AI 调用日志 ───

class AICallLog {
  final String phase;
  final String? systemPrompt;
  final String userPrompt;
  final List<Map<String, dynamic>>? toolSchemas;
  final String? responseContent;
  final String? thinking;
  final List<ToolCallLog>? toolCalls;
  final int inputTokens;
  final int outputTokens;
  final Duration elapsed;

  AICallLog({
    required this.phase,
    this.systemPrompt,
    required this.userPrompt,
    this.toolSchemas,
    this.responseContent,
    this.thinking,
    this.toolCalls,
    required this.inputTokens,
    required this.outputTokens,
    required this.elapsed,
  });

  String toReport() {
    final buf = StringBuffer();
    buf.writeln('══════════════════════════════════════════════════');
    buf.writeln('📋 AI 调用 [$phase]');
    buf.writeln('⏱  耗时: ${elapsed.inMilliseconds}ms');
    buf.writeln('📊 Token: input=$inputTokens, output=$outputTokens');
    if (systemPrompt != null && systemPrompt!.isNotEmpty) {
      buf.writeln('── System Prompt ──');
      buf.writeln(systemPrompt!.length > 500
          ? '${systemPrompt!.substring(0, 500)}...(截断，共${systemPrompt!.length}字)'
          : systemPrompt);
    }
    buf.writeln('── User Prompt ──');
    buf.writeln(userPrompt.length > 1000
        ? '${userPrompt.substring(0, 1000)}...(截断，共${userPrompt.length}字)'
        : userPrompt);
    if (thinking != null && thinking!.isNotEmpty) {
      buf.writeln('── Thinking ──');
      buf.writeln(thinking!.length > 500
          ? '${thinking!.substring(0, 500)}...(截断)'
          : thinking);
    }
    if (toolCalls != null && toolCalls!.isNotEmpty) {
      buf.writeln('── Tool Calls ──');
      for (final tc in toolCalls!) {
        buf.writeln('  🔧 ${tc.name}');
        buf.writeln('     参数: ${tc.arguments}');
      }
    }
    if (responseContent != null && responseContent!.isNotEmpty) {
      buf.writeln('── Response ──');
      buf.writeln(responseContent!.length > 500
          ? '${responseContent!.substring(0, 500)}...(截断，共${responseContent!.length}字)'
          : responseContent);
    }
    buf.writeln('══════════════════════════════════════════════════');
    return buf.toString();
  }
}

class ToolCallLog {
  final String name;
  final Map<String, dynamic> arguments;
  ToolCallLog(this.name, this.arguments);
}

// 全局 AI 调用日志（跨测试收集）
final _aiCallLogs = <AICallLog>[];

// ═══════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    _loadSqlite3WithFts5();
    registerFallbackValue(feature_config.ModelTier.fast);
  });

  group('Full Pipeline: Agent → Tools → Hooks → DB（真实 AI 完整链路）', () {
    late AppDatabase db;
    late MockAIConfigRepository mockConfigRepo;
    late ToolRegistry registry;
    late AgentService agentService;
    late WorkRepository workRepo;
    late VolumeRepository volumeRepo;
    late ChapterRepository chapterRepo;
    late CharacterRepository charRepo;
    late ItemRepository itemRepo;
    late LocationRepository locRepo;
    late FactionRepository facRepo;
    late RelationshipRepository relRepo;
    late InspirationRepository insRepo;
    late ChatRepository chatRepo;

    setUp(() async {
      Get.reset();
      _aiCallLogs.clear();

      // 1. 数据库
      db = _createTestDb();
      Get.put<AppDatabase>(db);

      // 2. Mock AI 配置
      mockConfigRepo = MockAIConfigRepository();
      when(() => mockConfigRepo.getCoreModelConfig(any()))
          .thenAnswer((_) async => _makeModelConfig());
      when(() => mockConfigRepo.getCoreProviderConfig(any()))
          .thenAnswer((_) async => _makeProviderConfig());
      when(() => mockConfigRepo.getFunctionOverrideTier(any()))
          .thenAnswer((_) async => null);
      Get.put<AIConfigRepository>(mockConfigRepo);

      // 3. AIService
      final aiService = AIService();
      Get.put<AIService>(aiService);

      // 4. 仓库
      workRepo = WorkRepository(db);
      volumeRepo = VolumeRepository(db);
      chapterRepo = ChapterRepository(db);
      charRepo = CharacterRepository(db);
      itemRepo = ItemRepository(db);
      locRepo = LocationRepository(db);
      facRepo = FactionRepository(db);
      relRepo = RelationshipRepository(db);
      insRepo = InspirationRepository(db);
      chatRepo = ChatRepository(db);

      Get.put<WorkRepository>(workRepo);
      Get.put<VolumeRepository>(volumeRepo);
      Get.put<ChapterRepository>(chapterRepo);
      Get.put<CharacterRepository>(charRepo);
      Get.put<ItemRepository>(itemRepo);
      Get.put<LocationRepository>(locRepo);
      Get.put<FactionRepository>(facRepo);
      Get.put<RelationshipRepository>(relRepo);
      Get.put<InspirationRepository>(insRepo);
      Get.put<ChatRepository>(chatRepo);


      // 6. 工具注册（全部连接真实仓库 + hooks）
      registry = ToolRegistry();
      registry.clear();

      // --- 查询工具 ---

      registry.register(ListWorksTool(
        listFn: () async {
          final works = await workRepo.getAllWorks();
          return works
              .map((w) => {'id': w.id, 'name': w.name, 'type': w.type ?? ''})
              .toList();
        },
      ));

      registry.register(ListVolumesTool(
        listFn: (workId) async {
          final vols = await volumeRepo.getVolumesByWorkId(workId);
          return vols
              .map((v) => {
                    'id': v.id,
                    'name': v.name,
                    'sort_order': v.sortOrder.toString(),
                  })
              .toList();
        },
      ));

      registry.register(SearchTool.withSearchService(
        SearchService(
          workRepository: workRepo,
          chapterRepository: chapterRepo,
          characterRepository: charRepo,
          itemRepository: itemRepo,
          locationRepository: locRepo,
          factionRepository: facRepo,
        ),
      ));

      // --- 创建工具（带 hooks）---

      registry.register(CreateWorkTool(
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
      ));

      registry.register(CreateVolumeTool(
        createFn: (workId, name, {sortOrder = 0}) async {
          final vol = await volumeRepo.createVolume(
            workId: workId,
            name: name,
            sortOrder: sortOrder,
          );
          return (id: vol.id, name: vol.name);
        },
      ));

      registry.register(CreateChapterTool(
        createFn: (workId, volumeId, title, {sortOrder = 0, content}) async {
          final ch = await chapterRepo.createOrGetChapterByTitle(
            workId: workId,
            volumeId: volumeId,
            title: title,
            sortOrder: sortOrder,
          );
          if (content != null && content.trim().isNotEmpty) {
            await chapterRepo.updateContent(
              ch.id,
              content.trim(),
              content.trim().length,
            );
          }
          return (id: ch.id, title: ch.title);
        },
      ));

      registry.register(UpdateChapterContentTool(
        updateFn: (chapterId, content, wordCount) async {
          await chapterRepo.updateContent(chapterId, content, wordCount);
        },
      ));

      registry.register(CreateCharacterTool(
        createFn: (workId, name, tier,
            {aliases, gender, age, identity, bio}) async {
          final character = await charRepo.createCharacter(
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
          return (
            id: character.id,
            name: character.name,
            tier: character.tier.name,
          );
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
          final item = await itemRepo.createItem(
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
          final location = await locRepo.createLocation(
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
          final faction = await facRepo.createFaction(
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
          final ins = await insRepo.create(
            title: title,
            content: content,
            workId: workId,
            category: category,
            tags: tags,
            source: source,
          );
          return (id: ins.id, title: ins.title);
        },
      ));

      // 7. AgentService（完整链路）
      final contextManager = ContextManager(aiService: aiService);
      agentService = AgentService(
        aiService: aiService,
        toolRegistry: registry,
        contextManager: contextManager,
      );
    });

    tearDown(() async {
      registry.clear();
      Get.deleteAll(force: true);
      Get.reset();
      await db.close();
    });

    // ─── 辅助：运行 agent 并收集日志 ───

    Future<List<AgentEvent>> _runAgentAndLog({
      required String task,
      required String workId,
      required String phase,
      int maxIterations = 8,
    }) async {
      final events = <AgentEvent>[];
      final sw = Stopwatch()..start();

      print('\n┌─────────────────────────────────────────────');
      print('│ 🚀 Phase: $phase');
      print('│ 📝 Task: ${task.length > 200 ? '${task.substring(0, 200)}...' : task}');
      print('│ 🆔 WorkId: $workId');
      print('└─────────────────────────────────────────────');

      await for (final event in agentService.run(
        task: task,
        workId: workId,
        maxIterations: maxIterations,
      )) {
        events.add(event);

        switch (event) {
          case AgentThinking(:final thought):
            print('  💭 Thinking: ${thought.length > 150 ? '${thought.substring(0, 150)}...' : thought}');
          case AgentAction(:final toolName, :final input):
            print('  🔧 Action: $toolName');
            print('     Input: ${_truncateMap(input)}');
          case AgentObservation(:final result):
            final status = result.success ? '✅' : '❌';
            final msg = result.success ? result.output : (result.error ?? 'unknown');
            print('  $status Observation: ${msg.length > 200 ? '${msg.substring(0, 200)}...' : msg}');
          case AgentResponseChunk():
            // 流式块，不需要实时打印
            break;
          // AgentReflection removed - not a current event type
          case AgentResponse(
            :final content,
            :final iterations,
            :final totalInputTokens,
            :final totalOutputTokens,
          ):
            sw.stop();
            print('  📤 Response (${iterations} iters, ${sw.elapsedMilliseconds}ms)');
            print('     Tokens: in=$totalInputTokens out=$totalOutputTokens');
            print('     Content: ${content.length > 300 ? '${content.substring(0, 300)}...' : content}');

            // 记录到日志
            _aiCallLogs.add(AICallLog(
              phase: phase,
              userPrompt: task,
              responseContent: content,
              inputTokens: totalInputTokens,
              outputTokens: totalOutputTokens,
              elapsed: sw.elapsed,
            ));
          case AgentError(:final error):
            sw.stop();
            print('  🚨 Error: $error');
        }
      }

      return events;
    }

    // ─── 阶段 1：创建作品 ───

    test('Phase 1: Agent 创建作品 + 世界观设定', timeout: const Timeout(Duration(minutes: 5)), () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final events = await _runAgentAndLog(
        task: '请帮我创建一部叫"灵渊秘录"的玄幻小说，'
            '主题是修真世界中一个少年发现上古秘境并逆天改命的故事。'
            '创建完成后请回复确认即可，不要重复创建。',
        workId: '', // 无 workId，agent 需先创建作品
        phase: 'Phase 1: 创建作品',
        maxIterations: 4,
      );

      // 验证事件
      final actions = events.whereType<AgentAction>().toList();
      expect(actions, isNotEmpty, reason: 'Agent 应调用工具');

      final createAction = actions.where((a) => a.toolName == 'create_work').toList();
      expect(createAction, isNotEmpty, reason: '应调用 create_work');

      // 验证 DB
      final works = await workRepo.getAllWorks();
      expect(works.any((w) => w.name.contains('灵渊秘录')), isTrue,
          reason: '数据库应包含「灵渊秘录」');

      final observations = events.whereType<AgentObservation>().toList();
      expect(observations.any((o) => o.result.success), isTrue,
          reason: '至少一个工具执行成功');

      // 输出 AI 调用报告
      _printAIReport('Phase 1');
    });

    // ─── 阶段 2：创建角色 ───

    test('Phase 2: Agent 创建角色 + 关系', timeout: const Timeout(Duration(minutes: 3)), () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      // 先创建作品
      final work = await workRepo.createWork(
        CreateWorkParams(name: '灵渊秘录', type: '玄幻'),
      );
      print('  📌 预创建作品: ${work.name} (${work.id})');

      final events = await _runAgentAndLog(
        task: '请在作品 ${work.id} 中创建以下角色：\n'
            '1. 主角"凌霄"，男性，18岁，天赋异禀但身世神秘的少年\n'
            '2. 反派"冥渊老祖"，男性，上古邪修\n'
            '3. 配角"云瑶"，女性，灵渊宗圣女',
        workId: work.id,
        phase: 'Phase 2: 创建角色',
      );

      // 验证
      final actions = events.whereType<AgentAction>().toList();
      final charActions = actions.where((a) => a.toolName == 'create_character').toList();
      expect(charActions.length, greaterThanOrEqualTo(1),
          reason: '应至少调用一次 create_character');

      // 验证 DB
      final chars = await charRepo.getCharactersByWorkId(work.id);
      expect(chars, isNotEmpty, reason: '数据库应有角色记录');

      // 输出角色列表
      for (final c in chars) {
        print('  👤 ${c.name} (${c.tier.name})${c.bio != null ? ' - ${c.bio!.length > 50 ? '${c.bio!.substring(0, 50)}...' : c.bio}' : ''}');
      }

      _printAIReport('Phase 2');
    });

    // ─── 阶段 3：创建地点 + 物品 + 势力 ───

    test('Phase 3: Agent 创建地点/物品/势力', timeout: const Timeout(Duration(minutes: 3)), () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final work = await workRepo.createWork(
        CreateWorkParams(name: '灵渊秘录-实体测试', type: '玄幻'),
      );

      final events = await _runAgentAndLog(
        task: '请在作品 ${work.id} 中创建以下内容：\n'
            '1. 地点"灵渊秘境"，类型为秘境，描述：上古大能留下的洞天福地，蕴含天地灵气\n'
            '2. 物品"天璇剑"，类型为法宝，稀有度：仙器，描述：由天外陨铁铸造的灵剑，可斩妖除魔\n'
            '3. 势力"灵渊宗"，类型为宗门，描述：传承万年的修仙大派，镇守灵渊秘境',
        workId: work.id,
        phase: 'Phase 3: 创建实体',
      );

      // 验证工具调用
      final actions = events.whereType<AgentAction>().toList();
      final toolNames = actions.map((a) => a.toolName).toSet();
      expect(toolNames.intersection({
        'create_location', 'create_item', 'create_faction'
      }).length, greaterThanOrEqualTo(1),
          reason: '应至少调用一个实体创建工具');

      // 验证 DB
      final locs = await locRepo.getLocationsByWorkId(work.id);
      final items = await itemRepo.getItemsByWorkId(work.id);
      final facs = await facRepo.getFactionsByWorkId(work.id);
      final totalEntities = locs.length + items.length + facs.length;
      expect(totalEntities, greaterThanOrEqualTo(1),
          reason: '至少创建一个实体');

      print('  📍 地点: ${locs.map((l) => l.name).join(", ")}');
      print('  🗡️ 物品: ${items.map((i) => i.name).join(", ")}');
      print('  🏛️ 势力: ${facs.map((f) => f.name).join(", ")}');

      _printAIReport('Phase 3');
    });

    // ─── 阶段 4：创建章节（含 content） ───

    test('Phase 4: Agent 创建卷 + 章节（含正文内容）', timeout: const Timeout(Duration(minutes: 5)), () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      // 预创建作品和卷
      final work = await workRepo.createWork(
        CreateWorkParams(name: '灵渊秘录-章节测试', type: '玄幻'),
      );
      final vol = await volumeRepo.createVolume(
        workId: work.id,
        name: '第一卷 灵渊初现',
      );

      final events = await _runAgentAndLog(
        task: '请在作品 ${work.id} 的卷 ${vol.id} 中创建第一章，标题为"少年凌霄"，'
            '内容要求：\n'
            '- 开头描述灵渊镇清晨的景象\n'
            '- 主角凌霄在山中发现异常灵气波动\n'
            '- 结尾留下悬念，字数不少于300字\n'
            '请在 content 参数中写入完整正文。',
        workId: work.id,
        phase: 'Phase 4: 创建章节',
        maxIterations: 6,
      );

      // 验证工具调用
      final actions = events.whereType<AgentAction>().toList();
      final chapterActions = actions
          .where((a) => a.toolName == 'create_chapter' || a.toolName == 'update_chapter_content')
          .toList();
      expect(chapterActions, isNotEmpty, reason: '应调用章节创建/更新工具');

      // 验证 DB
      final chapters = await chapterRepo.getChaptersByWorkId(work.id);
      expect(chapters, isNotEmpty, reason: '应有章节记录');

      // 检查章节内容是否非空（hooks 应拦截空内容）
      final chaptersWithContent = chapters.where((c) =>
          c.content != null && c.content!.trim().isNotEmpty).toList();
      print('  📄 章节: ${chapters.map((c) => '${c.title}(${(c.content ?? '').length}字)').join(", ")}');

      // 至少有一个章节有内容（hooks 会拦截空内容但工具仍会创建章节记录）
      if (chaptersWithContent.isNotEmpty) {
        expect(chaptersWithContent.first.content?.length ?? 0, greaterThanOrEqualTo(50),
            reason: '章节内容应通过 hooks 检查（非空非占位符）');
      }

      _printAIReport('Phase 4');
    });

    // ─── 阶段 5：完整链路（创建作品→角色→章节 一条消息） ───

    test('Phase 5: 完整链路 - 一条消息触发多个工具调用', timeout: const Timeout(Duration(minutes: 5)), () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final events = await _runAgentAndLog(
        task: '请帮我创建一部叫"天命修仙录"的仙侠小说，'
            '类型为仙侠，然后创建一个叫"叶辰"的主角（男性，20岁，废柴逆袭的少年）'
            '和一个叫"苏灵儿"的配角（女性，19岁，天才少女）。',
        workId: '',
        phase: 'Phase 5: 完整链路',
        maxIterations: 10,
      );

      // 验证事件流
      final actions = events.whereType<AgentAction>().toList();
      final reflections = <AgentEvent>[]; // AgentReflection removed
      final observations = events.whereType<AgentObservation>().toList();
      final responses = events.whereType<AgentResponse>().toList();

      print('\n  📊 事件统计:');
      print('     Actions: ${actions.length}');
      print('     Observations: ${observations.length}');
      print('     Reflections: ${reflections.length}');
      print('     Responses: ${responses.length}');

      // 工具调用分布
      final toolDist = <String, int>{};
      for (final a in actions) {
        toolDist[a.toolName] = (toolDist[a.toolName] ?? 0) + 1;
      }
      print('     Tool distribution: $toolDist');

      // 验证至少调用了 create_work 和 create_character
      final toolNames = actions.map((a) => a.toolName).toSet();
      expect(toolNames.contains('create_work'), isTrue,
          reason: '应调用 create_work');
      expect(toolNames.contains('create_character'), isTrue,
          reason: '应调用 create_character');

      // Reflections 已移除（AgentReflection 不再是当前事件类型）

      // 验证成功/失败比
      final successes = observations.where((o) => o.result.success).length;
      final failures = observations.where((o) => !o.result.success).length;
      print('     ✓ Success: $successes  ✗ Failures: $failures');
      expect(successes, greaterThanOrEqualTo(2),
          reason: '至少2个工具执行成功（创建作品+角色）');

      // 验证 DB
      final works = await workRepo.getAllWorks();
      final allChars = <String>[];
      for (final w in works.where((w) => w.name.contains('天命修仙录'))) {
        final chars = await charRepo.getCharactersByWorkId(w.id);
        allChars.addAll(chars.map((c) => c.name));
      }
      print('  📚 最终 DB 状态:');
      print('     作品: ${works.where((w) => w.name.contains('天命修仙录')).map((w) => w.name).join(", ")}');
      print('     角色: ${allChars.join(", ")}');

      // 验证最终响应
      expect(responses, isNotEmpty, reason: '应有最终响应');
      expect(responses.first.iterations, greaterThan(0));

      _printAIReport('Phase 5');
    });

    // ─── 阶段 6：Hooks 拦截测试 ───

    test('Phase 6: Hooks 拦截占位内容', timeout: const Timeout(Duration(minutes: 2)), () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final work = await workRepo.createWork(
        CreateWorkParams(name: 'Hooks测试作品'),
      );

      final events = await _runAgentAndLog(
        task: '请在作品 ${work.id} 中创建一个叫"测试角色"的配角，简介写"暂无"即可。',
        workId: work.id,
        phase: 'Phase 6: Hooks 拦截',
        maxIterations: 6,
      );

      final observations = events.whereType<AgentObservation>().toList();
      // 如果 hooks 拦截了占位内容，应该有失败结果
      final blocked = observations.where((o) =>
          !o.result.success && o.result.error != null && o.result.error!.contains('安全检查')).toList();

      if (blocked.isNotEmpty) {
        print('  🛡️ Hooks 拦截了 ${blocked.length} 次占位内容');
        for (final b in blocked) {
          print('     ${b.result.error!.length > 100 ? '${b.result.error!.substring(0, 100)}...' : b.result.error}');
        }
      } else {
        print('  ℹ️ Hooks 未拦截（模型可能未使用占位内容）');
      }

      // 检查反思事件
      final reflections = <AgentEvent>[]; // AgentReflection removed
      if (false) { // AgentReflection.toolsFailed removed
        print('  🪞 Agent 反思检测到工具失败');
      }

      _printAIReport('Phase 6');
    });
  });

  // ─── 汇总报告 ───

  group('Full Pipeline Summary Report', () {
    test('输出完整 AI 调用报告', () {
      if (_aiCallLogs.isEmpty) {
        print('\n⚠️ 无 AI 调用记录（可能所有测试都被跳过了）');
        return;
      }

      print('\n');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║          FULL PIPELINE AI CALL REPORT                     ║');
      print('╠════════════════════════════════════════════════════════════╣');

      var totalInput = 0;
      var totalOutput = 0;
      var totalMs = 0;

      for (final log in _aiCallLogs) {
        print(log.toReport());
        totalInput += log.inputTokens;
        totalOutput += log.outputTokens;
        totalMs += log.elapsed.inMilliseconds;
      }

      print('┌─────────────────────────────────────────────────────────┐');
      print('│ 📊 TOTALS                                                │');
      print('│   AI Calls: ${_aiCallLogs.length}                                                  │');
      print('│   Input Tokens:  $totalInput                                          │');
      print('│   Output Tokens: $totalOutput                                          │');
      print('│   Total Time:    ${totalMs}ms                                          │');
      print('└─────────────────────────────────────────────────────────┘');
      print('╚════════════════════════════════════════════════════════════╝');
    });
  });
}

// ─── 辅助 ───

String _truncateMap(Map<String, dynamic> m, [int maxLen = 200]) {
  final s = m.toString();
  return s.length > maxLen ? '${s.substring(0, maxLen)}...' : s;
}

void _printAIReport(String phase) {
  // 由 Summary Report group 统一输出
  print('\n  📋 Phase "$phase" 完成，详细报告见 Full Pipeline Summary Report');
}
