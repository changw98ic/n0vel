import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// Manages the lifecycle of the settings encryption key: creation,
/// device-bound derivation, rotation, and recovery.
class SettingsKeyManager {
  SettingsKeyManager({String? keyFilePath})
    : _keyFilePath = keyFilePath;

  static const String _salt = 'novel-writer-settings-v1';
  static const int _aesKeyLength = 32;

  final String? _keyFilePath;

  final AesGcm _algorithm = AesGcm.with256bits();

  // ---- Public API ----

  /// Loads the existing key file or creates a fresh random key.
  ///
  /// If the environment variable `NOVEL_WRITER_SETTINGS_AES_KEY` is set,
  /// that value takes precedence (same override behaviour as before).
  Future<SecretKey> loadOrCreateKey() async {
    final override = Platform.environment['NOVEL_WRITER_SETTINGS_AES_KEY'];
    if (override != null && override.trim().isNotEmpty) {
      return SecretKey(await _normalizeOverrideKey(override.trim()));
    }

    final keyFile = _resolveKeyFile();
    if (await keyFile.exists()) {
      return _readKeyFile(keyFile);
    }

    // First run: generate a new random key and persist it.
    final secretKey = await _algorithm.newSecretKey();
    final bytes = await secretKey.extractBytes();
    await _writeKeyFileAtomic(keyFile, bytes);
    return SecretKey(bytes);
  }

  /// Rotates the encryption key for [settings].
  ///
  /// 1. Load the current key.
  /// 2. Generate a new random key.
  /// 3. Backup the old key file.
  /// 4. Write the new key atomically.
  ///
  /// The caller is responsible for re-encrypting the settings data with the
  /// returned (new) key after this method succeeds.
  ///
  /// Returns the new [SecretKey] on success, `null` on failure.
  Future<SecretKey?> rotateKey() async {
    final keyFile = _resolveKeyFile();

    // Load the current key so we can back it up.
    if (!await keyFile.exists()) {
      return null;
    }

    try {
      final oldBytes = await _readKeyFileBytes(keyFile);

      // Backup old key.
      final backupFile = File('${keyFile.path}.backup');
      await backupFile.writeAsString(base64Encode(oldBytes));

      // Generate new key and write atomically.
      final newKey = await _algorithm.newSecretKey();
      final newBytes = await newKey.extractBytes();
      await _writeKeyFileAtomic(keyFile, newBytes);

      return SecretKey(newBytes);
    } on Exception {
      return null;
    }
  }

  /// Attempts to recover a usable key when the primary key is missing or
  /// corrupted.
  ///
  /// Recovery strategy (in order):
  ///   1. Try backup key file (`.settings.key.backup`).
  ///   2. Try device-derived key.
  ///   3. As a last resort, generate a new key (data is lost but app works).
  ///
  /// Returns a recovered [SecretKey], or `null` if recovery fails completely.
  Future<SecretKey?> attemptRecovery() async {
    final keyFile = _resolveKeyFile();

    // Strategy 1: backup key.
    final backupFile = File('${keyFile.path}.backup');
    if (await backupFile.exists()) {
      try {
        final recovered = await _readKeyFile(backupFile);
        await _persistRecoveredKey(keyFile, recovered);
        return recovered;
      } on FormatException {
        // Backup is also corrupted; fall through.
      }
    }

    // Strategy 2: device-derived key.
    try {
      final recovered = await deriveFromDevice();
      await _persistRecoveredKey(keyFile, recovered);
      return recovered;
    } on Exception {
      // Device info unavailable; fall through.
    }

    // Strategy 3: brand-new key. Settings data will be lost, but the app
    // will be functional.
    try {
      final secretKey = await _algorithm.newSecretKey();
      final bytes = await secretKey.extractBytes();
      await _writeKeyFileAtomic(keyFile, bytes);
      return SecretKey(bytes);
    } on Exception {
      return null;
    }
  }

  /// Derives a deterministic key from device-specific information
  /// (hostname + username), stretched with HKDF-SHA256.
  ///
  /// This provides a stable fallback key when the random key file is lost.
  Future<SecretKey> deriveFromDevice() async {
    final hostname = _getHostname();
    final username = _getUsername();
    if (hostname.isEmpty && username.isEmpty) {
      throw const FormatException(
        '无法获取设备信息用于密钥派生。',
      );
    }

    final seed = utf8.encode('$hostname\x00$username');
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: _aesKeyLength);
    return hkdf.deriveKey(
      secretKey: SecretKey(seed),
      nonce: utf8.encode(_salt),
    );
  }

  // ---- Internal helpers ----

  File _resolveKeyFile() {
    final path = _keyFilePath;
    if (path != null) {
      return File(path);
    }
    // Match the default location used by SettingsJsonCipher.
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      if (Platform.isMacOS) {
        return File(
          '$home/Library/Application Support/NovelWriter/.settings.key',
        );
      }
      return File('$home/.novel_writer/.settings.key');
    }
    return File('.settings.key');
  }

  Future<SecretKey> _readKeyFile(File file) async {
    final bytes = await _readKeyFileBytes(file);
    return SecretKey(bytes);
  }

  /// Persists a recovered key to the key file so subsequent loads succeed.
  Future<void> _persistRecoveredKey(File keyFile, SecretKey key) async {
    final bytes = await key.extractBytes();
    await _writeKeyFileAtomic(keyFile, bytes);
  }

  Future<List<int>> _readKeyFileBytes(File file) async {
    final stored = (await file.readAsString()).trim();
    final bytes = base64Decode(stored);
    if (bytes.length != _aesKeyLength) {
      throw const FormatException(
        '.settings.key 必须是 32 字节 AES key 的 base64。',
      );
    }
    return bytes;
  }

  /// Writes [keyBytes] to [file] atomically: write to a temp file first,
  /// then rename. Restricts permissions on POSIX systems.
  Future<void> _writeKeyFileAtomic(File file, List<int> keyBytes) async {
    await file.parent.create(recursive: true);

    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(base64Encode(keyBytes));
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', tempFile.path]);
    }
    await tempFile.rename(file.path);
  }

  Future<List<int>> _normalizeOverrideKey(String value) async {
    try {
      final decoded = base64Decode(value);
      if (decoded.length == _aesKeyLength) {
        return decoded;
      }
    } on FormatException {
      // Treat non-base64 values as passphrases below.
    }
    final hash = await Sha256().hash(utf8.encode(value));
    return hash.bytes;
  }

  String _getHostname() {
    try {
      return Platform.localHostname;
    } on Object {
      return '';
    }
  }

  String _getUsername() {
    final envVars = Platform.environment;
    // macOS / Linux
    final user = envVars['USER'];
    if (user != null && user.isNotEmpty) return user;
    // Windows
    final username = envVars['USERNAME'];
    if (username != null && username.isNotEmpty) return username;
    return '';
  }
}
