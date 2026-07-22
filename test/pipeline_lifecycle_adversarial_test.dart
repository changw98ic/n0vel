import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/state/app_settings_storage.dart';
import 'package:novel_writer/app/state/app_settings_store.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/generation_evidence_fingerprints.dart';
import 'package:novel_writer/features/story_generation/data/generation_pipeline_config.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger.dart';
import 'package:novel_writer/features/story_generation/data/generation_ledger_models.dart';
import 'package:novel_writer/features/story_generation/data/generation_stage_checkpoint_codec.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_models.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_event_log.dart';
import 'package:novel_writer/features/story_generation/data/pipeline_stage_runner_impl.dart';
import 'package:novel_writer/features/story_generation/data/scene_generation_identity.dart';
import 'package:novel_writer/features/story_generation/data/scene_pipeline_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_roleplay_session_models.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/event_log.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/soul_contract.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/stage_runner.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/structured_profile.dart';
import 'package:novel_writer/features/story_generation/domain/memory_models.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';
import 'package:novel_writer/features/story_generation/domain/story_pipeline_interfaces.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('pipeline lifecycle adversarial boundaries', () {
    test('prepared brief is a detached deeply immutable snapshot', () {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final runner = _runner(settings, _StableDirector());
      final speakingPatterns = <String>['先停顿，再回答'];
      final coreValues = <String>['守诺'];
      final profileBeats = <Object?>['不主动解释伤口'];
      final promptTags = <String>{'克制', '观察优先'};
      final worldFacts = <String>['旧码头已经封锁'];
      final outlineBeats = <String>['先盘问，再发现盐霜'];
      final profileMetadata = <String, Object?>{
        'prompt': <String, Object?>{'beats': profileBeats},
      };
      final source = _brief().copyWith(
        metadata: {..._brief().metadata, 'promptTags': promptTags},
        characterProfiles: [
          StructuredProfile(
            id: 'character-a',
            name: '阿岚',
            personality: const PersonalityVector(),
            voicePrint: VoicePrint(speakingPatterns: speakingPatterns),
            behaviorBounds: const BehaviorBounds(),
            soul: SoulContract(coreValues: coreValues),
            metadata: profileMetadata,
          ),
        ],
      );

      final prepared = runner.prepareSceneBrief(
        source,
        materials: ProjectMaterialSnapshot(
          worldFacts: worldFacts,
          outlineBeats: outlineBeats,
        ),
      );
      final sealedDigest = prepared.digest;

      speakingPatterns.add('调用者后来追加的口癖');
      coreValues.add('调用者后来追加的价值');
      profileBeats.add('调用者后来追加的节拍');
      worldFacts.add('调用者后来追加的世界事实');
      outlineBeats.add('调用者后来追加的大纲节拍');
      promptTags.add('调用者后来追加的标签');

      final sealedProfile = prepared.brief.characterProfiles.single;
      expect(sealedProfile.voicePrint.speakingPatterns, ['先停顿，再回答']);
      expect(sealedProfile.soul.coreValues, ['守诺']);
      expect(((sealedProfile.metadata['prompt']! as Map)['beats']! as List), [
        '不主动解释伤口',
      ]);
      expect(SceneGenerationIdentity.briefHash(prepared.brief), sealedDigest);
      expect(prepared.brief.metadata['promptTags'], ['克制', '观察优先']);
      expect(prepared.materials!.worldFacts, ['旧码头已经封锁']);
      expect(prepared.materials!.outlineBeats, ['先盘问，再发现盐霜']);
      expect(
        () => sealedProfile.voicePrint.speakingPatterns.add('越界'),
        throwsUnsupportedError,
      );
      expect(
        () => ((sealedProfile.metadata['prompt']! as Map)['beats']! as List)
            .add('越界'),
        throwsUnsupportedError,
      );
      expect(
        () => prepared.materials!.worldFacts.add('越界'),
        throwsUnsupportedError,
      );
      expect(
        () => (prepared.brief.metadata['promptTags']! as List).add('越界'),
        throwsUnsupportedError,
      );
    });

    test(
      'prepared brief keeps its captured arc when runner state changes',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final director = _CapturingDirector();
        final runner = _runner(settings, director);
        final prepared = runner.prepareSceneBrief(
          _brief().copyWith(sceneId: 'scene-prepared'),
        );

        expect(prepared.brief.narrativeArc, isNotNull);
        expect(prepared.brief.narrativeArc!.thematicArcs, isEmpty);

        await runner.runScene(
          _brief().copyWith(
            sceneId: 'scene-mutates-runner',
            narrativeArc: NarrativeArcState(
              thematicArcs: const ['MUTATED_ARC_SENTINEL'],
            ),
          ),
        );
        final output = await runner.runPreparedScene(prepared);

        expect(output.brief.sceneId, 'scene-prepared');
        expect(output.brief.narrativeArc, isNotNull);
        expect(output.brief.narrativeArc!.thematicArcs, isEmpty);
        expect(director.lastSceneId, 'scene-prepared');
        expect(
          director.lastRagContext,
          isNot(contains('MUTATED_ARC_SENTINEL')),
        );
        expect(
          SceneGenerationIdentity.briefHash(output.brief),
          prepared.digest,
        );
      },
    );

    test(
      'checkpoint records every completed stage without becoming proof',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final checkpoints = _MemoryCheckpointStore();
        final runner = _runner(settings, _StableDirector())
          ..checkpointRunId = 'run-checkpoint'
          ..checkpointStore = checkpoints;

        await runner.runScene(_brief());

        final completed = checkpoints.values.where(
          (value) => value.isCompleted,
        );
        expect(completed, isNotEmpty);
        expect(
          completed.every((value) => value.runId == 'run-checkpoint'),
          isTrue,
        );
        expect(
          completed.every((value) => value.inputDigest.length == 64),
          isTrue,
        );
        expect(
          completed.every((value) => value.artifactDigest.length == 64),
          isTrue,
        );
        expect(
          completed.map((value) => value.ordinal),
          containsAll(List<int>.generate(13, (ordinal) => ordinal)),
        );
      },
    );

    test('corrupt checkpoint fails closed and recomputes the stage', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final checkpoints = _MemoryCheckpointStore([
        const PipelineStageCheckpoint(
          runId: 'run-corrupt',
          ordinal: 1,
          stageId: 'director',
          stageAttempt: 1,
          schemaVersion: 999,
          inputDigest: 'not-a-digest',
          artifactDigest: 'forged',
          status: 'completed',
          createdAtMs: 1,
          completedAtMs: 2,
        ),
      ]);
      final director = _StableDirector();
      final runner = _runner(settings, director)
        ..checkpointRunId = 'run-corrupt'
        ..checkpointStore = checkpoints;

      await runner.runScene(_brief());

      expect(director.calls, 1);
      expect(
        runner.eventLog.query(
          stageId: 'director',
          eventType: 'checkpoint_discarded_incompatible',
        ),
        hasLength(1),
      );
    });

    test(
      'director checkpoint digest follows semantic scene identity boundaries',
      () async {
        final baseline = await _directorInputDigestFor(_brief());
        final formal = await _directorInputDigestFor(
          _brief().copyWith(formalExecution: true),
        );
        final semanticMetadata = await _directorInputDigestFor(
          _brief().copyWith(
            metadata: {
              ..._brief().metadata,
              'publicSceneSetup': '线人袖口有盐霜，暗示他刚从远洋货仓出来。',
            },
          ),
        );
        final nonSemanticMetadata = await _directorInputDigestFor(
          _brief().copyWith(
            metadata: {..._brief().metadata, 'displayLabel': 'UI-only label'},
          ),
        );

        expect(formal, isNot(baseline));
        expect(semanticMetadata, isNot(baseline));
        expect(nonSemanticMetadata, baseline);
      },
    );

    test(
      'no-redraw runner persists one complete formal-attempt evidence envelope',
      () async {
        final file = File(
          '${Directory.systemTemp.path}/generation-attempt-evidence-${DateTime.now().microsecondsSinceEpoch}.jsonl',
        );
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
          final lockFile = File('${file.path}.lock');
          if (lockFile.existsSync()) lockFile.deleteSync();
        });
        final settings = await _startIoCompletionSettings();
        final eventLog = PipelineEventLogImpl(jsonlPath: file.path);
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: eventLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: 'lifecycle-no-redraw-success-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );
        final brief = _brief().copyWith(
          sceneSummary: 'RAW_PROMPT_SENTINEL_DO_NOT_LOG',
          metadata: const {},
        );

        final output = await runner.runScene(brief);
        await eventLog.dispose();

        expect(output.prose.text, isNotEmpty);
        expect(settings.calls, 4);
        expect(settings.stageId, 'director');
        expect(settings.callSiteId, 'scene-director');
        expect(settings.promptReleaseRef, isNotNull);
        expect(settings.promptInvocationEvidence, isNotNull);
        expect(
          settings.generationBundleHash,
          matches(r'^sha256:[0-9a-f]{64}$'),
        );

        final evidenceEvents = eventLog.query(
          eventType: 'story_generation_attempt_evidence_envelope_recorded',
        );
        expect(evidenceEvents, hasLength(1));
        final durableAttemptEvents = eventLog.query(
          eventType: storyGenerationAttemptEvidenceRecordedEventType,
        );
        expect(durableAttemptEvents, hasLength(4));
        final durableIntentEvents = eventLog.query(
          eventType: storyGenerationAttemptIntentRecordedEventType,
        );
        expect(durableIntentEvents, hasLength(4));
        expect(
          durableIntentEvents.map(
            (event) => (event.metadata['private']! as Map)['sequenceNo'],
          ),
          [0, 1, 2, 3],
        );
        final pendingEnvelopeEvents = eventLog.query(
          eventType: storyGenerationAttemptEvidenceEnvelopePendingEventType,
        );
        expect(pendingEnvelopeEvents, hasLength(1));
        expect(
          pendingEnvelopeEvents.single.metadata['admissionState'],
          'pending',
        );
        final durableAttemptMetadata = durableAttemptEvents.first.metadata;
        expect(
          durableAttemptMetadata['schemaVersion'],
          storyGenerationAttemptEvidenceEventSchemaVersion,
        );
        final durablePrivateAttempt = Map<String, Object?>.from(
          durableAttemptMetadata['private']! as Map,
        );
        expect(durableAttemptMetadata['visibility'], 'private');
        expect(durableAttemptMetadata, isNot(contains('blind')));
        expect(durablePrivateAttempt['sequenceNo'], 0);
        expect(durablePrivateAttempt['disposition'], 'returned');
        expect(
          durablePrivateAttempt['providerModel'],
          'private-provider-model',
        );
        expect(
          durablePrivateAttempt['providerResponseId'],
          'private-response-001',
        );
        expect(
          durablePrivateAttempt['providerBoundaryReceiptHash'],
          matches(r'^sha256:[0-9a-f]{64}$'),
        );
        expect(
          durablePrivateAttempt['providerBoundaryPhysicalDispatchCount'],
          1,
        );
        expect(
          durablePrivateAttempt['providerBoundaryReceiptVerified'],
          isTrue,
        );
        final metadata = evidenceEvents.single.metadata;
        expect(
          metadata['schemaVersion'],
          'story-generation-attempt-evidence-envelope-v1',
        );
        expect(metadata['runStatus'], 'completed');
        expect(metadata['admissionState'], 'committed');
        expect(metadata['evidenceComplete'], isTrue);
        expect(metadata['visibility'], 'private');
        expect(metadata, isNot(contains('blind')));
        expect(metadata['attemptRecordCount'], 4);
        final finalDigest = Map<String, Object?>.from(
          metadata['finalArtifactDigest']! as Map,
        );
        expect(
          finalDigest['digest'],
          ArtifactDigest.fromUtf8String(output.prose.text).digest,
        );

        final privateEvidence = Map<String, Object?>.from(
          metadata['private']! as Map,
        );
        final privateAttempts = (privateEvidence['attempts']! as List)
            .map((value) => Map<String, Object?>.from(value as Map))
            .toList(growable: false);
        expect(privateAttempts, hasLength(4));
        final privateAttempt = privateAttempts.firstWhere(
          (attempt) => attempt['callSiteId'] == 'scene-director',
        );
        expect(
          privateEvidence['generationArmPolicy'],
          'arm-a-current-pipeline-v1',
        );
        expect(privateAttempt['disposition'], 'returned');
        expect(privateAttempt['providerModel'], 'private-provider-model');
        expect(privateAttempt['providerResponseId'], 'private-response-001');
        expect(privateAttempt['artifactDigest'], isA<Map>());
        expect(
          privateAttempt['generationFingerprintDigest'],
          matches(r'^sha256:[0-9a-f]{64}$'),
        );
        final sealEvents = eventLog.query(
          eventType: storyGenerationArtifactSealRecordedEventType,
        );
        expect(sealEvents, hasLength(1));
        expect(sealEvents.single.metadata['visibility'], 'private');
        expect(sealEvents.single.metadata, isNot(contains('blind')));
        final sealPrivate = Map<String, Object?>.from(
          sealEvents.single.metadata['private']! as Map,
        );
        expect(
          sealPrivate['sourceCallSiteId'],
          'scene-editorial-generator',
          reason:
              'without final polish, the exact editorial provider completion is the final prose source',
        );
        final editorialAttempt = privateAttempts.singleWhere(
          (attempt) => attempt['callSiteId'] == 'scene-editorial-generator',
        );
        expect(
          sealPrivate['sourceLogicalAttemptId'],
          editorialAttempt['logicalAttemptId'],
        );
        expect(
          sealPrivate['artifactDigest'],
          editorialAttempt['artifactDigest'],
        );
        expect(
          metadata['sealedArtifactDigest'],
          metadata['finalArtifactDigest'],
        );

        final jsonl = await file.readAsString();
        expect(jsonl, isNot(contains('RAW_PROMPT_SENTINEL_DO_NOT_LOG')));
        expect(
          jsonl,
          isNot(contains('RAW_PROVIDER_COMPLETION_SENTINEL_DO_NOT_LOG')),
        );
        expect(jsonl, isNot(contains('"blind"')));
        final reparsed = <Map<String, Object?>>[
          for (final line in const LineSplitter().convert(jsonl))
            Map<String, Object?>.from(jsonDecode(line) as Map),
        ];
        expect(
          reparsed.where(
            (event) =>
                event['eventType'] ==
                storyGenerationAttemptEvidenceEnvelopeRecordedEventType,
          ),
          hasLength(1),
        );
        expect(
          reparsed.where(
            (event) =>
                event['eventType'] ==
                storyGenerationAttemptEvidenceRecordedEventType,
          ),
          hasLength(4),
        );
        expect(
          reparsed.where(
            (event) =>
                event['eventType'] ==
                storyGenerationAttemptIntentRecordedEventType,
          ),
          hasLength(4),
        );
      },
    );

    test(
      'no-redraw preserves the first outcome-admission error after durable invalidation',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'attempt-admission-error-visibility-',
        );
        final eventLog = PipelineEventLogImpl(
          jsonlPath: '${directory.path}/pipeline.jsonl',
        );
        addTearDown(() async {
          await eventLog.dispose();
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final settings = await _startIoCompletionSettings(
          malformedRouteIdentity: true,
        );
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: eventLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: 'lifecycle-invalid-route-outcome-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );

        Object? thrownError;
        StackTrace? thrownStackTrace;
        try {
          await runner.runScene(_brief().copyWith(metadata: const {}));
          fail('malformed route identity must reject the attempt outcome');
        } on Object catch (error, stackTrace) {
          thrownError = error;
          thrownStackTrace = stackTrace;
        }

        expect(settings.calls, 1);
        expect(thrownError, isA<StoryGenerationEvidenceIntegrityFailure>());
        expect(
          thrownError.toString(),
          contains(
            'attempt outcome is not canonically admissible: '
            'attempt evidence has an unsupported v1 shape, '
            'provider receipt, observed route, and selected endpoint disagree',
          ),
        );
        expect(
          thrownError.toString(),
          isNot(contains('write-ahead intent has no durable attempt outcome')),
        );
        expect(
          thrownStackTrace.toString(),
          contains('PipelineStoryGenerationEvidenceJournal.persistAttempt'),
        );

        final persisted = await eventLog.readPersistedEvents();
        final intents = persisted.where(
          (event) =>
              event.eventType == storyGenerationAttemptIntentRecordedEventType,
        );
        final outcomes = persisted.where(
          (event) =>
              event.eventType ==
              storyGenerationAttemptEvidenceRecordedEventType,
        );
        final invalidations = persisted.where(
          (event) =>
              event.eventType == storyGenerationEvidenceInvalidatedEventType,
        );
        expect(intents, hasLength(1));
        expect(outcomes, isEmpty);
        expect(invalidations, hasLength(1));
        final privateInvalidation = Map<String, Object?>.from(
          invalidations.single.metadata['private']! as Map,
        );
        expect(privateInvalidation['reason'], 'indeterminate_provider_attempt');
        expect(privateInvalidation['logicalAttemptIds'], hasLength(1));
      },
    );

    test(
      'completed attempt survives failure before the scene envelope',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'attempt-before-envelope-failure-',
        );
        final eventLog = PipelineEventLogImpl(
          jsonlPath: '${directory.path}/pipeline.jsonl',
        );
        addTearDown(() async {
          await eventLog.dispose();
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final settings = await _startIoCompletionSettings(failureStatus: 401);
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: eventLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: 'lifecycle-no-redraw-envelope-failure-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );

        await expectLater(
          runner.runScene(_brief().copyWith(metadata: const {})),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('injected provider rejection'),
            ),
          ),
        );

        final persisted = await eventLog.readPersistedEvents();
        final attempts = persisted.where(
          (event) =>
              event.eventType ==
              storyGenerationAttemptEvidenceRecordedEventType,
        );
        final envelopes = persisted.where(
          (event) =>
              event.eventType ==
              'story_generation_attempt_evidence_envelope_recorded',
        );
        expect(attempts, hasLength(1));
        expect(envelopes, hasLength(1));
        expect(envelopes.single.metadata['runStatus'], 'incomplete');
        expect(envelopes.single.metadata['admissionState'], 'rejected');
        expect(envelopes.single.metadata['evidenceComplete'], isFalse);
        final privateAttempt = Map<String, Object?>.from(
          attempts.single.metadata['private']! as Map,
        );
        expect(privateAttempt['succeeded'], isFalse);
        expect(privateAttempt['failureKind'], 'unauthorized');
        expect(privateAttempt['evidenceComplete'], isTrue);
      },
    );

    test(
      'envelope persistence error remains primary when the body succeeded',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'successful-body-envelope-failure-',
        );
        final eventLog = PipelineEventLogImpl(
          jsonlPath: '${directory.path}/pipeline.jsonl',
        );
        addTearDown(() async {
          await eventLog.dispose();
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final settings = await _startIoCompletionSettings();
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: eventLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: 'lifecycle-envelope-error-primary-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: _DisposeEvidenceLeaseAfterScoring(eventLog),
        );

        await expectLater(
          runner.runScene(_brief().copyWith(metadata: const {})),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('exclusive prepared writer lease'),
            ),
          ),
        );

        expect(settings.calls, 4);
        final persisted = await eventLog.readPersistedEvents();
        expect(
          persisted.where(
            (event) =>
                event.eventType ==
                storyGenerationAttemptEvidenceRecordedEventType,
          ),
          hasLength(4),
        );
        expect(
          persisted.where(
            (event) =>
                event.eventType ==
                storyGenerationAttemptEvidenceEnvelopeRecordedEventType,
          ),
          isEmpty,
        );
        expect(
          persisted.where(
            (event) =>
                event.eventType == storyGenerationEvidenceInvalidatedEventType,
          ),
          isEmpty,
          reason: 'a lost OS writer lease cannot append even an invalidation',
        );
      },
    );

    test(
      'no-redraw runner rejects a volatile evidence log before dispatch',
      () async {
        final settings = _SingleCompletionSettings();
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: 'lifecycle-no-redraw-missing-sink-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );

        await expectLater(
          runner.runScene(_brief().copyWith(metadata: const {})),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('persistent, retrievable evidence sink'),
            ),
          ),
        );

        expect(settings.calls, 0);
      },
    );

    test(
      'self-attesting public evidence sink cannot reach the provider',
      () async {
        final settings = await _startIoCompletionSettings();
        final forgedLog = _SelfAttestingEvidenceLog();
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: forgedLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: 'lifecycle-forged-evidence-sink-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );

        await expectLater(
          runner.runScene(_brief().copyWith(metadata: const {})),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('persistent, retrievable evidence sink'),
            ),
          ),
        );

        expect(settings.calls, 0);
        expect(settings.serverRequests, 0);
        expect(forgedLog.persistenceBoundaryCalls, 0);
        expect(forgedLog.query(), isEmpty);
      },
    );

    test(
      'same run and scene cannot rebind to a second real JSONL before dispatch',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'cross-jsonl-evidence-replay-',
        );
        final firstLog = PipelineEventLogImpl(
          jsonlPath: '${directory.path}/first.jsonl',
        );
        final secondLog = PipelineEventLogImpl(
          jsonlPath: '${directory.path}/second.jsonl',
        );
        addTearDown(() async {
          await firstLog.dispose();
          await secondLog.dispose();
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final settings = await _startIoCompletionSettings();
        const evidenceRunId = 'lifecycle-cross-jsonl-replay-v1';
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: secondLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
            evidenceRunId: evidenceRunId,
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );
        final prepared = runner.prepareSceneBrief(
          _brief().copyWith(metadata: const {}),
        );
        await firstLog.openStoryGenerationEvidenceJournal(
          evidenceRunId: evidenceRunId,
          sceneId: prepared.brief.sceneId,
          preparedBriefDigest: prepared.digest,
          generationArmPolicy: 'arm-a-current-pipeline-v1',
        );
        await firstLog.dispose();

        await expectLater(
          runner.runPreparedScene(prepared),
          throwsA(
            isA<StoryGenerationEvidenceIntegrityFailure>().having(
              (error) => error.message,
              'message',
              contains('already bound to another durable JSONL locator'),
            ),
          ),
        );

        expect(settings.calls, 0);
        expect(settings.serverRequests, 0);
        expect(
          secondLog.query(
            eventType: storyGenerationAttemptEvidenceEnvelopeRecordedEventType,
          ),
          isEmpty,
        );
      },
    );

    test(
      'no-redraw runner rejects a missing stable run id before dispatch',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'missing-evidence-run-id-',
        );
        final eventLog = PipelineEventLogImpl(
          jsonlPath: '${directory.path}/pipeline.jsonl',
        );
        addTearDown(() async {
          await eventLog.dispose();
          if (await directory.exists()) {
            await directory.delete(recursive: true);
          }
        });
        final settings = _SingleCompletionSettings();
        final runner = PipelineStageRunnerImpl(
          settingsStore: settings,
          eventLog: eventLog,
          pipelineConfig: const GenerationPipelineConfig(
            hardGatesEnabled: false,
            sceneContentRedrawPolicy: SceneContentRedrawPolicy.noContentRedraw,
            generationArmPolicy: 'arm-a-current-pipeline-v1',
          ),
          reviewCoordinator: const _PassReview(),
          qualityScorer: const _PassingQuality(),
        );

        await expectLater(
          runner.runScene(_brief().copyWith(metadata: const {})),
          throwsA(
            isA<StoryGenerationEvidencePreflightFailure>().having(
              (error) => error.message,
              'message',
              contains('evidenceRunId'),
            ),
          ),
        );
        expect(settings.calls, 0);
        expect(await File(eventLog.evidenceLocator!).exists(), isFalse);
      },
    );

    for (final blocked in [false, true]) {
      test(
        'typed no-redraw ${blocked ? 'failure' : 'success'} returns its durable evidence envelope',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'pipeline-result-evidence-',
          );
          final eventLog = PipelineEventLogImpl(
            jsonlPath: '${directory.path}/pipeline.jsonl',
          );
          addTearDown(() async {
            await eventLog.dispose();
            if (await directory.exists()) {
              await directory.delete(recursive: true);
            }
          });
          final settings = await _startIoCompletionSettings();
          final runner = PipelineStageRunnerImpl(
            settingsStore: settings,
            eventLog: eventLog,
            pipelineConfig: GenerationPipelineConfig(
              hardGatesEnabled: false,
              sceneContentRedrawPolicy:
                  SceneContentRedrawPolicy.noContentRedraw,
              generationArmPolicy: 'arm-a-current-pipeline-v1',
              evidenceRunId: blocked
                  ? 'lifecycle-no-redraw-typed-blocked-v1'
                  : 'lifecycle-no-redraw-typed-success-v1',
            ),
            reviewCoordinator: blocked
                ? _RewriteOnceReview()
                : const _PassReview(),
            qualityScorer: const _PassingQuality(),
          );
          final brief = _brief().copyWith(metadata: const {});
          final context = _pipelineContextFor(runner, brief);

          final result = await runner.run(context.sceneBrief, context);

          expect(result.success, !blocked);
          if (blocked) {
            expect(result.failureCode, FailureCode.blocked);
            expect(result.failedStageId, 'editorial');
          }
          final returnedEnvelopes = result.events.where(
            (event) =>
                event.eventType ==
                'story_generation_attempt_evidence_envelope_recorded',
          );
          expect(returnedEnvelopes, hasLength(1));
          expect(result.events.last, same(returnedEnvelopes.single));

          final persistedEnvelopes = (await eventLog.readPersistedEvents())
              .where(
                (event) =>
                    event.eventType ==
                    'story_generation_attempt_evidence_envelope_recorded',
              );
          expect(persistedEnvelopes, hasLength(1));
          expect(
            persistedEnvelopes.single.metadata,
            returnedEnvelopes.single.metadata,
          );
        },
      );
    }

    test(
      'transient stage failures retry within the declared ceiling',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final director = _FlakyDirector(failuresBeforeSuccess: 1);
        final runner = _runner(settings, director);

        await runner.runScene(_brief());

        expect(director.calls, 2);
        expect(
          runner.eventLog.query(
            stageId: 'director',
            eventType: 'stage_retry_scheduled',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'outer prose rewrite advances durable checkpoint attempt identities',
      () async {
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        final checkpoints = _MemoryCheckpointStore();
        final review = _RewriteOnceReview();
        final runner = _runner(settings, _StableDirector(), review: review)
          ..checkpointRunId = 'run-outer-rewrite'
          ..checkpointStore = checkpoints;

        await runner.runScene(_brief());

        List<int> attempts(int ordinal) =>
            checkpoints.values
                .where((value) => value.ordinal == ordinal && value.isCompleted)
                .map((value) => value.stageAttempt)
                .toSet()
                .toList()
              ..sort();
        expect(review.calls, greaterThanOrEqualTo(3));
        expect(attempts(5), <int>[1, 4]);
        expect(attempts(6), <int>[1, 4]);
      },
    );

    test('cancel before the first stage prevents provider dispatch', () async {
      final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
      addTearDown(settings.dispose);
      final director = _StableDirector();
      final runner = _runner(settings, director)..isRunCancelled = () => true;

      await expectLater(
        runner.runScene(_brief()),
        throwsA(isA<PipelineRunCancelled>()),
      );
      expect(director.calls, 0);
    });

    test(
      'file-backed completed provider checkpoint survives reopen without replay',
      () async {
        final file = File(
          '${Directory.systemTemp.path}/generation-resume-${DateTime.now().microsecondsSinceEpoch}.db',
        );
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });
        final settings = AppSettingsStore(
          storage: InMemoryAppSettingsStorage(),
        );
        addTearDown(settings.dispose);
        const runId = 'run-file-resume';
        const provenance = GenerationCheckpointProvenance(
          baseDraftDigest:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          materialDigest:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          promptDigest:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          modelDigest:
              'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        );
        final director = _StableDirector();
        final firstDb = sqlite3.sqlite3.open(file.path);
        firstDb.execute('PRAGMA foreign_keys = ON');
        final firstLedger = GenerationLedgerSqliteStore(db: firstDb)
          ..ensureTables();
        firstLedger.createRun(
          const GenerationRunRecord(
            runId: runId,
            requestId: 'request-file-resume',
            projectId: 'project',
            chapterId: 'chapter',
            sceneId: 'scene',
            sceneScopeId: 'project::scene',
            status: 'running',
            phase: 'planning',
            schemaVersion: 10,
            createdAtMs: 1,
            updatedAtMs: 1,
          ),
        );
        firstLedger.createWorkingProseRevision(
          const WorkingProseRevisionRecord(
            runId: runId,
            proseRevision: 0,
            proseHash: 'sha256:base-draft',
            proseText: '作者原稿',
            sourceKind: 'baseDraft',
            createdAtMs: 1,
          ),
        );
        final firstStore = _CrashAfterCompletedCheckpointStore(
          delegate: GenerationLedgerCheckpointStore(
            ledger: firstLedger,
            provenance: provenance,
          ),
          ordinal: 1,
        );
        final first = _runner(settings, director)
          ..checkpointRunId = runId
          ..checkpointStore = firstStore
          ..checkpointProvenance = provenance;
        await expectLater(
          first.runScene(_brief()),
          throwsA(isA<PipelineRunCancelled>()),
        );
        expect(firstStore.crashed, isTrue);
        firstDb.dispose();

        final resumedDb = sqlite3.sqlite3.open(file.path);
        addTearDown(resumedDb.dispose);
        resumedDb.execute('PRAGMA foreign_keys = ON');
        final resumedLedger = GenerationLedgerSqliteStore(db: resumedDb)
          ..ensureTables();
        final resumed = _runner(settings, director)
          ..checkpointRunId = runId
          ..checkpointStore = GenerationLedgerCheckpointStore(
            ledger: resumedLedger,
            provenance: provenance,
          )
          ..checkpointProvenance = provenance;

        await resumed.runScene(_brief());

        expect(
          director.calls,
          1,
          reason:
              'the durable director checkpoint must be restored after reopening SQLite',
        );
        expect(
          resumedDb.select(
            '''
            SELECT 1 FROM story_generation_stage_checkpoints
            WHERE run_id = ? AND ordinal = 1 AND status = 'completed'
          ''',
            [runId],
          ),
          hasLength(1),
        );
      },
    );
  });
}

