import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_templates.dart';

void main() {
  // Reset language after each test to avoid cross-test pollution.
  tearDown(() {
    StoryPromptTemplates.language = PromptLanguage.zh;
  });

  // ===========================================================================
  // PromptLanguage
  // ===========================================================================
  group('PromptLanguage', () {
    test('has exactly two values', () {
      expect(PromptLanguage.values, hasLength(2));
      expect(
        PromptLanguage.values,
        containsAll([PromptLanguage.zh, PromptLanguage.en]),
      );
    });
  });

  // ===========================================================================
  // PromptLocale
  // ===========================================================================
  group('PromptLocale', () {
    test('forLanguage returns zh locale for zh', () {
      final locale = PromptLocale.forLanguage(PromptLanguage.zh);
      expect(locale.novelLanguage, 'Chinese');
      expect(locale.colon, '：');
    });

    test('forLanguage returns en locale for en', () {
      final locale = PromptLocale.forLanguage(PromptLanguage.en);
      expect(locale.novelLanguage, 'English');
      expect(locale.colon, ': ');
    });

    test('zh and en locales have different format labels', () {
      expect(
        PromptLocale.zh.targetLabel,
        isNot(equals(PromptLocale.en.targetLabel)),
      );
      expect(
        PromptLocale.zh.conflictLabel,
        isNot(equals(PromptLocale.en.conflictLabel)),
      );
      expect(
        PromptLocale.zh.decisionLabel,
        isNot(equals(PromptLocale.en.decisionLabel)),
      );
      expect(
        PromptLocale.zh.reasonLabel,
        isNot(equals(PromptLocale.en.reasonLabel)),
      );
      expect(PromptLocale.zh.beatFact, isNot(equals(PromptLocale.en.beatFact)));
    });

    test('zh locale beat tags match original Chinese labels', () {
      final zh = PromptLocale.zh;
      expect(zh.beatFact, '事实');
      expect(zh.beatDialogue, '对白');
      expect(zh.beatAction, '动作');
      expect(zh.beatInternal, '心理');
      expect(zh.beatNarration, '叙述');
    });

    test('en locale beat tags are English', () {
      final en = PromptLocale.en;
      expect(en.beatFact, 'Fact');
      expect(en.beatDialogue, 'Dialogue');
      expect(en.beatAction, 'Action');
      expect(en.beatInternal, 'Internal');
      expect(en.beatNarration, 'Narration');
    });

    test('zh locale has tension and calm keywords', () {
      expect(PromptLocale.zh.tensionKeywords, isNotEmpty);
      expect(PromptLocale.zh.calmKeywords, isNotEmpty);
      expect(PromptLocale.zh.tensionKeywords, contains('冲突'));
      expect(PromptLocale.zh.calmKeywords, contains('平静'));
    });

    test('en locale has tension and calm keywords', () {
      expect(PromptLocale.en.tensionKeywords, isNotEmpty);
      expect(PromptLocale.en.calmKeywords, isNotEmpty);
      expect(PromptLocale.en.tensionKeywords, contains('conflict'));
      expect(PromptLocale.en.calmKeywords, contains('calm'));
    });

    test('beatTags returns all five beat tags', () {
      expect(PromptLocale.zh.beatTags, hasLength(5));
      expect(PromptLocale.en.beatTags, hasLength(5));
    });

    test('all system prompts are non-empty for both locales', () {
      for (final locale in [PromptLocale.zh, PromptLocale.en]) {
        expect(locale.sysSceneProse, isNotEmpty);
        expect(locale.sysSceneDirectorPolish, isNotEmpty);
        expect(locale.sysSceneEditorial, isNotEmpty);
        expect(locale.sysSceneReviewTemplate, isNotEmpty);
        expect(locale.sysDynamicRoleAgent, isNotEmpty);
        expect(locale.sysDynamicRoleAgentWithTools, isNotEmpty);
        expect(locale.sysSceneBeatResolve, isNotEmpty);
        expect(locale.sysThoughtExtraction, isNotEmpty);
      }
    });

    test('sysSceneReviewTemplate contains {passName} placeholder', () {
      for (final locale in [PromptLocale.zh, PromptLocale.en]) {
        expect(locale.sysSceneReviewTemplate, contains('{passName}'));
      }
    });
  });

  // ===========================================================================
  // StoryPromptTemplates — language switching
  // ===========================================================================
  group('StoryPromptTemplates language switching', () {
    test('defaults to zh', () {
      expect(StoryPromptTemplates.language, PromptLanguage.zh);
      expect(StoryPromptTemplates.locale.novelLanguage, 'Chinese');
    });

    test('switching to en changes all templates', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      expect(StoryPromptTemplates.locale.novelLanguage, 'English');
      expect(StoryPromptTemplates.sysSceneProse, contains('English'));
      expect(StoryPromptTemplates.sysSceneDirectorPolish, contains('English'));
      expect(StoryPromptTemplates.sysSceneEditorial, contains('English'));
      expect(StoryPromptTemplates.sysDynamicRoleAgent, contains('English'));
      expect(
        StoryPromptTemplates.sysDynamicRoleAgentWithTools,
        contains('English'),
      );
      expect(StoryPromptTemplates.sysSceneBeatResolve, contains('English'));
    });

    test('switching to zh restores Chinese templates', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      StoryPromptTemplates.language = PromptLanguage.zh;
      expect(StoryPromptTemplates.sysSceneProse, contains('Chinese'));
    });

    test(
      'runWithLanguage scopes locale without mutating global default',
      () async {
        StoryPromptTemplates.language = PromptLanguage.zh;

        final scopedLanguage = await StoryPromptTemplates.runWithLanguage(
          PromptLanguage.en,
          () async {
            await Future<void>.delayed(Duration.zero);
            return StoryPromptTemplates.locale.novelLanguage;
          },
        );

        expect(scopedLanguage, 'English');
        expect(StoryPromptTemplates.language, PromptLanguage.zh);
      },
    );

    test('sysSceneReview interpolates passName', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      final result = StoryPromptTemplates.sysSceneReview('scene judge review');
      expect(result, contains('scene judge review'));
      expect(result, contains('决定'));
    });

    test('sysSceneReview interpolates passName in English', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final result = StoryPromptTemplates.sysSceneReview('scene judge review');
      expect(result, contains('scene judge review'));
      expect(result, contains('Decision'));
    });

    test('format labels change with language', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      expect(StoryPromptTemplates.locale.targetLabel, '目标');
      expect(StoryPromptTemplates.locale.conflictLabel, '冲突');

      StoryPromptTemplates.language = PromptLanguage.en;
      expect(StoryPromptTemplates.locale.targetLabel, 'Target');
      expect(StoryPromptTemplates.locale.conflictLabel, 'Conflict');
    });

    test('director plan format labels used in building plans', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final l = StoryPromptTemplates.locale;
      expect('${l.targetLabel}${l.colon}test', equals('Target: test'));
      expect('${l.conflictLabel}${l.colon}test', equals('Conflict: test'));
    });
  });

  // ===========================================================================
  // AppSettingsSnapshot — promptLanguage persistence
  // ===========================================================================
  group('AppSettingsSnapshot promptLanguage', () {
    test('defaults to zh', () {
      const snapshot = AppSettingsSnapshot(
        providerName: 'test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'key',
        timeoutMs: 30000,
        maxConcurrentRequests: 1,
        maxTokens: 1024,
        hasApiKey: true,
        themePreference: AppThemePreference.light,
      );
      expect(snapshot.promptLanguage, PromptLanguage.zh);
    });

    test('toJson includes promptLanguage', () {
      const snapshot = AppSettingsSnapshot(
        providerName: 'test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'key',
        timeoutMs: 30000,
        maxConcurrentRequests: 1,
        maxTokens: 1024,
        hasApiKey: true,
        themePreference: AppThemePreference.light,
        promptLanguage: PromptLanguage.en,
      );
      final json = snapshot.toJson();
      expect(json['promptLanguage'], 'en');
    });

    test('fromJson reads promptLanguage', () {
      final json = {
        'providerName': 'test',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-4.1-mini',
        'apiKey': 'key',
        'timeoutMs': 30000,
        'maxConcurrentRequests': 1,
        'promptLanguage': 'en',
      };
      final snapshot = AppSettingsSnapshot.fromJson(json);
      expect(snapshot.promptLanguage, PromptLanguage.en);
    });

    test('fromJson defaults to zh when promptLanguage is missing', () {
      final json = {
        'providerName': 'test',
        'baseUrl': 'https://api.example.com/v1',
        'model': 'gpt-4.1-mini',
        'apiKey': 'key',
        'timeoutMs': 30000,
        'maxConcurrentRequests': 1,
      };
      final snapshot = AppSettingsSnapshot.fromJson(json);
      expect(snapshot.promptLanguage, PromptLanguage.zh);
    });

    test('copyWith preserves promptLanguage', () {
      const snapshot = AppSettingsSnapshot(
        providerName: 'test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'key',
        timeoutMs: 30000,
        maxConcurrentRequests: 1,
        maxTokens: 1024,
        hasApiKey: true,
        themePreference: AppThemePreference.light,
        promptLanguage: PromptLanguage.en,
      );
      final copied = snapshot.copyWith(model: 'new-model');
      expect(copied.promptLanguage, PromptLanguage.en);
      expect(copied.model, 'new-model');
    });

    test('copyWith can change promptLanguage', () {
      const snapshot = AppSettingsSnapshot(
        providerName: 'test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'key',
        timeoutMs: 30000,
        maxConcurrentRequests: 1,
        maxTokens: 1024,
        hasApiKey: true,
        themePreference: AppThemePreference.light,
      );
      final copied = snapshot.copyWith(promptLanguage: PromptLanguage.en);
      expect(copied.promptLanguage, PromptLanguage.en);
    });

    test('roundtrip zh preserves language', () {
      const snapshot = AppSettingsSnapshot(
        providerName: 'test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'key',
        timeoutMs: 30000,
        maxConcurrentRequests: 1,
        maxTokens: 1024,
        hasApiKey: true,
        themePreference: AppThemePreference.light,
        promptLanguage: PromptLanguage.zh,
      );
      final restored = AppSettingsSnapshot.fromJson(snapshot.toJson());
      expect(restored.promptLanguage, PromptLanguage.zh);
    });

    test('roundtrip en preserves language', () {
      const snapshot = AppSettingsSnapshot(
        providerName: 'test',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4.1-mini',
        apiKey: 'key',
        timeoutMs: 30000,
        maxConcurrentRequests: 1,
        maxTokens: 1024,
        hasApiKey: true,
        themePreference: AppThemePreference.light,
        promptLanguage: PromptLanguage.en,
      );
      final restored = AppSettingsSnapshot.fromJson(snapshot.toJson());
      expect(restored.promptLanguage, PromptLanguage.en);
    });
  });

  // ===========================================================================
  // User prompt field labels
  // ===========================================================================
  group('PromptLocale user prompt field labels', () {
    test('zh locale has all user prompt labels', () {
      final zh = PromptLocale.zh;
      expect(zh.taskLabel, '任务');
      expect(zh.sceneLabel, '场景');
      expect(zh.sceneShortLabel, '场');
      expect(zh.summaryLabel, '摘要');
      expect(zh.directorLabel, '导演');
      expect(zh.directorPlanLabel, '导演计划');
      expect(zh.roleInputLabel, '角色输入');
      expect(zh.targetLengthLabel, '目标字数');
      expect(zh.charactersUnit, '汉字');
      expect(zh.currentAttemptLabel, '当前尝试');
      expect(zh.noneLabel, '无');
      expect(zh.rewriteFeedbackLabel, '复写反馈');
      expect(zh.editorialFeedbackLabel, '编辑反馈');
      expect(zh.proseLabel, '正文');
      expect(zh.reviewLabel, '评审');
      expect(zh.rulesOnlyBlocking, '规则：聚焦阻塞问题，正文改写交给后续步骤');
      expect(zh.knownFactsLabel, '已知事实');
      expect(zh.toneFieldLabel, '基调');
      expect(zh.pacingFieldLabel, '节奏');
      expect(zh.contextLabel, '上下文');
      expect(zh.retrievalContextLabel, '检索上下文');
      expect(zh.sceneBeatsLabel, '场景拍');
      expect(zh.listSeparator, '；');
    });

    test('en locale has all user prompt labels', () {
      final en = PromptLocale.en;
      expect(en.taskLabel, 'Task');
      expect(en.sceneLabel, 'Scene');
      expect(en.sceneShortLabel, 'Scene');
      expect(en.summaryLabel, 'Summary');
      expect(en.directorLabel, 'Director');
      expect(en.directorPlanLabel, 'Director plan');
      expect(en.roleInputLabel, 'Role input');
      expect(en.targetLengthLabel, 'Target length');
      expect(en.charactersUnit, 'characters');
      expect(en.currentAttemptLabel, 'Current attempt');
      expect(en.noneLabel, 'None');
      expect(en.rewriteFeedbackLabel, 'Rewrite feedback');
      expect(en.editorialFeedbackLabel, 'Editorial feedback');
      expect(en.proseLabel, 'Prose');
      expect(en.reviewLabel, 'Review');
      expect(
        en.rulesOnlyBlocking,
        'Rules: focus on blocking issues; prose rewriting happens in later steps',
      );
      expect(en.knownFactsLabel, 'Known facts');
      expect(en.toneFieldLabel, 'Tone');
      expect(en.pacingFieldLabel, 'Pacing');
      expect(en.contextLabel, 'Context');
      expect(en.retrievalContextLabel, 'Retrieval context');
      expect(en.sceneBeatsLabel, 'Scene beats');
      expect(en.listSeparator, '; ');
    });

    test('zh and en user prompt labels differ', () {
      expect(
        PromptLocale.zh.taskLabel,
        isNot(equals(PromptLocale.en.taskLabel)),
      );
      expect(
        PromptLocale.zh.summaryLabel,
        isNot(equals(PromptLocale.en.summaryLabel)),
      );
      expect(
        PromptLocale.zh.noneLabel,
        isNot(equals(PromptLocale.en.noneLabel)),
      );
      expect(
        PromptLocale.zh.listSeparator,
        isNot(equals(PromptLocale.en.listSeparator)),
      );
    });
  });

  // ===========================================================================
  // SceneDirectorPlan — locale-aware toText / tryParse
  // ===========================================================================
  group('SceneDirectorPlan locale-aware', () {
    tearDown(() {
      StoryPromptTemplates.language = PromptLanguage.zh;
    });

    test('toText produces Chinese format in zh mode', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      final plan = SceneDirectorPlan(
        target: '揭露真相',
        conflict: '信任危机',
        progression: '对峙升级',
        constraints: '不能离开房间',
      );
      final text = plan.toText();
      expect(text, contains('目标：揭露真相'));
      expect(text, contains('冲突：信任危机'));
      expect(text, contains('推进：对峙升级'));
      expect(text, contains('约束：不能离开房间'));
    });

    test('toText produces English format in en mode', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final plan = SceneDirectorPlan(
        target: 'reveal the truth',
        conflict: 'trust crisis',
        progression: 'confrontation escalates',
        constraints: 'cannot leave the room',
      );
      final text = plan.toText();
      expect(text, contains('Target: reveal the truth'));
      expect(text, contains('Conflict: trust crisis'));
      expect(text, contains('Progression: confrontation escalates'));
      expect(text, contains('Constraint: cannot leave the room'));
    });

    test('tryParse parses Chinese format in zh mode', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      final plan = SceneDirectorPlan.tryParse(
        '目标：揭露真相\n冲突：信任危机\n推进：对峙升级\n约束：不能离开房间',
      );
      expect(plan, isNotNull);
      expect(plan!.target, '揭露真相');
      expect(plan.conflict, '信任危机');
      expect(plan.progression, '对峙升级');
      expect(plan.constraints, '不能离开房间');
    });

    test('tryParse parses English format in en mode', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final plan = SceneDirectorPlan.tryParse(
        'Target: reveal the truth\nConflict: trust crisis\nProgression: confrontation escalates\nConstraint: cannot leave the room',
      );
      expect(plan, isNotNull);
      expect(plan!.target, 'reveal the truth');
      expect(plan.conflict, 'trust crisis');
      expect(plan.progression, 'confrontation escalates');
      expect(plan.constraints, 'cannot leave the room');
    });

    test('tryParse returns null for wrong language format', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final plan = SceneDirectorPlan.tryParse(
        '目标：揭露真相\n冲突：信任危机\n推进：对峙升级\n约束：不能离开房间',
      );
      expect(plan, isNull);
    });

    test('roundtrip zh: toText then tryParse', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      final original = SceneDirectorPlan(
        target: 'a',
        conflict: 'b',
        progression: 'c',
        constraints: 'd',
      );
      final restored = SceneDirectorPlan.tryParse(original.toText());
      expect(restored, isNotNull);
      expect(restored!.target, 'a');
      expect(restored.conflict, 'b');
      expect(restored.progression, 'c');
      expect(restored.constraints, 'd');
    });

    test('roundtrip en: toText then tryParse', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final original = SceneDirectorPlan(
        target: 'a',
        conflict: 'b',
        progression: 'c',
        constraints: 'd',
      );
      final restored = SceneDirectorPlan.tryParse(original.toText());
      expect(restored, isNotNull);
      expect(restored!.target, 'a');
      expect(restored.conflict, 'b');
      expect(restored.progression, 'c');
      expect(restored.constraints, 'd');
    });
  });

  // ===========================================================================
  // RolePlayTurnOutput — locale-aware parsing
  // ===========================================================================
  group('RolePlayTurnOutput locale-aware parsing', () {
    tearDown(() {
      StoryPromptTemplates.language = PromptLanguage.zh;
    });

    test('parses Chinese role agent output in zh mode', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      final output = DynamicRoleAgentOutput(
        characterId: 'char01',
        name: 'Alice',
        text: '立场：坚定\n动作：转身离开\n禁忌：妥协',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);
      expect(turn.stance, '坚定');
      expect(turn.action, '转身离开');
      expect(turn.taboo, '妥协');
    });

    test('parses English role agent output in en mode', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final output = DynamicRoleAgentOutput(
        characterId: 'char01',
        name: 'Alice',
        text: 'Stance: firm\nAction: turns and leaves\nTaboo: compromise',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);
      expect(turn.stance, 'firm');
      expect(turn.action, 'turns and leaves');
      expect(turn.taboo, 'compromise');
    });

    test('parses Chinese retrieval intent in zh mode', () {
      StoryPromptTemplates.language = PromptLanguage.zh;
      final output = DynamicRoleAgentOutput(
        characterId: 'char01',
        name: 'Alice',
        text: '立场：怀疑\n动作：质问\n禁忌：暴力\n检索：character_profile|主角背景|确认动机',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);
      expect(turn.retrievalIntents, hasLength(1));
      expect(turn.retrievalIntents[0].toolName, 'character_profile');
      expect(turn.retrievalIntents[0].query, '主角背景');
    });

    test('parses English retrieval intent in en mode', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final output = DynamicRoleAgentOutput(
        characterId: 'char01',
        name: 'Alice',
        text:
            'Stance: suspicious\nAction: questions\nTaboo: violence\nRetrieval: character_profile|protagonist background|confirm motive',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);
      expect(turn.retrievalIntents, hasLength(1));
      expect(turn.retrievalIntents[0].toolName, 'character_profile');
    });

    test('wrong language format yields empty fields', () {
      StoryPromptTemplates.language = PromptLanguage.en;
      final output = DynamicRoleAgentOutput(
        characterId: 'char01',
        name: 'Alice',
        text: '立场：坚定\n动作：转身离开\n禁忌：妥协',
      );
      final turn = RolePlayTurnOutput.fromDynamicAgentOutput(output);
      expect(turn.stance, '');
      expect(turn.action, '');
      expect(turn.taboo, '');
    });
  });
}
