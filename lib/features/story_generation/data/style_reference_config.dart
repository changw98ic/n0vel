import 'dart:io';

import '../domain/source_ledger_models.dart';
import 'source_admission_resolver.dart';

class StyleReferenceConfig {
  const StyleReferenceConfig._({
    required this.enabled,
    this.intensity = 0,
    this.rootPath = '',
    this.promptSafeSummary = '',
    this.allowWritingReferenceRetrieval = false,
    this.approvedBundle,
    this.profileJson = const <String, Object?>{},
  });

  const StyleReferenceConfig.defaultEnabled()
    : enabled = false,
      intensity = 0,
      rootPath = '',
      promptSafeSummary = '',
      allowWritingReferenceRetrieval = false,
      approvedBundle = null,
      profileJson = const <String, Object?>{};

  const StyleReferenceConfig.disabled()
    : enabled = false,
      intensity = 0,
      rootPath = '',
      promptSafeSummary = '',
      allowWritingReferenceRetrieval = false,
      approvedBundle = null,
      profileJson = const <String, Object?>{};

  factory StyleReferenceConfig.fromProfile({
    required int intensity,
    String profileId = '',
    String profileName = '',
    String profileSource = '',
    Map<String, Object?> profileJson = const <String, Object?>{},
  }) {
    if (intensity <= 0) return const StyleReferenceConfig.disabled();
    final rootPath = _resolveInternalRootPath(
      profileId: profileId,
      profileName: profileName,
      profileSource: profileSource,
      profileJson: profileJson,
    );
    if (rootPath.isEmpty) return const StyleReferenceConfig.disabled();

    final requestedUsage = _referenceUsageFromProfile(profileJson);
    final rawIntent = _rawIntentFromProfile(profileJson);
    final abstractFeatures = _abstractFeaturesFromProfile(profileJson);
    final contributionShares = _contributionSharesFromProfile(profileJson);
    final centralResolver = SourceAdmissionResolver.fromDefaultManifest();
    var bundle = centralResolver.resolveRoot(
      rootPath: rootPath,
      requestedUsage: requestedUsage,
      rawIntent: rawIntent,
      abstractFeatures: abstractFeatures,
      contributionShares: contributionShares,
    );
    // A repository-level determination is authoritative. A colocated ledger
    // may describe a root that is absent from the central inventory, but it
    // cannot override an explicit central denial such as `unknown`.
    if (!bundle.allowed &&
        bundle.denialReasonCode == SourceAdmissionReasonCode.unknownSource) {
      final manifestFile = File('$rootPath/source_manifest.json');
      if (_safeFileExists(manifestFile)) {
        bundle = SourceAdmissionResolver.fromManifestFile(manifestFile)
            .resolveRoot(
              rootPath: rootPath,
              requestedUsage: requestedUsage,
              rawIntent: rawIntent,
              abstractFeatures: abstractFeatures,
              contributionShares: contributionShares,
            );
      }
    }
    if (!bundle.allowed) return const StyleReferenceConfig.disabled();
    if (bundle.referenceUsage == ReferenceUsage.localAnalysisOnly) {
      return const StyleReferenceConfig.disabled();
    }

    final promptSafeSummary = _promptSummaryFromBundle(
      bundle: bundle,
      intensity: intensity,
    );
    return StyleReferenceConfig._(
      enabled: true,
      intensity: intensity,
      rootPath: bundle.runtimeRootPath ?? rootPath,
      promptSafeSummary: promptSafeSummary,
      allowWritingReferenceRetrieval: _allowsRetrieval(bundle.referenceUsage),
      approvedBundle: bundle,
      profileJson: Map<String, Object?>.unmodifiable(bundle.abstractFeatures),
    );
  }

  static const String defaultRootPath = '';

  final bool enabled;
  final int intensity;
  final String rootPath;
  final String promptSafeSummary;
  final bool allowWritingReferenceRetrieval;
  final ApprovedStyleReferenceBundle? approvedBundle;
  final Map<String, Object?> profileJson;

  String get referenceLabel => '';

  String get promptSummary {
    final bundle = approvedBundle;
    if (!enabled ||
        bundle == null ||
        !bundle.allowed ||
        bundle.referenceUsage == ReferenceUsage.localAnalysisOnly) {
      return '';
    }
    return promptSafeSummary.trim();
  }

