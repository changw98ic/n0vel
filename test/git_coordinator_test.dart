import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/git_coordinator.dart';
import 'package:novel_writer/domain/workspace_models.dart';
import 'package:novel_writer/features/import_export/data/markdown_exporter.dart';

void main() {
  group('GitCoordinator.checkStatus', () {
    test(
      'returns clean status for a Git worktree with no uncommitted changes',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        // Initialize a Git repository
        await Process.run('git', ['-C', tempDir.path, 'init']);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'config',
          'user.email',
          'test@example.com',
        ]);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'config',
          'user.name',
          'Test User',
        ]);
        await File('${tempDir.path}/test.txt').writeAsString('test');
        await Process.run('git', ['-C', tempDir.path, 'add', 'test.txt']);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'commit',
          '-m',
          'Initial commit',
        ]);

        final coordinator = GitCoordinator();
        final result = await coordinator.checkStatus(tempDir);

        expect(result.status, GitCoordinatorStatus.clean);
        expect(result.isGitWorktree, isTrue);
        expect(result.hasUncommittedChanges, isFalse);
        expect(result.changedFiles, isEmpty);
        expect(result.issues, isEmpty);
      },
    );

    test(
      'returns dirty status for a Git worktree with uncommitted changes',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        // Initialize a Git repository
        await Process.run('git', ['-C', tempDir.path, 'init']);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'config',
          'user.email',
          'test@example.com',
        ]);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'config',
          'user.name',
          'Test User',
        ]);
        await File('${tempDir.path}/test.txt').writeAsString('test');
        await Process.run('git', ['-C', tempDir.path, 'add', 'test.txt']);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'commit',
          '-m',
          'Initial commit',
        ]);
        // Make uncommitted changes
        await File('${tempDir.path}/test.txt').writeAsString('modified');
        await File('${tempDir.path}/new.txt').writeAsString('new');

        final coordinator = GitCoordinator();
        final result = await coordinator.checkStatus(tempDir);

        expect(result.status, GitCoordinatorStatus.dirty);
        expect(result.isGitWorktree, isTrue);
        expect(result.hasUncommittedChanges, isTrue);
        expect(result.changedFiles, contains('test.txt'));
        expect(result.changedFiles, contains('new.txt'));
      },
    );

    test(
      'returns nonGit status for a directory that is not a Git worktree',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final coordinator = GitCoordinator();
        final result = await coordinator.checkStatus(tempDir);

        expect(result.status, GitCoordinatorStatus.nonGit);
        expect(result.isGitWorktree, isFalse);
        expect(result.hasUncommittedChanges, isFalse);
        expect(result.changedFiles, isEmpty);
        expect(result.issues, isEmpty);
      },
    );

    test('returns gitUnavailable status when Git command fails', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Mock command runner that always fails
      final mockGitCommand = _MockGitCommand(
        Future.value(ProcessResult(0, 1, '', 'Git command failed')),
      );

      final coordinator = GitCoordinator(commandRunner: mockGitCommand);
      final result = await coordinator.checkStatus(tempDir);

      expect(result.status, GitCoordinatorStatus.gitUnavailable);
      expect(result.issues, isNotEmpty);
      expect(result.issues.first.code, 'git_rev_parse_failed');
    });

    test(
      'returns gitUnavailable status when Git executable is not found',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        // Mock command runner that throws ProcessException
        final mockGitCommand = _MockGitCommand(
          Future.error(
            const ProcessException(
              'nonexistent-git',
              [],
              'Executable not found',
            ),
          ),
        );

        final coordinator = GitCoordinator(commandRunner: mockGitCommand);
        final result = await coordinator.checkStatus(tempDir);

        expect(result.status, GitCoordinatorStatus.gitUnavailable);
        expect(result.issues, isNotEmpty);
        expect(result.issues.first.code, 'git_executable_not_found');
      },
    );
  });

  group('GitCoordinator.syncImport', () {
    test('imports from clean Git mirror and returns import plan', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Set up a valid n0vel project structure
      await MarkdownExporter().export(_validInput(), tempDir);

      // Initialize a Git repository and commit everything
      await Process.run('git', ['-C', tempDir.path, 'init']);
      await Process.run('git', [
        '-C',
        tempDir.path,
        'config',
        'user.email',
        'test@example.com',
      ]);
      await Process.run('git', [
        '-C',
        tempDir.path,
        'config',
        'user.name',
        'Test User',
      ]);
      await Process.run('git', ['-C', tempDir.path, 'add', '.']);
      await Process.run('git', [
        '-C',
        tempDir.path,
        'commit',
        '-m',
        'Initial commit',
      ]);

      final coordinator = GitCoordinator();
      final result = await coordinator.syncImport(tempDir);

      expect(result.status, GitCoordinatorStatus.clean);
      expect(result.isGitWorktree, isTrue);
      expect(result.hasUncommittedChanges, isFalse);
      expect(result.importResult, isNotNull);
      expect(result.importResult?.isValid, isTrue);
      expect(result.importResult?.project?.title, '潮汐档案');
    });

    test(
      'imports from dirty Git mirror and returns import plan with changes',
      () async {
        final tempDir = await Directory.systemTemp.createTemp();
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        // Set up a valid n0vel project structure
        await MarkdownExporter().export(_validInput(), tempDir);

        // Initialize a Git repository and commit everything
        await Process.run('git', ['-C', tempDir.path, 'init']);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'config',
          'user.email',
          'test@example.com',
        ]);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'config',
          'user.name',
          'Test User',
        ]);
        await Process.run('git', ['-C', tempDir.path, 'add', '.']);
        await Process.run('git', [
          '-C',
          tempDir.path,
          'commit',
          '-m',
          'Initial commit',
        ]);

        // Make uncommitted changes
        await File('${tempDir.path}/chapters/ch01/scene-001.md').writeAsString(
          '''
---
id: scene-1
chapter: 第 1 章 / 场景 01
---

# 雨夜码头

## 摘要

主角改为在雨夜码头发现第二枚钥匙。
''',
        );

        final coordinator = GitCoordinator();
        final result = await coordinator.syncImport(tempDir);

        expect(result.status, GitCoordinatorStatus.dirty);
        expect(result.isGitWorktree, isTrue);
        expect(result.hasUncommittedChanges, isTrue);
        expect(result.changedFiles, contains('chapters/ch01/scene-001.md'));
        expect(result.importResult, isNotNull);
        expect(result.importResult?.isValid, isTrue);
        expect(result.importResult?.scenes.single.summary, '主角改为在雨夜码头发现第二枚钥匙。');
      },
    );

    test('returns importBlocked when project.n0vel.json is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Initialize a Git repository without project.n0vel.json
      await Process.run('git', ['-C', tempDir.path, 'init']);
      await Process.run('git', [
        '-C',
        tempDir.path,
        'config',
        'user.email',
        'test@example.com',
      ]);
      await Process.run('git', [
        '-C',
        tempDir.path,
        'config',
        'user.name',
        'Test User',
      ]);
      await File('${tempDir.path}/test.txt').writeAsString('test');
      await Process.run('git', ['-C', tempDir.path, 'add', 'test.txt']);
      await Process.run('git', [
        '-C',
        tempDir.path,
        'commit',
        '-m',
        'Initial commit',
      ]);

      final coordinator = GitCoordinator();
      final result = await coordinator.syncImport(tempDir);

      expect(result.status, GitCoordinatorStatus.importBlocked);
      expect(result.isGitWorktree, isTrue);
      expect(result.importResult, isNotNull);
      expect(result.importResult?.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'missing_project_json'),
        isTrue,
      );
    });

    test('returns nonGit status when syncing in a non-Git directory', () async {
      final tempDir = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Set up a valid n0vel project structure but no Git
      await MarkdownExporter().export(_validInput(), tempDir);

      final coordinator = GitCoordinator();
      final result = await coordinator.syncImport(tempDir);

      expect(result.status, GitCoordinatorStatus.nonGit);
      expect(result.isGitWorktree, isFalse);
      expect(result.importResult, isNotNull);
      expect(result.importResult?.isValid, isTrue);
    });
  });
}

MarkdownExportInput _validInput() {
  return const MarkdownExportInput(
    project: ProjectRecord(
      id: 'project-1',
      sceneId: 'scene-1',
      title: '潮汐档案',
      genre: '悬疑',
      summary: '港城谜案。',
      recentLocation: '第 1 章 / 场景 01',
      lastOpenedAtMs: 1,
    ),
    scenes: [
      SceneRecord(
        id: 'scene-1',
        chapterLabel: '第 1 章 / 场景 01',
        title: '雨夜码头',
        summary: '主角在码头发现第一枚钥匙。',
      ),
    ],
    characters: [
      CharacterRecord(
        id: 'char-1',
        name: '林舟',
        role: '主角',
        summary: '前调查员。',
        need: '寻找真相。',
        note: '讨厌雨夜。',
      ),
    ],
    worldNodes: [
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

class _MockGitCommand extends GitCommand {
  _MockGitCommand(this.result);

  final Future<ProcessResult> result;

  @override
  Future<ProcessResult> call(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return result;
  }
}
