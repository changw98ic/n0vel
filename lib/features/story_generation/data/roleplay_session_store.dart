import 'scene_roleplay_session_models.dart';

abstract interface class RoleplaySessionStore {
  Future<void> saveSession({
    required String projectId,
    required SceneRoleplaySession session,
  });

  Future<SceneRoleplaySession?> loadSession({
    required String projectId,
    required String chapterId,
    required String sceneId,
  });

  Future<List<SceneRoleplaySession>> loadChapterSessions({
    required String projectId,
    required String chapterId,
  });

  Future<void> clearProject(String projectId);
}
