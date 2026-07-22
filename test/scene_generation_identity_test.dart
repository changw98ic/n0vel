import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/narrative_arc_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_context_models.dart';
import 'package:novel_writer/features/story_generation/data/scene_generation_identity.dart';
import 'package:novel_writer/features/story_generation/data/scene_runtime_models.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/structured_profile.dart';

void main() {
  group('SceneGenerationIdentity', () {
    test('includes every generation-visible SceneBrief field', () {
      final base = _brief();
      final baseHash = SceneGenerationIdentity.briefHash(base);

      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(chapterTitle: '第二章 雨夜'),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(base.copyWith(formalExecution: true)),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(
            cast: [
              _cast(name: '陈止', action: '收刀', metadata: {'scar': 'left'}),
            ],
          ),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(characterProfiles: [_profile(backstory: '曾经背叛过同门')]),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(
            relationshipStates: [
              _relationship(sharedSecrets: ['旧案', '私下交易']),
            ],
          ),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(
            socialPositions: [
              _social(resources: ['巡检腰牌', '密信']),
            ],
          ),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(
            beliefStates: [
              _belief(perceivedKnowledge: ['他知道井底尸体']),
            ],
          ),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(
            presentationStates: [
              _presentation(concealments: ['假装没有受伤']),
            ],
          ),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(knowledgeAtoms: [_knowledge(content: '凶手不是外来人')]),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(narrativeArc: _arc(thematicArcs: ['欠债者终被欠债追上'])),
        ),
        isNot(baseHash),
      );
      expect(
        SceneGenerationIdentity.briefHash(
          base.copyWith(
            metadata: {
              ...base.metadata,
              'requiredOutlineBeats': ['进祠堂', '看见断香', '听见雨停'],
            },
          ),
        ),
        isNot(baseHash),
      );
    });

    test('excludes only versioned non-semantic metadata keys', () {
      final base = _brief(
        metadata: {
          'requiredOutlineBeats': ['进祠堂', '看见断香'],
          'createdAtMs': 1,
          'traceId': 'trace-a',
          'artifactPath': '/tmp/a.json',
          'displayLabel': 'human friendly label',
        },
      );
      final changedNonSemantic = _brief(
        metadata: {
          'requiredOutlineBeats': ['进祠堂', '看见断香'],
          'createdAtMs': 2,
          'traceId': 'trace-b',
          'artifactPath': '/tmp/b.json',
          'displayLabel': 'renamed label',
        },
      );
      final changedUnknown = _brief(
        metadata: {
          'requiredOutlineBeats': ['进祠堂', '看见断香'],
          'createdAtMs': 1,
          'traceId': 'trace-a',
          'artifactPath': '/tmp/a.json',
          'displayLabel': 'human friendly label',
          'newPromptVisibleConstraint': '必须让配角先开口',
        },
      );

      expect(
        SceneGenerationIdentity.briefHash(changedNonSemantic),
        SceneGenerationIdentity.briefHash(base),
      );
      expect(
        SceneGenerationIdentity.briefHash(changedUnknown),
        isNot(SceneGenerationIdentity.briefHash(base)),
      );
      expect(SceneGenerationIdentity.excludesMetadataKey('traceId'), isTrue);
      expect(
        SceneGenerationIdentity.excludesMetadataKey(
          'newPromptVisibleConstraint',
        ),
        isFalse,
      );
    });

    test('recursively excludes transport metadata inside prompt profiles', () {
      final base = _brief().copyWith(
        characterProfiles: [
          _profile(
            metadata: const {
              'promptVisibleTag': '克制',
              'transport': {
                'traceId': 'trace-a',
                'createdAtMs': 1,
                'provenancePath': '/tmp/profile-a.json',
              },
            },
          ),
        ],
        metadata: const {
          'requiredOutlineBeats': ['进祠堂', '看见断香'],
          'runtime': {
            'requestId': 'request-a',
            'artifactPath': '/tmp/run-a/output.json',
          },
        },
      );
      final transportOnlyChange = _brief().copyWith(
        characterProfiles: [
          _profile(
            metadata: const {
              'promptVisibleTag': '克制',
              'transport': {
                'traceId': 'trace-b',
                'createdAtMs': 2,
                'provenancePath': '/tmp/profile-b.json',
              },
            },
          ),
        ],
        metadata: const {
          'requiredOutlineBeats': ['进祠堂', '看见断香'],
          'runtime': {
            'requestId': 'request-b',
            'artifactPath': '/tmp/run-b/output.json',
          },
        },
      );
      final semanticChange = _brief().copyWith(
        characterProfiles: [
          _profile(
            metadata: const {
              'promptVisibleTag': '急躁',
              'transport': {
                'traceId': 'trace-b',
                'createdAtMs': 2,
                'provenancePath': '/tmp/profile-b.json',
              },
            },
          ),
        ],
        metadata: transportOnlyChange.metadata,
      );

      expect(
        SceneGenerationIdentity.briefHash(transportOnlyChange),
        SceneGenerationIdentity.briefHash(base),
      );
      expect(
        SceneGenerationIdentity.briefHash(semanticChange),
        isNot(SceneGenerationIdentity.briefHash(base)),
      );
    });

    test(
      'transport-only nested subtrees can appear or disappear without changing identity',
      () {
        final base = _brief().copyWith(
          cast: [
            _cast(metadata: const {'visibleWound': 'right hand'}),
          ],
          characterProfiles: [
            _profile(metadata: const {'promptVisibleTag': '克制'}),
          ],
        );
        final withTransportSubtrees = base.copyWith(
          cast: [
            _cast(
              metadata: {
                'visibleWound': 'right hand',
                'transport': [
                  {'request_id': 'request-a', 'GENERATED-AT-MS': 77},
                  {'local_artifact_path': '/tmp/cast.json'},
                ],
              },
            ),
          ],
          characterProfiles: [
            _profile(
              metadata: {
                'promptVisibleTag': '克制',
                'audit': {
                  'taskId': 'task-a',
                  'provenanceRefs': ['/tmp/source-a.json'],
                  'ui_only': {'expanded': true},
                },
              },
            ),
          ],
          metadata: {
            ...base.metadata,
            'runtime': {
              'run-id': 'run-a',
              'provider_request_id': 'provider-a',
              'timestamp': '2026-07-21T12:00:00Z',
            },
          },
        );

        expect(
          SceneGenerationIdentity.briefHash(withTransportSubtrees),
          SceneGenerationIdentity.briefHash(base),
        );
      },
    );

    test('retains nested prompt semantics next to stripped metadata', () {
      final base = _brief().copyWith(
        characterProfiles: [
          _profile(
            metadata: const {
              'directing': {
                'promptConstraint': '说话前先看门外',
                'traceId': 'trace-a',
              },
            },
          ),
        ],
      );
      final transportOnlyChange = base.copyWith(
        characterProfiles: [
          _profile(
            metadata: const {
              'directing': {
                'promptConstraint': '说话前先看门外',
                'traceId': 'trace-b',
              },
            },
          ),
        ],
      );
      final promptChange = base.copyWith(
        characterProfiles: [
          _profile(
            metadata: const {
              'directing': {
                'promptConstraint': '说话前先看井口',
                'traceId': 'trace-a',
              },
            },
          ),
        ],
      );

      expect(
        SceneGenerationIdentity.briefHash(transportOnlyChange),
        SceneGenerationIdentity.briefHash(base),
      );
      expect(
        SceneGenerationIdentity.briefHash(promptChange),
        isNot(SceneGenerationIdentity.briefHash(base)),
      );
    });

    test('metadata policy is versioned and exact rather than suffix-based', () {
      final projection = SceneGenerationIdentity.briefObject(_brief());

      expect(
        projection['metadataProjectionVersion'],
        SceneGenerationIdentity.metadataProjectionVersion,
      );
      expect(
        SceneGenerationIdentity.metadataProjectionVersion,
        'scene-generation-metadata-v1',
      );
      expect(SceneGenerationIdentity.excludesMetadataKey('REQUEST_ID'), isTrue);
      expect(
        SceneGenerationIdentity.excludesMetadataKey('provenance-path'),
        isTrue,
      );
      expect(
        SceneGenerationIdentity.excludesMetadataKey('generated_at_ms'),
        isTrue,
      );
      expect(
        SceneGenerationIdentity.excludesMetadataKey('storyRunId'),
        isFalse,
      );
      expect(
        SceneGenerationIdentity.excludesMetadataKey('fictionalTimestamp'),
        isFalse,
      );
      expect(SceneGenerationIdentity.excludesMetadataKey('path'), isFalse);
      expect(SceneGenerationIdentity.excludesMetadataKey('state'), isFalse);
    });

    test('similarly named semantic metadata still changes identity', () {
      final base = _brief(
        metadata: const {
          'storyRunId': 'third-night',
          'fictionalTimestamp': '子时三刻',
          'path': '井沿到内堂',
          'state': '香灰未冷',
        },
      );
      final changed = _brief(
        metadata: const {
          'storyRunId': 'fourth-night',
          'fictionalTimestamp': '子时三刻',
          'path': '井沿到内堂',
          'state': '香灰未冷',
        },
      );

      expect(
        SceneGenerationIdentity.briefHash(changed),
        isNot(SceneGenerationIdentity.briefHash(base)),
      );
    });

    test('preserves list order as semantic order', () {
      final base = _brief(
        metadata: {
          'requiredOutlineBeats': ['进祠堂', '看见断香'],
        },
      );
      final reorderedBeats = _brief(
        metadata: {
          'requiredOutlineBeats': ['看见断香', '进祠堂'],
        },
      );
      final reorderedCast = base.copyWith(
        cast: [
          _cast(characterId: 'b', name: '乙', role: '旁观者'),
          _cast(characterId: 'a', name: '甲', role: '主导者'),
        ],
      );

      expect(
        SceneGenerationIdentity.briefHash(reorderedBeats),
        isNot(SceneGenerationIdentity.briefHash(base)),
      );
      expect(
        SceneGenerationIdentity.briefHash(reorderedCast),
        isNot(SceneGenerationIdentity.briefHash(base)),
      );
    });

    test('fails closed for non-json metadata values', () {
      expect(
        () => SceneGenerationIdentity.briefObject(
          _brief(metadata: {'bad': Object()}),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('skips excluded opaque values but rejects nested semantic ones', () {
      expect(
        () => SceneGenerationIdentity.briefObject(
          _brief(
            metadata: {
              'runtime': {'traceId': Object()},
            },
          ),
        ),
        returnsNormally,
      );
      expect(
        () => SceneGenerationIdentity.briefObject(
          _brief(
            metadata: {
              'runtime': {'promptConstraint': Object()},
            },
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

SceneBrief _brief({Map<String, Object?> metadata = const {}}) {
  return SceneBrief(
    projectId: 'project-1',
    chapterId: 'chapter-1',
    chapterTitle: '第一章 雨入祠堂',
    sceneId: 'scene-1',
    sceneIndex: 1,
    totalScenesInChapter: 3,
    sceneTitle: '断香',
    sceneSummary: '陈止进祠堂查断香。',
    targetLength: 1200,
    targetBeat: '发现断香与井底旧案有关。',
    worldNodeIds: const ['祠堂', '井'],
    cast: [_cast(characterId: 'a', name: '甲', role: '主导者')],
    characterProfiles: [_profile()],
    relationshipStates: [_relationship()],
    socialPositions: [_social()],
    beliefStates: [_belief()],
    presentationStates: [_presentation()],
    knowledgeAtoms: [_knowledge()],
    narrativeArc: _arc(),
    metadata: {
      'requiredOutlineBeats': ['进祠堂', '看见断香'],
      'privateFacts': {
        '陈止': ['知道井底不是第一次死人'],
      },
      ...metadata,
    },
  );
}

SceneCastCandidate _cast({
  String characterId = 'c1',
  String name = '陈止',
  String role = '查案者',
  String? action = '推门',
  Map<String, Object?> metadata = const {'visibleWound': 'right hand'},
}) {
  return SceneCastCandidate(
    characterId: characterId,
    name: name,
    role: role,
    participation: SceneCastParticipation(action: action, dialogue: '低声问话'),
    metadata: metadata,
  );
}

StructuredProfile _profile({
  String backstory = '旧县衙书吏',
  Map<String, Object?> metadata = const {'promptVisibleTag': '克制'},
}) {
  return StructuredProfile(
    id: 'c1',
    name: '陈止',
    personality: const PersonalityVector(openness: 0.7),
    voicePrint: const VoicePrint(
      sentenceLength: 'short',
      speakingPatterns: ['先停顿再反问'],
    ),
    behaviorBounds: const BehaviorBounds(
      forbiddenActions: ['无故杀人'],
      mandatoryResponses: ['先确认旁人目光'],
    ),
    backstory: backstory,
    relationships: const [
      RelationshipEdge(targetId: 'c2', type: 'old-debt', strength: 0.8),
    ],
    metadata: metadata,
  );
}

RelationshipState _relationship({List<String> sharedSecrets = const ['旧案']}) {
  return RelationshipState(
    sourceCharacterId: 'c1',
    targetCharacterId: 'c2',
    trust: 0.2,
    dependence: 0.1,
    fear: 0.4,
    resentment: 0.6,
    desire: 0.3,
    powerGap: 0.5,
    publicAlignment: '同路',
    privateAlignment: '互疑',
    sharedSecrets: sharedSecrets,
    recentTriggers: const ['雨夜'],
  );
}

SocialPositionState _social({List<String> resources = const ['旧卷宗']}) {
  return SocialPositionState(
    characterId: 'c1',
    institution: '县衙',
    publicStatus: '退职书吏',
    legalExposure: '可被旧案牵连',
    resources: resources,
    activeConstraints: const ['不能公开进祠堂'],
    currentLeverage: const ['知道香灰去向'],
    watchers: const ['族老'],
  );
}

BeliefState _belief({List<String> perceivedKnowledge = const ['族老撒谎']}) {
  return BeliefState(
    ownerCharacterId: 'c1',
    aboutCharacterId: 'c2',
    perceivedGoal: '遮掩旧案',
    perceivedLoyalty: '祠堂',
    perceivedCompetence: '熟悉卷宗',
    perceivedRisk: '会毁证',
    perceivedEmotionalState: '镇定过度',
    perceivedKnowledge: perceivedKnowledge,
    suspectedSecrets: const ['井底尸体'],
    misreadPoints: const ['以为对方不知道断香'],
    confidence: 0.65,
  );
}

ContextPresentationState _presentation({
  List<String> concealments = const ['隐瞒手伤'],
}) {
  return ContextPresentationState(
    characterId: 'c1',
    projectedPersona: '只是避雨',
    concealments: concealments,
    deceptionGoals: const ['让族老先说出香灰'],
  );
}

KnowledgeAtom _knowledge({String content = '断香来自内堂'}) {
  return KnowledgeAtom(
    id: 'k1',
    type: 'clue',
    content: content,
    ownerScope: 'scene',
    visibility: KnowledgeVisibility.agentPrivate,
    priority: 3,
    tokenCostEstimate: 12,
    tags: const ['香', '旧案'],
    unlockCondition: const {'afterBeat': '进祠堂'},
  );
}

NarrativeArcState _arc({List<String> thematicArcs = const ['债会回头']}) {
  return NarrativeArcState(
    activeThreads: [
      PlotThread(
        id: 't1',
        description: '井底旧案',
        status: PlotThreadStatus.rising,
        involvedCharacters: const ['c1', 'c2'],
        introducedInScene: 'scene-0',
      ),
    ],
    closedThreads: [
      PlotThread(
        id: 't0',
        description: '雨夜入城',
        status: PlotThreadStatus.resolved,
        involvedCharacters: const ['c1'],
        introducedInScene: 'scene-0',
        resolvedInScene: 'scene-1',
      ),
    ],
    pendingForeshadowing: [
      Foreshadowing(
        id: 'f1',
        hint: '井绳有新泥',
        plantedInScene: 'scene-1',
        plannedPayoff: '第三章',
        urgency: 2,
      ),
    ],
    thematicArcs: thematicArcs,
    chapterIndex: 1,
  );
}
