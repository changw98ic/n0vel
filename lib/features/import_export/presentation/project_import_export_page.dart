import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_ai_history_store.dart';
import '../../../app/state/app_draft_store.dart';
import '../../../app/state/app_scene_context_store.dart';
import '../../../app/state/app_simulation_store.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../data/project_transfer_service.dart';

enum ProjectImportExportUiState {
  ready,
  importSuccess,
  exportSuccess,
  overwriteSuccess,
  overwriteConfirm,
  invalidPackage,
  missingManifest,
  noExportableProject,
  majorVersionBlocked,
  minorVersionWarning,
  integrityCheckFailed,
}

class ProjectImportExportPage extends StatefulWidget {
  const ProjectImportExportPage({
    super.key,
    this.uiState = ProjectImportExportUiState.ready,
  });

  static const titleKey = ValueKey<String>('project-import-export-title');
  static const manifestKey = ValueKey<String>('project-import-export-manifest');
  static const executeImportButtonKey = ValueKey<String>(
    'project-import-export-execute-import',
  );
  @visibleForTesting
  static ProjectTransferService? debugServiceOverride;

  final ProjectImportExportUiState uiState;

  @override
  State<ProjectImportExportPage> createState() =>
      _ProjectImportExportPageState();
}

class _ProjectImportExportPageState extends State<ProjectImportExportPage> {
  bool _isDrawerOpen = false;
  late final ProjectTransferService _service;
  ProjectPackageManifest? _manifest;
  String? _manifestPackagePath;

  @override
  void initState() {
    super.initState();
    _service =
        ProjectImportExportPage.debugServiceOverride ??
        ProjectTransferService(
          roleplayStateExport: exportRoleplayStateForProject,
          roleplayStateImport: importRoleplayStateForProject,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshManifestSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveUiState = _effectiveUiState(context);
    return DesktopShellFrame(
      header: const DesktopHeaderBar(
        title: '工程导入导出',
        titleKey: ProjectImportExportPage.titleKey,
        subtitle: '导出现有工程包，或导入外部工程',
        showBackButton: true,
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
            width: 180,
            child: Container(
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.all(16),
              child: _buildExportPanel(context, theme, effectiveUiState),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.all(16),
              child: _buildImportPanel(context, theme, effectiveUiState),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            child: Container(
              key: ProjectImportExportPage.manifestKey,
              decoration: appPanelDecoration(context),
              padding: const EdgeInsets.all(16),
              child: _buildManifestPanel(theme),
            ),
          ),
        ],
      ),
      statusBar: DesktopStatusStrip(
        leftText: _footerMessage(effectiveUiState),
        rightText: '已入库摘要同步',
      ),
    );
  }

