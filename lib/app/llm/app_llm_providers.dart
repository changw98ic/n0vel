/// Pre-configured LLM provider definitions and lookup utilities.
///
/// Each provider declares its id, display name, default base URL,
/// supported model ids, and optional model alias mappings (e.g. `"kimi-2.6" → "kimi-k2.6"`).
/// The registry is a pure-static constant bag — no async, no IO, no side effects.
library;

class AppLlmProvider {
  const AppLlmProvider({
    required this.id,
    required this.name,
    required this.defaultBaseUrl,
    required this.models,
    this.modelAliases = const {},
  });

  /// Stable programmatic identifier (e.g. `'openai'`, `'kimi'`).
  final String id;

  /// Human-readable display name for the settings UI.
  final String name;

  /// Default API base URL (including version path segment if applicable).
  final String defaultBaseUrl;

  /// Canonical model ids offered by this provider.
  final List<String> models;

  /// Alias → canonical model id mappings for user-input normalisation.
  final Map<String, String> modelAliases;

  bool supportsModel(String model) {
    final normalized = model.trim().toLowerCase();
    if (modelAliases.containsKey(normalized)) return true;
    return models.any((m) => m.toLowerCase() == normalized);
  }

  String resolveModel(String model) {
    final trimmed = model.trim();
    final alias = modelAliases[trimmed.toLowerCase()];
    if (alias != null) return alias;
    return trimmed;
  }
}

class AppLlmProviderRegistry {
  const AppLlmProviderRegistry._();

  static const openai = AppLlmProvider(
    id: 'openai',
    name: 'OpenAI',
    defaultBaseUrl: 'https://api.openai.com/v1',
    models: ['gpt-4.1-mini', 'gpt-5.4', 'gpt-5.4-mini'],
  );

  static const kimi = AppLlmProvider(
    id: 'kimi',
    name: 'Kimi (Moonshot)',
    defaultBaseUrl: 'https://api.moonshot.cn/v1',
    models: ['kimi-k2.6'],
    modelAliases: {'kimi-2.6': 'kimi-k2.6'},
  );

  static const kimiCodingPlan = AppLlmProvider(
    id: 'kimi-coding-plan',
    name: 'Kimi Code 会员 Coding API',
    defaultBaseUrl: 'https://api.kimi.com/coding/v1',
    models: ['kimi-for-coding'],
  );