Future<String> _directorInputDigestFor(SceneBrief brief) async {
  final settings = AppSettingsStore(storage: InMemoryAppSettingsStorage());
  addTearDown(settings.dispose);
  final checkpoints = _MemoryCheckpointStore();
  final runner = _runner(settings, _StableDirector())
    ..checkpointRunId = 'run-director-digest-${Object().hashCode}'
    ..checkpointStore = checkpoints;

  try {
    await runner.runScene(brief);
  } catch (_) {
    // Formal runs may fail later when local fallback-only stages are rejected.
    // This helper only observes the already-completed director checkpoint.
  }

  final directorCheckpoint = checkpoints.values.singleWhere(
    (value) =>
        value.isCompleted && value.ordinal == 1 && value.stageId == 'director',
  );
  return directorCheckpoint.inputDigest;
}

PipelineStageRunnerImpl _runner(
  AppSettingsStore settings,
  SceneDirectorService director, {
  SceneReviewService review = const _PassReview(),
}) {
  return PipelineStageRunnerImpl(
    settingsStore: settings,
    pipelineConfig: const GenerationPipelineConfig(hardGatesEnabled: false),
    directorOrchestrator: director,
    reviewCoordinator: review,
    qualityScorer: const _PassingQuality(),
  );
}

SceneBrief _brief() => SceneBrief(
  chapterId: 'chapter',
  chapterTitle: '第一章',
  sceneId: 'scene',
  sceneTitle: '雨夜码头',
  sceneSummary: '阿岚逼问线人。',
  targetBeat: '阿岚逼问线人，得到关键线索。',
  metadata: const {
    'localStructuredRoleplayOnly': true,
    'localEditorialOnly': true,
    'localPolishOnly': true,
  },
);

