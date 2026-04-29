import 'project_storage.dart';
import 'story_generation_storage_stub.dart'
    if (dart.library.io) 'story_generation_storage_io.dart';

abstract class StoryGenerationStorage extends ProjectStorage {}

class InMemoryStoryGenerationStorage extends InMemoryProjectStorage
    implements StoryGenerationStorage {}

StoryGenerationStorage createDefaultStoryGenerationStorage() =>
    createStoryGenerationStorage();
