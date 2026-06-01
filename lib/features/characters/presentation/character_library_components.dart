import 'package:flutter/material.dart';

import '../../../app/theme/app_design_tokens.dart';
import '../../../app/widgets/desktop_shell.dart';

class CharacterListButton extends StatelessWidget {
  const CharacterListButton({
    this.buttonKey,
    required this.label,
    this.selected = false,
    required this.onPressed,
    super.key,
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

class CharacterInfoBlock extends StatelessWidget {
  const CharacterInfoBlock({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppDesignTokens.space4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class CharacterEditableTextField extends StatelessWidget {
  const CharacterEditableTextField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
    super.key,
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

class CharacterStateCard extends StatelessWidget {
  const CharacterStateCard({
    required this.title,
    required this.message,
    required this.accent,
    super.key,
  });

  final String title;
  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignTokens.space12),
      decoration: BoxDecoration(
        color: desktopPalette(context).subtle,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMedium),
        border: Border.all(color: desktopPalette(context).borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space8),
          Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class CharacterCallToActionState extends StatelessWidget {
  const CharacterCallToActionState({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    super.key,
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
          const SizedBox(height: AppDesignTokens.space8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDesignTokens.space16),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class CharacterCenteredPanelState extends StatelessWidget {
  const CharacterCenteredPanelState({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: appPanelDecoration(
        context,
        color: desktopPalette(context).subtle,
      ),
      padding: const EdgeInsets.all(AppDesignTokens.space24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppDesignTokens.space8),
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

class CharacterDeleteOverlay extends StatelessWidget {
  const CharacterDeleteOverlay({
    required this.characterName,
    required this.sceneLabel,
    this.onCancel,
    this.onForceDelete,
    super.key,
  });

  final String characterName;
  final String sceneLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onForceDelete;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99F6F0E6),
      child: Center(
        child: Container(
          width: 728,
          padding: const EdgeInsets.all(AppDesignTokens.space20),
          decoration: BoxDecoration(
            color: desktopPalette(context).surface,
            borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
            border: Border.all(color: desktopPalette(context).borderStrong),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('删除被引用角色？', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppDesignTokens.space16),
              Text(
                '角色"$characterName"仍被 $sceneLabel 引用。继续删除会导致相关场景失去角色绑定。\n\n建议先回到工作台或角色库移除引用，再执行删除。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDesignTokens.space16),
              CharacterInfoBlock(title: '引用场景', message: sceneLabel),
              const SizedBox(height: AppDesignTokens.space16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: onCancel, child: const Text('取消')),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: onForceDelete, child: const Text('确认删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
