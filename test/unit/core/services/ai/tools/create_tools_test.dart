import 'package:flutter_test/flutter_test.dart';
import 'package:writing_assistant/core/services/ai/tools/create_chapter_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_character_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_faction_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_inspiration_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_item_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_location_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_relationship_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_volume_tool.dart';
import 'package:writing_assistant/core/services/ai/tools/create_work_tool.dart';

// Typed function aliases matching tool constructor signatures
typedef WorkCreateFn = Future<({String id, String name})> Function(
  String name, {
  String? type,
  String? description,
  int? targetWords,
});
typedef VolumeCreateFn = Future<({String id, String name})> Function(
  String workId,
  String name, {
  int sortOrder,
});
typedef ChapterCreateFn = Future<({String id, String title})> Function(
  String workId,
  String volumeId,
  String title, {
  int sortOrder,
  String? content,
});
typedef CharacterCreateFn = Future<({String id, String name, String tier})>
    Function(
  String workId,
  String name,
  String tier, {
  List<String>? aliases,
  String? gender,
  String? age,
  String? identity,
  String? bio,
});
typedef RelationshipCreateFn = Future<({String id, String relationType})>
    Function(
  String workId,
  String characterAId,
  String characterBId,
  String relationType,
);
typedef ItemCreateFn = Future<({String id, String name})> Function({
  required String workId,
  required String name,
  String? type,
  String? rarity,
  String? description,
  List<String>? abilities,
  String? holderId,
});
typedef LocationCreateFn = Future<({String id, String name})> Function({
  required String workId,
  required String name,
  String? type,
  String? parentId,
  String? description,
  List<String>? importantPlaces,
});
typedef FactionCreateFn = Future<({String id, String name})> Function({
  required String workId,
  required String name,
  String? type,
  String? description,
  List<String>? traits,
  String? leaderId,
});
typedef InspirationCreateFn = Future<({String id, String title})> Function({
  required String title,
  required String content,
  String? workId,
  required String category,
  List<String>? tags,
  String? source,
});

