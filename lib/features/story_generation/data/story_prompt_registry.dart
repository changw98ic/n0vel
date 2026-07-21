import 'dart:async';

import '../../../app/llm/app_llm_prompt_release.dart';
import '../../../app/llm/app_llm_prompt_release_store.dart';
import '../../../app/llm/app_llm_prompt_invocation.dart';
import '../../../app/llm/app_llm_client_types.dart';
import '../../../app/llm/app_llm_prompt_renderer.dart';
import '../../../domain/prompt_language.dart';
import 'story_prompt_templates.dart';

final class StoryPromptCallSite {
  const StoryPromptCallSite(this.stageId, this.callSiteId, this.variantId);

  final String stageId;
  final String callSiteId;
  final String variantId;

  String get key => '$stageId\u0000$callSiteId\u0000$variantId';
}

final class StoryPromptRegistration {
  const StoryPromptRegistration({
    required this.callSite,
    required this.release,
  });

  final StoryPromptCallSite callSite;
  final PromptRelease release;

  GenerationBundleBinding get binding => GenerationBundleBinding(
    stageId: callSite.stageId,
    callSiteId: callSite.callSiteId,
    variantId: callSite.variantId,
    promptReleaseRef: release.ref,
  );
}

final class StoryPromptInvocation {
  const StoryPromptInvocation({
    required this.callSite,
    required this.release,
    required this.generationBundleHash,
  });

  final StoryPromptCallSite callSite;
  final PromptRelease release;
  final String generationBundleHash;

  PromptReleaseRef get promptReleaseRef => release.ref;

  AppLlmRenderedPrompt render(Map<String, Object?> resolvedVariables) =>
      AppLlmPromptRendererRegistry.builtIn.render(
        release: release,
        resolvedVariables: resolvedVariables,
      );

  PromptInvocationEvidence evidence(
    List<AppLlmChatMessage> messages, {
    required Map<String, Object?> resolvedVariables,
  }) {
    return PromptInvocationEvidence(
      release: release,
      promptReleaseRef: release.ref,
      messages: messages,
      resolvedVariables: resolvedVariables,
    );
  }
}

/// Explicit identity registry for every production story-generation LLM call.
///
/// This registry is intentionally separate from trace-name inference. Adding or
/// removing a production call-site requires changing [requiredCallSites] and
/// publishing its own immutable release; incomplete coverage fails closed.
final class StoryPromptRegistry {
  factory StoryPromptRegistry.current() =>
      StoryPromptRegistry.fromRegistrations(currentRegistrations);

  factory StoryPromptRegistry.literaryEvaluation() =>
      StoryPromptRegistry._fromRegistrations(
        [_buildLiteraryEvaluationRegistration()],
        expectedCallSites: const [literaryEvaluationCallSite],
        bundleId: 'story-literary-evaluation-v1',
      );

  factory StoryPromptRegistry.causalityChallenger() {
    final champion = StoryPromptRegistry.current();
    final original = champion.registrations.singleWhere(
      (registration) =>
          registration.callSite.stageId == 'editorial' &&
          registration.callSite.callSiteId == 'scene-editorial-generator',
    );
    final release = original.release;
    return champion.replacing(
      StoryPromptRegistration(
        callSite: original.callSite,
        release: PromptRelease(
          templateId: release.templateId,
          semanticVersion: '1.2.0-causality-challenger',
          language: release.language,
          systemTemplate:
              '${release.systemTemplate}\n'
              'For every major irreversible choice, make the prose show this '
              'causal bridge in order: concrete evidence or pressure, visible '
              'resistance or cost, a specific trigger, an observable reaction, '
              'then the choice and its immediate consequence. Do not replace '
              'the bridge with a summary sentence.',
          userTemplate: release.userTemplate,
          variablesSchemaSnapshot: release.variablesSchemaSnapshot,
          outputSchemaSnapshot: release.outputSchemaSnapshot,
          rendererRelease: release.rendererRelease,
          parserRelease: release.parserRelease,
          repairPolicySnapshot: release.repairPolicySnapshot,
          owner: release.owner,
          changeNote:
              'Champion/challenger candidate for explicit causal transitions.',
          createdAt: DateTime.utc(2026, 7, 12),
        ),
      ),
    );
  }

  factory StoryPromptRegistry.fromRegistrations(
    Iterable<StoryPromptRegistration> registrations, {
    String bundleId = 'story-generation-production-v1',
  }) => StoryPromptRegistry._fromRegistrations(
    registrations,
    expectedCallSites: requiredCallSites,
    bundleId: bundleId,
  );

  factory StoryPromptRegistry._fromRegistrations(
    Iterable<StoryPromptRegistration> registrations, {
    required Iterable<StoryPromptCallSite> expectedCallSites,
    required String bundleId,
  }) {
    final values = List<StoryPromptRegistration>.of(registrations);
    final byKey = <String, StoryPromptRegistration>{};
    final releaseIdentities = <String>{};
    for (final registration in values) {
      final key = registration.callSite.key;
      if (byKey.containsKey(key)) {
        throw StateError('duplicate story prompt call-site: $key');
      }
      if (!registration.release.hasValidContentHash) {
        throw StateError('invalid prompt release at call-site: $key');
      }
      if (!releaseIdentities.add(registration.release.contentHash)) {
        throw StateError(
          'call-sites must have independent prompt releases: $key',
        );
      }
      byKey[key] = registration;
    }

    final required = {for (final callSite in expectedCallSites) callSite.key};
    final actual = byKey.keys.toSet();
    final missing = required.difference(actual).toList()..sort();
    final unexpected = actual.difference(required).toList()..sort();
    if (missing.isNotEmpty || unexpected.isNotEmpty) {
      throw StateError(
        'story prompt registry coverage mismatch; '
        'missing=${missing.join(',')}; unexpected=${unexpected.join(',')}',
      );
    }

    final ordered = values
      ..sort((left, right) => left.callSite.key.compareTo(right.callSite.key));
    final frozen = List<StoryPromptRegistration>.unmodifiable(ordered);
    return StoryPromptRegistry._(
      registrations: frozen,
      byKey: Map<String, StoryPromptRegistration>.unmodifiable(byKey),
      generationBundle: GenerationBundle(
        bundleId: bundleId,
        releases: [for (final registration in frozen) registration.binding],
      ),
    );
  }

  const StoryPromptRegistry._({
    required this.registrations,
    required Map<String, StoryPromptRegistration> byKey,
    required this.generationBundle,
  }) : _byKey = byKey;

  final List<StoryPromptRegistration> registrations;
  final Map<String, StoryPromptRegistration> _byKey;
  final GenerationBundle generationBundle;

  static final Object _zoneKey = Object();
  static final StoryPromptRegistry _production = StoryPromptRegistry.current();

  static StoryPromptRegistry get production =>
      Zone.current[_zoneKey] as StoryPromptRegistry? ?? _production;

  T run<T>(T Function() body) =>
      runZoned(body, zoneValues: <Object, Object>{_zoneKey: this});