  Widget _buildExportPanel(
    BuildContext context,
    ThemeData theme,
    ProjectImportExportUiState effectiveUiState,
  ) {
    final exportDisabled =
        effectiveUiState == ProjectImportExportUiState.noExportableProject;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('导出工程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: appPanelDecoration(
              context,
              color: desktopPalette(context).elevated,
            ),
            child: Text(
              exportDisabled ? '目前没有项目' : _service.exportPackagePath,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: exportDisabled ? null : () => _handleExport(context),
              child: const Text('导出当前工程'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportPanel(
    BuildContext context,
    ThemeData theme,
    ProjectImportExportUiState effectiveUiState,
  ) {
    final status = _statusDescriptor(effectiveUiState);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('导入工程', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _FieldRow(label: '工程包', value: _service.importPackagePath),
          const SizedBox(height: 8),
          const _FieldRow(label: '导入方式', value: '导入为新项目'),
          const SizedBox(height: 12),
          SizedBox(
            width: 108,
            child: FilledButton(
              onPressed:
                  effectiveUiState ==
                      ProjectImportExportUiState.majorVersionBlocked
                  ? null
                  : () => _handleImport(context),
              key: ProjectImportExportPage.executeImportButtonKey,
              child: const Text('执行导入'),
            ),
          ),
          const SizedBox(height: 16),
          _TransferStatusCard(
            descriptor: status,
            accent: _stateAccent(effectiveUiState),
          ),
          if (effectiveUiState == ProjectImportExportUiState.importSuccess ||
              effectiveUiState ==
                  ProjectImportExportUiState.overwriteSuccess) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () =>
                      AppNavigator.push(context, AppRoutes.workbench),
                  child: const Text('打开项目'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回项目列表'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManifestPanel(ThemeData theme) {
    final manifest = _manifest;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('包信息 / 兼容性', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _FieldRow(label: '包名', value: manifest?.packageName ?? 'lunarifest'),
          const SizedBox(height: 8),
          _FieldRow(label: '包版本', value: manifest?.schemaLabel ?? 'v1.0'),
          const SizedBox(height: 8),
          _FieldRow(label: '项目', value: manifest?.projectTitle ?? '等待导入或导出'),
          const SizedBox(height: 8),
          _FieldRow(
            label: '内容摘要',
            value: manifest?.contentSummary ?? '正文 / 资料 / 风格 / 版本',
          ),
          if (_manifestPackagePath != null) ...[
            const SizedBox(height: 8),
            _FieldRow(label: '包路径', value: _manifestPackagePath!),
          ],
        ],
      ),
    );
  }

  ProjectImportExportUiState _effectiveUiState(BuildContext context) {
    if (widget.uiState != ProjectImportExportUiState.ready) {
      return widget.uiState;
    }
    return switch (AppWorkspaceScope.of(context).projectTransferState) {
      ProjectTransferState.ready => ProjectImportExportUiState.ready,
      ProjectTransferState.importSuccess =>
        ProjectImportExportUiState.importSuccess,
      ProjectTransferState.exportSuccess =>
        ProjectImportExportUiState.exportSuccess,
      ProjectTransferState.overwriteSuccess =>
        ProjectImportExportUiState.overwriteSuccess,
      ProjectTransferState.overwriteConfirm =>
        ProjectImportExportUiState.overwriteConfirm,
      ProjectTransferState.invalidPackage =>
        ProjectImportExportUiState.invalidPackage,
      ProjectTransferState.missingManifest =>
        ProjectImportExportUiState.missingManifest,
      ProjectTransferState.noExportableProject =>
        ProjectImportExportUiState.noExportableProject,
      ProjectTransferState.majorVersionBlocked =>
        ProjectImportExportUiState.majorVersionBlocked,
      ProjectTransferState.minorVersionWarning =>
        ProjectImportExportUiState.minorVersionWarning,
      ProjectTransferState.integrityCheckFailed =>
        ProjectImportExportUiState.integrityCheckFailed,
    };
  }

  _TransferStatusDescriptor _statusDescriptor(
    ProjectImportExportUiState effectiveUiState,
  ) {
    switch (effectiveUiState) {
      case ProjectImportExportUiState.ready:
        return const _TransferStatusDescriptor(
          header: '导入准备',
          tone: '待执行',
          title: '准备导入',
          message: '默认导入模式为“导入为新项目”，右侧会展示包摘要与兼容性。',
          detailTitle: '当前流程',
          detailLines: ['检查工程包摘要', '确认兼容性后执行导入'],
        );
      case ProjectImportExportUiState.importSuccess:
        return const _TransferStatusDescriptor(
          header: '导入结果',
          tone: '已完成',
          title: '导入成功',
          message: '角色、世界观、风格、版本与最近写作位置索引已经刷新。',
          detailTitle: '已刷新内容',
          detailLines: ['角色 / 世界观 / 风格 / 版本', '最近写作位置与当前项目入口'],
        );
      case ProjectImportExportUiState.exportSuccess:
        return const _TransferStatusDescriptor(
          header: '导出结果',
          tone: '已完成',
          title: '导出成功',
          message: '工程包已写入本地导出目录，可直接分发或重新导入验证。',
          detailTitle: '当前状态',
          detailLines: ['已写入本地导出目录', '可直接分发或重新导入验证'],
        );
      case ProjectImportExportUiState.overwriteSuccess:
        return const _TransferStatusDescriptor(
          header: '导入结果',
          tone: '已覆盖',
          title: '覆盖导入成功',
          message: '旧索引已被替换刷新，可以直接进入项目继续写作。',
          detailTitle: '已替换内容',
          detailLines: ['同 ID 项目的本地索引', '最近写作位置与书架入口'],
        );
      case ProjectImportExportUiState.overwriteConfirm:
        return const _TransferStatusDescriptor(
          header: '兼容性提示',
          tone: '待确认',
          title: '覆盖确认',
          message: '覆盖导入会替换同 ID 项目的本地索引与最近写作位置。',
          detailTitle: '覆盖范围',
          detailLines: ['同 ID 项目的本地索引', '最近写作位置与书架入口'],
        );
      case ProjectImportExportUiState.invalidPackage:
        return const _TransferStatusDescriptor(
          header: '失败原因',
          tone: '结构异常',
          title: '非法工程包',
          message: '工程包结构非法，无法继续导入。',
          detailTitle: '阻塞项',
          detailLines: ['无法识别为有效工程包', '请重新导出后再尝试导入'],
        );
      case ProjectImportExportUiState.missingManifest:
        return const _TransferStatusDescriptor(
          header: '失败原因',
          tone: '缺少摘要',
          title: '缺少 manifest.json',
          message: '无法读取项目元信息，导入按钮已禁用。',
          detailTitle: '阻塞项',
          detailLines: ['manifest.json 缺失', '无法确认项目元信息与兼容性'],
        );
      case ProjectImportExportUiState.noExportableProject:
        return const _TransferStatusDescriptor(
          header: '导出状态',
          tone: '无项目',
          title: '无可导出项目',
          message: '请先创建项目或导入一个工程。',
          detailTitle: '当前状态',
          detailLines: ['当前没有可导出的本地项目', '可先创建项目或导入现有工程'],
        );
      case ProjectImportExportUiState.majorVersionBlocked:
        return const _TransferStatusDescriptor(
          header: '失败原因',
          tone: '已阻止',
          title: '版本主号不兼容',
          message: '主版本号不兼容，请重新导出或升级客户端。',
          detailTitle: '兼容性',
          detailLines: ['当前客户端仅支持 schema v1.x', '无法导入更高主版本工程包'],
        );
      case ProjectImportExportUiState.minorVersionWarning:
        return const _TransferStatusDescriptor(
          header: '兼容性提示',
          tone: '允许继续',
          title: '版本次号兼容性警告',
          message: '次版本号不一致，但仍允许继续导入。',
          detailTitle: '兼容性',
          detailLines: ['schema_minor 不一致', '允许继续导入，但建议先核对内容后再继续'],
        );
      case ProjectImportExportUiState.integrityCheckFailed:
        return const _TransferStatusDescriptor(
          header: '失败原因',
          tone: '完整性校验失败',
          title: '数据完整性校验未通过',
          message: '工程包数据校验失败，文件可能已损坏或被篡改。',
          detailTitle: '阻塞项',
          detailLines: ['载荷文件校验和不匹配或数据结构不合法', '请重新导出后再尝试导入'],
        );
    }
  }

  Color _stateAccent(ProjectImportExportUiState effectiveUiState) {
    switch (effectiveUiState) {
      case ProjectImportExportUiState.importSuccess:
      case ProjectImportExportUiState.exportSuccess:
      case ProjectImportExportUiState.overwriteSuccess:
        return appSuccessColor;
      case ProjectImportExportUiState.minorVersionWarning:
      case ProjectImportExportUiState.overwriteConfirm:
      case ProjectImportExportUiState.noExportableProject:
        return const Color(0xFFB6813B);
      case ProjectImportExportUiState.ready:
        return appInfoColor;
      case ProjectImportExportUiState.invalidPackage:
      case ProjectImportExportUiState.missingManifest:
      case ProjectImportExportUiState.majorVersionBlocked:
      case ProjectImportExportUiState.integrityCheckFailed:
        return appDangerColor;
    }
  }

  String _footerMessage(ProjectImportExportUiState effectiveUiState) {
    switch (effectiveUiState) {
      case ProjectImportExportUiState.ready:
        return '导入导出准备就绪';
      case ProjectImportExportUiState.importSuccess:
        return '导入完成，可继续写作';
      case ProjectImportExportUiState.exportSuccess:
        return '导出完成，可分发工程包';
      case ProjectImportExportUiState.overwriteSuccess:
        return '覆盖导入完成';
      case ProjectImportExportUiState.overwriteConfirm:
        return '等待覆盖确认';
      case ProjectImportExportUiState.invalidPackage:
        return '导入失败：包结构非法';
      case ProjectImportExportUiState.missingManifest:
        return '导入失败：manifest 缺失';
      case ProjectImportExportUiState.noExportableProject:
        return '当前没有可导出的工程';
      case ProjectImportExportUiState.majorVersionBlocked:
        return '导入已阻止';
      case ProjectImportExportUiState.minorVersionWarning:
        return '存在版本兼容提示';
      case ProjectImportExportUiState.integrityCheckFailed:
        return '导入失败：数据完整性校验未通过';
    }
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

  Future<void> _handleExport(BuildContext context) async {
    final workspaceStore = AppWorkspaceScope.of(context);
    final result = await _service.exportPackage(
      aiHistoryStore: AppAiHistoryScope.of(context),
      draftStore: AppDraftScope.of(context),
      sceneContextStore: AppSceneContextScope.of(context),
      simulationStore: AppSimulationScope.of(context),
      versionStore: AppVersionScope.of(context),
      workspaceStore: workspaceStore,
    );
    if (!mounted) {
      return;
    }
    workspaceStore.setProjectTransferState(result.state);
    await _refreshManifestSummary(packagePath: result.packagePath);
  }

  Future<void> _handleImport(BuildContext context) async {
    final workspaceStore = AppWorkspaceScope.of(context);
    final result = await _service.importPackage(
      aiHistoryStore: AppAiHistoryScope.of(context),
      draftStore: AppDraftScope.of(context),
      sceneContextStore: AppSceneContextScope.of(context),
      simulationStore: AppSimulationScope.of(context),
      versionStore: AppVersionScope.of(context),
      workspaceStore: workspaceStore,
      overwriteExisting:
          workspaceStore.projectTransferState ==
          ProjectTransferState.overwriteConfirm,
    );
    if (!mounted) {
      return;
    }
    workspaceStore.setProjectTransferState(result.state);
    await _refreshManifestSummary(packagePath: result.packagePath);
  }

  Future<void> _refreshManifestSummary({String? packagePath}) async {
    final nextPath = packagePath ?? _packagePathForCurrentState();
    if (nextPath == null || nextPath == _manifestPackagePath) {
      return;
    }

    final inspection = await _service.inspectPackage(File(nextPath));
    if (!mounted) {
      return;
    }
    setState(() {
      _manifestPackagePath = nextPath;
      _manifest = inspection.manifest;
    });
  }

  String? _packagePathForCurrentState() {
    switch (widget.uiState) {
      case ProjectImportExportUiState.exportSuccess:
        return _service.exportPackagePath;
      case ProjectImportExportUiState.ready:
      case ProjectImportExportUiState.importSuccess:
      case ProjectImportExportUiState.overwriteSuccess:
      case ProjectImportExportUiState.overwriteConfirm:
      case ProjectImportExportUiState.invalidPackage:
      case ProjectImportExportUiState.missingManifest:
      case ProjectImportExportUiState.noExportableProject:
      case ProjectImportExportUiState.majorVersionBlocked:
      case ProjectImportExportUiState.minorVersionWarning:
      case ProjectImportExportUiState.integrityCheckFailed:
        return _service.importPackagePath;
    }
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

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
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TransferStatusDescriptor {
  const _TransferStatusDescriptor({
    required this.header,
    required this.tone,
    required this.title,
    required this.message,
    required this.detailTitle,
    required this.detailLines,
  });

  final String header;
  final String tone;
  final String title;
  final String message;
  final String detailTitle;
  final List<String> detailLines;
}

class _TransferStatusCard extends StatelessWidget {
  const _TransferStatusCard({required this.descriptor, required this.accent});

  final _TransferStatusDescriptor descriptor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descriptor.header,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  descriptor.tone,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(descriptor.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(descriptor.message, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: appPanelDecoration(
              context,
              color: desktopPalette(context).surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descriptor.detailTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < descriptor.detailLines.length;
                  index++
                ) ...[
                  Text(
                    descriptor.detailLines[index],
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                  ),
                  if (index != descriptor.detailLines.length - 1)
                    const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
