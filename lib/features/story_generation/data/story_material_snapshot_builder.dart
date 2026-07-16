import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/state/story_outline_store.dart';
import '../../review_tasks/data/review_task_store.dart';
import '../data/scene_context_models.dart';
import '../domain/contracts/structured_profile.dart';
import '../domain/outline_plan_models.dart';
import '../domain/scene_models.dart';

/// Builds the bounded project-material view consumed by context enrichment.
class StoryMaterialSnapshotBuilder {
  const StoryMaterialSnapshotBuilder();

  /// Builds the production brief from the information already authored in the
  /// workspace and outline.  This deliberately does not invent relationship
  /// or private-state records: those need their own authoritative stores.
  SceneBrief buildSceneBrief({
    required AppWorkspaceStore workspaceStore,
    StoryOutlineStore? outlineStore,
    String? sceneSummaryOverride,
    Map<String, Object?> runtimeMetadata = const {},
    bool formalExecution = false,
  }) {
    final scene = workspaceStore.currentScene;
    final outline = outlineStore?.snapshot;
    final planMatch = _findScenePlan(outline, scene.id);
    final chapterPlan = _findChapterPlan(outline, planMatch);
    final legacyMatch = _findLegacyScene(
      outline,
      sceneId: scene.id,
      chapterLabel: scene.chapterLabel,
    );
    final planScenes = chapterPlan?.scenes;
    final workspaceScenes = _workspaceChapterScenes(
      workspaceStore,
      scene.chapterLabel,
    );
    final totalScenesInChapter = planScenes?.length ?? workspaceScenes.length;
    final sceneIndex = _sceneIndex(
      sceneId: scene.id,
      scenePlans: planScenes,
      scenes: workspaceScenes,
    );
    final castRecords = _castForScene(
      workspaceStore: workspaceStore,
      sceneId: scene.id,
      plan: planMatch,
    );
    final worldRecords = _worldNodesForScene(
      workspaceStore: workspaceStore,
      sceneId: scene.id,
      plan: planMatch,
    );
    final targetBeat = _targetBeat(
      planMatch,
      legacyMatch?.scene.summary ?? scene.summary,
    );
    final outlineBeatContract = _outlineBeatContract(
      plan: planMatch,
      legacyScene: legacyMatch?.scene,
    );
    final requireOutlineFidelity =
        planMatch?.metadata['requireOutlineFidelity'] == true ||
        legacyMatch?.scene.metadata['requireOutlineFidelity'] == true ||
        runtimeMetadata['requireOutlineFidelity'] == true;
    final metadata = <String, Object?>{
      ...legacyMatch?.scene.metadata ?? const <String, Object?>{},
      ...planMatch?.metadata ?? const <String, Object?>{},
      ...runtimeMetadata,
      if (outlineBeatContract.present)
        'requiredOutlineBeats': outlineBeatContract.value,
      if (requireOutlineFidelity) 'requireOutlineFidelity': true,
      if (planMatch != null) 'outlineScenePlanId': planMatch.id,
      if (chapterPlan != null) 'outlineChapterPlanId': chapterPlan.id,
      if (legacyMatch != null) ...{
        'outlineSceneSnapshotId': legacyMatch.scene.id,
        'outlineChapterSnapshotId': legacyMatch.chapter.id,
      },
      'sceneContext': {
        'sceneId': scene.id,
        'chapterLabel': scene.chapterLabel,
        'sceneIndex': sceneIndex,
        'totalScenesInChapter': totalScenesInChapter,
      },
      'publicKnownFacts': [
        for (final node in worldRecords) _worldKnowledge(node),
      ],
      'characterKnownFacts': {
        for (final character in castRecords)
          character.id: [
            for (final value in [
              character.role,
              character.need,
              character.summary,
            ])
              if (value.trim().isNotEmpty) value.trim(),
          ],
      },
    };

    return SceneBrief(
      projectId: workspaceStore.currentProjectId,
      // StoryGenerationStore currently keys chapter state by this label.
      // Preserve that compatibility while retaining an outline-plan id above.
      chapterId: scene.chapterLabel,
      chapterTitle:
          chapterPlan?.title ??
          legacyMatch?.chapter.title ??
          scene.chapterOnlyLabel,
      sceneId: scene.id,
      sceneIndex: sceneIndex,
      totalScenesInChapter: totalScenesInChapter,
      sceneTitle: planMatch?.title.trim().isNotEmpty == true
          ? planMatch!.title
          : (legacyMatch?.scene.title.trim().isNotEmpty == true
                ? legacyMatch!.scene.title
                : scene.title),
      sceneSummary: sceneSummaryOverride?.trim().isNotEmpty == true
          ? sceneSummaryOverride!.trim()
          : (planMatch?.summary.trim().isNotEmpty == true
                ? planMatch!.summary
                : (legacyMatch?.scene.summary.trim().isNotEmpty == true
                      ? legacyMatch!.scene.summary
                      : scene.summary)),
      targetLength:
          planMatch?.targetLength != null && planMatch!.targetLength > 0
          ? planMatch.targetLength
          : 400,
      targetBeat: targetBeat,
      worldNodeIds: [for (final node in worldRecords) node.id],
      cast: [
        for (final character in castRecords)
          SceneCastCandidate(
            characterId: character.id,
            name: character.name,
            role: character.role,
            metadata: {
              'summary': character.summary,
              'need': character.need,
              'note': character.note,
              'referenceSummary': character.referenceSummary,
              'source': 'workspace-character',
            },
          ),
      ],
      characterProfiles: [
        for (final character in castRecords) _profileFor(character),
      ],
      knowledgeAtoms: [
        for (final node in worldRecords)
          KnowledgeAtom(
            id: 'world:${node.id}',
            type: 'world-node',
            content: _worldKnowledge(node),
            ownerScope: 'world:${node.id}',
            visibility: KnowledgeVisibility.publicObservable,
            priority: 100,
            tags: [
              node.id,
              node.type,
              node.location,
            ].where((value) => value.trim().isNotEmpty).toList(growable: false),
          ),
        for (final character in castRecords)
          KnowledgeAtom(
            id: 'character:${character.id}',
            type: 'character-profile',
            content: _characterKnowledge(character),
            ownerScope: 'character:${character.id}',
            visibility: KnowledgeVisibility.agentPrivate,
            priority: 80,
            tags: [
              character.id,
              character.role,
            ].where((value) => value.trim().isNotEmpty).toList(growable: false),
          ),
      ],
      formalExecution: formalExecution,
      metadata: metadata,
    );
  }