PipelineContext _pipelineContextFor(
  PipelineStageRunnerImpl runner,
  SceneBrief brief,
) {
  final sceneBrief = SceneBriefRef(
    projectId: brief.projectId ?? brief.chapterId,
    sceneId: brief.sceneId,
  );
  return PipelineContext(
    eventLog: runner.eventLog,
    retrievalPolicy: runner.defaultRetrievalPolicy,
    writebackGate: runner.writebackGate,
    sceneBrief: sceneBrief,
    metadata: <String, Object?>{'sceneBrief': brief},
  );
}

class _MemoryCheckpointStore implements PipelineCheckpointStore {
  _MemoryCheckpointStore([Iterable<PipelineStageCheckpoint> initial = const []])
    : values = [...initial];

  final List<PipelineStageCheckpoint> values;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) async =>
      List.unmodifiable(values.where((value) => value.runId == runId));

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    values.removeWhere(
      (value) =>
          value.runId == checkpoint.runId &&
          value.ordinal == checkpoint.ordinal &&
          value.stageId == checkpoint.stageId &&
          value.stageAttempt == checkpoint.stageAttempt,
    );
    values.add(checkpoint);
  }
}

class _CrashAfterCompletedCheckpointStore implements PipelineCheckpointStore {
  _CrashAfterCompletedCheckpointStore({
    required this.delegate,
    required this.ordinal,
  });

