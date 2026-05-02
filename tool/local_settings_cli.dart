import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/state/local_settings_file.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final file = File(_optionValue(args, '--file') ?? 'setting.json');
  switch (args.first) {
    case 'write-mimo':
      await _writeMimo(file);
      return;
    case 'write-zhipu':
      await _writeZhipu(file);
      return;
    case 'write-routed':
      await _writeRouted(file);
      return;
    case 'decrypt':
      await _decrypt(file, showSecrets: args.contains('--show-secrets'));
      return;
    default:
      stderr.writeln('Unknown command: ${args.first}');
      _printUsage();
      exitCode = 64;
  }
}

Future<void> _writeMimo(File file) async {
  final apiKey = Platform.environment['MIMO_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('MIMO_API_KEY environment variable is required.');
    exitCode = 64;
    return;
  }

  await saveEncryptedLocalSettingsFile(
    file: file,
    values: {
      'providerName': 'Xiaomi MiMo',
      'baseUrl': 'https://token-plan-cn.xiaomimimo.com/v1',
      'model': 'mimo-v2.5-pro',
      'apiKey': apiKey,
      'maxTokens': 0,
      'MIMO_API_KEY': apiKey,
      'MIMO_BASE_URL': 'https://token-plan-cn.xiaomimimo.com/v1',
      'MIMO_MODEL': 'mimo-v2.5-pro',
      'REAL_AI_MAX_TOKENS': '0',
      'REAL_AI_MODEL': 'mimo-v2.5-pro',
      'REAL_AI_TIMEOUT_MS': '180000',
      'REAL_AI_MAX_CONCURRENT_REQUESTS': '3',
    },
  );
  stdout.writeln('Encrypted MiMo settings written to ${file.path}.');
}

Future<void> _writeZhipu(File file) async {
  final apiKey = Platform.environment['ZHIPU_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('ZHIPU_API_KEY environment variable is required.');
    exitCode = 64;
    return;
  }

  const baseUrl = 'https://open.bigmodel.cn/api/paas/v4';
  const model = 'glm-5.1';
  await saveEncryptedLocalSettingsFile(
    file: file,
    values: {
      'providerName': '智谱 GLM',
      'baseUrl': baseUrl,
      'model': model,
      'apiKey': apiKey,
      'maxTokens': 0,
      'ZHIPU_API_KEY': apiKey,
      'ZHIPU_BASE_URL': baseUrl,
      'ZHIPU_MODEL': model,
      'REAL_AI_MAX_TOKENS': '0',
      'REAL_AI_MODEL': model,
      'REAL_AI_TIMEOUT_MS': '180000',
      'REAL_AI_MAX_CONCURRENT_REQUESTS': '3',
    },
  );
  stdout.writeln('Encrypted Zhipu settings written to ${file.path}.');
}