  Future<T> runAsync<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: <Object, Object>{_zoneKey: this});

  StoryPromptRegistry replacing(StoryPromptRegistration replacement) {
    final registrations = <StoryPromptRegistration>[
      for (final registration in this.registrations)
        if (registration.callSite.key == replacement.callSite.key)
          replacement
        else
          registration,
    ];
    if (!registrations.any(
      (registration) => registration.callSite.key == replacement.callSite.key,
    )) {
      throw StateError(
        'replacement call-site is not part of the production inventory',
      );
    }
    final safeVersion = replacement.release.semanticVersion.replaceAll(
      RegExp(r'[^a-zA-Z0-9._-]'),
      '-',
    );
    return StoryPromptRegistry.fromRegistrations(
      registrations,
      bundleId:
          'story-generation-${replacement.release.templateId}-$safeVersion',
    );
  }

  /// Publishes the exact code-reviewed production registry into the durable
  /// prompt authority. Repeated calls are idempotent only when every immutable
  /// snapshot and bundle member is byte-for-byte equivalent.
  void publishTo(AppLlmPromptReleaseStore store) {
    for (final registration in registrations) {
      store.putPromptRelease(registration.release);
    }
    store.putGenerationBundle(generationBundle);
  }

  PromptRelease resolve({
    required String stageId,
    required String callSiteId,
    required String variantId,
  }) {
    final key = '$stageId\u0000$callSiteId\u0000$variantId';
    final registration = _byKey[key];
    if (registration == null) {
      throw StateError('unregistered story prompt call-site: $key');
    }
    return registration.release;
  }

  StoryPromptInvocation invocation({
    required String stageId,
    required String callSiteId,
    String variantId = 'zh',
  }) {
    final callSite = StoryPromptCallSite(stageId, callSiteId, variantId);
    final release = resolve(
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
    );
    return StoryPromptInvocation(
      callSite: callSite,
      release: release,
      generationBundleHash: generationBundle.bundleHash,
    );
  }

  static const List<StoryPromptCallSite> requiredCallSites = [
    StoryPromptCallSite('director', 'scene-director', 'zh'),
    StoryPromptCallSite('editorial', 'scene-editor', 'zh'),
    StoryPromptCallSite('editorial', 'scene-editorial-generator', 'zh'),
    StoryPromptCallSite('review', 'judge', 'zh'),
    StoryPromptCallSite('review', 'consistency', 'zh'),
    StoryPromptCallSite('review', 'format-repair-judge', 'zh'),
    StoryPromptCallSite('quality-gate', 'quality-scorer', 'zh'),
    StoryPromptCallSite('roleplay', 'role-agent-controller', 'zh'),
    StoryPromptCallSite('roleplay', 'role-turn', 'zh'),
    StoryPromptCallSite('beat-resolution', 'beat-resolver', 'zh'),
    StoryPromptCallSite('stage-narration', 'stage-narrator', 'zh'),
    StoryPromptCallSite('polish', 'language-polish', 'zh'),
    StoryPromptCallSite('roleplay', 'arbiter', 'zh'),
    StoryPromptCallSite('chapter-summary', 'chapter-summarizer', 'zh'),
    StoryPromptCallSite('review', 'character-consistency', 'zh'),
    StoryPromptCallSite('prose', 'scene-prose', 'zh'),
    StoryPromptCallSite('review', 'reader-flow', 'zh'),
    StoryPromptCallSite('review', 'lexicon', 'zh'),
    StoryPromptCallSite('review', 'adjudication', 'zh'),
    StoryPromptCallSite('review', 'format-repair-consistency', 'zh'),
    StoryPromptCallSite('review', 'format-repair-reader-flow', 'zh'),
    StoryPromptCallSite('review', 'format-repair-lexicon', 'zh'),
    StoryPromptCallSite('review', 'format-repair-adjudication', 'zh'),
  ];

  static const StoryPromptCallSite literaryEvaluationCallSite =
      StoryPromptCallSite('literary-quality', 'scene-evaluator', 'zh');

  static List<StoryPromptRegistration> get currentRegistrations =>
      List<StoryPromptRegistration>.unmodifiable(
        StoryPromptTemplates.runWithLanguage(
          PromptLanguage.zh,
          _buildCurrentRegistrations,
        ),
      );
}

StoryPromptRegistration
_buildLiteraryEvaluationRegistration() => StoryPromptRegistration(
  callSite: StoryPromptRegistry.literaryEvaluationCallSite,
  release: PromptRelease(
    templateId: 'scene_literary_quality_evaluation',
    semanticVersion: '1.2.0',
    language: 'zh',
    systemTemplate: _literaryEvaluationSystemTemplate,
    userTemplate: _literaryEvaluationUserTemplate,
    variablesSchemaSnapshot: const <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['evaluationInputJson'],
      'properties': <String, Object?>{
        'evaluationInputJson': <String, Object?>{'type': 'string'},
      },
    },
    outputSchemaSnapshot: _literaryEvaluationOutputSchema,
    rendererRelease: AppLlmPromptRendererRegistry.strictRendererRelease,
    parserRelease: 'scene-literary-quality-output-parser-v1',
    repairPolicySnapshot: const <String, Object?>{
      'policy': 'bounded-retry-v1',
      'maxOutputRetries': 2,
      'localRepair': false,
      'outputMode': 'closed-json',
    },
    owner: 'story-generation-quality',
    changeNote:
        'Add concrete 60/75/85/90/95 anchors, near-final contradiction checks, and exact deviation authorization semantics after repeated real-provider scoring.',
    createdAt: DateTime.utc(2026, 7, 21),
  ),
);

const Map<String, Object?> _literaryEvaluationOutputSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>[
    'schemaVersion',
    'semanticHardReview',
    'craft',
    'styleFit',
    'readerEffect',
    'findings',
    'evaluatorSelfConfidence',
  ],
  'properties': <String, Object?>{
    'schemaVersion': <String, Object?>{'type': 'integer', 'const': 1},
    'semanticHardReview': <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['passed', 'hardFindingIds'],
      'properties': <String, Object?>{
        'passed': <String, Object?>{'type': 'boolean'},
        'hardFindingIds': <String, Object?>{
          'type': 'array',
          'uniqueItems': true,
          'items': <String, Object?>{'type': 'string', 'minLength': 1},
        },
      },
    },
    'craft': <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['dimensions'],
      'properties': <String, Object?>{
        'dimensions': <String, Object?>{
          'type': 'object',
          'additionalProperties': false,
          'required': <String>[
            'prosePrecision',
            'paragraphFunction',
            'scenePressure',
            'characterVoice',
            'informationControl',
            'coherence',
            'completenessAndTurn',
          ],
          'properties': <String, Object?>{
            'prosePrecision': _literaryScoreSchema,
            'paragraphFunction': _literaryScoreSchema,
            'scenePressure': _literaryScoreSchema,
            'characterVoice': _literaryScoreSchema,
            'informationControl': _literaryScoreSchema,
            'coherence': _literaryScoreSchema,
            'completenessAndTurn': _literaryScoreSchema,
          },
        },
      },
    },
    'styleFit': <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>[
        'decision',
        'axisExplanations',
        'deviationIds',
        'evidenceRefs',
        'deviationAuthorizationRefs',
      ],
      'properties': <String, Object?>{
        'decision': <String, Object?>{
          'type': 'string',
          'enum': <String>[
            'aligned',
            'plannedDeviation',
            'approvedDeviation',
            'mismatch',
          ],
        },
        'axisExplanations': <String, Object?>{
          'type': 'object',
          'additionalProperties': <String, Object?>{
            'type': 'string',
            'minLength': 1,
          },
        },
        'deviationIds': _literaryUniqueStringArraySchema,
        'evidenceRefs': _literaryUniqueStringArraySchema,
        'deviationAuthorizationRefs': _literaryAuthorizationArraySchema,
      },
    },
    'readerEffect': <String, Object?>{
      'type': 'object',
      'additionalProperties': false,
      'required': <String>['effectEstimates', 'warnings'],
      'properties': <String, Object?>{
        'effectEstimates': <String, Object?>{
          'type': 'object',
          'additionalProperties': false,
          'required': <String>[
            'tension',
            'clarity',
            'curiosity',
            'emotionalImpact',
            'momentum',
          ],
          'properties': <String, Object?>{
            'tension': _literaryReaderEstimateSchema,
            'clarity': _literaryReaderEstimateSchema,
            'curiosity': _literaryReaderEstimateSchema,
            'emotionalImpact': _literaryReaderEstimateSchema,
            'momentum': _literaryReaderEstimateSchema,
          },
        },
        'warnings': _literaryUniqueStringArraySchema,
      },
    },
    'findings': <String, Object?>{
      'type': 'array',
      'items': _literaryFindingSchema,
    },
    'evaluatorSelfConfidence': <String, Object?>{
      'type': 'number',
      'minimum': 0,
      'maximum': 1,
    },
  },
};

