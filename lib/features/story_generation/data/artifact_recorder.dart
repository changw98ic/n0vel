import 'dart:io';

/// A single pipeline artifact produced during story generation.
///
/// Captures what happened at a given pipeline stage so downstream consumers
/// can inspect, debug, or trace the provenance of generated content.
class PipelineArtifact {
  const PipelineArtifact({
    required this.id,
    required this.sceneId,
    required this.chapterId,
    required this.artifactType,
    required this.sourceId,
    required this.data,
    required this.recordedAtMs,
    required this.sourceTraceIds,
  });

  final String id;
  final String sceneId;
  final String chapterId;

  /// One of: 'outline', 'director_cue', 'role_packet', 'event', 'cognition',
  /// 'transition', 'review'.
  final String artifactType;

  /// ID of the source component that produced this artifact.
  final String sourceId;

  /// Arbitrary payload from the source component.
  final Map<String, Object?> data;

  /// Epoch millis when this artifact was recorded.
  final int recordedAtMs;

  /// IDs of upstream artifacts that contributed to this one.
  final List<String> sourceTraceIds;

  PipelineArtifact copyWith({
    String? id,
    String? sceneId,
    String? chapterId,
    String? artifactType,
    String? sourceId,
    Map<String, Object?>? data,
    int? recordedAtMs,
    List<String>? sourceTraceIds,
  }) {
    return PipelineArtifact(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      chapterId: chapterId ?? this.chapterId,
      artifactType: artifactType ?? this.artifactType,
      sourceId: sourceId ?? this.sourceId,
      data: data ?? this.data,
      recordedAtMs: recordedAtMs ?? this.recordedAtMs,
      sourceTraceIds: sourceTraceIds ?? this.sourceTraceIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'chapterId': chapterId,
      'artifactType': artifactType,
      'sourceId': sourceId,
      'data': data,
      'recordedAtMs': recordedAtMs,
      'sourceTraceIds': sourceTraceIds,
    };
  }

  static PipelineArtifact fromJson(Map<Object?, Object?> json) {
    return PipelineArtifact(
      id: json['id'] as String,
      sceneId: json['sceneId'] as String,
      chapterId: json['chapterId'] as String,
      artifactType: json['artifactType'] as String,
      sourceId: json['sourceId'] as String,
      data: (json['data'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
          const {},
      recordedAtMs: json['recordedAtMs'] as int,
      sourceTraceIds: (json['sourceTraceIds'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }
}

class ArtifactRecorder {
  ArtifactRecorder({Directory? rootDirectory})
    : rootDirectory =
          rootDirectory ?? Directory(ArtifactRecorder.defaultRootPath),
      _rootUri = Uri.directory(
        (rootDirectory ?? Directory(ArtifactRecorder.defaultRootPath))
            .absolute
            .path,
        windows: Platform.isWindows,
      );

  static const String defaultRootPath =
      'artifacts/real_validation/three_chapter_run';

  final Directory rootDirectory;
  final Uri _rootUri;

  Future<void> recordChapterText({
    required String chapterId,
    required String text,
  }) {
    final safeChapterId = _validateChapterId(chapterId);
    final file = _resolveFileWithinRoot('chapters/$safeChapterId.md');
    return _writeFile(file, text);
  }

  Future<void> recordReport({
    required String relativePath,
    required String content,
  }) {
    final file = _resolveFileWithinRoot(relativePath);
    return _writeFile(file, content);
  }

  Future<void> _writeFile(File file, String content) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  String _validateChapterId(String chapterId) {
    final normalizedChapterId = chapterId.trim();
    if (normalizedChapterId.isEmpty ||
        normalizedChapterId == '.' ||
        normalizedChapterId == '..' ||
        normalizedChapterId.contains('/') ||
        normalizedChapterId.contains(r'\')) {
      throw ArgumentError.value(
        chapterId,
        'chapterId',
        'must be a single file-safe identifier within ${rootDirectory.path}',
      );
    }
    return normalizedChapterId;
  }

  File _resolveFileWithinRoot(String relativePath) {
    final normalizedRelativePath = _normalizeRelativePath(relativePath);
    if (normalizedRelativePath.isEmpty) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must not be empty',
      );
    }

    final candidateUri = _rootUri.resolve(normalizedRelativePath);
    final rootPath = _normalizeForComparison(
      _rootUri.toFilePath(windows: Platform.isWindows),
      isDirectory: true,
    );
    final candidatePath = _normalizeForComparison(
      candidateUri.toFilePath(windows: Platform.isWindows),
    );
    if (!_isWithinRoot(rootPath, candidatePath)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must stay within ${rootDirectory.path}',
      );
    }
    return File(candidatePath);
  }

  String _normalizeRelativePath(String value) {
    return value.trim().replaceAll(r'\', '/');
  }

  String _normalizeForComparison(String path, {bool isDirectory = false}) {
    var normalized = path;
    if (Platform.isWindows) {
      normalized = normalized.replaceAll('/', r'\').toLowerCase();
      final separator = Platform.pathSeparator;
      if (isDirectory && !normalized.endsWith(separator)) {
        normalized = '$normalized$separator';
      }
      return normalized;
    }

    normalized = normalized.replaceAll(r'\', '/');
    if (isDirectory && !normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }

  bool _isWithinRoot(String rootPath, String candidatePath) {
    return candidatePath.startsWith(rootPath);
  }

  // --- In-memory pipeline artifact tracking ---

  final List<PipelineArtifact> _artifacts = [];

  /// Record a pipeline artifact with source tracing.
  void recordArtifact(PipelineArtifact artifact) {
    _artifacts.add(artifact);
  }

  /// Get all artifacts for a scene, in recording order.
  List<PipelineArtifact> artifactsForScene(String sceneId) {
    return _artifacts
        .where((a) => a.sceneId == sceneId)
        .toList();
  }

  /// Get artifacts by type.
  List<PipelineArtifact> artifactsByType(String artifactType) {
    return _artifacts
        .where((a) => a.artifactType == artifactType)
        .toList();
  }

  /// Get the full trace chain for an artifact, walking [sourceTraceIds].
  ///
  /// Returns artifacts ordered from root to leaf. The starting artifact is
  /// included as the last element.
  List<PipelineArtifact> traceChain(String artifactId) {
    final byId = <String, PipelineArtifact>{};
    for (final a in _artifacts) {
      byId[a.id] = a;
    }

    final chain = <PipelineArtifact>[];
    var current = byId[artifactId];
    while (current != null) {
      chain.insert(0, current);
      if (current.sourceTraceIds.isEmpty) break;
      current = byId[current.sourceTraceIds.first];
    }
    return chain;
  }

  /// Clear artifacts for a scene.
  void clearSceneArtifacts(String sceneId) {
    _artifacts.removeWhere((a) => a.sceneId == sceneId);
  }

  /// Get concise summary for debugging.
  String debugSummary(String sceneId) {
    final sceneArtifacts = artifactsForScene(sceneId);
    if (sceneArtifacts.isEmpty) return '[]';

    final typeCounts = <String, int>{};
    for (final a in sceneArtifacts) {
      typeCounts[a.artifactType] = (typeCounts[a.artifactType] ?? 0) + 1;
    }

    final parts = typeCounts.entries
        .map((e) => '${e.key}:${e.value}')
        .join(' ');
    return '$sceneId [$parts]';
  }
}
