import 'project_storage.dart';
import 'app_simulation_storage_stub.dart'
    if (dart.library.io) 'app_simulation_storage_io.dart';

abstract class AppSimulationStorage extends ProjectStorage {}

class InMemoryAppSimulationStorage extends InMemoryProjectStorage
    implements AppSimulationStorage {}

AppSimulationStorage createDefaultAppSimulationStorage() =>
    createAppSimulationStorage();
