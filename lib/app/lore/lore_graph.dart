// ============================================================================
// Lore Graph
// ============================================================================
//
// Cross-project lore graph model and deterministic visualization projection.
// M8-04 intentionally keeps inference and canvas editing out of scope.

import 'dart:math' as math;

class LoreGraphException implements Exception {
  const LoreGraphException(this.message);

  final String message;

  @override
  String toString() => 'LoreGraphException($message)';
}

enum LoreNodeType {
  project('project'),
  character('character'),
  location('location'),
  worldItem('worldItem'),
  arc('arc'),
  custom('custom');

  const LoreNodeType(this.id);

  final String id;
}

enum LoreRelationDirection {
  directed('directed'),
  undirected('undirected');

  const LoreRelationDirection(this.id);

  final String id;
}

class LoreGraphNode {
  const LoreGraphNode({
    required this.id,
    required this.projectId,
    required this.label,
    required this.type,
    this.description,
    this.metadata = const {},
  });

  final String id;
  final String projectId;
  final String label;
  final LoreNodeType type;
  final String? description;
  final Map<String, Object?> metadata;

  bool get isProjectNode => type == LoreNodeType.project;

  LoreGraphNode copyWith({
    String? id,
    String? projectId,
    String? label,
    LoreNodeType? type,
    String? description,
    Map<String, Object?>? metadata,
  }) {
    return LoreGraphNode(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      label: label ?? this.label,
      type: type ?? this.type,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }
}

class LoreGraphRelation {
  const LoreGraphRelation({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.kind,
    required this.label,
    this.direction = LoreRelationDirection.directed,
    this.metadata = const {},
  });

  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String kind;
  final String label;
  final LoreRelationDirection direction;
  final Map<String, Object?> metadata;

  bool connects(String nodeId) {
    return sourceNodeId == nodeId || targetNodeId == nodeId;
  }
}

class LoreGraphProjectSummary {
  const LoreGraphProjectSummary({
    required this.projectId,
    required this.nodeCount,
    required this.relationCount,
  });

  final String projectId;
  final int nodeCount;
  final int relationCount;
}

class LoreGraph {
  const LoreGraph({this.nodes = const {}, this.relations = const {}});

  static const empty = LoreGraph();

  final Map<String, LoreGraphNode> nodes;
  final Map<String, LoreGraphRelation> relations;

  bool get isEmpty => nodes.isEmpty && relations.isEmpty;

  Set<String> get projectIds {
    final ids = nodes.values.map((node) => node.projectId).toSet();
    return Set.unmodifiable(ids);
  }

  LoreGraphNode? node(String nodeId) => nodes[nodeId];

  LoreGraphRelation? relation(String relationId) => relations[relationId];

  List<LoreGraphNode> nodesForProject(String projectId) {
    final items =
        nodes.values.where((node) => node.projectId == projectId).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(items);
  }

  List<LoreGraphRelation> relationsForProject(String projectId) {
    final projectNodeIds = nodesForProject(
      projectId,
    ).map((node) => node.id).toSet();
    final items =
        relations.values
            .where(
              (relation) =>
                  projectNodeIds.contains(relation.sourceNodeId) ||
                  projectNodeIds.contains(relation.targetNodeId),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(items);
  }

  List<LoreGraphRelation> crossProjectRelations() {
    final items = relations.values.where(isCrossProjectRelation).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(items);
  }

  bool isCrossProjectRelation(LoreGraphRelation relation) {
    final source = nodes[relation.sourceNodeId];
    final target = nodes[relation.targetNodeId];
    if (source == null || target == null) return false;
    return source.projectId != target.projectId;
  }

  LoreGraph upsertNode(LoreGraphNode node) {
    _validateNode(node);
    return LoreGraph(
      nodes: Map.unmodifiable({...nodes, node.id: node}),
      relations: relations,
    );
  }

  LoreGraph addManualRelation({
    String? relationId,
    required String sourceNodeId,
    required String targetNodeId,
    required String kind,
    required String label,
    LoreRelationDirection direction = LoreRelationDirection.directed,
    Map<String, Object?> metadata = const {},
  }) {
    _requireNode(sourceNodeId, 'sourceNodeId');
    _requireNode(targetNodeId, 'targetNodeId');
    if (sourceNodeId == targetNodeId) {
      throw const LoreGraphException('relation cannot target the same node');
    }
    final normalizedKind = _requireToken(kind, 'kind');
    final normalizedLabel = _requireText(label, 'label');
    final id = relationId?.trim().isNotEmpty == true
        ? relationId!.trim()
        : _manualRelationId(sourceNodeId, targetNodeId, normalizedKind);
    _requireToken(id, 'relationId');
    if (relations.containsKey(id)) {
      throw LoreGraphException('relation already exists: $id');
    }

    return LoreGraph(
      nodes: nodes,
      relations: Map.unmodifiable({
        ...relations,
        id: LoreGraphRelation(
          id: id,
          sourceNodeId: sourceNodeId,
          targetNodeId: targetNodeId,
          kind: normalizedKind,
          label: normalizedLabel,
          direction: direction,
          metadata: Map.unmodifiable(metadata),
        ),
      }),
    );
  }

  LoreGraph removeRelation(String relationId) {
    if (!relations.containsKey(relationId)) return this;
    final next = Map<String, LoreGraphRelation>.from(relations)
      ..remove(relationId);
    return LoreGraph(nodes: nodes, relations: Map.unmodifiable(next));
  }

  List<LoreGraphProjectSummary> projectSummaries() {
    final summaries = <LoreGraphProjectSummary>[];
    for (final projectId in projectIds.toList()..sort()) {
      summaries.add(
        LoreGraphProjectSummary(
          projectId: projectId,
          nodeCount: nodesForProject(projectId).length,
          relationCount: relationsForProject(projectId).length,
        ),
      );
    }
    return List.unmodifiable(summaries);
  }

  void _validateNode(LoreGraphNode node) {
    _requireToken(node.id, 'node.id');
    _requireToken(node.projectId, 'node.projectId');
    _requireText(node.label, 'node.label');
  }

  void _requireNode(String nodeId, String fieldName) {
    _requireToken(nodeId, fieldName);
    if (!nodes.containsKey(nodeId)) {
      throw LoreGraphException('unknown node for $fieldName: $nodeId');
    }
  }
}

class LoreGraphProjectionOptions {
  const LoreGraphProjectionOptions({
    this.projectSpacing = 360,
    this.nodeRadius = 96,
    this.clusterPadding = 56,
  });

