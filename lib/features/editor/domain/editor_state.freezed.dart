// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'editor_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$EditorState {
  String get chapterId => throw _privateConstructorUsedError;
  String? get content => throw _privateConstructorUsedError;
  bool get isDirty => throw _privateConstructorUsedError;
  bool get isSaving => throw _privateConstructorUsedError;
  bool get autoSaveEnabled => throw _privateConstructorUsedError;
  DateTime? get lastSavedAt => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError; // 统计
  int get wordCount => throw _privateConstructorUsedError;
  int get paragraphCount => throw _privateConstructorUsedError;
  int get dialogueCount => throw _privateConstructorUsedError;
  int get dialogueWordCount => throw _privateConstructorUsedError; // 选中的角色
  List<String> get involvedCharacterIds =>
      throw _privateConstructorUsedError; // 撤销/重做
  List<EditorHistoryEntry> get undoStack => throw _privateConstructorUsedError;
  List<EditorHistoryEntry> get redoStack => throw _privateConstructorUsedError;
  int get maxHistorySize => throw _privateConstructorUsedError;

  /// Create a copy of EditorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EditorStateCopyWith<EditorState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EditorStateCopyWith<$Res> {
  factory $EditorStateCopyWith(
    EditorState value,
    $Res Function(EditorState) then,
  ) = _$EditorStateCopyWithImpl<$Res, EditorState>;
  @useResult
  $Res call({
    String chapterId,
    String? content,
    bool isDirty,
    bool isSaving,
    bool autoSaveEnabled,
    DateTime? lastSavedAt,
    String? error,
    int wordCount,
    int paragraphCount,
    int dialogueCount,
    int dialogueWordCount,
    List<String> involvedCharacterIds,
    List<EditorHistoryEntry> undoStack,
    List<EditorHistoryEntry> redoStack,
    int maxHistorySize,
  });
}

