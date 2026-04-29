import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';

import 'context_capsule_compressor.dart';
import '../domain/roleplay_models.dart';
import '../domain/pipeline_models.dart';
import '../domain/scene_models.dart';
import 'story_generation_pass_retry.dart';
import 'tool_intent_parser.dart';

/// Adapts [RolePromptPacket] to legacy plain-text prompt format.
///
/// Legacy consumers expect Chinese-section-header text blocks.
/// This adapter converts structured packets into that format so existing
/// callsites keep working during the migration to structured packets.
class RolePromptAdapter {
  /// Ordered section definitions: (header, field-accessor).
  static const _sections = <(String, String)>[
    ('【当前理解】', 'currentUnderstanding'),
    ('【当前感受】', 'currentFeeling'),
    ('【对他人的看法】', 'viewOfOthers'),
    ('【表层表现】', 'surfaceBehavior'),
    ('【未出口念头】', 'unspokenThoughts'),
    ('【行动意图】', 'actionIntent'),
    ('【对白倾向】', 'dialogueTendency'),
  ];

  /// Convert a [RolePromptPacket] to legacy prompt text.
  ///
  /// Each non-empty field becomes a section with a Chinese bracket header.
  /// Empty fields are omitted entirely. Sections are separated by blank lines.
  static String toLegacyText(RolePromptPacket packet) {
    final values = <String>[
      packet.currentUnderstanding,
      packet.currentFeeling,
      packet.viewOfOthers,
      packet.surfaceBehavior,
      packet.unspokenThoughts,
      packet.actionIntent,
      packet.dialogueTendency,
    ];

    final parts = <String>[];
    for (var i = 0; i < _sections.length; i++) {
      if (values[i].isNotEmpty) {
        parts.add('${_sections[i].$1}\n${values[i]}');
      }
    }
    return parts.join('\n\n');
  }

  /// Check text for hidden-truth leakage patterns.
  ///
  /// Returns a list of violation descriptions. An empty list means the text
  /// is clean — no narrator-omniscient language leaked into character output.
  static List<String> detectHiddenTruthLeakage(String text) {
    const patternSpecs = <(String, bool)>[
      // English patterns
      (r'actually\s', false),
      (r'hidden\s', false),
      (r'secretly\s', false),
      (r"don'?t\s+know", false),
      (r'unknown\s+to', false),
      // Chinese patterns
      ('其实', true),
      ('暗中', true),
      ('不知道', true),
    ];

    final violations = <String>[];
    for (final spec in patternSpecs) {
      final regex = RegExp(spec.$1, caseSensitive: spec.$2);
      if (regex.hasMatch(text)) {
        violations.add('Detected hidden-truth pattern: ${spec.$1}');
      }
    }
    return violations;
  }
}

/// Controller loop for a single role agent that handles on-demand
/// retrieval via tool intents and capsule reinjection.
///
/// Flow:
/// 1. Run the role agent.
/// 2. If the agent emits a retrieval intent, call the retrieval tool.
/// 3. Compress the raw result into a [ContextCapsule].
/// 4. Re-inject only the capsule into the next agent prompt.
/// 5. Repeat until the agent produces a full roleplay turn or
///    the retrieval budget is exhausted.
class RoleAgentController {
  RoleAgentController({
    required AppSettingsStore settingsStore,
    ContextCapsuleCompressor? capsuleCompressor,
    int maxRetrievalRounds = 2,
  })  : _settingsStore = settingsStore,
        _capsuleCompressor =
            capsuleCompressor ?? ContextCapsuleCompressor(),
        _maxRetrievalRounds = maxRetrievalRounds;

  final AppSettingsStore _settingsStore;
  final ContextCapsuleCompressor _capsuleCompressor;
  final int _maxRetrievalRounds;

  final _toolIntentParser = ToolIntentParser();

  /// Runs the role agent with retrieval support.
  ///
  /// [retrievalTool] is called when the agent emits a retrieval intent.
  /// It returns the raw content which is compressed into a capsule.
  /// The capsule (not the raw payload) is re-injected into subsequent
  /// prompts.
  Future<RoleplayTurn> runWithRetrieval({
    required SceneBrief brief,
    required ResolvedSceneCastMember member,
    required SceneDirectorOutput director,
    required Future<String> Function(RetrievalIntent intent) retrievalTool,
  }) async {
    final capsules = <ContextCapsule>[];
    var retrievalRounds = 0;

    while (true) {
      final result = await _requestAgent(
        brief: brief,
        member: member,
        director: director,
        capsules: capsules,
      );

      if (!result.succeeded) {
        throw StateError(
          result.detail ?? 'Role agent failed for ${member.characterId}.',
        );
      }

      final text = result.text!.trim();

      final intent = _toolIntentParser.tryParse(text, member.characterId);
      if (intent != null &&
          intent.isToolAllowed &&
          retrievalRounds < _maxRetrievalRounds) {
        final rawContent = await retrievalTool(intent);

        final budget = PromptBudget(maxChars: 500);
        final capsule = _capsuleCompressor.compress(
          sourceTool: intent.toolName,
          rawContent: rawContent,
          budget: budget,
        );

        if (capsule != null) {
          capsules.add(capsule);
        }

        retrievalRounds++;
        continue;
      }

      return RoleplayTurn.parse(
        characterId: member.characterId,
        name: member.name,
        text: text,
      );
    }
  }

  Future<AppLlmChatResult> _requestAgent({
    required SceneBrief brief,
    required ResolvedSceneCastMember member,
    required SceneDirectorOutput director,
    required List<ContextCapsule> capsules,
  }) {
    final capsuleContext = capsules.isEmpty
        ? ''
        : '补充信息：\n${capsules.map((c) => '  [${c.sourceTool}] ${c.summary}').join('\n')}';

    return requestStoryGenerationPassWithRetry(
      settingsStore: _settingsStore,
      messages: [
        const AppLlmChatMessage(
          role: 'system',
          content:
              'You are a dynamic role agent for a Chinese novel scene. '
              'Output exactly 3 short lines and nothing else:\n'
              '立场：...\n'
              '动作：...\n'
              '禁忌：...\n'
              'If you lack critical context to decide, instead output:\n'
              'RETRIEVE:tool_name:param=value\n'
              'where tool_name is one of: character_profile, '
              'relationship_history, scene_context, world_rule.\n'
              'Keep every line concrete and brief. No prose.',
        ),
        AppLlmChatMessage(
          role: 'user',
          content: [
            '任务：dynamic_role',
            '格式：立场/动作/禁忌',
            '角色：${member.name}(${member.role})',
            '梗概：${_compact(brief.sceneSummary, maxChars: 100)}',
            '导演：${_compact(director.text, maxChars: 120)}',
            if (capsuleContext.isNotEmpty) capsuleContext,
          ].join('\n'),
        ),
      ],
    );
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
