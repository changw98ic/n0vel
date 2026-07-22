import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_workspace_storage_io.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_project_switch_test',
    );
    dbPath = '${tempDir.path}/authoring.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  SqliteAppWorkspaceStorage storage0() =>
      SqliteAppWorkspaceStorage(dbPath: dbPath);

  Map<String, Object?> projectAData() => {
    'projects': [
      {
        'id': 'project-A',
        'sceneId': 'scene-A1',
        'title': '项目A',
        'genre': 'test',
        'summary': '项目A的摘要',
        'recentLocation': '场景A1',
        'lastOpenedAtMs': 1000,
      },
    ],
    'charactersByProject': {
      'project-A': [
        {
          'name': '角色A1',
          'role': '主角',
          'note': 'A的笔记',
          'need': 'A的需求',
          'summary': 'A的总结',
        },
      ],
    },
    'scenesByProject': {
      'project-A': [
        {
          'id': 'scene-A1',
          'chapterLabel': '第1章',
          'title': '场景A1',
          'summary': '场景A1摘要',
        },
      ],
    },
    'worldNodesByProject': {},
    'auditIssuesByProject': {},
  };

  Map<String, Object?> projectBData() => {
    'projects': [
      {
        'id': 'project-B',
        'sceneId': 'scene-B1',
        'title': '项目B',
        'genre': 'test',
        'summary': '项目B的摘要',
        'recentLocation': '场景B1',
        'lastOpenedAtMs': 2000,
      },
    ],
    'charactersByProject': {
      'project-B': [
        {
          'name': '角色B1',
          'role': '配角',
          'note': 'B的笔记',
          'need': 'B的需求',
          'summary': 'B的总结',
        },
      ],
    },
    'scenesByProject': {
      'project-B': [
        {
          'id': 'scene-B1',
          'chapterLabel': '第2章',
          'title': '场景B1',
          'summary': '场景B1摘要',
        },
      ],
    },
    'worldNodesByProject': {},
    'auditIssuesByProject': {},
  };

  Map<String, Object?> bothProjectsData() => {
    'projects': [
      {
        'id': 'project-A',
        'sceneId': 'scene-A1',
        'title': '项目A',
        'genre': 'test',
        'summary': '项目A的摘要',
        'recentLocation': '场景A1',
        'lastOpenedAtMs': 1000,
      },
      {
        'id': 'project-B',
        'sceneId': 'scene-B1',
        'title': '项目B',
        'genre': 'test',
        'summary': '项目B的摘要',
        'recentLocation': '场景B1',
        'lastOpenedAtMs': 2000,
      },
    ],
    'charactersByProject': {
      'project-A': [
        {
          'name': '角色A1',
          'role': '主角',
          'note': 'A的笔记',
          'need': 'A的需求',
          'summary': 'A的总结',
        },
      ],
      'project-B': [
        {
          'name': '角色B1',
          'role': '配角',
          'note': 'B的笔记',
          'need': 'B的需求',
          'summary': 'B的总结',
        },
      ],
    },
    'scenesByProject': {
      'project-A': [
        {
          'id': 'scene-A1',
          'chapterLabel': '第1章',
          'title': '场景A1',
          'summary': '场景A1摘要',
        },
      ],
      'project-B': [
        {
          'id': 'scene-B1',
          'chapterLabel': '第2章',
          'title': '场景B1',
          'summary': '场景B1摘要',
        },
      ],
    },
    'worldNodesByProject': {},
    'auditIssuesByProject': {},
  };

  test('save project A then B, both preserved on load', () async {
    final storage = storage0();

    // Save project A.
    await storage.save(projectAData());
    var loaded = await storage.load();
    expect(loaded, isNotNull);
    var projects = loaded!['projects'] as List<Object?>;
    expect(projects.length, 1);

    // Save both projects.
    await storage.save(bothProjectsData());
    loaded = await storage.load();
    expect(loaded, isNotNull);
    projects = loaded!['projects'] as List<Object?>;
    expect(projects.length, 2);

    // Verify characters for each project.
    final chars = loaded['charactersByProject'] as Map<String, Object?>;
    expect((chars['project-A'] as List).length, 1);
    expect((chars['project-B'] as List).length, 1);
  });

  test('modify project A does not affect project B data', () async {
    final storage = storage0();

    // Save both projects.
    await storage.save(bothProjectsData());

    // Modify project A's title.
    final modified = bothProjectsData();
    (modified['projects'] as List).removeWhere(
      (p) => (p as Map)['id'] == 'project-A',
    );
    (modified['projects'] as List).add({
      'id': 'project-A',
      'sceneId': 'scene-A1',
      'title': '项目A-修改后',
      'genre': 'test',
      'summary': '修改后的摘要',
      'recentLocation': '场景A1',
      'lastOpenedAtMs': 3000,
    });

    await storage.save(modified);

    final loaded = await storage.load();
    expect(loaded, isNotNull);

    // Verify project B is untouched.
    final projects = loaded!['projects'] as List<Object?>;
    final projectB =
        projects.firstWhere((p) => (p as Map)['id'] == 'project-B')
            as Map<String, Object?>;
    expect(projectB['title'], '项目B');

    // Verify project A was modified.
    final projectA =
        projects.firstWhere((p) => (p as Map)['id'] == 'project-A')
            as Map<String, Object?>;
    expect(projectA['title'], '项目A-修改后');
    expect(projectA['lastOpenedAtMs'], 3000);
  });

  test('delete project A leaves project B intact', () async {
    final storage = storage0();

    // Save both.
    await storage.save(bothProjectsData());

    // Save only project B data (effectively deleting A).
    await storage.save(projectBData());

    final loaded = await storage.load();
    expect(loaded, isNotNull);
    final projects = loaded!['projects'] as List<Object?>;
    expect(projects.length, 1);
    expect((projects.first as Map)['id'], 'project-B');

    // Characters for A should be gone.
    final chars = loaded['charactersByProject'] as Map<String, Object?>;
    expect(chars.containsKey('project-A'), isFalse);
    expect(chars.containsKey('project-B'), isTrue);
  });

  test('rapid switch A → B → A → B preserves final state', () async {
    final storage = storage0();

    // Rapid saves simulating quick project switches.
    await storage.save(projectAData());
    await storage.save(projectBData());
    await storage.save(bothProjectsData());
    await storage.save(projectAData());

    // Final state should be project A only.
    final loaded = await storage.load();
    expect(loaded, isNotNull);
    final projects = loaded!['projects'] as List<Object?>;
    expect(projects.length, 1);
    expect((projects.first as Map)['id'], 'project-A');
  });

  test('save and load preserves scene data per project', () async {
    final storage = storage0();

    await storage.save(bothProjectsData());
    final loaded = await storage.load();

    final scenes = loaded!['scenesByProject'] as Map<String, Object?>;
    final scenesA = scenes['project-A'] as List<Object?>;
    final scenesB = scenes['project-B'] as List<Object?>;

    expect(scenesA.length, 1);
    expect((scenesA.first as Map)['title'], '场景A1');
    expect(scenesB.length, 1);
    expect((scenesB.first as Map)['title'], '场景B1');
  });
}
