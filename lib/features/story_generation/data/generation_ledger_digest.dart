import 'dart:convert';

import 'package:cryptography/dart.dart';

/// Small deterministic JSON/SHA-256 utility for ledger identities.
class GenerationLedgerDigest {
  const GenerationLedgerDigest._();

  static String text(String value) {
    final digest = const DartSha256().hashSync(
      utf8.encode(value.replaceAll('\r\n', '\n')),
    );
    return 'sha256:${digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static String object(Object? value) => text(canonicalJson(value));

  static String canonicalJson(Object? value) => jsonEncode(_canonical(value));

  static Object? _canonical(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Iterable) return [for (final item in value) _canonical(item)];
    if (value is Map) {
      final entries =
          value.entries
              .map(
                (entry) =>
                    MapEntry(entry.key.toString(), _canonical(entry.value)),
              )
              .toList()
            ..sort((left, right) => left.key.compareTo(right.key));
      return {for (final entry in entries) entry.key: entry.value};
    }
    return value.toString();
  }
}
