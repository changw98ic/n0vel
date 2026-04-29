import 'project_storage.dart';
import 'story_outline_storage_stub.dart'
    if (dart.library.io) 'story_outline_storage_io.dart';

abstract class StoryOutlineStorage extends ProjectStorage {}

class InMemoryStoryOutlineStorage extends InMemoryProjectStorage
    implements StoryOutlineStorage {}

StoryOutlineStorage createDefaultStoryOutlineStorage() =>
    createStoryOutlineStorage();
