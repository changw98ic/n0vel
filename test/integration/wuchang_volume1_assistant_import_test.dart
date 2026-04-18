@Tags(['integration'])
library;

import 'dart:convert';
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
      id: 'assistant_${tier.name}_$_modelName',
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

const _chapterTasks = <Map<String, String>>[
  {
    'title': '第1章：错寿之人',
    'pov': '张影',
    'beat': '车祸暴毙，魂体被强行拖入森罗殿，发现生死簿副册写着自己十六岁就该死，二十六岁的死反而成了错账，最后被定为窃命。',
  },
  {
    'title': '第2章：业火不收',
    'pov': '张影',
    'beat': '主簿审判，张影在涤罪所遭业火酷刑并本能吞掉业火，刑具失控；黑煞鬼将带回阳间鬼差折损消息，主簿把张影发往灰营做灰牌耗材。',
  },
  {
    'title': '第3章：灰营疯狗',
    'pov': '张影',
    'beat': '进入灰营，见到屠夫、老算盘、小倩和牢头，写清灰营的耗材秩序；冲突升级到张影瞬杀牢头，再用锁魂链自缚手臂立下疯狗名声。',
  },
  {
    'title': '第4章：黑吃黑',
    'pov': '张影',
    'beat': '第一次押去阳间出任务，洛九川暗中强化尸傀导致正式鬼差惨死；张影在生死边缘黑吃黑，吞掉鬼差和残余阴差力量，洛九川因此注意到他。',
  },
  {
    'title': '第5章：孽镜碎响',
    'pov': '张影',
    'beat': '洛九川现身并教授伪造符文；提刑司用回溯孽镜查验张影，孽镜无法解析混沌而当场碎裂，主簿与提刑官带着恐惧封卷。',
  },
  {
    'title': '第6章：断香庙',
    'pov': '张影',
    'beat': '灰营小队被派去处理伪神庙祝一线，庙内神光带来压迫，小倩的童谣第一次明确对黑水将军的气息起反应，屠夫则对供奉方式显出异常厌恶。',
  },
  {
    'title': '第7章：凡火斩神',
    'pov': '赵铁柱',
    'beat': '限定屠夫视角，写他被庙里童男童女遗物刺激，想起村民和女儿，最终以凡人怒火拔刀劈碎神光；张影趁机吞下伪神赐福。',
  },
  {
    'title': '第8章：金黑之血',
    'pov': '张影',
    'beat': '吞噬赐福后连续咳出金色黑血，精神被庙祝死前惨叫污染；队内关系重新洗牌，屠夫更认可他，小倩更贴近他，老算盘意识到他是无法做平的坏账。',
  },
  {
    'title': '第9章：阴德旧账',
    'pov': '陈账房',
    'beat': '限定老算盘视角，写纠察司如何拿孙子阴德账户逼他做供状；要把他的抹零法、求活算计、对孙子的执念和对张影的惧怕写出来。',
  },
  {
    'title': '第10章：吃掉口供',
    'pov': '张影',
    'beat': '公堂对质，主簿把老算盘供状变成具象证据，试图把窃命案钉死；张影在极限压迫里发动混沌，先吃掉纸面口供，再追咬老算盘脑海里的概念记忆。',
  },
  {
    'title': '第11章：无证之堂',
    'pov': '张影',
    'beat':
        '承接公堂崩坏余震，所有人都看见证据消失却无法解释，主簿拼命维持秩序，老算盘发现自己脑中某段供状与概念被抠空，最后只能在无证状态下放人。',
  },
  {
    'title': '第12章：赢下冥律',
    'pov': '张影',
    'beat': '写张影表面赢过制度一回却没有喜悦，只有空；屠夫和小倩更靠近他，老算盘更怕他，结尾埋下巨大代价即将爆发的不安。',
  },
  {
    'title': '第13章：外婆失面',
    'pov': '张影',
    'beat': '代价爆发，张影发现自己再也想不起外婆的脸，只剩银镯残念和“回家吃饭”的幻听；赢了冥律却丢掉灵魂的一块。',
  },
  {
    'title': '第14章：洗髓令',
    'pov': '噬心主簿',
    'beat': '限定主簿视角，写他如何把混沌异常包装成合法洗髓大阵项目，官僚式自保、绩效恐惧和自我合理化要写足。',
  },
  {
    'title': '第15章：阵中耗材',
    'pov': '小倩',
    'beat': '限定小倩视角，用儿童化感知写大阵开启，她和屠夫像被一点点抽空；童谣自然浮出黑水将军真名碎片，张影在阵内被压住无法立刻救人。',
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
    'beat': '限定鬼将视角，写他判断继续效忠只会被系统清算，于是自爆炸碎阵眼；他不是行善，只是把危险兵器放去咬更该死的人。',
  },
  {
    'title': '第20章：灰雾九成',
    'pov': '张影',
    'beat': '阵破后张影同化度飙到九成，魂体几乎化成灰雾；写他杀穿追兵时既像复仇者又像天灾，小倩旋律和屠夫幻痛一起拉着他别彻底散掉。',
  },
  {
    'title': '第21章：啃断法相',
    'pov': '张影',
    'beat': '主簿祭出判官法相镇压，张影在狂暴中硬生生斩断并咬碎那一指法相，代价是骨骼液化和形体崩溃，必须写成濒死错位而不是热血升级。',
  },
  {
    'title': '第22章：坠入归墟',
    'pov': '张影',
    'beat': '写张影在骨架崩散和灰雾化之间坠进死地归墟，这是一场失重、失名、失身的坠落；外婆残响和混沌饥饿都像快断掉的线。',
  },
  {
    'title': '第23章：墟海残骸',
    'pov': '张影',
    'beat': '归墟篇从纯粹死地与残骸开始，张影在墟海里看见魔神残骨、破碎规则和被吃剩的名字；不要大篇科普，而是让他像溺水者一样摸出归墟的秩序。',
  },
  {
    'title': '第24章：链生肉死',
    'pov': '张影',
    'beat': '张影吞噬魔神残骸，肉身与锁链开始诡异融合；屠夫幻痛、小倩童谣、外婆银镯残响同时参与这场蜕变，让新形态由代价压出来。',
  },
  {
    'title': '第25章：灰无常',
    'pov': '洛九川',
    'beat': '限定洛九川视角，看见张影自归墟走出真正成为灰无常；他意识到自己押中的不是工具，而是会反咬整个制度的存在。',
  },
  {
    'title': '第26章：返殿',
    'pov': '张影',
    'beat': '张影杀回森罗殿外围，系统兵器、鬼差规制和旧刑具在灰无常面前一层层失效；黑煞鬼将虽死，其军人习惯和遗言仍在张影行动里留下痕迹。',
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
    'beat':
        '卷内最高点，主簿当众说出老算盘孙子早被炼丹的真相，老算盘精神崩塌；张影下令让残存鬼差活活撕碎并分食老算盘，以公开吃人仪式立下“吃了自己人的，才是无常”。',
  },
  {
    'title': '第30章：遥指黑水',
    'pov': '张影',
    'beat':
        '卷终后的短暂静止，张影踩着主簿，摸到银镯残念，体内同时有屠夫的痛、小倩的咒和自己的饥饿；他用滴血杀猪刀遥指阳间黑水将军神庙，确立下一卷屠神大战方向。',
  },
];

