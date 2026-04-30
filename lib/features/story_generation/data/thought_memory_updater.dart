import 'dart:convert';

export '../domain/memory_models.dart' show ThoughtUpdateResult;

import '../domain/memory_models.dart';
import 'story_memory_dedupe.dart';
import 'story_memory_storage.dart';
import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';

/// Optional LLM caller for thought refinement.
/// Returns the raw response text, or null on failure.
typedef LlmThoughtCaller =
    Future<String?> Function(String systemPrompt, String userPrompt);

const String _llmSystemPrompt =
    'You are a thought extraction engine for a novel writing system. '
    'Given scene context, extract reusable thought atoms as a JSON array.\n'
    'Use objects with exactly these fields:\n'
    '- thoughtType: one of "persona", "plotCausality", "state", '
    '"foreshadowing", "style"\n'
    '- content: concise observation under 100 characters\n'
    '- confidence: number 0.0 to 1.0\n'
    '- sourceIds: array of source id strings\n'
    '- rootSourceIds: array of root source id strings\n'
    '- tags: array of relevant tag strings\n'
    'Return a plain JSON array.';

/// Extracts Thought-Retriever-style thought atoms after scene acceptance.
class ThoughtMemoryUpdater implements ThoughtMemoryService {
  ThoughtMemoryUpdater({
    required this.storage,
    StoryMemoryDedupe? dedupe,
    this.llmCaller,
  }) : _dedupe = dedupe ?? StoryMemoryDedupe();

  final StoryMemoryStorage storage;
  final StoryMemoryDedupe _dedupe;
  final LlmThoughtCaller? llmCaller;

  /// Extracts thoughts using LLM refinement when available,
  /// falling back to local extraction on failure.
  @override
  Future<ThoughtUpdateResult> extractWithLlm({
    required String projectId,
    required SceneRuntimeOutput sceneOutput,
    int? nowMs,
  }) async {
    if (llmCaller == null) {
      return extractLocal(
        projectId: projectId,
        sceneOutput: sceneOutput,
        nowMs: nowMs,
      );
    }

    try {
      final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
      final brief = sceneOutput.brief;
      final scopeId = '${brief.chapterId}:${brief.sceneId}';

      final response = await llmCaller!(
        _llmSystemPrompt,
        _buildLlmPrompt(sceneOutput),
      );

      if (response == null || response.trim().isEmpty) {
        return extractLocal(
          projectId: projectId,
          sceneOutput: sceneOutput,
          nowMs: nowMs,
        );
      }

      final parsed = _parseLlmResponse(response, projectId, scopeId, ts);
      if (parsed.isEmpty) {
        return extractLocal(
          projectId: projectId,
          sceneOutput: sceneOutput,
          nowMs: nowMs,
        );
      }

      return _filterAndPersist(projectId, parsed);
    } catch (_) {
      return extractLocal(
        projectId: projectId,
        sceneOutput: sceneOutput,
        nowMs: nowMs,
      );
    }
  }

