import 'package:novel_writer/app/state/app_settings_storage.dart';

class ReadFailureWarningStorage implements AppSettingsStorage {
  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.fileReadFailed;

  @override
  String? get lastLoadDetail => 'settings.json is unreadable';

  @override
  Future<Map<String, Object?>?> load() async {
    return {
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'themePreference': 'light',
    };
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult();
  }
}

class RecoveringReadStorage implements AppSettingsStorage {
  int _loadCount = 0;
  AppSettingsPersistenceIssue _lastLoadIssue =
      AppSettingsPersistenceIssue.fileReadFailed;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue => _lastLoadIssue;

  @override
  String? get lastLoadDetail =>
      _loadCount == 1 ? 'settings.json is unreadable' : null;

  @override
  Future<Map<String, Object?>?> load() async {
    _loadCount += 1;
    _lastLoadIssue = _loadCount == 1
        ? AppSettingsPersistenceIssue.fileReadFailed
        : AppSettingsPersistenceIssue.none;
    return {
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': _loadCount == 1 ? '' : 'sk-recovered-key',
      'themePreference': 'light',
    };
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult();
  }
}

class RecoveringWriteStorage implements AppSettingsStorage {
  int _saveCount = 0;
  Map<String, Object?>? _data;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.none;

  @override
  String? get lastLoadDetail => null;

  @override
  Future<Map<String, Object?>?> load() async {
    return _data == null ? null : Map<String, Object?>.from(_data!);
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    _saveCount += 1;
    _data = Map<String, Object?>.from(data);
    return AppSettingsSaveResult(
      issue: _saveCount == 1
          ? AppSettingsPersistenceIssue.fileWriteFailed
          : AppSettingsPersistenceIssue.none,
      detail: _saveCount == 1 ? 'settings.json write denied' : null,
    );
  }
}

class FailingSecureSettingsStorage implements AppSettingsStorage {
  Map<String, Object?>? _data;

  @override
  String? get lastLoadDetail => null;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.none;

  @override
  Future<Map<String, Object?>?> load() async {
    return _data == null ? null : Map<String, Object?>.from(_data!);
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    _data = Map<String, Object?>.from(data);
    return const AppSettingsSaveResult(
      issue: AppSettingsPersistenceIssue.fileWriteFailed,
      detail: 'settings.json write denied',
    );
  }
}

class LegacyMigrationWarningStorage implements AppSettingsStorage {
  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.fileReadFailed;

  @override
  String? get lastLoadDetail => 'settings.json contains invalid legacy data';

  @override
  Future<Map<String, Object?>?> load() async {
    return {
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': 'sk-legacy-key',
      'themePreference': 'light',
    };
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult();
  }
}
