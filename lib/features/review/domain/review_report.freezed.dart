// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReviewReport _$ReviewReportFromJson(Map<String, dynamic> json) {
  return _ReviewReport.fromJson(json);
}

/// @nodoc
mixin _$ReviewReport {
  String get id => throw _privateConstructorUsedError;
  String get chapterId => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  double get overallScore => throw _privateConstructorUsedError;
  Map<String, double> get dimensionScores => throw _privateConstructorUsedError;
  List<ReviewIssue> get issues => throw _privateConstructorUsedError;
  int get criticalCount => throw _privateConstructorUsedError;
  int get majorCount => throw _privateConstructorUsedError;
  int get minorCount => throw _privateConstructorUsedError;

  /// Serializes this ReviewReport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewReportCopyWith<ReviewReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewReportCopyWith<$Res> {
  factory $ReviewReportCopyWith(
    ReviewReport value,
    $Res Function(ReviewReport) then,
  ) = _$ReviewReportCopyWithImpl<$Res, ReviewReport>;
  @useResult
  $Res call({
    String id,
    String chapterId,
    DateTime createdAt,
    double overallScore,
    Map<String, double> dimensionScores,
    List<ReviewIssue> issues,
    int criticalCount,
    int majorCount,
    int minorCount,
  });
}

/// @nodoc
class _$ReviewReportCopyWithImpl<$Res, $Val extends ReviewReport>
    implements $ReviewReportCopyWith<$Res> {
  _$ReviewReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? createdAt = null,
    Object? overallScore = null,
    Object? dimensionScores = null,
    Object? issues = null,
    Object? criticalCount = null,
    Object? majorCount = null,
    Object? minorCount = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterId: null == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            overallScore: null == overallScore
                ? _value.overallScore
                : overallScore // ignore: cast_nullable_to_non_nullable
                      as double,
            dimensionScores: null == dimensionScores
                ? _value.dimensionScores
                : dimensionScores // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
            issues: null == issues
                ? _value.issues
                : issues // ignore: cast_nullable_to_non_nullable
                      as List<ReviewIssue>,
            criticalCount: null == criticalCount
                ? _value.criticalCount
                : criticalCount // ignore: cast_nullable_to_non_nullable
                      as int,
            majorCount: null == majorCount
                ? _value.majorCount
                : majorCount // ignore: cast_nullable_to_non_nullable
                      as int,
            minorCount: null == minorCount
                ? _value.minorCount
                : minorCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewReportImplCopyWith<$Res>
    implements $ReviewReportCopyWith<$Res> {
  factory _$$ReviewReportImplCopyWith(
    _$ReviewReportImpl value,
    $Res Function(_$ReviewReportImpl) then,
  ) = __$$ReviewReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String chapterId,
    DateTime createdAt,
    double overallScore,
    Map<String, double> dimensionScores,
    List<ReviewIssue> issues,
    int criticalCount,
    int majorCount,
    int minorCount,
  });
}

