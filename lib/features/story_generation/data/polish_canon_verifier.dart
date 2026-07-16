import '../../../app/llm/app_llm_canonical_hash.dart';
import '../domain/scene_models.dart' show ProjectMaterialSnapshot;
import 'polish_canon_evidence.dart';
import 'scene_runtime_models.dart' show SceneBrief;

/// Frozen high-precision guard for facts introduced only by language polish.
///
/// The verifier does not attempt open-ended semantic judging. It compares
/// explicit character, named-item, and world-rule introductions against the
/// exact pre-polish candidate plus the structured material snapshot. Softer
/// prose changes remain the responsibility of the final council.
final class PolishCanonVerifier {
  const PolishCanonVerifier._();

  static const standard = PolishCanonVerifier._();

  static String get releaseHash => AppLlmCanonicalHash.domainHash(
    'polish-canon-verifier-release-v1',
    const <String, Object?>{
      'allowedSources': <String>[
        'pre-polish-candidate',
        'scene-brief',
        'cast-and-structured-profile',
        'project-material-snapshot',
      ],
      'claims': <String>[
        'explicit-character-introduction-v1',
        'named-item-introduction-v1',
        'explicit-world-rule-assertion-v1',
      ],
      'policy': 'new-explicit-fact-must-have-an-allowed-source-v1',
    },
  );

  static String proseHash(String prose) => AppLlmCanonicalHash.domainHash(
    'polish-canon-prose-v1',
    prose.replaceAll('\r\n', '\n'),
  );

  PolishCanonEvidence verify({
    required String prePolishProse,
    required String polishedProse,
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
  }) {
    final allowedSources = _allowedSources(
      prePolishProse: prePolishProse,
      brief: brief,
      materials: materials,
    );
    final allowedFactHashes =
        allowedSources
            .map(
              (source) => AppLlmCanonicalHash.domainHash(
                'polish-canon-allowed-fact-v1',
                <String, Object?>{
                  'kind': source.kind,
                  'content': _normalize(source.content),
                },
              ),
            )
            .toSet()
            .toList()
          ..sort();
    final allowedRoot = AppLlmCanonicalHash.domainHash(
      'polish-canon-allowed-root-v1',
      allowedFactHashes,
    );
    final introduced = <PolishCanonIntroducedFact>[];
    final seen = <String>{};
    for (final claim in _extractClaims(polishedProse)) {
      if (_supported(claim, allowedSources)) continue;
      final factHash = AppLlmCanonicalHash.domainHash(
        'polish-canon-introduced-fact-v1',
        <String, Object?>{
          'kind': claim.kind.name,
          'content': _normalize(claim.content),
        },
      );
      if (!seen.add(factHash)) continue;
      introduced.add(
        PolishCanonIntroducedFact(
          kind: claim.kind,
          factHash: factHash,
          failureCode: 'continuity.polish_unknown_${claim.kind.name}',
        ),
      );
    }
    return PolishCanonEvidence(
      verifierReleaseHash: releaseHash,
      prePolishProseHash: proseHash(prePolishProse),
      finalProseHash: proseHash(polishedProse),
      allowedCanonRootHash: allowedRoot,
      allowedCanonFactHashes: allowedFactHashes,
      introducedFacts: introduced,
    );
  }

  List<_AllowedCanonSource> _allowedSources({
    required String prePolishProse,
    required SceneBrief brief,
    required ProjectMaterialSnapshot materials,
  }) {
    final result = <_AllowedCanonSource>[
      _AllowedCanonSource('candidateState', prePolishProse),
      _AllowedCanonSource('sceneTitle', brief.sceneTitle),
      _AllowedCanonSource('sceneSummary', brief.sceneSummary),
      _AllowedCanonSource('targetBeat', brief.targetBeat),
      for (final id in brief.worldNodeIds)
        _AllowedCanonSource('worldNodeId', id),
      for (final member in brief.cast) ...<_AllowedCanonSource>[
        _AllowedCanonSource('characterId', member.characterId),
        _AllowedCanonSource('characterName', member.name),
        _AllowedCanonSource('characterRole', member.role),
        _AllowedCanonSource('characterMetadata', member.metadata.toString()),
      ],
      for (final profile in brief.characterProfiles)
        _AllowedCanonSource(
          'structuredCharacterProfile',
          AppLlmCanonicalHash.canonicalJson(profile.toJson()),
        ),
      for (final fact in materials.worldFacts)
        _AllowedCanonSource('worldFact', fact),
      for (final profile in materials.characterProfiles)
        _AllowedCanonSource('characterProfile', profile),
      for (final hint in materials.relationshipHints)
        _AllowedCanonSource('relationshipHint', hint),
      for (final beat in materials.outlineBeats)
        _AllowedCanonSource('outlineBeat', beat),
      for (final summary in materials.sceneSummaries)
        _AllowedCanonSource('sceneSummaryMaterial', summary),
      for (final state in materials.acceptedStates)
        _AllowedCanonSource('acceptedState', state),
      for (final finding in materials.reviewFindings)
        _AllowedCanonSource('reviewFinding', finding),
    ];
    return result
        .where((source) => _normalize(source.content).isNotEmpty)
        .toList(growable: false);
  }

