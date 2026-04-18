import 'writer_runtime_hooks.dart';

/// 校验结果
class PersistenceValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const PersistenceValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// 合并多次校验结果
  PersistenceValidationResult merge(PersistenceValidationResult other) {
    return PersistenceValidationResult(
      isValid: isValid && other.isValid,
      errors: [...errors, ...other.errors],
      warnings: [...warnings, ...other.warnings],
    );
  }
}

/// Repository 层落库闸门
/// 即使绕过 tool gate，仍有最后一道校验
class WriterPersistenceGuard {
  const WriterPersistenceGuard();

  /// 校验章节内容
  PersistenceValidationResult validateChapterContent(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      errors.add('章节内容为空，不允许落库。');
      return PersistenceValidationResult(isValid: false, errors: errors);
    }

    if (trimmed.contains('TODO') || trimmed.contains('待补充') || trimmed.contains('待填写')) {
      errors.add('章节内容包含未完成占位符，不允许落库。');
    }

    if (trimmed.length < 80) {
      errors.add('章节正文过短（${trimmed.length} 字），低于最低要求 80 字。');
    } else if (trimmed.length < 200) {
      warnings.add('章节正文偏短（${trimmed.length} 字），建议扩展到 200 字以上。');
    }

    if (trimmed.endsWith('……')) {
      warnings.add('章节以省略号结尾，可能未写完。');
    }

    return PersistenceValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// 校验实体简介（角色/地点/物品/势力/作品）
  PersistenceValidationResult validateEntityBio(
    String bio,
    String entityType,
  ) {
    final errors = <String>[];
    final warnings = <String>[];
    final trimmed = bio.trim();

    if (trimmed.isEmpty) {
      // bio 允许为空（不是必填字段）
      return const PersistenceValidationResult(isValid: true);
    }

    const placeholders = ['暂无', '无', '未知', '待定', '—'];
    if (placeholders.contains(trimmed)) {
      errors.add('$entityType 简介为占位内容（"$trimmed"），不允许落库。');
    }

    if (trimmed.contains('TODO') || trimmed.contains('待补充')) {
      errors.add('$entityType 简介包含占位内容，不允许落库。');
    }

    if (trimmed.length < 10) {
      errors.add('$entityType 简介过短（${trimmed.length} 字），缺少有效描述。');
    } else if (trimmed.length < 30) {
      warnings.add('$entityType 简介偏短，建议补充更多细节。');
    }

    return PersistenceValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// 校验世界观设定
  PersistenceValidationResult validateWorldbuilding(String content) {
    final errors = <String>[];
    final warnings = <String>[];
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      errors.add('世界观设定内容为空，不允许落库。');
      return PersistenceValidationResult(isValid: false, errors: errors);
    }

    if (trimmed.length < 50) {
      errors.add('世界观设定过短（${trimmed.length} 字），缺少具体内容。');
    } else if (trimmed.length < 150) {
      warnings.add('世界观设定偏短，建议补充核心设定、力量体系等。');
    }

    return PersistenceValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// 校验通用内容（素材、片段等）
  PersistenceValidationResult validateGenericContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const PersistenceValidationResult(
        isValid: false,
        errors: ['内容为空，不允许落库。'],
      );
    }
    if (trimmed.contains('TODO') || trimmed.contains('待补充')) {
      return const PersistenceValidationResult(
        isValid: false,
        errors: ['内容包含未完成占位符，不允许落库。'],
      );
    }
    return const PersistenceValidationResult(isValid: true);
  }

  /// 根据规则类型自动选择校验方法
  PersistenceValidationResult validate(
    String content,
    HookRuleType ruleType, {
    String entityType = '实体',
  }) {
    return switch (ruleType) {
      HookRuleType.chapterBody => validateChapterContent(content),
      HookRuleType.entityBio => validateEntityBio(content, entityType),
      HookRuleType.worldbuilding => validateWorldbuilding(content),
      _ => validateGenericContent(content),
    };
  }
}
