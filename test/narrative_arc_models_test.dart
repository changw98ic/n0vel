import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/features/story_generation/domain/narrative_arc_models.dart';

void main() {
  group('NarrativeArcPhase', () {
    test('fromString resolves valid names', () {
      expect(
        NarrativeArcPhase.fromString('risingAction'),
        NarrativeArcPhase.risingAction,
      );
      expect(
        NarrativeArcPhase.fromString('climax'),
        NarrativeArcPhase.climax,
      );
      expect(
        NarrativeArcPhase.fromString('resolution'),
        NarrativeArcPhase.resolution,
      );
    });

    test('fromString falls back to setup for unknown values', () {
      expect(NarrativeArcPhase.fromString(null), NarrativeArcPhase.setup);
      expect(NarrativeArcPhase.fromString(''), NarrativeArcPhase.setup);
      expect(NarrativeArcPhase.fromString('unknown'), NarrativeArcPhase.setup);
    });

    test('covers all six phases', () {
      expect(NarrativeArcPhase.values.length, 6);
      expect(
        NarrativeArcPhase.values,
        containsAll([
          NarrativeArcPhase.setup,
          NarrativeArcPhase.risingAction,
          NarrativeArcPhase.midpoint,
          NarrativeArcPhase.fallingAction,
          NarrativeArcPhase.climax,
          NarrativeArcPhase.resolution,
        ]),
      );
    });
  });

  group('PlotPoint', () {
    test('constructs with required fields and defaults', () {
      final pp = PlotPoint(
        id: 'pp-1',
        chapterId: 'ch-1',
        title: '发现密信',
        phase: NarrativeArcPhase.risingAction,
      );
      expect(pp.id, 'pp-1');
      expect(pp.chapterId, 'ch-1');
      expect(pp.title, '发现密信');
      expect(pp.phase, NarrativeArcPhase.risingAction);
      expect(pp.description, '');
      expect(pp.tension, 0.0);
      expect(pp.characterIds, isEmpty);
      expect(pp.precedingPlotPointIds, isEmpty);
    });

    test('clamps tension to 0.0-1.0 on construction', () {
      expect(
        PlotPoint(
          id: 'a',
          chapterId: 'b',
          title: 't',
          phase: NarrativeArcPhase.setup,
          tension: 1.5,
        ).tension,
        1.0,
      );
      expect(
        PlotPoint(
          id: 'a',
          chapterId: 'b',
          title: 't',
          phase: NarrativeArcPhase.setup,
          tension: -0.3,
        ).tension,
        0.0,
      );
    });

    test('serializes and deserializes round-trip', () {
      final original = PlotPoint(
        id: 'pp-2',
        chapterId: 'ch-3',
        title: '码头对峙',
        phase: NarrativeArcPhase.climax,
        description: '柳溪和岳人在旧港仓库正面交锋',
        tension: 0.9,
        characterIds: ['liuxi', 'yueren'],
        precedingPlotPointIds: ['pp-1'],
        metadata: {'intensity': 'high'},
      );
      final restored = PlotPoint.fromJson(original.toJson());
      expect(restored, equals(original));
      expect(restored.characterIds, ['liuxi', 'yueren']);
      expect(restored.precedingPlotPointIds, ['pp-1']);
    });

    test('fromJson handles missing fields', () {
      final restored = PlotPoint.fromJson({});
      expect(restored.id, '');
      expect(restored.chapterId, '');
      expect(restored.title, '');
      expect(restored.phase, NarrativeArcPhase.setup);
      expect(restored.description, '');
      expect(restored.tension, 0.0);
      expect(restored.characterIds, isEmpty);
      expect(restored.precedingPlotPointIds, isEmpty);
    });

    test('fromJson clamps tension from JSON', () {
      final restored = PlotPoint.fromJson({'tension': 2.0});
      expect(restored.tension, 1.0);
      final restoredNeg = PlotPoint.fromJson({'tension': -1.0});
      expect(restoredNeg.tension, 0.0);
    });

    test('copyWith preserves unmodified fields', () {
      final original = PlotPoint(
        id: 'pp-3',
        chapterId: 'ch-1',
        title: 'original',
        phase: NarrativeArcPhase.setup,
        tension: 0.5,
      );
      final copied = original.copyWith(title: 'updated');
      expect(copied.title, 'updated');
      expect(copied.id, 'pp-3');
      expect(copied.chapterId, 'ch-1');
      expect(copied.phase, NarrativeArcPhase.setup);
      expect(copied.tension, 0.5);
    });

    test('equality and hashCode work correctly', () {
      final a = PlotPoint(
        id: 'x',
        chapterId: 'c',
        title: 't',
        phase: NarrativeArcPhase.midpoint,
      );
      final b = PlotPoint(
        id: 'x',
        chapterId: 'c',
        title: 't',
        phase: NarrativeArcPhase.midpoint,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('collections are immutable', () {
      final pp = PlotPoint(
        id: 'pp',
        chapterId: 'ch',
        title: 't',
        phase: NarrativeArcPhase.setup,
        characterIds: ['a'],
        precedingPlotPointIds: ['b'],
        metadata: {'k': 'v'},
      );
      expect(() => pp.characterIds.add('x'), throwsA(isA<UnsupportedError>()));
      expect(
        () => pp.precedingPlotPointIds.add('x'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => pp.metadata['k'] = 'y',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('CharacterArc', () {
    test('constructs with required fields and defaults', () {
      final arc = CharacterArc(
        characterId: 'liuxi',
        startState: '自我封闭',
        endState: '信任他人',
      );
      expect(arc.characterId, 'liuxi');
      expect(arc.startState, '自我封闭');
      expect(arc.endState, '信任他人');
      expect(arc.transformDescription, '');
      expect(arc.plotPointIds, isEmpty);
    });

    test('hasTransform detects state change', () {
      final withTransform = CharacterArc(
        characterId: 'a',
        startState: '冷漠',
        endState: '共情',
      );
      expect(withTransform.hasTransform, isTrue);

      final noTransform = CharacterArc(
        characterId: 'b',
        startState: '稳定',
        endState: '稳定',
      );
      expect(noTransform.hasTransform, isFalse);
    });

    test('serializes and deserializes round-trip', () {
      final original = CharacterArc(
        characterId: 'yueren',
        startState: '忠诚下属',
        endState: '独立抉择者',
        transformDescription: '经历背叛后学会独立判断',
        plotPointIds: ['pp-1', 'pp-3'],
        metadata: {'arcType': 'redemption'},
      );
      final restored = CharacterArc.fromJson(original.toJson());
      expect(restored, equals(original));
      expect(restored.plotPointIds, ['pp-1', 'pp-3']);
      expect(restored.hasTransform, isTrue);
    });

    test('fromJson handles missing fields', () {
      final restored = CharacterArc.fromJson({});
      expect(restored.characterId, '');
      expect(restored.startState, '');
      expect(restored.endState, '');
      expect(restored.transformDescription, '');
      expect(restored.plotPointIds, isEmpty);
    });

    test('copyWith preserves unmodified fields', () {
      final original = CharacterArc(
        characterId: 'liuxi',
        startState: '孤立',
        endState: '开放',
      );
      final copied = original.copyWith(endState: '犹豫');
      expect(copied.endState, '犹豫');
      expect(copied.startState, '孤立');
      expect(copied.characterId, 'liuxi');
    });

    test('equality and hashCode work correctly', () {
      final a = CharacterArc(
        characterId: 'x',
        startState: 'a',
        endState: 'b',
      );
      final b = CharacterArc(
        characterId: 'x',
        startState: 'a',
        endState: 'b',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('plotPointIds are immutable', () {
      final arc = CharacterArc(
        characterId: 'a',
        startState: 'x',
        endState: 'y',
        plotPointIds: ['pp-1'],
      );
      expect(
        () => arc.plotPointIds.add('pp-2'),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('NarrativeTensionPoint', () {
    test('constructs with required fields', () {
      const point = NarrativeTensionPoint(
        chapterId: 'ch-1',
        tension: 0.6,
        label: '码头发现',
      );
      expect(point.chapterId, 'ch-1');
      expect(point.tension, 0.6);
      expect(point.label, '码头发现');
    });

    test('fromJson clamps tension', () {
      final restored = NarrativeTensionPoint.fromJson({'tension': 3.0});
      expect(restored.tension, 1.0);
    });

    test('fromJson handles missing fields', () {
      final restored = NarrativeTensionPoint.fromJson({});
      expect(restored.chapterId, '');
      expect(restored.tension, 0.0);
      expect(restored.label, '');
    });

    test('serializes round-trip', () {
      const original = NarrativeTensionPoint(
        chapterId: 'ch-5',
        tension: 0.85,
        label: '高潮',
      );
      final restored = NarrativeTensionPoint.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('equality works', () {
      const a = NarrativeTensionPoint(chapterId: 'c', tension: 0.5);
      const b = NarrativeTensionPoint(chapterId: 'c', tension: 0.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('NarrativeTensionCurve', () {
    test('empty curve has zero peak and average', () {
      final curve = NarrativeTensionCurve();
      expect(curve.peakTension, 0.0);
      expect(curve.averageTension, 0.0);
      expect(curve.points, isEmpty);
    });

    test('peakTension returns highest tension value', () {
      final curve = NarrativeTensionCurve(points: [
        const NarrativeTensionPoint(chapterId: 'ch-1', tension: 0.3),
        const NarrativeTensionPoint(chapterId: 'ch-2', tension: 0.8),
        const NarrativeTensionPoint(chapterId: 'ch-3', tension: 0.5),
      ]);
      expect(curve.peakTension, 0.8);
    });

    test('averageTension computes mean', () {
      final curve = NarrativeTensionCurve(points: [
        const NarrativeTensionPoint(chapterId: 'ch-1', tension: 0.2),
        const NarrativeTensionPoint(chapterId: 'ch-2', tension: 0.6),
      ]);
      expect(curve.averageTension, closeTo(0.4, 0.001));
    });

    test('pointAtChapter finds matching chapter', () {
      final curve = NarrativeTensionCurve(points: [
        const NarrativeTensionPoint(chapterId: 'ch-1', tension: 0.3),
        const NarrativeTensionPoint(chapterId: 'ch-2', tension: 0.7),
      ]);
      expect(curve.pointAtChapter('ch-2')?.tension, 0.7);
      expect(curve.pointAtChapter('ch-99'), isNull);
    });

    test('serializes round-trip', () {
      final curve = NarrativeTensionCurve(points: [
        const NarrativeTensionPoint(
          chapterId: 'ch-1',
          tension: 0.4,
          label: '铺垫',
        ),
        const NarrativeTensionPoint(
          chapterId: 'ch-3',
          tension: 0.9,
          label: '高潮',
        ),
      ]);
      final restored = NarrativeTensionCurve.fromJson(curve.toJson());
      expect(restored.points.length, 2);
      expect(restored.points.first.chapterId, 'ch-1');
      expect(restored.points.last.tension, 0.9);
    });

    test('fromJson handles empty input', () {
      final restored = NarrativeTensionCurve.fromJson({});
      expect(restored.points, isEmpty);
    });

    test('points are immutable', () {
      final curve = NarrativeTensionCurve(points: [
        const NarrativeTensionPoint(chapterId: 'ch-1', tension: 0.5),
      ]);
      expect(
        () => curve.points.add(
          const NarrativeTensionPoint(chapterId: 'x', tension: 0.0),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('NarrativeArc', () {
    test('constructs with required fields and defaults', () {
      final arc = NarrativeArc(projectId: 'proj-1');
      expect(arc.projectId, 'proj-1');
      expect(arc.id, '');
      expect(arc.title, '');
      expect(arc.theme, '');
      expect(arc.centralConflict, '');
      expect(arc.currentPhase, NarrativeArcPhase.setup);
      expect(arc.plotPoints, isEmpty);
      expect(arc.characterArcs, isEmpty);
      expect(arc.tensionCurve.points, isEmpty);
    });

    test('plotPointsInPhase filters correctly', () {
      final arc = NarrativeArc(
        projectId: 'p1',
        plotPoints: [
          PlotPoint(
            id: 'pp-1',
            chapterId: 'ch-1',
            title: '引入',
            phase: NarrativeArcPhase.setup,
          ),
          PlotPoint(
            id: 'pp-2',
            chapterId: 'ch-2',
            title: '冲突升级',
            phase: NarrativeArcPhase.risingAction,
          ),
          PlotPoint(
            id: 'pp-3',
            chapterId: 'ch-3',
            title: '更多冲突',
            phase: NarrativeArcPhase.risingAction,
          ),
          PlotPoint(
            id: 'pp-4',
            chapterId: 'ch-5',
            title: '决战',
            phase: NarrativeArcPhase.climax,
          ),
        ],
      );
      final rising = arc.plotPointsInPhase(NarrativeArcPhase.risingAction);
      expect(rising.length, 2);
      expect(rising.every((p) => p.phase == NarrativeArcPhase.risingAction), isTrue);

      final setup = arc.plotPointsInPhase(NarrativeArcPhase.setup);
      expect(setup.length, 1);
      expect(setup.first.title, '引入');

      final resolution = arc.plotPointsInPhase(NarrativeArcPhase.resolution);
      expect(resolution, isEmpty);
    });

    test('arcForCharacter finds matching arc', () {
      final arc = NarrativeArc(
        projectId: 'p1',
        characterArcs: [
          CharacterArc(
            characterId: 'liuxi',
            startState: '孤立',
            endState: '信任',
          ),
          CharacterArc(
            characterId: 'yueren',
            startState: '忠诚',
            endState: '独立',
          ),
        ],
      );
      expect(arc.arcForCharacter('liuxi')?.startState, '孤立');
      expect(arc.arcForCharacter('yueren')?.hasTransform, isTrue);
      expect(arc.arcForCharacter('nonexistent'), isNull);
    });

    test('full JSON round-trip preserves all data', () {
      final original = NarrativeArc(
        projectId: 'proj-moon',
        id: 'arc-main',
        title: '月潮之谜',
        theme: '信任与背叛',
        centralConflict: '真相 vs 安全',
        currentPhase: NarrativeArcPhase.risingAction,
        plotPoints: [
          PlotPoint(
            id: 'pp-1',
            chapterId: 'ch-1',
            title: '码头发现',
            phase: NarrativeArcPhase.setup,
            description: '柳溪在旧港发现一封密信',
            tension: 0.2,
            characterIds: ['liuxi'],
          ),
          PlotPoint(
            id: 'pp-2',
            chapterId: 'ch-3',
            title: '仓库对峙',
            phase: NarrativeArcPhase.climax,
            tension: 0.95,
            characterIds: ['liuxi', 'yueren', 'fuxingzhou'],
            precedingPlotPointIds: ['pp-1'],
          ),
        ],
        characterArcs: [
          CharacterArc(
            characterId: 'liuxi',
            startState: '自我封闭',
            endState: '接受合作',
            transformDescription: '学会信任他人',
            plotPointIds: ['pp-1', 'pp-2'],
          ),
        ],
        tensionCurve: NarrativeTensionCurve(points: [
          const NarrativeTensionPoint(chapterId: 'ch-1', tension: 0.2),
          const NarrativeTensionPoint(chapterId: 'ch-3', tension: 0.95),
        ]),
        metadata: {'source': 'outline-v2'},
      );

      final restored = NarrativeArc.fromJson(original.toJson());

      expect(restored.projectId, 'proj-moon');
      expect(restored.id, 'arc-main');
      expect(restored.title, '月潮之谜');
      expect(restored.theme, '信任与背叛');
      expect(restored.centralConflict, '真相 vs 安全');
      expect(restored.currentPhase, NarrativeArcPhase.risingAction);
      expect(restored.plotPoints.length, 2);
      expect(restored.plotPoints.first.title, '码头发现');
      expect(restored.plotPoints.last.tension, 0.95);
      expect(restored.plotPoints.last.characterIds, [
        'liuxi',
        'yueren',
        'fuxingzhou',
      ]);
      expect(restored.characterArcs.length, 1);
      expect(restored.characterArcs.first.hasTransform, isTrue);
      expect(restored.tensionCurve.points.length, 2);
      expect(restored.tensionCurve.peakTension, 0.95);
    });

    test('fromJson handles missing nested collections', () {
      final restored = NarrativeArc.fromJson({'projectId': 'p1'});
      expect(restored.projectId, 'p1');
      expect(restored.plotPoints, isEmpty);
      expect(restored.characterArcs, isEmpty);
      expect(restored.tensionCurve.points, isEmpty);
      expect(restored.currentPhase, NarrativeArcPhase.setup);
    });

    test('fromJson handles completely empty input', () {
      final restored = NarrativeArc.fromJson({});
      expect(restored.projectId, '');
      expect(restored.id, '');
      expect(restored.title, '');
    });

    test('copyWith preserves unmodified fields', () {
      final original = NarrativeArc(
        projectId: 'p1',
        title: '旧标题',
        currentPhase: NarrativeArcPhase.setup,
      );
      final copied = original.copyWith(
        title: '新标题',
        currentPhase: NarrativeArcPhase.climax,
      );
      expect(copied.title, '新标题');
      expect(copied.currentPhase, NarrativeArcPhase.climax);
      expect(copied.projectId, 'p1');
    });

    test('collections are immutable', () {
      final arc = NarrativeArc(
        projectId: 'p1',
        plotPoints: [
          PlotPoint(
            id: 'pp-1',
            chapterId: 'ch-1',
            title: 't',
            phase: NarrativeArcPhase.setup,
          ),
        ],
        characterArcs: [
          CharacterArc(
            characterId: 'a',
            startState: 'x',
            endState: 'y',
          ),
        ],
        metadata: {'key': 'value'},
      );
      expect(
        () => arc.plotPoints.add(
          PlotPoint(
            id: 'x',
            chapterId: 'x',
            title: 'x',
            phase: NarrativeArcPhase.setup,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => arc.characterArcs.add(
          CharacterArc(characterId: 'b', startState: '', endState: ''),
        ),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => arc.metadata['key'] = 'other',
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('Non-functional invariants', () {
    test('tension curve never reports values outside 0.0-1.0', () {
      final curve = NarrativeTensionCurve(points: [
        const NarrativeTensionPoint(chapterId: 'ch-1', tension: 0.0),
        const NarrativeTensionPoint(chapterId: 'ch-2', tension: 0.5),
        const NarrativeTensionPoint(chapterId: 'ch-3', tension: 1.0),
      ]);
      for (final p in curve.points) {
        expect(p.tension, greaterThanOrEqualTo(0.0));
        expect(p.tension, lessThanOrEqualTo(1.0));
      }
      expect(curve.peakTension, greaterThanOrEqualTo(0.0));
      expect(curve.peakTension, lessThanOrEqualTo(1.0));
      expect(curve.averageTension, greaterThanOrEqualTo(0.0));
      expect(curve.averageTension, lessThanOrEqualTo(1.0));
    });

    test('plot points maintain phase ordering within chapters', () {
      final arc = NarrativeArc(
        projectId: 'p1',
        plotPoints: [
          PlotPoint(
            id: 'pp-1',
            chapterId: 'ch-1',
            title: '开场',
            phase: NarrativeArcPhase.setup,
          ),
          PlotPoint(
            id: 'pp-2',
            chapterId: 'ch-2',
            title: '升级',
            phase: NarrativeArcPhase.risingAction,
          ),
          PlotPoint(
            id: 'pp-3',
            chapterId: 'ch-3',
            title: '转折',
            phase: NarrativeArcPhase.midpoint,
          ),
          PlotPoint(
            id: 'pp-4',
            chapterId: 'ch-4',
            title: '高潮',
            phase: NarrativeArcPhase.climax,
          ),
          PlotPoint(
            id: 'pp-5',
            chapterId: 'ch-5',
            title: '收尾',
            phase: NarrativeArcPhase.resolution,
          ),
        ],
      );
      final phases = arc.plotPoints.map((p) => p.phase).toList();
      for (var i = 1; i < phases.length; i++) {
        expect(
          phases.indexOf(phases[i]),
          greaterThanOrEqualTo(phases.indexOf(phases[i - 1])),
          reason: '${phases[i]} appeared after ${phases[i - 1]} out of order',
        );
      }
    });

    test('character arcs reference valid plot points within the arc', () {
      final arc = NarrativeArc(
        projectId: 'p1',
        plotPoints: [
          PlotPoint(
            id: 'pp-1',
            chapterId: 'ch-1',
            title: 'a',
            phase: NarrativeArcPhase.setup,
          ),
          PlotPoint(
            id: 'pp-2',
            chapterId: 'ch-2',
            title: 'b',
            phase: NarrativeArcPhase.climax,
          ),
        ],
        characterArcs: [
          CharacterArc(
            characterId: 'liuxi',
            startState: '孤立',
            endState: '信任',
            plotPointIds: ['pp-1', 'pp-2'],
          ),
          CharacterArc(
            characterId: 'yueren',
            startState: '忠诚',
            endState: '独立',
            plotPointIds: ['pp-2'],
          ),
        ],
      );
      final validIds = arc.plotPoints.map((p) => p.id).toSet();
      for (final ca in arc.characterArcs) {
        for (final pid in ca.plotPointIds) {
          expect(validIds, contains(pid), reason: 'CharacterArc for ${ca.characterId} references unknown plot point $pid');
        }
      }
    });
  });
}
