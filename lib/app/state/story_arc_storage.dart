import 'project_storage.dart';
import 'story_arc_storage_stub.dart'
    if (dart.library.io) 'story_arc_storage_io.dart';

/// 故事弧线状态持久化抽象层
///
/// 存储 NarrativeArcState（情节线 + 伏笔追踪）的 JSON 数据，
/// 按 project_id 索引。
abstract class StoryArcStorage extends ProjectStorage {}

class InMemoryStoryArcStorage extends InMemoryProjectStorage
    implements StoryArcStorage {}

StoryArcStorage createDefaultStoryArcStorage() => createStoryArcStorage();
