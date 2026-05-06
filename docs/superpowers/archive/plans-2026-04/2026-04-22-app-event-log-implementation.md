# App Event Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add a local structured event log that writes to both SQLite and JSONL, then wire it into settings, AI requests, import/export, and the key workbench UI actions needed for debugging.

**Architecture:** Introduce one shared event model and one app-scoped logging service. The service writes each event to a dedicated telemetry SQLite database plus a JSONL mirror, and all writes are best-effort so logging failures never break user workflows. Integrations should log around high-signal actions instead of spraying low-value UI noise.

**Tech Stack:** Flutter, ChangeNotifier stores, sqlite3, local file IO, widget tests, unit tests

---

### Task 1: Build the event model and dual-sink storage

**Files:**
- Create: `/Users/chengwen/dev/novel-wirter/lib/app/logging/app_event_log_types.dart`
- Create: `/Users/chengwen/dev/novel-wirter/lib/app/logging/app_event_log_storage.dart`
- Create: `/Users/chengwen/dev/novel-wirter/lib/app/logging/app_event_log_storage_io.dart`
- Create: `/Users/chengwen/dev/novel-wirter/lib/app/logging/app_event_log_storage_stub.dart`
- Create: `/Users/chengwen/dev/novel-wirter/lib/app/logging/app_event_log.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/state/app_authoring_storage_io_support.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/app_event_log_storage_io_test.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/app_event_log_test.dart`

- [x] **Step 1: Write the failing storage tests for SQLite, JSONL, and fallback paths**

```dart
test('event log storage writes one event to sqlite and jsonl', () async {
  final tempDir = await Directory.systemTemp.createTemp('novel_writer_event_log');
  final storage = createTestAppEventLogStorage(
    sqlitePath: '${tempDir.path}/telemetry.db',
    logsDirectory: Directory('${tempDir.path}/logs'),
  );

  await storage.write(
    AppEventLogEntry(
      eventId: 'evt-1',
      timestampMs: 1,
      level: AppEventLogLevel.info,
      category: AppEventLogCategory.ai,
      action: 'ai.chat.request',
      status: AppEventLogStatus.started,
      sessionId: 'session-1',
      correlationId: 'corr-1',
      projectId: 'project-a',
      sceneId: 'scene-a',
      message: 'Started AI request.',
      metadata: {'provider': 'OpenAI compatible'},
    ),
  );

  expect(await readLoggedEventsFromSqlite(...), hasLength(1));
  expect(await readJsonlLines(...), hasLength(1));
});

test('event log path helpers fall back when HOME is empty', () {
  expect(resolveTelemetryDbPath(homeOverride: ''), '.telemetry.db');
  expect(resolveTelemetryLogsDirectory(homeOverride: '').path, './logs');
});
```

- [x] **Step 2: Run the storage tests to verify they fail**

Run: `flutter test test/app_event_log_storage_io_test.dart test/app_event_log_test.dart`
Expected: FAIL with missing logging types/storage helpers.

- [x] **Step 3: Add the core event types and storage API**

```dart
enum AppEventLogLevel { debug, info, warn, error }
enum AppEventLogStatus { started, succeeded, failed, cancelled, warning }

class AppEventLogEntry {
  const AppEventLogEntry({
    required this.eventId,
    required this.timestampMs,
    required this.level,
    required this.category,
    required this.action,
    required this.status,
    required this.sessionId,
    required this.message,
    this.correlationId,
    this.projectId,
    this.sceneId,
    this.errorCode,
    this.errorDetail,
    this.metadata = const <String, Object?>{},
  });

  final String eventId;
  final int timestampMs;
  final AppEventLogLevel level;
  final AppEventLogCategory category;
  final String action;
  final AppEventLogStatus status;
  final String sessionId;
  final String? correlationId;
  final String? projectId;
  final String? sceneId;
  final String message;
  final String? errorCode;
  final String? errorDetail;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => { ... };
}

abstract class AppEventLogStorage {
  Future<void> write(AppEventLogEntry entry);
}
```

- [x] **Step 4: Implement the IO storage with SQLite primary and JSONL mirror**

```dart
class IoAppEventLogStorage implements AppEventLogStorage {
  IoAppEventLogStorage({
    String? sqlitePath,
    Directory? logsDirectory,
  }) : _sqlitePath = sqlitePath ?? resolveTelemetryDbPath(),
       _logsDirectory = logsDirectory ?? resolveTelemetryLogsDirectory();

  @override
  Future<void> write(AppEventLogEntry entry) async {
    Object? sqliteError;
    try {
      _writeToSqlite(entry);
    } catch (error) {
      sqliteError = error;
    }
    try {
      await _appendJsonl(entry);
    } catch (error) {
      sqliteError ??= error;
    }
    if (sqliteError != null) {
      assert(() {
        debugPrint('AppEventLog write failed: $sqliteError');
        return true;
      }());
    }
  }
}
```

