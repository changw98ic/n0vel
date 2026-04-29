import 'app_settings_storage_stub.dart'
    if (dart.library.io) 'app_settings_storage_io.dart';
import 'app_storage_clone.dart';

enum AppSettingsPersistenceIssue { none, fileReadFailed, fileWriteFailed }

class AppSettingsSaveResult {
  const AppSettingsSaveResult({
    this.issue = AppSettingsPersistenceIssue.none,
    this.detail,
  });

  final AppSettingsPersistenceIssue issue;
  final String? detail;

  bool get succeededWithoutWarnings =>
      issue == AppSettingsPersistenceIssue.none;
}

abstract class AppSettingsStorage {
  AppSettingsPersistenceIssue get lastLoadIssue;
  String? get lastLoadDetail => null;

  Future<Map<String, Object?>?> load();

  Future<AppSettingsSaveResult> save(Map<String, Object?> data);
}

class InMemoryAppSettingsStorage implements AppSettingsStorage {
  Map<String, Object?>? _data;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue =>
      AppSettingsPersistenceIssue.none;

  @override
  String? get lastLoadDetail => null;

  @override
  Future<Map<String, Object?>?> load() async {
    return _data == null ? null : cloneStorageMap(_data!);
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    _data = cloneStorageMap(data);
    return const AppSettingsSaveResult();
  }
}

AppSettingsStorage createDefaultAppSettingsStorage() =>
    createAppSettingsStorage();
