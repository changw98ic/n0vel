@Tags(['integration'])
library;

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/open.dart';

import 'package:writing_assistant/core/database/database.dart';
import 'package:writing_assistant/core/services/ai/models/model_config.dart';
import 'package:writing_assistant/core/services/ai/models/model_tier.dart';
import 'package:writing_assistant/core/services/ai/models/provider_config.dart';
import 'package:writing_assistant/core/services/ai/providers/openai_provider.dart';
import 'package:writing_assistant/features/ai_config/data/ai_config_repository.dart';
import 'package:writing_assistant/features/ai_config/domain/model_config.dart'
    as feature_config;
import 'package:writing_assistant/features/editor/data/chapter_repository.dart';
import 'package:writing_assistant/features/settings/data/character_repository.dart';
import 'package:writing_assistant/features/settings/data/faction_repository.dart';
import 'package:writing_assistant/features/settings/data/item_repository.dart';
import 'package:writing_assistant/features/settings/data/location_repository.dart';
import 'package:writing_assistant/features/settings/data/relationship_repository.dart';
import 'package:writing_assistant/features/settings/domain/character.dart'
    as character_domain;
import 'package:writing_assistant/features/settings/domain/relationship.dart'
    as relationship_domain;
import 'package:writing_assistant/features/work/data/volume_repository.dart';
import 'package:writing_assistant/features/work/data/work_repository.dart';

// ─── 配置 ───

final _apiKey = Platform.environment['TEST_AI_API_KEY'] ?? 'lm-studio';
final _endpoint =
    Platform.environment['TEST_AI_ENDPOINT'] ?? 'http://127.0.0.1:1234/v1';
final _modelName =
    Platform.environment['TEST_AI_MODEL'] ?? 'google/gemma-4-26b-a4b';
final _dbPath = Platform.environment['TEST_DB_PATH'] ??
    'C:/Users/changw98/Documents/writing_assistant.db';

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

late AppDatabase db;
late WorkRepository workRepo;
late VolumeRepository volumeRepo;
late ChapterRepository chapterRepo;
late CharacterRepository charRepo;
late RelationshipRepository relRepo;
late ItemRepository itemRepo;
late LocationRepository locRepo;
late FactionRepository factionRepo;
late OpenAIProvider provider;

final _providerConfig = ProviderConfig(
  id: 'test',
  type: AIProviderType.openai,
  name: 'LM Studio',
  apiKey: _apiKey,
  apiEndpoint: _endpoint,
  timeoutSeconds: 600,
);

final _modelConfig = ModelConfig(
  id: 'test',
  tier: ModelTier.fast,
  displayName: 'LM Studio',
  providerType: 'openai',
  modelName: _modelName,
  temperature: 0.8,
  maxOutputTokens: 4096,
);

/// 调用大模型生成文本
Future<String> _generate(String systemPrompt, String userPrompt) async {
  final response = await provider.complete(
    config: _providerConfig,
    model: _modelConfig,
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
    temperature: 0.8,
    maxTokens: 4096,
  );
  return response.content;
}

// ─── Mock ───

class MockAIConfigRepository extends Mock implements AIConfigRepository {}

// ═══════════════════════════════════════════════════════════════════

