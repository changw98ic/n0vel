import 'package:novel_writer/domain/workspace_models.dart';

/// 角色关系持久化抽象接口
///
/// 支持一对多、多对多关系建模，提供 CRUD 操作和一致性校验。
abstract interface class CharacterRelationStorage {
  /// 保存一条关系（upsert 语义）
  ///
  /// 如果 [projectId, fromCharacterId, toCharacterId] 已存在则更新。
  Future<void> save(CharacterRelationRecord relation);

  /// 批量保存关系（upsert 语义）
  Future<void> saveAll(List<CharacterRelationRecord> relations);

  /// 加载指定项目的所有关系
  Future<List<CharacterRelationRecord>> loadByProject(String projectId);

  /// 加载指定角色作为出发方的所有关系
  Future<List<CharacterRelationRecord>> loadByFromCharacter(
    String projectId,
    String fromCharacterId,
  );

  /// 加载指定角色作为目标方的所有关系
  Future<List<CharacterRelationRecord>> loadByToCharacter(
    String projectId,
    String toCharacterId,
  );

  /// 加载涉及指定角色的所有关系（无论方向）
  Future<List<CharacterRelationRecord>> loadAllForCharacter(
    String projectId,
    String characterId,
  );

  /// 删除一条关系
  Future<bool> delete(
    String projectId,
    String fromCharacterId,
    String toCharacterId,
  );

  /// 删除指定项目的所有关系
  Future<void> clearProject(String projectId);

  /// 删除涉及指定角色的所有关系（清理孤儿数据）
  Future<int> clearForCharacter(String projectId, String characterId);

  /// 校验并修复数据一致性
  ///
  /// 返回修复操作的描述列表。
  Future<List<String>> validateAndRepair(
    String projectId,
    Set<String> existingCharacterIds,
  );
}