const Map<String, Object?> _literaryScoreSchema = <String, Object?>{
  'type': 'number',
  'minimum': 0,
  'maximum': 100,
};

const Map<String, Object?> _literaryUniqueStringArraySchema = <String, Object?>{
  'type': 'array',
  'uniqueItems': true,
  'items': <String, Object?>{'type': 'string', 'minLength': 1},
};

const Map<String, Object?> _literaryReaderEstimateSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['value', 'evidenceRefs'],
  'properties': <String, Object?>{
    'value': _literaryScoreSchema,
    'evidenceRefs': _literaryUniqueStringArraySchema,
  },
};

const Map<String, Object?> _literaryAuthorizationArraySchema =
    <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['authorizedBy', 'referenceId'],
        'properties': <String, Object?>{
          'authorizedBy': <String, Object?>{
            'type': 'string',
            'enum': <String>[
              'sceneContract',
              'independentReview',
              'authorOverride',
            ],
          },
          'referenceId': <String, Object?>{'type': 'string', 'minLength': 1},
        },
      },
    };

const Map<String, Object?> _literaryFindingSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>[
    'findingId',
    'findingClass',
    'severity',
    'axis',
    'code',
    'claim',
    'evidence',
    'contractRefs',
    'suggestedAction',
    'effectiveFunction',
    'expectedReturnCondition',
    'deviationAuthorizationRefs',
  ],
  'properties': <String, Object?>{
    'findingId': <String, Object?>{'type': 'string', 'minLength': 1},
    'findingClass': <String, Object?>{
      'type': 'string',
      'enum': <String>[
        'hardError',
        'craftWeakness',
        'styleChoice',
        'effectiveDeviation',
      ],
    },
    'severity': <String, Object?>{
      'type': 'string',
      'enum': <String>['blocker', 'major', 'minor', 'note'],
    },
    'axis': <String, Object?>{
      'type': 'string',
      'enum': <String>[
        'causality',
        'timeline',
        'spatialContinuity',
        'worldRule',
        'pov',
        'characterKnowledge',
        'characterMotivation',
        'relationship',
        'objectState',
        'corePromise',
        'foreshadowing',
        'prose',
        'paragraphFunction',
        'scenePressure',
        'informationControl',
        'characterVoice',
        'rhythm',
        'projectVoice',
        'readerEffect',
        'provenance',
      ],
    },
    'code': <String, Object?>{'type': 'string', 'minLength': 1},
    'claim': <String, Object?>{'type': 'string', 'minLength': 1},
    'evidence': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>['startOffset', 'endOffset', 'localExcerpt'],
        'properties': <String, Object?>{
          'startOffset': <String, Object?>{'type': 'integer', 'minimum': 0},
          'endOffset': <String, Object?>{'type': 'integer', 'minimum': 1},
          'localExcerpt': <String, Object?>{
            'type': 'string',
            'minLength': 1,
            'maxLength': 240,
          },
        },
      },
    },
    'contractRefs': _literaryUniqueStringArraySchema,
    'suggestedAction': <String, Object?>{
      'type': 'string',
      'enum': <String>[
        'blockAndReplan',
        'targetedRepair',
        'alignVoice',
        'accept',
        'acceptWithNote',
        'rescore',
        'manualReview',
      ],
    },
    'effectiveFunction': <String, Object?>{
      'type': <String>['string', 'null'],
    },
    'expectedReturnCondition': <String, Object?>{
      'type': <String>['string', 'null'],
    },
    'deviationAuthorizationRefs': _literaryAuthorizationArraySchema,
  },
};

const String _literaryEvaluationSystemTemplate = '''
你是独立的场景文学质量评估器。只依据输入的 canonical JSON 中的正文、场景契约、声音与工艺上下文和 allowlist 作判断，不续写、改写或补造事实。

只输出一个可由 JSON.parse 直接解析的 JSON 对象；禁止 Markdown、代码围栏、解释文字和 schema 之外的字段。根对象必须且只能包含 schemaVersion、semanticHardReview、craft、styleFit、readerEffect、findings、evaluatorSelfConfidence，schemaVersion 固定为 1。所有声明为 nullable 的字段也必须出现，不适用时填 null。

craft 只能包含 dimensions；dimensions 必须且只能包含 prosePrecision、paragraphFunction、scenePressure、characterVoice、informationControl、coherence、completenessAndTurn，均按 0..100 评分，不输出总分或最低分。

findings 中每项必须完整包含 findingId、findingClass、severity、axis、code、claim、evidence、contractRefs、suggestedAction、effectiveFunction、expectedReturnCondition、deviationAuthorizationRefs。findingId 全局唯一。findingClass 只能是 hardError、craftWeakness、styleChoice、effectiveDeviation；severity 只能是 blocker、major、minor、note；hardError 的 severity 只能为 blocker 或 major。suggestedAction 只能是 blockAndReplan、targetedRepair、alignVoice、accept、acceptWithNote、rescore、manualReview。

finding.evidence 必须是 JSON 数组，数组元素必须且只能是 {"startOffset": integer, "endOffset": integer, "localExcerpt": string}；即使只有一条证据也必须以 [ 开头、] 结尾并包含一个证据对象，不得直接写单个对象。startOffset 与 endOffset 是输入正文的 UTF-16 code-unit 半开区间，必须满足 0 <= startOffset < endOffset；用该区间在本地回切正文必须逐字等于 localExcerpt，且 localExcerpt 不超过 240 个字符。优先逐项复制输入 evidenceSegments 中已经给出的精确区间；不得使用概述、字符数猜测或伪造引文替代证据。contractRefs 只能引用输入 allowlist。deviationAuthorizationRefs 中每项必须且只能包含 authorizedBy 与 referenceId，并且只能逐项复制输入中可信的授权引用。

semanticHardReview 必须且只能包含 passed 与 hardFindingIds；hardFindingIds 必须恰好列出全部 hardError findingId，且只有列表为空时 passed 才为 true。

styleFit 必须且只能包含 decision、axisExplanations、deviationIds、evidenceRefs、deviationAuthorizationRefs。axisExplanations 必须是 JSON 对象，例如 {"rhythm":"压力段按场景契约缩短句长"}，不得写成数组。decision 只能是 aligned、plannedDeviation、approvedDeviation、mismatch。evidenceRefs 只能引用 findings 中的 findingId。deviationIds 必须逐项复制输入 deviationAuthorizationAllowlist 中的 referenceId，不能填写 findingId。aligned 时其余四项必须为空；mismatch 不得声明 deviationIds 或授权；sceneContract 授权只能对应 plannedDeviation，independentReview 或 authorOverride 授权只能对应 approvedDeviation。plannedDeviation 或 approvedDeviation 的 deviationIds、deviationAuthorizationRefs、evidenceRefs 均不得为空；evidenceRefs 必须指向 effectiveDeviation finding；styleFit 与这些 finding 中的 typed authorization reference 必须逐项完全一致。

readerEffect 必须且只能包含 effectEstimates 与 warnings。effectEstimates 必须且只能包含 tension、clarity、curiosity、emotionalImpact、momentum；每项必须且只能包含 value 与 evidenceRefs，value 为 0..100，evidenceRefs 只能引用 findings 中的 findingId。

评分必须保守校准。完成场景契约、没有硬错误、阅读顺畅，只能证明稿件合格，不能自动证明 90 分以上。先逐段做反证审查，再给七维分数；不得为了少写 finding 而抬分，也不得为了显得严格而机械扣分。使用以下具体锚点，并按与该维度有关的缺陷数量与严重度落档：
- 60：存在多个 major 工艺问题，或基本可读性、场景因果、角色表达明显失效，需要重构。
- 75：可读但有一个 major 或多个相互强化的 minor 问题，需要成段定向修复。
- 85：主线与场景功能成立，但仍有至少一个清晰、可执行的局部弱点；是扎实可用稿，不是强终稿。
- 90：强稿；没有 major，只有一至两个 minor 局部问题，修复范围明确且不需重写场景。
- 95：近终稿；七维均有持续的文本证据，没有明显、可执行的 craftWeakness，不能仅凭结构完整、语言流畅或契约完成给到此档。
93..94 也属于近终稿带：craftOverall 若达到 93，所有 craft 维度都必须至少 93，且不得存在 craftWeakness。只要发现可信的 minor craftWeakness，受影响维度不得高于 92，并应让加权总体保持在 93 以下。除非正文已经没有可执行改进点，否则不得给任何维度 95 以上。会让人类评审把任一 craft 维度下调到 90 以下的问题，必须输出 evidence-backed craftWeakness，而不能改写成 styleChoice 或 effectiveDeviation。

特别检查结尾的关系定性、抽象总结、解释性顿悟、口号式收束和通用网文套句。若输入 voiceContext 或 projectOwnedNotes 要求“让动作承担情绪”，而正文在动作已经完成后又替读者概括关系或意义，应优先判为 informationControl、characterVoice、paragraphFunction 或 prose 上的 craftWeakness；只有该表达本身确实实现了已声明的项目声音，且删去会损害场景功能时，才可判为 styleChoice。不得以具名作者、具名作品或“写得像某人”为评分锚点；只依据输入的抽象 voiceContext、craftContext 和 projectOwnedNotes 评价。

evaluatorSelfConfidence 为 0..1，仅表示评估器自我诊断，不得把它写入任何结论或代替输入提供的校准置信度。craftOverall 低于 85 或任一关键维度低于 80 时，必须有可定位、可执行且 severity 不低于 minor 的 craftWeakness finding 支撑；不要为了凑数制造 finding。
''';