  Iterable<_CanonClaim> _extractClaims(String prose) sync* {
    for (final marker in const <String>['名叫', '名字叫', '名字是', '自称', '人称']) {
      for (final tail in _tailsAfter(prose, marker)) {
        var candidate = _claimSegment(tail, maximumRunes: 12);
        final qualifier = candidate.indexOf('的');
        if (qualifier > 0) candidate = candidate.substring(0, qualifier);
        final copula = candidate.indexOf('是');
        if (copula > 0) candidate = candidate.substring(0, copula);
        final runes = candidate.runes.toList(growable: false);
        if (runes.length >= 2 && runes.length <= 32) {
          final bounded = runes.length <= 4 || _isLatinIdentity(candidate);
          if (bounded) {
            yield _CanonClaim(PolishCanonFactKind.character, candidate);
          }
        }
      }
    }
    const itemSuffixes = <String>[
      '钥匙',
      '戒指',
      '吊坠',
      '徽章',
      '芯片',
      '药剂',
      '遗物',
      '武器',
      '装置',
      '终端',
      '刀',
      '剑',
      '枪',
    ];
    for (final marker in const <String>[
      '拿出',
      '掏出',
      '取出',
      '摸出',
      '亮出',
      '发现',
      '得到',
      '拾起',
      '举起',
      '握住',
    ]) {
      for (final tail in _tailsAfter(prose, marker)) {
        var candidate = _claimSegment(tail, maximumRunes: 30);
        candidate = candidate.replaceFirst(
          RegExp(r'^(?:了)?(?:一(?:把|柄|枚|件|本|张|颗|块|只|个))?'),
          '',
        );
        for (final suffix in itemSuffixes) {
          final suffixAt = candidate.indexOf(suffix);
          if (suffixAt < 0) continue;
          final item = candidate.substring(0, suffixAt + suffix.length);
          if (item.runes.length >= 2 && item.runes.length <= 24) {
            yield _CanonClaim(PolishCanonFactKind.item, item);
          }
          break;
        }
      }
    }
    for (final marker in const <String>[
      '世界规则',
      '铁律',
      '禁令',
      '真相',
      '设定',
      '族规',
      '城规',
      '契约',
    ]) {
      for (var tail in _tailsAfter(prose, marker)) {
        tail = tail.trimLeft();
        if (tail.isEmpty ||
            !const <String>{'是', '为', '：', ':'}.contains(tail[0])) {
          continue;
        }
        final claim = _claimSegment(tail.substring(1), maximumRunes: 80);
        if (claim.runes.length >= 2) {
          yield _CanonClaim(PolishCanonFactKind.canon, claim);
        }
      }
    }
  }

  Iterable<String> _tailsAfter(String value, String marker) sync* {
    var start = 0;
    while (start < value.length) {
      final index = value.indexOf(marker, start);
      if (index < 0) return;
      yield value.substring(index + marker.length);
      start = index + marker.length;
    }
  }

  String _claimSegment(String value, {required int maximumRunes}) {
    var cleaned = value.trimLeft();
    while (cleaned.isNotEmpty && '「『“"'.contains(cleaned[0])) {
      cleaned = cleaned.substring(1).trimLeft();
    }
    final boundary = RegExp(
      r'[，。！？；：、,!?;:\n\r「」『』“”"]',
    ).firstMatch(cleaned)?.start;
    if (boundary != null) cleaned = cleaned.substring(0, boundary);
    final runes = cleaned.trim().runes.take(maximumRunes).toList();
    return String.fromCharCodes(runes).trim();
  }

  bool _isLatinIdentity(String value) =>
      RegExp(r'^[A-Za-z][A-Za-z0-9_-]{1,31}$').hasMatch(value);

  bool _supported(_CanonClaim claim, List<_AllowedCanonSource> allowedSources) {
    final normalized = _normalize(claim.content);
    if (normalized.isEmpty) return true;
    for (final source in allowedSources) {
      final allowed = _normalize(source.content);
      if (allowed.contains(normalized) ||
          (allowed.runes.length >= 2 && normalized.contains(allowed))) {
        return true;
      }
      if (claim.kind == PolishCanonFactKind.canon &&
          _canonTermCoverage(normalized, allowed) >= 0.75) {
        return true;
      }
    }
    return false;
  }

  double _canonTermCoverage(String claim, String allowed) {
    final terms = _terms(claim);
    if (terms.isEmpty) return 0;
    final matched = terms.where(allowed.contains).length;
    return matched / terms.length;
  }

  Set<String> _terms(String value) {
    final result = <String>{};
    final latin = RegExp(r'[a-z0-9_-]{3,}');
    for (final match in latin.allMatches(value)) {
      result.add(match.group(0)!);
    }
    final cjk = value.runes
        .where((rune) => rune >= 0x3400 && rune <= 0x9fff)
        .toList(growable: false);
    for (var index = 0; index + 1 < cjk.length; index += 2) {
      result.add(String.fromCharCodes(cjk.sublist(index, index + 2)));
    }
    return result;
  }

  String _normalize(String value) => value.toLowerCase().replaceAll(
    RegExp(r'[\s\p{P}\p{S}]+', unicode: true),
    '',
  );
}

final class PolishCanonViolation implements Exception {
  const PolishCanonViolation(this.evidence);

  final PolishCanonEvidence evidence;

  @override
  String toString() =>
      'PolishCanonViolation: ${evidence.failureCodes.join(',')}';
}

final class _AllowedCanonSource {
  const _AllowedCanonSource(this.kind, this.content);

  final String kind;
  final String content;
}

final class _CanonClaim {
  const _CanonClaim(this.kind, this.content);

  final PolishCanonFactKind kind;
  final String content;
}
