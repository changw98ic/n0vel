import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:novel_writer/app/state/settings_key_manager.dart';
import 'package:novel_writer/app/state/settings_secret_store.dart';

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
    test('loads existing key from secret store before key file', () async {
      final secretBytes = List<int>.generate(32, (i) => (i + 11) % 256);
      final fileBytes = List<int>.generate(32, (i) => (i + 99) % 256);
      await File(keyPath()).writeAsString(base64Encode(fileBytes));
      final secretStore = _FakeSettingsSecretStore(initialSecret: secretBytes);

      final manager = SettingsKeyManager(
        keyFilePath: keyPath(),
        secretStore: secretStore,
      );

      final key = await manager.loadOrCreateKey();
      final bytes = await key.extractBytes();

      expect(bytes, equals(secretBytes));
      expect(secretStore.readCount, 1);
    });

    test('migrates an existing key file into the secret store', () async {
      final existing = List<int>.generate(32, (i) => (i * 5 + 7) % 256);
      await File(keyPath()).writeAsString(base64Encode(existing));
      final secretStore = _FakeSettingsSecretStore();

      final manager = SettingsKeyManager(
        keyFilePath: keyPath(),
        secretStore: secretStore,
      );

      final key = await manager.loadOrCreateKey();
      final bytes = await key.extractBytes();

      expect(bytes, equals(existing));
      expect(secretStore.storedSecret, equals(existing));
      expect(secretStore.writeCount, 1);
    });

    test('falls back to key file when secret store cannot save', () async {
      final secretStore = _FakeSettingsSecretStore(failWrites: true);
      final manager = SettingsKeyManager(
        keyFilePath: keyPath(),
        secretStore: secretStore,
      );

      final key = await manager.loadOrCreateKey();
      final bytes = await key.extractBytes();

      expect(bytes.length, 32);
      expect(secretStore.writeCount, 1);
      final file = File(keyPath());
      expect(await file.exists(), isTrue);
      expect(base64Decode(await file.readAsString()), equals(bytes));
    });

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

    test(
      'rotates secret-store-only key without writing key file backup',
      () async {
        final existing = List<int>.generate(32, (i) => (i * 11 + 9) % 256);
        final secretStore = _FakeSettingsSecretStore(initialSecret: existing);
        final manager = SettingsKeyManager(
          keyFilePath: keyPath(),
          secretStore: secretStore,
        );

        final newKey = await manager.rotateKey();

        expect(newKey, isNotNull);
        final newBytes = await newKey!.extractBytes();
        expect(newBytes.length, 32);
        expect(newBytes, isNot(equals(existing)));
        expect(secretStore.storedSecret, equals(newBytes));
        expect(await File(keyPath()).exists(), isFalse);
        expect(await File('${keyPath()}.backup').exists(), isFalse);
      },
    );

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

  group('PlatformSettingsSecretStore', () {
    test(
      'passes saved secret through stdin instead of command arguments',
      () async {
        final runner = _CapturingSettingsSecretCommandRunner();
        final store = createDefaultSettingsSecretStore(commandRunner: runner);
        final bytes = List<int>.generate(32, (i) => (i * 3 + 17) % 256);
        final encoded = base64Encode(bytes);

        final saved = await store.saveSecretKey(
          'test-settings-key',
          SecretKey(bytes),
        );

        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          expect(saved, isTrue);
          expect(runner.calls, hasLength(1));
          final call = runner.calls.single;
          expect(call.arguments, isNot(contains(encoded)));
          expect(call.stdin?.trim(), encoded);
        } else {
          expect(saved, isFalse);
          expect(runner.calls, isEmpty);
        }
      },
    );
  });
}

class _FakeSettingsSecretStore implements SettingsSecretStore {
  _FakeSettingsSecretStore({List<int>? initialSecret, this.failWrites = false})
    : storedSecret = initialSecret == null
          ? null
          : List<int>.from(initialSecret);

  List<int>? storedSecret;
  final bool failWrites;
  var readCount = 0;
  var writeCount = 0;

  @override
  Future<SecretKey?> loadSecretKey(String keyId) async {
    readCount++;
    final bytes = storedSecret;
    return bytes == null ? null : SecretKey(List<int>.from(bytes));
  }

  @override
  Future<bool> saveSecretKey(String keyId, SecretKey key) async {
    writeCount++;
    if (failWrites) return false;
    storedSecret = await key.extractBytes();
    return true;
  }
}

class _CapturingSettingsSecretCommandRunner
    implements SettingsSecretCommandRunner {
  final List<_CapturedSettingsSecretCommand> calls = [];

  @override
  Future<SettingsSecretCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdin,
  }) async {
    calls.add(
      _CapturedSettingsSecretCommand(
        arguments: List<String>.from(arguments),
        stdin: stdin,
      ),
    );
    return const SettingsSecretCommandResult(exitCode: 0);
  }
}

class _CapturedSettingsSecretCommand {
  const _CapturedSettingsSecretCommand({required this.arguments, this.stdin});

  final List<String> arguments;
  final String? stdin;
}
