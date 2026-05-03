import 'dart:convert';
import 'dart:io';

import 'settings_json_cipher.dart';

Future<Map<String, String>> loadLocalSettingsFile({File? file}) async {
  return _stringMap(await loadLocalSettingsObjectFile(file: file));
}

Future<Map<String, Object?>> loadLocalSettingsObjectFile({File? file}) async {
  final configFile = file ?? File('setting.json');
  if (!await configFile.exists()) {
    return const {};
  }

  final raw = await configFile.readAsString();
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      final normalized = decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
      if (SettingsJsonCipher.forSettingsFile(
        configFile,
      ).isEncryptedEnvelope(normalized)) {
        final decrypted = await SettingsJsonCipher.forSettingsFile(
          configFile,
        ).decryptEnvelope(normalized);
        return decrypted;
      }
      return normalized;
    }
  } on FormatException {
    // Fall through to line-based parsing for legacy developer config files.
  }

  return parseLocalSettingsKeyValue(raw);
}

Future<void> saveEncryptedLocalSettingsFile({
  File? file,
  required Map<String, Object?> values,
}) async {
  final configFile = file ?? File('setting.json');
  await configFile.parent.create(recursive: true);
  final envelope = await SettingsJsonCipher.forSettingsFile(
    configFile,
  ).encryptMap(values);
  await configFile.writeAsString(jsonEncode(envelope));
}

Map<String, String> parseLocalSettingsKeyValue(String raw) {
  final values = <String, String>{};
  for (final line in const LineSplitter().convert(raw)) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || trimmedLine.startsWith('#')) {
      continue;
    }
    final separator = trimmedLine.indexOf('=');
    if (separator <= 0) {
      continue;
    }
    final key = trimmedLine.substring(0, separator).trim();
    if (key.isEmpty) {
      continue;
    }
    values[key] = trimmedLine.substring(separator + 1).trim();
  }
  return values;
}

Map<String, String> _stringMap(Map<String, Object?> values) {
  return values.map(
    (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
  );
}
