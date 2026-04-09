// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'prompt_template.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

PromptTemplate _$PromptTemplateFromJson(Map<String, dynamic> json) {
  return _PromptTemplate.fromJson(json);
}

/// @nodoc
mixin _$PromptTemplate {
  String get id => throw _privateConstructorUsedError;
  String get functionType =>
      throw _privateConstructorUsedError; // 对应 AIFunction.key
  String get name => throw _privateConstructorUsedError;
  String get systemPrompt => throw _privateConstructorUsedError;
  String get userPromptTemplate => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  List<String> get variables => throw _privateConstructorUsedError; // 模板变量列表
  int get version => throw _privateConstructorUsedError;
  bool get isDefault => throw _privateConstructorUsedError;
  bool get isBuiltIn => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $PromptTemplateCopyWith<PromptTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromptTemplateCopyWith<$Res> {
  factory $PromptTemplateCopyWith(
          PromptTemplate value, $Res Function(PromptTemplate) then) =
      _$PromptTemplateCopyWithImpl<$Res, PromptTemplate>;
  @useResult
  $Res call(
      {String id,
      String functionType,
      String name,
      String systemPrompt,
      String userPromptTemplate,
      String? description,
      List<String> variables,
      int version,
      bool isDefault,
      bool isBuiltIn,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class _$PromptTemplateCopyWithImpl<$Res, $Val extends PromptTemplate>
    implements $PromptTemplateCopyWith<$Res> {
  _$PromptTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? functionType = null,
    Object? name = null,
    Object? systemPrompt = null,
    Object? userPromptTemplate = null,
    Object? description = freezed,
    Object? variables = null,
    Object? version = null,
    Object? isDefault = null,
    Object? isBuiltIn = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      functionType: null == functionType
          ? _value.functionType
          : functionType // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      systemPrompt: null == systemPrompt
          ? _value.systemPrompt
          : systemPrompt // ignore: cast_nullable_to_non_nullable
              as String,
      userPromptTemplate: null == userPromptTemplate
          ? _value.userPromptTemplate
          : userPromptTemplate // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      variables: null == variables
          ? _value.variables
          : variables // ignore: cast_nullable_to_non_nullable
              as List<String>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      isDefault: null == isDefault
          ? _value.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      isBuiltIn: null == isBuiltIn
          ? _value.isBuiltIn
          : isBuiltIn // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PromptTemplateImplCopyWith<$Res>
    implements $PromptTemplateCopyWith<$Res> {
  factory _$$PromptTemplateImplCopyWith(_$PromptTemplateImpl value,
          $Res Function(_$PromptTemplateImpl) then) =
      __$$PromptTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String functionType,
      String name,
      String systemPrompt,
      String userPromptTemplate,
      String? description,
      List<String> variables,
      int version,
      bool isDefault,
      bool isBuiltIn,
      DateTime? createdAt,
      DateTime? updatedAt});
}

/// @nodoc
class __$$PromptTemplateImplCopyWithImpl<$Res>
    extends _$PromptTemplateCopyWithImpl<$Res, _$PromptTemplateImpl>
    implements _$$PromptTemplateImplCopyWith<$Res> {
  __$$PromptTemplateImplCopyWithImpl(
      _$PromptTemplateImpl _value, $Res Function(_$PromptTemplateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? functionType = null,
    Object? name = null,
    Object? systemPrompt = null,
    Object? userPromptTemplate = null,
    Object? description = freezed,
    Object? variables = null,
    Object? version = null,
    Object? isDefault = null,
    Object? isBuiltIn = null,
    Object? createdAt = freezed,
    Object? updatedAt = freezed,
  }) {
    return _then(_$PromptTemplateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      functionType: null == functionType
          ? _value.functionType
          : functionType // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      systemPrompt: null == systemPrompt
          ? _value.systemPrompt
          : systemPrompt // ignore: cast_nullable_to_non_nullable
              as String,
      userPromptTemplate: null == userPromptTemplate
          ? _value.userPromptTemplate
          : userPromptTemplate // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      variables: null == variables
          ? _value._variables
          : variables // ignore: cast_nullable_to_non_nullable
              as List<String>,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as int,
      isDefault: null == isDefault
          ? _value.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
      isBuiltIn: null == isBuiltIn
          ? _value.isBuiltIn
          : isBuiltIn // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PromptTemplateImpl extends _PromptTemplate {
  const _$PromptTemplateImpl(
      {required this.id,
      required this.functionType,
      required this.name,
      required this.systemPrompt,
      required this.userPromptTemplate,
      this.description,
      final List<String> variables = const [],
      this.version = 1,
      this.isDefault = false,
      this.isBuiltIn = false,
      this.createdAt,
      this.updatedAt})
      : _variables = variables,
        super._();

  factory _$PromptTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$PromptTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String functionType;
// 对应 AIFunction.key
  @override
  final String name;
  @override
  final String systemPrompt;
  @override
  final String userPromptTemplate;
  @override
  final String? description;
  final List<String> _variables;
  @override
  @JsonKey()
  List<String> get variables {
    if (_variables is EqualUnmodifiableListView) return _variables;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_variables);
  }

// 模板变量列表
  @override
  @JsonKey()
  final int version;
  @override
  @JsonKey()
  final bool isDefault;
  @override
  @JsonKey()
  final bool isBuiltIn;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  @override
  String toString() {
    return 'PromptTemplate(id: $id, functionType: $functionType, name: $name, systemPrompt: $systemPrompt, userPromptTemplate: $userPromptTemplate, description: $description, variables: $variables, version: $version, isDefault: $isDefault, isBuiltIn: $isBuiltIn, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromptTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.functionType, functionType) ||
                other.functionType == functionType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.systemPrompt, systemPrompt) ||
                other.systemPrompt == systemPrompt) &&
            (identical(other.userPromptTemplate, userPromptTemplate) ||
                other.userPromptTemplate == userPromptTemplate) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality()
                .equals(other._variables, _variables) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.isBuiltIn, isBuiltIn) ||
                other.isBuiltIn == isBuiltIn) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      functionType,
      name,
      systemPrompt,
      userPromptTemplate,
      description,
      const DeepCollectionEquality().hash(_variables),
      version,
      isDefault,
      isBuiltIn,
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$PromptTemplateImplCopyWith<_$PromptTemplateImpl> get copyWith =>
      __$$PromptTemplateImplCopyWithImpl<_$PromptTemplateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PromptTemplateImplToJson(
      this,
    );
  }
}

abstract class _PromptTemplate extends PromptTemplate {
  const factory _PromptTemplate(
      {required final String id,
      required final String functionType,
      required final String name,
      required final String systemPrompt,
      required final String userPromptTemplate,
      final String? description,
      final List<String> variables,
      final int version,
      final bool isDefault,
      final bool isBuiltIn,
      final DateTime? createdAt,
      final DateTime? updatedAt}) = _$PromptTemplateImpl;
  const _PromptTemplate._() : super._();

  factory _PromptTemplate.fromJson(Map<String, dynamic> json) =
      _$PromptTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get functionType;
  @override // 对应 AIFunction.key
  String get name;
  @override
  String get systemPrompt;
  @override
  String get userPromptTemplate;
  @override
  String? get description;
  @override
  List<String> get variables;
  @override // 模板变量列表
  int get version;
  @override
  bool get isDefault;
  @override
  bool get isBuiltIn;
  @override
  DateTime? get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$PromptTemplateImplCopyWith<_$PromptTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
