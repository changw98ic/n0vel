import 'app_simulation_storage.dart';

class _NoopAppSimulationStorage implements AppSimulationStorage {
  @override
  Future<void> clear({String? projectId}) async {}

  @override
  Future<Map<String, Object?>?> load({required String projectId}) async => null;

  @override
  Future<void> save(
    Map<String, Object?> data, {
    required String projectId,
  }) async {}
}

AppSimulationStorage createAppSimulationStorage() =>
    _NoopAppSimulationStorage();
