import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/app_workspace_storage_io.dart';
import 'package:novel_writer/app/state/storage_write_verification.dart';

void main() {
  group('StorageWriteVerificationException', () {
    test('toString contains label and attempts', () {
      final exception = StorageWriteVerificationException(
        label: 'test-storage',
        attempts: 2,
        snapshotFingerprint: 111,
        verifyFingerprint: 222,
      );

      expect(exception.toString(), contains('test-storage'));
      expect(exception.toString(), contains('2'));
    });
  });

  group('verifyAfterWrite', () {
    late Directory tempDir;
    late String dbPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'novel_writer_write_verify_test',
      );
      dbPath = '${tempDir.path}/authoring.db';
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('succeeds when save and load are consistent', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final data = <String, Object?>{
        'projects': [
          {
            'id': 'project-verify',
            'sceneId': 'scene-01',
            'title': '验证测试',
            'genre': 'test',
            'summary': 'test',
            'recentLocation': 'test',
            'lastOpenedAtMs': 1,
          },
        ],
      };

      // Should not throw.
      await expectLater(
        verifyAfterWrite(
          label: 'test',
          save: (d) async => storage.save(d),
          reload: () => storage.load(),
          data: data,
        ),
        completes,
      );

      // Verify data was persisted.
      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 1);
    });

    test('throws after retry when reload always returns null', () async {
      var saveCount = 0;

      await expectLater(
        verifyAfterWrite(
          label: 'null-test',
          save: (_) async {
            saveCount++;
          },
          reload: () async => null,
          data: {'key': 'value'},
        ),
        throwsA(isA<StorageWriteVerificationException>()),
      );

      // Should have saved twice (initial + 1 retry).
      expect(saveCount, 2);
    });

    test('throws when reload returns different data each time', () async {
      var callIndex = 0;

      await expectLater(
        verifyAfterWrite(
          label: 'mismatch-test',
          save: (_) async {},
          reload: () async {
            callIndex++;
            return {'call': callIndex};
          },
          data: {'key': 'value'},
        ),
        throwsA(isA<StorageWriteVerificationException>()),
      );
    });

    test(
      'retries once on first mismatch then succeeds on second attempt',
      () async {
        var saveCallCount = 0;
        var loadCallIndex = 0;

        // First save: snapshot and verify both get index 1 and 2 (mismatch).
        // Retry (second save): snapshot and verify both get index 3 and 4 (but we
        // need them to match). Let's make it so after the first save attempt,
        // loads return consistent data.
        final stableData = {'stable': true};

        await verifyAfterWrite(
          label: 'retry-success',
          save: (_) async {
            saveCallCount++;
          },
          reload: () async {
            loadCallIndex++;
            // After first save (saveCallCount >= 1), return stable data so
            // the retry succeeds.
            if (saveCallCount >= 2) return stableData;
            return {'unstable': loadCallIndex};
          },
          data: {'key': 'value'},
        );

        // Should have saved twice (initial + 1 retry).
        expect(saveCallCount, 2);
      },
    );

    test(
      'retry succeeds when first attempt null then second matches data',
      () async {
        var saveCount = 0;
        final data = <String, Object?>{'retry': 'test'};

        await verifyAfterWrite(
          label: 'null-then-match',
          save: (_) async {
            saveCount++;
          },
          reload: () async {
            // After second save (retry), return the correct data.
            if (saveCount >= 2) return data;
            return null;
          },
          data: data,
        );

        expect(saveCount, 2);
      },
    );

    test('large data round-trip verification succeeds', () async {
      final storage = SqliteAppWorkspaceStorage(dbPath: dbPath);
      final bigData = <String, Object?>{
        'projects': List<Map<String, Object?>>.generate(
          500,
          (i) => {
            'id': 'proj-$i',
            'sceneId': 'scene-$i',
            'title': '项目$i — ${'x' * 100}',
            'genre': 'test',
            'summary': 's' * 200,
            'recentLocation': 'loc',
            'lastOpenedAtMs': i,
          },
        ),
      };

      await expectLater(
        verifyAfterWrite(
          label: 'large-data',
          save: (d) async => storage.save(d),
          reload: () => storage.load(),
          data: bigData,
        ),
        completes,
      );

      final loaded = await storage.load();
      expect(loaded, isNotNull);
      final projects = loaded!['projects'] as List<Object?>;
      expect(projects.length, 500);
    });

    test('exception contains correct diagnostic info', () async {
      var callIndex = 0;
      try {
        await verifyAfterWrite(
          label: 'diag-test',
          save: (_) async {},
          reload: () async {
            callIndex++;
            return {
              'call': callIndex,
            }; // Each call returns different data → mismatch
          },
          data: {'expected': true},
        );
        fail('Should have thrown');
      } on StorageWriteVerificationException catch (e) {
        expect(e.label, 'diag-test');
        expect(e.attempts, 2);
      }
    });
  });
}