  /// Extracts thoughts from an accepted scene using local rules.
  ///
  /// Works without an LLM by summarizing accepted state changes,
  /// open threats, role turn withheld info, and review pass results.
  @override
  Future<ThoughtUpdateResult> extractLocal({
    required String projectId,
    required SceneRuntimeOutput sceneOutput,
    int? nowMs,
  }) async {
    final ts = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final candidates = <ThoughtAtom>[];
    final brief = sceneOutput.brief;
    final scopeId = '${brief.chapterId}:${brief.sceneId}';
    var seq = 0;

    // Persona thought from cast participation
    for (final member in sceneOutput.resolvedCast) {
      final content = '${member.name} participates in ${brief.sceneTitle}';
      candidates.add(
        ThoughtAtom(
          id: '${projectId}_tp_${ts}_$seq',
          projectId: projectId,
          scopeId: scopeId,
          thoughtType: ThoughtType.persona,
          content: content,
          confidence: 0.75,
          abstractionLevel: 1.0,
          sourceRefs: [
            MemorySourceRef(
              sourceId: brief.sceneId,
              sourceType: MemorySourceKind.sceneSummary,
            ),
          ],
          rootSourceIds: [brief.sceneId],
          tags: ['char-${member.characterId}', 'persona'],
          priority: 2,
          tokenCostEstimate: (content.length / 3.5).ceil(),
          createdAtMs: ts + seq,
        ),
      );
      seq++;
    }

    // Plot causality from director text
    if (sceneOutput.director.text.isNotEmpty) {
      final content =
          'Director intent: ${_truncate(sceneOutput.director.text, 120)}';
      candidates.add(
        ThoughtAtom(
          id: '${projectId}_tc_${ts}_$seq',
          projectId: projectId,
          scopeId: scopeId,
          thoughtType: ThoughtType.plotCausality,
          content: content,
          confidence: 0.80,
          abstractionLevel: 2.0,
          sourceRefs: [
            MemorySourceRef(
              sourceId: brief.sceneId,
              sourceType: MemorySourceKind.sceneSummary,
            ),
          ],
          rootSourceIds: [brief.sceneId],
          tags: ['plot', 'causality', 'ch-${brief.chapterId}'],
          priority: 3,
          tokenCostEstimate: (content.length / 3.5).ceil(),
          createdAtMs: ts + seq,
        ),
      );
      seq++;
    }

    // State thought from review decision
    if (sceneOutput.review.decision.name != 'pass') {
      final content =
          'Review result: ${sceneOutput.review.decision.name} for ${brief.sceneTitle}';
      candidates.add(
        ThoughtAtom(
          id: '${projectId}_ts_${ts}_$seq',
          projectId: projectId,
          scopeId: scopeId,
          thoughtType: ThoughtType.state,
          content: content,
          confidence: 0.85,
          abstractionLevel: 1.5,
          sourceRefs: [
            MemorySourceRef(
              sourceId: brief.sceneId,
              sourceType: MemorySourceKind.reviewFinding,
            ),
          ],
          rootSourceIds: [brief.sceneId],
          tags: ['state', 'review', 'ch-${brief.chapterId}'],
          priority: 4,
          tokenCostEstimate: (content.length / 3.5).ceil(),
          createdAtMs: ts + seq,
        ),
      );
      seq++;
    }

    // Foreshadowing from prose if review passed
    if (sceneOutput.review.decision.name == 'pass' &&
        sceneOutput.prose.text.isNotEmpty) {
      final content =
          'Accepted scene prose (${brief.sceneTitle}): ${_truncate(sceneOutput.prose.text, 100)}';
      candidates.add(
        ThoughtAtom(
          id: '${projectId}_tf_${ts}_$seq',
          projectId: projectId,
          scopeId: scopeId,
          thoughtType: ThoughtType.foreshadowing,
          content: content,
          confidence: 0.75,
          abstractionLevel: 1.5,
          sourceRefs: [
            MemorySourceRef(
              sourceId: brief.sceneId,
              sourceType: MemorySourceKind.sceneSummary,
            ),
          ],
          rootSourceIds: [brief.sceneId],
          tags: ['foreshadowing', 'ch-${brief.chapterId}'],
          priority: 2,
          tokenCostEstimate: (content.length / 3.5).ceil(),
          createdAtMs: ts + seq,
        ),
      );
      seq++;
    }

    return _filterAndPersist(projectId, candidates);
  }

