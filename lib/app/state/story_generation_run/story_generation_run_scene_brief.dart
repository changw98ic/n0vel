part of '../story_generation_run_store.dart';

extension _StoryGenerationRunSceneBrief on StoryGenerationRunStore {
  List<AuthorFeedbackItem> _activeRevisionRequestsForCurrentScene({
    required String chapterId,
    required String sceneId,
  }) {
    return _authorFeedbackStore?.activeRevisionRequestsForScene(
          chapterId: chapterId,
          sceneId: sceneId,
        ) ??
        const <AuthorFeedbackItem>[];
  }

  Map<String, Object?> _runtimeMetadata({
    List<AuthorFeedbackItem> revisionRequests = const [],
    String? rulesOverride,
    List<Map<String, Object?>> continuityLedger = const [],
  }) {
    final localOnly =
        allowLocalOnlyFallback && !_settingsStore.hasReadyConfiguration;
    final revisionNotes = [
      for (final request in revisionRequests)
        if (request.note.trim().isNotEmpty) request.note.trim(),
      if (rulesOverride != null && rulesOverride.trim().isNotEmpty)
        rulesOverride.trim(),
    ];
    return {
      'structuredRoleplayPipeline': true,
      'roleplayRounds': 1,
      'reviewMode': 'blocking',
      if (revisionNotes.isNotEmpty)
        'authorRevisionRequests': List<String>.unmodifiable(revisionNotes),
      // An empty ledger is valid evidence for the first scene. Omitting the
      // key would make formal execution indistinguishable from a producer
      // that forgot to load continuity state, so every production run carries
      // the explicit (possibly empty) prefix it actually observed.
      'continuityLedger': <Object?>[
        for (final entry in continuityLedger)
          Map<String, Object?>.unmodifiable(entry),
      ],
      if (localOnly) 'localDirectorOnly': true,
      if (localOnly) 'localStructuredRoleplayOnly': true,
      if (localOnly) 'localEditorialOnly': true,
      if (localOnly) 'localReviewOnly': true,
      if (formalEvaluation) ...FormalEvaluationPolicy.runtimeMetadata(),
    };
  }

  List<Map<String, Object?>> _committedContinuityLedgerBefore(
    String currentSceneId,
  ) {
    final ledger = _generationLedger;
    if (ledger == null) return const <Map<String, Object?>>[];
    // Workspace order is the production scene-prefix authority. Outline beats
    // may describe intent, but they do not define the order of persisted scene
    // identities and therefore cannot safely reorder continuity state.
    final priorSceneIds = <String>[];
    for (final scene in _workspaceStore.scenes) {
      if (scene.id == currentSceneId) break;
      priorSceneIds.add(scene.id);
    }
    if (priorSceneIds.isEmpty) return const <Map<String, Object?>>[];
    return ledger.loadCommittedContinuityLedger(
      projectId: _workspaceStore.currentProjectId,
      sourceSceneIds: priorSceneIds,
    );
  }

  ProjectMaterialSnapshot _materialsWithContinuityLedger(
    ProjectMaterialSnapshot base,
    Object? rawLedger,
  ) {
    if (rawLedger is! List || rawLedger.isEmpty) return base;
    final stateEntries = <String>[];
    for (final rawEntry in rawLedger) {
      if (rawEntry is! Map) continue;
      final entityId = rawEntry['entityId']?.toString().trim() ?? '';
      final holder = rawEntry['holder']?.toString().trim() ?? '';
      final location = rawEntry['location']?.toString().trim() ?? '';
      final status = rawEntry['status']?.toString().trim() ?? '';
      final source = rawEntry['sourceSceneId']?.toString().trim() ?? '';
      final aliases = rawEntry['aliases'] is List
          ? (rawEntry['aliases'] as List)
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .join('/')
          : '';
      if (entityId.isEmpty) continue;
      stateEntries.add(
        '[连续性状态] $entityId（$aliases）持有人：$holder；地点：$location；'
        '状态：$status；来源：$source',
      );
    }
    if (stateEntries.isEmpty) return base;
    return ProjectMaterialSnapshot(
      worldFacts: base.worldFacts,
      characterProfiles: base.characterProfiles,
      relationshipHints: base.relationshipHints,
      outlineBeats: base.outlineBeats,
      sceneSummaries: base.sceneSummaries,
      acceptedStates: <String>[...base.acceptedStates, ...stateEntries],
      reviewFindings: base.reviewFindings,
    );
  }

  String _sceneLabel() {
    return '${_workspaceStore.currentProject.title} / ${_workspaceStore.currentScene.displayLocation}';
  }
}