  static const deepseek = AppLlmProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    defaultBaseUrl: 'https://api.deepseek.com',
    models: ['deepseek-chat', 'deepseek-reasoner'],
  );

  static const mimo = AppLlmProvider(
    id: 'mimo',
    name: 'Xiaomi MiMo Token Plan CN',
    defaultBaseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
    models: [
      'mimo-v2.5-pro',
      'mimo-v2.5',
      'mimo-v2-pro',
      'mimo-v2-omni',
      'mimo-v2-flash',
    ],
    modelAliases: {'mimo-v25-pro': 'mimo-v2.5-pro', 'mimo-v25': 'mimo-v2.5'},
  );

  static const zhipu = AppLlmProvider(
    id: 'zhipu',
    name: '智谱 GLM 中国按量 API',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    models: [
      'glm-5.1',
      'glm-5',
      'glm-5-turbo',
      'glm-4.7',
      'glm-4.7-flash',
      'glm-4.6',
      'glm-4.5',
      'glm-4.5-air',
      'glm-4.5-flash',
      'glm-4-plus',
      'glm-4-flash-250414',
    ],
  );

  static const zhipuGlobal = AppLlmProvider(
    id: 'zhipu-global',
    name: 'Z.AI GLM 国际按量 API',
    defaultBaseUrl: 'https://api.z.ai/api/paas/v4',
    models: ['glm-5.1', 'glm-5', 'glm-5-turbo', 'glm-4.7', 'glm-4.5-air'],
  );

  static const zhipuCodingPlanCn = AppLlmProvider(
    id: 'zhipu-coding-plan-cn',
    name: '智谱 GLM Coding Plan 中国',
    defaultBaseUrl: 'https://open.bigmodel.cn/api/coding/paas/v4',
    models: ['glm-4.7', 'glm-5', 'glm-5.1', 'glm-4.6', 'glm-4.5-air'],
  );

  static const zhipuCodingPlanGlobal = AppLlmProvider(
    id: 'zhipu-coding-plan-global',
    name: 'Z.AI GLM Coding Plan 国际',
    defaultBaseUrl: 'https://api.z.ai/api/coding/paas/v4',
    models: ['glm-4.7', 'glm-5.1', 'glm-5-turbo', 'glm-4.5-air'],
  );

  static const aliyunDashscope = AppLlmProvider(
    id: 'aliyun-dashscope',
    name: '阿里百炼 中国按量 API',
    defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    models: ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen-long', 'qwq-plus'],
  );

  static const aliyunDashscopeIntl = AppLlmProvider(
    id: 'aliyun-dashscope-intl',
    name: '阿里百炼 国际按量 API',
    defaultBaseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    models: ['qwen-plus', 'qwen-turbo', 'qwen-max', 'qwen-long', 'qwq-plus'],
  );

  static const aliyunDashscopeUs = AppLlmProvider(
    id: 'aliyun-dashscope-us',
    name: '阿里百炼 美国按量 API',
    defaultBaseUrl: 'https://dashscope-us.aliyuncs.com/compatible-mode/v1',
    models: ['qwen-plus-us', 'qwen-turbo-us', 'qwen-max-us'],
  );

  static const aliyunCodingPlan = AppLlmProvider(
    id: 'aliyun-coding-plan',
    name: '阿里百炼 Coding Plan 中国',
    defaultBaseUrl: 'https://coding.dashscope.aliyuncs.com/v1',
    models: ['qwen3-coder-plus', 'qwen3-max-2026-01-23'],
  );

  static const volcengineArk = AppLlmProvider(
    id: 'volcengine-ark',
    name: '火山方舟 (Doubao)',
    defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    models: ['doubao-seed-1-6-250615'],
  );

  static const volcengineCodingPlan = AppLlmProvider(
    id: 'volcengine-coding-plan',
    name: '火山方舟 Coding Plan',
    defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3',
    models: ['ark-code-latest', 'doubao-seed-2.0-code'],
  );

  static const minimax = AppLlmProvider(
    id: 'minimax',
    name: 'MiniMax 国际',
    defaultBaseUrl: 'https://api.minimax.io/v1',
    models: ['MiniMax-M2.7'],
  );

  static const minimaxCn = AppLlmProvider(
    id: 'minimax-cn',
    name: 'MiniMax 中国',
    defaultBaseUrl: 'https://api.minimaxi.com/v1',
    models: ['MiniMax-M2.7'],
  );

  static const minimaxCodingPlan = AppLlmProvider(
    id: 'minimax-coding-plan',
    name: 'MiniMax Coding Plan 国际',
    defaultBaseUrl: 'https://api.minimax.io/v1',
    models: ['codex-MiniMax-M2.7'],
  );

  static const minimaxCodingPlanCn = AppLlmProvider(
    id: 'minimax-coding-plan-cn',
    name: 'MiniMax Coding Plan 中国',
    defaultBaseUrl: 'https://api.minimaxi.com/v1',
    models: ['codex-MiniMax-M2.7'],
  );

  static const tencentHunyuan = AppLlmProvider(
    id: 'tencent-hunyuan',
    name: '腾讯混元',
    defaultBaseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
    models: ['hunyuan-turbos-latest', 'hunyuan-pro', 'hunyuan-lite'],
  );

  static const tencentTokenHubPlan = AppLlmProvider(
    id: 'tencent-tokenhub-plan',
    name: '腾讯 TokenHub Token Plan',
    defaultBaseUrl: 'https://api.lkeap.cloud.tencent.com/plan/v3',
    models: ['hunyuan-2.0-instruct', 'glm-5.1', 'minimax-m2.7'],
  );

  static const tencentTokenHubEnterprise = AppLlmProvider(
    id: 'tencent-tokenhub-enterprise',
    name: '腾讯 TokenHub 企业版',
    defaultBaseUrl: 'https://tokenhub.tencentmaas.com/plan/v3',
    models: ['hunyuan-2.0-instruct', 'deepseek-v4-flash', 'glm-5.1'],
  );

  static const meituanLongCat = AppLlmProvider(
    id: 'meituan-longcat',
    name: '美团 LongCat',
    defaultBaseUrl: 'https://api.longcat.chat/openai/v1',
    models: ['LongCat-Flash-Chat'],
  );

  static const mimoUsage = AppLlmProvider(
    id: 'mimo-usage',
    name: 'Xiaomi MiMo 按量 API',
    defaultBaseUrl: 'https://api.xiaomimimo.com/v1',
    models: ['mimo-v2-flash', 'mimo-v2-pro', 'mimo-v2-omni'],
  );

  static const custom = AppLlmProvider(
    id: 'custom',
    name: 'OpenAI 兼容服务',
    defaultBaseUrl: 'https://api.example.com/v1',
    models: [],
  );

  static const List<AppLlmProvider> all = [
    openai,
    kimi,
    kimiCodingPlan,
    deepseek,
    mimoUsage,
    mimo,
    zhipu,
    zhipuGlobal,
    zhipuCodingPlanCn,
    zhipuCodingPlanGlobal,
    aliyunDashscope,
    aliyunDashscopeIntl,
    aliyunDashscopeUs,
    aliyunCodingPlan,
    volcengineArk,
    volcengineCodingPlan,
    minimax,
    minimaxCn,
    minimaxCodingPlan,
    minimaxCodingPlanCn,
    tencentHunyuan,
    tencentTokenHubPlan,
    tencentTokenHubEnterprise,
    meituanLongCat,
    custom,
  ];

  static AppLlmProvider findById(String id) {
    return all.firstWhere((p) => p.id == id, orElse: () => custom);
  }

  static AppLlmProvider findByModel(String model) {
    for (final provider in all) {
      if (provider.id == 'custom') continue;
      if (provider.supportsModel(model)) return provider;
    }
    return custom;
  }

  static bool isKnownModel(String model) {
    return findByModel(model).id != 'custom';
  }
}
