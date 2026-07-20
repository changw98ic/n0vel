import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';

enum SourceLicenseStatus {
  publicDomain,
  userOwned,
  licensed,
  restricted,
  unknown,
}

enum AllowedSourceUse {
  abstractFeatures,
  shortExcerpt,
  fullContext,
  calibration,
  localRiskScan,
  training,
}

enum ReferenceUsage {
  off,
  abstractFeaturesOnly,
  licensedExcerpts,
  userOwnedFullContext,
  localAnalysisOnly,
}

enum SourceAdmissionReasonCode {
  allowed,
  unknownSource,
  processingManifestOnly,
  manifestInvalid,
  usageNotAllowed,
  licenseStatusUnknown,
  dominantThirdPartySource,
  unsafeImitationIntent,
}

class SourceLedgerEntry {
  SourceLedgerEntry({
    required this.sourceId,
    required this.title,
    this.creator,
    required this.licenseStatus,
    required Iterable<AllowedSourceUse> allowedUses,
    required this.provenanceUri,
    required this.provenanceHash,
    required this.jurisdiction,
    required this.determinationDateMs,
    this.excerptLimitChars,
    required this.attributionRequired,
    required this.reviewedBy,
    required this.reviewedAtMs,
  }) : allowedUses = Set<AllowedSourceUse>.unmodifiable(allowedUses) {
    _requireNonEmpty(sourceId, 'sourceId');
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{1,127}$').hasMatch(sourceId)) {
      throw const FormatException('sourceId has an invalid wire format');
    }
    _requireNonEmpty(title, 'title');
    _requireNonEmpty(provenanceUri, 'provenanceUri');
    _requireSafeManifestPath(provenanceUri, 'provenanceUri');
    _requireNonEmpty(provenanceHash, 'provenanceHash');
    if (!RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(provenanceHash)) {
      throw const FormatException(
        'provenanceHash must be sha256:<64 lower hex>',
      );
    }
    _requireNonEmpty(jurisdiction, 'jurisdiction');
    _requireNonEmpty(reviewedBy, 'reviewedBy');
    if (determinationDateMs < 0) {
      throw const FormatException('determinationDateMs must be non-negative');
    }
    if (reviewedAtMs < 0) {
      throw const FormatException('reviewedAtMs must be non-negative');
    }
    if (excerptLimitChars != null && excerptLimitChars! < 0) {
      throw const FormatException('excerptLimitChars must be non-negative');
    }
    if (this.allowedUses.contains(AllowedSourceUse.shortExcerpt) &&
        (excerptLimitChars == null || excerptLimitChars! <= 0)) {
      throw const FormatException(
        'shortExcerpt requires a positive excerptLimitChars',
      );
    }
    if (licenseStatus == SourceLicenseStatus.restricted) {
      const restrictedUses = <AllowedSourceUse>{
        AllowedSourceUse.abstractFeatures,
        AllowedSourceUse.localRiskScan,
      };
      if (this.allowedUses.any((use) => !restrictedUses.contains(use)) ||
          excerptLimitChars != null) {
        throw const FormatException(
          'restricted sources may only allow abstract features or local scans',
        );
      }
    }
    if (licenseStatus == SourceLicenseStatus.unknown) {
      if (this.allowedUses.isNotEmpty) {
        throw const FormatException(
          'unknown sources cannot allow generation uses',
        );
      }
      if (excerptLimitChars != null) {
        throw const FormatException('unknown sources cannot expose excerpts');
      }
    }
  }

  factory SourceLedgerEntry.fromJson(Map<String, Object?> json) {
    _rejectUnknownKeys(json, 'source ledger entry', const <String>{
      'sourceId',
      'title',
      'creator',
      'licenseStatus',
      'allowedUses',
      'provenanceUri',
      'provenanceHash',
      'jurisdiction',
      'determinationDateMs',
      'excerptLimitChars',
      'attributionRequired',
      'reviewedBy',
      'reviewedAtMs',
    });
    return SourceLedgerEntry(
      sourceId: _readString(json, 'sourceId'),
      title: _readString(json, 'title'),
      creator: _readNullableString(json, 'creator'),
      licenseStatus: _parseEnum(
        _readString(json, 'licenseStatus'),
        SourceLicenseStatus.values,
        'licenseStatus',
      ),
      allowedUses: _readStringList(json, 'allowedUses').map(
        (value) => _parseEnum(value, AllowedSourceUse.values, 'allowedUses'),
      ),
      provenanceUri: _readString(json, 'provenanceUri'),
      provenanceHash: _readString(json, 'provenanceHash'),
      jurisdiction: _readString(json, 'jurisdiction'),
      determinationDateMs: _readInt(json, 'determinationDateMs'),
      excerptLimitChars: _readNullableInt(json, 'excerptLimitChars'),
      attributionRequired: _readBool(json, 'attributionRequired'),
      reviewedBy: _readString(json, 'reviewedBy'),
      reviewedAtMs: _readInt(json, 'reviewedAtMs'),
    );
  }

  final String sourceId;
  final String title;
  final String? creator;
  final SourceLicenseStatus licenseStatus;
  final Set<AllowedSourceUse> allowedUses;
  final String provenanceUri;
  final String provenanceHash;
  final String jurisdiction;
  final int determinationDateMs;
  final int? excerptLimitChars;
  final bool attributionRequired;
  final String reviewedBy;
  final int reviewedAtMs;

  bool get isUserOwned => licenseStatus == SourceLicenseStatus.userOwned;

  bool allows(AllowedSourceUse use) => allowedUses.contains(use);

  Map<String, Object?> toJson() => <String, Object?>{
    'sourceId': sourceId,
    'title': title,
    if (creator != null) 'creator': creator,
    'licenseStatus': licenseStatus.name,
    'allowedUses': _sortedEnumNames(allowedUses),
    'provenanceUri': provenanceUri,
    'provenanceHash': provenanceHash,
    'jurisdiction': jurisdiction,
    'determinationDateMs': determinationDateMs,
    if (excerptLimitChars != null) 'excerptLimitChars': excerptLimitChars,
    'attributionRequired': attributionRequired,
    'reviewedBy': reviewedBy,
    'reviewedAtMs': reviewedAtMs,
  };

  /// Public audit identity JSON. It deliberately excludes title, creator,
  /// root/path labels, provenance URI, and reviewer names. Prompt callers must
  /// use [ApprovedStyleReferenceBundle.toPromptSafeJson] instead.
  Map<String, Object?> toCanonicalJson() => _sortedMap(<String, Object?>{
    'allowedUses': _sortedEnumNames(allowedUses),
    'attributionRequired': attributionRequired,
    'determinationDateMs': determinationDateMs,
    if (excerptLimitChars != null) 'excerptLimitChars': excerptLimitChars,
    'jurisdiction': jurisdiction,
    'licenseStatus': licenseStatus.name,
    'provenanceHash': provenanceHash,
    'reviewedAtMs': reviewedAtMs,
    'sourceId': sourceId,
  });

  String get canonicalHash => AppLlmCanonicalHash.domainHash(
    'source-ledger-entry-v1',
    _sortedMap(<String, Object?>{
      'allowedUses': _sortedEnumNames(allowedUses),
      'attributionRequired': attributionRequired,
      if (creator != null) 'creator': creator,
      'determinationDateMs': determinationDateMs,
      if (excerptLimitChars != null) 'excerptLimitChars': excerptLimitChars,
      'jurisdiction': jurisdiction,
      'licenseStatus': licenseStatus.name,
      'provenanceHash': provenanceHash,
      'provenanceUri': provenanceUri,
      'reviewedAtMs': reviewedAtMs,
      'reviewedBy': reviewedBy,
      'sourceId': sourceId,
      'title': title,
    }),
  );
}

