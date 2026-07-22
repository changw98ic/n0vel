import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/cached_project_storage.dart';
import 'package:novel_writer/app/state/project_storage.dart';

/// Recording delegate that tracks every [save] call it receives.
class _RecordingStorage implements ProjectStorage {
  final List<_SaveCall> saves = [];
  final List<String> clears = [];
  int failuresRemaining = 0;
  Object failure = StateError('injected save failure');

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async => null;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw failure;
    }
    saves.add(_SaveCall(projectId, Map<String, Object?>.from(data)));
  }

  @override
  Future<void> clear({String? projectId}) async {
    clears.add(projectId ?? '*');
  }

  @override
  Future<void> clearProject(String projectId) async {
    clears.add('$projectId::project');
  }
}

class _SaveCall {
  final String projectId;
  final Map<String, Object?> data;
  _SaveCall(this.projectId, this.data);
}

class _BlockingFailureStorage extends _RecordingStorage {
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();
  bool _blockFirstWrite = true;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {
    if (_blockFirstWrite) {
      _blockFirstWrite = false;
      started.complete();
      await release.future;
      throw failure;
    }
    await super.save(data, projectId: projectId);
  }
}

void main() {
  test('save Future waits for durable delegate write', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(
      delegate,
      writeDelay: const Duration(milliseconds: 20),
    );

    var completed = false;
    final save = storage.save({'title': 'hello'}, projectId: 'p1');
    unawaited(save.then((_) => completed = true));
    await Future<void>.delayed(Duration.zero);

    expect(delegate.saves, isEmpty);
    expect(completed, isFalse);
    expect(storage.requestedRevisionFor('p1'), 1);
    expect(storage.durableRevisionFor('p1'), 0);

    await storage.flush();
    await save;

    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.first.projectId, 'p1');
    expect(delegate.saves.first.data['title'], 'hello');
    expect(completed, isTrue);
    expect(storage.durableRevisionFor('p1'), 1);
    await storage.dispose();
  });

  test('rapid saves coalesce while every revision waiter completes', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(
      delegate,
      writeDelay: const Duration(milliseconds: 20),
    );

    final first = storage.save({'title': 'first'}, projectId: 'p1');
    final second = storage.save({'title': 'second'}, projectId: 'p1');
    final third = storage.save({'title': 'third'}, projectId: 'p1');

    await storage.flush();
    await Future.wait([first, second, third]);

    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.single.data['title'], 'third');
    expect(storage.requestedRevisionFor('p1'), 3);
    expect(storage.durableRevisionFor('p1'), 3);
    await storage.dispose();
  });

  test(
    'delegate failure keeps latest pending snapshot for a later retry',
    () async {
      final delegate = _RecordingStorage()..failuresRemaining = 2;
      final storage = CachedProjectStorage(
        delegate,
        writeDelay: Duration.zero,
        maxRetries: 1,
      );

      final save = storage.save({'title': 'retry me'}, projectId: 'p1');
      await expectLater(
        save,
        throwsA(
          isA<CachedProjectStorageWriteException>().having(
            (error) => error.revision,
            'revision',
            1,
          ),
        ),
      );

      expect(delegate.saves, isEmpty);
      expect(storage.hasPendingWriteFor('p1'), isTrue);
      expect(storage.durableRevisionFor('p1'), 0);

      await storage.flush();

      expect(delegate.saves, hasLength(1));
      expect(delegate.saves.single.data['title'], 'retry me');
      expect(storage.durableRevisionFor('p1'), 1);
      expect(storage.hasPendingWriteFor('p1'), isFalse);
      await storage.dispose();
    },
  );

  test(
    'older failed revision does not fail a newer pending revision',
    () async {
      final delegate = _BlockingFailureStorage();
      final storage = CachedProjectStorage(
        delegate,
        writeDelay: Duration.zero,
        maxRetries: 0,
      );

      final first = storage.save({'title': 'old'}, projectId: 'p1');
      await delegate.started.future;
      final second = storage.save({'title': 'new'}, projectId: 'p1');
      delegate.release.complete();

      await expectLater(
        first,
        throwsA(
          isA<CachedProjectStorageWriteException>().having(
            (error) => error.revision,
            'revision',
            1,
          ),
        ),
      );
      var secondCompleted = false;
      unawaited(second.then((_) => secondCompleted = true));
      await Future<void>.delayed(Duration.zero);
      expect(secondCompleted, isFalse);
      expect(storage.hasPendingWriteFor('p1'), isTrue);

      await storage.flush();
      await second;
      expect(delegate.saves, hasLength(1));
      expect(delegate.saves.single.data['title'], 'new');
      expect(storage.durableRevisionFor('p1'), 2);
      await storage.dispose();
    },
  );

  test('clearProject does not cancel another project timer', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(
      delegate,
      writeDelay: const Duration(milliseconds: 10),
    );

    final p1Save = storage.save({'title': 'deleted'}, projectId: 'p1');
    final p2Save = storage.save({'title': 'kept'}, projectId: 'p2');
    unawaited(p1Save.catchError((_) {}));

    await storage.clearProject('p1');
    await p2Save;

    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.single.projectId, 'p2');
    expect(delegate.clears, contains('p1::project'));
    expect(storage.hasPendingWriteFor('p1'), isFalse);
    expect(storage.hasPendingWriteFor('p2'), isFalse);
    await storage.dispose();
  });

  test('dispose flushes pending writes before returning', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(
      delegate,
      writeDelay: const Duration(milliseconds: 10),
    );

    final save = storage.save({'title': 'hello'}, projectId: 'p1');
    await storage.dispose();
    await save;

    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.first.projectId, 'p1');
    expect(delegate.saves.first.data['title'], 'hello');
  });

  test('discard cancels deferred writes without flushing them', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(
      delegate,
      writeDelay: const Duration(milliseconds: 20),
    );

    final save = storage.save({'title': 'discarded'}, projectId: 'p1');
    unawaited(save.catchError((_) {}));
    storage.discard();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(delegate.saves, isEmpty);
    expect(storage.hasPendingWriteFor('p1'), isFalse);
  });

  test('flush before dispose writes pending data to delegate', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(
      delegate,
      writeDelay: const Duration(milliseconds: 10),
    );

    final save = storage.save({'title': 'hello'}, projectId: 'p1');
    await storage.flush();
    await save;
    await storage.dispose();

    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.first.projectId, 'p1');
    expect(delegate.saves.first.data['title'], 'hello');
  });
}
