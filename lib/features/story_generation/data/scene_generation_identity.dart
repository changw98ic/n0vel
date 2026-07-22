import 'generation_ledger_digest.dart';
import 'narrative_arc_models.dart';
import 'scene_context_models.dart';
import 'scene_runtime_models.dart';

/// Shared semantic identity for a scene generation request.
///
/// This projection is intentionally prompt-visible by default. Metadata is
/// included unless its key is explicitly versioned here as non-semantic runtime
/// bookkeeping. Unsupported values fail closed instead of falling through to
/// Object.toString(), because a stringified instance identity would make
/// generation input digests silently unstable.
class SceneGenerationIdentity {
  const SceneGenerationIdentity._();

  /// Version of the metadata projection policy used by [briefObject].
  ///
  /// Bump this when the classification below changes. Generation identities
  /// made under different policy versions must not be treated as equivalent by
  /// callers that persist them across releases.
  static const String metadataProjectionVersion =
      'scene-generation-metadata-v1';

  /// Metadata keys that describe transport, persistence, or presentation
  /// rather than model-visible story input.
  ///
  /// Matching is case-insensitive and separator-insensitive, so the same
  /// versioned policy covers `requestId`, `request_id`, and `request-id`.
  /// Deliberately do not exclude broad names such as `id`, `path`, `label`, or
  /// `state`: an unknown metadata field remains semantic by default.
  static const Set<String> excludedMetadataKeys = {
    // Wall-clock bookkeeping.
    'timestamp',
    'timestampMs',
    'createdAt',
    'createdAtMs',
    'updatedAt',
    'updatedAtMs',
    'generatedAt',
    'generatedAtMs',
    'capturedAt',
    'capturedAtMs',
    'persistedAt',
    'persistedAtMs',
    'ingestedAt',
    'ingestedAtMs',
    'startedAt',
    'startedAtMs',
    'completedAt',
    'completedAtMs',
    'lastModifiedAt',
    'lastModifiedAtMs',

    // Request and tracing identities.
    'traceId',
    'spanId',
    'parentSpanId',
    'runTraceId',
    'requestId',
    'providerRequestId',
    'taskId',
    'runId',
    'jobId',
    'attemptId',
    'invocationId',
    'correlationId',

    // Local persistence and provenance locations.
    'artifactPath',
    'localArtifactPath',
    'localPath',
    'filePath',
    'provenancePath',
    'provenancePaths',
    'provenanceRef',
    'provenanceRefs',
    'sourceFilePath',
    'cachePath',
    'tempPath',
    'tmpPath',

    // UI-only state.
    'displayLabel',
    'displayOrder',
    'uiLabel',
    'uiState',
    'uiOnly',
    'uiMetadata',
    'uiExpanded',
    'uiSelected',
    'isExpanded',
    'isSelected',
  };

  static final Set<String> _normalizedExcludedMetadataKeys = {
    for (final key in excludedMetadataKeys) _normalizeMetadataKey(key),
  };

  static const Object _omittedMetadata = Object();

  static bool excludesMetadataKey(String key) {
    return _normalizedExcludedMetadataKeys.contains(_normalizeMetadataKey(key));
  }

  static String briefHash(SceneBrief brief) {
    return GenerationLedgerDigest.object(briefObject(brief));
  }

  static Map<String, Object?> briefObject(SceneBrief brief) {
    return _jsonMap({
      'metadataProjectionVersion': metadataProjectionVersion,
      'projectId': brief.projectId,
      'chapterId': brief.chapterId,
      'chapterTitle': brief.chapterTitle,
      'sceneId': brief.sceneId,
      'sceneIndex': brief.sceneIndex,
      'totalScenesInChapter': brief.totalScenesInChapter,
      'sceneTitle': brief.sceneTitle,
      'sceneSummary': brief.sceneSummary,
      'targetLength': brief.targetLength,
      'targetBeat': brief.targetBeat,
      'worldNodeIds': brief.worldNodeIds,
      'cast': [for (final cast in brief.cast) _castObject(cast)],
      'characterProfiles': [
        for (final profile in brief.characterProfiles)
          _structuredProfileObject(profile.toJson()),
      ],
      'relationshipStates': [
        for (final state in brief.relationshipStates)
          _relationshipObject(state),
      ],
      'socialPositions': [
        for (final state in brief.socialPositions) _socialPositionObject(state),
      ],
      'beliefStates': [for (final state in brief.beliefStates) state.toJson()],
      'presentationStates': [
        for (final state in brief.presentationStates) state.toJson(),
      ],
      'knowledgeAtoms': [
        for (final atom in brief.knowledgeAtoms) _knowledgeAtomObject(atom),
      ],
      'narrativeArc': _narrativeArcObject(brief.narrativeArc),
      'formalExecution': brief.formalExecution,
      'metadata': _semanticMetadata(brief.metadata),
    });
  }

  static Map<String, Object?> _castObject(SceneCastCandidate cast) {
    return {
      'characterId': cast.characterId,
      'name': cast.name,
      'role': cast.role,
      'participation': {
        'action': cast.participation.action,
        'dialogue': cast.participation.dialogue,
        'interaction': cast.participation.interaction,
      },
      'metadata': _semanticMetadata(cast.metadata),
    };
  }

