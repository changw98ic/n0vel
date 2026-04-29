import 'app_settings_storage.dart';

class _NoopAppSettingsStorage implements AppSettingsStorage {
  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.none;

  @override
  String? get lastLoadDetail => null;

  @override
  Future<Map<String, Object?>?> load() async => null;

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return const AppSettingsSaveResult();
  }
}

AppSettingsStorage createAppSettingsStorage() => _NoopAppSettingsStorage();