  final PipelineCheckpointStore delegate;
  final int ordinal;
  bool crashed = false;

  @override
  Future<List<PipelineStageCheckpoint>> load({required String runId}) =>
      delegate.load(runId: runId);

  @override
  Future<void> save(PipelineStageCheckpoint checkpoint) async {
    await delegate.save(checkpoint);
    if (!crashed && checkpoint.ordinal == ordinal && checkpoint.isCompleted) {
      crashed = true;
      throw PipelineRunCancelled('file-crash-after-$ordinal');
    }
  }
}

class _StableDirector implements SceneDirectorService {
  int calls = 0;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    calls += 1;
    return const SceneDirectorOutput(text: '逼问线人并取得关键线索。');
  }
}

class _CapturingDirector extends _StableDirector {
  String? lastSceneId;
  String? lastRagContext;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    lastSceneId = brief.sceneId;
    lastRagContext = ragContext;
    return super.run(brief: brief, cast: cast, ragContext: ragContext);
  }
}

class _FlakyDirector extends _StableDirector {
  _FlakyDirector({required this.failuresBeforeSuccess});

  final int failuresBeforeSuccess;

  @override
  Future<SceneDirectorOutput> run({
    required SceneBrief brief,
    required List<ResolvedSceneCastMember> cast,
    String? ragContext,
  }) async {
    calls += 1;
    if (calls <= failuresBeforeSuccess) {
      throw StateError('transient provider failure');
    }
    return const SceneDirectorOutput(text: '逼问线人并取得关键线索。');
  }
}

