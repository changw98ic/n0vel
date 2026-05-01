import 'scene_context_models.dart';
import 'scene_runtime_models.dart';

bool isRoleplayEligibleCastCandidate(SceneCastCandidate candidate) {
  return !isNoninteractiveCastCandidate(candidate);
}

bool isNoninteractiveCastCandidate(SceneCastCandidate candidate) {
  final metadata = candidate.metadata;
  if (_isFalse(metadata['roleplayEnabled']) ||
      _isFalse(metadata['canRoleplay']) ||
      _isFalse(metadata['activeInRoleplay']) ||
      _isFalse(metadata['canAct'])) {
    return true;
  }

  final mode = _normalized(metadata['roleplayMode'] ?? metadata['castMode']);
  if (const {
    'evidence',
    'prop',
    'background',
    'passive',
    'noninteractive',
    'non-interactive',
    'non_interactive',
    '环境',
    '证物',
    '证据',
    '道具',
    '背景',
  }.contains(mode)) {
    return true;
  }

  final lifeState = _normalized(
    metadata['lifeState'] ?? metadata['state'] ?? metadata['status'],
  );
  return const {
    'corpse',
    'dead',
    'deceased',
    'body',
    '尸体',
    '遗体',
    '死亡',
    '已死',
  }.contains(lifeState);
}

String noninteractiveCastBoundaryText(SceneBrief brief) {
  final rules = [
    for (final candidate in brief.cast)
      if (isNoninteractiveCastCandidate(candidate)) _boundaryRuleFor(candidate),
  ];
  if (rules.isEmpty) {
    return '';
  }
  return '非行动角色边界：${rules.join('；')}';
}

String noninteractiveCastViolationText(SceneBrief brief, String prose) {
  for (final candidate in brief.cast) {
    if (!isNoninteractiveCastCandidate(candidate)) continue;
    final violation = _findNoninteractiveViolation(candidate, prose);
    if (violation != null) {
      return '非行动角色边界违规：$violation';
    }
  }
  return '';
}

String _boundaryRuleFor(SceneCastCandidate candidate) {
  final mode = _normalized(candidate.metadata['roleplayMode']);
  final state = _normalized(
    candidate.metadata['lifeState'] ??
        candidate.metadata['state'] ??
        candidate.metadata['status'],
  );
  final label = [
    candidate.name,
    if (candidate.role.trim().isNotEmpty) '（${candidate.role.trim()}）',
  ].join();
  final basis = [
    if (mode.isNotEmpty) mode,
    if (state.isNotEmpty) state,
  ].join('/');
  return '$label${basis.isEmpty ? '' : '[$basis]'}不可主动行动、说话或产生即时心理描写；'
      '其身体、口腔、四肢、遗物或附着物也不可主动移动、喷吐、伸出、攻击；'
      '只能作为静态外观、既有痕迹、声纹记录、记忆、遗留物或他人观察对象出现';
}

String? _findNoninteractiveViolation(
  SceneCastCandidate candidate,
  String prose,
) {
  final name = candidate.name.trim();
  if (name.isEmpty || prose.trim().isEmpty) return null;
  final activeBodyPattern = RegExp(
    r'(嘴角|嘴唇|口腔|声带|骨线|身体|尸体|遗体|手|眼|头|脸|肌肉|四肢|附着物|遗物).{0,24}'
    r'(震颤|蠕动|渗出|激射|刺入|伸出|抓住|开口|张开|断裂|扩大|露出|振动|吐出|发出|攻击|扑向)',
  );
  for (final sentence in _sentences(prose)) {
    if (!sentence.contains(name)) continue;
    if (activeBodyPattern.hasMatch(sentence)) {
      return '${candidate.name}是非行动角色，但正文写成其遗体/附着物主动变化或攻击：'
          '${_compact(sentence, maxChars: 90)}';
    }
  }
  return null;
}

List<String> _sentences(String text) {
  return text
      .split(RegExp(r'[。！？!?\n]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

String _compact(String value, {required int maxChars}) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxChars) return normalized;
  return '${normalized.substring(0, maxChars - 3)}...';
}

bool _isFalse(Object? value) {
  if (value is bool) {
    return !value;
  }
  final normalized = _normalized(value);
  return const {
    'false',
    '0',
    'no',
    'off',
    '否',
    '不能',
    '不可',
  }.contains(normalized);
}

String _normalized(Object? value) {
  return value?.toString().trim().toLowerCase() ?? '';
}
