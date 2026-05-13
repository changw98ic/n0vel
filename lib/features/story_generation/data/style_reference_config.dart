class StyleReferenceConfig {
  const StyleReferenceConfig({
    required this.enabled,
    this.profileId = '',
    this.profileName = '',
    this.profileSource = '',
    this.intensity = 0,
    this.rootPath = defaultRootPath,
    this.profileJson = const <String, Object?>{},
  });

  const StyleReferenceConfig.defaultEnabled()
    : enabled = true,
      profileId = '',
      profileName = '剑来参考',
      profileSource = 'default',
      intensity = 1,
      rootPath = defaultRootPath,
      profileJson = const <String, Object?>{};

  factory StyleReferenceConfig.fromProfile({
    required int intensity,
    String profileId = '',
    String profileName = '',
    String profileSource = '',
    Map<String, Object?> profileJson = const <String, Object?>{},
  }) {
    if (intensity <= 0 || profileName.trim().isEmpty) {
      return const StyleReferenceConfig(enabled: false);
    }
    return StyleReferenceConfig(
      enabled: true,
      profileId: profileId,
      profileName: profileName,
      profileSource: profileSource,
      intensity: intensity,
      rootPath: _resolveRootPath(
        profileId: profileId,
        profileName: profileName,
        profileSource: profileSource,
        profileJson: profileJson,
      ),
      profileJson: Map<String, Object?>.unmodifiable(profileJson),
    );
  }

  static const String defaultRootPath = 'artifacts/writing_reference/jianlai';

  final bool enabled;
  final String profileId;
  final String profileName;
  final String profileSource;
  final int intensity;
  final String rootPath;
  final Map<String, Object?> profileJson;

  String get referenceLabel {
    final normalized = rootPath.toLowerCase();
    if (normalized.contains('tigui')) return '体鬼';
    if (normalized.contains('guimi')) return '诡秘';
    if (normalized.contains('jianlai')) return '剑来';
    return rootPath;
  }

  String get promptSummary {
    if (!enabled) return '';
    if (profileSource == 'default' && profileId.isEmpty) return '';
    final parts = <String>[
      '启用动态风格：$profileName',
      '强度：$intensity',
      '写作参考库：$referenceLabel',
      ..._profileDirectives(profileJson),
    ];
    return parts.where((part) => part.trim().isNotEmpty).join('；');
  }

  static List<String> _profileDirectives(Map<String, Object?> json) {
    final directives = <String>[];
    void addScalar(String key, String label) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) directives.add('$label：$value');
    }

    void addList(String key, String label) {
      final values = _stringList(json[key]);
      if (values.isNotEmpty) directives.add('$label：${values.join('、')}');
    }

    addList('genre_tags', '类型');
    addScalar('pov_mode', '视角');
    addScalar('narrative_distance', '叙述距离');
    addScalar('rhythm_profile', '节奏');
    addScalar('sentence_length_preference', '句长');
    addScalar('dialogue_ratio', '对白占比');
    addScalar('description_density', '描写密度');
    addScalar('emotional_intensity', '情绪强度');
    addList('tone_keywords', '语气关键词');
    addList('taboo_patterns', '避免');
    addScalar('notes', '补充要求');
    return directives;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return raw
          .split(RegExp(r'[,，;；|/]+'))
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static String _resolveRootPath({
    required String profileId,
    required String profileName,
    required String profileSource,
    required Map<String, Object?> profileJson,
  }) {
    final explicitRoot = _firstString(profileJson, const [
      'writing_reference_root',
      'writingReferenceRoot',
      'rag_root',
      'ragRoot',
      'reference_root',
      'referenceRoot',
    ]);
    if (explicitRoot.isNotEmpty) return explicitRoot;

    final haystack = [
      profileId,
      profileName,
      profileSource,
      profileJson['name']?.toString() ?? '',
      ..._stringList(profileJson['genre_tags']),
      ..._stringList(profileJson['tone_keywords']),
    ].join(' ').toLowerCase();

    if (haystack.contains('体鬼') || haystack.contains('tigui')) {
      return 'artifacts/writing_reference/tigui';
    }
    if (haystack.contains('诡秘') ||
        haystack.contains('guimi') ||
        haystack.contains('lord of mysteries')) {
      return 'artifacts/writing_reference/guimi';
    }
    if (haystack.contains('剑来') || haystack.contains('jianlai')) {
      return defaultRootPath;
    }
    return defaultRootPath;
  }

  static String _firstString(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
