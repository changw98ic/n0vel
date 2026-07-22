import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/features/story_generation/data/imitation_intent_linter.dart';
import 'package:novel_writer/features/story_generation/domain/source_ledger_models.dart';

class SourceAdmissionResolver {
  SourceAdmissionResolver._({
    required this.manifest,
    required this.processingManifestOnly,
    this.loadError,
    this.defaultRootPath,
  });

  factory SourceAdmissionResolver.empty() =>
      SourceAdmissionResolver._(manifest: null, processingManifestOnly: false);

  factory SourceAdmissionResolver.fromManifestFile(File file) {
    if (file.uri.pathSegments.last != 'source_manifest.json') {
      return SourceAdmissionResolver._(
        manifest: null,
        processingManifestOnly: file.uri.pathSegments.last == 'manifest.json',
      );
    }
    final parentPath = file.parent.path;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        throw const FormatException('source manifest must be an object');
      }
      final manifest = SourceLedgerManifest.fromJson(
        decoded.map((key, value) {
          if (key is! String) {
            throw const FormatException('manifest key invalid');
          }
          return MapEntry(key, value);
        }),
      );
      return SourceAdmissionResolver._(
        manifest: manifest,
        processingManifestOnly: false,
        defaultRootPath: parentPath,
      );
    } on FormatException catch (error) {
      return SourceAdmissionResolver._(
        manifest: null,
        processingManifestOnly: false,
        loadError: error,
        defaultRootPath: parentPath,
      );
    } on FileSystemException catch (error) {
      return SourceAdmissionResolver._(
        manifest: null,
        processingManifestOnly: false,
        loadError: FormatException(error.message),
        defaultRootPath: parentPath,
      );
    } on UnsupportedError catch (error) {
      // `dart:io` is unavailable on web. The synchronous adapter must fail
      // closed instead of crashing workspace/profile loading.
      return SourceAdmissionResolver._(
        manifest: null,
        processingManifestOnly: false,
        loadError: FormatException(error.message ?? 'filesystem unavailable'),
        defaultRootPath: parentPath,
      );
    }
  }

  factory SourceAdmissionResolver.fromDefaultManifest({
    String manifestPath = 'assets/novels/source_manifest.json',
  }) => SourceAdmissionResolver.fromManifestFile(File(manifestPath));

  final SourceLedgerManifest? manifest;
  final bool processingManifestOnly;
  final FormatException? loadError;
  final String? defaultRootPath;

  ApprovedStyleReferenceBundle resolveRoot({
    required String rootPath,
    required ReferenceUsage requestedUsage,
    String? rawIntent,
    Map<String, String> abstractFeatures = const <String, String>{},
    Map<String, double>? contributionShares,
  }) {
    if (processingManifestOnly) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.processingManifestOnly,
      );
    }
    final loadedManifest = manifest;
    if (loadError != null) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.manifestInvalid,
      );
    }
    if (loadedManifest == null) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.unknownSource,
      );
    }

    final rootResolution = _resolveRootBinding(loadedManifest, rootPath);
    if (rootResolution.entries.isEmpty) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.unknownSource,
      );
    }
    final entries = rootResolution.entries;
    if (entries.any(
      (entry) => entry.licenseStatus == SourceLicenseStatus.unknown,
    )) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.licenseStatusUnknown,
      );
    }

    final requiredUse = _requiredUseFor(requestedUsage);
    if (requiredUse == null) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    }
    final allAllowed = entries.every(
      (entry) => _entryAllowsUsage(entry, requestedUsage, requiredUse),
    );
    if (!allAllowed) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    }
    if (requestedUsage == ReferenceUsage.userOwnedFullContext &&
        entries.any((entry) => !entry.isUserOwned)) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    }
    if (requestedUsage == ReferenceUsage.licensedExcerpts &&
        entries.any(
          (entry) =>
              entry.excerptLimitChars == null || entry.excerptLimitChars! <= 0,
        )) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    }
    if (abstractFeatures.isNotEmpty &&
        entries.any(
          (entry) => !entry.allows(AllowedSourceUse.abstractFeatures),
        )) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.usageNotAllowed,
      );
    }
    final linter = ImitationIntentLinter(
      protectedCreatorTokens: entries
          .map((entry) => entry.creator)
          .whereType<String>(),
      protectedTitleTokens: entries.map((entry) => entry.title),
    );
    final ownership = entries.every((entry) => entry.isUserOwned)
        ? ImitationSourceOwnership.userOwned
        : ImitationSourceOwnership.thirdParty;
    if (rawIntent != null && rawIntent.trim().isNotEmpty) {
      final intent = linter.lintStructured(
        StructuredImitationIntentInput(
          text: rawIntent,
          creatorTokens: entries
              .map((entry) => entry.creator)
              .whereType<String>(),
          titleTokens: entries.map((entry) => entry.title),
          ownership: ownership,
          userOwnsVoice: entries.every((entry) => entry.isUserOwned),
        ),
      );
      if (!intent.canRender) {
        return ApprovedStyleReferenceBundle.denied(
          SourceAdmissionReasonCode.unsafeImitationIntent,
        );
      }
    }
    final safeAbstractFeatures = _sanitizeAbstractFeatures(
      abstractFeatures,
      linter: linter,
      ownership: ownership,
      userOwnsVoice: entries.every((entry) => entry.isUserOwned),
    );
    if (safeAbstractFeatures == null) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.unsafeImitationIntent,
      );
    }
    final shares = contributionShares ?? rootResolution.contributionShares;
    if (requestedUsage == ReferenceUsage.abstractFeaturesOnly &&
        safeAbstractFeatures.isNotEmpty &&
        entries.any((entry) => !entry.isUserOwned)) {
      if (shares == null || shares.isEmpty) {
        return ApprovedStyleReferenceBundle.denied(
          SourceAdmissionReasonCode.dominantThirdPartySource,
        );
      }
      final dominance = const SourceDominancePolicy().evaluate(
        shares,
        sources: entries,
      );
      if (dominance.decision != SourceDominanceDecision.allow) {
        return ApprovedStyleReferenceBundle.denied(dominance.reasonCode);
      }
    }

    return ApprovedStyleReferenceBundle(
      allowed: true,
      referenceUsage: requestedUsage,
      sources: entries,
      denialReasonCode: SourceAdmissionReasonCode.allowed,
      abstractFeatures: safeAbstractFeatures,
      runtimeRootPath: rootPath,
      maxDominantSourceShare:
          requestedUsage == ReferenceUsage.userOwnedFullContext ? 1.0 : 0.40,
    );
  }

  _RootResolution _resolveRootBinding(
    SourceLedgerManifest manifest,
    String rootPath,
  ) {
    final byId = manifest.entriesById;
    final normalizedRoot = _normalizePath(rootPath);
    if (manifest.rootBindings.isEmpty) {
      if (defaultRootPath != null &&
          _samePath(defaultRootPath!, normalizedRoot)) {
        return _RootResolution(entries: manifest.entries);
      }
      return const _RootResolution(entries: <SourceLedgerEntry>[]);
    }
    for (final binding in manifest.rootBindings) {
      if (_samePath(binding.rootPath, normalizedRoot)) {
        return _RootResolution(
          entries: binding.sourceIds
              .map((id) => byId[id])
              .whereType<SourceLedgerEntry>()
              .toList(growable: false),
          contributionShares: binding.contributionShares.isEmpty
              ? null
              : binding.contributionShares,
        );
      }
    }
    return const _RootResolution(entries: <SourceLedgerEntry>[]);
  }
}