class _PassReview implements SceneReviewService {
  const _PassReview();

  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    List<StoryMemoryChunk> canonFacts = const [],
  }) async {
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '通过。',
      rawText: 'PASS',
    );
    return const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    );
  }
}

class _RewriteOnceReview implements SceneReviewService {
  var calls = 0;

  @override
  Future<SceneReviewResult> review({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required List<DynamicRoleAgentOutput> roleOutputs,
    required SceneProseDraft prose,
    SceneRoleplaySession? roleplaySession,
    StoryRetrievalPack? retrievalPack,
    bool enableReaderFlowReview = false,
    bool enableLexiconReview = false,
    List<StoryMemoryChunk> canonFacts = const [],
  }) async {
    calls += 1;
    const pass = SceneReviewPassResult(
      status: SceneReviewStatus.pass,
      reason: '通过。',
      rawText: 'PASS',
    );
    if (calls == 1) {
      const rewrite = SceneReviewPassResult(
        status: SceneReviewStatus.rewriteProse,
        reason: '需要一次正文重写。',
        rawText: 'REWRITE_PROSE',
      );
      return const SceneReviewResult(
        judge: rewrite,
        consistency: pass,
        decision: SceneReviewDecision.rewriteProse,
      );
    }
    return const SceneReviewResult(
      judge: pass,
      consistency: pass,
      decision: SceneReviewDecision.pass,
    );
  }
}

