import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../../../app/theme/app_design_tokens.dart';
import 'work_settings_hub_components.dart';

class WorkSettingsHubPage extends ConsumerStatefulWidget {
  const WorkSettingsHubPage({super.key});

  @override
  ConsumerState<WorkSettingsHubPage> createState() =>
      _WorkSettingsHubPageState();
}

class _WorkSettingsHubPageState extends ConsumerState<WorkSettingsHubPage> {
  late ScrollController _sidebarScrollController;
  late ScrollController _mainScrollController;

  @override
  void initState() {
    super.initState();
    _sidebarScrollController = ScrollController();
    _mainScrollController = ScrollController();
  }

  @override
  void dispose() {
    _sidebarScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceStore = ref.watch(appWorkspaceStoreProvider);
    final sceneContextStore = ref.watch(appSceneContextStoreProvider);
    final draftStore = ref.watch(appDraftStoreProvider);
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
            tabs: const ['书架', '作品资料', '编辑'],
            activeTabIndex: 1,
            onTabChanged: (i) async {
              if (i == 0) {
                final canNavigate = await AppNavTabs.confirmIfBlocked(context);
                if (!context.mounted || !canNavigate) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else if (i == 2) {
                AppNavigator.push(context, AppRoutes.workbench);
              }
            },
            actions: [
              DesignActionButton(
                icon: Icons.edit_note,
                label: '进入编辑',
                onPressed: () =>
                    AppNavigator.push(context, AppRoutes.workbench),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final theme = Theme.of(context);
              final palette = desktopPalette(context);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignTokens.space24,
                  vertical: AppDesignTokens.space20,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Overview sidebar (330px glass)
                    SizedBox(
                      width: 330,
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
                            padding: const EdgeInsets.all(18),
                            decoration: frostedSidebarDecoration(context),
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.trackpad,
                                    },
                                  ),
                              child: Scrollbar(
                                controller: _sidebarScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _sidebarScrollController,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Project title
                                      Text(
                                        summary.headerSubtitle,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: palette.primary,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 20),
                                      // Stat chips
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.subtle.withValues(
                                            alpha: 0.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            AppDesignTokens.radiusMedium,
                                          ),
                                        ),
                                        child: Wrap(
                                          spacing: 24,
                                          runSpacing: 6,
                                          children: [
                                            WorkSettingsStatChip(
                                              icon: Icons.edit_note_outlined,
                                              label: '进度',
                                              value: summary.writingSummary,
                                            ),
                                            WorkSettingsStatChip(
                                              icon: Icons.history_edu_outlined,
                                              label: '设定',
                                              value: summary.recentSettings,
                                            ),
                                            WorkSettingsStatChip(
                                              icon: Icons
                                                  .playlist_add_check_outlined,
                                              label: '下一步',
                                              value: summary.nextStep,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        '下一步建议',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: palette.secondaryText,
                                            ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        summary.nextStep,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: palette.tertiaryText,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 28),
                    // Right: Main content (fill)
                    Expanded(
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
                            padding: const EdgeInsets.all(24),
                            decoration: glassCardDecoration(context),
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.trackpad,
                                    },
                                  ),
                              child: Scrollbar(
                                controller: _mainScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _mainScrollController,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '核心设定与大纲',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: palette.primary,
                                                ),
                                          ),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                icon: const Icon(
                                                  Icons.people_outline,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  '人物库',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    AppNavigator.push(
                                                      context,
                                                      AppRoutes.characters,
                                                    ),
                                              ),
                                              TextButton.icon(
                                                icon: const Icon(
                                                  Icons.public_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  '世界观',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    AppNavigator.push(
                                                      context,
                                                      AppRoutes.worldbuilding,
                                                    ),
                                              ),
                                              TextButton.icon(
                                                icon: const Icon(
                                                  Icons.auto_stories_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  '参考资料',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    AppNavigator.push(
                                                      context,
                                                      AppRoutes.style,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.group_outlined,
                                            size: 18,
                                            color: Color(0xFFB6813B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '核心出场角色',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: palette.primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      workspaceStore.characters.isEmpty
                                          ? Container(
                                              height: 100,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '角色库暂无角色，点击右上角人物库添加',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          palette.tertiaryText,
                                                    ),
                                              ),
                                            )
                                          : SizedBox(
                                              height: 140,
                                              child: PremiumHorizontalScrollView(
                                                builder:
                                                    (
                                                      context,
                                                      controller,
                                                    ) => ListView.separated(
                                                      controller: controller,
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      itemCount: workspaceStore
                                                          .characters
                                                          .length,
                                                      separatorBuilder:
                                                          (context, index) =>
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                      itemBuilder: (context, index) {
                                                        final char = workspaceStore
                                                            .characters[index];
                                                        final initial =
                                                            char.name.isNotEmpty
                                                            ? char.name
                                                                  .substring(
                                                                    0,
                                                                    1,
                                                                  )
                                                            : '?';
                                                        return FrostedCharacterCard(
                                                          name: char.name,
                                                          role: char.role,
                                                          avatarInitial:
                                                              initial,
                                                          onTap: () =>
                                                              AppNavigator.push(
                                                                context,
                                                                AppRoutes
                                                                    .characters,
                                                              ),
                                                        );
                                                      },
                                                    ),
                                              ),
                                            ),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.auto_stories_outlined,
                                            size: 18,
                                            color: Color(0xFFB6813B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '正文章节预览',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: palette.primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      workspaceStore.scenes.isEmpty
                                          ? Container(
                                              height: 160,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '正文暂无章节，请前往编辑新建第一章',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color:
                                                          palette.tertiaryText,
                                                    ),
                                              ),
                                            )
                                          : SizedBox(
                                              height: 190,
                                              child: PremiumHorizontalScrollView(
                                                builder:
                                                    (
                                                      context,
                                                      controller,
                                                    ) => ListView.separated(
                                                      controller: controller,
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      itemCount: workspaceStore
                                                          .scenes
                                                          .length,
                                                      separatorBuilder:
                                                          (context, index) =>
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                      itemBuilder: (context, index) {
                                                        final scene =
                                                            workspaceStore
                                                                .scenes[index];
                                                        return FrostedChapterCard(
                                                          title: scene.title,
                                                          location: scene
                                                              .displayChapterLabel,
                                                          summary:
                                                              scene.summary,
                                                          onTap: () {
                                                            workspaceStore
                                                                .updateCurrentScene(
                                                                  sceneId:
                                                                      scene.id,
                                                                  recentLocation:
                                                                      scene
                                                                          .displayLocation,
                                                                );
                                                            AppNavigator.push(
                                                              context,
                                                              AppRoutes
                                                                  .workbench,
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          statusBar: BottomSpecBar(description: summary.statusText),
        );
      },
    );
  }
}

class _WorkSettingsSummary {
  const _WorkSettingsSummary({
    required this.headerSubtitle,
    required this.writingSummary,
    required this.recentSettings,
    required this.nextStep,
    required this.characterSubtitle,
    required this.worldSubtitle,
    required this.styleSubtitle,
    required this.statusText,
  });

  final String headerSubtitle;
  final String writingSummary;
  final String recentSettings;
  final String nextStep;
  final String characterSubtitle;
  final String worldSubtitle;
  final String styleSubtitle;
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
        (scene == null ? null : chapterLocationLabel(scene.displayLocation)) ??
        chapterLocationLabel(_fallback(project?.recentLocation, '未选择章节'));
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
    const styleName = '东方含蓄文青风';
    final draftState = hasDraft
        ? '正文已有 ${draftText.trim().length} 字'
        : '正文尚未生成';
    final sceneNote = _sceneNote(sceneSummary, sceneLabel);

    return _WorkSettingsSummary(
      headerSubtitle: '$projectTitle · $sceneLabel',
      writingSummary: _joinSentences([
        '当前章节：$sceneLabel',
        sceneNote,
        draftState,
      ]),
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
      styleSubtitle: '11 个角色原型 · 东方含蓄文青风',
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
      return '先补齐当前章节目标和冲突，再进入正文或改稿。';
    }
    if (characterAnchor.isEmpty) {
      return '为当前章节关联核心角色，补上动机和关系压力。';
    }
    if (worldAnchor.isEmpty) {
      return '为当前章节补充地点规则或世界观约束，避免设定漂移。';
    }
    if (!hasDraft) {
      return '设定已具备基础锚点，可以回到工作台生成或补写正文。';
    }
    return '正文已有内容，下一步适合带着当前设定进入问题检查。';
  }
}

String _sceneNote(String sceneSummary, String sceneLabel) {
  if (sceneSummary.trim().isEmpty) {
    return '章节摘要待补充';
  }
  if (sceneSummary.contains('等待同步')) {
    return '章节资料等待同步';
  }
  if (sceneSummary.contains(sceneLabel)) {
    return '章节摘要已同步';
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
  var end = value.length;
  while (end > 0 && '。！？.!?'.contains(value[end - 1])) {
    end -= 1;
  }
  return value.substring(0, end);
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
  final normalized = _collapseWhitespace(value.trim());
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1)}…';
}

String _collapseWhitespace(String value) {
  final buffer = StringBuffer();
  var previousWasWhitespace = false;
  for (var index = 0; index < value.length; index += 1) {
    final codeUnit = value.codeUnitAt(index);
    if (_isWhitespace(codeUnit)) {
      if (!previousWasWhitespace) {
        buffer.write(' ');
      }
      previousWasWhitespace = true;
    } else {
      buffer.writeCharCode(codeUnit);
      previousWasWhitespace = false;
    }
  }
  return buffer.toString();
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0b ||
      codeUnit == 0x0c ||
      codeUnit == 0x0d ||
      codeUnit == 0x20;
}