class _RootResolution {
  const _RootResolution({required this.entries, this.contributionShares});

  final List<SourceLedgerEntry> entries;
  final Map<String, double>? contributionShares;
}

class SourceDominancePolicy {
  const SourceDominancePolicy({this.maxThirdPartyShare = 0.40})
    : assert(maxThirdPartyShare >= 0 && maxThirdPartyShare <= 1);

  final double maxThirdPartyShare;

  SourceDominancePolicyResult evaluate(
    Map<String, double> sourceShareById, {
    required Iterable<SourceLedgerEntry> sources,
  }) {
    final byId = <String, SourceLedgerEntry>{
      for (final source in sources) source.sourceId: source,
    };
    if (sourceShareById.keys.length != byId.keys.length ||
        !sourceShareById.keys.every(byId.containsKey) ||
        !byId.keys.every(sourceShareById.containsKey)) {
      return const SourceDominancePolicyResult(
        decision: SourceDominanceDecision.manualReview,
        reasonCode: SourceAdmissionReasonCode.dominantThirdPartySource,
      );
    }
    final sum = sourceShareById.values.fold<double>(
      0,
      (total, share) => total + share,
    );
    if ((sum - 1.0).abs() > 0.001) {
      return const SourceDominancePolicyResult(
        decision: SourceDominanceDecision.manualReview,
        reasonCode: SourceAdmissionReasonCode.dominantThirdPartySource,
      );
    }
    for (final entry in sourceShareById.entries) {
      final source = byId[entry.key];
      if (source == null ||
          !entry.value.isFinite ||
          entry.value < 0 ||
          entry.value > 1) {
        return const SourceDominancePolicyResult(
          decision: SourceDominanceDecision.manualReview,
          reasonCode: SourceAdmissionReasonCode.dominantThirdPartySource,
        );
      }
      if (source.isUserOwned) continue;
      if (entry.value > maxThirdPartyShare) {
        return const SourceDominancePolicyResult(
          decision: SourceDominanceDecision.manualReview,
          reasonCode: SourceAdmissionReasonCode.dominantThirdPartySource,
        );
      }
    }
    return const SourceDominancePolicyResult(
      decision: SourceDominanceDecision.allow,
      reasonCode: SourceAdmissionReasonCode.allowed,
    );
  }
}

