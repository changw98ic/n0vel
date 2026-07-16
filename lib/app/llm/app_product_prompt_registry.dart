import 'app_llm_client_types.dart';
import 'app_llm_prompt_invocation.dart';
import 'app_llm_prompt_release.dart';
import 'app_llm_prompt_renderer.dart';

final class AppProductPromptRegistration {
  const AppProductPromptRegistration({
    required this.stageId,
    required this.callSiteId,
    required this.variantId,
    required this.release,
  });

  final String stageId;
  final String callSiteId;
  final String variantId;
  final PromptRelease release;

  GenerationBundleBinding get binding => GenerationBundleBinding(
    stageId: stageId,
    callSiteId: callSiteId,
    variantId: variantId,
    promptReleaseRef: release.ref,
  );
}

final class AppProductPromptInvocation {
  const AppProductPromptInvocation({
    required this.registration,
    required this.generationBundleHash,
  });

  final AppProductPromptRegistration registration;
  final String generationBundleHash;

  PromptRelease get release => registration.release;
  PromptReleaseRef get promptReleaseRef => release.ref;
  String get stageId => registration.stageId;
  String get callSiteId => registration.callSiteId;
  String get variantId => registration.variantId;

  AppLlmRenderedPrompt render(Object? resolvedVariables) =>
      AppLlmPromptRendererRegistry.builtIn.render(
        release: release,
        resolvedVariables: resolvedVariables,
      );

  PromptInvocationEvidence evidence({
    required Iterable<AppLlmChatMessage> messages,
    required Object? resolvedVariables,
  }) => PromptInvocationEvidence(
    release: release,
    promptReleaseRef: release.ref,
    messages: messages,
    resolvedVariables: resolvedVariables,
  );
}

final class AppProductPromptRegistry {
  AppProductPromptRegistry._(Iterable<AppProductPromptRegistration> values)
    : registrations = List<AppProductPromptRegistration>.unmodifiable(values),
      generationBundle = GenerationBundle(
        bundleId: 'user-reachable-product-prompts-v1',
        releases: <GenerationBundleBinding>[
          for (final value in values) value.binding,
        ],
      );

  static final AppProductPromptRegistry current =
      AppProductPromptRegistry._(<AppProductPromptRegistration>[
        AppProductPromptRegistration(
          stageId: 'workbench',
          callSiteId: 'rewrite',
          variantId: 'zh',
          release: _release(
            templateId: 'workbench_rewrite',
            systemTemplate: workbenchRewriteSystemTemplate,
            userTemplate: workbenchUserTemplate,
            variablesSchema: workbenchVariablesSchema,
          ),
        ),
        AppProductPromptRegistration(
          stageId: 'workbench',
          callSiteId: 'continue',
          variantId: 'zh',
          release: _release(
            templateId: 'workbench_continue',
            systemTemplate: workbenchContinueSystemTemplate,
            userTemplate: workbenchUserTemplate,
            variablesSchema: workbenchVariablesSchema,
          ),
        ),
        AppProductPromptRegistration(
          stageId: 'simulation',
          callSiteId: 'real-agent-turn',
          variantId: 'zh',
          release: _release(
            templateId: 'simulation_real_agent_turn',
            systemTemplate: simulationRealAgentSystemTemplate,
            userTemplate: simulationRealAgentUserTemplate,
            variablesSchema: simulationRealAgentVariablesSchema,
          ),
        ),
      ]);

  final List<AppProductPromptRegistration> registrations;
  final GenerationBundle generationBundle;

  AppProductPromptInvocation invocation({
    required String stageId,
    required String callSiteId,
    String variantId = 'zh',
  }) {
    final matches = registrations.where(
      (registration) =>
          registration.stageId == stageId &&
          registration.callSiteId == callSiteId &&
          registration.variantId == variantId,
    );
    if (matches.length != 1) {
      throw StateError(
        'unknown product prompt call-site: $stageId/$callSiteId/$variantId',
      );
    }
    return AppProductPromptInvocation(
      registration: matches.single,
      generationBundleHash: generationBundle.bundleHash,
    );
  }
}

const String workbenchRewriteSystemTemplate =
    '你是中文小说改写助手。只输出最终改写结果，不要解释，不要使用 Markdown、标题、编号或引号。';
