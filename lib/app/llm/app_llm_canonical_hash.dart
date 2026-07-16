import 'dart:convert';

import 'package:cryptography/dart.dart';

import 'app_unicode_nfc_data.g.dart';

/// The repository-wide identity contract for immutable LLM artifacts.
///
/// `canonical-json-v2-unicode-17.0.0` deliberately accepts only JSON values.
/// Map keys and string values are NFC-normalized against the pinned Unicode
/// data release, keys are ordered by Unicode scalar value, finite numbers have
/// one deterministic representation, and hashes are domain-separated before
/// SHA-256 is applied.
abstract final class AppLlmCanonicalHash {
  static const String contract = 'canonical-json-v2-unicode-17.0.0';
  static const String unicodeVersion = AppUnicodeNfcData.version;

  /// Explicit reader for artifacts written by the former limited contract.
  ///
  /// The wire tag remains `canonical-json-v1` so existing digests can be
  /// verified. New artifacts must use [contract].
  static const String legacyContract = 'canonical-json-v1-limited-latin-hangul';
  static const String _legacyWireContract = 'canonical-json-v1';

  static String canonicalJson(Object? value) => _encode(value);

  static String domainHash(String domainTag, Object? value) {
    final tag = normalizeNfc(domainTag.trim());
    if (tag.isEmpty || !RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(tag)) {
      throw ArgumentError.value(domainTag, 'domainTag', 'invalid domain tag');
    }
    final preimage = '$contract\n$tag\n${canonicalJson(value)}';
    final digest = const DartSha256().hashSync(utf8.encode(preimage));
    final hex = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'sha256:$hex';
  }

  static String legacyCanonicalJson(Object? value) => _legacyEncode(value);

  static String legacyDomainHash(String domainTag, Object? value) {
    final tag = _legacyNormalizeNfc(domainTag.trim());
    if (tag.isEmpty || !RegExp(r'^[a-z0-9][a-z0-9._-]*$').hasMatch(tag)) {
      throw ArgumentError.value(domainTag, 'domainTag', 'invalid domain tag');
    }
    final preimage =
        '$_legacyWireContract\n$tag\n${legacyCanonicalJson(value)}';
    final digest = const DartSha256().hashSync(utf8.encode(preimage));
    final hex = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'sha256:$hex';
  }

  /// Returns an immutable, normalized JSON snapshot.
  static Object? immutableSnapshot(Object? value) => _freeze(value);

  /// Full NFC normalization pinned to [unicodeVersion].
  static String normalizeNfc(String value) {
    if (value.isEmpty) return value;
    _requireValidUnicodeScalarString(value);
    final decomposed = <int>[];
    for (final codePoint in value.runes) {
      _appendCanonicalDecomposition(codePoint, decomposed);
    }
    return String.fromCharCodes(_composeCanonical(decomposed));
  }

