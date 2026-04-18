import 'package:yaml/yaml.dart';

class WriterGuidanceIndex {
  final String charterAssetPath;
  final List<String> globalAssets;
  final List<WriterGuidanceEntry> modules;
  final List<WriterGuidanceEntry> paths;
  final List<WriterGuidanceEntry> skills;
  final List<WriterGuidanceEntry> agents;
  final List<WriterGuidanceEntry> teams;
  final List<WriterGuidanceEntry> hooks;

  const WriterGuidanceIndex({
    required this.charterAssetPath,
    required this.globalAssets,
    required this.modules,
    required this.paths,
    required this.skills,
    required this.agents,
    required this.teams,
    required this.hooks,
  });

  factory WriterGuidanceIndex.parse(String yamlText) {
    final root = loadYaml(yamlText) as YamlMap? ?? YamlMap();

    return WriterGuidanceIndex(
      charterAssetPath: (root['charter'] as String?)?.trim() ?? 'writer.md',
      globalAssets: _parseStringList(root['global']),
      modules: _parseEntries(root['modules'], matchKey: 'triggers'),
      paths: _parseEntries(root['paths'], matchKey: 'matches'),
      skills: _parseEntries(root['skills'], matchKey: 'triggers'),
      agents: _parseEntries(root['agents']),
      teams: _parseEntries(root['teams']),
      hooks: _parseEntries(root['hooks']),
    );
  }

  WriterGuidanceEntry? findAgent(String id) => _findById(agents, id);
  WriterGuidanceEntry? findSkill(String id) => _findById(skills, id);
  WriterGuidanceEntry? findTeam(String id) => _findById(teams, id);
  WriterGuidanceEntry? findHook(String id) => _findById(hooks, id);

  WriterGuidanceEntry? _findById(List<WriterGuidanceEntry> entries, String id) {
    for (final entry in entries) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  static List<String> _parseStringList(Object? value) {
    if (value is YamlList) {
      return value.map((item) => item.toString().trim()).toList();
    }
    return const [];
  }

  static List<WriterGuidanceEntry> _parseEntries(
    Object? value, {
    String? matchKey,
  }) {
    if (value is! YamlList) {
      return const [];
    }

    return value
        .whereType<YamlMap>()
        .map((map) {
          final id = (map['id'] as String?)?.trim() ?? '';
          final assetPath = (map['file'] as String?)?.trim() ?? '';
          final matchers = matchKey == null
              ? const <String>[]
              : _parseStringList(map[matchKey]);
          return WriterGuidanceEntry(
            id: id,
            assetPath: assetPath,
            matchers: matchers,
          );
        })
        .where((entry) => entry.id.isNotEmpty && entry.assetPath.isNotEmpty)
        .toList();
  }
}

class WriterGuidanceEntry {
  final String id;
  final String assetPath;
  final List<String> matchers;

  const WriterGuidanceEntry({
    required this.id,
    required this.assetPath,
    required this.matchers,
  });

  bool matchesPrompt(String haystack) {
    for (final matcher in matchers) {
      if (haystack.contains(matcher.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  bool matchesPaths(List<String> runtimePaths) {
    for (final runtimePath in runtimePaths) {
      for (final matcher in matchers) {
        if (runtimePath.startsWith(matcher)) {
          return true;
        }
      }
    }
    return false;
  }
}
