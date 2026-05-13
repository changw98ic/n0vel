import 'package:flutter/material.dart';

import '../../../domain/prompt_language.dart';
import '../../llm/app_llm_client.dart';

enum AppThemePreference { light, dark, system }

enum AppSettingsFeedbackTone { info, success, error }

enum AppSettingsConnectionTestStatus { idle, running, success, error }

enum AppSettingsConnectionTestOutcome {
  none,
  missingApiKey,
  missingModel,
  invalidBaseUrl,
  unsupportedModel,
  timeout,
  unauthorized,
  modelNotFound,
  networkError,
  success,
}

class AppSettingsFeedback {
  const AppSettingsFeedback({
    this.title,
    this.message,
    this.tone = AppSettingsFeedbackTone.info,
  });

  final String? title;
  final String? message;
  final AppSettingsFeedbackTone tone;
}

class AppSettingsConnectionTestState {
  const AppSettingsConnectionTestState({
    required this.status,
    required this.outcome,
    this.title,
    this.message,
  });

  const AppSettingsConnectionTestState.idle()
    : status = AppSettingsConnectionTestStatus.idle,
      outcome = AppSettingsConnectionTestOutcome.none,
      title = null,
      message = null;

  final AppSettingsConnectionTestStatus status;
  final AppSettingsConnectionTestOutcome outcome;
  final String? title;
  final String? message;
}

class AppSettingsDiagnostic {
  const AppSettingsDiagnostic({
    required this.issueCode,
    required this.title,
    required this.summary,
    this.detail,
  });

  final String issueCode;
  final String title;
  final String summary;
  final String? detail;

  String get report {
    final buffer = StringBuffer()
      ..writeln('类别：$issueCode')
      ..writeln('标题：$title')
      ..writeln()
      ..writeln(summary);
    if (detail != null && detail!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('诊断：$detail');
    }
    return buffer.toString().trim();
  }
}

class AppLlmProviderProfile {
  const AppLlmProviderProfile({
    required this.id,
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final String id;
  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'providerName': providerName,
      'baseUrl': baseUrl,
      'model': model,
      'apiKey': apiKey,
    };
  }

  static AppLlmProviderProfile? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final json = raw.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final id = (json['id'] as String?)?.trim() ?? '';
    final providerName = (json['providerName'] as String?)?.trim() ?? '';
    final baseUrl = (json['baseUrl'] as String?)?.trim() ?? '';
    final model = (json['model'] as String?)?.trim() ?? '';
    final apiKey = (json['apiKey'] as String?) ?? '';
    if (id.isEmpty ||
        providerName.isEmpty ||
        baseUrl.isEmpty ||
        model.isEmpty) {
      return null;
    }
    return AppLlmProviderProfile(
      id: id,
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
    );
  }
}

class AppLlmRequestProviderRoute {
  const AppLlmRequestProviderRoute({
    required this.traceNamePattern,
    required this.providerProfileId,
  });

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

  Map<String, Object?> toJson() {
    return {
      'traceNamePattern': traceNamePattern,
      'providerProfileId': providerProfileId,
    };
  }

