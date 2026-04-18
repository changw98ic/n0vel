// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'detection_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ForbiddenPattern _$ForbiddenPatternFromJson(Map<String, dynamic> json) {
  return _ForbiddenPattern.fromJson(json);
}

/// @nodoc
mixin _$ForbiddenPattern {
  String get id => throw _privateConstructorUsedError;
  String get pattern => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  List<String> get examples => throw _privateConstructorUsedError;
  bool get isEnabled => throw _privateConstructorUsedError;

  /// Serializes this ForbiddenPattern to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ForbiddenPattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ForbiddenPatternCopyWith<ForbiddenPattern> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ForbiddenPatternCopyWith<$Res> {
  factory $ForbiddenPatternCopyWith(
    ForbiddenPattern value,
    $Res Function(ForbiddenPattern) then,
  ) = _$ForbiddenPatternCopyWithImpl<$Res, ForbiddenPattern>;
  @useResult
  $Res call({
    String id,
    String pattern,
    String description,
    List<String> examples,
    bool isEnabled,
  });
}

/// @nodoc
class _$ForbiddenPatternCopyWithImpl<$Res, $Val extends ForbiddenPattern>
    implements $ForbiddenPatternCopyWith<$Res> {
  _$ForbiddenPatternCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ForbiddenPattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? pattern = null,
    Object? description = null,
    Object? examples = null,
    Object? isEnabled = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            pattern: null == pattern
                ? _value.pattern
                : pattern // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            examples: null == examples
                ? _value.examples
                : examples // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            isEnabled: null == isEnabled
                ? _value.isEnabled
                : isEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ForbiddenPatternImplCopyWith<$Res>
    implements $ForbiddenPatternCopyWith<$Res> {
  factory _$$ForbiddenPatternImplCopyWith(
    _$ForbiddenPatternImpl value,
    $Res Function(_$ForbiddenPatternImpl) then,
  ) = __$$ForbiddenPatternImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String pattern,
    String description,
    List<String> examples,
    bool isEnabled,
  });
}

