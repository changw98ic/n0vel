import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage_io.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

void main() {
  test('real AI smoke requires explicit OLLAMA credentials only', () {
    expect(
      _resolveBaseUrl({
        'OPENAI_BASE_URL': 'https://should-not-be-used.example/v1',
      }, const {}),
      'https://ollama.com/v1',
    );
    expect(
      _resolveBaseUrl({
        'OLLAMA_BASE_URL': 'https://custom.ollama.example/v1',
        'OPENAI_BASE_URL': 'https://should-not-be-used.example/v1',
      }, const {}),
      'https://custom.ollama.example/v1',
    );
    expect(
      _resolveApiKey({'OPENAI_API_KEY': 'sk-should-not-be-used'}, const {}),
      '',
    );
    expect(
      _resolveApiKey({
        'OLLAMA_API_KEY': 'ollama-key',
        'OPENAI_API_KEY': 'sk-should-not-be-used',
      }, const {}),
      'ollama-key',
    );
  });

  test('real AI smoke loads local setting.json key-value config', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_real_ai_smoke_local_config_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/setting.json');
    await file.writeAsString('''
OLLAMA_API_KEY=ollama-local-key
OLLAMA_BASE_URL=https://ollama.com/v1
REAL_AI_MODEL=kimi-k2.6
''');

    final localConfig = _loadLocalSmokeConfig(file: file);
    expect(_resolveApiKey(const {}, localConfig), 'ollama-local-key');
    expect(_resolveBaseUrl(const {}, localConfig), 'https://ollama.com/v1');
    expect(_candidateModels(const {}, localConfig), ['kimi-k2.6']);
  });

  test('real AI smoke loads local setting.json json config', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_real_ai_smoke_json_config_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/setting.json');
    await file.writeAsString(
      jsonEncode({
        'providerName': 'Ollama Cloud',
        'baseUrl': 'https://ollama.com/v1',
        'model': 'kimi-k2.6',
        'apiKey': 'ollama-json-key',
      }),
    );

    final localConfig = _loadLocalSmokeConfig(file: file);
    expect(_resolveApiKey(const {}, localConfig), 'ollama-json-key');
    expect(_resolveBaseUrl(const {}, localConfig), 'https://ollama.com/v1');
    expect(_candidateModels(const {}, localConfig), ['kimi-k2.6']);
  });

  test('real AI smoke validation', () async {
    final environment = Platform.environment;
    final localConfig = _loadLocalSmokeConfig();
    final baseUrl = _resolveBaseUrl(environment, localConfig);
    final apiKey = _resolveApiKey(environment, localConfig);

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      fail('Missing OLLAMA_API_KEY in setting.json or the environment.');
    }

    final candidateModels = _candidateModels(environment, localConfig);
    final workDir = await Directory.systemTemp.createTemp(
      'novel_writer_real_ai_smoke_',
    );
    final settingsFile = File('${workDir.path}/settings.json');
    final telemetryDbPath = '${workDir.path}/telemetry.db';
    final logsDirectory = Directory('${workDir.path}/logs');

    final eventStorage = createTestAppEventLogStorage(
      sqlitePath: telemetryDbPath,
      logsDirectory: logsDirectory,
    );
    final eventLog = AppEventLog(
      storage: eventStorage,
      sessionId: 'real-ai-smoke',
    );
    final settingsStore = AppSettingsStore(
      storage: FileAppSettingsStorage(file: settingsFile),
      eventLog: eventLog,
    );
    addTearDown(settingsStore.dispose);

    AppLlmChatResult? completionResult;
    String? resolvedModel;
    String? lastFailure;

    for (final model in candidateModels) {
      await settingsStore.saveWithFeedback(
        providerName: 'Ollama Cloud',
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        timeout: const AppLlmTimeoutConfig.uniform(30000),
      );

      if (!settingsStore.canRunConnectionTest) {
        lastFailure =
            'Model $model not ready for connection test: ${settingsStore.feedback.message}';
        continue;
      }

      await settingsStore.testConnection(
        baseUrl: baseUrl,
        model: model,
        apiKey: apiKey,
        timeout: const AppLlmTimeoutConfig.uniform(30000),
      );

      if (settingsStore.connectionTestState.status !=
          AppSettingsConnectionTestStatus.success) {
        lastFailure =
            'Connection test failed for $model: ${settingsStore.connectionTestState.title} / ${settingsStore.connectionTestState.message}';
        continue;
      }

      completionResult = await settingsStore.requestAiCompletion(
        messages: const [AppLlmChatMessage(role: 'user', content: '请只回复 pong')],
      );
      resolvedModel = model;
      if (completionResult.succeeded) {
        break;
      }
      lastFailure =
          'Completion failed for $model: ${completionResult.failureKind} / ${completionResult.detail}';
    }

    expect(
      resolvedModel,
      isNotNull,
      reason:
          'No candidate model completed the real smoke request. Last failure: $lastFailure',
    );
    expect(
      completionResult,
      isNotNull,
      reason: 'No completion request was executed.',
    );
    expect(
      completionResult!.succeeded,
      isTrue,
      reason:
          'Real AI smoke request failed: ${completionResult.failureKind} / ${completionResult.detail}',
    );

    final persistedSettings = await FileAppSettingsStorage(
      file: settingsFile,
    ).load();
    expect(persistedSettings?['baseUrl'], baseUrl);
    expect(persistedSettings?['model'], resolvedModel);

    final telemetryRows = await _readTelemetryCount(telemetryDbPath);
    final jsonlCount = await _readJsonlCount(logsDirectory);
    expect(telemetryRows, greaterThanOrEqualTo(2));
    expect(jsonlCount, greaterThanOrEqualTo(2));

    stdout.writeln('Real AI smoke validation passed.');
    stdout.writeln('Base URL: $baseUrl');
    stdout.writeln('Resolved model: $resolvedModel');
    stdout.writeln(
      'Connection test: ${settingsStore.connectionTestState.message}',
    );
    stdout.writeln(
      'Response preview: ${_preview(completionResult.text ?? '', 120)}',
    );
    stdout.writeln('Temp settings: ${settingsFile.path}');
    stdout.writeln('Telemetry DB: $telemetryDbPath');
    stdout.writeln('JSONL logs: ${logsDirectory.path}');
    stdout.writeln('Telemetry rows: $telemetryRows');
    stdout.writeln('JSONL lines: $jsonlCount');
  });
}