class _PassingQuality implements SceneQualityScorerService {
  const _PassingQuality();

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async => const SceneQualityScore(
    overall: 96,
    prose: 96,
    coherence: 96,
    character: 96,
    completeness: 96,
    summary: '通过。',
  );
}

final class _DisposeEvidenceLeaseAfterScoring
    implements SceneQualityScorerService {
  const _DisposeEvidenceLeaseAfterScoring(this.eventLog);

  final PipelineEventLogImpl eventLog;

  @override
  Future<SceneQualityScore> score({
    required SceneBrief brief,
    required SceneDirectorOutput director,
    required SceneProseDraft prose,
    required SceneReviewResult review,
  }) async {
    await eventLog.dispose();
    return const SceneQualityScore(
      overall: 96,
      prose: 96,
      coherence: 96,
      character: 96,
      completeness: 96,
      summary: '通过。',
    );
  }
}

final class _SelfAttestingEvidenceLog extends PipelineEventLog
    implements PipelineEvidenceSink {
  final List<PipelineEvent> _events = <PipelineEvent>[];
  int persistenceBoundaryCalls = 0;

  @override
  bool get canPersistAndRetrieveEvidence => true;

  @override
  String get evidenceLocator =>
      '${Directory.systemTemp.path}/forged-self-attesting-evidence.jsonl';

  @override
  void emit(PipelineEvent event) => _events.add(event);

  @override
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  }) => _events
      .where(
        (event) =>
            (stageId == null || event.stageId == stageId) &&
            (eventType == null || event.eventType == eventType) &&
            (failureCode == null || event.failureCode == failureCode),
      )
      .toList(growable: false);

  @override
  Future<void> flush() async {}

  @override
  Future<void> prepareEvidencePersistence() async {
    persistenceBoundaryCalls += 1;
  }

  @override
  Future<List<PipelineEvent>> claimStoryGenerationEvidenceJournal({
    required String evidenceRunId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
  }) async {
    persistenceBoundaryCalls += 1;
    return List<PipelineEvent>.unmodifiable(_events);
  }

  @override
  Future<void> appendAndFlushEvidence(PipelineEvent event) async {
    persistenceBoundaryCalls += 1;
    _events.add(event);
  }

  @override
  Future<List<PipelineEvent>> readPersistedEvents() async =>
      List<PipelineEvent>.unmodifiable(_events);
}

