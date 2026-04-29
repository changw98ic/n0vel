import '../../../app/state/project_storage.dart';
import 'author_feedback_storage_stub.dart'
    if (dart.library.io) 'author_feedback_storage_io.dart';

abstract class AuthorFeedbackStorage extends ProjectStorage {}

class InMemoryAuthorFeedbackStorage extends InMemoryProjectStorage
    implements AuthorFeedbackStorage {}

AuthorFeedbackStorage createDefaultAuthorFeedbackStorage() =>
    createAuthorFeedbackStorage();
