import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/local_rag_storage.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('LocalRagStorage FTS5 ranking', () {
    late Database db;
    late LocalRagStorage storage;

    setUp(() {
      db = sqlite3.openInMemory();
      storage = LocalRagStorage(db: db);
    });

    tearDown(() => db.dispose());

    test(
      'returns a stronger standard FTS match first with a higher score',
      () async {
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/strong.md',
          content: 'dragon fortress dragon fortress guarded the northern pass',
          category: 'scene',
        );
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/weak.md',
          content: 'a dragon crossed the distant valley',
          category: 'scene',
        );

        final results = await storage.searchFts(
          projectId: 'project-1',
          query: 'dragon fortress',
        );

        expect(results.map((result) => result.path), <String>[
          'project-1/strong.md',
          'project-1/weak.md',
        ]);
        expect(results.first.score, greaterThan(results.last.score));
      },
    );

    test(
      'keeps CJK merged ranking in the same higher-is-better direction',
      () async {
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/strong-cjk.md',
          content: '黑塔深处封存着神秘力量，守卫从未离开。',
          category: 'scene',
        );
        await storage.indexDocument(
          projectId: 'project-1',
          path: 'project-1/weak-cjk.md',
          content: '黑塔位于北境边缘。',
          category: 'scene',
        );

        final results = await storage.searchFts(
          projectId: 'project-1',
          query: '黑塔神秘',
        );

        expect(results.map((result) => result.path), <String>[
          'project-1/strong-cjk.md',
          'project-1/weak-cjk.md',
        ]);
        expect(results.first.score, greaterThan(results.last.score));
      },
    );
  });
}
