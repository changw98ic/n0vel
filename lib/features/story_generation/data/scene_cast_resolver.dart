import '../domain/scene_models.dart';
import '../domain/story_pipeline_interfaces.dart';
import 'scene_cast_roleplay_policy.dart';

class SceneCastResolver implements SceneCastResolverService {
  @override
  List<ResolvedSceneCastMember> resolve(SceneBrief brief) {
    return [
      for (final candidate in brief.cast)
        if (!isNoninteractiveCastCandidate(candidate))
          if (_resolveContributions(candidate.participation).isNotEmpty)
          ResolvedSceneCastMember(
            characterId: candidate.characterId,
            name: candidate.name,
            role: candidate.role,
            contributions: _resolveContributions(candidate.participation),
            metadata: candidate.metadata,
          ),
    ];
  }

  List<SceneCastContribution> _resolveContributions(
    SceneCastParticipation participation,
  ) {
    final contributions = <SceneCastContribution>[];
    if (_hasMeaningfulValue(participation.action)) {
      contributions.add(SceneCastContribution.action);
    }
    if (_hasMeaningfulValue(participation.dialogue)) {
      contributions.add(SceneCastContribution.dialogue);
    }
    if (_hasMeaningfulValue(participation.interaction)) {
      contributions.add(SceneCastContribution.interaction);
    }
    return List<SceneCastContribution>.unmodifiable(contributions);
  }

  bool _hasMeaningfulValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.trim().isNotEmpty;
    }
    if (value is Iterable<Object?>) {
      return value.any(_hasMeaningfulValue);
    }
    if (value is Map<Object?, Object?>) {
      return value.values.any(_hasMeaningfulValue);
    }
    return true;
  }
}
