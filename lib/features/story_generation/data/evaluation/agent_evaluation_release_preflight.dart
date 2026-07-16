/// Pure-Dart release authorization and budget preflight shared by the AOT
/// supervisor and diagnostic probes.
const agentEvaluationPaidReleaseRequiredEnvironment = <String>{
  'RUN_REAL_AGENT_EVAL',
  'REAL_LLM_COST_ACK',
  'ZHIPU_API_KEY',
  'ZHIPU_BASE_URL',
  'AGENT_EVAL_EXECUTION_ID',
  'AGENT_EVAL_REQUIRED_MODELS',
  'AGENT_EVAL_JUDGE_MODEL',
  'AGENT_EVAL_MAX_ATTEMPTS_PER_TRIAL',
  'AGENT_EVAL_MAX_CALLS_PER_TRIAL',
  'AGENT_EVAL_MAX_TOKENS_PER_TRIAL',
  'AGENT_EVAL_MAX_PROMPT_TOKENS_PER_CALL',
  'AGENT_EVAL_MAX_COMPLETION_TOKENS_PER_CALL',
  'AGENT_EVAL_MAX_CALLS',
  'AGENT_EVAL_MAX_TOKENS',
  'AGENT_EVAL_MAX_COST_MICROUSD',
  'AGENT_EVAL_DEADLINE_MS',
  'AGENT_EVAL_JUDGE_MAX_CALLS',
  'AGENT_EVAL_JUDGE_MAX_TOKENS',
  'AGENT_EVAL_JUDGE_MAX_COST_MICROUSD',
  'AGENT_EVAL_JUDGE_MAX_TOKENS_PER_CALL',
  'AGENT_EVAL_JUDGE_MAX_COST_MICROUSD_PER_CALL',
  'AGENT_EVAL_PROMPT_PRICE_MICROUSD_PER_MTOK',
  'AGENT_EVAL_COMPLETION_PRICE_MICROUSD_PER_MTOK',
  'AGENT_EVAL_JUDGE_PROMPT_PRICE_MICROUSD_PER_MTOK',
  'AGENT_EVAL_JUDGE_COMPLETION_PRICE_MICROUSD_PER_MTOK',
  'AGENT_EVAL_HOLDOUT_ACCESS_BUDGET',
  'AGENT_EVAL_PROVIDER_API_REVISION',
  'AGENT_EVAL_CODE_COMMIT',
  'AGENT_EVAL_SOURCE_TREE_HASH',
  'AGENT_EVAL_BUILD_ARTIFACT_HASH',
};

const agentEvaluationDerivedReleaseIdentityEnvironment = <String>{
  'AGENT_EVAL_SDK_ADAPTER_RELEASE_HASH',
  'AGENT_EVAL_TOKENIZER_RELEASE_HASH',
  'AGENT_EVAL_RUNTIME_RELEASE_HASH',
  'AGENT_EVAL_PROVIDER_PRICE_AUTHORITY_ROOT_KEY_ID',
};

final class AgentEvaluationPaidReleasePreflight {
  const AgentEvaluationPaidReleasePreflight({
    required this.missing,
    required this.invalid,
  });

  final List<String> missing;
  final List<String> invalid;

  bool get passed => missing.isEmpty && invalid.isEmpty;
}

AgentEvaluationPaidReleasePreflight validateAgentEvaluationPaidRelease(
  Map<String, String> environment,
) {
  final missing =
      agentEvaluationPaidReleaseRequiredEnvironment
          .where((name) => (environment[name] ?? '').trim().isEmpty)
          .toList()
        ..sort();
  if (missing.isNotEmpty) {
    return AgentEvaluationPaidReleasePreflight(
      missing: List<String>.unmodifiable(missing),
      invalid: const <String>[],
    );
  }
  final invalid = <String>[];
  if (environment['RUN_REAL_AGENT_EVAL'] != '1') {
    invalid.add('RUN_REAL_AGENT_EVAL');
  }
  if (environment['REAL_LLM_COST_ACK'] != 'YES') {
    invalid.add('REAL_LLM_COST_ACK');
  }
  for (final name in agentEvaluationPaidReleaseRequiredEnvironment.where(
    (name) =>
        name.contains('MAX_') ||
        name == 'AGENT_EVAL_DEADLINE_MS' ||
        name == 'AGENT_EVAL_HOLDOUT_ACCESS_BUDGET',
  )) {
    final value = int.tryParse(environment[name]!);
    if (value == null || value <= 0) invalid.add(name);
  }
  for (final name in agentEvaluationPaidReleaseRequiredEnvironment.where(
    (name) => name.endsWith('_PRICE_MICROUSD_PER_MTOK'),
  )) {
    final value = int.tryParse(environment[name]!);
    if (value == null || value < 0) invalid.add(name);
  }
  final digestPattern = RegExp(r'^[a-f0-9]{64}$');
  for (final name in <String>[
    'AGENT_EVAL_SOURCE_TREE_HASH',
    'AGENT_EVAL_BUILD_ARTIFACT_HASH',
  ]) {
    if (!digestPattern.hasMatch(environment[name]!)) invalid.add(name);
  }
  if (!RegExp(
    r'^(?:[a-f0-9]{40}|[a-f0-9]{64})$',
  ).hasMatch(environment['AGENT_EVAL_CODE_COMMIT']!)) {
    invalid.add('AGENT_EVAL_CODE_COMMIT');
  }
  final models = environment['AGENT_EVAL_REQUIRED_MODELS']!
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  if (models.isEmpty) invalid.add('AGENT_EVAL_REQUIRED_MODELS');
  if (models.contains(environment['AGENT_EVAL_JUDGE_MODEL']!.trim())) {
    invalid.add('AGENT_EVAL_JUDGE_MODEL');
  }
  if (!RegExp(
    r'^[A-Za-z0-9_.:-]{1,128}$',
  ).hasMatch(environment['AGENT_EVAL_EXECUTION_ID']!)) {
    invalid.add('AGENT_EVAL_EXECUTION_ID');
  }
  final deadlineMs = int.tryParse(environment['AGENT_EVAL_DEADLINE_MS']!);
  if (deadlineMs == null ||
      deadlineMs > const Duration(hours: 24).inMilliseconds) {
    invalid.add('AGENT_EVAL_DEADLINE_MS');
  }
  _validateCombinedMatrixBudgets(environment, invalid);
  invalid.sort();
  return AgentEvaluationPaidReleasePreflight(
    missing: const <String>[],
    invalid: List<String>.unmodifiable(invalid.toSet()),
  );
}