/// @nodoc
class _$EditorStateCopyWithImpl<$Res, $Val extends EditorState>
    implements $EditorStateCopyWith<$Res> {
  _$EditorStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EditorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? content = freezed,
    Object? isDirty = null,
    Object? isSaving = null,
    Object? autoSaveEnabled = null,
    Object? lastSavedAt = freezed,
    Object? error = freezed,
    Object? wordCount = null,
    Object? paragraphCount = null,
    Object? dialogueCount = null,
    Object? dialogueWordCount = null,
    Object? involvedCharacterIds = null,
    Object? undoStack = null,
    Object? redoStack = null,
    Object? maxHistorySize = null,
  }) {
    return _then(
      _value.copyWith(
            chapterId: null == chapterId
                ? _value.chapterId
                : chapterId // ignore: cast_nullable_to_non_nullable
                      as String,
            content: freezed == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String?,
            isDirty: null == isDirty
                ? _value.isDirty
                : isDirty // ignore: cast_nullable_to_non_nullable
                      as bool,
            isSaving: null == isSaving
                ? _value.isSaving
                : isSaving // ignore: cast_nullable_to_non_nullable
                      as bool,
            autoSaveEnabled: null == autoSaveEnabled
                ? _value.autoSaveEnabled
                : autoSaveEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            lastSavedAt: freezed == lastSavedAt
                ? _value.lastSavedAt
                : lastSavedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
            wordCount: null == wordCount
                ? _value.wordCount
                : wordCount // ignore: cast_nullable_to_non_nullable
                      as int,
            paragraphCount: null == paragraphCount
                ? _value.paragraphCount
                : paragraphCount // ignore: cast_nullable_to_non_nullable
                      as int,
            dialogueCount: null == dialogueCount
                ? _value.dialogueCount
                : dialogueCount // ignore: cast_nullable_to_non_nullable
                      as int,
            dialogueWordCount: null == dialogueWordCount
                ? _value.dialogueWordCount
                : dialogueWordCount // ignore: cast_nullable_to_non_nullable
                      as int,
            involvedCharacterIds: null == involvedCharacterIds
                ? _value.involvedCharacterIds
                : involvedCharacterIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            undoStack: null == undoStack
                ? _value.undoStack
                : undoStack // ignore: cast_nullable_to_non_nullable
                      as List<EditorHistoryEntry>,
            redoStack: null == redoStack
                ? _value.redoStack
                : redoStack // ignore: cast_nullable_to_non_nullable
                      as List<EditorHistoryEntry>,
            maxHistorySize: null == maxHistorySize
                ? _value.maxHistorySize
                : maxHistorySize // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EditorStateImplCopyWith<$Res>
    implements $EditorStateCopyWith<$Res> {
  factory _$$EditorStateImplCopyWith(
    _$EditorStateImpl value,
    $Res Function(_$EditorStateImpl) then,
  ) = __$$EditorStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String chapterId,
    String? content,
    bool isDirty,
    bool isSaving,
    bool autoSaveEnabled,
    DateTime? lastSavedAt,
    String? error,
    int wordCount,
    int paragraphCount,
    int dialogueCount,
    int dialogueWordCount,
    List<String> involvedCharacterIds,
    List<EditorHistoryEntry> undoStack,
    List<EditorHistoryEntry> redoStack,
    int maxHistorySize,
  });
}

/// @nodoc
class __$$EditorStateImplCopyWithImpl<$Res>
    extends _$EditorStateCopyWithImpl<$Res, _$EditorStateImpl>
    implements _$$EditorStateImplCopyWith<$Res> {
  __$$EditorStateImplCopyWithImpl(
    _$EditorStateImpl _value,
    $Res Function(_$EditorStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EditorState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? chapterId = null,
    Object? content = freezed,
    Object? isDirty = null,
    Object? isSaving = null,
    Object? autoSaveEnabled = null,
    Object? lastSavedAt = freezed,
    Object? error = freezed,
    Object? wordCount = null,
    Object? paragraphCount = null,
    Object? dialogueCount = null,
    Object? dialogueWordCount = null,
    Object? involvedCharacterIds = null,
    Object? undoStack = null,
    Object? redoStack = null,
    Object? maxHistorySize = null,
  }) {
    return _then(
      _$EditorStateImpl(
        chapterId: null == chapterId
            ? _value.chapterId
            : chapterId // ignore: cast_nullable_to_non_nullable
                  as String,
        content: freezed == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String?,
        isDirty: null == isDirty
            ? _value.isDirty
            : isDirty // ignore: cast_nullable_to_non_nullable
                  as bool,
        isSaving: null == isSaving
            ? _value.isSaving
            : isSaving // ignore: cast_nullable_to_non_nullable
                  as bool,
        autoSaveEnabled: null == autoSaveEnabled
            ? _value.autoSaveEnabled
            : autoSaveEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        lastSavedAt: freezed == lastSavedAt
            ? _value.lastSavedAt
            : lastSavedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
        wordCount: null == wordCount
            ? _value.wordCount
            : wordCount // ignore: cast_nullable_to_non_nullable
                  as int,
        paragraphCount: null == paragraphCount
            ? _value.paragraphCount
            : paragraphCount // ignore: cast_nullable_to_non_nullable
                  as int,
        dialogueCount: null == dialogueCount
            ? _value.dialogueCount
            : dialogueCount // ignore: cast_nullable_to_non_nullable
                  as int,
        dialogueWordCount: null == dialogueWordCount
            ? _value.dialogueWordCount
            : dialogueWordCount // ignore: cast_nullable_to_non_nullable
                  as int,
        involvedCharacterIds: null == involvedCharacterIds
            ? _value._involvedCharacterIds
            : involvedCharacterIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        undoStack: null == undoStack
            ? _value._undoStack
            : undoStack // ignore: cast_nullable_to_non_nullable
                  as List<EditorHistoryEntry>,
        redoStack: null == redoStack
            ? _value._redoStack
            : redoStack // ignore: cast_nullable_to_non_nullable
                  as List<EditorHistoryEntry>,
        maxHistorySize: null == maxHistorySize
            ? _value.maxHistorySize
            : maxHistorySize // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$EditorStateImpl extends _EditorState {
  const _$EditorStateImpl({
    required this.chapterId,
    this.content,
    this.isDirty = false,
    this.isSaving = false,
    this.autoSaveEnabled = false,
    this.lastSavedAt,
    this.error,
    this.wordCount = 0,
    this.paragraphCount = 0,
    this.dialogueCount = 0,
    this.dialogueWordCount = 0,
    final List<String> involvedCharacterIds = const [],
    final List<EditorHistoryEntry> undoStack = const [],
    final List<EditorHistoryEntry> redoStack = const [],
    this.maxHistorySize = 0,
  }) : _involvedCharacterIds = involvedCharacterIds,
       _undoStack = undoStack,
       _redoStack = redoStack,
       super._();

  @override
  final String chapterId;
  @override
  final String? content;
  @override
  @JsonKey()
  final bool isDirty;
  @override
  @JsonKey()
  final bool isSaving;
  @override
  @JsonKey()
  final bool autoSaveEnabled;
  @override
  final DateTime? lastSavedAt;
  @override
  final String? error;
  // 统计
  @override
  @JsonKey()
  final int wordCount;
  @override
  @JsonKey()
  final int paragraphCount;
  @override
  @JsonKey()
  final int dialogueCount;
  @override
  @JsonKey()
  final int dialogueWordCount;
  // 选中的角色
  final List<String> _involvedCharacterIds;
  // 选中的角色
  @override
  @JsonKey()
  List<String> get involvedCharacterIds {
    if (_involvedCharacterIds is EqualUnmodifiableListView)
      return _involvedCharacterIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_involvedCharacterIds);
  }

  // 撤销/重做
  final List<EditorHistoryEntry> _undoStack;
  // 撤销/重做
  @override
  @JsonKey()
  List<EditorHistoryEntry> get undoStack {
    if (_undoStack is EqualUnmodifiableListView) return _undoStack;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_undoStack);
  }

  final List<EditorHistoryEntry> _redoStack;
  @override
  @JsonKey()
  List<EditorHistoryEntry> get redoStack {
    if (_redoStack is EqualUnmodifiableListView) return _redoStack;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_redoStack);
  }

  @override
  @JsonKey()
  final int maxHistorySize;

  @override
  String toString() {
    return 'EditorState(chapterId: $chapterId, content: $content, isDirty: $isDirty, isSaving: $isSaving, autoSaveEnabled: $autoSaveEnabled, lastSavedAt: $lastSavedAt, error: $error, wordCount: $wordCount, paragraphCount: $paragraphCount, dialogueCount: $dialogueCount, dialogueWordCount: $dialogueWordCount, involvedCharacterIds: $involvedCharacterIds, undoStack: $undoStack, redoStack: $redoStack, maxHistorySize: $maxHistorySize)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EditorStateImpl &&
            (identical(other.chapterId, chapterId) ||
                other.chapterId == chapterId) &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.isDirty, isDirty) || other.isDirty == isDirty) &&
            (identical(other.isSaving, isSaving) ||
                other.isSaving == isSaving) &&
            (identical(other.autoSaveEnabled, autoSaveEnabled) ||
                other.autoSaveEnabled == autoSaveEnabled) &&
            (identical(other.lastSavedAt, lastSavedAt) ||
                other.lastSavedAt == lastSavedAt) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.wordCount, wordCount) ||
                other.wordCount == wordCount) &&
            (identical(other.paragraphCount, paragraphCount) ||
                other.paragraphCount == paragraphCount) &&
            (identical(other.dialogueCount, dialogueCount) ||
                other.dialogueCount == dialogueCount) &&
            (identical(other.dialogueWordCount, dialogueWordCount) ||
                other.dialogueWordCount == dialogueWordCount) &&
            const DeepCollectionEquality().equals(
              other._involvedCharacterIds,
              _involvedCharacterIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._undoStack,
              _undoStack,
            ) &&
            const DeepCollectionEquality().equals(
              other._redoStack,
              _redoStack,
            ) &&
            (identical(other.maxHistorySize, maxHistorySize) ||
                other.maxHistorySize == maxHistorySize));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    chapterId,
    content,
    isDirty,
    isSaving,
    autoSaveEnabled,
    lastSavedAt,
    error,
    wordCount,
    paragraphCount,
    dialogueCount,
    dialogueWordCount,
    const DeepCollectionEquality().hash(_involvedCharacterIds),
    const DeepCollectionEquality().hash(_undoStack),
    const DeepCollectionEquality().hash(_redoStack),
    maxHistorySize,
  );

  /// Create a copy of EditorState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EditorStateImplCopyWith<_$EditorStateImpl> get copyWith =>
      __$$EditorStateImplCopyWithImpl<_$EditorStateImpl>(this, _$identity);
}

