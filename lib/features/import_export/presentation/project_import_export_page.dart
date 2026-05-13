import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di/app_providers.dart';
import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import '../data/project_transfer_service.dart';
import '../data/standard_format_exporter.dart';
import 'import_export_components.dart';

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

class ProjectImportExportPage extends ConsumerStatefulWidget {
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
  ConsumerState<ProjectImportExportPage> createState() =>
      _ProjectImportExportPageState();
}

class _ProjectImportExportPageState extends ConsumerState<ProjectImportExportPage> {
  late final ProjectTransferService _service;
  ProjectPackageManifest? _manifest;
  String? _manifestPackagePath;
  StandardExportFormat _selectedFormat = StandardExportFormat.markdown;
  StandardExportMode _selectedMode = StandardExportMode.manuscript;

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
        subtitle: '导出当前工程，或导入外部工程包',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: 16),
                SizedBox(
                  width: 220,
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
                  width: 260,
                  child: Container(
                    key: ProjectImportExportPage.manifestKey,
                    decoration: appPanelDecoration(context),
                    padding: const EdgeInsets.all(16),
                    child: _buildManifestPanel(theme),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ImportExportResultLog(
            descriptor: _resultLogDescriptor(effectiveUiState),
            accent: _stateAccent(effectiveUiState),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exportDisabled ? '当前没有可导出的项目' : '本地导出目录',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                exportDisabled
                    ? Text('请先创建或导入项目', style: theme.textTheme.bodyMedium)
                    : ImportExportPathValueText(value: _service.exportPackagePath),
              ],
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
          const SizedBox(height: 16),
          Text('导出稿件', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: appPanelDecoration(
              context,
              color: desktopPalette(context).elevated,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('格式', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                ImportExportFormatDropdown<StandardExportFormat>(
                  title: '选择导出格式',
                  value: _selectedFormat,
                  items: const [
                    (StandardExportFormat.markdown, 'Markdown'),
                    (StandardExportFormat.html, 'HTML'),
                    (StandardExportFormat.plainText, '纯文本'),
                    (StandardExportFormat.json, 'JSON'),
                  ],
                  onChanged: (v) => setState(() => _selectedFormat = v),
                ),
                const SizedBox(height: 8),
                Text('范围', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                ImportExportFormatDropdown<StandardExportMode>(
                  title: '选择导出范围',
                  value: _selectedMode,
                  items: const [
                    (StandardExportMode.manuscript, '稿件正文'),
                    (StandardExportMode.fullProject, '完整项目'),
                    (StandardExportMode.finalDraft, '终稿'),
                  ],
                  onChanged: (v) => setState(() => _selectedMode = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: exportDisabled
                  ? null
                  : () => _handleFormatExport(context),
              child: const Text('导出稿件'),
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
          ImportExportFieldRow(label: '工程包', value: _service.importPackagePath),
          const SizedBox(height: 8),
          const ImportExportFieldRow(label: '导入方式', value: '导入为新项目'),
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
          ImportExportStatusCard(
            descriptor: status,
            accent: _stateAccent(effectiveUiState),
          ),
          if (_shouldShowGuidanceCard(effectiveUiState)) ...[
            const SizedBox(height: 12),
            ImportExportGuidanceCard(
              descriptor: _guidanceDescriptor(effectiveUiState),
              accent: _stateAccent(effectiveUiState),
            ),
          ],
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
          ImportExportFieldRow(label: '包名', value: manifest?.packageName ?? '小说工程包'),
          const SizedBox(height: 8),
          ImportExportFieldRow(label: '包版本', value: manifest?.schemaLabel ?? 'v1.0'),
          const SizedBox(height: 8),
          ImportExportFieldRow(label: '项目', value: manifest?.projectTitle ?? '等待导入或导出'),
          const SizedBox(height: 8),
          ImportExportFieldRow(
            label: '内容摘要',
            value: manifest?.contentSummary ?? '正文 / 资料 / 风格 / 版本',
          ),
          if (_manifestPackagePath != null) ...[
            const SizedBox(height: 8),
            ImportExportFieldRow(label: '包路径', value: _manifestPackagePath!),
          ],
        ],
      ),
    );
  }

  ProjectImportExportUiState _effectiveUiState(BuildContext context) {
    if (widget.uiState != ProjectImportExportUiState.ready) {
      return widget.uiState;
    }
    return switch (ref.watch(appWorkspaceStoreProvider).projectTransferState) {
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

  TransferStatusDescriptor _statusDescriptor(
    ProjectImportExportUiState effectiveUiState,
  ) {
    switch (effectiveUiState) {
      case ProjectImportExportUiState.ready:
        return const TransferStatusDescriptor(
          header: '导入准备',
          tone: '待执行',
          title: '准备导入',
          message: '默认导入模式为“导入为新项目”，右侧会展示包摘要与兼容性。',
          detailTitle: '当前流程',
          detailLines: ['检查工程包摘要', '确认兼容性后执行导入'],
        );
      case ProjectImportExportUiState.importSuccess:
        return const TransferStatusDescriptor(
          header: '导入结果',
          tone: '已完成',
          title: '导入成功',
          message: '角色、世界观、风格、版本与最近写作位置索引已经刷新。',
          detailTitle: '已刷新内容',
          detailLines: ['角色 / 世界观 / 风格 / 版本', '最近写作位置与当前项目入口'],
        );
      case ProjectImportExportUiState.exportSuccess:
        return const TransferStatusDescriptor(
          header: '导出结果',
          tone: '已完成',
          title: '导出成功',
          message: '工程包已写入本地导出目录，可直接分发或重新导入验证。',
          detailTitle: '当前状态',
          detailLines: ['已写入本地导出目录', '可直接分发或重新导入验证'],
        );
      case ProjectImportExportUiState.overwriteSuccess:
        return const TransferStatusDescriptor(
          header: '导入结果',
          tone: '已覆盖',
          title: '覆盖导入成功',
          message: '旧索引已被替换刷新，可以直接进入项目继续写作。',
          detailTitle: '已替换内容',
          detailLines: ['同 ID 项目的本地索引', '最近写作位置与书架入口'],
        );
      case ProjectImportExportUiState.overwriteConfirm:
        return const TransferStatusDescriptor(
          header: '兼容性提示',
          tone: '待确认',
          title: '覆盖确认',
          message: '检测到导入包中的项目 ID 与本地项目一致；覆盖导入会替换同 ID 项目的本地索引与最近写作位置。',
          detailTitle: '覆盖导入确认',
          detailLines: ['继续导入将覆盖当前工程数据', '建议先导出当前项目备份，再确认是否覆盖'],
        );
      case ProjectImportExportUiState.invalidPackage:
        return const TransferStatusDescriptor(
          header: '失败原因',
          tone: '结构异常',
          title: '非法工程包',
          message: '当前选择的工程包缺少必要元信息或版本主号不兼容，系统已阻止导入。',
          detailTitle: '阻塞项',
          detailLines: ['无法识别为有效工程包', '请重新选择有效工程包，或在来源客户端重新导出'],
        );
      case ProjectImportExportUiState.missingManifest:
        return const TransferStatusDescriptor(
          header: '失败原因',
          tone: '缺少摘要',
          title: '缺少 manifest.json',
          message: '无法读取项目元信息：当前选择的工程包无法找到 manifest.json，系统已阻止导入。',
          detailTitle: '阻塞项',
          detailLines: ['manifest.json 缺失', '无法确认项目元信息与兼容性'],
        );
      case ProjectImportExportUiState.noExportableProject:
        return const TransferStatusDescriptor(
          header: '导出状态',
          tone: '无项目',
          title: '无可导出项目',
          message: '请先创建项目或导入一个工程。',
          detailTitle: '当前状态',
          detailLines: ['当前没有可导出的本地项目', '可先创建项目或导入现有工程'],
        );
      case ProjectImportExportUiState.majorVersionBlocked:
        return const TransferStatusDescriptor(
          header: '失败原因',
          tone: '已阻止',
          title: '版本主号不兼容',
          message: '当前客户端仅支持 schema v1.x，无法导入更高主版本工程包。',
          detailTitle: '兼容性',
          detailLines: ['schema_major 不一致', '请在来源客户端降级导出，或升级本地客户端后再重试'],
        );
      case ProjectImportExportUiState.minorVersionWarning:
        return const TransferStatusDescriptor(
          header: '兼容性提示',
          tone: '允许继续',
          title: '版本次号兼容性警告',
          message: '次版本号不一致，但仍允许继续导入。',
          detailTitle: '兼容性',
          detailLines: ['schema_minor 不一致', '允许继续导入，但建议先核对内容后再继续'],
        );
      case ProjectImportExportUiState.integrityCheckFailed:
        return const TransferStatusDescriptor(
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

  TransferStatusDescriptor _resultLogDescriptor(
    ProjectImportExportUiState effectiveUiState,
  ) {
    switch (effectiveUiState) {
      case ProjectImportExportUiState.ready:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '待执行',
          title: '准备记录',
          message: '等待选择工程包或执行导出，结果会在这里留下简短记录。',
          detailTitle: '当前记录',
          detailLines: ['包摘要已同步', '兼容性检查将在执行前完成'],
        );
      case ProjectImportExportUiState.importSuccess:
      case ProjectImportExportUiState.overwriteSuccess:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '已完成',
          title: '已刷新项目索引',
          message: '正文、角色、世界观、风格配置与最近版本索引已刷新完成。',
          detailTitle: '同步范围',
          detailLines: ['角色卡、世界观节点、风格绑定', '章节版本与最近写作位置'],
        );
      case ProjectImportExportUiState.exportSuccess:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '已完成',
          title: '已写入本地导出目录',
          message: '工程包可直接分发，也可重新导入做一次完整性验证。',
          detailTitle: '导出位置',
          detailLines: ['本地导出目录', '建议分发前保留一份项目备份'],
        );
      case ProjectImportExportUiState.overwriteConfirm:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '等待确认',
          title: '覆盖前已暂停',
          message: '覆盖后仍会保留导入前确认步骤，不允许静默覆盖。',
          detailTitle: '建议操作',
          detailLines: ['先导出当前项目备份', '确认同 ID 工程后再继续导入'],
        );
      case ProjectImportExportUiState.invalidPackage:
      case ProjectImportExportUiState.missingManifest:
      case ProjectImportExportUiState.majorVersionBlocked:
      case ProjectImportExportUiState.integrityCheckFailed:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '已阻止',
          title: '无法导入工程包',
          message: '系统已阻止导入，避免污染本地数据库。',
          detailTitle: '下一步',
          detailLines: ['重新选择有效工程包', '或在来源客户端重新导出完整包'],
        );
      case ProjectImportExportUiState.noExportableProject:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '无对象',
          title: '暂无导出对象',
          message: '请先创建或导入项目，之后才能执行工程导出。',
          detailTitle: '建议',
          detailLines: ['确认项目已保存到本地数据库', '没有项目时导出入口保持禁用'],
        );
      case ProjectImportExportUiState.minorVersionWarning:
        return const TransferStatusDescriptor(
          header: '导入导出结果日志',
          tone: '可继续',
          title: '次版本兼容性提示',
          message: '版本次号不一致，但仍允许导入并给出兼容性警告。',
          detailTitle: '建议',
          detailLines: ['先核对内容摘要', '确认来源工程包后再继续导入'],
        );
    }
  }

  TransferStatusDescriptor _guidanceDescriptor(
    ProjectImportExportUiState effectiveUiState,
  ) {
    switch (effectiveUiState) {
      case ProjectImportExportUiState.overwriteConfirm:
        return const TransferStatusDescriptor(
          header: '下一步',
          tone: '建议备份',
          title: '覆盖前先留一份备份',
          message: '如果不确定导入包内容，先导出当前项目，再继续覆盖。',
          detailTitle: '操作建议',
          detailLines: ['先导出当前项目备份', '确认同 ID 工程后再执行导入'],
        );
      case ProjectImportExportUiState.invalidPackage:
      case ProjectImportExportUiState.missingManifest:
      case ProjectImportExportUiState.integrityCheckFailed:
        return const TransferStatusDescriptor(
          header: '下一步',
          tone: '重新选择',
          title: '换一个完整工程包',
          message: '当前文件不能安全导入，重新选择前不会写入本地数据库。',
          detailTitle: '操作建议',
          detailLines: ['重新选择有效工程包', '或在来源客户端重新导出完整包'],
        );
      case ProjectImportExportUiState.majorVersionBlocked:
        return const TransferStatusDescriptor(
          header: '下一步',
          tone: '需要处理',
          title: '先解决版本主号',
          message: '主版本不兼容时不允许继续导入。',
          detailTitle: '操作建议',
          detailLines: ['在来源客户端降级导出', '或升级当前客户端后再重试'],
        );
      case ProjectImportExportUiState.ready:
      case ProjectImportExportUiState.importSuccess:
      case ProjectImportExportUiState.exportSuccess:
      case ProjectImportExportUiState.overwriteSuccess:
      case ProjectImportExportUiState.noExportableProject:
      case ProjectImportExportUiState.minorVersionWarning:
        return _resultLogDescriptor(effectiveUiState);
    }
  }

  bool _shouldShowGuidanceCard(ProjectImportExportUiState effectiveUiState) {
    return switch (effectiveUiState) {
      ProjectImportExportUiState.overwriteConfirm ||
      ProjectImportExportUiState.invalidPackage ||
      ProjectImportExportUiState.missingManifest ||
      ProjectImportExportUiState.majorVersionBlocked ||
      ProjectImportExportUiState.integrityCheckFailed => true,
      ProjectImportExportUiState.ready ||
      ProjectImportExportUiState.importSuccess ||
      ProjectImportExportUiState.exportSuccess ||
      ProjectImportExportUiState.overwriteSuccess ||
      ProjectImportExportUiState.noExportableProject ||
      ProjectImportExportUiState.minorVersionWarning => false,
    };
  }

  void _refreshManifestSummary() {
    if (mounted) setState(() {});
  }

  Future<void> _handleExport(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中')),
    );
  }

  Future<void> _handleFormatExport(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('稿件导出功能开发中')),
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    _refreshManifestSummary();
  }
}
