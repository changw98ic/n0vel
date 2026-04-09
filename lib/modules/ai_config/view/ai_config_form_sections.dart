// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';

class AIConfigCopy {
  final Locale locale;

  AIConfigCopy._(this.locale);

  static AIConfigCopy of(BuildContext context) {
    return AIConfigCopy._(Localizations.localeOf(context));
  }

  bool get _isZh => locale.languageCode.startsWith('zh');

  String get aiConfig_title => _isZh ? 'AI 配置' : 'AI Config';
  String get aiConfig_tab_modelConfig => _isZh ? '模型配置' : 'Model Config';
  String get aiConfig_tab_functionMapping =>
      _isZh ? '功能映射' : 'Function Mapping';
  String get aiConfig_tab_promptManager =>
      _isZh ? 'Prompt 管理' : 'Prompt Manager';
  String get aiConfig_tab_usageStats => _isZh ? '使用统计' : 'Usage Stats';
  String get aiConfig_loadFailed => _isZh ? '加载失败' : 'Load failed';
  String get aiConfig_tierConfig_description => _isZh
      ? '为不同能力层级配置模型、接口和参数。'
      : 'Configure models, endpoints, and parameters for each capability tier.';
  String get aiConfig_searchPrompts =>
      _isZh ? '搜索 Prompt 模板' : 'Search prompt templates';
  String get aiConfig_new => _isZh ? '新建' : 'New';
  String get aiConfig_todayRequests => _isZh ? '今日请求' : 'Today Requests';
  String get aiConfig_todayTokens => _isZh ? '今日 Tokens' : 'Today Tokens';
  String get aiConfig_weekRequests => _isZh ? '本周请求' : 'Week Requests';
  String get aiConfig_weekTokens => _isZh ? '本周 Tokens' : 'Week Tokens';
  String get aiConfig_byModelStats => _isZh ? '按模型统计' : 'By Model';
  String get aiConfig_timesCount => _isZh ? '次' : 'times';
  String get aiConfig_tokens => 'tokens';
  String get aiConfig_byFunctionStats => _isZh ? '按功能统计' : 'By Function';
  String get aiConfig_test => _isZh ? '测试' : 'Test';
  String get aiConfig_testingConnection =>
      _isZh ? '正在测试连接...' : 'Testing connection...';
  String get aiConfig_connectionSuccess =>
      _isZh ? '连接成功' : 'Connection successful';
  String get aiConfig_connectionFailed => _isZh ? '连接失败' : 'Connection failed';
  String get aiConfig_testFailed => _isZh ? '测试失败' : 'Test failed';
  String get aiConfig_providerType => _isZh ? '服务商类型' : 'Provider Type';
  String get aiConfig_provider_openai => 'OpenAI';
  String get aiConfig_provider_anthropic => 'Anthropic';
  String get aiConfig_provider_ollama => 'Ollama';
  String get aiConfig_provider_azure => 'Azure';
  String get aiConfig_provider_custom => _isZh ? '自定义' : 'Custom';
  String get aiConfig_apiEndpoint => _isZh ? 'API 端点' : 'API Endpoint';
  String get aiConfig_apiKey => 'API Key';
  String get aiConfig_modelName => _isZh ? '模型名称' : 'Model Name';
  String get aiConfig_advancedParams => _isZh ? '高级参数' : 'Advanced Parameters';
  String get aiConfig_saveConfig => _isZh ? '保存配置' : 'Save Config';
  String get aiConfig_configSaved => _isZh ? '配置已保存' : 'Configuration saved';
  String get aiConfig_systemPrompt => _isZh ? '系统提示词' : 'System Prompt';
  String get aiConfig_edit => _isZh ? '编辑' : 'Edit';
  String get aiConfig_copy => _isZh ? '复制' : 'Copy';
  String get aiConfig_icon_edit => _isZh ? '编辑' : 'Edit';
  String get aiConfig_icon_chat => _isZh ? '对话' : 'Chat';
  String get aiConfig_icon_person => _isZh ? '角色' : 'Person';
  String get aiConfig_icon_review => _isZh ? '审阅' : 'Review';
  String get aiConfig_icon_extract => _isZh ? '提取' : 'Extract';
  String get aiConfig_icon_check => _isZh ? '检查' : 'Check';
  String get aiConfig_icon_timeline => _isZh ? '时间线' : 'Timeline';
  String get aiConfig_icon_warning => _isZh ? '警告' : 'Warning';
  String get aiConfig_icon_summarize => _isZh ? '摘要' : 'Summarize';
  String get aiConfig_icon_visibility => _isZh ? '视角' : 'Visibility';
  String get aiConfig_newPromptTemplate =>
      _isZh ? '新建 Prompt 模板' : 'New Prompt Template';
  String get aiConfig_templateId => _isZh ? '模板 ID' : 'Template ID';
  String get aiConfig_templateIdHint =>
      _isZh ? '例如 chapter_review' : 'For example: chapter_review';
  String get aiConfig_error_validation_templateId =>
      _isZh ? '模板 ID 必填' : 'Template ID is required';
  String get aiConfig_templateName => _isZh ? '模板名称' : 'Template Name';
  String get aiConfig_templateNameHint =>
      _isZh ? '例如章节审阅' : 'For example: Chapter Review';
  String get aiConfig_error_validation_templateName =>
      _isZh ? '模板名称必填' : 'Template name is required';
  String get aiConfig_description => _isZh ? '描述' : 'Description';
  String get aiConfig_descriptionHint =>
      _isZh ? '描述模板用途' : 'Describe what the template does';
  String get aiConfig_icon => _isZh ? '图标' : 'Icon';
  String get aiConfig_systemPromptLabel =>
      _isZh ? '系统 Prompt' : 'System Prompt';
  String get aiConfig_systemPromptHint =>
      _isZh ? '输入系统提示词' : 'Enter the system prompt';
  String get aiConfig_error_validation_systemPrompt =>
      _isZh ? '系统 Prompt 必填' : 'System prompt is required';
  String get aiConfig_userPromptTemplate =>
      _isZh ? '用户 Prompt 模板' : 'User Prompt Template';
  String get aiConfig_userPromptTemplateHint =>
      _isZh ? '可选，占位模板' : 'Optional template with placeholders';
  String get aiConfig_cancel => _isZh ? '取消' : 'Cancel';
  String get aiConfig_save => _isZh ? '保存' : 'Save';
  String get aiConfig_templateSaved => _isZh ? '模板已保存' : 'Template saved';
}

class ProviderTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const ProviderTypeDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: s.aiConfig_providerType,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: 'openai',
          child: Text(s.aiConfig_provider_openai),
        ),
        DropdownMenuItem(
          value: 'anthropic',
          child: Text(s.aiConfig_provider_anthropic),
        ),
        DropdownMenuItem(
          value: 'ollama',
          child: Text(s.aiConfig_provider_ollama),
        ),
        DropdownMenuItem(
          value: 'azure',
          child: Text(s.aiConfig_provider_azure),
        ),
        DropdownMenuItem(
          value: 'custom',
          child: Text(s.aiConfig_provider_custom),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class ConfigTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final Widget? suffixIcon;

  const ConfigTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class AdvancedParamsSection extends StatelessWidget {
  final double temperature;
  final int maxTokens;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<int> onMaxTokensChanged;

  const AdvancedParamsSection({
    super.key,
    required this.temperature,
    required this.maxTokens,
    required this.onTemperatureChanged,
    required this.onMaxTokensChanged,
  });

  /// 将 token 数转换为 slider 位置（对数刻度）
  /// slider 0→256, 1→512, 2→1K, 3→2K, ... 12→1M
  static double _tokensToSlider(int tokens) {
    if (tokens <= 256) return 0;
    if (tokens >= 1048576) return 12;
    final exp = _log2(tokens.toDouble());
    return (exp - 8).clamp(0.0, 12.0);
  }

  /// 将 slider 位置转换为 token 数
  static int _sliderToTokens(double slider) {
    // 2^(8 + slider)
    return (1 << (8 + slider.round()));
  }

  static double _log2(double x) {
    // ln(x) / ln(2)
    const ln2 = 0.6931471805599453;
    int exp = 0;
    while (x >= 2) {
      x /= 2;
      exp++;
    }
    return exp + (x > 1 ? (x - 1) / ln2 : 0.0);
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 1048576) return '1M';
    if (tokens >= 1024) return '${tokens ~/ 1024}K';
    return tokens.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return ExpansionTile(
      title: Text(s.aiConfig_advancedParams),
      children: [
        Row(
          children: [
            const Text('Temperature'),
            Expanded(
              child: Slider(
                value: temperature,
                min: 0,
                max: 2,
                divisions: 20,
                label: temperature.toStringAsFixed(1),
                onChanged: onTemperatureChanged,
              ),
            ),
            Text(temperature.toStringAsFixed(1)),
          ],
        ),
        Row(
          children: [
            const Text('Max Tokens'),
            Expanded(
              child: Slider(
                value: _tokensToSlider(maxTokens),
                min: 0,
                max: 12,
                divisions: 12,
                label: _formatTokens(maxTokens),
                onChanged: (value) =>
                    onMaxTokensChanged(_sliderToTokens(value)),
              ),
            ),
            Text(_formatTokens(maxTokens)),
          ],
        ),
      ],
    );
  }
}

class PromptTemplateActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onCopy;

  const PromptTemplateActions({
    super.key,
    required this.onEdit,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit),
          label: Text(s.aiConfig_edit),
        ),
        TextButton.icon(
          onPressed: onCopy,
          icon: const Icon(Icons.content_copy),
          label: Text(s.aiConfig_copy),
        ),
      ],
    );
  }
}

class PromptManagerToolbar extends StatelessWidget {
  final VoidCallback onCreateTemplate;

  const PromptManagerToolbar({super.key, required this.onCreateTemplate});

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return Material(
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: s.aiConfig_searchPrompts,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onCreateTemplate,
            icon: const Icon(Icons.add),
            label: Text(s.aiConfig_new),
          ),
        ],
      ),
      ),
    );
  }
}
