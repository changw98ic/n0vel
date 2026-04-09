import 'dart:convert';

import 'package:drift/drift.dart';

/// JSON 转换器 - 用于存储 Map 类型
class JsonConverter<T> extends TypeConverter<T?, String> {
  final T Function(Map<String, dynamic>) fromJson;

  JsonConverter(this.fromJson);

  @override
  T? fromSql(String fromDb) {
    if (fromDb.isEmpty) return null;
    final json = jsonDecode(fromDb) as Map<String, dynamic>;
    return fromJson(json);
  }

  @override
  String toSql(T? value) {
    if (value == null) return '';
    final map = (value as dynamic).toJson() as Map<String, dynamic>;
    return jsonEncode(map);
  }
}

/// JSON List 转换器 - 用于存储 List 类型
class JsonListConverter<T> extends TypeConverter<List<T>?, String> {
  final T Function(Map<String, dynamic>) fromJson;

  JsonListConverter(this.fromJson);

  @override
  List<T>? fromSql(String fromDb) {
    if (fromDb.isEmpty) return null;
    final list = jsonDecode(fromDb) as List;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  String toSql(List<T>? value) {
    if (value == null) return '';
    final list = value.map((e) => (e as dynamic).toJson()).toList();
    return jsonEncode(list);
  }
}

/// 字符串列表转换器 - 用于存储 List<String>
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    final list = jsonDecode(fromDb) as List;
    return list.cast<String>();
  }

  @override
  String toSql(List<String> value) {
    return jsonEncode(value);
  }
}

/// 字符串 Map 转换器 - 用于存储 Map<String, dynamic>
class StringMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const StringMapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    if (fromDb.isEmpty) return {};
    return jsonDecode(fromDb) as Map<String, dynamic>;
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}
