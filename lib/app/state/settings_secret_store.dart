import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

const String settingsSecretStoreKeyId = 'settings-aes-key';

abstract interface class SettingsSecretStore {
  Future<SecretKey?> loadSecretKey(String keyId);

  Future<bool> saveSecretKey(String keyId, SecretKey key);
}

class UnavailableSettingsSecretStore implements SettingsSecretStore {
  const UnavailableSettingsSecretStore();

  @override
  Future<SecretKey?> loadSecretKey(String keyId) async => null;

  @override
  Future<bool> saveSecretKey(String keyId, SecretKey key) async => false;
}

SettingsSecretStore createDefaultSettingsSecretStore({
  SettingsSecretCommandRunner? commandRunner,
}) {
  return PlatformSettingsSecretStore(
    commandRunner: commandRunner ?? const ProcessSettingsSecretCommandRunner(),
  );
}

class PlatformSettingsSecretStore implements SettingsSecretStore {
  const PlatformSettingsSecretStore({
    required SettingsSecretCommandRunner commandRunner,
  }) : _commandRunner = commandRunner;

  static const String _macOSService = 'novel-writer-settings';
  static const String _linuxApplication = 'novel-writer';

  final SettingsSecretCommandRunner _commandRunner;

  @override
  Future<SecretKey?> loadSecretKey(String keyId) async {
    final encoded = await _loadEncodedSecret(keyId);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      final bytes = base64Decode(encoded.trim());
      if (bytes.length != 32) {
        return null;
      }
      return SecretKey(bytes);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<bool> saveSecretKey(String keyId, SecretKey key) async {
    final encoded = base64Encode(await key.extractBytes());
    return _saveEncodedSecret(keyId, encoded);
  }

  Future<String?> _loadEncodedSecret(String keyId) async {
    if (Platform.isMacOS) {
      final result = await _commandRunner.run('security', [
        'find-generic-password',
        '-a',
        keyId,
        '-s',
        _macOSService,
        '-w',
      ]);
      return result.exitCode == 0 ? result.stdout.trim() : null;
    }

    if (Platform.isLinux) {
      final result = await _commandRunner.run('secret-tool', [
        'lookup',
        'application',
        _linuxApplication,
        'account',
        keyId,
      ]);
      return result.exitCode == 0 ? result.stdout.trim() : null;
    }

    if (Platform.isWindows) {
      return _loadWindowsDpapiSecret(keyId);
    }

    return null;
  }

  Future<bool> _saveEncodedSecret(String keyId, String encoded) async {
    if (Platform.isMacOS) {
      final result = await _commandRunner.run('security', [
        'add-generic-password',
        '-a',
        keyId,
        '-s',
        _macOSService,
        '-U',
        '-w',
      ], stdin: '$encoded\n');
      return result.exitCode == 0;
    }

    if (Platform.isLinux) {
      final result = await _commandRunner.run('secret-tool', [
        'store',
        '--label',
        'Novel Writer settings encryption key',
        'application',
        _linuxApplication,
        'account',
        keyId,
      ], stdin: encoded);
      return result.exitCode == 0;
    }

    if (Platform.isWindows) {
      return _saveWindowsDpapiSecret(keyId, encoded);
    }

    return false;
  }

  Future<String?> _loadWindowsDpapiSecret(String keyId) async {
    final path = _windowsSecretFile(keyId).path;
    final result = await _commandRunner.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'''
$path = $args[0]
if (!(Test-Path -LiteralPath $path)) { exit 2 }
$protected = [System.IO.File]::ReadAllBytes($path)
$bytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
  $protected,
  $null,
  [System.Security.Cryptography.DataProtectionScope]::CurrentUser
)
[Console]::Out.Write([Convert]::ToBase64String($bytes))
''',
      path,
    ]);
    return result.exitCode == 0 ? result.stdout.trim() : null;
  }

  Future<bool> _saveWindowsDpapiSecret(String keyId, String encoded) async {
    final path = _windowsSecretFile(keyId).path;
    final result = await _commandRunner.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'''
$path = $args[0]
$encoded = [Console]::In.ReadToEnd().Trim()
$bytes = [Convert]::FromBase64String($encoded)
$protected = [System.Security.Cryptography.ProtectedData]::Protect(
  $bytes,
  $null,
  [System.Security.Cryptography.DataProtectionScope]::CurrentUser
)
$parent = Split-Path -Parent $path
[System.IO.Directory]::CreateDirectory($parent) | Out-Null
[System.IO.File]::WriteAllBytes($path, $protected)
''',
      path,
    ], stdin: encoded);
    return result.exitCode == 0;
  }

  File _windowsSecretFile(String keyId) {
    final root =
        Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final safeKeyId = keyId.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return File('$root\\NovelWriter\\secrets\\$safeKeyId.dpapi');
  }
}

abstract interface class SettingsSecretCommandRunner {
  Future<SettingsSecretCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdin,
  });
}

class ProcessSettingsSecretCommandRunner
    implements SettingsSecretCommandRunner {
  const ProcessSettingsSecretCommandRunner();

  @override
  Future<SettingsSecretCommandResult> run(
    String executable,
    List<String> arguments, {
    String? stdin,
  }) async {
    try {
      if (stdin == null) {
        final result = await Process.run(executable, arguments);
        return SettingsSecretCommandResult(
          exitCode: result.exitCode,
          stdout: result.stdout?.toString() ?? '',
          stderr: result.stderr?.toString() ?? '',
        );
      }

      final process = await Process.start(executable, arguments);
      process.stdin.write(stdin);
      await process.stdin.close();
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      return SettingsSecretCommandResult(
        exitCode: exitCode,
        stdout: await stdoutFuture,
        stderr: await stderrFuture,
      );
    } on ProcessException catch (error) {
      return SettingsSecretCommandResult(
        exitCode: error.errorCode,
        stderr: error.message,
      );
    } on Object catch (error) {
      return SettingsSecretCommandResult(exitCode: 1, stderr: '$error');
    }
  }
}

class SettingsSecretCommandResult {
  const SettingsSecretCommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}
