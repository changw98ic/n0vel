import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/app_dialog.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_list_filter.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'character_library_components.dart';

enum CharacterLibraryUiState {
  ready,
  empty,
  searchNoResults,
  missingRequiredFields,
}

class CharacterLibraryPage extends ConsumerStatefulWidget {
  const CharacterLibraryPage({
    super.key,
    this.uiState = CharacterLibraryUiState.ready,
  });

  static const newCharacterButtonKey = ValueKey<String>(
    'character-library-new',
  );
  static const searchFieldKey = ValueKey<String>('character-library-search');
  static const yueRenKey = ValueKey<String>('character-library-yueren');
  static const nameFieldKey = ValueKey<String>('character-library-name-field');
  static const roleFieldKey = ValueKey<String>('character-library-role-field');
  static const noteFieldKey = ValueKey<String>('character-library-note-field');
  static const needFieldKey = ValueKey<String>('character-library-need-field');
  static const summaryFieldKey = ValueKey<String>(
    'character-library-summary-field',
  );
  static const deleteButtonKey = ValueKey<String>(
    'character-library-delete-button',
  );

  final CharacterLibraryUiState uiState;

  @override
  ConsumerState<CharacterLibraryPage> createState() => _CharacterLibraryPageState();
}

class _CharacterLibraryPageState extends ConsumerState<CharacterLibraryPage> {
  String? _selectedCharacterId;
  int _sortIndex = 0;
  bool _showDeleteOverlay = false;
  Timer? _syncContextTimer;
  final TextEditingController _searchController = TextEditingController();

  static const _sortOptions = <AppListSortOption<CharacterRecord>>[
    AppListSortOption(label: '按名称', compare: _compareByName),
    AppListSortOption(label: '按身份', compare: _compareByRole),
  ];

  static int _compareByName(CharacterRecord a, CharacterRecord b) =>
      a.name.compareTo(b.name);

  static int _compareByRole(CharacterRecord a, CharacterRecord b) =>
      a.role.compareTo(b.role);

