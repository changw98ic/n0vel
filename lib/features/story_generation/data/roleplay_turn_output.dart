part of 'scene_pipeline_models.dart';

// ---------------------------------------------------------------------------
// Roleplay turn output (replaces free-form DynamicRoleAgentOutput in pipeline)
// ---------------------------------------------------------------------------

class RolePlayTurnOutput {
  RolePlayTurnOutput({
    required this.characterId,
    required this.name,
    required this.stance,
    required this.action,
    required this.taboo,
    required List<RetrievalIntent> retrievalIntents,
    this.disclosure = '',
    this.proseFragment = '',
    this.presentation,
    Map<String, Object?> metadata = const {},
  }) : retrievalIntents = _immutableList(retrievalIntents),
       metadata = _immutableMap(metadata);

  final String characterId;
  final String name;
  final String stance;
  final String action;
  final String taboo;
  final List<RetrievalIntent> retrievalIntents;
  final String disclosure;
  final String proseFragment;
  final PresentationState? presentation;
  final Map<String, Object?> metadata;

  factory RolePlayTurnOutput.fromDynamicAgentOutput(
    DynamicRoleAgentOutput output,
  ) {
    final lines = output.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    String stance = '';
    String action = '';
    String taboo = '';
    String disclosure = '';
    String proseFragment = '';
    final retrievalIntents = <RetrievalIntent>[];
    final l = StoryPromptTemplates.locale;
    final stancePrefix = '${l.stanceLabel}${l.colon}';
    final actionPrefix = '${l.actionLabel}${l.colon}';
    final tabooPrefix = '${l.tabooLabel}${l.colon}';
    final retrievalPrefix = '${l.retrievalLabel}${l.colon}';
    const disclosurePrefix = '披露：';
    const proseFragmentPrefix = '正文片段：';
    const processPrefix = '过程：';
    const statePrefix = '局面：';
    for (final line in lines) {
      if (line.startsWith(stancePrefix)) {
        stance = line.substring(stancePrefix.length).trim();
      } else if (line.startsWith(actionPrefix)) {
        action = line.substring(actionPrefix.length).trim();
      } else if (line.startsWith(tabooPrefix)) {
        taboo = line.substring(tabooPrefix.length).trim();
      } else if (line.startsWith(disclosurePrefix)) {
        disclosure = line.substring(disclosurePrefix.length).trim();
      } else if (line.startsWith(proseFragmentPrefix)) {
        proseFragment = line.substring(proseFragmentPrefix.length).trim();
      } else if (line.startsWith(processPrefix)) {
        final process = line.substring(processPrefix.length).trim();
        disclosure = _appendDisclosure(disclosure, process);
      } else if (line.startsWith(statePrefix)) {
        final state = line.substring(statePrefix.length).trim();
        disclosure = _appendDisclosure(disclosure, state);
      } else if (line.startsWith(retrievalPrefix)) {
        final intent = _parseRetrievalIntent(
          line.substring(retrievalPrefix.length).trim(),
        );
        if (intent != null) {
          retrievalIntents.add(intent);
        }
      }
    }

    return RolePlayTurnOutput(
      characterId: output.characterId,
      name: output.name,
      stance: stance,
      action: action,
      taboo: taboo,
      retrievalIntents: retrievalIntents,
      disclosure: disclosure,
      proseFragment: proseFragment,
    );
  }

  static String _appendDisclosure(String current, String value) {
    if (value.isEmpty) return current;
    if (current.isEmpty) return value;
    return '$current / $value';
  }

  static RetrievalIntent? _parseRetrievalIntent(String raw) {
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    return RetrievalIntent(
      toolName: parts[0].trim(),
      query: parts[1].trim(),
      purpose: parts.length > 2 ? parts[2].trim() : '',
    );
  }
}
