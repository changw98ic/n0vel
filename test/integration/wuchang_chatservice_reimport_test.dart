@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:sqlite3/open.dart';
import 'package:writing_assistant/core/config/app_env.dart';

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
import 'package:writing_assistant/core/services/ai/tools/create_location_tool.dart';
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
import 'package:writing_assistant/features/settings/data/location_repository.dart';
import 'package:writing_assistant/features/settings/data/relationship_repository.dart';
import 'package:writing_assistant/features/settings/domain/character.dart'
    as character_domain;
import 'package:writing_assistant/features/settings/domain/relationship.dart'
    as relationship_domain;
import 'package:writing_assistant/features/work/data/volume_repository.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';

const _workName = '黑神话：无常';
const _volumeName = '第一卷 灰烬新生';
const _dbPath = r'C:\Users\changw98\Documents\writing_assistant.db';
const _sourceRoot = r'C:\Users\changw98\wuchang';

String get _apiKey =>
    AppEnv.testAiApiKey;
String get _endpoint => AppEnv.testAiEndpoint;
String get _modelName => AppEnv.testAiModel;
int get _startChapter => AppEnv.wuchangStartChapter;
int get _endChapter => AppEnv.wuchangEndChapter;
bool get _resumeImport => AppEnv.wuchangResumeImport;

void _loadSqlite3WithFts5() {
  if (!Platform.isWindows) return;
  final dllPath =
      '${Directory.current.path}/build/windows/x64/runner/Debug/sqlite3.dll';
  if (File(dllPath).existsSync()) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open(dllPath),
    );
  }
}

class ProbeAIConfigRepository extends AIConfigRepository {
  ProbeAIConfigRepository({
    required this.modelConfig,
    required this.providerConfig,
  });

  final core_model.ModelConfig modelConfig;
  final ProviderConfig providerConfig;

