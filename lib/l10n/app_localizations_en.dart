// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get actions => 'Actions';

  @override
  String get aiConfig_advancedParams => 'Advanced Parameters';

  @override
  String get aiConfig_apiEndpoint => 'API Endpoint';

  @override
  String get aiConfig_apiKey => 'API Key';

  @override
  String get aiConfig_byFunctionStats => 'By Function';

  @override
  String get aiConfig_byModelStats => 'By Model';

  @override
  String get aiConfig_cancel => 'Cancel';

  @override
  String get aiConfig_configSaved => 'Configuration saved';

  @override
  String get aiConfig_connectionFailed =>
      'Connection failed, please check your configuration';

  @override
  String get aiConfig_connectionSuccess => 'Connection successful!';

  @override
  String get aiConfig_copy => 'Copy';

  @override
  String get aiConfig_description => 'Description';

  @override
  String get aiConfig_descriptionHint =>
      'Describe the purpose of this template';

  @override
  String get aiConfig_edit => 'Edit';

  @override
  String get aiConfig_error_validation_systemPrompt =>
      'Please enter a System Prompt';

  @override
  String get aiConfig_error_validation_templateId =>
      'Please enter a Template ID';

  @override
  String get aiConfig_error_validation_templateName =>
      'Please enter a template name';

  @override
  String get aiConfig_icon => 'Icon';

  @override
  String get aiConfig_icon_chat => 'Chat';

  @override
  String get aiConfig_icon_check => 'Check';

  @override
  String get aiConfig_icon_edit => 'Edit';

  @override
  String get aiConfig_icon_extract => 'Extract';

  @override
  String get aiConfig_icon_person => 'Character';

  @override
  String get aiConfig_icon_review => 'Review';

  @override
  String get aiConfig_icon_summarize => 'Summarize';

  @override
  String get aiConfig_icon_timeline => 'Timeline';

  @override
  String get aiConfig_icon_visibility => 'Perspective';

  @override
  String get aiConfig_icon_warning => 'Warning';

  @override
  String get aiConfig_loadFailed => 'Load failed';

  @override
  String get aiConfig_modelName => 'Model Name';

  @override
  String get aiConfig_new => 'New';

  @override
  String get aiConfig_newPromptTemplate => 'New Prompt Template';

  @override
  String get aiConfig_providerType => 'Provider Type';

  @override
  String get aiConfig_provider_anthropic => 'Claude';

  @override
  String get aiConfig_provider_azure => 'Azure OpenAI';

  @override
  String get aiConfig_provider_custom => 'Custom';

  @override
  String get aiConfig_provider_ollama => 'Ollama (Local)';

  @override
  String get aiConfig_provider_openai => 'OpenAI';

  @override
  String get aiConfig_save => 'Save';

  @override
  String get aiConfig_saveConfig => 'Save Configuration';

  @override
  String get aiConfig_searchPrompts => 'Search prompt templates...';

  @override
  String get aiConfig_systemPrompt => 'System Prompt';

  @override
  String get aiConfig_systemPromptHint => 'System prompt for the AI';

  @override
  String get aiConfig_systemPromptLabel => 'System Prompt';

  @override
  String get aiConfig_tab_functionMapping => 'Function Mapping';

  @override
  String get aiConfig_tab_modelConfig => 'Model Configuration';

  @override
  String get aiConfig_tab_promptManager => 'Prompt Manager';

  @override
  String get aiConfig_tab_usageStats => 'Usage Statistics';

  @override
  String get aiConfig_templateId => 'Template ID';

  @override
  String get aiConfig_templateIdHint => 'e.g.: custom_continuation';

  @override
  String get aiConfig_templateName => 'Template Name';

  @override
  String get aiConfig_templateNameHint => 'e.g.: Custom Continuation';

  @override
  String get aiConfig_templateSaved => 'Template saved successfully';

  @override
  String get aiConfig_test => 'Test';

  @override
  String get aiConfig_testFailed => 'Test failed';

  @override
  String get aiConfig_testingConnection => 'Testing connection...';

  @override
  String get aiConfig_tierConfig_description =>
      'Configure three tiers of AI models. The system automatically selects the appropriate model based on task complexity.';

  @override
  String get aiConfig_timesCount => 'times';

  @override
  String get aiConfig_title => 'AI Configuration';

  @override
  String get aiConfig_todayRequests => 'Today\'s Requests';

  @override
  String get aiConfig_todayTokens => 'Today\'s Tokens';

  @override
  String get aiConfig_tokens => 'tokens';

  @override
  String get aiConfig_userPromptTemplate => 'User Prompt Template (Optional)';

  @override
  String aiConfig_userPromptTemplateHint(Object variable) {
    return 'User prompt template, use $variable placeholders';
  }

  @override
  String get aiConfig_weekRequests => 'This Week\'s Requests';

  @override
  String get aiConfig_weekTokens => 'This Week\'s Tokens';

  @override
  String get aiDetectionConfig_aiVocabularyHint =>
      'Detect commonly used AI vocabulary';

  @override
  String get aiDetectionConfig_autoAnalyzeHint =>
      'Automatically run AI detection when a chapter is saved';

  @override
  String get aiDetectionConfig_autoAnalyzeOnSave => 'Auto-analyze on save';

  @override
  String get aiDetectionConfig_dash => 'Dash ——';

  @override
  String get aiDetectionConfig_detectionItems => 'Detection Items';

  @override
  String get aiDetectionConfig_ellipsis => 'Ellipsis ……';

  @override
  String get aiDetectionConfig_exclamation => 'Exclamation mark !';

  @override
  String get aiDetectionConfig_forbiddenPatternsHint =>
      'Detect commonly used AI sentence patterns';

  @override
  String get aiDetectionConfig_perspectiveCheckHint =>
      'Detect omniscient POV and other issues';

  @override
  String get aiDetectionConfig_punctuationAbuseHint =>
      'Detect punctuation usage frequency';

  @override
  String get aiDetectionConfig_punctuationLimits =>
      'Punctuation Limits (per 1000 chars)';

  @override
  String get aiDetectionConfig_saved => 'Configuration saved';

  @override
  String get aiDetectionConfig_standardizedCheckHint =>
      'Detect list-style and repetitive patterns';

  @override
  String get aiDetectionConfig_times => 'times';

  @override
  String get aiDetectionConfig_title => 'AI Detection Settings';

  @override
  String get aiDetection_aiVocabulary => 'AI Vocabulary';

  @override
  String get aiDetection_analyzing => 'Analysis failed';

  @override
  String get aiDetection_apply => 'Apply';

  @override
  String get aiDetection_detectionSettings => 'Detection Settings';

  @override
  String get aiDetection_enableAiVocabulary =>
      'AI High-frequency Word Detection';

  @override
  String get aiDetection_enableForbiddenPatterns =>
      'Forbidden Pattern Detection';

  @override
  String get aiDetection_enablePunctuationAbuse =>
      'Punctuation Abuse Detection';

  @override
  String get aiDetection_forbiddenPatterns => 'Forbidden Patterns';

  @override
  String aiDetection_foundIssues(Object count) {
    return 'Found $count issues';
  }

  @override
  String aiDetection_issueDensity(Object density) {
    return 'Issue density $density / 1000 chars';
  }

  @override
  String get aiDetection_issueDistribution => 'Issue Distribution';

  @override
  String get aiDetection_noIssues => 'No significant issues found';

  @override
  String get aiDetection_noProblemsFound => 'No problems found';

  @override
  String get aiDetection_other => 'Other';

  @override
  String get aiDetection_overview => 'Overview';

  @override
  String get aiDetection_punctuationAbuse => 'Punctuation Abuse';

  @override
  String aiDetection_suggestion(Object suggestion) {
    return 'Suggestion: $suggestion';
  }

  @override
  String get aiDetection_title => 'AI Quality Detection';

  @override
  String get all => '全部';

  @override
  String get appName => '写作助手';

  @override
  String get archive => '归档';

  @override
  String get archived => '已归档';

  @override
  String get assistantPanel_characterSimulation => '角色模拟';

  @override
  String get assistantPanel_contextInfo => '当前章节内容会自动作为上下文一并发送。';

  @override
  String get assistantPanel_continuation => '续写';

  @override
  String get assistantPanel_customPrompt => '自定义提示词';

  @override
  String get assistantPanel_customPromptHint => '例如：让它检查节奏、补一个对白版本，或给出结构调整建议。';

  @override
  String get assistantPanel_customPromptSubtitle => '在当前章节上下文之上补充你的具体要求。';

  @override
  String get assistantPanel_dialogue => '对白';

  @override
  String get assistantPanel_generate => '生成';

  @override
  String get assistantPanel_generating => '生成中';

  @override
  String get assistantPanel_generatingSubtitle => '助手正在准备结果草稿。';

  @override
  String assistantPanel_generationFailed(Object error) {
    return '生成失败：$error';
  }

  @override
  String get assistantPanel_insertText => '插入正文';

  @override
  String get assistantPanel_plotInspiration => '剧情灵感';

  @override
  String get assistantPanel_regenerate => '重新生成';

  @override
  String get assistantPanel_result => '生成结果';

  @override
  String get assistantPanel_resultSubtitle => '先检查内容，再插入真正有用的部分。';

  @override
  String get assistantPanel_subtitle => '用几个短指令快速续写、补对白或发散思路，不用离开编辑器。';

  @override
  String get assistantPanel_title => 'AI 操作';

  @override
  String get back => '返回';

  @override
  String get basicInfo => '基本信息';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get configSaved => '配置已保存';

  @override
  String get confirm => '确认';

  @override
  String get content => '内容';

  @override
  String get copied => '已复制到剪贴板';

  @override
  String get createTime => '创建时间';

  @override
  String get darkMode => '深色模式';

  @override
  String get delete => '删除';

  @override
  String get deleteConfirm => '确认删除？';

  @override
  String get deleteConfirmDesc => '此操作不可撤销';

  @override
  String get description => '描述';

  @override
  String get deselectAll => '取消全选';

  @override
  String get disable => '禁用';

  @override
  String get disabled => '已禁用';

  @override
  String get edit => '编辑';

  @override
  String get editor_ai => 'AI';

  @override
  String get editor_aiOperations => 'AI 操作';

  @override
  String get editor_aiOperationsDesc => '用几个短指令快速续写、补对白或发散思路，不用离开编辑器。';

  @override
  String get editor_aiStyle => 'AI 痕迹';

  @override
  String get editor_apply => '应用';

  @override
  String get editor_applySegment => '已应用分段结果';

  @override
  String get editor_applySegmentResult => '已应用分段结果';

  @override
  String get editor_assistantPanel => '辅助面板';

  @override
  String get editor_autoSaveEnabled => '已开启自动保存';

  @override
  String get editor_autoSaveSuccess => '草稿已自动保存';

  @override
  String get editor_autoSaved => '草稿已自动保存';

  @override
  String get editor_bold => '加粗';

  @override
  String get editor_cancel => '取消';

  @override
  String get editor_chapterTitleHint => '章节标题';

  @override
  String get editor_characterAccessDescription => '这里预留给写作时快速查看角色资料。';

  @override
  String get editor_characterAccessNotAvailable => '角色快捷入口暂未接入';

  @override
  String get editor_characterOOC => '角色 OOC';

  @override
  String get editor_characterQuickAccess => '角色快捷入口暂未接入';

  @override
  String get editor_characterQuickAccessDesc => '这里预留给写作时快速查看角色资料。';

  @override
  String get editor_characterSimulation => '角色模拟';

  @override
  String get editor_characters => '角色';

  @override
  String get editor_close => '关闭';

  @override
  String get editor_consistency => '一致性';

  @override
  String get editor_contentArea => '正文编辑区';

  @override
  String get editor_continue => '继续';

  @override
  String get editor_continueWriting => '续写';

  @override
  String get editor_copiedToClipboard => '已复制到剪贴板';

  @override
  String get editor_copy => '复制';

  @override
  String get editor_customPrompt => '自定义提示词';

  @override
  String get editor_customPromptDesc => '在当前章节上下文之上补充你的具体要求。';

  @override
  String get editor_dialogue => '对话';

  @override
  String get editor_dialogueLabel => '对白';

  @override
  String get editor_dimension_aiStyle => 'AI 痕迹';

  @override
  String get editor_dimension_characterOOC => '角色 OOC';

  @override
  String get editor_dimension_consistency => '一致性';

  @override
  String get editor_dimension_pacing => '节奏';

  @override
  String get editor_dimension_plotLogic => '剧情逻辑';

  @override
  String get editor_dimension_spelling => '错别字';

  @override
  String get editor_editTools => '编辑工具';

  @override
  String get editor_exportChapter => '导出章节';

  @override
  String get editor_exportChapterTitle => '导出章节';

  @override
  String editor_exportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get editor_exportFormatMarkdown => 'Markdown';

  @override
  String get editor_exportFormatText => '纯文本';

  @override
  String editor_exportPreview(Object format) {
    return '导出预览（$format）';
  }

  @override
  String get editor_find => '查找';

  @override
  String get editor_focusedMode => '专注于起草、修订和 AI 辅助迭代的编辑模式。';

  @override
  String get editor_generate => '生成';

  @override
  String get editor_generating => '生成中';

  @override
  String get editor_generatingDesc => '助手正在准备结果草稿。';

  @override
  String editor_generationFailed(Object error) {
    return '生成失败：$error';
  }

  @override
  String get editor_generationResult => '生成结果';

  @override
  String get editor_generationResultDesc => '先检查内容，再插入真正有用的部分。';

  @override
  String get editor_hideSidebar => '隐藏侧边栏';

  @override
  String get editor_insertContent => '插入正文';

  @override
  String get editor_italic => '斜体';

  @override
  String get editor_mainEditArea => '正文编辑区';

  @override
  String get editor_pacing => '节奏';

  @override
  String editor_paragraphs(Object count) {
    return '$count 段';
  }

  @override
  String get editor_plotInspiration => '剧情灵感';

  @override
  String get editor_plotLogic => '剧情逻辑';

  @override
  String get editor_polish => '润色';

  @override
  String get editor_polishChapter => '润色章节';

  @override
  String get editor_promptContext => '当前章节内容会自动作为上下文一并发送。';

  @override
  String get editor_promptHint => '例如：让它检查节奏、补一个对白版本，或给出结构调整建议。';

  @override
  String editor_rating(Object score) {
    return '评分 $score';
  }

  @override
  String editor_readingTime(Object minutes) {
    return '约 $minutes 分钟阅读';
  }

  @override
  String get editor_redo => '重做';

  @override
  String get editor_regenerate => '重新生成';

  @override
  String get editor_rename => '重命名';

  @override
  String get editor_renameChapter => '重命名章节';

  @override
  String get editor_renameTitle => '重命名章节';

  @override
  String get editor_replace => '替换';

  @override
  String get editor_reviewChapter => '审阅章节';

  @override
  String editor_reviewChapterConfirm(Object count, Object title) {
    return '要为“$title”执行 $count 个审阅维度吗？你可以在审阅中心查看进度。';
  }

  @override
  String get editor_reviewChapterTitle => '审阅章节';

  @override
  String editor_reviewChapterTitleLabel(Object title) {
    return '审阅《$title》';
  }

  @override
  String editor_reviewConfirmation(Object count, Object title) {
    return '要为“$title”执行 $count 个审阅维度吗？你可以在审阅中心查看进度。';
  }

  @override
  String get editor_reviewDescription => '选择要执行的审阅维度。';

  @override
  String get editor_reviewStarted => '已启动审阅流程';

  @override
  String editor_reviewTitle(Object title) {
    return '审阅《$title》';
  }

  @override
  String get editor_save => '保存';

  @override
  String get editor_saveNow => '立即保存';

  @override
  String editor_savedAt(Object time) {
    return '已保存 $time';
  }

  @override
  String editor_savedTime(Object time) {
    return '已保存 $time';
  }

  @override
  String editor_score(Object score) {
    return '评分 $score';
  }

  @override
  String editor_segmented(Object chars, Object type) {
    return '$chars chars • $type';
  }

  @override
  String get editor_selectReviewDimensions => '选择要执行的审阅维度。';

  @override
  String get editor_shortcutHint => '快捷键：Ctrl+S 保存，Ctrl+Z 撤销';

  @override
  String get editor_showSidebar => '显示侧边栏';

  @override
  String get editor_sidePanel => '辅助面板';

  @override
  String get editor_smartSegment => '智能分段';

  @override
  String get editor_smartSegmentPreview => '智能分段预览';

  @override
  String get editor_spelling => '错别字';

  @override
  String get editor_startReview => '开始审阅';

  @override
  String get editor_startWriting => '开始写作...';

  @override
  String get editor_statistics => '统计';

  @override
  String get editor_subtitle => '专注于起草、修订和 AI 辅助迭代的编辑模式。';

  @override
  String get editor_tab_ai => 'AI';

  @override
  String get editor_tab_characters => '角色';

  @override
  String get editor_tab_statistics => '统计';

  @override
  String get editor_toolbar_bold => '加粗';

  @override
  String get editor_toolbar_boldTooltip => '插入加粗标记';

  @override
  String get editor_toolbar_dialogue => '对话';

  @override
  String get editor_toolbar_dialogueTooltip => '插入对话引号';

  @override
  String get editor_toolbar_find => '查找';

  @override
  String get editor_toolbar_findTooltip => '在章节内查找';

  @override
  String get editor_toolbar_italic => '斜体';

  @override
  String get editor_toolbar_italicTooltip => '插入斜体标记';

  @override
  String get editor_toolbar_polish => '润色';

  @override
  String get editor_toolbar_polishTooltip => '整理并规范文本格式';

  @override
  String get editor_toolbar_redo => '重做';

  @override
  String get editor_toolbar_redoTooltip => '恢复刚才撤销的修改';

  @override
  String get editor_toolbar_replace => '替换';

  @override
  String get editor_toolbar_replaceTooltip => '替换文本';

  @override
  String get editor_toolbar_shortcuts => '快捷键：Ctrl+S 保存，Ctrl+Z 撤销';

  @override
  String get editor_toolbar_title => '编辑工具';

  @override
  String get editor_toolbar_undo => '撤销';

  @override
  String get editor_toolbar_undoTooltip => '撤销上一步修改';

  @override
  String get editor_undo => '撤销';

  @override
  String editor_words(Object count) {
    return '$count 字';
  }

  @override
  String get enable => '启用';

  @override
  String get enabled => '已启用';

  @override
  String get export => '导出';

  @override
  String get finish => '完成';

  @override
  String get import => '导入';

  @override
  String get language => '语言';

  @override
  String get lightMode => '浅色模式';

  @override
  String get loadFailed => '加载失败';

  @override
  String get loading => '加载中...';

  @override
  String get name => '名称';

  @override
  String get next => '下一步';

  @override
  String get no => '否';

  @override
  String get noData => '暂无数据';

  @override
  String get none => '无';

  @override
  String get operationFailed => '操作失败';

  @override
  String get operationSuccess => '操作成功';

  @override
  String get other => '其他';

  @override
  String get pinned => '已置顶';

  @override
  String get povGeneration_addInnerThoughts => '添加内心独白';

  @override
  String get povGeneration_addInnerThoughtsHint => '根据角色性格添加内心活动';

  @override
  String get povGeneration_chapterContentEmpty => '章节内容为空';

  @override
  String get povGeneration_characterNotFound => '角色不存在';

  @override
  String povGeneration_createdNewChapter(Object title) {
    return '已创建新章节：$title';
  }

  @override
  String get povGeneration_customInstructions => '额外指令（可选）';

  @override
  String get povGeneration_customInstructionsHint => '输入特殊要求或注意事项';

  @override
  String get povGeneration_emotionalIntensity => '情感强度';

  @override
  String get povGeneration_expandObservations => '扩展观察细节';

  @override
  String get povGeneration_expandObservationsHint => '扩展角色观察到的细节描写';

  @override
  String get povGeneration_generating => '生成中...';

  @override
  String get povGeneration_generationConfig => '生成配置';

  @override
  String get povGeneration_generationFailed => '生成失败';

  @override
  String get povGeneration_generationMode => '生成模式';

  @override
  String get povGeneration_help => '使用帮助';

  @override
  String get povGeneration_help_description => '配角视角生成功能可以帮助您从配角的视角重写章节内容。';

  @override
  String get povGeneration_help_mode1 => '• 完整重写：从角色视角完整重写整章';

  @override
  String get povGeneration_help_mode2 => '• 补充内容：在原文基础上补充视角细节';

  @override
  String get povGeneration_help_mode3 => '• 视角摘要：生成角色视角的章节摘要';

  @override
  String get povGeneration_help_mode4 => '• 场景片段：只生成特定场景的视角内容';

  @override
  String get povGeneration_help_modesTitle => '生成模式说明：';

  @override
  String get povGeneration_help_step1 => '1. 选择要重写的章节';

  @override
  String get povGeneration_help_step2 => '2. 选择视角角色（配角）';

  @override
  String get povGeneration_help_step3 => '3. 配置生成参数';

  @override
  String get povGeneration_help_step4 => '4. 点击“开始生成”';

  @override
  String get povGeneration_help_steps => '使用步骤：';

  @override
  String get povGeneration_help_title => '使用帮助';

  @override
  String get povGeneration_history => '历史记录';

  @override
  String get povGeneration_history_close => '关闭';

  @override
  String get povGeneration_history_noHistory => '暂无历史记录';

  @override
  String get povGeneration_history_task => '任务';

  @override
  String get povGeneration_history_title => '历史记录';

  @override
  String get povGeneration_intense => '强烈';

  @override
  String get povGeneration_keepDialogue => '保留对话';

  @override
  String get povGeneration_keepDialogueHint => '保留原文中的对话内容';

  @override
  String get povGeneration_loadFailed => '加载失败';

  @override
  String get povGeneration_newChapter => '• 新建章节：创建一个新章节保存POV内容';

  @override
  String get povGeneration_newChapterButton => '新建章节';

  @override
  String get povGeneration_noSupportingCharacters => '暂无配角，请先在角色设定中创建配角';

  @override
  String get povGeneration_outputStyle => '输出风格';

  @override
  String get povGeneration_placeholder => '选择章节和角色后开始生成';

  @override
  String get povGeneration_pleaseCreateVolume => '请先创建卷';

  @override
  String get povGeneration_pleaseSelectChapter => '请先选择章节';

  @override
  String get povGeneration_povChapterTitle => 'POV视角章节';

  @override
  String get povGeneration_quickTemplates => '快速模板';

  @override
  String get povGeneration_restrained => '克制';

  @override
  String get povGeneration_saveAsDraft => '• 保存为草稿：保存到当前章节的草稿';

  @override
  String get povGeneration_saveAsDraftButton => '保存为草稿';

  @override
  String get povGeneration_savePOVResult => '保存POV结果';

  @override
  String get povGeneration_savedToDraft => '已保存到草稿';

  @override
  String get povGeneration_selectChapter => '选择章节';

  @override
  String get povGeneration_selectChapterHint => '请选择章节';

  @override
  String get povGeneration_selectCharacter => '选择角色';

  @override
  String get povGeneration_selectCharacterHint => '请选择配角';

  @override
  String get povGeneration_selectSaveMethod => '请选择保存方式：';

  @override
  String get povGeneration_startGeneration => '开始生成';

  @override
  String get povGeneration_targetWordCount => '目标字数（可选）';

  @override
  String get povGeneration_targetWordCountHint => '不填则自动估算';

  @override
  String get povGeneration_title => '配角视角生成';

  @override
  String get povGeneration_useCharacterVoice => '使用角色语言风格';

  @override
  String get povGeneration_useCharacterVoiceHint => '使用角色档案中设定的说话风格';

  @override
  String get povGeneration_view => '查看';

  @override
  String get povGeneration_words => '字';

  @override
  String get povResult_accept => '采纳';

  @override
  String get povResult_analysisDescription => '分析数据将在生成完成后显示在这里，包括：';

  @override
  String get povResult_analysisReport => '分析报告';

  @override
  String get povResult_analysis_item1 => '• 角色出现段落';

  @override
  String get povResult_analysis_item2 => '• 情感曲线分析';

  @override
  String get povResult_analysis_item3 => '• 关键观察记录';

  @override
  String get povResult_analysis_item4 => '• 角色互动分析';

  @override
  String get povResult_analysis_item5 => '• 建议的内心独白';

  @override
  String get povResult_copiedToClipboard => '已复制到剪贴板';

  @override
  String get povResult_copy => '复制';

  @override
  String get povResult_edit => '编辑';

  @override
  String get povResult_generationFailed => '生成失败';

  @override
  String get povResult_innerThoughts => '内心独白';

  @override
  String get povResult_noAnalysisData => '暂无分析数据';

  @override
  String get povResult_noResult => '暂无生成结果';

  @override
  String get povResult_pleaseWait => '这可能需要一些时间，请耐心等待';

  @override
  String get povResult_preview => '预览';

  @override
  String get povResult_regenerate => '重新生成';

  @override
  String get povResult_retry => '重试';

  @override
  String get povResult_status_analyzing => '正在分析章节内容...';

  @override
  String get povResult_status_generating => '正在生成视角内容...';

  @override
  String get povResult_status_preparing => '准备中...';

  @override
  String get povResult_status_processing => '处理中...';

  @override
  String get povResult_tab_analysis => '分析报告';

  @override
  String get povResult_tab_result => '生成结果';

  @override
  String povResult_tokenCount(Object count) {
    return 'Token：$count';
  }

  @override
  String get povResult_unknownError => '未知错误';

  @override
  String get povResult_viewRawData => '查看原始数据';

  @override
  String povResult_wordCount(Object count) {
    return '字数：$count';
  }

  @override
  String get previous => '上一步';

  @override
  String get reader_addBookmark => '添加书签';

  @override
  String get reader_addNote => '添加笔记';

  @override
  String get reader_bookmarkAdded => '书签已添加';

  @override
  String get reader_bookmarkNote => '笔记（可选）';

  @override
  String get reader_bookmarkNoteHint => '为这个书签添加备注...';

  @override
  String reader_bookmarkPosition(Object order, Object position) {
    return '位置：第 $order 章，$position 字';
  }

  @override
  String reader_chapterInfo(Object order) {
    return '第 $order 章';
  }

  @override
  String get reader_chapterList => '章节列表';

  @override
  String get reader_copied => '已复制';

  @override
  String get reader_copy => '复制';

  @override
  String get reader_firstChapter => '已经是第一章了';

  @override
  String get reader_highlightAdded => '已添加高亮';

  @override
  String get reader_highlightColor => '高亮颜色';

  @override
  String get reader_lastChapter => '已经是最后一章了';

  @override
  String get reader_loadingFailed => '加载失败';

  @override
  String get reader_noteContent => '笔记内容';

  @override
  String get reader_noteContentHint => '输入你的想法...';

  @override
  String get reader_noteSaved => '笔记已保存';

  @override
  String get reader_pleaseEnterNote => '请输入笔记内容';

  @override
  String get reader_reading => '阅读中';

  @override
  String get reader_retry => '重试';

  @override
  String get reader_saveBookmark => '保存书签';

  @override
  String get reader_selectChapter => '选择章节';

  @override
  String get reader_settings_autoScroll => '自动翻页';

  @override
  String get reader_settings_background => '背景颜色';

  @override
  String get reader_settings_background_short => '背景';

  @override
  String get reader_settings_close => '关闭';

  @override
  String get reader_settings_compact => '紧凑';

  @override
  String get reader_settings_default => '默认';

  @override
  String get reader_settings_display => '显示';

  @override
  String get reader_settings_font => '字体';

  @override
  String get reader_settings_fontFang => '仿宋';

  @override
  String get reader_settings_fontKai => '楷体';

  @override
  String get reader_settings_fontSerif => '宋体';

  @override
  String reader_settings_fontSize(Object size) {
    return '字体大小: $size';
  }

  @override
  String get reader_settings_large => '大';

  @override
  String reader_settings_lineHeight(Object height) {
    return '行高: $height';
  }

  @override
  String get reader_settings_loose => '宽松';

  @override
  String get reader_settings_orientation => '屏幕方向';

  @override
  String reader_settings_pageMargin(Object margin) {
    return '页边距: $margin';
  }

  @override
  String get reader_settings_pageMargin_short => '页边距';

  @override
  String get reader_settings_sansSerif => '黑体';

  @override
  String reader_settings_scrollSpeed(Object speed) {
    return '$speed 字/秒';
  }

  @override
  String get reader_settings_showProgressBar => '显示进度条';

  @override
  String get reader_settings_showTime => '显示时间';

  @override
  String get reader_settings_small => '小';

  @override
  String get reader_settings_title => '阅读设置';

  @override
  String get reader_tags => '标签（可选）';

  @override
  String get reader_tagsHint => '用逗号分隔，如：重要,伏笔';

  @override
  String reader_wordCount(Object count) {
    return '$count 字';
  }

  @override
  String get reading_addBookmark => '添加书签';

  @override
  String get reading_addNote => '添加笔记';

  @override
  String get reading_addNoteLabel => '添加笔记';

  @override
  String get reading_autoScroll => '自动翻页';

  @override
  String reading_autoScrollSpeed(Object speed) {
    return '$speed 字/秒';
  }

  @override
  String get reading_backgroundColor => '背景颜色';

  @override
  String get reading_backgroundLabel => '背景';

  @override
  String get reading_bookmarkAdded => '书签已添加';

  @override
  String reading_bookmarkLocation(Object order, Object position) {
    return '位置：第 $order 章，$position 字';
  }

  @override
  String get reading_bookmarkNote => '笔记（可选）';

  @override
  String get reading_bookmarkNoteHint => '为这个书签添加备注...';

  @override
  String get reading_chapterList => '章节列表';

  @override
  String reading_chapterNumber(Object order) {
    return '第 $order 章';
  }

  @override
  String get reading_close => '关闭';

  @override
  String get reading_compact => '紧凑';

  @override
  String get reading_copied => '已复制';

  @override
  String get reading_displaySettings => '显示';

  @override
  String get reading_enterNoteContent => '请输入笔记内容';

  @override
  String get reading_firstChapter => '已经是第一章了';

  @override
  String get reading_font => '字体';

  @override
  String get reading_fontDefault => '默认';

  @override
  String get reading_fontFang => '仿宋';

  @override
  String get reading_fontKai => '楷体';

  @override
  String get reading_fontSans => '黑体';

  @override
  String get reading_fontSerif => '宋体';

  @override
  String reading_fontSize(Object size) {
    return '字体大小: $size';
  }

  @override
  String get reading_fontSizeLabel => '字体大小';

  @override
  String get reading_highlightAdded => '已添加高亮';

  @override
  String get reading_highlightColor => '高亮颜色';

  @override
  String get reading_large => '大';

  @override
  String get reading_lastChapter => '已经是最后一章了';

  @override
  String reading_lineHeight(Object height) {
    return '行高: $height';
  }

  @override
  String get reading_lineHeightLabel => '行高';

  @override
  String reading_loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get reading_loose => '宽松';

  @override
  String get reading_noteContent => '笔记内容';

  @override
  String get reading_noteHint => '输入你的想法...';

  @override
  String get reading_noteSaved => '笔记已保存';

  @override
  String reading_pageMargin(Object margin) {
    return '页边距: $margin';
  }

  @override
  String get reading_pageMarginLabel => '页边距';

  @override
  String get reading_reading => '阅读中';

  @override
  String get reading_readingSettings => '阅读设置';

  @override
  String get reading_readingToolbar => '阅读工具栏';

  @override
  String get reading_retry => '重试';

  @override
  String get reading_saveBookmark => '保存书签';

  @override
  String get reading_screenOrientation => '屏幕方向';

  @override
  String get reading_selectChapter => '选择章节';

  @override
  String get reading_showProgressBar => '显示进度条';

  @override
  String get reading_showTime => '显示时间';

  @override
  String get reading_small => '小';

  @override
  String get reading_tags => '标签（可选）';

  @override
  String get reading_tagsHint => '用逗号分隔，如：重要,伏笔';

  @override
  String reading_words(Object count) {
    return '$count 字';
  }

  @override
  String get refresh => '刷新';

  @override
  String get remark => '备注';

  @override
  String get reset => '重置';

  @override
  String get retry => '重试';

  @override
  String get review_aiAnalyzing => 'AI 分析中...';

  @override
  String get review_aiStyleLabel => 'AI口吻';

  @override
  String get review_all => '全部';

  @override
  String get review_allChapters => '全部章节';

  @override
  String get review_allChaptersScope => '全部章节';

  @override
  String get review_autoReview => '自动审查';

  @override
  String get review_autoReviewDesc => '章节保存后自动触发审查';

  @override
  String get review_center_title => '审查中心';

  @override
  String get review_characterOOCLabel => '角色OOC';

  @override
  String get review_completed => '完成';

  @override
  String get review_comprehensive => '全面';

  @override
  String get review_comprehensiveDesc => '最全面的审查，包括伏笔和主题分析';

  @override
  String get review_configSaved => '配置已保存';

  @override
  String get review_configTitle => '审查配置';

  @override
  String get review_config_autoReview => '自动审查';

  @override
  String get review_config_autoReviewSubtitle => '章节保存后自动触发审查';

  @override
  String get review_config_depth => '审查深度';

  @override
  String get review_config_depthDescription_1 => '仅检查基本错误和格式问题';

  @override
  String get review_config_depthDescription_2 => '检查设定一致性和基本逻辑';

  @override
  String get review_config_depthDescription_3 => '深入分析角色行为和剧情发展';

  @override
  String get review_config_depthDescription_4 => '全面审查包括文风和节奏';

  @override
  String get review_config_depthDescription_5 => '最全面的审查，包括伏笔和主题分析';

  @override
  String get review_config_depth_comprehensive => '全面';

  @override
  String get review_config_depth_deep => '深入';

  @override
  String get review_config_depth_detailed => '详细';

  @override
  String get review_config_depth_quick => '快速';

  @override
  String get review_config_depth_standard => '标准';

  @override
  String get review_config_notifications => '启用通知';

  @override
  String get review_config_notificationsSubtitle => '审查完成后显示通知';

  @override
  String get review_config_saved => '配置已保存';

  @override
  String get review_config_title => '审查配置';

  @override
  String get review_consistencyLabel => '设定一致性';

  @override
  String get review_critical => '严重';

  @override
  String get review_currentVolume => '当前卷';

  @override
  String get review_detailed => '详细';

  @override
  String get review_detailedDesc => '深入分析角色行为和剧情发展';

  @override
  String get review_dimension => '维度';

  @override
  String get review_dimensionScore => '维度评分';

  @override
  String get review_dimensionScores => '维度评分';

  @override
  String get review_enableNotifications => '启用通知';

  @override
  String get review_enableNotificationsDesc => '审查完成后显示通知';

  @override
  String get review_filter_all => '全部';

  @override
  String get review_filter_dimension => '维度';

  @override
  String get review_filter_fixed => '已修复';

  @override
  String get review_filter_ignored => '已忽略';

  @override
  String get review_filter_pending => '待处理';

  @override
  String get review_filter_severity => '严重程度';

  @override
  String get review_filter_status => '状态';

  @override
  String get review_firstVolume => '第一卷';

  @override
  String get review_fixed => '已修复';

  @override
  String get review_generatingReport => '生成报告...';

  @override
  String get review_good => '良好';

  @override
  String get review_ignore => '忽略';

  @override
  String get review_ignored => '已忽略';

  @override
  String get review_inDepth => '深入';

  @override
  String get review_inDepthDesc => '全面审查包括文风和节奏';

  @override
  String get review_issueCard_ignore => '忽略';

  @override
  String get review_issueCard_view => '查看';

  @override
  String review_issueCount(Object count) {
    return '$count 个问题';
  }

  @override
  String review_issueDesc(Object number) {
    return '这是第 $number 个问题的描述，显示问题详情。';
  }

  @override
  String review_issueDescription(Object number) {
    return '这是第 $number 个问题的描述，显示问题详情。';
  }

  @override
  String get review_issueList => '问题列表';

  @override
  String review_issueLocation(Object chapter) {
    return '第$chapter章';
  }

  @override
  String get review_loadingChapters => '加载章节内容...';

  @override
  String review_location(Object chapter) {
    return '第$chapter章';
  }

  @override
  String get review_major => '中等';

  @override
  String get review_minor => '轻微';

  @override
  String get review_overallScore => '综合评分';

  @override
  String get review_overview => '概览';

  @override
  String get review_pacingLabel => '节奏把控';

  @override
  String get review_passedChapters => '已通过章节';

  @override
  String get review_pending => '待处理';

  @override
  String get review_plotLogicLabel => '剧情逻辑';

  @override
  String get review_preparingReview => '准备审查...';

  @override
  String get review_progressAnalyzing => 'AI 分析中...';

  @override
  String get review_progressCompleted => '完成';

  @override
  String get review_progressFinished => '审查完成！';

  @override
  String get review_progressGenerating => '生成报告...';

  @override
  String get review_progressLoading => '加载章节内容...';

  @override
  String get review_progressPreparing => '准备审查...';

  @override
  String get review_progress_result => '审查完成，请在问题列表中查看结果';

  @override
  String get review_progress_title => '审查进行中';

  @override
  String get review_progress_viewResult => '查看结果';

  @override
  String get review_quick => '快速';

  @override
  String get review_quickDesc => '仅检查基本错误和格式问题';

  @override
  String get review_quickReview => '快速审查';

  @override
  String get review_quickReviewTitle => '快速审查';

  @override
  String get review_quickReview_title => '快速审查';

  @override
  String get review_reviewCenter => '审查中心';

  @override
  String get review_reviewCompleted => '审查完成！';

  @override
  String get review_reviewCompletedDesc => '审查完成，请在问题列表中查看结果';

  @override
  String get review_reviewDepth => '审查深度';

  @override
  String get review_reviewDimensions => '审查维度';

  @override
  String get review_reviewInProgress => '审查进行中';

  @override
  String get review_reviewScope => '审查范围';

  @override
  String get review_scope_all => '全部章节';

  @override
  String get review_scope_chapter => '指定章节';

  @override
  String get review_scope_volume => '当前卷';

  @override
  String review_scoreLabel(Object score) {
    return '$score 分';
  }

  @override
  String get review_score_good => '良好';

  @override
  String review_score_points(Object score) {
    return '$score 分';
  }

  @override
  String get review_secondVolume => '第二卷';

  @override
  String get review_severity => '严重程度';

  @override
  String get review_severity_critical => '严重';

  @override
  String get review_severity_major => '中等';

  @override
  String get review_severity_minor => '轻微';

  @override
  String get review_specifiedChapter => '指定章节';

  @override
  String get review_spellingLabel => '错别字';

  @override
  String get review_standard => '标准';

  @override
  String get review_standardDesc => '检查设定一致性和基本逻辑';

  @override
  String get review_startReview => '开始审查';

  @override
  String get review_statistics => '统计';

  @override
  String get review_statistics_placeholder => '统计分析将在这里显示';

  @override
  String get review_status => '状态';

  @override
  String get review_tab_issues => '问题列表';

  @override
  String get review_tab_overview => '概览';

  @override
  String get review_tab_statistics => '统计';

  @override
  String get review_view => '查看';

  @override
  String get review_viewResults => '查看结果';

  @override
  String get review_volume => '第一卷';

  @override
  String get review_volume2 => '第二卷';

  @override
  String get save => '保存';

  @override
  String get saved => '已保存';

  @override
  String get search => '搜索';

  @override
  String get selectAll => '全选';

  @override
  String get settings => '设置';

  @override
  String get settings_addChildLocation => '添加子地点';

  @override
  String get settings_addFaction => '添加势力';

  @override
  String get settings_addItem => '添加物品';

  @override
  String get settings_addLocation => '添加地点';

  @override
  String get settings_addRelationship => '添加关系';

  @override
  String get settings_affection => '好感';

  @override
  String get settings_mergeDuplicates => '合并重复地点';

  @override
  String get settings_noDuplicatesFound => '未发现重复地点';

  @override
  String get settings_selectKeepLocation => '选择要保留的地点';

  @override
  String get settings_mergeConfirm => '确认合并';

  @override
  String get settings_mergeDesc => '将重复地点合并为一个，关联数据会自动转移';

  @override
  String get settings_age => '年龄';

  @override
  String get settings_ageHint => '如：25岁 / 未知';

  @override
  String get settings_aiConfig => 'AI 配置';

  @override
  String get settings_aiConfigSubtitle => '模型、提示词和调用统计。';

  @override
  String get settings_aiUsageStats => 'AI 使用统计';

  @override
  String get settings_aiUsageStatsSubtitle => '查看 token、调用次数和成本。';

  @override
  String get settings_aliases => '别名/称号';

  @override
  String get settings_aliasesHint => '多个别名用逗号分隔';

  @override
  String get settings_all => '全部';

  @override
  String get settings_allTypes => '全部类型';

  @override
  String get settings_analysisEntry => '分析入口';

  @override
  String get settings_analysisEntrySubtitle => '统计、审查和时间线。';

  @override
  String get settings_archive => '归档';

  @override
  String get settings_archiveCharacter => '归档角色';

  @override
  String settings_archiveConfirm(Object name) {
    return '确定要归档 $name 吗？归档后将从主列表中隐藏。';
  }

  @override
  String get settings_archived => '已归档';

  @override
  String get settings_basicInfo => '基本信息';

  @override
  String get settings_cancel => '取消';

  @override
  String get settings_changeHistory => '变更历史';

  @override
  String get settings_changeLifeStatus => '更改生命状态';

  @override
  String get settings_characterA => '角色 A';

  @override
  String get settings_characterB => '角色 B';

  @override
  String get settings_characterBio => '角色简介';

  @override
  String get settings_characterBioHint => '简要描述角色背景';

  @override
  String get settings_characterList => '角色列表';

  @override
  String get settings_characterListSubtitle => '进入角色档案和角色卡片列表。';

  @override
  String get settings_characterListTooltip => '角色列表';

  @override
  String get settings_characterManagement => '角色管理';

  @override
  String get settings_characterManagementTitle => '角色管理';

  @override
  String get settings_characterName => '角色名称';

  @override
  String get settings_characterRelations => '角色关系';

  @override
  String get settings_characterRelationsSubtitle => '角色、关系链路和生命状态。';

  @override
  String get settings_characterTier => '角色分级';

  @override
  String get settings_confirm => '确定';

  @override
  String get settings_create => '创建';

  @override
  String get settings_createFaction => '创建势力';

  @override
  String settings_createFailed(Object error) {
    return '创建失败: $error';
  }

  @override
  String get settings_createItem => '创建物品';

  @override
  String get settings_createLocation => '创建地点';

  @override
  String get settings_createRelationshipTitle => '新建角色关系';

  @override
  String get settings_cropAvatar => '裁剪头像';

  @override
  String settings_deleteFailed(Object error) {
    return '删除失败: $error';
  }

  @override
  String get settings_deleteRelationship => '删除关系';

  @override
  String get settings_deleteRelationshipConfirm =>
      '确定要删除这个关系吗？此操作不可撤销，相关的历史记录也会被删除。';

  @override
  String get settings_detailInfo => '详细信息';

  @override
  String get settings_edit => '编辑';

  @override
  String get settings_editCharacter => '编辑角色';

  @override
  String get settings_editRelationshipTitle => '编辑角色关系';

  @override
  String get settings_emotionalDimensionBar => '情感维度条';

  @override
  String get settings_emotionalDimensions => '情感维度';

  @override
  String get settings_enterCharacterName => '输入角色名称';

  @override
  String settings_eventCountChanges(Object count) {
    return '$count次变化';
  }

  @override
  String get settings_factionCard => '势力卡片';

  @override
  String get settings_factionListTitle => '势力/组织';

  @override
  String get settings_factionManagement => '势力管理';

  @override
  String get settings_factionManagementSubtitle => '管理组织、阵营和政治结构。';

  @override
  String get settings_fear => '恐惧';

  @override
  String settings_firstAppeared(Object date) {
    return '首次出现: $date';
  }

  @override
  String settings_fromChange(Object fromType) {
    return '从 $fromType 变更';
  }

  @override
  String get settings_gender => '性别';

  @override
  String get settings_hideArchived => '隐藏归档';

  @override
  String get settings_identity => '身份';

  @override
  String get settings_identityHint => '如：青云门大弟子';

  @override
  String get settings_itemCard => '物品卡片';

  @override
  String get settings_itemListTitle => '物品管理';

  @override
  String get settings_itemManagement => '物件管理';

  @override
  String get settings_itemManagementSubtitle => '整理武器、道具和关键物品。';

  @override
  String settings_lastUpdated(Object date) {
    return '最近更新: $date';
  }

  @override
  String get settings_lifeStatus => '生命状态';

  @override
  String get settings_listView => '列表视图';

  @override
  String get settings_listViewTitle => '列表视图';

  @override
  String settings_loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get settings_locationListTitle => '地点管理';

  @override
  String get settings_locationManagement => '地点管理';

  @override
  String get settings_locationManagementSubtitle => '组织城市、场景和地理层级。';

  @override
  String get settings_locationTreeNode => '地点树节点';

  @override
  String settings_markAsStatus(Object name, Object status) {
    return '已将 $name 标记为 $status';
  }

  @override
  String get settings_modelConfig => '模型配置';

  @override
  String get settings_modelConfigSubtitle => '管理 AI 提供商、API Key 和参数。';

  @override
  String get settings_newCharacter => '新建角色';

  @override
  String get settings_newRelationship => '新建关系';

  @override
  String get settings_noChangeRecords => '暂无变更记录';

  @override
  String get settings_noCharactersCreated => '还没有创建角色';

  @override
  String get settings_noFactionsCreated => '还没有创建势力';

  @override
  String get settings_noItemsCreated => '还没有创建物品';

  @override
  String get settings_noLocationsCreated => '还没有创建地点';

  @override
  String get settings_noMatchingCharacters => '没有找到匹配的角色';

  @override
  String get settings_noRelationshipsCreated => '还没有创建角色关系';

  @override
  String get settings_noRelationshipsYet => '还没有建立关系';

  @override
  String get settings_openReadingMode => '打开阅读模式';

  @override
  String get settings_openReadingModeDescription => '直接进入沉浸式阅读界面。';

  @override
  String settings_operationFailed(Object error) {
    return '操作失败: $error';
  }

  @override
  String settings_peopleCount(Object count) {
    return '$count 人';
  }

  @override
  String get settings_pleaseEnterCharacterName => '请输入角色名称';

  @override
  String get settings_povGeneration => 'POV 生成';

  @override
  String get settings_povGenerationDescription => '从角色视角重写章节片段。';

  @override
  String get settings_profileRequired => '此角色需要完善深度档案，包括性格特质、说话风格、行为习惯等';

  @override
  String get settings_quickActions => 'Quick actions';

  @override
  String get settings_rarity => '品级';

  @override
  String get settings_rarityBadge => '品级徽章';

  @override
  String settings_reason(Object reason) {
    return '原因: $reason';
  }

  @override
  String get settings_recentSearches => '最近搜索';

  @override
  String settings_recentlyUpdated(Object date) {
    return '最近更新于 $date';
  }

  @override
  String get settings_relationshipCard => '关系卡片';

  @override
  String get settings_relationshipCreated => '关系已创建';

  @override
  String get settings_relationshipDeleted => '关系已删除';

  @override
  String get settings_relationshipListTitle => '角色关系';

  @override
  String get settings_relationshipManagement => '角色关系';

  @override
  String get settings_relationshipManagementSubtitle => '查看人物之间的关系变化和事件。';

  @override
  String get settings_relationshipTimelineView => '关系时间线视图';

  @override
  String get settings_relationshipType => '关系类型';

  @override
  String get settings_relationshipUpdated => '关系已更新';

  @override
  String get settings_respect => '尊敬';

  @override
  String get settings_reviewCenter => '审查中心';

  @override
  String get settings_save => '保存';

  @override
  String settings_saveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String settings_search(Object query) {
    return '搜索: $query';
  }

  @override
  String get settings_searchCharacters => '搜索角色名称、别名、身份...';

  @override
  String get settings_showArchived => '显示归档';

  @override
  String get settings_statisticsTooltip => '统计面板';

  @override
  String get settings_tierBadge => '分级徽章';

  @override
  String get settings_tierDescription => '主角、主要配角、反派需要填写深度档案';

  @override
  String get settings_timeline => '时间线';

  @override
  String get settings_timelineSubtitle => '管理事件、冲突和角色轨迹。';

  @override
  String get settings_treeView => '树形视图';

  @override
  String get settings_treeViewTitle => '树形视图';

  @override
  String get settings_trust => '信任';

  @override
  String get settings_type => '类型';

  @override
  String get settings_unarchive => '取消归档';

  @override
  String get settings_unarchiveCharacter => '取消归档';

  @override
  String settings_unarchiveConfirm(Object name) {
    return '确定要取消归档 $name 吗？';
  }

  @override
  String get settings_unarchived => '已取消归档';

  @override
  String get settings_unknownCharacter => '未知角色';

  @override
  String settings_updateFailed(Object error) {
    return '更新失败: $error';
  }

  @override
  String settings_updateFailedGeneric(Object error) {
    return '更新失败: $error';
  }

  @override
  String get settings_viewChangeHistory => '查看变更历史';

  @override
  String get settings_workStatistics => '作品统计';

  @override
  String get settings_workStatisticsSubtitle => '章节进度、字数趋势和写作目标。';

  @override
  String get settings_worldSettings => '世界设定';

  @override
  String get settings_worldSettingsSubtitle => '地点、物件和势力的整理入口。';

  @override
  String get settings_worldWorkbench => '世界工作台';

  @override
  String get settings_worldWorkbenchSubtitle => '管理角色、物件、地点、势力和分析入口。';

  @override
  String get settings_worldbuildingControl => '把角色、关系、地点和物件放进一个清晰的操控面板。';

  @override
  String get settings_worldbuildingDescription =>
      '这里不再是零散的功能清单，而是围绕一个作品的世界信息中枢。你可以在这里进入设定、分析与统计路径。';

  @override
  String get shared_filter => '筛选';

  @override
  String get shared_noContent => '暂无内容';

  @override
  String get shared_search => '搜索...';

  @override
  String get shared_sort => '排序';

  @override
  String get statistics_addFirstGoal => '添加第一个目标';

  @override
  String get statistics_addGoal => '添加目标';

  @override
  String get statistics_addWritingGoal => '添加写作目标';

  @override
  String get statistics_averageChapterWords => '平均章节字数';

  @override
  String get statistics_chapterCount => '章节数';

  @override
  String get statistics_chapterList => '章节列表';

  @override
  String get statistics_chapterProgress => '章节进度';

  @override
  String get statistics_chapterProgressItem => '章节进度项';

  @override
  String get statistics_chapterProgressTab => '章节进度';

  @override
  String get statistics_chapterProgressTitle => '章节进度';

  @override
  String get statistics_chapterStatistics => '章节统计';

  @override
  String get statistics_chapterStatusDistribution => '章节状态分布';

  @override
  String get statistics_chapters => '章';

  @override
  String get statistics_characterStat => '角色统计';

  @override
  String get statistics_characterStatistics => '角色统计';

  @override
  String get statistics_characters => '字';

  @override
  String get statistics_completedChapters => '已完成章节';

  @override
  String get statistics_completionProgress => '完成进度';

  @override
  String get statistics_completionRate => '完成进度';

  @override
  String get statistics_coreMetrics => '核心指标';

  @override
  String get statistics_csvFormat => 'CSV';

  @override
  String get statistics_csvFormatDescription => '适合表格分析';

  @override
  String get statistics_cumulative => '累计';

  @override
  String get statistics_currentValue => '当前值';

  @override
  String get statistics_dailyAverageWords => '日均字数';

  @override
  String get statistics_dailyGoal => '每日目标';

  @override
  String get statistics_detailedData => '详细数据';

  @override
  String get statistics_draft => '草稿';

  @override
  String get statistics_editFunctionInDevelopment => '编辑功能开发中';

  @override
  String get statistics_editInDevelopment => '编辑功能开发中';

  @override
  String get statistics_endDate => '结束日期（可选）';

  @override
  String statistics_estimatedCompletionDate(Object date) {
    return '预计完成日期：$date';
  }

  @override
  String statistics_estimatedDate(Object date) {
    return '预计 $date';
  }

  @override
  String statistics_estimatedDaysRemaining(Object days) {
    return '预计还需 $days 天';
  }

  @override
  String statistics_exportFailed(Object error) {
    return '导出失败: $error';
  }

  @override
  String get statistics_exportReport => '导出报告';

  @override
  String get statistics_goalCard => '目标卡片';

  @override
  String get statistics_goalDeleted => '目标已删除';

  @override
  String get statistics_goalSaved => '目标已保存';

  @override
  String get statistics_goalType => '目标类型';

  @override
  String get statistics_goalsTabTitle => '目标标签页';

  @override
  String get statistics_growthRate => '增长率';

  @override
  String statistics_growthRateValue(Object rate) {
    return '$rate%';
  }

  @override
  String get statistics_jsonFormat => 'JSON';

  @override
  String get statistics_jsonFormatDescription => '包含完整统计数据';

  @override
  String get statistics_loadFailed => '加载失败';

  @override
  String get statistics_maxChapterWords => '最多字数章节';

  @override
  String get statistics_metricCard => '指标卡片';

  @override
  String get statistics_minChapterWords => '最少字数章节';

  @override
  String get statistics_minorCharacter => '次要角色';

  @override
  String get statistics_minorCharacters => '次要角色';

  @override
  String get statistics_monthlyGoal => '每月目标';

  @override
  String get statistics_noChapterData => '暂无章节数据';

  @override
  String get statistics_noData => '暂无数据';

  @override
  String get statistics_noGoalSet => '未设定目标';

  @override
  String get statistics_noGoalsSet => '还没有设置写作目标';

  @override
  String get statistics_overviewTab => '概览';

  @override
  String get statistics_overviewTabTitle => '概览标签页';

  @override
  String statistics_percentage(Object percent) {
    return '$percent%';
  }

  @override
  String get statistics_pleaseFillCompleteInfo => '请填写完整信息';

  @override
  String get statistics_progressTabTitle => '进度标签页';

  @override
  String get statistics_protagonist => '主角';

  @override
  String get statistics_published => '已发布';

  @override
  String statistics_publishedChapters(Object count) {
    return '已发布 $count 章';
  }

  @override
  String statistics_publishedWords(Object count) {
    return '已发布 $count 字';
  }

  @override
  String get statistics_recentWordCountTrend => '近期字数趋势';

  @override
  String statistics_reportExported(Object path) {
    return '报告已导出: $path';
  }

  @override
  String get statistics_selectDate => '选择日期';

  @override
  String get statistics_selectExportFormat => '选择导出格式';

  @override
  String get statistics_startDate => '开始日期';

  @override
  String get statistics_statRow => '统计行';

  @override
  String get statistics_supporting => '配角';

  @override
  String get statistics_supportingCharacter => '配角';

  @override
  String get statistics_targetValue => '目标值（字数）';

  @override
  String statistics_tenThousand(Object value) {
    return '$value万';
  }

  @override
  String get statistics_title => '统计中心';

  @override
  String get statistics_total => '总计';

  @override
  String statistics_totalChapters(Object count) {
    return '共 $count 章';
  }

  @override
  String get statistics_totalCharacters => '总计';

  @override
  String get statistics_totalGoal => '总目标';

  @override
  String get statistics_totalGrowth => '总增长';

  @override
  String statistics_totalGrowthValue(Object growth) {
    return '$growth 字';
  }

  @override
  String get statistics_totalWords => '总字数';

  @override
  String get statistics_trendTabTitle => '趋势标签页';

  @override
  String get statistics_view => '查看';

  @override
  String get statistics_villain => '反派';

  @override
  String get statistics_weeklyGoal => '每周目标';

  @override
  String get statistics_wordCount => '字数';

  @override
  String get statistics_wordCountTrend => '字数趋势';

  @override
  String get statistics_wordCountTrendTab => '字数趋势';

  @override
  String statistics_wordProgress(Object current, Object target) {
    return '$current / $target 字';
  }

  @override
  String statistics_words(Object count) {
    return '$count 字';
  }

  @override
  String statistics_writingDays(Object days) {
    return '写作天数 $days 天';
  }

  @override
  String get statistics_writingGoals => '写作目标';

  @override
  String get statistics_writingGoalsTab => '写作目标';

  @override
  String get statistics_writingGoalsTitle => '写作目标';

  @override
  String get status => '状态';

  @override
  String get submit => '提交';

  @override
  String get systemMode => '跟随系统';

  @override
  String get tag => '标签';

  @override
  String get theme => '主题';

  @override
  String get timeline_aiAutoFix => 'AI自动修复将根据建议自动调整相关事件';

  @override
  String get timeline_aiAutoFixButton => 'AI自动修复';

  @override
  String get timeline_all => '全部';

  @override
  String timeline_applyFixFailed(Object error) {
    return '应用修复失败: $error';
  }

  @override
  String get timeline_basicInfo => '基本信息';

  @override
  String get timeline_belongsToChapter => '所属章节';

  @override
  String timeline_chapter(Object id) {
    return '章节: $id';
  }

  @override
  String timeline_chapterNumber(Object number) {
    return '第 $number 章';
  }

  @override
  String get timeline_chapterTimeline => '章节时间线';

  @override
  String timeline_chapterTitle(Object chapterId) {
    return '第 $chapterId 章';
  }

  @override
  String get timeline_characterAvailabilityFix =>
      '角色在事件时间不可用（如被囚禁时参与其他事件）。请调整事件时间或角色安排。';

  @override
  String get timeline_characterView => '角色';

  @override
  String get timeline_charactersTab => '角色';

  @override
  String get timeline_close => '关闭';

  @override
  String get timeline_conflictFixed => '冲突已修复';

  @override
  String get timeline_conflictMarkedResolved => '冲突已标记为已解决';

  @override
  String get timeline_conflictType => '冲突类型：';

  @override
  String get timeline_conflictsTab => '冲突';

  @override
  String get timeline_createEvent => '创建事件';

  @override
  String get timeline_createFirstEvent => '创建第一个事件';

  @override
  String get timeline_cultivationProgress => '修为进度';

  @override
  String get timeline_cultivationProgressDisplay => '修为进度将在这里显示';

  @override
  String timeline_detectedConflicts(Object count) {
    return '检测到 $count 个潜在冲突';
  }

  @override
  String get timeline_edit => '编辑';

  @override
  String get timeline_editEvent => '编辑事件';

  @override
  String timeline_eventCount(Object count) {
    return '$count 个事件';
  }

  @override
  String get timeline_eventDescription => '事件描述';

  @override
  String get timeline_eventDescriptionLabel => '事件描述';

  @override
  String get timeline_eventListTile => '事件列表项';

  @override
  String get timeline_eventName => '名称';

  @override
  String get timeline_eventNode => '事件节点';

  @override
  String get timeline_eventTimelineComponent => '事件时间线组件';

  @override
  String get timeline_eventType => '类型';

  @override
  String timeline_eventTypeLabel(Object type) {
    return '类型：$type';
  }

  @override
  String get timeline_eventUpdated => '事件已更新';

  @override
  String get timeline_eventsTab => '事件';

  @override
  String get timeline_filterEvents => '筛选事件';

  @override
  String get timeline_fix => '修复';

  @override
  String get timeline_importance => '重要程度';

  @override
  String timeline_importanceLabel(Object importance) {
    return '重要程度：$importance';
  }

  @override
  String get timeline_keyEvent => '关键事件';

  @override
  String get timeline_listView => '列表';

  @override
  String get timeline_locationConflictFix => '角色或事件在同一时间出现在不同地点。建议调整时间安排或地点设置。';

  @override
  String get timeline_locationView => '地点';

  @override
  String get timeline_locationViewComponent => '地点视图';

  @override
  String get timeline_locationsTab => '地点';

  @override
  String get timeline_markAsResolved => '标记为已解决';

  @override
  String get timeline_newEvent => '新建事件';

  @override
  String get timeline_noEventRecords => '该角色暂无事件记录';

  @override
  String get timeline_noEventsYet => '还没有事件';

  @override
  String get timeline_noLocationData => '暂无地点数据';

  @override
  String get timeline_noTimeConflicts => '未检测到时间冲突';

  @override
  String get timeline_pleaseEnterEventName => '请输入事件名称';

  @override
  String get timeline_pleaseSelectCharacter => '请选择一个角色';

  @override
  String get timeline_relationshipChanges => '关系变化';

  @override
  String get timeline_relationshipChangesDisplay => '关系变化将在这里显示';

  @override
  String timeline_relativeTime(Object time) {
    return '相对时间：$time';
  }

  @override
  String get timeline_relativeTimeHint => '例如：事件发生后3天';

  @override
  String get timeline_required => '必填';

  @override
  String get timeline_resolutionSuggestion => '修复建议';

  @override
  String timeline_saveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get timeline_selectCharacter => '选择角色';

  @override
  String get timeline_stateConflictFix => '角色状态不一致（如死亡后又出现）。请检查角色状态变更的合理性。';

  @override
  String timeline_storyTime(Object time) {
    return '故事时间：$time';
  }

  @override
  String get timeline_storyTimeHint => '例如：第一卷 第三章';

  @override
  String get timeline_subsequentImpact => '后续影响';

  @override
  String get timeline_subsequentImpactLabel => '后续影响';

  @override
  String get timeline_suggestedFix => '建议修复方案：';

  @override
  String get timeline_timeSequenceFix => '调整事件的时间顺序，确保因果关系合理。建议检查前序事件的完成时间。';

  @override
  String get timeline_timelineNode => '时间线节点';

  @override
  String get timeline_timelineView => '时间线';

  @override
  String get timeline_title => '时间线';

  @override
  String get timeline_trajectory => '轨迹';

  @override
  String get timeline_unassignedChapter => '未分配章节';

  @override
  String get title => '标题';

  @override
  String get type => '类型';

  @override
  String get unarchive => '取消归档';

  @override
  String get unarchived => '已取消归档';

  @override
  String get unpinned => '已取消置顶';

  @override
  String get updateTime => '更新时间';

  @override
  String get usageStats_avgResponse => '平均响应';

  @override
  String get usageStats_cachedHits => '缓存命中';

  @override
  String get usageStats_dailyDetails => '每日详情';

  @override
  String get usageStats_errorCount => '错误数';

  @override
  String get usageStats_noData => '暂无数据';

  @override
  String get usageStats_recentRequests => '最近请求';

  @override
  String get usageStats_requestCount => '请求数';

  @override
  String get usageStats_selectDateRange => '选择日期范围';

  @override
  String get usageStats_statusDistribution => '状态分布';

  @override
  String get usageStats_status_cached => '缓存';

  @override
  String get usageStats_status_error => '错误';

  @override
  String get usageStats_status_success => '成功';

  @override
  String get usageStats_successRate => '成功率';

  @override
  String get usageStats_tab_byFunction => '按功能';

  @override
  String get usageStats_tab_byModel => '按模型';

  @override
  String get usageStats_tab_overview => '概览';

  @override
  String get usageStats_tier => '层级';

  @override
  String get usageStats_title => 'AI 使用统计';

  @override
  String get usageStats_totalRequests => '总请求';

  @override
  String get usageStats_totalTokens => '总 Token';

  @override
  String get work_adjustFilter => '调整筛选';

  @override
  String get work_aiDetection => 'AI 检测';

  @override
  String get work_aiDetectionDesc => '需要时把当前内容送去做 AI 检测。';

  @override
  String get work_aiSettings => 'AI 设置';

  @override
  String get work_aiUsageStats => 'AI 使用统计';

  @override
  String get work_aiUsageStatsDesc => '查看这部作品相关的模型与 token 使用情况。';

  @override
  String get work_all => '全部';

  @override
  String get work_analysis => '分析';

  @override
  String get work_analysisView => '分析视图';

  @override
  String get work_analysisViewDesc => '当你需要检查节奏、结构或故事逻辑时，从这里进入。';

  @override
  String get work_archiveWork => '归档作品';

  @override
  String get work_archived => '已归档作品';

  @override
  String get work_archivedHidden => '已隐藏归档';

  @override
  String get work_archivedHint => '已完结或暂停，但保留备查的作品。';

  @override
  String get work_archivedShown => '已显示归档';

  @override
  String get work_backToLibrary => '返回作品库';

  @override
  String get work_backToWork => '返回作品';

  @override
  String get work_cancel => '取消';

  @override
  String get work_changeCover => '更换封面';

  @override
  String get work_chapterMap => '章节地图';

  @override
  String get work_chapterMapDesc => '先创建第一章，作品结构就能建立起来。';

  @override
  String get work_chapterMapDesc2 => '按卷展示章节、阅读时间和审阅状态，方便快速导航。';

  @override
  String get work_chapterTitleHint => '章节标题';

  @override
  String get work_chapters => '章节';

  @override
  String work_chaptersCount(Object count) {
    return '$count 章';
  }

  @override
  String get work_chaptersHint => '当前作品下的所有章节。';

  @override
  String get work_chaptersLabel => '章节';

  @override
  String get work_characters => '角色';

  @override
  String get work_charactersDesc => '管理主要角色、简介和详细档案。';

  @override
  String get work_completedStatus => '已完成';

  @override
  String get work_completedStatusDesc => '这是一部已完成作品，章节、设定和审阅记录都已沉淀完毕。';

  @override
  String work_continueCreating(Object title) {
    return '继续创作《$title》';
  }

  @override
  String get work_create => '创建';

  @override
  String get work_createChapterTitle => '创建章节';

  @override
  String get work_createFirstChapter => '创建第一章';

  @override
  String get work_createFirstWork => '创建第一部作品';

  @override
  String get work_createWork => '新建作品';

  @override
  String get work_creation => '创作';

  @override
  String get work_creationSpace => '创作空间';

  @override
  String get work_creationSpaceDesc => '浏览所有作品，快速筛选书架，并直接回到当前最重要的创作现场。';

  @override
  String get work_creationSpaceTitle => '把正文、设定和创作节奏放在同一个地方。';

  @override
  String get work_creationTools => '创作工具';

  @override
  String get work_creationToolsDesc => '在作品上下文里完成写作、AI 辅助、审阅和阅读切换。';

  @override
  String get work_crossWorkSearch => '跨作品搜索';

  @override
  String work_currentShowing(Object count) {
    return '当前显示 $count 部作品';
  }

  @override
  String get work_currentWorkOnly => '仅当前作品';

  @override
  String get work_currentWorks => '当前作品';

  @override
  String get work_currentWorksHint => '按当前书架筛选结果统计。';

  @override
  String get work_customCover => '已选择自定义封面';

  @override
  String get work_dartStatusDesc => '梳理世界观、搭建章节结构，把零散灵感沉淀成稳定稿件。';

  @override
  String work_daysAgo(Object days) {
    return '$days天前';
  }

  @override
  String get work_defaultCover => '未上传时将使用默认封面';

  @override
  String get work_defaultCoverLabel => '默认封面';

  @override
  String get work_defaultStatusDesc => '一个聚合章节、角色和世界设定的写作空间。';

  @override
  String get work_draftStatus => '草稿';

  @override
  String get work_drafts => '草稿';

  @override
  String get work_draftsHint => '还在搭框架和大纲阶段的作品。';

  @override
  String get work_draftsLabel => '草稿';

  @override
  String get work_editInfo => '编辑信息';

  @override
  String get work_editProfile => '编辑资料';

  @override
  String get work_editWork => '编辑作品';

  @override
  String get work_enterKeyword => '先输入关键词';

  @override
  String get work_enterKeywordDesc => '可以按标题、简介或实体名称搜索，快速定位到对应内容。';

  @override
  String work_exportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String get work_exportFormat => '导出格式';

  @override
  String get work_exportMarkdown => 'Markdown';

  @override
  String work_exportSuccess(Object count, Object path) {
    return '已导出 $count 个章节到 $path';
  }

  @override
  String get work_exportTxt => '纯文本';

  @override
  String get work_exportWork => '导出作品';

  @override
  String get work_exportZip => 'ZIP 压缩包';

  @override
  String get work_exporting => '正在导出...';

  @override
  String get work_factions => '势力';

  @override
  String get work_factionsDesc => '管理组织、联盟和更大的权力结构。';

  @override
  String get work_featuredWork => '当前焦点作品';

  @override
  String get work_featuredWorkDesc => '想继续写的时候，优先从这里恢复，而不是重新找上下文。';

  @override
  String get work_globalScope => '全局范围';

  @override
  String get work_globalSearch => '全局搜索';

  @override
  String get work_hideArchived => '隐藏归档';

  @override
  String get work_inWorkSearch => '当前作品内搜索';

  @override
  String get work_items => '物品';

  @override
  String get work_itemsDesc => '整理道具、法宝和反复出现的重要物件。';

  @override
  String get work_library => '作品库';

  @override
  String get work_libraryDesc => '书架上的所有作品都在这里，进度和状态一目了然。';

  @override
  String get work_loadFailed => '工作区加载失败';

  @override
  String get work_loadFailedDescription => '暂时无法读取作品库。你可以重试，当前筛选条件会保留。';

  @override
  String get work_locations => '地点';

  @override
  String get work_locationsDesc => '管理场景设定和地点相关线索。';

  @override
  String get work_moreActions => '更多操作';

  @override
  String get work_newChapter => '新建章节';

  @override
  String get work_newChapterDefault => '新章节';

  @override
  String get work_newChapterLabel => '新建章节';

  @override
  String get work_newWork => '新建作品';

  @override
  String get work_noChaptersInVolume => '这一卷还没有章节。';

  @override
  String get work_noChaptersYet => '还没有章节';

  @override
  String get work_noChaptersYetDesc => '创建第一章时会自动生成第一卷，让作品从一开始就有清晰结构。';

  @override
  String get work_noMatchingResults => '没有匹配结果';

  @override
  String get work_noMatchingResultsDesc => '可以换个更宽泛的关键词，或重新打开归档范围。';

  @override
  String get work_noResults => '没有匹配结果';

  @override
  String get work_noResultsDesc => '可以换个更宽泛的关键词，或切换搜索范围。';

  @override
  String get work_noWorksYet => '还没有作品';

  @override
  String get work_noWorksYetDesc => '先创建第一部作品，建立你的写作工作区。';

  @override
  String get work_notSet => '未设置';

  @override
  String get work_ongoing => '进行中';

  @override
  String get work_ongoingStatus => '进行中';

  @override
  String get work_ongoingStatusDesc => '作品正在推进中。跟踪进度、保持节奏，并维持设定一致性。';

  @override
  String get work_openDetailDesc => '打开作品详情页，管理章节、查看进度，并直接进入编辑器。';

  @override
  String get work_openForm => '打开表单';

  @override
  String get work_openGlobalSearch => '打开全局搜索';

  @override
  String get work_openReader => '打开阅读器';

  @override
  String get work_openWorkspace => '打开工作区';

  @override
  String get work_otherType => '其他';

  @override
  String work_pickImageFailed(Object error) {
    return '选择图片失败: $error';
  }

  @override
  String get work_pin => '置顶作品';

  @override
  String get work_pinned => '已置顶作品';

  @override
  String get work_povGeneration => 'POV 生成';

  @override
  String get work_povGenerationDesc => '生成替代视角，扩展章节思路。';

  @override
  String get work_quickFind => '快速查找';

  @override
  String get work_quickFindDesc => '直接定位到目标页面，不必一层层点进去找。';

  @override
  String get work_quickFindTitle => '用一个搜索框查章节、角色和世界设定。';

  @override
  String get work_readingMode => '阅读模式';

  @override
  String get work_readingModeDesc => '切换到沉浸式阅读界面并保留进度。';

  @override
  String work_readingTime(Object minutes) {
    return '约 $minutes 分钟阅读';
  }

  @override
  String get work_refresh => '刷新';

  @override
  String get work_relationships => '关系';

  @override
  String get work_relationshipsDesc => '查看角色之间的联系、张力和变化历史。';

  @override
  String get work_restoreArchive => '恢复归档';

  @override
  String get work_restored => '已从归档恢复';

  @override
  String get work_retry => '重试';

  @override
  String get work_reviewCenter => '审阅中心';

  @override
  String get work_reviewCenterDesc => '运行写作检查并查看历史审阅结果。';

  @override
  String get work_reviewed => '已审阅';

  @override
  String get work_reviewedHint => '已有审阅分数的章节数量。';

  @override
  String get work_save => '保存';

  @override
  String work_saveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get work_search => '搜索';

  @override
  String get work_searchCurrentWork => '搜索当前作品';

  @override
  String get work_searchFailed => '搜索失败';

  @override
  String get work_searchFailedDesc => '这次查询没有完成，请重试。';

  @override
  String get work_searchGlobalHint => '搜索作品、章节、角色和地点';

  @override
  String get work_searchHint => '按标题或简介筛选作品';

  @override
  String get work_searchInWorkHint => '在当前作品内搜索';

  @override
  String get work_searchResults => '筛选结果';

  @override
  String get work_searchResultsDesc => '每条结果都会展示类型，方便你直接跳到正确位置。';

  @override
  String get work_searchResultsTitle => '搜索结果';

  @override
  String get work_searchWorkContent => '搜索作品内容';

  @override
  String get work_searchWorkContentDesc => '直接跳到章节、角色或设定条目。';

  @override
  String get work_serializing => '部连载中';

  @override
  String get work_serializingHint => '正在持续推进章节的作品。';

  @override
  String get work_serializingLabel => '连载中';

  @override
  String get work_settings => '设定';

  @override
  String get work_showArchived => '显示归档';

  @override
  String get work_startNewWork => '开始新作品';

  @override
  String get work_startSearch => '开始搜索';

  @override
  String get work_statistics => '统计';

  @override
  String get work_statisticsDesc => '查看字数、趋势和整体进度。';

  @override
  String get work_target => '目标';

  @override
  String get work_targetWords => '目标字数（可选）';

  @override
  String get work_targetWordsHint => '例如：100000';

  @override
  String get work_targetWordsInvalid => '请输入有效的字数';

  @override
  String get work_targetWordsUnit => '字';

  @override
  String get work_timeline => '时间线';

  @override
  String get work_timelineDesc => '检查事件顺序、冲突和时间一致性。';

  @override
  String get work_today => '今天';

  @override
  String get work_total => '总数';

  @override
  String get work_totalWords => '总字数';

  @override
  String get work_totalWordsHint => '所有章节累计的文本字数。';

  @override
  String get work_typeChapter => '章节';

  @override
  String get work_typeCharacter => '角色';

  @override
  String get work_typeFaction => '势力';

  @override
  String get work_typeItem => '物品';

  @override
  String get work_typeLocation => '地点';

  @override
  String get work_typeWork => '作品';

  @override
  String get work_unpin => '取消置顶';

  @override
  String get work_unpinned => '已取消置顶';

  @override
  String work_updateArchiveFailed(Object error) {
    return '更新归档状态失败：$error';
  }

  @override
  String work_updatePinFailed(Object error) {
    return '更新置顶状态失败：$error';
  }

  @override
  String get work_uploadCover => '上传封面';

  @override
  String get work_uploadLater => '可稍后再上传';

  @override
  String get work_useDefaultCover => '使用默认封面';

  @override
  String work_volumeChaptersWords(Object chapters, Object words) {
    return '$chapters 章，$words 字';
  }

  @override
  String get work_volumeCount => '卷数';

  @override
  String get work_volumes => '卷';

  @override
  String get work_volumesHint => '用于组织故事弧线或章节分组。';

  @override
  String work_wordProgress(Object current, Object target) {
    return '$current / $target 字';
  }

  @override
  String work_wordsCount(Object count) {
    return '$count 字';
  }

  @override
  String work_wordsStatus(Object status, Object words) {
    return '$words 字，$status';
  }

  @override
  String work_workCreated(Object name) {
    return '作品已创建：$name';
  }

  @override
  String get work_workDescription => '作品简介';

  @override
  String get work_workDescriptionHint => '简要描述作品内容';

  @override
  String get work_workDetailDesc => '这里集中管理这部作品的章节、世界设定、审阅结果和写作进度。';

  @override
  String get work_workDetailSubtitle => '和这部作品有关的内容，都集中在这个工作区里。';

  @override
  String get work_workName => '作品名称';

  @override
  String get work_workNameHint => '输入作品名称';

  @override
  String get work_workNameRequired => '请输入作品名称';

  @override
  String get work_workNameTooLong => '作品名称不能超过 100 字';

  @override
  String get work_workNotExist => '作品不存在';

  @override
  String get work_workNotExistDesc => '找不到当前选中的作品工作区。';

  @override
  String get work_workNotFound => '未找到作品';

  @override
  String get work_workNotFoundDesc => '这部作品当前不可用，请返回作品库后重新打开。';

  @override
  String get work_workSettings => '作品设置';

  @override
  String get work_workSettingsDesc => '打开完整设置区域，管理作品元数据和全局配置。';

  @override
  String get work_workSettingsLabel => '作品设置';

  @override
  String get work_workType => '作品类型';

  @override
  String work_workUpdated(Object name) {
    return '作品已更新：$name';
  }

  @override
  String get work_workbenchSubtitle => '把作品、设定和正在推进的章节集中在一个界面里。';

  @override
  String get work_workspaceLabel => '工作区';

  @override
  String get work_workspaceOverview => '工作区概览';

  @override
  String get work_workspaceOverviewDesc => '快速看一眼当前书架的整体状态。';

  @override
  String get work_workspaceStatus => '工作区状态';

  @override
  String get work_worldSettings => '世界设定';

  @override
  String get work_worldSettingsDesc => '角色、地点、关系和各种设定资料都在这里整理。';

  @override
  String get work_writingWorkbench => '写作工作台';

  @override
  String work_writtenWords(Object count) {
    return '已写 $count 字';
  }

  @override
  String get work_yesterday => '昨天';

  @override
  String get yes => '是';

  @override
  String get work_workDetailDesc2 => '管理这部作品的章节、世界设定、审阅结果和写作进度。';

  @override
  String get work_workSettingsDesc2 => '打开完整设置区域，管理作品元数据和全局配置。';

  @override
  String get settings_manuallyEdited => '手动编辑';

  @override
  String get settings_manuallyCreated => '手动创建';

  @override
  String get settings_delete => '删除';
}