final _characterSeeds = <Map<String, Object>>[
  {
    'name': '张影',
    'aliases': <String>['灰无常'],
    'tier': character_domain.CharacterTier.protagonist,
    'identity': '被误判为窃命罪魂的灰营耗材，后来自封灰无常',
    'bio': '混沌容器，心口有灰色漩涡。越痛越清醒，越饿越像野兽。唯一的人性锚点是外婆留下的银镯残念。',
  },
  {
    'name': '赵铁柱',
    'aliases': <String>['屠夫'],
    'tier': character_domain.CharacterTier.supporting,
    'identity': '被污名化的屠夫，灰营耗材',
    'bio': '为保护村民杀死三十六名伪神信徒，却被卷宗定成凶犯。手里的生锈杀猪刀能亵渎伪神。',
  },
  {
    'name': '陈账房',
    'aliases': <String>['老算盘'],
    'tier': character_domain.CharacterTier.supporting,
    'identity': '灰营账房兼统计员',
    'bio': '靠抹零法偷阴德给阳间孙子续命，越算越深，最后发现自己一直在给死人记账。',
  },
  {
    'name': '小倩',
    'aliases': <String>[],
    'tier': character_domain.CharacterTier.supporting,
    'identity': '被献祭给黑水将军的溺死少女',
    'bio': '总哼唱带有古神语碎片的童谣，童谣本质上是残缺弑神咒与诅咒信标。',
  },
  {
    'name': '噬心主簿',
    'aliases': <String>[],
    'tier': character_domain.CharacterTier.majorAntagonist,
    'identity': '窃据判官位、代理森罗殿的主簿',
    'bio': '典型绩效官僚，最在乎秩序稳定和责任不落到自己身上，擅长把甩锅包装成制度正义。',
  },
  {
    'name': '黑煞鬼将',
    'aliases': <String>[],
    'tier': character_domain.CharacterTier.antagonist,
    'identity': '地府前线将领',
    'bio': '生前是名将，死后反抗地府失败，被驯成恶犬，把张影视作危险但好用的兵器。',
  },
  {
    'name': '洛九川',
    'aliases': <String>['前任白无常'],
    'tier': character_domain.CharacterTier.antagonist,
    'identity': '三百年前叛逃的白无常',
    'bio': '藏着半截哭丧棒和不完整的小轮回，帮助张影时夹着赎罪欲和实验心。',
  },
  {
    'name': '黑水将军',
    'aliases': <String>[],
    'tier': character_domain.CharacterTier.majorAntagonist,
    'identity': '伪河神',
    'bio': '曾经治水，后堕成靠童男童女献祭续命的怪物，以顾全大局自我催眠。',
  },
  {
    'name': '沉睡阎罗',
    'aliases': <String>['伪阎罗'],
    'tier': character_domain.CharacterTier.majorAntagonist,
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
  {
    'name': '森罗殿',
    'type': '建筑',
    'description': '地府权力核心，主簿窃据判官位后把这里经营成只认卷宗与绩效的审判机器。',
  },
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
  {
    'name': '断香庙',
    'type': '建筑',
    'description': '供奉伪神的阴阳交界神庙，香火腥甜，神光里混着献祭童男童女的怨气。',
  },
  {
    'name': '望乡台',
    'type': '区域',
    'description': '魂灵回望阳世的地方，也是洗髓大阵施行后绝望最容易聚成形的地方。',
  },
  {
    'name': '归墟',
    'type': '区域',
    'description': '死地中的死地，堆满魔神残骸、失效法则和被吞剩的名字，时间与因果都不稳定。',
  },
  {
    'name': '黑水将军神庙',
    'type': '建筑',
    'description': '阳间黑水河畔的伪神神庙，以童男童女献祭续命，是第一卷卷终所指向的屠神战场。',
  },
];

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
        return '$index. 标题建议：${task['title']} | POV=${task['pov']} | 任务=${task['beat']}';
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

Future<void> _cleanupWuchangData(AppDatabase db) async {
  final workRows = await db.customSelect(
    'SELECT id FROM works WHERE name = ?',
    variables: [const Variable<String>(_workName)],
    readsFrom: {db.works},
  ).get();

  final workIds = workRows.map((row) => row.read<String>('id')).toList();
  if (workIds.isEmpty) return;

  for (final workId in workIds) {
    await db.transaction(() async {
      await (db.delete(db.inspirations)..where((t) => t.workId.equals(workId))).go();
      await (db.delete(db.chatConversations)..where((t) => t.workId.equals(workId))).go();
      await (db.delete(db.works)..where((t) => t.id.equals(workId))).go();
    });
  }
}

void main() {
  setUpAll(_loadSqlite3WithFts5);

  test(
    'assistant imports wuchang volume one into the main database',
    () async {
      Get.reset();
      final dbFile = File(_dbPath);
      await dbFile.parent.create(recursive: true);
      final db = AppDatabase.connect(
        DatabaseConnection(NativeDatabase(dbFile)),
      );

      try {
        await _cleanupWuchangData(db);

        final providerConfig = ProviderConfig(
          id: 'assistant_provider',
          type: core_model.AIProviderType.openai,
          name: 'Local LM Studio',
          apiKey: _apiKey,
          apiEndpoint: _endpoint,
          timeoutSeconds: 1800,
          maxRetries: 1,
        );
        final modelConfig = core_model.ModelConfig(
          id: 'assistant_model',
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
                      (item) =>
                          item.name.toLowerCase() == relationType.toLowerCase(),
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
          ListWorksTool(
            listFn: () async {
              final works = await workRepo.getAllWorks(includeArchived: true);
              return works
                  .map(
                    (work) => {
                      'id': work.id,
                      'name': work.name,
                      'type': work.type ?? '',
                    },
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
                    (volume) => {
                      'id': volume.id,
                      'name': volume.name,
                      'sort_order': volume.sortOrder.toString(),
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

        final plan = await _readSource('$_sourceRoot\\第一卷规划.md');
        final bible = await _readSource('$_sourceRoot\\第一卷角色设定.md');

        final works = await workRepo.getAllWorks(includeArchived: true);
        final existingWork =
            works.where((item) => item.name == _workName).toList()
              ..sort((a, b) => a.currentWords.compareTo(b.currentWords));
        final work = existingWork.isNotEmpty
            ? existingWork.first
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

        Future<void> upsertInspiration({
          required String title,
          required String content,
          required String category,
        }) async {
          final existing = await inspirationRepo.getByWorkId(work.id);
          final matched = existing
              .where((item) => item.title == title)
              .toList();
          if (matched.isEmpty) {
            await inspirationRepo.create(
              title: title,
              content: content,
              workId: work.id,
              category: category,
              source: 'assistant-import',
              tags: const ['黑神话无常', '第一卷'],
            );
            return;
          }
          await inspirationRepo.update(
            matched.first.id,
            title: title,
            content: content,
            category: category,
            tags: const ['黑神话无常', '第一卷'],
            source: 'assistant-import',
          );
        }

        await upsertInspiration(
          title: '世界观总纲：伪神纪元与混沌失效',
          content: bible,
          category: 'worldbuilding',
        );
        await upsertInspiration(
          title: '第一卷总纲：灰烬新生',
          content: plan,
          category: 'scene_fragment',
        );
        await upsertInspiration(
          title: '卷一视角铁律',
          content: '每章必须单一限制视角；不允许上帝视角；不允许说教性总结或主题点题；角色发言和行为必须服从自己的设定、身份和认知边界。',
          category: 'character_sketch',
        );

        final existingCharacters = await characterRepo.getCharactersByWorkId(
          work.id,
          includeArchived: true,
        );
        final characterByName = {
          for (final item in existingCharacters) item.name: item,
        };
        for (final seed in _characterSeeds) {
          if (characterByName.containsKey(seed['name'])) continue;
          final created = await characterRepo.createCharacter(
            character_domain.CreateCharacterParams(
              workId: work.id,
              name: seed['name']! as String,
              aliases: seed['aliases']! as List<String>,
              tier: seed['tier']! as character_domain.CharacterTier,
              identity: seed['identity']! as String,
              bio: seed['bio']! as String,
            ),
          );
          characterByName[created.name] = created;
        }

        for (final seed in _relationshipSeeds) {
          final a = characterByName[seed['a']]!;
          final b = characterByName[seed['b']]!;
          final existing = await relationshipRepo.getRelationshipBetween(
            a.id,
            b.id,
          );
          if (existing != null) continue;
          await relationshipRepo.createRelationship(
            workId: work.id,
            characterAId: a.id,
            characterBId: b.id,
            relationType: seed['type']! as relationship_domain.RelationType,
          );
        }

        final conversation = await chatService.createConversation(
          workId: work.id,
          title: '黑神话：无常第一卷写入',
          source: 'assistant-import',
        );

        Future<void> runTurn(String message, {required String workId}) async {
          print('\n===== TURN =====\n${_clip(message, 220)}');
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

        final selectedTasks = _chapterTasks.sublist(
          _startChapter - 1,
          _endChapter,
        );

        if (selectedTasks.length == 1) {
          final task = selectedTasks.first;
          await runTurn('''
请直接调用 create_chapter，把 ${task['title']} 写入当前作品的 $_volumeName。

硬性要求：
1. 标题必须就是：${task['title']}
2. 正文不少于 4000 个中文字符
3. 严格单一限制视角：${task['pov']}
4. 只能基于项目里已保存的世界观、卷纲、角色设定，以及已经写入的章节事实继续推进
5. 不允许上帝视角旁白、不允许说教性总结、不允许主题点题、不允许作者解释
6. 人物发言和行为必须服从设定，不能突然全知，不能越过当前 POV 的认知边界
7. 必须承接前文里的伤势、代价、线索、关系变化
8. create_chapter 的 content 必须一次性给出完整正文，不要先建空章

本章任务：
${task['beat']}
''', workId: work.id);
        } else {
          await runTurn(_buildBatchPrompt(selectedTasks), workId: work.id);
        }

        final volumes = await volumeRepo.getVolumesByWorkId(work.id);
        final chapters = await chapterRepo.getChaptersByWorkId(work.id);
        final characters = await characterRepo.getCharactersByWorkId(work.id);
        final relationships = await relationshipRepo.getRelationshipsByWorkId(
          work.id,
        );
        final inspirations = await inspirationRepo.getByWorkId(work.id);

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

        final summary = {
          'db_path': _dbPath,
          'model': _modelName,
          'endpoint': _endpoint,
          'work_name': work.name,
          'work_id': work.id,
          'volume_count': volumes.length,
          'chapter_count': importedChapters.length,
          'character_count': characters.length,
          'relationship_count': relationships.length,
          'inspiration_count': inspirations.length,
          'short_chapters': shortChapters,
        };
        print(
          '===== WUCHANG ASSISTANT SUMMARY =====\n'
          '${const JsonEncoder.withIndent('  ').convert(summary)}',
        );

        expect(volumes.any((volume) => volume.name == _volumeName), isTrue);
        expect(importedChapters.length, selectedTasks.length);
        expect(shortChapters, isEmpty);
        expect(characters.length, greaterThanOrEqualTo(9));
        expect(relationships.length, greaterThanOrEqualTo(6));
        expect(
          inspirations.any((item) => item.category == 'worldbuilding'),
          isTrue,
        );
      } finally {
        ToolRegistry().clear();
        await db.close();
        Get.reset();
      }
    },
    timeout: const Timeout(Duration(hours: 3)),
  );
}
