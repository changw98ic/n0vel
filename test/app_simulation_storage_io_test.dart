import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/app/state/app_simulation_storage_io.dart';
import 'package:novel_writer/app/state/app_simulation_storage.dart';
import 'package:novel_writer/app/state/app_simulation_store.dart';
import 'test_support/fake_app_llm_client.dart';

void main() {
  test('sqlite simulation storage persists state payload', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_simulation_storage_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteAppSimulationStorage(
      dbPath: '${directory.path}/simulation.db',
    );

    final store = AppSimulationStore(storage: storage);
    addTearDown(store.dispose);

    store.startSuccessfulRun();
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final restoredStore = AppSimulationStore(storage: storage);
    addTearDown(restoredStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(restoredStore.snapshot.status, SimulationStatus.completed);
    expect(restoredStore.snapshot.messages, isNotEmpty);
    expect(restoredStore.snapshot.turnLabel, '第 05 回合');
  });

  test('sqlite simulation storage keeps prompt edits across restore', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_simulation_prompt_storage_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteAppSimulationStorage(
      dbPath: '${directory.path}/simulation.db',
    );

    final store = AppSimulationStore(storage: storage);
    addTearDown(store.dispose);

    store.startSuccessfulRun();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    store.updateParticipantPrompt(
      SimulationParticipant.liuXi,
      '先压低语气，再决定是否继续追问。',
    );

    final restoredStore = AppSimulationStore(storage: storage);
    addTearDown(restoredStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final liuXi = restoredStore.snapshot.participantSnapshot(
      SimulationParticipant.liuXi,
    );
    expect(liuXi.promptSummary, '先压低语气，再决定是否继续追问。');
  });

  test(
    'sqlite simulation storage writes normalized simulation tables',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_simulation_schema_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/simulation.db';
      final storage = SqliteAppSimulationStorage(dbPath: dbPath);

      final store = AppSimulationStore(storage: storage);
      addTearDown(store.dispose);

      store.startSuccessfulRun();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      store.updateParticipantPrompt(
        SimulationParticipant.liuXi,
        '先压低语气，再决定是否继续追问。',
      );

      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);

      final tableNames = database
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();

      expect(tableNames, contains('simulation_runs'));
      expect(tableNames, contains('simulation_participant_prompts'));
      expect(tableNames, contains('simulation_chat_messages'));
      expect(
        database
            .select('PRAGMA table_info(simulation_runs)')
            .map((row) => row['name'] as String),
        contains('run_mode'),
      );
      expect(
        database
            .select('PRAGMA table_info(simulation_chat_messages)')
            .map((row) => row['name'] as String),
        contains('message_kind'),
      );

      final runsCount =
          database
                  .select('SELECT COUNT(*) AS c FROM simulation_runs')
                  .first['c']
              as int;
      final promptsCount =
          database
                  .select(
                    'SELECT COUNT(*) AS c FROM simulation_participant_prompts',
                  )
                  .first['c']
              as int;
      final messagesCount =
          database
                  .select('SELECT COUNT(*) AS c FROM simulation_chat_messages')
                  .first['c']
              as int;

      expect(runsCount, 1);
      expect(promptsCount, greaterThanOrEqualTo(1));
      expect(messagesCount, greaterThanOrEqualTo(1));
    },
  );

  test(
    'real agent simulation calls provider for each role and persists output',
    () async {
      final storage = InMemoryAppSimulationStorage();
      final fakeClient = FakeAppLlmClient(
        responder: (request) {
          final system = request.messages.first.content;
          final role = system.contains('director')
              ? 'director'
              : system.contains('protagonist')
              ? 'protagonist'
              : 'antagonist';
          return AppLlmChatResult.success(
            text:
                '真实 provider 输出：$role · ${request.messages.last.content.length}',
            latencyMs: 12,
          );
        },
      );
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: fakeClient,
      );
      final store = AppSimulationStore(storage: storage);
      addTearDown(store.dispose);
      addTearDown(settingsStore.dispose);

      final result = await store.runRealAgentSession(
        settingsStore: settingsStore,
        sceneContext: '第三章场景：主角在码头对峙，对立角色隐藏关键证据。',
        authorGoal: '让模拟结果进入正文生成前的输入。',
      );

      expect(result.succeeded, isTrue);
      expect(fakeClient.requests, hasLength(6));
      expect(store.snapshot.status, SimulationStatus.completed);
      expect(store.snapshot.messages, hasLength(6));
      expect(
        store.snapshot.messages.map((message) => message.sender).toSet(),
        containsAll(<String>{'director', 'protagonist', 'antagonist'}),
      );
      expect(
        store.snapshot.messages.map((message) => message.body).join('\n'),
        isNot(contains('玻璃杯边缘的反光')),
      );

      final restoredStore = AppSimulationStore(storage: storage);
      addTearDown(restoredStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restoredStore.snapshot.status, SimulationStatus.completed);
      expect(restoredStore.snapshot.messages, hasLength(6));
      expect(restoredStore.snapshot.headline, contains('真实多 Agent'));
    },
  );

  test('preview monitor state is not persisted into sqlite storage', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_simulation_preview_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteAppSimulationStorage(
      dbPath: '${directory.path}/simulation.db',
    );

    final previewStore = AppSimulationStore.preview(SimulationStatus.completed);
    previewStore.updateParticipantPrompt(
      SimulationParticipant.liuXi,
      '先观察停顿，再决定追问顺序。',
    );
    previewStore.dispose();

    final restoredStore = AppSimulationStore(storage: storage);
    addTearDown(restoredStore.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(restoredStore.snapshot.status, SimulationStatus.none);
  });

  test(
    'malformed legacy simulation_state json is ignored during migration',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_simulation_legacy_migration_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final dbPath = '${directory.path}/simulation.db';
      final database = sqlite3.open(dbPath);
      addTearDown(database.dispose);
      database.execute('''
      CREATE TABLE simulation_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        payload_json TEXT NOT NULL,
        updated_at_ms INTEGER NOT NULL
      )
      ''');
      database.execute('''
      INSERT INTO simulation_state (id, payload_json, updated_at_ms)
      VALUES (1, '{bad-json', 0)
      ''');
      database.dispose();

      final storage = SqliteAppSimulationStorage(dbPath: dbPath);
      final restoredStore = AppSimulationStore(storage: storage);
      addTearDown(restoredStore.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restoredStore.snapshot.status, SimulationStatus.none);

      final migratedDb = sqlite3.open(dbPath);
      addTearDown(migratedDb.dispose);
      final tableNames = migratedDb
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      expect(tableNames, isNot(contains('simulation_state')));
    },
  );

  test('sqlite simulation storage isolates payloads by project id', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_simulation_project_scope_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = SqliteAppSimulationStorage(
      dbPath: '${directory.path}/simulation.db',
    );

    await storage.save({
      'template': 'completed',
      'promptOverrides': {'liuXi': '项目一提示'},
      'extraMessages': const [],
    }, projectId: 'project-a');
    await storage.save({
      'template': 'failed',
      'promptOverrides': {'liuXi': '项目二提示'},
      'extraMessages': const [],
    }, projectId: 'project-b');

    final projectA = await storage.load(projectId: 'project-a');
    final projectB = await storage.load(projectId: 'project-b');

    expect(projectA?['template'], 'completed');
    expect(
      (projectA?['promptOverrides'] as Map<Object?, Object?>)['liuXi'],
      '项目一提示',
    );
    expect(projectB?['template'], 'failed');
    expect(
      (projectB?['promptOverrides'] as Map<Object?, Object?>)['liuXi'],
      '项目二提示',
    );
  });

  test('simulation runs emit started and terminal lifecycle events', () async {
    final eventStorage = _RecordingAppEventLogStorage();
    final eventLog = AppEventLog(
      storage: eventStorage,
      sessionId: 'session-task4',
    );
    final store = AppSimulationStore(
      storage: InMemoryAppSimulationStorage(),
      eventLog: eventLog,
    );
    addTearDown(store.dispose);

    store.startSuccessfulRun();
    await Future<void>.delayed(const Duration(milliseconds: 900));

    expect(
      _entriesForAction(eventStorage.entries, 'simulation.run.started'),
      hasLength(1),
    );
    expect(
      _entriesForAction(eventStorage.entries, 'simulation.run.succeeded'),
      hasLength(1),
    );

    final started = _entriesForAction(
      eventStorage.entries,
      'simulation.run.started',
    ).single;
    final succeeded = _entriesForAction(
      eventStorage.entries,
      'simulation.run.succeeded',
    ).single;
    expect(started.correlationId, succeeded.correlationId);
    expect(started.projectId, store.activeProjectId);
    expect(succeeded.projectId, store.activeProjectId);
  });

  test(
    'simulation lifecycle logging stays best-effort when writes fail',
    () async {
      final store = AppSimulationStore(
        storage: InMemoryAppSimulationStorage(),
        eventLog: AppEventLog(
          storage: _ThrowingAppEventLogStorage(),
          sessionId: 'session-task4',
        ),
      );
      addTearDown(store.dispose);

      store.startFailureRun();
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(store.snapshot.status, SimulationStatus.failed);
    },
  );
}

List<AppEventLogEntry> _entriesForAction(
  List<AppEventLogEntry> entries,
  String action,
) {
  return entries.where((entry) => entry.action == action).toList();
}

class _RecordingAppEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}

class _ThrowingAppEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) {
    throw StateError('log write failed');
  }
}
