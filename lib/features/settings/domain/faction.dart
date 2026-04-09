import 'package:freezed_annotation/freezed_annotation.dart';

part 'faction.freezed.dart';
part 'faction.g.dart';

/// 势力/组织
@freezed
class Faction with _$Faction {
  const Faction._();

  const factory Faction({
    required String id,
    required String workId,
    required String name,
    String? type,
    String? emblemPath,
    String? description,
    @Default([]) List<String> traits,
    String? leaderId,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Faction;

  factory Faction.fromJson(Map<String, dynamic> json) => _$FactionFromJson(json);
}

/// 势力类型
enum FactionType {
  sect('宗门'),
  guild('公会'),
  empire('帝国'),
  kingdom('王国'),
  organization('组织'),
  clan('家族'),
  gang('帮派'),
  other('其他');

  const FactionType(this.label);
  final String label;
}

/// 势力-成员关联
@freezed
class FactionMember with _$FactionMember {
  const factory FactionMember({
    required String id,
    required String factionId,
    required String characterId,
    String? role,
    String? joinChapterId,
    String? leaveChapterId,
    @Default('active') String status,
    required DateTime createdAt,
  }) = _FactionMember;

  factory FactionMember.fromJson(Map<String, dynamic> json) =>
      _$FactionMemberFromJson(json);
}
