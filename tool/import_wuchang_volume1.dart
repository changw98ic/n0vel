import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
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

const _defaultDbPath = r'C:\Users\changw98\Documents\writing_assistant.db';
const _defaultSourceRoot = r'C:\Users\changw98\wuchang';
const _minChapterLength = 4000;
const _targetChapterLength = 4500;
const _workName = '黑神话：无常';
const _volumeName = '第一卷 灰烬新生';

const _worldRules = <String>[
  '伪神纪元里，真神已为抵御归墟潮息而献祭，现存秩序由域外伪神与地府官僚维持。',
  '混沌不可被现有秩序观测或定义，它表现为记录失效、因果错位、规则崩裂。',
  '所有人的悲剧都源于制度性绞杀，不要把冲突简化成脸谱化善恶对打。',
  '能力必须对应代价，越界越强，代价越重，而且代价要落在身体、记忆、理智或关系上。',
  '叙事只能通过角色看到、听到、猜到的内容推进，不允许上帝视角提前宣告真相。',
];

const _writingRules = <String>[
  '全章必须是可直接入库的中文正文，不要返回提纲、解释、创作说明、章节总结或作者旁白。',
  '每章严格使用单一限制视角，只写 POV 角色此刻可见、可闻、可感、可推断的内容。',
  '禁止说教性总结、价值判断式收束、替角色下定义的评论句、替读者解释主题。',
  '用动作、场景、对话、感官和失控后的代价表现人物，不要用抽象概括代替戏。',
  '角色发言必须符合其身份、处境、认知和语言习惯，不能突然全知，也不能说出不属于他的理论化台词。',
  '前后文必须连续承接，上一章留下的伤势、关系变化、线索、代价都要在后文持续生效。',
  '输出长度目标是 4500 到 5200 个中文字符，绝不能低于 4000。',
];

const _chapter01DraftFileName = 'chapter-01-source-draft.md';

final _characterSeeds = <CharacterSeed>[
  CharacterSeed(
    name: '张影',
    aliases: ['灰无常'],
    tier: character_domain.CharacterTier.protagonist,
    identity: '被误判为窃命罪魂的灰营耗材，后来自封灰无常',
    bio: '混沌的容器，心口有灰色漩涡。越痛越清醒，越饿越像野兽。唯一的人性锚点是外婆留下的银镯残念。信条是“饿，就要吃”。',
  ),
  CharacterSeed(
    name: '赵铁柱',
    aliases: ['屠夫'],
    tier: character_domain.CharacterTier.supporting,
    identity: '被污名化的屠夫，灰营耗材',
    bio: '沉默、能忍、护短。为保护村民杀了三十六名伪神信徒，却被阳间官府和地府卷宗一起定成凶犯。手里的生锈杀猪刀能亵渎伪神。',
  ),
  CharacterSeed(
    name: '陈账房',
    aliases: ['老算盘'],
    tier: character_domain.CharacterTier.supporting,
    identity: '灰营账房兼统计员',
    bio: '精于算计、怯于赴死，靠抹零法偷阴德给阳间孙子续命。以为自己还能把账做平，其实从头到尾都在给死人记账。',
  ),
  CharacterSeed(
    name: '小倩',
    aliases: [],
    tier: character_domain.CharacterTier.supporting,
    identity: '被献祭给黑水将军的溺死少女',
    bio: '年纪很小，常常哼唱带有古神语碎片的童谣。童谣不是安慰，而是残缺弑神咒与诅咒信标。',
  ),
  CharacterSeed(
    name: '噬心主簿',
    aliases: [],
    tier: character_domain.CharacterTier.majorAntagonist,
    identity: '窃据判官位、代理森罗殿的主簿',
    bio: '典型的绩效官僚。最在乎的是秩序稳定、责任不落在自己头上。他不是单纯嗜杀，而是把每一次甩锅都包装成制度正义。',
  ),
  CharacterSeed(
    name: '黑煞鬼将',
    aliases: [],
    tier: character_domain.CharacterTier.antagonist,
    identity: '地府前线将领',
    bio: '生前是名将，死后反抗地府失败，被驯成恶犬。看重效率和战果，把张影视作危险但好用的兵器。',
  ),
  CharacterSeed(
    name: '洛九川',
    aliases: ['前任白无常'],
    tier: character_domain.CharacterTier.antagonist,
    identity: '三百年前叛逃的白无常',
    bio: '理想没有死，勇气先死了。藏着半截哭丧棒和不完整的小轮回，帮助张影时夹着赎罪欲和强烈的实验心。',
  ),
  CharacterSeed(
    name: '黑水将军',
    aliases: [],
    tier: character_domain.CharacterTier.majorAntagonist,
    identity: '伪河神',
    bio: '曾经治水，后为续命堕成靠童男童女献祭维持神力的怪物。以“顾全大局”自我催眠。',
  ),
  CharacterSeed(
    name: '沉睡阎罗',
    aliases: ['伪阎罗'],
    tier: character_domain.CharacterTier.majorAntagonist,
    identity: '窃据阎罗神位的域外神魔',
    bio: '把整个地府秩序当成租税机器。只关心秩序是否稳定、畏惧是否持续产出，不关心任何个体冤屈。',
  ),
];

final _relationshipSeeds = <RelationshipSeed>[
  RelationshipSeed(
    a: '张影',
    b: '赵铁柱',
    relationType: relationship_domain.RelationType.closeFriend,
    changeReason: '在灰营并肩求生，最终以吞噬献祭完成最残酷的托付。',
  ),
  RelationshipSeed(
    a: '张影',
    b: '陈账房',
    relationType: relationship_domain.RelationType.hostile,
    changeReason: '张影知道老算盘始终在算计，却也多次借他保命；关系因背叛彻底破裂。',
  ),
  RelationshipSeed(
    a: '张影',
    b: '小倩',
    relationType: relationship_domain.RelationType.family,
    changeReason: '小倩像张影在灰营里唯一还会本能护住的活物，她的童谣成为张影对黑水将军的因果锚。',
  ),
  RelationshipSeed(
    a: '张影',
    b: '噬心主簿',
    relationType: relationship_domain.RelationType.enemy,
    changeReason: '主簿坚持把错命写成窃命，层层加码，逼出张影对整套系统的反噬。',
  ),
  RelationshipSeed(
    a: '张影',
    b: '黑煞鬼将',
    relationType: relationship_domain.RelationType.rival,
    changeReason: '一个把对方当兵器，一个把对方当枷锁；最终在阵中完成血腥的放手。',
  ),
  RelationshipSeed(
    a: '张影',
    b: '洛九川',
    relationType: relationship_domain.RelationType.mentor,
    changeReason: '洛九川提供伪造符文与逃生思路，但他的帮助始终裹着观测和试验。',
  ),
  RelationshipSeed(
    a: '陈账房',
    b: '噬心主簿',
    relationType: relationship_domain.RelationType.hostile,
    changeReason: '主簿把老算盘当作可压榨的脏账工具，老算盘恨他，却不敢当面反抗。',
  ),
];