/// @nodoc
class __$$ForbiddenPatternImplCopyWithImpl<$Res>
    extends _$ForbiddenPatternCopyWithImpl<$Res, _$ForbiddenPatternImpl>
    implements _$$ForbiddenPatternImplCopyWith<$Res> {
  __$$ForbiddenPatternImplCopyWithImpl(
    _$ForbiddenPatternImpl _value,
    $Res Function(_$ForbiddenPatternImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ForbiddenPattern
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? pattern = null,
    Object? description = null,
    Object? examples = null,
    Object? isEnabled = null,
  }) {
    return _then(
      _$ForbiddenPatternImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        pattern: null == pattern
            ? _value.pattern
            : pattern // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        examples: null == examples
            ? _value._examples
            : examples // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        isEnabled: null == isEnabled
            ? _value.isEnabled
            : isEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ForbiddenPatternImpl implements _ForbiddenPattern {
  const _$ForbiddenPatternImpl({
    required this.id,
    required this.pattern,
    required this.description,
    final List<String> examples = const [],
    this.isEnabled = true,
  }) : _examples = examples;

  factory _$ForbiddenPatternImpl.fromJson(Map<String, dynamic> json) =>
      _$$ForbiddenPatternImplFromJson(json);

  @override
  final String id;
  @override
  final String pattern;
  @override
  final String description;
  final List<String> _examples;
  @override
  @JsonKey()
  List<String> get examples {
    if (_examples is EqualUnmodifiableListView) return _examples;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_examples);
  }

  @override
  @JsonKey()
  final bool isEnabled;

  @override
  String toString() {
    return 'ForbiddenPattern(id: $id, pattern: $pattern, description: $description, examples: $examples, isEnabled: $isEnabled)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForbiddenPatternImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.pattern, pattern) || other.pattern == pattern) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._examples, _examples) &&
            (identical(other.isEnabled, isEnabled) ||
                other.isEnabled == isEnabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    pattern,
    description,
    const DeepCollectionEquality().hash(_examples),
    isEnabled,
  );

  /// Create a copy of ForbiddenPattern
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForbiddenPatternImplCopyWith<_$ForbiddenPatternImpl> get copyWith =>
      __$$ForbiddenPatternImplCopyWithImpl<_$ForbiddenPatternImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ForbiddenPatternImplToJson(this);
  }
}

abstract class _ForbiddenPattern implements ForbiddenPattern {
  const factory _ForbiddenPattern({
    required final String id,
    required final String pattern,
    required final String description,
    final List<String> examples,
    final bool isEnabled,
  }) = _$ForbiddenPatternImpl;

  factory _ForbiddenPattern.fromJson(Map<String, dynamic> json) =
      _$ForbiddenPatternImpl.fromJson;

  @override
  String get id;
  @override
  String get pattern;
  @override
  String get description;
  @override
  List<String> get examples;
  @override
  bool get isEnabled;

  /// Create a copy of ForbiddenPattern
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForbiddenPatternImplCopyWith<_$ForbiddenPatternImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PunctuationLimit _$PunctuationLimitFromJson(Map<String, dynamic> json) {
  return _PunctuationLimit.fromJson(json);
}

/// @nodoc
mixin _$PunctuationLimit {
  String get punctuation => throw _privateConstructorUsedError;
  int get maxPerThousand => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Serializes this PunctuationLimit to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PunctuationLimit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PunctuationLimitCopyWith<PunctuationLimit> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PunctuationLimitCopyWith<$Res> {
  factory $PunctuationLimitCopyWith(
    PunctuationLimit value,
    $Res Function(PunctuationLimit) then,
  ) = _$PunctuationLimitCopyWithImpl<$Res, PunctuationLimit>;
  @useResult
  $Res call({String punctuation, int maxPerThousand, String description});
}

/// @nodoc
class _$PunctuationLimitCopyWithImpl<$Res, $Val extends PunctuationLimit>
    implements $PunctuationLimitCopyWith<$Res> {
  _$PunctuationLimitCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PunctuationLimit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? punctuation = null,
    Object? maxPerThousand = null,
    Object? description = null,
  }) {
    return _then(
      _value.copyWith(
            punctuation: null == punctuation
                ? _value.punctuation
                : punctuation // ignore: cast_nullable_to_non_nullable
                      as String,
            maxPerThousand: null == maxPerThousand
                ? _value.maxPerThousand
                : maxPerThousand // ignore: cast_nullable_to_non_nullable
                      as int,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PunctuationLimitImplCopyWith<$Res>
    implements $PunctuationLimitCopyWith<$Res> {
  factory _$$PunctuationLimitImplCopyWith(
    _$PunctuationLimitImpl value,
    $Res Function(_$PunctuationLimitImpl) then,
  ) = __$$PunctuationLimitImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String punctuation, int maxPerThousand, String description});
}

/// @nodoc
class __$$PunctuationLimitImplCopyWithImpl<$Res>
    extends _$PunctuationLimitCopyWithImpl<$Res, _$PunctuationLimitImpl>
    implements _$$PunctuationLimitImplCopyWith<$Res> {
  __$$PunctuationLimitImplCopyWithImpl(
    _$PunctuationLimitImpl _value,
    $Res Function(_$PunctuationLimitImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PunctuationLimit
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? punctuation = null,
    Object? maxPerThousand = null,
    Object? description = null,
  }) {
    return _then(
      _$PunctuationLimitImpl(
        punctuation: null == punctuation
            ? _value.punctuation
            : punctuation // ignore: cast_nullable_to_non_nullable
                  as String,
        maxPerThousand: null == maxPerThousand
            ? _value.maxPerThousand
            : maxPerThousand // ignore: cast_nullable_to_non_nullable
                  as int,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PunctuationLimitImpl implements _PunctuationLimit {
  const _$PunctuationLimitImpl({
    required this.punctuation,
    required this.maxPerThousand,
    required this.description,
  });

  factory _$PunctuationLimitImpl.fromJson(Map<String, dynamic> json) =>
      _$$PunctuationLimitImplFromJson(json);

  @override
  final String punctuation;
  @override
  final int maxPerThousand;
  @override
  final String description;

  @override
  String toString() {
    return 'PunctuationLimit(punctuation: $punctuation, maxPerThousand: $maxPerThousand, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PunctuationLimitImpl &&
            (identical(other.punctuation, punctuation) ||
                other.punctuation == punctuation) &&
            (identical(other.maxPerThousand, maxPerThousand) ||
                other.maxPerThousand == maxPerThousand) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, punctuation, maxPerThousand, description);

  /// Create a copy of PunctuationLimit
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PunctuationLimitImplCopyWith<_$PunctuationLimitImpl> get copyWith =>
      __$$PunctuationLimitImplCopyWithImpl<_$PunctuationLimitImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$PunctuationLimitImplToJson(this);
  }
}

abstract class _PunctuationLimit implements PunctuationLimit {
  const factory _PunctuationLimit({
    required final String punctuation,
    required final int maxPerThousand,
    required final String description,
  }) = _$PunctuationLimitImpl;

  factory _PunctuationLimit.fromJson(Map<String, dynamic> json) =
      _$PunctuationLimitImpl.fromJson;

  @override
  String get punctuation;
  @override
  int get maxPerThousand;
  @override
  String get description;

  /// Create a copy of PunctuationLimit
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PunctuationLimitImplCopyWith<_$PunctuationLimitImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AIVocabulary _$AIVocabularyFromJson(Map<String, dynamic> json) {
  return _AIVocabulary.fromJson(json);
}

/// @nodoc
mixin _$AIVocabulary {
  String get word => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  List<String> get alternatives => throw _privateConstructorUsedError;

  /// Serializes this AIVocabulary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AIVocabulary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AIVocabularyCopyWith<AIVocabulary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AIVocabularyCopyWith<$Res> {
  factory $AIVocabularyCopyWith(
    AIVocabulary value,
    $Res Function(AIVocabulary) then,
  ) = _$AIVocabularyCopyWithImpl<$Res, AIVocabulary>;
  @useResult
  $Res call({String word, String category, List<String> alternatives});
}

/// @nodoc
class _$AIVocabularyCopyWithImpl<$Res, $Val extends AIVocabulary>
    implements $AIVocabularyCopyWith<$Res> {
  _$AIVocabularyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AIVocabulary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? word = null,
    Object? category = null,
    Object? alternatives = null,
  }) {
    return _then(
      _value.copyWith(
            word: null == word
                ? _value.word
                : word // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            alternatives: null == alternatives
                ? _value.alternatives
                : alternatives // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AIVocabularyImplCopyWith<$Res>
    implements $AIVocabularyCopyWith<$Res> {
  factory _$$AIVocabularyImplCopyWith(
    _$AIVocabularyImpl value,
    $Res Function(_$AIVocabularyImpl) then,
  ) = __$$AIVocabularyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String word, String category, List<String> alternatives});
}

/// @nodoc
class __$$AIVocabularyImplCopyWithImpl<$Res>
    extends _$AIVocabularyCopyWithImpl<$Res, _$AIVocabularyImpl>
    implements _$$AIVocabularyImplCopyWith<$Res> {
  __$$AIVocabularyImplCopyWithImpl(
    _$AIVocabularyImpl _value,
    $Res Function(_$AIVocabularyImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AIVocabulary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? word = null,
    Object? category = null,
    Object? alternatives = null,
  }) {
    return _then(
      _$AIVocabularyImpl(
        word: null == word
            ? _value.word
            : word // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        alternatives: null == alternatives
            ? _value._alternatives
            : alternatives // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AIVocabularyImpl implements _AIVocabulary {
  const _$AIVocabularyImpl({
    required this.word,
    required this.category,
    final List<String> alternatives = const [],
  }) : _alternatives = alternatives;

  factory _$AIVocabularyImpl.fromJson(Map<String, dynamic> json) =>
      _$$AIVocabularyImplFromJson(json);

  @override
  final String word;
  @override
  final String category;
  final List<String> _alternatives;
  @override
  @JsonKey()
  List<String> get alternatives {
    if (_alternatives is EqualUnmodifiableListView) return _alternatives;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_alternatives);
  }

  @override
  String toString() {
    return 'AIVocabulary(word: $word, category: $category, alternatives: $alternatives)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AIVocabularyImpl &&
            (identical(other.word, word) || other.word == word) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(
              other._alternatives,
              _alternatives,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    word,
    category,
    const DeepCollectionEquality().hash(_alternatives),
  );

  /// Create a copy of AIVocabulary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AIVocabularyImplCopyWith<_$AIVocabularyImpl> get copyWith =>
      __$$AIVocabularyImplCopyWithImpl<_$AIVocabularyImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AIVocabularyImplToJson(this);
  }
}

abstract class _AIVocabulary implements AIVocabulary {
  const factory _AIVocabulary({
    required final String word,
    required final String category,
    final List<String> alternatives,
  }) = _$AIVocabularyImpl;

  factory _AIVocabulary.fromJson(Map<String, dynamic> json) =
      _$AIVocabularyImpl.fromJson;

  @override
  String get word;
  @override
  String get category;
  @override
  List<String> get alternatives;

  /// Create a copy of AIVocabulary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AIVocabularyImplCopyWith<_$AIVocabularyImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DetectionResult _$DetectionResultFromJson(Map<String, dynamic> json) {
  return _DetectionResult.fromJson(json);
}

/// @nodoc
mixin _$DetectionResult {
  String get id => throw _privateConstructorUsedError;
  DetectionType get type => throw _privateConstructorUsedError;
  String get matchedText => throw _privateConstructorUsedError;
  int get startOffset => throw _privateConstructorUsedError;
  int get endOffset => throw _privateConstructorUsedError;
  String? get suggestion => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String? get pattern => throw _privateConstructorUsedError;

  /// Serializes this DetectionResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DetectionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DetectionResultCopyWith<DetectionResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DetectionResultCopyWith<$Res> {
  factory $DetectionResultCopyWith(
    DetectionResult value,
    $Res Function(DetectionResult) then,
  ) = _$DetectionResultCopyWithImpl<$Res, DetectionResult>;
  @useResult
  $Res call({
    String id,
    DetectionType type,
    String matchedText,
    int startOffset,
    int endOffset,
    String? suggestion,
    String? description,
    String? pattern,
  });
}

/// @nodoc
class _$DetectionResultCopyWithImpl<$Res, $Val extends DetectionResult>
    implements $DetectionResultCopyWith<$Res> {
  _$DetectionResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DetectionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? matchedText = null,
    Object? startOffset = null,
    Object? endOffset = null,
    Object? suggestion = freezed,
    Object? description = freezed,
    Object? pattern = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as DetectionType,
            matchedText: null == matchedText
                ? _value.matchedText
                : matchedText // ignore: cast_nullable_to_non_nullable
                      as String,
            startOffset: null == startOffset
                ? _value.startOffset
                : startOffset // ignore: cast_nullable_to_non_nullable
                      as int,
            endOffset: null == endOffset
                ? _value.endOffset
                : endOffset // ignore: cast_nullable_to_non_nullable
                      as int,
            suggestion: freezed == suggestion
                ? _value.suggestion
                : suggestion // ignore: cast_nullable_to_non_nullable
                      as String?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            pattern: freezed == pattern
                ? _value.pattern
                : pattern // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DetectionResultImplCopyWith<$Res>
    implements $DetectionResultCopyWith<$Res> {
  factory _$$DetectionResultImplCopyWith(
    _$DetectionResultImpl value,
    $Res Function(_$DetectionResultImpl) then,
  ) = __$$DetectionResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    DetectionType type,
    String matchedText,
    int startOffset,
    int endOffset,
    String? suggestion,
    String? description,
    String? pattern,
  });
}

/// @nodoc
class __$$DetectionResultImplCopyWithImpl<$Res>
    extends _$DetectionResultCopyWithImpl<$Res, _$DetectionResultImpl>
    implements _$$DetectionResultImplCopyWith<$Res> {
  __$$DetectionResultImplCopyWithImpl(
    _$DetectionResultImpl _value,
    $Res Function(_$DetectionResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DetectionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? matchedText = null,
    Object? startOffset = null,
    Object? endOffset = null,
    Object? suggestion = freezed,
    Object? description = freezed,
    Object? pattern = freezed,
  }) {
    return _then(
      _$DetectionResultImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as DetectionType,
        matchedText: null == matchedText
            ? _value.matchedText
            : matchedText // ignore: cast_nullable_to_non_nullable
                  as String,
        startOffset: null == startOffset
            ? _value.startOffset
            : startOffset // ignore: cast_nullable_to_non_nullable
                  as int,
        endOffset: null == endOffset
            ? _value.endOffset
            : endOffset // ignore: cast_nullable_to_non_nullable
                  as int,
        suggestion: freezed == suggestion
            ? _value.suggestion
            : suggestion // ignore: cast_nullable_to_non_nullable
                  as String?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        pattern: freezed == pattern
            ? _value.pattern
            : pattern // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DetectionResultImpl extends _DetectionResult {
  const _$DetectionResultImpl({
    required this.id,
    required this.type,
    required this.matchedText,
    required this.startOffset,
    required this.endOffset,
    this.suggestion,
    this.description,
    this.pattern,
  }) : super._();

  factory _$DetectionResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$DetectionResultImplFromJson(json);

  @override
  final String id;
  @override
  final DetectionType type;
  @override
  final String matchedText;
  @override
  final int startOffset;
  @override
  final int endOffset;
  @override
  final String? suggestion;
  @override
  final String? description;
  @override
  final String? pattern;

  @override
  String toString() {
    return 'DetectionResult(id: $id, type: $type, matchedText: $matchedText, startOffset: $startOffset, endOffset: $endOffset, suggestion: $suggestion, description: $description, pattern: $pattern)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DetectionResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.matchedText, matchedText) ||
                other.matchedText == matchedText) &&
            (identical(other.startOffset, startOffset) ||
                other.startOffset == startOffset) &&
            (identical(other.endOffset, endOffset) ||
                other.endOffset == endOffset) &&
            (identical(other.suggestion, suggestion) ||
                other.suggestion == suggestion) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.pattern, pattern) || other.pattern == pattern));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    type,
    matchedText,
    startOffset,
    endOffset,
    suggestion,
    description,
    pattern,
  );

  /// Create a copy of DetectionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DetectionResultImplCopyWith<_$DetectionResultImpl> get copyWith =>
      __$$DetectionResultImplCopyWithImpl<_$DetectionResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DetectionResultImplToJson(this);
  }
}

abstract class _DetectionResult extends DetectionResult {
  const factory _DetectionResult({
    required final String id,
    required final DetectionType type,
    required final String matchedText,
    required final int startOffset,
    required final int endOffset,
    final String? suggestion,
    final String? description,
    final String? pattern,
  }) = _$DetectionResultImpl;
  const _DetectionResult._() : super._();

  factory _DetectionResult.fromJson(Map<String, dynamic> json) =
      _$DetectionResultImpl.fromJson;

  @override
  String get id;
  @override
  DetectionType get type;
  @override
  String get matchedText;
  @override
  int get startOffset;
  @override
  int get endOffset;
  @override
  String? get suggestion;
  @override
  String? get description;
  @override
  String? get pattern;

  /// Create a copy of DetectionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DetectionResultImplCopyWith<_$DetectionResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DetectionReport _$DetectionReportFromJson(Map<String, dynamic> json) {
  return _DetectionReport.fromJson(json);
}

/// @nodoc
mixin _$DetectionReport {
  String get chapterId => throw _privateConstructorUsedError;
  DateTime get analyzedAt => throw _privateConstructorUsedError;
  List<DetectionResult> get results => throw _privateConstructorUsedError;
  Map<String, int> get typeCounts => throw _privateConstructorUsedError;
  int get totalIssues => throw _privateConstructorUsedError;
  int get wordCount => throw _privateConstructorUsedError;

  /// Serializes this DetectionReport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DetectionReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DetectionReportCopyWith<DetectionReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DetectionReportCopyWith<$Res> {
  factory $DetectionReportCopyWith(
    DetectionReport value,
    $Res Function(DetectionReport) then,
  ) = _$DetectionReportCopyWithImpl<$Res, DetectionReport>;
  @useResult
  $Res call({
    String chapterId,
    DateTime analyzedAt,
    List<DetectionResult> results,
    Map<String, int> typeCounts,
    int totalIssues,
    int wordCount,
  });
}

/// @nodoc
class _$DetectionReportCopyWithImpl<$Res, $Val extends DetectionReport>
    implements $DetectionReportCopyWith<$Res> {
  _$DetectionReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DetectionReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? analyzedAt = null,
    Object? results = null,
    Object? typeCounts = null,
    Object? totalIssues = null,
    Object? wordCount = null,
  }) {
    return _then(
      _value.copyWith(
            chapterId: null == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String,
            analyzedAt: null == analyzedAt
                ? _value.analyzedAt
                : analyzedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            results: null == results
                ? _value.results
                : results // ignore: cast_nullable_to_non_nullable
                      as List<DetectionResult>,
            typeCounts: null == typeCounts
                ? _value.typeCounts
                : typeCounts // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
            totalIssues: null == totalIssues
                ? _value.totalIssues
                : totalIssues // ignore: cast_nullable_to_non_nullable
                      as int,
            wordCount: null == wordCount
                ? _value.wordCount
                : wordCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DetectionReportImplCopyWith<$Res>
    implements $DetectionReportCopyWith<$Res> {
  factory _$$DetectionReportImplCopyWith(
    _$DetectionReportImpl value,
    $Res Function(_$DetectionReportImpl) then,
  ) = __$$DetectionReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String chapterId,
    DateTime analyzedAt,
    List<DetectionResult> results,
    Map<String, int> typeCounts,
    int totalIssues,
    int wordCount,
  });
}

/// @nodoc
class __$$DetectionReportImplCopyWithImpl<$Res>
    extends _$DetectionReportCopyWithImpl<$Res, _$DetectionReportImpl>
    implements _$$DetectionReportImplCopyWith<$Res> {
  __$$DetectionReportImplCopyWithImpl(
    _$DetectionReportImpl _value,
    $Res Function(_$DetectionReportImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DetectionReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? analyzedAt = null,
    Object? results = null,
    Object? typeCounts = null,
    Object? totalIssues = null,
    Object? wordCount = null,
  }) {
    return _then(
      _$DetectionReportImpl(
        chapterId: null == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String,
        analyzedAt: null == analyzedAt
            ? _value.analyzedAt
            : analyzedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        results: null == results
            ? _value._results
            : results // ignore: cast_nullable_to_non_nullable
                  as List<DetectionResult>,
        typeCounts: null == typeCounts
            ? _value._typeCounts
            : typeCounts // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
        totalIssues: null == totalIssues
            ? _value.totalIssues
            : totalIssues // ignore: cast_nullable_to_non_nullable
                  as int,
        wordCount: null == wordCount
            ? _value.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$DetectionReportImpl extends _DetectionReport {
  const _$DetectionReportImpl({
    required this.chapterId,
    required this.analyzedAt,
    required final List<DetectionResult> results,
    required final Map<String, int> typeCounts,
    this.totalIssues = 0,
    this.wordCount = 0,
  }) : _results = results,
       _typeCounts = typeCounts,
       super._();

  factory _$DetectionReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$DetectionReportImplFromJson(json);

  @override
  final String chapterId;
  @override
  final DateTime analyzedAt;
  final List<DetectionResult> _results;
  @override
  List<DetectionResult> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  final Map<String, int> _typeCounts;
  @override
  Map<String, int> get typeCounts {
    if (_typeCounts is EqualUnmodifiableMapView) return _typeCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_typeCounts);
  }

  @override
  @JsonKey()
  final int totalIssues;
  @override
  @JsonKey()
  final int wordCount;

  @override
  String toString() {
    return 'DetectionReport(chapterId: $chapterId, analyzedAt: $analyzedAt, results: $results, typeCounts: $typeCounts, totalIssues: $totalIssues, wordCount: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DetectionReportImpl &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.analyzedAt, analyzedAt) ||
                other.analyzedAt == analyzedAt) &&
            const DeepCollectionEquality().equals(other._results, _results) &&
            const DeepCollectionEquality().equals(
              other._typeCounts,
              _typeCounts,
            ) &&
            (identical(other.totalIssues, totalIssues) ||
                other.totalIssues == totalIssues) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    chapterId,
    analyzedAt,
    const DeepCollectionEquality().hash(_results),
    const DeepCollectionEquality().hash(_typeCounts),
    totalIssues,
    wordCount,
  );

  /// Create a copy of DetectionReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DetectionReportImplCopyWith<_$DetectionReportImpl> get copyWith =>
      __$$DetectionReportImplCopyWithImpl<_$DetectionReportImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$DetectionReportImplToJson(this);
  }
}

abstract class _DetectionReport extends DetectionReport {
  const factory _DetectionReport({
    required final String chapterId,
    required final DateTime analyzedAt,
    required final List<DetectionResult> results,
    required final Map<String, int> typeCounts,
    final int totalIssues,
    final int wordCount,
  }) = _$DetectionReportImpl;
  const _DetectionReport._() : super._();

  factory _DetectionReport.fromJson(Map<String, dynamic> json) =
      _$DetectionReportImpl.fromJson;

  @override
  String get chapterId;
  @override
  DateTime get analyzedAt;
  @override
  List<DetectionResult> get results;
  @override
  Map<String, int> get typeCounts;
  @override
  int get totalIssues;
  @override
  int get wordCount;

  /// Create a copy of DetectionReport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DetectionReportImplCopyWith<_$DetectionReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
