import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/desktop_shell.dart';

class WorkSettingsHubPage extends StatelessWidget {
  const WorkSettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final workspaceStore = AppWorkspaceScope.of(context);
    final sceneContextStore = AppSceneContextScope.of(context);
    final draftStore = AppDraftScope.of(context);
    final merged = Listenable.merge([
      workspaceStore,
      sceneContextStore,
      draftStore,
    ]);

    return ListenableBuilder(
      listenable: merged,
      builder: (context, _) {
        final summary = _WorkSettingsSummary.fromStores(
          workspaceStore: workspaceStore,
          sceneContext: sceneContextStore.snapshot,
          draftText: draftStore.snapshot.text,
        );

        return DesktopShellFrame(
          header: DesktopHeaderBar(
            title: '作品设定',
            subtitle: summary.headerSubtitle,
            showBackButton: true,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 960
                  ? 280.0
                  : constraints.maxWidth > 600
                  ? 240.0
                  : double.infinity;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _ContextCard(
                            icon: Icons.menu_book_outlined,
                            title: '作品圣经摘要',
                            body: summary.bibleSummary,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _ContextCard(
                            icon: Icons.history_edu_outlined,
                            title: '最近设定',
                            body: summary.recentSettings,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _ContextCard(
                            icon: Icons.playlist_add_check_outlined,
                            title: '下一步',
                            body: summary.nextStep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.people_outline,
                            title: '角色库',
                            subtitle: summary.characterSubtitle,
                            onTap: () => AppNavigator.push(
                              context,
                              AppRoutes.characters,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.public_outlined,
                            title: '世界观',
                            subtitle: summary.worldSubtitle,
                            onTap: () => AppNavigator.push(
                              context,
                              AppRoutes.worldbuilding,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.palette_outlined,
                            title: '风格面板',
                            subtitle: summary.styleSubtitle,
                            onTap: () =>
                                AppNavigator.push(context, AppRoutes.style),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _HubCard(
                            icon: Icons.auto_stories_outlined,
                            title: '作品圣经',
                            subtitle: summary.storyBibleSubtitle,
                            onTap: () => AppNavigator.push(
                              context,
                              AppRoutes.storyBible,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          statusBar: DesktopStatusStrip(leftText: summary.statusText),
        );
      },
    );
  }
}

class _WorkSettingsSummary {
  const _WorkSettingsSummary({
    required this.headerSubtitle,
    required this.bibleSummary,
    required this.recentSettings,
    required this.nextStep,
    required this.characterSubtitle,
    required this.worldSubtitle,
    required this.styleSubtitle,
    required this.storyBibleSubtitle,
    required this.statusText,
  });

  final String headerSubtitle;
  final String bibleSummary;
  final String recentSettings;
  final String nextStep;
  final String characterSubtitle;
  final String worldSubtitle;
  final String styleSubtitle;
  final String storyBibleSubtitle;
  final String statusText;

  factory _WorkSettingsSummary.fromStores({
    required AppWorkspaceStore workspaceStore,
    required AppSceneContextSnapshot sceneContext,
    required String draftText,
  }) {
    final project = workspaceStore.currentProjectOrNull;
    final scene = workspaceStore.currentSceneOrNull;
    final projectTitle = _fallback(project?.title, '未选择项目');
    final sceneLabel =
        scene?.displayLocation ?? _fallback(project?.recentLocation, '未选择场景');
    final sceneSummary = _firstMeaningful([
      sceneContext.sceneSummary,
      scene?.summary,
      project?.summary,
    ]);
    final hasDraft = draftText.trim().isNotEmpty;
    final characters = workspaceStore.characters;
    final worldNodes = workspaceStore.worldNodes;
    final linkedCharacters = scene == null
        ? characters
        : characters
              .where((character) => character.linkedSceneIds.contains(scene.id))
              .toList(growable: false);
    final linkedWorldNodes = scene == null
        ? worldNodes
        : worldNodes
              .where((node) => node.linkedSceneIds.contains(scene.id))
              .toList(growable: false);
    final characterAnchor = _firstMeaningful([
      sceneContext.characterSummary,
      for (final character in linkedCharacters.take(2))
        _joinNonEmpty([character.name, character.role]),
      for (final character in characters.take(2))
        _joinNonEmpty([character.name, character.role]),
    ]);
    final worldAnchor = _firstMeaningful([
      sceneContext.worldSummary,
      for (final node in linkedWorldNodes.take(2))
        _joinNonEmpty([node.title, node.type]),
      for (final node in worldNodes.take(2))
        _joinNonEmpty([node.title, node.type]),
    ]);
    final styleProfile = workspaceStore.selectedStyleProfile;
    final styleName = _fallback(styleProfile?.name, '未绑定风格');
    final draftState = hasDraft
        ? '正文已有 ${draftText.trim().length} 字'
        : '正文尚未生成';
    final sceneNote = _sceneNote(sceneSummary, sceneLabel);

    return _WorkSettingsSummary(
      headerSubtitle: '$projectTitle · $sceneLabel',
      bibleSummary: _joinSentences(['当前锚点：$sceneLabel', sceneNote, draftState]),
      recentSettings: _joinSentences([
        characters.isEmpty
            ? '角色库尚未建立'
            : '角色 ${characters.length} 个 · ${_nameList(characters.map((c) => c.name))}',
        worldNodes.isEmpty
            ? '世界观节点尚未建立'
            : '世界观 ${worldNodes.length} 个 · ${_nameList(worldNodes.map((n) => n.title))}',
        '风格：$styleName',
      ]),
      nextStep: _nextStep(
        hasDraft: hasDraft,
        sceneSummary: sceneSummary,
        characterAnchor: characterAnchor,
        worldAnchor: worldAnchor,
      ),
      characterSubtitle: characters.isEmpty
          ? '尚未建立角色档案'
          : '管理 ${characters.length} 个角色，当前相关 ${linkedCharacters.length} 个',
      worldSubtitle: worldNodes.isEmpty
          ? '尚未建立世界观节点'
          : '维护 ${worldNodes.length} 个节点，当前相关 ${linkedWorldNodes.length} 个',
      styleSubtitle: '当前风格 $styleName · 强度 ${workspaceStore.styleIntensity}',
      storyBibleSubtitle: _joinSentences([
        characterAnchor.isEmpty ? '角色摘要待同步' : _compact(characterAnchor),
        worldAnchor.isEmpty ? '世界观摘要待同步' : _compact(worldAnchor),
      ]),
      statusText: '$projectTitle · $draftState',
    );
  }

  static String _nextStep({
    required bool hasDraft,
    required String sceneSummary,
    required String characterAnchor,
    required String worldAnchor,
  }) {
    if (sceneSummary.isEmpty) {
      return '先补齐当前场景目标和冲突，再进入正文或改稿。';
    }
    if (characterAnchor.isEmpty) {
      return '为当前场景关联核心角色，补上动机和关系压力。';
    }
    if (worldAnchor.isEmpty) {
      return '为当前场景补充地点规则或世界观约束，避免设定漂移。';
    }
    if (!hasDraft) {
      return '设定已具备基础锚点，可以回到工作台生成或补写正文。';
    }
    return '正文已有内容，下一步适合带着当前设定进入问题检查。';
  }
}

String _sceneNote(String sceneSummary, String sceneLabel) {
  if (sceneSummary.trim().isEmpty) {
    return '场景摘要待补充';
  }
  if (sceneSummary.contains('等待同步')) {
    return '场景资料等待同步';
  }
  if (sceneSummary.contains(sceneLabel)) {
    return '场景摘要已同步';
  }
  return _compact(sceneSummary, maxLength: 42);
}

String _fallback(String? value, String fallback) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? fallback : trimmed;
}

String _firstMeaningful(Iterable<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

String _joinNonEmpty(Iterable<String> parts) {
  return [
    for (final part in parts)
      if (part.trim().isNotEmpty) part.trim(),
  ].join(' · ');
}

String _joinSentences(Iterable<String> parts) {
  return [
    for (final part in parts)
      if (part.trim().isNotEmpty) _trimSentenceEnd(part.trim()),
  ].join('。');
}

String _trimSentenceEnd(String value) {
  return value.replaceFirst(RegExp(r'[。！？.!?]+$'), '');
}

String _nameList(Iterable<String> names) {
  final normalized = [
    for (final name in names)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (normalized.isEmpty) {
    return '待命名';
  }
  final visible = normalized.take(3).join('、');
  final hiddenCount = normalized.length - 3;
  return hiddenCount > 0 ? '$visible 等 $hiddenCount 个' : visible;
}

String _compact(String value, {int maxLength = 28}) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1)}…';
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: palette.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);

    return Material(
      color: palette.elevated,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: palette.primary),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
