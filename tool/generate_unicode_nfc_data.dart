import 'dart:io';

import 'package:cryptography/dart.dart';

const _unicodeVersion = '17.0.0';
const _unicodeDataSha256 =
    '2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c';
const _derivedNormalizationPropsSha256 =
    '71fd6a206a2c0cdd41feb6b7f656aa31091db45e9cedc926985d718397f9e488';

void main(List<String> arguments) {
  if (arguments.length != 3) {
    stderr.writeln(
      'usage: dart run tool/generate_unicode_nfc_data.dart '
      '<UnicodeData.txt> <DerivedNormalizationProps.txt> <output.dart>',
    );
    exitCode = 64;
    return;
  }
  final unicodeData = File(arguments[0]);
  final derivedProperties = File(arguments[1]);
  final output = File(arguments[2]);
  if (!unicodeData.existsSync() || !derivedProperties.existsSync()) {
    stderr.writeln('Unicode input data is missing');
    exitCode = 66;
    return;
  }
  if (_sha256(unicodeData) != _unicodeDataSha256 ||
      _sha256(derivedProperties) != _derivedNormalizationPropsSha256) {
    stderr.writeln('Unicode input data does not match the pinned release');
    exitCode = 65;
    return;
  }

  final decompositions = <int, List<int>>{};
  final combiningClasses = <int, int>{};
  for (final rawLine in unicodeData.readAsLinesSync()) {
    if (rawLine.isEmpty) continue;
    final fields = rawLine.split(';');
    if (fields.length < 6) {
      throw const FormatException('malformed UnicodeData row');
    }
    final codePoint = int.parse(fields[0], radix: 16);
    final combiningClass = int.parse(fields[3]);
    if (combiningClass != 0) combiningClasses[codePoint] = combiningClass;
    final decomposition = fields[5].trim();
    if (decomposition.isEmpty || decomposition.startsWith('<')) continue;
    decompositions[codePoint] = decomposition
        .split(' ')
        .map((value) => int.parse(value, radix: 16))
        .toList(growable: false);
  }

  final compositionExclusions = <int>{};
  for (final rawLine in derivedProperties.readAsLinesSync()) {
    final content = rawLine.split('#').first.trim();
    if (content.isEmpty) continue;
    final fields = content.split(';').map((value) => value.trim()).toList();
    if (fields.length != 2 || fields[1] != 'Full_Composition_Exclusion') {
      continue;
    }
    final bounds = fields[0].split('..');
    final first = int.parse(bounds.first, radix: 16);
    final last = int.parse(bounds.last, radix: 16);
    for (var codePoint = first; codePoint <= last; codePoint += 1) {
      compositionExclusions.add(codePoint);
    }
  }

  final compositions = <int, int>{};
  for (final entry in decompositions.entries) {
    final parts = entry.value;
    if (parts.length != 2 || compositionExclusions.contains(entry.key)) {
      continue;
    }
    final key = (parts[0] << 21) | parts[1];
    if (compositions.putIfAbsent(key, () => entry.key) != entry.key) {
      throw StateError('duplicate Unicode composition pair');
    }
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE. DO NOT EDIT.')
    ..writeln('// Unicode $_unicodeVersion, generated from:')
    ..writeln(
      '// https://www.unicode.org/Public/$_unicodeVersion/ucd/UnicodeData.txt',
    )
    ..writeln('// SHA-256: $_unicodeDataSha256')
    ..writeln(
      '// https://www.unicode.org/Public/$_unicodeVersion/ucd/DerivedNormalizationProps.txt',
    )
    ..writeln('// SHA-256: $_derivedNormalizationPropsSha256')
    ..writeln('// Data is distributed under the Unicode Data Files license:')
    ..writeln('// https://www.unicode.org/license.txt')
    ..writeln()
    ..writeln('abstract final class AppUnicodeNfcData {')
    ..writeln("  static const version = '$_unicodeVersion';")
    ..writeln('  static const canonicalDecompositions = <int, List<int>>{');
  _writeListMap(buffer, decompositions);
  buffer
    ..writeln('  };')
    ..writeln('  static const canonicalCombiningClasses = <int, int>{');
  _writeIntMap(buffer, combiningClasses);
  buffer
    ..writeln('  };')
    ..writeln('  static const canonicalCompositions = <int, int>{');
  _writeIntMap(buffer, compositions);
  buffer
    ..writeln('  };')
    ..writeln('}');

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(buffer.toString(), flush: true);
}

void _writeListMap(StringBuffer output, Map<int, List<int>> values) {
  final keys = values.keys.toList()..sort();
  for (final key in keys) {
    output.writeln(
      '    ${_hex(key)}: <int>[${values[key]!.map(_hex).join(', ')}],',
    );
  }
}

void _writeIntMap(StringBuffer output, Map<int, int> values) {
  final keys = values.keys.toList()..sort();
  for (final key in keys) {
    output.writeln('    ${_hex(key)}: ${_hex(values[key]!)},');
  }
}

String _hex(int value) => '0x${value.toRadixString(16)}';

String _sha256(File file) => const DartSha256()
    .hashSync(file.readAsBytesSync())
    .bytes
    .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
    .join();
