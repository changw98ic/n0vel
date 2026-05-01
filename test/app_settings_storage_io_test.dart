import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage_io.dart';

void main() {
  test('file storage encrypts settings.json and restores apiKey', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/settings.json');
    final storage = FileAppSettingsStorage(file: file);

    await storage.save({
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': 'sk-secure-key',
      'maxConcurrentRequests': 2,
      'themePreference': 'dark',
    });

    final raw = await file.readAsString();
    expect(raw.contains('sk-secure-key'), isFalse);
    expect(raw.contains('"apiKey"'), isFalse);
    expect(raw.contains('novel-writer-settings-aes-gcm-v1'), isTrue);

    final restored = await storage.load();
    expect(restored?['apiKey'], 'sk-secure-key');
    expect(restored?['model'], 'gpt-5.4');
    expect(restored?['maxConcurrentRequests'], 2);
    expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.none);
  });

  test(
    'file storage keeps cleared apiKey encrypted in settings.json',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_settings_storage_clear_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/settings.json');
      final storage = FileAppSettingsStorage(file: file);

      final result = await storage.save({
        'providerName': 'OpenAI 兼容服务',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-5.4',
        'apiKey': '',
        'themePreference': 'light',
      });

      final raw = await file.readAsString();
      expect(raw.contains('"apiKey"'), isFalse);
      expect(result.issue, AppSettingsPersistenceIssue.none);
    },
  );

  test(
    'file storage loads apiKey from persisted JSON without keychain fallback',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_settings_storage_load_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/settings.json');
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '{"providerName":"Ollama Cloud","baseUrl":"https://ollama.com/v1/","model":"kimi-k2.6","apiKey":"sk-inline-key","timeoutMs":30000,"maxConcurrentRequests":3,"themePreference":"light"}',
      );

      final storage = FileAppSettingsStorage(file: file);
      final restored = await storage.load();

      expect(restored?['apiKey'], 'sk-inline-key');
      expect(restored?['providerName'], 'Ollama Cloud');
      expect(restored?['maxConcurrentRequests'], 3);
      expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.none);
      expect(storage.lastLoadDetail, isNull);
    },
  );

  test('file storage reports malformed json as fileReadFailed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_malformed_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/settings.json');
    await file.parent.create(recursive: true);
    await file.writeAsString('{not valid json');

    final storage = FileAppSettingsStorage(file: file);
    final restored = await storage.load();

    expect(restored, isNull);
    expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.fileReadFailed);
    expect(storage.lastLoadDetail, isNotNull);
  });

  test('file storage reports non-object json as fileReadFailed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_non_object_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/settings.json');
    await file.parent.create(recursive: true);
    await file.writeAsString('["wrong-shape"]');

    final storage = FileAppSettingsStorage(file: file);
    final restored = await storage.load();

    expect(restored, isNull);
    expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.fileReadFailed);
    expect(storage.lastLoadDetail, 'settings.json 必须是 JSON object。');
  });

  test(
    'file storage overwrites previous encrypted data on second save',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_settings_storage_overwrite_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/settings.json');
      final storage = FileAppSettingsStorage(file: file);

      await storage.save({
        'providerName': '旧服务商',
        'baseUrl': 'https://old.example.com/v1',
        'model': 'gpt-4.1-mini',
        'apiKey': 'sk-old-key',
        'timeoutMs': 10000,
        'maxConcurrentRequests': 1,
        'themePreference': 'light',
      });

      await storage.save({
        'providerName': 'OpenAI 兼容服务',
        'baseUrl': 'https://new.example.com/v1',
        'model': 'gpt-5.4',
        'apiKey': 'sk-new-key',
        'timeoutMs': 60000,
        'maxConcurrentRequests': 4,
        'themePreference': 'dark',
      });

      final restored = await storage.load();
      expect(restored, isNotNull);
      expect(restored!['providerName'], 'OpenAI 兼容服务');
      expect(restored['baseUrl'], 'https://new.example.com/v1');
      expect(restored['model'], 'gpt-5.4');
      expect(restored['apiKey'], 'sk-new-key');
      expect(restored['timeoutMs'], 60000);
      expect(restored['maxConcurrentRequests'], 4);
      expect(restored['themePreference'], 'dark');

      final raw = await file.readAsString();
      expect(raw.contains('sk-old-key'), isFalse);
      expect(raw.contains('sk-new-key'), isFalse);
    },
  );

  test('file storage auto-creates parent directory on save', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_auto_dir_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final nestedFile = File('${directory.path}/deep/nested/dir/settings.json');
    expect(await nestedFile.parent.exists(), isFalse);

    final storage = FileAppSettingsStorage(file: nestedFile);
    final result = await storage.save({
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': 'sk-auto-dir',
      'timeoutMs': 30000,
      'maxConcurrentRequests': 1,
      'themePreference': 'light',
    });

    expect(result.issue, AppSettingsPersistenceIssue.none);
    expect(await nestedFile.exists(), isTrue);

    final restored = await storage.load();
    expect(restored!['apiKey'], 'sk-auto-dir');
  });

  test(
    'file storage resets lastLoadIssue after failed load followed by successful load',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_settings_storage_issue_reset_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/settings.json');
      await file.parent.create(recursive: true);

      final storage = FileAppSettingsStorage(file: file);

      await file.writeAsString('{bad json');
      final failed = await storage.load();
      expect(failed, isNull);
      expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.fileReadFailed);
      expect(storage.lastLoadDetail, isNotNull);

      await file.writeAsString(
        '{"providerName":"恢复后","baseUrl":"https://recovered.local/v1","model":"gpt-5.4","apiKey":"sk-ok","timeoutMs":30000,"maxConcurrentRequests":2,"themePreference":"dark"}',
      );
      final restored = await storage.load();
      expect(restored, isNotNull);
      expect(restored!['providerName'], '恢复后');
      expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.none);
      expect(storage.lastLoadDetail, isNull);
    },
  );

  test('file storage returns consistent data across multiple loads', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_multi_load_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/settings.json');
    final storage = FileAppSettingsStorage(file: file);

    await storage.save({
      'providerName': 'OpenAI 兼容服务',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'kimi-k2.6',
      'apiKey': 'sk-multi-load',
      'timeoutMs': 45000,
      'maxConcurrentRequests': 3,
      'themePreference': 'dark',
    });

    final first = await storage.load();
    final second = await storage.load();
    final third = await storage.load();

    expect(first, equals(second));
    expect(second, equals(third));
    expect(first!['apiKey'], 'sk-multi-load');
    expect(first['timeoutMs'], 45000);
  });

  test('file storage preserves unicode and special characters', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_unicode_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/settings.json');
    final storage = FileAppSettingsStorage(file: file);

    await storage.save({
      'providerName': '月潮回声 · 暗港',
      'baseUrl': 'https://api.example.com/v1',
      'model': 'gpt-5.4',
      'apiKey': 'sk-中文密钥-🔑',
      'timeoutMs': 30000,
      'maxConcurrentRequests': 1,
      'themePreference': 'dark',
    });

    final restored = await storage.load();
    expect(restored!['providerName'], '月潮回声 · 暗港');
    expect(restored['apiKey'], 'sk-中文密钥-🔑');
  });

  test('file storage reports write failures as fileWriteFailed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_write_failure_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final parentAsFile = File('${directory.path}/parent-as-file');
    await parentAsFile.writeAsString('not a directory');
    final file = File('${parentAsFile.path}/settings.json');
    final storage = FileAppSettingsStorage(file: file);

    final result = await storage.save({
      'providerName': 'Ollama Cloud',
      'baseUrl': 'https://ollama.com/v1/',
      'model': 'kimi-k2.6',
      'apiKey': 'sk-inline-key',
      'timeoutMs': 120000,
      'themePreference': 'light',
    });

    expect(result.issue, AppSettingsPersistenceIssue.fileWriteFailed);
    expect(result.detail, isNotNull);
  });
}
