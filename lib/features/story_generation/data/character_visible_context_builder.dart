import 'character_visible_context_models.dart';
import 'scene_pipeline_models.dart' show SceneTaskCard;
import 'scene_roleplay_session_models.dart';
import '../domain/scene_models.dart';

class CharacterVisibleContextBuilder {
  const CharacterVisibleContextBuilder();

  CharacterVisibleContext build({
    required SceneBrief brief,
    required ResolvedSceneCastMember member,
    required SceneDirectorOutput director,
    required String publicSceneState,
    required List<SceneRoleplayTurn> transcript,
    SceneTaskCard? taskCard,
  }) {
    return CharacterVisibleContext(
      characterId: member.characterId,
      characterName: member.name,
      role: member.role,
      privateBriefing: _privateBriefing(
        brief: brief,
        member: member,
        director: director,
      ),
      publicSceneState: PublicSceneState(summary: publicSceneState),
      visibleEvents: _visibleEvents(transcript),
      knownFacts: _knownFacts(brief: brief, member: member),
      beliefs: _beliefs(taskCard: taskCard, member: member),
      relationships: _relationships(taskCard: taskCard, member: member),
      socialPositions: _socialPositions(taskCard: taskCard, member: member),
    );
  }

  List<VisibleEvent> _visibleEvents(List<SceneRoleplayTurn> transcript) {
    return [
      for (final turn in transcript)
        if (turn.visibleAction.trim().isNotEmpty ||
            turn.dialogue.trim().isNotEmpty)
          VisibleEvent(
            round: turn.round,
            actorId: turn.characterId,
            actorName: turn.name,
            visibleAction: turn.visibleAction,
            dialogue: turn.dialogue,
          ),
    ];
  }

  List<CharacterKnownFact> _knownFacts({
    required SceneBrief brief,
    required ResolvedSceneCastMember member,
  }) {
    final facts = <CharacterKnownFact>[];
    void addVisible(Object? raw, VisibilityAcl acl, {String source = ''}) {
      final value = _stringValue(raw);
      if (value == null || !acl.canSee(member.characterId)) return;
      facts.add(CharacterKnownFact(content: value, acl: acl, source: source));
    }

    for (final raw in _listValue(brief.metadata['publicKnownFacts'])) {
      addVisible(raw, VisibilityAcl.public(), source: 'publicKnownFacts');
    }

    final byCharacter =
        brief.metadata['characterKnownFacts'] ??
        brief.metadata['privateKnownFacts'];
    if (byCharacter is Map) {
      for (final raw in _listValue(byCharacter[member.characterId])) {
        addVisible(
          raw,
          VisibilityAcl.characters({member.characterId}),
          source: 'characterKnownFacts',
        );
      }
    }

    final aclFacts = brief.metadata['knownFacts'];
    if (aclFacts is List) {
      for (final raw in aclFacts) {
        if (raw is! Map) continue;
        final content = _stringValue(raw['content']);
        if (content == null) continue;
        final acl = _aclFromMetadata(raw['visibility'], raw['characterIds']);
        if (!acl.canSee(member.characterId)) continue;
        facts.add(
          CharacterKnownFact(
            content: content,
            acl: acl,
            confidence: _doubleValue(raw['confidence']) ?? 1,
            source: _stringValue(raw['source']) ?? 'knownFacts',
          ),
        );
      }
    }

    return List.unmodifiable(facts);
  }

  String _privateBriefing({
    required SceneBrief brief,
    required ResolvedSceneCastMember member,
    required SceneDirectorOutput director,
  }) {
    final explicit = _privateBriefingFromMetadata(brief, member.characterId);
    if (explicit != null) return _compact(explicit, maxChars: 240);

    final note = director.plan?.noteFor(member.characterId);
    final contribution = member.contributions.map(_contributionLabel).join('/');
    final parts = <String>[
      if (member.role.trim().isNotEmpty) '身份=${member.role.trim()}',
      if (note != null && note.motivation.trim().isNotEmpty)
        '动机=${note.motivation.trim()}',
      if (note != null && note.emotionalArc.trim().isNotEmpty)
        '情绪=${note.emotionalArc.trim()}',
      if (note != null && note.keyAction.trim().isNotEmpty)
        '当前冲动=${note.keyAction.trim()}',
      if (contribution.isNotEmpty) '参与=$contribution',
    ];
    if (parts.isEmpty) return member.name;
    return parts.join('；');
  }

  String? _privateBriefingFromMetadata(SceneBrief brief, String characterId) {
    final raw =
        brief.metadata['privateRoleBriefings'] ??
        brief.metadata['characterPrivateBriefings'];
    if (raw is Map) return _stringValue(raw[characterId]);
    return null;
  }

  List<String> _beliefs({
    required SceneTaskCard? taskCard,
    required ResolvedSceneCastMember member,
  }) {
    if (taskCard == null) return const <String>[];
    return [
      for (final belief in taskCard.beliefsFor(member.characterId))
        '${_memberName(taskCard, belief.targetId)}/${belief.aspect}=${belief.value}',
    ];
  }

  List<String> _relationships({
    required SceneTaskCard? taskCard,
    required ResolvedSceneCastMember member,
  }) {
    if (taskCard == null) return const <String>[];
    return [
      for (final relationship in taskCard.relationshipsFor(member.characterId))
        '${_memberName(taskCard, relationship.characterA)}↔${_memberName(taskCard, relationship.characterB)}：${relationship.label}（张力${relationship.tension}/信任${relationship.trust}）',
    ];
  }

  List<String> _socialPositions({
    required SceneTaskCard? taskCard,
    required ResolvedSceneCastMember member,
  }) {
    if (taskCard == null) return const <String>[];
    final social = taskCard.socialPositionFor(member.characterId);
    if (social == null) return const <String>[];
    return ['${social.role}/${social.formalRank}/影响力${social.actualInfluence}'];
  }

  VisibilityAcl _aclFromMetadata(Object? visibility, Object? characterIds) {
    final value = _stringValue(visibility);
    if (value == 'public') return VisibilityAcl.public();
    if (value == 'authorOnly' || value == 'author_only') {
      return VisibilityAcl.authorOnly();
    }
    final ids = _listValue(
      characterIds,
    ).map(_stringValue).whereType<String>().toSet();
    if (ids.isNotEmpty) return VisibilityAcl.characters(ids);
    return VisibilityAcl.authorOnly();
  }

  String _memberName(SceneTaskCard taskCard, String characterId) {
    for (final member in taskCard.cast) {
      if (member.characterId == characterId) return member.name;
    }
    return characterId;
  }

  List<Object?> _listValue(Object? raw) {
    if (raw is List) return raw;
    if (raw == null) return const <Object?>[];
    return <Object?>[raw];
  }

  String? _stringValue(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  double? _doubleValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  String _contributionLabel(SceneCastContribution contribution) {
    return switch (contribution) {
      SceneCastContribution.action => '行动',
      SceneCastContribution.dialogue => '对白',
      SceneCastContribution.interaction => '互动',
    };
  }

  String _compact(String value, {required int maxChars}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
