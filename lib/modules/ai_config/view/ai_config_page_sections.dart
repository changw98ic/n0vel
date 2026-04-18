import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../features/ai_config/data/ai_config_repository.dart';
import '../../../features/ai_config/domain/model_config.dart';
import 'ai_config_form_sections.dart';
import 'ai_config_page_common_widgets.dart';
import 'ai_config_page_template_widgets.dart';

class AITierConfigCard extends StatelessWidget {
  final ModelTier tier;

  const AITierConfigCard({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AIConfigTierCardHeader(
              tier: tier,
              testLabel: s.aiConfig_test,
              onTestConnection: () => _testConnection(context),
            ),
            const Divider(height: 24),
            AIModelConfigForm(tier: tier),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection(BuildContext context) async {
    final s = AIConfigCopy.of(context);
    showAIConfigLoadingDialog(
      context: context,
      message: s.aiConfig_testingConnection,
    );

    try {
      final repository = Get.find<AIConfigRepository>();
      final result = await repository.testConnection(tier);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? s.aiConfig_connectionSuccess
                  : result.errorMessage ?? s.aiConfig_connectionFailed,
            ),
            backgroundColor: aiConfigResultColor(result.success),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.aiConfig_testFailed}: $e'),
            backgroundColor: aiConfigFailureColor,
          ),
        );
      }
    }
  }
}

class AIModelConfigForm extends StatefulWidget {
  final ModelTier tier;

  const AIModelConfigForm({super.key, required this.tier});

  @override
  State<AIModelConfigForm> createState() => _AIModelConfigFormState();
}

class _AIModelConfigFormState extends State<AIModelConfigForm> {
  late TextEditingController _modelController;
  late TextEditingController _endpointController;
  late TextEditingController _apiKeyController;
  late double _temperature;
  late int _maxTokens;

  String _providerType = 'openai';

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _endpointController = TextEditingController();
    _apiKeyController = TextEditingController();
    _temperature = 0.7;
    _maxTokens = 4096;
    _loadConfig();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _endpointController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final repository = Get.find<AIConfigRepository>();
    final config = await repository.getModelConfig(widget.tier);
    if (config != null && mounted) {
      setState(() {
        _providerType = config.providerType;
        _modelController.text = config.modelName;
        _endpointController.text = config.apiEndpoint ?? '';
        _temperature = config.temperature;
        _maxTokens = config.maxOutputTokens;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProviderTypeDropdown(
          value: _providerType,
          onChanged: (value) {
            setState(() {
              _providerType = value ?? 'openai';
              _endpointController.text =
                  aiConfigDefaultEndpointForProvider(value);
            });
          },
        ),
        SizedBox(height: 16.h),
        ConfigTextField(
          controller: _endpointController,
          labelText: s.aiConfig_apiEndpoint,
          hintText: 'https://api.openai.com/v1',
        ),
        SizedBox(height: 16.h),
        ConfigTextField(
          controller: _apiKeyController,
          labelText: s.aiConfig_apiKey,
          obscureText: true,
          suffixIcon: const Icon(Icons.visibility_off),
        ),
        SizedBox(height: 16.h),
        ConfigTextField(
          controller: _modelController,
          labelText: s.aiConfig_modelName,
          hintText: 'gpt-4 / claude-3-opus / qwen2.5:14b',
        ),
        SizedBox(height: 16.h),
        AdvancedParamsSection(
          temperature: _temperature,
          maxTokens: _maxTokens,
          onTemperatureChanged: (value) {
            setState(() => _temperature = value);
          },
          onMaxTokensChanged: (value) {
            setState(() => _maxTokens = value);
          },
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saveConfig,
            icon: const Icon(Icons.save),
            label: Text(s.aiConfig_saveConfig),
          ),
        ),
      ],
    );
  }

  Future<void> _saveConfig() async {
    final repository = Get.find<AIConfigRepository>();
    await repository.saveModelConfig(
      tier: widget.tier,
      providerType: _providerType,
      modelName: _modelController.text,
      apiEndpoint: _endpointController.text,
      apiKey: _apiKeyController.text,
      temperature: _temperature,
      maxOutputTokens: _maxTokens,
    );

    if (mounted) {
      final s = AIConfigCopy.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.aiConfig_configSaved)));
    }
  }
}

class AIFunctionMappingCard extends StatelessWidget {
  final AIFunction function;
  final FunctionMapping mapping;

  const AIFunctionMappingCard({
    super.key,
    required this.function,
    required this.mapping,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ListTile(
        leading: Icon(function.icon),
        title: Text(function.label),
        subtitle: Text(function.description),
        trailing: DropdownButton<ModelTier>(
          value: mapping.useOverride && mapping.overrideTier != null
              ? mapping.overrideTier
              : function.defaultTier,
          items: buildAIConfigTierMenuItems(),
          onChanged: (tier) {
            if (tier != null) {
              _updateMapping(tier);
            }
          },
        ),
      ),
    );
  }

  void _updateMapping(ModelTier tier) {
    final repository = Get.find<AIConfigRepository>();
    repository.updateFunctionMapping(functionKey: function.key, tier: tier);
  }
}

class AIPromptTemplateCard extends StatelessWidget {
  final PromptTemplate template;

  const AIPromptTemplateCard({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ExpansionTile(
        leading: Icon(template.icon),
        title: Text(template.name),
        subtitle: Text(template.description),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.aiConfig_systemPrompt,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    template.systemPrompt,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12.sp),
                  ),
                ),
                SizedBox(height: 16.h),
                PromptTemplateActions(onEdit: () {}, onCopy: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AIUsageStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const AIUsageStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: AIConfigUsageStatContent(
          title: title,
          value: value,
          icon: icon,
          color: color,
        ),
      ),
    );
  }
}

class AIPromptTemplateEditorDialog extends StatefulWidget {
  const AIPromptTemplateEditorDialog({super.key});

  @override
  State<AIPromptTemplateEditorDialog> createState() =>
      _AIPromptTemplateEditorDialogState();
}

class _AIPromptTemplateEditorDialogState
    extends State<AIPromptTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _userPromptController = TextEditingController();
  String _selectedIcon = 'edit_note';

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _systemPromptController.dispose();
    _userPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    return AlertDialog(
      title: Text(s.aiConfig_newPromptTemplate),
      content: SizedBox(
        width: 600.w,
        child: AIConfigTemplateEditorForm(
          formKey: _formKey,
          idController: _idController,
          nameController: _nameController,
          descriptionController: _descriptionController,
          systemPromptController: _systemPromptController,
          userPromptController: _userPromptController,
          selectedIcon: _selectedIcon,
          onIconChanged: (value) {
            setState(() => _selectedIcon = value);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.aiConfig_cancel),
        ),
        FilledButton(onPressed: _saveTemplate, child: Text(s.aiConfig_save)),
      ],
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final template = PromptTemplate(
      id: _idController.text,
      name: _nameController.text,
      description: _descriptionController.text,
      systemPrompt: _systemPromptController.text,
      userPromptTemplate: _userPromptController.text.isEmpty
          ? null
          : _userPromptController.text,
      iconName: _selectedIcon,
      createdAt: DateTime.now(),
    );

    final repository = Get.find<AIConfigRepository>();
    await repository.savePromptTemplate(template);

    if (mounted) {
      final s = AIConfigCopy.of(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.aiConfig_templateSaved)));
    }
  }
}
