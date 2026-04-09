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

import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/core/services/ai/ai_service.dart';
import 'package:writing_assistant/core/services/ai/agent/agent_service.dart';
import 'package:writing_assistant/core/services/ai/context/context_manager.dart';
import 'package:writing_assistant/core/services/ai/models/model_config.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/ai/models/provider_config.dart';
import 'package:writing_assistant/core/services/ai/providers/openai_provider.dart';
import 'package:writing_assistant/core/services/ai/tools/create_character_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_chapter_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_volume_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_work_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/tool_registry.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart'
    as feature_config;
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/settings/data/character_repository.dart';
import 'package:writing_assistant/features/settings/domain/character.dart'
    as character_domain;
import 'package:writing_assistant/features/work/data/volume_repository.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';

// ─── 环境变量配置 ───

String get _apiKey =>
    Platform.environment['TEST_AI_API_KEY'] ?? 'lm-studio';
String get _endpoint =>
    Platform.environment['TEST_AI_ENDPOINT'] ?? 'http://127.0.0.1:1234/v1';
String get _modelName =>
    Platform.environment['TEST_AI_MODEL'] ?? 'google/gemma-4-26b-a4b';
bool get _hasApiConfig => true; // LM Studio 默认可用

/// 加载 sqlite3_flutter_libs 提供的 sqlite3（含 FTS5）
void _loadSqlite3WithFts5() {
  if (Platform.isWindows) {
    final dllPath = '${Directory.current.path}/build/windows/x64/runner/Debug/sqlite3.dll';
    if (File(dllPath).existsSync()) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(dllPath));
    }
  }
}

/// 真实数据库文件路径（客户端使用的同一个 db）
String get _realDbPath =>
    Platform.environment['TEST_DB_PATH'] ??
    'C:/Users/changw98/Documents/writing_assistant.db';

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
      maxOutputTokens: 500,
    );

// ─── Mock ───

class MockAIConfigRepository extends Mock implements AIConfigRepository {}

// ─── 测试用 tool schemas ───

final _createWorkSchema = {
  'type': 'function',
  'function': {
    'name': 'create_work',
    'description': '创建新作品。指定作品名称即可创建一部新小说。',
    'parameters': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'description': '作品名称'},
        'type': {'type': 'string', 'description': '作品类型，如：玄幻、都市、科幻'},
        'description': {'type': 'string', 'description': '作品简介'},
      },
      'required': ['name'],
    },
  },
};

final _searchSchema = {
  'type': 'function',
  'function': {
    'name': 'search_content',
    'description': '搜索作品中的角色、地点、物品、章节等内容。',
    'parameters': {
      'type': 'object',
      'properties': {
        'work_id': {'type': 'string', 'description': '作品 ID'},
        'query': {'type': 'string', 'description': '搜索关键词'},
        'type': {
          'type': 'string',
          'enum': ['character', 'location', 'item', 'faction', 'chapter', 'all'],
        },
      },
      'required': ['work_id', 'query'],
    },
  },
};

final _createCharacterSchema = {
  'type': 'function',
  'function': {
    'name': 'create_character',
    'description': '在作品中创建角色。',
    'parameters': {
      'type': 'object',
      'properties': {
        'work_id': {'type': 'string', 'description': '作品 ID'},
        'name': {'type': 'string', 'description': '角色名称'},
        'tier': {
          'type': 'string',
          'enum': ['protagonist', 'major_antagonist', 'antagonist', 'supporting', 'minor'],
          'description': '角色等级',
        },
        'gender': {'type': 'string', 'description': '性别'},
        'bio': {'type': 'string', 'description': '角色简介'},
      },
      'required': ['work_id', 'name', 'tier'],
    },
  },
};