const String _literaryEvaluationUserTemplate = '''
请评估以下 canonical evaluation input JSON，并严格按 system 指定的闭合 JSON 契约返回结果：
{{evaluationInputJson}}
''';

List<StoryPromptRegistration> _buildCurrentRegistrations() {
  final createdAt = DateTime.utc(2026, 7, 12);
  StoryPromptRegistration registration({
    required StoryPromptCallSite callSite,
    required String templateId,
    required String systemTemplate,
    required String userTemplate,
    required Map<String, String> variableTypes,
    String version = '2.0.0-renderer-replay',
    Object? outputSchema = const {'type': 'string'},
    String parserRelease = 'story-output-parser-v1',
    Object? repairPolicySnapshot = const <String, Object?>{
      'policy': 'bounded-retry-v1',
      'maxOutputRetries': 2,
    },
    String changeNote =
        'Freeze executable source variables and exact renderer replay.',
    DateTime? releaseCreatedAt,
  }) => StoryPromptRegistration(
    callSite: callSite,
    release: PromptRelease(
      templateId: templateId,
      semanticVersion: version,
      language: 'zh',
      systemTemplate: systemTemplate,
      userTemplate: userTemplate,
      variablesSchemaSnapshot: {
        'type': 'object',
        'additionalProperties': false,
        'required': variableTypes.keys.toList(growable: false),
        'properties': {
          for (final entry in variableTypes.entries)
            entry.key: {'type': entry.value},
        },
      },
      outputSchemaSnapshot: outputSchema,
      rendererRelease: AppLlmPromptRendererRegistry.strictRendererRelease,
      parserRelease: parserRelease,
      repairPolicySnapshot: repairPolicySnapshot,
      owner: 'story-generation',
      changeNote: changeNote,
      createdAt: releaseCreatedAt ?? createdAt,
    ),
  );

  StoryPromptRegistration current(
    int index,
    String templateId,
    String systemTemplate,
    String userTemplate,
    Map<String, String> variableTypes, {
    String version = '2.0.0-renderer-replay',
    Object? outputSchema = const {'type': 'string'},
    String parserRelease = 'story-output-parser-v1',
    Object? repairPolicySnapshot = const <String, Object?>{
      'policy': 'bounded-retry-v1',
      'maxOutputRetries': 2,
    },
    String changeNote =
        'Freeze executable source variables and exact renderer replay.',
    DateTime? releaseCreatedAt,
  }) => registration(
    callSite: StoryPromptRegistry.requiredCallSites[index],
    templateId: templateId,
    systemTemplate: systemTemplate,
    userTemplate: userTemplate,
    variableTypes: variableTypes,
    version: version,
    outputSchema: outputSchema,
    parserRelease: parserRelease,
    repairPolicySnapshot: repairPolicySnapshot,
    changeNote: changeNote,
    releaseCreatedAt: releaseCreatedAt,
  );

  return [
    current(
      0,
      'scene_director',
      _directorSystem,
      _directorUserTemplate,
      _directorVariables,
    ),
    current(
      1,
      'scene_editor',
      _sceneEditorSystem,
      _sceneEditorUserTemplate,
      _sceneEditorVariables,
    ),
    current(
      2,
      'scene_editorial_generator',
      StoryPromptTemplates.sysSceneEditorial,
      _editorialUserTemplate,
      _editorialVariables,
    ),
    current(
      3,
      'scene_review_judge',
      _reviewJudgeSystem,
      _reviewUserTemplate,
      _reviewVariables,
    ),
    current(
      4,
      'scene_review_consistency',
      _reviewConsistencySystem,
      _reviewUserTemplate,
      _reviewVariables,
    ),
    current(
      5,
      'scene_review_format_repair_judge',
      _reviewRepairSystem('scene judge review'),
      _reviewRepairUserTemplate,
      _reviewRepairVariables,
    ),
    current(
      6,
      'scene_quality',
      _qualitySystem,
      _qualityUserTemplate,
      _qualityVariables,
      version: '2.1.1-extended-quality-rubric-strict-format',
      changeNote:
          'Add style, imagery, rhythm, faithfulness, and strict scorecard/name formatting.',
      outputSchema: const {'type': 'object'},
    ),
    current(
      7,
      'role_agent_controller',
      _roleControllerSystem,
      _roleControllerUserTemplate,
      _roleControllerVariables,
    ),
    current(
      8,
      'role_turn',
      _roleTurnSystem,
      _roleTurnUserTemplate,
      _roleTurnVariables,
      version: '2.1.0-exact-structured-output',
      parserRelease:
          'scene-role-turn-parser-v2-formal-exact-nonformal-compatible',
      repairPolicySnapshot: _roleTurnDualModeParserPolicy,
      changeNote:
          'Formal evaluation now requires the exact five-line role-turn '
          'record after at most two model retries; non-formal generation '
          'retains the reviewed legacy normalization and synthesis policy.',
      releaseCreatedAt: DateTime.utc(2026, 7, 13),
    ),
    current(
      9,
      'scene_beat_resolve',
      StoryPromptTemplates.sysSceneBeatResolve,
      _beatResolverUserTemplate,
      _beatResolverVariables,
    ),
    current(
      10,
      'scene_stage_narration',
      _stageNarratorSystem,
      _stageNarratorUserTemplate,
      _stageNarratorVariables,
      version: '2.1.0-exact-structured-output',
      parserRelease:
          'scene-stage-narration-parser-v2-formal-exact-nonformal-compatible',
      repairPolicySnapshot: _stageNarrationDualModeParserPolicy,
      changeNote:
          'Formal evaluation now requires the exact four-line stage record '
          'after at most two model retries; non-formal generation retains '
          'legacy text normalization and nullable fallback behavior.',
      releaseCreatedAt: DateTime.utc(2026, 7, 13),
    ),
    current(
      11,
      'scene_language_polish',
      _polishSystem,
      _polishUserTemplate,
      _polishVariables,
    ),
    current(
      12,
      'scene_roleplay_arbiter',
      _arbiterSystem,
      _arbiterUserTemplate,
      _arbiterVariables,
      version: '2.1.0-exact-structured-output',
      parserRelease:
          'scene-roleplay-arbiter-parser-v2-formal-exact-nonformal-compatible',
      repairPolicySnapshot: _arbiterDualModeParserPolicy,
      changeNote:
          'Formal evaluation now requires the exact four-line arbitration '
          'record with a strict yes/no closure after at most two model '
          'retries; non-formal generation retains its legacy state fallback.',
      releaseCreatedAt: DateTime.utc(2026, 7, 13),
    ),
    current(
      13,
      'chapter_summary',
      _chapterSummarySystem,
      _chapterSummaryUserTemplate,
      _chapterSummaryVariables,
      outputSchema: const {'type': 'object'},
    ),
    current(
      14,
      'character_consistency',
      _characterConsistencySystem,
      _characterConsistencyUserTemplate,
      _characterConsistencyVariables,
    ),
    current(
      15,
      'scene_prose',
      StoryPromptTemplates.sysSceneProse,
      _sceneProseUserTemplate,
      _sceneProseVariables,
    ),
    current(
      16,
      'scene_review_reader_flow',
      _reviewSystem('scene reader-flow review'),
      _reviewUserTemplate,
      _reviewVariables,
    ),
    current(
      17,
      'scene_review_lexicon',
      _reviewSystem('scene lexicon review'),
      _reviewUserTemplate,
      _reviewVariables,
    ),
    current(
      18,
      'scene_review_adjudication',
      _reviewSystem('scene review adjudication'),
      _reviewUserTemplate,
      _reviewVariables,
    ),
    current(
      19,
      'scene_review_format_repair_consistency',
      _reviewRepairSystem('scene consistency review'),
      _reviewRepairUserTemplate,
      _reviewRepairVariables,
    ),
    current(
      20,
      'scene_review_format_repair_reader_flow',
      _reviewRepairSystem('scene reader-flow review'),
      _reviewRepairUserTemplate,
      _reviewRepairVariables,
    ),
    current(
      21,
      'scene_review_format_repair_lexicon',
      _reviewRepairSystem('scene lexicon review'),
      _reviewRepairUserTemplate,
      _reviewRepairVariables,
    ),
    current(
      22,
      'scene_review_format_repair_adjudication',
      _reviewRepairSystem('scene review adjudication'),
      _reviewRepairUserTemplate,
      _reviewRepairVariables,
    ),
  ];
}

