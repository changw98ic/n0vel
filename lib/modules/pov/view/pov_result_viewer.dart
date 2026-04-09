import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/pov_generation/domain/pov_models.dart';

/// POV 结果查看器
class POVResultViewer extends StatefulWidget {
  final POVTask task;
  final Function(String content) onAccept;
  final VoidCallback onRegenerate;
  final Function(String content) onEdit;

  const POVResultViewer({
    super.key,
    required this.task,
    required this.onAccept,
    required this.onRegenerate,
    required this.onEdit,
  });

  @override
  State<POVResultViewer> createState() => _POVResultViewerState();
}

class _POVResultViewerState extends State<POVResultViewer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _editController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _editController.text = widget.task.generatedContent ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(POVResultViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.generatedContent != widget.task.generatedContent) {
      _editController.text = widget.task.generatedContent ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    if (widget.task.status == POVTaskStatus.failed) {
      return _buildErrorView();
    }

    if (widget.task.status == POVTaskStatus.pending ||
        widget.task.status == POVTaskStatus.analyzing ||
        widget.task.status == POVTaskStatus.generating) {
      return _buildLoadingView();
    }

    return Column(
      children: [
        // 标签栏
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: s.povResult_tab_result),
              Tab(text: s.povResult_tab_analysis),
            ],
          ),
        ),

        // 内容区
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildResultTab(),
              _buildAnalysisTab(),
            ],
          ),
        ),

        // 底部操作栏
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildLoadingView() {
    final s = S.of(context)!;
    final statusText = switch (widget.task.status) {
      POVTaskStatus.pending => s.povResult_status_preparing,
      POVTaskStatus.analyzing => s.povResult_status_analyzing,
      POVTaskStatus.generating => s.povResult_status_generating,
      _ => s.povResult_status_processing,
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: 24.h),
          Text(
            statusText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: 8.h),
          Text(
            s.povResult_pleaseWait,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
            SizedBox(height: 16.h),
            Text(
              '生成失败',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              widget.task.errorMessage ?? '未知错误',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: widget.onRegenerate,
              icon: Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTab() {
    if (widget.task.generatedContent == null) {
      return const Center(child: Text('暂无生成结果'));
    }

    return Column(
      children: [
        // 工具栏
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '字数：${widget.task.generatedContent!.length}',
                style: TextStyle(fontSize: 12.sp),
              ),
              SizedBox(width: 16.w),
              Text(
                'Token：${widget.task.tokenUsage}',
                style: TextStyle(fontSize: 12.sp),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.task.generatedContent!),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                tooltip: '复制',
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
                onPressed: () {
                  setState(() => _isEditing = !_isEditing);
                },
                tooltip: _isEditing ? '预览' : '编辑',
              ),
            ],
          ),
        ),

        // 内容
        Expanded(
          child: _isEditing
              ? TextField(
                  controller: _editController,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16.w),
                  ),
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16.sp,
                    height: 1.8,
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(24.w),
                  child: SelectableText(
                    widget.task.generatedContent!,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16.sp,
                      height: 1.8,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAnalysisTab() {
    final analysis = widget.task.analysis;
    if (analysis == null) {
      return const Center(child: Text('暂无分析数据'));
    }

    // 这里需要解析 JSON
    // 简化处理，直接显示原始 JSON
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics),
                  SizedBox(width: 8.w),
                  Text(
                    '分析报告',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              const Text(
                '分析数据将在生成完成后显示在这里，包括：',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 8.h),
              const Text('• 角色出现段落'),
              const Text('• 情感曲线分析'),
              const Text('• 关键观察记录'),
              const Text('• 角色互动分析'),
              const Text('• 建议的内心独白'),
              SizedBox(height: 16.h),
              ExpansionTile(
                title: const Text('查看原始数据'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      analysis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          // 重新生成
          OutlinedButton.icon(
            onPressed: widget.onRegenerate,
            icon: Icon(Icons.refresh),
            label: const Text('重新生成'),
          ),
          SizedBox(width: 16.w),

          // 配置信息
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(widget.task.config.mode.label),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(widget.task.config.style.label),
                  visualDensity: VisualDensity.compact,
                ),
                if (widget.task.config.addInnerThoughts)
                  const Chip(
                    label: Text('内心独白'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

          SizedBox(width: 16.w),

          // 接受
          FilledButton.icon(
            onPressed: () {
              final content =
                  _isEditing ? _editController.text : widget.task.generatedContent!;
              widget.onAccept(content);
            },
            icon: Icon(Icons.check),
            label: const Text('采纳'),
          ),
        ],
      ),
    );
  }
}
