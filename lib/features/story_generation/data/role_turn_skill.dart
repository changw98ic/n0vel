import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'character_memory_delta_models.dart';
import 'character_visible_context_models.dart';
import 'role_skill_descriptor.dart';
import 'scene_roleplay_session_models.dart';
import 'story_generation_pass_retry.dart';

abstract interface class RoleTurnSkill {
  String get skillId;
  String get version;
  RoleSkillDescriptor get descriptor;

  Future<SceneRoleplayTurn> runTurn({
    required CharacterVisibleContext context,
    required int round,
  });
}

class BasicRoleTurnSkill implements RoleTurnSkill {
  BasicRoleTurnSkill({required AppSettingsStore settingsStore})
    : _settingsStore = settingsStore;

  final AppSettingsStore _settingsStore;

  @override
  String get skillId => 'basic_role_turn';

  @override
  String get version => '1.1.0';

  @override
  RoleSkillDescriptor get descriptor => const RoleSkillDescriptor(
    skillId: 'basic_role_turn',
    version: '1.1.0',
    inputSchema: {
      'type': 'CharacterVisibleContext',
      'fields': [
        'characterId',
        'characterName',
        'role',
        'privateBriefing',
        'publicSceneState',
        'visibleEvents',
        'knownFacts',
        'beliefs',
        'relationships',
        'socialPositions',
      ],
    },
    outputSchema: {
      'type': 'SceneRoleplayTurn',
      'lines': ['意图', '可见动作', '对白', '内心', '正文片段'],
      'privateFields': ['内心'],
      'publicFields': ['可见动作', '对白', '正文片段'],
    },
    supportsPrivateMemoryDeltas: true,
    compatibilityNotes: [
      '角色输入来自 CharacterVisibleContext。',
      '输出可包含私有内心；正文侧读取公开动作、对白、正文片段和仲裁事实。',
    ],
  );

