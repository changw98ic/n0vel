import 'settings_models.dart';

class AppLlmProviderCatalogEntry {
  const AppLlmProviderCatalogEntry({
    required this.id,
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.summary,
    this.requiresApiKey = true,
  });

  final String id;
  final String providerName;
  final String baseUrl;
  final String model;
  final String summary;
  final bool requiresApiKey;

  AppLlmProviderProfile toProfile({String apiKey = ''}) {
    return AppLlmProviderProfile(
      id: id,
      providerName: providerName,
      baseUrl: baseUrl,
      model: model,
      apiKey: apiKey,
    );
  }
}

const String singleChapterDefaultProviderName = '智谱 GLM';
const String singleChapterDefaultBaseUrl =
    'https://open.bigmodel.cn/api/paas/v4';
const String singleChapterDefaultModel = 'glm-5.1';

const List<AppLlmProviderCatalogEntry> appLlmProviderCatalogEntries = [
  AppLlmProviderCatalogEntry(
    id: 'zhipu',
    providerName: '智谱 GLM 中国按量 API',
    baseUrl: singleChapterDefaultBaseUrl,
    model: singleChapterDefaultModel,
    summary: '智谱开放平台国内按量接口，适合中文长文、角色推演与单章生成。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'zhipu-global',
    providerName: 'Z.AI GLM 国际按量 API',
    baseUrl: 'https://api.z.ai/api/paas/v4',
    model: 'glm-5.1',
    summary: 'Z.AI 国际站标准 API 入口，与国内 open.bigmodel.cn 分开配置。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'zhipu-coding-plan-cn',
    providerName: '智谱 GLM Coding Plan 中国',
    baseUrl: 'https://open.bigmodel.cn/api/coding/paas/v4',
    model: 'glm-4.7',
    summary: '智谱国内 Coding Plan 专用 OpenAI 兼容入口，不与普通 API 账单混用。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'zhipu-coding-plan-global',
    providerName: 'Z.AI GLM Coding Plan 国际',
    baseUrl: 'https://api.z.ai/api/coding/paas/v4',
    model: 'glm-4.7',
    summary: 'Z.AI 国际站 Coding Plan 专用入口，适合支持的编程工具场景。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'openai',
    providerName: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-5.4-mini',
    summary: '通用 OpenAI 兼容云端服务。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'kimi',
    providerName: 'Kimi (Moonshot)',
    baseUrl: 'https://api.moonshot.cn/v1',
    model: 'kimi-k2.6',
    summary: 'Moonshot 开放平台按量 API，适合长上下文阅读、分析和改写。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'kimi-coding-plan',
    providerName: 'Kimi Code 会员 Coding API',
    baseUrl: 'https://api.kimi.com/coding/v1',
    model: 'kimi-for-coding',
    summary: 'Kimi Code 会员/Coding API OpenAI 兼容入口，与 Moonshot 按量 API 分开配置。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'deepseek',
    providerName: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
    summary: 'OpenAI 兼容接口，适合低成本通用任务。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'aliyun-dashscope',
    providerName: '阿里百炼 中国按量 API',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
    summary: '阿里云百炼北京地域按量 API，适合中文长文与通用生成。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'aliyun-dashscope-intl',
    providerName: '阿里百炼 国际按量 API',
    baseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus',
    summary: '阿里云百炼新加坡国际部署入口，API Key 与国内地域分开管理。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'aliyun-dashscope-us',
    providerName: '阿里百炼 美国按量 API',
    baseUrl: 'https://dashscope-us.aliyuncs.com/compatible-mode/v1',
    model: 'qwen-plus-us',
    summary: '阿里云百炼美国弗吉尼亚部署入口，部分模型需使用 -us 后缀。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'aliyun-coding-plan',
    providerName: '阿里百炼 Coding Plan 中国',
    baseUrl: 'https://coding.dashscope.aliyuncs.com/v1',
    model: 'qwen3-coder-plus',
    summary: '阿里云百炼 Coding Plan 专属 OpenAI 兼容入口，需使用套餐专属 API Key。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'volcengine-ark',
    providerName: '火山方舟 (Doubao)',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    model: 'doubao-seed-1-6-250615',
    summary: '字节火山方舟在线推理接口，适合豆包通用文本生成。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'volcengine-coding-plan',
    providerName: '火山方舟 Coding Plan',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3',
    model: 'ark-code-latest',
    summary: 'Coding Plan 专用网关，与火山方舟在线推理地址分开配置。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'minimax',
    providerName: 'MiniMax 国际',
    baseUrl: 'https://api.minimax.io/v1',
    model: 'MiniMax-M2.7',
    summary: 'MiniMax OpenAI 兼容接口，适合长上下文与通用对话。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'minimax-cn',
    providerName: 'MiniMax 中国',
    baseUrl: 'https://api.minimaxi.com/v1',
    model: 'MiniMax-M2.7',
    summary: 'MiniMax 中国区 OpenAI 兼容接口，适合国内账号与网络环境。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'minimax-coding-plan',
    providerName: 'MiniMax Coding Plan 国际',
    baseUrl: 'https://api.minimax.io/v1',
    model: 'codex-MiniMax-M2.7',
    summary: 'MiniMax Codex/Coding Plan 推荐配置，国际账号使用国际 endpoint。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'minimax-coding-plan-cn',
    providerName: 'MiniMax Coding Plan 中国',
    baseUrl: 'https://api.minimaxi.com/v1',
    model: 'codex-MiniMax-M2.7',
    summary: 'MiniMax Codex/Coding Plan 推荐配置，中国账号使用 minimaxi endpoint。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'tencent-hunyuan',
    providerName: '腾讯混元',
    baseUrl: 'https://api.hunyuan.cloud.tencent.com/v1',
    model: 'hunyuan-turbos-latest',
    summary: '腾讯混元 OpenAI 兼容接口，适合中文通用生成。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'tencent-tokenhub-plan',
    providerName: '腾讯 TokenHub Token Plan',
    baseUrl: 'https://api.lkeap.cloud.tencent.com/plan/v3',
    model: 'hunyuan-2.0-instruct',
    summary: '腾讯 TokenHub Token Plan 个人版 OpenAI 兼容入口，Key 与混元按量 API 不共用。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'tencent-tokenhub-enterprise',
    providerName: '腾讯 TokenHub 企业版',
    baseUrl: 'https://tokenhub.tencentmaas.com/plan/v3',
    model: 'hunyuan-2.0-instruct',
    summary: '腾讯 TokenHub 企业版套餐入口，适合团队统一服务与用量管理。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'meituan-longcat',
    providerName: '美团 LongCat',
    baseUrl: 'https://api.longcat.chat/openai/v1',
    model: 'LongCat-Flash-Chat',
    summary: '美团 LongCat OpenAI 兼容接口，默认使用 Flash Chat。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'ollama-kimi',
    providerName: 'Ollama Cloud',
    baseUrl: 'https://ollama.com/v1',
    model: 'kimi-k2.6',
    summary: '单章生成路由预设中的角色扮演供应商。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'mimo-usage',
    providerName: 'Xiaomi MiMo 按量 API',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    model: 'mimo-v2-pro',
    summary: '小米 MiMo 标准按量 OpenAI 兼容接口，适合常规生产调用。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'mimo',
    providerName: 'Xiaomi MiMo Token Plan CN',
    baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
    model: 'mimo-v2.5-pro',
    summary: '小米 MiMo 中国区 Token Plan 入口，与按量 API Key/账单分开配置。',
  ),
  AppLlmProviderCatalogEntry(
    id: 'local-ollama',
    providerName: 'Ollama 本地',
    baseUrl: 'http://127.0.0.1:11434/v1',
    model: 'llama3.1',
    summary: '本机 OpenAI 兼容接口，无需 API Key。',
    requiresApiKey: false,
  ),
];