  @override
  Future<core_model.ModelConfig?> getCoreModelConfig(
    feature_model.ModelTier tier,
  ) async {
    return modelConfig.copyWith(
      id: 'chatservice_${tier.name}_$_modelName',
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

final _characterSeeds = <Map<String, Object>>[
  {
    'name': '张影',
    'tier': character_domain.CharacterTier.protagonist,
    'aliases': <String>['灰无常'],
    'identity': '被误判为窃命罪魂的灰营耗材，后来自封灰无常',
    'bio': '混沌容器，心口有灰色漩涡。越痛越清醒，越饿越像野兽。外婆银镯残念是最后的人性锚点。',
  },
  {
    'name': '赵铁柱',
    'tier': character_domain.CharacterTier.supporting,
    'aliases': <String>['屠夫'],
    'identity': '被污名化的屠夫，灰营耗材',
    'bio': '为保护村民杀死三十六名伪神信徒，却被卷宗定成凶犯。生锈杀猪刀能亵渎伪神。',
  },
  {
    'name': '陈账房',
    'tier': character_domain.CharacterTier.supporting,
    'aliases': <String>['老算盘'],
    'identity': '灰营账房兼统计员',
    'bio': '靠抹零法偷阴德给阳间孙子续命，越算越深，最后发现自己一直在给死人记账。',
  },
  {
    'name': '小倩',
    'tier': character_domain.CharacterTier.supporting,
    'aliases': <String>[],
    'identity': '被献祭给黑水将军的溺死少女',
    'bio': '总哼唱带有古神语碎片的童谣，童谣本质上是残缺弑神咒与诅咒信标。',
  },
  {
    'name': '噬心主簿',
    'tier': character_domain.CharacterTier.majorAntagonist,
    'aliases': <String>[],
    'identity': '窃据判官位、代理森罗殿的主簿',
    'bio': '典型绩效官僚，只在乎秩序稳定与责任归属，擅长把甩锅包装成制度正义。',
  },
  {
    'name': '黑煞鬼将',
    'tier': character_domain.CharacterTier.antagonist,
    'aliases': <String>[],
    'identity': '地府前线将领',
    'bio': '生前为名将，死后反抗地府失败，被驯成恶犬，把张影视作危险但好用的兵器。',
  },
  {
    'name': '洛九川',
    'tier': character_domain.CharacterTier.antagonist,
    'aliases': <String>['前任白无常'],
    'identity': '三百年前叛逃的白无常',
    'bio': '藏着半截哭丧棒和不完整的小轮回，帮助张影时夹着赎罪欲和实验心。',
  },
  {
    'name': '黑水将军',
    'tier': character_domain.CharacterTier.majorAntagonist,
    'aliases': <String>[],
    'identity': '伪河神',
    'bio': '曾经治水，后堕成靠童男童女献祭续命的怪物，以顾全大局自我催眠。',
  },
  {
    'name': '沉睡阎罗',
    'tier': character_domain.CharacterTier.majorAntagonist,
    'aliases': <String>['伪阎罗'],
    'identity': '窃据阎罗神位的域外神魔',
    'bio': '把整个地府秩序当成租税机器，只关心秩序和畏惧能否持续产出。',
  },
];

final _relationshipSeeds = <Map<String, Object>>[
  {'a': '张影', 'b': '赵铁柱', 'type': relationship_domain.RelationType.closeFriend},
  {'a': '张影', 'b': '陈账房', 'type': relationship_domain.RelationType.hostile},
  {'a': '张影', 'b': '小倩', 'type': relationship_domain.RelationType.family},
  {'a': '张影', 'b': '噬心主簿', 'type': relationship_domain.RelationType.enemy},
  {'a': '张影', 'b': '黑煞鬼将', 'type': relationship_domain.RelationType.rival},
  {'a': '张影', 'b': '洛九川', 'type': relationship_domain.RelationType.mentor},
];

final _locationSeeds = <Map<String, String>>[
  {'name': '森罗殿', 'type': '建筑', 'description': '地府权力核心，主簿把这里经营成只认卷宗与绩效的审判机器。'},
  {
    'name': '涤罪所',
    'type': '建筑',
    'description': '专门用业火剥魂的刑狱，火焰没有温度，却能精准烧穿魂体每一寸结构。',
  },
  {
    'name': '灰营',
    'type': '区域',
    'description': '地府最低等耗材营地，灰牌罪魂在这里像牲口一样被登记、消耗、回收。',
  },
  {'name': '断香庙', 'type': '建筑', 'description': '供奉伪神的神庙，香火腥甜，神光里混着献祭童男童女的怨气。'},
  {'name': '望乡台', 'type': '区域', 'description': '魂灵回望阳世之地，也是洗髓大阵把人逼到绝境的地方。'},
  {'name': '归墟', 'type': '区域', 'description': '死地中的死地，堆满魔神残骸、失效法则和被吞剩的名字。'},
  {'name': '黑水将军神庙', 'type': '建筑', 'description': '阳间黑水河畔的伪神神庙，卷终所指向的屠神战场。'},
];

final _chapterTasks = <Map<String, String>>[
  {
    'title': '第1章：错寿之人',
    'pov': '张影',
    'beat': '车祸暴毙，魂体被强行拖入森罗殿，发现自己十六岁就该死，二十六岁的死反而成了错账，最终被定为窃命。',
  },
  {
    'title': '第2章：业火不收',
    'pov': '张影',
    'beat': '涤罪所酷刑与吞噬业火，黑煞鬼将带回折损消息，主簿把张影打成灰牌耗材发往灰营。',
  },
  {
    'title': '第3章：灰营疯狗',
    'pov': '张影',
    'beat': '进入灰营，见屠夫、老算盘、小倩和牢头；冲突升级到张影瞬杀牢头，再用锁魂链自缚手臂立下疯狗名声。',
  },
  {
    'title': '第4章：黑吃黑',
    'pov': '张影',
    'beat': '第一次阳间任务，洛九川暗中强化尸傀导致鬼差惨死，张影在生死边缘吞掉鬼差与残余阴差力量。',
  },
  {
    'title': '第5章：孽镜碎响',
    'pov': '张影',
    'beat': '洛九川教授伪造符文；回溯孽镜查验张影时因无法解析混沌而碎裂，主簿与提刑官带着恐惧封卷。',
  },
  {
    'title': '第6章：断香庙',
    'pov': '张影',
    'beat': '灰营小队被派去处理伪神庙祝一线，小倩童谣第一次对黑水将军的气息起反应，屠夫也对供奉方式表现出异常厌恶。',
  },
  {
    'title': '第7章：凡火斩神',
    'pov': '赵铁柱',
    'beat': '限定屠夫视角，写他被童男童女遗物刺激后想起村民和女儿，最终以凡人怒火拔刀劈碎神光，张影趁机吞下伪神赐福。',
  },
  {
    'title': '第8章：金黑之血',
    'pov': '张影',
    'beat': '吞噬赐福后连续咳出金色黑血，精神被庙祝死前惨叫污染；屠夫更认可他，小倩更贴近他，老算盘意识到他是无法做平的坏账。',
  },
  {
    'title': '第9章：阴德旧账',
    'pov': '陈账房',
    'beat': '限定老算盘视角，写纠察司如何拿孙子阴德账户逼他做供状，写足他的抹零法、求活算计、对孙子的执念和对张影的惧怕。',
  },
  {
    'title': '第10章：吃掉口供',
    'pov': '张影',
    'beat': '公堂对质，主簿把供状变成具象证据，张影在极限压迫里先吃掉纸面口供，再追咬老算盘脑海里的概念记忆。',
  },
  {
    'title': '第11章：无证之堂',
    'pov': '张影',
    'beat': '承接公堂崩坏余震，证据消失却无人能解释，主簿拼命维持秩序，老算盘发现自己脑中某段供状与概念被抠空，最后只能无证放人。',
  },
  {
    'title': '第12章：赢下冥律',
    'pov': '张影',
    'beat': '张影表面赢过制度一回却没有喜悦，只有空；屠夫和小倩更靠近他，老算盘更怕他，结尾埋下巨大代价即将爆发的不安。',
  },
  {
    'title': '第13章：外婆失面',
    'pov': '张影',
    'beat': '代价爆发，张影再也想不起外婆的脸，只剩银镯残念和回家吃饭的幻听；赢了冥律却丢掉灵魂的一块。',
  },
  {
    'title': '第14章：洗髓令',
    'pov': '噬心主簿',
    'beat': '限定主簿视角，写他如何把混沌异常包装成合法洗髓大阵项目，官僚式自保、绩效恐惧和自我合理化要写足。',
  },
  {
    'title': '第15章：阵中耗材',
    'pov': '小倩',
    'beat': '限定小倩视角，用儿童化感知写大阵开启，她和屠夫像被一点点抽空；童谣自然浮出黑水将军真名碎片。',
  },
  {
    'title': '第16章：阵外账房',
    'pov': '陈账房',
    'beat': '老算盘被放在阵外做记录与核销，一边自我催眠一边看着熟人被合法做成电池；黑煞鬼将和主簿的冷硬对话让他明白自己也是弃子。',
  },
  {
    'title': '第17章：请吃我',
    'pov': '张影',
    'beat': '大阵逼到绝境，屠夫断腿仍护着小倩，张影被饥饿和剧痛撕扯；屠夫主动要求张影吃掉自己，把恨和活路一起吞下。',
  },
  {
    'title': '第18章：断腿幻痛',
    'pov': '张影',
    'beat': '张影在极度清醒里撕碎并吞噬屠夫，力量暴涨的同时背上永恒断腿幻痛；黑煞鬼将意识到局势失控，开始做最后选择。',
  },
  {
    'title': '第19章：阵眼火雨',
    'pov': '黑煞鬼将',
    'beat': '限定鬼将视角，写他判断继续效忠只会被系统清算，于是自爆炸碎阵眼；不是行善，只是把危险兵器放去咬更该死的人。',
  },
  {
    'title': '第20章：灰雾九成',
    'pov': '张影',
    'beat': '张影同化度飙到九成，魂体几乎化成灰雾；写他杀穿追兵时既像复仇者又像天灾，小倩旋律和屠夫幻痛一起拉着他别彻底散掉。',
  },
  {
    'title': '第21章：啃断法相',
    'pov': '张影',
    'beat': '主簿祭出判官法相镇压，张影在狂暴中斩断并咬碎那一指法相，代价是骨骼液化和形体崩溃，必须写成濒死错位而不是热血升级。',
  },
  {
    'title': '第22章：坠入归墟',
    'pov': '张影',
    'beat': '写张影在骨架崩散和灰雾化之间坠进死地归墟，这是失重、失名、失身的坠落；外婆残响和混沌饥饿都像快断掉的线。',
  },
  {
    'title': '第23章：墟海残骸',
    'pov': '张影',
    'beat': '归墟篇从纯粹死地与残骸开始，张影在墟海里看见魔神残骨、破碎规则和被吃剩的名字。',
  },
  {
    'title': '第24章：链生肉死',
    'pov': '张影',
    'beat': '张影吞噬魔神残骸，肉身与锁链开始诡异融合；屠夫幻痛、小倩童谣、外婆银镯残响同时参与蜕变。',
  },
  {
    'title': '第25章：灰无常',
    'pov': '洛九川',
    'beat': '限定洛九川视角，看见张影自归墟走出真正成为灰无常；他意识到自己押中的不是工具，而是会反咬整个制度的存在。',
  },
  {
    'title': '第26章：返殿',
    'pov': '张影',
    'beat': '张影杀回森罗殿外围，系统兵器、鬼差规制和旧刑具在灰无常面前一层层失效；黑煞鬼将的军人习惯和遗言仍在张影行动里留下痕迹。',
  },
  {
    'title': '第27章：咬碎副册',
    'pov': '噬心主簿',
    'beat': '限定主簿视角，写防线彻底崩塌，他还在试图用条文与法理壮胆，最后亲眼看着张影掐住自己并盯上生死簿副册。',
  },
  {
    'title': '第28章：主簿成凡',
    'pov': '张影',
    'beat': '张影一口咬碎生死簿副册，基层死亡法则瘫痪，刑具成废铁，主簿被从制度神力里剥出来，真正沦成会怕痛会发抖的凡人。',
  },
  {
    'title': '第29章：吃自己人',
    'pov': '张影',
    'beat': '主簿当众说出老算盘孙子早被炼丹的真相，老算盘精神崩塌；张影下令让残存鬼差活活撕碎并分食老算盘，以公开吃人仪式立下新法则。',
  },
  {
    'title': '第30章：遥指黑水',
    'pov': '张影',
    'beat': '卷终后的短暂静止，张影踩着主簿，摸到银镯残念，体内同时有屠夫的痛、小倩的咒和自己的饥饿；他用滴血杀猪刀遥指黑水将军神庙。',
  },
];

Future<void> _cleanupWuchangData(AppDatabase db) async {
  final workRows = await db
      .customSelect(
        'SELECT id FROM works WHERE name = ?',
        variables: [const Variable<String>(_workName)],
        readsFrom: {db.works},
      )
      .get();
  final workIds = workRows.map((row) => row.read<String>('id')).toList();
  await db.customStatement('DROP TRIGGER IF EXISTS chapters_ad');
  await db.customStatement('DROP TRIGGER IF EXISTS chapters_au');
  await db.customStatement('DROP TRIGGER IF EXISTS chapters_ai');
  await db.customStatement('DROP TABLE IF EXISTS chapters_fts');
  for (final workId in workIds) {
    await db.transaction(() async {
      await (db.delete(
        db.inspirations,
      )..where((t) => t.workId.equals(workId))).go();
      await (db.delete(
        db.chatConversations,
      )..where((t) => t.workId.equals(workId))).go();
      await (db.delete(db.works)..where((t) => t.id.equals(workId))).go();
    });
  }
}

Future<String> _readSource(String path) async {
  final file = File(path);
  if (!await file.exists()) return '';
  return file.readAsString();
}

String _clip(String text, int max) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= max) return normalized;
  return '${normalized.substring(0, max)}...';
}

String _buildBatchPrompt(List<Map<String, String>> tasks) {
  final chapterList = tasks
      .asMap()
      .entries
      .map((entry) {
        final index = entry.key + 1;
        final task = entry.value;
        return '$index. 标题=${task['title']} | POV=${task['pov']} | 任务=${task['beat']}';
      })
      .join('\n');
  return '''
请连续写 ${tasks.length} 章《黑神话：无常》第一卷内容，并直接保存到当前作品的$_volumeName。

硬性要求：
1. 每章 4500 字左右，不能低于 4000 字
2. 每章都必须严格单一限制视角
3. 不允许上帝视角旁白、不允许说教性总结、不允许主题点题、不允许作者解释
4. 人物发言和行为必须服从设定，不能突然全知
5. 必须承接已保存的世界观、卷纲、角色设定和已写章节事实
6. 章节之间要连续推进，不要每章重讲世界观

章节任务列表：
$chapterList
''';
}

void main() {
  setUpAll(_loadSqlite3WithFts5);

  test(
    'reimport wuchang via chatservice with cleanup and parallel setup',
    () async {
      Get.reset();
      final dbFile = File(_dbPath);
      await dbFile.parent.create(recursive: true);
      final db = AppDatabase.connect(
        DatabaseConnection(NativeDatabase(dbFile)),
      );

      try {
        if (!_resumeImport) {
          await _cleanupWuchangData(db);
        }

        final providerConfig = ProviderConfig(
          id: 'chatservice_provider',
          type: core_model.AIProviderType.openai,
          name: 'Local LM Studio',
          apiKey: _apiKey,
          apiEndpoint: _endpoint,
          timeoutSeconds: 3600,
          maxRetries: 3,
        );
        final modelConfig = core_model.ModelConfig(
          id: 'chatservice_model',
          tier: ModelTier.thinking,
          displayName: _modelName,
          providerType: 'openai',
          modelName: _modelName,
          temperature: 0.4,
          maxOutputTokens: 12000,
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
        final locationRepo = LocationRepository(db);
        final relationshipRepo = RelationshipRepository(db);
        final inspirationRepo = InspirationRepository(db);
        final chatRepo = ChatRepository(db);

        Get.put<VolumeRepository>(volumeRepo);
        Get.put<ChapterRepository>(chapterRepo);
        Get.put<LocationRepository>(locationRepo);

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
                        (item) => item.name.toLowerCase() == tier.toLowerCase(),
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
                    tier: character.tier.toString(),
                  );
                },
          ),
        );
        toolRegistry.register(
          CreateLocationTool(
            createFn:
                ({
                  required workId,
                  required name,
                  type,
                  parentId,
                  description,
                  importantPlaces,
                }) async {
                  final location = await locationRepo.createLocation(
                    workId: workId,
                    name: name,
                    type: type,
                    parentId: parentId,
                    description: description,
                    importantPlaces: importantPlaces,
                  );
                  return (id: location.id, name: location.name);
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
                      (item) =>
                          item.name.toLowerCase() == relationType.toLowerCase(),
                      orElse: () => relationship_domain.RelationType.neutral,
                    ),
              );
              return (
                id: relation.id,
                relationType: relation.relationType.toString(),
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
            listFn: () async =>
                (await workRepo.getAllWorks(includeArchived: true))
                    .map(
                      (work) => {
                        'id': work.id,
                        'name': work.name,
                        'type': work.type ?? '',
                      },
                    )
                    .toList(),
          ),
        );
        toolRegistry.register(
          ListVolumesTool(
            listFn: (workId) async =>
                (await volumeRepo.getVolumesByWorkId(workId))
                    .map(
                      (volume) => {
                        'id': volume.id,
                        'name': volume.name,
                        'sort_order': volume.sortOrder.toString(),
                      },
                    )
                    .toList(),
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

        final existingWorks = await workRepo.getAllWorks(includeArchived: true);
        final matchedWorks =
            existingWorks.where((item) => item.name == _workName).toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final work = _resumeImport && matchedWorks.isNotEmpty
            ? matchedWorks.first
            : await workRepo.createWork(
                CreateWorkParams(
                  name: _workName,
                  type: 'dark_fantasy',
                  description: '伪神纪元下的地府黑暗奇诡长篇，第一卷为灰烬新生。',
                  targetWords: 150000,
                ),
              );
        final existingVolumes = await volumeRepo.getVolumesByWorkId(work.id);
        if (!existingVolumes.any((item) => item.name == _volumeName)) {
          await volumeRepo.createVolume(
            workId: work.id,
            name: _volumeName,
            sortOrder: 1,
          );
        }

        Future<void> runTurn({
          required String conversationId,
          required String workId,
          required String message,
        }) async {
          print('\n===== TURN =====\n${_clip(message, 220)}');
          final stream = chatService.sendMessageStreamWithTools(
            conversationId: conversationId,
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
              case ChatBatchProgress(
                :final phase,
                :final completed,
                :final total,
              ):
                print('[batch-progress] $phase $completed/$total');
              case ChatBatchChapterDone(
                :final index,
                :final title,
                :final wordCount,
              ):
                print('[batch-chapter] #$index $title $wordCount');
              case ChatBatchComplete(:final totalWords, :final chapters):
                print(
                  '[batch-complete] chapters=${chapters.length} words=$totalWords',
                );
              case ChatChunk(:final chunk):
                if (chunk.trim().isNotEmpty)
                  print('[chunk] ${_clip(chunk, 120)}');
              case ChatComplete(:final fullContent):
                print('[complete] ${_clip(fullContent, 300)}');
              case ChatError(:final error):
                lastError = error;
                print('[error] $error');
              default:
                break;
            }
          }
          expect(lastError, equals(null), reason: '回合执行失败: $lastError');
        }

        Future<void> runSetupTurn({
          required String conversationId,
          required String workId,
          required String message,
          required String expectedTool,
        }) async {
          print('\n===== TURN =====\n${_clip(message, 220)}');
          final stream = chatService.sendMessageStreamWithTools(
            conversationId: conversationId,
            userMessage: message,
            workId: workId,
          );
          String? lastError;
          var sawSuccess = false;
          final completer = Completer<void>();
          late final StreamSubscription<ChatStreamEvent> subscription;
          subscription = stream.listen(
            (event) {
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
                  if (success && toolName == expectedTool) {
                    sawSuccess = true;
                    if (!completer.isCompleted) completer.complete();
                    subscription.cancel();
                  }
                case ChatError(:final error):
                  lastError = error;
                  print('[error] $error');
                  if (!completer.isCompleted) completer.complete();
                default:
                  break;
              }
            },
            onError: (error) {
              lastError = error.toString();
              if (!completer.isCompleted) completer.complete();
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
          );
          await completer.future;
          expect(lastError, equals(null), reason: '鍥炲悎鎵ц澶辫触: $lastError');
          expect(sawSuccess, isTrue, reason: '鏈湅鍒版湡鏈涚殑宸ュ叿鎴愬姛: $expectedTool');
        }

        Future<void> runPromptWave(
          List<String> messages,
          String titlePrefix,
          String expectedTool, {
          int batchSize = 4,
          bool stopOnFirstSuccessfulTool = true,
        }) async {
          for (var start = 0; start < messages.length; start += batchSize) {
            final end = (start + batchSize).clamp(0, messages.length);
            final wave = messages.sublist(start, end);
            await Future.wait(
              wave.asMap().entries.map((entry) async {
                final conversation = await chatService.createConversation(
                  workId: work.id,
                  title: '$titlePrefix-${start + entry.key + 1}',
                  source: 'chatservice-import',
                );
                if (stopOnFirstSuccessfulTool) {
                  await runSetupTurn(
                    conversationId: conversation.id,
                    workId: work.id,
                    message: entry.value,
                    expectedTool: expectedTool,
                  );
                } else {
                  await runTurn(
                    conversationId: conversation.id,
                    workId: work.id,
                    message: entry.value,
                  );
                }
              }),
            );
          }
        }

        final worldPrompts = <String>[
          '请直接调用 create_inspiration，为当前作品创建 1 条 worldbuilding 素材，标题为“第一卷世界法则”，内容必须写清：真神已献祭、伪神与地府官僚维持秩序、混沌不可观测且会让生死簿与孽镜失效、系统性绞杀是第一卷所有悲剧的根源。',
          '请直接调用 create_inspiration，为当前作品创建 1 条 character_sketch 素材，标题为“第一卷视角铁律”，内容必须写清：单一限制视角、禁止上帝视角、禁止说教性总结、角色不得越认知边界。',
          '请直接调用 create_inspiration，为当前作品创建 1 条 scene_fragment 素材，标题为“场景种子：森罗殿误判”，内容写张影被定为窃命、业火酷刑、主簿甩锅的场景张力。',
          '请直接调用 create_inspiration，为当前作品创建 1 条 scene_fragment 素材，标题为“场景种子：灰营生存”，内容写灰营耗材秩序、牢头折辱、疯狗名声的建立。',
          '请直接调用 create_inspiration，为当前作品创建 1 条 scene_fragment 素材，标题为“场景种子：断香庙”，内容写伪神庙祝、神光、童男童女供奉痕迹以及屠夫的怒火。',
          '请直接调用 create_inspiration，为当前作品创建 1 条 scene_fragment 素材，标题为“场景种子：洗髓大阵”，内容写主簿合法抹杀、屠夫小倩沦为电池、张影被逼到吞噬挚友的边缘。',
          '请直接调用 create_inspiration，为当前作品创建 1 条 scene_fragment 素材，标题为“场景种子：归墟蜕变”，内容写坠入归墟、吞噬魔神残骸、灰无常成型以及回指黑水神庙。',
        ];
        final characterPrompts = <String>[
          '请直接调用 create_character，为当前作品创建以下角色：'
              '${_characterSeeds.take(3).map((seed) {
                final tier = seed['tier']! as character_domain.CharacterTier;
                final aliases = (seed['aliases']! as List<String>).join(",");
                return "\\n- name=${seed['name']} tier=${tier.name} aliases=$aliases identity=${seed['identity']} bio=${seed['bio']}";
              }).join()}',
          '请直接调用 create_character，为当前作品创建以下角色：'
              '${_characterSeeds.skip(3).take(3).map((seed) {
                final tier = seed['tier']! as character_domain.CharacterTier;
                final aliases = (seed['aliases']! as List<String>).join(",");
                return "\\n- name=${seed['name']} tier=${tier.name} aliases=$aliases identity=${seed['identity']} bio=${seed['bio']}";
              }).join()}',
          '请直接调用 create_character，为当前作品创建以下角色：'
              '${_characterSeeds.skip(6).map((seed) {
                final tier = seed['tier']! as character_domain.CharacterTier;
                final aliases = (seed['aliases']! as List<String>).join(",");
                return "\\n- name=${seed['name']} tier=${tier.name} aliases=$aliases identity=${seed['identity']} bio=${seed['bio']}";
              }).join()}',
        ];
        final locationPrompts = <String>[
          '请直接调用 create_location，为当前作品创建以下地点：${_locationSeeds.take(4).map((seed) => "\\n- name=${seed['name']} type=${seed['type']} description=${seed['description']}").join()}',
          '请直接调用 create_location，为当前作品创建以下地点：${_locationSeeds.skip(4).map((seed) => "\\n- name=${seed['name']} type=${seed['type']} description=${seed['description']}").join()}',
        ];

        final singleCharacterPrompts = _characterSeeds.map((seed) {
          final tier = seed['tier']! as character_domain.CharacterTier;
          final aliases = (seed['aliases']! as List<String>).join(',');
          return '请直接调用 create_character，为当前作品创建角色：name=${seed['name']} tier=${tier.name} aliases=$aliases identity=${seed['identity']} bio=${seed['bio']}';
        }).toList();
        final singleLocationPrompts = _locationSeeds.map((seed) {
          return '请直接调用 create_location，为当前作品创建地点：name=${seed['name']} type=${seed['type']} description=${seed['description']}';
        }).toList();

        final existingInspirationsBeforeImport = await inspirationRepo
            .getByWorkId(work.id);
        final existingCharactersBeforeImport = await characterRepo
            .getCharactersByWorkId(work.id, includeArchived: true);
        final existingLocationsBeforeImport = await locationRepo
            .getLocationsByWorkId(work.id, includeArchived: true);

        final pendingWorldPrompts = worldPrompts
            .skip(
              existingInspirationsBeforeImport.length.clamp(
                0,
                worldPrompts.length,
              ),
            )
            .toList();
        final pendingCharacterPrompts = singleCharacterPrompts
            .skip(
              existingCharactersBeforeImport.length.clamp(
                0,
                singleCharacterPrompts.length,
              ),
            )
            .toList();
        final pendingLocationPrompts = singleLocationPrompts
            .skip(
              existingLocationsBeforeImport.length.clamp(
                0,
                singleLocationPrompts.length,
              ),
            )
            .toList();

        await runPromptWave(
          pendingWorldPrompts,
          'world',
          'create_inspiration',
          batchSize: 1,
        );
        await runPromptWave(
          pendingCharacterPrompts,
          'character',
          'create_character',
          batchSize: 3,
        );
        await runPromptWave(
          pendingLocationPrompts,
          'location',
          'create_location',
          batchSize: 3,
        );

        final importedCharacters = await characterRepo.getCharactersByWorkId(
          work.id,
          includeArchived: true,
        );
        final characterByName = {
          for (final item in importedCharacters) item.name: item,
        };
        final relationshipLines = _relationshipSeeds
            .map((seed) {
              final a = characterByName[seed['a']]!;
              final b = characterByName[seed['b']]!;
              final type = seed['type']! as relationship_domain.RelationType;
              return '- ${seed['a']}=${a.id} <-> ${seed['b']}=${b.id} | relation=${type.name}';
            })
            .join('\n');

        final relationConv = await chatService.createConversation(
          workId: work.id,
          title: '关系导入',
          source: 'chatservice-import',
        );
        await runSetupTurn(
          conversationId: relationConv.id,
          workId: work.id,
          message:
              '请直接调用 create_relationship，把以下角色关系导入当前作品，必须使用给定的 ID：\n$relationshipLines',
          expectedTool: 'create_relationship',
        );

        final selectedTasks = _chapterTasks.sublist(
          _startChapter - 1,
          _endChapter,
        );
        final chapterConv = await chatService.createConversation(
          workId: work.id,
          title: '第一卷章节写入',
          source: 'chatservice-import',
        );
        if (selectedTasks.length == 1) {
          final task = selectedTasks.first;
          await runSetupTurn(
            conversationId: chapterConv.id,
            workId: work.id,
            message:
                '''
请直接调用 create_chapter，把 ${task['title']} 写入当前作品的$_volumeName。
要求：单一限制视角=${task['pov']}；正文不少于4000字；不允许上帝视角和说教总结；必须承接既有设定与前文事实。
本章任务：${task['beat']}
''',
            expectedTool: 'create_chapter',
          );
        } else {
          await runTurn(
            conversationId: chapterConv.id,
            workId: work.id,
            message: _buildBatchPrompt(selectedTasks),
          );
        }

        final chapters = await chapterRepo.getChaptersByWorkId(work.id);
        final targetTitles = selectedTasks
            .map((task) => task['title']!)
            .toSet();
        final importedChapters = chapters
            .where((chapter) => targetTitles.contains(chapter.title))
            .toList();
        final shortChapters = importedChapters
            .where((chapter) => (chapter.content ?? '').trim().length < 4000)
            .map(
              (chapter) => {
                'title': chapter.title,
                'length': (chapter.content ?? '').trim().length,
              },
            )
            .toList();
        final locations = await locationRepo.getLocationsByWorkId(
          work.id,
          includeArchived: true,
        );
        final inspirations = await inspirationRepo.getByWorkId(work.id);
        final relationships = await relationshipRepo.getRelationshipsByWorkId(
          work.id,
        );

        print('===== REIMPORT SUMMARY =====');
        print(
          const JsonEncoder.withIndent('  ').convert({
            'work_id': work.id,
            'chapter_count': importedChapters.length,
            'character_count': importedCharacters.length,
            'location_count': locations.length,
            'relationship_count': relationships.length,
            'inspiration_count': inspirations.length,
            'short_chapters': shortChapters,
          }),
        );

        expect(
          importedCharacters.length,
          greaterThanOrEqualTo(_characterSeeds.length),
        );
        expect(locations.length, greaterThanOrEqualTo(_locationSeeds.length));
        expect(
          relationships.length,
          greaterThanOrEqualTo(_relationshipSeeds.length),
        );
        expect(
          inspirations
              .where((item) => item.category == 'worldbuilding')
              .isNotEmpty,
          isTrue,
        );
        expect(
          inspirations
              .where((item) => item.category == 'scene_fragment')
              .length,
          greaterThanOrEqualTo(4),
        );
        expect(importedChapters.length, selectedTasks.length);
        expect(shortChapters, isEmpty);
      } finally {
        ToolRegistry().clear();
        await db.close();
        Get.reset();
      }
    },
    timeout: const Timeout(Duration(hours: 4)),
  );
}