  static Map<String, Object?> _relationshipObject(RelationshipState state) {
    return {
      'sourceCharacterId': state.sourceCharacterId,
      'targetCharacterId': state.targetCharacterId,
      'trust': state.trust,
      'dependence': state.dependence,
      'fear': state.fear,
      'resentment': state.resentment,
      'desire': state.desire,
      'powerGap': state.powerGap,
      'publicAlignment': state.publicAlignment,
      'privateAlignment': state.privateAlignment,
      'sharedSecrets': state.sharedSecrets,
      'recentTriggers': state.recentTriggers,
    };
  }

  static Map<String, Object?> _socialPositionObject(SocialPositionState state) {
    return {
      'characterId': state.characterId,
      'institution': state.institution,
      'publicStatus': state.publicStatus,
      'legalExposure': state.legalExposure,
      'resources': state.resources,
      'activeConstraints': state.activeConstraints,
      'currentLeverage': state.currentLeverage,
      'watchers': state.watchers,
    };
  }

  static Map<String, Object?> _knowledgeAtomObject(KnowledgeAtom atom) {
    return {
      'id': atom.id,
      'type': atom.type,
      'content': atom.content,
      'ownerScope': atom.ownerScope,
      'visibility': atom.visibility.name,
      'priority': atom.priority,
      'tokenCostEstimate': atom.tokenCostEstimate,
      'tags': atom.tags,
      'unlockCondition': atom.unlockCondition,
    };
  }

  static Map<String, Object?>? _narrativeArcObject(NarrativeArcState? arc) {
    if (arc == null) return null;
    return {
      'activeThreads': [
        for (final thread in arc.activeThreads) _plotThreadObject(thread),
      ],
      'closedThreads': [
        for (final thread in arc.closedThreads) _plotThreadObject(thread),
      ],
      'pendingForeshadowing': [
        for (final foreshadowing in arc.pendingForeshadowing)
          _foreshadowingObject(foreshadowing),
      ],
      'thematicArcs': arc.thematicArcs,
      'chapterIndex': arc.chapterIndex,
    };
  }

  static Map<String, Object?> _plotThreadObject(PlotThread thread) {
    return {
      'id': thread.id,
      'description': thread.description,
      'status': thread.status.name,
      'involvedCharacters': thread.involvedCharacters,
      'introducedInScene': thread.introducedInScene,
      'resolvedInScene': thread.resolvedInScene,
    };
  }

  static Map<String, Object?> _foreshadowingObject(
    Foreshadowing foreshadowing,
  ) {
    return {
      'id': foreshadowing.id,
      'hint': foreshadowing.hint,
      'plannedPayoff': foreshadowing.plannedPayoff,
      'plantedInScene': foreshadowing.plantedInScene,
      'resolvedInScene': foreshadowing.resolvedInScene,
      'urgency': foreshadowing.urgency,
    };
  }

  static Map<String, Object?> _semanticMetadata(Map<String, Object?> metadata) {
    return Map<String, Object?>.from(
      _semanticMetadataValue(metadata, isRoot: true) as Map<String, Object?>,
    );
  }

  static Map<String, Object?> _structuredProfileObject(
    Map<String, Object?> profile,
  ) {
    return {
      for (final entry in profile.entries)
        entry.key: entry.key == 'metadata'
            ? _semanticMetadata(_requireStringMap(entry.value, 'metadata'))
            : _jsonValue(entry.value),
    };
  }

  static Object? _semanticMetadataValue(Object? value, {bool isRoot = false}) {
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw UnsupportedError(
            'scene generation identity only accepts string map keys',
          );
        }
        if (excludesMetadataKey(key)) continue;
        final projected = _semanticMetadataValue(entry.value);
        if (!identical(projected, _omittedMetadata)) {
          result[key] = projected;
        }
      }
      if (!isRoot && value.isNotEmpty && result.isEmpty) {
        return _omittedMetadata;
      }
      return result;
    }
    if (value is Iterable) {
      final result = <Object?>[];
      var hadItems = false;
      for (final item in value) {
        hadItems = true;
        final projected = _semanticMetadataValue(item);
        if (!identical(projected, _omittedMetadata)) {
          result.add(projected);
        }
      }
      if (hadItems && result.isEmpty) return _omittedMetadata;
      return result;
    }
    return _jsonValue(value);
  }

  static Map<String, Object?> _requireStringMap(Object? value, String field) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      try {
        return Map<String, Object?>.from(value);
      } on Object {
        // Use the same fail-closed contract as all other identity values.
      }
    }
    throw UnsupportedError(
      'scene generation identity requires $field to be a string-keyed map',
    );
  }

  static String _normalizeMetadataKey(String key) {
    return key.replaceAll(RegExp(r'[_\-\s]'), '').toLowerCase();
  }

  static Map<String, Object?> _jsonMap(Map<String, Object?> value) {
    return Map<String, Object?>.from(_jsonValue(value) as Map<String, Object?>);
  }

  static Object? _jsonValue(Object? value) {
    if (value == null || value is String || value is bool) return value;
    if (value is int) return value;
    if (value is double) {
      if (!value.isFinite) {
        throw UnsupportedError('non-finite double is not JSON-compatible');
      }
      return value;
    }
    if (value is Iterable) {
      return [for (final item in value) _jsonValue(item)];
    }
    if (value is Map) {
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw UnsupportedError(
            'scene generation identity only accepts string map keys',
          );
        }
        result[key] = _jsonValue(entry.value);
      }
      return result;
    }
    throw UnsupportedError(
      'scene generation identity only accepts JSON-compatible values',
    );
  }
}
