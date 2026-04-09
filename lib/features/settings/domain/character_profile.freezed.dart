// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'character_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BigFive _$BigFiveFromJson(Map<String, dynamic> json) {
  return _BigFive.fromJson(json);
}

/// @nodoc
mixin _$BigFive {
  int get openness => throw _privateConstructorUsedError; // 开放性 0-100
  int get conscientiousness => throw _privateConstructorUsedError; // 尽责性 0-100
  int get extraversion => throw _privateConstructorUsedError; // 外向性 0-100
  int get agreeableness => throw _privateConstructorUsedError; // 宜人性 0-100
  int get neuroticism => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BigFiveCopyWith<BigFive> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BigFiveCopyWith<$Res> {
  factory $BigFiveCopyWith(BigFive value, $Res Function(BigFive) then) =
      _$BigFiveCopyWithImpl<$Res, BigFive>;
  @useResult
  $Res call(
      {int openness,
      int conscientiousness,
      int extraversion,
      int agreeableness,
      int neuroticism});
}

/// @nodoc
class _$BigFiveCopyWithImpl<$Res, $Val extends BigFive>
    implements $BigFiveCopyWith<$Res> {
  _$BigFiveCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? openness = null,
    Object? conscientiousness = null,
    Object? extraversion = null,
    Object? agreeableness = null,
    Object? neuroticism = null,
  }) {
    return _then(_value.copyWith(
      openness: null == openness
          ? _value.openness
          : openness // ignore: cast_nullable_to_non_nullable
              as int,
      conscientiousness: null == conscientiousness
          ? _value.conscientiousness
          : conscientiousness // ignore: cast_nullable_to_non_nullable
              as int,
      extraversion: null == extraversion
          ? _value.extraversion
          : extraversion // ignore: cast_nullable_to_non_nullable
              as int,
      agreeableness: null == agreeableness
          ? _value.agreeableness
          : agreeableness // ignore: cast_nullable_to_non_nullable
              as int,
      neuroticism: null == neuroticism
          ? _value.neuroticism
          : neuroticism // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BigFiveImplCopyWith<$Res> implements $BigFiveCopyWith<$Res> {
  factory _$$BigFiveImplCopyWith(
          _$BigFiveImpl value, $Res Function(_$BigFiveImpl) then) =
      __$$BigFiveImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int openness,
      int conscientiousness,
      int extraversion,
      int agreeableness,
      int neuroticism});
}

