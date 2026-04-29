import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'app_authoring_storage_io_support.dart';
import 'app_workspace_storage.dart';
import 'workspace_storage_io_helpers.dart';
import 'workspace_storage_schema.dart';

class SqliteAppWorkspaceStorage implements AppWorkspaceStorage {
  SqliteAppWorkspaceStorage({String? dbPath})
    : _dbPath = dbPath ?? resolveAuthoringDbPath();

  final String _dbPath;

  @override
  Future<Map<String, Object?>?> load() async {
    final database = _openDatabase();
    try {
      final projects = database.select(
        '''
        SELECT id, scene_id, title, genre, summary, recent_location, last_opened_at_ms
        FROM workspace_projects
        WHERE scope_key = ?
        ORDER BY position_no ASC
        ''',
        [_scopeKey],
      );
      final characters = database.select(
        '''
        SELECT project_id, name, role, note, need_text, summary
        FROM workspace_characters
        WHERE scope_key = ?
        ORDER BY project_id ASC, position_no ASC
        ''',
        [_scopeKey],
      );
      final worldNodes = database.select(
        '''
        SELECT project_id, title, location, type, detail, summary
        FROM workspace_world_nodes
        WHERE scope_key = ?
        ORDER BY project_id ASC, position_no ASC
        ''',
        [_scopeKey],
      );
      final auditIssues = database.select(
        '''
        SELECT project_id, title, evidence, target
        FROM workspace_audit_issues
        WHERE scope_key = ?
        ORDER BY project_id ASC, position_no ASC
        ''',
        [_scopeKey],
      );
      final scenes = database.select(
        '''
        SELECT project_id, position_no, id, chapter_label, title, summary
        FROM workspace_scenes
        WHERE scope_key = ?
        ORDER BY project_id ASC, position_no ASC
        ''',
        [_scopeKey],
      );
      final preferences = database.select(
        '''
        SELECT preference_key, preference_value
        FROM workspace_preferences
        WHERE scope_key = ?
        ''',
        [_scopeKey],
      );
      final projectPreferences = database.select(
        '''
        SELECT project_id, preference_key, preference_value
        FROM workspace_project_preferences
        WHERE scope_key = ?
        ORDER BY project_id ASC
        ''',
        [_scopeKey],
      );

      if (projects.isEmpty &&
          characters.isEmpty &&
          scenes.isEmpty &&
          worldNodes.isEmpty &&
          auditIssues.isEmpty &&
          preferences.isEmpty &&
          projectPreferences.isEmpty) {
        return null;
      }

      final preferenceMap = <String, String>{
        for (final row in preferences)
          row['preference_key'] as String: row['preference_value'] as String,
      };

      return {
        'projects': [
          for (final row in projects)
            {
              'id': row['id'] as String,
              'sceneId': row['scene_id'] as String,
              'title': row['title'] as String,
              'genre': row['genre'] as String,
              'summary': row['summary'] as String,
              'recentLocation': row['recent_location'] as String,
              'lastOpenedAtMs': row['last_opened_at_ms'] as int,
            },
        ],
        'charactersByProject': WorkspaceStorageHelpers.groupRowsByProject(
          rows: characters,
          rowMapper: (row) => {
            'name': row['name'] as String,
            'role': row['role'] as String,
            'note': row['note'] as String,
            'need': row['need_text'] as String,
            'summary': row['summary'] as String,
          },
        ),
        'scenesByProject': WorkspaceStorageHelpers.groupRowsByProject(
          rows: scenes,
          rowMapper: (row) => {
            'id': row['id'] as String,
            'chapterLabel': row['chapter_label'] as String,
            'title': row['title'] as String,
            'summary': row['summary'] as String,
          },
        ),
        'worldNodesByProject': WorkspaceStorageHelpers.groupRowsByProject(
          rows: worldNodes,
          rowMapper: (row) => {
            'title': row['title'] as String,
            'location': row['location'] as String,
            'type': row['type'] as String,
            'detail': row['detail'] as String,
            'summary': row['summary'] as String,
          },
        ),
        'auditIssuesByProject': WorkspaceStorageHelpers.groupRowsByProject(
          rows: auditIssues,
          rowMapper: (row) => {
            'title': row['title'] as String,
            'evidence': row['evidence'] as String,
            'target': row['target'] as String,
          },
        ),
        'projectStyles': WorkspaceStorageHelpers.groupProjectPreferences(
          rows: projectPreferences,
          keys: const {
            'style_input_mode',
            'style_intensity',
            'style_binding_feedback',
          },
          rename: const {
            'style_input_mode': 'styleInputMode',
            'style_intensity': 'styleIntensity',
            'style_binding_feedback': 'styleBindingFeedback',
          },
        ),
        'projectAuditStates': WorkspaceStorageHelpers.groupProjectPreferences(
          rows: projectPreferences,
          keys: const {'selected_audit_issue_index', 'audit_action_feedback'},
          rename: const {
            'selected_audit_issue_index': 'selectedAuditIssueIndex',
            'audit_action_feedback': 'auditActionFeedback',
          },
        ),
        'projectTransferState': preferenceMap['project_transfer_state'],
        'currentProjectId': preferenceMap['current_project_id'],
      };
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> save(Map<String, Object?> data) async {
    final database = _openDatabase();
    try {
      final projects = (data['projects'] as List<Object?>?) ?? const [];
      final charactersByProject =
          (data['charactersByProject'] as Map<Object?, Object?>?) ?? const {};
      final worldNodesByProject =
          (data['worldNodesByProject'] as Map<Object?, Object?>?) ?? const {};
      final scenesByProject =
          (data['scenesByProject'] as Map<Object?, Object?>?) ?? const {};
      final auditIssuesByProject =
          (data['auditIssuesByProject'] as Map<Object?, Object?>?) ?? const {};
      final projectStyles =
          (data['projectStyles'] as Map<Object?, Object?>?) ?? const {};
      final projectAuditStates =
          (data['projectAuditStates'] as Map<Object?, Object?>?) ?? const {};
      final preferences = <String, String>{
        'project_transfer_state':
            data['projectTransferState']?.toString() ?? '',
        'current_project_id': data['currentProjectId']?.toString() ?? '',
      };

      runInTransaction(database, () {
        database.execute('DELETE FROM workspace_projects WHERE scope_key = ?', [
          _scopeKey,
        ]);
        database.execute(
          'DELETE FROM workspace_characters WHERE scope_key = ?',
          [_scopeKey],
        );
        database.execute(
          'DELETE FROM workspace_world_nodes WHERE scope_key = ?',
          [_scopeKey],
        );
        database.execute('DELETE FROM workspace_scenes WHERE scope_key = ?', [
          _scopeKey,
        ]);
        database.execute(
          'DELETE FROM workspace_audit_issues WHERE scope_key = ?',
          [_scopeKey],
        );
        database.execute(
          'DELETE FROM workspace_preferences WHERE scope_key = ?',
          [_scopeKey],
        );
        database.execute(
          'DELETE FROM workspace_project_preferences WHERE scope_key = ?',
          [_scopeKey],
        );

        WorkspaceStorageHelpers.insertProjectRows(
          database,
          _scopeKey,
          projects,
        );
        WorkspaceStorageHelpers.insertProjectScopedRows(
          database: database,
          scopeKey: _scopeKey,
          tableName: 'workspace_characters',
          rowsByProject: charactersByProject,
          columnNames: const ['name', 'role', 'note', 'need_text', 'summary'],
          valuesBuilder: (row) => [
            row['name']?.toString() ?? '',
            row['role']?.toString() ?? '',
            row['note']?.toString() ?? '',
            row['need']?.toString() ?? '',
            row['summary']?.toString() ?? '',
          ],
        );
        WorkspaceStorageHelpers.insertProjectScopedRows(
          database: database,
          scopeKey: _scopeKey,
          tableName: 'workspace_scenes',
          rowsByProject: scenesByProject,
          columnNames: const ['id', 'chapter_label', 'title', 'summary'],
          valuesBuilder: (row) => [
            row['id']?.toString() ?? '',
            row['chapterLabel']?.toString() ?? '',
            row['title']?.toString() ?? '',
            row['summary']?.toString() ?? '',
          ],
        );
        WorkspaceStorageHelpers.insertProjectScopedRows(
          database: database,
          scopeKey: _scopeKey,
          tableName: 'workspace_world_nodes',
          rowsByProject: worldNodesByProject,
          columnNames: const ['title', 'location', 'type', 'detail', 'summary'],
          valuesBuilder: (row) => [
            row['title']?.toString() ?? '',
            row['location']?.toString() ?? '',
            row['type']?.toString() ?? '',
            row['detail']?.toString() ?? '',
            row['summary']?.toString() ?? '',
          ],
        );
        WorkspaceStorageHelpers.insertProjectScopedRows(
          database: database,
          scopeKey: _scopeKey,
          tableName: 'workspace_audit_issues',
          rowsByProject: auditIssuesByProject,
          columnNames: const ['title', 'evidence', 'target'],
          valuesBuilder: (row) => [
            row['title']?.toString() ?? '',
            row['evidence']?.toString() ?? '',
            row['target']?.toString() ?? '',
          ],
        );

        final prefStmt = database.prepare('''
          INSERT INTO workspace_preferences (
            scope_key, preference_key, preference_value
          ) VALUES (?, ?, ?)
          ''');
        try {
          for (final entry in preferences.entries) {
            prefStmt.execute([_scopeKey, entry.key, entry.value]);
          }
        } finally {
          prefStmt.dispose();
        }

        WorkspaceStorageHelpers.insertProjectPreferences(
          database: database,
          scopeKey: _scopeKey,
          preferencesByProject: projectStyles,
          rename: const {
            'styleInputMode': 'style_input_mode',
            'styleIntensity': 'style_intensity',
            'styleBindingFeedback': 'style_binding_feedback',
          },
        );
        WorkspaceStorageHelpers.insertProjectPreferences(
          database: database,
          scopeKey: _scopeKey,
          preferencesByProject: projectAuditStates,
          rename: const {
            'selectedAuditIssueIndex': 'selected_audit_issue_index',
            'auditActionFeedback': 'audit_action_feedback',
          },
        );
      });
    } finally {
      database.dispose();
    }
  }

  @override
  Future<void> clear() async {
    final database = _openDatabase();
    try {
      database.execute('DELETE FROM workspace_projects WHERE scope_key = ?', [
        _scopeKey,
      ]);
      database.execute('DELETE FROM workspace_characters WHERE scope_key = ?', [
        _scopeKey,
      ]);
      database.execute(
        'DELETE FROM workspace_world_nodes WHERE scope_key = ?',
        [_scopeKey],
      );
      database.execute('DELETE FROM workspace_scenes WHERE scope_key = ?', [
        _scopeKey,
      ]);
      database.execute(
        'DELETE FROM workspace_audit_issues WHERE scope_key = ?',
        [_scopeKey],
      );
      database.execute(
        'DELETE FROM workspace_preferences WHERE scope_key = ?',
        [_scopeKey],
      );
      database.execute(
        'DELETE FROM workspace_project_preferences WHERE scope_key = ?',
        [_scopeKey],
      );
    } finally {
      database.dispose();
    }
  }

  sqlite3.Database _openDatabase() {
    final database = openAuthoringDatabase(_dbPath);
    WorkspaceSchema.migrateLegacyProjectSchema(database, _scopeKey);
    WorkspaceSchema.migrateLegacyScopedTables(database, _scopeKey);
    WorkspaceSchema.ensureSchema(database);
    WorkspaceSchema.migrateLegacyProjectPreferences(database, _scopeKey);
    return database;
  }

  static const String _scopeKey = 'workspace-default';
}

AppWorkspaceStorage createAppWorkspaceStorage() => SqliteAppWorkspaceStorage();
