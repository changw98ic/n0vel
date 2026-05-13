import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_version_store.dart';
import 'package:novel_writer/app/state/story_outline_store.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/import_export/data/standard_format_exporter.dart';

void main() {
  late StandardFormatExporter exporter;

  setUp(() {
    exporter = StandardFormatExporter();
  });

  StandardExportInput buildInput({
    String draftText = '这是正文内容。',
    List<VersionEntry>? versions,
    StoryOutlineSnapshot? outline,
    StandardExportMode mode = StandardExportMode.fullProject,
  }) {
    return StandardExportInput(
      project: const ProjectRecord(
        id: 'project-test',
        sceneId: 'scene-01',
        title: '月潮回声',
        genre: '悬疑 / 8.7 万字',
        summary: '证人房间对峙的故事。',
        recentLocation: '第 1 章',
        lastOpenedAtMs: 1700000000000,
      ),
      characters: const [
        CharacterRecord(
          id: 'char-1',
          name: '柳溪',
          role: '调查记者',
          note: '失去搭档后的控制欲',
          need: '承认她也会判断失误',
          summary: '冷静、急迫、对线索高度敏感。',
        ),
        CharacterRecord(id: 'char-2', name: '岳人', role: '线人'),
      ],
      scenes: const [
        SceneRecord(
          id: 'scene-01',
          chapterLabel: '第 1 章',
          title: '仓库雨夜',
          summary: '柳溪在仓库外等待线人。',
        ),
      ],
      worldNodes: const [
        WorldNodeRecord(
          id: 'world-1',
          title: '盐港码头',
          location: '城市东部',
          type: '地点',
          summary: '废弃的货运码头。',
          ruleSummary: '夜间禁止进入。',
        ),
      ],
      draftText: draftText,
      versionEntries:
          versions ??
          const [
            VersionEntry(label: '初始版本', content: '旧内容。'),
            VersionEntry(label: '第二版', content: '较新内容。'),
          ],
      outline: outline,
      mode: mode,
    );
  }

  // ===========================================================================
  // Markdown
  // ===========================================================================

  group('Markdown export', () {
    test('includes project title, genre, and summary', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.markdown,
      );
      expect(result, contains('# 月潮回声'));
      expect(result, contains('**类型**: 悬疑 / 8.7 万字'));
      expect(result, contains('> 证人房间对峙的故事。'));
    });

    test('includes characters with all fields', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.markdown,
      );
      expect(result, contains('## 角色'));
      expect(result, contains('### 柳溪'));
      expect(result, contains('**角色**: 调查记者'));
      expect(result, contains('冷静、急迫、对线索高度敏感。'));
      expect(result, contains('**核心需求**: 承认她也会判断失误'));
      expect(result, contains('**备注**: 失去搭档后的控制欲'));
      expect(result, contains('### 岳人'));
    });

    test('includes world nodes with all fields', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.markdown,
      );
      expect(result, contains('## 世界观'));
      expect(result, contains('### 盐港码头'));
      expect(result, contains('**类型**: 地点'));
      expect(result, contains('**位置**: 城市东部'));
      expect(result, contains('废弃的货运码头。'));
      expect(result, contains('**规则**: 夜间禁止进入。'));
    });

    test('includes scenes section', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.markdown,
      );
      expect(result, contains('## 章节'));
      expect(result, contains('第 1 章 · 仓库雨夜'));
      expect(result, contains('柳溪在仓库外等待线人。'));
    });

    test('includes draft text as 正文 section', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.markdown,
      );
      expect(result, contains('## 正文'));
      expect(result, contains('这是正文内容。'));
    });

    test('includes version history', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.markdown,
      );
      expect(result, contains('## 版本历史'));
      expect(result, contains('1. **初始版本**'));
      expect(result, contains('2. **第二版**'));
    });

    test('includes outline when present', () {
      const outline = StoryOutlineSnapshot(
        projectId: 'project-test',
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'ch-1',
            title: '第一章 暗流',
            summary: '柳溪到达盐港。',
            scenes: [
              StoryOutlineSceneSnapshot(
                id: 'sc-1',
                title: '码头初遇',
                summary: '柳溪在码头遇到岳人。',
                cast: [
                  StoryOutlineCastSnapshot(
                    characterId: 'char-1',
                    name: '柳溪',
                    role: '主角',
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      final result = exporter.export(
        buildInput(outline: outline),
        StandardExportFormat.markdown,
      );
      expect(result, contains('## 大纲'));
      expect(result, contains('### 第一章 暗流'));
      expect(result, contains('柳溪到达盐港。'));
      expect(result, contains('- **码头初遇**: 柳溪在码头遇到岳人。'));
      expect(result, contains('角色: 柳溪(主角)'));
    });

    test('omits empty sections', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '空项目',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [],
        scenes: [],
        worldNodes: [],
      );
      final result = exporter.export(input, StandardExportFormat.markdown);
      expect(result, contains('# 空项目'));
      expect(result, isNot(contains('## 角色')));
      expect(result, isNot(contains('## 世界观')));
      expect(result, isNot(contains('## 章节')));
      expect(result, isNot(contains('## 正文')));
      expect(result, isNot(contains('## 版本历史')));
      expect(result, isNot(contains('## 大纲')));
    });
  });

  // ===========================================================================
  // Manuscript / Final Draft
  // ===========================================================================

  group('Manuscript export', () {
    test('markdown exports a submission-ready manuscript only', () {
      const outline = StoryOutlineSnapshot(
        projectId: 'project-test',
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'ch-1',
            title: '第一章 暗流',
            summary: '柳溪到达盐港。',
          ),
          StoryOutlineChapterSnapshot(
            id: 'ch-2',
            title: '第二章 回声',
            summary: '证词开始反转。',
          ),
        ],
      );

      final result = exporter.export(
        buildInput(
          draftText: '第一章 暗流\n\n雨停在仓库门前。\n\n第二章 回声\n\n证词变得迟疑。',
          outline: outline,
        ),
        StandardExportFormat.markdown,
        mode: StandardExportMode.manuscript,
      );

      expect(result, contains('# 月潮回声'));
      expect(result, contains('## 稿件信息'));
      expect(result, contains('- 字数: 25'));
      expect(result, contains('- 章节数: 2'));
      expect(result, contains('## 目录'));
      expect(result, contains('1. 第一章 暗流'));
      expect(result, contains('2. 第二章 回声'));
      expect(result, contains('## 正文'));
      expect(result, contains('雨停在仓库门前。'));
      expect(result, isNot(contains('## 角色')));
      expect(result, isNot(contains('## 世界观')));
      expect(result, isNot(contains('## 章节')));
      expect(result, isNot(contains('## 版本历史')));
      expect(result, isNot(contains('柳溪到达盐港。')));
      expect(result, isNot(contains('废弃的货运码头。')));
    });

    test('plain text final draft omits project backup sections', () {
      final result = exporter.export(
        buildInput(draftText: '正文段落一\n正文段落二'),
        StandardExportFormat.plainText,
        mode: StandardExportMode.finalDraft,
      );

      expect(result, contains('========== 稿件信息 =========='));
      expect(result, contains('字数: 10'));
      expect(result, contains('========== 正文 =========='));
      expect(result, contains('正文段落一\n正文段落二'));
      expect(result, isNot(contains('========== 大纲 ==========')));
      expect(result, isNot(contains('调查记者')));
      expect(result, isNot(contains('盐港码头')));
    });

    test('input mode enables manuscript export without method override', () {
      final result = exporter.export(
        buildInput(draftText: '正文段落一', mode: StandardExportMode.manuscript),
        StandardExportFormat.markdown,
      );

      expect(result, contains('## 稿件信息'));
      expect(result, contains('## 正文'));
      expect(result, isNot(contains('## 角色')));
    });

    test(
      'single outline chapter is used as body heading when draft has none',
      () {
        const outline = StoryOutlineSnapshot(
          projectId: 'project-test',
          chapters: [
            StoryOutlineChapterSnapshot(
              id: 'ch-1',
              title: '第一章 暗流',
              summary: '柳溪到达盐港。',
            ),
          ],
        );

        final result = exporter.export(
          buildInput(
            draftText: '雨停在仓库门前。',
            outline: outline,
            versions: const [],
          ),
          StandardExportFormat.markdown,
          mode: StandardExportMode.manuscript,
        );

        expect(result, contains('### 第一章 暗流'));
        expect(result, contains('雨停在仓库门前。'));
      },
    );

    test(
      'json keeps full project backup semantics even in manuscript mode',
      () {
        final result = exporter.export(
          buildInput(),
          StandardExportFormat.json,
          mode: StandardExportMode.manuscript,
        );
        final decoded = jsonDecode(result) as Map<String, Object?>;

        expect(decoded['characters'], isA<List>());
        expect(decoded['worldNodes'], isA<List>());
        expect(decoded['versions'], isA<List>());
        expect(decoded['draft'], '这是正文内容。');
      },
    );
  });

  // ===========================================================================
  // Plain Text
  // ===========================================================================

  group('Plain text export', () {
    test('includes project title and genre', () {
      final result = exporter.export(
        buildInput(),
        StandardExportFormat.plainText,
      );
      expect(result, contains('月潮回声'));
      expect(result, contains('[悬疑 / 8.7 万字]'));
      expect(result, contains('证人房间对峙的故事。'));
    });

    test('includes outline when present', () {
      const outline = StoryOutlineSnapshot(
        projectId: 'project-test',
        chapters: [
          StoryOutlineChapterSnapshot(
            id: 'ch-1',
            title: '第一章',
            summary: '章节摘要',
            scenes: [
              StoryOutlineSceneSnapshot(
                id: 'sc-1',
                title: '章节一',
                summary: '章节摘要',
              ),
            ],
          ),
        ],
      );
      final result = exporter.export(
        buildInput(outline: outline),
        StandardExportFormat.plainText,
      );
      expect(result, contains('========== 大纲 =========='));
      expect(result, contains('第一章'));
      expect(result, contains('  - 章节一: 章节摘要'));
    });

    test('includes draft text', () {
      final result = exporter.export(
        buildInput(draftText: '正文段落一\n正文段落二'),
        StandardExportFormat.plainText,
      );
      expect(result, contains('========== 正文 =========='));
      expect(result, contains('正文段落一\n正文段落二'));
    });

    test('omits outline and draft sections when empty', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [],
        scenes: [],
        worldNodes: [],
      );
      final result = exporter.export(input, StandardExportFormat.plainText);
      expect(result, isNot(contains('========== 大纲 ==========')));
      expect(result, isNot(contains('========== 正文 ==========')));
    });
  });

  // ===========================================================================
  // JSON
  // ===========================================================================

  group('JSON export', () {
    test('produces valid JSON with all sections', () {
      final result = exporter.export(buildInput(), StandardExportFormat.json);
      final decoded = jsonDecode(result) as Map<String, Object?>;
      expect(decoded['project'], isA<Map>());
      expect(decoded['characters'], isA<List>());
      expect(decoded['scenes'], isA<List>());
      expect(decoded['worldNodes'], isA<List>());
      expect(decoded['draft'], '这是正文内容。');
      expect(decoded['versions'], isA<List>());
    });

    test('project JSON contains expected fields', () {
      final result = exporter.export(buildInput(), StandardExportFormat.json);
      final decoded = jsonDecode(result) as Map<String, Object?>;
      final project = decoded['project'] as Map<String, Object?>;
      expect(project['id'], 'project-test');
      expect(project['title'], '月潮回声');
      expect(project['genre'], '悬疑 / 8.7 万字');
    });

    test('includes outline when present', () {
      const outline = StoryOutlineSnapshot(
        projectId: 'project-test',
        chapters: [
          StoryOutlineChapterSnapshot(id: 'ch-1', title: '第一章', summary: '摘要'),
        ],
      );
      final result = exporter.export(
        buildInput(outline: outline),
        StandardExportFormat.json,
      );
      final decoded = jsonDecode(result) as Map<String, Object?>;
      expect(decoded['outline'], isA<Map>());
      final outlineJson = decoded['outline'] as Map<String, Object?>;
      expect(outlineJson['chapters'], isA<List>());
    });

    test('omits outline key when absent', () {
      final result = exporter.export(buildInput(), StandardExportFormat.json);
      final decoded = jsonDecode(result) as Map<String, Object?>;
      expect(decoded.containsKey('outline'), isFalse);
    });

    test('is indented for readability', () {
      final result = exporter.export(buildInput(), StandardExportFormat.json);
      expect(result, contains('\n'));
      expect(result, contains('  '));
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('edge cases', () {
    test('empty project exports without errors', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p-empty',
          sceneId: 's-empty',
          title: '空',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [],
        scenes: [],
        worldNodes: [],
      );

      for (final format in StandardExportFormat.values) {
        final result = exporter.export(input, format);
        expect(result.isNotEmpty, isTrue, reason: format.name);
      }
    });

    test('character with minimal fields exports cleanly', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'T',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [CharacterRecord(id: 'c1')],
        scenes: [],
        worldNodes: [],
      );
      final md = exporter.export(input, StandardExportFormat.markdown);
      expect(md, contains('### 新角色'));
    });

    test('world node with minimal fields exports cleanly', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'T',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [],
        scenes: [],
        worldNodes: [WorldNodeRecord(id: 'w1')],
      );
      final md = exporter.export(input, StandardExportFormat.markdown);
      expect(md, contains('### 新节点'));
    });
  });

  // ===========================================================================
  // HTML
  // ===========================================================================

  group('HTML export', () {
    test('produces valid HTML document', () {
      final result = exporter.export(buildInput(), StandardExportFormat.html);
      expect(result, contains('<!DOCTYPE html>'));
      expect(result, contains('</html>'));
      expect(result, contains('<title>月潮回声</title>'));
      expect(result, contains('<h1>月潮回声</h1>'));
    });

    test('includes project metadata', () {
      final result = exporter.export(buildInput(), StandardExportFormat.html);
      expect(result, contains('<strong>类型:</strong>'));
      expect(result, contains('悬疑 / 8.7 万字'));
      expect(result, contains('证人房间对峙的故事'));
    });

    test('includes character section', () {
      final result = exporter.export(buildInput(), StandardExportFormat.html);
      expect(result, contains('<h2>角色</h2>'));
      expect(result, contains('<h3>柳溪</h3>'));
      expect(result, contains('<strong>角色:</strong> 调查记者'));
    });

    test('includes world nodes section', () {
      final result = exporter.export(buildInput(), StandardExportFormat.html);
      expect(result, contains('<h2>世界观</h2>'));
      expect(result, contains('<h3>盐港码头</h3>'));
    });

    test('includes scenes section', () {
      final result = exporter.export(buildInput(), StandardExportFormat.html);
      expect(result, contains('<h2>章节</h2>'));
    });

    test('includes draft text as paragraphs', () {
      final result = exporter.export(buildInput(), StandardExportFormat.html);
      expect(result, contains('<h2>正文</h2>'));
      expect(result, contains('<p>这是正文内容。</p>'));
    });

    test('escapes HTML special characters', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: 'A <B> "C" & D',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [],
        scenes: [],
        worldNodes: [],
      );
      final result = exporter.export(input, StandardExportFormat.html);
      expect(result, contains('A &lt;B&gt; &quot;C&quot; &amp; D'));
    });

    test('manuscript mode includes word count and TOC', () {
      const outline = StoryOutlineSnapshot(
        projectId: 'project-test',
        chapters: [
          StoryOutlineChapterSnapshot(id: 'ch-1', title: '第一章', summary: ''),
          StoryOutlineChapterSnapshot(id: 'ch-2', title: '第二章', summary: ''),
        ],
      );
      final result = exporter.export(
        buildInput(outline: outline, mode: StandardExportMode.manuscript),
        StandardExportFormat.html,
        mode: StandardExportMode.manuscript,
      );
      expect(result, contains('<h2>目录</h2>'));
      expect(result, contains('<li>第一章</li>'));
      expect(result, contains('<li>第二章</li>'));
      expect(result, contains('字数:'));
      expect(result, contains('<h2>正文</h2>'));
    });

    test('omits sections when data is empty', () {
      const input = StandardExportInput(
        project: ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '空项目',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
        characters: [],
        scenes: [],
        worldNodes: [],
      );
      final result = exporter.export(input, StandardExportFormat.html);
      expect(result, isNot(contains('<h2>角色</h2>')));
      expect(result, isNot(contains('<h2>世界观</h2>')));
      expect(result, isNot(contains('<h2>章节</h2>')));
      expect(result, isNot(contains('<h2>正文</h2>')));
    });
  });
}
