/// 路由名称常量
///
/// 所有路由名统一定义在此，避免硬编码字符串。
abstract class AppRoutes {
  static const root = '/';
  static const search = '/search';
  static const workDetail = '/work/:id';
  static const workSettings = '/work/:id/settings';
  static const workCharacters = '/work/:id/characters';
  static const workCharacterNew = '/work/:id/characters/new';
  static const workCharacterDetail = '/work/:workId/characters/:characterId';
  static const workRelationships = '/work/:id/relationships';
  static const workItems = '/work/:id/items';
  static const workLocations = '/work/:id/locations';
  static const workFactions = '/work/:id/factions';
  static const chapterEditor = '/work/:workId/chapter/:chapterId';
  static const review = '/work/:id/review';
  static const aiDetection = '/ai-detection';
  static const timeline = '/work/:id/timeline';
  static const pov = '/work/:id/pov';
  static const stats = '/work/:id/stats';
  static const read = '/work/:id/read';
  static const aiConfig = '/ai-config';
  static const aiUsageStats = '/work/:id/ai-usage-stats';
  static const workEdit = '/work/:id/edit';
  static const workNew = '/work/new';
  static const workflowTasks = '/workflow/tasks/:workId';
  static const workflowTask = '/workflow/task/:taskId';
}
