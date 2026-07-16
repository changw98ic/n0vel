import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';

class ReferenceMaterialsPage extends ConsumerStatefulWidget {
  const ReferenceMaterialsPage({super.key});

  @override
  ConsumerState<ReferenceMaterialsPage> createState() =>
      _ReferenceMaterialsPageState();
}

class _ReferenceMaterialsPageState
    extends ConsumerState<ReferenceMaterialsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final store = ref.watch(appWorkspaceStoreProvider).styleFacade;
    final profiles = store.styleProfiles;
    final selectedProfile = store.selectedStyleProfile;
    final selectedProfileId =
        selectedProfile?.id ?? (profiles.isEmpty ? '' : profiles.first.id);
    final isEnabled = selectedProfile != null;
    final styleName = selectedProfile?.name ?? '风格参考';

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        tabs: const ['作品资料', '设定资料', '编辑'],
        activeTabIndex: 1,
        onTabChanged: (i) async {
          if (i == 0) {
            final canNavigate = await AppNavTabs.confirmIfBlocked(context);
            if (!context.mounted || !canNavigate) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workSettingsHub);
          } else if (i == 2) {
            final canNavigate = await AppNavTabs.confirmIfBlocked(context);
            if (!context.mounted || !canNavigate) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workbench);
          }
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignTokens.space24,
          vertical: AppDesignTokens.space20,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDesignTokens.radiusXLarge,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: AppDesignTokens.glassBlurRadius,
                      sigmaY: AppDesignTokens.glassBlurRadius,
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: const EdgeInsets.all(24),
                      decoration: glassCardDecoration(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('动态风格启用', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 16),
                          if (profiles.isEmpty)
                            Text(
                              '当前项目暂无风格档案。',
                              style: theme.textTheme.bodySmall,
                            )
                          else
                            RadioGroup<String>(
                              groupValue: selectedProfileId,
                              onChanged: (value) {
                                if (value != null) {
                                  store.selectStyleProfile(value);
                                }
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final profile in profiles) ...[
                                    _StyleProfileRadioTile(profile: profile),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: glassCardDecoration(
                              context,
                              color: palette.surface.withValues(alpha: 0.7),
                            ),
                            child: Text(
                              isEnabled
                                  ? 'AI 生成时会参考「$styleName」的风格特征来组织语言。'
                                  : '当前没有启用的风格参考。',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      statusBar: BottomSpecBar(
        description: isEnabled ? '$styleName · 已启用' : '风格参考未启用',
      ),
    );
  }
}

class _StyleProfileRadioTile extends StatelessWidget {
  const _StyleProfileRadioTile({required this.profile});

  final StyleProfileRecord profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final sourceLabel = switch (profile.source) {
      'json' => 'JSON 导入',
      'questionnaire' => '问卷生成',
      _ => profile.source,
    };
    return DecoratedBox(
      decoration: appPanelDecoration(context, color: palette.surface),
      child: RadioListTile<String>(
        value: profile.id,
        title: Text(profile.name, style: theme.textTheme.bodyMedium),
        subtitle: Text(sourceLabel, style: theme.textTheme.bodySmall),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