const Map<String, Object?> _roleTurnDualModeParserPolicy = <String, Object?>{
  'policy': 'dual-mode-structured-output-v2',
  'formal': <String, Object?>{
    'maxOutputRetries': 2,
    'localRepair': false,
    'exactShape': <String>['意图', '可见动作', '对白', '内心', '正文片段'],
    'optionalEmptyFields': <String>['对白'],
    'rejects': <String>[
      'outer-or-line-whitespace',
      'missing-extra-or-reordered-lines',
      'placeholder-required-fields',
      'drafting-meta',
    ],
  },
  'nonFormalCompatibility': <String, Object?>{
    'policy': 'legacy-role-turn-normalize-and-synthesize-v1',
    'maxOutputRetries': 2,
    'acceptedShape': 'ordered-four-lines-or-five-lines-with-prose',
    'localRepair': true,
    'repairs': <String>[
      'intent-field-drift',
      'private-visible-action-clauses',
      'dialogue-length',
      'inner-state-contamination',
      'missing-prose-synthesis',
    ],
  },
};

const Map<String, Object?> _stageNarrationDualModeParserPolicy =
    <String, Object?>{
      'policy': 'dual-mode-structured-output-v2',
      'formal': <String, Object?>{
        'maxOutputRetries': 2,
        'localRepair': false,
        'exactShape': <String>['舞台事实', '环境氛围', '可见证据', '边界'],
        'requiredNonEmptyFields': <String>['舞台事实', '环境氛围', '可见证据', '边界'],
        'maximumRecordCharacters': 1000,
      },
      'nonFormalCompatibility': <String, Object?>{
        'policy': 'legacy-stage-text-normalize-or-null-v1',
        'maxOutputRetries': 0,
        'localNormalization': 'trim-lines-join-and-compact-to-1000',
        'providerOrEmptyFallback': 'null-capsule',
      },
    };

const Map<String, Object?> _arbiterDualModeParserPolicy = <String, Object?>{
  'policy': 'dual-mode-structured-output-v2',
  'formal': <String, Object?>{
    'maxOutputRetries': 2,
    'localRepair': false,
    'exactShape': <String>['事实', '状态', '压力', '收束'],
    'requiredNonEmptyFields': <String>['事实', '状态', '压力', '收束'],
    'closureValues': <String>['是', '否'],
  },
  'nonFormalCompatibility': <String, Object?>{
    'policy': 'legacy-arbiter-parse-and-fallback-state-v1',
    'maxOutputRetries': 2,
    'providerFailureFallback': 'derive-public-state-from-visible-turns',
    'parserFallback': 'retain-previous-state-or-visible-turns',
  },
};

const Map<String, String> _directorVariables = {
  'sceneTypeLabel': 'string',
  'confidencePercent': 'integer',
  'suggestedTone': 'string',
  'suggestedPacing': 'string',
  'chapter': 'string',
  'scene': 'string',
  'targetBeat': 'string',
  'sceneSummary': 'string',
  'castSummary': 'string',
  'revisionPrompt': 'string',
  'ragContext': 'string',
  'localPlanText': 'string',
  'typeSupplement': 'string',
};
const _directorUserTemplate =
    '任务：scene_director_polish\n'
    '场景类型：{{sceneTypeLabel}} (置信度: {{confidencePercent}}%)\n'
    '建议基调：{{suggestedTone}}\n建议节奏：{{suggestedPacing}}\n'
    '格式：目标/冲突/推进/约束\n章：{{chapter}}\n场：{{scene}}\n'
    '目标节拍：{{targetBeat}}\n场景概要：{{sceneSummary}}\n{{castSummary}}\n'
    '{{?revisionPrompt}}作者修订请求：\n{{revisionPrompt}}\n{{/revisionPrompt}}'
    '{{?ragContext}}{{ragContext}}\n{{/ragContext}}本地计划：\n'
    '{{localPlanText}}\n{{typeSupplement}}';