Map<String, String> _loadLocalSmokeConfig({File? file}) {
  final configFile = file ?? File('setting.json');
  if (!configFile.existsSync()) {
    return const {};
  }

  final raw = configFile.readAsStringSync();
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    }
  } on FormatException {
    // Fall through to line-based parsing for local developer config files.
  }

  final config = <String, String>{};
  for (final line in const LineSplitter().convert(raw)) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
      continue;
    }
    final separatorIndex = trimmedLine.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }
    final key = trimmedLine.substring(0, separatorIndex).trim();
    final value = trimmedLine.substring(separatorIndex + 1).trim();
    if (key.isNotEmpty) {
      config[key] = value;
    }
  }
  return config;
}

String _resolveBaseUrl(
  Map<String, String> environment,
  Map<String, String> localConfig,
) {
  final explicit = (environment['OLLAMA_BASE_URL'] ?? '').trim();
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final local = _firstNonEmpty(localConfig, ['OLLAMA_BASE_URL', 'baseUrl']);
  if (local.isNotEmpty) {
    return local;
  }
  return 'https://ollama.com/v1';
}

String _resolveApiKey(
  Map<String, String> environment,
  Map<String, String> localConfig,
) {
  final explicit = (environment['OLLAMA_API_KEY'] ?? '').trim();
  if (explicit.isNotEmpty) {
    return explicit;
  }
  return _firstNonEmpty(localConfig, ['OLLAMA_API_KEY', 'apiKey']);
}

List<String> _candidateModels(
  Map<String, String> environment,
  Map<String, String> localConfig,
) {
  final candidateModels = <String>[
    if ((environment['REAL_AI_MODEL'] ?? '').trim().isNotEmpty)
      environment['REAL_AI_MODEL']!.trim(),
    if (_firstNonEmpty(localConfig, ['REAL_AI_MODEL', 'model']).isNotEmpty)
      _firstNonEmpty(localConfig, ['REAL_AI_MODEL', 'model']),
    'kimi-k2.6',
  ];
  final unique = <String>[];
  for (final model in candidateModels) {
    if (!unique.contains(model)) {
      unique.add(model);
    }
  }
  return unique;
}

String _firstNonEmpty(Map<String, String> values, List<String> keys) {
  for (final key in keys) {
    final value = (values[key] ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

Future<int> _readTelemetryCount(String dbPath) async {
  final process = await Process.run('/usr/bin/sqlite3', [
    dbPath,
    'SELECT COUNT(*) FROM app_event_log_entries;',
  ]);
  if (process.exitCode != 0) {
    return -1;
  }
  return int.tryParse(process.stdout.toString().trim()) ?? -1;
}

Future<int> _readJsonlCount(Directory logsDirectory) async {
  if (!await logsDirectory.exists()) {
    return 0;
  }
  var count = 0;
  await for (final entity in logsDirectory.list()) {
    if (entity is! File || !entity.path.endsWith('.jsonl')) {
      continue;
    }
    final lines = await entity.readAsLines();
    count += lines.where((line) => line.trim().isNotEmpty).length;
  }
  return count;
}

String _preview(String text, int maxLength) {
  final trimmed = text.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return '${trimmed.substring(0, maxLength)}...';
}