  ProjectMaterialSnapshot build({
    required AppWorkspaceStore workspaceStore,
    AppSceneContextStore? sceneContextStore,
    StoryOutlineStore? outlineStore,
    ReviewTaskStore? reviewTaskStore,
  }) {
    final sceneContext = sceneContextStore?.snapshot;
    final outline = outlineStore?.snapshot;

    final worldFacts = <String>[
      for (final node in workspaceStore.worldNodes)
        _line(node.title, {
          '类型': node.type,
          '地点': node.location,
          '设定': node.detail,
          '摘要': node.summary,
          '规则': node.ruleSummary,
          '参考': node.referenceSummary,
        }),
      if (sceneContext != null) sceneContext.worldSummary,
    ];
    final characterProfiles = <String>[
      for (final character in workspaceStore.characters)
        _line(character.name, {
          '角色': character.role,
          '需求': character.need,
          '备注': character.note,
          '摘要': character.summary,
          '参考': character.referenceSummary,
        }),
      if (sceneContext != null) sceneContext.characterSummary,
    ];
    final outlineBeats = <String>[
      if (outline != null)
        for (final chapter in outline.chapters) ...[
          _line(chapter.title, {'章节摘要': chapter.summary}),
          for (final scene in chapter.scenes)
            _line(scene.title, {'场景摘要': scene.summary}),
        ],
      if (outline?.executablePlan != null)
        for (final scene in outline!.scenePlans) ...[
          _line(scene.title, {
            '场景摘要': scene.summary,
            '叙事弧': scene.narrativeArc,
          }),
          for (final beat in scene.beats)
            _line('节拍 ${beat.sequence}', {
              '类型': beat.beatType,
              '内容': beat.content,
            }),
        ],
    ];
    final sceneSummaries = <String>[
      for (final scene in workspaceStore.scenes)
        _line(scene.title, {'章节': scene.chapterLabel, '摘要': scene.summary}),
      if (sceneContext != null) sceneContext.sceneSummary,
    ];
    final reviewFindings = <String>[
      for (final issue in workspaceStore.auditIssues)
        _line(issue.title, {
          '状态': _enumName(issue.status),
          '证据': issue.evidence,
          '目标': issue.target,
        }),
      for (final task in reviewTaskStore?.tasks ?? const [])
        _line(task.title, {
          '状态': _enumName(task.status),
          '严重度': _enumName(task.severity),
          '内容': task.body,
        }),
    ];

    return ProjectMaterialSnapshot(
      worldFacts: _unique(worldFacts),
      characterProfiles: _unique(characterProfiles),
      outlineBeats: _unique(outlineBeats),
      sceneSummaries: _unique(sceneSummaries),
      reviewFindings: _unique(reviewFindings),
    );
  }

