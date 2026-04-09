import 'package:freezed_annotation/freezed_annotation.dart';

part 'location.freezed.dart';
part 'location.g.dart';

/// 地点
@freezed
class Location with _$Location {
  const Location._();

  const factory Location({
    required String id,
    required String workId,
    required String name,
    String? type,
    String? parentId,
    String? description,
    @Default([]) List<String> importantPlaces,
    @Default([]) List<String> characterIds,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Location;

  factory Location.fromJson(Map<String, dynamic> json) => _$LocationFromJson(json);

  /// 是否是顶级地点
  bool get isTopLevel => parentId == null;
}

/// 地点类型
enum LocationType {
  continent('大陆'),
  country('国家'),
  city('城市'),
  region('区域'),
  building('建筑'),
  room('房间'),
  other('其他');

  const LocationType(this.label);
  final String label;
}

/// 地点-角色关联
@freezed
class LocationCharacter with _$LocationCharacter {
  const factory LocationCharacter({
    required String id,
    required String locationId,
    required String characterId,
    String? relationship,
    String? startChapterId,
    String? endChapterId,
    @Default('active') String status,
    required DateTime createdAt,
  }) = _LocationCharacter;

  factory LocationCharacter.fromJson(Map<String, dynamic> json) =>
      _$LocationCharacterFromJson(json);
}