abstract class _EditorState extends EditorState {
  const factory _EditorState({
    required final String chapterId,
    final String? content,
    final bool isDirty,
    final bool isSaving,
    final bool autoSaveEnabled,
    final DateTime? lastSavedAt,
    final String? error,
    final int wordCount,
    final int paragraphCount,
    final int dialogueCount,
    final int dialogueWordCount,
    final List<String> involvedCharacterIds,
    final List<EditorHistoryEntry> undoStack,
    final List<EditorHistoryEntry> redoStack,
    final int maxHistorySize,
  }) = _$EditorStateImpl;
  const _EditorState._() : super._();

  @override
  String get chapterId;
  @override
  String? get content;
  @override
  bool get isDirty;
  @override
  bool get isSaving;
  @override
  bool get autoSaveEnabled;
  @override
  DateTime? get lastSavedAt;
  @override
  String? get error; // 统计
  @override
  int get wordCount;
  @override
  int get paragraphCount;
  @override
  int get dialogueCount;
  @override
  int get dialogueWordCount; // 选中的角色
  @override
  List<String> get involvedCharacterIds; // 撤销/重做
  @override
  List<EditorHistoryEntry> get undoStack;
  @override
  List<EditorHistoryEntry> get redoStack;
  @override
  int get maxHistorySize;

