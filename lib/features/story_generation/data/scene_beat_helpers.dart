import 'prompt_string_utils.dart';
import 'scene_pipeline_models.dart';
import 'scene_roleplay_session_models.dart';
import 'scene_stage_narrator.dart';
import 'story_prompt_templates.dart';

// ---------------------------------------------------------------------------
// Beat parsing
// ---------------------------------------------------------------------------

/// Parse the LLM response into structured beats.
List<SceneBeat> parseBeatsFromRaw(String raw) {
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

// ---------------------------------------------------------------------------
// Fallback & filtering
// ---------------------------------------------------------------------------

/// Generate fallback beats from role turns when the LLM fails.
List<SceneBeat> fallbackBeats({
  required SceneTaskCard taskCard,
  required List<RolePlayTurnOutput> roleTurns,
  required List<LightContextCapsule> capsules,
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

  for (final capsule in stageCapsules(capsules)) {
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

bool hasAuthoritativeRoleplay(
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

List<SceneBeat> filterPlanningOnlyBeats(
  List<SceneBeat> beats, {
  required SceneTaskCard taskCard,
  required List<RolePlayTurnOutput> roleTurns,
  required List<LightContextCapsule> capsules,
  SceneRoleplaySession? roleplaySession,
}) {
  if (!hasAuthoritativeRoleplay(roleTurns, roleplaySession)) {
    return beats;
  }

  final planningOnlyTerms = _planningOnlyTerms(
    taskCard: taskCard,
    roleTurns: roleTurns,
    capsules: capsules,
    roleplaySession: roleplaySession,
  );
  if (planningOnlyTerms.isEmpty) {
    return reorderBeats([
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
  return reorderBeats(filtered);
}

Set<String> _planningOnlyTerms({
  required SceneTaskCard taskCard,
  required List<RolePlayTurnOutput> roleTurns,
  required List<LightContextCapsule> capsules,
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
    for (final capsule in stageCapsules(capsules)) capsule.summary,
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
  final cjkRuns = RegExp(r'[一-鿿]{3,}').allMatches(normalized);
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

List<SceneBeat> reorderBeats(List<SceneBeat> beats) {
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

// ---------------------------------------------------------------------------
// Capsule helpers
// ---------------------------------------------------------------------------

List<LightContextCapsule> stageCapsules(List<LightContextCapsule> capsules) {
  return [
    for (final capsule in capsules)
      if (capsule.intent.toolName == SceneStageNarrator.capsuleToolName)
        capsule,
  ];
}

List<LightContextCapsule> retrievalCapsules(
  List<LightContextCapsule> capsules,
) {
  return [
    for (final capsule in capsules)
      if (capsule.intent.toolName != SceneStageNarrator.capsuleToolName)
        capsule,
  ];
}

// ---------------------------------------------------------------------------
// Prompt formatting
// ---------------------------------------------------------------------------

String turnSummary(List<RolePlayTurnOutput> turns) {
  final l = StoryPromptTemplates.locale;
  if (turns.isEmpty) return '${l.roleInputLabel}${l.colon}${l.noneLabel}';
  return '${l.roleInputLabel}${l.colon}${PromptStringUtils.mapJoin(turns, (t) {
    final process = t.disclosure.trim().isEmpty ? '' : '/过程${l.colon}${t.disclosure}';
    final prose = t.proseFragment.trim().isEmpty ? '' : '/正文片段${l.colon}${t.proseFragment}';
    final taboo = t.taboo.trim().isEmpty ? '' : '/${l.tabooLabel}${l.colon}${t.taboo}';
    return '${t.name}${l.colon}${l.stanceLabel}${t.stance}/${l.actionLabel}${t.action}$taboo$process$prose';
  }, separator: l.listSeparator)}';
}

String pacingLabel(ScenePacing pacing) {
  final l = StoryPromptTemplates.locale;
  return switch (pacing) {
    ScenePacing.slow => l.pacingSlow,
    ScenePacing.medium => l.pacingMedium,
    ScenePacing.fast => l.pacingFast,
  };
}
