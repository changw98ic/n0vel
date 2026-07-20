import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';

import '../../features/story_generation/domain/contracts/memory_policy.dart';
import '../../features/story_generation/domain/memory_models.dart';
import '../../features/story_generation/data/source_admission_resolver.dart';
import '../../features/story_generation/domain/source_ledger_models.dart';
import 'hybrid_retriever.dart';

/// Imports the offline novel-reference atoms into an isolated hybrid index.
///
/// The importer intentionally reads `atoms.jsonl`, not
/// `rag_contextual_atoms.jsonl`: contextual records contain overlapping
/// neighbour windows that would inflate the index and retrieval redundancy.
class NovelCorpusImporter {
  NovelCorpusImporter({
    required this.retriever,
    required this.corpusRootPath,
    required this.sourceAdmissionResolver,
    this.batchSize = 500,
  }) {
    if (batchSize < 1) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be positive');
    }
  }

  static const defaultWorks = <String>['jianlai', 'guimi', 'tigui'];
  static const producer = 'writing-reference-import/v1';

  final HybridRetriever retriever;
  final String corpusRootPath;
  final SourceAdmissionResolver sourceAdmissionResolver;
  final int batchSize;

  Future<NovelCorpusImportReport> importWorks({
    List<String> works = defaultWorks,
    int limitPerWork = 0,
    Map<String, int> startOrdinalByWork = const {},
    Future<void> Function(NovelCorpusImportProgress progress)? onProgress,
  }) async {
    if (limitPerWork < 0) {
      throw ArgumentError.value(
        limitPerWork,
        'limitPerWork',
        'must be zero (unlimited) or positive',
      );
    }
    final normalizedWorks = _normalizeWorks(works);

    final watch = Stopwatch()..start();
    final reports = <NovelCorpusWorkImportReport>[];
    for (final work in normalizedWorks) {
      reports.add(
        await _importWork(
          work,
          limitPerWork: limitPerWork,
          startOrdinal: startOrdinalByWork[work] ?? 0,
          onProgress: onProgress,
        ),
      );
    }
    watch.stop();
    return NovelCorpusImportReport(
      corpusRootPath: corpusRootPath,
      sourceFileName: 'atoms.jsonl',
      limitPerWork: limitPerWork,
      batchSize: batchSize,
      elapsedMs: watch.elapsedMilliseconds,
      works: reports,
    );
  }

  /// Verifies source-ledger admission without opening or hashing corpus text.
  ///
  /// Callers that perform preparatory work (for example, embedding-resume
  /// manifest hashing) must invoke this before touching `atoms.jsonl`.
  void assertWorksAdmitted({List<String> works = defaultWorks}) {
    for (final work in _normalizeWorks(works)) {
      _requireWorkAdmission(work);
    }
  }

  Future<NovelCorpusWorkImportReport> _importWork(
    String work, {
    required int limitPerWork,
    required int startOrdinal,
    required Future<void> Function(NovelCorpusImportProgress progress)?
    onProgress,
  }) async {
    if (startOrdinal < 0) {
      throw ArgumentError.value(
        startOrdinal,
        'startOrdinal',
        'must be non-negative',
      );
    }
    final workRootPath = '$corpusRootPath/$work';
    _requireWorkAdmission(work);

    final source = File('$workRootPath/atoms.jsonl');
    if (!source.existsSync()) {
      throw FileSystemException('Missing novel corpus atoms', source.path);
    }

    final projectId = projectIdForWork(work);
    final uniqueByContent = <String, _CorpusAtomAggregate>{};
    final pending = <StoryMemoryChunk>[];
    var inputRecords = 0;
    var indexedRecords = startOrdinal;
    var writtenRecords = 0;
    var selectedRecords = 0;
    var reportedComplete = false;
    var duplicateRecords = 0;
    var invalidRecords = 0;
    var truncatedByLimit = false;

    Future<void> flush() async {
      if (pending.isEmpty) return;
      await retriever.indexChunks(List<StoryMemoryChunk>.of(pending));
      indexedRecords += pending.length;
      writtenRecords += pending.length;
      pending.clear();
      await onProgress?.call(
        NovelCorpusImportProgress(
          work: work,
          nextOrdinal: indexedRecords,
          selectedRecords: selectedRecords,
          complete: indexedRecords == selectedRecords,
        ),
      );
      reportedComplete = indexedRecords == selectedRecords;
    }

    final lines = utf8.decoder
        .bind(source.openRead())
        .transform(const LineSplitter());
    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      inputRecords++;

      Map<String, Object?> record;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          invalidRecords++;
          continue;
        }
        record = Map<String, Object?>.from(decoded);
      } on FormatException {
        invalidRecords++;
        continue;
      }

      final content = record['text']?.toString().trim() ?? '';
      final atomId = _firstNonEmpty([record['atom_id'], record['chunk_id']]);
      final parentSceneId = record['parent_scene_id']?.toString().trim() ?? '';
      if (content.isEmpty || atomId.isEmpty || parentSceneId.isEmpty) {
        invalidRecords++;
        continue;
      }

      final normalizedContent = _normalizeContent(content);
      final existing = uniqueByContent[normalizedContent];
      if (existing != null) {
        duplicateRecords++;
        existing.merge(record, atomId: atomId, parentSceneId: parentSceneId);
        continue;
      }
      uniqueByContent[normalizedContent] = _CorpusAtomAggregate(
        work: work,
        content: content,
        normalizedContent: normalizedContent,
        record: record,
        atomId: atomId,
        parentSceneId: parentSceneId,
      );
    }

    if (uniqueByContent.isEmpty) {
      throw StateError('No valid atoms found in ${source.path}');
    }
    final selected = uniqueByContent.values.toList()
      ..sort((first, second) => first.stableHash.compareTo(second.stableHash));
    if (limitPerWork > 0 && selected.length > limitPerWork) {
      selected.removeRange(limitPerWork, selected.length);
      truncatedByLimit = true;
    }
    selectedRecords = selected.length;
    if (startOrdinal > selectedRecords) {
      throw StateError(
        'Resume ordinal $startOrdinal exceeds $selectedRecords selected '
        'records for $work',
      );
    }
    for (final aggregate in selected.skip(startOrdinal)) {
      pending.add(aggregate.toChunk(projectId: projectId));
      if (pending.length >= batchSize) await flush();
    }
    await flush();
    if (indexedRecords == selectedRecords && !reportedComplete) {
      await onProgress?.call(
        NovelCorpusImportProgress(
          work: work,
          nextOrdinal: indexedRecords,
          selectedRecords: selectedRecords,
          complete: true,
        ),
      );
    }

    return NovelCorpusWorkImportReport(
      work: work,
      projectId: projectId,
      sourcePath: source.path,
      inputRecords: inputRecords,
      indexedRecords: indexedRecords,
      writtenRecords: writtenRecords,
      resumedFromOrdinal: startOrdinal,
      duplicateRecords: duplicateRecords,
      invalidRecords: invalidRecords,
      truncatedByLimit: truncatedByLimit,
    );
  }

  static String projectIdForWork(String work) => 'writing-reference-$work';

  List<String> _normalizeWorks(Iterable<String> works) {
    final normalizedWorks = <String>[];
    final seenWorks = <String>{};
    for (final rawWork in works) {
      final work = rawWork.trim().toLowerCase();
      if (work.isEmpty || !RegExp(r'^[a-z0-9_-]+$').hasMatch(work)) {
        throw ArgumentError.value(rawWork, 'works', 'contains an invalid slug');
      }
      if (seenWorks.add(work)) normalizedWorks.add(work);
    }
    if (normalizedWorks.isEmpty) {
      throw ArgumentError.value(works, 'works', 'must not be empty');
    }
    return normalizedWorks;
  }

  ApprovedStyleReferenceBundle _requireWorkAdmission(String work) {
    final admission = _resolveWorkAdmission('$corpusRootPath/$work');
    if (!admission.allowed ||
        admission.referenceUsage != ReferenceUsage.localAnalysisOnly) {
      throw SourceAdmissionException(
        work: work,
        reasonCode: admission.denialReasonCode,
      );
    }
    return admission;
  }

  ApprovedStyleReferenceBundle _resolveWorkAdmission(String workRootPath) {
    final primary = sourceAdmissionResolver.resolveRoot(
      rootPath: workRootPath,
      requestedUsage: ReferenceUsage.localAnalysisOnly,
    );
    if (primary.allowed ||
        primary.denialReasonCode != SourceAdmissionReasonCode.unknownSource) {
      return primary;
    }
    final sourceManifest = File('$workRootPath/source_manifest.json');
    if (sourceManifest.existsSync()) {
      return SourceAdmissionResolver.fromManifestFile(
        sourceManifest,
      ).resolveRoot(
        rootPath: workRootPath,
        requestedUsage: ReferenceUsage.localAnalysisOnly,
      );
    }
    final processingManifest = File('$workRootPath/manifest.json');
    if (processingManifest.existsSync()) {
      return ApprovedStyleReferenceBundle.denied(
        SourceAdmissionReasonCode.processingManifestOnly,
      );
    }
    return primary;
  }

  static String _normalizeContent(String content) =>
      content.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _stableContentHash(String work, String content) {
    final digest = const DartSha256().hashSync(
      utf8.encode('$work\u0000$content'),
    );
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  static String _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<String> _recordTags(Map<String, Object?> record, String work) {
    final tags = <String>{'writing-reference', 'work:$work'};
    if (record['needs_llm_review'] == true) {
      tags.add('review:needs-llm');
    }
    final primaryTag = record['primary_tag']?.toString().trim() ?? '';
    if (primaryTag.isNotEmpty) tags.add('style:$primaryTag');
    final axes = record['tag_axes'];
    if (axes is List) {
      for (final raw in axes) {
        final axis = raw?.toString().trim() ?? '';
        if (axis.isNotEmpty) tags.add('axis:$axis');
      }
    }
    final rawTags = record['tags'];
    if (rawTags is List) {
      for (final raw in rawTags) {
        if (raw is! Map) continue;
        final id = raw['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) tags.add('style:$id');
      }
    }
    final qualityFlags = record['quality_flags'];
    if (qualityFlags is List) {
      for (final raw in qualityFlags) {
        final flag = raw?.toString().trim() ?? '';
        if (flag.isNotEmpty) tags.add('quality:$flag');
      }
    }
    final stable = tags.toList()..sort();
    return List.unmodifiable(stable);
  }
}

class SourceAdmissionException implements Exception {
  const SourceAdmissionException({
    required this.work,
    required this.reasonCode,
  });

  final String work;
  final SourceAdmissionReasonCode reasonCode;

  @override
  String toString() =>
      'SourceAdmissionException(work: $work, '
      'reasonCode: ${reasonCode.name})';
}

class _CorpusAtomAggregate {
  _CorpusAtomAggregate({
    required this.work,
    required this.content,
    required this.normalizedContent,
    required Map<String, Object?> record,
    required String atomId,
    required String parentSceneId,
  }) : stableHash = NovelCorpusImporter._stableContentHash(
         work,
         normalizedContent,
       ) {
    merge(record, atomId: atomId, parentSceneId: parentSceneId);
  }

  final String work;
  final String content;
  final String normalizedContent;
  final String stableHash;
  final Set<String> atomIds = <String>{};
  final Set<String> parentSceneIds = <String>{};
  final Set<String> tags = <String>{};

  void merge(
    Map<String, Object?> record, {
    required String atomId,
    required String parentSceneId,
  }) {
    atomIds.add(atomId);
    parentSceneIds.add(parentSceneId);
    tags.addAll(NovelCorpusImporter._recordTags(record, work));
  }

  StoryMemoryChunk toChunk({required String projectId}) {
    final stableAtomIds = atomIds.toList()..sort();
    final stableSceneIds = parentSceneIds.toList()..sort();
    final stableTags = tags.toList()..sort();
    return StoryMemoryChunk(
      id: 'writing-reference/v1/$work/$stableHash',
      projectId: projectId,
      // A shared per-work scope lets the retriever suppress duplicates across
      // scenes while projectId still prevents cross-book leakage.
      scopeId: projectId,
      kind: MemorySourceKind.reviewFinding,
      content: content,
      tier: MemoryTier.scene,
      producer: NovelCorpusImporter.producer,
      sourceRefs: [
        for (final atomId in stableAtomIds)
          MemorySourceRef(
            sourceId: atomId,
            sourceType: MemorySourceKind.sceneSummary,
          ),
      ],
      rootSourceIds: stableSceneIds,
      tags: stableTags,
      tokenCostEstimate: (content.runes.length + 1) ~/ 2,
    );
  }
}

class NovelCorpusWorkImportReport {
  const NovelCorpusWorkImportReport({
    required this.work,
    required this.projectId,
    required this.sourcePath,
    required this.inputRecords,
    required this.indexedRecords,
    required this.writtenRecords,
    required this.resumedFromOrdinal,
    required this.duplicateRecords,
    required this.invalidRecords,
    required this.truncatedByLimit,
  });

  final String work;
  final String projectId;
  final String sourcePath;
  final int inputRecords;
  final int indexedRecords;
  final int writtenRecords;
  final int resumedFromOrdinal;
  final int duplicateRecords;
  final int invalidRecords;
  final bool truncatedByLimit;

  Map<String, Object?> toJson() => {
    'work': work,
    'projectId': projectId,
    'sourcePath': sourcePath,
    'inputRecords': inputRecords,
    'indexedRecords': indexedRecords,
    'writtenRecords': writtenRecords,
    'resumedFromOrdinal': resumedFromOrdinal,
    'duplicateRecords': duplicateRecords,
    'invalidRecords': invalidRecords,
    'truncatedByLimit': truncatedByLimit,
  };
}

class NovelCorpusImportProgress {
  const NovelCorpusImportProgress({
    required this.work,
    required this.nextOrdinal,
    required this.selectedRecords,
    required this.complete,
  });

  final String work;
  final int nextOrdinal;
  final int selectedRecords;
  final bool complete;
}

class NovelCorpusImportReport {
  const NovelCorpusImportReport({
    required this.corpusRootPath,
    required this.sourceFileName,
    required this.limitPerWork,
    required this.batchSize,
    required this.elapsedMs,
    required this.works,
  });

  final String corpusRootPath;
  final String sourceFileName;
  final int limitPerWork;
  final int batchSize;
  final int elapsedMs;
  final List<NovelCorpusWorkImportReport> works;

  int get indexedRecords =>
      works.fold(0, (total, work) => total + work.indexedRecords);
  int get duplicateRecords =>
      works.fold(0, (total, work) => total + work.duplicateRecords);
  int get invalidRecords =>
      works.fold(0, (total, work) => total + work.invalidRecords);

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'corpusRootPath': corpusRootPath,
    'sourceFileName': sourceFileName,
    'limitPerWork': limitPerWork,
    'batchSize': batchSize,
    'elapsedMs': elapsedMs,
    'indexedRecords': indexedRecords,
    'duplicateRecords': duplicateRecords,
    'invalidRecords': invalidRecords,
    'works': [for (final work in works) work.toJson()],
  };
}
