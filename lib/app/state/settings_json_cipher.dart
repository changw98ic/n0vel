import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

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
  }) : _keyFile = keyFile,
       _algorithm = algorithm ?? AesGcm.with256bits(),
       _keyHasher = keyHasher ?? Sha256();

  factory SettingsJsonCipher.forSettingsFile(File settingsFile) {
    final parent = settingsFile.parent.path;
    return SettingsJsonCipher(keyFile: File('$parent/.settings.key'));
  }

  final File _keyFile;
  final AesGcm _algorithm;
  final Sha256 _keyHasher;

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
    try {
      final nonce = _decodeBase64Field(envelope, 'nonce');
      final cipherText = _decodeBase64Field(envelope, 'ciphertext');
      final mac = _decodeBase64Field(envelope, 'mac');
      final plaintext = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: await _loadSecretKey(),
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

  Future<SecretKey> _loadSecretKey() async {
    final override = Platform.environment['NOVEL_WRITER_SETTINGS_AES_KEY'];
    if (override != null && override.trim().isNotEmpty) {
      return SecretKey(await _normalizeOverrideKey(override.trim()));
    }

    if (await _keyFile.exists()) {
      final stored = (await _keyFile.readAsString()).trim();
      final bytes = base64Decode(stored);
      if (bytes.length != 32) {
        throw const SettingsJsonCipherException(
          '.settings.key 必须是 32 字节 AES key 的 base64。',
        );
      }
      return SecretKey(bytes);
    }

    await _keyFile.parent.create(recursive: true);
    final secretKey = await _algorithm.newSecretKey();
    final bytes = await secretKey.extractBytes();
    await _keyFile.writeAsString(base64Encode(bytes));
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', _keyFile.path]);
    }
    return SecretKey(bytes);
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
