import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../app/state/app_workspace_store.dart';
import '../../../app/widgets/desktop_shell.dart';
import 'style_panel_ui_state.dart';
import 'widgets/style_questionnaire_widgets.dart';
import 'widgets/style_summary_pane.dart';

export 'style_panel_ui_state.dart';

class StylePanelPage extends StatefulWidget {
  const StylePanelPage({super.key, this.uiState = StylePanelUiState.ready});

  static const questionnaireModeButtonKey = ValueKey<String>(
    'style-panel-mode-questionnaire',
  );
  static const jsonModeButtonKey = ValueKey<String>('style-panel-mode-json');
  static const profileNameFieldKey = ValueKey<String>(
    'style-panel-profile-name',
  );
  static const jsonDraftFieldKey = ValueKey<String>('style-panel-json-draft');
  static const generateQuestionnaireButtonKey = ValueKey<String>(
    'style-panel-generate-questionnaire',
  );
  static const importJsonButtonKey = ValueKey<String>(
    'style-panel-import-json',
  );
  static const intensityIncreaseButtonKey = ValueKey<String>(
    'style-panel-intensity-increase',
  );
  static const intensityDecreaseButtonKey = ValueKey<String>(
    'style-panel-intensity-decrease',
  );
  static const bindProjectButtonKey = ValueKey<String>(
    'style-panel-bind-project',
  );
  static const bindSceneButtonKey = ValueKey<String>('style-panel-bind-scene');

  final StylePanelUiState uiState;

  @override
  State<StylePanelPage> createState() => _StylePanelPageState();
}

class _StylePanelPageState extends State<StylePanelPage> {
  bool _isDrawerOpen = false;
  late final TextEditingController _jsonDraftController;
  bool _jsonControllerReady = false;

  @override
  void initState() {
    super.initState();
    _jsonDraftController = TextEditingController();
  }

