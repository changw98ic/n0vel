import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// Manages the lifecycle of the settings encryption key: creation,
/// device-bound derivation, rotation, and recovery.
class SettingsKeyManager {
  SettingsKeyManager({String? keyFilePath}) : _keyFilePath = keyFilePath;

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

  /// Loads the current key without creating a replacement.
  ///
  /// Decryption must distinguish a missing primary key from a first-run
  /// encryption request. Creating a random key on the decrypt path would
  /// bypass the `.backup`/device recovery strategies and produce a misleading
  /// authentication failure instead of restoring the known key.
  Future<SecretKey> loadExistingKey() async {
    final override = Platform.environment['NOVEL_WRITER_SETTINGS_AES_KEY'];
    if (override != null && override.trim().isNotEmpty) {
      return SecretKey(await _normalizeOverrideKey(override.trim()));
    }
    final keyFile = _resolveKeyFile();
    if (!await keyFile.exists()) {
      throw const FormatException('.settings.key does not exist');
    }
    return _readKeyFile(keyFile);
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
    // An environment override is intentionally ephemeral and takes
    // precedence over the on-disk key. Rotating the file while the override
    // is active would make the returned key unusable on the next read.
    final override = Platform.environment['NOVEL_WRITER_SETTINGS_AES_KEY'];
    if (override != null && override.trim().isNotEmpty) {
      return null;
    }

    final keyFile = _resolveKeyFile();

    // Load the current key so we can back it up.
    if (!await keyFile.exists()) {
      return null;
    }

    try {
      final oldBytes = await _readKeyFileBytes(keyFile);

      // Backup old key atomically before touching the primary key. The
      // backup is also a rollback point for a settings-file rotation that
      // fails after the new key has been installed.
      final backupFile = File('${keyFile.path}.backup');
      await _writeKeyFileAtomic(backupFile, oldBytes);

      // Generate new key and write atomically.
      final newKey = await _algorithm.newSecretKey();
      final newBytes = await newKey.extractBytes();
      await _writeKeyFileAtomic(keyFile, newBytes);

      return SecretKey(newBytes);
    } on Exception {
      return null;
    }
  }

  /// Restores the primary key from the last rotation backup.
  ///
  /// This is used by the settings cipher when re-encrypting the settings
  /// file fails after [rotateKey] has installed a new primary key. Returning
  /// `false` keeps the caller from claiming a successful rotation when the
  /// rollback could not be persisted.
  Future<bool> restoreKeyFromBackup() async {
    final keyFile = _resolveKeyFile();
    final backupFile = File('${keyFile.path}.backup');
    try {
      final bytes = await _readKeyFileBytes(backupFile);
      await _writeKeyFileAtomic(keyFile, bytes);
      return true;
    } on Exception {
      return false;
    }
  }

  /// Commits a completed settings rotation by making the recovery backup
  /// point at the active key.
  ///
  /// [rotateKey] first stores the old key in `.backup` so the caller can
  /// roll back if rewriting `settings.json` fails. Once that rewrite has
  /// succeeded, retaining the old key would make a later missing-primary-key
  /// recovery restore a key that cannot decrypt the current settings. Copying
  /// the active key into the backup closes that time-of-check/time-of-use
  /// gap while keeping the backup file useful for future recovery.
  Future<bool> commitRotationBackup() async {
    final keyFile = _resolveKeyFile();
    final backupFile = File('${keyFile.path}.backup');
    try {
      final activeBytes = await _readKeyFileBytes(keyFile);
      await _writeKeyFileAtomic(backupFile, activeBytes);
      return true;
    } on Exception {
      return false;
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
      } on Exception {
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
      throw const FormatException('无法获取设备信息用于密钥派生。');
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
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return File('$localAppData\\NovelWriter\\.settings.key');
      }
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return File('$userProfile\\AppData\\Local\\NovelWriter\\.settings.key');
      }
      return File('.settings.key');
    }
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
      throw const FormatException('.settings.key 必须是 32 字节 AES key 的 base64。');
    }
    return bytes;
  }

  /// Writes [keyBytes] to [file] atomically: write to a temp file first,
  /// then rename. Restricts permissions on POSIX systems.
  Future<void> _writeKeyFileAtomic(File file, List<int> keyBytes) async {
    await file.parent.create(recursive: true);

    final tempFile = File('${file.path}.tmp');
    try {
      await tempFile.writeAsString(base64Encode(keyBytes), flush: true);
      if (!Platform.isWindows) {
        await Process.run('chmod', ['600', tempFile.path]);
      }
      await tempFile.rename(file.path);
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
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
