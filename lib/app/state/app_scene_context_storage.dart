import 'project_storage.dart';
import 'app_scene_context_storage_stub.dart'
    if (dart.library.io) 'app_scene_context_storage_io.dart';

abstract class AppSceneContextStorage extends ProjectStorage {}

class InMemoryAppSceneContextStorage extends InMemoryProjectStorage
    implements AppSceneContextStorage {}

AppSceneContextStorage createDefaultAppSceneContextStorage() =>
    createAppSceneContextStorage();
