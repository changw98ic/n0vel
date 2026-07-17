import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/data/evaluation/agent_evaluation_trace_context.dart';
import 'package:novel_writer/features/story_generation/data/polish_canon_verifier.dart';
import 'package:novel_writer/features/story_generation/data/scene_hard_gates.dart';
import 'package:novel_writer/features/story_generation/data/story_mechanics_verifier.dart';
import 'package:novel_writer/features/story_generation/domain/scene_models.dart';

import 'test_support/agent_evaluation_production_protocol_client.dart';

void main() {
  test(
    'purpose-built prose is stable per trial and independent across trials',
    () {
      String proseFor(String slot) => AgentEvaluationTraceContext.run(
        _traceContext(slot),
        purposeBuiltProductionProtocolProse,
      );

      final first = proseFor('purpose-slot-1');
      final firstRepeat = proseFor('purpose-slot-1');
      final second = proseFor('purpose-slot-2');
      final variants = <String>[
        for (var index = 0; index < 60; index += 1)
          proseFor('purpose-matrix-slot-$index'),
      ];

      expect(firstRepeat, first);
      expect(second, isNot(first));
      expect(first, contains('批次'));
      expect(second, contains('批次'));
      expect(variants.toSet(), hasLength(variants.length));
      for (var index = 0; index < variants.length; index += 1) {
        final violations = sceneHardGateViolations(
          brief: _formalBrief(),
          proseText: variants[index],
        );
        expect(
          violations,
          isEmpty,
          reason:
              'variant $index: '
              '${violations.map((violation) => violation.text).join('\n')}',
        );
      }
    },
  );

  test('purpose-built production prose satisfies every formal hard gate', () {
    final prose = purposeBuiltProductionProtocolProse();
    final brief = _formalBrief();

    final violations = sceneHardGateViolations(brief: brief, proseText: prose);

    expect(
      violations,
      isEmpty,
      reason: violations.map((violation) => violation.text).join('\n'),
    );
    final mechanics = StoryMechanicsVerifier.standard.verify(prose);
    expect(mechanics.passed, isTrue, reason: mechanics.failureCodes.join('\n'));
    final polishCanon = PolishCanonVerifier.standard.verify(
      prePolishProse: prose,
      polishedProse: purposeBuiltProductionProtocolProse(),
      brief: brief,
      materials: const ProjectMaterialSnapshot(),
    );
    expect(
      polishCanon.passed,
      isTrue,
      reason: polishCanon.failureCodes.join('\n'),
    );
  });
}

SceneBrief _formalBrief() => SceneBrief(
  projectId: 'formal-evaluation-project',
  chapterId: 'chapter-1',
  chapterTitle: '第一章',
  sceneId: 'scene-1',
  sceneTitle: '七号仓门后',
  sceneSummary: '林舟取得账本线索，并面对门后伏击。',
  sceneIndex: 0,
  totalScenesInChapter: 1,
  targetLength: 2000,
  cast: <SceneCastCandidate>[
    SceneCastCandidate(characterId: 'linzhou', name: '林舟', role: '调查者'),
  ],
  formalExecution: true,
  metadata: const <String, Object?>{
    'continuityLedger': <Object?>[],
    'requiredOutlineBeats': <Object?>[
      <String, Object?>{
        'id': 'identify-ledger',
        'description': '林舟确认七号仓与被篡改账本有关。',
        'evidenceGroups': <Object?>[
          <String>['林舟'],
          <String>['七号仓'],
          <String>['账本', '原账'],
        ],
      },
      <String, Object?>{
        'id': 'find-access',
        'description': '守门人交代主管与备用钥匙线索。',
        'evidenceGroups': <Object?>[
          <String>['守门人'],
          <String>['码头主管', '贺彬'],
          <String>['备用钥匙'],
        ],
      },
      <String, Object?>{
        'id': 'face-ambush',
        'description': '林舟进入仓库后遭遇仍未解除的威胁。',
        'evidenceGroups': <Object?>[
          <String>['仓库'],
          <String>['枪栓'],
          <String>['真正的账本', '真正账本'],
        ],
      },
    ],
  },
);

AgentEvaluationTraceContext _traceContext(String trialSlotId) =>
    AgentEvaluationTraceContext(
      experimentId: 'purpose-built-prose-experiment',
      executionId: 'purpose-built-prose-execution',
      cellId: 'purpose-built-prose-cell',
      trialSlotId: trialSlotId,
      attemptNo: 1,
      runId: 'run-$trialSlotId',
      leaseEpoch: 1,
      leaseOwner: 'purpose-built-worker',
      isolationTrialId: 'isolation-$trialSlotId',
      generationBundleHash: _digest('a'),
      evaluationBundleHash: _digest('b'),
    );

String _digest(String character) =>
    'sha256:${List<String>.filled(64, character).join()}';
