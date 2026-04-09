import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

/// 物品
@freezed
class Item with _$Item {
  const Item._();

  const factory Item({
    required String id,
    required String workId,
    required String name,
    String? type,
    String? rarity,
    String? iconPath,
    String? description,
    @Default([]) List<String> abilities,
    String? holderId,
    @Default(false) bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}

/// 物品类型
enum ItemType {
  weapon('武器'),
  armor('防具'),
  accessory('饰品'),
  consumable('消耗品'),
  material('材料'),
  key('关键道具'),
  other('其他');

  const ItemType(this.label);
  final String label;
}

/// 物品品级
enum ItemRarity {
  common('普通'),
  uncommon('优秀'),
  rare('稀有'),
  epic('史诗'),
  legendary('传说'),
  mythic('神话');

  const ItemRarity(this.label);
  final String label;

  Color get color => switch (this) {
    common => Colors.grey,
    uncommon => Colors.green,
    rare => Colors.blue,
    epic => Colors.purple,
    legendary => Colors.orange,
    mythic => Colors.red,
  };
}
