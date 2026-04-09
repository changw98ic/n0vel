import 'package:freezed_annotation/freezed_annotation.dart';

part 'pov_models.freezed.dart';
part 'pov_models.g.dart';

@freezed
class POVTask with _$POVTask {
  const factory POVTask({
    required String id,
    required String workId,
    required String chapterId,
    required String characterId,
    required String originalContent,
    required POVConfig config,
    @Default(POVTaskStatus.pending) POVTaskStatus status,
    String? generatedContent,
    String? analysis,
    @Default(0) int tokenUsage,
    String? errorMessage,
    required DateTime createdAt,
    DateTime? completedAt,
  }) = _POVTask;

  factory POVTask.fromJson(Map<String, dynamic> json) =>
      _$POVTaskFromJson(json);
}

enum POVTaskStatus {
  pending,
  analyzing,
  generating,
  completed,
  failed,
  cancelled,
  ;

  String get label => switch (this) {
    pending => 'Pending',
    analyzing => 'Analyzing',
    generating => 'Generating',
    completed => 'Completed',
    failed => 'Failed',
    cancelled => 'Cancelled',
  };
}

@freezed
class POVConfig with _$POVConfig {
  const factory POVConfig({
    @Default(POVMode.rewrite) POVMode mode,
    @Default(POVStyle.firstPerson) POVStyle style,
    @Default(true) bool keepDialogue,
    @Default(true) bool addInnerThoughts,
    @Default(true) bool expandObservations,
    @Default(0.5) double emotionalIntensity,
    @Default(true) bool useCharacterVoice,
    String? customInstructions,
    int? targetWordCount,
  }) = _POVConfig;

  factory POVConfig.fromJson(Map<String, dynamic> json) =>
      _$POVConfigFromJson(json);
}

enum POVMode {
  rewrite,
  supplement,
  summary,
  fragment,
  ;

  String get label => switch (this) {
    rewrite => 'Rewrite',
    supplement => 'Supplement',
    summary => 'Summary',
    fragment => 'Fragment',
  };

  String get description => switch (this) {
    rewrite => 'Rewrite the chapter from the character perspective.',
    supplement => 'Add missing perspective details on top of the original.',
    summary => 'Generate a perspective summary.',
    fragment => 'Generate only a focused scene fragment.',
  };
}

enum POVStyle {
  firstPerson,
  thirdPersonLimited,
  diary,
  memoir,
  ;

  String get label => switch (this) {
    firstPerson => 'First Person',
    thirdPersonLimited => 'Third Person Limited',
    diary => 'Diary',
    memoir => 'Memoir',
  };
}

@freezed
class POVAnalysis with _$POVAnalysis {
  const factory POVAnalysis({
    required List<CharacterAppearance> appearances,
    required List<EmotionPoint> emotionCurve,
    required List<KeyObservation> observations,
    required List<CharacterInteraction> interactions,
    required List<InnerThought> suggestedThoughts,
    required List<String> suggestions,
  }) = _POVAnalysis;

  factory POVAnalysis.fromJson(Map<String, dynamic> json) =>
      _$POVAnalysisFromJson(json);
}

@freezed
class CharacterAppearance with _$CharacterAppearance {
  const factory CharacterAppearance({
    required int paragraphIndex,
    required String originalText,
    String? action,
    String? dialogue,
    String? contextSummary,
  }) = _CharacterAppearance;

  factory CharacterAppearance.fromJson(Map<String, dynamic> json) =>
      _$CharacterAppearanceFromJson(json);
}

@freezed
class EmotionPoint with _$EmotionPoint {
  const factory EmotionPoint({
    required int position,
    required EmotionType type,
    required double intensity,
    String? trigger,
    String? description,
  }) = _EmotionPoint;

  factory EmotionPoint.fromJson(Map<String, dynamic> json) =>
      _$EmotionPointFromJson(json);
}

enum EmotionType {
  joy,
  sadness,
  anger,
  fear,
  surprise,
  disgust,
  anticipation,
  trust,
  love,
  hate,
  hope,
  despair,
  ;

  String get label => name;
}

@freezed
class KeyObservation with _$KeyObservation {
  const factory KeyObservation({
    required int position,
    required String content,
    required ObservationType type,
    String? characterReaction,
  }) = _KeyObservation;

  factory KeyObservation.fromJson(Map<String, dynamic> json) =>
      _$KeyObservationFromJson(json);
}

enum ObservationType {
  character,
  environment,
  action,
  dialogue,
  inner,
  ;

  String get label => name;
}

@freezed
class CharacterInteraction with _$CharacterInteraction {
  const factory CharacterInteraction({
    required String otherCharacterId,
    required String otherCharacterName,
    required int position,
    required InteractionType type,
    String? content,
    String? povCharacterReaction,
  }) = _CharacterInteraction;

  factory CharacterInteraction.fromJson(Map<String, dynamic> json) =>
      _$CharacterInteractionFromJson(json);
}

enum InteractionType {
  dialogue,
  action,
  eye,
  physical,
  mental,
  ;

  String get label => name;
}

@freezed
class InnerThought with _$InnerThought {
  const factory InnerThought({
    required int position,
    required String content,
    required ThoughtType type,
    String? trigger,
  }) = _InnerThought;

  factory InnerThought.fromJson(Map<String, dynamic> json) =>
      _$InnerThoughtFromJson(json);
}

enum ThoughtType {
  reaction,
  reflection,
  memory,
  plan,
  emotion,
  judgment,
  ;

  String get label => name;
}

@freezed
class POVTemplate with _$POVTemplate {
  const factory POVTemplate({
    required String id,
    required String name,
    required String description,
    required POVConfig config,
    @Default([]) List<String> suitableCharacterTypes,
    String? exampleOutput,
    @Default(false) bool isBuiltIn,
  }) = _POVTemplate;

  factory POVTemplate.fromJson(Map<String, dynamic> json) =>
      _$POVTemplateFromJson(json);
}

/// POV 保存选项
@freezed
class POVSaveOptions with _$POVSaveOptions {
  const factory POVSaveOptions({
    required bool canSaveAsDraft,
    required bool canReplaceChapter,
    required bool canCreateNewChapter,
    String? currentChapterTitle,
    required int suggestedSortOrder,
    String? defaultVolumeId,
  }) = _POVSaveOptions;

  factory POVSaveOptions.fromJson(Map<String, dynamic> json) =>
      _$POVSaveOptionsFromJson(json);
}

/// POV 保存类型
enum POVSaveType {
  draft,
  replaceChapter,
  newChapter,
  ;

  String get label => switch (this) {
        draft => '保存为草稿',
        replaceChapter => '替换当前章节',
        newChapter => '创建新章节',
      };
}
