import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage_io.dart';
import 'package:novel_writer/app/state/settings_json_cipher.dart';

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

  test(
    'file storage preserves existing settings when staging write fails',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_settings_storage_atomic_write_failure_test',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/settings.json');
      final storage = FileAppSettingsStorage(file: file);
      const previousSettings = {
        'providerName': 'Existing provider',
        'baseUrl': 'https://old.example.com/v1',
        'model': 'old-model',
        'apiKey': 'sk-old-key',
        'timeoutMs': 30000,
        'maxConcurrentRequests': 1,
        'themePreference': 'dark',
      };
      const replacementSettings = {
        'providerName': 'Replacement provider',
        'baseUrl': 'https://new.example.com/v1',
        'model': 'new-model',
        'apiKey': 'sk-new-key',
        'timeoutMs': 60000,
        'maxConcurrentRequests': 2,
        'themePreference': 'light',
      };

      expect(
        (await storage.save(previousSettings)).issue,
        AppSettingsPersistenceIssue.none,
      );
      final rawBefore = await file.readAsString();
      await Directory('${file.path}.tmp').create();

      final result = await storage.save(replacementSettings);

      expect(result.issue, AppSettingsPersistenceIssue.fileWriteFailed);
      expect(await file.readAsString(), rawBefore);
      expect((await storage.load())?['apiKey'], 'sk-old-key');
    },
  );

  test('file storage reports corrupted ciphertext as fileReadFailed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_cipher_corrupt_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final cipher = SettingsJsonCipher.forSettingsFile(
      File('${directory.path}/settings.json'),
    );
    final file = File('${directory.path}/settings.json');
    await _writeAndCorruptEncryptedSettings(
      cipher: cipher,
      file: file,
      data: const {
        'providerName': 'OpenAI 兼容服务',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-5.4',
        'apiKey': 'sk-corrupt-test',
        'timeoutMs': 30000,
        'maxConcurrentRequests': 1,
        'themePreference': 'dark',
      },
    );

    final storage = FileAppSettingsStorage(file: file);
    final restored = await storage.load();

    expect(restored, isNull);
    expect(storage.lastLoadIssue, AppSettingsPersistenceIssue.fileReadFailed);
    expect(storage.lastLoadDetail, isNotNull);
    expect(storage.lastLoadDetail, contains('AES 解密失败'));
  });

  test('file storage reports key mismatch as fileReadFailed', () async {
    final directory = await Directory.systemTemp.createTemp(
      'novel_writer_settings_storage_cipher_mismatch_test',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final file = File('${directory.path}/settings.json');
    final writerCipher = SettingsJsonCipher.forSettingsFile(file);
    final stored = await writerCipher.encryptMap({
      'providerName': 'Ollama Cloud',
      'baseUrl': 'https://ollama.com/v1',
      'model': 'kimi-k2.6',
      'apiKey': 'sk-read-key',
      'timeoutMs': 120000,
      'maxConcurrentRequests': 2,
      'themePreference': 'light',
    });
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(stored));

    final wrongKeyFile = File('${directory.path}/wrong.key');
    await wrongKeyFile.writeAsString(
      base64Encode(List<int>.generate(32, (index) => index % 256)),
    );
    final readerStorage = FileAppSettingsStorage(
      file: file,
      cipher: SettingsJsonCipher(keyFile: wrongKeyFile),
    );

    final restored = await readerStorage.load();
    expect(restored, isNull);
    expect(
      readerStorage.lastLoadIssue,
      AppSettingsPersistenceIssue.fileReadFailed,
    );
    expect(readerStorage.lastLoadDetail, contains('AES 解密失败'));
  });
}

Future<void> _writeAndCorruptEncryptedSettings({
  required SettingsJsonCipher cipher,
  required File file,
  required Map<String, Object?> data,
}) async {
  final envelope = await cipher.encryptMap(data);
  final encrypted = envelope['ciphertext'] as String;
  if (encrypted.isNotEmpty) {
    final bytes = utf8.encode(encrypted);
    bytes[bytes.length - 1] = bytes[bytes.length - 1] == 65 ? 66 : 65;
    final corrupted = utf8.decode(bytes);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({...envelope, 'ciphertext': corrupted}),
    );
  }
}
