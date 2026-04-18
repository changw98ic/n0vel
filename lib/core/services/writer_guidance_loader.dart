import 'package:flutter/foundation.dart' show FlutterError, debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'writer_guidance_index.dart';

/// 校验结果
class WriterGuidanceValidationResult {
  final List<String> missingAssets;
  final List<String> warnings;

  const WriterGuidanceValidationResult({
    this.missingAssets = const [],
    this.warnings = const [],
  });

  bool get isValid => missingAssets.isEmpty;

  @override
  String toString() {
    if (isValid && warnings.isEmpty) return 'WriterGuidanceIndex: valid';
    final parts = <String>[];
    if (missingAssets.isNotEmpty) {
      parts.add('Missing: ${missingAssets.join(", ")}');
    }
    if (warnings.isNotEmpty) {
      parts.add('Warnings: ${warnings.join(", ")}');
    }
    return 'WriterGuidanceIndex: ${parts.join("; ")}';
  }
}

class WriterGuidanceLoader {
  static const String _indexAsset = '.writer/memory/index.yaml';

  String? _cachedCharter;
  WriterGuidanceIndex? _cachedIndex;
  final Map<String, String> _assetCache = {};

  /// 校验 index.yaml 引用的所有资源文件是否存在
  Future<WriterGuidanceValidationResult> validateIndex() async {
    final index = await loadIndex();
    final missing = <String>[];
    final warnings = <String>[];

    // 检查 charter
    if (index.charterAssetPath.isNotEmpty) {
      if (!await _assetExists(index.charterAssetPath)) {
        missing.add(index.charterAssetPath);
      }
    }

    // 检查 global assets
    for (final path in index.globalAssets) {
      if (!await _assetExists(path)) {
        missing.add(path);
      }
    }

    // 检查 modules / skills / paths / agents / teams / hooks
    for (final entry in [
      ...index.modules,
      ...index.skills,
      ...index.paths,
      ...index.agents,
      ...index.teams,
      ...index.hooks,
    ]) {
      if (entry.assetPath.isEmpty) {
        warnings.add('${entry.id}: empty assetPath');
        continue;
      }
      if (!await _assetExists(entry.assetPath)) {
        missing.add(entry.assetPath);
      }
    }

    if (missing.isNotEmpty) {
      debugPrint('[WriterGuidance] Validation failed: $this');
      for (final path in missing) {
        debugPrint('[WriterGuidance]   MISSING: $path');
      }
    }

    return WriterGuidanceValidationResult(
      missingAssets: missing,
      warnings: warnings,
    );
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.loadString(path);
      return true;
    } on FlutterError {
      return false;
    }
  }

  Future<WriterGuidanceIndex> loadIndex() async {
    if (_cachedIndex != null) {
      return _cachedIndex!;
    }
    final indexText = await _loadAsset(_indexAsset);
    _cachedIndex = WriterGuidanceIndex.parse(indexText);
    return _cachedIndex!;
  }

  Future<String> loadGlobalCharter() async {
    if (_cachedCharter != null) {
      return _cachedCharter!;
    }

    final index = await loadIndex();
    final parts = <String>[];

    final writer = await _loadAsset(index.charterAssetPath);
    if (writer.isNotEmpty) {
      parts.add(writer.trim());
    }

    for (final assetPath in index.globalAssets) {
      final globalMemory = await _loadAsset(assetPath);
      if (globalMemory.isNotEmpty) {
        parts.add(globalMemory.trim());
      }
    }

    _cachedCharter = parts.join('\n\n').trim();
    return _cachedCharter!;
  }

  Future<List<String>> loadModuleMemories(
    String prompt, {
    String? contextContent,
  }) async {
    final index = await loadIndex();
    return _loadMatchedAssets(
      entries: index.modules,
      prompt: prompt,
      contextContent: contextContent,
    );
  }

  Future<List<String>> loadSkillGuidance(
    String prompt, {
    String? contextContent,
  }) async {
    final index = await loadIndex();
    return _loadMatchedAssets(
      entries: index.skills,
      prompt: prompt,
      contextContent: contextContent,
    );
  }

  Future<List<String>> loadPathMemories(List<String> runtimePaths) async {
    if (runtimePaths.isEmpty) {
      return const [];
    }

    final index = await loadIndex();
    final matches = <String>[];
    for (final entry in index.paths) {
      if (!entry.matchesPaths(runtimePaths)) {
        continue;
      }
      final content = await _loadAsset(entry.assetPath);
      if (content.trim().isNotEmpty) {
        matches.add(content.trim());
      }
    }
    return matches;
  }

  Future<String> loadAgentGuidance(String agentId) async {
    final entry = (await loadIndex()).findAgent(agentId);
    if (entry == null) {
      return '';
    }
    return (await _loadAsset(entry.assetPath)).trim();
  }

  Future<String> loadSkillById(String skillId) async {
    final entry = (await loadIndex()).findSkill(skillId);
    if (entry == null) {
      return '';
    }
    return (await _loadAsset(entry.assetPath)).trim();
  }

  Future<String> loadTeamGuidance(String teamId) async {
    final entry = (await loadIndex()).findTeam(teamId);
    if (entry == null) {
      return '';
    }
    return (await _loadAsset(entry.assetPath)).trim();
  }

  Future<String> loadHookGuidance(String hookId) async {
    final entry = (await loadIndex()).findHook(hookId);
    if (entry == null) {
      return '';
    }
    return (await _loadAsset(entry.assetPath)).trim();
  }

  Future<List<String>> _loadMatchedAssets({
    required List<WriterGuidanceEntry> entries,
    required String prompt,
    String? contextContent,
  }) async {
    final haystack = '$prompt\n${contextContent ?? ''}'.toLowerCase();
    final matches = <String>[];

    for (final entry in entries) {
      if (!entry.matchesPrompt(haystack)) {
        continue;
      }
      final content = await _loadAsset(entry.assetPath);
      if (content.trim().isNotEmpty) {
        matches.add(content.trim());
      }
    }

    return matches;
  }

  Future<String> _loadAsset(String assetPath) async {
    final cached = _assetCache[assetPath];
    if (cached != null) {
      return cached;
    }
    try {
      final content = await rootBundle.loadString(assetPath);
      _assetCache[assetPath] = content;
      return content;
    } on FlutterError {
      _assetCache[assetPath] = '';
      return '';
    }
  }

  void clearCache() {
    _cachedCharter = null;
    _cachedIndex = null;
    _assetCache.clear();
  }
}