  ScenePlan? _findScenePlan(StoryOutlineSnapshot? outline, String sceneId) {
    if (outline == null || sceneId.trim().isEmpty) return null;
    for (final plan in outline.scenePlans) {
      if (plan.id == sceneId) return plan;
    }
    return null;
  }

  ChapterPlan? _findChapterPlan(
    StoryOutlineSnapshot? outline,
    ScenePlan? scenePlan,
  ) {
    if (outline?.executablePlan == null || scenePlan == null) return null;
    for (final chapter in outline!.executablePlan!.chapters) {
      if (chapter.id == scenePlan.chapterPlanId ||
          chapter.scenes.any((scene) => scene.id == scenePlan.id)) {
        return chapter;
      }
    }
    return null;
  }

  _LegacySceneMatch? _findLegacyScene(
    StoryOutlineSnapshot? outline, {
    required String sceneId,
    required String chapterLabel,
  }) {
    if (outline == null || sceneId.trim().isEmpty) return null;
    final matches = <_LegacySceneMatch>[];
    for (final chapter in outline.chapters) {
      for (final scene in chapter.scenes) {
        if (scene.id == sceneId) {
          matches.add(_LegacySceneMatch(chapter: chapter, scene: scene));
        }
      }
    }
    if (matches.length == 1) return matches.single;
    if (matches.isEmpty) return null;

    final chapterMatches = matches
        .where((match) {
          return match.chapter.id == chapterLabel ||
              match.chapter.title == chapterLabel;
        })
        .toList(growable: false);
    return chapterMatches.length == 1 ? chapterMatches.single : null;
  }

  ({bool present, Object? value}) _outlineBeatContract({
    required ScenePlan? plan,
    required StoryOutlineSceneSnapshot? legacyScene,
  }) {
    final planHasContract =
        plan?.metadata.containsKey('requiredOutlineBeats') == true;
    final legacyHasContract =
        legacyScene?.metadata.containsKey('requiredOutlineBeats') == true;
    final planContract = plan?.metadata['requiredOutlineBeats'];
    final legacyContract = legacyScene?.metadata['requiredOutlineBeats'];

    if (planHasContract && _hasCompleteEvidenceGroups(planContract)) {
      return (present: true, value: _copyOutlineContract(planContract));
    }
    if (legacyHasContract && _hasCompleteEvidenceGroups(legacyContract)) {
      return (present: true, value: _copyOutlineContract(legacyContract));
    }
    if (planHasContract) {
      return (present: true, value: _copyOutlineContract(planContract));
    }
    if (legacyHasContract) {
      return (present: true, value: _copyOutlineContract(legacyContract));
    }

    if (plan != null && plan.beats.isNotEmpty) {
      final beats = List<BeatPlan>.from(plan.beats)
        ..sort((left, right) => left.sequence.compareTo(right.sequence));
      return (
        present: true,
        value: <Object?>[
          for (final beat in beats)
            <String, Object?>{
              'id': beat.id,
              'description': beat.content,
              'sequence': beat.sequence,
              'beatType': beat.beatType,
            },
        ],
      );
    }

    final legacySummary = legacyScene?.summary.trim() ?? '';
    if (legacyScene != null && legacySummary.isNotEmpty) {
      return (
        present: true,
        value: <Object?>[
          <String, Object?>{'id': legacyScene.id, 'description': legacySummary},
        ],
      );
    }
    return (present: false, value: null);
  }

  bool _hasCompleteEvidenceGroups(Object? rawContract) {
    if (rawContract is! List || rawContract.isEmpty) return false;
    for (final rawBeat in rawContract) {
      if (rawBeat is! Map) return false;
      final rawGroups = rawBeat['evidenceGroups'];
      if (rawGroups is! List || rawGroups.isEmpty) return false;
      for (final rawGroup in rawGroups) {
        if (rawGroup is! List ||
            !rawGroup.any(
              (alias) => alias is String && alias.trim().isNotEmpty,
            )) {
          return false;
        }
      }
    }
    return true;
  }

