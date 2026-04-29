/// Centralised, language-aware prompt templates for the story-generation pipeline.
///
/// Every system prompt used across scene generators, reviewers, resolvers,
/// and thought extractors lives here so that prompt content is decoupled from
/// orchestration logic.  To tweak any prompt, edit the relevant
/// [PromptLocale] in `prompt_language.dart` — no other code needs to change.
///
/// To switch languages at runtime:
/// ```dart
/// StoryPromptTemplates.language = PromptLanguage.en;
/// ```
///
/// Format labels (目标/Target, 决定/Decision, etc.) are also exposed here so
/// that parsers can stay in sync with the prompt language.
///
/// Naming convention: `sys<Domain><Purpose>`.
library;

import 'prompt_language.dart';

class StoryPromptTemplates {
  StoryPromptTemplates._();

  // ---------------------------------------------------------------------------
  // Language switch
  // ---------------------------------------------------------------------------

  /// Current prompt language. Defaults to [PromptLanguage.zh].
  static PromptLanguage language = PromptLanguage.zh;

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
