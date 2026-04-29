import 'package:novel_writer/app/state/app_settings_store.dart';

import '../domain/scene_models.dart';
import 'role_turn_skill.dart';

class RoleSkillRegistry {
  RoleSkillRegistry({required AppSettingsStore settingsStore})
    : _basic = BasicRoleTurnSkill(settingsStore: settingsStore);

  final RoleTurnSkill _basic;

  RoleTurnSkill resolve({
    required ResolvedSceneCastMember member,
    Map<String, Object?> metadata = const {},
  }) {
    final skillId = _skillIdFor(member: member, metadata: metadata);
    return switch (skillId) {
      'basic_role_turn' || '' => _basic,
      _ => _basic,
    };
  }

  String _skillIdFor({
    required ResolvedSceneCastMember member,
    required Map<String, Object?> metadata,
  }) {
    final roleSkillIds = metadata['roleSkillIds'];
    if (roleSkillIds is Map) {
      final value = roleSkillIds[member.characterId];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    final defaultSkillId = metadata['defaultRoleSkillId'];
    if (defaultSkillId is String && defaultSkillId.trim().isNotEmpty) {
      return defaultSkillId.trim();
    }
    return 'basic_role_turn';
  }
}
