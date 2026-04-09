import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../app/theme.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/models/model_tier.dart' show AIFunction;

class AssistantPanel extends StatefulWidget {
  final String content;
  final void Function(String) onInsert;

  const AssistantPanel({
    super.key,
    required this.content,
    required this.onInsert,
  });

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _generatedText;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Quick actions — 2x2 grid
        Text(
          '快捷操作',
          style: theme.textTheme.titleSmall?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 10.h),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8.h,
          crossAxisSpacing: 8.w,
          childAspectRatio: 2.8,
          children: [
            _QuickAction(
              icon: Icons.auto_awesome_rounded,
              label: '续写',
              color: colorScheme.primary,
              onPressed: _generateContinuation,
            ),
            _QuickAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: '对白',
              color: colorScheme.secondary,
              onPressed: _generateDialogue,
            ),
            _QuickAction(
              icon: Icons.lightbulb_outline_rounded,
              label: '剧情灵感',
              color: colorScheme.tertiary,
              onPressed: _suggestPlot,
            ),
            _QuickAction(
              icon: Icons.psychology_alt_rounded,
              label: '角色模拟',
              color: colorScheme.primary,
              onPressed: _simulateCharacter,
            ),
          ],
        ),
        SizedBox(height: 16.h),

        // Custom prompt — compact
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: _promptController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '输入自定义提示词...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12.w),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isGenerating)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: colorScheme.primary),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _isGenerating ? null : _generateWithPrompt,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('生成'),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        textStyle: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Result — inline, no extra card boxing
        if (_generatedText != null) ...[
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  '生成结果',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: '重新生成',
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: _isGenerating ? null : _regenerate,
                visualDensity: VisualDensity.compact,
              ),
              FilledButton.tonalIcon(
                onPressed: () => widget.onInsert(_generatedText!),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('插入'),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: SelectableText(
              _generatedText!,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }

  void _generateContinuation() async {
    setState(() => _isGenerating = true);
    try {
      final aiService = Get.find<AIService>();
      final response = await aiService.generate(
        prompt: 'Continue the following story draft:\n\n${widget.content}',
        config: AIRequestConfig(
          function: AIFunction.continuation,
          userPrompt: 'Continue the following story draft:\n\n${widget.content}',
        ),
      );
      setState(() { _isGenerating = false; _generatedText = response.content; });
    } catch (e) {
      _showGenerationError(e);
    }
  }

  void _generateDialogue() async {
    setState(() => _isGenerating = true);
    try {
      final aiService = Get.find<AIService>();
      final response = await aiService.generate(
        prompt: 'Generate dialogue based on the current chapter context:\n\n${widget.content}',
        config: AIRequestConfig(
          function: AIFunction.dialogue,
          userPrompt: 'Generate dialogue based on the current chapter context:\n\n${widget.content}',
        ),
      );
      setState(() { _isGenerating = false; _generatedText = response.content; });
    } catch (e) {
      _showGenerationError(e);
    }
  }

  void _suggestPlot() async {
    setState(() => _isGenerating = true);
    try {
      final aiService = Get.find<AIService>();
      final response = await aiService.generate(
        prompt: 'Suggest 3 to 5 plot directions based on the current chapter:\n\n${widget.content}',
        config: AIRequestConfig(
          function: AIFunction.continuation,
          systemPrompt: 'You are a fiction development editor. Offer compact, practical plot directions.',
          userPrompt: 'Suggest 3 to 5 plot directions based on the current chapter:\n\n${widget.content}',
        ),
      );
      setState(() { _isGenerating = false; _generatedText = response.content; });
    } catch (e) {
      _showGenerationError(e);
    }
  }

  void _simulateCharacter() async {
    setState(() => _isGenerating = true);
    try {
      final aiService = Get.find<AIService>();
      final response = await aiService.generate(
        prompt: 'Simulate a likely character response based on the current chapter:\n\n${widget.content}',
        config: AIRequestConfig(
          function: AIFunction.characterSimulation,
          userPrompt: 'Simulate a likely character response based on the current chapter:\n\n${widget.content}',
        ),
      );
      setState(() { _isGenerating = false; _generatedText = response.content; });
    } catch (e) {
      _showGenerationError(e);
    }
  }

  void _generateWithPrompt() async {
    if (_promptController.text.trim().isEmpty) return;
    setState(() => _isGenerating = true);
    try {
      final aiService = Get.find<AIService>();
      final response = await aiService.generate(
        prompt: _promptController.text.trim(),
        config: AIRequestConfig(
          function: AIFunction.continuation,
          userPrompt: '${_promptController.text.trim()}\n\nCurrent chapter:\n${widget.content}',
        ),
      );
      setState(() { _isGenerating = false; _generatedText = response.content; });
    } catch (e) {
      _showGenerationError(e);
    }
  }

  void _regenerate() {
    if (_promptController.text.trim().isNotEmpty) {
      _generateWithPrompt();
    } else {
      _generateContinuation();
    }
  }

  void _showGenerationError(Object error) {
    setState(() => _isGenerating = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$error')),
      );
    }
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          child: Row(
            children: [
              Icon(icon, size: 18.sp, color: color),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
