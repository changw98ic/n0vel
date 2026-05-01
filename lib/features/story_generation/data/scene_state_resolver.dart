import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/domain/outline_plan_models.dart';

import 'prompt_string_utils.dart';
import 'scene_stage_narrator.dart';
import 'story_generation_pass_retry.dart';
import 'scene_pipeline_models.dart';
import 'scene_roleplay_session_models.dart';
import 'story_prompt_templates.dart';

enum SceneTransitionStatus { passed, missed }

class SceneTransitionRequirement {
  SceneTransitionRequirement({
    required this.id,
    required this.description,
    required this.isRequired,
    List<String> matchTerms = const [],
  }) : matchTerms = List.unmodifiable([
         for (final term in matchTerms)
           if (term.trim().isNotEmpty) term.trim(),
       ]);

  final String id;
  final String description;
  final bool isRequired;
  final List<String> matchTerms;
}

class SceneTransitionCheck {
  SceneTransitionCheck({
    required this.requirement,
    required this.status,
    List<int> matchedBeatOrders = const [],
    List<String> evidence = const [],
  }) : matchedBeatOrders = List.unmodifiable(matchedBeatOrders),
       evidence = List.unmodifiable(evidence);

  final SceneTransitionRequirement requirement;
  final SceneTransitionStatus status;
  final List<int> matchedBeatOrders;
  final List<String> evidence;

  String get id => requirement.id;
  String get description => requirement.description;
  bool get isRequired => requirement.isRequired;
  bool get passed => status == SceneTransitionStatus.passed;
}

class SceneTransitionReport {
  SceneTransitionReport({List<SceneTransitionCheck> checks = const []})
    : checks = List.unmodifiable(checks);

  final List<SceneTransitionCheck> checks;

  List<SceneTransitionCheck> get requiredChecks => [
    for (final check in checks)
      if (check.isRequired) check,
  ];

  List<SceneTransitionCheck> get optionalChecks => [
    for (final check in checks)
      if (!check.isRequired) check,
  ];

  List<SceneTransitionCheck> get missingRequired => [
    for (final check in requiredChecks)
      if (!check.passed) check,
  ];

  List<SceneTransitionCheck> get missingOptional => [
    for (final check in optionalChecks)
      if (!check.passed) check,
  ];

  bool get hasMissedRequired => missingRequired.isNotEmpty;
  bool get allRequiredPassed => missingRequired.isEmpty;
  bool get allTransitionsPassed =>
      checks.every((check) => check.status == SceneTransitionStatus.passed);

  String get blockingReason {
    if (!hasMissedRequired) return '';
    return 'Missing required transitions: '
        '${missingRequired.map((check) => check.id).join(', ')}';
  }
}

/// Tracks the resolution status of a single state transition between scenes.
class TransitionStatus {
  const TransitionStatus({
    required this.transitionId,
    required this.fromSceneId,
    required this.toSceneId,
    required this.isResolved,
    this.resolvedValue,
  });

  final String transitionId;
  final String fromSceneId;
  final String toSceneId;
  final bool isResolved;
  final String? resolvedValue;

  TransitionStatus copyWith({
    String? transitionId,
    String? fromSceneId,
    String? toSceneId,
    bool? isResolved,
    String? resolvedValue,
  }) {
    return TransitionStatus(
      transitionId: transitionId ?? this.transitionId,
      fromSceneId: fromSceneId ?? this.fromSceneId,
      toSceneId: toSceneId ?? this.toSceneId,
      isResolved: isResolved ?? this.isResolved,
      resolvedValue: resolvedValue ?? this.resolvedValue,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'transitionId': transitionId,
      'fromSceneId': fromSceneId,
      'toSceneId': toSceneId,
      'isResolved': isResolved,
      if (resolvedValue != null) 'resolvedValue': resolvedValue,
    };
  }

