import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/app_empty_state.dart';
import '../../../app/widgets/app_list_filter.dart';
import '../../../app/widgets/desktop_shell.dart';

enum CharacterLibraryUiState {
  ready,
  empty,
  searchNoResults,
  missingRequiredFields,
  deleteReferencedConfirm,
}

class CharacterLibraryPage extends StatefulWidget {
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

  final CharacterLibraryUiState uiState;

  @override
  State<CharacterLibraryPage> createState() => _CharacterLibraryPageState();
}

class _CharacterLibraryPageState extends State<CharacterLibraryPage> {
  bool _isDrawerOpen = false;
  int _selectedIndex = 0;
  int _sortIndex = 0;
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppWorkspaceScope.of(context);
    final characters = _characters(context);
    final visibleCharacters = _visibleCharacters(characters);
    final selectedIndex = _resolveSelectedIndex(characters, visibleCharacters);
    final current = visibleCharacters.isEmpty
        ? null
        : characters[selectedIndex];
    final body = Row(
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
            child: _buildList(theme, visibleCharacters, selectedIndex),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: appPanelDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _buildDetail(theme, store, current),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: Container(
            decoration: appPanelDecoration(context),
            padding: const EdgeInsets.all(16),
            child: _buildSummary(theme, store, current),
          ),
        ),
      ],
    );
    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: '角色库',
        subtitle: '维护人物信息、心理参数与引用场景',
        showBackButton: true,
        actions: [
          FilledButton(
            key: CharacterLibraryPage.newCharacterButtonKey,
            onPressed: () => _createCharacter(store),
            child: const Text('新建角色'),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.uiState == CharacterLibraryUiState.deleteReferencedConfirm)
            Opacity(opacity: 0.55, child: body)
          else
            body,
          if (widget.uiState == CharacterLibraryUiState.deleteReferencedConfirm)
            Positioned.fill(
              child: _CharacterDeleteOverlay(
                characterName: current?.name ?? '当前角色',
                sceneLabel: _linkedSceneTag(store, current),
              ),
            ),
        ],
      ),
      statusBar: const DesktopStatusStrip(
        leftText: '角色索引已同步',
        rightText: '场景 05',
      ),
    );
  }

  Widget _buildList(
    ThemeData theme,
    List<CharacterRecord> visibleCharacters,
    int selectedIndex,
  ) {
    if (widget.uiState == CharacterLibraryUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('角色列表', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('当前项目无角色', style: theme.textTheme.bodySmall),
        ],
      );
    }
    if (_showSearchNoResults(visibleCharacters)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('搜索结果', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('0 个匹配', style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          const _InfoBlock(title: '没有找到匹配角色', message: '试试更短的名字、别名或身份关键词。'),
          const SizedBox(height: 12),
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
        const SizedBox(height: 8),
        DesktopSearchField(
          fieldKey: CharacterLibraryPage.searchFieldKey,
          controller: _searchController,
          hintText: '搜索角色',
          onChanged: (_) => setState(() {}),
          width: double.infinity,
        ),
        const SizedBox(height: 8),
        AppListSortDropdown<CharacterRecord>(
          options: _sortOptions,
          selectedIndex: _sortIndex,
          onChanged: (i) => setState(() => _sortIndex = i),
        ),
        const SizedBox(height: 12),
        if (visibleCharacters.isEmpty)
          const Expanded(
            child: AppEmptyState(title: '没有匹配角色', message: '换个关键词，或新建一个角色。'),
          )
        else
          for (final character in visibleCharacters) ...[
            _ListButton(
              buttonKey: character.name == '岳人'
                  ? CharacterLibraryPage.yueRenKey
                  : null,
              label: character.name,
              selected: _characters(context)[selectedIndex] == character,
              onPressed: () => setState(() {
                _selectedIndex = _characters(context).indexOf(character);
              }),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _buildDetail(
    ThemeData theme,
    AppWorkspaceStore store,
    CharacterRecord? current,
  ) {
    if (widget.uiState == CharacterLibraryUiState.empty) {
      return _CallToActionState(
        title: '创建第一个角色',
        message: '先建立主要人物，再为其填写角色定位、Fear、Need 和引用场景。',
        buttonLabel: '新建角色',
        onPressed: () => _createCharacter(store),
      );
    }
    if (_showSearchNoResults(const <CharacterRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('角色详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const Expanded(
            child: _CenteredPanelState(
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
            const SizedBox(height: 12),
            const _StateCard(
              title: '缺少必填字段',
              message: '当前角色尚未填写姓名，因此本轮不会写入角色索引，也不会同步到写作工作台的角色摘要。',
              accent: Color(0xFF51624D),
            ),
            if (current != null) ...[
              const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          const Expanded(
            child: _CenteredPanelState(
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
          Text('角色详情', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildCharacterFields(store, current),
          const SizedBox(height: 12),
          Text('引用场景', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final scene in store.scenes)
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

  int _resolveSelectedIndex(
    List<CharacterRecord> characters,
    List<CharacterRecord> visibleCharacters,
  ) {
    if (characters.isEmpty || visibleCharacters.isEmpty) {
      return 0;
    }
    if (_selectedIndex < characters.length &&
        visibleCharacters.contains(characters[_selectedIndex])) {
      return _selectedIndex;
    }
    return characters.indexOf(visibleCharacters.first);
  }

  void _createCharacter(AppWorkspaceStore store) {
    setState(() {
      store.createCharacter();
      _selectedIndex = 0;
      _searchController.clear();
    });
  }

  List<CharacterRecord> _characters(BuildContext context) =>
      AppWorkspaceScope.of(context).characters;

  Widget _buildSummary(
    ThemeData theme,
    AppWorkspaceStore store,
    CharacterRecord? current,
  ) {
    if (widget.uiState == CharacterLibraryUiState.empty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('人物摘要', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(
            title: '引用场景',
            message: '当前还没有角色引用，创建角色后可以从这里快速跳回工作台。',
          ),
        ],
      );
    }
    if (_showSearchNoResults(const <CharacterRecord>[])) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('人物摘要', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(title: '改搜建议', message: '试试角色名、关系称谓、标签或登场场景关键词。'),
          const SizedBox(height: 8),
          const _InfoBlock(title: '引用场景', message: '搜索无结果时，不展示引用片段。'),
        ],
      );
    }
    if (widget.uiState == CharacterLibraryUiState.missingRequiredFields) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('人物摘要', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          const _InfoBlock(
            title: '人物摘要',
            message: '缺少姓名时，系统不会生成角色摘要，也不会同步到写作工作台。',
          ),
        ],
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('人物摘要', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          if (current == null)
            const AppEmptyState(title: '暂无摘要', message: '请先搜索或新建一个角色。')
          else ...[
            _InfoBlock(
              title: '引用摘要',
              message: current.referenceSummary.isEmpty
                  ? current.summary
                  : current.referenceSummary,
            ),
            const SizedBox(height: 8),
            if (current.linkedSceneIds.isEmpty)
              const AppEmptyState(
                title: '暂无引用场景',
                message: '勾选左侧场景后，可直接跳回工作台定位。',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final scene in store.scenes)
                    if (current.linkedSceneIds.contains(scene.id))
                      TextButton(
                        onPressed: () {
                          store.updateCurrentScene(
                            sceneId: scene.id,
                            recentLocation: scene.displayLocation,
                          );
                          AppNavigator.push(context, AppRoutes.workbench);
                        },
                        child: Text('查看 ${scene.title}'),
                      ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  bool _showSearchNoResults(List<CharacterRecord> visibleCharacters) {
    if (widget.uiState == CharacterLibraryUiState.searchNoResults) {
      return true;
    }
    return _searchController.text.trim().isNotEmpty &&
        visibleCharacters.isEmpty;
  }

  String _linkedSceneTag(AppWorkspaceStore store, CharacterRecord? current) {
    if (current == null || current.linkedSceneIds.isEmpty) {
      return 'Scene 05';
    }
    SceneRecord? matchedScene;
    for (final sceneId in current.linkedSceneIds) {
      final candidate = store.scenes.where((scene) => scene.id == sceneId);
      if (candidate.isEmpty) {
        continue;
      }
      final scene = candidate.first;
      if (scene.chapterLabel.contains('场景 05')) {
        matchedScene = scene;
        break;
      }
      matchedScene ??= scene;
    }
    if (matchedScene == null) {
      return 'Scene 05';
    }
    final match = RegExp(r'场景\s*(\d+)').firstMatch(matchedScene.chapterLabel);
    if (match == null) {
      return matchedScene.title;
    }
    return 'Scene ${match.group(1)}';
  }

  Widget _buildCharacterFields(
    AppWorkspaceStore store,
    CharacterRecord current,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.nameFieldKey.value}-${current.id}',
          ),
          label: '姓名',
          initialValue: current.name,
          onChanged: (value) =>
              store.updateCharacter(characterId: current.id, name: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.roleFieldKey.value}-${current.id}',
          ),
          label: '身份',
          initialValue: current.role,
          onChanged: (value) =>
              store.updateCharacter(characterId: current.id, role: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.noteFieldKey.value}-${current.id}',
          ),
          label: '笔记',
          initialValue: current.note,
          maxLines: 3,
          onChanged: (value) =>
              store.updateCharacter(characterId: current.id, note: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.needFieldKey.value}-${current.id}',
          ),
          label: '核心需求',
          initialValue: current.need,
          maxLines: 3,
          onChanged: (value) =>
              store.updateCharacter(characterId: current.id, need: value),
        ),
        const SizedBox(height: 8),
        _EditableTextField(
          fieldKey: ValueKey<String>(
            '${CharacterLibraryPage.summaryFieldKey.value}-${current.id}',
          ),
          label: '人物摘要',
          initialValue: current.summary,
          maxLines: 3,
          onChanged: (value) =>
              store.updateCharacter(characterId: current.id, summary: value),
        ),
      ],
    );
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

class _ListButton extends StatelessWidget {
  const _ListButton({
    this.buttonKey,
    required this.label,
    this.selected = false,
    required this.onPressed,
  });

  final Key? buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: buttonKey,
          onPressed: onPressed,
          child: Text(label),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: buttonKey,
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EditableTextField extends StatelessWidget {
  const _EditableTextField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    required this.accent,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CallToActionState extends StatelessWidget {
  const _CallToActionState({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _CenteredPanelState extends StatelessWidget {
  const _CenteredPanelState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).surfaceRaised,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterDeleteOverlay extends StatelessWidget {
  const _CharacterDeleteOverlay({
    required this.characterName,
    required this.sceneLabel,
  });

  final String characterName;
  final String sceneLabel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99F6F0E6),
      child: Center(
        child: Container(
          width: 728,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: desktopPalette(context).surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB7AA9A)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('删除被引用角色？', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                '角色“$characterName”仍被 $sceneLabel 引用。继续删除会导致相关场景失去角色绑定。\n\n建议先回到工作台或角色库移除引用，再执行删除。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _InfoBlock(title: '引用场景', message: sceneLabel),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () {}, child: const Text('取消')),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: () {}, child: const Text('查看引用后再删')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