final class _SingleCompletionSettings
    implements
        StoryGenerationSettingsContract,
        StoryGenerationModelRouteIdentityProvider,
        StoryGenerationSinglePhysicalDispatchSettingsContract {
  _SingleCompletionSettings();
  static const AppLlmDispatchResolution _singleDispatchResolution =
      AppLlmDispatchResolution(
        endpointId: 'primary',
        baseUrl: 'http://test-provider.local',
        model: 'test-model',
        provider: AppLlmProvider.openaiCompatible,
        isLocal: true,
        physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
      );
  static const AppLlmProviderBoundaryReceipt _providerBoundaryReceipt =
      _TestProviderBoundaryReceipt();
  int calls = 0;
  String? stageId;
  String? callSiteId;
  String? generationBundleHash;
  PromptReleaseRef? promptReleaseRef;
  PromptInvocationEvidence? promptInvocationEvidence;

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Object storyGenerationModelRouteIdentity({required String traceName}) =>
      <String, Object?>{
        'contract': 'test-story-generation-model-route-v1',
        'traceName': traceName,
        'primary': <String, Object?>{
          'provider': 'test-provider',
          'model': 'test-model',
        },
        'failover': const <Object?>[],
      };

  @override
  StoryGenerationSinglePhysicalDispatchRouteLease
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  }) => _PipelineTestRouteLease(<String, Object?>{
    'contract': 'test-story-generation-single-physical-route-v1',
    'traceName': traceName,
    'physicalDispatchPolicy': AppLlmPhysicalDispatchPolicy.single.name,
    'selectedEndpoint': _singleDispatchResolution.toCredentialFreeJson(),
  });

  @override
  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  }) async =>
      (await requestAiCompletion(
            messages: messages,
            maxTokens: maxTokens,
            traceName: traceName,
            traceMetadata: traceMetadata,
            promptReleaseRef: promptReleaseRef,
            promptInvocationEvidence: promptInvocationEvidence,
            promptVersion: promptVersion,
            stageId: stageId,
            callSiteId: callSiteId,
            variantId: variantId,
            generationBundleHash: generationBundleHash,
          ))
          .withProviderBoundaryReceipt(_providerBoundaryReceipt)
          .withDispatchResolution(_singleDispatchResolution);

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    calls += 1;
    this.stageId ??= stageId;
    this.callSiteId ??= callSiteId;
    this.generationBundleHash ??= generationBundleHash;
    this.promptReleaseRef ??= promptReleaseRef;
    this.promptInvocationEvidence ??= promptInvocationEvidence;
    expect(promptInvocationEvidence?.matchesMessages(messages), isTrue);
    final text = switch (callSiteId) {
      'scene-director' => SceneDirectorPlan(
        target: '逼问线人',
        conflict: '线人拒绝开口',
        progression: '取得关键线索',
        constraints: '不改动主线事实',
      ).toText(),
      'stage-narrator' => '雨水打在铁棚上，线人退到生锈的护栏边。',
      'beat-resolver' => '[动作] @narrator 阿岚封住线人的退路\n[事实] @narrator 线人交出仓库编号',
      'scene-editorial-generator' => '阿岚把账页压在灯下，封住线人的退路。线人盯着纸角的水痕，终于交出仓库编号。',
      'language-polish' => '阿岚把账页压在灯下，封住线人的退路。线人盯着纸角的水痕，终于交出仓库编号。',
      _ => throw StateError('unexpected callsite $callSiteId'),
    };
    return AppLlmChatResult.success(
      text: '$text\nRAW_PROVIDER_COMPLETION_SENTINEL_DO_NOT_LOG',
      providerModel: 'private-provider-model',
      providerResponseId:
          'private-response-${calls.toString().padLeft(3, '0')}',
      promptTokens: 21,
      completionTokens: 13,
      totalTokens: 34,
    );
  }
}

/// The successful lifecycle path must cross the same concrete IO boundary as
/// production.  `_SingleCompletionSettings` deliberately remains below for
/// fail-closed tests: public receipt lookalikes must never qualify as proof.
Future<_IoCompletionSettings> _startIoCompletionSettings({
  int? failureStatus,
  bool malformedRouteIdentity = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  late final _IoCompletionSettings settings;
  final baseUrl = 'http://${server.address.host}:${server.port}/v1';
  final store = AppSettingsStore(
    storage: InMemoryAppSettingsStorage(),
    llmClient: createDefaultAppLlmClient(),
  );
  await store.save(
    providerName: 'Local Test',
    baseUrl: baseUrl,
    model: 'test-model',
    apiKey: '',
    timeout: const AppLlmTimeoutConfig.uniform(1000),
    maxTokens: 4096,
  );
  settings = _IoCompletionSettings(
    store,
    baseUrl,
    malformedRouteIdentity: malformedRouteIdentity,
  );
  unawaited(
    server.forEach((request) async {
      settings.serverRequests += 1;
      await utf8.decoder.bind(request).join();
      final response = failureStatus == null ? settings.takeResponse() : null;
      request.response
        ..statusCode = failureStatus ?? HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            if (failureStatus == null) ...<String, Object?>{
              'id':
                  'private-response-${settings.calls.toString().padLeft(3, '0')}',
              'model': 'private-provider-model',
              'choices': <Object?>[
                <String, Object?>{
                  'message': <String, Object?>{'content': response},
                },
              ],
              'usage': <String, Object?>{
                'prompt_tokens': 21,
                'completion_tokens': 13,
                'total_tokens': 34,
              },
            } else
              'error': <String, Object?>{
                'message': 'injected provider rejection',
              },
          }),
        );
      await request.response.close();
    }),
  );
  addTearDown(() => server.close(force: true));
  addTearDown(settings.dispose);
  return settings;
}

