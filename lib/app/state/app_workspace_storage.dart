import 'singleton_storage.dart';
import 'app_workspace_storage_stub.dart'
    if (dart.library.io) 'app_workspace_storage_io.dart';

abstract class AppWorkspaceStorage extends SingletonStorage {}

class InMemoryAppWorkspaceStorage extends InMemorySingletonStorage
    implements AppWorkspaceStorage {}

AppWorkspaceStorage createDefaultAppWorkspaceStorage() =>
    createAppWorkspaceStorage();
