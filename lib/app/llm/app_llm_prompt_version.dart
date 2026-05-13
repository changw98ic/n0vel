/// Prompt 模板版本标识。
///
/// 每个 prompt 模板都应标注版本号，用于追踪和回放。
/// 版本号遵循语义化版本规范（semver），便于比较和排序。
class PromptVersion {
  const PromptVersion({
    required this.templateId,
    required this.version,
    this.description,
  });

  /// 模板唯一标识（如 'scene_editorial', 'scene_review', 'scene_director'）。
  final String templateId;

  /// 语义化版本号（如 '1.0.0'）。
  final String version;

  /// 变更描述。
  final String? description;

  /// 解析版本号为可比较的整数元组 (major, minor, patch)。
  ///
  /// 如果版本号格式非法，返回 (0, 0, 0)。
  ({int major, int minor, int patch}) get parsed {
    final parts = version.split('.');
    if (parts.length != 3) return (major: 0, minor: 0, patch: 0);
    return (
      major: int.tryParse(parts[0]) ?? 0,
      minor: int.tryParse(parts[1]) ?? 0,
      patch: int.tryParse(parts[2]) ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'templateId': templateId,
      'version': version,
      if (description != null) 'description': description,
    };
  }

  factory PromptVersion.fromJson(Map<String, Object?> json) {
    return PromptVersion(
      templateId: json['templateId'] as String,
      version: json['version'] as String,
      description: json['description'] as String?,
    );
  }

  @override
  String toString() => 'PromptVersion($templateId@$version)';

  @override
  bool operator ==(Object other) {
    if (other is! PromptVersion) return false;
    return templateId == other.templateId && version == other.version;
  }

  @override
  int get hashCode => Object.hash(templateId, version);
}
