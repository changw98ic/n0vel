enum StyleInputMode { questionnaire, json }

enum StyleWorkflowState {
  ready,
  empty,
  jsonError,
  unsupportedVersion,
  unknownFieldsIgnored,
  missingRequiredFields,
  validationFailed,
  maxProfilesReached,
  sceneOverrideNotice,
}

enum AuditIssueStatus { open, resolved, ignored }

enum AuditIssueFilter { all, open, resolved, ignored }

enum ProjectTransferState {
  ready,
  importSuccess,
  exportSuccess,
  overwriteSuccess,
  overwriteConfirm,
  invalidPackage,
  missingManifest,
  noExportableProject,
  majorVersionBlocked,
  minorVersionWarning,
}

String generateProjectId() =>
    'project-${DateTime.now().microsecondsSinceEpoch}';

String generateSceneId() => 'scene-${DateTime.now().microsecondsSinceEpoch}';

String generateScopedRecordId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

List<String> stringListFromRaw(Object? raw) {
  if (raw is! List) {
    return const <String>[];
  }
  return [
    for (final item in raw)
      if (item.toString().trim().isNotEmpty) item.toString(),
  ];
}

Map<String, Object?> stringObjectMapFromRaw(Object? raw) {
  if (raw is! Map) {
    return const <String, Object?>{};
  }
  return {for (final entry in raw.entries) entry.key.toString(): entry.value};
}

String _fallbackScopedRecordId(String prefix, Object? seed) {
  final normalized = seed?.toString().trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '-',
  );
  if (normalized == null || normalized.isEmpty) {
    return '$prefix-fallback';
  }
  return '$prefix-$normalized';
}

int _parseProjectOpenedAt(Object? raw) {
  return int.tryParse(raw?.toString() ?? '') ??
      DateTime.now().millisecondsSinceEpoch;
}

String _projectTagFor(int lastOpenedAtMs) {
  final delta = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(lastOpenedAtMs),
  );
  if (delta.inHours < 6) {
    return '刚刚打开';
  }
  if (delta.inDays < 1) {
    return '今天打开';
  }
  if (delta.inDays == 1) {
    return '昨天打开';
  }
  return '${delta.inDays} 天前打开';
}

AuditIssueStatus _decodeAuditIssueStatus(Object? raw) {
  return switch (raw?.toString()) {
    'resolved' => AuditIssueStatus.resolved,
    'ignored' => AuditIssueStatus.ignored,
    _ => AuditIssueStatus.open,
  };
}

class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.sceneId,
    required this.title,
    required this.genre,
    required this.summary,
    required this.recentLocation,
    required this.lastOpenedAtMs,
  });

  final String id;
  final String sceneId;
  final String title;
  final String genre;
  final String summary;
  final String recentLocation;
  final int lastOpenedAtMs;

  String get tag => _projectTagFor(lastOpenedAtMs);

  ProjectRecord copyWith({
    String? id,
    String? sceneId,
    String? title,
    String? genre,
    String? summary,
    String? recentLocation,
    int? lastOpenedAtMs,
  }) {
    return ProjectRecord(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      summary: summary ?? this.summary,
      recentLocation: recentLocation ?? this.recentLocation,
      lastOpenedAtMs: lastOpenedAtMs ?? this.lastOpenedAtMs,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'title': title,
      'genre': genre,
      'summary': summary,
      'recentLocation': recentLocation,
      'lastOpenedAtMs': lastOpenedAtMs,
    };
  }

  static ProjectRecord fromJson(Map<Object?, Object?> json) {
    return ProjectRecord(
      id: json['id']?.toString() ?? generateProjectId(),
      sceneId: json['sceneId']?.toString() ?? generateSceneId(),
      title: json['title']?.toString() ?? '未命名项目',
      genre: json['genre']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      recentLocation: json['recentLocation']?.toString() ?? '',
      lastOpenedAtMs: _parseProjectOpenedAt(json['lastOpenedAtMs']),
    );
  }
}

class SceneRecord {
  const SceneRecord({
    required this.id,
    required this.chapterLabel,
    required this.title,
    required this.summary,
  });

  final String id;
  final String chapterLabel;
  final String title;
  final String summary;

  String get displayLocation => '$chapterLabel · $title';

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'chapterLabel': chapterLabel,
      'title': title,
      'summary': summary,
    };
  }

  static SceneRecord fromJson(Map<Object?, Object?> json) {
    return SceneRecord(
      id: json['id']?.toString() ?? generateSceneId(),
      chapterLabel: json['chapterLabel']?.toString() ?? '第 1 章 / 场景 01',
      title: json['title']?.toString() ?? '等待命名',
      summary: json['summary']?.toString() ?? '等待补充场景目标、冲突和收束条件。',
    );
  }
}

class CharacterRecord {
  const CharacterRecord({
    this.id = '',
    required this.name,
    required this.role,
    required this.note,
    required this.need,
    required this.summary,
    this.referenceSummary = '',
    this.linkedSceneIds = const <String>[],
  });

  final String id;
  final String name;
  final String role;
  final String note;
  final String need;
  final String summary;
  final String referenceSummary;
  final List<String> linkedSceneIds;