  /// Create a copy of EditorState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EditorStateImplCopyWith<_$EditorStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$EditorHistoryEntry {
  String get content => throw _privateConstructorUsedError;
  int get cursorPosition => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;

  /// Create a copy of EditorHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EditorHistoryEntryCopyWith<EditorHistoryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EditorHistoryEntryCopyWith<$Res> {
  factory $EditorHistoryEntryCopyWith(
    EditorHistoryEntry value,
    $Res Function(EditorHistoryEntry) then,
  ) = _$EditorHistoryEntryCopyWithImpl<$Res, EditorHistoryEntry>;
  @useResult
  $Res call({
    String content,
    int cursorPosition,
    DateTime timestamp,
    String? description,
  });
}

/// @nodoc
class _$EditorHistoryEntryCopyWithImpl<$Res, $Val extends EditorHistoryEntry>
    implements $EditorHistoryEntryCopyWith<$Res> {
  _$EditorHistoryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EditorHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? cursorPosition = null,
    Object? timestamp = null,
    Object? description = freezed,
  }) {
    return _then(
      _value.copyWith(
            content: null == content
                ? _value.content
                : content // ignore: cast_nullable_to_non_nullable
                      as String,
            cursorPosition: null == cursorPosition
                ? _value.cursorPosition
                : cursorPosition // ignore: cast_nullable_to_non_nullable
                      as int,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EditorHistoryEntryImplCopyWith<$Res>
    implements $EditorHistoryEntryCopyWith<$Res> {
  factory _$$EditorHistoryEntryImplCopyWith(
    _$EditorHistoryEntryImpl value,
    $Res Function(_$EditorHistoryEntryImpl) then,
  ) = __$$EditorHistoryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String content,
    int cursorPosition,
    DateTime timestamp,
    String? description,
  });
}

/// @nodoc
class __$$EditorHistoryEntryImplCopyWithImpl<$Res>
    extends _$EditorHistoryEntryCopyWithImpl<$Res, _$EditorHistoryEntryImpl>
    implements _$$EditorHistoryEntryImplCopyWith<$Res> {
  __$$EditorHistoryEntryImplCopyWithImpl(
    _$EditorHistoryEntryImpl _value,
    $Res Function(_$EditorHistoryEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EditorHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? content = null,
    Object? cursorPosition = null,
    Object? timestamp = null,
    Object? description = freezed,
  }) {
    return _then(
      _$EditorHistoryEntryImpl(
        content: null == content
            ? _value.content
            : content // ignore: cast_nullable_to_non_nullable
                  as String,
        cursorPosition: null == cursorPosition
            ? _value.cursorPosition
            : cursorPosition // ignore: cast_nullable_to_non_nullable
                  as int,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$EditorHistoryEntryImpl implements _EditorHistoryEntry {
  const _$EditorHistoryEntryImpl({
    required this.content,
    required this.cursorPosition,
    required this.timestamp,
    this.description,
  });

  @override
  final String content;
  @override
  final int cursorPosition;
  @override
  final DateTime timestamp;
  @override
  final String? description;

  @override
  String toString() {
    return 'EditorHistoryEntry(content: $content, cursorPosition: $cursorPosition, timestamp: $timestamp, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EditorHistoryEntryImpl &&
            (identical(other.content, content) || other.content == content) &&
            (identical(other.cursorPosition, cursorPosition) ||
                other.cursorPosition == cursorPosition) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, content, cursorPosition, timestamp, description);

  /// Create a copy of EditorHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EditorHistoryEntryImplCopyWith<_$EditorHistoryEntryImpl> get copyWith =>
      __$$EditorHistoryEntryImplCopyWithImpl<_$EditorHistoryEntryImpl>(
        this,
        _$identity,
      );
}

abstract class _EditorHistoryEntry implements EditorHistoryEntry {
  const factory _EditorHistoryEntry({
    required final String content,
    required final int cursorPosition,
    required final DateTime timestamp,
    final String? description,
  }) = _$EditorHistoryEntryImpl;

  @override
  String get content;
  @override
  int get cursorPosition;
  @override
  DateTime get timestamp;
  @override
  String? get description;

  /// Create a copy of EditorHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EditorHistoryEntryImplCopyWith<_$EditorHistoryEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SmartSegmentResult {
  List<Segment> get segments => throw _privateConstructorUsedError;
  List<String> get detectedSpeakers => throw _privateConstructorUsedError;
  int get dialogueCount => throw _privateConstructorUsedError;
  int get innerThoughtCount => throw _privateConstructorUsedError;

  /// Create a copy of SmartSegmentResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SmartSegmentResultCopyWith<SmartSegmentResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SmartSegmentResultCopyWith<$Res> {
  factory $SmartSegmentResultCopyWith(
    SmartSegmentResult value,
    $Res Function(SmartSegmentResult) then,
  ) = _$SmartSegmentResultCopyWithImpl<$Res, SmartSegmentResult>;
  @useResult
  $Res call({
    List<Segment> segments,
    List<String> detectedSpeakers,
    int dialogueCount,
    int innerThoughtCount,
  });
}

/// @nodoc
class _$SmartSegmentResultCopyWithImpl<$Res, $Val extends SmartSegmentResult>
    implements $SmartSegmentResultCopyWith<$Res> {
  _$SmartSegmentResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SmartSegmentResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? segments = null,
    Object? detectedSpeakers = null,
    Object? dialogueCount = null,
    Object? innerThoughtCount = null,
  }) {
    return _then(
      _value.copyWith(
            segments: null == segments
                ? _value.segments
                : segments // ignore: cast_nullable_to_non_nullable
                      as List<Segment>,
            detectedSpeakers: null == detectedSpeakers
                ? _value.detectedSpeakers
                : detectedSpeakers // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            dialogueCount: null == dialogueCount
                ? _value.dialogueCount
                : dialogueCount // ignore: cast_nullable_to_non_nullable
                      as int,
            innerThoughtCount: null == innerThoughtCount
                ? _value.innerThoughtCount
                : innerThoughtCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SmartSegmentResultImplCopyWith<$Res>
    implements $SmartSegmentResultCopyWith<$Res> {
  factory _$$SmartSegmentResultImplCopyWith(
    _$SmartSegmentResultImpl value,
    $Res Function(_$SmartSegmentResultImpl) then,
  ) = __$$SmartSegmentResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Segment> segments,
    List<String> detectedSpeakers,
    int dialogueCount,
    int innerThoughtCount,
  });
}

/// @nodoc
class __$$SmartSegmentResultImplCopyWithImpl<$Res>
    extends _$SmartSegmentResultCopyWithImpl<$Res, _$SmartSegmentResultImpl>
    implements _$$SmartSegmentResultImplCopyWith<$Res> {
  __$$SmartSegmentResultImplCopyWithImpl(
    _$SmartSegmentResultImpl _value,
    $Res Function(_$SmartSegmentResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SmartSegmentResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? segments = null,
    Object? detectedSpeakers = null,
    Object? dialogueCount = null,
    Object? innerThoughtCount = null,
  }) {
    return _then(
      _$SmartSegmentResultImpl(
        segments: null == segments
            ? _value._segments
            : segments // ignore: cast_nullable_to_non_nullable
                  as List<Segment>,
        detectedSpeakers: null == detectedSpeakers
            ? _value._detectedSpeakers
            : detectedSpeakers // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        dialogueCount: null == dialogueCount
            ? _value.dialogueCount
            : dialogueCount // ignore: cast_nullable_to_non_nullable
                  as int,
        innerThoughtCount: null == innerThoughtCount
            ? _value.innerThoughtCount
            : innerThoughtCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$SmartSegmentResultImpl implements _SmartSegmentResult {
  const _$SmartSegmentResultImpl({
    required final List<Segment> segments,
    final List<String> detectedSpeakers = const [],
    this.dialogueCount = 0,
    this.innerThoughtCount = 0,
  }) : _segments = segments,
       _detectedSpeakers = detectedSpeakers;

  final List<Segment> _segments;
  @override
  List<Segment> get segments {
    if (_segments is EqualUnmodifiableListView) return _segments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_segments);
  }

  final List<String> _detectedSpeakers;
  @override
  @JsonKey()
  List<String> get detectedSpeakers {
    if (_detectedSpeakers is EqualUnmodifiableListView)
      return _detectedSpeakers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_detectedSpeakers);
  }

  @override
  @JsonKey()
  final int dialogueCount;
  @override
  @JsonKey()
  final int innerThoughtCount;

  @override
  String toString() {
    return 'SmartSegmentResult(segments: $segments, detectedSpeakers: $detectedSpeakers, dialogueCount: $dialogueCount, innerThoughtCount: $innerThoughtCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SmartSegmentResultImpl &&
            const DeepCollectionEquality().equals(other._segments, _segments) &&
            const DeepCollectionEquality().equals(
              other._detectedSpeakers,
              _detectedSpeakers,
            ) &&
            (identical(other.dialogueCount, dialogueCount) ||
                other.dialogueCount == dialogueCount) &&
            (identical(other.innerThoughtCount, innerThoughtCount) ||
                other.innerThoughtCount == innerThoughtCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_segments),
    const DeepCollectionEquality().hash(_detectedSpeakers),
    dialogueCount,
    innerThoughtCount,
  );

  /// Create a copy of SmartSegmentResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SmartSegmentResultImplCopyWith<_$SmartSegmentResultImpl> get copyWith =>
      __$$SmartSegmentResultImplCopyWithImpl<_$SmartSegmentResultImpl>(
        this,
        _$identity,
      );
}

abstract class _SmartSegmentResult implements SmartSegmentResult {
  const factory _SmartSegmentResult({
    required final List<Segment> segments,
    final List<String> detectedSpeakers,
    final int dialogueCount,
    final int innerThoughtCount,
  }) = _$SmartSegmentResultImpl;

  @override
  List<Segment> get segments;
  @override
  List<String> get detectedSpeakers;
  @override
  int get dialogueCount;
  @override
  int get innerThoughtCount;

  /// Create a copy of SmartSegmentResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SmartSegmentResultImplCopyWith<_$SmartSegmentResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Segment _$SegmentFromJson(Map<String, dynamic> json) {
  return _Segment.fromJson(json);
}

/// @nodoc
mixin _$Segment {
  String get id => throw _privateConstructorUsedError;
  String get text => throw _privateConstructorUsedError;
  SegmentType get type => throw _privateConstructorUsedError;
  bool get needsIndent => throw _privateConstructorUsedError;
  String? get speakerId => throw _privateConstructorUsedError;

  /// Serializes this Segment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Segment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SegmentCopyWith<Segment> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SegmentCopyWith<$Res> {
  factory $SegmentCopyWith(Segment value, $Res Function(Segment) then) =
      _$SegmentCopyWithImpl<$Res, Segment>;
  @useResult
  $Res call({
    String id,
    String text,
    SegmentType type,
    bool needsIndent,
    String? speakerId,
  });
}

/// @nodoc
class _$SegmentCopyWithImpl<$Res, $Val extends Segment>
    implements $SegmentCopyWith<$Res> {
  _$SegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Segment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? type = null,
    Object? needsIndent = null,
    Object? speakerId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as SegmentType,
            needsIndent: null == needsIndent
                ? _value.needsIndent
                : needsIndent // ignore: cast_nullable_to_non_nullable
                      as bool,
            speakerId: freezed == speakerId
                ? _value.speakerId
                : speakerId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SegmentImplCopyWith<$Res> implements $SegmentCopyWith<$Res> {
  factory _$$SegmentImplCopyWith(
    _$SegmentImpl value,
    $Res Function(_$SegmentImpl) then,
  ) = __$$SegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String text,
    SegmentType type,
    bool needsIndent,
    String? speakerId,
  });
}

/// @nodoc
class __$$SegmentImplCopyWithImpl<$Res>
    extends _$SegmentCopyWithImpl<$Res, _$SegmentImpl>
    implements _$$SegmentImplCopyWith<$Res> {
  __$$SegmentImplCopyWithImpl(
    _$SegmentImpl _value,
    $Res Function(_$SegmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Segment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? text = null,
    Object? type = null,
    Object? needsIndent = null,
    Object? speakerId = freezed,
  }) {
    return _then(
      _$SegmentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as SegmentType,
        needsIndent: null == needsIndent
            ? _value.needsIndent
            : needsIndent // ignore: cast_nullable_to_non_nullable
                  as bool,
        speakerId: freezed == speakerId
            ? _value.speakerId
            : speakerId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SegmentImpl extends _Segment {
  const _$SegmentImpl({
    required this.id,
    required this.text,
    required this.type,
    this.needsIndent = true,
    this.speakerId,
  }) : super._();

  factory _$SegmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$SegmentImplFromJson(json);

  @override
  final String id;
  @override
  final String text;
  @override
  final SegmentType type;
  @override
  @JsonKey()
  final bool needsIndent;
  @override
  final String? speakerId;

  @override
  String toString() {
    return 'Segment(id: $id, text: $text, type: $type, needsIndent: $needsIndent, speakerId: $speakerId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SegmentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.needsIndent, needsIndent) ||
                other.needsIndent == needsIndent) &&
            (identical(other.speakerId, speakerId) ||
                other.speakerId == speakerId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, text, type, needsIndent, speakerId);

  /// Create a copy of Segment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SegmentImplCopyWith<_$SegmentImpl> get copyWith =>
      __$$SegmentImplCopyWithImpl<_$SegmentImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SegmentImplToJson(this);
  }
}

abstract class _Segment extends Segment {
  const factory _Segment({
    required final String id,
    required final String text,
    required final SegmentType type,
    final bool needsIndent,
    final String? speakerId,
  }) = _$SegmentImpl;
  const _Segment._() : super._();

  factory _Segment.fromJson(Map<String, dynamic> json) = _$SegmentImpl.fromJson;

  @override
  String get id;
  @override
  String get text;
  @override
  SegmentType get type;
  @override
  bool get needsIndent;
  @override
  String? get speakerId;

  /// Create a copy of Segment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SegmentImplCopyWith<_$SegmentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
