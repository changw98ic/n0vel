import 'package:freezed_annotation/freezed_annotation.dart';

part 'character_profile.freezed.dart';
part 'character_profile.g.dart';

/// MBTI 人格类型
enum MBTI {
  intj('INTJ', '建筑师'),
  intp('INTP', '逻辑学家'),
  entj('ENTJ', '指挥官'),
  entp('ENTP', '辩论家'),
  infj('INFJ', '提倡者'),
  infp('INFP', '调停者'),
  enfj('ENFJ', '主人公'),
  enfp('ENFP', '竞选者'),
  istj('ISTJ', '物流师'),
  istp('ISTP', '鉴赏家'),
  estj('ESTJ', '总经理'),
  estp('ESTP', '企业家'),
  isfj('ISFJ', '守卫者'),
  isfp('ISFP', '探险家'),
  esfj('ESFJ', '执政官'),
  esfp('ESFP', '表演者');

  const MBTI(this.code, this.name);

  final String code;
  final String name;
}

/// 大五人格维度
@freezed
class BigFive with _$BigFive {
  const factory BigFive({
    @Default(50) int openness,       // 开放性 0-100
    @Default(50) int conscientiousness, // 尽责性 0-100
    @Default(50) int extraversion,      // 外向性 0-100
    @Default(50) int agreeableness,     // 宜人性 0-100
    @Default(50) int neuroticism,       // 神经质 0-100
  }) = _BigFive;

  factory BigFive.fromJson(Map<String, dynamic> json) => _$BigFiveFromJson(json);
}

/// 语言风格
@freezed
class SpeechStyle with _$SpeechStyle {
  const factory SpeechStyle({
    String? languageStyle,    // 简洁/文雅/粗俗/幽默
    String? toneStyle,        // 冷淡/热情/温和/嘲讽
    @Default('medium') String speed, // 快/中/慢
    List<String>? sentencePatterns,  // 句式偏好
    List<String>? catchphrases,      // 口头禅
    List<String>? vocabularyPreferences, // 词汇偏好
    List<String>? tabooWords,         // 避讳词
    List<SpeechExample>? examples,    // 台词示例
  }) = _SpeechStyle;

  factory SpeechStyle.fromJson(Map<String, dynamic> json) =>
      _$SpeechStyleFromJson(json);
}

/// 台词示例
@freezed
class SpeechExample with _$SpeechExample {
  const factory SpeechExample({
    required String scene,
    required String emotion,
    required String line,
  }) = _SpeechExample;

  factory SpeechExample.fromJson(Map<String, dynamic> json) =>
      _$SpeechExampleFromJson(json);
}

/// 行为模式
@freezed
class BehaviorPattern with _$BehaviorPattern {
  const factory BehaviorPattern({
    required String trigger,     // 触发条件
    required String behavior,    // 行为反应
    String? description,         // 详细描述
  }) = _BehaviorPattern;

  factory BehaviorPattern.fromJson(Map<String, dynamic> json) =>
      _$BehaviorPatternFromJson(json);
}

/// 角色深度档案
@freezed
class CharacterProfile with _$CharacterProfile {
  const CharacterProfile._();

  const factory CharacterProfile({
    required String id,
    required String characterId,
    MBTI? mbti,
    BigFive? bigFive,
    @Default([]) List<String> personalityKeywords,
    String? coreValues,
    String? fears,
    String? desires,
    String? moralBaseline,
    SpeechStyle? speechStyle,
    @Default([]) List<BehaviorPattern> behaviorPatterns,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CharacterProfile;

  factory CharacterProfile.fromJson(Map<String, dynamic> json) =>
      _$CharacterProfileFromJson(json);

  /// 是否有完整档案
  bool get isComplete =>
      mbti != null &&
      personalityKeywords.isNotEmpty &&
      coreValues != null &&
      speechStyle != null;
}
