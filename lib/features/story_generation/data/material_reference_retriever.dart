import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/features/story_generation/data/source_admission_resolver.dart';
import 'package:novel_writer/features/story_generation/domain/source_ledger_models.dart';

import '../domain/pipeline_models.dart' as domain;
import 'scene_pipeline_models.dart' as scene;

const String kWritingReferenceToolName = 'search_writing_reference';

/// Local JSONL retriever for curated writing reference material.
///
/// It only exposes retrieval-safe labels plus a short excerpt. Guidance fields
/// from the source records are never copied into results.
class MaterialReferenceRetriever {
  MaterialReferenceRetriever({
    String rootPath = '',
    ApprovedStyleReferenceBundle? approvedBundle,
    SourceAdmissionResolver? sourceAdmissionResolver,
    ReferenceUsage requestedUsage = ReferenceUsage.licensedExcerpts,
    int defaultLimit = 6,
    int maxLimit = 12,
    int excerptCharLimit = 220,
  }) : _rootPath = rootPath,
       _approvedBundle =
           approvedBundle ??
           sourceAdmissionResolver?.resolveRoot(
             rootPath: rootPath,
             requestedUsage: requestedUsage,
           ) ??
           ApprovedStyleReferenceBundle.denied(
             SourceAdmissionReasonCode.unknownSource,
           ),
       _maxLimit = _boundedMaxLimit(maxLimit),
       _defaultLimit = _boundedDefaultLimit(defaultLimit, maxLimit),
       _excerptCharLimit = excerptCharLimit.clamp(24, 1000);

  final String _rootPath;
  final ApprovedStyleReferenceBundle _approvedBundle;
  final int _defaultLimit;
  final int _maxLimit;
  final int _excerptCharLimit;

  static int _boundedMaxLimit(int value) => value.clamp(1, 12);

  static int _boundedDefaultLimit(int value, int maxLimit) {
    return value.clamp(1, _boundedMaxLimit(maxLimit));
  }

  Future<MaterialReferenceResult> search(MaterialReferenceQuery query) async {
    return searchSync(query);
  }

  MaterialReferenceResult searchSync(MaterialReferenceQuery query) {
    if (!_canReadReferenceFiles) {
      return MaterialReferenceResult.denied(
        source: _sourceWithoutFilesystem(query.source).name,
        reasonCode: _approvedBundle.denialReasonCode,
      );
    }
    final source = _resolveSource(query.source);
    final records = _loadRecords(source);
    final fallbackTextByScene = source == MaterialReferenceSource.refinedScenes
        ? _loadRagFallbackTextByScene()
        : const <String, String>{};
    final scored = <_ScoredHit>[];

    for (final record in records) {
      final hit = _hitFromRecord(
        record,
        source: source,
        fallbackTextByScene: fallbackTextByScene,
      );
      if (hit == null) continue;
      final score = _score(hit, query);
      if (score <= 0 && query.hasAnyFilter) continue;
      scored.add(_ScoredHit(hit, score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.hit.chunkId.compareTo(b.hit.chunkId);
    });

    final seen = <String>{};
    final hits = <MaterialReferenceHit>[];
    for (final item in scored) {
      if (!seen.add(item.hit.chunkId)) continue;
      hits.add(item.hit);
      if (hits.length >= _limit(query.limit)) break;
    }

    return MaterialReferenceResult(
      source: source.name,
      hits: List<MaterialReferenceHit>.unmodifiable(hits),
      sourceAdmissionDenied: false,
      sourceAdmissionReasonCode: _approvedBundle.denialReasonCode.name,
    );
  }

  domain.ContextCapsule searchToDomainCapsule(Map<String, Object?> parameters) {
    final result = searchSync(
      MaterialReferenceQuery.fromParameters(parameters),
    );
    final summary = result.toPromptSummary();
    return domain.ContextCapsule(
      id: 'writing_reference_${DateTime.now().millisecondsSinceEpoch}',
      sourceTool: kWritingReferenceToolName,
      summary: summary.isEmpty ? '未找到匹配的写作素材参考。' : summary,
      charBudget: 900,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      metadata: {
        'source': result.source,
        'hitCount': result.hits.length,
        'sourceAdmissionDenied': result.sourceAdmissionDenied,
        if (result.sourceAdmissionReasonCode != null)
          'sourceAdmissionReasonCode': result.sourceAdmissionReasonCode,
      },
    );
  }

  String searchToSceneSummary(scene.LightRetrievalIntent intent) {
    final result = searchSync(
      MaterialReferenceQuery(
        query: intent.query,
        useWhen: intent.purpose,
        limit: 4,
      ),
    );
    return result.toPromptSummary(maxHits: 4);
  }

  MaterialReferenceSource _resolveSource(String? raw) {
    final explicit = _sourceWithoutFilesystem(raw);
    if ((raw ?? '').trim().isNotEmpty) return explicit;
    final refined = File('$_rootPath/refined_scenes.jsonl');
    if (refined.existsSync()) return MaterialReferenceSource.refinedScenes;
    return MaterialReferenceSource.ragContextualAtoms;
  }

  MaterialReferenceSource _sourceWithoutFilesystem(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized == MaterialReferenceSource.refinedScenes.name ||
        normalized == 'refined_scenes') {
      return MaterialReferenceSource.refinedScenes;
    }
    return MaterialReferenceSource.ragContextualAtoms;
  }

