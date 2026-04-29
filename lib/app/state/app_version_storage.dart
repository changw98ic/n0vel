import 'project_storage.dart';
import 'app_version_storage_stub.dart'
    if (dart.library.io) 'app_version_storage_io.dart';

abstract class AppVersionStorage extends ProjectStorage {}

class InMemoryAppVersionStorage extends InMemoryProjectStorage
    implements AppVersionStorage {}

AppVersionStorage createDefaultAppVersionStorage() => createAppVersionStorage();