  static AppLlmRequestProviderRoute? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final json = raw.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final traceNamePattern =
        (json['traceNamePattern'] as String?)?.trim() ?? '';
    final providerProfileId =
        (json['providerProfileId'] as String?)?.trim() ?? '';
    if (traceNamePattern.isEmpty || providerProfileId.isEmpty) {
      return null;
    }
    return AppLlmRequestProviderRoute(
      traceNamePattern: traceNamePattern,
      providerProfileId: providerProfileId,
    );
  }
}

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    AppLlmTimeoutConfig? timeout,
    int timeoutMs = 30000,
    required this.maxConcurrentRequests,
    required this.maxTokens,
    required this.hasApiKey,
    required this.themePreference,
    this.providerProfiles = const [],
    this.requestProviderRoutes = const [],
    this.promptLanguage = PromptLanguage.zh,
  }) : _timeout = timeout,
       _timeoutMs = timeoutMs;

  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;
  final AppLlmTimeoutConfig? _timeout;
  final int _timeoutMs;
  final int maxConcurrentRequests;
  final int maxTokens;
  final bool hasApiKey;
  final AppThemePreference themePreference;
  final List<AppLlmProviderProfile> providerProfiles;
  final List<AppLlmRequestProviderRoute> requestProviderRoutes;
  final PromptLanguage promptLanguage;

  AppLlmTimeoutConfig get timeout =>
      _timeout ?? AppLlmTimeoutConfig.uniform(_timeoutMs);

  int get timeoutMs => timeout.receiveTimeoutMs;

  AppSettingsSnapshot copyWith({
    String? providerName,
    String? baseUrl,
    String? model,
    String? apiKey,
    AppLlmTimeoutConfig? timeout,
    int? maxConcurrentRequests,
    int? maxTokens,
    bool? hasApiKey,
    AppThemePreference? themePreference,
    List<AppLlmProviderProfile>? providerProfiles,
    List<AppLlmRequestProviderRoute>? requestProviderRoutes,
    PromptLanguage? promptLanguage,
  }) {
    return AppSettingsSnapshot(
      providerName: providerName ?? this.providerName,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      timeout: timeout ?? this.timeout,
      maxConcurrentRequests:
          maxConcurrentRequests ?? this.maxConcurrentRequests,
      maxTokens: maxTokens ?? this.maxTokens,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      themePreference: themePreference ?? this.themePreference,
      providerProfiles: providerProfiles ?? this.providerProfiles,
      requestProviderRoutes:
          requestProviderRoutes ?? this.requestProviderRoutes,
      promptLanguage: promptLanguage ?? this.promptLanguage,
    );
  }

  ThemeMode get themeMode => switch (themePreference) {
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
  };

  AppLlmProviderProfile get primaryProviderProfile => AppLlmProviderProfile(
    id: 'primary',
    providerName: providerName,
    baseUrl: baseUrl,
    model: model,
    apiKey: apiKey,
  );

  Map<String, Object?> toJson() {
    return {
      'providerName': providerName,
      'baseUrl': baseUrl,
      'model': model,
      'apiKey': apiKey,
      ...timeout.toJson(),
      'maxConcurrentRequests': maxConcurrentRequests,
      'maxTokens': maxTokens,
      'themePreference': themePreference.name,
      'providerProfiles': [
        for (final profile in providerProfiles) profile.toJson(),
      ],
      'requestProviderRoutes': [
        for (final route in requestProviderRoutes) route.toJson(),
      ],
      'promptLanguage': promptLanguage.name,
    };
  }

  static AppSettingsSnapshot fromJson(Map<String, Object?> json) {
    final themeName = json['themePreference'] as String?;
    final themePreference = switch (themeName) {
      'dark' => AppThemePreference.dark,
      'system' => AppThemePreference.system,
      _ => AppThemePreference.light,
    };

    final apiKey = (json['apiKey'] as String?) ?? '';

    final promptLanguageName = json['promptLanguage'] as String?;
    final promptLanguage = switch (promptLanguageName) {
      'en' => PromptLanguage.en,
      _ => PromptLanguage.zh,
    };
    final providerProfiles = _providerProfilesFromJson(
      json['providerProfiles'],
    );
    final requestProviderRoutes = _requestProviderRoutesFromJson(
      json['requestProviderRoutes'],
    );

    final providerName = (json['providerName'] as String?) ?? 'OpenAI 兼容服务';
    final baseUrl =
        (json['baseUrl'] as String?) ?? 'https://api.example.com/v1';
    final model = (json['model'] as String?) ?? 'gpt-4.1-mini';
    return AppSettingsSnapshot(
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
      timeout: AppLlmTimeoutConfig.fromJson(json),
      maxConcurrentRequests: (json['maxConcurrentRequests'] as int?) ?? 1,
      maxTokens: AppLlmChatRequest.normalizeMaxTokens(
        (json['maxTokens'] as int?) ?? AppLlmChatRequest.unlimitedMaxTokens,
      ),
      hasApiKey: apiKey.isNotEmpty,
      themePreference: themePreference,
      providerProfiles: _profilesWithPrimary(
        providerProfiles,
        AppLlmProviderProfile(
          id: 'primary',
          providerName: providerName,
          baseUrl: baseUrl,
          model: model,
          apiKey: apiKey,
        ),
      ),
      requestProviderRoutes: requestProviderRoutes,
      promptLanguage: promptLanguage,
    );
  }
}

List<AppLlmProviderProfile> _providerProfilesFromJson(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (AppLlmProviderProfile.fromJson(item) != null)
        AppLlmProviderProfile.fromJson(item)!,
  ];
}

List<AppLlmProviderProfile> _profilesWithPrimary(
  List<AppLlmProviderProfile> profiles,
  AppLlmProviderProfile primary,
) {
  final updated = <AppLlmProviderProfile>[];
  var inserted = false;
  for (final profile in profiles) {
    if (profile.id == primary.id) {
      if (!inserted) {
        updated.add(primary);
        inserted = true;
      }
    } else {
      updated.add(profile);
    }
  }
  if (!inserted) {
    updated.insert(0, primary);
  }
  return List<AppLlmProviderProfile>.unmodifiable(updated);
}

List<AppLlmRequestProviderRoute> _requestProviderRoutesFromJson(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (AppLlmRequestProviderRoute.fromJson(item) != null)
        AppLlmRequestProviderRoute.fromJson(item)!,
  ];
}

class ResolvedRequestSettings {
  const ResolvedRequestSettings({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.providerProfileId,
  });

  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;
  final String? providerProfileId;
}