void main() {
  setUpAll(() {
    _loadSqlite3WithFts5();
    registerFallbackValue(feature_config.ModelTier.fast);
  });

  group('完整小说创作（AI 生成 + 真实 DB）', () {
    setUp(() async {
      Get.reset();

      db = AppDatabase.connect(
          DatabaseConnection(NativeDatabase(File(_dbPath))));
      Get.put<AppDatabase>(db);

      final mockConfigRepo = MockAIConfigRepository();
      when(() => mockConfigRepo.getCoreModelConfig(any()))
          .thenAnswer((_) async => _modelConfig);
      when(() => mockConfigRepo.getCoreProviderConfig(any()))
          .thenAnswer((_) async => _providerConfig);
      Get.put<AIConfigRepository>(mockConfigRepo);

      workRepo = WorkRepository(db);
      volumeRepo = VolumeRepository(db);
      chapterRepo = ChapterRepository(db);
      charRepo = CharacterRepository(db);
      relRepo = RelationshipRepository(db);
      itemRepo = ItemRepository(db);
      locRepo = LocationRepository(db);
      factionRepo = FactionRepository(db);
      provider = OpenAIProvider();
    });

    tearDown(() async {
      await db.close();
      Get.reset();
    });

    test('清空数据库 → AI 生成完整小说 → 写入 DB → 客户端可见', () async {
      // ─── 0. 清空数据库 ───
      print('🧹 清空数据库...');
      await db.customStatement('DROP TRIGGER IF EXISTS chapters_ai');
      await db.customStatement('DROP TRIGGER IF EXISTS chapters_ad');
      await db.customStatement('DROP TRIGGER IF EXISTS chapters_au');
      await db.customStatement('DROP TABLE IF EXISTS chapters_fts');
      await db.customStatement('PRAGMA foreign_keys = OFF');
      await db.delete(db.relationshipEvents).go();
      await db.delete(db.relationshipHeads).go();
      await db.delete(db.chapterCharacters).go();
      await db.delete(db.chapters).go();
      await db.delete(db.volumes).go();
      await db.delete(db.characterProfiles).go();
      await db.delete(db.characters).go();
      await db.delete(db.items).go();
      await db.delete(db.locationCharacters).go();
      await db.delete(db.locations).go();
      await db.delete(db.factionMembers).go();
      await db.delete(db.factions).go();
      await db.delete(db.events).go();
      await db.delete(db.eventCharacters).go();
      await db.delete(db.works).go();
      await db.customStatement('PRAGMA foreign_keys = ON');
      await db.createFTSIndexes();
      print('✅ 数据库已清空');

      // ─── 1. AI 生成作品名称和简介 ───
      print('📝 AI 生成作品设定...');
      final workInfo = await _generate(
        '你是一位玄幻小说策划。只输出两行文本，不要任何额外文字。'
        '第一行是作品名称（4-8个字），第二行是简介（100-200字）。',
        '为一部东方玄幻小说生成名称和简介。'
        '背景：灵气复苏的修仙世界，主角从底层崛起。',
      );
      final lines = workInfo.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
      final workName = lines.first.trim();
      final workDesc = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '一部东方玄幻小说';
      print('  作品名: $workName');
      print('  简介: ${workDesc.substring(0, workDesc.length.clamp(0, 60))}...');

      final work = await workRepo.createWork(CreateWorkParams(
        name: workName,
        type: '玄幻',
        description: workDesc,
        targetWords: 500000,
      ));
      final workId = work.id;
      print('✅ 作品「${work.name}」已创建');

      // ─── 2. 创建第一卷 ───
      final volume = await volumeRepo.createVolume(
        workId: workId,
        name: '第一卷 初入江湖',
      );
      final volId = volume.id;
      print('✅ 第一卷已创建');

      // ─── 3. AI 生成第一章标题 + 3000字内容 ───
      print('📖 AI 生成第一章...');
      final chapterText = await _generate(
        '你是一位专业的玄幻小说作家。'
        '请写小说第一章，3000字以上。'
        '第一行是章节标题（不要「第x章」前缀），之后空一行，然后是正文内容。'
        '要求：场景描写+人物对话+内心独白，开头有悬念，自然融入世界观。'
        '不要输出任何提示语或说明，只输出标题和正文。',
        '作品：$workName\n简介：$workDesc\n'
        '请开始写第一章。主角是一个出身低微但天赋异禀的少年。',
      );
      final chapterLines = chapterText.trim().split('\n');
      final chapterTitle = chapterLines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
      final chapterContent = chapterLines.skip(1).join('\n').trim();
      final wordCount = chapterContent.replaceAll(RegExp(r'\s'), '').length;

      final chapter = await chapterRepo.createChapter(
        workId: workId,
        volumeId: volId,
        title: chapterTitle.isNotEmpty ? chapterTitle : '初入修仙界',
      );
      await chapterRepo.updateContent(chapter.id, chapterContent, wordCount);
      print('✅ 第一章「${chapter.title}」已写入 ($wordCount 字)');

      // ─── 4. 创建 3 个角色 ───
      print('👥 创建角色...');
      final charNames = ['叶辰', '苏瑶', '萧天策'];
      final charBios = [
        'protagonist|男|出身低微却身怀神秘血脉的少年，性格坚韧不屈，暗中修炼上古功法',
        'supporting|女|天机宗宗主之女，冰雪聪明，擅长阵法，与叶辰有命定之缘',
        'antagonist|男|世家嫡子，天赋过人却心高气傲，视叶辰为眼中钉，誓要将其踩在脚下',
      ];
      final charIds = <String>[];
      for (var i = 0; i < 3; i++) {
        final parts = charBios[i].split('|');
        final character = await charRepo.createCharacter(
          character_domain.CreateCharacterParams(
            workId: workId,
            name: charNames[i],
            tier: character_domain.CharacterTier.values.firstWhere(
              (t) => t.name == parts[0],
              orElse: () => character_domain.CharacterTier.supporting,
            ),
            gender: parts[1],
            bio: parts[2],
          ),
        );
        charIds.add(character.id);
        print('  ✅ ${character.name} (${character.tier.name})');
      }

      // ─── 5. 创建角色关系 ───
      print('🔗 创建角色关系...');
      final relationships = [
        (0, 1, relationship_domain.RelationType.friendly, '初次相遇，互相欣赏'),
        (0, 2, relationship_domain.RelationType.rival, '同时入门，互不相让'),
        (1, 2, relationship_domain.RelationType.neutral, '立场不同但彼此尊重'),
      ];
      for (final (aIdx, bIdx, relType, reason) in relationships) {
        await relRepo.createRelationship(
          workId: workId,
          characterAId: charIds[aIdx],
          characterBId: charIds[bIdx],
          relationType: relType,
          changeReason: reason,
        );
        print('  ✅ ${charNames[aIdx]} ↔ ${charNames[bIdx]} (${relType.label})');
      }

      // ─── 6. 创建地点 ───
      print('🏔️ 创建地点...');
      final locations = [
        ('天机城', '古城', '天机宗所在的千年古城，灵气浓郁，修士云集'),
        ('落星谷', '秘境', '传说中陨星坠落之地，蕴含天地灵韵，是叶辰发现血脉秘密之处'),
        ('云霄峰', '山脉', '天机宗最高峰，终年云雾缭绕，宗门禁地所在'),
      ];
      for (final (name, type, desc) in locations) {
        await locRepo.createLocation(
          workId: workId,
          name: name,
          type: type,
          description: desc,
        );
        print('  ✅ $name ($type)');
      }

      // ─── 7. 创建势力 + 物品 ───
      print('⚔️ 创建势力...');
      await factionRepo.createFaction(
        workId: workId,
        name: '天机宗',
        type: '宗门',
        description: '修仙界四大宗门之首，以阵法和天机术闻名，门下弟子数千',
        leaderId: null,
      );
      await factionRepo.createFaction(
        workId: workId,
        name: '萧家',
        type: '世家',
        description: '天机城中势力最大的修仙世家，与天机宗有千丝万缕的关系',
        leaderId: charIds[2],
      );
      print('  ✅ 天机宗、萧家');

      print('💎 创建物品...');
      final items = [
        ('星陨剑', '武器', '传说', '陨星谷中出土的上古神兵，与叶辰血脉共鸣'),
        ('聚灵丹', '丹药', '稀有', '天机宗秘制丹药，可大幅提升修为'),
        ('天机令', '法宝', '传说', '天机宗宗主信物，号令全宗的无上法器'),
      ];
      for (final (name, type, rarity, desc) in items) {
        await itemRepo.createItem(
          workId: workId,
          name: name,
          type: type,
          rarity: rarity,
          description: desc,
        );
        print('  ✅ $name ($type/$rarity)');
      }

      // ─── 8. 验证数据库 ───
      print('\n🔍 验证数据库...');

      final works = await workRepo.getAllWorks();
      expect(works.any((w) => w.id == workId), isTrue);
      final savedWork = works.firstWhere((w) => w.id == workId);
      expect(savedWork.name, isNotEmpty);
      expect(savedWork.description, isNotEmpty);
      print('  ✅ 作品: ${savedWork.name} (有描述: ${savedWork.description!.length}字)');

      final volumes = await volumeRepo.getVolumesByWorkId(workId);
      expect(volumes, isNotEmpty);
      print('  ✅ 卷: ${volumes.length}卷');

      final chapters = await chapterRepo.getChaptersByWorkId(workId);
      expect(chapters, isNotEmpty);
      final ch0 = chapters.first;
      expect(ch0.content, isNotNull);
      expect(ch0.content!.length, greaterThanOrEqualTo(1000));
      print('  ✅ 章节: ${ch0.title} (${ch0.content!.length}字)');

      final chars = await charRepo.getCharactersByWorkId(workId);
      expect(chars.length, greaterThanOrEqualTo(3));
      print('  ✅ 角色: ${chars.map((c) => '${c.name}(${c.tier.label})').join('、')}');

      final locs = await locRepo.getLocationsByWorkId(workId);
      expect(locs, isNotEmpty);
      print('  ✅ 地点: ${locs.map((l) => l.name).join('、')}');

      final facs = await factionRepo.getFactionsByWorkId(workId);
      expect(facs, isNotEmpty);
      print('  ✅ 势力: ${facs.map((f) => f.name).join('、')}');

      final itms = await itemRepo.getItemsByWorkId(workId);
      expect(itms, isNotEmpty);
      print('  ✅ 物品: ${itms.map((i) => i.name).join('、')}');

      print('\n🎉 完整小说创作测试通过！刷新客户端即可查看。');
    }, timeout: const Timeout(Duration(seconds: 600)));
  });
}
