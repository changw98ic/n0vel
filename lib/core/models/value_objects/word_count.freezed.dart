// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'word_count.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$WordCount {
  int get chineseChars => throw _privateConstructorUsedError;
  int get englishWords => throw _privateConstructorUsedError;
  int get punctuation => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;

  /// Create a copy of WordCount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $WordCountCopyWith<WordCount> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $WordCountCopyWith<$Res> {
  factory $WordCountCopyWith(WordCount value, $Res Function(WordCount) then) =
      _$WordCountCopyWithImpl<$Res, WordCount>;
  @useResult
  $Res call({int chineseChars, int englishWords, int punctuation, int total});
}

/// @nodoc
class _$WordCountCopyWithImpl<$Res, $Val extends WordCount>
    implements $WordCountCopyWith<$Res> {
  _$WordCountCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of WordCount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chineseChars = null,
    Object? englishWords = null,
    Object? punctuation = null,
    Object? total = null,
  }) {
    return _then(
      _value.copyWith(
            chineseChars: null == chineseChars
                ? _value.chineseChars
                : chineseChars // ignore: cast_nullable_to_non_nullable
                      as int,
            englishWords: null == englishWords
                ? _value.englishWords
                : englishWords // ignore: cast_nullable_to_non_nullable
                      as int,
            punctuation: null == punctuation
                ? _value.punctuation
                : punctuation // ignore: cast_nullable_to_non_nullable
                      as int,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$WordCountImplCopyWith<$Res>
    implements $WordCountCopyWith<$Res> {
  factory _$$WordCountImplCopyWith(
    _$WordCountImpl value,
    $Res Function(_$WordCountImpl) then,
  ) = __$$WordCountImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int chineseChars, int englishWords, int punctuation, int total});
}

/// @nodoc
class __$$WordCountImplCopyWithImpl<$Res>
    extends _$WordCountCopyWithImpl<$Res, _$WordCountImpl>
    implements _$$WordCountImplCopyWith<$Res> {
  __$$WordCountImplCopyWithImpl(
    _$WordCountImpl _value,
    $Res Function(_$WordCountImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of WordCount
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chineseChars = null,
    Object? englishWords = null,
    Object? punctuation = null,
    Object? total = null,
  }) {
    return _then(
      _$WordCountImpl(
        chineseChars: null == chineseChars
            ? _value.chineseChars
            : chineseChars // ignore: cast_nullable_to_non_nullable
                  as int,
        englishWords: null == englishWords
            ? _value.englishWords
            : englishWords // ignore: cast_nullable_to_non_nullable
                  as int,
        punctuation: null == punctuation
            ? _value.punctuation
            : punctuation // ignore: cast_nullable_to_non_nullable
                  as int,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$WordCountImpl extends _WordCount {
  const _$WordCountImpl({
    required this.chineseChars,
    required this.englishWords,
    required this.punctuation,
    required this.total,
  }) : super._();

  @override
  final int chineseChars;
  @override
  final int englishWords;
  @override
  final int punctuation;
  @override
  final int total;

  @override
  String toString() {
    return 'WordCount(chineseChars: $chineseChars, englishWords: $englishWords, punctuation: $punctuation, total: $total)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$WordCountImpl &&
            (identical(other.chineseChars, chineseChars) ||
                other.chineseChars == chineseChars) &&
            (identical(other.englishWords, englishWords) ||
                other.englishWords == englishWords) &&
            (identical(other.punctuation, punctuation) ||
                other.punctuation == punctuation) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, chineseChars, englishWords, punctuation, total);

  /// Create a copy of WordCount
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$WordCountImplCopyWith<_$WordCountImpl> get copyWith =>
      __$$WordCountImplCopyWithImpl<_$WordCountImpl>(this, _$identity);
}

abstract class _WordCount extends WordCount {
  const factory _WordCount({
    required final int chineseChars,
    required final int englishWords,
    required final int punctuation,
    required final int total,
  }) = _$WordCountImpl;
  const _WordCount._() : super._();

  @override
  int get chineseChars;
  @override
  int get englishWords;
  @override
  int get punctuation;
  @override
  int get total;

  /// Create a copy of WordCount
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$WordCountImplCopyWith<_$WordCountImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