/// @nodoc
class __$$ReviewReportImplCopyWithImpl<$Res>
    extends _$ReviewReportCopyWithImpl<$Res, _$ReviewReportImpl>
    implements _$$ReviewReportImplCopyWith<$Res> {
  __$$ReviewReportImplCopyWithImpl(
    _$ReviewReportImpl _value,
    $Res Function(_$ReviewReportImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? chapterId = null,
    Object? createdAt = null,
    Object? overallScore = null,
    Object? dimensionScores = null,
    Object? issues = null,
    Object? criticalCount = null,
    Object? majorCount = null,
    Object? minorCount = null,
  }) {
    return _then(
      _$ReviewReportImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterId: null == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        overallScore: null == overallScore
            ? _value.overallScore
            : overallScore // ignore: cast_nullable_to_non_nullable
                  as double,
        dimensionScores: null == dimensionScores
            ? _value._dimensionScores
            : dimensionScores // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
        issues: null == issues
            ? _value._issues
            : issues // ignore: cast_nullable_to_non_nullable
                  as List<ReviewIssue>,
        criticalCount: null == criticalCount
            ? _value.criticalCount
            : criticalCount // ignore: cast_nullable_to_non_nullable
                  as int,
        majorCount: null == majorCount
            ? _value.majorCount
            : majorCount // ignore: cast_nullable_to_non_nullable
                  as int,
        minorCount: null == minorCount
            ? _value.minorCount
            : minorCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewReportImpl extends _ReviewReport {
  const _$ReviewReportImpl({
    required this.id,
    required this.chapterId,
    required this.createdAt,
    this.overallScore = 0,
    required final Map<String, double> dimensionScores,
    required final List<ReviewIssue> issues,
    this.criticalCount = 0,
    this.majorCount = 0,
    this.minorCount = 0,
  }) : _dimensionScores = dimensionScores,
       _issues = issues,
       super._();

  factory _$ReviewReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewReportImplFromJson(json);

  @override
  final String id;
  @override
  final String chapterId;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final double overallScore;
  final Map<String, double> _dimensionScores;
  @override
  Map<String, double> get dimensionScores {
    if (_dimensionScores is EqualUnmodifiableMapView) return _dimensionScores;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dimensionScores);
  }

  final List<ReviewIssue> _issues;
  @override
  List<ReviewIssue> get issues {
    if (_issues is EqualUnmodifiableListView) return _issues;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_issues);
  }

  @override
  @JsonKey()
  final int criticalCount;
  @override
  @JsonKey()
  final int majorCount;
  @override
  @JsonKey()
  final int minorCount;

  @override
  String toString() {
    return 'ReviewReport(id: $id, chapterId: $chapterId, createdAt: $createdAt, overallScore: $overallScore, dimensionScores: $dimensionScores, issues: $issues, criticalCount: $criticalCount, majorCount: $majorCount, minorCount: $minorCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewReportImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.overallScore, overallScore) ||
                other.overallScore == overallScore) &&
            const DeepCollectionEquality().equals(
              other._dimensionScores,
              _dimensionScores,
            ) &&
            const DeepCollectionEquality().equals(other._issues, _issues) &&
            (identical(other.criticalCount, criticalCount) ||
                other.criticalCount == criticalCount) &&
            (identical(other.majorCount, majorCount) ||
                other.majorCount == majorCount) &&
            (identical(other.minorCount, minorCount) ||
                other.minorCount == minorCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    chapterId,
    createdAt,
    overallScore,
    const DeepCollectionEquality().hash(_dimensionScores),
    const DeepCollectionEquality().hash(_issues),
    criticalCount,
    majorCount,
    minorCount,
  );

  /// Create a copy of ReviewReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewReportImplCopyWith<_$ReviewReportImpl> get copyWith =>
      __$$ReviewReportImplCopyWithImpl<_$ReviewReportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewReportImplToJson(this);
  }
}

abstract class _ReviewReport extends ReviewReport {
  const factory _ReviewReport({
    required final String id,
    required final String chapterId,
    required final DateTime createdAt,
    final double overallScore,
    required final Map<String, double> dimensionScores,
    required final List<ReviewIssue> issues,
    final int criticalCount,
    final int majorCount,
    final int minorCount,
  }) = _$ReviewReportImpl;
  const _ReviewReport._() : super._();

  factory _ReviewReport.fromJson(Map<String, dynamic> json) =
      _$ReviewReportImpl.fromJson;

  @override
  String get id;
  @override
  String get chapterId;
  @override
  DateTime get createdAt;
  @override
  double get overallScore;
  @override
  Map<String, double> get dimensionScores;
  @override
  List<ReviewIssue> get issues;
  @override
  int get criticalCount;
  @override
  int get majorCount;
  @override
  int get minorCount;

