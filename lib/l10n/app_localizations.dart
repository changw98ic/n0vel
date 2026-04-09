import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S? of(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @actions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get actions;

  /// No description provided for @aiConfig_advancedParams.
  ///
  /// In zh, this message translates to:
  /// **'高级参数'**
  String get aiConfig_advancedParams;

  /// No description provided for @aiConfig_apiEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'API 地址'**
  String get aiConfig_apiEndpoint;

  /// No description provided for @aiConfig_apiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get aiConfig_apiKey;

  /// No description provided for @aiConfig_byFunctionStats.
  ///
  /// In zh, this message translates to:
  /// **'按功能统计'**
  String get aiConfig_byFunctionStats;

  /// No description provided for @aiConfig_byModelStats.
  ///
  /// In zh, this message translates to:
  /// **'按模型统计'**
  String get aiConfig_byModelStats;

  /// No description provided for @aiConfig_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get aiConfig_cancel;

  /// No description provided for @aiConfig_configSaved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get aiConfig_configSaved;

  /// No description provided for @aiConfig_connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请检查配置'**
  String get aiConfig_connectionFailed;

  /// No description provided for @aiConfig_connectionSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功！'**
  String get aiConfig_connectionSuccess;

  /// No description provided for @aiConfig_copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get aiConfig_copy;

  /// No description provided for @aiConfig_description.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get aiConfig_description;

  /// No description provided for @aiConfig_descriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'描述这个模板的用途'**
  String get aiConfig_descriptionHint;

  /// No description provided for @aiConfig_edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get aiConfig_edit;

  /// No description provided for @aiConfig_error_validation_systemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请输入 System Prompt'**
  String get aiConfig_error_validation_systemPrompt;

  /// No description provided for @aiConfig_error_validation_templateId.
  ///
  /// In zh, this message translates to:
  /// **'请输入模板 ID'**
  String get aiConfig_error_validation_templateId;

  /// No description provided for @aiConfig_error_validation_templateName.
  ///
  /// In zh, this message translates to:
  /// **'请输入模板名称'**
  String get aiConfig_error_validation_templateName;

  /// No description provided for @aiConfig_icon.
  ///
  /// In zh, this message translates to:
  /// **'图标'**
  String get aiConfig_icon;

  /// No description provided for @aiConfig_icon_chat.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get aiConfig_icon_chat;

  /// No description provided for @aiConfig_icon_check.
  ///
  /// In zh, this message translates to:
  /// **'检查'**
  String get aiConfig_icon_check;

  /// No description provided for @aiConfig_icon_edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get aiConfig_icon_edit;

  /// No description provided for @aiConfig_icon_extract.
  ///
  /// In zh, this message translates to:
  /// **'提取'**
  String get aiConfig_icon_extract;

  /// No description provided for @aiConfig_icon_person.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get aiConfig_icon_person;

  /// No description provided for @aiConfig_icon_review.
  ///
  /// In zh, this message translates to:
  /// **'审查'**
  String get aiConfig_icon_review;

  /// No description provided for @aiConfig_icon_summarize.
  ///
  /// In zh, this message translates to:
  /// **'摘要'**
  String get aiConfig_icon_summarize;

  /// No description provided for @aiConfig_icon_timeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get aiConfig_icon_timeline;

  /// No description provided for @aiConfig_icon_visibility.
  ///
  /// In zh, this message translates to:
  /// **'视角'**
  String get aiConfig_icon_visibility;

  /// No description provided for @aiConfig_icon_warning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get aiConfig_icon_warning;

  /// No description provided for @aiConfig_loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get aiConfig_loadFailed;

  /// No description provided for @aiConfig_modelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get aiConfig_modelName;

  /// No description provided for @aiConfig_new.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get aiConfig_new;

  /// No description provided for @aiConfig_newPromptTemplate.
  ///
  /// In zh, this message translates to:
  /// **'新建 Prompt 模板'**
  String get aiConfig_newPromptTemplate;

  /// No description provided for @aiConfig_providerType.
  ///
  /// In zh, this message translates to:
  /// **'服务商类型'**
  String get aiConfig_providerType;

  /// No description provided for @aiConfig_provider_anthropic.
  ///
  /// In zh, this message translates to:
  /// **'Claude'**
  String get aiConfig_provider_anthropic;

  /// No description provided for @aiConfig_provider_azure.
  ///
  /// In zh, this message translates to:
  /// **'Azure OpenAI'**
  String get aiConfig_provider_azure;

  /// No description provided for @aiConfig_provider_custom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get aiConfig_provider_custom;

  /// No description provided for @aiConfig_provider_ollama.
  ///
  /// In zh, this message translates to:
  /// **'Ollama (本地)'**
  String get aiConfig_provider_ollama;

  /// No description provided for @aiConfig_provider_openai.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI'**
  String get aiConfig_provider_openai;

  /// No description provided for @aiConfig_save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get aiConfig_save;

  /// No description provided for @aiConfig_saveConfig.
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get aiConfig_saveConfig;

  /// No description provided for @aiConfig_searchPrompts.
  ///
  /// In zh, this message translates to:
  /// **'搜索 Prompt 模板...'**
  String get aiConfig_searchPrompts;

  /// No description provided for @aiConfig_systemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'System Prompt'**
  String get aiConfig_systemPrompt;

  /// No description provided for @aiConfig_systemPromptHint.
  ///
  /// In zh, this message translates to:
  /// **'AI 的系统提示词'**
  String get aiConfig_systemPromptHint;

  /// No description provided for @aiConfig_systemPromptLabel.
  ///
  /// In zh, this message translates to:
  /// **'System Prompt'**
  String get aiConfig_systemPromptLabel;

  /// No description provided for @aiConfig_tab_functionMapping.
  ///
  /// In zh, this message translates to:
  /// **'功能映射'**
  String get aiConfig_tab_functionMapping;

  /// No description provided for @aiConfig_tab_modelConfig.
  ///
  /// In zh, this message translates to:
  /// **'模型配置'**
  String get aiConfig_tab_modelConfig;

  /// No description provided for @aiConfig_tab_promptManager.
  ///
  /// In zh, this message translates to:
  /// **'Prompt 管理'**
  String get aiConfig_tab_promptManager;

  /// No description provided for @aiConfig_tab_usageStats.
  ///
  /// In zh, this message translates to:
  /// **'使用统计'**
  String get aiConfig_tab_usageStats;

  /// No description provided for @aiConfig_templateId.
  ///
  /// In zh, this message translates to:
  /// **'模板 ID'**
  String get aiConfig_templateId;

  /// No description provided for @aiConfig_templateIdHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: custom_continuation'**
  String get aiConfig_templateIdHint;

  /// No description provided for @aiConfig_templateName.
  ///
  /// In zh, this message translates to:
  /// **'模板名称'**
  String get aiConfig_templateName;

  /// No description provided for @aiConfig_templateNameHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: 自定义续写'**
  String get aiConfig_templateNameHint;

  /// No description provided for @aiConfig_templateSaved.
  ///
  /// In zh, this message translates to:
  /// **'模板保存成功'**
  String get aiConfig_templateSaved;

  /// No description provided for @aiConfig_test.
  ///
  /// In zh, this message translates to:
  /// **'测试'**
  String get aiConfig_test;

  /// No description provided for @aiConfig_testFailed.
  ///
  /// In zh, this message translates to:
  /// **'测试失败'**
  String get aiConfig_testFailed;

  /// No description provided for @aiConfig_testingConnection.
  ///
  /// In zh, this message translates to:
  /// **'正在测试连接...'**
  String get aiConfig_testingConnection;

  /// No description provided for @aiConfig_tierConfig_description.
  ///
  /// In zh, this message translates to:
  /// **'配置三个层级的 AI 模型，系统会根据任务复杂度自动选择合适的模型。'**
  String get aiConfig_tierConfig_description;

  /// No description provided for @aiConfig_timesCount.
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get aiConfig_timesCount;

  /// No description provided for @aiConfig_title.
  ///
  /// In zh, this message translates to:
  /// **'AI 配置'**
  String get aiConfig_title;

  /// No description provided for @aiConfig_todayRequests.
  ///
  /// In zh, this message translates to:
  /// **'今日调用'**
  String get aiConfig_todayRequests;

  /// No description provided for @aiConfig_todayTokens.
  ///
  /// In zh, this message translates to:
  /// **'今日 Token'**
  String get aiConfig_todayTokens;

  /// No description provided for @aiConfig_tokens.
  ///
  /// In zh, this message translates to:
  /// **'tokens'**
  String get aiConfig_tokens;

  /// No description provided for @aiConfig_userPromptTemplate.
  ///
  /// In zh, this message translates to:
  /// **'User Prompt 模板 (可选)'**
  String get aiConfig_userPromptTemplate;

  /// No description provided for @aiConfig_userPromptTemplateHint.
  ///
  /// In zh, this message translates to:
  /// **'用户提示词模板，可使用 {variable} 占位符'**
  String aiConfig_userPromptTemplateHint(Object variable);

  /// No description provided for @aiConfig_weekRequests.
  ///
  /// In zh, this message translates to:
  /// **'本周调用'**
  String get aiConfig_weekRequests;

  /// No description provided for @aiConfig_weekTokens.
  ///
  /// In zh, this message translates to:
  /// **'本周 Token'**
  String get aiConfig_weekTokens;

  /// No description provided for @aiDetectionConfig_aiVocabularyHint.
  ///
  /// In zh, this message translates to:
  /// **'检测AI常用词汇'**
  String get aiDetectionConfig_aiVocabularyHint;

  /// No description provided for @aiDetectionConfig_autoAnalyzeHint.
  ///
  /// In zh, this message translates to:
  /// **'章节保存后自动进行AI检测'**
  String get aiDetectionConfig_autoAnalyzeHint;

  /// No description provided for @aiDetectionConfig_autoAnalyzeOnSave.
  ///
  /// In zh, this message translates to:
  /// **'保存时自动分析'**
  String get aiDetectionConfig_autoAnalyzeOnSave;

  /// No description provided for @aiDetectionConfig_dash.
  ///
  /// In zh, this message translates to:
  /// **'破折号 ——'**
  String get aiDetectionConfig_dash;

  /// No description provided for @aiDetectionConfig_detectionItems.
  ///
  /// In zh, this message translates to:
  /// **'检测项'**
  String get aiDetectionConfig_detectionItems;

  /// No description provided for @aiDetectionConfig_ellipsis.
  ///
  /// In zh, this message translates to:
  /// **'省略号 ……'**
  String get aiDetectionConfig_ellipsis;

  /// No description provided for @aiDetectionConfig_exclamation.
  ///
  /// In zh, this message translates to:
  /// **'感叹号 ！'**
  String get aiDetectionConfig_exclamation;

  /// No description provided for @aiDetectionConfig_forbiddenPatternsHint.
  ///
  /// In zh, this message translates to:
  /// **'检测AI常用的固定句式'**
  String get aiDetectionConfig_forbiddenPatternsHint;

  /// No description provided for @aiDetectionConfig_perspectiveCheckHint.
  ///
  /// In zh, this message translates to:
  /// **'检测上帝视角等问题'**
  String get aiDetectionConfig_perspectiveCheckHint;

  /// No description provided for @aiDetectionConfig_punctuationAbuseHint.
  ///
  /// In zh, this message translates to:
  /// **'检测标点符号使用频率'**
  String get aiDetectionConfig_punctuationAbuseHint;

  /// No description provided for @aiDetectionConfig_punctuationLimits.
  ///
  /// In zh, this message translates to:
  /// **'标点限制（次/千字）'**
  String get aiDetectionConfig_punctuationLimits;

  /// No description provided for @aiDetectionConfig_saved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get aiDetectionConfig_saved;

  /// No description provided for @aiDetectionConfig_standardizedCheckHint.
  ///
  /// In zh, this message translates to:
  /// **'检测列表式、重复句式'**
  String get aiDetectionConfig_standardizedCheckHint;

  /// No description provided for @aiDetectionConfig_times.
  ///
  /// In zh, this message translates to:
  /// **'次'**
  String get aiDetectionConfig_times;

  /// No description provided for @aiDetectionConfig_title.
  ///
  /// In zh, this message translates to:
  /// **'AI检测配置'**
  String get aiDetectionConfig_title;

  /// No description provided for @aiDetection_aiVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'AI 词汇'**
  String get aiDetection_aiVocabulary;

  /// No description provided for @aiDetection_analyzing.
  ///
  /// In zh, this message translates to:
  /// **'分析失败'**
  String get aiDetection_analyzing;

  /// No description provided for @aiDetection_apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get aiDetection_apply;

  /// No description provided for @aiDetection_detectionSettings.
  ///
  /// In zh, this message translates to:
  /// **'检测设置'**
  String get aiDetection_detectionSettings;

  /// No description provided for @aiDetection_enableAiVocabulary.
  ///
  /// In zh, this message translates to:
  /// **'AI 高频词检测'**
  String get aiDetection_enableAiVocabulary;

  /// No description provided for @aiDetection_enableForbiddenPatterns.
  ///
  /// In zh, this message translates to:
  /// **'禁用句式检测'**
  String get aiDetection_enableForbiddenPatterns;

  /// No description provided for @aiDetection_enablePunctuationAbuse.
  ///
  /// In zh, this message translates to:
  /// **'标点滥用检测'**
  String get aiDetection_enablePunctuationAbuse;

  /// No description provided for @aiDetection_forbiddenPatterns.
  ///
  /// In zh, this message translates to:
  /// **'禁用句式'**
  String get aiDetection_forbiddenPatterns;

  /// No description provided for @aiDetection_foundIssues.
  ///
  /// In zh, this message translates to:
  /// **'发现 {count} 个问题'**
  String aiDetection_foundIssues(Object count);

  /// No description provided for @aiDetection_issueDensity.
  ///
  /// In zh, this message translates to:
  /// **'问题密度 {density} / 千字'**
  String aiDetection_issueDensity(Object density);

  /// No description provided for @aiDetection_issueDistribution.
  ///
  /// In zh, this message translates to:
  /// **'问题分布'**
  String get aiDetection_issueDistribution;

  /// No description provided for @aiDetection_noIssues.
  ///
  /// In zh, this message translates to:
  /// **'没有发现明显问题'**
  String get aiDetection_noIssues;

  /// No description provided for @aiDetection_noProblemsFound.
  ///
  /// In zh, this message translates to:
  /// **'没有发现问题'**
  String get aiDetection_noProblemsFound;

  /// No description provided for @aiDetection_other.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get aiDetection_other;

  /// No description provided for @aiDetection_overview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get aiDetection_overview;

  /// No description provided for @aiDetection_punctuationAbuse.
  ///
  /// In zh, this message translates to:
  /// **'标点滥用'**
  String get aiDetection_punctuationAbuse;

  /// No description provided for @aiDetection_suggestion.
  ///
  /// In zh, this message translates to:
  /// **'建议：{suggestion}'**
  String aiDetection_suggestion(Object suggestion);

  /// No description provided for @aiDetection_title.
  ///
  /// In zh, this message translates to:
  /// **'AI 质量检测'**
  String get aiDetection_title;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'写作助手'**
  String get appName;

  /// No description provided for @archive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get archive;

  /// No description provided for @archived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get archived;

  /// No description provided for @assistantPanel_characterSimulation.
  ///
  /// In zh, this message translates to:
  /// **'角色模拟'**
  String get assistantPanel_characterSimulation;

  /// No description provided for @assistantPanel_contextInfo.
  ///
  /// In zh, this message translates to:
  /// **'当前章节内容会自动作为上下文一并发送。'**
  String get assistantPanel_contextInfo;

  /// No description provided for @assistantPanel_continuation.
  ///
  /// In zh, this message translates to:
  /// **'续写'**
  String get assistantPanel_continuation;

  /// No description provided for @assistantPanel_customPrompt.
  ///
  /// In zh, this message translates to:
  /// **'自定义提示词'**
  String get assistantPanel_customPrompt;

  /// No description provided for @assistantPanel_customPromptHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：让它检查节奏、补一个对白版本，或给出结构调整建议。'**
  String get assistantPanel_customPromptHint;

  /// No description provided for @assistantPanel_customPromptSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'在当前章节上下文之上补充你的具体要求。'**
  String get assistantPanel_customPromptSubtitle;

  /// No description provided for @assistantPanel_dialogue.
  ///
  /// In zh, this message translates to:
  /// **'对白'**
  String get assistantPanel_dialogue;

  /// No description provided for @assistantPanel_generate.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get assistantPanel_generate;

  /// No description provided for @assistantPanel_generating.
  ///
  /// In zh, this message translates to:
  /// **'生成中'**
  String get assistantPanel_generating;

  /// No description provided for @assistantPanel_generatingSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'助手正在准备结果草稿。'**
  String get assistantPanel_generatingSubtitle;

  /// No description provided for @assistantPanel_generationFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败：{error}'**
  String assistantPanel_generationFailed(Object error);

  /// No description provided for @assistantPanel_insertText.
  ///
  /// In zh, this message translates to:
  /// **'插入正文'**
  String get assistantPanel_insertText;

  /// No description provided for @assistantPanel_plotInspiration.
  ///
  /// In zh, this message translates to:
  /// **'剧情灵感'**
  String get assistantPanel_plotInspiration;

  /// No description provided for @assistantPanel_regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get assistantPanel_regenerate;

  /// No description provided for @assistantPanel_result.
  ///
  /// In zh, this message translates to:
  /// **'生成结果'**
  String get assistantPanel_result;

  /// No description provided for @assistantPanel_resultSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'先检查内容，再插入真正有用的部分。'**
  String get assistantPanel_resultSubtitle;

  /// No description provided for @assistantPanel_subtitle.
  ///
  /// In zh, this message translates to:
  /// **'用几个短指令快速续写、补对白或发散思路，不用离开编辑器。'**
  String get assistantPanel_subtitle;

  /// No description provided for @assistantPanel_title.
  ///
  /// In zh, this message translates to:
  /// **'AI 操作'**
  String get assistantPanel_title;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @basicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get basicInfo;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @configSaved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get configSaved;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @content.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get content;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copied;

  /// No description provided for @createTime.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get createTime;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @deleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认删除？'**
  String get deleteConfirm;

  /// No description provided for @deleteConfirmDesc.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可撤销'**
  String get deleteConfirmDesc;

  /// No description provided for @description.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get description;

  /// No description provided for @deselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get deselectAll;

  /// No description provided for @disable.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get disable;

  /// No description provided for @disabled.
  ///
  /// In zh, this message translates to:
  /// **'已禁用'**
  String get disabled;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @editor_ai.
  ///
  /// In zh, this message translates to:
  /// **'AI'**
  String get editor_ai;

  /// No description provided for @editor_aiOperations.
  ///
  /// In zh, this message translates to:
  /// **'AI 操作'**
  String get editor_aiOperations;

  /// No description provided for @editor_aiOperationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'用几个短指令快速续写、补对白或发散思路，不用离开编辑器。'**
  String get editor_aiOperationsDesc;

  /// No description provided for @editor_aiStyle.
  ///
  /// In zh, this message translates to:
  /// **'AI 痕迹'**
  String get editor_aiStyle;

  /// No description provided for @editor_apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get editor_apply;

  /// No description provided for @editor_applySegment.
  ///
  /// In zh, this message translates to:
  /// **'已应用分段结果'**
  String get editor_applySegment;

  /// No description provided for @editor_applySegmentResult.
  ///
  /// In zh, this message translates to:
  /// **'已应用分段结果'**
  String get editor_applySegmentResult;

  /// No description provided for @editor_assistantPanel.
  ///
  /// In zh, this message translates to:
  /// **'辅助面板'**
  String get editor_assistantPanel;

  /// No description provided for @editor_autoSaveEnabled.
  ///
  /// In zh, this message translates to:
  /// **'已开启自动保存'**
  String get editor_autoSaveEnabled;

  /// No description provided for @editor_autoSaveSuccess.
  ///
  /// In zh, this message translates to:
  /// **'草稿已自动保存'**
  String get editor_autoSaveSuccess;

  /// No description provided for @editor_autoSaved.
  ///
  /// In zh, this message translates to:
  /// **'草稿已自动保存'**
  String get editor_autoSaved;

  /// No description provided for @editor_bold.
  ///
  /// In zh, this message translates to:
  /// **'加粗'**
  String get editor_bold;

  /// No description provided for @editor_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get editor_cancel;

  /// No description provided for @editor_chapterTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'章节标题'**
  String get editor_chapterTitleHint;

  /// No description provided for @editor_characterAccessDescription.
  ///
  /// In zh, this message translates to:
  /// **'这里预留给写作时快速查看角色资料。'**
  String get editor_characterAccessDescription;

  /// No description provided for @editor_characterAccessNotAvailable.
  ///
  /// In zh, this message translates to:
  /// **'角色快捷入口暂未接入'**
  String get editor_characterAccessNotAvailable;

  /// No description provided for @editor_characterOOC.
  ///
  /// In zh, this message translates to:
  /// **'角色 OOC'**
  String get editor_characterOOC;

  /// No description provided for @editor_characterQuickAccess.
  ///
  /// In zh, this message translates to:
  /// **'角色快捷入口暂未接入'**
  String get editor_characterQuickAccess;

  /// No description provided for @editor_characterQuickAccessDesc.
  ///
  /// In zh, this message translates to:
  /// **'这里预留给写作时快速查看角色资料。'**
  String get editor_characterQuickAccessDesc;

  /// No description provided for @editor_characterSimulation.
  ///
  /// In zh, this message translates to:
  /// **'角色模拟'**
  String get editor_characterSimulation;

  /// No description provided for @editor_characters.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get editor_characters;

  /// No description provided for @editor_close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get editor_close;

  /// No description provided for @editor_consistency.
  ///
  /// In zh, this message translates to:
  /// **'一致性'**
  String get editor_consistency;

  /// No description provided for @editor_contentArea.
  ///
  /// In zh, this message translates to:
  /// **'正文编辑区'**
  String get editor_contentArea;

  /// No description provided for @editor_continue.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get editor_continue;

  /// No description provided for @editor_continueWriting.
  ///
  /// In zh, this message translates to:
  /// **'续写'**
  String get editor_continueWriting;

  /// No description provided for @editor_copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get editor_copiedToClipboard;

  /// No description provided for @editor_copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get editor_copy;

  /// No description provided for @editor_customPrompt.
  ///
  /// In zh, this message translates to:
  /// **'自定义提示词'**
  String get editor_customPrompt;

  /// No description provided for @editor_customPromptDesc.
  ///
  /// In zh, this message translates to:
  /// **'在当前章节上下文之上补充你的具体要求。'**
  String get editor_customPromptDesc;

  /// No description provided for @editor_dialogue.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get editor_dialogue;

  /// No description provided for @editor_dialogueLabel.
  ///
  /// In zh, this message translates to:
  /// **'对白'**
  String get editor_dialogueLabel;

  /// No description provided for @editor_dimension_aiStyle.
  ///
  /// In zh, this message translates to:
  /// **'AI 痕迹'**
  String get editor_dimension_aiStyle;

  /// No description provided for @editor_dimension_characterOOC.
  ///
  /// In zh, this message translates to:
  /// **'角色 OOC'**
  String get editor_dimension_characterOOC;

  /// No description provided for @editor_dimension_consistency.
  ///
  /// In zh, this message translates to:
  /// **'一致性'**
  String get editor_dimension_consistency;

  /// No description provided for @editor_dimension_pacing.
  ///
  /// In zh, this message translates to:
  /// **'节奏'**
  String get editor_dimension_pacing;

  /// No description provided for @editor_dimension_plotLogic.
  ///
  /// In zh, this message translates to:
  /// **'剧情逻辑'**
  String get editor_dimension_plotLogic;

  /// No description provided for @editor_dimension_spelling.
  ///
  /// In zh, this message translates to:
  /// **'错别字'**
  String get editor_dimension_spelling;

  /// No description provided for @editor_editTools.
  ///
  /// In zh, this message translates to:
  /// **'编辑工具'**
  String get editor_editTools;

  /// No description provided for @editor_exportChapter.
  ///
  /// In zh, this message translates to:
  /// **'导出章节'**
  String get editor_exportChapter;

  /// No description provided for @editor_exportChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出章节'**
  String get editor_exportChapterTitle;

  /// No description provided for @editor_exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String editor_exportFailed(Object error);

  /// No description provided for @editor_exportFormatMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'Markdown'**
  String get editor_exportFormatMarkdown;

  /// No description provided for @editor_exportFormatText.
  ///
  /// In zh, this message translates to:
  /// **'纯文本'**
  String get editor_exportFormatText;

  /// No description provided for @editor_exportPreview.
  ///
  /// In zh, this message translates to:
  /// **'导出预览（{format}）'**
  String editor_exportPreview(Object format);

  /// No description provided for @editor_find.
  ///
  /// In zh, this message translates to:
  /// **'查找'**
  String get editor_find;

  /// No description provided for @editor_focusedMode.
  ///
  /// In zh, this message translates to:
  /// **'专注于起草、修订和 AI 辅助迭代的编辑模式。'**
  String get editor_focusedMode;

  /// No description provided for @editor_generate.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get editor_generate;

  /// No description provided for @editor_generating.
  ///
  /// In zh, this message translates to:
  /// **'生成中'**
  String get editor_generating;

  /// No description provided for @editor_generatingDesc.
  ///
  /// In zh, this message translates to:
  /// **'助手正在准备结果草稿。'**
  String get editor_generatingDesc;

  /// No description provided for @editor_generationFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败：{error}'**
  String editor_generationFailed(Object error);

  /// No description provided for @editor_generationResult.
  ///
  /// In zh, this message translates to:
  /// **'生成结果'**
  String get editor_generationResult;

  /// No description provided for @editor_generationResultDesc.
  ///
  /// In zh, this message translates to:
  /// **'先检查内容，再插入真正有用的部分。'**
  String get editor_generationResultDesc;

  /// No description provided for @editor_hideSidebar.
  ///
  /// In zh, this message translates to:
  /// **'隐藏侧边栏'**
  String get editor_hideSidebar;

  /// No description provided for @editor_insertContent.
  ///
  /// In zh, this message translates to:
  /// **'插入正文'**
  String get editor_insertContent;

  /// No description provided for @editor_italic.
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get editor_italic;

  /// No description provided for @editor_mainEditArea.
  ///
  /// In zh, this message translates to:
  /// **'正文编辑区'**
  String get editor_mainEditArea;

  /// No description provided for @editor_pacing.
  ///
  /// In zh, this message translates to:
  /// **'节奏'**
  String get editor_pacing;

  /// No description provided for @editor_paragraphs.
  ///
  /// In zh, this message translates to:
  /// **'{count} 段'**
  String editor_paragraphs(Object count);

  /// No description provided for @editor_plotInspiration.
  ///
  /// In zh, this message translates to:
  /// **'剧情灵感'**
  String get editor_plotInspiration;

  /// No description provided for @editor_plotLogic.
  ///
  /// In zh, this message translates to:
  /// **'剧情逻辑'**
  String get editor_plotLogic;

  /// No description provided for @editor_polish.
  ///
  /// In zh, this message translates to:
  /// **'润色'**
  String get editor_polish;

  /// No description provided for @editor_polishChapter.
  ///
  /// In zh, this message translates to:
  /// **'润色章节'**
  String get editor_polishChapter;

  /// No description provided for @editor_promptContext.
  ///
  /// In zh, this message translates to:
  /// **'当前章节内容会自动作为上下文一并发送。'**
  String get editor_promptContext;

  /// No description provided for @editor_promptHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：让它检查节奏、补一个对白版本，或给出结构调整建议。'**
  String get editor_promptHint;

  /// No description provided for @editor_rating.
  ///
  /// In zh, this message translates to:
  /// **'评分 {score}'**
  String editor_rating(Object score);

  /// No description provided for @editor_readingTime.
  ///
  /// In zh, this message translates to:
  /// **'约 {minutes} 分钟阅读'**
  String editor_readingTime(Object minutes);

  /// No description provided for @editor_redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get editor_redo;

  /// No description provided for @editor_regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get editor_regenerate;

  /// No description provided for @editor_rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get editor_rename;

  /// No description provided for @editor_renameChapter.
  ///
  /// In zh, this message translates to:
  /// **'重命名章节'**
  String get editor_renameChapter;

  /// No description provided for @editor_renameTitle.
  ///
  /// In zh, this message translates to:
  /// **'重命名章节'**
  String get editor_renameTitle;

  /// No description provided for @editor_replace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get editor_replace;

  /// No description provided for @editor_reviewChapter.
  ///
  /// In zh, this message translates to:
  /// **'审阅章节'**
  String get editor_reviewChapter;

  /// No description provided for @editor_reviewChapterConfirm.
  ///
  /// In zh, this message translates to:
  /// **'要为“{title}”执行 {count} 个审阅维度吗？你可以在审阅中心查看进度。'**
  String editor_reviewChapterConfirm(Object count, Object title);

  /// No description provided for @editor_reviewChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'审阅章节'**
  String get editor_reviewChapterTitle;

  /// No description provided for @editor_reviewChapterTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'审阅《{title}》'**
  String editor_reviewChapterTitleLabel(Object title);

  /// No description provided for @editor_reviewConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'要为“{title}”执行 {count} 个审阅维度吗？你可以在审阅中心查看进度。'**
  String editor_reviewConfirmation(Object count, Object title);

  /// No description provided for @editor_reviewDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择要执行的审阅维度。'**
  String get editor_reviewDescription;

  /// No description provided for @editor_reviewStarted.
  ///
  /// In zh, this message translates to:
  /// **'已启动审阅流程'**
  String get editor_reviewStarted;

  /// No description provided for @editor_reviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'审阅《{title}》'**
  String editor_reviewTitle(Object title);

  /// No description provided for @editor_save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get editor_save;

  /// No description provided for @editor_saveNow.
  ///
  /// In zh, this message translates to:
  /// **'立即保存'**
  String get editor_saveNow;

  /// No description provided for @editor_savedAt.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {time}'**
  String editor_savedAt(Object time);

  /// No description provided for @editor_savedTime.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {time}'**
  String editor_savedTime(Object time);

  /// No description provided for @editor_score.
  ///
  /// In zh, this message translates to:
  /// **'评分 {score}'**
  String editor_score(Object score);

  /// No description provided for @editor_segmented.
  ///
  /// In zh, this message translates to:
  /// **'{chars} chars • {type}'**
  String editor_segmented(Object chars, Object type);

  /// No description provided for @editor_selectReviewDimensions.
  ///
  /// In zh, this message translates to:
  /// **'选择要执行的审阅维度。'**
  String get editor_selectReviewDimensions;

  /// No description provided for @editor_shortcutHint.
  ///
  /// In zh, this message translates to:
  /// **'快捷键：Ctrl+S 保存，Ctrl+Z 撤销'**
  String get editor_shortcutHint;

  /// No description provided for @editor_showSidebar.
  ///
  /// In zh, this message translates to:
  /// **'显示侧边栏'**
  String get editor_showSidebar;

  /// No description provided for @editor_sidePanel.
  ///
  /// In zh, this message translates to:
  /// **'辅助面板'**
  String get editor_sidePanel;

  /// No description provided for @editor_smartSegment.
  ///
  /// In zh, this message translates to:
  /// **'智能分段'**
  String get editor_smartSegment;

  /// No description provided for @editor_smartSegmentPreview.
  ///
  /// In zh, this message translates to:
  /// **'智能分段预览'**
  String get editor_smartSegmentPreview;

  /// No description provided for @editor_spelling.
  ///
  /// In zh, this message translates to:
  /// **'错别字'**
  String get editor_spelling;

  /// No description provided for @editor_startReview.
  ///
  /// In zh, this message translates to:
  /// **'开始审阅'**
  String get editor_startReview;

  /// No description provided for @editor_startWriting.
  ///
  /// In zh, this message translates to:
  /// **'开始写作...'**
  String get editor_startWriting;

  /// No description provided for @editor_statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get editor_statistics;

  /// No description provided for @editor_subtitle.
  ///
  /// In zh, this message translates to:
  /// **'专注于起草、修订和 AI 辅助迭代的编辑模式。'**
  String get editor_subtitle;

  /// No description provided for @editor_tab_ai.
  ///
  /// In zh, this message translates to:
  /// **'AI'**
  String get editor_tab_ai;

  /// No description provided for @editor_tab_characters.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get editor_tab_characters;

  /// No description provided for @editor_tab_statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get editor_tab_statistics;

  /// No description provided for @editor_toolbar_bold.
  ///
  /// In zh, this message translates to:
  /// **'加粗'**
  String get editor_toolbar_bold;

  /// No description provided for @editor_toolbar_boldTooltip.
  ///
  /// In zh, this message translates to:
  /// **'插入加粗标记'**
  String get editor_toolbar_boldTooltip;

  /// No description provided for @editor_toolbar_dialogue.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get editor_toolbar_dialogue;

  /// No description provided for @editor_toolbar_dialogueTooltip.
  ///
  /// In zh, this message translates to:
  /// **'插入对话引号'**
  String get editor_toolbar_dialogueTooltip;

  /// No description provided for @editor_toolbar_find.
  ///
  /// In zh, this message translates to:
  /// **'查找'**
  String get editor_toolbar_find;

  /// No description provided for @editor_toolbar_findTooltip.
  ///
  /// In zh, this message translates to:
  /// **'在章节内查找'**
  String get editor_toolbar_findTooltip;

  /// No description provided for @editor_toolbar_italic.
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get editor_toolbar_italic;

  /// No description provided for @editor_toolbar_italicTooltip.
  ///
  /// In zh, this message translates to:
  /// **'插入斜体标记'**
  String get editor_toolbar_italicTooltip;

  /// No description provided for @editor_toolbar_polish.
  ///
  /// In zh, this message translates to:
  /// **'润色'**
  String get editor_toolbar_polish;

  /// No description provided for @editor_toolbar_polishTooltip.
  ///
  /// In zh, this message translates to:
  /// **'整理并规范文本格式'**
  String get editor_toolbar_polishTooltip;

  /// No description provided for @editor_toolbar_redo.
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get editor_toolbar_redo;

  /// No description provided for @editor_toolbar_redoTooltip.
  ///
  /// In zh, this message translates to:
  /// **'恢复刚才撤销的修改'**
  String get editor_toolbar_redoTooltip;

  /// No description provided for @editor_toolbar_replace.
  ///
  /// In zh, this message translates to:
  /// **'替换'**
  String get editor_toolbar_replace;

  /// No description provided for @editor_toolbar_replaceTooltip.
  ///
  /// In zh, this message translates to:
  /// **'替换文本'**
  String get editor_toolbar_replaceTooltip;

  /// No description provided for @editor_toolbar_shortcuts.
  ///
  /// In zh, this message translates to:
  /// **'快捷键：Ctrl+S 保存，Ctrl+Z 撤销'**
  String get editor_toolbar_shortcuts;

  /// No description provided for @editor_toolbar_title.
  ///
  /// In zh, this message translates to:
  /// **'编辑工具'**
  String get editor_toolbar_title;

  /// No description provided for @editor_toolbar_undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get editor_toolbar_undo;

  /// No description provided for @editor_toolbar_undoTooltip.
  ///
  /// In zh, this message translates to:
  /// **'撤销上一步修改'**
  String get editor_toolbar_undoTooltip;

  /// No description provided for @editor_undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get editor_undo;

  /// No description provided for @editor_words.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String editor_words(Object count);

  /// No description provided for @enable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enable;

  /// No description provided for @enabled.
  ///
  /// In zh, this message translates to:
  /// **'已启用'**
  String get enabled;

  /// No description provided for @export.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

  /// No description provided for @finish.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get finish;

  /// No description provided for @import.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get import;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @name.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get name;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @no.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get no;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get none;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get operationFailed;

  /// No description provided for @operationSuccess.
  ///
  /// In zh, this message translates to:
  /// **'操作成功'**
  String get operationSuccess;

  /// No description provided for @other.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get other;

  /// No description provided for @pinned.
  ///
  /// In zh, this message translates to:
  /// **'已置顶'**
  String get pinned;

  /// No description provided for @povGeneration_addInnerThoughts.
  ///
  /// In zh, this message translates to:
  /// **'添加内心独白'**
  String get povGeneration_addInnerThoughts;

  /// No description provided for @povGeneration_addInnerThoughtsHint.
  ///
  /// In zh, this message translates to:
  /// **'根据角色性格添加内心活动'**
  String get povGeneration_addInnerThoughtsHint;

  /// No description provided for @povGeneration_chapterContentEmpty.
  ///
  /// In zh, this message translates to:
  /// **'章节内容为空'**
  String get povGeneration_chapterContentEmpty;

  /// No description provided for @povGeneration_characterNotFound.
  ///
  /// In zh, this message translates to:
  /// **'角色不存在'**
  String get povGeneration_characterNotFound;

  /// No description provided for @povGeneration_createdNewChapter.
  ///
  /// In zh, this message translates to:
  /// **'已创建新章节：{title}'**
  String povGeneration_createdNewChapter(Object title);

  /// No description provided for @povGeneration_customInstructions.
  ///
  /// In zh, this message translates to:
  /// **'额外指令（可选）'**
  String get povGeneration_customInstructions;

  /// No description provided for @povGeneration_customInstructionsHint.
  ///
  /// In zh, this message translates to:
  /// **'输入特殊要求或注意事项'**
  String get povGeneration_customInstructionsHint;

  /// No description provided for @povGeneration_emotionalIntensity.
  ///
  /// In zh, this message translates to:
  /// **'情感强度'**
  String get povGeneration_emotionalIntensity;

  /// No description provided for @povGeneration_expandObservations.
  ///
  /// In zh, this message translates to:
  /// **'扩展观察细节'**
  String get povGeneration_expandObservations;

  /// No description provided for @povGeneration_expandObservationsHint.
  ///
  /// In zh, this message translates to:
  /// **'扩展角色观察到的细节描写'**
  String get povGeneration_expandObservationsHint;

  /// No description provided for @povGeneration_generating.
  ///
  /// In zh, this message translates to:
  /// **'生成中...'**
  String get povGeneration_generating;

  /// No description provided for @povGeneration_generationConfig.
  ///
  /// In zh, this message translates to:
  /// **'生成配置'**
  String get povGeneration_generationConfig;

  /// No description provided for @povGeneration_generationFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get povGeneration_generationFailed;

  /// No description provided for @povGeneration_generationMode.
  ///
  /// In zh, this message translates to:
  /// **'生成模式'**
  String get povGeneration_generationMode;

  /// No description provided for @povGeneration_help.
  ///
  /// In zh, this message translates to:
  /// **'使用帮助'**
  String get povGeneration_help;

  /// No description provided for @povGeneration_help_description.
  ///
  /// In zh, this message translates to:
  /// **'配角视角生成功能可以帮助您从配角的视角重写章节内容。'**
  String get povGeneration_help_description;

  /// No description provided for @povGeneration_help_mode1.
  ///
  /// In zh, this message translates to:
  /// **'• 完整重写：从角色视角完整重写整章'**
  String get povGeneration_help_mode1;

  /// No description provided for @povGeneration_help_mode2.
  ///
  /// In zh, this message translates to:
  /// **'• 补充内容：在原文基础上补充视角细节'**
  String get povGeneration_help_mode2;

  /// No description provided for @povGeneration_help_mode3.
  ///
  /// In zh, this message translates to:
  /// **'• 视角摘要：生成角色视角的章节摘要'**
  String get povGeneration_help_mode3;

  /// No description provided for @povGeneration_help_mode4.
  ///
  /// In zh, this message translates to:
  /// **'• 场景片段：只生成特定场景的视角内容'**
  String get povGeneration_help_mode4;

  /// No description provided for @povGeneration_help_modesTitle.
  ///
  /// In zh, this message translates to:
  /// **'生成模式说明：'**
  String get povGeneration_help_modesTitle;

  /// No description provided for @povGeneration_help_step1.
  ///
  /// In zh, this message translates to:
  /// **'1. 选择要重写的章节'**
  String get povGeneration_help_step1;

  /// No description provided for @povGeneration_help_step2.
  ///
  /// In zh, this message translates to:
  /// **'2. 选择视角角色（配角）'**
  String get povGeneration_help_step2;

  /// No description provided for @povGeneration_help_step3.
  ///
  /// In zh, this message translates to:
  /// **'3. 配置生成参数'**
  String get povGeneration_help_step3;

  /// No description provided for @povGeneration_help_step4.
  ///
  /// In zh, this message translates to:
  /// **'4. 点击“开始生成”'**
  String get povGeneration_help_step4;

  /// No description provided for @povGeneration_help_steps.
  ///
  /// In zh, this message translates to:
  /// **'使用步骤：'**
  String get povGeneration_help_steps;

  /// No description provided for @povGeneration_help_title.
  ///
  /// In zh, this message translates to:
  /// **'使用帮助'**
  String get povGeneration_help_title;

  /// No description provided for @povGeneration_history.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get povGeneration_history;

  /// No description provided for @povGeneration_history_close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get povGeneration_history_close;

  /// No description provided for @povGeneration_history_noHistory.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史记录'**
  String get povGeneration_history_noHistory;

  /// No description provided for @povGeneration_history_task.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get povGeneration_history_task;

  /// No description provided for @povGeneration_history_title.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get povGeneration_history_title;

  /// No description provided for @povGeneration_intense.
  ///
  /// In zh, this message translates to:
  /// **'强烈'**
  String get povGeneration_intense;

  /// No description provided for @povGeneration_keepDialogue.
  ///
  /// In zh, this message translates to:
  /// **'保留对话'**
  String get povGeneration_keepDialogue;

  /// No description provided for @povGeneration_keepDialogueHint.
  ///
  /// In zh, this message translates to:
  /// **'保留原文中的对话内容'**
  String get povGeneration_keepDialogueHint;

  /// No description provided for @povGeneration_loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get povGeneration_loadFailed;

  /// No description provided for @povGeneration_newChapter.
  ///
  /// In zh, this message translates to:
  /// **'• 新建章节：创建一个新章节保存POV内容'**
  String get povGeneration_newChapter;

  /// No description provided for @povGeneration_newChapterButton.
  ///
  /// In zh, this message translates to:
  /// **'新建章节'**
  String get povGeneration_newChapterButton;

  /// No description provided for @povGeneration_noSupportingCharacters.
  ///
  /// In zh, this message translates to:
  /// **'暂无配角，请先在角色设定中创建配角'**
  String get povGeneration_noSupportingCharacters;

  /// No description provided for @povGeneration_outputStyle.
  ///
  /// In zh, this message translates to:
  /// **'输出风格'**
  String get povGeneration_outputStyle;

  /// No description provided for @povGeneration_placeholder.
  ///
  /// In zh, this message translates to:
  /// **'选择章节和角色后开始生成'**
  String get povGeneration_placeholder;

  /// No description provided for @povGeneration_pleaseCreateVolume.
  ///
  /// In zh, this message translates to:
  /// **'请先创建卷'**
  String get povGeneration_pleaseCreateVolume;

  /// No description provided for @povGeneration_pleaseSelectChapter.
  ///
  /// In zh, this message translates to:
  /// **'请先选择章节'**
  String get povGeneration_pleaseSelectChapter;

  /// No description provided for @povGeneration_povChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'POV视角章节'**
  String get povGeneration_povChapterTitle;

  /// No description provided for @povGeneration_quickTemplates.
  ///
  /// In zh, this message translates to:
  /// **'快速模板'**
  String get povGeneration_quickTemplates;

  /// No description provided for @povGeneration_restrained.
  ///
  /// In zh, this message translates to:
  /// **'克制'**
  String get povGeneration_restrained;

  /// No description provided for @povGeneration_saveAsDraft.
  ///
  /// In zh, this message translates to:
  /// **'• 保存为草稿：保存到当前章节的草稿'**
  String get povGeneration_saveAsDraft;

  /// No description provided for @povGeneration_saveAsDraftButton.
  ///
  /// In zh, this message translates to:
  /// **'保存为草稿'**
  String get povGeneration_saveAsDraftButton;

  /// No description provided for @povGeneration_savePOVResult.
  ///
  /// In zh, this message translates to:
  /// **'保存POV结果'**
  String get povGeneration_savePOVResult;

  /// No description provided for @povGeneration_savedToDraft.
  ///
  /// In zh, this message translates to:
  /// **'已保存到草稿'**
  String get povGeneration_savedToDraft;

  /// No description provided for @povGeneration_selectChapter.
  ///
  /// In zh, this message translates to:
  /// **'选择章节'**
  String get povGeneration_selectChapter;

  /// No description provided for @povGeneration_selectChapterHint.
  ///
  /// In zh, this message translates to:
  /// **'请选择章节'**
  String get povGeneration_selectChapterHint;

  /// No description provided for @povGeneration_selectCharacter.
  ///
  /// In zh, this message translates to:
  /// **'选择角色'**
  String get povGeneration_selectCharacter;

  /// No description provided for @povGeneration_selectCharacterHint.
  ///
  /// In zh, this message translates to:
  /// **'请选择配角'**
  String get povGeneration_selectCharacterHint;

  /// No description provided for @povGeneration_selectSaveMethod.
  ///
  /// In zh, this message translates to:
  /// **'请选择保存方式：'**
  String get povGeneration_selectSaveMethod;

  /// No description provided for @povGeneration_startGeneration.
  ///
  /// In zh, this message translates to:
  /// **'开始生成'**
  String get povGeneration_startGeneration;

  /// No description provided for @povGeneration_targetWordCount.
  ///
  /// In zh, this message translates to:
  /// **'目标字数（可选）'**
  String get povGeneration_targetWordCount;

  /// No description provided for @povGeneration_targetWordCountHint.
  ///
  /// In zh, this message translates to:
  /// **'不填则自动估算'**
  String get povGeneration_targetWordCountHint;

  /// No description provided for @povGeneration_title.
  ///
  /// In zh, this message translates to:
  /// **'配角视角生成'**
  String get povGeneration_title;

  /// No description provided for @povGeneration_useCharacterVoice.
  ///
  /// In zh, this message translates to:
  /// **'使用角色语言风格'**
  String get povGeneration_useCharacterVoice;

  /// No description provided for @povGeneration_useCharacterVoiceHint.
  ///
  /// In zh, this message translates to:
  /// **'使用角色档案中设定的说话风格'**
  String get povGeneration_useCharacterVoiceHint;

  /// No description provided for @povGeneration_view.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get povGeneration_view;

  /// No description provided for @povGeneration_words.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get povGeneration_words;

  /// No description provided for @povResult_accept.
  ///
  /// In zh, this message translates to:
  /// **'采纳'**
  String get povResult_accept;

  /// No description provided for @povResult_analysisDescription.
  ///
  /// In zh, this message translates to:
  /// **'分析数据将在生成完成后显示在这里，包括：'**
  String get povResult_analysisDescription;

  /// No description provided for @povResult_analysisReport.
  ///
  /// In zh, this message translates to:
  /// **'分析报告'**
  String get povResult_analysisReport;

  /// No description provided for @povResult_analysis_item1.
  ///
  /// In zh, this message translates to:
  /// **'• 角色出现段落'**
  String get povResult_analysis_item1;

  /// No description provided for @povResult_analysis_item2.
  ///
  /// In zh, this message translates to:
  /// **'• 情感曲线分析'**
  String get povResult_analysis_item2;

  /// No description provided for @povResult_analysis_item3.
  ///
  /// In zh, this message translates to:
  /// **'• 关键观察记录'**
  String get povResult_analysis_item3;

  /// No description provided for @povResult_analysis_item4.
  ///
  /// In zh, this message translates to:
  /// **'• 角色互动分析'**
  String get povResult_analysis_item4;

  /// No description provided for @povResult_analysis_item5.
  ///
  /// In zh, this message translates to:
  /// **'• 建议的内心独白'**
  String get povResult_analysis_item5;

  /// No description provided for @povResult_copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get povResult_copiedToClipboard;

  /// No description provided for @povResult_copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get povResult_copy;

  /// No description provided for @povResult_edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get povResult_edit;

  /// No description provided for @povResult_generationFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成失败'**
  String get povResult_generationFailed;

  /// No description provided for @povResult_innerThoughts.
  ///
  /// In zh, this message translates to:
  /// **'内心独白'**
  String get povResult_innerThoughts;

  /// No description provided for @povResult_noAnalysisData.
  ///
  /// In zh, this message translates to:
  /// **'暂无分析数据'**
  String get povResult_noAnalysisData;

  /// No description provided for @povResult_noResult.
  ///
  /// In zh, this message translates to:
  /// **'暂无生成结果'**
  String get povResult_noResult;

  /// No description provided for @povResult_pleaseWait.
  ///
  /// In zh, this message translates to:
  /// **'这可能需要一些时间，请耐心等待'**
  String get povResult_pleaseWait;

  /// No description provided for @povResult_preview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get povResult_preview;

  /// No description provided for @povResult_regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get povResult_regenerate;

  /// No description provided for @povResult_retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get povResult_retry;

  /// No description provided for @povResult_status_analyzing.
  ///
  /// In zh, this message translates to:
  /// **'正在分析章节内容...'**
  String get povResult_status_analyzing;

  /// No description provided for @povResult_status_generating.
  ///
  /// In zh, this message translates to:
  /// **'正在生成视角内容...'**
  String get povResult_status_generating;

  /// No description provided for @povResult_status_preparing.
  ///
  /// In zh, this message translates to:
  /// **'准备中...'**
  String get povResult_status_preparing;

  /// No description provided for @povResult_status_processing.
  ///
  /// In zh, this message translates to:
  /// **'处理中...'**
  String get povResult_status_processing;

  /// No description provided for @povResult_tab_analysis.
  ///
  /// In zh, this message translates to:
  /// **'分析报告'**
  String get povResult_tab_analysis;

  /// No description provided for @povResult_tab_result.
  ///
  /// In zh, this message translates to:
  /// **'生成结果'**
  String get povResult_tab_result;

  /// No description provided for @povResult_tokenCount.
  ///
  /// In zh, this message translates to:
  /// **'Token：{count}'**
  String povResult_tokenCount(Object count);

  /// No description provided for @povResult_unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get povResult_unknownError;

  /// No description provided for @povResult_viewRawData.
  ///
  /// In zh, this message translates to:
  /// **'查看原始数据'**
  String get povResult_viewRawData;

  /// No description provided for @povResult_wordCount.
  ///
  /// In zh, this message translates to:
  /// **'字数：{count}'**
  String povResult_wordCount(Object count);

  /// No description provided for @previous.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get previous;

  /// No description provided for @reader_addBookmark.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get reader_addBookmark;

  /// No description provided for @reader_addNote.
  ///
  /// In zh, this message translates to:
  /// **'添加笔记'**
  String get reader_addNote;

  /// No description provided for @reader_bookmarkAdded.
  ///
  /// In zh, this message translates to:
  /// **'书签已添加'**
  String get reader_bookmarkAdded;

  /// No description provided for @reader_bookmarkNote.
  ///
  /// In zh, this message translates to:
  /// **'笔记（可选）'**
  String get reader_bookmarkNote;

  /// No description provided for @reader_bookmarkNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'为这个书签添加备注...'**
  String get reader_bookmarkNoteHint;

  /// No description provided for @reader_bookmarkPosition.
  ///
  /// In zh, this message translates to:
  /// **'位置：第 {order} 章，{position} 字'**
  String reader_bookmarkPosition(Object order, Object position);

  /// No description provided for @reader_chapterInfo.
  ///
  /// In zh, this message translates to:
  /// **'第 {order} 章'**
  String reader_chapterInfo(Object order);

  /// No description provided for @reader_chapterList.
  ///
  /// In zh, this message translates to:
  /// **'章节列表'**
  String get reader_chapterList;

  /// No description provided for @reader_copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get reader_copied;

  /// No description provided for @reader_copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get reader_copy;

  /// No description provided for @reader_firstChapter.
  ///
  /// In zh, this message translates to:
  /// **'已经是第一章了'**
  String get reader_firstChapter;

  /// No description provided for @reader_highlightAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加高亮'**
  String get reader_highlightAdded;

  /// No description provided for @reader_highlightColor.
  ///
  /// In zh, this message translates to:
  /// **'高亮颜色'**
  String get reader_highlightColor;

  /// No description provided for @reader_lastChapter.
  ///
  /// In zh, this message translates to:
  /// **'已经是最后一章了'**
  String get reader_lastChapter;

  /// No description provided for @reader_loadingFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get reader_loadingFailed;

  /// No description provided for @reader_noteContent.
  ///
  /// In zh, this message translates to:
  /// **'笔记内容'**
  String get reader_noteContent;

  /// No description provided for @reader_noteContentHint.
  ///
  /// In zh, this message translates to:
  /// **'输入你的想法...'**
  String get reader_noteContentHint;

  /// No description provided for @reader_noteSaved.
  ///
  /// In zh, this message translates to:
  /// **'笔记已保存'**
  String get reader_noteSaved;

  /// No description provided for @reader_pleaseEnterNote.
  ///
  /// In zh, this message translates to:
  /// **'请输入笔记内容'**
  String get reader_pleaseEnterNote;

  /// No description provided for @reader_reading.
  ///
  /// In zh, this message translates to:
  /// **'阅读中'**
  String get reader_reading;

  /// No description provided for @reader_retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get reader_retry;

  /// No description provided for @reader_saveBookmark.
  ///
  /// In zh, this message translates to:
  /// **'保存书签'**
  String get reader_saveBookmark;

  /// No description provided for @reader_selectChapter.
  ///
  /// In zh, this message translates to:
  /// **'选择章节'**
  String get reader_selectChapter;

  /// No description provided for @reader_settings_autoScroll.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get reader_settings_autoScroll;

  /// No description provided for @reader_settings_background.
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get reader_settings_background;

  /// No description provided for @reader_settings_background_short.
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get reader_settings_background_short;

  /// No description provided for @reader_settings_close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get reader_settings_close;

  /// No description provided for @reader_settings_compact.
  ///
  /// In zh, this message translates to:
  /// **'紧凑'**
  String get reader_settings_compact;

  /// No description provided for @reader_settings_default.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get reader_settings_default;

  /// No description provided for @reader_settings_display.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get reader_settings_display;

  /// No description provided for @reader_settings_font.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get reader_settings_font;

  /// No description provided for @reader_settings_fontFang.
  ///
  /// In zh, this message translates to:
  /// **'仿宋'**
  String get reader_settings_fontFang;

  /// No description provided for @reader_settings_fontKai.
  ///
  /// In zh, this message translates to:
  /// **'楷体'**
  String get reader_settings_fontKai;

  /// No description provided for @reader_settings_fontSerif.
  ///
  /// In zh, this message translates to:
  /// **'宋体'**
  String get reader_settings_fontSerif;

  /// No description provided for @reader_settings_fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小: {size}'**
  String reader_settings_fontSize(Object size);

  /// No description provided for @reader_settings_large.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get reader_settings_large;

  /// No description provided for @reader_settings_lineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行高: {height}'**
  String reader_settings_lineHeight(Object height);

  /// No description provided for @reader_settings_loose.
  ///
  /// In zh, this message translates to:
  /// **'宽松'**
  String get reader_settings_loose;

  /// No description provided for @reader_settings_orientation.
  ///
  /// In zh, this message translates to:
  /// **'屏幕方向'**
  String get reader_settings_orientation;

  /// No description provided for @reader_settings_pageMargin.
  ///
  /// In zh, this message translates to:
  /// **'页边距: {margin}'**
  String reader_settings_pageMargin(Object margin);

  /// No description provided for @reader_settings_pageMargin_short.
  ///
  /// In zh, this message translates to:
  /// **'页边距'**
  String get reader_settings_pageMargin_short;

  /// No description provided for @reader_settings_sansSerif.
  ///
  /// In zh, this message translates to:
  /// **'黑体'**
  String get reader_settings_sansSerif;

  /// No description provided for @reader_settings_scrollSpeed.
  ///
  /// In zh, this message translates to:
  /// **'{speed} 字/秒'**
  String reader_settings_scrollSpeed(Object speed);

  /// No description provided for @reader_settings_showProgressBar.
  ///
  /// In zh, this message translates to:
  /// **'显示进度条'**
  String get reader_settings_showProgressBar;

  /// No description provided for @reader_settings_showTime.
  ///
  /// In zh, this message translates to:
  /// **'显示时间'**
  String get reader_settings_showTime;

  /// No description provided for @reader_settings_small.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get reader_settings_small;

  /// No description provided for @reader_settings_title.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get reader_settings_title;

  /// No description provided for @reader_tags.
  ///
  /// In zh, this message translates to:
  /// **'标签（可选）'**
  String get reader_tags;

  /// No description provided for @reader_tagsHint.
  ///
  /// In zh, this message translates to:
  /// **'用逗号分隔，如：重要,伏笔'**
  String get reader_tagsHint;

  /// No description provided for @reader_wordCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String reader_wordCount(Object count);

  /// No description provided for @reading_addBookmark.
  ///
  /// In zh, this message translates to:
  /// **'添加书签'**
  String get reading_addBookmark;

  /// No description provided for @reading_addNote.
  ///
  /// In zh, this message translates to:
  /// **'添加笔记'**
  String get reading_addNote;

  /// No description provided for @reading_addNoteLabel.
  ///
  /// In zh, this message translates to:
  /// **'添加笔记'**
  String get reading_addNoteLabel;

  /// No description provided for @reading_autoScroll.
  ///
  /// In zh, this message translates to:
  /// **'自动翻页'**
  String get reading_autoScroll;

  /// No description provided for @reading_autoScrollSpeed.
  ///
  /// In zh, this message translates to:
  /// **'{speed} 字/秒'**
  String reading_autoScrollSpeed(Object speed);

  /// No description provided for @reading_backgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'背景颜色'**
  String get reading_backgroundColor;

  /// No description provided for @reading_backgroundLabel.
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get reading_backgroundLabel;

  /// No description provided for @reading_bookmarkAdded.
  ///
  /// In zh, this message translates to:
  /// **'书签已添加'**
  String get reading_bookmarkAdded;

  /// No description provided for @reading_bookmarkLocation.
  ///
  /// In zh, this message translates to:
  /// **'位置：第 {order} 章，{position} 字'**
  String reading_bookmarkLocation(Object order, Object position);

  /// No description provided for @reading_bookmarkNote.
  ///
  /// In zh, this message translates to:
  /// **'笔记（可选）'**
  String get reading_bookmarkNote;

  /// No description provided for @reading_bookmarkNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'为这个书签添加备注...'**
  String get reading_bookmarkNoteHint;

  /// No description provided for @reading_chapterList.
  ///
  /// In zh, this message translates to:
  /// **'章节列表'**
  String get reading_chapterList;

  /// No description provided for @reading_chapterNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {order} 章'**
  String reading_chapterNumber(Object order);

  /// No description provided for @reading_close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get reading_close;

  /// No description provided for @reading_compact.
  ///
  /// In zh, this message translates to:
  /// **'紧凑'**
  String get reading_compact;

  /// No description provided for @reading_copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get reading_copied;

  /// No description provided for @reading_displaySettings.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get reading_displaySettings;

  /// No description provided for @reading_enterNoteContent.
  ///
  /// In zh, this message translates to:
  /// **'请输入笔记内容'**
  String get reading_enterNoteContent;

  /// No description provided for @reading_firstChapter.
  ///
  /// In zh, this message translates to:
  /// **'已经是第一章了'**
  String get reading_firstChapter;

  /// No description provided for @reading_font.
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get reading_font;

  /// No description provided for @reading_fontDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get reading_fontDefault;

  /// No description provided for @reading_fontFang.
  ///
  /// In zh, this message translates to:
  /// **'仿宋'**
  String get reading_fontFang;

  /// No description provided for @reading_fontKai.
  ///
  /// In zh, this message translates to:
  /// **'楷体'**
  String get reading_fontKai;

  /// No description provided for @reading_fontSans.
  ///
  /// In zh, this message translates to:
  /// **'黑体'**
  String get reading_fontSans;

  /// No description provided for @reading_fontSerif.
  ///
  /// In zh, this message translates to:
  /// **'宋体'**
  String get reading_fontSerif;

  /// No description provided for @reading_fontSize.
  ///
  /// In zh, this message translates to:
  /// **'字体大小: {size}'**
  String reading_fontSize(Object size);

  /// No description provided for @reading_fontSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get reading_fontSizeLabel;

  /// No description provided for @reading_highlightAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加高亮'**
  String get reading_highlightAdded;

  /// No description provided for @reading_highlightColor.
  ///
  /// In zh, this message translates to:
  /// **'高亮颜色'**
  String get reading_highlightColor;

  /// No description provided for @reading_large.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get reading_large;

  /// No description provided for @reading_lastChapter.
  ///
  /// In zh, this message translates to:
  /// **'已经是最后一章了'**
  String get reading_lastChapter;

  /// No description provided for @reading_lineHeight.
  ///
  /// In zh, this message translates to:
  /// **'行高: {height}'**
  String reading_lineHeight(Object height);

  /// No description provided for @reading_lineHeightLabel.
  ///
  /// In zh, this message translates to:
  /// **'行高'**
  String get reading_lineHeightLabel;

  /// No description provided for @reading_loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String reading_loadFailed(Object error);

  /// No description provided for @reading_loose.
  ///
  /// In zh, this message translates to:
  /// **'宽松'**
  String get reading_loose;

  /// No description provided for @reading_noteContent.
  ///
  /// In zh, this message translates to:
  /// **'笔记内容'**
  String get reading_noteContent;

  /// No description provided for @reading_noteHint.
  ///
  /// In zh, this message translates to:
  /// **'输入你的想法...'**
  String get reading_noteHint;

  /// No description provided for @reading_noteSaved.
  ///
  /// In zh, this message translates to:
  /// **'笔记已保存'**
  String get reading_noteSaved;

  /// No description provided for @reading_pageMargin.
  ///
  /// In zh, this message translates to:
  /// **'页边距: {margin}'**
  String reading_pageMargin(Object margin);

  /// No description provided for @reading_pageMarginLabel.
  ///
  /// In zh, this message translates to:
  /// **'页边距'**
  String get reading_pageMarginLabel;

  /// No description provided for @reading_reading.
  ///
  /// In zh, this message translates to:
  /// **'阅读中'**
  String get reading_reading;

  /// No description provided for @reading_readingSettings.
  ///
  /// In zh, this message translates to:
  /// **'阅读设置'**
  String get reading_readingSettings;

  /// No description provided for @reading_readingToolbar.
  ///
  /// In zh, this message translates to:
  /// **'阅读工具栏'**
  String get reading_readingToolbar;

  /// No description provided for @reading_retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get reading_retry;

  /// No description provided for @reading_saveBookmark.
  ///
  /// In zh, this message translates to:
  /// **'保存书签'**
  String get reading_saveBookmark;

  /// No description provided for @reading_screenOrientation.
  ///
  /// In zh, this message translates to:
  /// **'屏幕方向'**
  String get reading_screenOrientation;

  /// No description provided for @reading_selectChapter.
  ///
  /// In zh, this message translates to:
  /// **'选择章节'**
  String get reading_selectChapter;

  /// No description provided for @reading_showProgressBar.
  ///
  /// In zh, this message translates to:
  /// **'显示进度条'**
  String get reading_showProgressBar;

  /// No description provided for @reading_showTime.
  ///
  /// In zh, this message translates to:
  /// **'显示时间'**
  String get reading_showTime;

  /// No description provided for @reading_small.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get reading_small;

  /// No description provided for @reading_tags.
  ///
  /// In zh, this message translates to:
  /// **'标签（可选）'**
  String get reading_tags;

  /// No description provided for @reading_tagsHint.
  ///
  /// In zh, this message translates to:
  /// **'用逗号分隔，如：重要,伏笔'**
  String get reading_tagsHint;

  /// No description provided for @reading_words.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String reading_words(Object count);

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @remark.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get remark;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @review_aiAnalyzing.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析中...'**
  String get review_aiAnalyzing;

  /// No description provided for @review_aiStyleLabel.
  ///
  /// In zh, this message translates to:
  /// **'AI口吻'**
  String get review_aiStyleLabel;

  /// No description provided for @review_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get review_all;

  /// No description provided for @review_allChapters.
  ///
  /// In zh, this message translates to:
  /// **'全部章节'**
  String get review_allChapters;

  /// No description provided for @review_allChaptersScope.
  ///
  /// In zh, this message translates to:
  /// **'全部章节'**
  String get review_allChaptersScope;

  /// No description provided for @review_autoReview.
  ///
  /// In zh, this message translates to:
  /// **'自动审查'**
  String get review_autoReview;

  /// No description provided for @review_autoReviewDesc.
  ///
  /// In zh, this message translates to:
  /// **'章节保存后自动触发审查'**
  String get review_autoReviewDesc;

  /// No description provided for @review_center_title.
  ///
  /// In zh, this message translates to:
  /// **'审查中心'**
  String get review_center_title;

  /// No description provided for @review_characterOOCLabel.
  ///
  /// In zh, this message translates to:
  /// **'角色OOC'**
  String get review_characterOOCLabel;

  /// No description provided for @review_completed.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get review_completed;

  /// No description provided for @review_comprehensive.
  ///
  /// In zh, this message translates to:
  /// **'全面'**
  String get review_comprehensive;

  /// No description provided for @review_comprehensiveDesc.
  ///
  /// In zh, this message translates to:
  /// **'最全面的审查，包括伏笔和主题分析'**
  String get review_comprehensiveDesc;

  /// No description provided for @review_configSaved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get review_configSaved;

  /// No description provided for @review_configTitle.
  ///
  /// In zh, this message translates to:
  /// **'审查配置'**
  String get review_configTitle;

  /// No description provided for @review_config_autoReview.
  ///
  /// In zh, this message translates to:
  /// **'自动审查'**
  String get review_config_autoReview;

  /// No description provided for @review_config_autoReviewSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'章节保存后自动触发审查'**
  String get review_config_autoReviewSubtitle;

  /// No description provided for @review_config_depth.
  ///
  /// In zh, this message translates to:
  /// **'审查深度'**
  String get review_config_depth;

  /// No description provided for @review_config_depthDescription_1.
  ///
  /// In zh, this message translates to:
  /// **'仅检查基本错误和格式问题'**
  String get review_config_depthDescription_1;

  /// No description provided for @review_config_depthDescription_2.
  ///
  /// In zh, this message translates to:
  /// **'检查设定一致性和基本逻辑'**
  String get review_config_depthDescription_2;

  /// No description provided for @review_config_depthDescription_3.
  ///
  /// In zh, this message translates to:
  /// **'深入分析角色行为和剧情发展'**
  String get review_config_depthDescription_3;

  /// No description provided for @review_config_depthDescription_4.
  ///
  /// In zh, this message translates to:
  /// **'全面审查包括文风和节奏'**
  String get review_config_depthDescription_4;

  /// No description provided for @review_config_depthDescription_5.
  ///
  /// In zh, this message translates to:
  /// **'最全面的审查，包括伏笔和主题分析'**
  String get review_config_depthDescription_5;

  /// No description provided for @review_config_depth_comprehensive.
  ///
  /// In zh, this message translates to:
  /// **'全面'**
  String get review_config_depth_comprehensive;

  /// No description provided for @review_config_depth_deep.
  ///
  /// In zh, this message translates to:
  /// **'深入'**
  String get review_config_depth_deep;

  /// No description provided for @review_config_depth_detailed.
  ///
  /// In zh, this message translates to:
  /// **'详细'**
  String get review_config_depth_detailed;

  /// No description provided for @review_config_depth_quick.
  ///
  /// In zh, this message translates to:
  /// **'快速'**
  String get review_config_depth_quick;

  /// No description provided for @review_config_depth_standard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get review_config_depth_standard;

  /// No description provided for @review_config_notifications.
  ///
  /// In zh, this message translates to:
  /// **'启用通知'**
  String get review_config_notifications;

  /// No description provided for @review_config_notificationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'审查完成后显示通知'**
  String get review_config_notificationsSubtitle;

  /// No description provided for @review_config_saved.
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get review_config_saved;

  /// No description provided for @review_config_title.
  ///
  /// In zh, this message translates to:
  /// **'审查配置'**
  String get review_config_title;

  /// No description provided for @review_consistencyLabel.
  ///
  /// In zh, this message translates to:
  /// **'设定一致性'**
  String get review_consistencyLabel;

  /// No description provided for @review_critical.
  ///
  /// In zh, this message translates to:
  /// **'严重'**
  String get review_critical;

  /// No description provided for @review_currentVolume.
  ///
  /// In zh, this message translates to:
  /// **'当前卷'**
  String get review_currentVolume;

  /// No description provided for @review_detailed.
  ///
  /// In zh, this message translates to:
  /// **'详细'**
  String get review_detailed;

  /// No description provided for @review_detailedDesc.
  ///
  /// In zh, this message translates to:
  /// **'深入分析角色行为和剧情发展'**
  String get review_detailedDesc;

  /// No description provided for @review_dimension.
  ///
  /// In zh, this message translates to:
  /// **'维度'**
  String get review_dimension;

  /// No description provided for @review_dimensionScore.
  ///
  /// In zh, this message translates to:
  /// **'维度评分'**
  String get review_dimensionScore;

  /// No description provided for @review_dimensionScores.
  ///
  /// In zh, this message translates to:
  /// **'维度评分'**
  String get review_dimensionScores;

  /// No description provided for @review_enableNotifications.
  ///
  /// In zh, this message translates to:
  /// **'启用通知'**
  String get review_enableNotifications;

  /// No description provided for @review_enableNotificationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'审查完成后显示通知'**
  String get review_enableNotificationsDesc;

  /// No description provided for @review_filter_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get review_filter_all;

  /// No description provided for @review_filter_dimension.
  ///
  /// In zh, this message translates to:
  /// **'维度'**
  String get review_filter_dimension;

  /// No description provided for @review_filter_fixed.
  ///
  /// In zh, this message translates to:
  /// **'已修复'**
  String get review_filter_fixed;

  /// No description provided for @review_filter_ignored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get review_filter_ignored;

  /// No description provided for @review_filter_pending.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get review_filter_pending;

  /// No description provided for @review_filter_severity.
  ///
  /// In zh, this message translates to:
  /// **'严重程度'**
  String get review_filter_severity;

  /// No description provided for @review_filter_status.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get review_filter_status;

  /// No description provided for @review_firstVolume.
  ///
  /// In zh, this message translates to:
  /// **'第一卷'**
  String get review_firstVolume;

  /// No description provided for @review_fixed.
  ///
  /// In zh, this message translates to:
  /// **'已修复'**
  String get review_fixed;

  /// No description provided for @review_generatingReport.
  ///
  /// In zh, this message translates to:
  /// **'生成报告...'**
  String get review_generatingReport;

  /// No description provided for @review_good.
  ///
  /// In zh, this message translates to:
  /// **'良好'**
  String get review_good;

  /// No description provided for @review_ignore.
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get review_ignore;

  /// No description provided for @review_ignored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get review_ignored;

  /// No description provided for @review_inDepth.
  ///
  /// In zh, this message translates to:
  /// **'深入'**
  String get review_inDepth;

  /// No description provided for @review_inDepthDesc.
  ///
  /// In zh, this message translates to:
  /// **'全面审查包括文风和节奏'**
  String get review_inDepthDesc;

  /// No description provided for @review_issueCard_ignore.
  ///
  /// In zh, this message translates to:
  /// **'忽略'**
  String get review_issueCard_ignore;

  /// No description provided for @review_issueCard_view.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get review_issueCard_view;

  /// No description provided for @review_issueCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个问题'**
  String review_issueCount(Object count);

  /// No description provided for @review_issueDesc.
  ///
  /// In zh, this message translates to:
  /// **'这是第 {number} 个问题的描述，显示问题详情。'**
  String review_issueDesc(Object number);

  /// No description provided for @review_issueDescription.
  ///
  /// In zh, this message translates to:
  /// **'这是第 {number} 个问题的描述，显示问题详情。'**
  String review_issueDescription(Object number);

  /// No description provided for @review_issueList.
  ///
  /// In zh, this message translates to:
  /// **'问题列表'**
  String get review_issueList;

  /// No description provided for @review_issueLocation.
  ///
  /// In zh, this message translates to:
  /// **'第{chapter}章'**
  String review_issueLocation(Object chapter);

  /// No description provided for @review_loadingChapters.
  ///
  /// In zh, this message translates to:
  /// **'加载章节内容...'**
  String get review_loadingChapters;

  /// No description provided for @review_location.
  ///
  /// In zh, this message translates to:
  /// **'第{chapter}章'**
  String review_location(Object chapter);

  /// No description provided for @review_major.
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get review_major;

  /// No description provided for @review_minor.
  ///
  /// In zh, this message translates to:
  /// **'轻微'**
  String get review_minor;

  /// No description provided for @review_overallScore.
  ///
  /// In zh, this message translates to:
  /// **'综合评分'**
  String get review_overallScore;

  /// No description provided for @review_overview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get review_overview;

  /// No description provided for @review_pacingLabel.
  ///
  /// In zh, this message translates to:
  /// **'节奏把控'**
  String get review_pacingLabel;

  /// No description provided for @review_passedChapters.
  ///
  /// In zh, this message translates to:
  /// **'已通过章节'**
  String get review_passedChapters;

  /// No description provided for @review_pending.
  ///
  /// In zh, this message translates to:
  /// **'待处理'**
  String get review_pending;

  /// No description provided for @review_plotLogicLabel.
  ///
  /// In zh, this message translates to:
  /// **'剧情逻辑'**
  String get review_plotLogicLabel;

  /// No description provided for @review_preparingReview.
  ///
  /// In zh, this message translates to:
  /// **'准备审查...'**
  String get review_preparingReview;

  /// No description provided for @review_progressAnalyzing.
  ///
  /// In zh, this message translates to:
  /// **'AI 分析中...'**
  String get review_progressAnalyzing;

  /// No description provided for @review_progressCompleted.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get review_progressCompleted;

  /// No description provided for @review_progressFinished.
  ///
  /// In zh, this message translates to:
  /// **'审查完成！'**
  String get review_progressFinished;

  /// No description provided for @review_progressGenerating.
  ///
  /// In zh, this message translates to:
  /// **'生成报告...'**
  String get review_progressGenerating;

  /// No description provided for @review_progressLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载章节内容...'**
  String get review_progressLoading;

  /// No description provided for @review_progressPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备审查...'**
  String get review_progressPreparing;

  /// No description provided for @review_progress_result.
  ///
  /// In zh, this message translates to:
  /// **'审查完成，请在问题列表中查看结果'**
  String get review_progress_result;

  /// No description provided for @review_progress_title.
  ///
  /// In zh, this message translates to:
  /// **'审查进行中'**
  String get review_progress_title;

  /// No description provided for @review_progress_viewResult.
  ///
  /// In zh, this message translates to:
  /// **'查看结果'**
  String get review_progress_viewResult;

  /// No description provided for @review_quick.
  ///
  /// In zh, this message translates to:
  /// **'快速'**
  String get review_quick;

  /// No description provided for @review_quickDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅检查基本错误和格式问题'**
  String get review_quickDesc;

  /// No description provided for @review_quickReview.
  ///
  /// In zh, this message translates to:
  /// **'快速审查'**
  String get review_quickReview;

  /// No description provided for @review_quickReviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'快速审查'**
  String get review_quickReviewTitle;

  /// No description provided for @review_quickReview_title.
  ///
  /// In zh, this message translates to:
  /// **'快速审查'**
  String get review_quickReview_title;

  /// No description provided for @review_reviewCenter.
  ///
  /// In zh, this message translates to:
  /// **'审查中心'**
  String get review_reviewCenter;

  /// No description provided for @review_reviewCompleted.
  ///
  /// In zh, this message translates to:
  /// **'审查完成！'**
  String get review_reviewCompleted;

  /// No description provided for @review_reviewCompletedDesc.
  ///
  /// In zh, this message translates to:
  /// **'审查完成，请在问题列表中查看结果'**
  String get review_reviewCompletedDesc;

  /// No description provided for @review_reviewDepth.
  ///
  /// In zh, this message translates to:
  /// **'审查深度'**
  String get review_reviewDepth;

  /// No description provided for @review_reviewDimensions.
  ///
  /// In zh, this message translates to:
  /// **'审查维度'**
  String get review_reviewDimensions;

  /// No description provided for @review_reviewInProgress.
  ///
  /// In zh, this message translates to:
  /// **'审查进行中'**
  String get review_reviewInProgress;

  /// No description provided for @review_reviewScope.
  ///
  /// In zh, this message translates to:
  /// **'审查范围'**
  String get review_reviewScope;

  /// No description provided for @review_scope_all.
  ///
  /// In zh, this message translates to:
  /// **'全部章节'**
  String get review_scope_all;

  /// No description provided for @review_scope_chapter.
  ///
  /// In zh, this message translates to:
  /// **'指定章节'**
  String get review_scope_chapter;

  /// No description provided for @review_scope_volume.
  ///
  /// In zh, this message translates to:
  /// **'当前卷'**
  String get review_scope_volume;

  /// No description provided for @review_scoreLabel.
  ///
  /// In zh, this message translates to:
  /// **'{score} 分'**
  String review_scoreLabel(Object score);

  /// No description provided for @review_score_good.
  ///
  /// In zh, this message translates to:
  /// **'良好'**
  String get review_score_good;

  /// No description provided for @review_score_points.
  ///
  /// In zh, this message translates to:
  /// **'{score} 分'**
  String review_score_points(Object score);

  /// No description provided for @review_secondVolume.
  ///
  /// In zh, this message translates to:
  /// **'第二卷'**
  String get review_secondVolume;

  /// No description provided for @review_severity.
  ///
  /// In zh, this message translates to:
  /// **'严重程度'**
  String get review_severity;

  /// No description provided for @review_severity_critical.
  ///
  /// In zh, this message translates to:
  /// **'严重'**
  String get review_severity_critical;

  /// No description provided for @review_severity_major.
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get review_severity_major;

  /// No description provided for @review_severity_minor.
  ///
  /// In zh, this message translates to:
  /// **'轻微'**
  String get review_severity_minor;

  /// No description provided for @review_specifiedChapter.
  ///
  /// In zh, this message translates to:
  /// **'指定章节'**
  String get review_specifiedChapter;

  /// No description provided for @review_spellingLabel.
  ///
  /// In zh, this message translates to:
  /// **'错别字'**
  String get review_spellingLabel;

  /// No description provided for @review_standard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get review_standard;

  /// No description provided for @review_standardDesc.
  ///
  /// In zh, this message translates to:
  /// **'检查设定一致性和基本逻辑'**
  String get review_standardDesc;

  /// No description provided for @review_startReview.
  ///
  /// In zh, this message translates to:
  /// **'开始审查'**
  String get review_startReview;

  /// No description provided for @review_statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get review_statistics;

  /// No description provided for @review_statistics_placeholder.
  ///
  /// In zh, this message translates to:
  /// **'统计分析将在这里显示'**
  String get review_statistics_placeholder;

  /// No description provided for @review_status.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get review_status;

  /// No description provided for @review_tab_issues.
  ///
  /// In zh, this message translates to:
  /// **'问题列表'**
  String get review_tab_issues;

  /// No description provided for @review_tab_overview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get review_tab_overview;

  /// No description provided for @review_tab_statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get review_tab_statistics;

  /// No description provided for @review_view.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get review_view;

  /// No description provided for @review_viewResults.
  ///
  /// In zh, this message translates to:
  /// **'查看结果'**
  String get review_viewResults;

  /// No description provided for @review_volume.
  ///
  /// In zh, this message translates to:
  /// **'第一卷'**
  String get review_volume;

  /// No description provided for @review_volume2.
  ///
  /// In zh, this message translates to:
  /// **'第二卷'**
  String get review_volume2;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saved;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @selectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAll;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settings_addChildLocation.
  ///
  /// In zh, this message translates to:
  /// **'添加子地点'**
  String get settings_addChildLocation;

  /// No description provided for @settings_addFaction.
  ///
  /// In zh, this message translates to:
  /// **'添加势力'**
  String get settings_addFaction;

  /// No description provided for @settings_addItem.
  ///
  /// In zh, this message translates to:
  /// **'添加物品'**
  String get settings_addItem;

  /// No description provided for @settings_addLocation.
  ///
  /// In zh, this message translates to:
  /// **'添加地点'**
  String get settings_addLocation;

  /// No description provided for @settings_addRelationship.
  ///
  /// In zh, this message translates to:
  /// **'添加关系'**
  String get settings_addRelationship;

  /// No description provided for @settings_affection.
  ///
  /// In zh, this message translates to:
  /// **'好感'**
  String get settings_affection;

  /// No description provided for @settings_mergeDuplicates.
  ///
  /// In zh, this message translates to:
  /// **'合并重复地点'**
  String get settings_mergeDuplicates;

  /// No description provided for @settings_noDuplicatesFound.
  ///
  /// In zh, this message translates to:
  /// **'未发现重复地点'**
  String get settings_noDuplicatesFound;

  /// No description provided for @settings_selectKeepLocation.
  ///
  /// In zh, this message translates to:
  /// **'选择要保留的地点'**
  String get settings_selectKeepLocation;

  /// No description provided for @settings_mergeConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认合并'**
  String get settings_mergeConfirm;

  /// No description provided for @settings_mergeDesc.
  ///
  /// In zh, this message translates to:
  /// **'将重复地点合并为一个，关联数据会自动转移'**
  String get settings_mergeDesc;

  /// No description provided for @settings_age.
  ///
  /// In zh, this message translates to:
  /// **'年龄'**
  String get settings_age;

  /// No description provided for @settings_ageHint.
  ///
  /// In zh, this message translates to:
  /// **'如：25岁 / 未知'**
  String get settings_ageHint;

  /// No description provided for @settings_aiConfig.
  ///
  /// In zh, this message translates to:
  /// **'AI 配置'**
  String get settings_aiConfig;

  /// No description provided for @settings_aiConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'模型、提示词和调用统计。'**
  String get settings_aiConfigSubtitle;

  /// No description provided for @settings_aiUsageStats.
  ///
  /// In zh, this message translates to:
  /// **'AI 使用统计'**
  String get settings_aiUsageStats;

  /// No description provided for @settings_aiUsageStatsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看 token、调用次数和成本。'**
  String get settings_aiUsageStatsSubtitle;

  /// No description provided for @settings_aliases.
  ///
  /// In zh, this message translates to:
  /// **'别名/称号'**
  String get settings_aliases;

  /// No description provided for @settings_aliasesHint.
  ///
  /// In zh, this message translates to:
  /// **'多个别名用逗号分隔'**
  String get settings_aliasesHint;

  /// No description provided for @settings_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get settings_all;

  /// No description provided for @settings_allTypes.
  ///
  /// In zh, this message translates to:
  /// **'全部类型'**
  String get settings_allTypes;

  /// No description provided for @settings_analysisEntry.
  ///
  /// In zh, this message translates to:
  /// **'分析入口'**
  String get settings_analysisEntry;

  /// No description provided for @settings_analysisEntrySubtitle.
  ///
  /// In zh, this message translates to:
  /// **'统计、审查和时间线。'**
  String get settings_analysisEntrySubtitle;

  /// No description provided for @settings_archive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get settings_archive;

  /// No description provided for @settings_archiveCharacter.
  ///
  /// In zh, this message translates to:
  /// **'归档角色'**
  String get settings_archiveCharacter;

  /// No description provided for @settings_archiveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要归档 {name} 吗？归档后将从主列表中隐藏。'**
  String settings_archiveConfirm(Object name);

  /// No description provided for @settings_archived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get settings_archived;

  /// No description provided for @settings_basicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get settings_basicInfo;

  /// No description provided for @settings_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get settings_cancel;

  /// No description provided for @settings_changeHistory.
  ///
  /// In zh, this message translates to:
  /// **'变更历史'**
  String get settings_changeHistory;

  /// No description provided for @settings_changeLifeStatus.
  ///
  /// In zh, this message translates to:
  /// **'更改生命状态'**
  String get settings_changeLifeStatus;

  /// No description provided for @settings_characterA.
  ///
  /// In zh, this message translates to:
  /// **'角色 A'**
  String get settings_characterA;

  /// No description provided for @settings_characterB.
  ///
  /// In zh, this message translates to:
  /// **'角色 B'**
  String get settings_characterB;

  /// No description provided for @settings_characterBio.
  ///
  /// In zh, this message translates to:
  /// **'角色简介'**
  String get settings_characterBio;

  /// No description provided for @settings_characterBioHint.
  ///
  /// In zh, this message translates to:
  /// **'简要描述角色背景'**
  String get settings_characterBioHint;

  /// No description provided for @settings_characterList.
  ///
  /// In zh, this message translates to:
  /// **'角色列表'**
  String get settings_characterList;

  /// No description provided for @settings_characterListSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'进入角色档案和角色卡片列表。'**
  String get settings_characterListSubtitle;

  /// No description provided for @settings_characterListTooltip.
  ///
  /// In zh, this message translates to:
  /// **'角色列表'**
  String get settings_characterListTooltip;

  /// No description provided for @settings_characterManagement.
  ///
  /// In zh, this message translates to:
  /// **'角色管理'**
  String get settings_characterManagement;

  /// No description provided for @settings_characterManagementTitle.
  ///
  /// In zh, this message translates to:
  /// **'角色管理'**
  String get settings_characterManagementTitle;

  /// No description provided for @settings_characterName.
  ///
  /// In zh, this message translates to:
  /// **'角色名称'**
  String get settings_characterName;

  /// No description provided for @settings_characterRelations.
  ///
  /// In zh, this message translates to:
  /// **'角色关系'**
  String get settings_characterRelations;

  /// No description provided for @settings_characterRelationsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'角色、关系链路和生命状态。'**
  String get settings_characterRelationsSubtitle;

  /// No description provided for @settings_characterTier.
  ///
  /// In zh, this message translates to:
  /// **'角色分级'**
  String get settings_characterTier;

  /// No description provided for @settings_confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get settings_confirm;

  /// No description provided for @settings_create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get settings_create;

  /// No description provided for @settings_createFaction.
  ///
  /// In zh, this message translates to:
  /// **'创建势力'**
  String get settings_createFaction;

  /// No description provided for @settings_createFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败: {error}'**
  String settings_createFailed(Object error);

  /// No description provided for @settings_createItem.
  ///
  /// In zh, this message translates to:
  /// **'创建物品'**
  String get settings_createItem;

  /// No description provided for @settings_createLocation.
  ///
  /// In zh, this message translates to:
  /// **'创建地点'**
  String get settings_createLocation;

  /// No description provided for @settings_createRelationshipTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建角色关系'**
  String get settings_createRelationshipTitle;

  /// No description provided for @settings_cropAvatar.
  ///
  /// In zh, this message translates to:
  /// **'裁剪头像'**
  String get settings_cropAvatar;

  /// No description provided for @settings_deleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败: {error}'**
  String settings_deleteFailed(Object error);

  /// No description provided for @settings_deleteRelationship.
  ///
  /// In zh, this message translates to:
  /// **'删除关系'**
  String get settings_deleteRelationship;

  /// No description provided for @settings_deleteRelationshipConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这个关系吗？此操作不可撤销，相关的历史记录也会被删除。'**
  String get settings_deleteRelationshipConfirm;

  /// No description provided for @settings_detailInfo.
  ///
  /// In zh, this message translates to:
  /// **'详细信息'**
  String get settings_detailInfo;

  /// No description provided for @settings_edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get settings_edit;

  /// No description provided for @settings_editCharacter.
  ///
  /// In zh, this message translates to:
  /// **'编辑角色'**
  String get settings_editCharacter;

  /// No description provided for @settings_editRelationshipTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑角色关系'**
  String get settings_editRelationshipTitle;

  /// No description provided for @settings_emotionalDimensionBar.
  ///
  /// In zh, this message translates to:
  /// **'情感维度条'**
  String get settings_emotionalDimensionBar;

  /// No description provided for @settings_emotionalDimensions.
  ///
  /// In zh, this message translates to:
  /// **'情感维度'**
  String get settings_emotionalDimensions;

  /// No description provided for @settings_enterCharacterName.
  ///
  /// In zh, this message translates to:
  /// **'输入角色名称'**
  String get settings_enterCharacterName;

  /// No description provided for @settings_eventCountChanges.
  ///
  /// In zh, this message translates to:
  /// **'{count}次变化'**
  String settings_eventCountChanges(Object count);

  /// No description provided for @settings_factionCard.
  ///
  /// In zh, this message translates to:
  /// **'势力卡片'**
  String get settings_factionCard;

  /// No description provided for @settings_factionListTitle.
  ///
  /// In zh, this message translates to:
  /// **'势力/组织'**
  String get settings_factionListTitle;

  /// No description provided for @settings_factionManagement.
  ///
  /// In zh, this message translates to:
  /// **'势力管理'**
  String get settings_factionManagement;

  /// No description provided for @settings_factionManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理组织、阵营和政治结构。'**
  String get settings_factionManagementSubtitle;

  /// No description provided for @settings_fear.
  ///
  /// In zh, this message translates to:
  /// **'恐惧'**
  String get settings_fear;

  /// No description provided for @settings_firstAppeared.
  ///
  /// In zh, this message translates to:
  /// **'首次出现: {date}'**
  String settings_firstAppeared(Object date);

  /// No description provided for @settings_fromChange.
  ///
  /// In zh, this message translates to:
  /// **'从 {fromType} 变更'**
  String settings_fromChange(Object fromType);

  /// No description provided for @settings_gender.
  ///
  /// In zh, this message translates to:
  /// **'性别'**
  String get settings_gender;

  /// No description provided for @settings_hideArchived.
  ///
  /// In zh, this message translates to:
  /// **'隐藏归档'**
  String get settings_hideArchived;

  /// No description provided for @settings_identity.
  ///
  /// In zh, this message translates to:
  /// **'身份'**
  String get settings_identity;

  /// No description provided for @settings_identityHint.
  ///
  /// In zh, this message translates to:
  /// **'如：青云门大弟子'**
  String get settings_identityHint;

  /// No description provided for @settings_itemCard.
  ///
  /// In zh, this message translates to:
  /// **'物品卡片'**
  String get settings_itemCard;

  /// No description provided for @settings_itemListTitle.
  ///
  /// In zh, this message translates to:
  /// **'物品管理'**
  String get settings_itemListTitle;

  /// No description provided for @settings_itemManagement.
  ///
  /// In zh, this message translates to:
  /// **'物件管理'**
  String get settings_itemManagement;

  /// No description provided for @settings_itemManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'整理武器、道具和关键物品。'**
  String get settings_itemManagementSubtitle;

  /// No description provided for @settings_lastUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新: {date}'**
  String settings_lastUpdated(Object date);

  /// No description provided for @settings_lifeStatus.
  ///
  /// In zh, this message translates to:
  /// **'生命状态'**
  String get settings_lifeStatus;

  /// No description provided for @settings_listView.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get settings_listView;

  /// No description provided for @settings_listViewTitle.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get settings_listViewTitle;

  /// No description provided for @settings_loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败: {error}'**
  String settings_loadFailed(Object error);

  /// No description provided for @settings_locationListTitle.
  ///
  /// In zh, this message translates to:
  /// **'地点管理'**
  String get settings_locationListTitle;

  /// No description provided for @settings_locationManagement.
  ///
  /// In zh, this message translates to:
  /// **'地点管理'**
  String get settings_locationManagement;

  /// No description provided for @settings_locationManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'组织城市、场景和地理层级。'**
  String get settings_locationManagementSubtitle;

  /// No description provided for @settings_locationTreeNode.
  ///
  /// In zh, this message translates to:
  /// **'地点树节点'**
  String get settings_locationTreeNode;

  /// No description provided for @settings_markAsStatus.
  ///
  /// In zh, this message translates to:
  /// **'已将 {name} 标记为 {status}'**
  String settings_markAsStatus(Object name, Object status);

  /// No description provided for @settings_modelConfig.
  ///
  /// In zh, this message translates to:
  /// **'模型配置'**
  String get settings_modelConfig;

  /// No description provided for @settings_modelConfigSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理 AI 提供商、API Key 和参数。'**
  String get settings_modelConfigSubtitle;

  /// No description provided for @settings_newCharacter.
  ///
  /// In zh, this message translates to:
  /// **'新建角色'**
  String get settings_newCharacter;

  /// No description provided for @settings_newRelationship.
  ///
  /// In zh, this message translates to:
  /// **'新建关系'**
  String get settings_newRelationship;

  /// No description provided for @settings_noChangeRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无变更记录'**
  String get settings_noChangeRecords;

  /// No description provided for @settings_noCharactersCreated.
  ///
  /// In zh, this message translates to:
  /// **'还没有创建角色'**
  String get settings_noCharactersCreated;

  /// No description provided for @settings_noFactionsCreated.
  ///
  /// In zh, this message translates to:
  /// **'还没有创建势力'**
  String get settings_noFactionsCreated;

  /// No description provided for @settings_noItemsCreated.
  ///
  /// In zh, this message translates to:
  /// **'还没有创建物品'**
  String get settings_noItemsCreated;

  /// No description provided for @settings_noLocationsCreated.
  ///
  /// In zh, this message translates to:
  /// **'还没有创建地点'**
  String get settings_noLocationsCreated;

  /// No description provided for @settings_noMatchingCharacters.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的角色'**
  String get settings_noMatchingCharacters;

  /// No description provided for @settings_noRelationshipsCreated.
  ///
  /// In zh, this message translates to:
  /// **'还没有创建角色关系'**
  String get settings_noRelationshipsCreated;

  /// No description provided for @settings_noRelationshipsYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有建立关系'**
  String get settings_noRelationshipsYet;

  /// No description provided for @settings_openReadingMode.
  ///
  /// In zh, this message translates to:
  /// **'打开阅读模式'**
  String get settings_openReadingMode;

  /// No description provided for @settings_openReadingModeDescription.
  ///
  /// In zh, this message translates to:
  /// **'直接进入沉浸式阅读界面。'**
  String get settings_openReadingModeDescription;

  /// No description provided for @settings_operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败: {error}'**
  String settings_operationFailed(Object error);

  /// No description provided for @settings_peopleCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人'**
  String settings_peopleCount(Object count);

  /// No description provided for @settings_pleaseEnterCharacterName.
  ///
  /// In zh, this message translates to:
  /// **'请输入角色名称'**
  String get settings_pleaseEnterCharacterName;

  /// No description provided for @settings_povGeneration.
  ///
  /// In zh, this message translates to:
  /// **'POV 生成'**
  String get settings_povGeneration;

  /// No description provided for @settings_povGenerationDescription.
  ///
  /// In zh, this message translates to:
  /// **'从角色视角重写章节片段。'**
  String get settings_povGenerationDescription;

  /// No description provided for @settings_profileRequired.
  ///
  /// In zh, this message translates to:
  /// **'此角色需要完善深度档案，包括性格特质、说话风格、行为习惯等'**
  String get settings_profileRequired;

  /// No description provided for @settings_quickActions.
  ///
  /// In zh, this message translates to:
  /// **'Quick actions'**
  String get settings_quickActions;

  /// No description provided for @settings_rarity.
  ///
  /// In zh, this message translates to:
  /// **'品级'**
  String get settings_rarity;

  /// No description provided for @settings_rarityBadge.
  ///
  /// In zh, this message translates to:
  /// **'品级徽章'**
  String get settings_rarityBadge;

  /// No description provided for @settings_reason.
  ///
  /// In zh, this message translates to:
  /// **'原因: {reason}'**
  String settings_reason(Object reason);

  /// No description provided for @settings_recentSearches.
  ///
  /// In zh, this message translates to:
  /// **'最近搜索'**
  String get settings_recentSearches;

  /// No description provided for @settings_recentlyUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新于 {date}'**
  String settings_recentlyUpdated(Object date);

  /// No description provided for @settings_relationshipCard.
  ///
  /// In zh, this message translates to:
  /// **'关系卡片'**
  String get settings_relationshipCard;

  /// No description provided for @settings_relationshipCreated.
  ///
  /// In zh, this message translates to:
  /// **'关系已创建'**
  String get settings_relationshipCreated;

  /// No description provided for @settings_relationshipDeleted.
  ///
  /// In zh, this message translates to:
  /// **'关系已删除'**
  String get settings_relationshipDeleted;

  /// No description provided for @settings_relationshipListTitle.
  ///
  /// In zh, this message translates to:
  /// **'角色关系'**
  String get settings_relationshipListTitle;

  /// No description provided for @settings_relationshipManagement.
  ///
  /// In zh, this message translates to:
  /// **'角色关系'**
  String get settings_relationshipManagement;

  /// No description provided for @settings_relationshipManagementSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看人物之间的关系变化和事件。'**
  String get settings_relationshipManagementSubtitle;

  /// No description provided for @settings_relationshipTimelineView.
  ///
  /// In zh, this message translates to:
  /// **'关系时间线视图'**
  String get settings_relationshipTimelineView;

  /// No description provided for @settings_relationshipType.
  ///
  /// In zh, this message translates to:
  /// **'关系类型'**
  String get settings_relationshipType;

  /// No description provided for @settings_relationshipUpdated.
  ///
  /// In zh, this message translates to:
  /// **'关系已更新'**
  String get settings_relationshipUpdated;

  /// No description provided for @settings_respect.
  ///
  /// In zh, this message translates to:
  /// **'尊敬'**
  String get settings_respect;

  /// No description provided for @settings_reviewCenter.
  ///
  /// In zh, this message translates to:
  /// **'审查中心'**
  String get settings_reviewCenter;

  /// No description provided for @settings_save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settings_save;

  /// No description provided for @settings_saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String settings_saveFailed(Object error);

  /// No description provided for @settings_search.
  ///
  /// In zh, this message translates to:
  /// **'搜索: {query}'**
  String settings_search(Object query);

  /// No description provided for @settings_searchCharacters.
  ///
  /// In zh, this message translates to:
  /// **'搜索角色名称、别名、身份...'**
  String get settings_searchCharacters;

  /// No description provided for @settings_showArchived.
  ///
  /// In zh, this message translates to:
  /// **'显示归档'**
  String get settings_showArchived;

  /// No description provided for @settings_statisticsTooltip.
  ///
  /// In zh, this message translates to:
  /// **'统计面板'**
  String get settings_statisticsTooltip;

  /// No description provided for @settings_tierBadge.
  ///
  /// In zh, this message translates to:
  /// **'分级徽章'**
  String get settings_tierBadge;

  /// No description provided for @settings_tierDescription.
  ///
  /// In zh, this message translates to:
  /// **'主角、主要配角、反派需要填写深度档案'**
  String get settings_tierDescription;

  /// No description provided for @settings_timeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get settings_timeline;

  /// No description provided for @settings_timelineSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理事件、冲突和角色轨迹。'**
  String get settings_timelineSubtitle;

  /// No description provided for @settings_treeView.
  ///
  /// In zh, this message translates to:
  /// **'树形视图'**
  String get settings_treeView;

  /// No description provided for @settings_treeViewTitle.
  ///
  /// In zh, this message translates to:
  /// **'树形视图'**
  String get settings_treeViewTitle;

  /// No description provided for @settings_trust.
  ///
  /// In zh, this message translates to:
  /// **'信任'**
  String get settings_trust;

  /// No description provided for @settings_type.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get settings_type;

  /// No description provided for @settings_unarchive.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get settings_unarchive;

  /// No description provided for @settings_unarchiveCharacter.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get settings_unarchiveCharacter;

  /// No description provided for @settings_unarchiveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要取消归档 {name} 吗？'**
  String settings_unarchiveConfirm(Object name);

  /// No description provided for @settings_unarchived.
  ///
  /// In zh, this message translates to:
  /// **'已取消归档'**
  String get settings_unarchived;

  /// No description provided for @settings_unknownCharacter.
  ///
  /// In zh, this message translates to:
  /// **'未知角色'**
  String get settings_unknownCharacter;

  /// No description provided for @settings_updateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败: {error}'**
  String settings_updateFailed(Object error);

  /// No description provided for @settings_updateFailedGeneric.
  ///
  /// In zh, this message translates to:
  /// **'更新失败: {error}'**
  String settings_updateFailedGeneric(Object error);

  /// No description provided for @settings_viewChangeHistory.
  ///
  /// In zh, this message translates to:
  /// **'查看变更历史'**
  String get settings_viewChangeHistory;

  /// No description provided for @settings_workStatistics.
  ///
  /// In zh, this message translates to:
  /// **'作品统计'**
  String get settings_workStatistics;

  /// No description provided for @settings_workStatisticsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'章节进度、字数趋势和写作目标。'**
  String get settings_workStatisticsSubtitle;

  /// No description provided for @settings_worldSettings.
  ///
  /// In zh, this message translates to:
  /// **'世界设定'**
  String get settings_worldSettings;

  /// No description provided for @settings_worldSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'地点、物件和势力的整理入口。'**
  String get settings_worldSettingsSubtitle;

  /// No description provided for @settings_worldWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'世界工作台'**
  String get settings_worldWorkbench;

  /// No description provided for @settings_worldWorkbenchSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理角色、物件、地点、势力和分析入口。'**
  String get settings_worldWorkbenchSubtitle;

  /// No description provided for @settings_worldbuildingControl.
  ///
  /// In zh, this message translates to:
  /// **'把角色、关系、地点和物件放进一个清晰的操控面板。'**
  String get settings_worldbuildingControl;

  /// No description provided for @settings_worldbuildingDescription.
  ///
  /// In zh, this message translates to:
  /// **'这里不再是零散的功能清单，而是围绕一个作品的世界信息中枢。你可以在这里进入设定、分析与统计路径。'**
  String get settings_worldbuildingDescription;

  /// No description provided for @shared_filter.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get shared_filter;

  /// No description provided for @shared_noContent.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get shared_noContent;

  /// No description provided for @shared_search.
  ///
  /// In zh, this message translates to:
  /// **'搜索...'**
  String get shared_search;

  /// No description provided for @shared_sort.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get shared_sort;

  /// No description provided for @statistics_addFirstGoal.
  ///
  /// In zh, this message translates to:
  /// **'添加第一个目标'**
  String get statistics_addFirstGoal;

  /// No description provided for @statistics_addGoal.
  ///
  /// In zh, this message translates to:
  /// **'添加目标'**
  String get statistics_addGoal;

  /// No description provided for @statistics_addWritingGoal.
  ///
  /// In zh, this message translates to:
  /// **'添加写作目标'**
  String get statistics_addWritingGoal;

  /// No description provided for @statistics_averageChapterWords.
  ///
  /// In zh, this message translates to:
  /// **'平均章节字数'**
  String get statistics_averageChapterWords;

  /// No description provided for @statistics_chapterCount.
  ///
  /// In zh, this message translates to:
  /// **'章节数'**
  String get statistics_chapterCount;

  /// No description provided for @statistics_chapterList.
  ///
  /// In zh, this message translates to:
  /// **'章节列表'**
  String get statistics_chapterList;

  /// No description provided for @statistics_chapterProgress.
  ///
  /// In zh, this message translates to:
  /// **'章节进度'**
  String get statistics_chapterProgress;

  /// No description provided for @statistics_chapterProgressItem.
  ///
  /// In zh, this message translates to:
  /// **'章节进度项'**
  String get statistics_chapterProgressItem;

  /// No description provided for @statistics_chapterProgressTab.
  ///
  /// In zh, this message translates to:
  /// **'章节进度'**
  String get statistics_chapterProgressTab;

  /// No description provided for @statistics_chapterProgressTitle.
  ///
  /// In zh, this message translates to:
  /// **'章节进度'**
  String get statistics_chapterProgressTitle;

  /// No description provided for @statistics_chapterStatistics.
  ///
  /// In zh, this message translates to:
  /// **'章节统计'**
  String get statistics_chapterStatistics;

  /// No description provided for @statistics_chapterStatusDistribution.
  ///
  /// In zh, this message translates to:
  /// **'章节状态分布'**
  String get statistics_chapterStatusDistribution;

  /// No description provided for @statistics_chapters.
  ///
  /// In zh, this message translates to:
  /// **'章'**
  String get statistics_chapters;

  /// No description provided for @statistics_characterStat.
  ///
  /// In zh, this message translates to:
  /// **'角色统计'**
  String get statistics_characterStat;

  /// No description provided for @statistics_characterStatistics.
  ///
  /// In zh, this message translates to:
  /// **'角色统计'**
  String get statistics_characterStatistics;

  /// No description provided for @statistics_characters.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get statistics_characters;

  /// No description provided for @statistics_completedChapters.
  ///
  /// In zh, this message translates to:
  /// **'已完成章节'**
  String get statistics_completedChapters;

  /// No description provided for @statistics_completionProgress.
  ///
  /// In zh, this message translates to:
  /// **'完成进度'**
  String get statistics_completionProgress;

  /// No description provided for @statistics_completionRate.
  ///
  /// In zh, this message translates to:
  /// **'完成进度'**
  String get statistics_completionRate;

  /// No description provided for @statistics_coreMetrics.
  ///
  /// In zh, this message translates to:
  /// **'核心指标'**
  String get statistics_coreMetrics;

  /// No description provided for @statistics_csvFormat.
  ///
  /// In zh, this message translates to:
  /// **'CSV'**
  String get statistics_csvFormat;

  /// No description provided for @statistics_csvFormatDescription.
  ///
  /// In zh, this message translates to:
  /// **'适合表格分析'**
  String get statistics_csvFormatDescription;

  /// No description provided for @statistics_cumulative.
  ///
  /// In zh, this message translates to:
  /// **'累计'**
  String get statistics_cumulative;

  /// No description provided for @statistics_currentValue.
  ///
  /// In zh, this message translates to:
  /// **'当前值'**
  String get statistics_currentValue;

  /// No description provided for @statistics_dailyAverageWords.
  ///
  /// In zh, this message translates to:
  /// **'日均字数'**
  String get statistics_dailyAverageWords;

  /// No description provided for @statistics_dailyGoal.
  ///
  /// In zh, this message translates to:
  /// **'每日目标'**
  String get statistics_dailyGoal;

  /// No description provided for @statistics_detailedData.
  ///
  /// In zh, this message translates to:
  /// **'详细数据'**
  String get statistics_detailedData;

  /// No description provided for @statistics_draft.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get statistics_draft;

  /// No description provided for @statistics_editFunctionInDevelopment.
  ///
  /// In zh, this message translates to:
  /// **'编辑功能开发中'**
  String get statistics_editFunctionInDevelopment;

  /// No description provided for @statistics_editInDevelopment.
  ///
  /// In zh, this message translates to:
  /// **'编辑功能开发中'**
  String get statistics_editInDevelopment;

  /// No description provided for @statistics_endDate.
  ///
  /// In zh, this message translates to:
  /// **'结束日期（可选）'**
  String get statistics_endDate;

  /// No description provided for @statistics_estimatedCompletionDate.
  ///
  /// In zh, this message translates to:
  /// **'预计完成日期：{date}'**
  String statistics_estimatedCompletionDate(Object date);

  /// No description provided for @statistics_estimatedDate.
  ///
  /// In zh, this message translates to:
  /// **'预计 {date}'**
  String statistics_estimatedDate(Object date);

  /// No description provided for @statistics_estimatedDaysRemaining.
  ///
  /// In zh, this message translates to:
  /// **'预计还需 {days} 天'**
  String statistics_estimatedDaysRemaining(Object days);

  /// No description provided for @statistics_exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败: {error}'**
  String statistics_exportFailed(Object error);

  /// No description provided for @statistics_exportReport.
  ///
  /// In zh, this message translates to:
  /// **'导出报告'**
  String get statistics_exportReport;

  /// No description provided for @statistics_goalCard.
  ///
  /// In zh, this message translates to:
  /// **'目标卡片'**
  String get statistics_goalCard;

  /// No description provided for @statistics_goalDeleted.
  ///
  /// In zh, this message translates to:
  /// **'目标已删除'**
  String get statistics_goalDeleted;

  /// No description provided for @statistics_goalSaved.
  ///
  /// In zh, this message translates to:
  /// **'目标已保存'**
  String get statistics_goalSaved;

  /// No description provided for @statistics_goalType.
  ///
  /// In zh, this message translates to:
  /// **'目标类型'**
  String get statistics_goalType;

  /// No description provided for @statistics_goalsTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'目标标签页'**
  String get statistics_goalsTabTitle;

  /// No description provided for @statistics_growthRate.
  ///
  /// In zh, this message translates to:
  /// **'增长率'**
  String get statistics_growthRate;

  /// No description provided for @statistics_growthRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{rate}%'**
  String statistics_growthRateValue(Object rate);

  /// No description provided for @statistics_jsonFormat.
  ///
  /// In zh, this message translates to:
  /// **'JSON'**
  String get statistics_jsonFormat;

  /// No description provided for @statistics_jsonFormatDescription.
  ///
  /// In zh, this message translates to:
  /// **'包含完整统计数据'**
  String get statistics_jsonFormatDescription;

  /// No description provided for @statistics_loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get statistics_loadFailed;

  /// No description provided for @statistics_maxChapterWords.
  ///
  /// In zh, this message translates to:
  /// **'最多字数章节'**
  String get statistics_maxChapterWords;

  /// No description provided for @statistics_metricCard.
  ///
  /// In zh, this message translates to:
  /// **'指标卡片'**
  String get statistics_metricCard;

  /// No description provided for @statistics_minChapterWords.
  ///
  /// In zh, this message translates to:
  /// **'最少字数章节'**
  String get statistics_minChapterWords;

  /// No description provided for @statistics_minorCharacter.
  ///
  /// In zh, this message translates to:
  /// **'次要角色'**
  String get statistics_minorCharacter;

  /// No description provided for @statistics_minorCharacters.
  ///
  /// In zh, this message translates to:
  /// **'次要角色'**
  String get statistics_minorCharacters;

  /// No description provided for @statistics_monthlyGoal.
  ///
  /// In zh, this message translates to:
  /// **'每月目标'**
  String get statistics_monthlyGoal;

  /// No description provided for @statistics_noChapterData.
  ///
  /// In zh, this message translates to:
  /// **'暂无章节数据'**
  String get statistics_noChapterData;

  /// No description provided for @statistics_noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get statistics_noData;

  /// No description provided for @statistics_noGoalSet.
  ///
  /// In zh, this message translates to:
  /// **'未设定目标'**
  String get statistics_noGoalSet;

  /// No description provided for @statistics_noGoalsSet.
  ///
  /// In zh, this message translates to:
  /// **'还没有设置写作目标'**
  String get statistics_noGoalsSet;

  /// No description provided for @statistics_overviewTab.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get statistics_overviewTab;

  /// No description provided for @statistics_overviewTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'概览标签页'**
  String get statistics_overviewTabTitle;

  /// No description provided for @statistics_percentage.
  ///
  /// In zh, this message translates to:
  /// **'{percent}%'**
  String statistics_percentage(Object percent);

  /// No description provided for @statistics_pleaseFillCompleteInfo.
  ///
  /// In zh, this message translates to:
  /// **'请填写完整信息'**
  String get statistics_pleaseFillCompleteInfo;

  /// No description provided for @statistics_progressTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'进度标签页'**
  String get statistics_progressTabTitle;

  /// No description provided for @statistics_protagonist.
  ///
  /// In zh, this message translates to:
  /// **'主角'**
  String get statistics_protagonist;

  /// No description provided for @statistics_published.
  ///
  /// In zh, this message translates to:
  /// **'已发布'**
  String get statistics_published;

  /// No description provided for @statistics_publishedChapters.
  ///
  /// In zh, this message translates to:
  /// **'已发布 {count} 章'**
  String statistics_publishedChapters(Object count);

  /// No description provided for @statistics_publishedWords.
  ///
  /// In zh, this message translates to:
  /// **'已发布 {count} 字'**
  String statistics_publishedWords(Object count);

  /// No description provided for @statistics_recentWordCountTrend.
  ///
  /// In zh, this message translates to:
  /// **'近期字数趋势'**
  String get statistics_recentWordCountTrend;

  /// No description provided for @statistics_reportExported.
  ///
  /// In zh, this message translates to:
  /// **'报告已导出: {path}'**
  String statistics_reportExported(Object path);

  /// No description provided for @statistics_selectDate.
  ///
  /// In zh, this message translates to:
  /// **'选择日期'**
  String get statistics_selectDate;

  /// No description provided for @statistics_selectExportFormat.
  ///
  /// In zh, this message translates to:
  /// **'选择导出格式'**
  String get statistics_selectExportFormat;

  /// No description provided for @statistics_startDate.
  ///
  /// In zh, this message translates to:
  /// **'开始日期'**
  String get statistics_startDate;

  /// No description provided for @statistics_statRow.
  ///
  /// In zh, this message translates to:
  /// **'统计行'**
  String get statistics_statRow;

  /// No description provided for @statistics_supporting.
  ///
  /// In zh, this message translates to:
  /// **'配角'**
  String get statistics_supporting;

  /// No description provided for @statistics_supportingCharacter.
  ///
  /// In zh, this message translates to:
  /// **'配角'**
  String get statistics_supportingCharacter;

  /// No description provided for @statistics_targetValue.
  ///
  /// In zh, this message translates to:
  /// **'目标值（字数）'**
  String get statistics_targetValue;

  /// No description provided for @statistics_tenThousand.
  ///
  /// In zh, this message translates to:
  /// **'{value}万'**
  String statistics_tenThousand(Object value);

  /// No description provided for @statistics_title.
  ///
  /// In zh, this message translates to:
  /// **'统计中心'**
  String get statistics_title;

  /// No description provided for @statistics_total.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get statistics_total;

  /// No description provided for @statistics_totalChapters.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 章'**
  String statistics_totalChapters(Object count);

  /// No description provided for @statistics_totalCharacters.
  ///
  /// In zh, this message translates to:
  /// **'总计'**
  String get statistics_totalCharacters;

  /// No description provided for @statistics_totalGoal.
  ///
  /// In zh, this message translates to:
  /// **'总目标'**
  String get statistics_totalGoal;

  /// No description provided for @statistics_totalGrowth.
  ///
  /// In zh, this message translates to:
  /// **'总增长'**
  String get statistics_totalGrowth;

  /// No description provided for @statistics_totalGrowthValue.
  ///
  /// In zh, this message translates to:
  /// **'{growth} 字'**
  String statistics_totalGrowthValue(Object growth);

  /// No description provided for @statistics_totalWords.
  ///
  /// In zh, this message translates to:
  /// **'总字数'**
  String get statistics_totalWords;

  /// No description provided for @statistics_trendTabTitle.
  ///
  /// In zh, this message translates to:
  /// **'趋势标签页'**
  String get statistics_trendTabTitle;

  /// No description provided for @statistics_view.
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get statistics_view;

  /// No description provided for @statistics_villain.
  ///
  /// In zh, this message translates to:
  /// **'反派'**
  String get statistics_villain;

  /// No description provided for @statistics_weeklyGoal.
  ///
  /// In zh, this message translates to:
  /// **'每周目标'**
  String get statistics_weeklyGoal;

  /// No description provided for @statistics_wordCount.
  ///
  /// In zh, this message translates to:
  /// **'字数'**
  String get statistics_wordCount;

  /// No description provided for @statistics_wordCountTrend.
  ///
  /// In zh, this message translates to:
  /// **'字数趋势'**
  String get statistics_wordCountTrend;

  /// No description provided for @statistics_wordCountTrendTab.
  ///
  /// In zh, this message translates to:
  /// **'字数趋势'**
  String get statistics_wordCountTrendTab;

  /// No description provided for @statistics_wordProgress.
  ///
  /// In zh, this message translates to:
  /// **'{current} / {target} 字'**
  String statistics_wordProgress(Object current, Object target);

  /// No description provided for @statistics_words.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String statistics_words(Object count);

  /// No description provided for @statistics_writingDays.
  ///
  /// In zh, this message translates to:
  /// **'写作天数 {days} 天'**
  String statistics_writingDays(Object days);

  /// No description provided for @statistics_writingGoals.
  ///
  /// In zh, this message translates to:
  /// **'写作目标'**
  String get statistics_writingGoals;

  /// No description provided for @statistics_writingGoalsTab.
  ///
  /// In zh, this message translates to:
  /// **'写作目标'**
  String get statistics_writingGoalsTab;

  /// No description provided for @statistics_writingGoalsTitle.
  ///
  /// In zh, this message translates to:
  /// **'写作目标'**
  String get statistics_writingGoalsTitle;

  /// No description provided for @status.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get status;

  /// No description provided for @submit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get submit;

  /// No description provided for @systemMode.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get systemMode;

  /// No description provided for @tag.
  ///
  /// In zh, this message translates to:
  /// **'标签'**
  String get tag;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @timeline_aiAutoFix.
  ///
  /// In zh, this message translates to:
  /// **'AI自动修复将根据建议自动调整相关事件'**
  String get timeline_aiAutoFix;

  /// No description provided for @timeline_aiAutoFixButton.
  ///
  /// In zh, this message translates to:
  /// **'AI自动修复'**
  String get timeline_aiAutoFixButton;

  /// No description provided for @timeline_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get timeline_all;

  /// No description provided for @timeline_applyFixFailed.
  ///
  /// In zh, this message translates to:
  /// **'应用修复失败: {error}'**
  String timeline_applyFixFailed(Object error);

  /// No description provided for @timeline_basicInfo.
  ///
  /// In zh, this message translates to:
  /// **'基本信息'**
  String get timeline_basicInfo;

  /// No description provided for @timeline_belongsToChapter.
  ///
  /// In zh, this message translates to:
  /// **'所属章节'**
  String get timeline_belongsToChapter;

  /// No description provided for @timeline_chapter.
  ///
  /// In zh, this message translates to:
  /// **'章节: {id}'**
  String timeline_chapter(Object id);

  /// No description provided for @timeline_chapterNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {number} 章'**
  String timeline_chapterNumber(Object number);

  /// No description provided for @timeline_chapterTimeline.
  ///
  /// In zh, this message translates to:
  /// **'章节时间线'**
  String get timeline_chapterTimeline;

  /// No description provided for @timeline_chapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'第 {chapterId} 章'**
  String timeline_chapterTitle(Object chapterId);

  /// No description provided for @timeline_characterAvailabilityFix.
  ///
  /// In zh, this message translates to:
  /// **'角色在事件时间不可用（如被囚禁时参与其他事件）。请调整事件时间或角色安排。'**
  String get timeline_characterAvailabilityFix;

  /// No description provided for @timeline_characterView.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get timeline_characterView;

  /// No description provided for @timeline_charactersTab.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get timeline_charactersTab;

  /// No description provided for @timeline_close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get timeline_close;

  /// No description provided for @timeline_conflictFixed.
  ///
  /// In zh, this message translates to:
  /// **'冲突已修复'**
  String get timeline_conflictFixed;

  /// No description provided for @timeline_conflictMarkedResolved.
  ///
  /// In zh, this message translates to:
  /// **'冲突已标记为已解决'**
  String get timeline_conflictMarkedResolved;

  /// No description provided for @timeline_conflictType.
  ///
  /// In zh, this message translates to:
  /// **'冲突类型：'**
  String get timeline_conflictType;

  /// No description provided for @timeline_conflictsTab.
  ///
  /// In zh, this message translates to:
  /// **'冲突'**
  String get timeline_conflictsTab;

  /// No description provided for @timeline_createEvent.
  ///
  /// In zh, this message translates to:
  /// **'创建事件'**
  String get timeline_createEvent;

  /// No description provided for @timeline_createFirstEvent.
  ///
  /// In zh, this message translates to:
  /// **'创建第一个事件'**
  String get timeline_createFirstEvent;

  /// No description provided for @timeline_cultivationProgress.
  ///
  /// In zh, this message translates to:
  /// **'修为进度'**
  String get timeline_cultivationProgress;

  /// No description provided for @timeline_cultivationProgressDisplay.
  ///
  /// In zh, this message translates to:
  /// **'修为进度将在这里显示'**
  String get timeline_cultivationProgressDisplay;

  /// No description provided for @timeline_detectedConflicts.
  ///
  /// In zh, this message translates to:
  /// **'检测到 {count} 个潜在冲突'**
  String timeline_detectedConflicts(Object count);

  /// No description provided for @timeline_edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get timeline_edit;

  /// No description provided for @timeline_editEvent.
  ///
  /// In zh, this message translates to:
  /// **'编辑事件'**
  String get timeline_editEvent;

  /// No description provided for @timeline_eventCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个事件'**
  String timeline_eventCount(Object count);

  /// No description provided for @timeline_eventDescription.
  ///
  /// In zh, this message translates to:
  /// **'事件描述'**
  String get timeline_eventDescription;

  /// No description provided for @timeline_eventDescriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'事件描述'**
  String get timeline_eventDescriptionLabel;

  /// No description provided for @timeline_eventListTile.
  ///
  /// In zh, this message translates to:
  /// **'事件列表项'**
  String get timeline_eventListTile;

  /// No description provided for @timeline_eventName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get timeline_eventName;

  /// No description provided for @timeline_eventNode.
  ///
  /// In zh, this message translates to:
  /// **'事件节点'**
  String get timeline_eventNode;

  /// No description provided for @timeline_eventTimelineComponent.
  ///
  /// In zh, this message translates to:
  /// **'事件时间线组件'**
  String get timeline_eventTimelineComponent;

  /// No description provided for @timeline_eventType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get timeline_eventType;

  /// No description provided for @timeline_eventTypeLabel.
  ///
  /// In zh, this message translates to:
  /// **'类型：{type}'**
  String timeline_eventTypeLabel(Object type);

  /// No description provided for @timeline_eventUpdated.
  ///
  /// In zh, this message translates to:
  /// **'事件已更新'**
  String get timeline_eventUpdated;

  /// No description provided for @timeline_eventsTab.
  ///
  /// In zh, this message translates to:
  /// **'事件'**
  String get timeline_eventsTab;

  /// No description provided for @timeline_filterEvents.
  ///
  /// In zh, this message translates to:
  /// **'筛选事件'**
  String get timeline_filterEvents;

  /// No description provided for @timeline_fix.
  ///
  /// In zh, this message translates to:
  /// **'修复'**
  String get timeline_fix;

  /// No description provided for @timeline_importance.
  ///
  /// In zh, this message translates to:
  /// **'重要程度'**
  String get timeline_importance;

  /// No description provided for @timeline_importanceLabel.
  ///
  /// In zh, this message translates to:
  /// **'重要程度：{importance}'**
  String timeline_importanceLabel(Object importance);

  /// No description provided for @timeline_keyEvent.
  ///
  /// In zh, this message translates to:
  /// **'关键事件'**
  String get timeline_keyEvent;

  /// No description provided for @timeline_listView.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get timeline_listView;

  /// No description provided for @timeline_locationConflictFix.
  ///
  /// In zh, this message translates to:
  /// **'角色或事件在同一时间出现在不同地点。建议调整时间安排或地点设置。'**
  String get timeline_locationConflictFix;

  /// No description provided for @timeline_locationView.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get timeline_locationView;

  /// No description provided for @timeline_locationViewComponent.
  ///
  /// In zh, this message translates to:
  /// **'地点视图'**
  String get timeline_locationViewComponent;

  /// No description provided for @timeline_locationsTab.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get timeline_locationsTab;

  /// No description provided for @timeline_markAsResolved.
  ///
  /// In zh, this message translates to:
  /// **'标记为已解决'**
  String get timeline_markAsResolved;

  /// No description provided for @timeline_newEvent.
  ///
  /// In zh, this message translates to:
  /// **'新建事件'**
  String get timeline_newEvent;

  /// No description provided for @timeline_noEventRecords.
  ///
  /// In zh, this message translates to:
  /// **'该角色暂无事件记录'**
  String get timeline_noEventRecords;

  /// No description provided for @timeline_noEventsYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有事件'**
  String get timeline_noEventsYet;

  /// No description provided for @timeline_noLocationData.
  ///
  /// In zh, this message translates to:
  /// **'暂无地点数据'**
  String get timeline_noLocationData;

  /// No description provided for @timeline_noTimeConflicts.
  ///
  /// In zh, this message translates to:
  /// **'未检测到时间冲突'**
  String get timeline_noTimeConflicts;

  /// No description provided for @timeline_pleaseEnterEventName.
  ///
  /// In zh, this message translates to:
  /// **'请输入事件名称'**
  String get timeline_pleaseEnterEventName;

  /// No description provided for @timeline_pleaseSelectCharacter.
  ///
  /// In zh, this message translates to:
  /// **'请选择一个角色'**
  String get timeline_pleaseSelectCharacter;

  /// No description provided for @timeline_relationshipChanges.
  ///
  /// In zh, this message translates to:
  /// **'关系变化'**
  String get timeline_relationshipChanges;

  /// No description provided for @timeline_relationshipChangesDisplay.
  ///
  /// In zh, this message translates to:
  /// **'关系变化将在这里显示'**
  String get timeline_relationshipChangesDisplay;

  /// No description provided for @timeline_relativeTime.
  ///
  /// In zh, this message translates to:
  /// **'相对时间：{time}'**
  String timeline_relativeTime(Object time);

  /// No description provided for @timeline_relativeTimeHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：事件发生后3天'**
  String get timeline_relativeTimeHint;

  /// No description provided for @timeline_required.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get timeline_required;

  /// No description provided for @timeline_resolutionSuggestion.
  ///
  /// In zh, this message translates to:
  /// **'修复建议'**
  String get timeline_resolutionSuggestion;

  /// No description provided for @timeline_saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String timeline_saveFailed(Object error);

  /// No description provided for @timeline_selectCharacter.
  ///
  /// In zh, this message translates to:
  /// **'选择角色'**
  String get timeline_selectCharacter;

  /// No description provided for @timeline_stateConflictFix.
  ///
  /// In zh, this message translates to:
  /// **'角色状态不一致（如死亡后又出现）。请检查角色状态变更的合理性。'**
  String get timeline_stateConflictFix;

  /// No description provided for @timeline_storyTime.
  ///
  /// In zh, this message translates to:
  /// **'故事时间：{time}'**
  String timeline_storyTime(Object time);

  /// No description provided for @timeline_storyTimeHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：第一卷 第三章'**
  String get timeline_storyTimeHint;

  /// No description provided for @timeline_subsequentImpact.
  ///
  /// In zh, this message translates to:
  /// **'后续影响'**
  String get timeline_subsequentImpact;

  /// No description provided for @timeline_subsequentImpactLabel.
  ///
  /// In zh, this message translates to:
  /// **'后续影响'**
  String get timeline_subsequentImpactLabel;

  /// No description provided for @timeline_suggestedFix.
  ///
  /// In zh, this message translates to:
  /// **'建议修复方案：'**
  String get timeline_suggestedFix;

  /// No description provided for @timeline_timeSequenceFix.
  ///
  /// In zh, this message translates to:
  /// **'调整事件的时间顺序，确保因果关系合理。建议检查前序事件的完成时间。'**
  String get timeline_timeSequenceFix;

  /// No description provided for @timeline_timelineNode.
  ///
  /// In zh, this message translates to:
  /// **'时间线节点'**
  String get timeline_timelineNode;

  /// No description provided for @timeline_timelineView.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get timeline_timelineView;

  /// No description provided for @timeline_title.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get timeline_title;

  /// No description provided for @timeline_trajectory.
  ///
  /// In zh, this message translates to:
  /// **'轨迹'**
  String get timeline_trajectory;

  /// No description provided for @timeline_unassignedChapter.
  ///
  /// In zh, this message translates to:
  /// **'未分配章节'**
  String get timeline_unassignedChapter;

  /// No description provided for @title.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get title;

  /// No description provided for @type.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get type;

  /// No description provided for @unarchive.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get unarchive;

  /// No description provided for @unarchived.
  ///
  /// In zh, this message translates to:
  /// **'已取消归档'**
  String get unarchived;

  /// No description provided for @unpinned.
  ///
  /// In zh, this message translates to:
  /// **'已取消置顶'**
  String get unpinned;

  /// No description provided for @updateTime.
  ///
  /// In zh, this message translates to:
  /// **'更新时间'**
  String get updateTime;

  /// No description provided for @usageStats_avgResponse.
  ///
  /// In zh, this message translates to:
  /// **'平均响应'**
  String get usageStats_avgResponse;

  /// No description provided for @usageStats_cachedHits.
  ///
  /// In zh, this message translates to:
  /// **'缓存命中'**
  String get usageStats_cachedHits;

  /// No description provided for @usageStats_dailyDetails.
  ///
  /// In zh, this message translates to:
  /// **'每日详情'**
  String get usageStats_dailyDetails;

  /// No description provided for @usageStats_errorCount.
  ///
  /// In zh, this message translates to:
  /// **'错误数'**
  String get usageStats_errorCount;

  /// No description provided for @usageStats_noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get usageStats_noData;

  /// No description provided for @usageStats_recentRequests.
  ///
  /// In zh, this message translates to:
  /// **'最近请求'**
  String get usageStats_recentRequests;

  /// No description provided for @usageStats_requestCount.
  ///
  /// In zh, this message translates to:
  /// **'请求数'**
  String get usageStats_requestCount;

  /// No description provided for @usageStats_selectDateRange.
  ///
  /// In zh, this message translates to:
  /// **'选择日期范围'**
  String get usageStats_selectDateRange;

  /// No description provided for @usageStats_statusDistribution.
  ///
  /// In zh, this message translates to:
  /// **'状态分布'**
  String get usageStats_statusDistribution;

  /// No description provided for @usageStats_status_cached.
  ///
  /// In zh, this message translates to:
  /// **'缓存'**
  String get usageStats_status_cached;

  /// No description provided for @usageStats_status_error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get usageStats_status_error;

  /// No description provided for @usageStats_status_success.
  ///
  /// In zh, this message translates to:
  /// **'成功'**
  String get usageStats_status_success;

  /// No description provided for @usageStats_successRate.
  ///
  /// In zh, this message translates to:
  /// **'成功率'**
  String get usageStats_successRate;

  /// No description provided for @usageStats_tab_byFunction.
  ///
  /// In zh, this message translates to:
  /// **'按功能'**
  String get usageStats_tab_byFunction;

  /// No description provided for @usageStats_tab_byModel.
  ///
  /// In zh, this message translates to:
  /// **'按模型'**
  String get usageStats_tab_byModel;

  /// No description provided for @usageStats_tab_overview.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get usageStats_tab_overview;

  /// No description provided for @usageStats_tier.
  ///
  /// In zh, this message translates to:
  /// **'层级'**
  String get usageStats_tier;

  /// No description provided for @usageStats_title.
  ///
  /// In zh, this message translates to:
  /// **'AI 使用统计'**
  String get usageStats_title;

  /// No description provided for @usageStats_totalRequests.
  ///
  /// In zh, this message translates to:
  /// **'总请求'**
  String get usageStats_totalRequests;

  /// No description provided for @usageStats_totalTokens.
  ///
  /// In zh, this message translates to:
  /// **'总 Token'**
  String get usageStats_totalTokens;

  /// No description provided for @work_adjustFilter.
  ///
  /// In zh, this message translates to:
  /// **'调整筛选'**
  String get work_adjustFilter;

  /// No description provided for @work_aiDetection.
  ///
  /// In zh, this message translates to:
  /// **'AI 检测'**
  String get work_aiDetection;

  /// No description provided for @work_aiDetectionDesc.
  ///
  /// In zh, this message translates to:
  /// **'需要时把当前内容送去做 AI 检测。'**
  String get work_aiDetectionDesc;

  /// No description provided for @work_aiSettings.
  ///
  /// In zh, this message translates to:
  /// **'AI 设置'**
  String get work_aiSettings;

  /// No description provided for @work_aiUsageStats.
  ///
  /// In zh, this message translates to:
  /// **'AI 使用统计'**
  String get work_aiUsageStats;

  /// No description provided for @work_aiUsageStatsDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看这部作品相关的模型与 token 使用情况。'**
  String get work_aiUsageStatsDesc;

  /// No description provided for @work_all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get work_all;

  /// No description provided for @work_analysis.
  ///
  /// In zh, this message translates to:
  /// **'分析'**
  String get work_analysis;

  /// No description provided for @work_analysisView.
  ///
  /// In zh, this message translates to:
  /// **'分析视图'**
  String get work_analysisView;

  /// No description provided for @work_analysisViewDesc.
  ///
  /// In zh, this message translates to:
  /// **'当你需要检查节奏、结构或故事逻辑时，从这里进入。'**
  String get work_analysisViewDesc;

  /// No description provided for @work_archiveWork.
  ///
  /// In zh, this message translates to:
  /// **'归档作品'**
  String get work_archiveWork;

  /// No description provided for @work_archived.
  ///
  /// In zh, this message translates to:
  /// **'已归档作品'**
  String get work_archived;

  /// No description provided for @work_archivedHidden.
  ///
  /// In zh, this message translates to:
  /// **'已隐藏归档'**
  String get work_archivedHidden;

  /// No description provided for @work_archivedHint.
  ///
  /// In zh, this message translates to:
  /// **'已完结或暂停，但保留备查的作品。'**
  String get work_archivedHint;

  /// No description provided for @work_archivedShown.
  ///
  /// In zh, this message translates to:
  /// **'已显示归档'**
  String get work_archivedShown;

  /// No description provided for @work_backToLibrary.
  ///
  /// In zh, this message translates to:
  /// **'返回作品库'**
  String get work_backToLibrary;

  /// No description provided for @work_backToWork.
  ///
  /// In zh, this message translates to:
  /// **'返回作品'**
  String get work_backToWork;

  /// No description provided for @work_cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get work_cancel;

  /// No description provided for @work_changeCover.
  ///
  /// In zh, this message translates to:
  /// **'更换封面'**
  String get work_changeCover;

  /// No description provided for @work_chapterMap.
  ///
  /// In zh, this message translates to:
  /// **'章节地图'**
  String get work_chapterMap;

  /// No description provided for @work_chapterMapDesc.
  ///
  /// In zh, this message translates to:
  /// **'先创建第一章，作品结构就能建立起来。'**
  String get work_chapterMapDesc;

  /// No description provided for @work_chapterMapDesc2.
  ///
  /// In zh, this message translates to:
  /// **'按卷展示章节、阅读时间和审阅状态，方便快速导航。'**
  String get work_chapterMapDesc2;

  /// No description provided for @work_chapterTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'章节标题'**
  String get work_chapterTitleHint;

  /// No description provided for @work_chapters.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get work_chapters;

  /// No description provided for @work_chaptersCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 章'**
  String work_chaptersCount(Object count);

  /// No description provided for @work_chaptersHint.
  ///
  /// In zh, this message translates to:
  /// **'当前作品下的所有章节。'**
  String get work_chaptersHint;

  /// No description provided for @work_chaptersLabel.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get work_chaptersLabel;

  /// No description provided for @work_characters.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get work_characters;

  /// No description provided for @work_charactersDesc.
  ///
  /// In zh, this message translates to:
  /// **'管理主要角色、简介和详细档案。'**
  String get work_charactersDesc;

  /// No description provided for @work_completedStatus.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get work_completedStatus;

  /// No description provided for @work_completedStatusDesc.
  ///
  /// In zh, this message translates to:
  /// **'这是一部已完成作品，章节、设定和审阅记录都已沉淀完毕。'**
  String get work_completedStatusDesc;

  /// No description provided for @work_continueCreating.
  ///
  /// In zh, this message translates to:
  /// **'继续创作《{title}》'**
  String work_continueCreating(Object title);

  /// No description provided for @work_create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get work_create;

  /// No description provided for @work_createChapterTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建章节'**
  String get work_createChapterTitle;

  /// No description provided for @work_createFirstChapter.
  ///
  /// In zh, this message translates to:
  /// **'创建第一章'**
  String get work_createFirstChapter;

  /// No description provided for @work_createFirstWork.
  ///
  /// In zh, this message translates to:
  /// **'创建第一部作品'**
  String get work_createFirstWork;

  /// No description provided for @work_createWork.
  ///
  /// In zh, this message translates to:
  /// **'新建作品'**
  String get work_createWork;

  /// No description provided for @work_creation.
  ///
  /// In zh, this message translates to:
  /// **'创作'**
  String get work_creation;

  /// No description provided for @work_creationSpace.
  ///
  /// In zh, this message translates to:
  /// **'创作空间'**
  String get work_creationSpace;

  /// No description provided for @work_creationSpaceDesc.
  ///
  /// In zh, this message translates to:
  /// **'浏览所有作品，快速筛选书架，并直接回到当前最重要的创作现场。'**
  String get work_creationSpaceDesc;

  /// No description provided for @work_creationSpaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'把正文、设定和创作节奏放在同一个地方。'**
  String get work_creationSpaceTitle;

  /// No description provided for @work_creationTools.
  ///
  /// In zh, this message translates to:
  /// **'创作工具'**
  String get work_creationTools;

  /// No description provided for @work_creationToolsDesc.
  ///
  /// In zh, this message translates to:
  /// **'在作品上下文里完成写作、AI 辅助、审阅和阅读切换。'**
  String get work_creationToolsDesc;

  /// No description provided for @work_crossWorkSearch.
  ///
  /// In zh, this message translates to:
  /// **'跨作品搜索'**
  String get work_crossWorkSearch;

  /// No description provided for @work_currentShowing.
  ///
  /// In zh, this message translates to:
  /// **'当前显示 {count} 部作品'**
  String work_currentShowing(Object count);

  /// No description provided for @work_currentWorkOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅当前作品'**
  String get work_currentWorkOnly;

  /// No description provided for @work_currentWorks.
  ///
  /// In zh, this message translates to:
  /// **'当前作品'**
  String get work_currentWorks;

  /// No description provided for @work_currentWorksHint.
  ///
  /// In zh, this message translates to:
  /// **'按当前书架筛选结果统计。'**
  String get work_currentWorksHint;

  /// No description provided for @work_customCover.
  ///
  /// In zh, this message translates to:
  /// **'已选择自定义封面'**
  String get work_customCover;

  /// No description provided for @work_dartStatusDesc.
  ///
  /// In zh, this message translates to:
  /// **'梳理世界观、搭建章节结构，把零散灵感沉淀成稳定稿件。'**
  String get work_dartStatusDesc;

  /// No description provided for @work_daysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{days}天前'**
  String work_daysAgo(Object days);

  /// No description provided for @work_defaultCover.
  ///
  /// In zh, this message translates to:
  /// **'未上传时将使用默认封面'**
  String get work_defaultCover;

  /// No description provided for @work_defaultCoverLabel.
  ///
  /// In zh, this message translates to:
  /// **'默认封面'**
  String get work_defaultCoverLabel;

  /// No description provided for @work_defaultStatusDesc.
  ///
  /// In zh, this message translates to:
  /// **'一个聚合章节、角色和世界设定的写作空间。'**
  String get work_defaultStatusDesc;

  /// No description provided for @work_draftStatus.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get work_draftStatus;

  /// No description provided for @work_drafts.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get work_drafts;

  /// No description provided for @work_draftsHint.
  ///
  /// In zh, this message translates to:
  /// **'还在搭框架和大纲阶段的作品。'**
  String get work_draftsHint;

  /// No description provided for @work_draftsLabel.
  ///
  /// In zh, this message translates to:
  /// **'草稿'**
  String get work_draftsLabel;

  /// No description provided for @work_editInfo.
  ///
  /// In zh, this message translates to:
  /// **'编辑信息'**
  String get work_editInfo;

  /// No description provided for @work_editProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑资料'**
  String get work_editProfile;

  /// No description provided for @work_editWork.
  ///
  /// In zh, this message translates to:
  /// **'编辑作品'**
  String get work_editWork;

  /// No description provided for @work_enterKeyword.
  ///
  /// In zh, this message translates to:
  /// **'先输入关键词'**
  String get work_enterKeyword;

  /// No description provided for @work_enterKeywordDesc.
  ///
  /// In zh, this message translates to:
  /// **'可以按标题、简介或实体名称搜索，快速定位到对应内容。'**
  String get work_enterKeywordDesc;

  /// No description provided for @work_exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String work_exportFailed(Object error);

  /// No description provided for @work_exportFormat.
  ///
  /// In zh, this message translates to:
  /// **'导出格式'**
  String get work_exportFormat;

  /// No description provided for @work_exportMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'Markdown'**
  String get work_exportMarkdown;

  /// No description provided for @work_exportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导出 {count} 个章节到 {path}'**
  String work_exportSuccess(Object count, Object path);

  /// No description provided for @work_exportTxt.
  ///
  /// In zh, this message translates to:
  /// **'纯文本'**
  String get work_exportTxt;

  /// No description provided for @work_exportWork.
  ///
  /// In zh, this message translates to:
  /// **'导出作品'**
  String get work_exportWork;

  /// No description provided for @work_exportZip.
  ///
  /// In zh, this message translates to:
  /// **'ZIP 压缩包'**
  String get work_exportZip;

  /// No description provided for @work_exporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导出...'**
  String get work_exporting;

  /// No description provided for @work_factions.
  ///
  /// In zh, this message translates to:
  /// **'势力'**
  String get work_factions;

  /// No description provided for @work_factionsDesc.
  ///
  /// In zh, this message translates to:
  /// **'管理组织、联盟和更大的权力结构。'**
  String get work_factionsDesc;

  /// No description provided for @work_featuredWork.
  ///
  /// In zh, this message translates to:
  /// **'当前焦点作品'**
  String get work_featuredWork;

  /// No description provided for @work_featuredWorkDesc.
  ///
  /// In zh, this message translates to:
  /// **'想继续写的时候，优先从这里恢复，而不是重新找上下文。'**
  String get work_featuredWorkDesc;

  /// No description provided for @work_globalScope.
  ///
  /// In zh, this message translates to:
  /// **'全局范围'**
  String get work_globalScope;

  /// No description provided for @work_globalSearch.
  ///
  /// In zh, this message translates to:
  /// **'全局搜索'**
  String get work_globalSearch;

  /// No description provided for @work_hideArchived.
  ///
  /// In zh, this message translates to:
  /// **'隐藏归档'**
  String get work_hideArchived;

  /// No description provided for @work_inWorkSearch.
  ///
  /// In zh, this message translates to:
  /// **'当前作品内搜索'**
  String get work_inWorkSearch;

  /// No description provided for @work_items.
  ///
  /// In zh, this message translates to:
  /// **'物品'**
  String get work_items;

  /// No description provided for @work_itemsDesc.
  ///
  /// In zh, this message translates to:
  /// **'整理道具、法宝和反复出现的重要物件。'**
  String get work_itemsDesc;

  /// No description provided for @work_library.
  ///
  /// In zh, this message translates to:
  /// **'作品库'**
  String get work_library;

  /// No description provided for @work_libraryDesc.
  ///
  /// In zh, this message translates to:
  /// **'书架上的所有作品都在这里，进度和状态一目了然。'**
  String get work_libraryDesc;

  /// No description provided for @work_loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'工作区加载失败'**
  String get work_loadFailed;

  /// No description provided for @work_loadFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取作品库。你可以重试，当前筛选条件会保留。'**
  String get work_loadFailedDescription;

  /// No description provided for @work_locations.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get work_locations;

  /// No description provided for @work_locationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'管理场景设定和地点相关线索。'**
  String get work_locationsDesc;

  /// No description provided for @work_moreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get work_moreActions;

  /// No description provided for @work_newChapter.
  ///
  /// In zh, this message translates to:
  /// **'新建章节'**
  String get work_newChapter;

  /// No description provided for @work_newChapterDefault.
  ///
  /// In zh, this message translates to:
  /// **'新章节'**
  String get work_newChapterDefault;

  /// No description provided for @work_newChapterLabel.
  ///
  /// In zh, this message translates to:
  /// **'新建章节'**
  String get work_newChapterLabel;

  /// No description provided for @work_newWork.
  ///
  /// In zh, this message translates to:
  /// **'新建作品'**
  String get work_newWork;

  /// No description provided for @work_noChaptersInVolume.
  ///
  /// In zh, this message translates to:
  /// **'这一卷还没有章节。'**
  String get work_noChaptersInVolume;

  /// No description provided for @work_noChaptersYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有章节'**
  String get work_noChaptersYet;

  /// No description provided for @work_noChaptersYetDesc.
  ///
  /// In zh, this message translates to:
  /// **'创建第一章时会自动生成第一卷，让作品从一开始就有清晰结构。'**
  String get work_noChaptersYetDesc;

  /// No description provided for @work_noMatchingResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配结果'**
  String get work_noMatchingResults;

  /// No description provided for @work_noMatchingResultsDesc.
  ///
  /// In zh, this message translates to:
  /// **'可以换个更宽泛的关键词，或重新打开归档范围。'**
  String get work_noMatchingResultsDesc;

  /// No description provided for @work_noResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配结果'**
  String get work_noResults;

  /// No description provided for @work_noResultsDesc.
  ///
  /// In zh, this message translates to:
  /// **'可以换个更宽泛的关键词，或切换搜索范围。'**
  String get work_noResultsDesc;

  /// No description provided for @work_noWorksYet.
  ///
  /// In zh, this message translates to:
  /// **'还没有作品'**
  String get work_noWorksYet;

  /// No description provided for @work_noWorksYetDesc.
  ///
  /// In zh, this message translates to:
  /// **'先创建第一部作品，建立你的写作工作区。'**
  String get work_noWorksYetDesc;

  /// No description provided for @work_notSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get work_notSet;

  /// No description provided for @work_ongoing.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get work_ongoing;

  /// No description provided for @work_ongoingStatus.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get work_ongoingStatus;

  /// No description provided for @work_ongoingStatusDesc.
  ///
  /// In zh, this message translates to:
  /// **'作品正在推进中。跟踪进度、保持节奏，并维持设定一致性。'**
  String get work_ongoingStatusDesc;

  /// No description provided for @work_openDetailDesc.
  ///
  /// In zh, this message translates to:
  /// **'打开作品详情页，管理章节、查看进度，并直接进入编辑器。'**
  String get work_openDetailDesc;

  /// No description provided for @work_openForm.
  ///
  /// In zh, this message translates to:
  /// **'打开表单'**
  String get work_openForm;

  /// No description provided for @work_openGlobalSearch.
  ///
  /// In zh, this message translates to:
  /// **'打开全局搜索'**
  String get work_openGlobalSearch;

  /// No description provided for @work_openReader.
  ///
  /// In zh, this message translates to:
  /// **'打开阅读器'**
  String get work_openReader;

  /// No description provided for @work_openWorkspace.
  ///
  /// In zh, this message translates to:
  /// **'打开工作区'**
  String get work_openWorkspace;

  /// No description provided for @work_otherType.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get work_otherType;

  /// No description provided for @work_pickImageFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择图片失败: {error}'**
  String work_pickImageFailed(Object error);

  /// No description provided for @work_pin.
  ///
  /// In zh, this message translates to:
  /// **'置顶作品'**
  String get work_pin;

  /// No description provided for @work_pinned.
  ///
  /// In zh, this message translates to:
  /// **'已置顶作品'**
  String get work_pinned;

  /// No description provided for @work_povGeneration.
  ///
  /// In zh, this message translates to:
  /// **'POV 生成'**
  String get work_povGeneration;

  /// No description provided for @work_povGenerationDesc.
  ///
  /// In zh, this message translates to:
  /// **'生成替代视角，扩展章节思路。'**
  String get work_povGenerationDesc;

  /// No description provided for @work_quickFind.
  ///
  /// In zh, this message translates to:
  /// **'快速查找'**
  String get work_quickFind;

  /// No description provided for @work_quickFindDesc.
  ///
  /// In zh, this message translates to:
  /// **'直接定位到目标页面，不必一层层点进去找。'**
  String get work_quickFindDesc;

  /// No description provided for @work_quickFindTitle.
  ///
  /// In zh, this message translates to:
  /// **'用一个搜索框查章节、角色和世界设定。'**
  String get work_quickFindTitle;

  /// No description provided for @work_readingMode.
  ///
  /// In zh, this message translates to:
  /// **'阅读模式'**
  String get work_readingMode;

  /// No description provided for @work_readingModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'切换到沉浸式阅读界面并保留进度。'**
  String get work_readingModeDesc;

  /// No description provided for @work_readingTime.
  ///
  /// In zh, this message translates to:
  /// **'约 {minutes} 分钟阅读'**
  String work_readingTime(Object minutes);

  /// No description provided for @work_refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get work_refresh;

  /// No description provided for @work_relationships.
  ///
  /// In zh, this message translates to:
  /// **'关系'**
  String get work_relationships;

  /// No description provided for @work_relationshipsDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看角色之间的联系、张力和变化历史。'**
  String get work_relationshipsDesc;

  /// No description provided for @work_restoreArchive.
  ///
  /// In zh, this message translates to:
  /// **'恢复归档'**
  String get work_restoreArchive;

  /// No description provided for @work_restored.
  ///
  /// In zh, this message translates to:
  /// **'已从归档恢复'**
  String get work_restored;

  /// No description provided for @work_retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get work_retry;

  /// No description provided for @work_reviewCenter.
  ///
  /// In zh, this message translates to:
  /// **'审阅中心'**
  String get work_reviewCenter;

  /// No description provided for @work_reviewCenterDesc.
  ///
  /// In zh, this message translates to:
  /// **'运行写作检查并查看历史审阅结果。'**
  String get work_reviewCenterDesc;

  /// No description provided for @work_reviewed.
  ///
  /// In zh, this message translates to:
  /// **'已审阅'**
  String get work_reviewed;

  /// No description provided for @work_reviewedHint.
  ///
  /// In zh, this message translates to:
  /// **'已有审阅分数的章节数量。'**
  String get work_reviewedHint;

  /// No description provided for @work_save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get work_save;

  /// No description provided for @work_saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String work_saveFailed(Object error);

  /// No description provided for @work_search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get work_search;

  /// No description provided for @work_searchCurrentWork.
  ///
  /// In zh, this message translates to:
  /// **'搜索当前作品'**
  String get work_searchCurrentWork;

  /// No description provided for @work_searchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败'**
  String get work_searchFailed;

  /// No description provided for @work_searchFailedDesc.
  ///
  /// In zh, this message translates to:
  /// **'这次查询没有完成，请重试。'**
  String get work_searchFailedDesc;

  /// No description provided for @work_searchGlobalHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索作品、章节、角色和地点'**
  String get work_searchGlobalHint;

  /// No description provided for @work_searchHint.
  ///
  /// In zh, this message translates to:
  /// **'按标题或简介筛选作品'**
  String get work_searchHint;

  /// No description provided for @work_searchInWorkHint.
  ///
  /// In zh, this message translates to:
  /// **'在当前作品内搜索'**
  String get work_searchInWorkHint;

  /// No description provided for @work_searchResults.
  ///
  /// In zh, this message translates to:
  /// **'筛选结果'**
  String get work_searchResults;

  /// No description provided for @work_searchResultsDesc.
  ///
  /// In zh, this message translates to:
  /// **'每条结果都会展示类型，方便你直接跳到正确位置。'**
  String get work_searchResultsDesc;

  /// No description provided for @work_searchResultsTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索结果'**
  String get work_searchResultsTitle;

  /// No description provided for @work_searchWorkContent.
  ///
  /// In zh, this message translates to:
  /// **'搜索作品内容'**
  String get work_searchWorkContent;

  /// No description provided for @work_searchWorkContentDesc.
  ///
  /// In zh, this message translates to:
  /// **'直接跳到章节、角色或设定条目。'**
  String get work_searchWorkContentDesc;

  /// No description provided for @work_serializing.
  ///
  /// In zh, this message translates to:
  /// **'部连载中'**
  String get work_serializing;

  /// No description provided for @work_serializingHint.
  ///
  /// In zh, this message translates to:
  /// **'正在持续推进章节的作品。'**
  String get work_serializingHint;

  /// No description provided for @work_serializingLabel.
  ///
  /// In zh, this message translates to:
  /// **'连载中'**
  String get work_serializingLabel;

  /// No description provided for @work_settings.
  ///
  /// In zh, this message translates to:
  /// **'设定'**
  String get work_settings;

  /// No description provided for @work_showArchived.
  ///
  /// In zh, this message translates to:
  /// **'显示归档'**
  String get work_showArchived;

  /// No description provided for @work_startNewWork.
  ///
  /// In zh, this message translates to:
  /// **'开始新作品'**
  String get work_startNewWork;

  /// No description provided for @work_startSearch.
  ///
  /// In zh, this message translates to:
  /// **'开始搜索'**
  String get work_startSearch;

  /// No description provided for @work_statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get work_statistics;

  /// No description provided for @work_statisticsDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看字数、趋势和整体进度。'**
  String get work_statisticsDesc;

  /// No description provided for @work_target.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get work_target;

  /// No description provided for @work_targetWords.
  ///
  /// In zh, this message translates to:
  /// **'目标字数（可选）'**
  String get work_targetWords;

  /// No description provided for @work_targetWordsHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：100000'**
  String get work_targetWordsHint;

  /// No description provided for @work_targetWordsInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的字数'**
  String get work_targetWordsInvalid;

  /// No description provided for @work_targetWordsUnit.
  ///
  /// In zh, this message translates to:
  /// **'字'**
  String get work_targetWordsUnit;

  /// No description provided for @work_timeline.
  ///
  /// In zh, this message translates to:
  /// **'时间线'**
  String get work_timeline;

  /// No description provided for @work_timelineDesc.
  ///
  /// In zh, this message translates to:
  /// **'检查事件顺序、冲突和时间一致性。'**
  String get work_timelineDesc;

  /// No description provided for @work_today.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get work_today;

  /// No description provided for @work_total.
  ///
  /// In zh, this message translates to:
  /// **'总数'**
  String get work_total;

  /// No description provided for @work_totalWords.
  ///
  /// In zh, this message translates to:
  /// **'总字数'**
  String get work_totalWords;

  /// No description provided for @work_totalWordsHint.
  ///
  /// In zh, this message translates to:
  /// **'所有章节累计的文本字数。'**
  String get work_totalWordsHint;

  /// No description provided for @work_typeChapter.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get work_typeChapter;

  /// No description provided for @work_typeCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get work_typeCharacter;

  /// No description provided for @work_typeFaction.
  ///
  /// In zh, this message translates to:
  /// **'势力'**
  String get work_typeFaction;

  /// No description provided for @work_typeItem.
  ///
  /// In zh, this message translates to:
  /// **'物品'**
  String get work_typeItem;

  /// No description provided for @work_typeLocation.
  ///
  /// In zh, this message translates to:
  /// **'地点'**
  String get work_typeLocation;

  /// No description provided for @work_typeWork.
  ///
  /// In zh, this message translates to:
  /// **'作品'**
  String get work_typeWork;

  /// No description provided for @work_unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get work_unpin;

  /// No description provided for @work_unpinned.
  ///
  /// In zh, this message translates to:
  /// **'已取消置顶'**
  String get work_unpinned;

  /// No description provided for @work_updateArchiveFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新归档状态失败：{error}'**
  String work_updateArchiveFailed(Object error);

  /// No description provided for @work_updatePinFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新置顶状态失败：{error}'**
  String work_updatePinFailed(Object error);

  /// No description provided for @work_uploadCover.
  ///
  /// In zh, this message translates to:
  /// **'上传封面'**
  String get work_uploadCover;

  /// No description provided for @work_uploadLater.
  ///
  /// In zh, this message translates to:
  /// **'可稍后再上传'**
  String get work_uploadLater;

  /// No description provided for @work_useDefaultCover.
  ///
  /// In zh, this message translates to:
  /// **'使用默认封面'**
  String get work_useDefaultCover;

  /// No description provided for @work_volumeChaptersWords.
  ///
  /// In zh, this message translates to:
  /// **'{chapters} 章，{words} 字'**
  String work_volumeChaptersWords(Object chapters, Object words);

  /// No description provided for @work_volumeCount.
  ///
  /// In zh, this message translates to:
  /// **'卷数'**
  String get work_volumeCount;

  /// No description provided for @work_volumes.
  ///
  /// In zh, this message translates to:
  /// **'卷'**
  String get work_volumes;

  /// No description provided for @work_volumesHint.
  ///
  /// In zh, this message translates to:
  /// **'用于组织故事弧线或章节分组。'**
  String get work_volumesHint;

  /// No description provided for @work_wordProgress.
  ///
  /// In zh, this message translates to:
  /// **'{current} / {target} 字'**
  String work_wordProgress(Object current, Object target);

  /// No description provided for @work_wordsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String work_wordsCount(Object count);

  /// No description provided for @work_wordsStatus.
  ///
  /// In zh, this message translates to:
  /// **'{words} 字，{status}'**
  String work_wordsStatus(Object status, Object words);

  /// No description provided for @work_workCreated.
  ///
  /// In zh, this message translates to:
  /// **'作品已创建：{name}'**
  String work_workCreated(Object name);

  /// No description provided for @work_workDescription.
  ///
  /// In zh, this message translates to:
  /// **'作品简介'**
  String get work_workDescription;

  /// No description provided for @work_workDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'简要描述作品内容'**
  String get work_workDescriptionHint;

  /// No description provided for @work_workDetailDesc.
  ///
  /// In zh, this message translates to:
  /// **'这里集中管理这部作品的章节、世界设定、审阅结果和写作进度。'**
  String get work_workDetailDesc;

  /// No description provided for @work_workDetailSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'和这部作品有关的内容，都集中在这个工作区里。'**
  String get work_workDetailSubtitle;

  /// No description provided for @work_workName.
  ///
  /// In zh, this message translates to:
  /// **'作品名称'**
  String get work_workName;

  /// No description provided for @work_workNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入作品名称'**
  String get work_workNameHint;

  /// No description provided for @work_workNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入作品名称'**
  String get work_workNameRequired;

  /// No description provided for @work_workNameTooLong.
  ///
  /// In zh, this message translates to:
  /// **'作品名称不能超过 100 字'**
  String get work_workNameTooLong;

  /// No description provided for @work_workNotExist.
  ///
  /// In zh, this message translates to:
  /// **'作品不存在'**
  String get work_workNotExist;

  /// No description provided for @work_workNotExistDesc.
  ///
  /// In zh, this message translates to:
  /// **'找不到当前选中的作品工作区。'**
  String get work_workNotExistDesc;

  /// No description provided for @work_workNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到作品'**
  String get work_workNotFound;

  /// No description provided for @work_workNotFoundDesc.
  ///
  /// In zh, this message translates to:
  /// **'这部作品当前不可用，请返回作品库后重新打开。'**
  String get work_workNotFoundDesc;

  /// No description provided for @work_workSettings.
  ///
  /// In zh, this message translates to:
  /// **'作品设置'**
  String get work_workSettings;

  /// No description provided for @work_workSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'打开完整设置区域，管理作品元数据和全局配置。'**
  String get work_workSettingsDesc;

  /// No description provided for @work_workSettingsLabel.
  ///
  /// In zh, this message translates to:
  /// **'作品设置'**
  String get work_workSettingsLabel;

  /// No description provided for @work_workType.
  ///
  /// In zh, this message translates to:
  /// **'作品类型'**
  String get work_workType;

  /// No description provided for @work_workUpdated.
  ///
  /// In zh, this message translates to:
  /// **'作品已更新：{name}'**
  String work_workUpdated(Object name);

  /// No description provided for @work_workbenchSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'把作品、设定和正在推进的章节集中在一个界面里。'**
  String get work_workbenchSubtitle;

  /// No description provided for @work_workspaceLabel.
  ///
  /// In zh, this message translates to:
  /// **'工作区'**
  String get work_workspaceLabel;

  /// No description provided for @work_workspaceOverview.
  ///
  /// In zh, this message translates to:
  /// **'工作区概览'**
  String get work_workspaceOverview;

  /// No description provided for @work_workspaceOverviewDesc.
  ///
  /// In zh, this message translates to:
  /// **'快速看一眼当前书架的整体状态。'**
  String get work_workspaceOverviewDesc;

  /// No description provided for @work_workspaceStatus.
  ///
  /// In zh, this message translates to:
  /// **'工作区状态'**
  String get work_workspaceStatus;

  /// No description provided for @work_worldSettings.
  ///
  /// In zh, this message translates to:
  /// **'世界设定'**
  String get work_worldSettings;

  /// No description provided for @work_worldSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'角色、地点、关系和各种设定资料都在这里整理。'**
  String get work_worldSettingsDesc;

  /// No description provided for @work_writingWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'写作工作台'**
  String get work_writingWorkbench;

  /// No description provided for @work_writtenWords.
  ///
  /// In zh, this message translates to:
  /// **'已写 {count} 字'**
  String work_writtenWords(Object count);

  /// No description provided for @work_yesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get work_yesterday;

  /// No description provided for @yes.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get yes;

  /// No description provided for @work_workDetailDesc2.
  ///
  /// In zh, this message translates to:
  /// **'管理这部作品的章节、世界设定、审阅结果和写作进度。'**
  String get work_workDetailDesc2;

  /// No description provided for @work_workSettingsDesc2.
  ///
  /// In zh, this message translates to:
  /// **'打开完整设置区域，管理作品元数据和全局配置。'**
  String get work_workSettingsDesc2;

  /// No description provided for @settings_manuallyEdited.
  ///
  /// In zh, this message translates to:
  /// **'手动编辑'**
  String get settings_manuallyEdited;

  /// No description provided for @settings_manuallyCreated.
  ///
  /// In zh, this message translates to:
  /// **'手动创建'**
  String get settings_manuallyCreated;

  /// No description provided for @settings_delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get settings_delete;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return SEn();
    case 'zh':
      return SZh();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
