import 'project_storage.dart';
import 'app_draft_storage_stub.dart'
    if (dart.library.io) 'app_draft_storage_io.dart';

abstract class AppDraftStorage extends ProjectStorage {}

class InMemoryAppDraftStorage extends InMemoryProjectStorage
    implements AppDraftStorage {}

AppDraftStorage createDefaultAppDraftStorage() => createAppDraftStorage();
