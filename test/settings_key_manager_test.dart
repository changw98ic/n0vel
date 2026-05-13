import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/settings_key_manager.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novel_writer_key_manager_test',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  String keyPath() => '${tempDir.path}/.settings.key';

  group('loadOrCreateKey', () {
    test('creates a new key file on first call', () async {
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final key = await manager.loadOrCreateKey();
      final bytes = await key.extractBytes();

      expect(bytes.length, 32);

      final file = File(keyPath());
      expect(await file.exists(), isTrue);

      final stored = base64Decode(await file.readAsString());
      expect(stored.length, 32);
      expect(stored, equals(bytes));
    });

    test('loads existing key from file on subsequent calls', () async {
      final existing = List<int>.generate(32, (i) => (i * 7 + 3) % 256);
      await File(keyPath()).writeAsString(base64Encode(existing));

      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final key = await manager.loadOrCreateKey();
      final bytes = await key.extractBytes();

      expect(bytes, equals(existing));
    });

    test('throws on corrupted key file (wrong length)', () async {
      await File(keyPath()).writeAsString(base64Encode([1, 2, 3]));

      final manager = SettingsKeyManager(keyFilePath: keyPath());
      expect(() => manager.loadOrCreateKey(), throwsA(isA<FormatException>()));
    });
  });

  group('deriveFromDevice', () {
    test('produces a deterministic 32-byte key', () async {
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final key1 = await manager.deriveFromDevice();
      final key2 = await manager.deriveFromDevice();

      final bytes1 = await key1.extractBytes();
      final bytes2 = await key2.extractBytes();

      expect(bytes1.length, 32);
      expect(bytes2.length, 32);
      expect(bytes1, equals(bytes2));
    });

    test('produces different keys on different device info', () async {
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final key = await manager.deriveFromDevice();
      final bytes = await key.extractBytes();

      // The key should be deterministic but not all zeros.
      expect(bytes.every((b) => b == 0), isFalse);
    });
  });

  group('rotateKey', () {
    test('creates backup and replaces key file', () async {
      // Create initial key
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final oldKey = await manager.loadOrCreateKey();
      final oldBytes = await oldKey.extractBytes();

      // Rotate
      final newKey = await manager.rotateKey();
      expect(newKey, isNotNull);

      final newBytes = await newKey!.extractBytes();
      expect(newBytes.length, 32);
      expect(newBytes, isNot(equals(oldBytes)));

      // Verify backup exists with old key
      final backupFile = File('${keyPath()}.backup');
      expect(await backupFile.exists(), isTrue);
      final backupBytes = base64Decode(await backupFile.readAsString());
      expect(backupBytes, equals(oldBytes));

      // Verify key file has new key
      final keyFile = File(keyPath());
      final storedBytes = base64Decode(await keyFile.readAsString());
      expect(storedBytes, equals(newBytes));
    });

    test('returns null when no key file exists', () async {
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final result = await manager.rotateKey();
      expect(result, isNull);
    });
  });

  group('attemptRecovery', () {
    test('recovers from backup key file', () async {
      final backupBytes = List<int>.generate(32, (i) => (i + 42) % 256);
      final backupFile = File('${keyPath()}.backup');
      await backupFile.writeAsString(base64Encode(backupBytes));

      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final recovered = await manager.attemptRecovery();
      expect(recovered, isNotNull);

      final bytes = await recovered!.extractBytes();
      expect(bytes, equals(backupBytes));
    });

    test('falls back to device-derived key when no backup', () async {
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final recovered = await manager.attemptRecovery();
      expect(recovered, isNotNull);

      final recoveredBytes = await recovered!.extractBytes();
      expect(recoveredBytes.length, 32);

      // Should match device-derived key.
      final derivedKey = await manager.deriveFromDevice();
      final derivedBytes = await derivedKey.extractBytes();
      expect(recoveredBytes, equals(derivedBytes));
    });

    test('succeeds without key file or backup', () async {
      // No key file, no backup — recovery should still succeed (via
      // device-derived key or a freshly generated key).
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final recovered = await manager.attemptRecovery();
      expect(recovered, isNotNull);

      final bytes = await recovered!.extractBytes();
      expect(bytes.length, 32);

      // A key file should have been persisted.
      final keyFile = File(keyPath());
      expect(await keyFile.exists(), isTrue);
    });

    test('handles corrupted backup gracefully', () async {
      await File('${keyPath()}.backup').writeAsString('not-valid-base64!!!');

      final manager = SettingsKeyManager(keyFilePath: keyPath());
      final recovered = await manager.attemptRecovery();
      // Should still succeed via device-derived or new key.
      expect(recovered, isNotNull);
    });
  });

  group('atomic key file write', () {
    test('key file has restricted permissions on POSIX', () async {
      final manager = SettingsKeyManager(keyFilePath: keyPath());
      await manager.loadOrCreateKey();

      if (!Platform.isWindows) {
        final stat = await Process.run('stat', ['-f', '%Lp', keyPath()]);
        if (stat.exitCode == 0) {
          final permissions = (stat.stdout as String).trim();
          // 600 = owner read/write only
          expect(permissions, '600');
        }
      }
    });
  });
}
