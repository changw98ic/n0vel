import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'ai_config_form_sections.dart';

class AIConfigTemplateIconOption {
  final String name;
  final IconData icon;
  final String label;

  const AIConfigTemplateIconOption({
    required this.name,
    required this.icon,
    required this.label,
  });
}

List<AIConfigTemplateIconOption> buildAIConfigTemplateIconOptions(
  AIConfigCopy s,
) {
  return [
    AIConfigTemplateIconOption(
      name: 'edit_note',
      icon: Icons.edit_note,
      label: s.aiConfig_icon_edit,
    ),
    AIConfigTemplateIconOption(
      name: 'chat',
      icon: Icons.chat,
      label: s.aiConfig_icon_chat,
    ),
    AIConfigTemplateIconOption(
      name: 'person',
      icon: Icons.person,
      label: s.aiConfig_icon_person,
    ),
    AIConfigTemplateIconOption(
      name: 'rate_review',
      icon: Icons.rate_review,
      label: s.aiConfig_icon_review,
    ),
    AIConfigTemplateIconOption(
      name: 'extract',
      icon: Icons.input,
      label: s.aiConfig_icon_extract,
    ),
    AIConfigTemplateIconOption(
      name: 'check_circle',
      icon: Icons.check_circle,
      label: s.aiConfig_icon_check,
    ),
    AIConfigTemplateIconOption(
      name: 'timeline',
      icon: Icons.timeline,
      label: s.aiConfig_icon_timeline,
    ),
    AIConfigTemplateIconOption(
      name: 'warning',
      icon: Icons.warning,
      label: s.aiConfig_icon_warning,
    ),
    AIConfigTemplateIconOption(
      name: 'summarize',
      icon: Icons.summarize,
      label: s.aiConfig_icon_summarize,
    ),
    AIConfigTemplateIconOption(
      name: 'visibility',
      icon: Icons.visibility,
      label: s.aiConfig_icon_visibility,
    ),
  ];
}

class AIConfigTemplateEditorForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController idController;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController systemPromptController;
  final TextEditingController userPromptController;
  final String selectedIcon;
  final ValueChanged<String> onIconChanged;

  const AIConfigTemplateEditorForm({
    super.key,
    required this.formKey,
    required this.idController,
    required this.nameController,
    required this.descriptionController,
    required this.systemPromptController,
    required this.userPromptController,
    required this.selectedIcon,
    required this.onIconChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = AIConfigCopy.of(context);
    final availableIcons = buildAIConfigTemplateIconOptions(s);

    return Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: idController,
              decoration: InputDecoration(
                labelText: s.aiConfig_templateId,
                hintText: s.aiConfig_templateIdHint,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? s.aiConfig_error_validation_templateId
                  : null,
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: s.aiConfig_templateName,
                hintText: s.aiConfig_templateNameHint,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty ?? true
                  ? s.aiConfig_error_validation_templateName
                  : null,
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: s.aiConfig_description,
                hintText: s.aiConfig_descriptionHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16.h),
            DropdownButtonFormField<String>(
              initialValue: selectedIcon,
              decoration: InputDecoration(
                labelText: s.aiConfig_icon,
                border: const OutlineInputBorder(),
              ),
              items: availableIcons.map((iconData) {
                return DropdownMenuItem<String>(
                  value: iconData.name,
                  child: Row(
                    children: [
                      Icon(iconData.icon),
                      SizedBox(width: 8.w),
                      Text(iconData.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onIconChanged(value);
                }
              },
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: systemPromptController,
              decoration: InputDecoration(
                labelText: s.aiConfig_systemPromptLabel,
                hintText: s.aiConfig_systemPromptHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (value) => value?.isEmpty ?? true
                  ? s.aiConfig_error_validation_systemPrompt
                  : null,
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: userPromptController,
              decoration: InputDecoration(
                labelText: s.aiConfig_userPromptTemplate,
                hintText: s.aiConfig_userPromptTemplateHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
