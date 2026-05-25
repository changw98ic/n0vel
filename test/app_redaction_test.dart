import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/logging/app_redaction.dart';

void main() {
  group('SensitiveDataRedactionPolicy', () {
    test('redacts common LLM credentials from free-form strings', () {
      const policy = SensitiveDataRedactionPolicy.defaults;

      final redacted = policy.redactString(
        'Authorization: Bearer sk-live-secret, '
        'x-api-key=anthropic-secret, '
        'url=https://api.example.com/v1?api_key=query-secret&model=gpt',
      );

      expect(redacted, contains('Authorization: Bearer [REDACTED]'));
      expect(redacted, contains('x-api-key=[REDACTED]'));
      expect(redacted, contains('api_key=[REDACTED]'));
      expect(redacted, isNot(contains('sk-live-secret')));
      expect(redacted, isNot(contains('anthropic-secret')));
      expect(redacted, isNot(contains('query-secret')));
      expect(redacted, contains('model=gpt'));
    });

    test('redacts nested metadata by sensitive key names', () {
      const policy = SensitiveDataRedactionPolicy.defaults;

      final redacted =
          policy.redactValue({
                'model': 'gpt-5.4',
                'headers': {
                  'Authorization': 'Bearer sk-header-secret',
                  'x-api-key': 'x-secret',
                  'content-type': 'application/json',
                },
                'providerProfiles': [
                  {'id': 'p1', 'apiKey': 'profile-secret'},
                  {
                    'id': 'p2',
                    'baseUrl': 'https://example.com?token=url-secret',
                  },
                ],
              })
              as Map<String, Object?>;

      expect(redacted['model'], 'gpt-5.4');
      final headers = redacted['headers'] as Map<String, Object?>;
      expect(headers['Authorization'], '[REDACTED]');
      expect(headers['x-api-key'], '[REDACTED]');
      expect(headers['content-type'], 'application/json');
      final profiles = redacted['providerProfiles'] as List<Object?>;
      expect(profiles.first, {'id': 'p1', 'apiKey': '[REDACTED]'});
      expect(profiles.last, {
        'id': 'p2',
        'baseUrl': 'https://example.com?token=[REDACTED]',
      });
    });

    test('can be disabled for explicit diagnostic snapshots', () {
      const policy = SensitiveDataRedactionPolicy(enabled: false);

      expect(
        policy.redactString('Authorization: Bearer sk-live-secret'),
        'Authorization: Bearer sk-live-secret',
      );
    });
  });

  test('AppEventLog redacts durable event fields before storage', () async {
    final storage = _RecordingAppEventLogStorage();
    final log = AppEventLog(storage: storage, sessionId: 'session-1');

    await log.log(
      level: AppEventLogLevel.warn,
      category: AppEventLogCategory.ai,
      action: 'llm.failed',
      status: AppEventLogStatus.failed,
      message: 'POST https://api.example.com/v1?api_key=query-secret',
      errorDetail: 'Authorization: Bearer sk-error-secret',
      metadata: {
        'apiKey': 'metadata-secret',
        'headers': {'x-api-key': 'header-secret'},
      },
    );

    final entry = storage.entries.single;
    expect(entry.message, 'POST https://api.example.com/v1?api_key=[REDACTED]');
    expect(entry.errorDetail, 'Authorization: Bearer [REDACTED]');
    expect(entry.metadata['apiKey'], '[REDACTED]');
    expect(entry.metadata['headers'], {'x-api-key': '[REDACTED]'});
  });

  test('AppEventLog can use an explicit no-redaction policy', () async {
    final storage = _RecordingAppEventLogStorage();
    final log = AppEventLog(
      storage: storage,
      sessionId: 'session-1',
      redactionPolicy: const SensitiveDataRedactionPolicy(enabled: false),
    );

    await log.info(
      category: AppEventLogCategory.ai,
      action: 'llm.request',
      message: 'Authorization: Bearer sk-test-visible',
    );

    expect(storage.entries.single.message, contains('sk-test-visible'));
  });

  test('event log storage redacts direct writes to sqlite and jsonl', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_redaction_storage_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final storage = createTestAppEventLogStorage(
      sqlitePath: '${directory.path}/telemetry.db',
      logsDirectory: Directory('${directory.path}/logs'),
    );

    await storage.write(
      AppEventLogEntry(
        eventId: 'evt-redacted',
        timestampMs: DateTime.utc(2026, 5, 25, 12).millisecondsSinceEpoch,
        level: AppEventLogLevel.error,
        category: AppEventLogCategory.ai,
        action: 'llm.request.failed',
        status: AppEventLogStatus.failed,
        sessionId: 'session-1',
        message: 'Authorization: Bearer sk-storage-secret',
        metadata: {'apiKey': 'storage-secret'},
      ),
    );

    final db = sqlite3.open('${directory.path}/telemetry.db');
    addTearDown(db.dispose);
    final row = db
        .select('SELECT message, metadata_json FROM app_event_log_entries')
        .single;
    expect(row['message'], 'Authorization: Bearer [REDACTED]');
    expect(jsonDecode(row['metadata_json'] as String), {
      'apiKey': '[REDACTED]',
    });

    final jsonlFile = File('${directory.path}/logs/2026-05-25.jsonl');
    final jsonl =
        jsonDecode(await jsonlFile.readAsString()) as Map<String, Object?>;
    expect(jsonl['message'], 'Authorization: Bearer [REDACTED]');
    expect(jsonl['metadata'], {'apiKey': '[REDACTED]'});
  });

  test('LLM call traces redact failure detail and metadata', () {
    final entry = AppLlmCallTraceEntry.fromRequestResult(
      request: const AppLlmChatRequest(
        baseUrl: 'https://api.example.com/v1?api_key=query-secret',
        apiKey: 'sk-request-secret',
        model: 'gpt-5.4',
        messages: [AppLlmChatMessage(role: 'user', content: 'hello')],
      ),
      result: const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.unauthorized,
        detail: 'Authorization: Bearer sk-result-secret',
      ),
      traceName: 'test_trace',
      metadata: const {
        'apiKey': 'trace-secret',
        'headers': {'Authorization': 'Bearer sk-trace-header'},
      },
    );

    expect(entry.host, 'api.example.com');
    expect(entry.errorDetail, 'Authorization: Bearer [REDACTED]');
    expect(entry.metadata['apiKey'], '[REDACTED]');
    expect(entry.metadata['headers'], {'Authorization': '[REDACTED]'});
  });
}

class _RecordingAppEventLogStorage implements AppEventLogStorage {
  final List<AppEventLogEntry> entries = <AppEventLogEntry>[];

  @override
  Future<void> write(AppEventLogEntry entry) async {
    entries.add(entry);
  }
}
