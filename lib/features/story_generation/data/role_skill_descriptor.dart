import 'dart:convert';

class RoleSkillDescriptor {
  const RoleSkillDescriptor({
    required this.skillId,
    required this.version,
    required this.inputSchema,
    required this.outputSchema,
    this.schemaVersion = 1,
    this.source = 'builtin',
    this.migrationPolicy = const {},
    this.supportsPrivateMemoryDeltas = false,
    this.compatibleSkillIds = const [],
    this.compatibilityNotes = const [],
  });

  final String skillId;
  final String version;
  final int schemaVersion;
  final String source;
  final Map<String, Object?> inputSchema;
  final Map<String, Object?> outputSchema;
  final Map<String, Object?> migrationPolicy;
  final bool supportsPrivateMemoryDeltas;
  final List<String> compatibleSkillIds;
  final List<String> compatibilityNotes;

  String get qualifiedId => '$skillId@$version';

  Map<String, Object?> toJson() {
    return {
      'skillId': skillId,
      'version': version,
      'schemaVersion': schemaVersion,
      'qualifiedId': qualifiedId,
      'source': source,
      'inputSchema': inputSchema,
      'outputSchema': outputSchema,
      'migrationPolicy': migrationPolicy,
      'supportsPrivateMemoryDeltas': supportsPrivateMemoryDeltas,
      'compatibleSkillIds': compatibleSkillIds,
      'compatibilityNotes': compatibilityNotes,
    };
  }

  factory RoleSkillDescriptor.fromJson(Map<String, Object?> json) {
    return RoleSkillDescriptor(
      skillId: _string(json['skillId']),
      version: _string(json['version']),
      schemaVersion: _int(json['schemaVersion'], fallback: 1),
      source: _string(json['source'], fallback: 'external'),
      inputSchema: _objectMap(json['inputSchema']),
      outputSchema: _objectMap(json['outputSchema']),
      migrationPolicy: _objectMap(json['migrationPolicy']),
      supportsPrivateMemoryDeltas: json['supportsPrivateMemoryDeltas'] == true,
      compatibleSkillIds: _stringList(json['compatibleSkillIds']),
      compatibilityNotes: _stringList(json['compatibilityNotes']),
    );
  }

  static String _string(Object? raw, {String fallback = ''}) {
    if (raw is! String) return fallback;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static int _int(Object? raw, {required int fallback}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? fallback;
    return fallback;
  }

  static Map<String, Object?> _objectMap(Object? raw) {
    if (raw is! Map) return const <String, Object?>{};
    return {for (final entry in raw.entries) entry.key.toString(): entry.value};
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return [
      for (final item in raw)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }
}

class RoleSkillManifest {
  const RoleSkillManifest({
    required this.packageId,
    required this.version,
    required this.skills,
  });

  final String packageId;
  final String version;
  final List<RoleSkillDescriptor> skills;

  factory RoleSkillManifest.fromJson(Map<String, Object?> json) {
    return RoleSkillManifest(
      packageId: RoleSkillDescriptor._string(
        json['packageId'],
        fallback: 'external-role-skills',
      ),
      version: RoleSkillDescriptor._string(json['version'], fallback: '0.0.0'),
      skills: [
        for (final raw in (json['skills'] as List<Object?>? ?? const []))
          if (raw is Map)
            RoleSkillDescriptor.fromJson(Map<String, Object?>.from(raw)),
      ],
    );
  }

  factory RoleSkillManifest.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Role skill manifest must be a JSON object.');
    }
    return RoleSkillManifest.fromJson(Map<String, Object?>.from(decoded));
  }
}