  static TransitionStatus fromJson(Map<Object?, Object?> json) {
    return TransitionStatus(
      transitionId: json['transitionId']?.toString() ?? '',
      fromSceneId: json['fromSceneId']?.toString() ?? '',
      toSceneId: json['toSceneId']?.toString() ?? '',
      isResolved: json['isResolved'] == true,
      resolvedValue: json['resolvedValue']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransitionStatus) return false;
    return other.transitionId == transitionId &&
        other.fromSceneId == fromSceneId &&
        other.toSceneId == toSceneId &&
        other.isResolved == isResolved &&
        other.resolvedValue == resolvedValue;
  }

  @override
  int get hashCode => Object.hash(
    transitionId,
    fromSceneId,
    toSceneId,
    isResolved,
    resolvedValue,
  );
}

/// Tracks required transitions for a scene and reports which are resolved
/// versus pending.
class SceneTransitionTracker {
  /// Track required transitions for a scene.
  ///
  /// Returns a map of [transitionId] to [TransitionStatus] indicating which
  /// transitions are resolved vs pending, based on the provided
  /// [resolvedValues] mapping.
  Map<String, TransitionStatus> trackTransitions({
    required List<StateTransitionTarget> targets,
    required Map<String, String> resolvedValues,
  }) {
    return {
      for (final target in targets)
        target.id: TransitionStatus(
          transitionId: target.id,
          fromSceneId: target.fromSceneId,
          toSceneId: target.toSceneId,
          isResolved: resolvedValues.containsKey(target.id),
          resolvedValue: resolvedValues[target.id],
        ),
    };
  }

  /// Check if all required transitions are resolved.
  ///
  /// A transition is considered resolved when [TransitionStatus.isResolved]
  /// is true. Returns true only when every status in [statuses] is resolved.
  bool allRequiredResolved(List<TransitionStatus> statuses) {
    return statuses.every((status) => status.isResolved);
  }
}