  @override
  void dispose() {
    _jsonDraftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = desktopPalette(context);
    final store = AppWorkspaceScope.of(context);
    final effectiveUiState = _effectiveUiState(store);
    final draft = store.styleQuestionnaireDraft;
    if (!_jsonControllerReady) {
      _jsonDraftController.text = store.styleJsonDraft;
      _jsonDraftController.addListener(() {
        if (_jsonDraftController.text !=
            AppWorkspaceScope.of(context).styleJsonDraft) {
          AppWorkspaceScope.of(
            context,
          ).setStyleJsonDraft(_jsonDraftController.text);
        }
      });
      _jsonControllerReady = true;
    } else if (_jsonDraftController.text != store.styleJsonDraft) {
      _jsonDraftController.value = _jsonDraftController.value.copyWith(
        text: store.styleJsonDraft,
        selection: TextSelection.collapsed(offset: store.styleJsonDraft.length),
      );
    }

    final inputPanel = Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('风格输入', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              StyleModeButton(
                buttonKey: StylePanelPage.questionnaireModeButtonKey,
                label: '问卷',
                selected:
                    store.styleInputMode ==
                    StyleInputMode.questionnaire,
                onPressed: () => store.setStyleInputMode(
                  StyleInputMode.questionnaire,
                ),
              ),
              StyleModeButton(
                buttonKey: StylePanelPage.jsonModeButtonKey,
                label: 'JSON',
                selected: store.styleInputMode == StyleInputMode.json,
                onPressed: () =>
                    store.setStyleInputMode(StyleInputMode.json),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StyleModeFramingCard(
            title: store.styleInputMode == StyleInputMode.questionnaire
                ? '问卷输入'
                : 'JSON 草稿',
            message:
                store.styleInputMode == StyleInputMode.questionnaire
                ? '优先补全问卷字段，再生成当前项目的风格摘要。'
                : '可直接粘贴或导入 StyleProfile JSON，导入后会保留字段校验结果。',
          ),
          const SizedBox(height: 16),
          if (store.styleInputMode == StyleInputMode.questionnaire) ...[
            StyleQuestionnaireTextField(
              fieldKey: StylePanelPage.profileNameFieldKey,
              label: '风格名称',
              initialValue: draft['profile_name']?.toString() ?? '',
              onChanged: (value) => store.updateStyleQuestionnaireField(
                'profile_name',
                value,
              ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireChoiceGroup(
              label: '叙事视角',
              currentValue: draft['pov_mode']?.toString() ?? '',
              values: const {
                'first_person_limited': '第一人称受限',
                'third_person_limited': '第三人称限知',
                'third_person_multi': '第三人称多视角',
              },
              onSelected: (value) => store
                  .updateStyleQuestionnaireField('pov_mode', value),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireChoiceGroup(
              label: '对白比例',
              currentValue: draft['dialogue_ratio']?.toString() ?? '',
              values: const {'low': '低', 'medium': '中', 'high': '高'},
              onSelected: (value) =>
                  store.updateStyleQuestionnaireField(
                    'dialogue_ratio',
                    value,
                  ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireChoiceGroup(
              label: '句长倾向',
              currentValue:
                  draft['sentence_length_preference']?.toString() ?? '',
              values: const {
                'short': '短句',
                'short_medium': '短中句',
                'balanced': '均衡',
                'medium_long': '中长句',
              },
              onSelected: (value) =>
                  store.updateStyleQuestionnaireField(
                    'sentence_length_preference',
                    value,
                  ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireChoiceGroup(
              label: '节奏轮廓',
              currentValue: draft['rhythm_profile']?.toString() ?? '',
              values: const {
                'tight': '紧凑',
                'balanced': '均衡',
                'slow_burn': '慢燃',
              },
              onSelected: (value) =>
                  store.updateStyleQuestionnaireField(
                    'rhythm_profile',
                    value,
                  ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireChoiceGroup(
              label: '描写密度',
              currentValue:
                  draft['description_density']?.toString() ?? '',
              values: const {'low': '低', 'medium': '中', 'high': '高'},
              onSelected: (value) =>
                  store.updateStyleQuestionnaireField(
                    'description_density',
                    value,
                  ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireChoiceGroup(
              label: '情绪强度',
              currentValue:
                  draft['emotional_intensity']?.toString() ?? '',
              values: const {
                'low': '低',
                'medium': '中',
                'medium_high': '中高',
                'high': '高',
              },
              onSelected: (value) =>
                  store.updateStyleQuestionnaireField(
                    'emotional_intensity',
                    value,
                  ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireTagGroup(
              label: '主要体裁',
              selectedValues: styleStringListFromRaw(
                draft['genre_tags'],
              ),
              values: const ['悬疑', '现实', '都市', '成长'],
              onToggle: (value) => store.toggleStyleQuestionnaireTag(
                'genre_tags',
                value,
              ),
            ),
            const SizedBox(height: 12),
            StyleQuestionnaireTagGroup(
              label: '禁忌表达',
              selectedValues: styleStringListFromRaw(
                draft['taboo_patterns'],
              ),
              values: const ['过度抒情', '全知解释', '空泛形容词'],
              onToggle: (value) => store.toggleStyleQuestionnaireTag(
                'taboo_patterns',
                value,
              ),
            ),
          ] else ...[
            Text(
              'style_profile.schema.json',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: StylePanelPage.importJsonButtonKey,
                onPressed: store.importStyleFromJsonDraft,
                child: const Text('选择 JSON 文件'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: StylePanelPage.jsonDraftFieldKey,
              controller: _jsonDraftController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'StyleProfile JSON',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ],
      ),
    );

    final summaryPanel = Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('风格摘要', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: StyleSummaryPane(
              uiState: effectiveUiState,
              workflowMessage: store.styleWorkflowMessage,
              warningMessages: store.styleWarningMessages,
              profile: store.selectedStyleProfile,
            ),
          ),
        ],
      ),
    );

    final bindingPanel = Container(
      decoration: appPanelDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('绑定与强度', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _StrengthStepper(
                buttonKey: StylePanelPage.intensityDecreaseButtonKey,
                icon: Icons.remove,
                onTap: store.decreaseStyleIntensity,
              ),
              const SizedBox(width: 8),
              Text(
                '${store.styleIntensity}x',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              _StrengthStepper(
                buttonKey: StylePanelPage.intensityIncreaseButtonKey,
                icon: Icons.add,
                onTap: store.increaseStyleIntensity,
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: StylePanelPage.bindProjectButtonKey,
            onPressed: store.bindStyleToProject,
            child: const Text('绑定到项目'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: StylePanelPage.bindSceneButtonKey,
            onPressed: store.bindStyleToScene,
            child: const Text('仅绑定当前场景'),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: appPanelDecoration(
              context,
              color: palette.elevated,
            ),
            child: Text(
              store.styleBindingFeedback,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );

    return DesktopShellFrame(
      header: DesktopHeaderBar(
        title: '风格面板',
        subtitle: '以问卷为主，支持 JSON 导入的风格配置',
        showBackButton: true,
        actions: [
          FilledButton(
            key: StylePanelPage.generateQuestionnaireButtonKey,
            onPressed: store.generateStyleProfileFromQuestionnaire,
            child: const Text('生成风格配置'),
          ),
        ],
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
            width: DesktopLayoutTokens.styleInputWidth,
            child: inputPanel,
          ),
          const SizedBox(width: 16),
          Expanded(child: summaryPanel),
          const SizedBox(width: 16),
          SizedBox(
            width: DesktopLayoutTokens.styleSideWidth,
            child: bindingPanel,
          ),
        ],
      ),
      statusBar: DesktopStatusStrip(
        leftText: _footerMessage(effectiveUiState),
        rightText: '规范 v1.0',
      ),
    );
  }

  StylePanelUiState _effectiveUiState(AppWorkspaceStore store) {
    if (widget.uiState != StylePanelUiState.ready) {
      return widget.uiState;
    }
    return switch (store.styleWorkflowState) {
      StyleWorkflowState.ready => StylePanelUiState.ready,
      StyleWorkflowState.empty => StylePanelUiState.empty,
      StyleWorkflowState.jsonError => StylePanelUiState.jsonError,
      StyleWorkflowState.unsupportedVersion =>
        StylePanelUiState.unsupportedVersion,
      StyleWorkflowState.unknownFieldsIgnored =>
        StylePanelUiState.unknownFieldsIgnored,
      StyleWorkflowState.missingRequiredFields =>
        StylePanelUiState.missingRequiredFields,
      StyleWorkflowState.validationFailed => StylePanelUiState.validationFailed,
      StyleWorkflowState.maxProfilesReached =>
        StylePanelUiState.maxProfilesReached,
      StyleWorkflowState.sceneOverrideNotice =>
        StylePanelUiState.sceneOverrideNotice,
    };
  }

  String _footerMessage(StylePanelUiState state) {
    switch (state) {
      case StylePanelUiState.ready:
        return '校验就绪 · 问卷已完成 · 支持 JSON Schema v1.0';
      case StylePanelUiState.empty:
        return '尚未创建风格配置。';
      case StylePanelUiState.jsonError:
        return '配置文件校验失败，请检查字段格式。';
      case StylePanelUiState.unsupportedVersion:
        return '仅支持 1.0 版配置。';
      case StylePanelUiState.unknownFieldsIgnored:
        return '检测到未知字段，已忽略并继续生成。';
      case StylePanelUiState.missingRequiredFields:
        return '缺少必填字段，当前不会生成风格配置。';
      case StylePanelUiState.validationFailed:
        return '风格校验失败，请调整后重试。';
      case StylePanelUiState.maxProfilesReached:
        return '同一项目最多保留 3 个风格配置。';
      case StylePanelUiState.sceneOverrideNotice:
        return '当前场景级绑定优先于项目级默认风格。';
    }
  }

  List<DesktopMenuItemData> _menuItems(BuildContext context) {
    return [
      DesktopMenuItemData(
        label: '书架',
        onTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
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

class _StrengthStepper extends StatelessWidget {
  const _StrengthStepper({
    required this.buttonKey,
    required this.icon,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: appPanelDecoration(
          context,
          color: desktopPalette(context).elevated,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: desktopPalette(context).primary),
        ),
      ),
    );
  }
}
