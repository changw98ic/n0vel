import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/state/app_settings_store.dart';
import '../../../app/widgets/desktop_shell.dart';

class SettingsFieldInputBox extends StatelessWidget {
  const SettingsFieldInputBox({
    required this.label,
    required this.controller,
    this.fieldKey,
    this.obscureText = false,
    this.placeholder,
    this.suffix,
    this.onToggleObscure,
    this.keyboardType,
    this.inputFormatters,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final bool obscureText;
  final String? placeholder;
  final String? suffix;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: placeholder,
            suffixText: suffix,
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                    tooltip: obscureText ? '显示密钥' : '隐藏密钥',
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.title,
    required this.subtitle,
    required this.children,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class SettingsThemeButton extends StatelessWidget {
  const SettingsThemeButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton(key: buttonKey, onPressed: onTap, child: Text(label));
    }
    return OutlinedButton(key: buttonKey, onPressed: onTap, child: Text(label));
  }
}

class SettingsProviderCatalogCard extends StatelessWidget {
  const SettingsProviderCatalogCard({
    required this.entry,
    required this.onAdd,
    required this.onSetPrimary,
    super.key,
  });

  final AppLlmProviderCatalogEntry entry;
  final Future<void> Function() onAdd;
  final Future<void> Function() onSetPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${entry.providerName} · ${entry.model}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                entry.requiresApiKey ? '需密钥' : '本地无需密钥',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(entry.summary, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            entry.baseUrl,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
              OutlinedButton.icon(
                onPressed: onSetPrimary,
                icon: const Icon(Icons.radio_button_checked, size: 18),
                label: const Text('设为默认'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
    this.onTest,
    this.onSetPrimary,
    super.key,
  });

  final AppLlmProviderProfile profile;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTest;
  final VoidCallback? onSetPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profile.providerName} · ${profile.model}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.baseUrl,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTest != null)
            IconButton(
              icon: const Icon(Icons.wifi_tethering, size: 20),
              onPressed: onTest,
              tooltip: '测试连接',
            ),
          if (onSetPrimary != null)
            IconButton(
              icon: const Icon(Icons.radio_button_checked, size: 20),
              onPressed: onSetPrimary,
              tooltip: '设为默认',
            ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: '编辑',
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              tooltip: '删除',
            ),
        ],
      ),
    );
  }
}

class SettingsRouteCard extends StatelessWidget {
  const SettingsRouteCard({
    required this.route,
    required this.profiles,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final AppLlmRequestProviderRoute route;
  final List<AppLlmProviderProfile> profiles;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final profileName =
        profiles
            .where((p) => p.id == route.providerProfileId)
            .map((p) => '${p.providerName} (${p.model})')
            .firstOrNull ??
        route.providerProfileId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracePatternLabel(route.traceNamePattern),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  profileName,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              tooltip: '编辑',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            tooltip: '删除',
          ),
        ],
      ),
    );
  }
}

const kRoutePatternOptions = <(String, String)>[
  ('scene_prose_generation', '散文生成'),
  ('scene_director_polish', '导演润色'),
  ('scene_roleplay_turn', '角色扮演回合'),
  ('scene_roleplay_arbitrate', '角色仲裁'),
  ('scene_editorial', '编辑'),
  ('scene_beat_resolve', '节拍解析'),
  ('dynamic_role', '动态角色'),
  ('language_polish', '语言润色'),
  ('scene_quality_scoring', '质量评分'),
  ('scene_combined_review', '综合审查'),
  ('scene_review_*', '审查（全部）'),
];

String tracePatternLabel(String pattern) {
  for (final (value, label) in kRoutePatternOptions) {
    if (pattern == value) return '$label ($value)';
    if (!value.endsWith('*') && pattern.startsWith(value)) {
      return '$label* ($pattern)';
    }
  }
  return pattern;
}
