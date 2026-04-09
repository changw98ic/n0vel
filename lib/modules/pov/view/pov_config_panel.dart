import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:writing_assistant/l10n/app_localizations.dart';

import '../../../features/pov_generation/domain/pov_models.dart';

/// POV 配置面板
class POVConfigPanel extends StatelessWidget {
  final POVConfig config;
  final ValueChanged<POVConfig> onChanged;

  const POVConfigPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context)!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.povGeneration_generationConfig,
              style: theme.textTheme.titleMedium,
            ),
            SizedBox(height: 16.h),

            // 生成模式
            _buildModeSelector(context),
            SizedBox(height: 16.h),

            // 输出风格
            _buildStyleSelector(context),
            SizedBox(height: 16.h),

            // 开关选项
            _buildSwitchOptions(context),
            SizedBox(height: 16.h),

            // 情感强度滑块
            _buildEmotionSlider(context),
            SizedBox(height: 16.h),

            // 目标字数
            _buildTargetWordCount(context),
            SizedBox(height: 16.h),

            // 自定义指令
            _buildCustomInstructions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.povGeneration_generationMode),
        SizedBox(height: 8.h),
        SegmentedButton<POVMode>(
          segments: POVMode.values.map((mode) {
            return ButtonSegment(
              value: mode,
              label: Text(mode.label),
              tooltip: mode.description,
            );
          }).toList(),
          selected: {config.mode},
          onSelectionChanged: (modes) {
            if (modes.isNotEmpty) {
              onChanged(config.copyWith(mode: modes.first));
            }
          },
        ),
      ],
    );
  }

  Widget _buildStyleSelector(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.povGeneration_outputStyle),
        SizedBox(height: 8.h),
        DropdownButtonFormField<POVStyle>(
          value: config.style,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
          items: POVStyle.values.map((style) {
            return DropdownMenuItem(
              value: style,
              child: Text(style.label),
            );
          }).toList(),
          onChanged: (style) {
            if (style != null) {
              onChanged(config.copyWith(style: style));
            }
          },
        ),
      ],
    );
  }

  Widget _buildSwitchOptions(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      children: [
        SwitchListTile(
          title: Text(s.povGeneration_keepDialogue),
          subtitle: Text(s.povGeneration_keepDialogueHint),
          value: config.keepDialogue,
          onChanged: (value) {
            onChanged(config.copyWith(keepDialogue: value));
          },
        ),
        SwitchListTile(
          title: Text(s.povGeneration_addInnerThoughts),
          subtitle: Text(s.povGeneration_addInnerThoughtsHint),
          value: config.addInnerThoughts,
          onChanged: (value) {
            onChanged(config.copyWith(addInnerThoughts: value));
          },
        ),
        SwitchListTile(
          title: Text(s.povGeneration_expandObservations),
          subtitle: Text(s.povGeneration_expandObservationsHint),
          value: config.expandObservations,
          onChanged: (value) {
            onChanged(config.copyWith(expandObservations: value));
          },
        ),
        SwitchListTile(
          title: Text(s.povGeneration_useCharacterVoice),
          subtitle: Text(s.povGeneration_useCharacterVoiceHint),
          value: config.useCharacterVoice,
          onChanged: (value) {
            onChanged(config.copyWith(useCharacterVoice: value));
          },
        ),
      ],
    );
  }

  Widget _buildEmotionSlider(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.povGeneration_emotionalIntensity),
            Text('${(config.emotionalIntensity * 100).toInt()}%'),
          ],
        ),
        SizedBox(height: 8.h),
        Slider(
          value: config.emotionalIntensity,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          label: '${(config.emotionalIntensity * 100).toInt()}%',
          onChanged: (value) {
            onChanged(config.copyWith(emotionalIntensity: value));
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(s.povGeneration_restrained, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
            Text(s.povGeneration_intense, style: TextStyle(fontSize: 12.sp, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildTargetWordCount(BuildContext context) {
    final s = S.of(context)!;
    return TextFormField(
      initialValue: config.targetWordCount?.toString(),
      decoration: InputDecoration(
        labelText: s.povGeneration_targetWordCount,
        border: const OutlineInputBorder(),
        hintText: s.povGeneration_targetWordCountHint,
        suffixText: s.povGeneration_words,
      ),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final count = int.tryParse(value);
        onChanged(config.copyWith(targetWordCount: count));
      },
    );
  }

  Widget _buildCustomInstructions(BuildContext context) {
    final s = S.of(context)!;
    return TextFormField(
      initialValue: config.customInstructions,
      decoration: InputDecoration(
        labelText: s.povGeneration_customInstructions,
        border: const OutlineInputBorder(),
        hintText: s.povGeneration_customInstructionsHint,
      ),
      maxLines: 3,
      onChanged: (value) {
        onChanged(config.copyWith(customInstructions: value));
      },
    );
  }
}
