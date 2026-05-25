import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app RAG modules do not import story_generation feature contracts', () {
    final appRagDir = Directory('lib/app/rag');
    final offenders = <String>[];

    for (final entity in appRagDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('features/story_generation/') ||
          source.contains('features\\story_generation\\')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Shared RAG infrastructure must depend on app/rag contracts, not '
          'story_generation feature contracts.',
    );
  });
}