class SourceRootBinding {
  SourceRootBinding({
    required this.rootPath,
    required Iterable<String> sourceIds,
    Map<String, double> contributionShares = const <String, double>{},
  }) : sourceIds = List<String>.unmodifiable(sourceIds),
       contributionShares = Map<String, double>.unmodifiable(
         contributionShares,
       ) {
    _requireNonEmpty(rootPath, 'rootPath');
    _requireSafeManifestPath(rootPath, 'rootPath');
    if (sourceIds.isEmpty) {
      throw const FormatException('root binding sourceIds must be non-empty');
    }
  }

  factory SourceRootBinding.fromJson(Map<String, Object?> json) {
    _rejectUnknownKeys(json, 'source root binding', const <String>{
      'rootPath',
      'sourceIds',
      'contributionShares',
    });
    return SourceRootBinding(
      rootPath: _readString(json, 'rootPath'),
      sourceIds: _readStringList(json, 'sourceIds'),
      contributionShares: _readNullableDoubleMap(json, 'contributionShares'),
    );
  }

  final String rootPath;
  final List<String> sourceIds;
  final Map<String, double> contributionShares;

  Map<String, Object?> toJson() => <String, Object?>{
    'rootPath': rootPath,
    'sourceIds': List<String>.unmodifiable(sourceIds),
    if (contributionShares.isNotEmpty) 'contributionShares': contributionShares,
  };
}