- [x] **Step 5: Run the storage tests to verify they pass**

Run: `flutter test test/app_event_log_storage_io_test.dart test/app_event_log_test.dart`
Expected: PASS

- [x] **Step 6: Checkpoint**

No git commit in this workspace because `/Users/chengwen/dev/novel-wirter` has no `.git`. Mark this task complete in the plan and continue.

### Task 2: Add an app-scoped logging service and session context

**Files:**
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/logging/app_event_log.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/app.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/app_event_log_test.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/main_test.dart`

- [x] **Step 1: Write the failing service/scope tests**

```dart
test('app event log reuses one session id across writes', () async {
  final storage = InMemoryAppEventLogStorage();
  final log = AppEventLog(storage: storage, sessionId: 'session-1');

  await log.info(category: AppEventLogCategory.app, action: 'app.started', message: 'boot');
  await log.info(category: AppEventLogCategory.ui, action: 'ui.clicked', message: 'clicked');

  expect(storage.entries.map((e) => e.sessionId).toSet(), {'session-1'});
});

testWidgets('NovelWriterApp provides AppEventLogScope', (tester) async {
  await tester.pumpWidget(const NovelWriterApp());
  expect(find.byType(NovelWriterApp), findsOneWidget);
});
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/app_event_log_test.dart test/main_test.dart`
Expected: FAIL with missing `AppEventLog` service/scope.

- [x] **Step 3: Implement the service and scope**

```dart
class AppEventLog {
  AppEventLog({
    AppEventLogStorage? storage,
    String? sessionId,
  }) : _storage = storage ?? createDefaultAppEventLogStorage(),
       sessionId = sessionId ?? _generateSessionId();

  final AppEventLogStorage _storage;
  final String sessionId;

  Future<void> write(AppEventLogEntry entry) => _storage.write(entry);

  Future<void> info({
    required AppEventLogCategory category,
    required String action,
    required String message,
    String? correlationId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    return write(
      AppEventLogEntry(
        eventId: _generateEventId(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        level: AppEventLogLevel.info,
        category: category,
        action: action,
        status: AppEventLogStatus.succeeded,
        sessionId: sessionId,
        correlationId: correlationId,
        message: message,
        metadata: metadata,
      ),
    );
  }
}
```

- [x] **Step 4: Wire the service into `NovelWriterApp`**

```dart
late final AppEventLog _eventLog;

@override
void initState() {
  super.initState();
  _eventLog = AppEventLog();
  ...
}

@override
Widget build(BuildContext context) {
  return AppEventLogScope(
    log: _eventLog,
    child: ...
  );
}
```

- [x] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/app_event_log_test.dart test/main_test.dart`
Expected: PASS

- [x] **Step 6: Checkpoint**

No git commit in this workspace because `/Users/chengwen/dev/novel-wirter` has no `.git`. Mark this task complete in the plan and continue.

### Task 3: Instrument settings and AI request flows with structured logs

**Files:**
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/state/app_settings_store.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/workbench/presentation/workbench_shell_page.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/llm/app_llm_client_types.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/settings_persistence_test.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/workbench_shell_test.dart`

- [x] **Step 1: Write failing tests for settings and AI event emission**

```dart
test('settings save emits started and succeeded events', () async {
  final log = AppEventLog(storage: InMemoryAppEventLogStorage(), sessionId: 'session-1');
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: FakeAppLlmClient(),
    eventLog: log,
  );

  await store.saveWithFeedback(
    providerName: 'OpenAI 兼容服务',
    baseUrl: 'https://api.example.com/v1',
    model: 'gpt-5.4',
    apiKey: 'sk-test',
    timeoutMs: 30000,
  );

  expect(logEntriesFor(log, 'settings.save.started'), hasLength(1));
  expect(logEntriesFor(log, 'settings.save.succeeded'), hasLength(1));
});

testWidgets('AI generate emits request and review events', (tester) async {
  // Pump app with in-memory log, trigger AI generate, then verify entries.
});
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/settings_persistence_test.dart test/workbench_shell_test.dart`
Expected: FAIL with missing event log integration.

- [x] **Step 3: Inject the logging dependency into settings and workbench flows**

```dart
class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore({
    AppSettingsStorage? storage,
    AppLlmClient? llmClient,
    AppEventLog? eventLog,
  }) : _eventLog = eventLog ?? debugEventLogOverride ?? createDefaultAppEventLog();