  Object? _copyOutlineContract(Object? value) {
    if (value is List) {
      return <Object?>[for (final entry in value) _copyOutlineContract(entry)];
    }
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _copyOutlineContract(entry.value),
      };
    }
    return value;
  }

  List<SceneRecord> _workspaceChapterScenes(
    AppWorkspaceStore workspaceStore,
    String chapterLabel,
  ) {
    final matching = workspaceStore.scenes
        .where((scene) => scene.chapterLabel == chapterLabel)
        .toList(growable: false);
    return matching.isEmpty ? [workspaceStore.currentScene] : matching;
  }

  int _sceneIndex({
    required String sceneId,
    required List<ScenePlan>? scenePlans,
    required List<SceneRecord> scenes,
  }) {
    final planIndex = scenePlans?.indexWhere((scene) => scene.id == sceneId);
    if (planIndex != null && planIndex >= 0) return planIndex;
    final workspaceIndex = scenes.indexWhere((scene) => scene.id == sceneId);
    return workspaceIndex >= 0 ? workspaceIndex : 0;
  }

  List<CharacterRecord> _castForScene({
    required AppWorkspaceStore workspaceStore,
    required String sceneId,
    required ScenePlan? plan,
  }) {
    final byId = {
      for (final character in workspaceStore.characters)
        character.id: character,
    };
    if (plan != null && plan.castIds.isNotEmpty) {
      return [
        for (final id in plan.castIds)
          if (byId[id] != null) byId[id]!,
      ];
    }
    final linked = workspaceStore.characters
        .where((character) => character.linkedSceneIds.contains(sceneId))
        .toList(growable: false);
    return linked.isEmpty ? workspaceStore.characters : linked;
  }

  List<WorldNodeRecord> _worldNodesForScene({
    required AppWorkspaceStore workspaceStore,
    required String sceneId,
    required ScenePlan? plan,
  }) {
    final byId = {for (final node in workspaceStore.worldNodes) node.id: node};
    if (plan != null && plan.worldNodeIds.isNotEmpty) {
      return [
        for (final id in plan.worldNodeIds)
          if (byId[id] != null) byId[id]!,
      ];
    }
    final linked = workspaceStore.worldNodes
        .where((node) => node.linkedSceneIds.contains(sceneId))
        .toList(growable: false);
    return linked.isEmpty ? workspaceStore.worldNodes : linked;
  }

  String _targetBeat(ScenePlan? plan, String fallback) {
    if (plan != null) {
      final beats = List<BeatPlan>.from(plan.beats)
        ..sort((left, right) => left.sequence.compareTo(right.sequence));
      for (final beat in beats) {
        if (beat.content.trim().isNotEmpty) return beat.content.trim();
      }
      if (plan.narrativeArc.trim().isNotEmpty) return plan.narrativeArc.trim();
    }
    return fallback.trim();
  }

  StructuredProfile _profileFor(CharacterRecord character) {
    return StructuredProfile(
      id: character.id,
      name: character.name,
      personality: const PersonalityVector(),
      voicePrint: VoicePrint(
        speakingPatterns: [
          character.referenceSummary,
        ].where((value) => value.trim().isNotEmpty).toList(growable: false),
      ),
      behaviorBounds: BehaviorBounds(
        mandatoryResponses: [
          character.need,
        ].where((value) => value.trim().isNotEmpty).toList(growable: false),
      ),
      backstory: _characterKnowledge(character),
      metadata: {'role': character.role, 'source': 'workspace-character'},
    );
  }

  String _characterKnowledge(CharacterRecord character) {
    return [
      if (character.role.trim().isNotEmpty) '身份：${character.role.trim()}',
      if (character.need.trim().isNotEmpty) '目标：${character.need.trim()}',
      if (character.summary.trim().isNotEmpty) '摘要：${character.summary.trim()}',
      if (character.note.trim().isNotEmpty) '备注：${character.note.trim()}',
      if (character.referenceSummary.trim().isNotEmpty)
        '参考：${character.referenceSummary.trim()}',
    ].join('；');
  }

  String _worldKnowledge(WorldNodeRecord node) {
    return [
      node.title.trim(),
      if (node.type.trim().isNotEmpty) '类型：${node.type.trim()}',
      if (node.location.trim().isNotEmpty) '地点：${node.location.trim()}',
      if (node.detail.trim().isNotEmpty) '设定：${node.detail.trim()}',
      if (node.summary.trim().isNotEmpty) '摘要：${node.summary.trim()}',
      if (node.ruleSummary.trim().isNotEmpty) '规则：${node.ruleSummary.trim()}',
    ].where((value) => value.isNotEmpty).join('；');
  }
}

class _LegacySceneMatch {
  const _LegacySceneMatch({required this.chapter, required this.scene});

  final StoryOutlineChapterSnapshot chapter;
  final StoryOutlineSceneSnapshot scene;
}

String _line(String heading, Map<String, String> fields) {
  final parts = <String>[
    heading.trim(),
    for (final entry in fields.entries)
      if (entry.value.trim().isNotEmpty) '${entry.key}：${entry.value.trim()}',
  ].where((part) => part.isNotEmpty).toList(growable: false);
  return parts.join('；');
}

List<String> _unique(Iterable<String> values) {
  return List<String>.unmodifiable({
    for (final value in values)
      if (value.trim().isNotEmpty) value.trim(),
  });
}

String _enumName(Object value) {
  final text = value.toString();
  final separator = text.lastIndexOf('.');
  return separator < 0 ? text : text.substring(separator + 1);
}