class SourceLedgerManifest {
  SourceLedgerManifest({
    required this.schemaVersion,
    required this.generatedAtMs,
    required Iterable<SourceLedgerEntry> entries,
    Iterable<SourceRootBinding> rootBindings = const <SourceRootBinding>[],
  }) : entries = List<SourceLedgerEntry>.unmodifiable(entries),
       rootBindings = List<SourceRootBinding>.unmodifiable(rootBindings) {
    if (this.entries.isEmpty) {
      throw const FormatException('source manifest must contain entries');
    }
    if (generatedAtMs < 0) throw const FormatException('generatedAtMs invalid');
  }

  factory SourceLedgerManifest.fromJson(Map<String, Object?> json) {
    _rejectUnknownKeys(json, 'source ledger manifest', const <String>{
      'schemaVersion',
      'generatedAtMs',
      'entries',
      'rootBindings',
    });
    final schemaVersion = _readString(json, 'schemaVersion');
    if (schemaVersion != 'source-ledger-v1') {
      throw const FormatException('unsupported source manifest schemaVersion');
    }
    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      throw const FormatException('source manifest entries must be a list');
    }
    final entries = rawEntries
        .map(
          (entry) => SourceLedgerEntry.fromJson(
            _asStringObjectMap(entry, 'source manifest entry'),
          ),
        )
        .toList(growable: false);
    final sourceIds = <String>{};
    for (final entry in entries) {
      if (!sourceIds.add(entry.sourceId)) {
        throw FormatException('duplicate sourceId: ${entry.sourceId}');
      }
    }
    final rootBindings = <SourceRootBinding>[];
    final bindings = json['rootBindings'];
    if (bindings is List) {
      rootBindings.addAll(
        bindings.map(
          (binding) => SourceRootBinding.fromJson(
            _asStringObjectMap(binding, 'source root binding'),
          ),
        ),
      );
    }
    final rootPaths = <String>{};
    for (final binding in rootBindings) {
      final normalizedRoot = _normalizeManifestPath(binding.rootPath);
      if (!rootPaths.add(normalizedRoot)) {
        throw FormatException(
          'duplicate source root binding: ${binding.rootPath}',
        );
      }
      final bindingIds = <String>{};
      for (final sourceId in binding.sourceIds) {
        if (!sourceIds.contains(sourceId)) {
          throw FormatException(
            'root binding references unknown sourceId: $sourceId',
          );
        }
        if (!bindingIds.add(sourceId)) {
          throw FormatException(
            'duplicate sourceId in root binding: $sourceId',
          );
        }
      }
      for (final sourceId in binding.contributionShares.keys) {
        if (!sourceIds.contains(sourceId) ||
            !binding.sourceIds.contains(sourceId)) {
          throw FormatException(
            'contributionShares references unbound sourceId: $sourceId',
          );
        }
      }
      if (binding.contributionShares.isNotEmpty) {
        final missingShares = binding.sourceIds.where(
          (sourceId) => !binding.contributionShares.containsKey(sourceId),
        );
        if (missingShares.isNotEmpty) {
          throw const FormatException(
            'contributionShares must cover all root binding sourceIds',
          );
        }
        final sum = binding.contributionShares.values.fold<double>(
          0,
          (total, share) => total + share,
        );
        if ((sum - 1.0).abs() > 0.001) {
          throw const FormatException('contributionShares must sum to 1.0');
        }
      }
    }
    return SourceLedgerManifest(
      schemaVersion: schemaVersion,
      generatedAtMs: _readInt(json, 'generatedAtMs'),
      entries: entries,
      rootBindings: rootBindings,
    );
  }

  final String schemaVersion;
  final int generatedAtMs;
  final List<SourceLedgerEntry> entries;
  final List<SourceRootBinding> rootBindings;

  Map<String, SourceLedgerEntry> get entriesById => <String, SourceLedgerEntry>{
    for (final entry in entries) entry.sourceId: entry,
  };
}

