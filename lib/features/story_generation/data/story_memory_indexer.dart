import '../domain/memory_models.dart';
import '../domain/scene_models.dart';

/// Converts project records, outline data, scene context, generated scenes,
/// and reviews into memory chunks.
class StoryMemoryIndexer {
  /// Indexes a project material snapshot into memory chunks.
  List<StoryMemoryChunk> index({
    required String projectId,
    required String scopeId,
    required ProjectMaterialSnapshot materials,
    int? nowMs,
  }) {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final chunks = <StoryMemoryChunk>[];
    var seq = 0;

    for (final fact in materials.worldFacts) {
      if (fact.trim().isEmpty) continue;
      chunks.add(_chunk(
        id: '${projectId}_wf_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.worldFact,
        content: fact,
        tags: _extractWorldTags(fact),
        nowMs: ts + seq,
      ));
      seq++;
    }

    for (final profile in materials.characterProfiles) {
      if (profile.trim().isEmpty) continue;
      final isPrivate = profile.trim().startsWith('@private:');
      final content =
          isPrivate ? profile.trim().substring('@private:'.length).trim() : profile;
      chunks.add(_chunk(
        id: '${projectId}_cp_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.characterProfile,
        content: content,
        tags: _extractCharTags(content),
        visibility: isPrivate
            ? MemoryVisibility.agentPrivate
            : MemoryVisibility.publicObservable,
        nowMs: ts + seq,
      ));
      seq++;
    }

    for (final hint in materials.relationshipHints) {
      if (hint.trim().isEmpty) continue;
      chunks.add(_chunk(
        id: '${projectId}_rh_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.relationshipHint,
        content: hint,
        tags: _extractRelationshipTags(hint),
        nowMs: ts + seq,
      ));
      seq++;
    }

    for (final beat in materials.outlineBeats) {
      if (beat.trim().isEmpty) continue;
      chunks.add(_chunk(
        id: '${projectId}_ob_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.outlineBeat,
        content: beat,
        tags: _extractBeatTags(beat),
        nowMs: ts + seq,
      ));
      seq++;
    }

    for (final summary in materials.sceneSummaries) {
      if (summary.trim().isEmpty) continue;
      chunks.add(_chunk(
        id: '${projectId}_ss_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.sceneSummary,
        content: summary,
        tags: _extractSceneTags(summary),
        nowMs: ts + seq,
      ));
      seq++;
    }

    for (final state in materials.acceptedStates) {
      if (state.trim().isEmpty) continue;
      chunks.add(_chunk(
        id: '${projectId}_as_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.acceptedState,
        content: state,
        tags: _extractStateTags(state),
        priority: 5,
        nowMs: ts + seq,
      ));
      seq++;
    }

    for (final finding in materials.reviewFindings) {
      if (finding.trim().isEmpty) continue;
      chunks.add(_chunk(
        id: '${projectId}_rf_$seq',
        projectId: projectId,
        scopeId: scopeId,
        kind: MemorySourceKind.reviewFinding,
        content: finding,
        tags: _extractReviewTags(finding),
        nowMs: ts + seq,
      ));
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
    List<String> tags = const [],
    MemoryVisibility visibility = MemoryVisibility.publicObservable,
    int priority = 3,
    required int nowMs,
  }) {
    return StoryMemoryChunk(
      id: id,
      projectId: projectId,
      scopeId: scopeId,
      kind: kind,
      content: content,
      sourceRefs: [
        MemorySourceRef(sourceId: id, sourceType: kind),
      ],
      rootSourceIds: [id],
      visibility: visibility,
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
}