final _chapterSpecs = <ChapterSpec>[
  ChapterSpec(
    number: 1,
    title: '错寿之人',
    pov: '张影',
    focusCharacters: ['张影', '噬心主簿'],
    beat:
        '从车祸暴毙写起，张影魂体被强行拖入森罗殿。要让他亲眼看到生死簿副册上写着自己十六岁就该死，二十六岁的死反而成了错账。结尾落到“窃命”定性，主簿以制度口吻压死他的辩解。',
  ),
  ChapterSpec(
    number: 2,
    title: '业火不收',
    pov: '张影',
    focusCharacters: ['张影', '噬心主簿', '黑煞鬼将'],
    beat:
        '写审判和涤罪所业火酷刑。张影在极端痛苦里本能吞掉业火，让刑具失控宕机。黑煞鬼将带回阳间折损正式鬼差的消息，主簿为了甩锅和废物利用，把张影打成灰牌耗材，发去灰营。',
  ),
  ChapterSpec(
    number: 3,
    title: '灰营疯狗',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '陈账房', '小倩'],
    beat:
        '写灰营第一夜，建立灰营食物链和耗材氛围。让张影见到屠夫、老算盘、小倩，也见识牢头如何折辱灰牌。冲突升级到张影像鬼手一样瞬杀牢头，再用锁魂链把自己一条手臂死死缠住，给自己立下“疯狗”的名声。',
  ),
  ChapterSpec(
    number: 4,
    title: '黑吃黑',
    pov: '张影',
    focusCharacters: ['张影', '黑煞鬼将', '洛九川'],
    beat:
        '写张影第一次被押去阳间出任务。洛九川暗中强化尸傀，导致正式鬼差惨死，张影在生死边缘吞掉那名鬼差和残余阴差力量。重点写他第一次主动“黑吃黑”后的快感、恶心与饥饿。结尾让洛九川注意到他是因果乱码。',
  ),
  ChapterSpec(
    number: 5,
    title: '孽镜碎响',
    pov: '张影',
    focusCharacters: ['张影', '洛九川', '噬心主簿'],
    beat:
        '洛九川现身，借刀杀人地教授伪造符文，好让张影暂时在制度里藏身。回到提刑司后，回溯孽镜被拿来查验张影。孽镜因无法解析混沌当场碎裂，提刑官和主簿都被吓到，最后以封卷脱罪收束。',
  ),
  ChapterSpec(
    number: 6,
    title: '断香庙',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '小倩'],
    beat:
        '推进到伪神庙祝一线。写灰营小队被差遣去清理香火异常和失踪魂灵，庙内神光带着压迫感。小倩的童谣第一次明确对黑水将军的气息产生反应，屠夫也对庙里的供奉方式表现出非同寻常的厌恶。',
  ),
  ChapterSpec(
    number: 7,
    title: '凡火斩神',
    pov: '赵铁柱',
    focusCharacters: ['赵铁柱', '张影', '黑水将军'],
    beat:
        '全章严格限定在屠夫视角。写他被庙里供奉的童男童女遗物刺激，想起村民和女儿，最终在凡人怒火里拔出杀猪刀，一刀劈碎伪神神光。张影趁机吞下伪神赐福，屠夫亲眼看见那份力量如何把人往怪物方向推。',
  ),
  ChapterSpec(
    number: 8,
    title: '金黑之血',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '小倩', '陈账房'],
    beat:
        '写吞噬赐福后的代价。张影连续咳出金色黑血，精神被庙祝死前惨叫污染，饥饿更重。要让队内关系重新洗牌：屠夫更警惕也更认可他，小倩童谣更贴近他，老算盘则意识到他已是无法做平的坏账。结尾接到纠察司传唤。',
  ),
  ChapterSpec(
    number: 9,
    title: '阴德旧账',
    pov: '陈账房',
    focusCharacters: ['陈账房', '噬心主簿', '张影'],
    beat:
        '用老算盘视角写纠察司主事如何拿“孙子阴德账户”逼他做供状。要把他的抹零法、偷阴德的小聪明、对孙子的执念和对张影的惧怕都写出来。他不是忠于主簿，只是在制度缝隙里本能求活。',
  ),
  ChapterSpec(
    number: 10,
    title: '吃掉口供',
    pov: '张影',
    focusCharacters: ['张影', '陈账房', '噬心主簿'],
    beat:
        '写公堂对质。主簿把老算盘供状变成一件近乎具象的证据，试图把窃命案钉死。张影在极限压迫里发动混沌，先吃掉纸面口供，再追着老算盘脑海里的“概念记忆”去咬。重点写混沌吃概念时的诡异感。',
  ),
  ChapterSpec(
    number: 11,
    title: '无证之堂',
    pov: '张影',
    focusCharacters: ['张影', '陈账房', '噬心主簿'],
    beat:
        '承接公堂崩坏后的余震。所有人都看见证据消失，却没人能解释为什么。主簿拼命维持秩序，老算盘则发现自己脑中关于某段供状和某些概念被抠空。章末要落到“没有证据，就只能放人”的被迫现实。',
  ),
  ChapterSpec(
    number: 12,
    title: '赢下冥律',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '陈账房'],
    beat:
        '写张影离开公堂后表面上的胜利。他在灰营里第一次真正尝到赢过制度一回的感觉，但这份胜利不带喜悦，只有空。屠夫和小倩对他更近，老算盘则更怕。结尾埋下代价即将爆发的不安。',
  ),
  ChapterSpec(
    number: 13,
    title: '外婆失面',
    pov: '张影',
    focusCharacters: ['张影', '小倩'],
    beat:
        '代价爆发：张影发现自己再也想不起外婆的脸，只剩银镯和一句“回家吃饭”的幻听。他明明赢了，却像把魂里最柔软的一块弄丢。小倩用童谣陪着他，但不能安慰，只能让那份缺失更尖。',
  ),
  ChapterSpec(
    number: 14,
    title: '洗髓令',
    pov: '噬心主簿',
    focusCharacters: ['噬心主簿', '沉睡阎罗', '张影'],
    beat:
        '限定在主簿视角，写他如何把混沌异常包装成可合法抹除的“洗髓大阵”项目。要写他的官僚逻辑、绩效恐惧和自我合理化。不要把他写成疯子，而是写成一个越精明越走向灾难的人。',
  ),
  ChapterSpec(
    number: 15,
    title: '阵中耗材',
    pov: '小倩',
    focusCharacters: ['小倩', '张影', '赵铁柱'],
    beat:
        '用小倩的儿童感知写大阵开启。她不懂制度术语，只知道自己和屠夫像被什么东西一点点抽空。她的童谣里要自然浮出黑水将军的真名碎片，成为后续诅咒的线头。张影在阵内也被压住，无法立刻救人。',
  ),
  ChapterSpec(
    number: 16,
    title: '阵外账房',
    pov: '陈账房',
    focusCharacters: ['陈账房', '噬心主簿', '黑煞鬼将'],
    beat:
        '老算盘被放在阵外做记录和核销。写他一边自我催眠，一边明白自己正在看着熟人被合法做成电池。黑煞鬼将和主簿之间的冷硬对话，要让老算盘看见自己只是双方都能丢弃的算盘珠。',
  ),
  ChapterSpec(
    number: 17,
    title: '请吃我',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '小倩'],
    beat:
        '大阵将人逼到绝境。屠夫断腿、还在护着小倩，张影则被饥饿和剧痛撕扯。屠夫主动要求张影吃掉自己，把恨和活路一起吞下。重点写张影第一次真正不想吃，却偏偏只能靠吃活下去。',
  ),
  ChapterSpec(
    number: 18,
    title: '断腿幻痛',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '黑煞鬼将'],
    beat:
        '写张影在极度清醒里撕碎并吞噬屠夫。力量暴涨的同时，他永久背上屠夫断腿的幻痛，走一步都像在替另一个人跛行。黑煞鬼将意识到局势失控，开始做最后的选择。',
  ),
  ChapterSpec(
    number: 19,
    title: '阵眼火雨',
    pov: '黑煞鬼将',
    focusCharacters: ['黑煞鬼将', '张影', '噬心主簿'],
    beat:
        '限定鬼将视角，写他如何判断继续效忠只会被系统一并清算，于是自爆炸碎阵眼。他不是为善，只是把最危险的武器放去咬更该死的人。要有他的遗言和军人式决绝。',
  ),
  ChapterSpec(
    number: 20,
    title: '灰雾九成',
    pov: '张影',
    focusCharacters: ['张影', '小倩'],
    beat:
        '阵破后张影同化度飙到九成，魂体几乎化成灰雾。写他杀穿追兵时既像复仇者又像天灾，小倩留下的旋律和屠夫的幻痛一起拉着他别彻底散掉。结尾引出判官法相。',
  ),
  ChapterSpec(
    number: 21,
    title: '啃断法相',
    pov: '张影',
    focusCharacters: ['张影', '噬心主簿'],
    beat:
        '主簿祭出判官法相镇压，张影在狂暴中硬生生斩断并咬碎那一指法相。力量越界后代价是骨骼液化、形体崩溃。全章要保持濒死时的感官错位和疯笑，不准写成热血升级。',
  ),
  ChapterSpec(
    number: 22,
    title: '坠入归墟',
    pov: '张影',
    focusCharacters: ['张影'],
    beat:
        '写张影在骨架崩散和灰雾化之间坠进死地归墟。这里不是新地图介绍，而是一次失重、失名、失身的坠落。把外婆的残响和混沌饥饿都写成快要断掉的线，结尾停在彻底坠入之前。',
  ),
  ChapterSpec(
    number: 23,
    title: '墟海残骸',
    pov: '张影',
    focusCharacters: ['张影'],
    beat:
        '归墟篇从纯粹的死地与残骸开始。张影在墟海里看见魔神残骨、破碎规则和被吃剩的名字。不要大篇科普，而是让他像溺水者一样一点点摸出归墟的可怕秩序。',
  ),
  ChapterSpec(
    number: 24,
    title: '链生肉死',
    pov: '张影',
    focusCharacters: ['张影', '赵铁柱', '小倩'],
    beat:
        '张影吞噬魔神残骸，肉身与锁链开始诡异融合。屠夫的断腿幻痛、小倩童谣、外婆的银镯残响要同时参与这场蜕变，让新形态不是白捡，而是三种代价压出来的东西。',
  ),
  ChapterSpec(
    number: 25,
    title: '灰无常',
    pov: '洛九川',
    focusCharacters: ['洛九川', '张影'],
    beat:
        '限定洛九川视角，看见张影自归墟走出，真正成了灰无常。洛九川要意识到自己押中的不是工具，而是会反咬整个制度的存在。他既想借力，也开始怕自己根本收不住。',
  ),
  ChapterSpec(
    number: 26,
    title: '返殿',
    pov: '张影',
    focusCharacters: ['张影', '黑煞鬼将', '噬心主簿'],
    beat:
        '张影杀回森罗殿外围。重点写系统兵器、鬼差规制和旧刑具在灰无常面前一层层失效。黑煞鬼将虽然已经死去，但他的军人习惯和遗言还在张影行动里留下痕迹。',
  ),
  ChapterSpec(
    number: 27,
    title: '咬碎副册',
    pov: '噬心主簿',
    focusCharacters: ['噬心主簿', '张影'],
    beat:
        '用主簿视角写防线彻底崩塌。他还在试图用条文、封条和法理给自己壮胆，最后亲眼看着张影掐住自己并盯上生死簿副册。恐惧必须是官僚的，不是豪言壮语式的。',
  ),
  ChapterSpec(
    number: 28,
    title: '主簿成凡',
    pov: '张影',
    focusCharacters: ['张影', '噬心主簿'],
    beat:
        '张影一口咬碎生死簿副册，基层死亡法则瘫痪，刑具全成废铁。主簿被从制度神力里剥出来，真正沦成一个会怕痛、会发抖、没有遮羞布的凡人。要写制度失效后的裸露感。',
  ),
  ChapterSpec(
    number: 29,
    title: '吃自己人',
    pov: '张影',
    focusCharacters: ['张影', '陈账房', '噬心主簿'],
    beat:
        '卷内最高点。主簿在极度恐惧里当众嘲讽老算盘，说出其孙子早被炼丹的真相。老算盘精神崩塌。张影下令让残存鬼差活活撕碎并分食老算盘，借这场公开吃人仪式立下“吃了自己人的，才是无常”的军令。',
  ),
  ChapterSpec(
    number: 30,
    title: '遥指黑水',
    pov: '张影',
    focusCharacters: ['张影', '小倩', '黑水将军'],
    beat:
        '写卷终后的短暂静止。张影踩着主簿，摸到银镯残念，体内同时有屠夫的痛、小倩的咒和自己的饥饿。他用滴血的杀猪刀遥指阳间黑水将军神庙，确立下一卷“跨越阴阳屠神”的战争方向。',
  ),
];

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  _loadSqlite3WithFts5();

  final options = ScriptOptions.parse(args);
  final generator = WuchangVolumeImporter(options);

  try {
    await generator.run();
  } on Exception catch (error, stackTrace) {
    stderr
      ..writeln('导入失败: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}

void _loadSqlite3WithFts5() {
  if (!Platform.isWindows) {
    return;
  }

  final dllPath = p.join(
    Directory.current.path,
    'build',
    'windows',
    'x64',
    'runner',
    'Debug',
    'sqlite3.dll',
  );
  if (File(dllPath).existsSync()) {
    open.overrideFor(
      OperatingSystem.windows,
      () => DynamicLibrary.open(dllPath),
    );
  }
}

class ScriptOptions {
  ScriptOptions({
    required this.dbPath,
    required this.sourceRoot,
    required this.outputRoot,
    required this.endpoint,
    required this.model,
    required this.apiKey,
    required this.startChapter,
    required this.endChapter,
    required this.forceRegenerate,
    required this.skipGeneration,
    required this.useAssistant,
  });

  final String dbPath;
  final String sourceRoot;
  final String outputRoot;
  final String endpoint;
  final String model;
  final String apiKey;
  final int startChapter;
  final int endChapter;
  final bool forceRegenerate;
  final bool skipGeneration;
  final bool useAssistant;

  factory ScriptOptions.parse(List<String> args) {
    var dbPath = AppEnv.get('WUCHANG_DB_PATH') ?? _defaultDbPath;
    var sourceRoot = AppEnv.get('WUCHANG_SOURCE_ROOT') ?? _defaultSourceRoot;
    var outputRoot =
        AppEnv.get('WUCHANG_OUTPUT_ROOT') ??
        p.join(Directory.current.path, 'tool', 'wuchang_volume1', 'generated');
    var endpoint = AppEnv.localEndpoint;
    var model = AppEnv.localModelName;
    var apiKey = AppEnv.localApiKey;
    var startChapter = AppEnv.wuchangStartChapter;
    var endChapter = AppEnv.wuchangEndChapter;
    var forceRegenerate = false;
    var skipGeneration = false;
    var useAssistant = true;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--db-path':
          dbPath = args[++i];
        case '--source-root':
          sourceRoot = args[++i];
        case '--output-root':
          outputRoot = args[++i];
        case '--endpoint':
          endpoint = args[++i];
        case '--model':
          model = args[++i];
        case '--api-key':
          apiKey = args[++i];
        case '--start':
          startChapter = int.parse(args[++i]);
        case '--end':
          endChapter = int.parse(args[++i]);
        case '--force':
          forceRegenerate = true;
        case '--skip-generation':
          skipGeneration = true;
        case '--direct':
          useAssistant = false;
      }
    }

    if (startChapter < 1 || endChapter > 30 || startChapter > endChapter) {
      throw ArgumentError('章节范围非法: $startChapter-$endChapter');
    }

    return ScriptOptions(
      dbPath: dbPath,
      sourceRoot: sourceRoot,
      outputRoot: outputRoot,
      endpoint: endpoint,
      model: model,
      apiKey: apiKey,
      startChapter: startChapter,
      endChapter: endChapter,
      forceRegenerate: forceRegenerate,
      skipGeneration: skipGeneration,
      useAssistant: useAssistant,
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
      id: 'wuchang_${tier.name}_${modelConfig.modelName}',
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

class WuchangVolumeImporter {
  WuchangVolumeImporter(this.options)
    : _client = LocalOpenAIClient(
        endpoint: options.endpoint,
        model: options.model,
        apiKey: options.apiKey,
      );

  final ScriptOptions options;
  final LocalOpenAIClient _client;

  late final Directory _outputDir = Directory(options.outputRoot);
  late final Directory _referenceDir = Directory(
    p.join(_outputDir.path, 'reference'),
  );
  late final Directory _chaptersDir = Directory(
    p.join(_outputDir.path, 'chapters'),
  );
  late final Directory _summariesDir = Directory(
    p.join(_outputDir.path, 'summaries'),
  );
  late final File _manifestFile = File(
    p.join(_outputDir.path, 'manifest.json'),
  );
  late final File _worldFile = File(p.join(_referenceDir.path, 'world.md'));
  late final File _planFile = File(
    p.join(_referenceDir.path, 'volume-plan.md'),
  );
  late final File _characterFile = File(
    p.join(_referenceDir.path, 'character-bible.md'),
  );
  late final File _chapter01DraftFile = File(
    p.join(_referenceDir.path, _chapter01DraftFileName),
  );

  final Map<int, String> _chapterSummaries = <int, String>{};

  Future<void> run() async {
    if (options.useAssistant) {
      await _runViaAssistant();
      return;
    }

    await _runDirect();
  }

  Future<void> _runDirect() async {
    await _prepareDirectories();
    await _copyReferenceFiles();
    await _client.assertReady();

    final database = AppDatabase.connect(
      DatabaseConnection(NativeDatabase(File(options.dbPath))),
    );
    try {
      final workRepo = WorkRepository(database);
      final volumeRepo = VolumeRepository(database);
      final chapterRepo = ChapterRepository(database);
      final characterRepo = CharacterRepository(database);
      final relationshipRepo = RelationshipRepository(database);
      final inspirationRepo = InspirationRepository(database);

      final work = await _ensureWork(workRepo);
      final volume = await _ensureVolume(volumeRepo, work.id);
      final characters = await _ensureCharacters(characterRepo, work.id);

      await _upsertInspiration(
        repo: inspirationRepo,
        workId: work.id,
        title: '世界观总纲：伪神纪元与混沌失效',
        category: 'worldbuilding',
        source: 'wuchang-volume1-import',
        content: await _buildWorldSummary(),
        tags: const ['黑神话无常', '世界观', '第一卷'],
      );
      await _upsertInspiration(
        repo: inspirationRepo,
        workId: work.id,
        title: '第一卷总纲：灰烬新生',
        category: 'scene_fragment',
        source: 'wuchang-volume1-import',
        content: await _planFile.readAsString(),
        tags: const ['黑神话无常', '第一卷', '总纲'],
      );
      await _upsertInspiration(
        repo: inspirationRepo,
        workId: work.id,
        title: '卷一视角铁律',
        category: 'character_sketch',
        source: 'wuchang-volume1-import',
        content: _writingRules.join('\n'),
        tags: const ['黑神话无常', '视角', '写作约束'],
      );

      await _ensureRelationships(relationshipRepo, work.id, characters);

      final importedChapters = <Map<String, Object>>[];
      for (final spec in _chapterSpecs) {
        if (spec.number < options.startChapter ||
            spec.number > options.endChapter) {
          continue;
        }

        stdout.writeln('==> 处理 ${spec.titleLine}');
        final content = await _ensureChapterMarkdown(spec);
        if (content.trim().length < _minChapterLength) {
          throw StateError('${spec.titleLine} 正文仍不足 $_minChapterLength 字');
        }

        final chapter = await chapterRepo.createOrGetChapterByTitle(
          workId: work.id,
          volumeId: volume.id,
          title: spec.titleLine,
          sortOrder: spec.number,
        );
        await chapterRepo.updateContent(
          chapter.id,
          content.trim(),
          content.trim().length,
        );

        final summary = await _ensureChapterSummary(spec, content);
        _chapterSummaries[spec.number] = summary;

        importedChapters.add({
          'number': spec.number,
          'title': spec.titleLine,
          'length': content.trim().length,
          'chapter_id': chapter.id,
          'summary': summary,
        });
      }

      await _writeManifest(importedChapters);
      await _verifyResult(
        chapterRepo: chapterRepo,
        characterRepo: characterRepo,
        relationshipRepo: relationshipRepo,
        inspirationRepo: inspirationRepo,
        workId: work.id,
      );
    } finally {
      await database.close();
    }
  }

  Future<void> _runViaAssistant() async {
    await _prepareDirectories();
    await _copyReferenceFiles();

    Get.reset();
    final database = AppDatabase.connect(
      DatabaseConnection(NativeDatabase(File(options.dbPath))),
    );

    try {
      final providerConfig = ProviderConfig(
        id: 'wuchang_provider',
        type: core_model.AIProviderType.openai,
        name: 'Local LM Studio',
        apiKey: options.apiKey,
        apiEndpoint: options.endpoint,
        timeoutSeconds: 1800,
        maxRetries: 1,
      );
      final modelConfig = core_model.ModelConfig(
        id: 'wuchang_model',
        tier: ModelTier.thinking,
        displayName: options.model,
        providerType: 'openai',
        modelName: options.model,
        temperature: 0.4,
        maxOutputTokens: 12000,
      );

      Get.put<AppDatabase>(database);
      Get.put<AIConfigRepository>(
        ProbeAIConfigRepository(
          modelConfig: modelConfig,
          providerConfig: providerConfig,
        ),
      );


      final aiService = AIService();

      final contextManager = ContextManager(aiService: aiService);
      final toolRegistry = ToolRegistry()..clear();

      final workRepo = WorkRepository(database);
      final volumeRepo = VolumeRepository(database);
      final chapterRepo = ChapterRepository(database);
      final characterRepo = CharacterRepository(database);
      final relationshipRepo = RelationshipRepository(database);
      final inspirationRepo = InspirationRepository(database);
      final chatRepo = ChatRepository(database);

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

          createFn: (workId, volumeId, title, {sortOrder = 0, content}) async {
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
              relationType: relationship_domain.RelationType.values.firstWhere(
                (item) => item.name.toLowerCase() == relationType.toLowerCase(),
                orElse: () => relationship_domain.RelationType.neutral,
              ),
            );
            return (id: relation.id, relationType: relation.relationType.name);
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

      final conversation = await chatService.createConversation(
        title: '黑神话：无常第一卷写入',
        source: 'wuchang-assistant-import',
      );

      await _runAssistantTurn(
        chatService: chatService,
        conversationId: conversation.id,
        workId: '',
        message: await _buildAssistantSetupPrompt(),
      );

      final works = await workRepo.getAllWorks(includeArchived: true);
      final work = works.firstWhere(
        (item) => item.name == _workName,
        orElse: () => throw StateError('内置助手未创建目标作品：$_workName'),
      );

      for (final spec in _chapterSpecs) {
        if (spec.number < options.startChapter ||
            spec.number > options.endChapter) {
          continue;
        }
        await _runAssistantTurn(
          chatService: chatService,
          conversationId: conversation.id,
          workId: work.id,
          message: _buildAssistantChapterPrompt(spec),
        );
      }

      final chapters = await chapterRepo.getChaptersByWorkId(work.id);
      final imported = chapters
          .where(
            (chapter) =>
                _chapterSpecs.any((spec) => spec.titleLine == chapter.title),
          )
          .map(
            (chapter) => {
              'title': chapter.title,
              'length': (chapter.content ?? '').trim().length,
              'chapter_id': chapter.id,
            },
          )
          .toList();
      await _writeManifest(imported);
      await _verifyResult(
        chapterRepo: chapterRepo,
        characterRepo: characterRepo,
        relationshipRepo: relationshipRepo,
        inspirationRepo: inspirationRepo,
        workId: work.id,
      );
    } finally {
      ToolRegistry().clear();
      await database.close();
      Get.reset();
    }
  }

  Future<void> _runAssistantTurn({
    required ChatService chatService,
    required String conversationId,
    required String workId,
    required String message,
  }) async {
    stdout.writeln('\n===== ASSISTANT TURN =====');
    stdout.writeln(_clip(message, 240));
    final stream = chatService.sendMessageStreamWithTools(
      conversationId: conversationId,
      userMessage: message,
      workId: workId,
    );

    String? lastError;
    await for (final event in stream) {
      switch (event) {
        case ChatThinking(:final thought):
          stdout.writeln('[thinking] ${_clip(thought, 180)}');
        case ChatToolStatus(:final toolName, :final statusMessage):
          stdout.writeln('[tool] $toolName :: $statusMessage');
        case ChatToolResult(:final toolName, :final summary, :final success):
          stdout.writeln(
            '[tool-result] $toolName :: ${success ? "OK" : "FAIL"} :: ${_clip(summary, 220)}',
          );
        case ChatChunk():
          break;
        case ChatComplete(:final fullContent):
          stdout.writeln('[complete] ${_clip(fullContent, 320)}');
        case ChatError(:final error):
          lastError = error;
          stdout.writeln('[error] $error');
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

    if (lastError != null) {
      throw StateError('内置助手回合失败: $lastError');
    }
  }

  Future<String> _buildAssistantSetupPrompt() async {
    final worldSummary = await _buildWorldSummary();
    final characterRequirements = _characterSeeds
        .map(
          (seed) =>
              '- ${seed.name} | tier=${seed.tier.name} | 身份=${seed.identity} | 设定=${seed.bio}',
        )
        .join('\n');
    final relationshipRequirements = _relationshipSeeds
        .map(
          (seed) =>
              '- ${seed.a} <-> ${seed.b} | relation=${seed.relationType.name} | 说明=${seed.changeReason}',
        )
        .join('\n');

    return '''
请直接调用工具，把《黑神话：无常》第一卷的基础资料写入项目，不要只给建议。

必须在这一回合完成：
1. 创建或复用作品：$_workName
2. 创建或复用分卷：$_volumeName
3. 把下面的世界观资料保存为至少 1 条 `worldbuilding` 素材
4. 把卷纲保存为至少 1 条 `scene_fragment` 素材
5. 把视角/写作铁律保存为至少 1 条 `character_sketch` 素材
6. 创建下面列出的全部核心角色
7. 创建下面列出的全部核心关系

写入规则：
- 如果作品、分卷、角色或关系已存在，就复用，不要重复造同名脏数据。
- 所有内容只能基于我给出的设定，不能擅自改世界观底层逻辑。
- 回复保持简短，只需要说明已写入了哪些对象。

【世界观与卷纲资料】
$worldSummary

【角色创建要求】
$characterRequirements

【关系创建要求】
$relationshipRequirements
''';
  }

  String _buildAssistantChapterPrompt(ChapterSpec spec) {
    final focus = _characterSeeds
        .where((seed) => spec.focusCharacters.contains(seed.name))
        .map((seed) => '- ${seed.name}：${seed.identity}。${seed.bio}')
        .join('\n');

    return '''
请直接调用 `create_chapter`，把 ${spec.titleLine} 写入当前作品的 $_volumeName。

硬性要求：
1. 标题必须就是：${spec.titleLine}
2. 正文不少于 $_minChapterLength 个中文字符
3. 严格单一限制视角：${spec.pov}
4. 只能基于项目里已保存的世界观、卷纲、角色设定，以及之前已经写入的章节继续推进
5. 不允许上帝视角旁白、不允许说教性总结、不允许主题点题、不允许作者解释
6. 人物发言和行为必须服从设定，不能突然全知，不能越过当前 POV 的认知边界
7. 必须承接已写章节里的伤势、代价、线索、关系变化
8. 调用 `create_chapter` 时，`content` 必须一次性给出完整正文，不要先建空章

本章 POV 限制：
${_povGuidance(spec.pov)}

本章关键角色：
$focus

本章任务：
${spec.beat}
''';
  }

  String _clip(String text, int max) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= max) {
      return normalized;
    }
    return '${normalized.substring(0, max)}...';
  }

  Future<void> _prepareDirectories() async {
    await _referenceDir.create(recursive: true);
    await _chaptersDir.create(recursive: true);
    await _summariesDir.create(recursive: true);
  }

  Future<void> _copyReferenceFiles() async {
    await _copyIfExists(
      source: File(p.join(options.sourceRoot, '第一卷规划.md')),
      target: _planFile,
    );
    await _copyIfExists(
      source: File(p.join(options.sourceRoot, '第一卷角色设定.md')),
      target: _characterFile,
    );
    await _copyIfExists(
      source: File(
        p.join(options.sourceRoot, 'patreon', 'patreon-1', '1-zh.txt'),
      ),
      target: _chapter01DraftFile,
    );
    await _worldFile.writeAsString(await _buildWorldSummary());
  }

  Future<void> _copyIfExists({
    required File source,
    required File target,
  }) async {
    if (!await source.exists()) {
      return;
    }
    await target.writeAsString(await source.readAsString());
  }

  Future<String> _buildWorldSummary() async {
    final plan = await _safeRead(_planFile);
    final characterBible = await _safeRead(_characterFile);
    return [
      '# 第一卷世界观摘要',
      '',
      '## 世界法则',
      ..._worldRules.map((rule) => '- $rule'),
      '',
      '## 写作铁律',
      ..._writingRules.map((rule) => '- $rule'),
      '',
      '## 角色摘要',
      ..._characterSeeds.map(
        (seed) => '- ${seed.name}：${seed.identity}。${seed.bio}',
      ),
      '',
      if (plan.isNotEmpty) ...['## 卷纲原文', plan.trim(), ''],
      if (characterBible.isNotEmpty) ...['## 角色设定原文', characterBible.trim()],
    ].join('\n');
  }

  Future<String> _safeRead(File file) async {
    if (!await file.exists()) {
      return '';
    }
    return file.readAsString();
  }

  Future<dynamic> _ensureWork(WorkRepository repository) async {
    final works = await repository.getAllWorks(includeArchived: true);
    final existing = works.where((work) => work.name == _workName).toList();
    if (existing.isNotEmpty) {
      return existing.first;
    }
    return repository.createWork(
      CreateWorkParams(
        name: _workName,
        type: 'dark_fantasy',
        description: '伪神纪元下的地府黑暗奇诡长篇，第一卷为灰烬新生。',
        targetWords: 150000,
      ),
    );
  }

  Future<dynamic> _ensureVolume(
    VolumeRepository repository,
    String workId,
  ) async {
    final volumes = await repository.getVolumesByWorkId(workId);
    final existing = volumes
        .where((volume) => volume.name == _volumeName)
        .toList();
    if (existing.isNotEmpty) {
      return existing.first;
    }
    return repository.createVolume(
      workId: workId,
      name: _volumeName,
      sortOrder: 1,
    );
  }

  Future<Map<String, dynamic>> _ensureCharacters(
    CharacterRepository repository,
    String workId,
  ) async {
    final existing = await repository.getCharactersByWorkId(
      workId,
      includeArchived: true,
    );
    final byName = <String, dynamic>{
      for (final character in existing) character.name: character,
    };

    for (final seed in _characterSeeds) {
      if (byName.containsKey(seed.name)) {
        continue;
      }
      final created = await repository.createCharacter(
        character_domain.CreateCharacterParams(
          workId: workId,
          name: seed.name,
          aliases: seed.aliases,
          tier: seed.tier,
          identity: seed.identity,
          bio: seed.bio,
        ),
      );
      byName[seed.name] = created;
    }

    return byName;
  }

  Future<void> _ensureRelationships(
    RelationshipRepository repository,
    String workId,
    Map<String, dynamic> characters,
  ) async {
    for (final seed in _relationshipSeeds) {
      final characterA = characters[seed.a];
      final characterB = characters[seed.b];
      if (characterA == null || characterB == null) {
        throw StateError('关系角色缺失: ${seed.a} / ${seed.b}');
      }

      final existing = await repository.getRelationshipBetween(
        characterA.id as String,
        characterB.id as String,
      );
      if (existing != null) {
        continue;
      }

      await repository.createRelationship(
        workId: workId,
        characterAId: characterA.id as String,
        characterBId: characterB.id as String,
        relationType: seed.relationType,
        changeReason: seed.changeReason,
      );
    }
  }

  Future<void> _upsertInspiration({
    required InspirationRepository repo,
    required String workId,
    required String title,
    required String category,
    required String source,
    required String content,
    required List<String> tags,
  }) async {
    final existing = await repo.getByWorkId(workId);
    final matched = existing.where((item) => item.title == title).toList();
    if (matched.isEmpty) {
      await repo.create(
        title: title,
        content: content,
        workId: workId,
        category: category,
        tags: tags,
        source: source,
        priority: 2,
      );
      return;
    }

    await repo.update(
      matched.first.id,
      title: title,
      content: content,
      category: category,
      tags: tags,
      source: source,
      priority: 2,
    );
  }

  Future<String> _ensureChapterMarkdown(ChapterSpec spec) async {
    final file = File(p.join(_chaptersDir.path, spec.fileName));
    if (!options.forceRegenerate && await file.exists()) {
      final existing = await file.readAsString();
      if (existing.trim().length >= _minChapterLength) {
        return existing.trim();
      }
    }

    if (options.skipGeneration) {
      throw StateError(
        '${spec.titleLine} 没有可复用的 Markdown 文件，且当前启用了 --skip-generation。',
      );
    }

    stdout.writeln('    生成正文...');
    var body = await _generateChapter(spec);
    body = _normalizeChapterBody(spec, body);

    if (body.length < _minChapterLength) {
      body = await _expandChapter(spec, body);
      body = _normalizeChapterBody(spec, body);
    }

    if (body.length < _minChapterLength) {
      body = await _rewriteShortChapter(spec, body);
      body = _normalizeChapterBody(spec, body);
    }

    if (body.length < _minChapterLength) {
      throw StateError('${spec.titleLine} 生成失败，正文长度只有 ${body.length}');
    }

    await file.writeAsString(body.trim());
    return body.trim();
  }

  Future<String> _generateChapter(ChapterSpec spec) async {
    final recentSummaries = _recentSummaries(spec.number);
    final draft = spec.number == 1 ? await _safeRead(_chapter01DraftFile) : '';
    final worldSummary = await _safeRead(_worldFile);
    final characters = _characterSeeds
        .where((seed) => spec.focusCharacters.contains(seed.name))
        .map((seed) => '- ${seed.name}：${seed.identity}。${seed.bio}')
        .join('\n');

    final userPrompt = StringBuffer()
      ..writeln('作品：$_workName')
      ..writeln('分卷：$_volumeName')
      ..writeln('章节：${spec.titleLine}')
      ..writeln('本章 POV：${spec.pov}')
      ..writeln('POV 限制：${_povGuidance(spec.pov)}')
      ..writeln()
      ..writeln('【本章目标】')
      ..writeln(spec.beat)
      ..writeln()
      ..writeln('【本章必须出现的核心角色】')
      ..writeln(characters)
      ..writeln()
      ..writeln('【近期连续性摘要】')
      ..writeln(recentSummaries.isEmpty ? '这是卷内起始章节，没有前情摘要。' : recentSummaries)
      ..writeln()
      ..writeln('【世界观与写作规则】')
      ..writeln(worldSummary)
      ..writeln()
      ..writeln('【硬性要求】')
      ..writeln('1. 严格使用 ${spec.pov} 的限制视角。')
      ..writeln('2. 正文不少于 $_minChapterLength 个中文字符，建议 4500-5200。')
      ..writeln('3. 不要出现“这一刻他并不知道未来”“命运因此改变”这类越视角总结句。')
      ..writeln('4. 不要写本章总结、读者提示、主题提炼或上帝视角旁白。')
      ..writeln('5. 角色台词必须贴合身份，不准突然哲学化或全知化。')
      ..writeln('6. 结尾要自然留下下一章的动作钩子，但不能用作者腔卖关子。')
      ..writeln('7. 只输出正文，不要附加解释、标题、注释、markdown 列表或分隔线。');

    if (draft.isNotEmpty) {
      userPrompt
        ..writeln()
        ..writeln('【已有旧稿，仅供本章参考与重写扩写】')
        ..writeln('保留核心事件、氛围和人物关系，但不要逐句照抄，要重写成更完整、更稳、更长的版本。')
        ..writeln(draft.trim());
    }

    return _client.complete(
      systemPrompt: _systemPrompt(),
      userPrompt: userPrompt.toString(),
      temperature: 0.85,
      maxTokens: 12000,
    );
  }

  Future<String> _expandChapter(ChapterSpec spec, String current) async {
    stdout.writeln('    正文不足 $_minChapterLength 字，进行扩写...');
    var body = current.trim();
    var attempts = 0;
    while (body.length < _minChapterLength && attempts < 3) {
      attempts += 1;
      final deficit = _targetChapterLength - body.length;
      final expansion = await _client.complete(
        systemPrompt: _systemPrompt(),
        userPrompt:
            '''
下面是已经写好的 ${spec.titleLine} 正文，它还差至少 ${deficit > 0 ? deficit : 500} 个中文字符才能达标。

请在不重复已有句子的前提下，从末尾自然续写或在薄弱处补写细节，让这一章达到 4500 字以上。
要求：
1. 仍然保持 ${spec.pov} 的限制视角。
2. 不要回头重讲已经写过的事件，不要解释主题，不要总结。
3. 只输出新增正文，不要输出任何说明。

已写正文：
$body
''',
        temperature: 0.75,
        maxTokens: 8000,
      );
      body = '$body\n\n${_normalizeContinuation(expansion)}'.trim();
    }
    return body;
  }

  Future<String> _rewriteShortChapter(ChapterSpec spec, String current) {
    stdout.writeln('    进入整章重写补强...');
    return _client.complete(
      systemPrompt: _systemPrompt(),
      userPrompt:
          '''
请把下面这章重写成一版完整长章节，保留事件顺序、角色关系和情绪走向，但整体扩写到 4500-5200 个中文字符。

章节：${spec.titleLine}
POV：${spec.pov}
章节要求：${spec.beat}

重写要求：
1. 严格使用 ${spec.pov} 的限制视角。
2. 不得加入超出该角色认知的解释。
3. 不得加入作者总结、说教或主题点题。
4. 只输出正文。

现有版本：
$current
''',
      temperature: 0.8,
      maxTokens: 12000,
    );
  }

  Future<String> _ensureChapterSummary(ChapterSpec spec, String content) async {
    final file = File(
      p.join(
        _summariesDir.path,
        '${spec.number.toString().padLeft(2, '0')}-summary.txt',
      ),
    );

    if (!options.forceRegenerate && await file.exists()) {
      final existing = await file.readAsString();
      if (existing.trim().isNotEmpty) {
        return existing.trim();
      }
    }

    final summary = await _client.complete(
      systemPrompt: '你是长篇小说连续性整理助手。请把章节压缩成给作者自己看的连续性备忘，不做文学评论。',
      userPrompt:
          '''
请把下面这章总结成 120 到 180 个中文字符的连续性备忘，只保留：
1. 这一章发生的关键事件
2. 角色关系变化
3. 新增伤势、代价与线索
4. 下一章必须承接的动作钩子

不要写评价，不要写主题，不要用项目符号。

章节：${spec.titleLine}
正文：
$content
''',
      temperature: 0.2,
      maxTokens: 1200,
    );
    final normalized = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
    await file.writeAsString(normalized);
    return normalized;
  }

  Future<void> _writeManifest(
    List<Map<String, Object>> importedChapters,
  ) async {
    await _manifestFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'work_name': _workName,
        'volume_name': _volumeName,
        'db_path': options.dbPath,
        'model': options.model,
        'endpoint': options.endpoint,
        'generated_at': DateTime.now().toIso8601String(),
        'chapters': importedChapters,
      }),
    );
  }

  Future<void> _verifyResult({
    required ChapterRepository chapterRepo,
    required CharacterRepository characterRepo,
    required RelationshipRepository relationshipRepo,
    required InspirationRepository inspirationRepo,
    required String workId,
  }) async {
    final chapters = await chapterRepo.getChaptersByWorkId(workId);
    final volumeChapters = chapters.where((chapter) {
      final title = chapter.title;
      return _chapterSpecs.any((spec) => spec.titleLine == title);
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (volumeChapters.length < 30) {
      throw StateError('导入后仅找到 ${volumeChapters.length} 章目标章节');
    }

    final short = volumeChapters.where((chapter) {
      return (chapter.content ?? '').trim().length < _minChapterLength;
    }).toList();
    if (short.isNotEmpty) {
      throw StateError(
        '存在不足 $_minChapterLength 字的章节: ${short.map((item) => item.title).join('、')}',
      );
    }

    final characters = await characterRepo.getCharactersByWorkId(
      workId,
      includeArchived: true,
    );
    if (characters.length < _characterSeeds.length) {
      throw StateError('角色数量不足，当前仅有 ${characters.length} 名');
    }

    final relationships = await relationshipRepo.getRelationshipsByWorkId(
      workId,
    );
    if (relationships.length < _relationshipSeeds.length) {
      throw StateError('角色关系数量不足，当前仅有 ${relationships.length} 条');
    }

    final inspirations = await inspirationRepo.getByWorkId(workId);
    final requiredInspirationTitles = {
      '世界观总纲：伪神纪元与混沌失效',
      '第一卷总纲：灰烬新生',
      '卷一视角铁律',
    };
    final actualTitles = inspirations.map((item) => item.title).toSet();
    final missing = requiredInspirationTitles.difference(actualTitles);
    if (missing.isNotEmpty) {
      throw StateError('素材缺失: ${missing.join('、')}');
    }

    stdout.writeln('导入完成，校验通过。');
    stdout.writeln('作品：$_workName');
    stdout.writeln('分卷：$_volumeName');
    stdout.writeln('章节数：${volumeChapters.length}');
    stdout.writeln(
      '最短章节：${volumeChapters.map((item) => (item.content ?? '').trim().length).reduce((a, b) => a < b ? a : b)}',
    );
    stdout.writeln('角色数：${characters.length}');
    stdout.writeln('关系数：${relationships.length}');
    stdout.writeln('输出目录：${_outputDir.path}');
  }

  String _systemPrompt() {
    return '''
你是严苛的中文长篇小说代笔助手，正在为《黑神话：无常》第一卷写正式正文。

必须同时满足以下规则：
${_writingRules.map((rule) => '- $rule').join('\n')}

额外强约束：
- 只写戏，不写创作说明。
- 只准使用输入里指定的 POV。
- 每个角色的行动和发言都必须服从其设定、当下处境与已知信息。
- 任何力量提升都必须伴随具体代价，而且代价要落地。
- 如果你犹豫该不该解释，请删掉解释，改成场景、动作、对话或感官。
''';
  }

  String _recentSummaries(int currentNumber) {
    final summaries = <String>[];
    for (var index = currentNumber - 2; index < currentNumber; index++) {
      if (index < 1) {
        continue;
      }
      final summary = _chapterSummaries[index];
      if (summary != null && summary.isNotEmpty) {
        summaries.add('第$index章：$summary');
      }
    }
    return summaries.join('\n');
  }

  String _normalizeChapterBody(ChapterSpec spec, String raw) {
    var text = raw.trim().replaceAll('\r\n', '\n');
    text = text.replaceAll(RegExp(r'^```(?:markdown|md|text)?\s*'), '');
    text = text.replaceAll(RegExp(r'```$'), '');
    text = text.replaceAll(RegExp(r'^#\s*'), '');
    if (text.startsWith(spec.titleLine)) {
      text = text.substring(spec.titleLine.length).trimLeft();
    }
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text;
  }

  String _normalizeContinuation(String raw) {
    var text = raw.trim();
    text = text.replaceAll(RegExp(r'^```(?:markdown|md|text)?\s*'), '');
    text = text.replaceAll(RegExp(r'```$'), '');
    text = text.replaceAll(RegExp(r'^(续写|新增正文)[:：]\s*'), '');
    return text.trim();
  }

  String _povGuidance(String pov) {
    return switch (pov) {
      '张影' => '只能写他此刻看到的地府、听到的动静、身体痛感、饥饿、记忆缺口和主观推断，不能替别人下结论。',
      '赵铁柱' => '只能写屠夫看见的场面、想起的村庄与闺女、握刀时的身体记忆和对张影的观察，不能替张影解释混沌机理。',
      '陈账房' => '只能写老算盘自己看到的官场脸色、账目、威胁、恐惧与自我算计，不能替他人解释真正底牌。',
      '小倩' => '只能写她儿童化、碎片化、恐惧化的感知，不准突然成熟全知。',
      '噬心主簿' => '只能写他官僚式的观察、风险判断、自保逻辑和当下恐惧，不能替敌人总结宿命。',
      '黑煞鬼将' => '只能写军人式判断、战场观察和算计，不能替别人做心理剖析。',
      '洛九川' => '只能写他作为旁观者和试验者能直接看到、猜到、害怕的内容，不能越过观察所得宣布真相。',
      _ => '只能写该角色当下感知与推断到的内容。',
    };
  }
}

class LocalOpenAIClient {
  LocalOpenAIClient({
    required this.endpoint,
    required this.model,
    required this.apiKey,
  }) : _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 30),
           receiveTimeout: const Duration(minutes: 30),
           sendTimeout: const Duration(minutes: 30),
         ),
       );

  final String endpoint;
  final String model;
  final String apiKey;
  final Dio _dio;

  Future<void> assertReady() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$endpoint/models',
      options: Options(headers: _headers()),
    );
    final data = response.data?['data'] as List<dynamic>? ?? const [];
    final ids = data
        .whereType<Map<String, dynamic>>()
        .map((item) => item['id'])
        .whereType<String>()
        .toSet();
    if (!ids.contains(model)) {
      throw StateError('本地模型列表里没有 $model，当前只有: ${ids.join(', ')}');
    }
  }

  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
    required double temperature,
    required int maxTokens,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/chat/completions',
      data: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': false,
      },
      options: Options(headers: _headers()),
    );

    final data = response.data;
    if (data == null) {
      throw StateError('模型返回为空');
    }
    if (data.containsKey('error')) {
      throw StateError('模型报错: ${data['error']}');
    }

    final choices = data['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw StateError('模型没有返回 choices');
    }

    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    final content = message?['content'] as String? ?? '';
    if (content.trim().isNotEmpty) {
      return content.trim();
    }

    final reasoning = message?['reasoning_content'] as String? ?? '';
    if (reasoning.trim().isNotEmpty) {
      throw StateError('模型只返回了 reasoning_content，没有正文');
    }
    throw StateError('模型没有返回正文');
  }

  Map<String, String> _headers() {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }
}

class CharacterSeed {
  const CharacterSeed({
    required this.name,
    required this.aliases,
    required this.tier,
    required this.identity,
    required this.bio,
  });

  final String name;
  final List<String> aliases;
  final character_domain.CharacterTier tier;
  final String identity;
  final String bio;
}

class RelationshipSeed {
  const RelationshipSeed({
    required this.a,
    required this.b,
    required this.relationType,
    required this.changeReason,
  });

  final String a;
  final String b;
  final relationship_domain.RelationType relationType;
  final String changeReason;
}

class ChapterSpec {
  const ChapterSpec({
    required this.number,
    required this.title,
    required this.pov,
    required this.focusCharacters,
    required this.beat,
  });

  final int number;
  final String title;
  final String pov;
  final List<String> focusCharacters;
  final String beat;

  String get titleLine => '第$number章：$title';

  String get fileName => '${number.toString().padLeft(2, '0')}-$title.md';
}