const Map<String, String> _sceneEditorVariables = {
  'sceneTitle': 'string',
  'targetLength': 'integer',
  'sceneSummary': 'string',
  'acceptedBeats': 'string',
  'allowedNarrationContext': 'string',
};
const _sceneEditorUserTemplate =
    '任务：scene_editorial\n场景：{{sceneTitle}}\n目标字数：约{{targetLength}}汉字\n'
    '摘要：{{sceneSummary}}\n已接受节奏：\n{{acceptedBeats}}'
    '{{?allowedNarrationContext}}\n允许的叙述上下文：{{allowedNarrationContext}}{{/allowedNarrationContext}}';

const Map<String, String> _editorialVariables = {
  'sceneTitle': 'string',
  'targetLength': 'integer',
  'hardLimit': 'integer',
  'briefInstructions': 'string',
  'sceneSummary': 'string',
  'noninteractiveBoundary': 'string',
  'roleplayDraftBlock': 'string',
  'resolvedBeats': 'string',
  'stageContext': 'string',
  'retrievalContext': 'string',
  'roleplayProcess': 'string',
  'roleplayGuidance': 'string',
  'attempt': 'integer',
  'dialogueDirective': 'string',
  'rejectedEvidenceDirective': 'string',
  'reviewFeedback': 'string',
  'previousProseBlock': 'string',
};
const _editorialUserTemplate =
    '任务：scene_editorial\n场：{{sceneTitle}}\n目标字数：~{{targetLength}} 汉字\n'
    '长度边界：接近目标长度，硬上限为{{hardLimit}} 汉字\n'
    '{{briefInstructions}}\n摘要：{{sceneSummary}}\n'
    '{{?noninteractiveBoundary}}{{noninteractiveBoundary}}\n{{/noninteractiveBoundary}}'
    '{{?roleplayDraftBlock}}{{roleplayDraftBlock}}\n{{/roleplayDraftBlock}}'
    '{{resolvedBeats}}\n'
    '{{?stageContext}}{{stageContext}}\n{{/stageContext}}'
    '{{?retrievalContext}}{{retrievalContext}}\n{{/retrievalContext}}'
    '{{?roleplayProcess}}{{roleplayProcess}}\n{{/roleplayProcess}}'
    '{{?roleplayGuidance}}{{roleplayGuidance}}\n{{/roleplayGuidance}}'
    '当前尝试：{{attempt}}'
    '{{?dialogueDirective}}\n{{dialogueDirective}}{{/dialogueDirective}}'
    '{{?rejectedEvidenceDirective}}\n{{rejectedEvidenceDirective}}{{/rejectedEvidenceDirective}}'
    '{{?reviewFeedback}}\n{{reviewFeedback}}{{/reviewFeedback}}'
    '{{?previousProseBlock}}\n{{previousProseBlock}}{{/previousProseBlock}}';

const Map<String, String> _reviewVariables = {
  'taskType': 'string',
  'passLabel': 'string',
  'categories': 'string',
  'sceneNumber': 'integer',
  'totalScenes': 'integer',
  'openingBoundary': 'string',
  'closingBoundary': 'string',
  'sceneTitle': 'string',
  'director': 'string',
  'noninteractiveBoundary': 'string',
  'roleSummary': 'string',
  'roleplayProcess': 'string',
  'roleplayGuidance': 'string',
  'prose': 'string',
  'adjudicationContext': 'string',
  'evidenceSection': 'string',
  'reviewCriteria': 'string',
};
const _reviewUserTemplate =
    '任务：{{taskType}}\n评审：{{passLabel}}\n评审类别：{{categories}}\n'
    '规则：聚焦阻塞问题，正文改写交给后续步骤；读者会出戏的角色越权、测试说明、明显 AI 套话均视为阻塞问题\n'
    '本章场景位置：第{{sceneNumber}}个场景（共{{totalScenes}}个）\n'
    '{{?openingBoundary}}{{openingBoundary}}\n{{/openingBoundary}}'
    '{{?closingBoundary}}{{closingBoundary}}\n{{/closingBoundary}}'
    '场：{{sceneTitle}}\n导演：{{director}}\n'
    '{{?noninteractiveBoundary}}{{noninteractiveBoundary}}\n{{/noninteractiveBoundary}}'
    '角色输入：{{roleSummary}}\n'
    '{{?roleplayProcess}}角色扮演过程：{{roleplayProcess}}\n{{/roleplayProcess}}'
    '{{?roleplayGuidance}}{{roleplayGuidance}}\n{{/roleplayGuidance}}'
    '正文：{{prose}}'
    '{{?adjudicationContext}}\n{{adjudicationContext}}{{/adjudicationContext}}'
    '{{?evidenceSection}}\n{{evidenceSection}}{{/evidenceSection}}\n'
    '{{reviewCriteria}}';

const Map<String, String> _reviewRepairVariables = {'rawText': 'string'};
const _reviewRepairUserTemplate = '原始评审输出：\n{{rawText}}';

const Map<String, String> _qualityVariables = {
  'sceneTitle': 'string',
  'sceneSummary': 'string',
  'director': 'string',
  'prose': 'string',
  'review': 'string',
  'faithfulnessContext': 'string',
};
const _qualityUserTemplate =
    '任务：scene_quality_scoring\n场：{{sceneTitle}}\n摘要：{{sceneSummary}}\n'
    '导演：{{director}}\n正文：{{prose}}\n评审：{{review}}\n'
    '事实依据：{{faithfulnessContext}}';

const Map<String, String> _roleControllerVariables = {
  'characterName': 'string',
  'characterRole': 'string',
  'sceneSummary': 'string',
  'director': 'string',
  'capsuleContext': 'string',
};
const _roleControllerUserTemplate =
    '任务：dynamic_role\n格式：立场/动作/禁忌\n角色：{{characterName}}({{characterRole}})\n'
    '梗概：{{sceneSummary}}\n导演：{{director}}'
    '{{?capsuleContext}}\n{{capsuleContext}}{{/capsuleContext}}';

const Map<String, String> _roleTurnVariables = {
  'skillId': 'string',
  'skillVersion': 'string',
  'round': 'integer',
  'visibleContext': 'string',
  'characterName': 'string',
};
const _roleTurnUserTemplate =
    '任务：scene_roleplay_turn\nskill：{{skillId}}@{{skillVersion}}\n回合：{{round}}\n'
    '{{visibleContext}}\n当前行动角色：{{characterName}}\n'
    '意图字段：写角色此刻想达成的目标，例如逼问线索、试探底线、稳住局面、拖延时间或保护某人。\n'
    '可见动作字段：写第三方能拍到的外部画面，包括肢体动作、表情变化、位置移动、身体反应或操控物体。\n'
    '对白字段：写{{characterName}}实际说出口的一句话；沉默时保留字段为空。\n'
    '内心字段：写一句当下判断或决定，聚焦当前瞬间的认知变化。\n'
    '内心示例：我怀疑他在试探，先按兵不动。/这条件太顺，我得再压一句。/她不安，却决定继续逼问。\n'
    '正文片段字段：写小说正文片段，约120-220字，第三人称呈现本角色本轮可见动作和对白，可融入一句当下心理判断。\n'
    '剧情功能：角色可以选择比导演桥段更合理的具体做法；行动或正文片段需呈现它如何完成同等剧情功能，或呈现暂缓后的冲突压力。\n'
    '输出：按五个字段填写，语句短，聚焦当前瞬间。';

