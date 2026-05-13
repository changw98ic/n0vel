/// Centralised, language-aware prompt templates for the story-generation pipeline.
///
/// Every system prompt used across scene generators, reviewers, resolvers,
/// and thought extractors lives here so that prompt content is decoupled from
/// orchestration logic.  To tweak any prompt, edit the relevant
/// [PromptLocale] in `prompt_language.dart` — no other code needs to change.
///
/// To switch languages for a generation run:
/// ```dart
/// StoryPromptTemplates.runWithLanguage(PromptLanguage.en, () async {
///   // build prompts here
/// });
/// ```
///
/// Format labels (目标/Target, 决定/Decision, etc.) are also exposed here so
/// that parsers can stay in sync with the prompt language.
///
/// Naming convention: `sys<Domain><Purpose>`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_version.dart';

import 'prompt_language.dart';
import '../../../domain/prompt_language.dart';

const Object _promptLanguageZoneKey = Object();

class StoryPromptTemplates {
  StoryPromptTemplates._();

  // ---------------------------------------------------------------------------
  // Prompt versions
  // ---------------------------------------------------------------------------

  /// 当前所有 prompt 模板的版本标识。
  ///
  /// 每次 prompt 内容变更时应递增版本号，以便追踪和回放。
  static const PromptVersion versionSceneProse = PromptVersion(
    templateId: 'scene_prose',
    version: '1.0.0',
  );

  static const PromptVersion versionSceneDirector = PromptVersion(
    templateId: 'scene_director',
    version: '1.0.0',
  );

  static const PromptVersion versionSceneEditorial = PromptVersion(
    templateId: 'scene_editorial',
    version: '1.0.0',
  );

  static const PromptVersion versionSceneReview = PromptVersion(
    templateId: 'scene_review',
    version: '1.0.0',
  );

  static const PromptVersion versionDynamicRoleAgent = PromptVersion(
    templateId: 'dynamic_role_agent',
    version: '1.0.0',
  );

  static const PromptVersion versionSceneBeatResolve = PromptVersion(
    templateId: 'scene_beat_resolve',
    version: '1.0.0',
  );

  static const PromptVersion versionThoughtExtraction = PromptVersion(
    templateId: 'thought_extraction',
    version: '1.0.0',
  );

  // ---------------------------------------------------------------------------
  // Language switch
  // ---------------------------------------------------------------------------

  /// Default prompt language used when no Zone override is active.
  /// Production code should use [runWithLanguage] for per-run isolation.
  static PromptLanguage _language = PromptLanguage.zh;

  static PromptLanguage get language =>
      Zone.current[_promptLanguageZoneKey] as PromptLanguage? ?? _language;

  @visibleForTesting
  static set language(PromptLanguage value) {
    _language = value;
  }

  static R runWithLanguage<R>(PromptLanguage language, R Function() body) {
    return runZoned(body, zoneValues: {_promptLanguageZoneKey: language});
  }

  /// The active [PromptLocale] for the current [language].
  static PromptLocale get locale => PromptLocale.forLanguage(language);

  // ---------------------------------------------------------------------------
  // Scene prose generation
  // ---------------------------------------------------------------------------

  /// [SceneProseGenerator] system instruction.
  static String get sysSceneProse => locale.sysSceneProse;

  // ---------------------------------------------------------------------------
  // Scene direction
  // ---------------------------------------------------------------------------

  /// [SceneDirectorOrchestrator] polish pass system instruction.
  static String get sysSceneDirectorPolish => locale.sysSceneDirectorPolish;

  // ---------------------------------------------------------------------------
  // Scene editorial (beat stitching)
  // ---------------------------------------------------------------------------

  /// [SceneEditorialGenerator] system instruction.
  static String get sysSceneEditorial => locale.sysSceneEditorial;

  // ---------------------------------------------------------------------------
  // Scene review
  // ---------------------------------------------------------------------------

  /// [SceneReviewCoordinator] system instruction.
  ///
  /// [passName] is substituted at call site (e.g. "scene judge review").
  static String sysSceneReview(String passName) =>
      locale.sysSceneReviewTemplate.replaceAll('{passName}', passName);

  // ---------------------------------------------------------------------------
  // Dynamic role agent
  // ---------------------------------------------------------------------------

  /// [DynamicRoleAgentRunner] system instruction — without tool retrieval.
  static String get sysDynamicRoleAgent => locale.sysDynamicRoleAgent;

  /// [DynamicRoleAgentRunner] system instruction — with tool retrieval.
  static String get sysDynamicRoleAgentWithTools =>
      locale.sysDynamicRoleAgentWithTools;

  // ---------------------------------------------------------------------------
  // Scene beat resolution
  // ---------------------------------------------------------------------------

  /// [SceneStateResolver] system instruction.
  static String get sysSceneBeatResolve => locale.sysSceneBeatResolve;

  // ---------------------------------------------------------------------------
  // Thought extraction
  // ---------------------------------------------------------------------------

  /// [_StoryThoughtLlmRefiner] system instruction for extracting thought atoms.
  static String get sysThoughtExtraction => locale.sysThoughtExtraction;
}
