import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/settings_json_cipher.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_settings_cipher_test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('rotates key and writes the envelope to settings.json', () async {
    final settingsFile = File('${tempDir.path}/settings.json');
    final cipher = SettingsJsonCipher.forSettingsFile(settingsFile);
    final initial = <String, Object?>{
      'providerName': '旧服务商',
      'model': 'gpt-4.1-mini',
      'apiKey': 'sk-old',
    };
    final initialEnvelope = await cipher.encryptMap(initial);
    await settingsFile.writeAsString(jsonEncode(initialEnvelope));

    final keyFile = File('${tempDir.path}/.settings.key');
    final oldKey = base64Decode(await keyFile.readAsString());

    final updated = <String, Object?>{
      'providerName': '新服务商',
      'model': 'gpt-5.4',
      'apiKey': 'sk-new',
    };
    expect(await cipher.rotateKey(updated), isTrue);

    final storedKey = base64Decode(await keyFile.readAsString());
    expect(storedKey, hasLength(32));
    expect(storedKey, isNot(equals(oldKey)));

    final raw = await settingsFile.readAsString();
    final envelope = (jsonDecode(raw) as Map).map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    expect(envelope['format'], settingsJsonCipherFormat);
    expect(await cipher.decryptEnvelope(envelope), updated);

    // A successful rotation also advances the recovery backup. If the active
    // key disappears later, recovery must restore the key that can decrypt
    // the current envelope rather than the pre-rotation key.
    final backupFile = File('${keyFile.path}.backup');
    expect(await backupFile.readAsString(), await keyFile.readAsString());
    await keyFile.delete();
    expect(await cipher.decryptEnvelope(envelope), updated);

    // The key file must remain a base64-encoded 32-byte key, never a JSON
    // envelope (the previous implementation overwrote it with this data).
    final keyRaw = await keyFile.readAsString();
    expect(keyRaw.trim(), isNot(startsWith('{')));
    expect(base64Decode(keyRaw), hasLength(32));
  });

  test(
    'restores the old key when settings rotation cannot be written',
    () async {
      final settingsFile = File('${tempDir.path}/settings.json');
      final cipher = SettingsJsonCipher.forSettingsFile(settingsFile);
      final initial = <String, Object?>{
        'providerName': '保持可解密',
        'model': 'gpt-4.1-mini',
      };
      final initialEnvelope = await cipher.encryptMap(initial);
      await settingsFile.writeAsString(jsonEncode(initialEnvelope));

      final keyFile = File('${tempDir.path}/.settings.key');
      final oldKey = await keyFile.readAsString();
      final oldSettings = await settingsFile.readAsString();

      // Keep the key file's parent usable, but make the destination itself a
      // directory so the atomic rename fails after the key has rotated.
      await settingsFile.delete();
      await Directory(settingsFile.path).create();

      expect(await cipher.rotateKey(const {'providerName': '不可写'}), isFalse);

      expect(await keyFile.readAsString(), oldKey);

      await Directory(settingsFile.path).delete();
      await settingsFile.writeAsString(oldSettings);
      final restoredEnvelope = (jsonDecode(oldSettings) as Map).map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      expect(await cipher.decryptEnvelope(restoredEnvelope), initial);
    },
  );

  test(
    'key-only ciphers refuse rotation without touching the key file',
    () async {
      final keyFile = File('${tempDir.path}/.settings.key');
      final keyOnlyCipher = SettingsJsonCipher(keyFile: keyFile);
      await keyOnlyCipher.encryptMap(const {'value': 'keep'});
      final before = await keyFile.readAsString();

      expect(await keyOnlyCipher.rotateKey(const {'value': 'rotate'}), isFalse);
      expect(await keyFile.readAsString(), before);
    },
  );
}
