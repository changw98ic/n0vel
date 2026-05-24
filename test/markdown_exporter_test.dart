import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/import_export/data/markdown_exporter.dart';

void main() {
  late MarkdownExporter exporter;

  setUp(() {
    exporter = MarkdownExporter();
  });

  group('Tree shape and relative paths', () {
    test('exports to expected directory structure', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput();
      final result = await exporter.export(input, tempDir);

      expect(result.writtenFiles, contains('project.n0vel.json'));
      expect(result.writtenFiles, contains('README.md'));
      expect(result.writtenFiles.any((p) => p.startsWith('chapters/')), isTrue);
      expect(
        result.writtenFiles.any((p) => p.startsWith('bible/characters/')),
        isTrue,
      );
      expect(
        result.writtenFiles.any((p) => p.startsWith('bible/world/')),
        isTrue,
      );
    });

    test('all written files are relative paths from target root', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput();
      final result = await exporter.export(input, tempDir);

      for (final path in result.writtenFiles) {
        // No absolute paths
        expect(path, isNot(startsWith('/')));
        // No parent directory references
        expect(path, isNot(contains('..')));
      }
    });

    test('scene files follow chapters/chNN/scene-NNN.md pattern', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(id: 's1', chapterLabel: '第 1 章 / 场景 01', title: '开篇'),
          SceneRecord(id: 's2', chapterLabel: '第 1 章 / 场景 02', title: '发展'),
          SceneRecord(id: 's3', chapterLabel: '第 2 章 / 场景 01', title: '转折'),
        ],
      );
      final result = await exporter.export(input, tempDir);

      expect(result.writtenFiles, contains('chapters/ch01/scene-001.md'));
      expect(result.writtenFiles, contains('chapters/ch01/scene-002.md'));
      expect(result.writtenFiles, contains('chapters/ch02/scene-001.md'));
    });

    test(
      'character files follow bible/characters/NNN-slug.md pattern',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final input = _buildInput(
          characters: const [
            CharacterRecord(id: 'c1', name: '张三'),
            CharacterRecord(id: 'c2', name: '李四'),
          ],
        );
        final result = await exporter.export(input, tempDir);

        expect(result.writtenFiles, contains('bible/characters/001-张三.md'));
        expect(result.writtenFiles, contains('bible/characters/002-李四.md'));
      },
    );

    test('world node files follow bible/world/NNN-slug.md pattern', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        worldNodes: const [
          WorldNodeRecord(id: 'w1', title: '暗影森林'),
          WorldNodeRecord(id: 'w2', title: '魔法学院'),
        ],
        useDefaults: false,
      );
      final result = await exporter.export(input, tempDir);

      expect(result.writtenFiles, contains('bible/world/001-暗影森林.md'));
      expect(result.writtenFiles, contains('bible/world/002-魔法学院.md'));
    });
  });

  group('README.md content', () {
    test('README.md is human-readable and contains project info', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        project: const ProjectRecord(
          id: 'p1',
          sceneId: 's1',
          title: '测试小说',
          genre: '奇幻 / 冒险',
          summary: '一个关于勇者的故事。',
          recentLocation: '',
          lastOpenedAtMs: 0,
        ),
      );
      final result = await exporter.export(input, tempDir);

      final readme = await File(result.readmeFile).readAsString();

      expect(readme, contains('# 测试小说'));
      expect(readme, contains('**类型**: 奇幻 / 冒险'));
      expect(readme, contains('> 一个关于勇者的故事。'));
      expect(readme, contains('## 导出结构'));
      expect(readme, contains('project.n0vel.json'));
      expect(readme, contains('## 内容概览'));
    });

    test('README.md includes section pointers', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput();
      final result = await exporter.export(input, tempDir);

      final readme = await File(result.readmeFile).readAsString();

      expect(readme, contains('`chapters/` — 章节和场景'));
      expect(readme, contains('`bible/characters/` — 角色资料'));
      expect(readme, contains('`bible/world/` — 世界观设定'));
    });

    test('README.md shows statistics for non-empty sections', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(id: 's1', chapterLabel: '第 1 章', title: 'Scene'),
        ],
        characters: const [
          CharacterRecord(id: 'c1', name: 'Alice'),
          CharacterRecord(id: 'c2', name: 'Bob'),
        ],
        worldNodes: const [WorldNodeRecord(id: 'w1', title: 'World')],
      );
      final result = await exporter.export(input, tempDir);

      final readme = await File(result.readmeFile).readAsString();

      expect(readme, contains('**章节数**: 1'));
      expect(readme, contains('**角色数**: 2'));
      expect(readme, contains('**世界观条目**: 1'));
    });
  });

  group('Scene export', () {
    test('scene files contain frontmatter and body', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(
            id: 'scene-123',
            chapterLabel: '第 1 章 / 场景 01',
            title: '雨夜码头',
            summary: '主角抵达，遇到向导。',
          ),
        ],
      );
      await exporter.export(input, tempDir);

      final sceneFile = File('${tempDir.path}/chapters/ch01/scene-001.md');
      expect(await sceneFile.exists(), isTrue);

      final content = await sceneFile.readAsString();
      expect(content, contains('---'));
      expect(content, contains('id: scene-123'));
      expect(content, contains('chapter: 第 1 章 / 场景 01'));
      expect(content, contains('# 雨夜码头'));
      expect(content, contains('## 摘要'));
      expect(content, contains('主角抵达，遇到向导。'));
    });

    test('scenes are grouped by chapter in directories', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(id: 's1', chapterLabel: '第 1 章 / 场景 01', title: 'A'),
          SceneRecord(id: 's2', chapterLabel: '第 2 章 / 场景 01', title: 'B'),
          SceneRecord(id: 's3', chapterLabel: '第 1 章 / 场景 02', title: 'C'),
        ],
      );
      await exporter.export(input, tempDir);

      final ch01Dir = Directory('${tempDir.path}/chapters/ch01');
      final ch02Dir = Directory('${tempDir.path}/chapters/ch02');

      expect(await ch01Dir.exists(), isTrue);
      expect(await ch02Dir.exists(), isTrue);

      final ch01Files = ch01Dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toList();
      final ch02Files = ch02Dir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toList();

      expect(ch01Files.length, 2);
      expect(ch02Files.length, 1);
      expect(ch01Files, containsAll(['scene-001.md', 'scene-002.md']));
      expect(ch02Files, contains('scene-001.md'));
    });

    test(
      'scene numbering uses scene number from label when available',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final input = _buildInput(
          scenes: const [
            SceneRecord(id: 's1', chapterLabel: '第 1 章 / 场景 05', title: 'A'),
            SceneRecord(id: 's2', chapterLabel: '第 1 章 / 场景 12', title: 'B'),
          ],
        );
        await exporter.export(input, tempDir);

        final ch01Dir = Directory('${tempDir.path}/chapters/ch01');
        final files = ch01Dir
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList();

        expect(files, contains('scene-005.md'));
        expect(files, contains('scene-012.md'));
      },
    );
  });

  group('Character export', () {
    test('character files contain all fields', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        characters: const [
          CharacterRecord(
            id: 'char-001',
            name: '柳溪',
            role: '调查记者',
            summary: '冷静、急迫、对线索高度敏感。',
            need: '承认她也会判断失误',
            note: '失去搭档后的控制欲',
          ),
        ],
      );
      await exporter.export(input, tempDir);

      final charFile = File('${tempDir.path}/bible/characters/001-柳溪.md');
      expect(await charFile.exists(), isTrue);

      final content = await charFile.readAsString();
      expect(content, contains('# 柳溪'));
      expect(content, contains('**角色**: 调查记者'));
      expect(content, contains('## 简介'));
      expect(content, contains('冷静、急迫、对线索高度敏感。'));
      expect(content, contains('## 核心需求'));
      expect(content, contains('承认她也会判断失误'));
      expect(content, contains('## 备注'));
      expect(content, contains('失去搭档后的控制欲'));
    });

    test('characters are sorted alphabetically for stable numbering', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        characters: const [
          CharacterRecord(id: 'c1', name: 'Charlie'),
          CharacterRecord(id: 'c2', name: 'Alice'),
          CharacterRecord(id: 'c3', name: 'Bob'),
        ],
        useDefaults: false,
      );
      await exporter.export(input, tempDir);

      final charDir = Directory('${tempDir.path}/bible/characters');
      final files =
          charDir
              .listSync()
              .whereType<File>()
              .map((f) => f.path.split('/').last)
              .toList()
            ..sort();

      // Alphabetical order: Alice, Bob, Charlie
      expect(files[0], startsWith('001-'));
      expect(files[0], contains('Alice'));
      expect(files[1], startsWith('002-'));
      expect(files[1], contains('Bob'));
      expect(files[2], startsWith('003-'));
      expect(files[2], contains('Charlie'));
    });
  });

  group('Worldbuilding export', () {
    test('world node files contain all fields', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        worldNodes: const [
          WorldNodeRecord(
            id: 'world-001',
            title: '盐港码头',
            type: '地点',
            location: '城市东部',
            summary: '废弃的货运码头。',
            ruleSummary: '夜间禁止进入。',
            detail: '曾经是繁忙的贸易中心，现已荒废。',
          ),
        ],
      );
      await exporter.export(input, tempDir);

      final worldFile = File('${tempDir.path}/bible/world/001-盐港码头.md');
      expect(await worldFile.exists(), isTrue);

      final content = await worldFile.readAsString();
      expect(content, contains('# 盐港码头'));
      expect(content, contains('**类型**: 地点'));
      expect(content, contains('**位置**: 城市东部'));
      expect(content, contains('## 概要'));
      expect(content, contains('废弃的货运码头。'));
      expect(content, contains('## 规则'));
      expect(content, contains('夜间禁止进入。'));
      expect(content, contains('## 详情'));
      expect(content, contains('曾经是繁忙的贸易中心，现已荒废。'));
    });

    test('world nodes are sorted alphabetically by title', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        worldNodes: const [
          WorldNodeRecord(id: 'w1', title: 'Zebra'),
          WorldNodeRecord(id: 'w2', title: 'Alpha'),
          WorldNodeRecord(id: 'w3', title: 'Beta'),
        ],
        useDefaults: false,
      );
      await exporter.export(input, tempDir);

      final worldDir = Directory('${tempDir.path}/bible/world');
      final files = worldDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last)
          .toList();

      expect(files[0], contains('Alpha'));
      expect(files[1], contains('Beta'));
      expect(files[2], contains('Zebra'));
    });
  });

  group('UTF-8 and CJK support', () {
    test('CJK titles in filenames are preserved', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        characters: const [
          CharacterRecord(id: 'c1', name: '林黛玉'),
          CharacterRecord(id: 'c2', name: '薛宝钗'),
        ],
      );
      final result = await exporter.export(input, tempDir);

      expect(result.writtenFiles, contains('bible/characters/001-林黛玉.md'));
      expect(result.writtenFiles, contains('bible/characters/002-薛宝钗.md'));
    });

    test('CJK content in files is preserved', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(
            id: 's1',
            chapterLabel: '第一章',
            title: '雨夜码头',
            summary: '船只靠岸，向导现身。雨一直下，码头上的灯光昏暗。',
          ),
        ],
      );
      await exporter.export(input, tempDir);

      final sceneFile = File('${tempDir.path}/chapters/ch01/scene-001.md');
      final content = await sceneFile.readAsString();

      expect(content, contains('雨夜码头'));
      expect(content, contains('船只靠岸，向导现身。雨一直下，码头上的灯光昏暗。'));
    });
  });

  group('Unsafe filename handling', () {
    test('unsafe characters in names are replaced with hyphens', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        characters: const [CharacterRecord(id: 'c1', name: 'A/B:C*D?E')],
      );
      final result = await exporter.export(input, tempDir);

      // Should have safe filename
      expect(
        result.writtenFiles.any((p) => p.contains('001-A-B-C-D-E')),
        isTrue,
      );
    });

    test('empty names use "unnamed" fallback', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        characters: const [CharacterRecord(id: 'c1', name: '')],
      );
      final result = await exporter.export(input, tempDir);

      expect(result.writtenFiles.any((p) => p.contains('001-unnamed')), isTrue);
    });
  });

  group('Determinism and idempotence', () {
    test(
      'exporting twice to same location produces identical content',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final input = _buildInput(
          project: const ProjectRecord(
            id: 'p1',
            sceneId: 's1',
            title: '确定性测试',
            genre: '',
            summary: '',
            recentLocation: '',
            lastOpenedAtMs: 0,
          ),
          scenes: const [
            SceneRecord(
              id: 's1',
              chapterLabel: '第 1 章',
              title: 'Scene 1',
              summary: 'Summary',
            ),
          ],
        );

        await exporter.export(input, tempDir);

        final sceneFile1 = File('${tempDir.path}/chapters/ch01/scene-001.md');
        final content1 = await sceneFile1.readAsString();

        await exporter.export(input, tempDir);

        final sceneFile2 = File('${tempDir.path}/chapters/ch01/scene-001.md');
        final content2 = await sceneFile2.readAsString();

        expect(content1, equals(content2));
      },
    );

    test('no timestamps in exported markdown files', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput();
      await exporter.export(input, tempDir);

      final sceneFile = File('${tempDir.path}/chapters/ch01/scene-001.md');
      final content = await sceneFile.readAsString();

      // No timestamp-like patterns
      expect(content, isNot(contains(RegExp(r'\d{4}-\d{2}-\d{2}'))));
      expect(content, isNot(contains(RegExp(r'\d{2}:\d{2}:\d{2}'))));
    });
  });

  group('Empty collections', () {
    test(
      'export with no scenes creates chapters directory but no scene files',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final input = _buildInput(scenes: const [], useDefaults: false);
        final result = await exporter.export(input, tempDir);

        expect(result.sceneCount, 0);
        expect(await Directory('${tempDir.path}/chapters').exists(), isTrue);
      },
    );

    test(
      'export with no characters does not create character directory',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final input = _buildInput(characters: const [], useDefaults: false);
        final result = await exporter.export(input, tempDir);

        expect(result.characterCount, 0);
        // Directory is not created when there are no characters
        expect(
          await Directory('${tempDir.path}/bible/characters').exists(),
          isFalse,
        );
      },
    );

    test(
      'export with no world nodes does not create world directory',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final input = _buildInput(worldNodes: const [], useDefaults: false);
        final result = await exporter.export(input, tempDir);

        expect(result.worldNodeCount, 0);
        // Directory is not created when there are no world nodes
        expect(
          await Directory('${tempDir.path}/bible/world').exists(),
          isFalse,
        );
      },
    );
  });

  group('Scene filename collision handling', () {
    test('scenes with same parsed scene number get unique filenames', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Two scenes in the same chapter with labels that parse to same number
      final input = _buildInput(
        scenes: const [
          SceneRecord(
            id: 's1',
            chapterLabel: '第 1 章 / 场景 01',
            title: 'First Scene',
            summary: 'Content A',
          ),
          SceneRecord(
            id: 's2',
            chapterLabel: '第 1 章 / 场景 001',
            title: 'Second Scene',
            summary: 'Content B',
          ),
        ],
        useDefaults: false,
      );

      final result = await exporter.export(input, tempDir);

      // Both scenes should be counted
      expect(result.sceneCount, 2);

      // Scene paths must be unique
      final scenePaths = result.writtenFiles
          .where((p) => p.startsWith('chapters/'))
          .toList();
      expect(scenePaths.length, 2);
      expect(scenePaths[0], isNot(equals(scenePaths[1])));

      // Two scene files should exist on disk
      final ch01Dir = Directory('${tempDir.path}/chapters/ch01');
      expect(await ch01Dir.exists(), isTrue);

      final sceneFiles = ch01Dir.listSync().whereType<File>().toList();
      expect(sceneFiles.length, 2);

      // Each scene's content should be preserved in one of the files
      final contents = await Future.wait(
        sceneFiles.map((f) => f.readAsString()),
      );

      final allContent = contents.join('\n');
      expect(allContent, contains('First Scene'));
      expect(allContent, contains('Content A'));
      expect(allContent, contains('Second Scene'));
      expect(allContent, contains('Content B'));
    });

    test('collision uses title slug for disambiguation', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(id: 's1', chapterLabel: '第 1 章 / 场景 5', title: 'Opening'),
          SceneRecord(
            id: 's2',
            chapterLabel: '第 1 章 / 场景 05',
            title: 'Confrontation',
          ),
        ],
        useDefaults: false,
      );

      final result = await exporter.export(input, tempDir);

      final scenePaths =
          result.writtenFiles
              .where((p) => p.startsWith('chapters/ch01/'))
              .toList()
            ..sort();

      // Both scenes should export to unique files
      expect(scenePaths.length, 2);
      // One gets simple name, one gets title suffix (order depends on sorting)
      expect(scenePaths.any((p) => p.endsWith('scene-005.md')), isTrue);
      expect(scenePaths.any((p) => p.contains('scene-005-')), isTrue);
    });

    test('no collision when scene numbers differ', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        scenes: const [
          SceneRecord(
            id: 's1',
            chapterLabel: '第 1 章 / 场景 01',
            title: 'Scene A',
          ),
          SceneRecord(
            id: 's2',
            chapterLabel: '第 1 章 / 场景 02',
            title: 'Scene B',
          ),
        ],
        useDefaults: false,
      );

      final result = await exporter.export(input, tempDir);

      // Simple paths when no collision
      expect(result.writtenFiles, contains('chapters/ch01/scene-001.md'));
      expect(result.writtenFiles, contains('chapters/ch01/scene-002.md'));
    });

    test('collision fallback sanitizes unsafe id characters', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Force fallback by using same scene number AND same title
      // This makes the title-slug collision, forcing id-based fallback
      final input = _buildInput(
        scenes: const [
          SceneRecord(
            id: 'scene/with/slashes',
            chapterLabel: '第 1 章 / 场景 5',
            title: 'SameTitle',
            summary: 'Content from scene with slashes in id',
          ),
          SceneRecord(
            id: 'scene:with:colons',
            chapterLabel: '第 1 章 / 场景 05',
            title: 'SameTitle',
            summary: 'Content from scene with colons in id',
          ),
          SceneRecord(
            id: 'scene with spaces',
            chapterLabel: '第 1 章 / 场景 005',
            title: 'SameTitle',
            summary: 'Content from scene with spaces in id',
          ),
        ],
        useDefaults: false,
      );

      final result = await exporter.export(input, tempDir);

      // No duplicate paths
      final scenePaths = result.writtenFiles
          .where((p) => p.startsWith('chapters/'))
          .toList();
      final uniquePaths = scenePaths.toSet();
      expect(
        uniquePaths.length,
        scenePaths.length,
        reason: 'All scene paths should be unique',
      );

      // No path contains .. (parent directory escape)
      for (final path in result.writtenFiles) {
        expect(
          path,
          isNot(contains('..')),
          reason: 'Path should not contain parent directory reference',
        );
      }

      // Basename has no raw slash/unsafe id separators
      for (final path in scenePaths) {
        final basename = path.split('/').last;
        // After sanitization, slashes and colons become hyphens
        expect(
          basename,
          isNot(contains('/')),
          reason: 'Basename should not contain raw slash',
        );
        expect(
          basename,
          isNot(contains(':')),
          reason: 'Basename should not contain raw colon',
        );
      }

      // Every scene still exists on disk and preserves content
      final ch01Dir = Directory('${tempDir.path}/chapters/ch01');
      expect(await ch01Dir.exists(), isTrue);

      final sceneFiles = ch01Dir.listSync().whereType<File>().toList();
      expect(sceneFiles.length, 3, reason: 'Should have 3 scene files');

      final allContent = await Future.wait(
        sceneFiles.map((f) => f.readAsString()),
      );

      final combinedContent = allContent.join('\n');
      expect(
        combinedContent,
        contains('Content from scene with slashes in id'),
      );
      expect(combinedContent, contains('Content from scene with colons in id'));
      expect(combinedContent, contains('Content from scene with spaces in id'));
    });
  });

  group('project.n0vel.json', () {
    test('project JSON contains all input data', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput(
        project: const ProjectRecord(
          id: 'p-test',
          sceneId: 's-test',
          title: 'JSON 测试',
          genre: '类型',
          summary: '摘要',
          recentLocation: '位置',
          lastOpenedAtMs: 12345,
        ),
        draftText: '草稿内容',
      );
      final result = await exporter.export(input, tempDir);

      final jsonFile = File(result.projectJsonFile);
      expect(await jsonFile.exists(), isTrue);

      final jsonStr = await jsonFile.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, Object?>;

      expect(data['project'], isA<Map>());
      final project = data['project'] as Map<String, Object?>;
      expect(project['id'], 'p-test');
      expect(project['title'], 'JSON 测试');

      expect(data['scenes'], isA<List>());
      expect(data['characters'], isA<List>());
      expect(data['worldNodes'], isA<List>());
      expect(data['draft'], '草稿内容');
    });

    test('project JSON is indented for readability', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final input = _buildInput();
      await exporter.export(input, tempDir);

      final jsonFile = File('${tempDir.path}/project.n0vel.json');
      final content = await jsonFile.readAsString();

      expect(content, contains('\n'));
      expect(content, contains('  '));
    });
  });
}

