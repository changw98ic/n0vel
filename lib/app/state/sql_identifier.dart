final RegExp _sqliteIdentifierPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

String checkedSqlIdentifier(String identifier) {
  if (!_sqliteIdentifierPattern.hasMatch(identifier)) {
    throw ArgumentError.value(
      identifier,
      'identifier',
      'Expected a simple SQLite identifier.',
    );
  }
  return identifier;
}

String quotedSqlIdentifier(String identifier) {
  return '"${checkedSqlIdentifier(identifier)}"';
}