  /// Create a copy of ReviewReport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewReportImplCopyWith<_$ReviewReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReviewIssue _$ReviewIssueFromJson(Map<String, dynamic> json) {
  return _ReviewIssue.fromJson(json);
}

/// @nodoc
mixin _$ReviewIssue {
  String get id => throw _privateConstructorUsedError;
  String get reportId => throw _privateConstructorUsedError;
  ReviewDimension get dimension => throw _privateConstructorUsedError;
  IssueSeverity get severity => throw _privateConstructorUsedError;
  IssueStatus get status => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String? get originalText => throw _privateConstructorUsedError;
  String? get location => throw _privateConstructorUsedError;
  int? get startOffset => throw _privateConstructorUsedError;
  int? get endOffset => throw _privateConstructorUsedError;
  String? get suggestion => throw _privateConstructorUsedError;
  String? get relatedCharacterId => throw _privateConstructorUsedError;
  String? get relatedSettingId => throw _privateConstructorUsedError;
  DateTime? get fixedAt => throw _privateConstructorUsedError;
  String? get fixedBy => throw _privateConstructorUsedError;

  /// Serializes this ReviewIssue to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewIssue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewIssueCopyWith<ReviewIssue> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewIssueCopyWith<$Res> {
  factory $ReviewIssueCopyWith(
    ReviewIssue value,
    $Res Function(ReviewIssue) then,
  ) = _$ReviewIssueCopyWithImpl<$Res, ReviewIssue>;
  @useResult
  $Res call({
    String id,
    String reportId,
    ReviewDimension dimension,
    IssueSeverity severity,
    IssueStatus status,
    String description,
    String? originalText,
    String? location,
    int? startOffset,
    int? endOffset,
    String? suggestion,
    String? relatedCharacterId,
    String? relatedSettingId,
    DateTime? fixedAt,
    String? fixedBy,
  });
}

/// @nodoc
class _$ReviewIssueCopyWithImpl<$Res, $Val extends ReviewIssue>
    implements $ReviewIssueCopyWith<$Res> {
  _$ReviewIssueCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewIssue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reportId = null,
    Object? dimension = null,
    Object? severity = null,
    Object? status = null,
    Object? description = null,
    Object? originalText = freezed,
    Object? location = freezed,
    Object? startOffset = freezed,
    Object? endOffset = freezed,
    Object? suggestion = freezed,
    Object? relatedCharacterId = freezed,
    Object? relatedSettingId = freezed,
    Object? fixedAt = freezed,
    Object? fixedBy = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            reportId: null == reportId
                ? _value.reportId
                : reportId // ignore: cast_nullable_to_non_nullable
                      as String,
            dimension: null == dimension
                ? _value.dimension
                : dimension // ignore: cast_nullable_to_non_nullable
                      as ReviewDimension,
            severity: null == severity
                ? _value.severity
                : severity // ignore: cast_nullable_to_non_nullable
                      as IssueSeverity,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as IssueStatus,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            originalText: freezed == originalText
                ? _value.originalText
                : originalText // ignore: cast_nullable_to_non_nullable
                      as String?,
            location: freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                      as String?,
            startOffset: freezed == startOffset
                ? _value.startOffset
                : startOffset // ignore: cast_nullable_to_non_nullable
                      as int?,
            endOffset: freezed == endOffset
                ? _value.endOffset
                : endOffset // ignore: cast_nullable_to_non_nullable
                      as int?,
            suggestion: freezed == suggestion
                ? _value.suggestion
                : suggestion // ignore: cast_nullable_to_non_nullable
                      as String?,
            relatedCharacterId: freezed == relatedCharacterId
                ? _value.relatedCharacterId
                : relatedCharacterId // ignore: cast_nullable_to_non_nullable
                      as String?,
            relatedSettingId: freezed == relatedSettingId
                ? _value.relatedSettingId
                : relatedSettingId // ignore: cast_nullable_to_non_nullable
                      as String?,
            fixedAt: freezed == fixedAt
                ? _value.fixedAt
                : fixedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            fixedBy: freezed == fixedBy
                ? _value.fixedBy
                : fixedBy // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewIssueImplCopyWith<$Res>
    implements $ReviewIssueCopyWith<$Res> {
  factory _$$ReviewIssueImplCopyWith(
    _$ReviewIssueImpl value,
    $Res Function(_$ReviewIssueImpl) then,
  ) = __$$ReviewIssueImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String reportId,
    ReviewDimension dimension,
    IssueSeverity severity,
    IssueStatus status,
    String description,
    String? originalText,
    String? location,
    int? startOffset,
    int? endOffset,
    String? suggestion,
    String? relatedCharacterId,
    String? relatedSettingId,
    DateTime? fixedAt,
    String? fixedBy,
  });
}

