import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/import_export/data/markdown_exporter.dart';
import 'package:novel_writer/features/import_export/data/markdown_importer.dart';

void main() {
  test(
    'imports exported markdown tree and edited bodies into records',
    () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      await MarkdownExporter().export(_input(), tempDir);
      await File('${tempDir.path}/chapters/ch01/scene-001.md').writeAsString('''
---
id: scene-1
chapter: 第 1 章 / 场景 01
---

# 雨夜码头

## 摘要

主角改为在雨夜码头发现第二枚钥匙。
''');
      await File('${tempDir.path}/bible/characters/001-林舟.md').writeAsString('''
---
id: char-1
role: 主角
---

# 林舟

**角色**: 主角

## 简介

前调查员，仍然害怕水声。

## 核心需求

找回失踪的妹妹。

## 备注

不再信任旧同事。
''');
      await File('${tempDir.path}/bible/world/001-潮汐城.md').writeAsString('''
---
id: world-1
type: 城市
location: 东海岸
---

# 潮汐城

**类型**: 城市
**位置**: 东海岸

## 概要

一座被潮汐驱动的港城。

## 规则

午夜涨潮时旧城区不可通行。

## 详情

灯塔掌握航道税。
''');

      final result = await MarkdownImporter().importProject(tempDir);

      expect(result.isValid, isTrue);
      expect(result.project?.title, '潮汐档案');
      expect(result.scenes, hasLength(1));
      expect(result.scenes.single.summary, '主角改为在雨夜码头发现第二枚钥匙。');
      expect(result.characters.single.summary, '前调查员，仍然害怕水声。');
      expect(result.characters.single.need, '找回失踪的妹妹。');
      expect(result.characters.single.note, '不再信任旧同事。');
      expect(result.worldNodes.single.summary, '一座被潮汐驱动的港城。');
      expect(result.worldNodes.single.ruleSummary, '午夜涨潮时旧城区不可通行。');
      expect(result.worldNodes.single.detail, '灯塔掌握航道税。');

      final sceneEntry = result.plan.entryFor(
        ImportTargetKind.scene,
        'scene-1',
      );
      expect(sceneEntry?.state, ImportState.needsReview);
      expect(sceneEntry?.reason, 'fingerprint_mismatch');
    },
  );

  test('reports missing project json as a blocking import issue', () async {
    final tempDir = await Directory.systemTemp.createTemp();
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final result = await MarkdownImporter().importProject(tempDir);

    expect(result.isValid, isFalse);
    expect(result.plan.blockingIssues.single.code, 'missing_project_json');
  });

  test('plans duplicate ids and missing frontmatter for review', () async {
    final tempDir = await Directory.systemTemp.createTemp();
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await MarkdownExporter().export(
      _input(
        scenes: const [
          SceneRecord(
            id: 'scene-1',
            chapterLabel: '第 1 章 / 场景 01',
            title: '雨夜码头',
            summary: '旧摘要',
          ),
          SceneRecord(
            id: 'scene-2',
            chapterLabel: '第 1 章 / 场景 02',
            title: '灯塔追逐',
            summary: '追逐摘要',
          ),
        ],
      ),
      tempDir,
    );
    await File('${tempDir.path}/chapters/ch01/scene-002.md').writeAsString('''
---
id: scene-1
chapter: 第 1 章 / 场景 02
---

# 灯塔追逐

## 摘要

第二个文件重复了 scene-1。
''');
    await File('${tempDir.path}/bible/characters/001-林舟.md').writeAsString('''
# 林舟

## 简介

这个文件没有 frontmatter。
''');

    final result = await MarkdownImporter().importProject(tempDir);

    final duplicateEntries = result.plan.entries
        .where(
          (entry) =>
              entry.kind == ImportTargetKind.scene && entry.id == 'scene-1',
        )
        .toList();
    expect(duplicateEntries, hasLength(2));
    expect(
      duplicateEntries.every(
        (entry) => entry.state == ImportState.conflictKeepBoth,
      ),
      isTrue,
    );

    final characterEntry = result.plan.entries.singleWhere(
      (entry) => entry.kind == ImportTargetKind.character,
    );
    expect(characterEntry.state, ImportState.needsReview);
    expect(characterEntry.reason, 'missing_frontmatter');
  });

  test('plans missing scene chapter frontmatter for review', () async {
    final tempDir = await Directory.systemTemp.createTemp();
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    await MarkdownExporter().export(_input(), tempDir);
    await File('${tempDir.path}/chapters/ch01/scene-001.md').writeAsString('''
---
id: scene-1
---

# 雨夜码头

## 摘要

主角在码头发现第一枚钥匙。
''');

    final result = await MarkdownImporter().importProject(tempDir);

    final sceneEntry = result.plan.entryFor(ImportTargetKind.scene, 'scene-1');
    expect(sceneEntry?.state, ImportState.needsReview);
    expect(sceneEntry?.reason, 'missing_required_chapter');
    expect(result.scenes.single.chapterLabel, '第 1 章');
  });
}

MarkdownExportInput _input({
  List<SceneRecord>? scenes,
  List<CharacterRecord>? characters,
  List<WorldNodeRecord>? worldNodes,
}) {
  return MarkdownExportInput(
    project: const ProjectRecord(
      id: 'project-1',
      sceneId: 'scene-1',
      title: '潮汐档案',
      genre: '悬疑',
      summary: '港城谜案。',
      recentLocation: '第 1 章 / 场景 01',
      lastOpenedAtMs: 1,
    ),
    scenes:
        scenes ??
        const [
          SceneRecord(
            id: 'scene-1',
            chapterLabel: '第 1 章 / 场景 01',
            title: '雨夜码头',
            summary: '主角在码头发现第一枚钥匙。',
          ),
        ],
    characters:
        characters ??
        const [
          CharacterRecord(
            id: 'char-1',
            name: '林舟',
            role: '主角',
            summary: '前调查员。',
            need: '寻找真相。',
            note: '讨厌雨夜。',
          ),
        ],
    worldNodes:
        worldNodes ??
        const [
          WorldNodeRecord(
            id: 'world-1',
            title: '潮汐城',
            type: '城市',
            location: '东海岸',
            summary: '港城。',
            ruleSummary: '潮汐影响交通。',
            detail: '灯塔很重要。',
          ),
        ],
  );
}