  final AppEventLog _eventLog;
}
```

```dart
final correlationId = _eventLog.newCorrelationId('ai-request');
await _eventLog.write(... action: 'ui.ai.generate_clicked', status: AppEventLogStatus.started ...);
final result = await settingsStore.requestManualAi(...);
await _eventLog.write(... action: 'ai.chat.success' ...);
```

- [x] **Step 4: Redact sensitive fields and bound previews**

```dart
Map<String, Object?> _safeAiMetadata({
  required String provider,
  required String model,
  required String endpoint,
  required String prompt,
  String? response,
}) {
  return {
    'provider': provider,
    'model': model,
    'endpoint': endpoint,
    'promptLength': prompt.length,
    'promptPreview': _preview(prompt, 160),
    'responseLength': response?.length,
    'responsePreview': response == null ? null : _preview(response, 160),
  };
}
```

- [x] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/settings_persistence_test.dart test/workbench_shell_test.dart`
Expected: PASS

- [x] **Step 6: Checkpoint**

No git commit in this workspace because `/Users/chengwen/dev/novel-wirter` has no `.git`. Mark this task complete in the plan and continue.

### Task 4: Instrument import/export and simulation flows, then verify the full stack

**Files:**
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/import_export/data/project_transfer_service.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/app/state/app_simulation_store.dart`
- Modify: `/Users/chengwen/dev/novel-wirter/lib/features/workbench/presentation/workbench_shell_page.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/project_transfer_service_test.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/app_simulation_storage_io_test.dart`
- Test: `/Users/chengwen/dev/novel-wirter/test/app_llm_client_io_test.dart`

- [x] **Step 1: Write failing tests for import/export and simulation event emission**

```dart
test('project import emits started and failed events on invalid package', () async {
  final log = AppEventLog(storage: InMemoryAppEventLogStorage(), sessionId: 'session-1');
  final service = ProjectTransferService(..., eventLog: log);

  final result = await service.inspectPackage(File('/tmp/missing.zip'));

  expect(result.state, ProjectTransferState.invalidPackage);
  expect(logEntriesFor(log, 'project.import.inspect.failed'), hasLength(1));
});

test('simulation start emits run-started event', () {
  final log = AppEventLog(storage: InMemoryAppEventLogStorage(), sessionId: 'session-1');
  final store = AppSimulationStore(storage: InMemoryAppSimulationStorage(), eventLog: log);
  store.startSuccessfulRun();
  expect(logEntriesFor(log, 'simulation.run.started'), hasLength(1));
});
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/project_transfer_service_test.dart test/app_simulation_storage_io_test.dart`
Expected: FAIL with missing import/export/simulation event log hooks.

- [x] **Step 3: Instrument the service and simulation flows**

```dart
class ProjectTransferService {
  ProjectTransferService({
    Directory? exportsDirectory,
    Directory? importsDirectory,
    String zipExecutable = '/usr/bin/zip',
    String unzipExecutable = '/usr/bin/unzip',
    AppEventLog? eventLog,
  }) : _eventLog = eventLog ?? createDefaultAppEventLog();

  final AppEventLog _eventLog;
}
```

```dart
await _eventLog.write(... action: 'project.export.started' ...);
await _eventLog.write(... action: 'project.export.succeeded' ...);
await _eventLog.write(... action: 'project.import.failed' ...);
```

```dart
void startSuccessfulRun() {
  _eventLog.write(... action: 'simulation.run.started' ...);
  ...
}
```

- [x] **Step 4: Run targeted verification**

Run: `flutter test test/project_transfer_service_test.dart test/app_simulation_storage_io_test.dart test/app_llm_client_io_test.dart`
Expected: PASS

- [x] **Step 5: Run full verification**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test --coverage`
Expected: PASS with coverage regenerated and no regressions.

- [x] **Step 6: Checkpoint**

No git commit in this workspace because `/Users/chengwen/dev/novel-wirter` has no `.git`. Record final verification evidence in the implementation handoff.

## Self-Review

### Spec coverage

- Event model: covered by Task 1
- SQLite + JSONL dual sink: covered by Task 1
- App session id and shared logging service: covered by Task 2
- Settings and AI request logging: covered by Task 3
- Workbench UI actions: covered by Task 3 and Task 4
- Import/export and simulation logging: covered by Task 4
- Privacy and redaction: covered by Task 3
- Best-effort failure semantics: covered by Task 1 and Task 4

No spec gaps found.

### Placeholder scan

- No `TODO`, `TBD`, or “handle appropriately” placeholders remain.
- Each task lists exact files and verification commands.

### Type consistency

- The plan consistently uses `AppEventLog`, `AppEventLogEntry`, `AppEventLogStorage`, `sessionId`, and `correlationId`.
- The same dual-sink storage shape is referenced in all tasks.

### Notes

- This workspace currently has no `.git`, so commit steps are intentionally replaced with explicit checkpoints.