enum SourceDominanceDecision { allow, manualReview }

class SourceDominancePolicyResult {
  const SourceDominancePolicyResult({
    required this.decision,
    required this.reasonCode,
  });

  final SourceDominanceDecision decision;
  final SourceAdmissionReasonCode reasonCode;
}

AllowedSourceUse? _requiredUseFor(ReferenceUsage usage) {
  switch (usage) {
    case ReferenceUsage.off:
      return null;
    case ReferenceUsage.abstractFeaturesOnly:
      return AllowedSourceUse.abstractFeatures;
    case ReferenceUsage.licensedExcerpts:
      return AllowedSourceUse.shortExcerpt;
    case ReferenceUsage.userOwnedFullContext:
      return AllowedSourceUse.fullContext;
    case ReferenceUsage.localAnalysisOnly:
      return AllowedSourceUse.localRiskScan;
  }
}

bool _entryAllowsUsage(
  SourceLedgerEntry entry,
  ReferenceUsage usage,
  AllowedSourceUse requiredUse,
) {
  if (entry.licenseStatus == SourceLicenseStatus.unknown) return false;
  if (entry.licenseStatus == SourceLicenseStatus.restricted &&
      usage != ReferenceUsage.abstractFeaturesOnly &&
      usage != ReferenceUsage.localAnalysisOnly) {
    return false;
  }
  if (entry.allowedUses.contains(requiredUse)) return true;
  return false;
}

bool _samePath(String left, String right) {
  final normalizedLeft = _normalizePath(left);
  final normalizedRight = _normalizePath(right);
  return normalizedLeft == normalizedRight;
}

String _normalizePath(String path) {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return trimmed;
  return Directory(trimmed).absolute.uri.normalizePath().toFilePath();
}

Map<String, String>? _sanitizeAbstractFeatures(
  Map<String, String> features, {
  required ImitationIntentLinter linter,
  required ImitationSourceOwnership ownership,
  required bool userOwnsVoice,
}) {
  if (features.isEmpty) return const <String, String>{};
  final allowed = <String, String>{};
  for (final entry in features.entries) {
    final key = entry.key.trim();
    final value = entry.value.trim();
    if (!_isAllowedAbstractFeatureKey(key) || value.isEmpty) continue;
    final result = linter.lintStructured(
      StructuredImitationIntentInput(
        text: value,
        ownership: ownership,
        userOwnsVoice: userOwnsVoice,
      ),
    );
    if (result.disposition == ImitationIntentDisposition.rejected ||
        result.disposition == ImitationIntentDisposition.manualReview) {
      return null;
    }
    if (result.disposition == ImitationIntentDisposition.allowed &&
        result.canRender) {
      allowed[key] = result.sanitizedText;
    }
  }
  return Map<String, String>.unmodifiable(allowed);
}

bool _isAllowedAbstractFeatureKey(String key) {
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
  return allowedKeys.contains(key);
}
