import 'package:novel_writer/app/state/app_settings_store.dart';

import '../domain/scene_models.dart';
import 'role_skill_descriptor.dart';
import 'role_turn_skill.dart';

class RoleSkillRegistry {
  RoleSkillRegistry({
    required AppSettingsStore settingsStore,
    List<RoleTurnSkill> externalSkills = const [],
    List<RoleSkillDescriptor> externalDescriptors = const [],
  }) : _basic = BasicRoleTurnSkill(settingsStore: settingsStore) {
    _skillsById[_basic.skillId] = _basic;
    _descriptorsById[_basic.skillId] = _basic.descriptor;
    for (final skill in externalSkills) {
      _skillsById[skill.skillId] = skill;
      _descriptorsById[skill.skillId] = skill.descriptor;
    }
    for (final descriptor in externalDescriptors) {
      _descriptorsById[descriptor.skillId] = descriptor;
    }
  }

  final RoleTurnSkill _basic;
  final Map<String, RoleTurnSkill> _skillsById = <String, RoleTurnSkill>{};
  final Map<String, RoleSkillDescriptor> _descriptorsById =
      <String, RoleSkillDescriptor>{};

  List<RoleSkillDescriptor> get descriptors =>
      List<RoleSkillDescriptor>.unmodifiable(_descriptorsById.values);

  RoleTurnSkill resolve({
    required ResolvedSceneCastMember member,
    Map<String, Object?> metadata = const {},
  }) {
    final skillId = _skillIdFor(member: member, metadata: metadata);
    return _skillsById[_resolveSkillKey(skillId)] ?? _basic;
  }

  RoleSkillDescriptor resolveDescriptor({
    required ResolvedSceneCastMember member,
    Map<String, Object?> metadata = const {},
  }) {
    final skillId = _skillIdFor(member: member, metadata: metadata);
    return _descriptorsById[_resolveDescriptorKey(skillId)] ??
        _basic.descriptor;
  }

  void registerExternalSkill(RoleTurnSkill skill) {
    _skillsById[skill.skillId] = skill;
    _descriptorsById[skill.skillId] = skill.descriptor;
  }

  void registerExternalDescriptor(RoleSkillDescriptor descriptor) {
    _descriptorsById[descriptor.skillId] = descriptor;
  }

  void registerManifest(RoleSkillManifest manifest) {
    for (final descriptor in manifest.skills) {
      registerExternalDescriptor(descriptor);
    }
  }

  String _resolveSkillKey(String requested) {
    if (_skillsById.containsKey(requested)) return requested;
    final descriptorKey = _resolveDescriptorKey(requested);
    return _skillsById.containsKey(descriptorKey)
        ? descriptorKey
        : _basic.skillId;
  }

  String _resolveDescriptorKey(String requested) {
    if (_descriptorsById.containsKey(requested)) return requested;
    for (final entry in _descriptorsById.entries) {
      final descriptor = entry.value;
      if (descriptor.qualifiedId == requested) return entry.key;
      if (descriptor.compatibleSkillIds.contains(requested)) return entry.key;
    }
    final bareSkillId = requested.split('@').first;
    if (_descriptorsById.containsKey(bareSkillId)) return bareSkillId;
    return _basic.skillId;
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
