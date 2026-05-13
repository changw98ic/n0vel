part of 'workbench_shell_page.dart';

class _CreationGuideCard extends StatelessWidget {
  const _CreationGuideCard({
    required this.currentStageIndex,
    required this.hasCharacters,
    required this.hasWorldNodes,
    required this.hasSceneSummary,
    required this.hasDraft,
    required this.hasSceneCharacterBinding,
    required this.hasSceneWorldReference,
    required this.hasRun,
    required this.onOpenCharacters,
    required this.onOpenWorldbuilding,
    required this.onOpenOutline,
  });

  final int currentStageIndex;
  final bool hasCharacters;
  final bool hasWorldNodes;
  final bool hasSceneSummary;
  final bool hasDraft;
  final bool hasSceneCharacterBinding;
  final bool hasSceneWorldReference;
  final bool hasRun;
  final VoidCallback onOpenCharacters;
  final VoidCallback onOpenWorldbuilding;
  final VoidCallback onOpenOutline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final steps = [
      const _GuideStep('作品设定', true),
      _GuideStep('人物 / 世界观', hasCharacters && hasWorldNodes),
      _GuideStep('大纲 / 章节目标', hasSceneSummary),
      _GuideStep('本章资料', hasSceneCharacterBinding && hasSceneWorldReference),
      _GuideStep('生成候选稿', hasDraft || hasRun),
      _GuideStep('改稿 / 定稿', hasRun),
    ];
    final currentStep = steps[currentStageIndex.clamp(0, steps.length - 1)];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: glassCardDecoration(context, color: palette.glassCard),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.flag_outlined,
            size: 18,
            color: workbenchAccentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('创作向导', style: theme.textTheme.titleSmall),
                Text(
                  '当前：${currentStep.label}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                for (var index = 0; index < steps.length; index += 1)
                  Icon(
                    steps[index].done
                        ? Icons.check_circle
                        : index == currentStageIndex
                        ? Icons.radio_button_checked
                        : Icons.circle_outlined,
                    size: 13,
                    color: steps[index].done
                        ? appSuccessColor
                        : index == currentStageIndex
                        ? workbenchAccentColor
                        : theme.disabledColor,
                    semanticLabel: steps[index].label,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: onOpenCharacters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('人物'),
              ),
              TextButton(
                onPressed: onOpenWorldbuilding,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('世界观'),
              ),
              TextButton(
                onPressed: onOpenOutline,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('资料'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep(this.label, this.done);

  final String label;
  final bool done;
}

class _WorkbenchDialogField extends StatelessWidget {
  const _WorkbenchDialogField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: glassCardDecoration(
        context,
        color: desktopPalette(context).glassCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ChapterListPanel extends StatelessWidget {
  const _ChapterListPanel({
    required this.scenes,
    required this.currentSceneId,
    required this.onSelectScene,
    required this.onCreateScene,
    required this.onCollapse,
  });

  final List<SceneRecord> scenes;
  final String currentSceneId;
  final ValueChanged<SceneRecord> onSelectScene;
  final VoidCallback onCreateScene;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDesignTokens.radiusXLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: DesktopLayoutTokens.workbenchChapterSidebarWidth,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: frostedSidebarDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '正文章节',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF243226),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCollapse,
                    child: const Icon(
                      Icons.keyboard_double_arrow_left,
                      size: 20,
                      color: Color(0xFF5F665E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: scenes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final scene = scenes[index];
                    final isActive = scene.id == currentSceneId;
                    return GestureDetector(
                      onTap: () => onSelectScene(scene),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFE8E2D6)
                              : const Color(0x00FBFAF6),
                          borderRadius: BorderRadius.circular(8),
                          border: isActive
                              ? Border.all(color: const Color(0xFFD8D2C6))
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scene.title,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isActive
                                    ? const Color(0xFF243226)
                                    : const Color(0xFF5F665E),
                                fontWeight: isActive ? FontWeight.w600 : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              scene.displayLocation,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isActive
                                    ? const Color(0xFF77736A)
                                    : const Color(0xFF8A867C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModePillButton extends StatelessWidget {
  const _ModePillButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF243226),
          borderRadius: BorderRadius.circular(9999),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '正文模式',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorToolbarIconButton extends StatefulWidget {
  const EditorToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isActive;

  @override
  State<EditorToolbarIconButton> createState() =>
      _EditorToolbarIconButtonState();
}

class _EditorToolbarIconButtonState extends State<EditorToolbarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive || _hovered
        ? const Color(0xFF243226)
        : const Color(0xFF5F665E);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Icon(widget.icon, size: 18, color: color),
      ),
    );
  }
}
