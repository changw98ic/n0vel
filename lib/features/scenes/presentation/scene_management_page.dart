import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'scene_management_dialogs.dart';
import 'scene_management_widgets.dart';

export 'scene_management_dialogs.dart';
export 'scene_management_widgets.dart';

class SceneManagementPage extends StatefulWidget {
  const SceneManagementPage({super.key});

  static const newSceneButtonKey = ValueKey<String>('scene-management-new');
  static const renameSceneButtonKey = ValueKey<String>(
    'scene-management-rename',
  );
  static const deleteSceneButtonKey = ValueKey<String>(
    'scene-management-delete',
  );
  static const moveSceneUpButtonKey = ValueKey<String>(
    'scene-management-move-up',
  );
  static const moveSceneDownButtonKey = ValueKey<String>(
    'scene-management-move-down',
  );
  static const chapterLabelButtonKey = ValueKey<String>(
    'scene-management-chapter-label',
  );
  static const sceneSummaryButtonKey = ValueKey<String>(
    'scene-management-scene-summary',
  );
  static const sceneTitleFieldKey = ValueKey<String>(
    'scene-management-title-field',
  );
  static const chapterLabelFieldKey = ValueKey<String>(
    'scene-management-chapter-label-field',
  );
  static const sceneSummaryFieldKey = ValueKey<String>(
    'scene-management-scene-summary-field',
  );
  static const rainyDockKey = ValueKey<String>('scene-management-rainy-dock');
  static const chapterHeaderKey = ValueKey<String>(
    'scene-management-chapter-header',
  );

  @override
  State<SceneManagementPage> createState() => _SceneManagementPageState();
}