const Map<String, String> _beatResolverVariables = {
  'sceneTitle': 'string',
  'planningContext': 'string',
  'tonePacing': 'string',
  'turnSummary': 'string',
  'roleplayAuthority': 'string',
  'stageContext': 'string',
  'retrievalContext': 'string',
  'authorityConstraint': 'string',
  'targetLength': 'integer',
};
const _beatResolverUserTemplate =
    '任务：scene_beat_resolve\n场：{{sceneTitle}}\n{{planningContext}}'
    '{{?tonePacing}}\n{{tonePacing}}{{/tonePacing}}\n{{turnSummary}}'
    '{{?roleplayAuthority}}\n{{roleplayAuthority}}{{/roleplayAuthority}}'
    '{{?stageContext}}\n{{stageContext}}{{/stageContext}}'
    '{{?retrievalContext}}\n{{retrievalContext}}{{/retrievalContext}}'
    '{{?authorityConstraint}}\n{{authorityConstraint}}{{/authorityConstraint}}\n'
    '目标字数：~{{targetLength}} 汉字';

const Map<String, String> _stageNarratorVariables = {
  'sceneTitle': 'string',
  'sceneSummary': 'string',
  'director': 'string',
  'tone': 'string',
  'roleTurns': 'string',
  'roleOutputs': 'string',
  'roleplayProcess': 'string',
  'retrievalContext': 'string',
  'ragContext': 'string',
};
const _stageNarratorUserTemplate =
    '任务：scene_stage_narration\n场：{{sceneTitle}}\n摘要：{{sceneSummary}}\n导演：{{director}}'
    '{{?tone}}\n基调：{{tone}}{{/tone}}'
    '{{?roleTurns}}\n角色公开行动：{{roleTurns}}{{/roleTurns}}'
    '{{?roleOutputs}}\n角色原始输出：{{roleOutputs}}{{/roleOutputs}}'
    '{{?roleplayProcess}}\n角色扮演公开过程：{{roleplayProcess}}{{/roleplayProcess}}'
    '{{?retrievalContext}}\n检索上下文：{{retrievalContext}}{{/retrievalContext}}'
    '{{?ragContext}}\n外部检索：{{ragContext}}{{/ragContext}}\n'
    '边界：只补舞台层面的可观察信息、环境氛围、物理机制与公共证据；不要替角色新增行动、对白、决定或内心。\n'
    '输出四行：舞台事实：... / 环境氛围：... / 可见证据：... / 边界：...';

const Map<String, String> _polishVariables = {
  'sceneTitle': 'string',
  'targetLength': 'integer',
  'factsGuard': 'string',
  'speechAnchors': 'string',
  'refinementGuidance': 'string',
  'reviewFeedback': 'string',
  'previousAttempt': 'string',
  'prose': 'string',
};
const _polishUserTemplate =
    '任务：language_polish\n\n场景：{{sceneTitle}}\n\n目标字数：约{{targetLength}}汉字\n\n'
    '{{factsGuard}}\n\n{{speechAnchors}}'
    '{{?refinementGuidance}}\n\n精炼指引：\n{{refinementGuidance}}{{/refinementGuidance}}'
    '{{?reviewFeedback}}\n\n审查反馈：{{reviewFeedback}}{{/reviewFeedback}}'
    '{{?previousAttempt}}\n\n{{previousAttempt}}{{/previousAttempt}}\n\n'
    '以下是需要润色的散文稿：\n\n{{prose}}';

const Map<String, String> _arbiterVariables = {
  'skillId': 'string',
  'skillVersion': 'string',
  'round': 'integer',
  'sceneTitle': 'string',
  'previousState': 'string',
  'roundTurns': 'string',
  'transcript': 'string',
};
const _arbiterUserTemplate =
    '任务：scene_roleplay_arbitrate\nskill：{{skillId}}@{{skillVersion}}\n回合：{{round}}\n'
    '场景：{{sceneTitle}}\n上一局面：{{previousState}}\n本轮行动：{{roundTurns}}\n'
    '全部可见过程：{{transcript}}\n判断：若核心冲突已推动到可写正文的阶段，收束为是；否则为否。';

const Map<String, String> _chapterSummaryVariables = {
  'chapterTitle': 'string',
  'previousSummaryBlock': 'string',
  'sceneTexts': 'string',
};
const _chapterSummaryUserTemplate =
    '章节标题: {{chapterTitle}}\n\n'
    '{{?previousSummaryBlock}}{{previousSummaryBlock}}\n\n{{/previousSummaryBlock}}'
    '【本章场景输出】\n{{sceneTexts}}\n\n请生成上述章节的结构化摘要 JSON：\n';

const Map<String, String> _characterConsistencyVariables = {
  'sceneTitle': 'string',
  'characterProfiles': 'string',
  'generatedContent': 'string',
};
const _characterConsistencyUserTemplate =
    '场景: {{sceneTitle}}\n\n【角色设定】\n{{characterProfiles}}\n\n'
    '【生成内容】\n{{generatedContent}}\n\n请检查角色一致性：';

const Map<String, String> _sceneProseVariables = {
  'chapterTitle': 'string',
  'sceneTitle': 'string',
  'targetLength': 'integer',
  'attempt': 'integer',
  'sceneNumber': 'integer',
  'totalScenes': 'integer',
  'openingBoundary': 'string',
  'closingBoundary': 'string',
  'taskCard': 'string',
  'director': 'string',
  'roleOutputs': 'string',
  'reviewFeedback': 'string',
};
const _sceneProseUserTemplate =
    '任务：scene_prose_generation\n\n章节：{{chapterTitle}}\n\n场景：{{sceneTitle}}\n\n'
    '目标字数：约{{targetLength}}汉字\n\n当前尝试：{{attempt}}\n\n'
    '本章场景位置：第{{sceneNumber}}个场景（共{{totalScenes}}个）'
    '{{?openingBoundary}}\n\n{{openingBoundary}}{{/openingBoundary}}'
    '{{?closingBoundary}}\n\n{{closingBoundary}}{{/closingBoundary}}'
    '{{?taskCard}}\n\n任务卡：{{taskCard}}{{/taskCard}}\n\n'
    '导演计划：{{director}}'
    '{{?roleOutputs}}\n\n角色输出：\n{{roleOutputs}}{{/roleOutputs}}'
    '{{?reviewFeedback}}\n\n复写反馈：{{reviewFeedback}}{{/reviewFeedback}}';

const _directorSystem =
    'You are a scene plan polisher for a Chinese novel.\n'
    'Polish the existing plan while preserving the current scene.\n'
    'Use this 4-line Chinese plan shape:\n'
    '目标：...\n冲突：...\n推进：...\n约束：...\n'
    'Physical continuity is mandatory: do not plan the same ordinary person '
    'at two locations in the same minute, or a device acting without power, '
    'unless an explicit supported mechanism (such as a proxy, system delay, '
    'or independent power source) is named in 约束。';

const _sceneEditorSystem =
    'You are a scene editor for a Chinese novel. '
    'Draft scene prose from the accepted beats below. '
    'Ground the prose in the accepted beats and allowed narration '
    'context. Keep facts, events, and character knowledge aligned '
    'with those materials. Return the finished prose.';