void _validateCombinedMatrixBudgets(
  Map<String, String> environment,
  List<String> invalid,
) {
  int? number(String name) => int.tryParse(environment[name] ?? '');
  final modelCount = environment['AGENT_EVAL_REQUIRED_MODELS']!
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .length;
  final attempts = number('AGENT_EVAL_MAX_ATTEMPTS_PER_TRIAL');
  final callsPerTrial = number('AGENT_EVAL_MAX_CALLS_PER_TRIAL');
  final promptPerCall = number('AGENT_EVAL_MAX_PROMPT_TOKENS_PER_CALL');
  final completionPerCall = number('AGENT_EVAL_MAX_COMPLETION_TOKENS_PER_CALL');
  final judgeCompletionPerCall = number('AGENT_EVAL_JUDGE_MAX_TOKENS_PER_CALL');
  final promptPrice = number('AGENT_EVAL_PROMPT_PRICE_MICROUSD_PER_MTOK');
  final completionPrice = number(
    'AGENT_EVAL_COMPLETION_PRICE_MICROUSD_PER_MTOK',
  );
  final judgePromptPrice = number(
    'AGENT_EVAL_JUDGE_PROMPT_PRICE_MICROUSD_PER_MTOK',
  );
  final judgeCompletionPrice = number(
    'AGENT_EVAL_JUDGE_COMPLETION_PRICE_MICROUSD_PER_MTOK',
  );
  final judgeCostPerCall = number(
    'AGENT_EVAL_JUDGE_MAX_COST_MICROUSD_PER_CALL',
  );
  if (modelCount == 0 ||
      <int?>[
        attempts,
        callsPerTrial,
        promptPerCall,
        completionPerCall,
        judgeCompletionPerCall,
        promptPrice,
        completionPrice,
        judgePromptPrice,
        judgeCompletionPrice,
        judgeCostPerCall,
      ].any((value) => value == null)) {
    return;
  }

  int ceilPerMillion(int tokens, int price) =>
      tokens == 0 || price == 0 ? 0 : ((tokens * price) + 999999) ~/ 1000000;

  const matrices = 2;
  final slotsPerMatrix = modelCount * 10 * 2 * 3;
  final sutCallsPerMatrix = slotsPerMatrix * attempts! * callsPerTrial!;
  final judgeCallsPerMatrix = slotsPerMatrix * attempts;
  final judgeTokensPerMatrix =
      judgeCallsPerMatrix * (promptPerCall! + judgeCompletionPerCall!);
  final requiredCalls = matrices * (sutCallsPerMatrix + judgeCallsPerMatrix);
  final requiredTokens =
      matrices *
      (sutCallsPerMatrix * (promptPerCall + completionPerCall!) +
          judgeTokensPerMatrix);
  final sutCostPerCall =
      ceilPerMillion(promptPerCall, promptPrice!) +
      ceilPerMillion(completionPerCall, completionPrice!);
  final pricedJudgeCostPerCall =
      ceilPerMillion(promptPerCall, judgePromptPrice!) +
      ceilPerMillion(judgeCompletionPerCall, judgeCompletionPrice!);
  final requiredCost =
      matrices *
      (sutCallsPerMatrix * sutCostPerCall +
          judgeCallsPerMatrix * pricedJudgeCostPerCall);
  final requiredJudgeCost =
      matrices *
      judgeCallsPerMatrix *
      (pricedJudgeCostPerCall > judgeCostPerCall!
          ? pricedJudgeCostPerCall
          : judgeCostPerCall);

  void requireAtLeast(String name, int required) {
    final actual = number(name);
    if (actual == null || actual < required) invalid.add(name);
  }

  requireAtLeast('AGENT_EVAL_MAX_CALLS', requiredCalls);
  requireAtLeast('AGENT_EVAL_MAX_TOKENS', requiredTokens);
  requireAtLeast('AGENT_EVAL_MAX_COST_MICROUSD', requiredCost);
  requireAtLeast('AGENT_EVAL_JUDGE_MAX_CALLS', matrices * judgeCallsPerMatrix);
  requireAtLeast(
    'AGENT_EVAL_JUDGE_MAX_TOKENS',
    matrices * judgeTokensPerMatrix,
  );
  requireAtLeast('AGENT_EVAL_JUDGE_MAX_COST_MICROUSD', requiredJudgeCost);
}