  final double projectSpacing;
  final double nodeRadius;
  final double clusterPadding;
}

class LoreGraphVisualNode {
  const LoreGraphVisualNode({
    required this.id,
    required this.projectId,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
  });

  final String id;
  final String projectId;
  final String label;
  final LoreNodeType type;
  final double x;
  final double y;
}

class LoreGraphVisualRelation {
  const LoreGraphVisualRelation({
    required this.id,
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.label,
    required this.kind,
    required this.crossProject,
    required this.direction,
  });

  final String id;
  final String sourceNodeId;
  final String targetNodeId;
  final String label;
  final String kind;
  final bool crossProject;
  final LoreRelationDirection direction;
}

class LoreGraphProjectCluster {
  const LoreGraphProjectCluster({
    required this.projectId,
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.nodeIds,
  });

  final String projectId;
  final double centerX;
  final double centerY;
  final double radius;
  final List<String> nodeIds;
}

class LoreGraphProjection {
  const LoreGraphProjection({
    required this.nodes,
    required this.relations,
    required this.clusters,
  });

  final List<LoreGraphVisualNode> nodes;
  final List<LoreGraphVisualRelation> relations;
  final List<LoreGraphProjectCluster> clusters;
}

class LoreGraphProjector {
  const LoreGraphProjector({this.options = const LoreGraphProjectionOptions()});

  final LoreGraphProjectionOptions options;

  LoreGraphProjection project(LoreGraph graph) {
    final projectIds = graph.projectIds.toList()..sort();
    final visualNodes = <LoreGraphVisualNode>[];
    final clusters = <LoreGraphProjectCluster>[];

    for (
      var projectIndex = 0;
      projectIndex < projectIds.length;
      projectIndex++
    ) {
      final projectId = projectIds[projectIndex];
      final projectNodes = graph.nodesForProject(projectId);
      final centerX = projectIndex * options.projectSpacing;
      const centerY = 0.0;
      final radius = projectNodes.length <= 1
          ? 0.0
          : options.nodeRadius + options.clusterPadding;
      clusters.add(
        LoreGraphProjectCluster(
          projectId: projectId,
          centerX: centerX,
          centerY: centerY,
          radius: radius,
          nodeIds: List.unmodifiable(projectNodes.map((node) => node.id)),
        ),
      );

      for (var nodeIndex = 0; nodeIndex < projectNodes.length; nodeIndex++) {
        final node = projectNodes[nodeIndex];
        final point = _nodePoint(
          centerX: centerX,
          centerY: centerY,
          count: projectNodes.length,
          index: nodeIndex,
        );
        visualNodes.add(
          LoreGraphVisualNode(
            id: node.id,
            projectId: node.projectId,
            label: node.label,
            type: node.type,
            x: point.x,
            y: point.y,
          ),
        );
      }
    }

    final visualRelations = graph.relations.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return LoreGraphProjection(
      nodes: List.unmodifiable(visualNodes),
      relations: List.unmodifiable(
        visualRelations.map(
          (relation) => LoreGraphVisualRelation(
            id: relation.id,
            sourceNodeId: relation.sourceNodeId,
            targetNodeId: relation.targetNodeId,
            label: relation.label,
            kind: relation.kind,
            crossProject: graph.isCrossProjectRelation(relation),
            direction: relation.direction,
          ),
        ),
      ),
      clusters: List.unmodifiable(clusters),
    );
  }

  ({double x, double y}) _nodePoint({
    required double centerX,
    required double centerY,
    required int count,
    required int index,
  }) {
    if (count == 1) return (x: centerX, y: centerY);
    final angle = (-math.pi / 2) + ((math.pi * 2) * index / count);
    return (
      x: centerX + (math.cos(angle) * options.nodeRadius),
      y: centerY + (math.sin(angle) * options.nodeRadius),
    );
  }
}

String _requireToken(String value, String fieldName) {
  final token = value.trim();
  if (token.isEmpty) {
    throw LoreGraphException('$fieldName is required');
  }
  if (!RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(token)) {
    throw LoreGraphException('$fieldName must be a stable token');
  }
  return token;
}

String _requireText(String value, String fieldName) {
  final text = value.trim();
  if (text.isEmpty) {
    throw LoreGraphException('$fieldName is required');
  }
  return text;
}

String _manualRelationId(
  String sourceNodeId,
  String targetNodeId,
  String kind,
) {
  return 'manual:$sourceNodeId:$kind:$targetNodeId';
}