const String workbenchContinueSystemTemplate =
    '你是中文小说续写助手。只输出需要追加的新内容，不要解释，不要重复原文，不要使用 Markdown、标题、编号或引号。';
const String workbenchUserTemplate =
    '任务类型：{{taskType}}\n\n作者意图：{{effectivePrompt}}\n\n'
    '请求配置：{{providerSummary}}\n\n接口：{{endpointLabel}}\n\n'
    '风格约束：{{styleSummary}}\n\n章节上下文：{{sceneSummary}}\n\n'
    '{{characterSummary}}\n\n{{worldSummary}}\n\n'
    '模拟摘要：{{simulationSummary}}\n\n上一段：{{previousText}}\n\n'
    '原文：\n{{originalText}}\n\n下一段：{{nextText}}';
const String simulationRealAgentSystemTemplate =
    '你是小说场景模拟中的真实多 Agent 角色。只根据本次提供的角色职责、现场上下文和先前回合，输出可被正文生成引用的中文内容；保持角色现场判断口吻，不解释系统规则。';
const String simulationRealAgentUserTemplate =
    '角色：{{label}}\n\n目标：{{goal}}\n\n固定提示：{{agentPrompt}}\n\n'
    '任务：真实多 Agent 场景模拟\n\n回合：{{round}}/{{rounds}}\n\n'
    '作者目标：{{authorGoal}}\n\n场景上下文：{{sceneContext}}\n\n'
    '此前回合输出：{{priorOutputs}}\n\n'
    '请给出 {{label}} 本回合的判断、行动/阻力、以及对正文生成的约束。';

const Map<String, Object?> workbenchVariablesSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>[
    'taskType',
    'effectivePrompt',
    'providerSummary',
    'endpointLabel',
    'styleSummary',
    'sceneSummary',
    'characterSummary',
    'worldSummary',
    'simulationSummary',
    'previousText',
    'originalText',
    'nextText',
  ],
  'properties': <String, Object?>{
    'taskType': <String, Object?>{'type': 'string'},
    'effectivePrompt': <String, Object?>{'type': 'string'},
    'providerSummary': <String, Object?>{'type': 'string'},
    'endpointLabel': <String, Object?>{'type': 'string'},
    'styleSummary': <String, Object?>{'type': 'string'},
    'sceneSummary': <String, Object?>{'type': 'string'},
    'characterSummary': <String, Object?>{'type': 'string'},
    'worldSummary': <String, Object?>{'type': 'string'},
    'simulationSummary': <String, Object?>{'type': 'string'},
    'previousText': <String, Object?>{'type': 'string'},
    'originalText': <String, Object?>{'type': 'string'},
    'nextText': <String, Object?>{'type': 'string'},
  },
};

const Map<String, Object?> simulationRealAgentVariablesSchema =
    <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[
        'label',
        'goal',
        'agentPrompt',
        'round',
        'rounds',
        'sceneContext',
        'authorGoal',
        'priorOutputs',
      ],
      'properties': <String, Object?>{
        'label': <String, Object?>{'type': 'string'},
        'goal': <String, Object?>{'type': 'string'},
        'agentPrompt': <String, Object?>{'type': 'string'},
        'round': <String, Object?>{'type': 'integer'},
        'rounds': <String, Object?>{'type': 'integer'},
        'sceneContext': <String, Object?>{'type': 'string'},
        'authorGoal': <String, Object?>{'type': 'string'},
        'priorOutputs': <String, Object?>{'type': 'string'},
      },
    };

PromptRelease _release({
  required String templateId,
  required String systemTemplate,
  required String userTemplate,
  required Object? variablesSchema,
}) => PromptRelease(
  templateId: templateId,
  semanticVersion: '1.0.0',
  language: 'zh',
  systemTemplate: systemTemplate,
  userTemplate: userTemplate,
  variablesSchemaSnapshot: variablesSchema,
  outputSchemaSnapshot: const <String, Object?>{'type': 'string'},
  rendererRelease: AppLlmPromptRendererRegistry.strictRendererRelease,
  parserRelease: 'plain-text-output-parser-v1',
  repairPolicySnapshot: const <String, Object?>{
    'policy': 'bounded-transport-retry-v1',
    'maxTransientRetries': 3,
  },
  owner: 'product-llm',
  changeNote: 'Freeze user-reachable non-pipeline product prompt identity.',
  createdAt: DateTime.utc(2026, 7, 13),
);
