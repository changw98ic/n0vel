import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/state/cached_project_storage.dart';
import 'package:novel_writer/app/state/project_storage.dart';

/// Recording delegate that tracks every [save] call it receives.
class _RecordingStorage implements ProjectStorage {
  final List<_SaveCall> saves = [];

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async => null;

  @override
  Future<void> save(Map<String, Object?> data, {required String projectId}) async {
    saves.add(_SaveCall(projectId, Map<String, Object?>.from(data)));
  }

  @override
  Future<void> clear({String? projectId}) async {}
}

class _SaveCall {
  final String projectId;
  final Map<String, Object?> data;
  _SaveCall(this.projectId, this.data);
}

void main() {
  test('dispose flushes pending writes to delegate before returning', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(delegate, writeDelay: const Duration(milliseconds: 10));

    await storage.save({'title': 'hello'}, projectId: 'p1');
    // Only one pending write — timer has not fired yet.
    expect(delegate.saves, isEmpty);

    await storage.dispose();

    // Dispose must flush the last pending save so no data is lost.
    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.first.projectId, 'p1');
    expect(delegate.saves.first.data['title'], 'hello');
  });

  test('flush before dispose writes pending data to delegate', () async {
    final delegate = _RecordingStorage();
    final storage = CachedProjectStorage(delegate, writeDelay: const Duration(milliseconds: 10));

    await storage.save({'title': 'hello'}, projectId: 'p1');
    await storage.flush();
    storage.dispose();

    expect(delegate.saves, hasLength(1));
    expect(delegate.saves.first.projectId, 'p1');
    expect(delegate.saves.first.data['title'], 'hello');
  });
}
