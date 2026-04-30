import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/sql_identifier.dart';

void main() {
  test('checkedSqlIdentifier accepts simple SQLite identifiers', () {
    expect(checkedSqlIdentifier('workspace_projects'), 'workspace_projects');
    expect(checkedSqlIdentifier('_temporary2'), '_temporary2');
  });

  test('checkedSqlIdentifier rejects unsafe SQL fragments', () {
    expect(
      () => checkedSqlIdentifier('workspace_projects; DROP TABLE users'),
      throwsArgumentError,
    );
    expect(() => checkedSqlIdentifier('has space'), throwsArgumentError);
    expect(
      () => checkedSqlIdentifier('1starts_with_digit'),
      throwsArgumentError,
    );
  });
}
