abstract interface class StorePayloadContributor {
  String get filename;

  Map<String, Object?> exportJson();

  void importJson(Map<String, Object?> data);
}

abstract interface class AsyncStorePayloadContributor {
  String get filename;

  Future<Map<String, Object?>?> exportJson(String projectId);

  Future<void> importJson(String projectId, Map<String, Object?> data);

  Iterable<StorePayloadSidecar> exportSidecars(Map<String, Object?> data);
}

final class JsonStorePayloadContributor implements StorePayloadContributor {
  const JsonStorePayloadContributor({
    required this.filename,
    required Map<String, Object?> Function() exportJson,
    required void Function(Map<String, Object?> data) importJson,
  }) : _exportJson = exportJson,
       _importJson = importJson;

  @override
  final String filename;

  final Map<String, Object?> Function() _exportJson;
  final void Function(Map<String, Object?> data) _importJson;

  @override
  Map<String, Object?> exportJson() => _exportJson();

  @override
  void importJson(Map<String, Object?> data) => _importJson(data);
}

final class AsyncJsonStorePayloadContributor
    implements AsyncStorePayloadContributor {
  const AsyncJsonStorePayloadContributor({
    required this.filename,
    required Future<Map<String, Object?>?> Function(String projectId)
    exportJson,
    required Future<void> Function(String projectId, Map<String, Object?> data)
    importJson,
    Iterable<StorePayloadSidecar> Function(Map<String, Object?> data)?
    exportSidecars,
  }) : _exportJson = exportJson,
       _importJson = importJson,
       _exportSidecars = exportSidecars;

  @override
  final String filename;

  final Future<Map<String, Object?>?> Function(String projectId) _exportJson;
  final Future<void> Function(String projectId, Map<String, Object?> data)
  _importJson;
  final Iterable<StorePayloadSidecar> Function(Map<String, Object?> data)?
  _exportSidecars;

  @override
  Future<Map<String, Object?>?> exportJson(String projectId) {
    return _exportJson(projectId);
  }

  @override
  Future<void> importJson(String projectId, Map<String, Object?> data) {
    return _importJson(projectId, data);
  }

  @override
  Iterable<StorePayloadSidecar> exportSidecars(Map<String, Object?> data) {
    return _exportSidecars?.call(data) ?? const [];
  }
}

enum StorePayloadSidecarEncoding { json, text }

final class StorePayloadSidecar {
  const StorePayloadSidecar.json({
    required this.filename,
    required Map<String, Object?> data,
  }) : encoding = StorePayloadSidecarEncoding.json,
       jsonData = data,
       text = null;

  const StorePayloadSidecar.text({
    required this.filename,
    required String content,
  }) : encoding = StorePayloadSidecarEncoding.text,
       jsonData = null,
       text = content;

  final String filename;
  final StorePayloadSidecarEncoding encoding;
  final Map<String, Object?>? jsonData;
  final String? text;
}