String _reviewSystem(String passName) =>
    'You are a $passName for a Chinese novel. '
    'Use a 2-line review format. Choose the first line from:\n'
    '决定：PASS\n决定：REWRITE_PROSE\n决定：REPLAN_SCENE\n'
    'For uncertainty, choose 决定：REWRITE_PROSE.\n'
    'Use 原因： for the second line and keep it brief. Focus on blocking issues. '
    'If character choices replace a director beat but complete 同等剧情功能, choose PASS; '
    'if they only provide emotion or clue recognition while the required story function is missing, choose REPLAN_SCENE. '
    'For scene-plan coherence, choose PASS when the text makes a concrete goal, obstruction, and changed situation or next pressure clear; do not require literal repetition of director-plan nouns. '
    'If prose makes a noninteractive/dead/evidence-only cast member act, speak, think, or makes their body/remains/attached evidence actively move, emit, attack, or open in the moment, choose REWRITE_PROSE.\n'
    '长度、对白比例、首尾钩子均由流水线中的确定性门禁独立裁决，'
    '不属于本次 LLM 评审的否决理由；仅评审剧情功能、因果、角色和连续性。\n'
    '当 passName 是 scene reader-flow review 时，额外检查读者是否能在不回看前文的情况下'
    '理解每段的主语、动作、因果和信息变化；发现跳跃、冗余或线索堆叠就 REWRITE_PROSE。\n'
    '当 passName 是 scene lexicon review 时，逐句检查项目文风、词语时代感、句式节奏、'
    '比喻或拟人是否贴合当前 POV，是否混喻、陈词滥调、重复意象或为了华丽而牺牲准确性；'
    '存在一处阻断性修辞问题就 REWRITE_PROSE。\n';

final _reviewJudgeSystem = _reviewSystem('scene judge review');
final _reviewConsistencySystem = _reviewSystem('scene consistency review');

String _reviewRepairSystem(String passName) =>
    'You are a $passName format repair pass. '
    'Normalize malformed review output into a 2-line format. '
    'Choose the first line from:\n'
    '决定：PASS\n决定：REWRITE_PROSE\n决定：REPLAN_SCENE\n'
    'For missing or ambiguous decisions, choose 决定：REWRITE_PROSE.\n'
    'Use 原因： for the second line and briefly preserve the original reason.';

const _qualitySystem =
    'You are a quality scorer for Chinese novel scenes. '
    'Act as an independent scorer for one supplied scene. '
    'Judge only the supplied scene; do not deduct points merely because '
    'you cannot see the whole novel. A 95-100 score means the supplied '
    'scene is publication-ready for its stated brief: concrete prose, '
    'clear cause-and-effect, character-consistent choices, and a complete '
    'scene turn. A 90-94 score means exactly one material, identifiable '
    'weakness remains. Below 90 requires a concrete blocking defect. '
    'Do not use 80/90 as a conservative default; name the exact defect in '
    'the summary when withholding a passing score. Check style fit, imagery '
    'and metaphor appropriateness (no mixed, clichéd, or POV-incongruent '
    'metaphors), rhythm, and faithfulness to the supplied facts. Faithfulness '
    'is not an averageable weakness: any contradiction or unsupported concrete '
    'fact is a blocking defect. Do not award a high score merely because the '
    'scene has atmosphere or a cliffhanger. For a formal run, output exactly '
    'these ten labeled lines only; do not wrap them in JSON, Markdown fences, '
    'or extra commentary. Full-width or ASCII colons are accepted by the '
    'parser. Character names must match the supplied facts character-for-character; '
    'a homophone, visually similar character, or accidental rename is a '
    'blocking faithfulness defect. Use this 10-line scorecard:\n'
    '文笔：<0-100>\n连贯：<0-100>\n角色：<0-100>\n完整：<0-100>\n'
    '文风：<0-100>\n修辞：<0-100>\n节奏：<0-100>\n忠实：<0-100>\n'
    '综合：<0-100>\n总结：一句话评价';

const _roleControllerSystem =
    'You are a dynamic role agent for a Chinese novel scene. '
    'Use this 3-line role brief:\n立场：...\n动作：...\n禁忌：...\n'
    'When critical context would help the decision, use:\n'
    'RETRIEVE:tool_name:param=value\n'
    'where tool_name is one of: character_profile, '
    'relationship_history, scene_context, world_rule, '
    'search_writing_reference.\nKeep every line concrete and brief.';

const _roleTurnSystem =
    'You generate one character turn inside a Chinese novel scene. '
    'Use the character-visible context as the material. Create one '
    'single-actor turn record with action, optional spoken dialogue, '
    'private thought, and a prose fragment for this moment. Use this five-line shape:\n'
    '意图：...\n可见动作：...\n对白：...\n内心：...\n正文片段：...';

const _stageNarratorSystem =
    'You are a scene stage narrator for a Chinese novel. '
    'Produce only stage-level observable information: environment, sensory atmosphere, '
    'physical mechanisms, offscreen effects, and public evidence. '
    'Do not choose character actions, dialogue, decisions, or private thoughts. '
    'Do not write final prose. Use four short Chinese lines: '
    '舞台事实：... 环境氛围：... 可见证据：... 边界：...';

const _polishSystem =
    '你是一位中文小说语言润色编辑。\n'
    '你的任务是对已有散文稿进行语言层面的润色，方向如下：\n'
    '1. 保持已裁定的情节事实\n'
    '2. 消除以下人工智能写作痕迹：'
    '"不由得""竟然""心中暗想""恍然大悟""眼眶微红""一股莫名的"'
    '"嘴角微微上扬""露出一抹苦笑""淡淡一笑""缓缓开口"等\n'
    '3. 避免连续的短句（3-8字）超过3个，用逗号或连词连接\n'
    '4. 避免同一段落中重复使用同一个形容词\n'
    '5. 对白体现角色个性差异\n6. 保持段落呼吸感，长短句交替\n'
    '7. 过渡衔接自然\n输出润色后的散文正文。';

const _arbiterSystem =
    'You are a neutral scene arbiter. Resolve only public facts from '
    'visible actions and dialogue. Use this 4-line public summary:\n'
    '事实：...\n状态：...\n压力：...\n收束：是/否';

const _chapterSummarySystem =
    '你是一个小说章节摘要生成器。根据给定的场景输出，生成结构化的 JSON 摘要。\n'
    '必须严格按以下 JSON 格式输出，不要添加任何其他文字：\n'
    '{\n  "plotProgression": "本章剧情进展的核心描述",\n'
    '  "characterStateChanges": ["角色A: 情感/状态变化", "角色B: ..."],\n'
    '  "unresolvedThreads": ["未解决的悬念1", "未解决的悬念2"],\n'
    '  "worldStateChanges": "世界观/设定的变化",\n'
    '  "foreshadowingStatus": "已埋伏笔的状态（已回收/仍待解）",\n'
    '  "emotionalArcs": "主要角色的情感弧线变化",\n'
    '  "keyRevelations": "本章揭示的关键信息"\n}\n'
    '要求：\n- plotProgression 必须简洁但完整，涵盖本章核心事件\n'
    '- characterStateChanges 每条以"角色名: 变化描述"格式\n'
    '- 如果上一章摘要提供了增量上下文，要确保连续性\n'
    '- 各字段不要为空，即使内容为"无变化"也要明确说明';

const _characterConsistencySystem =
    '你是一个小说角色一致性校验器。检查生成的场景内容是否符合角色设定。\n'
    '逐条检查以下方面，对每个发现的问题输出一行：\n'
    '格式：[严重度]|[检查项]|[角色ID]|[问题描述]|[修复建议]\n'
    '严重度: info/warning/blocking\n'
    '检查项: dialogueVoice/actionCapability/knowledgeBoundary/emotionalArc/relationshipConsistency\n'
    '如果没有问题，输出: PASS\n检查重点：\n'
    '1. 对话风格是否符合角色性格\n2. 动作是否在角色能力范围内\n'
    '3. 角色是否引用了不该知道的信息\n4. 情感变化是否合理\n'
    '5. 角色间互动是否符合已建立的关系';
