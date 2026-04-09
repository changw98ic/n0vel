// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pov_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

POVTask _$POVTaskFromJson(Map<String, dynamic> json) {
  return _POVTask.fromJson(json);
}

/// @nodoc
mixin _$POVTask {
  String get id => throw _privateConstructorUsedError;
  String get workId => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  String get characterId => throw _privateConstructorUsedError;
  String get originalContent => throw _privateConstructorUsedError;
  POVConfig get config => throw _privateConstructorUsedError;
  POVTaskStatus get status => throw _privateConstructorUsedError;
  String? get generatedContent => throw _privateConstructorUsedError;
  String? get analysis => throw _privateConstructorUsedError;
  int get tokenUsage => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get completedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $POVTaskCopyWith<POVTask> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $POVTaskCopyWith<$Res> {
  factory $POVTaskCopyWith(POVTask value, $Res Function(POVTask) then) =
      _$POVTaskCopyWithImpl<$Res, POVTask>;
  @useResult
  $Res call(
      {String id,
      String workId,
      String chapterId,
      String characterId,
      String originalContent,
      POVConfig config,
      POVTaskStatus status,
      String? generatedContent,
      String? analysis,
      int tokenUsage,
      String? errorMessage,
      DateTime createdAt,
      DateTime? completedAt});

  $POVConfigCopyWith<$Res> get config;
}

/// @nodoc
class _$POVTaskCopyWithImpl<$Res, $Val extends POVTask>
    implements $POVTaskCopyWith<$Res> {
  _$POVTaskCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? chapterId = null,
    Object? characterId = null,
    Object? originalContent = null,
    Object? config = null,
    Object? status = null,
    Object? generatedContent = freezed,
    Object? analysis = freezed,
    Object? tokenUsage = null,
    Object? errorMessage = freezed,
    Object? createdAt = null,
    Object? completedAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      originalContent: null == originalContent
          ? _value.originalContent
          : originalContent // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as POVConfig,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as POVTaskStatus,
      generatedContent: freezed == generatedContent
          ? _value.generatedContent
          : generatedContent // ignore: cast_nullable_to_non_nullable
              as String?,
      analysis: freezed == analysis
          ? _value.analysis
          : analysis // ignore: cast_nullable_to_non_nullable
              as String?,
      tokenUsage: null == tokenUsage
          ? _value.tokenUsage
          : tokenUsage // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $POVConfigCopyWith<$Res> get config {
    return $POVConfigCopyWith<$Res>(_value.config, (value) {
      return _then(_value.copyWith(config: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$POVTaskImplCopyWith<$Res> implements $POVTaskCopyWith<$Res> {
  factory _$$POVTaskImplCopyWith(
          _$POVTaskImpl value, $Res Function(_$POVTaskImpl) then) =
      __$$POVTaskImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String workId,
      String chapterId,
      String characterId,
      String originalContent,
      POVConfig config,
      POVTaskStatus status,
      String? generatedContent,
      String? analysis,
      int tokenUsage,
      String? errorMessage,
      DateTime createdAt,
      DateTime? completedAt});

  @override
  $POVConfigCopyWith<$Res> get config;
}

/// @nodoc
class __$$POVTaskImplCopyWithImpl<$Res>
    extends _$POVTaskCopyWithImpl<$Res, _$POVTaskImpl>
    implements _$$POVTaskImplCopyWith<$Res> {
  __$$POVTaskImplCopyWithImpl(
      _$POVTaskImpl _value, $Res Function(_$POVTaskImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? workId = null,
    Object? chapterId = null,
    Object? characterId = null,
    Object? originalContent = null,
    Object? config = null,
    Object? status = null,
    Object? generatedContent = freezed,
    Object? analysis = freezed,
    Object? tokenUsage = null,
    Object? errorMessage = freezed,
    Object? createdAt = null,
    Object? completedAt = freezed,
  }) {
    return _then(_$POVTaskImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      workId: null == workId
          ? _value.workId
          : workId // ignore: cast_nullable_to_non_nullable
              as String,
      chapterId: null == chapterId
          ? _value.chapterId
          : chapterId // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      originalContent: null == originalContent
          ? _value.originalContent
          : originalContent // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as POVConfig,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as POVTaskStatus,
      generatedContent: freezed == generatedContent
          ? _value.generatedContent
          : generatedContent // ignore: cast_nullable_to_non_nullable
              as String?,
      analysis: freezed == analysis
          ? _value.analysis
          : analysis // ignore: cast_nullable_to_non_nullable
              as String?,
      tokenUsage: null == tokenUsage
          ? _value.tokenUsage
          : tokenUsage // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      completedAt: freezed == completedAt
          ? _value.completedAt
          : completedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$POVTaskImpl implements _POVTask {
  const _$POVTaskImpl(
      {required this.id,
      required this.workId,
      required this.chapterId,
      required this.characterId,
      required this.originalContent,
      required this.config,
      this.status = POVTaskStatus.pending,
      this.generatedContent,
      this.analysis,
      this.tokenUsage = 0,
      this.errorMessage,
      required this.createdAt,
      this.completedAt});

  factory _$POVTaskImpl.fromJson(Map<String, dynamic> json) =>
      _$$POVTaskImplFromJson(json);

  @override
  final String id;
  @override
  final String workId;
  @override
  final String chapterId;
  @override
  final String characterId;
  @override
  final String originalContent;
  @override
  final POVConfig config;
  @override
  @JsonKey()
  final POVTaskStatus status;
  @override
  final String? generatedContent;
  @override
  final String? analysis;
  @override
  @JsonKey()
  final int tokenUsage;
  @override
  final String? errorMessage;
  @override
  final DateTime createdAt;
  @override
  final DateTime? completedAt;

  @override
  String toString() {
    return 'POVTask(id: $id, workId: $workId, chapterId: $chapterId, characterId: $characterId, originalContent: $originalContent, config: $config, status: $status, generatedContent: $generatedContent, analysis: $analysis, tokenUsage: $tokenUsage, errorMessage: $errorMessage, createdAt: $createdAt, completedAt: $completedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$POVTaskImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.workId, workId) || other.workId == workId) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.originalContent, originalContent) ||
                other.originalContent == originalContent) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.generatedContent, generatedContent) ||
                other.generatedContent == generatedContent) &&
            (identical(other.analysis, analysis) ||
                other.analysis == analysis) &&
            (identical(other.tokenUsage, tokenUsage) ||
                other.tokenUsage == tokenUsage) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.completedAt, completedAt) ||
                other.completedAt == completedAt));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      workId,
      chapterId,
      characterId,
      originalContent,
      config,
      status,
      generatedContent,
      analysis,
      tokenUsage,
      errorMessage,
      createdAt,
      completedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$POVTaskImplCopyWith<_$POVTaskImpl> get copyWith =>
      __$$POVTaskImplCopyWithImpl<_$POVTaskImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$POVTaskImplToJson(
      this,
    );
  }
}

abstract class _POVTask implements POVTask {
  const factory _POVTask(
      {required final String id,
      required final String workId,
      required final String chapterId,
      required final String characterId,
      required final String originalContent,
      required final POVConfig config,
      final POVTaskStatus status,
      final String? generatedContent,
      final String? analysis,
      final int tokenUsage,
      final String? errorMessage,
      required final DateTime createdAt,
      final DateTime? completedAt}) = _$POVTaskImpl;

  factory _POVTask.fromJson(Map<String, dynamic> json) = _$POVTaskImpl.fromJson;

  @override
  String get id;
  @override
  String get workId;
  @override
  String get chapterId;
  @override
  String get characterId;
  @override
  String get originalContent;
  @override
  POVConfig get config;
  @override
  POVTaskStatus get status;
  @override
  String? get generatedContent;
  @override
  String? get analysis;
  @override
  int get tokenUsage;
  @override
  String? get errorMessage;
  @override
  DateTime get createdAt;
  @override
  DateTime? get completedAt;
  @override
  @JsonKey(ignore: true)
  _$$POVTaskImplCopyWith<_$POVTaskImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

POVConfig _$POVConfigFromJson(Map<String, dynamic> json) {
  return _POVConfig.fromJson(json);
}

/// @nodoc
mixin _$POVConfig {
  POVMode get mode => throw _privateConstructorUsedError;
  POVStyle get style => throw _privateConstructorUsedError;
  bool get keepDialogue => throw _privateConstructorUsedError;
  bool get addInnerThoughts => throw _privateConstructorUsedError;
  bool get expandObservations => throw _privateConstructorUsedError;
  double get emotionalIntensity => throw _privateConstructorUsedError;
  bool get useCharacterVoice => throw _privateConstructorUsedError;
  String? get customInstructions => throw _privateConstructorUsedError;
  int? get targetWordCount => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $POVConfigCopyWith<POVConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $POVConfigCopyWith<$Res> {
  factory $POVConfigCopyWith(POVConfig value, $Res Function(POVConfig) then) =
      _$POVConfigCopyWithImpl<$Res, POVConfig>;
  @useResult
  $Res call(
      {POVMode mode,
      POVStyle style,
      bool keepDialogue,
      bool addInnerThoughts,
      bool expandObservations,
      double emotionalIntensity,
      bool useCharacterVoice,
      String? customInstructions,
      int? targetWordCount});
}

/// @nodoc
class _$POVConfigCopyWithImpl<$Res, $Val extends POVConfig>
    implements $POVConfigCopyWith<$Res> {
  _$POVConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = null,
    Object? style = null,
    Object? keepDialogue = null,
    Object? addInnerThoughts = null,
    Object? expandObservations = null,
    Object? emotionalIntensity = null,
    Object? useCharacterVoice = null,
    Object? customInstructions = freezed,
    Object? targetWordCount = freezed,
  }) {
    return _then(_value.copyWith(
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as POVMode,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as POVStyle,
      keepDialogue: null == keepDialogue
          ? _value.keepDialogue
          : keepDialogue // ignore: cast_nullable_to_non_nullable
              as bool,
      addInnerThoughts: null == addInnerThoughts
          ? _value.addInnerThoughts
          : addInnerThoughts // ignore: cast_nullable_to_non_nullable
              as bool,
      expandObservations: null == expandObservations
          ? _value.expandObservations
          : expandObservations // ignore: cast_nullable_to_non_nullable
              as bool,
      emotionalIntensity: null == emotionalIntensity
          ? _value.emotionalIntensity
          : emotionalIntensity // ignore: cast_nullable_to_non_nullable
              as double,
      useCharacterVoice: null == useCharacterVoice
          ? _value.useCharacterVoice
          : useCharacterVoice // ignore: cast_nullable_to_non_nullable
              as bool,
      customInstructions: freezed == customInstructions
          ? _value.customInstructions
          : customInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWordCount: freezed == targetWordCount
          ? _value.targetWordCount
          : targetWordCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$POVConfigImplCopyWith<$Res>
    implements $POVConfigCopyWith<$Res> {
  factory _$$POVConfigImplCopyWith(
          _$POVConfigImpl value, $Res Function(_$POVConfigImpl) then) =
      __$$POVConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {POVMode mode,
      POVStyle style,
      bool keepDialogue,
      bool addInnerThoughts,
      bool expandObservations,
      double emotionalIntensity,
      bool useCharacterVoice,
      String? customInstructions,
      int? targetWordCount});
}

/// @nodoc
class __$$POVConfigImplCopyWithImpl<$Res>
    extends _$POVConfigCopyWithImpl<$Res, _$POVConfigImpl>
    implements _$$POVConfigImplCopyWith<$Res> {
  __$$POVConfigImplCopyWithImpl(
      _$POVConfigImpl _value, $Res Function(_$POVConfigImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = null,
    Object? style = null,
    Object? keepDialogue = null,
    Object? addInnerThoughts = null,
    Object? expandObservations = null,
    Object? emotionalIntensity = null,
    Object? useCharacterVoice = null,
    Object? customInstructions = freezed,
    Object? targetWordCount = freezed,
  }) {
    return _then(_$POVConfigImpl(
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as POVMode,
      style: null == style
          ? _value.style
          : style // ignore: cast_nullable_to_non_nullable
              as POVStyle,
      keepDialogue: null == keepDialogue
          ? _value.keepDialogue
          : keepDialogue // ignore: cast_nullable_to_non_nullable
              as bool,
      addInnerThoughts: null == addInnerThoughts
          ? _value.addInnerThoughts
          : addInnerThoughts // ignore: cast_nullable_to_non_nullable
              as bool,
      expandObservations: null == expandObservations
          ? _value.expandObservations
          : expandObservations // ignore: cast_nullable_to_non_nullable
              as bool,
      emotionalIntensity: null == emotionalIntensity
          ? _value.emotionalIntensity
          : emotionalIntensity // ignore: cast_nullable_to_non_nullable
              as double,
      useCharacterVoice: null == useCharacterVoice
          ? _value.useCharacterVoice
          : useCharacterVoice // ignore: cast_nullable_to_non_nullable
              as bool,
      customInstructions: freezed == customInstructions
          ? _value.customInstructions
          : customInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      targetWordCount: freezed == targetWordCount
          ? _value.targetWordCount
          : targetWordCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$POVConfigImpl implements _POVConfig {
  const _$POVConfigImpl(
      {this.mode = POVMode.rewrite,
      this.style = POVStyle.firstPerson,
      this.keepDialogue = true,
      this.addInnerThoughts = true,
      this.expandObservations = true,
      this.emotionalIntensity = 0.5,
      this.useCharacterVoice = true,
      this.customInstructions,
      this.targetWordCount});

  factory _$POVConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$POVConfigImplFromJson(json);

  @override
  @JsonKey()
  final POVMode mode;
  @override
  @JsonKey()
  final POVStyle style;
  @override
  @JsonKey()
  final bool keepDialogue;
  @override
  @JsonKey()
  final bool addInnerThoughts;
  @override
  @JsonKey()
  final bool expandObservations;
  @override
  @JsonKey()
  final double emotionalIntensity;
  @override
  @JsonKey()
  final bool useCharacterVoice;
  @override
  final String? customInstructions;
  @override
  final int? targetWordCount;

  @override
  String toString() {
    return 'POVConfig(mode: $mode, style: $style, keepDialogue: $keepDialogue, addInnerThoughts: $addInnerThoughts, expandObservations: $expandObservations, emotionalIntensity: $emotionalIntensity, useCharacterVoice: $useCharacterVoice, customInstructions: $customInstructions, targetWordCount: $targetWordCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$POVConfigImpl &&
            (identical(other.mode, mode) || other.mode == mode) &&
            (identical(other.style, style) || other.style == style) &&
            (identical(other.keepDialogue, keepDialogue) ||
                other.keepDialogue == keepDialogue) &&
            (identical(other.addInnerThoughts, addInnerThoughts) ||
                other.addInnerThoughts == addInnerThoughts) &&
            (identical(other.expandObservations, expandObservations) ||
                other.expandObservations == expandObservations) &&
            (identical(other.emotionalIntensity, emotionalIntensity) ||
                other.emotionalIntensity == emotionalIntensity) &&
            (identical(other.useCharacterVoice, useCharacterVoice) ||
                other.useCharacterVoice == useCharacterVoice) &&
            (identical(other.customInstructions, customInstructions) ||
                other.customInstructions == customInstructions) &&
            (identical(other.targetWordCount, targetWordCount) ||
                other.targetWordCount == targetWordCount));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      mode,
      style,
      keepDialogue,
      addInnerThoughts,
      expandObservations,
      emotionalIntensity,
      useCharacterVoice,
      customInstructions,
      targetWordCount);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$POVConfigImplCopyWith<_$POVConfigImpl> get copyWith =>
      __$$POVConfigImplCopyWithImpl<_$POVConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$POVConfigImplToJson(
      this,
    );
  }
}

abstract class _POVConfig implements POVConfig {
  const factory _POVConfig(
      {final POVMode mode,
      final POVStyle style,
      final bool keepDialogue,
      final bool addInnerThoughts,
      final bool expandObservations,
      final double emotionalIntensity,
      final bool useCharacterVoice,
      final String? customInstructions,
      final int? targetWordCount}) = _$POVConfigImpl;

  factory _POVConfig.fromJson(Map<String, dynamic> json) =
      _$POVConfigImpl.fromJson;

  @override
  POVMode get mode;
  @override
  POVStyle get style;
  @override
  bool get keepDialogue;
  @override
  bool get addInnerThoughts;
  @override
  bool get expandObservations;
  @override
  double get emotionalIntensity;
  @override
  bool get useCharacterVoice;
  @override
  String? get customInstructions;
  @override
  int? get targetWordCount;
  @override
  @JsonKey(ignore: true)
  _$$POVConfigImplCopyWith<_$POVConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

POVAnalysis _$POVAnalysisFromJson(Map<String, dynamic> json) {
  return _POVAnalysis.fromJson(json);
}

/// @nodoc
mixin _$POVAnalysis {
  List<CharacterAppearance> get appearances =>
      throw _privateConstructorUsedError;
  List<EmotionPoint> get emotionCurve => throw _privateConstructorUsedError;
  List<KeyObservation> get observations => throw _privateConstructorUsedError;
  List<CharacterInteraction> get interactions =>
      throw _privateConstructorUsedError;
  List<InnerThought> get suggestedThoughts =>
      throw _privateConstructorUsedError;
  List<String> get suggestions => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $POVAnalysisCopyWith<POVAnalysis> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $POVAnalysisCopyWith<$Res> {
  factory $POVAnalysisCopyWith(
          POVAnalysis value, $Res Function(POVAnalysis) then) =
      _$POVAnalysisCopyWithImpl<$Res, POVAnalysis>;
  @useResult
  $Res call(
      {List<CharacterAppearance> appearances,
      List<EmotionPoint> emotionCurve,
      List<KeyObservation> observations,
      List<CharacterInteraction> interactions,
      List<InnerThought> suggestedThoughts,
      List<String> suggestions});
}

/// @nodoc
class _$POVAnalysisCopyWithImpl<$Res, $Val extends POVAnalysis>
    implements $POVAnalysisCopyWith<$Res> {
  _$POVAnalysisCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appearances = null,
    Object? emotionCurve = null,
    Object? observations = null,
    Object? interactions = null,
    Object? suggestedThoughts = null,
    Object? suggestions = null,
  }) {
    return _then(_value.copyWith(
      appearances: null == appearances
          ? _value.appearances
          : appearances // ignore: cast_nullable_to_non_nullable
              as List<CharacterAppearance>,
      emotionCurve: null == emotionCurve
          ? _value.emotionCurve
          : emotionCurve // ignore: cast_nullable_to_non_nullable
              as List<EmotionPoint>,
      observations: null == observations
          ? _value.observations
          : observations // ignore: cast_nullable_to_non_nullable
              as List<KeyObservation>,
      interactions: null == interactions
          ? _value.interactions
          : interactions // ignore: cast_nullable_to_non_nullable
              as List<CharacterInteraction>,
      suggestedThoughts: null == suggestedThoughts
          ? _value.suggestedThoughts
          : suggestedThoughts // ignore: cast_nullable_to_non_nullable
              as List<InnerThought>,
      suggestions: null == suggestions
          ? _value.suggestions
          : suggestions // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$POVAnalysisImplCopyWith<$Res>
    implements $POVAnalysisCopyWith<$Res> {
  factory _$$POVAnalysisImplCopyWith(
          _$POVAnalysisImpl value, $Res Function(_$POVAnalysisImpl) then) =
      __$$POVAnalysisImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<CharacterAppearance> appearances,
      List<EmotionPoint> emotionCurve,
      List<KeyObservation> observations,
      List<CharacterInteraction> interactions,
      List<InnerThought> suggestedThoughts,
      List<String> suggestions});
}

/// @nodoc
class __$$POVAnalysisImplCopyWithImpl<$Res>
    extends _$POVAnalysisCopyWithImpl<$Res, _$POVAnalysisImpl>
    implements _$$POVAnalysisImplCopyWith<$Res> {
  __$$POVAnalysisImplCopyWithImpl(
      _$POVAnalysisImpl _value, $Res Function(_$POVAnalysisImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? appearances = null,
    Object? emotionCurve = null,
    Object? observations = null,
    Object? interactions = null,
    Object? suggestedThoughts = null,
    Object? suggestions = null,
  }) {
    return _then(_$POVAnalysisImpl(
      appearances: null == appearances
          ? _value._appearances
          : appearances // ignore: cast_nullable_to_non_nullable
              as List<CharacterAppearance>,
      emotionCurve: null == emotionCurve
          ? _value._emotionCurve
          : emotionCurve // ignore: cast_nullable_to_non_nullable
              as List<EmotionPoint>,
      observations: null == observations
          ? _value._observations
          : observations // ignore: cast_nullable_to_non_nullable
              as List<KeyObservation>,
      interactions: null == interactions
          ? _value._interactions
          : interactions // ignore: cast_nullable_to_non_nullable
              as List<CharacterInteraction>,
      suggestedThoughts: null == suggestedThoughts
          ? _value._suggestedThoughts
          : suggestedThoughts // ignore: cast_nullable_to_non_nullable
              as List<InnerThought>,
      suggestions: null == suggestions
          ? _value._suggestions
          : suggestions // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$POVAnalysisImpl implements _POVAnalysis {
  const _$POVAnalysisImpl(
      {required final List<CharacterAppearance> appearances,
      required final List<EmotionPoint> emotionCurve,
      required final List<KeyObservation> observations,
      required final List<CharacterInteraction> interactions,
      required final List<InnerThought> suggestedThoughts,
      required final List<String> suggestions})
      : _appearances = appearances,
        _emotionCurve = emotionCurve,
        _observations = observations,
        _interactions = interactions,
        _suggestedThoughts = suggestedThoughts,
        _suggestions = suggestions;

  factory _$POVAnalysisImpl.fromJson(Map<String, dynamic> json) =>
      _$$POVAnalysisImplFromJson(json);

  final List<CharacterAppearance> _appearances;
  @override
  List<CharacterAppearance> get appearances {
    if (_appearances is EqualUnmodifiableListView) return _appearances;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_appearances);
  }

  final List<EmotionPoint> _emotionCurve;
  @override
  List<EmotionPoint> get emotionCurve {
    if (_emotionCurve is EqualUnmodifiableListView) return _emotionCurve;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_emotionCurve);
  }

  final List<KeyObservation> _observations;
  @override
  List<KeyObservation> get observations {
    if (_observations is EqualUnmodifiableListView) return _observations;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_observations);
  }

  final List<CharacterInteraction> _interactions;
  @override
  List<CharacterInteraction> get interactions {
    if (_interactions is EqualUnmodifiableListView) return _interactions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_interactions);
  }

  final List<InnerThought> _suggestedThoughts;
  @override
  List<InnerThought> get suggestedThoughts {
    if (_suggestedThoughts is EqualUnmodifiableListView)
      return _suggestedThoughts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestedThoughts);
  }

  final List<String> _suggestions;
  @override
  List<String> get suggestions {
    if (_suggestions is EqualUnmodifiableListView) return _suggestions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestions);
  }

  @override
  String toString() {
    return 'POVAnalysis(appearances: $appearances, emotionCurve: $emotionCurve, observations: $observations, interactions: $interactions, suggestedThoughts: $suggestedThoughts, suggestions: $suggestions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$POVAnalysisImpl &&
            const DeepCollectionEquality()
                .equals(other._appearances, _appearances) &&
            const DeepCollectionEquality()
                .equals(other._emotionCurve, _emotionCurve) &&
            const DeepCollectionEquality()
                .equals(other._observations, _observations) &&
            const DeepCollectionEquality()
                .equals(other._interactions, _interactions) &&
            const DeepCollectionEquality()
                .equals(other._suggestedThoughts, _suggestedThoughts) &&
            const DeepCollectionEquality()
                .equals(other._suggestions, _suggestions));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_appearances),
      const DeepCollectionEquality().hash(_emotionCurve),
      const DeepCollectionEquality().hash(_observations),
      const DeepCollectionEquality().hash(_interactions),
      const DeepCollectionEquality().hash(_suggestedThoughts),
      const DeepCollectionEquality().hash(_suggestions));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$POVAnalysisImplCopyWith<_$POVAnalysisImpl> get copyWith =>
      __$$POVAnalysisImplCopyWithImpl<_$POVAnalysisImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$POVAnalysisImplToJson(
      this,
    );
  }
}

abstract class _POVAnalysis implements POVAnalysis {
  const factory _POVAnalysis(
      {required final List<CharacterAppearance> appearances,
      required final List<EmotionPoint> emotionCurve,
      required final List<KeyObservation> observations,
      required final List<CharacterInteraction> interactions,
      required final List<InnerThought> suggestedThoughts,
      required final List<String> suggestions}) = _$POVAnalysisImpl;

  factory _POVAnalysis.fromJson(Map<String, dynamic> json) =
      _$POVAnalysisImpl.fromJson;

  @override
  List<CharacterAppearance> get appearances;
  @override
  List<EmotionPoint> get emotionCurve;
  @override
  List<KeyObservation> get observations;
  @override
  List<CharacterInteraction> get interactions;
  @override
  List<InnerThought> get suggestedThoughts;
  @override
  List<String> get suggestions;
  @override
  @JsonKey(ignore: true)
  _$$POVAnalysisImplCopyWith<_$POVAnalysisImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CharacterAppearance _$CharacterAppearanceFromJson(Map<String, dynamic> json) {
  return _CharacterAppearance.fromJson(json);
}

/// @nodoc
mixin _$CharacterAppearance {
  int get paragraphIndex => throw _privateConstructorUsedError;
  String get originalText => throw _privateConstructorUsedError;
  String? get action => throw _privateConstructorUsedError;
  String? get dialogue => throw _privateConstructorUsedError;
  String? get contextSummary => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CharacterAppearanceCopyWith<CharacterAppearance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterAppearanceCopyWith<$Res> {
  factory $CharacterAppearanceCopyWith(
          CharacterAppearance value, $Res Function(CharacterAppearance) then) =
      _$CharacterAppearanceCopyWithImpl<$Res, CharacterAppearance>;
  @useResult
  $Res call(
      {int paragraphIndex,
      String originalText,
      String? action,
      String? dialogue,
      String? contextSummary});
}

/// @nodoc
class _$CharacterAppearanceCopyWithImpl<$Res, $Val extends CharacterAppearance>
    implements $CharacterAppearanceCopyWith<$Res> {
  _$CharacterAppearanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paragraphIndex = null,
    Object? originalText = null,
    Object? action = freezed,
    Object? dialogue = freezed,
    Object? contextSummary = freezed,
  }) {
    return _then(_value.copyWith(
      paragraphIndex: null == paragraphIndex
          ? _value.paragraphIndex
          : paragraphIndex // ignore: cast_nullable_to_non_nullable
              as int,
      originalText: null == originalText
          ? _value.originalText
          : originalText // ignore: cast_nullable_to_non_nullable
              as String,
      action: freezed == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String?,
      dialogue: freezed == dialogue
          ? _value.dialogue
          : dialogue // ignore: cast_nullable_to_non_nullable
              as String?,
      contextSummary: freezed == contextSummary
          ? _value.contextSummary
          : contextSummary // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CharacterAppearanceImplCopyWith<$Res>
    implements $CharacterAppearanceCopyWith<$Res> {
  factory _$$CharacterAppearanceImplCopyWith(_$CharacterAppearanceImpl value,
          $Res Function(_$CharacterAppearanceImpl) then) =
      __$$CharacterAppearanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int paragraphIndex,
      String originalText,
      String? action,
      String? dialogue,
      String? contextSummary});
}

/// @nodoc
class __$$CharacterAppearanceImplCopyWithImpl<$Res>
    extends _$CharacterAppearanceCopyWithImpl<$Res, _$CharacterAppearanceImpl>
    implements _$$CharacterAppearanceImplCopyWith<$Res> {
  __$$CharacterAppearanceImplCopyWithImpl(_$CharacterAppearanceImpl _value,
      $Res Function(_$CharacterAppearanceImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paragraphIndex = null,
    Object? originalText = null,
    Object? action = freezed,
    Object? dialogue = freezed,
    Object? contextSummary = freezed,
  }) {
    return _then(_$CharacterAppearanceImpl(
      paragraphIndex: null == paragraphIndex
          ? _value.paragraphIndex
          : paragraphIndex // ignore: cast_nullable_to_non_nullable
              as int,
      originalText: null == originalText
          ? _value.originalText
          : originalText // ignore: cast_nullable_to_non_nullable
              as String,
      action: freezed == action
          ? _value.action
          : action // ignore: cast_nullable_to_non_nullable
              as String?,
      dialogue: freezed == dialogue
          ? _value.dialogue
          : dialogue // ignore: cast_nullable_to_non_nullable
              as String?,
      contextSummary: freezed == contextSummary
          ? _value.contextSummary
          : contextSummary // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CharacterAppearanceImpl implements _CharacterAppearance {
  const _$CharacterAppearanceImpl(
      {required this.paragraphIndex,
      required this.originalText,
      this.action,
      this.dialogue,
      this.contextSummary});

  factory _$CharacterAppearanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterAppearanceImplFromJson(json);

  @override
  final int paragraphIndex;
  @override
  final String originalText;
  @override
  final String? action;
  @override
  final String? dialogue;
  @override
  final String? contextSummary;

  @override
  String toString() {
    return 'CharacterAppearance(paragraphIndex: $paragraphIndex, originalText: $originalText, action: $action, dialogue: $dialogue, contextSummary: $contextSummary)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterAppearanceImpl &&
            (identical(other.paragraphIndex, paragraphIndex) ||
                other.paragraphIndex == paragraphIndex) &&
            (identical(other.originalText, originalText) ||
                other.originalText == originalText) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.dialogue, dialogue) ||
                other.dialogue == dialogue) &&
            (identical(other.contextSummary, contextSummary) ||
                other.contextSummary == contextSummary));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, paragraphIndex, originalText,
      action, dialogue, contextSummary);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterAppearanceImplCopyWith<_$CharacterAppearanceImpl> get copyWith =>
      __$$CharacterAppearanceImplCopyWithImpl<_$CharacterAppearanceImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterAppearanceImplToJson(
      this,
    );
  }
}

abstract class _CharacterAppearance implements CharacterAppearance {
  const factory _CharacterAppearance(
      {required final int paragraphIndex,
      required final String originalText,
      final String? action,
      final String? dialogue,
      final String? contextSummary}) = _$CharacterAppearanceImpl;

  factory _CharacterAppearance.fromJson(Map<String, dynamic> json) =
      _$CharacterAppearanceImpl.fromJson;

  @override
  int get paragraphIndex;
  @override
  String get originalText;
  @override
  String? get action;
  @override
  String? get dialogue;
  @override
  String? get contextSummary;
  @override
  @JsonKey(ignore: true)
  _$$CharacterAppearanceImplCopyWith<_$CharacterAppearanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EmotionPoint _$EmotionPointFromJson(Map<String, dynamic> json) {
  return _EmotionPoint.fromJson(json);
}

/// @nodoc
mixin _$EmotionPoint {
  int get position => throw _privateConstructorUsedError;
  EmotionType get type => throw _privateConstructorUsedError;
  double get intensity => throw _privateConstructorUsedError;
  String? get trigger => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $EmotionPointCopyWith<EmotionPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EmotionPointCopyWith<$Res> {
  factory $EmotionPointCopyWith(
          EmotionPoint value, $Res Function(EmotionPoint) then) =
      _$EmotionPointCopyWithImpl<$Res, EmotionPoint>;
  @useResult
  $Res call(
      {int position,
      EmotionType type,
      double intensity,
      String? trigger,
      String? description});
}

/// @nodoc
class _$EmotionPointCopyWithImpl<$Res, $Val extends EmotionPoint>
    implements $EmotionPointCopyWith<$Res> {
  _$EmotionPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? type = null,
    Object? intensity = null,
    Object? trigger = freezed,
    Object? description = freezed,
  }) {
    return _then(_value.copyWith(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as EmotionType,
      intensity: null == intensity
          ? _value.intensity
          : intensity // ignore: cast_nullable_to_non_nullable
              as double,
      trigger: freezed == trigger
          ? _value.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EmotionPointImplCopyWith<$Res>
    implements $EmotionPointCopyWith<$Res> {
  factory _$$EmotionPointImplCopyWith(
          _$EmotionPointImpl value, $Res Function(_$EmotionPointImpl) then) =
      __$$EmotionPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int position,
      EmotionType type,
      double intensity,
      String? trigger,
      String? description});
}

/// @nodoc
class __$$EmotionPointImplCopyWithImpl<$Res>
    extends _$EmotionPointCopyWithImpl<$Res, _$EmotionPointImpl>
    implements _$$EmotionPointImplCopyWith<$Res> {
  __$$EmotionPointImplCopyWithImpl(
      _$EmotionPointImpl _value, $Res Function(_$EmotionPointImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? type = null,
    Object? intensity = null,
    Object? trigger = freezed,
    Object? description = freezed,
  }) {
    return _then(_$EmotionPointImpl(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as EmotionType,
      intensity: null == intensity
          ? _value.intensity
          : intensity // ignore: cast_nullable_to_non_nullable
              as double,
      trigger: freezed == trigger
          ? _value.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$EmotionPointImpl implements _EmotionPoint {
  const _$EmotionPointImpl(
      {required this.position,
      required this.type,
      required this.intensity,
      this.trigger,
      this.description});

  factory _$EmotionPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$EmotionPointImplFromJson(json);

  @override
  final int position;
  @override
  final EmotionType type;
  @override
  final double intensity;
  @override
  final String? trigger;
  @override
  final String? description;

  @override
  String toString() {
    return 'EmotionPoint(position: $position, type: $type, intensity: $intensity, trigger: $trigger, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EmotionPointImpl &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.intensity, intensity) ||
                other.intensity == intensity) &&
            (identical(other.trigger, trigger) || other.trigger == trigger) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, position, type, intensity, trigger, description);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$EmotionPointImplCopyWith<_$EmotionPointImpl> get copyWith =>
      __$$EmotionPointImplCopyWithImpl<_$EmotionPointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$EmotionPointImplToJson(
      this,
    );
  }
}

abstract class _EmotionPoint implements EmotionPoint {
  const factory _EmotionPoint(
      {required final int position,
      required final EmotionType type,
      required final double intensity,
      final String? trigger,
      final String? description}) = _$EmotionPointImpl;

  factory _EmotionPoint.fromJson(Map<String, dynamic> json) =
      _$EmotionPointImpl.fromJson;

  @override
  int get position;
  @override
  EmotionType get type;
  @override
  double get intensity;
  @override
  String? get trigger;
  @override
  String? get description;
  @override
  @JsonKey(ignore: true)
  _$$EmotionPointImplCopyWith<_$EmotionPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

KeyObservation _$KeyObservationFromJson(Map<String, dynamic> json) {
  return _KeyObservation.fromJson(json);
}

/// @nodoc
mixin _$KeyObservation {
  int get position => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  ObservationType get type => throw _privateConstructorUsedError;
  String? get characterReaction => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $KeyObservationCopyWith<KeyObservation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $KeyObservationCopyWith<$Res> {
  factory $KeyObservationCopyWith(
          KeyObservation value, $Res Function(KeyObservation) then) =
      _$KeyObservationCopyWithImpl<$Res, KeyObservation>;
  @useResult
  $Res call(
      {int position,
      String content,
      ObservationType type,
      String? characterReaction});
}

/// @nodoc
class _$KeyObservationCopyWithImpl<$Res, $Val extends KeyObservation>
    implements $KeyObservationCopyWith<$Res> {
  _$KeyObservationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? content = null,
    Object? type = null,
    Object? characterReaction = freezed,
  }) {
    return _then(_value.copyWith(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ObservationType,
      characterReaction: freezed == characterReaction
          ? _value.characterReaction
          : characterReaction // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$KeyObservationImplCopyWith<$Res>
    implements $KeyObservationCopyWith<$Res> {
  factory _$$KeyObservationImplCopyWith(_$KeyObservationImpl value,
          $Res Function(_$KeyObservationImpl) then) =
      __$$KeyObservationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int position,
      String content,
      ObservationType type,
      String? characterReaction});
}

/// @nodoc
class __$$KeyObservationImplCopyWithImpl<$Res>
    extends _$KeyObservationCopyWithImpl<$Res, _$KeyObservationImpl>
    implements _$$KeyObservationImplCopyWith<$Res> {
  __$$KeyObservationImplCopyWithImpl(
      _$KeyObservationImpl _value, $Res Function(_$KeyObservationImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? content = null,
    Object? type = null,
    Object? characterReaction = freezed,
  }) {
    return _then(_$KeyObservationImpl(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ObservationType,
      characterReaction: freezed == characterReaction
          ? _value.characterReaction
          : characterReaction // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$KeyObservationImpl implements _KeyObservation {
  const _$KeyObservationImpl(
      {required this.position,
      required this.content,
      required this.type,
      this.characterReaction});

  factory _$KeyObservationImpl.fromJson(Map<String, dynamic> json) =>
      _$$KeyObservationImplFromJson(json);

  @override
  final int position;
  @override
  final String content;
  @override
  final ObservationType type;
  @override
  final String? characterReaction;

  @override
  String toString() {
    return 'KeyObservation(position: $position, content: $content, type: $type, characterReaction: $characterReaction)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$KeyObservationImpl &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.characterReaction, characterReaction) ||
                other.characterReaction == characterReaction));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, position, content, type, characterReaction);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$KeyObservationImplCopyWith<_$KeyObservationImpl> get copyWith =>
      __$$KeyObservationImplCopyWithImpl<_$KeyObservationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$KeyObservationImplToJson(
      this,
    );
  }
}

abstract class _KeyObservation implements KeyObservation {
  const factory _KeyObservation(
      {required final int position,
      required final String content,
      required final ObservationType type,
      final String? characterReaction}) = _$KeyObservationImpl;

  factory _KeyObservation.fromJson(Map<String, dynamic> json) =
      _$KeyObservationImpl.fromJson;

  @override
  int get position;
  @override
  String get content;
  @override
  ObservationType get type;
  @override
  String? get characterReaction;
  @override
  @JsonKey(ignore: true)
  _$$KeyObservationImplCopyWith<_$KeyObservationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CharacterInteraction _$CharacterInteractionFromJson(Map<String, dynamic> json) {
  return _CharacterInteraction.fromJson(json);
}

/// @nodoc
mixin _$CharacterInteraction {
  String get otherCharacterId => throw _privateConstructorUsedError;
  String get otherCharacterName => throw _privateConstructorUsedError;
  int get position => throw _privateConstructorUsedError;
  InteractionType get type => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  String? get povCharacterReaction => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CharacterInteractionCopyWith<CharacterInteraction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterInteractionCopyWith<$Res> {
  factory $CharacterInteractionCopyWith(CharacterInteraction value,
          $Res Function(CharacterInteraction) then) =
      _$CharacterInteractionCopyWithImpl<$Res, CharacterInteraction>;
  @useResult
  $Res call(
      {String otherCharacterId,
      String otherCharacterName,
      int position,
      InteractionType type,
      String? content,
      String? povCharacterReaction});
}

/// @nodoc
class _$CharacterInteractionCopyWithImpl<$Res,
        $Val extends CharacterInteraction>
    implements $CharacterInteractionCopyWith<$Res> {
  _$CharacterInteractionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? otherCharacterId = null,
    Object? otherCharacterName = null,
    Object? position = null,
    Object? type = null,
    Object? content = freezed,
    Object? povCharacterReaction = freezed,
  }) {
    return _then(_value.copyWith(
      otherCharacterId: null == otherCharacterId
          ? _value.otherCharacterId
          : otherCharacterId // ignore: cast_nullable_to_non_nullable
              as String,
      otherCharacterName: null == otherCharacterName
          ? _value.otherCharacterName
          : otherCharacterName // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as InteractionType,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      povCharacterReaction: freezed == povCharacterReaction
          ? _value.povCharacterReaction
          : povCharacterReaction // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CharacterInteractionImplCopyWith<$Res>
    implements $CharacterInteractionCopyWith<$Res> {
  factory _$$CharacterInteractionImplCopyWith(_$CharacterInteractionImpl value,
          $Res Function(_$CharacterInteractionImpl) then) =
      __$$CharacterInteractionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String otherCharacterId,
      String otherCharacterName,
      int position,
      InteractionType type,
      String? content,
      String? povCharacterReaction});
}

/// @nodoc
class __$$CharacterInteractionImplCopyWithImpl<$Res>
    extends _$CharacterInteractionCopyWithImpl<$Res, _$CharacterInteractionImpl>
    implements _$$CharacterInteractionImplCopyWith<$Res> {
  __$$CharacterInteractionImplCopyWithImpl(_$CharacterInteractionImpl _value,
      $Res Function(_$CharacterInteractionImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? otherCharacterId = null,
    Object? otherCharacterName = null,
    Object? position = null,
    Object? type = null,
    Object? content = freezed,
    Object? povCharacterReaction = freezed,
  }) {
    return _then(_$CharacterInteractionImpl(
      otherCharacterId: null == otherCharacterId
          ? _value.otherCharacterId
          : otherCharacterId // ignore: cast_nullable_to_non_nullable
              as String,
      otherCharacterName: null == otherCharacterName
          ? _value.otherCharacterName
          : otherCharacterName // ignore: cast_nullable_to_non_nullable
              as String,
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as InteractionType,
      content: freezed == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String?,
      povCharacterReaction: freezed == povCharacterReaction
          ? _value.povCharacterReaction
          : povCharacterReaction // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CharacterInteractionImpl implements _CharacterInteraction {
  const _$CharacterInteractionImpl(
      {required this.otherCharacterId,
      required this.otherCharacterName,
      required this.position,
      required this.type,
      this.content,
      this.povCharacterReaction});

  factory _$CharacterInteractionImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterInteractionImplFromJson(json);

  @override
  final String otherCharacterId;
  @override
  final String otherCharacterName;
  @override
  final int position;
  @override
  final InteractionType type;
  @override
  final String? content;
  @override
  final String? povCharacterReaction;

  @override
  String toString() {
    return 'CharacterInteraction(otherCharacterId: $otherCharacterId, otherCharacterName: $otherCharacterName, position: $position, type: $type, content: $content, povCharacterReaction: $povCharacterReaction)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterInteractionImpl &&
            (identical(other.otherCharacterId, otherCharacterId) ||
                other.otherCharacterId == otherCharacterId) &&
            (identical(other.otherCharacterName, otherCharacterName) ||
                other.otherCharacterName == otherCharacterName) &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.povCharacterReaction, povCharacterReaction) ||
                other.povCharacterReaction == povCharacterReaction));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, otherCharacterId,
      otherCharacterName, position, type, content, povCharacterReaction);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterInteractionImplCopyWith<_$CharacterInteractionImpl>
      get copyWith =>
          __$$CharacterInteractionImplCopyWithImpl<_$CharacterInteractionImpl>(
              this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterInteractionImplToJson(
      this,
    );
  }
}

abstract class _CharacterInteraction implements CharacterInteraction {
  const factory _CharacterInteraction(
      {required final String otherCharacterId,
      required final String otherCharacterName,
      required final int position,
      required final InteractionType type,
      final String? content,
      final String? povCharacterReaction}) = _$CharacterInteractionImpl;

  factory _CharacterInteraction.fromJson(Map<String, dynamic> json) =
      _$CharacterInteractionImpl.fromJson;

  @override
  String get otherCharacterId;
  @override
  String get otherCharacterName;
  @override
  int get position;
  @override
  InteractionType get type;
  @override
  String? get content;
  @override
  String? get povCharacterReaction;
  @override
  @JsonKey(ignore: true)
  _$$CharacterInteractionImplCopyWith<_$CharacterInteractionImpl>
      get copyWith => throw _privateConstructorUsedError;
}

InnerThought _$InnerThoughtFromJson(Map<String, dynamic> json) {
  return _InnerThought.fromJson(json);
}

/// @nodoc
mixin _$InnerThought {
  int get position => throw _privateConstructorUsedError;
  String get content => throw _privateConstructorUsedError;
  ThoughtType get type => throw _privateConstructorUsedError;
  String? get trigger => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $InnerThoughtCopyWith<InnerThought> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InnerThoughtCopyWith<$Res> {
  factory $InnerThoughtCopyWith(
          InnerThought value, $Res Function(InnerThought) then) =
      _$InnerThoughtCopyWithImpl<$Res, InnerThought>;
  @useResult
  $Res call({int position, String content, ThoughtType type, String? trigger});
}

/// @nodoc
class _$InnerThoughtCopyWithImpl<$Res, $Val extends InnerThought>
    implements $InnerThoughtCopyWith<$Res> {
  _$InnerThoughtCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? content = null,
    Object? type = null,
    Object? trigger = freezed,
  }) {
    return _then(_value.copyWith(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ThoughtType,
      trigger: freezed == trigger
          ? _value.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InnerThoughtImplCopyWith<$Res>
    implements $InnerThoughtCopyWith<$Res> {
  factory _$$InnerThoughtImplCopyWith(
          _$InnerThoughtImpl value, $Res Function(_$InnerThoughtImpl) then) =
      __$$InnerThoughtImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int position, String content, ThoughtType type, String? trigger});
}

/// @nodoc
class __$$InnerThoughtImplCopyWithImpl<$Res>
    extends _$InnerThoughtCopyWithImpl<$Res, _$InnerThoughtImpl>
    implements _$$InnerThoughtImplCopyWith<$Res> {
  __$$InnerThoughtImplCopyWithImpl(
      _$InnerThoughtImpl _value, $Res Function(_$InnerThoughtImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? position = null,
    Object? content = null,
    Object? type = null,
    Object? trigger = freezed,
  }) {
    return _then(_$InnerThoughtImpl(
      position: null == position
          ? _value.position
          : position // ignore: cast_nullable_to_non_nullable
              as int,
      content: null == content
          ? _value.content
          : content // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as ThoughtType,
      trigger: freezed == trigger
          ? _value.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InnerThoughtImpl implements _InnerThought {
  const _$InnerThoughtImpl(
      {required this.position,
      required this.content,
      required this.type,
      this.trigger});

  factory _$InnerThoughtImpl.fromJson(Map<String, dynamic> json) =>
      _$$InnerThoughtImplFromJson(json);

  @override
  final int position;
  @override
  final String content;
  @override
  final ThoughtType type;
  @override
  final String? trigger;

  @override
  String toString() {
    return 'InnerThought(position: $position, content: $content, type: $type, trigger: $trigger)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InnerThoughtImpl &&
            (identical(other.position, position) ||
                other.position == position) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.trigger, trigger) || other.trigger == trigger));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, position, content, type, trigger);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$InnerThoughtImplCopyWith<_$InnerThoughtImpl> get copyWith =>
      __$$InnerThoughtImplCopyWithImpl<_$InnerThoughtImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InnerThoughtImplToJson(
      this,
    );
  }
}

abstract class _InnerThought implements InnerThought {
  const factory _InnerThought(
      {required final int position,
      required final String content,
      required final ThoughtType type,
      final String? trigger}) = _$InnerThoughtImpl;

  factory _InnerThought.fromJson(Map<String, dynamic> json) =
      _$InnerThoughtImpl.fromJson;

  @override
  int get position;
  @override
  String get content;
  @override
  ThoughtType get type;
  @override
  String? get trigger;
  @override
  @JsonKey(ignore: true)
  _$$InnerThoughtImplCopyWith<_$InnerThoughtImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

POVTemplate _$POVTemplateFromJson(Map<String, dynamic> json) {
  return _POVTemplate.fromJson(json);
}

/// @nodoc
mixin _$POVTemplate {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  POVConfig get config => throw _privateConstructorUsedError;
  List<String> get suitableCharacterTypes => throw _privateConstructorUsedError;
  String? get exampleOutput => throw _privateConstructorUsedError;
  bool get isBuiltIn => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $POVTemplateCopyWith<POVTemplate> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $POVTemplateCopyWith<$Res> {
  factory $POVTemplateCopyWith(
          POVTemplate value, $Res Function(POVTemplate) then) =
      _$POVTemplateCopyWithImpl<$Res, POVTemplate>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      POVConfig config,
      List<String> suitableCharacterTypes,
      String? exampleOutput,
      bool isBuiltIn});

  $POVConfigCopyWith<$Res> get config;
}

/// @nodoc
class _$POVTemplateCopyWithImpl<$Res, $Val extends POVTemplate>
    implements $POVTemplateCopyWith<$Res> {
  _$POVTemplateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? config = null,
    Object? suitableCharacterTypes = null,
    Object? exampleOutput = freezed,
    Object? isBuiltIn = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as POVConfig,
      suitableCharacterTypes: null == suitableCharacterTypes
          ? _value.suitableCharacterTypes
          : suitableCharacterTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      exampleOutput: freezed == exampleOutput
          ? _value.exampleOutput
          : exampleOutput // ignore: cast_nullable_to_non_nullable
              as String?,
      isBuiltIn: null == isBuiltIn
          ? _value.isBuiltIn
          : isBuiltIn // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $POVConfigCopyWith<$Res> get config {
    return $POVConfigCopyWith<$Res>(_value.config, (value) {
      return _then(_value.copyWith(config: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$POVTemplateImplCopyWith<$Res>
    implements $POVTemplateCopyWith<$Res> {
  factory _$$POVTemplateImplCopyWith(
          _$POVTemplateImpl value, $Res Function(_$POVTemplateImpl) then) =
      __$$POVTemplateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      POVConfig config,
      List<String> suitableCharacterTypes,
      String? exampleOutput,
      bool isBuiltIn});

  @override
  $POVConfigCopyWith<$Res> get config;
}

/// @nodoc
class __$$POVTemplateImplCopyWithImpl<$Res>
    extends _$POVTemplateCopyWithImpl<$Res, _$POVTemplateImpl>
    implements _$$POVTemplateImplCopyWith<$Res> {
  __$$POVTemplateImplCopyWithImpl(
      _$POVTemplateImpl _value, $Res Function(_$POVTemplateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? config = null,
    Object? suitableCharacterTypes = null,
    Object? exampleOutput = freezed,
    Object? isBuiltIn = null,
  }) {
    return _then(_$POVTemplateImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      config: null == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as POVConfig,
      suitableCharacterTypes: null == suitableCharacterTypes
          ? _value._suitableCharacterTypes
          : suitableCharacterTypes // ignore: cast_nullable_to_non_nullable
              as List<String>,
      exampleOutput: freezed == exampleOutput
          ? _value.exampleOutput
          : exampleOutput // ignore: cast_nullable_to_non_nullable
              as String?,
      isBuiltIn: null == isBuiltIn
          ? _value.isBuiltIn
          : isBuiltIn // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$POVTemplateImpl implements _POVTemplate {
  const _$POVTemplateImpl(
      {required this.id,
      required this.name,
      required this.description,
      required this.config,
      final List<String> suitableCharacterTypes = const [],
      this.exampleOutput,
      this.isBuiltIn = false})
      : _suitableCharacterTypes = suitableCharacterTypes;

  factory _$POVTemplateImpl.fromJson(Map<String, dynamic> json) =>
      _$$POVTemplateImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final POVConfig config;
  final List<String> _suitableCharacterTypes;
  @override
  @JsonKey()
  List<String> get suitableCharacterTypes {
    if (_suitableCharacterTypes is EqualUnmodifiableListView)
      return _suitableCharacterTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suitableCharacterTypes);
  }

  @override
  final String? exampleOutput;
  @override
  @JsonKey()
  final bool isBuiltIn;

  @override
  String toString() {
    return 'POVTemplate(id: $id, name: $name, description: $description, config: $config, suitableCharacterTypes: $suitableCharacterTypes, exampleOutput: $exampleOutput, isBuiltIn: $isBuiltIn)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$POVTemplateImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.config, config) || other.config == config) &&
            const DeepCollectionEquality().equals(
                other._suitableCharacterTypes, _suitableCharacterTypes) &&
            (identical(other.exampleOutput, exampleOutput) ||
                other.exampleOutput == exampleOutput) &&
            (identical(other.isBuiltIn, isBuiltIn) ||
                other.isBuiltIn == isBuiltIn));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      config,
      const DeepCollectionEquality().hash(_suitableCharacterTypes),
      exampleOutput,
      isBuiltIn);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$POVTemplateImplCopyWith<_$POVTemplateImpl> get copyWith =>
      __$$POVTemplateImplCopyWithImpl<_$POVTemplateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$POVTemplateImplToJson(
      this,
    );
  }
}

abstract class _POVTemplate implements POVTemplate {
  const factory _POVTemplate(
      {required final String id,
      required final String name,
      required final String description,
      required final POVConfig config,
      final List<String> suitableCharacterTypes,
      final String? exampleOutput,
      final bool isBuiltIn}) = _$POVTemplateImpl;

  factory _POVTemplate.fromJson(Map<String, dynamic> json) =
      _$POVTemplateImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  POVConfig get config;
  @override
  List<String> get suitableCharacterTypes;
  @override
  String? get exampleOutput;
  @override
  bool get isBuiltIn;
  @override
  @JsonKey(ignore: true)
  _$$POVTemplateImplCopyWith<_$POVTemplateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

POVSaveOptions _$POVSaveOptionsFromJson(Map<String, dynamic> json) {
  return _POVSaveOptions.fromJson(json);
}

/// @nodoc
mixin _$POVSaveOptions {
  bool get canSaveAsDraft => throw _privateConstructorUsedError;
  bool get canReplaceChapter => throw _privateConstructorUsedError;
  bool get canCreateNewChapter => throw _privateConstructorUsedError;
  String? get currentChapterTitle => throw _privateConstructorUsedError;
  int get suggestedSortOrder => throw _privateConstructorUsedError;
  String? get defaultVolumeId => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $POVSaveOptionsCopyWith<POVSaveOptions> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $POVSaveOptionsCopyWith<$Res> {
  factory $POVSaveOptionsCopyWith(
          POVSaveOptions value, $Res Function(POVSaveOptions) then) =
      _$POVSaveOptionsCopyWithImpl<$Res, POVSaveOptions>;
  @useResult
  $Res call(
      {bool canSaveAsDraft,
      bool canReplaceChapter,
      bool canCreateNewChapter,
      String? currentChapterTitle,
      int suggestedSortOrder,
      String? defaultVolumeId});
}

/// @nodoc
class _$POVSaveOptionsCopyWithImpl<$Res, $Val extends POVSaveOptions>
    implements $POVSaveOptionsCopyWith<$Res> {
  _$POVSaveOptionsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? canSaveAsDraft = null,
    Object? canReplaceChapter = null,
    Object? canCreateNewChapter = null,
    Object? currentChapterTitle = freezed,
    Object? suggestedSortOrder = null,
    Object? defaultVolumeId = freezed,
  }) {
    return _then(_value.copyWith(
      canSaveAsDraft: null == canSaveAsDraft
          ? _value.canSaveAsDraft
          : canSaveAsDraft // ignore: cast_nullable_to_non_nullable
              as bool,
      canReplaceChapter: null == canReplaceChapter
          ? _value.canReplaceChapter
          : canReplaceChapter // ignore: cast_nullable_to_non_nullable
              as bool,
      canCreateNewChapter: null == canCreateNewChapter
          ? _value.canCreateNewChapter
          : canCreateNewChapter // ignore: cast_nullable_to_non_nullable
              as bool,
      currentChapterTitle: freezed == currentChapterTitle
          ? _value.currentChapterTitle
          : currentChapterTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      suggestedSortOrder: null == suggestedSortOrder
          ? _value.suggestedSortOrder
          : suggestedSortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      defaultVolumeId: freezed == defaultVolumeId
          ? _value.defaultVolumeId
          : defaultVolumeId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$POVSaveOptionsImplCopyWith<$Res>
    implements $POVSaveOptionsCopyWith<$Res> {
  factory _$$POVSaveOptionsImplCopyWith(_$POVSaveOptionsImpl value,
          $Res Function(_$POVSaveOptionsImpl) then) =
      __$$POVSaveOptionsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool canSaveAsDraft,
      bool canReplaceChapter,
      bool canCreateNewChapter,
      String? currentChapterTitle,
      int suggestedSortOrder,
      String? defaultVolumeId});
}

/// @nodoc
class __$$POVSaveOptionsImplCopyWithImpl<$Res>
    extends _$POVSaveOptionsCopyWithImpl<$Res, _$POVSaveOptionsImpl>
    implements _$$POVSaveOptionsImplCopyWith<$Res> {
  __$$POVSaveOptionsImplCopyWithImpl(
      _$POVSaveOptionsImpl _value, $Res Function(_$POVSaveOptionsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? canSaveAsDraft = null,
    Object? canReplaceChapter = null,
    Object? canCreateNewChapter = null,
    Object? currentChapterTitle = freezed,
    Object? suggestedSortOrder = null,
    Object? defaultVolumeId = freezed,
  }) {
    return _then(_$POVSaveOptionsImpl(
      canSaveAsDraft: null == canSaveAsDraft
          ? _value.canSaveAsDraft
          : canSaveAsDraft // ignore: cast_nullable_to_non_nullable
              as bool,
      canReplaceChapter: null == canReplaceChapter
          ? _value.canReplaceChapter
          : canReplaceChapter // ignore: cast_nullable_to_non_nullable
              as bool,
      canCreateNewChapter: null == canCreateNewChapter
          ? _value.canCreateNewChapter
          : canCreateNewChapter // ignore: cast_nullable_to_non_nullable
              as bool,
      currentChapterTitle: freezed == currentChapterTitle
          ? _value.currentChapterTitle
          : currentChapterTitle // ignore: cast_nullable_to_non_nullable
              as String?,
      suggestedSortOrder: null == suggestedSortOrder
          ? _value.suggestedSortOrder
          : suggestedSortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      defaultVolumeId: freezed == defaultVolumeId
          ? _value.defaultVolumeId
          : defaultVolumeId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$POVSaveOptionsImpl implements _POVSaveOptions {
  const _$POVSaveOptionsImpl(
      {required this.canSaveAsDraft,
      required this.canReplaceChapter,
      required this.canCreateNewChapter,
      this.currentChapterTitle,
      required this.suggestedSortOrder,
      this.defaultVolumeId});

  factory _$POVSaveOptionsImpl.fromJson(Map<String, dynamic> json) =>
      _$$POVSaveOptionsImplFromJson(json);

  @override
  final bool canSaveAsDraft;
  @override
  final bool canReplaceChapter;
  @override
  final bool canCreateNewChapter;
  @override
  final String? currentChapterTitle;
  @override
  final int suggestedSortOrder;
  @override
  final String? defaultVolumeId;

  @override
  String toString() {
    return 'POVSaveOptions(canSaveAsDraft: $canSaveAsDraft, canReplaceChapter: $canReplaceChapter, canCreateNewChapter: $canCreateNewChapter, currentChapterTitle: $currentChapterTitle, suggestedSortOrder: $suggestedSortOrder, defaultVolumeId: $defaultVolumeId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$POVSaveOptionsImpl &&
            (identical(other.canSaveAsDraft, canSaveAsDraft) ||
                other.canSaveAsDraft == canSaveAsDraft) &&
            (identical(other.canReplaceChapter, canReplaceChapter) ||
                other.canReplaceChapter == canReplaceChapter) &&
            (identical(other.canCreateNewChapter, canCreateNewChapter) ||
                other.canCreateNewChapter == canCreateNewChapter) &&
            (identical(other.currentChapterTitle, currentChapterTitle) ||
                other.currentChapterTitle == currentChapterTitle) &&
            (identical(other.suggestedSortOrder, suggestedSortOrder) ||
                other.suggestedSortOrder == suggestedSortOrder) &&
            (identical(other.defaultVolumeId, defaultVolumeId) ||
                other.defaultVolumeId == defaultVolumeId));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      canSaveAsDraft,
      canReplaceChapter,
      canCreateNewChapter,
      currentChapterTitle,
      suggestedSortOrder,
      defaultVolumeId);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$POVSaveOptionsImplCopyWith<_$POVSaveOptionsImpl> get copyWith =>
      __$$POVSaveOptionsImplCopyWithImpl<_$POVSaveOptionsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$POVSaveOptionsImplToJson(
      this,
    );
  }
}

abstract class _POVSaveOptions implements POVSaveOptions {
  const factory _POVSaveOptions(
      {required final bool canSaveAsDraft,
      required final bool canReplaceChapter,
      required final bool canCreateNewChapter,
      final String? currentChapterTitle,
      required final int suggestedSortOrder,
      final String? defaultVolumeId}) = _$POVSaveOptionsImpl;

  factory _POVSaveOptions.fromJson(Map<String, dynamic> json) =
      _$POVSaveOptionsImpl.fromJson;

  @override
  bool get canSaveAsDraft;
  @override
  bool get canReplaceChapter;
  @override
  bool get canCreateNewChapter;
  @override
  String? get currentChapterTitle;
  @override
  int get suggestedSortOrder;
  @override
  String? get defaultVolumeId;
  @override
  @JsonKey(ignore: true)
  _$$POVSaveOptionsImplCopyWith<_$POVSaveOptionsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
