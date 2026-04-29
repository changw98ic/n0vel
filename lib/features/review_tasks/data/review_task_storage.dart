import '../../../app/state/project_storage.dart';
import 'review_task_storage_stub.dart'
    if (dart.library.io) 'review_task_storage_io.dart';

abstract class ReviewTaskStorage extends ProjectStorage {}

class InMemoryReviewTaskStorage extends InMemoryProjectStorage
    implements ReviewTaskStorage {}

ReviewTaskStorage createDefaultReviewTaskStorage() => createReviewTaskStorage();