class _SceneManagementPageState extends State<SceneManagementPage> {
  bool _isDrawerOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final store = AppWorkspaceScope.of(context);
    final scenes = _visibleScenes(store.scenes);
    final groupedScenes = _groupScenesByChapter(scenes);
    final currentScene = store.currentScene;

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: '场景管理',
        subtitle: '维护当前项目的场景列表、标题与顺序',
        showBackButton: true,
        actions: [
          FilledButton(
            key: SceneManagementPage.newSceneButtonKey,
            onPressed: () => showSceneDialog(
              context,
              title: '新建场景',
              initialValue: '',
              onConfirm: store.createScene,
              fieldKey: SceneManagementPage.sceneTitleFieldKey,
            ),
            child: const Text('新建场景'),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopMenuDrawerRegion(
            isOpen: _isDrawerOpen,
            onHandleTap: () {
              setState(() {
                _isDrawerOpen = !_isDrawerOpen;
              });
            },
            items: _menuItems(context),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: Container(
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DesktopSearchField(
                    controller: _searchController,
                    hintText: '搜索场景',
                    onChanged: (_) => setState(() {}),
                    width: double.infinity,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: scenes.isEmpty
                        ? const AppEmptyState(
                            title: '没有匹配场景',
                            message: '换个关键词，或新建一个场景。',
                          )
                        : ListView.separated(
                            itemCount: groupedScenes.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final group = groupedScenes[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.chapterLabel,
                                    key: index == 0
                                        ? SceneManagementPage.chapterHeaderKey
                                        : null,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '共 ${group.scenes.length} 个场景',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  for (final scene in group.scenes) ...[
                                    SceneListButton(
                                      key: scene.id == 'scene-03-rainy-dock'
                                          ? SceneManagementPage.rainyDockKey
                                          : null,
                                      label: scene.displayLocation,
                                      selected: scene.id == currentScene.id,
                                      onPressed: () {
                                        store.updateCurrentScene(
                                          sceneId: scene.id,
                                          recentLocation: scene.displayLocation,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('场景详情', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SceneDetailField(label: '场景标题', value: currentScene.title),
                    const SizedBox(height: 12),
                    SceneDetailField(
                      label: '章节标签',
                      value: currentScene.chapterLabel,
                    ),
                    const SizedBox(height: 12),
                    SceneDetailField(
                      label: '场景摘要',
                      value: currentScene.summary,
                      multiline: true,
                    ),
                    const SizedBox(height: 12),
                    const SceneDetailField(
                      label: '最近修改',
                      value: '12 分钟前 · 已同步到工作台',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: Container(
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('场景操作', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        '新建、重命名、编辑章节标签、编辑摘要、调整顺序与删除都集中在这里。',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SceneActionRow(label: '打开位置', value: '写作工作台'),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      onPressed: () {
                        AppNavigator.push(context, AppRoutes.workbench);
                      },
                      child: const Text('打开工作台'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      key: SceneManagementPage.renameSceneButtonKey,
                      onPressed: () => showSceneDialog(
                        context,
                        title: '重命名场景',
                        initialValue: currentScene.title,
                        onConfirm: store.renameCurrentScene,
                        fieldKey: SceneManagementPage.sceneTitleFieldKey,
                      ),
                      child: const Text('重命名场景'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      key: SceneManagementPage.chapterLabelButtonKey,
                      onPressed: () => showChapterDialog(
                        context,
                        initialValue: currentScene.chapterLabel,
                        onConfirm: store.updateCurrentSceneChapterLabel,
                        fieldKey: SceneManagementPage.chapterLabelFieldKey,
                      ),
                      child: const Text('编辑章节标签'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      key: SceneManagementPage.sceneSummaryButtonKey,
                      onPressed: () => showSummaryDialog(
                        context,
                        initialValue: currentScene.summary,
                        onConfirm: store.updateCurrentSceneSummary,
                        fieldKey: SceneManagementPage.sceneSummaryFieldKey,
                      ),
                      child: const Text('编辑场景摘要'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      key: SceneManagementPage.moveSceneUpButtonKey,
                      onPressed: store.moveCurrentSceneUp,
                      child: const Text('上移场景'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      key: SceneManagementPage.moveSceneDownButtonKey,
                      onPressed: store.moveCurrentSceneDown,
                      child: const Text('下移场景'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      key: SceneManagementPage.deleteSceneButtonKey,
                      onPressed: store.canDeleteCurrentScene
                          ? () => confirmDeleteScene(
                                context,
                                sceneTitle: currentScene.title,
                                onConfirm: store.deleteCurrentScene,
                              )
                          : null,
                      child: const Text('删除场景'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      statusBar: DesktopStatusStrip(
        leftText: '当前项目共 ${store.scenes.length} 个场景',
        rightText: currentScene.chapterLabel,
      ),
    );
  }

  List<SceneRecord> _visibleScenes(List<SceneRecord> scenes) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return scenes;
    }
    return scenes
        .where((scene) {
          final haystack =
              '${scene.chapterLabel} ${scene.title} ${scene.summary}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<SceneChapterGroup> _groupScenesByChapter(List<SceneRecord> scenes) {
    final orderedLabels = <String>[];
    final grouped = <String, List<SceneRecord>>{};
    for (final scene in scenes) {
      final chapterLabel = scene.chapterLabel.split('/').first.trim();
      if (!grouped.containsKey(chapterLabel)) {
        orderedLabels.add(chapterLabel);
        grouped[chapterLabel] = <SceneRecord>[];
      }
      grouped[chapterLabel]!.add(scene);
    }
    return [
      for (final chapterLabel in orderedLabels)
        SceneChapterGroup(
          chapterLabel: chapterLabel,
          scenes: grouped[chapterLabel]!,
        ),
    ];
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return [
      DesktopMenuItemData(
        label: '书架',
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
      DesktopMenuItemData(
        label: '编辑工作台',
        onTap: () {
          AppNavigator.push(context, AppRoutes.workbench);
        },
      ),
      DesktopMenuItemData(
        label: '设置',
        onTap: () {
          AppNavigator.push(context, AppRoutes.settings);
        },
      ),
    ];
  }
}