/// @nodoc
class __$$BigFiveImplCopyWithImpl<$Res>
    extends _$BigFiveCopyWithImpl<$Res, _$BigFiveImpl>
    implements _$$BigFiveImplCopyWith<$Res> {
  __$$BigFiveImplCopyWithImpl(
      _$BigFiveImpl _value, $Res Function(_$BigFiveImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? openness = null,
    Object? conscientiousness = null,
    Object? extraversion = null,
    Object? agreeableness = null,
    Object? neuroticism = null,
  }) {
    return _then(_$BigFiveImpl(
      openness: null == openness
          ? _value.openness
          : openness // ignore: cast_nullable_to_non_nullable
              as int,
      conscientiousness: null == conscientiousness
          ? _value.conscientiousness
          : conscientiousness // ignore: cast_nullable_to_non_nullable
              as int,
      extraversion: null == extraversion
          ? _value.extraversion
          : extraversion // ignore: cast_nullable_to_non_nullable
              as int,
      agreeableness: null == agreeableness
          ? _value.agreeableness
          : agreeableness // ignore: cast_nullable_to_non_nullable
              as int,
      neuroticism: null == neuroticism
          ? _value.neuroticism
          : neuroticism // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BigFiveImpl implements _BigFive {
  const _$BigFiveImpl(
      {this.openness = 50,
      this.conscientiousness = 50,
      this.extraversion = 50,
      this.agreeableness = 50,
      this.neuroticism = 50});

  factory _$BigFiveImpl.fromJson(Map<String, dynamic> json) =>
      _$$BigFiveImplFromJson(json);

  @override
  @JsonKey()
  final int openness;
// 开放性 0-100
  @override
  @JsonKey()
  final int conscientiousness;
// 尽责性 0-100
  @override
  @JsonKey()
  final int extraversion;
// 外向性 0-100
  @override
  @JsonKey()
  final int agreeableness;
// 宜人性 0-100
  @override
  @JsonKey()
  final int neuroticism;

  @override
  String toString() {
    return 'BigFive(openness: $openness, conscientiousness: $conscientiousness, extraversion: $extraversion, agreeableness: $agreeableness, neuroticism: $neuroticism)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BigFiveImpl &&
            (identical(other.openness, openness) ||
                other.openness == openness) &&
            (identical(other.conscientiousness, conscientiousness) ||
                other.conscientiousness == conscientiousness) &&
            (identical(other.extraversion, extraversion) ||
                other.extraversion == extraversion) &&
            (identical(other.agreeableness, agreeableness) ||
                other.agreeableness == agreeableness) &&
            (identical(other.neuroticism, neuroticism) ||
                other.neuroticism == neuroticism));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, openness, conscientiousness,
      extraversion, agreeableness, neuroticism);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BigFiveImplCopyWith<_$BigFiveImpl> get copyWith =>
      __$$BigFiveImplCopyWithImpl<_$BigFiveImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BigFiveImplToJson(
      this,
    );
  }
}

abstract class _BigFive implements BigFive {
  const factory _BigFive(
      {final int openness,
      final int conscientiousness,
      final int extraversion,
      final int agreeableness,
      final int neuroticism}) = _$BigFiveImpl;

  factory _BigFive.fromJson(Map<String, dynamic> json) = _$BigFiveImpl.fromJson;

  @override
  int get openness;
  @override // 开放性 0-100
  int get conscientiousness;
  @override // 尽责性 0-100
  int get extraversion;
  @override // 外向性 0-100
  int get agreeableness;
  @override // 宜人性 0-100
  int get neuroticism;
  @override
  @JsonKey(ignore: true)
  _$$BigFiveImplCopyWith<_$BigFiveImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SpeechStyle _$SpeechStyleFromJson(Map<String, dynamic> json) {
  return _SpeechStyle.fromJson(json);
}

/// @nodoc
mixin _$SpeechStyle {
  String? get languageStyle =>
      throw _privateConstructorUsedError; // 简洁/文雅/粗俗/幽默
  String? get toneStyle => throw _privateConstructorUsedError; // 冷淡/热情/温和/嘲讽
  String get speed => throw _privateConstructorUsedError; // 快/中/慢
  List<String>? get sentencePatterns =>
      throw _privateConstructorUsedError; // 句式偏好
  List<String>? get catchphrases => throw _privateConstructorUsedError; // 口头禅
  List<String>? get vocabularyPreferences =>
      throw _privateConstructorUsedError; // 词汇偏好
  List<String>? get tabooWords => throw _privateConstructorUsedError; // 避讳词
  List<SpeechExample>? get examples => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SpeechStyleCopyWith<SpeechStyle> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpeechStyleCopyWith<$Res> {
  factory $SpeechStyleCopyWith(
          SpeechStyle value, $Res Function(SpeechStyle) then) =
      _$SpeechStyleCopyWithImpl<$Res, SpeechStyle>;
  @useResult
  $Res call(
      {String? languageStyle,
      String? toneStyle,
      String speed,
      List<String>? sentencePatterns,
      List<String>? catchphrases,
      List<String>? vocabularyPreferences,
      List<String>? tabooWords,
      List<SpeechExample>? examples});
}

/// @nodoc
class _$SpeechStyleCopyWithImpl<$Res, $Val extends SpeechStyle>
    implements $SpeechStyleCopyWith<$Res> {
  _$SpeechStyleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageStyle = freezed,
    Object? toneStyle = freezed,
    Object? speed = null,
    Object? sentencePatterns = freezed,
    Object? catchphrases = freezed,
    Object? vocabularyPreferences = freezed,
    Object? tabooWords = freezed,
    Object? examples = freezed,
  }) {
    return _then(_value.copyWith(
      languageStyle: freezed == languageStyle
          ? _value.languageStyle
          : languageStyle // ignore: cast_nullable_to_non_nullable
              as String?,
      toneStyle: freezed == toneStyle
          ? _value.toneStyle
          : toneStyle // ignore: cast_nullable_to_non_nullable
              as String?,
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as String,
      sentencePatterns: freezed == sentencePatterns
          ? _value.sentencePatterns
          : sentencePatterns // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      catchphrases: freezed == catchphrases
          ? _value.catchphrases
          : catchphrases // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      vocabularyPreferences: freezed == vocabularyPreferences
          ? _value.vocabularyPreferences
          : vocabularyPreferences // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tabooWords: freezed == tabooWords
          ? _value.tabooWords
          : tabooWords // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      examples: freezed == examples
          ? _value.examples
          : examples // ignore: cast_nullable_to_non_nullable
              as List<SpeechExample>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SpeechStyleImplCopyWith<$Res>
    implements $SpeechStyleCopyWith<$Res> {
  factory _$$SpeechStyleImplCopyWith(
          _$SpeechStyleImpl value, $Res Function(_$SpeechStyleImpl) then) =
      __$$SpeechStyleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? languageStyle,
      String? toneStyle,
      String speed,
      List<String>? sentencePatterns,
      List<String>? catchphrases,
      List<String>? vocabularyPreferences,
      List<String>? tabooWords,
      List<SpeechExample>? examples});
}

/// @nodoc
class __$$SpeechStyleImplCopyWithImpl<$Res>
    extends _$SpeechStyleCopyWithImpl<$Res, _$SpeechStyleImpl>
    implements _$$SpeechStyleImplCopyWith<$Res> {
  __$$SpeechStyleImplCopyWithImpl(
      _$SpeechStyleImpl _value, $Res Function(_$SpeechStyleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageStyle = freezed,
    Object? toneStyle = freezed,
    Object? speed = null,
    Object? sentencePatterns = freezed,
    Object? catchphrases = freezed,
    Object? vocabularyPreferences = freezed,
    Object? tabooWords = freezed,
    Object? examples = freezed,
  }) {
    return _then(_$SpeechStyleImpl(
      languageStyle: freezed == languageStyle
          ? _value.languageStyle
          : languageStyle // ignore: cast_nullable_to_non_nullable
              as String?,
      toneStyle: freezed == toneStyle
          ? _value.toneStyle
          : toneStyle // ignore: cast_nullable_to_non_nullable
              as String?,
      speed: null == speed
          ? _value.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as String,
      sentencePatterns: freezed == sentencePatterns
          ? _value._sentencePatterns
          : sentencePatterns // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      catchphrases: freezed == catchphrases
          ? _value._catchphrases
          : catchphrases // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      vocabularyPreferences: freezed == vocabularyPreferences
          ? _value._vocabularyPreferences
          : vocabularyPreferences // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      tabooWords: freezed == tabooWords
          ? _value._tabooWords
          : tabooWords // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      examples: freezed == examples
          ? _value._examples
          : examples // ignore: cast_nullable_to_non_nullable
              as List<SpeechExample>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SpeechStyleImpl implements _SpeechStyle {
  const _$SpeechStyleImpl(
      {this.languageStyle,
      this.toneStyle,
      this.speed = 'medium',
      final List<String>? sentencePatterns,
      final List<String>? catchphrases,
      final List<String>? vocabularyPreferences,
      final List<String>? tabooWords,
      final List<SpeechExample>? examples})
      : _sentencePatterns = sentencePatterns,
        _catchphrases = catchphrases,
        _vocabularyPreferences = vocabularyPreferences,
        _tabooWords = tabooWords,
        _examples = examples;

  factory _$SpeechStyleImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpeechStyleImplFromJson(json);

  @override
  final String? languageStyle;
// 简洁/文雅/粗俗/幽默
  @override
  final String? toneStyle;
// 冷淡/热情/温和/嘲讽
  @override
  @JsonKey()
  final String speed;
// 快/中/慢
  final List<String>? _sentencePatterns;
// 快/中/慢
  @override
  List<String>? get sentencePatterns {
    final value = _sentencePatterns;
    if (value == null) return null;
    if (_sentencePatterns is EqualUnmodifiableListView)
      return _sentencePatterns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// 句式偏好
  final List<String>? _catchphrases;
// 句式偏好
  @override
  List<String>? get catchphrases {
    final value = _catchphrases;
    if (value == null) return null;
    if (_catchphrases is EqualUnmodifiableListView) return _catchphrases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// 口头禅
  final List<String>? _vocabularyPreferences;
// 口头禅
  @override
  List<String>? get vocabularyPreferences {
    final value = _vocabularyPreferences;
    if (value == null) return null;
    if (_vocabularyPreferences is EqualUnmodifiableListView)
      return _vocabularyPreferences;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// 词汇偏好
  final List<String>? _tabooWords;
// 词汇偏好
  @override
  List<String>? get tabooWords {
    final value = _tabooWords;
    if (value == null) return null;
    if (_tabooWords is EqualUnmodifiableListView) return _tabooWords;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

// 避讳词
  final List<SpeechExample>? _examples;
// 避讳词
  @override
  List<SpeechExample>? get examples {
    final value = _examples;
    if (value == null) return null;
    if (_examples is EqualUnmodifiableListView) return _examples;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'SpeechStyle(languageStyle: $languageStyle, toneStyle: $toneStyle, speed: $speed, sentencePatterns: $sentencePatterns, catchphrases: $catchphrases, vocabularyPreferences: $vocabularyPreferences, tabooWords: $tabooWords, examples: $examples)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpeechStyleImpl &&
            (identical(other.languageStyle, languageStyle) ||
                other.languageStyle == languageStyle) &&
            (identical(other.toneStyle, toneStyle) ||
                other.toneStyle == toneStyle) &&
            (identical(other.speed, speed) || other.speed == speed) &&
            const DeepCollectionEquality()
                .equals(other._sentencePatterns, _sentencePatterns) &&
            const DeepCollectionEquality()
                .equals(other._catchphrases, _catchphrases) &&
            const DeepCollectionEquality()
                .equals(other._vocabularyPreferences, _vocabularyPreferences) &&
            const DeepCollectionEquality()
                .equals(other._tabooWords, _tabooWords) &&
            const DeepCollectionEquality().equals(other._examples, _examples));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      languageStyle,
      toneStyle,
      speed,
      const DeepCollectionEquality().hash(_sentencePatterns),
      const DeepCollectionEquality().hash(_catchphrases),
      const DeepCollectionEquality().hash(_vocabularyPreferences),
      const DeepCollectionEquality().hash(_tabooWords),
      const DeepCollectionEquality().hash(_examples));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SpeechStyleImplCopyWith<_$SpeechStyleImpl> get copyWith =>
      __$$SpeechStyleImplCopyWithImpl<_$SpeechStyleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SpeechStyleImplToJson(
      this,
    );
  }
}

abstract class _SpeechStyle implements SpeechStyle {
  const factory _SpeechStyle(
      {final String? languageStyle,
      final String? toneStyle,
      final String speed,
      final List<String>? sentencePatterns,
      final List<String>? catchphrases,
      final List<String>? vocabularyPreferences,
      final List<String>? tabooWords,
      final List<SpeechExample>? examples}) = _$SpeechStyleImpl;

  factory _SpeechStyle.fromJson(Map<String, dynamic> json) =
      _$SpeechStyleImpl.fromJson;

  @override
  String? get languageStyle;
  @override // 简洁/文雅/粗俗/幽默
  String? get toneStyle;
  @override // 冷淡/热情/温和/嘲讽
  String get speed;
  @override // 快/中/慢
  List<String>? get sentencePatterns;
  @override // 句式偏好
  List<String>? get catchphrases;
  @override // 口头禅
  List<String>? get vocabularyPreferences;
  @override // 词汇偏好
  List<String>? get tabooWords;
  @override // 避讳词
  List<SpeechExample>? get examples;
  @override
  @JsonKey(ignore: true)
  _$$SpeechStyleImplCopyWith<_$SpeechStyleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SpeechExample _$SpeechExampleFromJson(Map<String, dynamic> json) {
  return _SpeechExample.fromJson(json);
}

/// @nodoc
mixin _$SpeechExample {
  String get scene => throw _privateConstructorUsedError;
  String get emotion => throw _privateConstructorUsedError;
  String get line => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SpeechExampleCopyWith<SpeechExample> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SpeechExampleCopyWith<$Res> {
  factory $SpeechExampleCopyWith(
          SpeechExample value, $Res Function(SpeechExample) then) =
      _$SpeechExampleCopyWithImpl<$Res, SpeechExample>;
  @useResult
  $Res call({String scene, String emotion, String line});
}

/// @nodoc
class _$SpeechExampleCopyWithImpl<$Res, $Val extends SpeechExample>
    implements $SpeechExampleCopyWith<$Res> {
  _$SpeechExampleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scene = null,
    Object? emotion = null,
    Object? line = null,
  }) {
    return _then(_value.copyWith(
      scene: null == scene
          ? _value.scene
          : scene // ignore: cast_nullable_to_non_nullable
              as String,
      emotion: null == emotion
          ? _value.emotion
          : emotion // ignore: cast_nullable_to_non_nullable
              as String,
      line: null == line
          ? _value.line
          : line // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SpeechExampleImplCopyWith<$Res>
    implements $SpeechExampleCopyWith<$Res> {
  factory _$$SpeechExampleImplCopyWith(
          _$SpeechExampleImpl value, $Res Function(_$SpeechExampleImpl) then) =
      __$$SpeechExampleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String scene, String emotion, String line});
}

/// @nodoc
class __$$SpeechExampleImplCopyWithImpl<$Res>
    extends _$SpeechExampleCopyWithImpl<$Res, _$SpeechExampleImpl>
    implements _$$SpeechExampleImplCopyWith<$Res> {
  __$$SpeechExampleImplCopyWithImpl(
      _$SpeechExampleImpl _value, $Res Function(_$SpeechExampleImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? scene = null,
    Object? emotion = null,
    Object? line = null,
  }) {
    return _then(_$SpeechExampleImpl(
      scene: null == scene
          ? _value.scene
          : scene // ignore: cast_nullable_to_non_nullable
              as String,
      emotion: null == emotion
          ? _value.emotion
          : emotion // ignore: cast_nullable_to_non_nullable
              as String,
      line: null == line
          ? _value.line
          : line // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SpeechExampleImpl implements _SpeechExample {
  const _$SpeechExampleImpl(
      {required this.scene, required this.emotion, required this.line});

  factory _$SpeechExampleImpl.fromJson(Map<String, dynamic> json) =>
      _$$SpeechExampleImplFromJson(json);

  @override
  final String scene;
  @override
  final String emotion;
  @override
  final String line;

  @override
  String toString() {
    return 'SpeechExample(scene: $scene, emotion: $emotion, line: $line)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SpeechExampleImpl &&
            (identical(other.scene, scene) || other.scene == scene) &&
            (identical(other.emotion, emotion) || other.emotion == emotion) &&
            (identical(other.line, line) || other.line == line));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, scene, emotion, line);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$SpeechExampleImplCopyWith<_$SpeechExampleImpl> get copyWith =>
      __$$SpeechExampleImplCopyWithImpl<_$SpeechExampleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SpeechExampleImplToJson(
      this,
    );
  }
}

abstract class _SpeechExample implements SpeechExample {
  const factory _SpeechExample(
      {required final String scene,
      required final String emotion,
      required final String line}) = _$SpeechExampleImpl;

  factory _SpeechExample.fromJson(Map<String, dynamic> json) =
      _$SpeechExampleImpl.fromJson;

  @override
  String get scene;
  @override
  String get emotion;
  @override
  String get line;
  @override
  @JsonKey(ignore: true)
  _$$SpeechExampleImplCopyWith<_$SpeechExampleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

BehaviorPattern _$BehaviorPatternFromJson(Map<String, dynamic> json) {
  return _BehaviorPattern.fromJson(json);
}

/// @nodoc
mixin _$BehaviorPattern {
  String get trigger => throw _privateConstructorUsedError; // 触发条件
  String get behavior => throw _privateConstructorUsedError; // 行为反应
  String? get description => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $BehaviorPatternCopyWith<BehaviorPattern> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BehaviorPatternCopyWith<$Res> {
  factory $BehaviorPatternCopyWith(
          BehaviorPattern value, $Res Function(BehaviorPattern) then) =
      _$BehaviorPatternCopyWithImpl<$Res, BehaviorPattern>;
  @useResult
  $Res call({String trigger, String behavior, String? description});
}

/// @nodoc
class _$BehaviorPatternCopyWithImpl<$Res, $Val extends BehaviorPattern>
    implements $BehaviorPatternCopyWith<$Res> {
  _$BehaviorPatternCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trigger = null,
    Object? behavior = null,
    Object? description = freezed,
  }) {
    return _then(_value.copyWith(
      trigger: null == trigger
          ? _value.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as String,
      behavior: null == behavior
          ? _value.behavior
          : behavior // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BehaviorPatternImplCopyWith<$Res>
    implements $BehaviorPatternCopyWith<$Res> {
  factory _$$BehaviorPatternImplCopyWith(_$BehaviorPatternImpl value,
          $Res Function(_$BehaviorPatternImpl) then) =
      __$$BehaviorPatternImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String trigger, String behavior, String? description});
}

/// @nodoc
class __$$BehaviorPatternImplCopyWithImpl<$Res>
    extends _$BehaviorPatternCopyWithImpl<$Res, _$BehaviorPatternImpl>
    implements _$$BehaviorPatternImplCopyWith<$Res> {
  __$$BehaviorPatternImplCopyWithImpl(
      _$BehaviorPatternImpl _value, $Res Function(_$BehaviorPatternImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? trigger = null,
    Object? behavior = null,
    Object? description = freezed,
  }) {
    return _then(_$BehaviorPatternImpl(
      trigger: null == trigger
          ? _value.trigger
          : trigger // ignore: cast_nullable_to_non_nullable
              as String,
      behavior: null == behavior
          ? _value.behavior
          : behavior // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BehaviorPatternImpl implements _BehaviorPattern {
  const _$BehaviorPatternImpl(
      {required this.trigger, required this.behavior, this.description});

  factory _$BehaviorPatternImpl.fromJson(Map<String, dynamic> json) =>
      _$$BehaviorPatternImplFromJson(json);

  @override
  final String trigger;
// 触发条件
  @override
  final String behavior;
// 行为反应
  @override
  final String? description;

  @override
  String toString() {
    return 'BehaviorPattern(trigger: $trigger, behavior: $behavior, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BehaviorPatternImpl &&
            (identical(other.trigger, trigger) || other.trigger == trigger) &&
            (identical(other.behavior, behavior) ||
                other.behavior == behavior) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, trigger, behavior, description);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$BehaviorPatternImplCopyWith<_$BehaviorPatternImpl> get copyWith =>
      __$$BehaviorPatternImplCopyWithImpl<_$BehaviorPatternImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BehaviorPatternImplToJson(
      this,
    );
  }
}

abstract class _BehaviorPattern implements BehaviorPattern {
  const factory _BehaviorPattern(
      {required final String trigger,
      required final String behavior,
      final String? description}) = _$BehaviorPatternImpl;

  factory _BehaviorPattern.fromJson(Map<String, dynamic> json) =
      _$BehaviorPatternImpl.fromJson;

  @override
  String get trigger;
  @override // 触发条件
  String get behavior;
  @override // 行为反应
  String? get description;
  @override
  @JsonKey(ignore: true)
  _$$BehaviorPatternImplCopyWith<_$BehaviorPatternImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CharacterProfile _$CharacterProfileFromJson(Map<String, dynamic> json) {
  return _CharacterProfile.fromJson(json);
}

/// @nodoc
mixin _$CharacterProfile {
  String get id => throw _privateConstructorUsedError;
  String get characterId => throw _privateConstructorUsedError;
  MBTI? get mbti => throw _privateConstructorUsedError;
  BigFive? get bigFive => throw _privateConstructorUsedError;
  List<String> get personalityKeywords => throw _privateConstructorUsedError;
  String? get coreValues => throw _privateConstructorUsedError;
  String? get fears => throw _privateConstructorUsedError;
  String? get desires => throw _privateConstructorUsedError;
  String? get moralBaseline => throw _privateConstructorUsedError;
  SpeechStyle? get speechStyle => throw _privateConstructorUsedError;
  List<BehaviorPattern> get behaviorPatterns =>
      throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CharacterProfileCopyWith<CharacterProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CharacterProfileCopyWith<$Res> {
  factory $CharacterProfileCopyWith(
          CharacterProfile value, $Res Function(CharacterProfile) then) =
      _$CharacterProfileCopyWithImpl<$Res, CharacterProfile>;
  @useResult
  $Res call(
      {String id,
      String characterId,
      MBTI? mbti,
      BigFive? bigFive,
      List<String> personalityKeywords,
      String? coreValues,
      String? fears,
      String? desires,
      String? moralBaseline,
      SpeechStyle? speechStyle,
      List<BehaviorPattern> behaviorPatterns,
      DateTime createdAt,
      DateTime updatedAt});

  $BigFiveCopyWith<$Res>? get bigFive;
  $SpeechStyleCopyWith<$Res>? get speechStyle;
}

/// @nodoc
class _$CharacterProfileCopyWithImpl<$Res, $Val extends CharacterProfile>
    implements $CharacterProfileCopyWith<$Res> {
  _$CharacterProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? characterId = null,
    Object? mbti = freezed,
    Object? bigFive = freezed,
    Object? personalityKeywords = null,
    Object? coreValues = freezed,
    Object? fears = freezed,
    Object? desires = freezed,
    Object? moralBaseline = freezed,
    Object? speechStyle = freezed,
    Object? behaviorPatterns = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      mbti: freezed == mbti
          ? _value.mbti
          : mbti // ignore: cast_nullable_to_non_nullable
              as MBTI?,
      bigFive: freezed == bigFive
          ? _value.bigFive
          : bigFive // ignore: cast_nullable_to_non_nullable
              as BigFive?,
      personalityKeywords: null == personalityKeywords
          ? _value.personalityKeywords
          : personalityKeywords // ignore: cast_nullable_to_non_nullable
              as List<String>,
      coreValues: freezed == coreValues
          ? _value.coreValues
          : coreValues // ignore: cast_nullable_to_non_nullable
              as String?,
      fears: freezed == fears
          ? _value.fears
          : fears // ignore: cast_nullable_to_non_nullable
              as String?,
      desires: freezed == desires
          ? _value.desires
          : desires // ignore: cast_nullable_to_non_nullable
              as String?,
      moralBaseline: freezed == moralBaseline
          ? _value.moralBaseline
          : moralBaseline // ignore: cast_nullable_to_non_nullable
              as String?,
      speechStyle: freezed == speechStyle
          ? _value.speechStyle
          : speechStyle // ignore: cast_nullable_to_non_nullable
              as SpeechStyle?,
      behaviorPatterns: null == behaviorPatterns
          ? _value.behaviorPatterns
          : behaviorPatterns // ignore: cast_nullable_to_non_nullable
              as List<BehaviorPattern>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $BigFiveCopyWith<$Res>? get bigFive {
    if (_value.bigFive == null) {
      return null;
    }

    return $BigFiveCopyWith<$Res>(_value.bigFive!, (value) {
      return _then(_value.copyWith(bigFive: value) as $Val);
    });
  }

  @override
  @pragma('vm:prefer-inline')
  $SpeechStyleCopyWith<$Res>? get speechStyle {
    if (_value.speechStyle == null) {
      return null;
    }

    return $SpeechStyleCopyWith<$Res>(_value.speechStyle!, (value) {
      return _then(_value.copyWith(speechStyle: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CharacterProfileImplCopyWith<$Res>
    implements $CharacterProfileCopyWith<$Res> {
  factory _$$CharacterProfileImplCopyWith(_$CharacterProfileImpl value,
          $Res Function(_$CharacterProfileImpl) then) =
      __$$CharacterProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String characterId,
      MBTI? mbti,
      BigFive? bigFive,
      List<String> personalityKeywords,
      String? coreValues,
      String? fears,
      String? desires,
      String? moralBaseline,
      SpeechStyle? speechStyle,
      List<BehaviorPattern> behaviorPatterns,
      DateTime createdAt,
      DateTime updatedAt});

  @override
  $BigFiveCopyWith<$Res>? get bigFive;
  @override
  $SpeechStyleCopyWith<$Res>? get speechStyle;
}

/// @nodoc
class __$$CharacterProfileImplCopyWithImpl<$Res>
    extends _$CharacterProfileCopyWithImpl<$Res, _$CharacterProfileImpl>
    implements _$$CharacterProfileImplCopyWith<$Res> {
  __$$CharacterProfileImplCopyWithImpl(_$CharacterProfileImpl _value,
      $Res Function(_$CharacterProfileImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? characterId = null,
    Object? mbti = freezed,
    Object? bigFive = freezed,
    Object? personalityKeywords = null,
    Object? coreValues = freezed,
    Object? fears = freezed,
    Object? desires = freezed,
    Object? moralBaseline = freezed,
    Object? speechStyle = freezed,
    Object? behaviorPatterns = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(_$CharacterProfileImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      characterId: null == characterId
          ? _value.characterId
          : characterId // ignore: cast_nullable_to_non_nullable
              as String,
      mbti: freezed == mbti
          ? _value.mbti
          : mbti // ignore: cast_nullable_to_non_nullable
              as MBTI?,
      bigFive: freezed == bigFive
          ? _value.bigFive
          : bigFive // ignore: cast_nullable_to_non_nullable
              as BigFive?,
      personalityKeywords: null == personalityKeywords
          ? _value._personalityKeywords
          : personalityKeywords // ignore: cast_nullable_to_non_nullable
              as List<String>,
      coreValues: freezed == coreValues
          ? _value.coreValues
          : coreValues // ignore: cast_nullable_to_non_nullable
              as String?,
      fears: freezed == fears
          ? _value.fears
          : fears // ignore: cast_nullable_to_non_nullable
              as String?,
      desires: freezed == desires
          ? _value.desires
          : desires // ignore: cast_nullable_to_non_nullable
              as String?,
      moralBaseline: freezed == moralBaseline
          ? _value.moralBaseline
          : moralBaseline // ignore: cast_nullable_to_non_nullable
              as String?,
      speechStyle: freezed == speechStyle
          ? _value.speechStyle
          : speechStyle // ignore: cast_nullable_to_non_nullable
              as SpeechStyle?,
      behaviorPatterns: null == behaviorPatterns
          ? _value._behaviorPatterns
          : behaviorPatterns // ignore: cast_nullable_to_non_nullable
              as List<BehaviorPattern>,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: null == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CharacterProfileImpl extends _CharacterProfile {
  const _$CharacterProfileImpl(
      {required this.id,
      required this.characterId,
      this.mbti,
      this.bigFive,
      final List<String> personalityKeywords = const [],
      this.coreValues,
      this.fears,
      this.desires,
      this.moralBaseline,
      this.speechStyle,
      final List<BehaviorPattern> behaviorPatterns = const [],
      required this.createdAt,
      required this.updatedAt})
      : _personalityKeywords = personalityKeywords,
        _behaviorPatterns = behaviorPatterns,
        super._();

  factory _$CharacterProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$CharacterProfileImplFromJson(json);

  @override
  final String id;
  @override
  final String characterId;
  @override
  final MBTI? mbti;
  @override
  final BigFive? bigFive;
  final List<String> _personalityKeywords;
  @override
  @JsonKey()
  List<String> get personalityKeywords {
    if (_personalityKeywords is EqualUnmodifiableListView)
      return _personalityKeywords;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_personalityKeywords);
  }

  @override
  final String? coreValues;
  @override
  final String? fears;
  @override
  final String? desires;
  @override
  final String? moralBaseline;
  @override
  final SpeechStyle? speechStyle;
  final List<BehaviorPattern> _behaviorPatterns;
  @override
  @JsonKey()
  List<BehaviorPattern> get behaviorPatterns {
    if (_behaviorPatterns is EqualUnmodifiableListView)
      return _behaviorPatterns;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_behaviorPatterns);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'CharacterProfile(id: $id, characterId: $characterId, mbti: $mbti, bigFive: $bigFive, personalityKeywords: $personalityKeywords, coreValues: $coreValues, fears: $fears, desires: $desires, moralBaseline: $moralBaseline, speechStyle: $speechStyle, behaviorPatterns: $behaviorPatterns, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CharacterProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.characterId, characterId) ||
                other.characterId == characterId) &&
            (identical(other.mbti, mbti) || other.mbti == mbti) &&
            (identical(other.bigFive, bigFive) || other.bigFive == bigFive) &&
            const DeepCollectionEquality()
                .equals(other._personalityKeywords, _personalityKeywords) &&
            (identical(other.coreValues, coreValues) ||
                other.coreValues == coreValues) &&
            (identical(other.fears, fears) || other.fears == fears) &&
            (identical(other.desires, desires) || other.desires == desires) &&
            (identical(other.moralBaseline, moralBaseline) ||
                other.moralBaseline == moralBaseline) &&
            (identical(other.speechStyle, speechStyle) ||
                other.speechStyle == speechStyle) &&
            const DeepCollectionEquality()
                .equals(other._behaviorPatterns, _behaviorPatterns) &&
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
      characterId,
      mbti,
      bigFive,
      const DeepCollectionEquality().hash(_personalityKeywords),
      coreValues,
      fears,
      desires,
      moralBaseline,
      speechStyle,
      const DeepCollectionEquality().hash(_behaviorPatterns),
      createdAt,
      updatedAt);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CharacterProfileImplCopyWith<_$CharacterProfileImpl> get copyWith =>
      __$$CharacterProfileImplCopyWithImpl<_$CharacterProfileImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CharacterProfileImplToJson(
      this,
    );
  }
}

abstract class _CharacterProfile extends CharacterProfile {
  const factory _CharacterProfile(
      {required final String id,
      required final String characterId,
      final MBTI? mbti,
      final BigFive? bigFive,
      final List<String> personalityKeywords,
      final String? coreValues,
      final String? fears,
      final String? desires,
      final String? moralBaseline,
      final SpeechStyle? speechStyle,
      final List<BehaviorPattern> behaviorPatterns,
      required final DateTime createdAt,
      required final DateTime updatedAt}) = _$CharacterProfileImpl;
  const _CharacterProfile._() : super._();

  factory _CharacterProfile.fromJson(Map<String, dynamic> json) =
      _$CharacterProfileImpl.fromJson;

  @override
  String get id;
  @override
  String get characterId;
  @override
  MBTI? get mbti;
  @override
  BigFive? get bigFive;
  @override
  List<String> get personalityKeywords;
  @override
  String? get coreValues;
  @override
  String? get fears;
  @override
  String? get desires;
  @override
  String? get moralBaseline;
  @override
  SpeechStyle? get speechStyle;
  @override
  List<BehaviorPattern> get behaviorPatterns;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;
  @override
  @JsonKey(ignore: true)
  _$$CharacterProfileImplCopyWith<_$CharacterProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
