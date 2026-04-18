// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'work.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Work _$WorkFromJson(Map<String, dynamic> json) {
  return _Work.fromJson(json);
}

/// @nodoc
mixin _$Work {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String? get type => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get coverPath => throw _privateConstructorUsedError;
  int? get targetWords => throw _privateConstructorUsedError;
  int get currentWords => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  bool get isPinned => throw _privateConstructorUsedError;
  bool get isArchived => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Work to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Work
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WorkCopyWith<Work> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WorkCopyWith<$Res> {
  factory $WorkCopyWith(Work value, $Res Function(Work) then) =
      _$WorkCopyWithImpl<$Res, Work>;
  @useResult
  $Res call({
    String id,
    String name,
    String? type,
    String? description,
    String? coverPath,
    int? targetWords,
    int currentWords,
    String status,
    bool isPinned,
    bool isArchived,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$WorkCopyWithImpl<$Res, $Val extends Work>
    implements $WorkCopyWith<$Res> {
  _$WorkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Work
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = freezed,
    Object? description = freezed,
    Object? coverPath = freezed,
    Object? targetWords = freezed,
    Object? currentWords = null,
    Object? status = null,
    Object? isPinned = null,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            type: freezed == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            coverPath: freezed == coverPath
                ? _value.coverPath
                : coverPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            targetWords: freezed == targetWords
                ? _value.targetWords
                : targetWords // ignore: cast_nullable_to_non_nullable
                      as int?,
            currentWords: null == currentWords
                ? _value.currentWords
                : currentWords // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            isPinned: null == isPinned
                ? _value.isPinned
                : isPinned // ignore: cast_nullable_to_non_nullable
                      as bool,
            isArchived: null == isArchived
                ? _value.isArchived
                : isArchived // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WorkImplCopyWith<$Res> implements $WorkCopyWith<$Res> {
  factory _$$WorkImplCopyWith(
    _$WorkImpl value,
    $Res Function(_$WorkImpl) then,
  ) = __$$WorkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String? type,
    String? description,
    String? coverPath,
    int? targetWords,
    int currentWords,
    String status,
    bool isPinned,
    bool isArchived,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$WorkImplCopyWithImpl<$Res>
    extends _$WorkCopyWithImpl<$Res, _$WorkImpl>
    implements _$$WorkImplCopyWith<$Res> {
  __$$WorkImplCopyWithImpl(_$WorkImpl _value, $Res Function(_$WorkImpl) _then)
    : super(_value, _then);

  /// Create a copy of Work
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? type = freezed,
    Object? description = freezed,
    Object? coverPath = freezed,
    Object? targetWords = freezed,
    Object? currentWords = null,
    Object? status = null,
    Object? isPinned = null,
    Object? isArchived = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$WorkImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        type: freezed == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        coverPath: freezed == coverPath
            ? _value.coverPath
            : coverPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        targetWords: freezed == targetWords
            ? _value.targetWords
            : targetWords // ignore: cast_nullable_to_non_nullable
                  as int?,
        currentWords: null == currentWords
            ? _value.currentWords
            : currentWords // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        isPinned: null == isPinned
            ? _value.isPinned
            : isPinned // ignore: cast_nullable_to_non_nullable
                  as bool,
        isArchived: null == isArchived
            ? _value.isArchived
            : isArchived // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$WorkImpl extends _Work {
  const _$WorkImpl({
    required this.id,
    required this.name,
    this.type,
    this.description,
    this.coverPath,
    this.targetWords,
    this.currentWords = 0,
    this.status = 'draft',
    this.isPinned = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  }) : super._();

  factory _$WorkImpl.fromJson(Map<String, dynamic> json) =>
      _$$WorkImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String? type;
  @override
  final String? description;
  @override
  final String? coverPath;
  @override
  final int? targetWords;
  @override
  @JsonKey()
  final int currentWords;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final bool isPinned;
  @override
  @JsonKey()
  final bool isArchived;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Work(id: $id, name: $name, type: $type, description: $description, coverPath: $coverPath, targetWords: $targetWords, currentWords: $currentWords, status: $status, isPinned: $isPinned, isArchived: $isArchived, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WorkImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.coverPath, coverPath) ||
                other.coverPath == coverPath) &&
            (identical(other.targetWords, targetWords) ||
                other.targetWords == targetWords) &&
            (identical(other.currentWords, currentWords) ||
                other.currentWords == currentWords) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.isArchived, isArchived) ||
                other.isArchived == isArchived) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    type,
    description,
    coverPath,
    targetWords,
    currentWords,
    status,
    isPinned,
    isArchived,
    createdAt,
    updatedAt,
  );

  /// Create a copy of Work
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WorkImplCopyWith<_$WorkImpl> get copyWith =>
      __$$WorkImplCopyWithImpl<_$WorkImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$WorkImplToJson(this);
  }
}

abstract class _Work extends Work {
  const factory _Work({
    required final String id,
    required final String name,
    final String? type,
    final String? description,
    final String? coverPath,
    final int? targetWords,
    final int currentWords,
    final String status,
    final bool isPinned,
    final bool isArchived,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$WorkImpl;
  const _Work._() : super._();

  factory _Work.fromJson(Map<String, dynamic> json) = _$WorkImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String? get type;
  @override
  String? get description;
  @override
  String? get coverPath;
  @override
  int? get targetWords;
  @override
  int get currentWords;
  @override
  String get status;
  @override
  bool get isPinned;
  @override
  bool get isArchived;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Work
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WorkImplCopyWith<_$WorkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