/// @nodoc
class __$$ReviewIssueImplCopyWithImpl<$Res>
    extends _$ReviewIssueCopyWithImpl<$Res, _$ReviewIssueImpl>
    implements _$$ReviewIssueImplCopyWith<$Res> {
  __$$ReviewIssueImplCopyWithImpl(
    _$ReviewIssueImpl _value,
    $Res Function(_$ReviewIssueImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewIssue
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? reportId = null,
    Object? dimension = null,
    Object? severity = null,
    Object? status = null,
    Object? description = null,
    Object? originalText = freezed,
    Object? location = freezed,
    Object? startOffset = freezed,
    Object? endOffset = freezed,
    Object? suggestion = freezed,
    Object? relatedCharacterId = freezed,
    Object? relatedSettingId = freezed,
    Object? fixedAt = freezed,
    Object? fixedBy = freezed,
  }) {
    return _then(
      _$ReviewIssueImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        reportId: null == reportId
            ? _value.reportId
            : reportId // ignore: cast_nullable_to_non_nullable
                  as String,
        dimension: null == dimension
            ? _value.dimension
            : dimension // ignore: cast_nullable_to_non_nullable
                  as ReviewDimension,
        severity: null == severity
            ? _value.severity
            : severity // ignore: cast_nullable_to_non_nullable
                  as IssueSeverity,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as IssueStatus,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        originalText: freezed == originalText
            ? _value.originalText
            : originalText // ignore: cast_nullable_to_non_nullable
                  as String?,
        location: freezed == location
            ? _value.location
            : location // ignore: cast_nullable_to_non_nullable
                  as String?,
        startOffset: freezed == startOffset
            ? _value.startOffset
            : startOffset // ignore: cast_nullable_to_non_nullable
                  as int?,
        endOffset: freezed == endOffset
            ? _value.endOffset
            : endOffset // ignore: cast_nullable_to_non_nullable
                  as int?,
        suggestion: freezed == suggestion
            ? _value.suggestion
            : suggestion // ignore: cast_nullable_to_non_nullable
                  as String?,
        relatedCharacterId: freezed == relatedCharacterId
            ? _value.relatedCharacterId
            : relatedCharacterId // ignore: cast_nullable_to_non_nullable
                  as String?,
        relatedSettingId: freezed == relatedSettingId
            ? _value.relatedSettingId
            : relatedSettingId // ignore: cast_nullable_to_non_nullable
                  as String?,
        fixedAt: freezed == fixedAt
            ? _value.fixedAt
            : fixedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        fixedBy: freezed == fixedBy
            ? _value.fixedBy
            : fixedBy // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewIssueImpl extends _ReviewIssue {
  const _$ReviewIssueImpl({
    required this.id,
    required this.reportId,
    required this.dimension,
    required this.severity,
    this.status = IssueStatus.pending,
    required this.description,
    this.originalText,
    this.location,
    this.startOffset,
    this.endOffset,
    this.suggestion,
    this.relatedCharacterId,
    this.relatedSettingId,
    this.fixedAt,
    this.fixedBy,
  }) : super._();

  factory _$ReviewIssueImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewIssueImplFromJson(json);

  @override
  final String id;
  @override
  final String reportId;
  @override
  final ReviewDimension dimension;
  @override
  final IssueSeverity severity;
  @override
  @JsonKey()
  final IssueStatus status;
  @override
  final String description;
  @override
  final String? originalText;
  @override
  final String? location;
  @override
  final int? startOffset;
  @override
  final int? endOffset;
  @override
  final String? suggestion;
  @override
  final String? relatedCharacterId;
  @override
  final String? relatedSettingId;
  @override
  final DateTime? fixedAt;
  @override
  final String? fixedBy;

  @override
  String toString() {
    return 'ReviewIssue(id: $id, reportId: $reportId, dimension: $dimension, severity: $severity, status: $status, description: $description, originalText: $originalText, location: $location, startOffset: $startOffset, endOffset: $endOffset, suggestion: $suggestion, relatedCharacterId: $relatedCharacterId, relatedSettingId: $relatedSettingId, fixedAt: $fixedAt, fixedBy: $fixedBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewIssueImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.reportId, reportId) ||
                other.reportId == reportId) &&
            (identical(other.dimension, dimension) ||
                other.dimension == dimension) &&
            (identical(other.severity, severity) ||
                other.severity == severity) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.originalText, originalText) ||
                other.originalText == originalText) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.startOffset, startOffset) ||
                other.startOffset == startOffset) &&
            (identical(other.endOffset, endOffset) ||
                other.endOffset == endOffset) &&
            (identical(other.suggestion, suggestion) ||
                other.suggestion == suggestion) &&
            (identical(other.relatedCharacterId, relatedCharacterId) ||
                other.relatedCharacterId == relatedCharacterId) &&
            (identical(other.relatedSettingId, relatedSettingId) ||
                other.relatedSettingId == relatedSettingId) &&
            (identical(other.fixedAt, fixedAt) || other.fixedAt == fixedAt) &&
            (identical(other.fixedBy, fixedBy) || other.fixedBy == fixedBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    reportId,
    dimension,
    severity,
    status,
    description,
    originalText,
    location,
    startOffset,
    endOffset,
    suggestion,
    relatedCharacterId,
    relatedSettingId,
    fixedAt,
    fixedBy,
  );

  /// Create a copy of ReviewIssue
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewIssueImplCopyWith<_$ReviewIssueImpl> get copyWith =>
      __$$ReviewIssueImplCopyWithImpl<_$ReviewIssueImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewIssueImplToJson(this);
  }
}