/// Resolves [RolePlayTurnOutput]s and [ContextCapsule]s into accepted
/// [SceneBeat]s before any prose is written.
///
/// This stage enforces the fact-first pipeline: no prose generation
/// happens until the resolver has produced an ordered list of beats.
class SceneStateResolver {
  SceneStateResolver({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  static SceneTransitionReport trackTransitions({
    required SceneTaskCard taskCard,
    required List<SceneBeat> resolvedBeats,
  }) {
    final requirements = [
      ..._requirementsFromMetadata(
        taskCard.metadata['requiredTransitions'],
        isRequired: true,
      ),
      ..._requirementsFromMetadata(
        taskCard.metadata['optionalTransitions'],
        isRequired: false,
      ),
      ..._requirementsFromMixedMetadata(taskCard.metadata['transitions']),
    ];

    return SceneTransitionReport(
      checks: [
        for (final requirement in requirements)
          _checkTransition(requirement, resolvedBeats),
      ],
    );
  }

  /// Resolve role turns + capsules into scene beats.
  ///
  /// The resolver sends a structured request to the LLM asking it to
  /// decompose the scene into ordered beats. Each beat is classified
  /// by [SceneBeatKind] and attributed to a source character.
  Future<List<SceneBeat>> resolve({
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<ContextCapsule> capsules,
    SceneRoleplaySession? roleplaySession,
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call(
      '场景 ${taskCard.brief.chapterId}/${taskCard.brief.sceneId} · resolving beats',
    );

    if (taskCard.metadata['localStructuredRoleplayOnly'] == true ||
        taskCard.brief.metadata['localStructuredRoleplayOnly'] == true) {
      return _fallbackBeats(
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: capsules,
        roleplaySession: roleplaySession,
      );
    }

    final l = StoryPromptTemplates.locale;
    final hasAuthoritativeRoleplay = _hasAuthoritativeRoleplay(
      roleTurns,
      roleplaySession,
    );
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      maxTransientRetries: 0,
      maxEscalatedTokens: storyGenerationEditorialMaxTokens,
      messages: [
        AppLlmChatMessage(
          role: 'system',
          content: StoryPromptTemplates.sysSceneBeatResolve,
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '${l.taskLabel}${l.colon}scene_beat_resolve',
            '${l.sceneShortLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneTitle, maxChars: 40)}',
            if (hasAuthoritativeRoleplay) ...[
              '规划背景（非既定事实，不得直接输出为场景拍）：'
                  '${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
              if (taskCard.directorPlan.trim().isNotEmpty)
                '导演规划（非既定事实，不得直接输出为场景拍）：'
                    '${PromptStringUtils.compact(taskCard.directorPlan, maxChars: 120)}',
            ] else ...[
              '${l.summaryLabel}${l.colon}${PromptStringUtils.compact(taskCard.brief.sceneSummary, maxChars: 120)}',
              '${l.directorLabel}${l.colon}${PromptStringUtils.compact(taskCard.directorPlan, maxChars: 120)}',
            ],
            if (taskCard.directorPlanParsed != null) ...[
              if (taskCard.directorPlanParsed!.tone.isNotEmpty)
                '${l.toneFieldLabel}${l.colon}${taskCard.directorPlanParsed!.tone}',
              '${l.pacingFieldLabel}${l.colon}${_pacingLabel(taskCard.directorPlanParsed!.pacing)}',
            ],
            _turnSummary(roleTurns),
            if (roleplaySession != null && !roleplaySession.isEmpty)
              '角色扮演裁决（权威事实源）：'
                  '${roleplaySession.toCommittedPromptText(maxChars: 2400)}',
            if (_stageCapsules(capsules).isNotEmpty)
              '场景旁白/舞台信息（权威场景源）：'
                  '${PromptStringUtils.mapJoin(_stageCapsules(capsules), (c) => c.summary, separator: l.listSeparator)}',
            if (_retrievalCapsules(capsules).isNotEmpty)
              '${l.retrievalContextLabel}${l.colon}${PromptStringUtils.mapJoin(_retrievalCapsules(capsules), (c) => c.summary, separator: l.listSeparator)}',
            if (hasAuthoritativeRoleplay)
              '约束：只从角色输入、角色扮演裁决和检索上下文抽取场景拍；'
                  '场景旁白/舞台信息可作为环境、氛围、物理机制与公共证据；'
                  '规划背景只用于场景边界和语气，不是已发生事件。',
            '${l.targetLengthLabel}${l.colon}~${taskCard.brief.targetLength} ${l.charactersUnit}',
          ].join('\n'),
        ),
      ],
    );

    if (!result.succeeded) {
      return _fallbackBeats(
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: capsules,
        roleplaySession: roleplaySession,
      );
    }

    final beats = _filterPlanningOnlyBeats(
      _parseBeats(result.text!),
      taskCard: taskCard,
      roleTurns: roleTurns,
      capsules: capsules,
      roleplaySession: roleplaySession,
    );
    if (beats.isEmpty) {
      return _fallbackBeats(
        taskCard: taskCard,
        roleTurns: roleTurns,
        capsules: capsules,
        roleplaySession: roleplaySession,
      );
    }

    return List<SceneBeat>.unmodifiable(beats);
  }

  /// Parse the LLM response into structured beats.
  List<SceneBeat> _parseBeats(String raw) {
    final beats = <SceneBeat>[];
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    for (var i = 0; i < lines.length; i++) {
      final beat = _parseSingleBeat(lines[i], order: i);
      if (beat != null) {
        beats.add(beat);
      }
    }

    return beats;
  }

  /// Parse one beat line: `[类型] @角色ID 内容`
  SceneBeat? _parseSingleBeat(String line, {required int order}) {
    // Match [类型] pattern
    final tagMatch = RegExp(r'^\[([^\]]+)\]\s*').firstMatch(line);
    if (tagMatch == null) return null;

    final kind = _parseKind(tagMatch.group(1)!);
    var rest = line.substring(tagMatch.end);

    // Match @characterId
    final charMatch = RegExp(r'^@(\S+)\s*').firstMatch(rest);
    String characterId;
    if (charMatch != null) {
      characterId = charMatch.group(1)!;
      rest = rest.substring(charMatch.end);
    } else {
      characterId = 'narrator';
    }

    final content = rest.trim();
    if (content.isEmpty) return null;

    return SceneBeat(
      kind: kind,
      content: content,
      sourceCharacterId: characterId,
      order: order,
    );
  }

  SceneBeatKind _parseKind(String tag) {
    final l = StoryPromptTemplates.locale;
    return switch (tag) {
      _ when tag == l.beatFact => SceneBeatKind.fact,
      _ when tag == l.beatDialogue => SceneBeatKind.dialogue,
      _ when tag == l.beatAction => SceneBeatKind.action,
      _ when tag == l.beatInternal => SceneBeatKind.internal,
      _ when tag == l.beatNarration => SceneBeatKind.narration,
      _ => SceneBeatKind.narration,
    };
  }

  /// Generate fallback beats from role turns when the LLM fails.
  List<SceneBeat> _fallbackBeats({
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<ContextCapsule> capsules,
    SceneRoleplaySession? roleplaySession,
  }) {
    final beats = <SceneBeat>[];
    var order = 0;

    if (roleplaySession != null && !roleplaySession.isEmpty) {
      for (final round in roleplaySession.rounds) {
        for (final turn in round.turns) {
          final action = turn.visibleAction.trim();
          if (action.isNotEmpty) {
            beats.add(
              SceneBeat(
                kind: SceneBeatKind.action,
                content: action,
                sourceCharacterId: turn.characterId,
                order: order++,
              ),
            );
          }
          final dialogue = turn.dialogue.trim();
          if (dialogue.isNotEmpty) {
            beats.add(
              SceneBeat(
                kind: SceneBeatKind.dialogue,
                content: dialogue,
                sourceCharacterId: turn.characterId,
                order: order++,
              ),
            );
          }
        }
        final fact = round.arbitration.fact.trim();
        if (fact.isNotEmpty) {
          beats.add(
            SceneBeat(
              kind: SceneBeatKind.fact,
              content: fact,
              sourceCharacterId: 'arbiter',
              order: order++,
            ),
          );
        }
      }
    } else if (roleTurns.isEmpty) {
      // Without roleplay, planning text is the only available fallback context.
      beats.add(
        SceneBeat(
          kind: SceneBeatKind.narration,
          content: taskCard.brief.sceneSummary,
          sourceCharacterId: 'narrator',
          order: order++,
        ),
      );

      if (taskCard.directorPlan.trim().isNotEmpty) {
        beats.add(
          SceneBeat(
            kind: SceneBeatKind.fact,
            content: taskCard.directorPlan,
            sourceCharacterId: 'director',
            order: order++,
          ),
        );
      }
    }

    for (final capsule in _stageCapsules(capsules)) {
      final content = capsule.summary.trim();
      if (content.isEmpty) {
        continue;
      }
      beats.add(
        SceneBeat(
          kind: SceneBeatKind.narration,
          content: content,
          sourceCharacterId: 'narrator',
          order: order++,
        ),
      );
    }

    for (final turn in roleTurns) {
      if (turn.action.trim().isNotEmpty) {
        beats.add(
          SceneBeat(
            kind: SceneBeatKind.action,
            content: turn.action,
            sourceCharacterId: turn.characterId,
            order: order++,
          ),
        );
      }
      if (turn.disclosure.trim().isNotEmpty) {
        beats.add(
          SceneBeat(
            kind: SceneBeatKind.dialogue,
            content: turn.disclosure,
            sourceCharacterId: turn.characterId,
            order: order++,
          ),
        );
      }
    }

    return List<SceneBeat>.unmodifiable(beats);
  }

  bool _hasAuthoritativeRoleplay(
    List<RolePlayTurnOutput> roleTurns,
    SceneRoleplaySession? roleplaySession,
  ) {
    if (roleplaySession != null && !roleplaySession.isEmpty) {
      return true;
    }
    return roleTurns.any(
      (turn) =>
          turn.action.trim().isNotEmpty ||
          turn.disclosure.trim().isNotEmpty ||
          turn.proseFragment.trim().isNotEmpty,
    );
  }

  List<SceneBeat> _filterPlanningOnlyBeats(
    List<SceneBeat> beats, {
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<ContextCapsule> capsules,
    SceneRoleplaySession? roleplaySession,
  }) {
    if (!_hasAuthoritativeRoleplay(roleTurns, roleplaySession)) {
      return beats;
    }

    final planningOnlyTerms = _planningOnlyTerms(
      taskCard: taskCard,
      roleTurns: roleTurns,
      capsules: capsules,
      roleplaySession: roleplaySession,
    );
    if (planningOnlyTerms.isEmpty) {
      return _reorderBeats([
        for (final beat in beats)
          if (beat.sourceCharacterId != 'director') beat,
      ]);
    }

    final filtered = <SceneBeat>[];
    for (final beat in beats) {
      if (beat.sourceCharacterId == 'director') {
        continue;
      }
      final beatContent = beat.content.toLowerCase();
      if (planningOnlyTerms.any(beatContent.contains)) {
        continue;
      }
      filtered.add(beat);
    }
    return _reorderBeats(filtered);
  }

  Set<String> _planningOnlyTerms({
    required SceneTaskCard taskCard,
    required List<RolePlayTurnOutput> roleTurns,
    required List<ContextCapsule> capsules,
    SceneRoleplaySession? roleplaySession,
  }) {
    final planningText = [
      taskCard.brief.sceneSummary,
      taskCard.directorPlan,
    ].join('\n');
    final authoritativeText = [
      taskCard.brief.sceneTitle,
      for (final turn in roleTurns) ...[
        turn.action,
        turn.disclosure,
        turn.proseFragment,
      ],
      for (final capsule in _stageCapsules(capsules)) capsule.summary,
      if (roleplaySession != null)
        roleplaySession.toCommittedPromptText(maxChars: 10000),
    ].join('\n');
    return _significantTerms(
      planningText,
    ).where((term) => !authoritativeText.contains(term)).toSet();
  }

  Set<String> _significantTerms(String text) {
    final terms = <String>{};
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    final cjkRuns = RegExp(r'[\u4e00-\u9fff]{3,}').allMatches(normalized);
    for (final match in cjkRuns) {
      final run = match.group(0)!;
      for (var size in const [3, 4]) {
        if (run.length < size) continue;
        for (var i = 0; i <= run.length - size; i += 1) {
          terms.add(run.substring(i, i + size));
        }
      }
    }
    final wordRuns = RegExp(r'[A-Za-z0-9_-]{4,}').allMatches(text);
    for (final match in wordRuns) {
      terms.add(match.group(0)!.toLowerCase());
    }
    return terms;
  }

  List<SceneBeat> _reorderBeats(List<SceneBeat> beats) {
    return [
      for (var i = 0; i < beats.length; i += 1)
        SceneBeat(
          kind: beats[i].kind,
          content: beats[i].content,
          sourceCharacterId: beats[i].sourceCharacterId,
          order: i,
        ),
    ];
  }

  List<ContextCapsule> _stageCapsules(List<ContextCapsule> capsules) {
    return [
      for (final capsule in capsules)
        if (capsule.intent.toolName == SceneStageNarrator.capsuleToolName)
          capsule,
    ];
  }

  List<ContextCapsule> _retrievalCapsules(List<ContextCapsule> capsules) {
    return [
      for (final capsule in capsules)
        if (capsule.intent.toolName != SceneStageNarrator.capsuleToolName)
          capsule,
    ];
  }

  String _turnSummary(List<RolePlayTurnOutput> turns) {
    final l = StoryPromptTemplates.locale;
    if (turns.isEmpty) return '${l.roleInputLabel}${l.colon}${l.noneLabel}';
    return '${l.roleInputLabel}${l.colon}${PromptStringUtils.mapJoin(turns, (t) {
      final process = t.disclosure.trim().isEmpty ? '' : '/过程${l.colon}${t.disclosure}';
      final prose = t.proseFragment.trim().isEmpty ? '' : '/正文片段${l.colon}${t.proseFragment}';
      final taboo = t.taboo.trim().isEmpty ? '' : '/${l.tabooLabel}${l.colon}${t.taboo}';
      return '${t.name}${l.colon}${l.stanceLabel}${t.stance}/${l.actionLabel}${t.action}$taboo$process$prose';
    }, separator: l.listSeparator)}';
  }

  String _pacingLabel(ScenePacing pacing) {
    final l = StoryPromptTemplates.locale;
    return switch (pacing) {
      ScenePacing.slow => l.pacingSlow,
      ScenePacing.medium => l.pacingMedium,
      ScenePacing.fast => l.pacingFast,
    };
  }

  static List<SceneTransitionRequirement> _requirementsFromMixedMetadata(
    Object? raw,
  ) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          _requirementFromMap(
            item,
            isRequired:
                _boolFromRaw(item['required']) ??
                !_isOptionalRaw(item['optional']),
          )
        else
          _requirementFromRaw(item, isRequired: true),
    ].whereType<SceneTransitionRequirement>().toList(growable: false);
  }

  static List<SceneTransitionRequirement> _requirementsFromMetadata(
    Object? raw, {
    required bool isRequired,
  }) {
    if (raw is! List) return const [];
    return [
      for (final item in raw) _requirementFromRaw(item, isRequired: isRequired),
    ].whereType<SceneTransitionRequirement>().toList(growable: false);
  }

  static SceneTransitionRequirement? _requirementFromRaw(
    Object? raw, {
    required bool isRequired,
  }) {
    if (raw is Map) {
      return _requirementFromMap(raw, isRequired: isRequired);
    }
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return SceneTransitionRequirement(
      id: value,
      description: value,
      isRequired: isRequired,
      matchTerms: [value],
    );
  }

  static SceneTransitionRequirement? _requirementFromMap(
    Map<Object?, Object?> raw, {
    required bool isRequired,
  }) {
    final id =
        _stringFromRaw(raw['id']) ??
        _stringFromRaw(raw['transitionId']) ??
        _stringFromRaw(raw['targetId']);
    final description =
        _stringFromRaw(raw['description']) ??
        _stringFromRaw(raw['summary']) ??
        _stringFromRaw(raw['label']) ??
        id;
    if (id == null || description == null) return null;

    return SceneTransitionRequirement(
      id: id,
      description: description,
      isRequired: isRequired,
      matchTerms: [
        ..._stringListFromRaw(raw['match']),
        ..._stringListFromRaw(raw['matches']),
        ..._stringListFromRaw(raw['matchTerms']),
        ..._stringListFromRaw(raw['aliases']),
      ],
    );
  }

  static SceneTransitionCheck _checkTransition(
    SceneTransitionRequirement requirement,
    List<SceneBeat> resolvedBeats,
  ) {
    final terms = requirement.matchTerms.isEmpty
        ? [requirement.description, requirement.id]
        : requirement.matchTerms;
    final matchedOrders = <int>[];
    final evidence = <String>[];

    for (final beat in resolvedBeats) {
      if (_matchesAnyTerm(beat.content, terms)) {
        matchedOrders.add(beat.order);
        evidence.add(beat.content);
      }
    }

    return SceneTransitionCheck(
      requirement: requirement,
      status: matchedOrders.isEmpty
          ? SceneTransitionStatus.missed
          : SceneTransitionStatus.passed,
      matchedBeatOrders: matchedOrders,
      evidence: evidence,
    );
  }

  static bool _matchesAnyTerm(String content, List<String> terms) {
    final normalizedContent = content.toLowerCase();
    for (final term in terms) {
      final normalizedTerm = term.trim().toLowerCase();
      if (normalizedTerm.isNotEmpty &&
          normalizedContent.contains(normalizedTerm)) {
        return true;
      }
    }
    return false;
  }

  static String? _stringFromRaw(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  static List<String> _stringListFromRaw(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if (_stringFromRaw(item) != null) _stringFromRaw(item)!,
      ];
    }
    final value = _stringFromRaw(raw);
    return value == null ? const [] : [value];
  }

  static bool? _boolFromRaw(Object? raw) {
    if (raw is bool) return raw;
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'true' || 'yes' || 'required' => true,
      'false' || 'no' || 'optional' => false,
      _ => null,
    };
  }

  static bool _isOptionalRaw(Object? raw) => _boolFromRaw(raw) == true;
}