Future<void> _writeRouted(File file) async {
  final existing = await loadLocalSettingsFile(file: file);
  final zhipuKey = _firstNonEmpty([
    Platform.environment['ZHIPU_API_KEY'],
    existing['ZHIPU_API_KEY'],
    existing['apiKey'],
  ]);
  if (zhipuKey.isEmpty) {
    stderr.writeln(
      'ZHIPU_API_KEY environment variable or existing setting.json key is required.',
    );
    exitCode = 64;
    return;
  }

  final mimoKey = _firstNonEmpty([
    Platform.environment['MIMO_API_KEY'],
    existing['MIMO_API_KEY'],
  ]);
  final ollamaKey = _firstNonEmpty([
    Platform.environment['OLLAMA_API_KEY'],
    existing['OLLAMA_API_KEY'],
  ]);

  const zhipuBaseUrl = 'https://open.bigmodel.cn/api/paas/v4';
  const zhipuModel = 'glm-5.1';
  const mimoBaseUrl = 'https://token-plan-cn.xiaomimimo.com/v1';
  const mimoModel = 'mimo-v2.5-pro';
  const ollamaBaseUrl = 'https://ollama.com/v1';
  const ollamaModel = 'kimi-k2.6';

  await saveEncryptedLocalSettingsFile(
    file: file,
    values: {
      'providerName': '智谱 GLM',
      'baseUrl': zhipuBaseUrl,
      'model': zhipuModel,
      'apiKey': zhipuKey,
      'maxTokens': 0,
      'ZHIPU_API_KEY': zhipuKey,
      'ZHIPU_BASE_URL': zhipuBaseUrl,
      'ZHIPU_MODEL': zhipuModel,
      if (mimoKey.isNotEmpty) 'MIMO_API_KEY': mimoKey,
      'MIMO_BASE_URL': mimoBaseUrl,
      'MIMO_MODEL': mimoModel,
      if (ollamaKey.isNotEmpty) 'OLLAMA_API_KEY': ollamaKey,
      'OLLAMA_BASE_URL': ollamaBaseUrl,
      'OLLAMA_MODEL': ollamaModel,
      'REAL_AI_MAX_TOKENS': '0',
      'REAL_AI_MODEL': zhipuModel,
      'REAL_AI_TIMEOUT_MS': '180000',
      'REAL_AI_MAX_CONCURRENT_REQUESTS': '3',
      'providerProfiles': [
        {
          'id': 'ollama-kimi',
          'providerName': 'Ollama Cloud',
          'baseUrl': ollamaBaseUrl,
          'model': ollamaModel,
          'apiKey': ollamaKey,
        },
        {
          'id': 'mimo',
          'providerName': 'Xiaomi MiMo',
          'baseUrl': mimoBaseUrl,
          'model': mimoModel,
          'apiKey': mimoKey,
        },
      ],
      'requestProviderRoutes': [
        {
          'traceNamePattern': 'scene_director_polish',
          'providerProfileId': 'ollama-kimi',
        },
        {
          'traceNamePattern': 'scene_roleplay_turn',
          'providerProfileId': 'ollama-kimi',
        },
        {
          'traceNamePattern': 'scene_roleplay_arbitrate',
          'providerProfileId': 'ollama-kimi',
        },
        {'traceNamePattern': 'scene_beat_resolve', 'providerProfileId': 'mimo'},
        {'traceNamePattern': 'scene_editorial', 'providerProfileId': 'mimo'},
        {'traceNamePattern': 'language_polish', 'providerProfileId': 'mimo'},
        {
          'traceNamePattern': 'scene_combined_review',
          'providerProfileId': 'mimo',
        },
        {'traceNamePattern': 'scene_review_*', 'providerProfileId': 'mimo'},
        {
          'traceNamePattern': 'scene_quality_scoring',
          'providerProfileId': 'mimo',
        },
      ],
    },
  );
  stdout.writeln('Encrypted routed provider settings written to ${file.path}.');
  if (ollamaKey.isEmpty) {
    stdout.writeln(
      'OLLAMA_API_KEY is missing; short generation routes will fall back to the default provider until it is added.',
    );
  }
}

Future<void> _decrypt(File file, {required bool showSecrets}) async {
  final values = await loadLocalSettingsObjectFile(file: file);
  final printable = showSecrets ? values : _redactSecrets(values);
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(printable));
}

Map<String, Object?> _redactSecrets(Map<String, Object?> values) {
  return values.map((key, value) {
    final lower = key.toLowerCase();
    if (lower.contains('key') || lower.contains('token')) {
      return MapEntry(key, _previewSecret(value?.toString() ?? ''));
    }
    return MapEntry(key, _redactNested(value));
  });
}

Object? _redactNested(Object? value) {
  if (value is Map) {
    return value.map((key, child) {
      final normalizedKey = key.toString();
      final lower = normalizedKey.toLowerCase();
      if (lower.contains('key') || lower.contains('token')) {
        return MapEntry(normalizedKey, _previewSecret(child?.toString() ?? ''));
      }
      return MapEntry(normalizedKey, _redactNested(child));
    });
  }
  if (value is List) {
    return [for (final item in value) _redactNested(item)];
  }
  return value;
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

String _previewSecret(String value) {
  if (value.length <= 8) {
    return value.isEmpty ? '' : '<redacted>';
  }
  return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
}

String? _optionValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

void _printUsage() {
  stdout.writeln('''
Usage:
  dart run tool/local_settings_cli.dart write-mimo [--file setting.json]
  dart run tool/local_settings_cli.dart write-zhipu [--file setting.json]
  dart run tool/local_settings_cli.dart write-routed [--file setting.json]
  dart run tool/local_settings_cli.dart decrypt [--file setting.json] [--show-secrets]

write-mimo reads MIMO_API_KEY from the environment and writes an AES-GCM encrypted setting.json.
write-zhipu reads ZHIPU_API_KEY from the environment and writes an AES-GCM encrypted setting.json.
write-routed writes Zhipu default routing plus Ollama Kimi and MiMo provider profiles; OLLAMA_API_KEY and MIMO_API_KEY are optional but required for their routes to activate.
decrypt prints decrypted values; secrets are redacted unless --show-secrets is present.
''');
}