abstract class _ReviewIssue extends ReviewIssue {
  const factory _ReviewIssue({
    required final String id,
    required final String reportId,
    required final ReviewDimension dimension,
    required final IssueSeverity severity,
    final IssueStatus status,
    required final String description,
    final String? originalText,
    final String? location,
    final int? startOffset,
    final int? endOffset,
    final String? suggestion,
    final String? relatedCharacterId,
    final String? relatedSettingId,
    final DateTime? fixedAt,
    final String? fixedBy,
  }) = _$ReviewIssueImpl;
  const _ReviewIssue._() : super._();

  factory _ReviewIssue.fromJson(Map<String, dynamic> json) =
      _$ReviewIssueImpl.fromJson;

  @override
  String get id;
  @override
  String get reportId;
  @override
  ReviewDimension get dimension;
  @override
  IssueSeverity get severity;
  @override
  IssueStatus get status;
  @override
  String get description;
  @override
  String? get originalText;
  @override
  String? get location;
  @override
  int? get startOffset;
  @override
  int? get endOffset;
  @override
  String? get suggestion;
  @override
  String? get relatedCharacterId;
  @override
  String? get relatedSettingId;
  @override
  DateTime? get fixedAt;
  @override
  String? get fixedBy;

  /// Create a copy of ReviewIssue
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewIssueImplCopyWith<_$ReviewIssueImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ReviewConfig _$ReviewConfigFromJson(Map<String, dynamic> json) {
  return _ReviewConfig.fromJson(json);
}

/// @nodoc
mixin _$ReviewConfig {
  bool get autoReview => throw _privateConstructorUsedError;
  Map<String, int> get dimensionStrictness =>
      throw _privateConstructorUsedError; // 0-100
  bool get checkAiStyle => throw _privateConstructorUsedError;
  bool get checkPerspective => throw _privateConstructorUsedError;
  bool get checkPacing => throw _privateConstructorUsedError;
  String get aiModelId => throw _privateConstructorUsedError;

  /// Serializes this ReviewConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReviewConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReviewConfigCopyWith<ReviewConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReviewConfigCopyWith<$Res> {
  factory $ReviewConfigCopyWith(
    ReviewConfig value,
    $Res Function(ReviewConfig) then,
  ) = _$ReviewConfigCopyWithImpl<$Res, ReviewConfig>;
  @useResult
  $Res call({
    bool autoReview,
    Map<String, int> dimensionStrictness,
    bool checkAiStyle,
    bool checkPerspective,
    bool checkPacing,
    String aiModelId,
  });
}

/// @nodoc
class _$ReviewConfigCopyWithImpl<$Res, $Val extends ReviewConfig>
    implements $ReviewConfigCopyWith<$Res> {
  _$ReviewConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReviewConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? autoReview = null,
    Object? dimensionStrictness = null,
    Object? checkAiStyle = null,
    Object? checkPerspective = null,
    Object? checkPacing = null,
    Object? aiModelId = null,
  }) {
    return _then(
      _value.copyWith(
            autoReview: null == autoReview
                ? _value.autoReview
                : autoReview // ignore: cast_nullable_to_non_nullable
                      as bool,
            dimensionStrictness: null == dimensionStrictness
                ? _value.dimensionStrictness
                : dimensionStrictness // ignore: cast_nullable_to_non_nullable
                      as Map<String, int>,
            checkAiStyle: null == checkAiStyle
                ? _value.checkAiStyle
                : checkAiStyle // ignore: cast_nullable_to_non_nullable
                      as bool,
            checkPerspective: null == checkPerspective
                ? _value.checkPerspective
                : checkPerspective // ignore: cast_nullable_to_non_nullable
                      as bool,
            checkPacing: null == checkPacing
                ? _value.checkPacing
                : checkPacing // ignore: cast_nullable_to_non_nullable
                      as bool,
            aiModelId: null == aiModelId
                ? _value.aiModelId
                : aiModelId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReviewConfigImplCopyWith<$Res>
    implements $ReviewConfigCopyWith<$Res> {
  factory _$$ReviewConfigImplCopyWith(
    _$ReviewConfigImpl value,
    $Res Function(_$ReviewConfigImpl) then,
  ) = __$$ReviewConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool autoReview,
    Map<String, int> dimensionStrictness,
    bool checkAiStyle,
    bool checkPerspective,
    bool checkPacing,
    String aiModelId,
  });
}

/// @nodoc
class __$$ReviewConfigImplCopyWithImpl<$Res>
    extends _$ReviewConfigCopyWithImpl<$Res, _$ReviewConfigImpl>
    implements _$$ReviewConfigImplCopyWith<$Res> {
  __$$ReviewConfigImplCopyWithImpl(
    _$ReviewConfigImpl _value,
    $Res Function(_$ReviewConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReviewConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? autoReview = null,
    Object? dimensionStrictness = null,
    Object? checkAiStyle = null,
    Object? checkPerspective = null,
    Object? checkPacing = null,
    Object? aiModelId = null,
  }) {
    return _then(
      _$ReviewConfigImpl(
        autoReview: null == autoReview
            ? _value.autoReview
            : autoReview // ignore: cast_nullable_to_non_nullable
                  as bool,
        dimensionStrictness: null == dimensionStrictness
            ? _value._dimensionStrictness
            : dimensionStrictness // ignore: cast_nullable_to_non_nullable
                  as Map<String, int>,
        checkAiStyle: null == checkAiStyle
            ? _value.checkAiStyle
            : checkAiStyle // ignore: cast_nullable_to_non_nullable
                  as bool,
        checkPerspective: null == checkPerspective
            ? _value.checkPerspective
            : checkPerspective // ignore: cast_nullable_to_non_nullable
                  as bool,
        checkPacing: null == checkPacing
            ? _value.checkPacing
            : checkPacing // ignore: cast_nullable_to_non_nullable
                  as bool,
        aiModelId: null == aiModelId
            ? _value.aiModelId
            : aiModelId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReviewConfigImpl implements _ReviewConfig {
  const _$ReviewConfigImpl({
    this.autoReview = true,
    final Map<String, int> dimensionStrictness = const {},
    this.checkAiStyle = false,
    this.checkPerspective = false,
    this.checkPacing = false,
    required this.aiModelId,
  }) : _dimensionStrictness = dimensionStrictness;

  factory _$ReviewConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReviewConfigImplFromJson(json);

  @override
  @JsonKey()
  final bool autoReview;
  final Map<String, int> _dimensionStrictness;
  @override
  @JsonKey()
  Map<String, int> get dimensionStrictness {
    if (_dimensionStrictness is EqualUnmodifiableMapView)
      return _dimensionStrictness;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dimensionStrictness);
  }

  // 0-100
  @override
  @JsonKey()
  final bool checkAiStyle;
  @override
  @JsonKey()
  final bool checkPerspective;
  @override
  @JsonKey()
  final bool checkPacing;
  @override
  final String aiModelId;

  @override
  String toString() {
    return 'ReviewConfig(autoReview: $autoReview, dimensionStrictness: $dimensionStrictness, checkAiStyle: $checkAiStyle, checkPerspective: $checkPerspective, checkPacing: $checkPacing, aiModelId: $aiModelId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReviewConfigImpl &&
            (identical(other.autoReview, autoReview) ||
                other.autoReview == autoReview) &&
            const DeepCollectionEquality().equals(
              other._dimensionStrictness,
              _dimensionStrictness,
            ) &&
            (identical(other.checkAiStyle, checkAiStyle) ||
                other.checkAiStyle == checkAiStyle) &&
            (identical(other.checkPerspective, checkPerspective) ||
                other.checkPerspective == checkPerspective) &&
            (identical(other.checkPacing, checkPacing) ||
                other.checkPacing == checkPacing) &&
            (identical(other.aiModelId, aiModelId) ||
                other.aiModelId == aiModelId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    autoReview,
    const DeepCollectionEquality().hash(_dimensionStrictness),
    checkAiStyle,
    checkPerspective,
    checkPacing,
    aiModelId,
  );

  /// Create a copy of ReviewConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReviewConfigImplCopyWith<_$ReviewConfigImpl> get copyWith =>
      __$$ReviewConfigImplCopyWithImpl<_$ReviewConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReviewConfigImplToJson(this);
  }
}

abstract class _ReviewConfig implements ReviewConfig {
  const factory _ReviewConfig({
    final bool autoReview,
    final Map<String, int> dimensionStrictness,
    final bool checkAiStyle,
    final bool checkPerspective,
    final bool checkPacing,
    required final String aiModelId,
  }) = _$ReviewConfigImpl;

  factory _ReviewConfig.fromJson(Map<String, dynamic> json) =
      _$ReviewConfigImpl.fromJson;

  @override
  bool get autoReview;
  @override
  Map<String, int> get dimensionStrictness; // 0-100
  @override
  bool get checkAiStyle;
  @override
  bool get checkPerspective;
  @override
  bool get checkPacing;
  @override
  String get aiModelId;

  /// Create a copy of ReviewConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReviewConfigImplCopyWith<_$ReviewConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
