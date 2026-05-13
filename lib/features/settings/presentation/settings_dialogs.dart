import 'package:flutter/material.dart';

import '../../../app/state/app_settings_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'settings_shell_components.dart';

Future<void> showProviderCatalogDialog({
  required BuildContext context,
  required AppSettingsStore store,
  required void Function(AppSettingsSnapshot) onSynchronizeControllers,
}) async {
  await showDialog<void>(
    context: context,
    barrierLabel: '关闭',
    builder: (dialogContext) {
      return DesktopModalDialog(
        title: '一键添加供应商',
        width: 680,
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in appLlmProviderCatalogEntries) ...[
                  SettingsProviderCatalogCard(
                    entry: entry,
                    onAdd: () async {
                      await store.addProviderFromCatalog(entry.id);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    onSetPrimary: () async {
                      await store.addProviderFromCatalog(
                        entry.id,
                        setAsPrimary: true,
                      );
                      if (!context.mounted) return;
                      onSynchronizeControllers(store.snapshot);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

Future<void> showProfileDialog({
  required BuildContext context,
  required AppSettingsStore store,
  AppLlmProviderProfile? existing,
}) async {
  final idController = TextEditingController(text: existing?.id);
  final nameController = TextEditingController(text: existing?.providerName);
  final urlController = TextEditingController(text: existing?.baseUrl);
  final modelController = TextEditingController(text: existing?.model);
  final keyController = TextEditingController(text: existing?.apiKey);
  var profileKeyVisible = false;
  final result = await showDialog<bool>(
    context: context,
    barrierLabel: '关闭',
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return DesktopModalDialog(
            title: existing == null ? '添加模型服务' : '编辑模型服务',
            width: 560,
            body: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    readOnly: existing != null,
                    decoration: const InputDecoration(
                      labelText: '标识（英文，唯一）',
                      hintText: '例如：glm-review',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '模型服务名称',
                      hintText: '例如：智谱 GLM',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: '接口地址',
                      hintText: 'https://open.bigmodel.cn/api/paas/v4',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: modelController,
                    decoration: const InputDecoration(
                      labelText: '模型',
                      hintText: '例如：glm-5.1',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: keyController,
                    obscureText: !profileKeyVisible,
                    decoration: InputDecoration(
                      labelText: '密钥',
                      hintText: '输入密钥',
                      suffixIcon: IconButton(
                        icon: Icon(
                          profileKeyVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            profileKeyVisible = !profileKeyVisible;
                          });
                        },
                        tooltip: profileKeyVisible ? '隐藏密钥' : '显示密钥',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final id = idController.text.trim();
                  if (id.isEmpty ||
                      nameController.text.trim().isEmpty ||
                      urlController.text.trim().isEmpty ||
                      modelController.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
  final profileId = idController.text.trim();
  final profileName = nameController.text.trim();
  final profileUrl = urlController.text.trim();
  final profileModel = modelController.text.trim();
  final profileKey = keyController.text.trim();
  if (result != true) return;
  if (!context.mounted) return;
  await store.upsertProviderProfile(
    AppLlmProviderProfile(
      id: profileId,
      providerName: profileName,
      baseUrl: profileUrl,
      model: profileModel,
      apiKey: profileKey,
    ),
  );
}

Future<void> showRouteDialog({
  required BuildContext context,
  required AppSettingsStore settingsStore,
  AppLlmRequestProviderRoute? existing,
}) async {
  final profiles = settingsStore.snapshot.providerProfiles;
  if (profiles.isEmpty) {
    return;
  }
  final presetPatterns = kRoutePatternOptions.map((e) => e.$1).toSet();
  String selectedPattern =
      existing != null && presetPatterns.contains(existing.traceNamePattern)
      ? existing.traceNamePattern
      : kRoutePatternOptions.first.$1;
  String? selectedProfileId = existing?.providerProfileId ?? profiles.first.id;
  final result = await showDialog<bool>(
    context: context,
    barrierLabel: '关闭',
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return DesktopModalDialog(
            title: existing != null ? '编辑路由' : '添加路由',
            width: 520,
            body: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '请求类型',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButton<String>(
                      value: selectedPattern,
                      isExpanded: true,
                      items: kRoutePatternOptions
                          .map(
                            (opt) => DropdownMenuItem(
                              value: opt.$1,
                              child: Text('${opt.$2} (${opt.$1})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedPattern = v;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '目标模型服务',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final profile in profiles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setDialogState(() {
                              selectedProfileId = profile.id;
                            });
                          },
                          child: Row(
                            children: [
                              Icon(
                                selectedProfileId == profile.id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${profile.id} (${profile.model})',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (selectedProfileId == null) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
    },
  );
  if (result != true) return;
  if (selectedProfileId == null) return;
  if (!context.mounted) return;
  await settingsStore.upsertRequestProviderRoute(
    AppLlmRequestProviderRoute(
      traceNamePattern: selectedPattern,
      providerProfileId: selectedProfileId!,
    ),
  );
}