void main() {
  // ── CreateWorkTool ──
  group('CreateWorkTool', () {
    test('schema has correct name and required fields', () {
      final tool = CreateWorkTool(
        createFn: (String name, {String? type, String? description, int? targetWords}) async =>
            (id: '', name: name),
      );
      expect(tool.name, 'create_work');
      expect((tool.inputSchema['required'] as List), ['name']);
    });

    test('execute succeeds with valid input', () async {
      final tool = CreateWorkTool(
        createFn: (String name, {String? type, String? description, int? targetWords}) async =>
            (id: 'w1', name: name),
      );
      final result = await tool.execute({'name': '我的小说', 'type': '玄幻'});
      expect(result.success, isTrue);
      expect(result.output, contains('我的小说'));
      expect(result.data?['id'], 'w1');
    });

    test('execute fails without name', () async {
      final tool = CreateWorkTool(
        createFn: (String name, {String? type, String? description, int? targetWords}) async =>
            (id: 'w1', name: name),
      );
      final result = await tool.execute({});
      expect(result.success, isFalse);
      expect(result.error, contains('name'));
    });
  });

  // ── CreateVolumeTool ──
  group('CreateVolumeTool', () {
    test('execute succeeds with valid input', () async {
      final tool = CreateVolumeTool(
        createFn: (String workId, String name, {int sortOrder = 0}) async =>
            (id: 'v1', name: name),
      );
      final result =
          await tool.execute({'work_id': 'w1', 'name': '第一卷'});
      expect(result.success, isTrue);
      expect(result.output, contains('第一卷'));
    });

    test('execute fails without work_id', () async {
      final tool = CreateVolumeTool(
        createFn: (String workId, String name, {int sortOrder = 0}) async =>
            (id: 'v1', name: name),
      );
      final result = await tool.execute({'name': '第一卷'});
      expect(result.success, isFalse);
    });
  });

  // ── CreateChapterTool ──
  group('CreateChapterTool', () {
    test('execute succeeds with valid input', () async {
      final tool = CreateChapterTool(
        createFn: (String workId, String volumeId, String title, {int sortOrder = 0, String? content}) async =>
            (id: 'c1', title: title),
      );
      final result = await tool.execute({
        'work_id': 'w1',
        'volume_id': 'v1',
        'title': '第一章 初入江湖',
        'content': '江湖故事开始',
      });
      expect(result.success, isTrue);
      expect(result.output, contains('第一章'));
    });

    test('execute fails without volume_id', () async {
      final tool = CreateChapterTool(
        createFn: (String workId, String volumeId, String title, {int sortOrder = 0, String? content}) async =>
            (id: 'c1', title: title),
      );
      final result =
          await tool.execute({'work_id': 'w1', 'title': 'test'});
      expect(result.success, isFalse);
    });
  });

  // ── CreateCharacterTool ──
  group('CreateCharacterTool', () {
    CharacterCreateFn _createFn({
      String Function(String)? nameOverride,
    }) =>
        (String workId, String name, String tier,
                {List<String>? aliases, String? gender, String? age, String? identity, String? bio}) async =>
            (id: 'ch1', name: nameOverride != null ? nameOverride(tier) : name, tier: tier);

    test('execute succeeds with valid tier', () async {
      final tool = CreateCharacterTool(createFn: _createFn());
      final result = await tool.execute({
        'work_id': 'w1',
        'name': '林峰',
        'tier': 'protagonist',
        'gender': '男',
        'bio': '天赋异禀的少年',
      });
      expect(result.success, isTrue);
      expect(result.output, contains('林峰'));
      expect(result.output, contains('主角'));
    });

    test('execute fails with invalid tier', () async {
      final tool = CreateCharacterTool(createFn: _createFn());
      final result = await tool.execute({
        'work_id': 'w1',
        'name': '测试',
        'tier': 'invalid_tier',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('tier'));
    });

    test('execute accepts case-insensitive tier', () async {
      final tool = CreateCharacterTool(createFn: _createFn());
      final result = await tool.execute({
        'work_id': 'w1',
        'name': '反派',
        'tier': 'Antagonist',
      });
      expect(result.success, isTrue);
    });
  });

  // ── CreateRelationshipTool ──
  group('CreateRelationshipTool', () {
    test('execute succeeds with valid relation type', () async {
      final tool = CreateRelationshipTool(
        createFn: (String workId, String aId, String bId, String relationType) async =>
            (id: 'r1', relationType: relationType),
      );
      final result = await tool.execute({
        'work_id': 'w1',
        'character_a_id': 'ch1',
        'character_b_id': 'ch2',
        'relation_type': 'rival',
      });
      expect(result.success, isTrue);
      expect(result.output, contains('对手'));
    });

    test('execute fails with invalid relation type', () async {
      final tool = CreateRelationshipTool(
        createFn: (String workId, String aId, String bId, String relationType) async =>
            (id: 'r1', relationType: relationType),
      );
      final result = await tool.execute({
        'work_id': 'w1',
        'character_a_id': 'ch1',
        'character_b_id': 'ch2',
        'relation_type': 'best_friend',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('relation_type'));
    });
  });

  // ── CreateItemTool ──
  group('CreateItemTool', () {
    test('execute succeeds with required fields only', () async {
      final tool = CreateItemTool(
        createFn: ({required String workId, required String name, String? type, String? rarity, String? description, List<String>? abilities, String? holderId}) async =>
            (id: 'i1', name: name),
      );
      final result =
          await tool.execute({'work_id': 'w1', 'name': '青龙剑'});
      expect(result.success, isTrue);
      expect(result.output, contains('青龙剑'));
    });

    test('execute passes optional fields correctly', () async {
      Map<String, dynamic>? captured;
      final tool = CreateItemTool(
        createFn: ({required String workId, required String name, String? type, String? rarity, String? description, List<String>? abilities, String? holderId}) async {
          captured = {'type': type, 'rarity': rarity, 'abilities': abilities};
          return (id: 'i1', name: name);
        },
      );
      await tool.execute({
        'work_id': 'w1',
        'name': '丹药',
        'type': '消耗品',
        'rarity': '稀有',
        'abilities': ['恢复气血'],
      });
      expect(captured?['type'], '消耗品');
      expect(captured?['rarity'], '稀有');
      expect(captured?['abilities'], ['恢复气血']);
    });
  });

  // ── CreateLocationTool ──
  group('CreateLocationTool', () {
    test('execute succeeds and passes parent_id', () async {
      String? capturedParentId;
      final tool = CreateLocationTool(
        createFn: ({required String workId, required String name, String? type, String? parentId, String? description, List<String>? importantPlaces}) async {
          capturedParentId = parentId;
          return (id: 'l1', name: name);
        },
      );
      final result = await tool.execute({
        'work_id': 'w1',
        'name': '练功房',
        'parent_id': 'main_hall',
      });
      expect(result.success, isTrue);
      expect(capturedParentId, 'main_hall');
    });
  });

  // ── CreateFactionTool ──
  group('CreateFactionTool', () {
    test('execute succeeds with leader_id', () async {
      String? capturedLeaderId;
      final tool = CreateFactionTool(
        createFn: ({required String workId, required String name, String? type, String? description, List<String>? traits, String? leaderId}) async {
          capturedLeaderId = leaderId;
          return (id: 'f1', name: name);
        },
      );
      final result = await tool.execute({
        'work_id': 'w1',
        'name': '天剑宗',
        'leader_id': 'ch1',
      });
      expect(result.success, isTrue);
      expect(capturedLeaderId, 'ch1');
    });
  });

  // ── CreateInspirationTool ──
  group('CreateInspirationTool', () {
    InspirationCreateFn _createFn() =>
        ({required String title, required String content, String? workId, required String category, List<String>? tags, String? source}) async =>
            (id: 'ins1', title: title);

    test('execute succeeds with scene_fragment category', () async {
      final tool = CreateInspirationTool(createFn: _createFn());
      final result = await tool.execute({
        'title': '月下对决',
        'content': '月光如水，两道身影在屋顶交错...',
        'category': 'scene_fragment',
        'tags': ['动作', '高潮'],
      });
      expect(result.success, isTrue);
      expect(result.output, contains('场景片段'));
      expect(result.output, contains('月下对决'));
    });

    test('execute succeeds with dialogue_snippet category', () async {
      final tool = CreateInspirationTool(createFn: _createFn());
      final result = await tool.execute({
        'title': '师徒对话',
        'content': '「你可知错？」「弟子……知错。」',
        'category': 'dialogue_snippet',
      });
      expect(result.success, isTrue);
      expect(result.output, contains('对白片段'));
    });

    test('execute succeeds with worldbuilding category', () async {
      final tool = CreateInspirationTool(createFn: _createFn());
      final result = await tool.execute({
        'title': '修炼体系',
        'content': '炼气→筑基→金丹→元婴→化神',
        'category': 'worldbuilding',
      });
      expect(result.success, isTrue);
      expect(result.output, contains('世界观设定'));
    });

    test('execute fails with invalid category', () async {
      final tool = CreateInspirationTool(createFn: _createFn());
      final result = await tool.execute({
        'title': 'test',
        'content': 'test',
        'category': 'invalid',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('category'));
    });

    test('execute fails without content', () async {
      final tool = CreateInspirationTool(createFn: _createFn());
      final result = await tool.execute({
        'title': 'test',
        'category': 'idea',
      });
      expect(result.success, isFalse);
      expect(result.error, contains('content'));
    });
  });

  // ── Error handling ──
  group('Tool error propagation', () {
    test('create tool catches repository exception', () async {
      final tool = CreateWorkTool(
        createFn: (String name, {String? type, String? description, int? targetWords}) async {
          throw Exception('数据库连接失败');
        },
      );
      final result = await tool.execute({'name': '测试'});
      expect(result.success, isFalse);
      expect(result.error, contains('数据库连接失败'));
    });
  });
}