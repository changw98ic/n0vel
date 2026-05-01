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

  static const deepseek = AppLlmProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    defaultBaseUrl: 'https://api.deepseek.com',
    models: ['deepseek-chat', 'deepseek-reasoner'],
  );

  static const mimo = AppLlmProvider(
    id: 'mimo',
    name: 'Xiaomi MiMo',
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
    name: '智谱 GLM',
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

  static const custom = AppLlmProvider(
    id: 'custom',
    name: 'OpenAI 兼容服务',
    defaultBaseUrl: 'https://api.example.com/v1',
    models: [],
  );

  static const List<AppLlmProvider> all = [
    openai,
    kimi,
    deepseek,
    mimo,
    zhipu,
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