  static String _encode(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is String) return jsonEncode(normalizeNfc(value));
    if (value is int) return value.toString();
    if (value is double) return _encodeDouble(value);
    if (value is Iterable<Object?>) {
      return '[${value.map(_encode).join(',')}]';
    }
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ArgumentError.value(
            entry.key,
            'key',
            'JSON keys must be strings',
          );
        }
        final key = normalizeNfc(entry.key as String);
        if (normalized.containsKey(key)) {
          throw FormatException(
            'duplicate map key after NFC normalization: $key',
          );
        }
        normalized[key] = entry.value;
      }
      final keys = normalized.keys.toList()..sort(_compareUnicodeScalars);
      return '{${keys.map((key) => '${jsonEncode(key)}:${_encode(normalized[key])}').join(',')}}';
    }
    throw ArgumentError.value(value, 'value', 'not a canonical JSON value');
  }

  static String _encodeDouble(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'JSON numbers must be finite');
    }
    if (value == 0) return '0';
    var encoded = jsonEncode(value);
    if (!encoded.contains('e') && encoded.endsWith('.0')) {
      encoded = encoded.substring(0, encoded.length - 2);
    }
    return encoded;
  }

  static Object? _freeze(Object? value) {
    if (value == null || value is bool || value is num) return value;
    if (value is String) return normalizeNfc(value);
    if (value is Iterable<Object?>) {
      return List<Object?>.unmodifiable(value.map(_freeze));
    }
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ArgumentError.value(
            entry.key,
            'key',
            'JSON keys must be strings',
          );
        }
        final key = normalizeNfc(entry.key as String);
        if (result.containsKey(key)) {
          throw FormatException(
            'duplicate map key after NFC normalization: $key',
          );
        }
        result[key] = _freeze(entry.value);
      }
      return Map<String, Object?>.unmodifiable(result);
    }
    throw ArgumentError.value(value, 'value', 'not a canonical JSON value');
  }

  static int _compareUnicodeScalars(String left, String right) {
    final a = left.runes.iterator;
    final b = right.runes.iterator;
    while (true) {
      final hasA = a.moveNext();
      final hasB = b.moveNext();
      if (!hasA || !hasB) return hasA == hasB ? 0 : (hasA ? 1 : -1);
      final comparison = a.current.compareTo(b.current);
      if (comparison != 0) return comparison;
    }
  }

  static void _requireValidUnicodeScalarString(String value) {
    final units = value.codeUnits;
    for (var index = 0; index < units.length; index += 1) {
      final unit = units[index];
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (index + 1 >= units.length ||
            units[index + 1] < 0xdc00 ||
            units[index + 1] > 0xdfff) {
          throw const FormatException(
            'canonical JSON strings must contain valid Unicode scalars',
          );
        }
        index += 1;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        throw const FormatException(
          'canonical JSON strings must contain valid Unicode scalars',
        );
      }
    }
  }

  static void _appendCanonicalDecomposition(int codePoint, List<int> output) {
    final hangul = _decomposeHangul(codePoint);
    if (hangul != null) {
      for (final part in hangul) {
        _appendOrdered(part, output);
      }
      return;
    }
    final decomposition = AppUnicodeNfcData.canonicalDecompositions[codePoint];
    if (decomposition == null) {
      _appendOrdered(codePoint, output);
      return;
    }
    for (final part in decomposition) {
      _appendCanonicalDecomposition(part, output);
    }
  }

  static void _appendOrdered(int codePoint, List<int> output) {
    output.add(codePoint);
    final combiningClass = _combiningClass(codePoint);
    if (combiningClass == 0) return;
    var position = output.length - 1;
    while (position > 0 &&
        _combiningClass(output[position - 1]) > combiningClass) {
      output[position] = output[position - 1];
      position -= 1;
    }
    output[position] = codePoint;
  }

  static List<int> _composeCanonical(List<int> decomposed) {
    if (decomposed.isEmpty) return const <int>[];
    final output = <int>[decomposed.first];
    var starterPosition = 0;
    var starter = decomposed.first;
    var lastCombiningClass = _combiningClass(decomposed.first);
    for (var index = 1; index < decomposed.length; index += 1) {
      final current = decomposed[index];
      final combiningClass = _combiningClass(current);
      final composite = _composePair(starter, current);
      if (composite != null &&
          (lastCombiningClass == 0 || lastCombiningClass < combiningClass)) {
        output[starterPosition] = composite;
        starter = composite;
        continue;
      }
      if (combiningClass == 0) {
        starterPosition = output.length;
        starter = current;
      }
      output.add(current);
      lastCombiningClass = combiningClass;
    }
    return output;
  }

  static int _combiningClass(int codePoint) =>
      AppUnicodeNfcData.canonicalCombiningClasses[codePoint] ?? 0;

  static int? _composePair(int left, int right) =>
      _composeHangul(left, right) ??
      AppUnicodeNfcData.canonicalCompositions[(left << 21) | right];

  static List<int>? _decomposeHangul(int codePoint) {
    const sBase = 0xac00;
    const lBase = 0x1100;
    const vBase = 0x1161;
    const tBase = 0x11a7;
    const vCount = 21;
    const tCount = 28;
    const nCount = vCount * tCount;
    const sCount = 19 * nCount;
    if (codePoint < sBase || codePoint >= sBase + sCount) return null;
    final sIndex = codePoint - sBase;
    final result = <int>[
      lBase + (sIndex ~/ nCount),
      vBase + ((sIndex % nCount) ~/ tCount),
    ];
    final trailing = sIndex % tCount;
    if (trailing != 0) result.add(tBase + trailing);
    return result;
  }

  static String _legacyNormalizeNfc(String value) {
    if (value.isEmpty) return value;
    final output = <int>[];
    for (final current in value.runes) {
      if (output.isNotEmpty) {
        final hangul = _composeHangul(output.last, current);
        if (hangul != null) {
          output[output.length - 1] = hangul;
          continue;
        }
        final composed = _latinCompositions[(output.last, current)];
        if (composed != null) {
          output[output.length - 1] = composed;
          continue;
        }
      }
      if (_isCombiningMark(current)) {
        throw FormatException(
          'canonical-json-v1 cannot NFC-normalize unsupported combining '
          'sequence U+${current.toRadixString(16).toUpperCase().padLeft(4, '0')}',
        );
      }
      output.add(current);
    }
    return String.fromCharCodes(output);
  }

  static String _legacyEncode(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is String) return jsonEncode(_legacyNormalizeNfc(value));
    if (value is int) return value.toString();
    if (value is double) return _encodeDouble(value);
    if (value is Iterable<Object?>) {
      return '[${value.map(_legacyEncode).join(',')}]';
    }
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw ArgumentError.value(
            entry.key,
            'key',
            'JSON keys must be strings',
          );
        }
        final key = _legacyNormalizeNfc(entry.key as String);
        if (normalized.containsKey(key)) {
          throw FormatException(
            'duplicate map key after NFC normalization: $key',
          );
        }
        normalized[key] = entry.value;
      }
      final keys = normalized.keys.toList()..sort(_compareUnicodeScalars);
      return '{${keys.map((key) => '${jsonEncode(key)}:${_legacyEncode(normalized[key])}').join(',')}}';
    }
    throw ArgumentError.value(value, 'value', 'not a canonical JSON value');
  }

  static bool _isCombiningMark(int rune) =>
      (rune >= 0x0300 && rune <= 0x036f) ||
      (rune >= 0x1ab0 && rune <= 0x1aff) ||
      (rune >= 0x1dc0 && rune <= 0x1dff) ||
      (rune >= 0x20d0 && rune <= 0x20ff) ||
      (rune >= 0xfe20 && rune <= 0xfe2f);

  static int? _composeHangul(int left, int right) {
    const sBase = 0xac00;
    const lBase = 0x1100;
    const vBase = 0x1161;
    const tBase = 0x11a7;
    const lCount = 19;
    const vCount = 21;
    const tCount = 28;
    const nCount = vCount * tCount;
    const sCount = lCount * nCount;
    if (left >= lBase &&
        left < lBase + lCount &&
        right >= vBase &&
        right < vBase + vCount) {
      return sBase + (left - lBase) * nCount + (right - vBase) * tCount;
    }
    if (left >= sBase &&
        left < sBase + sCount &&
        (left - sBase) % tCount == 0 &&
        right > tBase &&
        right < tBase + tCount) {
      return left + right - tBase;
    }
    return null;
  }

  static const Map<(int, int), int> _latinCompositions = {
    (0x0041, 0x0300): 0x00c0,
    (0x0041, 0x0301): 0x00c1,
    (0x0041, 0x0302): 0x00c2,
    (0x0041, 0x0303): 0x00c3,
    (0x0041, 0x0308): 0x00c4,
    (0x0041, 0x030a): 0x00c5,
    (0x0043, 0x0327): 0x00c7,
    (0x0045, 0x0300): 0x00c8,
    (0x0045, 0x0301): 0x00c9,
    (0x0045, 0x0302): 0x00ca,
    (0x0045, 0x0308): 0x00cb,
    (0x0049, 0x0300): 0x00cc,
    (0x0049, 0x0301): 0x00cd,
    (0x0049, 0x0302): 0x00ce,
    (0x0049, 0x0308): 0x00cf,
    (0x004e, 0x0303): 0x00d1,
    (0x004f, 0x0300): 0x00d2,
    (0x004f, 0x0301): 0x00d3,
    (0x004f, 0x0302): 0x00d4,
    (0x004f, 0x0303): 0x00d5,
    (0x004f, 0x0308): 0x00d6,
    (0x0055, 0x0300): 0x00d9,
    (0x0055, 0x0301): 0x00da,
    (0x0055, 0x0302): 0x00db,
    (0x0055, 0x0308): 0x00dc,
    (0x0059, 0x0301): 0x00dd,
    (0x0061, 0x0300): 0x00e0,
    (0x0061, 0x0301): 0x00e1,
    (0x0061, 0x0302): 0x00e2,
    (0x0061, 0x0303): 0x00e3,
    (0x0061, 0x0308): 0x00e4,
    (0x0061, 0x030a): 0x00e5,
    (0x0063, 0x0327): 0x00e7,
    (0x0065, 0x0300): 0x00e8,
    (0x0065, 0x0301): 0x00e9,
    (0x0065, 0x0302): 0x00ea,
    (0x0065, 0x0308): 0x00eb,
    (0x0069, 0x0300): 0x00ec,
    (0x0069, 0x0301): 0x00ed,
    (0x0069, 0x0302): 0x00ee,
    (0x0069, 0x0308): 0x00ef,
    (0x006e, 0x0303): 0x00f1,
    (0x006f, 0x0300): 0x00f2,
    (0x006f, 0x0301): 0x00f3,
    (0x006f, 0x0302): 0x00f4,
    (0x006f, 0x0303): 0x00f5,
    (0x006f, 0x0308): 0x00f6,
    (0x0075, 0x0300): 0x00f9,
    (0x0075, 0x0301): 0x00fa,
    (0x0075, 0x0302): 0x00fb,
    (0x0075, 0x0308): 0x00fc,
    (0x0079, 0x0301): 0x00fd,
    (0x0079, 0x0308): 0x00ff,
  };
}
