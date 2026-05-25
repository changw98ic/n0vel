import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'settings_key_manager.dart';
import 'settings_secret_store.dart';

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
    AesGcm? algorithm,
    Sha256? keyHasher,
    SettingsKeyManager? keyManager,
    SettingsSecretStore secretStore = const UnavailableSettingsSecretStore(),
  }) : _keyFile = keyFile,
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _keyHasher = keyHasher ?? Sha256(),
       _keyManager =
           keyManager ??
           SettingsKeyManager(
             keyFilePath: keyFile.path,
             secretStore: secretStore,
           );

  factory SettingsJsonCipher.forSettingsFile(
    File settingsFile, {
    SettingsSecretStore secretStore = const UnavailableSettingsSecretStore(),
  }) {
    final parent = settingsFile.parent.path;
    return SettingsJsonCipher(
      keyFile: File('$parent/.settings.key'),
      secretStore: secretStore,
    );
  }

  final File _keyFile;
  final AesGcm _algorithm;
  final Sha256 _keyHasher;
  final SettingsKeyManager _keyManager;

  bool isEncryptedEnvelope(Map<String, Object?> json) {
    return json['format'] == settingsJsonCipherFormat;
  }

  Future<Map<String, Object?>> encryptMap(Map<String, Object?> data) async {
    final plaintext = utf8.encode(jsonEncode(data));
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: await _loadSecretKey(),
    );
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
  /// Returns `true` on success.
  Future<bool> rotateKey(Map<String, Object?> settings) async {
    final newKey = await _keyManager.rotateKey();
    if (newKey == null) return false;

    final plaintext = utf8.encode(jsonEncode(settings));
    final box = await _algorithm.encrypt(plaintext, secretKey: newKey);
    final envelope = {
      'format': settingsJsonCipherFormat,
      'algorithm': 'AES-256-GCM',
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };

    await _keyFile.parent.create(recursive: true);
    await _keyFile.writeAsString(jsonEncode(envelope));
    return true;
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
      return await _loadSecretKey();
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
}