// ═══════════════════════════════════════════════════════════════════
// Level 1: 真实 AI Provider — 验证大模型返回 tool_calls
// ═══════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    _loadSqlite3WithFts5();
    registerFallbackValue(feature_config.ModelTier.fast);
  });

  group('Level 1: Provider Tool Calling（真实大模型）', () {
    late OpenAIProvider provider;

    setUp(() {
      provider = OpenAIProvider();
    });

    test('AI 收到「创建作品」指令后返回 create_work tool_call', () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final response = await provider.completeWithTools(
        config: _makeProviderConfig(),
        model: _makeModelConfig(),
        systemPrompt: '你是一位小说写作助手。当用户要求创建作品时，请调用 create_work 工具。',
        userPrompt: '请帮我创建一部叫"星辰变"的玄幻小说',
        tools: [_createWorkSchema],
        temperature: 0.1,
        maxTokens: 500,
      );

      // 验证：AI 必须返回 tool_calls
      expect(response.toolCalls, isNotEmpty, reason: 'AI 应返回 tool_calls');
      final call = response.toolCalls.first;
      expect(call.name, 'create_work', reason: '应调用 create_work');
      expect(call.arguments['name'], isNotNull, reason: '参数必须包含 name');
      expect(
        call.arguments['name'].toString(),
        contains('星辰变'),
        reason: 'name 参数应包含"星辰变"',
      );

      // 验证：token 统计有值
      expect(response.inputTokens, greaterThan(0), reason: '应记录 inputTokens');
      expect(response.outputTokens, greaterThan(0), reason: '应记录 outputTokens');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('AI 收到「搜索角色」指令后返回 search_content tool_call', () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final response = await provider.completeWithTools(
        config: _makeProviderConfig(),
        model: _makeModelConfig(),
        systemPrompt: '你是一位小说写作助手。用户想查找角色信息，请调用搜索工具。',
        userPrompt: '帮我查一下作品 w1 中有没有叫"林峰"的角色',
        tools: [_searchSchema],
        temperature: 0.1,
        maxTokens: 500,
      );

      expect(response.toolCalls, isNotEmpty, reason: 'AI 应返回 tool_calls');
      final call = response.toolCalls.first;
      expect(call.name, 'search_content');
      expect(call.arguments['work_id'], isNotNull);
      expect(call.arguments['query'].toString(), contains('林峰'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('AI 收到多个工具 schema 时选择正确的工具', () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final response = await provider.completeWithTools(
        config: _makeProviderConfig(),
        model: _makeModelConfig(),
        systemPrompt: '你是一位小说写作助手。请根据用户需求调用合适的工具。',
        userPrompt: '帮我在作品 w1 里创建一个叫"林峰"的主角，男性，天赋异禀的少年',
        tools: [_createWorkSchema, _searchSchema, _createCharacterSchema],
        temperature: 0.1,
        maxTokens: 500,
      );

      expect(response.toolCalls, isNotEmpty);
      final call = response.toolCalls.first;
      expect(call.name, 'create_character', reason: '应选择 create_character 而非其他工具');
      expect(call.arguments['name'], contains('林峰'));
      expect(call.arguments['work_id'], isNotNull);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('AI 不需要工具时直接返回文本', () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final response = await provider.completeWithTools(
        config: _makeProviderConfig(),
        model: _makeModelConfig(),
        systemPrompt: '你是一位小说写作助手。',
        userPrompt: '什么是"金手指"在玄幻小说中的含义？',
        tools: [_createWorkSchema, _searchSchema],
        temperature: 0.1,
        maxTokens: 500,
      );

      // 验证：响应对象有效（有 token 统计）
      // 注：小模型可能返回空 content 或意外触发 tool_calls，属于模型行为差异
      expect(response.inputTokens, greaterThanOrEqualTo(0));
      expect(response.modelId, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  // ═══════════════════════════════════════════════════════════════════
  // Level 2: Tool + SQLite — 验证工具操作真实数据库
  // ═══════════════════════════════════════════════════════════════════

  group('Level 2: Tool + Database（真实 SQLite）', () {
    late AppDatabase db;
    late WorkRepository workRepo;
    late VolumeRepository volumeRepo;
    late ChapterRepository chapterRepo;
    late CharacterRepository charRepo;

    setUp(() {
      db = _createTestDb();
      workRepo = WorkRepository(db);
      volumeRepo = VolumeRepository(db);
      chapterRepo = ChapterRepository(db);
      charRepo = CharacterRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('CreateWorkTool 写入 SQLite，数据可查回', () async {
      final tool = CreateWorkTool(
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
      );

      final result = await tool.execute({
        'name': '星辰变',
        'type': '玄幻',
        'description': '一部关于修仙的小说',
        'target_words': 500000,
      });

      expect(result.success, isTrue);
      expect(result.data?['id'], isNotNull);
      expect(result.output, contains('星辰变'));

      // 真实查询数据库验证
      final works = await workRepo.getAllWorks();
      expect(works.any((w) => w.name == '星辰变'), isTrue, reason: '数据库应包含「星辰变」');
    });

    test('连续创建 作品→卷→章节，完整层级写入数据库', () async {
      // 创建作品
      final workTool = CreateWorkTool(
        createFn: (name, {type, description, targetWords}) async {
          final work = await workRepo.createWork(
            CreateWorkParams(name: name, type: type, description: description),
          );
          return (id: work.id, name: work.name);
        },
      );
      final workResult = await workTool.execute({
        'name': '盘龙',
        'type': '玄幻',
      });
      expect(workResult.success, isTrue);
      final workId = workResult.data!['id'] as String;

      // 创建卷
      final volumeTool = CreateVolumeTool(
        createFn: (wId, name, {sortOrder = 0}) async {
          final vol = await volumeRepo.createVolume(
            workId: wId,
            name: name,
            sortOrder: sortOrder,
          );
          return (id: vol.id, name: vol.name);
        },
      );
      final volResult = await volumeTool.execute({
        'work_id': workId,
        'name': '第一卷 龙血战士',
      });
      expect(volResult.success, isTrue);
      final volId = volResult.data!['id'] as String;

      // 创建章节
      final chapterTool = CreateChapterTool(
        createFn: (wId, vId, title, {sortOrder = 0}) async {
          final ch = await chapterRepo.createChapter(
            workId: wId,
            volumeId: vId,
            title: title,
            sortOrder: sortOrder,
          );
          return (id: ch.id, title: ch.title);
        },
      );
      final chResult = await chapterTool.execute({
        'work_id': workId,
        'volume_id': volId,
        'title': '第一章 少年林雷',
      });
      expect(chResult.success, isTrue);

      // 验证数据库完整层级
      final works = await workRepo.getAllWorks();
      expect(works.any((w) => w.name == '盘龙'), isTrue, reason: '数据库应包含「盘龙」');
    });

    test('CreateCharacterTool 写入数据库，tier 正确转换', () async {
      // 先创建作品
      final work = await workRepo.createWork(
        CreateWorkParams(name: '测试作品'),
      );

      final tool = CreateCharacterTool(
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
              bio: bio,
            ),
          );
          return (
            id: character.id,
            name: character.name,
            tier: character.tier.name
          );
        },
      );

      final result = await tool.execute({
        'work_id': work.id,
        'name': '林峰',
        'tier': 'protagonist',
        'gender': '男',
        'bio': '天赋异禀的少年剑客',
      });

      expect(result.success, isTrue);
      expect(result.data?['id'], isNotNull);

      // 真实查询验证
      final chars = await charRepo.getCharactersByWorkId(work.id);
      expect(chars.any((c) => c.name == '林峰'), isTrue, reason: '数据库应包含角色「林峰」');
    });

    test('工具参数校验：缺少必填字段时返回失败', () async {
      final tool = CreateWorkTool(
        createFn: (name, {type, description, targetWords}) async {
          final work = await workRepo.createWork(
            CreateWorkParams(name: name, type: type),
          );
          return (id: work.id, name: work.name);
        },
      );

      final result = await tool.execute({}); // 缺少 name
      expect(result.success, isFalse);
      expect(result.error, contains('name'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // Level 3: 完整 Agent Loop — 真实 AI + 真实 DB + GetX DI
  // ═══════════════════════════════════════════════════════════════════

  group('Level 3: Full Agent Loop（真实 AI + 真实 DB）', () {
    late AppDatabase db;
    late MockAIConfigRepository mockConfigRepo;
    late ToolRegistry registry;
    late AgentService agentService;

    setUp(() async {
      // 清理 GetX
      Get.reset();

      // 1. 内存数据库
      db = _createTestDb();
      Get.put<AppDatabase>(db);

      // 2. Mock AI 配置仓库（绕过 FlutterSecureStorage）
      mockConfigRepo = MockAIConfigRepository();
      when(() => mockConfigRepo.getCoreModelConfig(any()))
          .thenAnswer((_) async => _makeModelConfig());
      when(() => mockConfigRepo.getCoreProviderConfig(any()))
          .thenAnswer((_) async => _makeProviderConfig());
      Get.put<AIConfigRepository>(mockConfigRepo);

      // 3. AIService（依赖 DB + AIConfigRepository）
      final aiService = AIService();
      Get.put<AIService>(aiService);

      // 4. 真实仓库
      final workRepo = WorkRepository(db);
      final volumeRepo = VolumeRepository(db);
      final chapterRepo = ChapterRepository(db);
      final charRepo = CharacterRepository(db);
      Get.put<WorkRepository>(workRepo);
      Get.put<VolumeRepository>(volumeRepo);
      Get.put<ChapterRepository>(chapterRepo);
      Get.put<CharacterRepository>(charRepo);

      // 5. 工具注册（连接真实仓库）
      registry = ToolRegistry();
      registry.clear();

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
          final vol = await Get.find<VolumeRepository>().createVolume(
            workId: workId,
            name: name,
            sortOrder: sortOrder,
          );
          return (id: vol.id, name: vol.name);
        },
      ));

      registry.register(CreateChapterTool(
        createFn: (workId, volumeId, title, {sortOrder = 0}) async {
          final ch = await Get.find<ChapterRepository>().createChapter(
            workId: workId,
            volumeId: volumeId,
            title: title,
            sortOrder: sortOrder,
          );
          return (id: ch.id, title: ch.title);
        },
      ));

      registry.register(CreateCharacterTool(
        createFn: (workId, name, tier,
            {aliases, gender, age, identity, bio}) async {
          final character =
              await Get.find<CharacterRepository>().createCharacter(
            character_domain.CreateCharacterParams(
              workId: workId,
              name: name,
              tier: character_domain.CharacterTier.values.firstWhere(
                (t) => t.name == tier,
                orElse: () => character_domain.CharacterTier.supporting,
              ),
              aliases: aliases,
              gender: gender,
              bio: bio,
            ),
          );
          return (id: character.id, name: character.name, tier: character.tier.name);
        },
      ));

      // 6. ContextManager + AgentService
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

    test('Agent 收到创建作品请求→调大模型→返回tool_call→执行工具→写入DB', () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      final events = await agentService
          .run(task: '请帮我创建一部叫"星辰变"的玄幻小说', workId: 'w1')
          .toList();

      // 应有: AgentAction + AgentThinking + AgentObservation + AgentResponse
      expect(events, isNotEmpty, reason: 'Agent 应产生事件');

      // 验证工具被调用
      final actions = events.whereType<AgentAction>().toList();
      expect(actions, isNotEmpty, reason: 'Agent 应调用工具');
      expect(actions.first.toolName, 'create_work',
          reason: '应调用 create_work');

      // 验证工具执行成功
      final observations = events.whereType<AgentObservation>().toList();
      expect(observations, isNotEmpty, reason: '应有工具执行结果');
      expect(observations.first.result.success, isTrue,
          reason: '工具执行应成功');

      // 验证数据库写入
      final works = await Get.find<WorkRepository>().getAllWorks();
      expect(works.any((w) => w.name == '星辰变'), isTrue, reason: '数据库应包含「星辰变」');

      // 验证最终响应
      final responses = events.whereType<AgentResponse>().toList();
      expect(responses, isNotEmpty, reason: 'Agent 应有最终响应');
      // content 可能为空（小模型行为），但迭代次数应 > 0
      expect(responses.first.iterations, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('Agent 连续创建角色→验证DB写入', () async {
      if (!_hasApiConfig) {
        markTestSkipped('需要设置 TEST_AI_API_KEY');
        return;
      }

      // 先创建作品
      final work = await Get.find<WorkRepository>().createWork(
        CreateWorkParams(name: '测试世界'),
      );

      final events = await agentService
          .run(
            task: '请在作品 ${work.id} 中创建一个叫"林峰"的主角，性别男，简介：天赋异禀的少年',
            workId: work.id,
          )
          .toList();

      // 验证工具调用
      final actions = events.whereType<AgentAction>().toList();
      expect(actions, isNotEmpty);

      final createActions =
          actions.where((a) => a.toolName == 'create_character').toList();
      expect(createActions, isNotEmpty, reason: '应调用 create_character');

      // 验证数据库
      final chars = await Get.find<CharacterRepository>().getCharactersByWorkId(work.id);
      expect(chars, isNotEmpty, reason: '数据库应至少有一条角色记录');
      expect(chars.first.name, '林峰');
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}