  @override
  void dispose() {
    _syncContextTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = ref.watch(appWorkspaceStoreProvider);
    final resources = workspace.resourceLibraryFacade;
    final projectScenes = workspace.projectSceneFacade;
    final characters = resources.characters;
    final visibleCharacters = _visibleCharacters(characters);
    final current = _resolveSelectedCharacter(characters, visibleCharacters);
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        tabs: const ['设定资料', '编辑资料', '正文'],
        activeTabIndex: 0,
        onTabChanged: (i) {
          if (i == 1) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workSettingsHub);
          } else if (i == 2) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppNavigator.push(context, AppRoutes.workbench);
          }
        },
        actions: [
          DesignActionButton(
            key: CharacterLibraryPage.newCharacterButtonKey,
            icon: Icons.person_add,
            label: '新建角色',
            onPressed: () => _createCharacter(resources),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final body = Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.space24,
              vertical: AppDesignTokens.space20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 260,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: AppDesignTokens.glassBlurRadius,
                        sigmaY: AppDesignTokens.glassBlurRadius,
                      ),
                      child: Container(
                        decoration: frostedSidebarDecoration(context),
                        padding: const EdgeInsets.all(18),
                        child: _buildList(
                          theme,
                          characters,
                          visibleCharacters,
                          current,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: AppDesignTokens.glassBlurRadius,
                        sigmaY: AppDesignTokens.glassBlurRadius,
                      ),
                      child: Container(
                        decoration: glassCardDecoration(context),
                        padding: const EdgeInsets.all(20),
                        child: _buildDetail(theme, resources, projectScenes, current, visibleCharacters),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
          return Stack(
            children: [
              if (_showDeleteOverlay)
                Opacity(opacity: 0.55, child: body)
              else
                body,
              if (_showDeleteOverlay && current != null)
                Positioned.fill(
                  child: CharacterDeleteOverlay(
                    characterName: current.name,
                    sceneLabel: _linkedSceneTag(projectScenes, current),
                    onCancel: () => setState(() {
                      _showDeleteOverlay = false;
                    }),
                    onForceDelete: () {
                      final character = current;
                      if (character == null) return;
                      setState(() {
                        resources.deleteCharacter(character.id);
                        _showDeleteOverlay = false;
                        final visible = _visibleCharacters(resources.characters);
                        _selectedCharacterId = visible.isEmpty
                            ? null
                            : visible.first.id;
                      });
                      ref.read(appSceneContextStoreProvider).syncContext();
                    },
                  ),
                ),
            ],
          );
        },
      ),
      statusBar: const BottomSpecBar(
        description: '作品设定 · 人物资料已保存',
      ),
    );
  }

  Widget _buildList(
    ThemeData theme,
    List<CharacterRecord> characters,
    List<CharacterRecord> visibleCharacters,
    CharacterRecord? current,
  ) {
    if (widget.uiState == CharacterLibraryUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('角色列表', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space8),
          Text('当前项目无角色', style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (_showSearchNoResults(visibleCharacters)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('搜索结果', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space8),
          Text('0 个匹配', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppDesignTokens.space12),
          const CharacterInfoBlock(title: '没有找到匹配角色', message: '试试更短的名字、别名或身份关键词。'),
          const SizedBox(height: AppDesignTokens.space12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _searchController.clear();
              }),
              child: const Text('清空搜索'),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('角色列表', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppDesignTokens.space8),
        DesktopSearchField(
          fieldKey: CharacterLibraryPage.searchFieldKey,
          controller: _searchController,
          hintText: '搜索角色',
          onChanged: (_) => setState(() {}),
          width: double.infinity,
        ),
        const SizedBox(height: AppDesignTokens.space8),
        AppListSortDropdown<CharacterRecord>(
          options: _sortOptions,
          selectedIndex: _sortIndex,
          onChanged: (i) => setState(() => _sortIndex = i),
        ),
        const SizedBox(height: AppDesignTokens.space12),
        if (visibleCharacters.isEmpty)
          const Expanded(
            child: AppEmptyState(title: '没有匹配角色', message: '换个关键词，或新建一个角色。'),
          )
        else
          for (final character in visibleCharacters) ...[
            CharacterListButton(
              buttonKey: character.name == '岳人'
                  ? CharacterLibraryPage.yueRenKey
                  : null,
              label: character.name,
              selected: current?.id == character.id,
              onPressed: () => setState(() {
                _selectedCharacterId = character.id;
              }),
            ),
            const SizedBox(height: AppDesignTokens.space8),
          ],
      ],
    );
  }

  Widget _buildDetail(
    ThemeData theme,
    WorkspaceResourceLibraryFacade store,
    WorkspaceProjectSceneFacade projectScenes,
    CharacterRecord? current,
    List<CharacterRecord> visibleCharacters,
  ) {
    if (widget.uiState == CharacterLibraryUiState.empty) {
      return CharacterCallToActionState(
        title: '创建第一个角色',
        message: '先建立主要人物，再为其填写角色定位、Fear、Need 和引用场景。',
        buttonLabel: '新建角色',
        onPressed: () => _createCharacter(store),
      );
    }
    if (_searchController.text.trim().isNotEmpty &&
        visibleCharacters.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('角色详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space12),
          const Expanded(
            child: CharacterCenteredPanelState(
              title: '未选中角色',
              message: '当前搜索没有结果，因此这里不显示角色详情。',
            ),
          ),
        ],
      );
    }
    if (widget.uiState == CharacterLibraryUiState.missingRequiredFields) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('角色详情', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppDesignTokens.space12),
            const CharacterStateCard(
              title: '缺少必填字段',
              message: '当前人物还没有名字，因此这次暂不写入人物资料，也不会刷新写作工作台的人物摘要。',
              accent: Color(0xFF51624D),
            ),
            if (current != null) ...[
              const SizedBox(height: AppDesignTokens.space12),
              _buildCharacterFields(store, current),
            ],
          ],
        ),
      );
    }

    if (current == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('角色详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space12),
          const Expanded(
            child: CharacterCenteredPanelState(
              title: '没有可展示的角色',
              message: '请先搜索或新建一个角色。',
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('角色详情', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                key: CharacterLibraryPage.deleteButtonKey,
                onPressed: () =>
                    _confirmDeleteCharacter(context, store, current),
                tooltip: '删除角色',
                color: appDangerColor,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: AppDesignTokens.space12),
          _buildCharacterFields(store, current),
          const SizedBox(height: AppDesignTokens.space16),
          if (current.referenceSummary.isNotEmpty || current.summary.isNotEmpty)
            CharacterInfoBlock(
              title: '引用摘要',
              message: current.referenceSummary.isEmpty
                  ? current.summary
                  : current.referenceSummary,
            ),
          if (current.referenceSummary.isNotEmpty || current.summary.isNotEmpty)
            const SizedBox(height: AppDesignTokens.space12),
          Text('引用场景', style: theme.textTheme.bodySmall),
          const SizedBox(height: AppDesignTokens.space4),
          Wrap(
            spacing: AppDesignTokens.space8,
            runSpacing: AppDesignTokens.space8,
            children: [
              for (final scene in projectScenes.scenes)
                FilterChip(
                  label: Text(scene.displayLocation),
                  selected: current.linkedSceneIds.contains(scene.id),
                  onSelected: (linked) => store.setCharacterSceneLinked(
                    characterId: current.id,
                    sceneId: scene.id,
                    linked: linked,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<CharacterRecord> _visibleCharacters(List<CharacterRecord> characters) {
    return applyListFilter(
      items: characters,
      searchQuery: _searchController.text.trim(),
      searchExtractor: (c) => '${c.name} ${c.role} ${c.summary}',
      activeSort: _sortOptions[_sortIndex],
    );
  }

  CharacterRecord? _resolveSelectedCharacter(
    List<CharacterRecord> characters,
    List<CharacterRecord> visibleCharacters,
  ) {
    if (visibleCharacters.isEmpty) {
      return null;
    }
    if (_selectedCharacterId != null) {
      final match = visibleCharacters.cast<CharacterRecord?>().firstWhere(
        (c) => c?.id == _selectedCharacterId,
        orElse: () => null,
      );
      if (match != null) {
        return match;
      }
    }
    return characters.isEmpty ? null : visibleCharacters.first;
  }

  Future<void> _createCharacter(WorkspaceResourceLibraryFacade store) async {
    final name = await showAppTextInputDialog(
      context: context,
      title: '新建角色',
      description: '为角色起个名字，创建后可以继续补充身份、需求和场景引用。',
      hintText: '输入角色名',
      confirmText: '创建',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      final newCharacter = store.createCharacter();
      store.updateCharacter(characterId: newCharacter.id, name: name.trim());
      _selectedCharacterId = newCharacter.id;
      _searchController.clear();
    });
  }

  Future<void> _confirmDeleteCharacter(
    BuildContext context,
    WorkspaceResourceLibraryFacade store,
    CharacterRecord character,
  ) async {
    if (character.linkedSceneIds.isNotEmpty) {
      setState(() {
        _showDeleteOverlay = true;
      });
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierLabel: '关闭',
      builder: (dialogContext) {
        return DesktopModalDialog(
          title: '删除角色',
          description: '删除后，角色资料和场景引用关系都会被移除。',
          body: Text(
            character.name,
            style: Theme.of(dialogContext).textTheme.bodyMedium,
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true) {
      setState(() {
        store.deleteCharacter(character.id);
        final visible = _visibleCharacters(store.characters);
        _selectedCharacterId = visible.isEmpty ? null : visible.first.id;
      });
      if (context.mounted) {
        ref.read(appSceneContextStoreProvider).syncContext();
      }
    }
  }

  bool _showSearchNoResults(List<CharacterRecord> visibleCharacters) {
    if (widget.uiState == CharacterLibraryUiState.searchNoResults) {
      return true;
    }
    return _searchController.text.trim().isNotEmpty &&
        visibleCharacters.isEmpty;
  }

  String _linkedSceneTag(
    WorkspaceProjectSceneFacade store,
    CharacterRecord? current,
  ) {
    if (current == null || current.linkedSceneIds.isEmpty) {
      return '第 3 章 / 场景 05';
    }
    SceneRecord? matchedScene;
    for (final sceneId in current.linkedSceneIds) {
      final candidate = store.scenes.where((scene) => scene.id == sceneId);
      if (candidate.isEmpty) {
        continue;
      }
      final scene = candidate.first;
      if (scene.locationParts.chapterNumber == 3) {
        matchedScene = scene;
        break;
      }
      matchedScene ??= scene;
    }
    if (matchedScene == null) {
      return '第 3 章 / 场景 05';
    }
    return matchedScene.displayLocation;
  }

  Widget _buildCharacterFields(
    WorkspaceResourceLibraryFacade store,
    CharacterRecord current,
  ) {
    void onFieldChanged(
      String characterId, {
      String? name,
      String? role,
      String? note,
      String? need,
      String? summary,
    }) {
      store.updateCharacter(
        characterId: characterId,
        name: name,
        role: role,
        note: note,
        need: need,
        summary: summary,
      );
      _syncContextTimer?.cancel();
      _syncContextTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          ref.read(appSceneContextStoreProvider).syncContext();
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CharacterEditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.nameFieldKey.value}-${current.id}',
          ),
          label: '姓名',
          initialValue: current.name,
          onChanged: (value) => onFieldChanged(current.id, name: value),
        ),
        const SizedBox(height: AppDesignTokens.space8),
        CharacterEditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.roleFieldKey.value}-${current.id}',
          ),
          label: '身份',
          initialValue: current.role,
          onChanged: (value) => onFieldChanged(current.id, role: value),
        ),
        const SizedBox(height: AppDesignTokens.space8),
        CharacterEditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.noteFieldKey.value}-${current.id}',
          ),
          label: '笔记',
          initialValue: current.note,
          maxLines: 3,
          onChanged: (value) => onFieldChanged(current.id, note: value),
        ),
        const SizedBox(height: AppDesignTokens.space8),
        CharacterEditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.needFieldKey.value}-${current.id}',
          ),
          label: '核心需求',
          initialValue: current.need,
          maxLines: 3,
          onChanged: (value) => onFieldChanged(current.id, need: value),
        ),
        const SizedBox(height: AppDesignTokens.space8),
        CharacterEditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.summaryFieldKey.value}-${current.id}',
          ),
          label: '人物摘要',
          initialValue: current.summary,
          maxLines: 3,
          onChanged: (value) => onFieldChanged(current.id, summary: value),
        ),
      ],
    );
  }

}