  List<Map<String, Object?>> _loadRecords(MaterialReferenceSource source) {
    final file = File('$_rootPath/${source.fileName}');
    if (!file.existsSync()) return const <Map<String, Object?>>[];
    final records = <Map<String, Object?>>[];
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        records.add(Map<String, Object?>.from(decoded));
      }
    }
    return records;
  }

  Map<String, String> _loadRagFallbackTextByScene() {
    final file = File(
      '$_rootPath/${MaterialReferenceSource.ragContextualAtoms.fileName}',
    );
    if (!file.existsSync()) return const <String, String>{};
    final fallback = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final decoded = jsonDecode(line);
      if (decoded is! Map) continue;
      final record = Map<String, Object?>.from(decoded);
      final sceneId = record['parent_scene_id']?.toString() ?? '';
      if (sceneId.isEmpty || fallback.containsKey(sceneId)) continue;
      final text = _firstText(record, const <String, String>{});
      if (text.isNotEmpty) fallback[sceneId] = text;
    }
    return fallback;
  }

  MaterialReferenceHit? _hitFromRecord(
    Map<String, Object?> record, {
    required MaterialReferenceSource source,
    required Map<String, String> fallbackTextByScene,
  }) {
    final chunkId = _chunkId(record);
    if (chunkId.isEmpty) return null;
    final promptSafeText = _redactPromptBoundSourceLabels(
      _firstText(record, fallbackTextByScene),
    );
    final text = _compact(promptSafeText);
    if (text.isEmpty) return null;
    return MaterialReferenceHit(
      chunkId: chunkId,
      primaryTag: record['primary_tag']?.toString() ?? '',
      tags: _tagIds(record['tags']),
      retrievalRoles: _stringList(record['retrieval_roles']),
      useWhen: record['use_when']?.toString() ?? '',
      qualityFlags: _stringList(record['quality_flags']),
      excerpt: text,
      source: source.name,
    );
  }

  String _chunkId(Map<String, Object?> record) {
    return _firstNonEmpty([
      record['chunk_id'],
      record['parent_scene_id'],
      record['rag_record_id'],
      record['source_atom_id'],
    ]);
  }

  String _firstText(
    Map<String, Object?> record,
    Map<String, String> fallbackTextByScene,
  ) {
    final direct = _firstNonEmpty([
      record['excerpt'],
      record['text'],
      record['generation_reference_text'],
    ]);
    if (direct.isNotEmpty) return direct;
    final chunkId = record['chunk_id']?.toString() ?? '';
    return fallbackTextByScene[chunkId] ?? '';
  }

  int _score(MaterialReferenceHit hit, MaterialReferenceQuery query) {
    var score = 1;
    score += _scoreText(query.query, [
      hit.chunkId,
      hit.primaryTag,
      hit.useWhen,
      hit.excerpt,
      ...hit.tags,
      ...hit.retrievalRoles,
      ...hit.qualityFlags,
    ]);
    score += _scoreTerms(query.tags, hit.tags) * 6;
    score += _scoreTerms(query.retrievalRoles, hit.retrievalRoles) * 6;
    score += _scoreText(query.useWhen, [hit.useWhen, hit.excerpt]) * 3;
    return score;
  }

  int _scoreText(String value, List<String> fields) {
    final terms = _terms(value);
    if (terms.isEmpty) return 0;
    var score = 0;
    final haystack = fields.join('\n').toLowerCase();
    for (final term in terms) {
      if (haystack.contains(term)) score += 1;
    }
    return score;
  }

  int _scoreTerms(List<String> terms, List<String> fields) {
    if (terms.isEmpty || fields.isEmpty) return 0;
    final normalizedFields = fields.map((v) => v.toLowerCase()).toSet();
    var score = 0;
    for (final term in terms) {
      final normalized = term.toLowerCase();
      if (normalizedFields.contains(normalized) ||
          normalizedFields.any((field) => field.contains(normalized))) {
        score += 1;
      }
    }
    return score;
  }

  int _limit(int? value) {
    final requested = value ?? _defaultLimit;
    return requested.clamp(1, _maxLimit);
  }

  bool get _canReadReferenceFiles =>
      _approvedBundle.allowed &&
      _rootPath.trim().isNotEmpty &&
      _approvedBundle.runtimeRootPath != null &&
      _sameRoot(_rootPath, _approvedBundle.runtimeRootPath!) &&
      (_approvedBundle.referenceUsage == ReferenceUsage.licensedExcerpts ||
          _approvedBundle.referenceUsage ==
              ReferenceUsage.userOwnedFullContext);

  static bool _sameRoot(String left, String right) {
    final normalizedLeft = Directory(
      left.trim(),
    ).absolute.uri.normalizePath().toFilePath();
    final normalizedRight = Directory(
      right.trim(),
    ).absolute.uri.normalizePath().toFilePath();
    return normalizedLeft == normalizedRight;
  }

  List<String> _terms(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return const <String>[];
    final split = normalized
        .split(RegExp(r'[\s,，;；|/]+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    return split.isEmpty ? <String>[normalized] : split;
  }

  List<String> _tagIds(Object? raw) {
    if (raw is! List) return const <String>[];
    final tags = <String>[];
    for (final item in raw) {
      if (item is Map && item['id'] != null) {
        tags.add(item['id'].toString());
      } else if (item != null) {
        tags.add(item.toString());
      }
    }
    return List<String>.unmodifiable(tags);
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return List<String>.unmodifiable(
        raw.map((v) => v.toString()).where((v) => v.trim().isNotEmpty),
      );
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return <String>[raw.trim()];
    }
    return const <String>[];
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _compact(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sourceLimit = _approvedBundle.sources.isEmpty
        ? null
        : _approvedBundle.sources
              .map((source) => source.excerptLimitChars)
              .whereType<int>()
              .fold<int?>(
                null,
                (min, value) => min == null || value < min ? value : min,
              );
    final limit = sourceLimit == null
        ? _excerptCharLimit
        : sourceLimit.clamp(0, _excerptCharLimit);
    if (limit <= 0) return '';
    final runes = normalized.runes;
    if (runes.length <= limit) return normalized;
    if (limit <= 3) return String.fromCharCodes(runes.take(limit));
    return '${String.fromCharCodes(runes.take(limit - 3))}...';
  }

  String _redactPromptBoundSourceLabels(String value) {
    var sanitized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.isEmpty) return '';

    final labels = <String>{};
    void addLabel(String? raw, {bool includeBasename = false}) {
      final label = raw?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
      if (label.length < 2) return;
      labels.add(label);
      if (!includeBasename) return;
      final normalizedPath = label.replaceAll('\\', '/');
      final basename = normalizedPath.split('/').last.trim();
      if (basename.length >= 2) {
        labels.add(basename);
        final extensionIndex = basename.lastIndexOf('.');
        if (extensionIndex > 1) {
          labels.add(basename.substring(0, extensionIndex));
        }
      }
    }

    addLabel(_rootPath, includeBasename: true);
    addLabel(_approvedBundle.runtimeRootPath, includeBasename: true);
    for (final source in _approvedBundle.sources) {
      addLabel(source.title);
      addLabel(source.creator);
      addLabel(source.sourceId);
      addLabel(source.provenanceUri, includeBasename: true);
    }

    final orderedLabels = labels.toList(growable: false)
      ..sort((left, right) => right.length.compareTo(left.length));
    for (final label in orderedLabels) {
      sanitized = sanitized.replaceAll(
        RegExp(RegExp.escape(label), caseSensitive: false),
        _promptSourceRedaction,
      );
    }
    sanitized = sanitized
        .replaceAll(_promptSourceMetadataKey, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final meaningful = sanitized
        .replaceAll(_promptSourceRedaction, '')
        .replaceAll(RegExp(r'[\s,，;；:：=|/\\._\-\[\]()]+'), '');
    return meaningful.isEmpty ? '' : sanitized;
  }
}

const String _promptSourceRedaction = '[来源已脱敏]';

final RegExp _promptSourceMetadataKey = RegExp(
  r'(?:source[_ -]?id|title|creator|author|root(?:[_ -]?path)?|'
  r'provenance(?:[_ -]?(?:uri|path|label))?|作品名|书名|作者|来源标识|'
  r'根目录|出处)\s*[:：=]\s*',
  caseSensitive: false,
);

enum MaterialReferenceSource {
  refinedScenes('refined_scenes.jsonl'),
  ragContextualAtoms('rag_contextual_atoms.jsonl');

  const MaterialReferenceSource(this.fileName);

  final String fileName;
}

class MaterialReferenceQuery {
  const MaterialReferenceQuery({
    this.query = '',
    this.tags = const <String>[],
    this.retrievalRoles = const <String>[],
    this.useWhen = '',
    this.limit,
    this.source,
  });

  final String query;
  final List<String> tags;
  final List<String> retrievalRoles;
  final String useWhen;
  final int? limit;
  final String? source;

  bool get hasAnyFilter =>
      query.trim().isNotEmpty ||
      tags.isNotEmpty ||
      retrievalRoles.isNotEmpty ||
      useWhen.trim().isNotEmpty;

  static MaterialReferenceQuery fromParameters(Map<String, Object?> params) {
    return MaterialReferenceQuery(
      query: params['query']?.toString() ?? '',
      tags: _listParam(params['tags']),
      retrievalRoles:
          _listParam(params['retrievalRoles']) +
          _listParam(params['retrieval_roles']),
      useWhen:
          params['useWhen']?.toString() ?? params['use_when']?.toString() ?? '',
      limit: int.tryParse(params['limit']?.toString() ?? ''),
      source: params['source']?.toString(),
    );
  }

  static List<String> _listParam(Object? raw) {
    if (raw is List) {
      return List<String>.unmodifiable(raw.map((v) => v.toString()));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return List<String>.unmodifiable(
        raw
            .split(RegExp(r'[,，;；|/]+'))
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty),
      );
    }
    return const <String>[];
  }
}

