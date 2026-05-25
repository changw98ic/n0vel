import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/lore/lore.dart';

void main() {
  group('LoreGraph', () {
    test('models multiple projects and manual cross-project relations', () {
      final graph = LoreGraph.empty
          .upsertNode(
            const LoreGraphNode(
              id: 'project:a',
              projectId: 'project-a',
              label: 'Project A',
              type: LoreNodeType.project,
            ),
          )
          .upsertNode(
            const LoreGraphNode(
              id: 'project:b',
              projectId: 'project-b',
              label: 'Project B',
              type: LoreNodeType.project,
            ),
          )
          .upsertNode(
            const LoreGraphNode(
              id: 'char:iris',
              projectId: 'project-a',
              label: 'Iris',
              type: LoreNodeType.character,
            ),
          )
          .upsertNode(
            const LoreGraphNode(
              id: 'place:archive',
              projectId: 'project-b',
              label: 'Archive City',
              type: LoreNodeType.location,
            ),
          )
          .addManualRelation(
            sourceNodeId: 'char:iris',
            targetNodeId: 'place:archive',
            kind: 'searches-for',
            label: 'searches for',
            direction: LoreRelationDirection.directed,
          );

      expect(graph.projectIds, {'project-a', 'project-b'});
      expect(graph.nodesForProject('project-a').map((node) => node.id), [
        'char:iris',
        'project:a',
      ]);
      expect(graph.crossProjectRelations(), hasLength(1));
      expect(graph.crossProjectRelations().single.label, 'searches for');
      expect(graph.projectSummaries(), hasLength(2));
      expect(graph.projectSummaries().first.projectId, 'project-a');
      expect(graph.projectSummaries().first.relationCount, 1);
    });

    test(
      'rejects relations with unknown, duplicate, or self-targeting nodes',
      () {
        final graph = LoreGraph.empty
            .upsertNode(
              const LoreGraphNode(
                id: 'char:iris',
                projectId: 'project-a',
                label: 'Iris',
                type: LoreNodeType.character,
              ),
            )
            .upsertNode(
              const LoreGraphNode(
                id: 'char:noor',
                projectId: 'project-a',
                label: 'Noor',
                type: LoreNodeType.character,
              ),
            );

        expect(
          () => graph.addManualRelation(
            sourceNodeId: 'char:iris',
            targetNodeId: 'missing',
            kind: 'knows',
            label: 'knows',
          ),
          throwsA(
            isA<LoreGraphException>().having(
              (e) => e.message,
              'message',
              contains('unknown node for targetNodeId: missing'),
            ),
          ),
        );

        expect(
          () => graph.addManualRelation(
            sourceNodeId: 'char:iris',
            targetNodeId: 'char:iris',
            kind: 'knows',
            label: 'knows',
          ),
          throwsA(
            isA<LoreGraphException>().having(
              (e) => e.message,
              'message',
              contains('relation cannot target the same node'),
            ),
          ),
        );

        final withRelation = graph.addManualRelation(
          relationId: 'rel:iris-noor',
          sourceNodeId: 'char:iris',
          targetNodeId: 'char:noor',
          kind: 'knows',
          label: 'knows',
        );

        expect(
          () => withRelation.addManualRelation(
            relationId: 'rel:iris-noor',
            sourceNodeId: 'char:iris',
            targetNodeId: 'char:noor',
            kind: 'knows',
            label: 'knows',
          ),
          throwsA(
            isA<LoreGraphException>().having(
              (e) => e.message,
              'message',
              contains('relation already exists: rel:iris-noor'),
            ),
          ),
        );
      },
    );
  });

  group('LoreGraphProjector', () {
    test('creates stable visual clusters, nodes, and edge projections', () {
      final graph = LoreGraph.empty
          .upsertNode(
            const LoreGraphNode(
              id: 'char:iris',
              projectId: 'project-a',
              label: 'Iris',
              type: LoreNodeType.character,
            ),
          )
          .upsertNode(
            const LoreGraphNode(
              id: 'arc:signal',
              projectId: 'project-a',
              label: 'Signal Arc',
              type: LoreNodeType.arc,
            ),
          )
          .upsertNode(
            const LoreGraphNode(
              id: 'place:archive',
              projectId: 'project-b',
              label: 'Archive City',
              type: LoreNodeType.location,
            ),
          )
          .addManualRelation(
            sourceNodeId: 'char:iris',
            targetNodeId: 'place:archive',
            kind: 'searches-for',
            label: 'searches for',
          );

      final projection = const LoreGraphProjector(
        options: LoreGraphProjectionOptions(projectSpacing: 400),
      ).project(graph);

      expect(projection.clusters.map((cluster) => cluster.projectId), [
        'project-a',
        'project-b',
      ]);
      expect(projection.nodes.map((node) => node.id), [
        'arc:signal',
        'char:iris',
        'place:archive',
      ]);
      expect(projection.clusters.first.centerX, 0);
      expect(projection.clusters.last.centerX, 400);
      expect(projection.relations.single.crossProject, isTrue);
      expect(projection.relations.single.kind, 'searches-for');
    });
  });
}
