/// A single search result from OpenViking.
class OpenVikingSearchResult {
  const OpenVikingSearchResult({
    required this.path,
    required this.content,
    required this.score,
    this.metadata = const {},
  });

  final String path;
  final String content;
  final double score;
  final Map<String, Object?> metadata;

  factory OpenVikingSearchResult.fromJson(Map<String, Object?> json) {
    return OpenVikingSearchResult(
      path: json['path']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      score: _parseDouble(json['score']),
      metadata: json['metadata'] is Map
          ? Map<String, Object?>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, Object?> toJson() => {
        'path': path,
        'content': content,
        'score': score,
        'metadata': metadata,
      };
}

/// Metadata about a resource stored in OpenViking.
class OpenVikingResourceInfo {
  const OpenVikingResourceInfo({
    required this.path,
    required this.type,
    this.size = 0,
    this.modifiedAt = '',
  });

  final String path;
  final String type;
  final int size;
  final String modifiedAt;

  factory OpenVikingResourceInfo.fromJson(Map<String, Object?> json) {
    return OpenVikingResourceInfo(
      path: json['path']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
      size: _parseInt(json['size']),
      modifiedAt: json['modifiedAt']?.toString() ?? '',
    );
  }
}

/// Response from a find/search operation.
class OpenVikingFindResponse {
  const OpenVikingFindResponse({
    required this.results,
    this.totalCount = 0,
  });

  final List<OpenVikingSearchResult> results;
  final int totalCount;

  factory OpenVikingFindResponse.fromJson(Map<String, Object?> json) {
    final resultsRaw = json['results'];
    final results = resultsRaw is List
        ? [
            for (final r in resultsRaw)
              if (r is Map)
                OpenVikingSearchResult.fromJson(
                  Map<String, Object?>.from(r),
                ),
          ]
        : <OpenVikingSearchResult>[];
    return OpenVikingFindResponse(
      results: results,
      totalCount: _parseInt(json['totalCount']),
    );
  }
}

double _parseDouble(Object? raw) {
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}

int _parseInt(Object? raw) {
  if (raw is int) return raw;
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