class MaterialReferenceResult {
  const MaterialReferenceResult({
    required this.source,
    required this.hits,
    this.sourceAdmissionDenied = false,
    this.sourceAdmissionReasonCode,
  });

  factory MaterialReferenceResult.denied({
    required String source,
    required SourceAdmissionReasonCode reasonCode,
  }) => MaterialReferenceResult(
    source: source,
    hits: const <MaterialReferenceHit>[],
    sourceAdmissionDenied: true,
    sourceAdmissionReasonCode: reasonCode.name,
  );

  final String source;
  final List<MaterialReferenceHit> hits;
  final bool sourceAdmissionDenied;
  final String? sourceAdmissionReasonCode;

  String toPromptSummary({int? maxHits, int maxChars = 900}) {
    if (sourceAdmissionDenied) return '';
    if (maxChars <= 0) return '';
    final capped = (maxHits == null ? hits : hits.take(maxHits)).toList(
      growable: false,
    );
    final summary = <String>[
      for (var index = 0; index < capped.length; index += 1)
        capped[index].toPromptLine(promptIndex: index + 1),
    ].join('\n');
    final runes = summary.runes;
    if (runes.length <= maxChars) return summary;
    return String.fromCharCodes(runes.take(maxChars));
  }

  Map<String, Object?> toJson() {
    return {
      'source': source,
      'sourceAdmissionDenied': sourceAdmissionDenied,
      if (sourceAdmissionReasonCode != null)
        'sourceAdmissionReasonCode': sourceAdmissionReasonCode,
      'results': [for (final hit in hits) hit.toJson()],
    };
  }
}

class MaterialReferenceHit {
  const MaterialReferenceHit({
    required this.chunkId,
    required this.primaryTag,
    required this.tags,
    required this.retrievalRoles,
    required this.useWhen,
    required this.qualityFlags,
    required this.excerpt,
    required this.source,
  });

  final String chunkId;
  final String primaryTag;
  final List<String> tags;
  final List<String> retrievalRoles;
  final String useWhen;
  final List<String> qualityFlags;
  final String excerpt;
  final String source;

  Map<String, Object?> toJson() {
    return {
      'chunk_id': chunkId,
      'primary_tag': primaryTag,
      'tags': tags,
      'retrieval_roles': retrievalRoles,
      'use_when': useWhen,
      'quality_flags': qualityFlags,
      'excerpt': excerpt,
      'source': source,
    };
  }

  String toPromptLine({required int promptIndex}) {
    final body = excerpt.isEmpty ? '' : ' excerpt=$excerpt';
    return '[ref_$promptIndex]$body'.trim();
  }
}

class _ScoredHit {
  const _ScoredHit(this.hit, this.score);

  final MaterialReferenceHit hit;
  final int score;
}
