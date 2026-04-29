import 'project_storage.dart';
import 'app_ai_history_storage_stub.dart'
    if (dart.library.io) 'app_ai_history_storage_io.dart';

abstract class AppAiHistoryStorage extends ProjectStorage {}

class InMemoryAppAiHistoryStorage extends InMemoryProjectStorage
    implements AppAiHistoryStorage {}

AppAiHistoryStorage createDefaultAppAiHistoryStorage() =>
    createAppAiHistoryStorage();
