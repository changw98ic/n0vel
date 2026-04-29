import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/logging/app_event_log.dart';
import 'package:novel_writer/app/logging/app_event_log_storage.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/features/story_generation/data/chapter_generation_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/scene_director_orchestrator.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_models.dart';

void main() {
  test(
    'orchestrator injects tracked narrative arc into the next scene',
    () async {
      final settingsStore = AppSettingsStore(
        storage: InMemoryAppSettingsStorage(),
        eventLog: AppEventLog(storage: _NoopEventLogStorage()),
      );
      addTearDown(settingsStore.dispose);

      final director = _CapturingDirector(settingsStore: settingsStore);
      final orchestrator = ChapterGenerationOrchestrator(
        settingsStore: settingsStore,
        directorOrchestrator: director,
      );

      final firstOutput = await orchestrator.runScene(
        _brief(sceneId: 'scene-01', targetBeat: '阿岚与伯恩合作追查码头账本'),
      );
      expect(
        firstOutput.sceneState?.acceptedStateDeltas.map((delta) => delta.kind),
        contains(SceneStateDeltaKind.alliance),
      );
      await orchestrator.runScene(
        _brief(sceneId: 'scene-02', targetBeat: '阿岚公开账本线索'),
      );

      expect(director.briefs, hasLength(2));
      expect(director.briefs.first.narrativeArc, isNull);

      final secondArc = director.briefs.last.narrativeArc;
      expect(secondArc, isNotNull);
      expect(secondArc!.activeThreads, isNotEmpty);
      expect(
        secondArc.activeThreads.map((thread) => thread.description),
        contains('阿岚与伯恩合作追查码头账本'),
      );
    },
  );
}

SceneBrief _brief({required String sceneId, required String targetBeat}) {
  return SceneBrief(
    chapterId: 'chapter-01',
    chapterTitle: '旧码头',
    sceneId: sceneId,
    sceneTitle: sceneId,
    sceneSummary: targetBeat,
    targetBeat: targetBeat,
    cast: [
      SceneCastCandidate(
        characterId: 'alan',
        name: '阿岚',
        role: '调查者',
        participation: const SceneCastParticipation(
          action: '追查',
          dialogue: '质询',
        ),
      ),
      SceneCastCandidate(
        characterId: 'bern',
        name: '伯恩',
        role: '线人',
        participation: const SceneCastParticipation(
          action: '协助',
          dialogue: '交底',
        ),
      ),
    ],
    metadata: const {
      'localStructuredRoleplayOnly': true,
      'localEditorialOnly': true,
      'localPolishOnly': true,
      'localReviewOnly': true,
    },
  );
}

class _CapturingDirector extends SceneDirectorOrchestrator {
  _CapturingDirector({required super.settingsStore});

  final List<SceneBrief> briefs = [];

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    briefs.add(brief);
    final target = brief.targetBeat.trim().isNotEmpty
        ? brief.targetBeat.trim()
        : brief.sceneSummary.trim();
    return SceneDirectorOutput(text: target);
  }
}

class _NoopEventLogStorage implements AppEventLogStorage {
  @override
  Future<void> write(AppEventLogEntry entry) async {}
}
