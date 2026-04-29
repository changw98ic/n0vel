/// Domain layer: Settings-related enums and data models.
/// Kept independent of Flutter UI dependencies.
library;

enum AppThemePreference { light, dark }

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

class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    required this.timeoutMs,
    required this.maxConcurrentRequests,
    required this.hasApiKey,
    required this.themePreference,
  });

  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;
  final int timeoutMs;
  final int maxConcurrentRequests;
  final bool hasApiKey;
  final AppThemePreference themePreference;

  AppSettingsSnapshot copyWith({
    String? providerName,
    String? baseUrl,
    String? model,
    String? apiKey,
    int? timeoutMs,
    int? maxConcurrentRequests,
    bool? hasApiKey,
    AppThemePreference? themePreference,
  }) {
    return AppSettingsSnapshot(
      providerName: providerName ?? this.providerName,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      maxConcurrentRequests:
          maxConcurrentRequests ?? this.maxConcurrentRequests,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      themePreference: themePreference ?? this.themePreference,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'providerName': providerName,
      'baseUrl': baseUrl,
      'model': model,
      'apiKey': apiKey,
      'timeoutMs': timeoutMs,
      'maxConcurrentRequests': maxConcurrentRequests,
      'themePreference': themePreference.name,
    };
  }

  static AppSettingsSnapshot fromJson(Map<String, Object?> json) {
    final themeName = json['themePreference'] as String?;
    final themePreference = switch (themeName) {
      'dark' => AppThemePreference.dark,
      _ => AppThemePreference.light,
    };

    final apiKey = (json['apiKey'] as String?) ?? '';

    return AppSettingsSnapshot(
      providerName: (json['providerName'] as String?) ?? 'OpenAI 兼容服务',
      baseUrl: (json['baseUrl'] as String?) ?? 'https://api.example.com/v1',
      model: (json['model'] as String?) ?? 'gpt-4.1-mini',
      apiKey: apiKey,
      timeoutMs: (json['timeoutMs'] as int?) ?? 30000,
      maxConcurrentRequests: (json['maxConcurrentRequests'] as int?) ?? 1,
      hasApiKey: apiKey.isNotEmpty,
      themePreference: themePreference,
    );
  }
}