  CharacterRecord copyWith({
    String? id,
    String? name,
    String? role,
    String? note,
    String? need,
    String? summary,
    String? referenceSummary,
    List<String>? linkedSceneIds,
  }) {
    return CharacterRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      note: note ?? this.note,
      need: need ?? this.need,
      summary: summary ?? this.summary,
      referenceSummary: referenceSummary ?? this.referenceSummary,
      linkedSceneIds: linkedSceneIds ?? this.linkedSceneIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'note': note,
      'need': need,
      'summary': summary,
      'referenceSummary': referenceSummary,
      'linkedSceneIds': linkedSceneIds,
    };
  }

  static CharacterRecord fromJson(Map<Object?, Object?> json) {
    return CharacterRecord(
      id:
          json['id']?.toString() ??
          _fallbackScopedRecordId('character', json['name']),
      name: json['name']?.toString() ?? '未命名角色',
      role: json['role']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      need: json['need']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      referenceSummary: json['referenceSummary']?.toString() ?? '',
      linkedSceneIds: stringListFromRaw(json['linkedSceneIds']),
    );
  }
}

class WorldNodeRecord {
  const WorldNodeRecord({
    this.id = '',
    required this.title,
    required this.location,
    required this.type,
    required this.detail,
    required this.summary,
    this.ruleSummary = '',
    this.referenceSummary = '',
    this.linkedSceneIds = const <String>[],
  });

  final String id;
  final String title;
  final String location;
  final String type;
  final String detail;
  final String summary;
  final String ruleSummary;
  final String referenceSummary;
  final List<String> linkedSceneIds;

  WorldNodeRecord copyWith({
    String? id,
    String? title,
    String? location,
    String? type,
    String? detail,
    String? summary,
    String? ruleSummary,
    String? referenceSummary,
    List<String>? linkedSceneIds,
  }) {
    return WorldNodeRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      type: type ?? this.type,
      detail: detail ?? this.detail,
      summary: summary ?? this.summary,
      ruleSummary: ruleSummary ?? this.ruleSummary,
      referenceSummary: referenceSummary ?? this.referenceSummary,
      linkedSceneIds: linkedSceneIds ?? this.linkedSceneIds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'type': type,
      'detail': detail,
      'summary': summary,
      'ruleSummary': ruleSummary,
      'referenceSummary': referenceSummary,
      'linkedSceneIds': linkedSceneIds,
    };
  }

  static WorldNodeRecord fromJson(Map<Object?, Object?> json) {
    return WorldNodeRecord(
      id:
          json['id']?.toString() ??
          _fallbackScopedRecordId('world', json['title']),
      title: json['title']?.toString() ?? '未命名节点',
      location: json['location']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      ruleSummary: json['ruleSummary']?.toString() ?? '',
      referenceSummary: json['referenceSummary']?.toString() ?? '',
      linkedSceneIds: stringListFromRaw(json['linkedSceneIds']),
    );
  }
}

class AuditIssueRecord {
  const AuditIssueRecord({
    this.id = '',
    required this.title,
    required this.evidence,
    required this.target,
    this.status = AuditIssueStatus.open,
    this.ignoreReason = '',
    this.lastAction = '等待处理',
  });

  final String id;
  final String title;
  final String evidence;
  final String target;
  final AuditIssueStatus status;
  final String ignoreReason;
  final String lastAction;

  bool get isOpen => status == AuditIssueStatus.open;

  AuditIssueRecord copyWith({
    String? id,
    String? title,
    String? evidence,
    String? target,
    AuditIssueStatus? status,
    String? ignoreReason,
    String? lastAction,
  }) {
    return AuditIssueRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      evidence: evidence ?? this.evidence,
      target: target ?? this.target,
      status: status ?? this.status,
      ignoreReason: ignoreReason ?? this.ignoreReason,
      lastAction: lastAction ?? this.lastAction,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'evidence': evidence,
      'target': target,
      'status': status.name,
      'ignoreReason': ignoreReason,
      'lastAction': lastAction,
    };
  }

  static AuditIssueRecord fromJson(Map<Object?, Object?> json) {
    return AuditIssueRecord(
      id:
          json['id']?.toString() ??
          _fallbackScopedRecordId('audit', json['title']),
      title: json['title']?.toString() ?? '未命名问题',
      evidence: json['evidence']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      status: _decodeAuditIssueStatus(json['status']),
      ignoreReason: json['ignoreReason']?.toString() ?? '',
      lastAction: json['lastAction']?.toString() ?? '等待处理',
    );
  }
}

class StyleProfileRecord {
  const StyleProfileRecord({
    this.id = '',
    required this.name,
    required this.source,
    required this.jsonData,
  });

  final String id;
  final String name;
  final String source;
  final Map<String, Object?> jsonData;

  StyleProfileRecord copyWith({
    String? id,
    String? name,
    String? source,
    Map<String, Object?>? jsonData,
  }) {
    return StyleProfileRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      jsonData: jsonData ?? this.jsonData,
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'name': name, 'source': source, 'jsonData': jsonData};
  }

  static StyleProfileRecord fromJson(Map<Object?, Object?> json) {
    return StyleProfileRecord(
      id:
          json['id']?.toString() ??
          _fallbackScopedRecordId('style', json['name']),
      name: json['name']?.toString() ?? '未命名风格',
      source: json['source']?.toString() ?? 'questionnaire',
      jsonData: stringObjectMapFromRaw(json['jsonData']),
    );
  }
}
