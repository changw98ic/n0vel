import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_io.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/state/local_settings_file.dart';

Future<void> main(List<String> args) async {
  final file = File(args.isEmpty ? 'setting.json' : args.first);
  final settings = await loadLocalSettingsObjectFile(file: file);
  if (settings.isEmpty) {
    stderr.writeln('No settings found at ${file.path}.');
    exitCode = 64;
    return;
  }

  final defaultProfile = _ProviderProfile.fromSettings(settings);
  final profiles = <String, _ProviderProfile>{
    for (final profile in _parseProviderProfiles(settings)) profile.id: profile,
  };
  final routes = _parseProviderRoutes(settings);
  final client = createAppLlmClient();

  final checks = [
    _SmokeCheck(traceName: 'scene_director_polish', expectedModel: 'kimi-k2.6'),
    _SmokeCheck(traceName: 'scene_roleplay_turn', expectedModel: 'kimi-k2.6'),
    _SmokeCheck(
      traceName: 'scene_roleplay_arbitrate',
      expectedModel: 'kimi-k2.6',
    ),
    _SmokeCheck(
      traceName: 'scene_beat_resolve',
      expectedModel: 'mimo-v2.5-pro',
    ),
    _SmokeCheck(traceName: 'scene_editorial', expectedModel: 'mimo-v2.5-pro'),
    _SmokeCheck(traceName: 'language_polish', expectedModel: 'mimo-v2.5-pro'),
    _SmokeCheck(
      traceName: 'scene_combined_review',
      expectedModel: 'mimo-v2.5-pro',
    ),
    _SmokeCheck(
      traceName: 'scene_review_smoke',
      expectedModel: 'mimo-v2.5-pro',
    ),
    _SmokeCheck(
      traceName: 'scene_quality_scoring',
      expectedModel: 'mimo-v2.5-pro',
    ),
    _SmokeCheck(traceName: 'manual_smoke', expectedModel: 'glm-5.1'),
  ];

  for (final check in checks) {
    final profile = _resolveProfile(
      traceName: check.traceName,
      defaultProfile: defaultProfile,
      profiles: profiles,
      routes: routes,
    );
    final result = await _chat(client, profile);
    final status = result.succeeded ? 'ok' : 'failed';
    stdout.writeln(
      '${check.traceName}: $status model=${profile.model} '
      'host=${profile.host}',
    );
    if (profile.model != check.expectedModel || !result.succeeded) {
      stderr.writeln(
        'Expected ${check.expectedModel}, got ${profile.model}; '
        'failure=${result.failureKind?.name ?? "none"} ${result.detail ?? ""}',
      );
      exitCode = 1;
      return;
    }
  }
}

Future<AppLlmChatResult> _chat(AppLlmClient client, _ProviderProfile profile) {
  return client.chat(
    AppLlmChatRequest(
      baseUrl: profile.baseUrl,
      apiKey: profile.apiKey,
      model: profile.model,
      provider: profile.providerName.toAppLlmProvider(),
      timeout: const AppLlmTimeoutConfig(
        connectTimeoutMs: 10000,
        sendTimeoutMs: 30000,
        receiveTimeoutMs: 60000,
        idleTimeoutMs: 30000,
      ),
      messages: const [AppLlmChatMessage(role: 'user', content: '只回复 pong')],
    ),
  );
}

_ProviderProfile _resolveProfile({
  required String traceName,
  required _ProviderProfile defaultProfile,
  required Map<String, _ProviderProfile> profiles,
  required List<_ProviderRoute> routes,
}) {
  for (final route in routes) {
    if (!route.matches(traceName)) {
      continue;
    }
    final routed = profiles[route.providerProfileId];
    if (routed != null && routed.isUsable) {
      return routed;
    }
  }
  return defaultProfile;
}

List<_ProviderProfile> _parseProviderProfiles(Map<String, Object?> settings) {
  final raw = settings['providerProfiles'];
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map)
        _ProviderProfile.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
  ];
}

List<_ProviderRoute> _parseProviderRoutes(Map<String, Object?> settings) {
  final raw = settings['requestProviderRoutes'];
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map)
        _ProviderRoute.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        ),
  ];
}

class _ProviderProfile {
  const _ProviderProfile({
    required this.id,
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  factory _ProviderProfile.fromSettings(Map<String, Object?> settings) {
    return _ProviderProfile(
      id: 'default',
      providerName: _readString(settings, 'providerName'),
      baseUrl: _readString(settings, 'baseUrl'),
      model: _readString(settings, 'model'),
      apiKey: _readString(settings, 'apiKey'),
    );
  }

  factory _ProviderProfile.fromJson(Map<String, Object?> json) {
    return _ProviderProfile(
      id: _readString(json, 'id'),
      providerName: _readString(json, 'providerName'),
      baseUrl: _readString(json, 'baseUrl'),
      model: _readString(json, 'model'),
      apiKey: _readString(json, 'apiKey'),
    );
  }

  final String id;
  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;

  bool get isUsable =>
      providerName.trim().isNotEmpty &&
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;

  String get host {
    return Uri.tryParse(baseUrl)?.host ?? '';
  }
}

class _ProviderRoute {
  const _ProviderRoute({
    required this.traceNamePattern,
    required this.providerProfileId,
  });

  factory _ProviderRoute.fromJson(Map<String, Object?> json) {
    return _ProviderRoute(
      traceNamePattern: _readString(json, 'traceNamePattern'),
      providerProfileId: _readString(json, 'providerProfileId'),
    );
  }

  final String traceNamePattern;
  final String providerProfileId;

  bool matches(String traceName) {
    final pattern = traceNamePattern.trim();
    if (pattern.isEmpty) {
      return false;
    }
    if (pattern.endsWith('*')) {
      return traceName.startsWith(pattern.substring(0, pattern.length - 1));
    }
    return traceName == pattern;
  }
}

class _SmokeCheck {
  const _SmokeCheck({required this.traceName, required this.expectedModel});

  final String traceName;
  final String expectedModel;
}

String _readString(Map<String, Object?> values, String key) {
  return values[key]?.toString().trim() ?? '';
}
