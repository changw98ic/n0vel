import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/navigation/reading_route_data.dart';
import 'package:novel_writer/app/state/app_workspace_records.dart';

void main() {
  group('ReadingSceneDocument', () {
    test('stores all fields correctly', () {
      const doc = ReadingSceneDocument(
        sceneId: 'scene-1',
        locationLabel: '第一章 · 开端',
        text: '夜色如墨，雨声渐紧。',
      );

      expect(doc.sceneId, 'scene-1');
      expect(doc.locationLabel, '第一章 · 开端');
      expect(doc.text, '夜色如墨，雨声渐紧。');
    });

    test('different documents with same fields are equal', () {
      const a = ReadingSceneDocument(
        sceneId: 's1',
        locationLabel: 'loc',
        text: 'hello',
      );
      const b = ReadingSceneDocument(
        sceneId: 's1',
        locationLabel: 'loc',
        text: 'hello',
      );

      // const constructors produce identical objects
      expect(identical(a, b), isTrue);
    });
  });

  group('ReadingSessionData', () {
    test('stores all fields correctly', () {
      const docs = [
        ReadingSceneDocument(
          sceneId: 's1',
          locationLabel: '第一章',
          text: 'text-1',
        ),
      ];
      const data = ReadingSessionData(
        projectTitle: '长夜',
        initialSceneId: 's1',
        documents: docs,
      );

      expect(data.projectTitle, '长夜');
      expect(data.initialSceneId, 's1');
      expect(data.documents, hasLength(1));
      expect(data.documents.first.sceneId, 's1');
    });

    test('signature includes project title and initial scene id', () {
      const data = ReadingSessionData(
        projectTitle: '长夜',
        initialSceneId: 's1',
        documents: [],
      );

      expect(data.signature, '长夜|s1');
    });

    test('signature includes all documents', () {
      const data = ReadingSessionData(
        projectTitle: '长夜',
        initialSceneId: 's1',
        documents: [
          ReadingSceneDocument(
            sceneId: 's1',
            locationLabel: '第一章',
            text: 'hello',
          ),
          ReadingSceneDocument(
            sceneId: 's2',
            locationLabel: '第二章',
            text: 'world',
          ),
        ],
      );

      expect(data.signature, '长夜|s1|s1:第一章:hello|s2:第二章:world');
    });

    test('signature changes when document text changes', () {
      const dataA = ReadingSessionData(
        projectTitle: '长夜',
        initialSceneId: 's1',
        documents: [
          ReadingSceneDocument(
            sceneId: 's1',
            locationLabel: '第一章',
            text: 'hello',
          ),
        ],
      );
      const dataB = ReadingSessionData(
        projectTitle: '长夜',
        initialSceneId: 's1',
        documents: [
          ReadingSceneDocument(
            sceneId: 's1',
            locationLabel: '第一章',
            text: 'goodbye',
          ),
        ],
      );

      expect(dataA.signature, isNot(equals(dataB.signature)));
    });

    test('signature for empty documents list', () {
      const data = ReadingSessionData(
        projectTitle: '空项目',
        initialSceneId: '',
        documents: [],
      );

      expect(data.signature, '空项目|');
    });
  });

  group('ProjectRecord', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      const record = ProjectRecord(
        id: 'project-42',
        sceneId: 'scene-99',
        title: '暗河',
        genre: '悬疑',
        summary: '一个关于真相的故事',
        recentLocation: '第三章 · 码头',
        lastOpenedAtMs: 1700000000000,
      );

      final json = record.toJson();
      // Simulate the Map<Object?, Object?> that arrives from platform side
      final restored = ProjectRecord.fromJson(Map<Object?, Object?>.from(json));

      expect(restored.id, record.id);
      expect(restored.sceneId, record.sceneId);
      expect(restored.title, record.title);
      expect(restored.genre, record.genre);
      expect(restored.summary, record.summary);
      expect(restored.recentLocation, record.recentLocation);
      expect(restored.lastOpenedAtMs, record.lastOpenedAtMs);
    });

    test('fromJson with null id generates a fallback id', () {
      final record = ProjectRecord.fromJson({
        'id': null,
        'sceneId': 'scene-1',
        'title': '测试项目',
        'genre': '科幻',
        'summary': '',
        'recentLocation': '',
        'lastOpenedAtMs': DateTime.now().millisecondsSinceEpoch,
      });

      expect(record.id, startsWith('project-'));
      expect(record.id, isNotEmpty);
    });

    test('fromJson with empty title defaults to 新建项目', () {
      final record = ProjectRecord.fromJson({
        'id': 'p1',
        'sceneId': 's1',
        'title': '',
        'genre': '',
        'summary': '',
        'recentLocation': '',
        'lastOpenedAtMs': 1000,
      });

      expect(record.title, '新建项目');
    });

    test('fromJson with whitespace-only title defaults to 新建项目', () {
      final record = ProjectRecord.fromJson({
        'id': 'p1',
        'sceneId': 's1',
        'title': '   ',
        'genre': '',
        'summary': '',
        'recentLocation': '',
        'lastOpenedAtMs': 1000,
      });

      expect(record.title, '新建项目');
    });

    test('copyWith only modifies specified fields', () {
      const original = ProjectRecord(
        id: 'p1',
        sceneId: 's1',
        title: '旧标题',
        genre: '奇幻',
        summary: '旧摘要',
        recentLocation: '旧位置',
        lastOpenedAtMs: 1000,
      );

      final modified = original.copyWith(title: '新标题');

      expect(modified.id, 'p1');
      expect(modified.sceneId, 's1');
      expect(modified.title, '新标题');
      expect(modified.genre, '奇幻');
      expect(modified.summary, '旧摘要');
      expect(modified.recentLocation, '旧位置');
      expect(modified.lastOpenedAtMs, 1000);
    });

    test('tag returns 刚刚打开 for recent timestamp', () {
      // Timestamp within the last minute — well under the 6-hour threshold
      final recentMs = DateTime.now()
          .subtract(const Duration(minutes: 5))
          .millisecondsSinceEpoch;

      final record = ProjectRecord(
        id: 'p1',
        sceneId: 's1',
        title: '测试',
        genre: '',
        summary: '',
        recentLocation: '',
        lastOpenedAtMs: recentMs,
      );

      expect(record.tag, '刚刚打开');
    });
  });

  group('SceneRecord', () {
    test('toJson/fromJson round-trip preserves all fields', () {
      const record = SceneRecord(
        id: 'scene-7',
        chapterLabel: '第 3 章',
        title: '雨中相遇',
        summary: '主角在雨中偶遇旧友。',
      );

      final json = record.toJson();
      final restored = SceneRecord.fromJson(Map<Object?, Object?>.from(json));

      expect(restored.id, record.id);
      expect(restored.chapterLabel, record.chapterLabel);
      expect(restored.title, record.title);
      expect(restored.summary, record.summary);
    });

    test('displayLocation formats as chapterLabel · title', () {
      const record = SceneRecord(
        id: 'scene-1',
        chapterLabel: '第 1 章',
        title: '夜行',
        summary: '',
      );

      expect(record.displayLocation, '第 1 章 · 夜行');
    });

    test('location parts preserve scene anchors and expose chapter labels', () {
      const record = SceneRecord(
        id: 'scene-1',
        chapterLabel: '第 12 章 / 场景 03',
        title: '夜行',
        summary: '',
      );

      expect(record.locationParts.chapterLabel, '第 12 章');
      expect(record.locationParts.sceneLabel, '场景 03');
      expect(record.locationParts.chapterNumber, 12);
      expect(record.locationParts.sceneNumber, 3);
      expect(record.chapterOnlyLabel, '第 12 章');
      expect(chapterLabelOnly(record.chapterLabel), '第 12 章');
      expect(chapterLocationLabel(record.displayLocation), '第 12 章 · 夜行');
      expect(SceneLocationParts.firstSceneNumberIn('跳转到 场景 03'), 3);
    });

    test('fromJson with null values uses defaults', () {
      final record = SceneRecord.fromJson({});

      // id gets a generated scene id
      expect(record.id, startsWith('scene-'));
      expect(record.chapterLabel, '第 1 章 / 场景 01');
      expect(record.title, '等待命名');
      expect(record.summary, '等待补充目标、冲突和收束条件。');
    });

    test('fromJson with null id generates a fallback scene id', () {
      final record = SceneRecord.fromJson({
        'id': null,
        'chapterLabel': '附录',
        'title': '番外',
        'summary': '一段回忆。',
      });

      expect(record.id, startsWith('scene-'));
      expect(record.title, '番外');
    });
  });
}