final class _IoCompletionSettings
    implements
        StoryGenerationSettingsContract,
        StoryGenerationModelRouteIdentityProvider,
        StoryGenerationSinglePhysicalDispatchSettingsContract {
  _IoCompletionSettings(
    this._store,
    this._baseUrl, {
    this.malformedRouteIdentity = false,
  });

  final AppSettingsStore _store;
  final String _baseUrl;
  final bool malformedRouteIdentity;
  late final AppLlmDispatchResolution _resolution = AppLlmDispatchResolution(
    endpointId: 'lifecycle-io-primary',
    baseUrl: _baseUrl,
    model: 'test-model',
    provider: AppLlmProvider.openaiCompatible,
    isLocal: true,
    physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
  );
  final _responses = <String>[
    SceneDirectorPlan(
      target: '逼问线人',
      conflict: '线人拒绝开口',
      progression: '取得关键线索',
      constraints: '不改动主线事实',
    ).toText(),
    '雨水打在铁棚上，线人退到生锈的护栏边。',
    '[动作] @narrator 阿岚封住线人的退路\n[事实] @narrator 线人交出仓库编号',
    '阿岚把账页压在灯下，封住线人的退路。线人盯着纸角的水痕，终于交出仓库编号。',
  ];
  int calls = 0;
  int serverRequests = 0;
  String? stageId;
  String? callSiteId;
  String? generationBundleHash;
  PromptReleaseRef? promptReleaseRef;
  PromptInvocationEvidence? promptInvocationEvidence;

  String takeResponse() {
    if (_responses.isEmpty) {
      throw StateError('unexpected extra IO completion');
    }
    return '${_responses.removeAt(0)}\nRAW_PROVIDER_COMPLETION_SENTINEL_DO_NOT_LOG';
  }

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Object storyGenerationModelRouteIdentity({required String traceName}) =>
      _store.storyGenerationModelRouteIdentity(traceName: traceName) ??
      (throw StateError('real AppSettings route identity is unavailable'));

  @override
  StoryGenerationSinglePhysicalDispatchRouteLease
  prepareStoryGenerationSinglePhysicalDispatchRoute({
    required String traceName,
  }) {
    final inner = _store.prepareStoryGenerationSinglePhysicalDispatchRoute(
      traceName: traceName,
    );
    if (inner == null) {
      throw StateError('real AppSettings route preflight failed');
    }
    return _IoCompletionRouteLease(traceName, inner);
  }

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    _captureRequest(
      messages: messages,
      stageId: stageId,
      callSiteId: callSiteId,
      generationBundleHash: generationBundleHash,
      promptReleaseRef: promptReleaseRef,
      promptInvocationEvidence: promptInvocationEvidence,
    );
    return _store.requestAiCompletion(
      messages: messages,
      maxTokens: maxTokens,
      traceName: traceName,
      traceMetadata: traceMetadata,
      promptReleaseRef: promptReleaseRef,
      promptInvocationEvidence: promptInvocationEvidence,
      promptVersion: promptVersion,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      generationBundleHash: generationBundleHash,
    );
  }

  @override
  Future<AppLlmChatResult> requestAiCompletionSinglePhysicalDispatch({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    required String dispatchEvidenceNonce,
    required Map<String, Object?> formalDispatchIntent,
    required Object committedIntentAuthority,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
    required StoryGenerationSinglePhysicalDispatchRouteLease routeLease,
  }) {
    if (routeLease is! _IoCompletionRouteLease ||
        routeLease.traceName != traceName) {
      throw StateError('unexpected single-dispatch route lease');
    }
    _captureRequest(
      messages: messages,
      stageId: stageId,
      callSiteId: callSiteId,
      generationBundleHash: generationBundleHash,
      promptReleaseRef: promptReleaseRef,
      promptInvocationEvidence: promptInvocationEvidence,
    );
    return _store
        .requestAiCompletionSinglePhysicalDispatch(
          messages: messages,
          maxTokens: maxTokens,
          traceName: traceName,
          traceMetadata: traceMetadata,
          promptReleaseRef: promptReleaseRef,
          promptInvocationEvidence: promptInvocationEvidence,
          promptVersion: promptVersion,
          stageId: stageId,
          callSiteId: callSiteId,
          variantId: variantId,
          generationBundleHash: generationBundleHash,
          dispatchEvidenceNonce: dispatchEvidenceNonce,
          formalDispatchIntent: formalDispatchIntent,
          committedIntentAuthority: committedIntentAuthority,
          routeLease: routeLease.inner,
        )
        .then((result) {
          if (!malformedRouteIdentity) return result;
          return result.withDispatchResolution(
            AppLlmDispatchResolution(
              endpointId: _resolution.endpointId,
              baseUrl: '$_baseUrl/observed-route-substitution',
              model: '${_resolution.model}-observed-substitution',
              provider: _resolution.provider,
              isLocal: true,
              physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
            ),
          );
        });
  }

  void _captureRequest({
    required List<AppLlmChatMessage> messages,
    required String? stageId,
    required String? callSiteId,
    required String? generationBundleHash,
    required PromptReleaseRef? promptReleaseRef,
    required PromptInvocationEvidence? promptInvocationEvidence,
  }) {
    calls += 1;
    this.stageId ??= stageId;
    this.callSiteId ??= callSiteId;
    this.generationBundleHash ??= generationBundleHash;
    this.promptReleaseRef ??= promptReleaseRef;
    this.promptInvocationEvidence ??= promptInvocationEvidence;
    expect(promptInvocationEvidence?.matchesMessages(messages), isTrue);
  }

  void dispose() => _store.dispose();
}

final class _IoCompletionRouteLease
    implements StoryGenerationSinglePhysicalDispatchRouteLease {
  const _IoCompletionRouteLease(this.traceName, this.inner);

  final String traceName;
  final StoryGenerationSinglePhysicalDispatchRouteLease inner;

  @override
  Object get credentialFreeIdentity => inner.credentialFreeIdentity;
}

final class _PipelineTestRouteLease
    implements StoryGenerationSinglePhysicalDispatchRouteLease {
  const _PipelineTestRouteLease(this.credentialFreeIdentity);

  @override
  final Object credentialFreeIdentity;
}

final class _TestProviderBoundaryReceipt
    implements AppLlmProviderBoundaryReceipt {
  const _TestProviderBoundaryReceipt();

  @override
  String get contract => 'app-llm-provider-boundary-receipt-v1';

  @override
  int get physicalDispatchCount => 1;

  @override
  String get requestedBaseUrl => 'http://test-provider.local';

  @override
  String get requestedModel => 'test-model';

  @override
  AppLlmProvider get requestedProvider => AppLlmProvider.openaiCompatible;

  @override
  String get dispatchEvidenceNonce =>
      'sha256:0000000000000000000000000000000000000000000000000000000000000000';

  @override
  String get transportEndpoint => 'http://test-provider.local/chat/completions';

  @override
  Map<String, Object?> toCredentialFreeJson() => <String, Object?>{
    'contract': contract,
    'physicalDispatchCount': physicalDispatchCount,
    'requestedBaseUrl': requestedBaseUrl,
    'requestedModel': requestedModel,
    'requestedProvider': requestedProvider.name,
    'dispatchEvidenceNonce': dispatchEvidenceNonce,
    'transportEndpoint': transportEndpoint,
  };
}
