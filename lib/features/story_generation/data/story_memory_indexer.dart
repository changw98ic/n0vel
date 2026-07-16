import '../domain/memory_models.dart';
import '../domain/contracts/memory_policy.dart';
import '../domain/scene_models.dart';

/// Converts project records, outline data, scene context, generated scenes,
/// and reviews into memory chunks.
class StoryMemoryIndexer {
  static const contextEnrichmentProducer = 'context-enrichment';
  static const generationNamespaceVersion = 'memory-generation-v1';

  static String generationNamespacePrefix({
    required String projectId,
    required String scopeId,
    required String producer,
  }) {
    final normalizedProducer = producer.trim();
    if (normalizedProducer.isEmpty) {
      throw ArgumentError.value(producer, 'producer', 'must not be empty');
    }
    return '${[generationNamespaceVersion, Uri.encodeComponent(projectId), Uri.encodeComponent(scopeId), Uri.encodeComponent(normalizedProducer)].join('/')}/';
  }

  static String generationChunkId({
    required String projectId,
    required String scopeId,
    required String producer,
    required MemorySourceKind kind,
    required int kindIndex,
  }) =>
      '${generationNamespacePrefix(projectId: projectId, scopeId: scopeId, producer: producer)}'
      '${kind.name}/$kindIndex';

  static bool ownsGenerationChunkId({
    required String id,
    required String projectId,
    required String scopeId,
    required String producer,
    required MemorySourceKind kind,
  }) {
    final prefix =
        '${generationNamespacePrefix(projectId: projectId, scopeId: scopeId, producer: producer)}'
        '${kind.name}/';
    if (!id.startsWith(prefix)) return false;
    return RegExp(r'^[0-9]+$').hasMatch(id.substring(prefix.length));
  }

  /// Indexes a project material snapshot into memory chunks.
  List<StoryMemoryChunk> index({
    required String projectId,
    required String scopeId,
    required ProjectMaterialSnapshot materials,
    String producer = '',
    int? nowMs,
  }) {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final chunks = <StoryMemoryChunk>[];
    final kindIndexes = <MemorySourceKind, int>{};
    var seq = 0;

    String chunkId(MemorySourceKind kind, String legacyCode) {
      if (producer.trim().isEmpty) return '${projectId}_${legacyCode}_$seq';
      final kindIndex = kindIndexes.update(
        kind,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      return generationChunkId(
        projectId: projectId,
        scopeId: scopeId,
        producer: producer,
        kind: kind,
        kindIndex: kindIndex,
      );
    }

    for (final fact in materials.worldFacts) {
      if (fact.trim().isEmpty) continue;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.worldFact, 'wf'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.worldFact,
          content: fact,
          tier: MemoryTier.canon,
          producer: producer,
          tags: _extractWorldTags(fact),
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    for (final profile in materials.characterProfiles) {
      if (profile.trim().isEmpty) continue;
      final privateProfile = _privateProfile(profile, seq);
      final isPrivate = privateProfile != null;
      final content = privateProfile?.content ?? profile;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.characterProfile, 'cp'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.characterProfile,
          content: content,
          tier: MemoryTier.character,
          producer: producer,
          tags: _extractCharTags(content),
          visibility: isPrivate
              ? MemoryVisibility.agentPrivate
              : MemoryVisibility.publicObservable,
          ownerId: privateProfile?.ownerId ?? '',
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    for (final hint in materials.relationshipHints) {
      if (hint.trim().isEmpty) continue;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.relationshipHint, 'rh'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.relationshipHint,
          content: hint,
          tier: MemoryTier.character,
          producer: producer,
          tags: _extractRelationshipTags(hint),
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    for (final beat in materials.outlineBeats) {
      if (beat.trim().isEmpty) continue;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.outlineBeat, 'ob'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.outlineBeat,
          content: beat,
          tier: MemoryTier.canon,
          producer: producer,
          tags: _extractBeatTags(beat),
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    for (final summary in materials.sceneSummaries) {
      if (summary.trim().isEmpty) continue;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.sceneSummary, 'ss'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.sceneSummary,
          content: summary,
          producer: producer,
          tags: _extractSceneTags(summary),
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    for (final state in materials.acceptedStates) {
      if (state.trim().isEmpty) continue;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.acceptedState, 'as'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.acceptedState,
          content: state,
          producer: producer,
          tags: _extractStateTags(state),
          priority: 5,
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    for (final finding in materials.reviewFindings) {
      if (finding.trim().isEmpty) continue;
      chunks.add(
        _chunk(
          id: chunkId(MemorySourceKind.reviewFinding, 'rf'),
          projectId: projectId,
          scopeId: scopeId,
          kind: MemorySourceKind.reviewFinding,
          content: finding,
          tier: MemoryTier.draft,
          producer: producer,
          tags: _extractReviewTags(finding),
          nowMs: ts + seq,
        ),
      );
      seq++;
    }

    return chunks;
  }

  StoryMemoryChunk _chunk({
    required String id,
    required String projectId,
    required String scopeId,
    required MemorySourceKind kind,
    required String content,
    MemoryTier tier = MemoryTier.scene,
    String producer = '',
    List<String> tags = const [],
    MemoryVisibility visibility = MemoryVisibility.publicObservable,
    String ownerId = '',
    int priority = 3,
    required int nowMs,
  }) {
    return StoryMemoryChunk(
      id: id,
      projectId: projectId,
      scopeId: scopeId,
      kind: kind,
      content: content,
      tier: tier,
      producer: producer.trim(),
      sourceRefs: [MemorySourceRef(sourceId: id, sourceType: kind)],
      rootSourceIds: [id],
      visibility: visibility,
      ownerId: ownerId,
      tags: tags,
      priority: priority,
      tokenCostEstimate: _estimateTokens(content),
      createdAtMs: nowMs,
    );
  }

  int _estimateTokens(String text) {
    return (text.length / 3.5).ceil();
  }

  List<String> _extractWorldTags(String text) {
    final tags = <String>['world'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  List<String> _extractCharTags(String text) {
    final tags = <String>['character'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  List<String> _extractBeatTags(String text) {
    final tags = <String>['outline'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  List<String> _extractSceneTags(String text) {
    final tags = <String>['scene'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  List<String> _extractStateTags(String text) {
    final tags = <String>['state', 'accepted'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  List<String> _extractRelationshipTags(String text) {
    final tags = <String>['relationship'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  List<String> _extractReviewTags(String text) {
    final tags = <String>['review'];
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.startsWith('#')) tags.add(word.substring(1));
    }
    return tags;
  }

  _PrivateProfile? _privateProfile(String profile, int sequence) {
    final trimmed = profile.trim();
    if (!trimmed.startsWith('@private:')) return null;
    final remainder = trimmed.substring('@private:'.length).trim();
    final separator = remainder.indexOf(':');
    if (separator <= 0) {
      return _PrivateProfile(
        ownerId: 'private-profile-$sequence',
        content: remainder,
      );
    }
    return _PrivateProfile(
      ownerId: remainder.substring(0, separator).trim(),
      content: remainder.substring(separator + 1).trim(),
    );
  }
}

class _PrivateProfile {
  const _PrivateProfile({required this.ownerId, required this.content});

  final String ownerId;
  final String content;
}