  static bool _allowsRetrieval(ReferenceUsage usage) =>
      usage == ReferenceUsage.licensedExcerpts ||
      usage == ReferenceUsage.userOwnedFullContext;

  static String _promptSummaryFromBundle({
    required ApprovedStyleReferenceBundle bundle,
    required int intensity,
  }) {
    final features = bundle.abstractFeatures.entries
        .where((entry) => entry.key.trim().isNotEmpty)
        .where((entry) => entry.value.trim().isNotEmpty)
        .map((entry) => '${_featureLabel(entry.key)}：${entry.value.trim()}')
        .toList(growable: false);
    if (features.isEmpty) return '';
    return [
      '参考使用：${bundle.referenceUsage.name}',
      '强度：$intensity',
      ...features,
    ].join('；');
  }

  static String _featureLabel(String key) => switch (key) {
    'genre_tags' => '类型',
    'pov_mode' => '视角',
    'narrative_distance' => '叙述距离',
    'rhythm_profile' => '节奏',
    'sentence_length_preference' => '句长',
    'dialogue_ratio' => '对白占比',
    'description_density' => '描写密度',
    'emotional_intensity' => '情绪强度',
    'tone_keywords' => '语气关键词',
    'taboo_patterns' => '避免',
    'information_release' => '信息释放',
    'syntax_density' => '句法密度',
    'rhetorical_domain' => '修辞域',
    'character_voice' => '人物声纹',
    _ => key,
  };

  static ReferenceUsage _referenceUsageFromProfile(
    Map<String, Object?> profileJson,
  ) {
    final raw = _firstString(profileJson, const <String>[
      'reference_usage',
      'referenceUsage',
    ]);
    if (raw.isEmpty) return ReferenceUsage.abstractFeaturesOnly;
    for (final usage in ReferenceUsage.values) {
      if (usage.name == raw) return usage;
    }
    return ReferenceUsage.off;
  }

  static Map<String, String> _abstractFeaturesFromProfile(
    Map<String, Object?> profileJson,
  ) {
    const allowedKeys = <String>{
      'genre_tags',
      'pov_mode',
      'narrative_distance',
      'rhythm_profile',
      'sentence_length_preference',
      'dialogue_ratio',
      'description_density',
      'emotional_intensity',
      'tone_keywords',
      'taboo_patterns',
      'information_release',
      'syntax_density',
      'rhetorical_domain',
      'character_voice',
    };
    final features = <String, String>{};
    for (final key in allowedKeys) {
      final value = _featureValue(profileJson[key]);
      if (value.isNotEmpty) features[key] = value;
    }
    return Map<String, String>.unmodifiable(features);
  }

  static Map<String, double>? _contributionSharesFromProfile(
    Map<String, Object?> profileJson,
  ) {
    final raw =
        profileJson['source_contribution_shares'] ??
        profileJson['sourceContributionShares'];
    if (raw is! Map) return null;
    final shares = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString().trim() ?? '';
      final value = entry.value;
      if (key.isEmpty || value is! num || !value.isFinite) return null;
      shares[key] = value.toDouble();
    }
    return Map<String, double>.unmodifiable(shares);
  }

  static String _featureValue(Object? raw) {
    if (raw is List) {
      return raw
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .join('、');
    }
    return raw?.toString().trim() ?? '';
  }

  static String? _rawIntentFromProfile(Map<String, Object?> profileJson) {
    final parts = <String>[
      _firstString(profileJson, const <String>['notes']),
      _firstString(profileJson, const <String>['free_prompt']),
      _firstString(profileJson, const <String>['freePrompt']),
      _firstString(profileJson, const <String>['prompt_notes']),
      _firstString(profileJson, const <String>['promptNotes']),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  static String _resolveInternalRootPath({
    required String profileId,
    required String profileName,
    required String profileSource,
    required Map<String, Object?> profileJson,
  }) {
    final explicitRoot = _firstString(profileJson, const <String>[
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
      return 'artifacts/writing_reference/jianlai';
    }
    return '';
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

  static String _firstString(Map<String, Object?> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static bool _safeFileExists(File file) {
    try {
      return file.existsSync();
    } on FileSystemException {
      return false;
    } on UnsupportedError {
      return false;
    }
  }
}
