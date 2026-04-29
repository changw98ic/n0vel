import 'package:flutter/material.dart';

import '../../../../app/state/app_workspace_store.dart';
import '../../../../app/widgets/desktop_shell.dart';
import '../style_panel_ui_state.dart';
import 'style_questionnaire_widgets.dart' show styleStringListFromRaw;

class StyleSummaryPane extends StatelessWidget {
  const StyleSummaryPane({
    super.key,
    required this.uiState,
    required this.workflowMessage,
    required this.warningMessages,
    required this.profile,
  });

  final StylePanelUiState uiState;
  final String workflowMessage;
  final List<String> warningMessages;
  final StyleProfileRecord? profile;

  @override
  Widget build(BuildContext context) {
    if (uiState == StylePanelUiState.ready && profile != null) {
      final jsonData = profile!.jsonData;
      return ListView(
        children: [
          _SummaryRow(
            label: '视角',
            value: _povLabel(jsonData['pov_mode']?.toString() ?? ''),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: '句长',
            value: _sentenceLengthLabel(
              jsonData['sentence_length_preference']?.toString() ?? '',
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: '对白比',
            value: _dialogueRatioLabel(
              jsonData['dialogue_ratio']?.toString() ?? '',
            ),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: '节奏',
            value: _rhythmLabel(jsonData['rhythm_profile']?.toString() ?? ''),
          ),
          const SizedBox(height: 8),
          _SummaryBlock(
            title: '禁忌表达',
            message: styleStringListFromRaw(
              jsonData['taboo_patterns'],
            ).join('、'),
          ),
          const SizedBox(height: 8),
          _SummaryBlock(title: '生成风格', message: profile!.name),
          const SizedBox(height: 8),
          _SummaryBlock(title: '状态', message: workflowMessage),
          if (warningMessages.isNotEmpty) ...[
            const SizedBox(height: 8),
            _SummaryBlock(title: '提示', message: warningMessages.join('\n')),
          ],
        ],
      );
    }

    if (uiState == StylePanelUiState.jsonError ||
        uiState == StylePanelUiState.unsupportedVersion) {
      return _SummaryOverlayCard(
        title: _title(),
        sections: [
          _SummarySectionData(title: '问题详情', lines: _primaryMessageLines()),
          _SummarySectionData(title: '处理建议', message: _resolutionMessage()),
          _SummarySectionData(title: '结果说明', message: _impactMessage()),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final section in _sections()) ...[
            _SummarySectionCard(section: section, accentColor: _accentColor()),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  String _title() {
    switch (uiState) {
      case StylePanelUiState.ready:
        return '冷峻悬疑第一人称';
      case StylePanelUiState.empty:
        return '尚未生成风格摘要';
      case StylePanelUiState.jsonError:
        return 'JSON 校验失败';
      case StylePanelUiState.unsupportedVersion:
        return '配置版本不受支持';
      case StylePanelUiState.unknownFieldsIgnored:
        return '未知字段已忽略';
      case StylePanelUiState.missingRequiredFields:
        return '问卷缺少必填项';
      case StylePanelUiState.validationFailed:
        return '风格校验失败';
      case StylePanelUiState.maxProfilesReached:
        return '达到风格配置上限';
      case StylePanelUiState.sceneOverrideNotice:
        return '场景级覆盖已生效';
    }
  }

  List<_SummarySectionData> _sections() {
    switch (uiState) {
      case StylePanelUiState.ready:
        return const [];
      case StylePanelUiState.empty:
        return const [
          _SummarySectionData(
            title: '开始方式',
            message: '从填写问卷或导入配置文件开始，摘要区会以风格卡的形式显示结果。',
          ),
        ];
      case StylePanelUiState.jsonError:
        return const [];
      case StylePanelUiState.unsupportedVersion:
        return const [];
      case StylePanelUiState.unknownFieldsIgnored:
        return const [
          _SummarySectionData(
            title: '忽略说明',
            message:
                '已忽略 2 个未知字段：mood_shift、voice_bias。其余合法字段已成功生成 StyleProfile。',
          ),
          _SummarySectionData(title: '结果说明', message: '附加备注字段已忽略，核心摘要仍可生成。'),
        ];
      case StylePanelUiState.missingRequiredFields:
        return const [
          _SummarySectionData(
            title: '缺失必填项',
            message: '体裁标签至少需要填写 1 项，因此当前问卷暂时无法生成新的 StyleProfile。',
          ),
          _SummarySectionData(
            title: '建议修正',
            message: '请先补全至少一个体裁标签，再重新生成风格配置。其余问卷输入已保留。',
          ),
        ];
      case StylePanelUiState.validationFailed:
        return const [
          _SummarySectionData(
            title: '失败原因',
            message:
                '当前风格输入之间存在冲突：极低描写密度与高情绪强度无法同时满足既定节奏规则，因此本轮未生成 StyleProfile。',
          ),
          _SummarySectionData(
            title: '建议修正',
            message: '可降低情绪强度，或把描写密度调回中等，再重新生成风格配置。',
          ),
          _SummarySectionData(
            title: '结果说明',
            message: '当前项目与场景绑定保持不变，本轮不会生成新的 StyleProfile。',
          ),
        ];
      case StylePanelUiState.maxProfilesReached:
        return const [
          _SummarySectionData(
            title: '容量上限',
            message: '同一项目最多保留 3 个风格配置，请先删除或替换现有配置。',
          ),
          _SummarySectionData(
            title: '建议操作',
            message: '保留正在使用的配置，并归档不再需要的旧版本后再继续新增。',
          ),
        ];
      case StylePanelUiState.sceneOverrideNotice:
        return const [
          _SummarySectionData(
            title: '覆盖说明',
            message: '当前场景使用更强约束，项目级风格仍保留为默认值。',
          ),
          _SummarySectionData(
            title: '绑定结果',
            message: '场景级绑定优先于项目级默认风格，切换场景后仍会恢复项目默认配置。',
          ),
        ];
    }
  }

  List<String> _primaryMessageLines() {
    return switch (uiState) {
      StylePanelUiState.jsonError => const [
        '错误 1：缺少必填字段 version',
        '错误 2：rhythm_profile 值不受支持',
      ],
      StylePanelUiState.unsupportedVersion => const [
        '当前文件声明的 version 为 2.0。',
        'MVP 仅支持 1.0 版配置。',
      ],
      _ => const [],
    };
  }

  String _resolutionMessage() {
    return switch (uiState) {
      StylePanelUiState.jsonError =>
        '当前选择的 StyleProfile JSON 不符合 MVP 支持的字段约定。请修正 JSON 后重新导入。',
      StylePanelUiState.unsupportedVersion =>
        '请在来源工具中导出 version: 1.0 的配置，或手动降级字段后重新导入。',
      _ => '',
    };
  }

  String _impactMessage() {
    return switch (uiState) {
      StylePanelUiState.jsonError => '系统不会生成风格配置。',
      StylePanelUiState.unsupportedVersion =>
        '该 JSON 文件可被读取，但当前版本不会被导入，也不会生成新的 StyleProfile。',
      _ => '',
    };
  }

  Color _accentColor() {
    return switch (uiState) {
      StylePanelUiState.unknownFieldsIgnored ||
      StylePanelUiState.maxProfilesReached ||
      StylePanelUiState.sceneOverrideNotice => const Color(0xFFB6813B),
      StylePanelUiState.empty => appInfoColor,
      _ => appDangerColor,
    };
  }

  String _povLabel(String value) {
    return switch (value) {
      'first_person_limited' => '第一人称受限',
      'third_person_multi' => '第三人称多视角',
      _ => '第三人称限知',
    };
  }

  String _sentenceLengthLabel(String value) {
    return switch (value) {
      'short' => '短句',
      'balanced' => '均衡',
      'medium_long' => '中长句',
      _ => '短中句',
    };
  }

  String _dialogueRatioLabel(String value) {
    return switch (value) {
      'low' => '低',
      'high' => '高',
      _ => '中',
    };
  }

  String _rhythmLabel(String value) {
    return switch (value) {
      'slow_burn' => '慢燃',
      'balanced' => '均衡',
      _ => '紧凑',
    };
  }
}

class _SummarySectionData {
  const _SummarySectionData({
    required this.title,
    this.message,
    this.lines = const [],
  });

  final String title;
  final String? message;
  final List<String> lines;
}

class _SummarySectionCard extends StatelessWidget {
  const _SummarySectionCard({required this.section, required this.accentColor});

  final _SummarySectionData section;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: desktopPalette(context).elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: Theme.of(context).textTheme.bodyMedium),
          if (section.lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final line in section.lines) ...[
              Text(line, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
            ],
          ],
          if (section.message case final message?) ...[
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _SummaryOverlayCard extends StatelessWidget {
  const _SummaryOverlayCard({required this.title, required this.sections});

  final String title;
  final List<_SummarySectionData> sections;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appDangerColor.withValues(alpha: 0.65)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              for (var index = 0; index < sections.length; index++) ...[
                _SummarySectionCard(
                  section: sections[index],
                  accentColor: appDangerColor,
                ),
                if (index != sections.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).elevated,
      ),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.title, required this.message});

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