  /// Filters candidates through quality gates and dedupe, then persists.
  Future<ThoughtUpdateResult> _filterAndPersist(
    String projectId,
    List<ThoughtAtom> candidates,
  ) async {
    final existing = await storage.loadThoughts(projectId);
    final accepted = <ThoughtAtom>[];
    final rejected = <ThoughtAtom>[];

    for (final candidate in candidates) {
      if (!_dedupe.passesQualityGate(candidate)) {
        rejected.add(candidate);
        continue;
      }
      if (_dedupe.isDuplicate(candidate, existing)) {
        rejected.add(candidate);
        continue;
      }
      accepted.add(candidate);
      existing.add(candidate);
    }

    if (accepted.isNotEmpty) {
      await storage.saveThoughts(projectId, [
        ...(await storage.loadThoughts(projectId)),
        ...accepted,
      ]);
    }

    return ThoughtUpdateResult(accepted: accepted, rejected: rejected);
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 3)}...';
  }

  String _buildLlmPrompt(SceneRuntimeOutput output) {
    final brief = output.brief;
    final parts = <String>[
      'Scene: ${brief.sceneTitle}',
      'Summary: ${brief.sceneSummary}',
    ];
    if (output.director.text.isNotEmpty) {
      parts.add('Director: ${_truncate(output.director.text, 200)}');
    }
    if (output.roleOutputs.isNotEmpty) {
      parts.add(
        'Roles: ${output.roleOutputs.map((r) => '${r.name}: ${_truncate(r.text, 80)}').join("; ")}',
      );
    }
    if (output.prose.text.isNotEmpty) {
      parts.add('Prose: ${_truncate(output.prose.text, 200)}');
    }
    parts.add('Review: ${output.review.decision.name}');
    if (output.review.editorialFeedback.isNotEmpty) {
      parts.add('Feedback: ${_truncate(output.review.editorialFeedback, 150)}');
    }
    return parts.join('\n');
  }

  List<ThoughtAtom> _parseLlmResponse(
    String response,
    String projectId,
    String scopeId,
    int ts,
  ) {
    var cleaned = response.trim();
    if (cleaned.startsWith('```')) {
      final endOfFirstLine = cleaned.indexOf('\n');
      if (endOfFirstLine > 0) {
        cleaned = cleaned.substring(endOfFirstLine + 1);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    final Object? parsed;
    try {
      parsed = jsonDecode(cleaned);
    } catch (_) {
      return const [];
    }

    if (parsed is! List) return const [];

    final atoms = <ThoughtAtom>[];
    for (var i = 0; i < parsed.length; i++) {
      final item = parsed[i];
      if (item is! Map<String, Object?>) continue;

      final thoughtType = _parseThoughtTypeFromLlm(item['thoughtType']);
      final content = item['content']?.toString() ?? '';
      if (content.trim().isEmpty) continue;

      final confidence = _parseDouble(item['confidence']);
      final sourceIds = _parseStringList(item['sourceIds']);
      final rootSourceIds = _parseStringList(item['rootSourceIds']);
      final tags = _parseStringList(item['tags']);

      atoms.add(
        ThoughtAtom(
          id: '${projectId}_tl_${ts}_$i',
          projectId: projectId,
          scopeId: scopeId,
          thoughtType: thoughtType,
          content: content,
          confidence: confidence.clamp(0.0, 1.0),
          abstractionLevel: 2.0,
          sourceRefs: [
            for (final sid in sourceIds)
              MemorySourceRef(
                sourceId: sid,
                sourceType: MemorySourceKind.sceneSummary,
              ),
          ],
          rootSourceIds: rootSourceIds.isNotEmpty ? rootSourceIds : sourceIds,
          tags: tags,
          priority: 3,
          tokenCostEstimate: (content.length / 3.5).ceil(),
          createdAtMs: ts + i,
        ),
      );
    }

    return atoms;
  }

  ThoughtType _parseThoughtTypeFromLlm(Object? raw) {
    final name = raw?.toString().toLowerCase() ?? '';
    for (final v in ThoughtType.values) {
      if (v.name.toLowerCase() == name) return v;
    }
    return ThoughtType.persona;
  }

  List<String> _parseStringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item != null && item.toString().trim().isNotEmpty) item.toString(),
    ];
  }

  double _parseDouble(Object? raw) {
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0.0;
  }
}
