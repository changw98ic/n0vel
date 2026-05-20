import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/character_consistency_models.dart';
import 'package:novel_writer/features/story_generation/data/character_consistency_verifier.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';
import 'package:novel_writer/features/story_generation/data/soul_contract_validator.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';

import 'test_support/fake_app_llm_client.dart';

void main() {
  test(
    'preGenerationCheck reports blocking soul contract violations',
    () async {
      final store = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        llmClient: FakeAppLlmClient(
          responder: (_) => const AppLlmChatResult.success(text: 'PASS'),
        ),
      );
      addTearDown(store.dispose);
      final verifier = CharacterConsistencyVerifier(
        settingsStore: store,
        soulValidator: const SoulContractValidator(
          SoulContract(forbiddenActions: ['betray']),
        ),
      );

      final report = await verifier.preGenerationCheck(
        brief: SceneBrief(
          chapterId: 'chapter-01',
          chapterTitle: 'Chapter',
          sceneId: 'scene-01',
          sceneTitle: 'Crossroads',
          sceneSummary: 'Aki chooses to betray the crew at dawn.',
        ),
        cast: [
          ResolvedSceneCastMember(
            characterId: 'aki',
            name: 'Aki',
            role: 'lead',
            contributions: const [SceneCastContribution.action],
          ),
        ],
        allFacts: const [],
        policies: const [],
      );

      expect(report.hasBlockingIssues, isTrue);
      expect(report.issues.single.aspect, ConsistencyAspect.actionCapability);
      expect(report.issues.single.description, contains('Soul contract'));
    },
  );
}