class ApprovedStyleReferenceBundle {
  ApprovedStyleReferenceBundle({
    required this.allowed,
    required this.referenceUsage,
    required Iterable<SourceLedgerEntry> sources,
    required this.denialReasonCode,
    Map<String, String> abstractFeatures = const <String, String>{},
    this.runtimeRootPath,
    this.maxDominantSourceShare = 0.40,
  }) : sources = List<SourceLedgerEntry>.unmodifiable(sources),
       abstractFeatures = Map<String, String>.unmodifiable(abstractFeatures) {
    if (!maxDominantSourceShare.isFinite ||
        maxDominantSourceShare < 0 ||
        maxDominantSourceShare > 1) {
      throw const FormatException('maxDominantSourceShare must be in 0..1');
    }
    if (allowed) {
      if (referenceUsage == ReferenceUsage.off ||
          this.sources.isEmpty ||
          denialReasonCode != SourceAdmissionReasonCode.allowed ||
          runtimeRootPath == null ||
          runtimeRootPath!.trim().isEmpty) {
        throw const FormatException('admitted bundle invariants are invalid');
      }
    } else if (referenceUsage != ReferenceUsage.off ||
        this.sources.isNotEmpty ||
        this.abstractFeatures.isNotEmpty ||
        denialReasonCode == SourceAdmissionReasonCode.allowed) {
      throw const FormatException('denied bundle invariants are invalid');
    }
  }

  factory ApprovedStyleReferenceBundle.denied(
    SourceAdmissionReasonCode reasonCode,
  ) => ApprovedStyleReferenceBundle(
    allowed: false,
    referenceUsage: ReferenceUsage.off,
    sources: const <SourceLedgerEntry>[],
    denialReasonCode: reasonCode,
  );

  final bool allowed;
  final ReferenceUsage referenceUsage;
  final List<SourceLedgerEntry> sources;
  final SourceAdmissionReasonCode denialReasonCode;
  final Map<String, String> abstractFeatures;
  final String? runtimeRootPath;
  final double maxDominantSourceShare;

  List<String> get sourceIds =>
      sources.map((source) => source.sourceId).toList();

  int? maxExcerptCharsForSource(String sourceId) {
    for (final source in sources) {
      if (source.sourceId == sourceId) return source.excerptLimitChars;
    }
    return null;
  }

  Map<String, Object?> toPromptSafeJson() => _sortedMap(<String, Object?>{
    'allowed': allowed,
    if (abstractFeatures.isNotEmpty) 'abstractFeatures': abstractFeatures,
    'denialReasonCode': denialReasonCode.name,
    'identityHash': identityHash,
    'maxDominantSourceShare': maxDominantSourceShare,
    'referenceUsage': referenceUsage.name,
    if (_excerptLimits.isNotEmpty) 'excerptLimits': _excerptLimits,
  });

