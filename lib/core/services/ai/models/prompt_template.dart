import 'package:freezed_annotation/freezed_annotation.dart';

part 'prompt_template.freezed.dart';
part 'prompt_template.g.dart';

/// Prompt 模板
/// 支持用户自定义各功能的 Prompt
@freezed
class PromptTemplate with _$PromptTemplate {
  const PromptTemplate._();

  const factory PromptTemplate({
    required String id,
    required String functionType,   // 对应 AIFunction.key
    required String name,
    required String systemPrompt,
    required String userPromptTemplate,
    String? description,
    @Default([]) List<String> variables,  // 模板变量列表
    @Default(1) int version,
    @Default(false) bool isDefault,
    @Default(false) bool isBuiltIn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _PromptTemplate;

  factory PromptTemplate.fromJson(Map<String, dynamic> json) =>
      _$PromptTemplateFromJson(json);

  /// 渲染模板
  String render(Map<String, dynamic> variables) {
    var result = userPromptTemplate;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value.toString());
    }
    return result;
  }

  /// 验证模板变量
  List<String> validateVariables(Map<String, dynamic> provided) {
    final missing = <String>[];
    for (final v in variables) {
      if (!provided.containsKey(v) || provided[v] == null) {
        missing.add(v);
      }
    }
    return missing;
  }
}

/// 角色扮演 Prompt 生成器
class CharacterPromptBuilder {
  /// 从角色档案生成角色扮演 Prompt
  static String buildCharacterPrompt({
    required String characterName,
    required String tier,
    String? mbti,
    Map<String, dynamic>? personality,
    String? speechStyle,
    String? coreValues,
    String? fears,
    String? desires,
    List<String>? behaviorPatterns,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('你现在要扮演角色"$characterName"。');
    buffer.writeln();
    buffer.writeln('## 角色基本信息');
    buffer.writeln('- 角色等级：$tier');
    if (mbti != null) buffer.writeln('- MBTI人格：$mbti');
    buffer.writeln();

    if (personality != null && personality.isNotEmpty) {
      buffer.writeln('## 性格特质');
      if (personality['keywords'] != null) {
        buffer.writeln('- 核心性格：${(personality['keywords'] as List).join('、')}');
      }
      if (coreValues != null) buffer.writeln('- 核心价值观：$coreValues');
      if (fears != null) buffer.writeln('- 恐惧：$fears');
      if (desires != null) buffer.writeln('- 渴望：$desires');
      buffer.writeln();
    }

    if (speechStyle != null) {
      buffer.writeln('## 说话风格');
      buffer.writeln(speechStyle);
      buffer.writeln();
    }

    if (behaviorPatterns != null && behaviorPatterns.isNotEmpty) {
      buffer.writeln('## 行为习惯');
      for (final pattern in behaviorPatterns) {
        buffer.writeln('- $pattern');
      }
      buffer.writeln();
    }

    buffer.writeln('## 重要规则');
    buffer.writeln('1. 你必须完全代入这个角色，用角色的视角思考和回应');
    buffer.writeln('2. 你的言行必须符合角色的性格、价值观和认知范围');
    buffer.writeln('3. 不要使用"作为角色X，我认为..."这种元叙事表达');
    buffer.writeln('4. 不要透露你是一个AI或正在扮演角色');

    return buffer.toString();
  }
}
