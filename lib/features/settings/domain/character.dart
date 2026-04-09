import 'package:freezed_annotation/freezed_annotation.dart';

part 'character.freezed.dart';
part 'character.g.dart';

/// 角色分级
enum CharacterTier {
  protagonist('主角', 0),
  majorAntagonist('主要反派', 1),
  antagonist('反派', 2),
  supporting('配角', 3),
  minor('龙套', 4);

  const CharacterTier(this.label, this.priority);

  final String label;
  final int priority;

  /// 是否需要深度档案
  bool get requiresProfile =>
      this == CharacterTier.protagonist ||
      this == CharacterTier.majorAntagonist ||
      this == CharacterTier.antagonist;
}

/// 生命状态
enum LifeStatus {
  alive('存活'),
  dead('死亡'),
  missing('失踪'),
  unknown('未知');

  const LifeStatus(this.label);

  final String label;
}

/// 角色实体
@freezed
class Character with _$Character {
  const Character._();

  const factory Character({
    required String id,
    required String workId,
    required String name,
    @Default([]) List<String> aliases,
    required CharacterTier tier,
    String? avatarPath,
    String? gender,
    String? age,
    String? identity,
    String? bio,
    @Default(LifeStatus.alive) LifeStatus lifeStatus,
    String? deathChapterId,
    String? deathReason,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);
}

/// 创建角色参数
@freezed
class CreateCharacterParams with _$CreateCharacterParams {
  const factory CreateCharacterParams({
    required String workId,
    required String name,
    List<String>? aliases,
    required CharacterTier tier,
    String? avatarPath,
    String? gender,
    String? age,
    String? identity,
    String? bio,
  }) = _CreateCharacterParams;
}
