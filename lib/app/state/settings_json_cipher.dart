import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'settings_key_manager.dart';
import 'storage_lock.dart';

const String settingsJsonCipherFormat = 'novel-writer-settings-aes-gcm-v1';

class SettingsJsonCipherException implements Exception {
  const SettingsJsonCipherException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SettingsJsonCipher {
  SettingsJsonCipher({
    required File keyFile,
    File? settingsFile,
    AesGcm? algorithm,
    Sha256? keyHasher,
    SettingsKeyManager? keyManager,
  }) : _keyFile = keyFile,
       _settingsFile = settingsFile,
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _keyHasher = keyHasher ?? Sha256(),
       _keyManager =
           keyManager ?? SettingsKeyManager(keyFilePath: keyFile.path);

  factory SettingsJsonCipher.forSettingsFile(File settingsFile) {
    final parent = settingsFile.parent.path;
    return SettingsJsonCipher(
      keyFile: File('$parent/.settings.key'),
      settingsFile: settingsFile,
    );
  }

  final File _keyFile;
  final File? _settingsFile;
  final AesGcm _algorithm;
  final Sha256 _keyHasher;
  final SettingsKeyManager _keyManager;

  bool isEncryptedEnvelope(Map<String, Object?> json) {
    return json['format'] == settingsJsonCipherFormat;
  }

  Future<Map<String, Object?>> encryptMap(Map<String, Object?> data) async {
    return _encryptMapWithKey(data, await _loadSecretKey());
  }

  Future<Map<String, Object?>> _encryptMapWithKey(
    Map<String, Object?> data,
    SecretKey secretKey,
  ) async {
    final plaintext = utf8.encode(jsonEncode(data));
    final box = await _algorithm.encrypt(plaintext, secretKey: secretKey);
    return {
      'format': settingsJsonCipherFormat,
      'algorithm': 'AES-256-GCM',
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<Map<String, Object?>> decryptEnvelope(
    Map<String, Object?> envelope,
  ) async {
    final secretKey = await _loadSecretKeyWithRecovery();
    try {
      final nonce = _decodeBase64Field(envelope, 'nonce');
      final cipherText = _decodeBase64Field(envelope, 'ciphertext');
      final mac = _decodeBase64Field(envelope, 'mac');
      final plaintext = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is! Map) {
        throw const SettingsJsonCipherException(
          'AES 解密后的 settings.json 不是 JSON object。',
        );
      }
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    } on SecretBoxAuthenticationError {
      throw const SettingsJsonCipherException(
        'AES 解密失败，请确认本机 .settings.key 或 NOVEL_WRITER_SETTINGS_AES_KEY 未变化。',
      );
    } on FormatException catch (error) {
      throw SettingsJsonCipherException('AES 信封格式无效：${error.message}');
    }
  }

  /// Rotates the encryption key and re-encrypts [settings] with it.
  ///
  /// The cipher must have been created with [forSettingsFile] (or with an
  /// explicit `settingsFile`). A key-only cipher cannot safely complete a
  /// rotation, so it returns `false` without changing the key file.
  ///
  /// The key manager keeps the old key in its backup while the new settings
  /// envelope is written. If encryption or the settings write fails, the
  /// primary key is restored from that backup so the previous settings remain
  /// decryptable.
  ///
  /// Returns `true` on success.
  Future<bool> rotateKey(Map<String, Object?> settings) async {
    final settingsFile = _settingsFile;
    if (settingsFile == null || _sameFile(settingsFile, _keyFile)) {
      return false;
    }

    return StorageLock().synchronized(
      settingsFile.path,
      () => _rotateKeyLocked(settingsFile, settings),
    );
  }

  Future<bool> _rotateKeyLocked(
    File settingsFile,
    Map<String, Object?> settings,
  ) async {
    SecretKey? newKey;
    try {
      newKey = await _keyManager.rotateKey();
      if (newKey == null) return false;

      final envelope = await _encryptMapWithKey(settings, newKey);
      await _writeEncryptedSettingsAtomic(settingsFile, envelope);
      // The backup created by rotateKey() is a rollback point only until the
      // settings file has been rewritten. Keep recovery aligned with the
      // active key after the transaction commits.
      return await _keyManager.commitRotationBackup();
    } on Exception {
      // rotateKey() has already written the old key to .backup before
      // installing the new key. Restore it when the settings side fails.
      if (newKey != null) {
        await _keyManager.restoreKeyFromBackup();
      }
      return false;
    }
  }

  /// Attempts key recovery via the key manager.
  ///
  /// Returns a recovered [SecretKey], or `null` if all strategies fail.
  Future<SecretKey?> attemptRecovery() => _keyManager.attemptRecovery();

  // ---- Internal helpers ----

  Future<SecretKey> _loadSecretKey() async {
    // Environment variable override still takes highest priority.
    final override = Platform.environment['NOVEL_WRITER_SETTINGS_AES_KEY'];
    if (override != null && override.trim().isNotEmpty) {
      return SecretKey(await _normalizeOverrideKey(override.trim()));
    }

    // Delegate to the key manager for everything else.
    return _keyManager.loadOrCreateKey();
  }

  /// Loads the secret key with automatic recovery on failure.
  ///
  /// If the primary key load fails (missing / corrupted file), the key
  /// manager's recovery strategy is attempted before giving up.
  Future<SecretKey> _loadSecretKeyWithRecovery() async {
    try {
      // Never let decryption silently create a new random key. A missing or
      // malformed primary must enter the explicit recovery strategy instead.
      return await _keyManager.loadExistingKey();
    } on SettingsJsonCipherException {
      rethrow;
    } on Exception {
      // Key file missing or unreadable — try recovery.
      final recovered = await _keyManager.attemptRecovery();
      if (recovered != null) return recovered;
      throw const SettingsJsonCipherException('密钥文件丢失或损坏，且自动恢复失败。请重新配置应用。');
    }
  }

  Future<List<int>> _normalizeOverrideKey(String value) async {
    try {
      final decoded = base64Decode(value);
      if (decoded.length == 32) {
        return decoded;
      }
    } on FormatException {
      // Treat non-base64 values as passphrases below.
    }

    final hash = await _keyHasher.hash(utf8.encode(value));
    return hash.bytes;
  }

  List<int> _decodeBase64Field(Map<String, Object?> envelope, String field) {
    final value = envelope[field];
    if (value is! String || value.trim().isEmpty) {
      throw SettingsJsonCipherException('AES 信封缺少 $field。');
    }
    return base64Decode(value);
  }

  bool _sameFile(File left, File right) {
    return left.absolute.path == right.absolute.path;
  }

  Future<void> _writeEncryptedSettingsAtomic(
    File settingsFile,
    Map<String, Object?> envelope,
  ) async {
    await settingsFile.parent.create(recursive: true);
    final temporary = File('${settingsFile.path}.rotate.tmp');
    try {
      await temporary.writeAsString(jsonEncode(envelope), flush: true);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', temporary.path]);
      }
      await temporary.rename(settingsFile.path);
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }
}
