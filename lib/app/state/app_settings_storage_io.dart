import 'dart:convert';
import 'dart:io';

import 'app_settings_storage.dart';
import 'storage_lock.dart';

class FileAppSettingsStorage implements AppSettingsStorage {
  FileAppSettingsStorage({File? file}) : _file = file ?? _resolveFile();

  final File _file;
  AppSettingsPersistenceIssue _lastLoadIssue = AppSettingsPersistenceIssue.none;
  String? _lastLoadDetail;

  @override
  AppSettingsPersistenceIssue get lastLoadIssue => _lastLoadIssue;

  @override
  String? get lastLoadDetail => _lastLoadDetail;

  static File _resolveFile() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return File('.novel_writer_settings.json');
    }

    if (Platform.isMacOS) {
      return File(
        '$home/Library/Application Support/NovelWriter/settings.json',
      );
    }

    return File('$home/.novel_writer/settings.json');
  }

  @override
  Future<Map<String, Object?>?> load() async {
    _lastLoadIssue = AppSettingsPersistenceIssue.none;
    _lastLoadDetail = null;
    return StorageLock().synchronized(_file.path, () => _loadFileData());
  }

  @override
  Future<AppSettingsSaveResult> save(Map<String, Object?> data) async {
    return StorageLock().synchronized(_file.path, () async {
      try {
        await _writeData(data);
        return const AppSettingsSaveResult();
      } on FileSystemException catch (error) {
        return AppSettingsSaveResult(
          issue: AppSettingsPersistenceIssue.fileWriteFailed,
          detail: error.message,
        );
      }
    });
  }

  Future<Map<String, Object?>?> _loadFileData() async {
    try {
      if (!await _file.exists()) {
        return null;
      }

      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _lastLoadIssue = AppSettingsPersistenceIssue.fileReadFailed;
        _lastLoadDetail = 'settings.json 必须是 JSON object。';
        return null;
      }

      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } on FileSystemException catch (error) {
      _lastLoadIssue = AppSettingsPersistenceIssue.fileReadFailed;
      _lastLoadDetail = error.message;
      return null;
    } on FormatException catch (error) {
      _lastLoadIssue = AppSettingsPersistenceIssue.fileReadFailed;
      _lastLoadDetail = error.message;
      return null;
    }
  }

  Future<void> _writeData(Map<String, Object?> data) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(data));
  }
}

AppSettingsStorage createAppSettingsStorage() => FileAppSettingsStorage();
