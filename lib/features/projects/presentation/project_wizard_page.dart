import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/app_dialog.dart';
import '../../../app/widgets/desktop_shell.dart';

class ProjectWizardPage extends ConsumerStatefulWidget {
  const ProjectWizardPage({super.key});

  static const nameFieldKey = ValueKey<String>('project-wizard-name-field');
  static const genreFieldKey = ValueKey<String>('project-wizard-genre-field');
  static const protagonistFieldKey =
      ValueKey<String>('project-wizard-protagonist-field');
  static const worldNodeFieldKey =
      ValueKey<String>('project-wizard-world-node-field');
  static const createButtonKey =
      ValueKey<String>('project-wizard-create-button');
  static const cancelButtonKey =
      ValueKey<String>('project-wizard-cancel-button');

  @override
  ConsumerState<ProjectWizardPage> createState() =>
      _ProjectWizardPageState();
}

class _ProjectWizardPageState extends ConsumerState<ProjectWizardPage> {
  final _nameController = TextEditingController();
  final _genreController = TextEditingController();
  final _protagonistController = TextEditingController();
  final _worldNodeController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genreController.dispose();
    _protagonistController.dispose();
    _worldNodeController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _canCreate => _nameController.text.trim().isNotEmpty && !_isCreating;

  void _handleCreate() {
    if (!_canCreate) return;

    final name = _nameController.text.trim();
    final protagonist = _protagonistController.text.trim();
    final worldNode = _worldNodeController.text.trim();

    setState(() => _isCreating = true);

    final workspaceStore = ref.read(appWorkspaceStoreProvider);

    workspaceStore.createProject(projectName: name);

    final projectRef = ref.read(appWorkspaceStoreProvider);

    if (protagonist.isNotEmpty) {
      projectRef.createCharacter();
      final characters = projectRef.characters;
      if (characters.isNotEmpty) {
        projectRef.updateCharacter(
          characterId: characters.first.id,
          name: protagonist,
          role: '主角',
        );
      }
    }

    if (worldNode.isNotEmpty) {
      projectRef.createWorldNode();
      final worldNodes = projectRef.worldNodes;
      if (worldNodes.isNotEmpty) {
        projectRef.updateWorldNode(
          nodeId: worldNodes.first.id,
          title: worldNode,
          type: '地点',
        );
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      AppNavigator.push(context, AppRoutes.projectHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = desktopPalette(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          decoration: BoxDecoration(
            color: palette.elevated,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusLarge),
            border: Border.all(
              color: palette.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, palette),
              Padding(
                padding: const EdgeInsets.all(AppDesignTokens.space24),
                child: Form(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNameField(context),
                      const SizedBox(height: AppDesignTokens.space16),
                      _buildGenreField(context),
                      const SizedBox(height: AppDesignTokens.space16),
                      _buildProtagonistField(context),
                      const SizedBox(height: AppDesignTokens.space16),
                      _buildWorldNodeField(context),
                      const SizedBox(height: AppDesignTokens.space24),
                      _buildActions(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DesktopPalette palette) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDesignTokens.space24,
        AppDesignTokens.space20,
        AppDesignTokens.space24,
        AppDesignTokens.space20,
      ),
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppDesignTokens.radiusLarge),
          topRight: Radius.circular(AppDesignTokens.radiusLarge),
        ),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFD8D2C6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: AppDesignTokens.iconLarge,
            color: palette.primary,
          ),
          const SizedBox(width: AppDesignTokens.space12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '新建作品',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.navActive,
                  fontWeight: AppDesignTokens.weightMedium,
                ),
              ),
              const Text(
                '填写基本信息，开始新的创作',
                style: TextStyle(
                  fontSize: AppDesignTokens.fontSizeSmall,
                  color: Color(0xFF999489),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(BuildContext context) {
    final palette = desktopPalette(context);
    return AppDialogField(
      label: '作品名称 *',
      child: TextField(
        key: ProjectWizardPage.nameFieldKey,
        controller: _nameController,
        focusNode: _nameFocusNode,
        textInputAction: TextInputAction.next,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: '输入作品名称',
          hintStyle: const TextStyle(
            color: Color(0xFF999489),
          ),
          filled: true,
          fillColor: const Color(0xFFFBFAF6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFFD8D2C6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: BorderSide(color: palette.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFFD8765F)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFFD8765F), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.space12,
            vertical: AppDesignTokens.space12,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreField(BuildContext context) {
    return AppDialogField(
      label: '作品类型',
      child: TextField(
        key: ProjectWizardPage.genreFieldKey,
        controller: _genreController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          hintText: '例如：悬疑、科幻、言情...',
          hintStyle: const TextStyle(
            color: Color(0xFF999489),
          ),
          filled: true,
          fillColor: const Color(0xFFFBFAF6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFFD8D2C6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFF5C7A69)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.space12,
            vertical: AppDesignTokens.space12,
          ),
        ),
      ),
    );
  }

  Widget _buildProtagonistField(BuildContext context) {
    return AppDialogField(
      label: '主角',
      child: TextField(
        key: ProjectWizardPage.protagonistFieldKey,
        controller: _protagonistController,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          hintText: '输入主角名称',
          hintStyle: const TextStyle(
            color: Color(0xFF999489),
          ),
          filled: true,
          fillColor: const Color(0xFFFBFAF6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFFD8D2C6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFF5C7A69)),
          ),
          prefixIcon: const Icon(
            Icons.person,
            size: AppDesignTokens.iconMedium,
            color: Color(0xFF999489),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.space12,
            vertical: AppDesignTokens.space12,
          ),
        ),
      ),
    );
  }

  Widget _buildWorldNodeField(BuildContext context) {
    return AppDialogField(
      label: '世界观地点',
      child: TextField(
        key: ProjectWizardPage.worldNodeFieldKey,
        controller: _worldNodeController,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _canCreate ? _handleCreate() : null,
        decoration: InputDecoration(
          hintText: '输入主要地点名称',
          hintStyle: const TextStyle(
            color: Color(0xFF999489),
          ),
          filled: true,
          fillColor: const Color(0xFFFBFAF6),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFFD8D2C6)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
            borderSide: const BorderSide(color: Color(0xFF5C7A69)),
          ),
          prefixIcon: const Icon(
            Icons.place,
            size: AppDesignTokens.iconMedium,
            color: Color(0xFF999489),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDesignTokens.space12,
            vertical: AppDesignTokens.space12,
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          key: ProjectWizardPage.cancelButtonKey,
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        const SizedBox(width: AppDesignTokens.space12),
        FilledButton(
          key: ProjectWizardPage.createButtonKey,
          onPressed: _canCreate ? _handleCreate : null,
          child: Text(_isCreating ? '创建中...' : '创建'),
        ),
      ],
    );
  }
}
