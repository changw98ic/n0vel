import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/local_settings_file.dart';
import 'package:novel_writer/app/state/settings_json_cipher.dart';

void main() {
  test(
    'encrypted local setting.json round trips without plaintext secrets',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_local_settings_file_test_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/setting.json');
      await saveEncryptedLocalSettingsFile(
        file: file,
        values: const {
          'providerName': 'Xiaomi MiMo',
          'baseUrl': 'https://token-plan-cn.xiaomimimo.com/v1',
          'model': 'mimo-v2.5-pro',
          'apiKey': 'tp-secret',
          'MIMO_API_KEY': 'tp-secret',
        },
      );

      final raw = await file.readAsString();
      expect(raw, contains(settingsJsonCipherFormat));
      expect(raw, isNot(contains('tp-secret')));
      expect(raw, isNot(contains('MIMO_API_KEY')));

      final restored = await loadLocalSettingsFile(file: file);
      expect(restored['providerName'], 'Xiaomi MiMo');
      expect(restored['baseUrl'], 'https://token-plan-cn.xiaomimimo.com/v1');
      expect(restored['model'], 'mimo-v2.5-pro');
      expect(restored['apiKey'], 'tp-secret');
      expect(restored['MIMO_API_KEY'], 'tp-secret');
    },
  );

  test(
    'encrypted local setting.json preserves nested provider routing config',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'novel_writer_local_settings_file_nested_test_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final file = File('${directory.path}/setting.json');
      await saveEncryptedLocalSettingsFile(
        file: file,
        values: const {
          'providerName': '智谱 GLM',
          'baseUrl': 'https://open.bigmodel.cn/api/paas/v4',
          'model': 'glm-5.1',
          'apiKey': 'zhipu-secret',
          'providerProfiles': [
            {
              'id': 'ollama-kimi',
              'providerName': 'Ollama Cloud',
              'baseUrl': 'https://ollama.com/v1',
              'model': 'kimi-k2.6',
              'apiKey': 'ollama-secret',
            },
          ],
          'requestProviderRoutes': [
            {
              'traceNamePattern': 'scene_review_*',
              'providerProfileId': 'ollama-kimi',
            },
          ],
        },
      );

      final raw = await file.readAsString();
      expect(raw, isNot(contains('ollama-secret')));
      expect(raw, isNot(contains('scene_review_*')));

      final restored = await loadLocalSettingsObjectFile(file: file);
      final profiles = restored['providerProfiles'] as List<Object?>;
      final routes = restored['requestProviderRoutes'] as List<Object?>;
      expect((profiles.single as Map)['id'], 'ollama-kimi');
      expect((profiles.single as Map)['apiKey'], 'ollama-secret');
      expect((routes.single as Map)['traceNamePattern'], 'scene_review_*');
    },
  );

  test('legacy key-value local setting.json still loads', () async {
    expect(
      parseLocalSettingsKeyValue('''
OLLAMA_API_KEY=ollama-local-key
OLLAMA_BASE_URL=https://ollama.com/v1
REAL_AI_MODEL=kimi-k2.6
'''),
      {
        'OLLAMA_API_KEY': 'ollama-local-key',
        'OLLAMA_BASE_URL': 'https://ollama.com/v1',
        'REAL_AI_MODEL': 'kimi-k2.6',
      },
    );
  });
}
