import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/data/workspace_data.dart';
import 'package:novel_writer/app/data/workspace_validator.dart';
import 'package:novel_writer/app/state/app_workspace_defaults.dart';
import 'package:novel_writer/app/state/app_workspace_records.dart';

void main() {
  group('WorkspaceValidator', () {
    group('validateProjectRecord', () {
      test('valid project has no issues', () {
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: 'scene-1',
          title: '测试项目',
          genre: '悬疑',
          summary: '测试摘要',
          recentLocation: '第 1 章 · 场景 01',
          lastOpenedAtMs: DateTime.now().millisecondsSinceEpoch,
        );
        expect(validateProjectRecord(project), isEmpty);
      });

      test('empty id is an error', () {
        final project = ProjectRecord(
          id: '',
          sceneId: 'scene-1',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 1000,
        );
        final issues = validateProjectRecord(project);
        expect(issues.any((i) => i.field == 'ProjectRecord.id'), isTrue);
        expect(
          issues.firstWhere((i) => i.field == 'ProjectRecord.id').severity,
          ValidationSeverity.error,
        );
      });

      test('empty sceneId is an error', () {
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: '',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 1000,
        );
        final issues = validateProjectRecord(project);
        expect(issues.any((i) => i.field == 'ProjectRecord.sceneId'), isTrue);
      });

      test('empty title is a warning', () {
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: 'scene-1',
          title: '  ',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 1000,
        );
        final issues = validateProjectRecord(project);
        expect(issues.any((i) => i.field == 'ProjectRecord.title'), isTrue);
        expect(
          issues.firstWhere((i) => i.field == 'ProjectRecord.title').severity,
          ValidationSeverity.warning,
        );
      });

      test('zero timestamp is a warning', () {
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: 'scene-1',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: 0,
        );
        final issues = validateProjectRecord(project);
        expect(
          issues.any((i) => i.field == 'ProjectRecord.lastOpenedAtMs'),
          isTrue,
        );
      });
    });

    group('validateSceneRecord', () {
      test('valid scene has no issues', () {
        const scene = SceneRecord(
          id: 'scene-1',
          chapterLabel: '第 1 章',
          title: '测试场景',
          summary: '摘要',
        );
        expect(validateSceneRecord(scene), isEmpty);
      });

      test('empty id is an error', () {
        const scene = SceneRecord(
          id: '',
          chapterLabel: '第 1 章',
          title: '测试',
          summary: '',
        );
        expect(
          validateSceneRecord(scene)
              .any((i) => i.field == 'SceneRecord.id' && i.severity == ValidationSeverity.error),
          isTrue,
        );
      });

      test('empty title is a warning', () {
        const scene = SceneRecord(
          id: 'scene-1',
          chapterLabel: '第 1 章',
          title: '  ',
          summary: '',
        );
        expect(
          validateSceneRecord(scene)
              .any((i) => i.field == 'SceneRecord.title' && i.severity == ValidationSeverity.warning),
          isTrue,
        );
      });
    });

    group('validateCharacterRecord', () {
      test('valid character has no issues', () {
        const character = CharacterRecord(
          id: 'char-1',
          name: '柳溪',
          role: '记者',
          note: '测试',
          need: '测试',
          summary: '测试',
        );
        expect(validateCharacterRecord(character), isEmpty);
      });

      test('empty id is an error', () {
        const character = CharacterRecord(
          id: '',
          name: '测试',
          role: '',
          note: '',
          need: '',
          summary: '',
        );
        expect(
          validateCharacterRecord(character)
              .any((i) => i.field == 'CharacterRecord.id' && i.severity == ValidationSeverity.error),
          isTrue,
        );
      });

      test('empty name is a warning', () {
        const character = CharacterRecord(
          id: 'char-1',
          name: '  ',
          role: '',
          note: '',
          need: '',
          summary: '',
        );
        expect(
          validateCharacterRecord(character)
              .any((i) => i.field == 'CharacterRecord.name' && i.severity == ValidationSeverity.warning),
          isTrue,
        );
      });
    });

    group('validateWorldNodeRecord', () {
      test('valid node has no issues', () {
        const node = WorldNodeRecord(
          id: 'world-1',
          title: '旧港规则',
          location: '旧港',
          type: '规则',
          detail: '测试',
          summary: '测试',
        );
        expect(validateWorldNodeRecord(node), isEmpty);
      });

      test('empty id is an error', () {
        const node = WorldNodeRecord(
          id: '',
          title: '测试',
          location: '',
          type: '',
          detail: '',
          summary: '',
        );
        expect(
          validateWorldNodeRecord(node)
              .any((i) => i.field == 'WorldNodeRecord.id' && i.severity == ValidationSeverity.error),
          isTrue,
        );
      });
    });

    group('validateAuditIssueRecord', () {
      test('valid issue has no issues', () {
        const issue = AuditIssueRecord(
          id: 'audit-1',
          title: '测试问题',
          evidence: '证据',
          target: '场景 01',
        );
        expect(validateAuditIssueRecord(issue), isEmpty);
      });

      test('empty id is an error', () {
        const issue = AuditIssueRecord(
          id: '',
          title: '测试',
          evidence: '',
          target: '',
        );
        expect(
          validateAuditIssueRecord(issue)
              .any((i) => i.field == 'AuditIssueRecord.id' && i.severity == ValidationSeverity.error),
          isTrue,
        );
      });
    });

    group('validateStyleProfileRecord', () {
      test('valid profile has no issues', () {
        const profile = StyleProfileRecord(
          id: 'style-1',
          name: '测试风格',
          source: 'questionnaire',
          jsonData: {},
        );
        expect(validateStyleProfileRecord(profile), isEmpty);
      });

      test('empty id is an error', () {
        const profile = StyleProfileRecord(
          id: '',
          name: '测试',
          source: '',
          jsonData: {},
        );
        expect(
          validateStyleProfileRecord(profile)
              .any((i) => i.field == 'StyleProfileRecord.id' && i.severity == ValidationSeverity.error),
          isTrue,
        );
      });
    });

    group('validateWorkspaceData', () {
      test('default workspace data is valid', () {
        final data = WorkspaceData.empty();
        final result = data.validate();
        expect(result.isValid, isTrue, reason: result.issues.join('\n'));
      });

      test('empty projects list is an error', () {
        final data = WorkspaceData(
          projects: const [],
          charactersByProjectId: const {},
          scenesByProjectId: const {},
          worldNodesByProjectId: const {},
          auditIssuesByProjectId: const {},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: '',
        );
        final result = validateWorkspaceData(data);
        expect(result.hasErrors, isTrue);
        expect(
          result.issues.any((i) => i.field == 'WorkspaceData.projects'),
          isTrue,
        );
      });

      test('missing currentProjectId is an error', () {
        final projects = buildDefaultProjects();
        final data = WorkspaceData(
          projects: projects,
          charactersByProjectId: const {},
          scenesByProjectId: const {},
          worldNodesByProjectId: const {},
          auditIssuesByProjectId: const {},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: 'nonexistent-project',
        );
        final result = validateWorkspaceData(data);
        expect(result.hasErrors, isTrue);
        expect(
          result.issues.any((i) => i.field == 'WorkspaceData.currentProjectId'),
          isTrue,
        );
      });

      test('duplicate project IDs are reported', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final projects = [
          ProjectRecord(
            id: 'dup-id',
            sceneId: 'scene-1',
            title: '项目A',
            genre: '',
            summary: '',
            recentLocation: '',
            lastOpenedAtMs: now,
          ),
          ProjectRecord(
            id: 'dup-id',
            sceneId: 'scene-2',
            title: '项目B',
            genre: '',
            summary: '',
            recentLocation: '',
            lastOpenedAtMs: now - 1,
          ),
        ];
        final data = WorkspaceData(
          projects: projects,
          charactersByProjectId: const {},
          scenesByProjectId: const {},
          worldNodesByProjectId: const {},
          auditIssuesByProjectId: const {},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: 'dup-id',
        );
        final result = validateWorkspaceData(data);
        expect(
          result.issues.any(
            (i) =>
                i.field == 'WorkspaceData.projects' &&
                i.message.contains('重复'),
          ),
          isTrue,
        );
      });

      test('character referencing nonexistent scene triggers warning', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: 'scene-1',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: now,
        );
        final data = WorkspaceData(
          projects: [project],
          charactersByProjectId: {
            'project-1': [
              const CharacterRecord(
                id: 'char-1',
                name: '测试角色',
                role: '',
                note: '',
                need: '',
                summary: '',
                linkedSceneIds: ['scene-nonexistent'],
              ),
            ],
          },
          scenesByProjectId: {
            'project-1': [
              const SceneRecord(
                id: 'scene-1',
                chapterLabel: '第 1 章',
                title: '场景1',
                summary: '',
              ),
            ],
          },
          worldNodesByProjectId: const {'project-1': []},
          auditIssuesByProjectId: const {'project-1': []},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: 'project-1',
        );
        final result = validateWorkspaceData(data);
        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((i) => i.message.contains('不存在的场景')),
          isTrue,
        );
      });

      test('project sceneId not in scene list triggers warning', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: 'scene-missing',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: now,
        );
        final data = WorkspaceData(
          projects: [project],
          charactersByProjectId: const {'project-1': []},
          scenesByProjectId: {
            'project-1': [
              const SceneRecord(
                id: 'scene-1',
                chapterLabel: '第 1 章',
                title: '场景1',
                summary: '',
              ),
            ],
          },
          worldNodesByProjectId: const {'project-1': []},
          auditIssuesByProjectId: const {'project-1': []},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: 'project-1',
        );
        final result = validateWorkspaceData(data);
        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((i) => i.message.contains('不存在于场景列表')),
          isTrue,
        );
      });

      test('orphan character data for unknown project is a warning', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final project = ProjectRecord(
          id: 'project-1',
          sceneId: 'scene-1',
          title: '测试',
          genre: '',
          summary: '',
          recentLocation: '',
          lastOpenedAtMs: now,
        );
        final data = WorkspaceData(
          projects: [project],
          charactersByProjectId: {
            'project-1': const [],
            'orphan-project': [const CharacterRecord(id: 'c', name: '孤', role: '', note: '', need: '', summary: '')],
          },
          scenesByProjectId: const {'project-1': []},
          worldNodesByProjectId: const {'project-1': []},
          auditIssuesByProjectId: const {'project-1': []},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: 'project-1',
        );
        final result = validateWorkspaceData(data);
        expect(result.hasWarnings, isTrue);
        expect(
          result.warnings.any((i) => i.message.contains('orphan-project')),
          isTrue,
        );
      });

      test('WorkspaceValidationResult partitions errors and warnings', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final data = WorkspaceData(
          projects: [
            ProjectRecord(
              id: '',
              sceneId: '',
              title: '  ',
              genre: '',
              summary: '',
              recentLocation: '',
              lastOpenedAtMs: now,
            ),
          ],
          charactersByProjectId: const {},
          scenesByProjectId: const {},
          worldNodesByProjectId: const {},
          auditIssuesByProjectId: const {},
          styleByProjectId: const {},
          auditUiByProjectId: const {},
          projectTransferState: ProjectTransferState.ready,
          currentProjectId: '',
        );
        final result = validateWorkspaceData(data);
        expect(result.hasErrors, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.errors.length + result.warnings.length, equals(result.issues.length));
      });
    });

    group('WorkspaceData.validate convenience method', () {
      test('delegates to validateWorkspaceData', () {
        final data = WorkspaceData.empty();
        final result = data.validate();
        expect(result, isA<WorkspaceValidationResult>());
        expect(result.isValid, isTrue);
      });
    });
  });
}