MarkdownExportInput _buildInput({
  ProjectRecord? project,
  List<SceneRecord>? scenes,
  List<CharacterRecord>? characters,
  List<WorldNodeRecord>? worldNodes,
  String draftText = '',
  bool useDefaults = true,
}) {
  const defaultProject = ProjectRecord(
    id: 'p-default',
    sceneId: 's-default',
    title: '默认项目',
    genre: '',
    summary: '',
    recentLocation: '',
    lastOpenedAtMs: 0,
  );

  final defaultScenes = useDefaults
      ? const [
          SceneRecord(
            id: 's-default',
            chapterLabel: '第 1 章',
            title: '默认场景',
            summary: '默认摘要',
          ),
        ]
      : const <SceneRecord>[];

  final defaultCharacters = useDefaults
      ? const [CharacterRecord(id: 'c-default', name: '默认角色')]
      : const <CharacterRecord>[];

  final defaultWorldNodes = useDefaults
      ? const [WorldNodeRecord(id: 'w-default', title: '默认世界观')]
      : const <WorldNodeRecord>[];

  return MarkdownExportInput(
    project: project ?? defaultProject,
    scenes: scenes ?? defaultScenes,
    characters: characters ?? defaultCharacters,
    worldNodes: worldNodes ?? defaultWorldNodes,
    draftText: draftText,
  );
}