  Map<String, Object?> toAuditJson() => _sortedMap(<String, Object?>{
    'allowed': allowed,
    if (abstractFeatures.isNotEmpty) 'abstractFeatures': abstractFeatures,
    'denialReasonCode': denialReasonCode.name,
    'identityHash': identityHash,
    'maxDominantSourceShare': maxDominantSourceShare,
    'referenceUsage': referenceUsage.name,
    'sourceIds': sourceIds..sort(),
    'sources': sources
        .map((source) => source.toCanonicalJson())
        .toList(growable: false),
  });

  String get identityHash => AppLlmCanonicalHash.domainHash(
    'approved-style-reference-bundle-v1',
    <String, Object?>{
      'allowed': allowed,
      'abstractFeatures': abstractFeatures,
      'denialReasonCode': denialReasonCode.name,
      'maxDominantSourceShare': maxDominantSourceShare,
      'referenceUsage': referenceUsage.name,
      'sourceHashes': sources.map((source) => source.canonicalHash).toList()
        ..sort(),
      'sourceIds': sourceIds..sort(),
    },
  );

  Map<String, int> get _excerptLimits {
    final result = <String, int>{};
    for (var index = 0; index < sources.length; index += 1) {
      final limit = sources[index].excerptLimitChars;
      if (limit != null) result['source_${index + 1}'] = limit;
    }
    return result;
  }
}

void _requireNonEmpty(String value, String field) {
  if (value.trim().isEmpty) throw FormatException('$field must be non-empty');
}

void _requireSafeManifestPath(String value, String field) {
  final normalized = value.trim().replaceAll('\\', '/');
  if (normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:/').hasMatch(normalized) ||
      RegExp(r'(^|/)\.\.(/|$)').hasMatch(normalized)) {
    throw FormatException('$field must be relative and cannot contain ..');
  }
}

String _normalizeManifestPath(String value) =>
    value.trim().replaceAll('\\', '/').replaceAll(RegExp(r'/+'), '/');

String _readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key must be a non-empty string');
}

String? _readNullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('$key must be a string or null');
}

int _readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('$key must be an integer');
}

int? _readNullableInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('$key must be an integer or null');
}

bool _readBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean');
}

Map<String, double> _readNullableDoubleMap(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) return const <String, double>{};
  if (value is! Map) throw FormatException('$key must be an object');
  final result = <String, double>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$key keys must be strings');
    }
    final share = entry.value;
    if (share is! num || !share.isFinite || share < 0 || share > 1) {
      throw FormatException('$key values must be finite numbers in 0..1');
    }
    result[entry.key as String] = share.toDouble();
  }
  return Map<String, double>.unmodifiable(result);
}

List<String> _readStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be a list');
  return value
      .map((item) {
        if (item is String && item.trim().isNotEmpty) return item;
        throw FormatException('$key contains a non-string value');
      })
      .toList(growable: false);
}

T _parseEnum<T extends Enum>(String value, List<T> values, String field) {
  for (final item in values) {
    if (item.name == value) return item;
  }
  throw FormatException('unknown $field enum: $value');
}

Map<String, Object?> _asStringObjectMap(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object');
  return value.map((key, value) {
    if (key is! String) throw FormatException('$label keys must be strings');
    return MapEntry(key, value);
  });
}

void _rejectUnknownKeys(
  Map<String, Object?> json,
  String label,
  Set<String> allowedKeys,
) {
  for (final key in json.keys) {
    if (!allowedKeys.contains(key)) {
      throw FormatException('$label contains unknown key: $key');
    }
  }
}

List<String> _sortedEnumNames(Iterable<Enum> values) =>
    (values.map((value) => value.name).toList()..sort());

Map<String, Object?> _sortedMap(Map<String, Object?> input) {
  final keys = input.keys.toList()..sort();
  return <String, Object?>{for (final key in keys) key: input[key]};
}