  @override
  Future<SceneRoleplayTurn> runTurn({
    required CharacterVisibleContext context,
    required int round,
  }) async {
    final result = await requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      shouldRetryOutput: _shouldRetryMalformedTurn,
      messages: [
        const AppLlmChatMessage(
          role: 'system',
          content:
              'You generate one character turn inside a Chinese novel scene. '
              'Use the character-visible context as the material. Create one '
              'single-actor turn record with action, optional spoken dialogue, '
              'private thought, and a prose fragment for this moment. Use this five-line shape:\n'
              '意图：...\n'
              '可见动作：...\n'
              '对白：...\n'
              '内心：...\n'
              '正文片段：...',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：scene_roleplay_turn',
            'skill：$skillId@$version',
            '回合：$round',
            context.toPromptText(),
            '当前行动角色：${context.characterName}',
            '意图字段：写角色此刻想达成的目标，例如逼问线索、试探底线、稳住局面、拖延时间或保护某人。',
            '可见动作字段：写第三方能拍到的外部画面，包括肢体动作、表情变化、位置移动、身体反应或操控物体。',
            '对白字段：写${context.characterName}实际说出口的一句话；沉默时保留字段为空。',
            '内心字段：写一句当下判断或决定，聚焦当前瞬间的认知变化。',
            '内心示例：我怀疑他在试探，先按兵不动。/这条件太顺，我得再压一句。/她不安，却决定继续逼问。',
            '正文片段字段：写小说正文片段，约120-220字，第三人称呈现本角色本轮可见动作和对白，可融入一句当下心理判断。',
            '剧情功能：角色可以选择比导演桥段更合理的具体做法；行动或正文片段需呈现它如何完成同等剧情功能，或呈现暂缓后的冲突压力。',
            '输出：按五个字段填写，语句短，聚焦当前瞬间。',
          ].join('\n'),
        ),
      ],
    );
    if (!result.succeeded) {
      throw StateError(
        result.detail ?? 'Role turn skill failed for ${context.characterId}.',
      );
    }
    final raw = result.text!.trim();
    return _parseTurn(
      raw: _normalizeTurnRaw(raw, context: context) ?? raw,
      round: round,
      context: context,
    );
  }

  SceneRoleplayTurn _parseTurn({
    required String raw,
    required int round,
    required CharacterVisibleContext context,
  }) {
    final values = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      final colon = trimmed.indexOf('：');
      if (colon <= 0) continue;
      values[trimmed.substring(0, colon)] = trimmed.substring(colon + 1).trim();
    }
    return SceneRoleplayTurn(
      round: round,
      characterId: context.characterId,
      name: context.characterName,
      intent: values['意图'] ?? '',
      visibleAction: values['可见动作'] ?? '',
      dialogue: values['对白'] ?? '',
      innerState: values['内心'] ?? '',
      taboo: values['禁忌'] ?? values['行动边界'] ?? '',
      rawText: raw,
      proseFragment: values['正文片段'] ?? '',
      skillId: skillId,
      skillVersion: version,
      proposedMemoryDeltas: _privateMemoryDeltas(
        round: round,
        context: context,
        intent: values['意图'] ?? '',
        innerState: values['内心'] ?? '',
      ),
    );
  }

  bool _shouldRetryMalformedTurn(String raw) {
    return _normalizeTurnRaw(raw) == null;
  }

  String? _normalizeTurnRaw(String raw, {CharacterVisibleContext? context}) {
    final values = _parseFields(raw);

    if (!_hasRoleTurnShape(raw)) {
      return null;
    }
    if (_isPlaceholder(values['意图']) || _isPlaceholder(values['可见动作'])) {
      return null;
    }
    if (_containsDraftingMeta(values.values)) {
      return null;
    }

    final intent = _repairIntent(values['意图'] ?? '');
    final visibleAction = _repairVisibleAction(values['可见动作'] ?? '');
    if (_isPlaceholder(intent) || _isPlaceholder(visibleAction)) {
      return null;
    }
    final dialogue = _repairDialogue(values['对白'] ?? '');
    final innerState = _repairInnerState(
      values['内心'] ?? '',
      fallbackIntent: intent,
    );
    final proseFragment = _repairProseFragment(
      values['正文片段'] ?? '',
      context: context,
      visibleAction: visibleAction,
      dialogue: dialogue,
      innerState: innerState,
    );

    return [
      '意图：$intent',
      '可见动作：$visibleAction',
      '对白：$dialogue',
      '内心：$innerState',
      '正文片段：$proseFragment',
    ].join('\n');
  }

  Map<String, String> _parseFields(String raw) {
    final values = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      final colon = trimmed.indexOf('：');
      if (colon <= 0) continue;
      values[trimmed.substring(0, colon)] = trimmed.substring(colon + 1).trim();
    }
    return values;
  }

  bool _hasRoleTurnShape(String raw) {
    final labels = <String>[];
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf('：');
      if (colon <= 0) return false;
      labels.add(trimmed.substring(0, colon));
    }
    final hasCore =
        labels.length >= 4 &&
        labels[0] == '意图' &&
        labels[1] == '可见动作' &&
        labels[2] == '对白' &&
        labels[3] == '内心';
    if (!hasCore) return false;
    return labels.length == 4 || (labels.length == 5 && labels[4] == '正文片段');
  }

  bool _isPlaceholder(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return true;
    if (normalized == '-' ||
        normalized == '—' ||
        normalized == '...' ||
        normalized == '…' ||
        normalized == '……') {
      return true;
    }
    return normalized.contains('他想做什么') ||
        normalized.contains('独白') ||
        normalized.contains('留空或') ||
        normalized.contains('可以更');
  }

  bool _containsDraftingMeta(Iterable<String> values) {
    return values.any((value) {
      final normalized = value.trim().toLowerCase();
      return normalized.contains('可能是') ||
          normalized.contains('或者留空') ||
          normalized.contains('让我看看') ||
          normalized.contains('考虑到') ||
          normalized.contains('应该是') ||
          normalized.contains('这句') ||
          normalized.contains('候选') ||
          normalized.contains('maybe') ||
          normalized.contains('option');
    });
  }

  _InnerStateIssue _classifyInnerState(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return const _InnerStateIssue.none();

    final backstoryPattern = RegExp(
      r'([0-9一二两三四五六七八九十百]+年|[0-9一二两三四五六七八九十百]+个月前|去年|前年|当年|曾经|从前|小时候|履历|出身|老手)',
    );
    final backstory = backstoryPattern.firstMatch(normalized);
    if (backstory != null) {
      return _InnerStateIssue(
        _InnerStateIssueKind.backstory,
        backstory.group(0) ?? '',
      );
    }

    const bodySensations = [
      '胃里',
      '胃部',
      '心跳',
      '心脏',
      '喉咙',
      '手心',
      '掌心',
      '冷汗',
      '汗毛',
      '背脊',
      '脊背',
      '发抖',
      '颤抖',
      '一缩',
      '发紧',
      '耳根',
      '耳蜗',
      '耳鸣',
    ];
    for (final token in bodySensations) {
      if (normalized.contains(token)) {
        return _InnerStateIssue(_InnerStateIssueKind.bodySensation, token);
      }
    }

    const worldExposition = [
      '楼宇倒悬',
      '天空成渊',
      '深渊天空',
      '倒悬城市',
      '共振层',
      '世界观',
      '维度裂缝',
      '声学牢笼',
    ];
    for (final token in worldExposition) {
      if (normalized.contains(token)) {
        return _InnerStateIssue(_InnerStateIssueKind.worldExposition, token);
      }
    }
    return const _InnerStateIssue.none();
  }

  String _repairIntent(String value) {
    var normalized = _trimTrailingPunctuation(value.trim());
    normalized = normalized.replaceFirst(
      RegExp(r'^(他|她|我|自己)?(猛然|突然|立刻|缓缓|上前|后退|转身|抬手|伸手|低头|靠近|逼近|挡住|按住|攥住|握紧)+'),
      '',
    );
    normalized = normalized.replaceFirst(RegExp(r'^(他|她|我|自己)'), '');
    return _trimTrailingPunctuation(normalized.trim());
  }

  String _repairVisibleAction(String value) {
    final clauses = _splitClauses(value)
        .map((clause) {
          var cleaned = clause.trim();
          cleaned = cleaned.replaceAll(RegExp(r'^(紧张|害怕|犹豫|焦急|慌乱|愤怒|不安)地'), '');
          return cleaned.trim();
        })
        .where(
          (clause) =>
              clause.isNotEmpty && !_visibleActionClauseLooksPrivate(clause),
        )
        .toList(growable: false);
    return _joinClauses(clauses);
  }

  bool _visibleActionClauseLooksPrivate(String clause) {
    const privateMarkers = [
      '内心',
      '心里',
      '感到',
      '觉得',
      '意识到',
      '想起',
      '明白',
      '害怕',
      '担心',
      '怀疑',
      '决定',
      '必须',
    ];
    return privateMarkers.any(clause.contains);
  }

  String _repairDialogue(String value) {
    final normalized = value.trim();
    if (normalized.length <= 160) {
      return normalized;
    }
    return _trimToCompleteSentence(normalized, maxChars: 160);
  }

  String _repairInnerState(String value, {required String fallbackIntent}) {
    final normalized = value.trim();
    if (_classifyInnerState(normalized).isNone) {
      return normalized;
    }

    final clauses = _splitClauses(normalized)
        .where((clause) => _classifyInnerState(clause).isNone)
        .map(_dropLeadingConjunction)
        .where((clause) => clause.trim().isNotEmpty)
        .toList(growable: false);
    final repaired = _joinClauses(clauses);
    if (repaired.isNotEmpty && _classifyInnerState(repaired).isNone) {
      return _ensureChinesePeriod(repaired);
    }
    return _fallbackInnerState(fallbackIntent);
  }

  String _repairProseFragment(
    String value, {
    required CharacterVisibleContext? context,
    required String visibleAction,
    required String dialogue,
    required String innerState,
  }) {
    var normalized = value.trim();
    if (_isPlaceholder(normalized) || _containsDraftingMeta([normalized])) {
      normalized = '';
    }
    if (normalized.isEmpty) {
      normalized = _fallbackProseFragment(
        context: context,
        visibleAction: visibleAction,
        dialogue: dialogue,
        innerState: innerState,
      );
    }
    return _trimToCompleteSentence(normalized, maxChars: 260);
  }

  String _fallbackProseFragment({
    required CharacterVisibleContext? context,
    required String visibleAction,
    required String dialogue,
    required String innerState,
  }) {
    final parts = <String>[];
    final name = context?.characterName.trim() ?? '';
    final action = visibleAction.trim();
    if (action.isNotEmpty) {
      parts.add(
        name.isEmpty || action.startsWith(name) ? action : '$name$action',
      );
    }
    final spoken = dialogue.trim();
    if (spoken.isNotEmpty) {
      parts.add(
        name.isEmpty
            ? '“${_stripOuterQuotes(spoken)}”'
            : '$name说：“${_stripOuterQuotes(spoken)}”',
      );
    }
    final thought = innerState.trim();
    if (thought.isNotEmpty) {
      parts.add(thought);
    }
    return _ensureChinesePeriod(parts.join('，'));
  }

  String _stripOuterQuotes(String value) {
    var result = value.trim();
    while (result.length >= 2 &&
        ((result.startsWith('“') && result.endsWith('”')) ||
            (result.startsWith('"') && result.endsWith('"')))) {
      result = result.substring(1, result.length - 1).trim();
    }
    return result;
  }

  List<String> _splitClauses(String value) {
    return value
        .replaceAll(RegExp(r'[。！？!?；;]'), '，')
        .split(RegExp(r'[，,]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  String _joinClauses(List<String> clauses) {
    return clauses.map(_trimTrailingPunctuation).join('，').trim();
  }

  String _dropLeadingConjunction(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^(但|但是|可|可是|然而|不过|只是|于是)'), '')
        .trim();
  }

  String _fallbackInnerState(String intent) {
    final normalizedIntent = _trimTrailingPunctuation(intent.trim());
    if (normalizedIntent.isEmpty) {
      return '我必须先稳住自己。';
    }
    return _ensureChinesePeriod('我必须$normalizedIntent');
  }

  String _trimTrailingPunctuation(String value) {
    return value.trim().replaceFirst(RegExp(r'[。！？!?；;，,]+$'), '').trim();
  }

  String _ensureChinesePeriod(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'[。！？!?]$').hasMatch(trimmed)) {
      return trimmed;
    }
    return '$trimmed。';
  }

  String _trimToCompleteSentence(String value, {required int maxChars}) {
    final trimmed = value.trim();
    if (trimmed.length <= maxChars) {
      return trimmed;
    }
    final prefix = trimmed.substring(0, maxChars);
    final lastStop = prefix.lastIndexOf(RegExp(r'[。！？!?]'));
    if (lastStop > 0) {
      return prefix.substring(0, lastStop + 1).trim();
    }
    return prefix.trim();
  }

  List<CharacterMemoryDelta> _privateMemoryDeltas({
    required int round,
    required CharacterVisibleContext context,
    required String intent,
    required String innerState,
  }) {
    final content = _firstNonEmpty([innerState, intent]);
    if (content.isEmpty) return const <CharacterMemoryDelta>[];
    final hash = _stableHash('${context.characterId}|$round|$content');
    return [
      CharacterMemoryDelta(
        deltaId: 'role-${context.characterId}-$round-$hash',
        characterId: context.characterId,
        kind: innerState.trim().isNotEmpty
            ? CharacterMemoryDeltaKind.emotion
            : CharacterMemoryDeltaKind.intention,
        content: content,
        acl: VisibilityAcl.characters({context.characterId}),
        sourceRound: round,
        sourceTurnId: 'role:${context.characterId}:$round',
        confidence: 0.72,
      ),
    ];
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  String _stableHash(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

enum _InnerStateIssueKind { none, backstory, bodySensation, worldExposition }

class _InnerStateIssue {
  const _InnerStateIssue(this.kind, this.fragment);

  const _InnerStateIssue.none() : this(_InnerStateIssueKind.none, '');

  final _InnerStateIssueKind kind;
  final String fragment;

  bool get isNone => kind == _InnerStateIssueKind.none;
}
