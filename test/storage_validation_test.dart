import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/storage_validation.dart';

void main() {
  late WorkspaceDataValidator validator;

  setUp(() {
    validator = WorkspaceDataValidator();
  });

  // =========================================================================
  // ValidationSeverity
  // =========================================================================

  group('ValidationSeverity', () {
    test('error is not warning', () {
      expect(ValidationSeverity.error == ValidationSeverity.warning, isFalse);
    });
  });

  // =========================================================================
  // ValidationError
  // =========================================================================

  group('ValidationError', () {
    test('toString without context shows field and message', () {
      const error = ValidationError(field: 'id', message: '不能为空');
      expect(error.toString(), 'id: 不能为空');
    });

    test('toString with context prefixes context', () {
      const error = ValidationError(
        field: 'title',
        message: '不能为空白',
        context: 'projects[0]',
      );
      expect(error.toString(), 'projects[0].title: 不能为空白');
    });

    test('isError is true by default', () {
      const error = ValidationError(field: 'id', message: '空');
      expect(error.isError, isTrue);
      expect(error.isWarning, isFalse);
    });

    test('isWarning is true for warning severity', () {
      const error = ValidationError(
        field: 'status',
        message: '可疑值',
        severity: ValidationSeverity.warning,
      );
      expect(error.isWarning, isTrue);
      expect(error.isError, isFalse);
    });

    test('toString with warning severity includes [WARNING]', () {
      const error = ValidationError(
        field: 'status',
        message: '可疑值',
        severity: ValidationSeverity.warning,
      );
      expect(error.toString(), contains('[WARNING]'));
    });

    test('toString with warning and context combines both', () {
      const error = ValidationError(
        field: 'status',
        message: '可疑值',
        context: 'auditIssues[0]',
        severity: ValidationSeverity.warning,
      );
      expect(error.toString(), 'auditIssues[0].status: [WARNING] 可疑值');
    });

    test('equality considers all fields', () {
      const a = ValidationError(
        field: 'f',
        message: 'm',
        context: 'c',
        severity: ValidationSeverity.warning,
      );
      const b = ValidationError(
        field: 'f',
        message: 'm',
        context: 'c',
        severity: ValidationSeverity.warning,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality for different severity', () {
      const a = ValidationError(
        field: 'f',
        message: 'm',
        severity: ValidationSeverity.error,
      );
      const b = ValidationError(
        field: 'f',
        message: 'm',
        severity: ValidationSeverity.warning,
      );
      expect(a == b, isFalse);
    });

    test('inequality for different field', () {
      const a = ValidationError(field: 'a', message: 'm');
      const b = ValidationError(field: 'b', message: 'm');
      expect(a == b, isFalse);
    });
  });

  // =========================================================================
  // ValidationResult
  // =========================================================================

  group('ValidationResult', () {
    test('ok result is valid with no errors', () {
      final result = ValidationResult.ok();
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('fail result is invalid with errors', () {
      final result = ValidationResult.fail([
        const ValidationError(field: 'id', message: '空'),
      ]);
      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(1));
    });

    test('merge combines errors from both results', () {
      final a = ValidationResult.fail([
        const ValidationError(field: 'a', message: 'err-a'),
      ]);
      final b = ValidationResult.fail([
        const ValidationError(field: 'b', message: 'err-b'),
      ]);
      final merged = a.merge(b);
      expect(merged.isValid, isFalse);
      expect(merged.errors, hasLength(2));
    });

    test('merge with ok returns other', () {
      final ok = ValidationResult.ok();
      final fail = ValidationResult.fail([
        const ValidationError(field: 'x', message: 'err'),
      ]);
      expect(ok.merge(fail).errors, hasLength(1));
      expect(fail.merge(ok).errors, hasLength(1));
    });

    test('hasErrors is true when error-severity items exist', () {
      final result = ValidationResult.fail([
        const ValidationError(field: 'x', message: 'err'),
      ]);
      expect(result.hasErrors, isTrue);
      expect(result.hasWarnings, isFalse);
    });

    test('hasWarnings is true when warning-severity items exist', () {
      final result = ValidationResult.fail([
        const ValidationError(
          field: 'w',
          message: 'warn',
          severity: ValidationSeverity.warning,
        ),
      ]);
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('errorsOnly filters to error severity', () {
      final result = ValidationResult.fail([
        const ValidationError(field: 'e1', message: 'err'),
        const ValidationError(
          field: 'w1',
          message: 'warn',
          severity: ValidationSeverity.warning,
        ),
        const ValidationError(field: 'e2', message: 'err2'),
      ]);
      expect(result.errorsOnly, hasLength(2));
      expect(result.warnings, hasLength(1));
    });

    test('ok result has no errors and no warnings', () {
      final result = ValidationResult.ok();
      expect(result.hasErrors, isFalse);
      expect(result.hasWarnings, isFalse);
    });
  });

  // =========================================================================
  // validateProject
  // =========================================================================

  group('validateProject', () {
    Map<String, Object?> validProject() => {
          'id': 'project-1',
          'sceneId': 'scene-1',
          'title': '测试项目',
          'genre': '悬疑',
          'summary': '摘要',
          'recentLocation': '位置',
          'lastOpenedAtMs': 1700000000000,
        };

    test('valid project passes validation', () {
      expect(validator.validateProject(validProject()).isValid, isTrue);
    });

    test('empty id fails', () {
      final project = validProject()..['id'] = '';
      final result = validator.validateProject(project);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.field == 'id'), isTrue);
    });

    test('null id fails', () {
      final project = validProject()..['id'] = null;
      expect(validator.validateProject(project).isValid, isFalse);
    });

    test('empty sceneId fails', () {
      final project = validProject()..['sceneId'] = '';
      expect(validator.validateProject(project).isValid, isFalse);
    });

    test('blank title fails', () {
      final project = validProject()..['title'] = '   ';
      final result = validator.validateProject(project);
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.field == 'title'), isTrue);
    });

    test('zero lastOpenedAtMs fails', () {
      final project = validProject()..['lastOpenedAtMs'] = 0;
      expect(validator.validateProject(project).isValid, isFalse);
    });

    test('negative lastOpenedAtMs fails', () {
      final project = validProject()..['lastOpenedAtMs'] = -1;
      expect(validator.validateProject(project).isValid, isFalse);
    });

    test('string lastOpenedAtMs fails', () {
      final project = validProject()..['lastOpenedAtMs'] = 'not-a-number';
      expect(validator.validateProject(project).isValid, isFalse);
    });

    test('multiple errors are all reported', () {
      final result = validator.validateProject({
        'id': '',
        'sceneId': null,
        'title': '  ',
        'lastOpenedAtMs': -5,
      });
      expect(result.isValid, isFalse);
      expect(result.errors, hasLength(4));
    });
  });

  // =========================================================================
  // validateScene
  // =========================================================================

  group('validateScene', () {
    test('valid scene passes', () {
      expect(
        validator.validateScene({
          'id': 'scene-1',
          'title': '场景一',
        }).isValid,
        isTrue,
      );
    });

    test('empty id fails', () {
      expect(
        validator.validateScene({'id': '', 'title': '标题'}).isValid,
        isFalse,
      );
    });

    test('blank title fails', () {
      expect(
        validator.validateScene({'id': 'scene-1', 'title': '\t'}).isValid,
        isFalse,
      );
    });
  });

  // =========================================================================
  // validateCharacter
  // =========================================================================

  group('validateCharacter', () {
    test('valid character passes', () {
      expect(
        validator.validateCharacter({'name': '柳溪'}).isValid,
        isTrue,
      );
    });

    test('empty name fails', () {
      expect(
        validator.validateCharacter({'name': ''}).isValid,
        isFalse,
      );
    });

    test('blank name fails', () {
      expect(
        validator.validateCharacter({'name': '  '}).isValid,
        isFalse,
      );
    });

    test('valid linkedSceneIds passes', () {
      expect(
        validator
            .validateCharacter({
              'name': '柳溪',
              'linkedSceneIds': ['scene-1', 'scene-2'],
            }, validSceneIds: {'scene-1', 'scene-2'})
            .isValid,
        isTrue,
      );
    });

    test('dangling linkedSceneIds produces warning', () {
      final result = validator.validateCharacter(
        {
          'name': '柳溪',
          'linkedSceneIds': ['scene-1', 'scene-missing'],
        },
        validSceneIds: {'scene-1'},
      );
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
      expect(
        result.warnings.any((e) => e.message.contains('scene-missing')),
        isTrue,
      );
    });

    test('empty string in linkedSceneIds fails', () {
      final result = validator.validateCharacter({
        'name': '柳溪',
        'linkedSceneIds': [''],
      });
      expect(result.isValid, isFalse);
      expect(result.hasErrors, isTrue);
    });

    test('non-list linkedSceneIds fails', () {
      final result = validator.validateCharacter({
        'name': '柳溪',
        'linkedSceneIds': 'not-a-list',
      });
      expect(result.isValid, isFalse);
      expect(result.errors.first.field, 'linkedSceneIds');
    });

    test('null linkedSceneIds is tolerated', () {
      expect(
        validator.validateCharacter({
          'name': '柳溪',
          'linkedSceneIds': null,
        }).isValid,
        isTrue,
      );
    });

    test('missing linkedSceneIds is tolerated', () {
      expect(
        validator.validateCharacter({'name': '柳溪'}).isValid,
        isTrue,
      );
    });

    test('linkedSceneIds without validSceneIds skips cross-ref', () {
      expect(
        validator
            .validateCharacter({
              'name': '柳溪',
              'linkedSceneIds': ['any-id'],
            })
            .isValid,
        isTrue,
      );
    });
  });

  // =========================================================================
  // validateWorldNode
  // =========================================================================

  group('validateWorldNode', () {
    test('valid node passes', () {
      expect(
        validator.validateWorldNode({'title': '旧港规则'}).isValid,
        isTrue,
      );
    });

    test('blank title fails', () {
      expect(
        validator.validateWorldNode({'title': '\n'}).isValid,
        isFalse,
      );
    });

    test('dangling linkedSceneIds produces warning', () {
      final result = validator.validateWorldNode(
        {
          'title': '旧港规则',
          'linkedSceneIds': ['scene-ghost'],
        },
        validSceneIds: {'scene-1'},
      );
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('non-list linkedSceneIds fails', () {
      final result = validator.validateWorldNode({
        'title': '旧港规则',
        'linkedSceneIds': 42,
      });
      expect(result.isValid, isFalse);
      expect(result.errors.first.field, 'linkedSceneIds');
    });
  });

  // =========================================================================
  // validateAuditIssue
  // =========================================================================

  group('validateAuditIssue', () {
    test('valid issue passes', () {
      expect(
        validator.validateAuditIssue({'title': '角色动机冲突'}).isValid,
        isTrue,
      );
    });

    test('blank title fails', () {
      expect(
        validator.validateAuditIssue({'title': ''}).isValid,
        isFalse,
      );
    });

    test('valid status open passes', () {
      expect(
        validator
            .validateAuditIssue({'title': '问题', 'status': 'open'})
            .isValid,
        isTrue,
      );
    });

    test('valid status resolved passes', () {
      expect(
        validator
            .validateAuditIssue({'title': '问题', 'status': 'resolved'})
            .isValid,
        isTrue,
      );
    });

    test('valid status ignored passes', () {
      expect(
        validator
            .validateAuditIssue({'title': '问题', 'status': 'ignored'})
            .isValid,
        isTrue,
      );
    });

    test('invalid status produces warning', () {
      final result = validator.validateAuditIssue({
        'title': '问题',
        'status': 'unknown-value',
      });
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
      expect(
        result.warnings.first.message,
        contains('unknown-value'),
      );
    });

    test('null status is tolerated', () {
      expect(
        validator
            .validateAuditIssue({'title': '问题', 'status': null})
            .isValid,
        isTrue,
      );
    });

    test('empty string status is tolerated', () {
      expect(
        validator
            .validateAuditIssue({'title': '问题', 'status': ''})
            .isValid,
        isTrue,
      );
    });
  });

  // =========================================================================
  // validateStyleProfile
  // =========================================================================

  group('validateStyleProfile', () {
    test('valid profile passes', () {
      expect(
        validator
            .validateStyleProfile({
              'id': 'style-1',
              'name': '悬疑风格',
              'source': 'questionnaire',
              'jsonData': {'key': 'value'},
            })
            .isValid,
        isTrue,
      );
    });

    test('blank name fails', () {
      expect(
        validator.validateStyleProfile({'name': '  '}).isValid,
        isFalse,
      );
    });

    test('empty name fails', () {
      expect(
        validator.validateStyleProfile({'name': ''}).isValid,
        isFalse,
      );
    });

    test('valid source values all pass', () {
      for (final source in ['questionnaire', 'sample', 'custom']) {
        expect(
          validator
              .validateStyleProfile({'name': '测试', 'source': source})
              .isValid,
          isTrue,
          reason: 'source=$source should be valid',
        );
      }
    });

    test('invalid source produces warning', () {
      final result = validator.validateStyleProfile({
        'name': '测试',
        'source': 'unknown',
      });
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
      expect(result.warnings.first.field, 'source');
    });

    test('non-map jsonData fails', () {
      final result = validator.validateStyleProfile({
        'name': '测试',
        'jsonData': 'not-a-map',
      });
      expect(result.isValid, isFalse);
      expect(result.hasErrors, isTrue);
      expect(result.errors.first.field, 'jsonData');
    });

    test('null jsonData is tolerated', () {
      expect(
        validator
            .validateStyleProfile({'name': '测试', 'jsonData': null})
            .isValid,
        isTrue,
      );
    });

    test('map jsonData passes', () {
      expect(
        validator
            .validateStyleProfile({
              'name': '测试',
              'jsonData': {'any': 'value'},
            })
            .isValid,
        isTrue,
      );
    });

    test('empty source is tolerated', () {
      expect(
        validator
            .validateStyleProfile({'name': '测试', 'source': ''})
            .isValid,
        isTrue,
      );
    });
  });

  // =========================================================================
  // validateWorkspaceData
  // =========================================================================

  group('validateWorkspaceData', () {
    Map<String, Object?> fullValidData() => {
          'projects': [
            {
              'id': 'project-alpha',
              'sceneId': 'scene-01',
              'title': '月潮回声',
              'genre': '悬疑',
              'summary': '摘要',
              'recentLocation': '位置',
              'lastOpenedAtMs': 1700000000000,
            },
          ],
          'charactersByProject': {
            'project-alpha': [
              {
                'name': '柳溪',
                'role': '主角',
                'note': '备注',
                'need': '需求',
                'summary': '摘要',
                'linkedSceneIds': ['scene-01'],
              },
            ],
          },
          'scenesByProject': {
            'project-alpha': [
              {
                'id': 'scene-01',
                'chapterLabel': '第1章',
                'title': '开篇',
                'summary': '摘要',
              },
            ],
          },
          'worldNodesByProject': {
            'project-alpha': [
              {
                'title': '旧港规则',
                'location': '旧港',
                'type': '规则',
                'detail': '细节',
                'summary': '摘要',
                'linkedSceneIds': ['scene-01'],
              },
            ],
          },
          'auditIssuesByProject': {
            'project-alpha': [
              {
                'title': '动机冲突',
                'evidence': '证据',
                'target': '场景05',
                'status': 'open',
              },
            ],
          },
        };

    test('fully valid workspace data passes', () {
      expect(validator.validateWorkspaceData(fullValidData()).isValid, isTrue);
    });

    test('empty data passes (no data to validate)', () {
      expect(validator.validateWorkspaceData({}).isValid, isTrue);
    });

    test('null list values are tolerated', () {
      expect(
        validator.validateWorkspaceData({'projects': null}).isValid,
        isTrue,
      );
    });

    test('wrong type for projects list fails', () {
      final result = validator.validateWorkspaceData({'projects': 'not-a-list'});
      expect(result.isValid, isFalse);
      expect(result.errors.first.field, 'projects');
    });

    test('wrong type for scoped map fails', () {
      final result = validator.validateWorkspaceData({
        'charactersByProject': 42,
      });
      expect(result.isValid, isFalse);
      expect(result.errors.first.field, 'charactersByProject');
    });

    test('invalid project in list reports errors with context', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {'id': '', 'sceneId': '', 'title': '  ', 'lastOpenedAtMs': -1},
        ],
      });
      expect(result.isValid, isFalse);
      expect(result.errors.first.context, contains('projects[0]'));
    });

    test('scoped collection with dangling project id reports error', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-exists',
            'sceneId': 'scene-1',
            'title': '存在项目',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': {
          'project-ghost': [
            {'name': '幽灵角色', 'role': 'r', 'note': 'n', 'need': 'ne', 'summary': 's'},
          ],
        },
      });
      expect(result.isValid, isFalse);
      expect(
        result.errors.any((e) => e.message.contains('project-ghost')),
        isTrue,
      );
    });

    test('invalid character in scoped collection reports context', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-1',
            'title': '项目',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': {
          'project-a': [
            {'name': '', 'role': 'r', 'note': 'n'},
          ],
        },
      });
      expect(result.isValid, isFalse);
      expect(
        result.errors.first.context,
        contains('charactersByProject.project-a[0]'),
      );
    });

    test('non-map entries in scoped lists are skipped', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-1',
            'title': '项目',
            'lastOpenedAtMs': 1,
          },
        ],
        'charactersByProject': {
          'project-a': ['not-a-map', 42, null],
        },
      });
      expect(result.isValid, isTrue);
    });

    test('non-map entries in project list are skipped', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          'bad',
          {
            'id': 'project-ok',
            'sceneId': 'scene-1',
            'title': '好项目',
            'lastOpenedAtMs': 1,
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('valid data with no scoped collections passes', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-solo',
            'sceneId': 'scene-1',
            'title': '独立项目',
            'lastOpenedAtMs': 1000,
          },
        ],
      });
      expect(result.isValid, isTrue);
    });

    test('multiple errors across sections are all collected', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {'id': '', 'sceneId': '', 'title': ' ', 'lastOpenedAtMs': 0},
        ],
        'charactersByProject': {
          'fallback': [
            {'name': ''},
          ],
        },
      });
      expect(result.isValid, isFalse);
      expect(result.errors.length, greaterThan(2));
    });

    test('dangling scene id in character linkedSceneIds produces warning', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-1',
            'title': '项目',
            'lastOpenedAtMs': 1,
          },
        ],
        'scenesByProject': {
          'project-a': [
            {'id': 'scene-1', 'title': '场景一'},
          ],
        },
        'charactersByProject': {
          'project-a': [
            {
              'name': '柳溪',
              'linkedSceneIds': ['scene-1', 'scene-nonexistent'],
            },
          ],
        },
      });
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
      expect(
        result.warnings.any((e) => e.message.contains('scene-nonexistent')),
        isTrue,
      );
    });

    test('dangling scene id in worldNode linkedSceneIds produces warning', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-1',
            'title': '项目',
            'lastOpenedAtMs': 1,
          },
        ],
        'scenesByProject': {
          'project-a': [
            {'id': 'scene-1', 'title': '场景一'},
          ],
        },
        'worldNodesByProject': {
          'project-a': [
            {
              'title': '规则',
              'linkedSceneIds': ['scene-phantom'],
            },
          ],
        },
      });
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('invalid audit issue status produces warning', () {
      final result = validator.validateWorkspaceData({
        'projects': [
          {
            'id': 'project-a',
            'sceneId': 'scene-1',
            'title': '项目',
            'lastOpenedAtMs': 1,
          },
        ],
        'auditIssuesByProject': {
          'project-a': [
            {'title': '问题', 'status': 'garbage'},
          ],
        },
      });
      expect(result.isValid, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('errors list is unmodifiable', () {
      final result = ValidationResult.fail([
        const ValidationError(field: 'f', message: 'm'),
      ]);
      expect(() => (result.errors as List).add(const ValidationError(field: 'x', message: 'y')), throwsA(anything));
    });
  });
}