const List<AppLlmProviderProfile> singleChapterProviderPresetProfiles = [
  AppLlmProviderProfile(
    id: 'ollama-kimi',
    providerName: 'Ollama Cloud',
    baseUrl: 'https://ollama.com/v1',
    model: 'kimi-k2.6',
    apiKey: '',
  ),
  AppLlmProviderProfile(
    id: 'mimo',
    providerName: 'Xiaomi MiMo',
    baseUrl: 'https://token-plan-cn.xiaomimimo.com/v1',
    model: 'mimo-v2.5-pro',
    apiKey: '',
  ),
];

const List<AppLlmRequestProviderRoute> singleChapterProviderPresetRoutes = [
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_director_polish',
    providerProfileId: 'ollama-kimi',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_roleplay_turn',
    providerProfileId: 'ollama-kimi',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_roleplay_arbitrate',
    providerProfileId: 'ollama-kimi',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_beat_resolve',
    providerProfileId: 'mimo',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_editorial',
    providerProfileId: 'mimo',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'language_polish',
    providerProfileId: 'mimo',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_combined_review',
    providerProfileId: 'mimo',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_review_*',
    providerProfileId: 'mimo',
  ),
  AppLlmRequestProviderRoute(
    traceNamePattern: 'scene_quality_scoring',
    providerProfileId: 'mimo',
  ),
];
