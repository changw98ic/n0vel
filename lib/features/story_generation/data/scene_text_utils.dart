import 'story_generation_models.dart';

String compactText(String value, {required int maxChars}) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return '${normalized.substring(0, maxChars - 3)}...';
}

String characterAnchorsText(List<StructuredProfile> profiles) {
  if (profiles.isEmpty) return '';
  final buffer = StringBuffer();
  for (final profile in profiles) {
    final role = profile.metadata['role']?.toString();
    if (role != null && role.isNotEmpty) {
      buffer.writeln('${profile.name}（$role）');
    } else {
      buffer.writeln(profile.name);
    }
    if (profile.backstory.isNotEmpty) {
      buffer.writeln('  背景：${profile.backstory}');
    }
    if (profile.behaviorBounds.mandatoryResponses.isNotEmpty) {
      buffer.writeln(
        '  必须回应：${profile.behaviorBounds.mandatoryResponses.take(3).join('；')}',
      );
    }
    if (profile.behaviorBounds.forbiddenActions.isNotEmpty) {
      buffer.writeln(
        '  禁忌：${profile.behaviorBounds.forbiddenActions.take(3).join('；')}',
      );
    }
    if (profile.voicePrint.speakingPatterns.isNotEmpty) {
      buffer.writeln(
        '  语言特征：${profile.voicePrint.speakingPatterns.take(3).join('；')}',
      );
    }
    if (profile.voicePrint.catchphrases.isNotEmpty) {
      buffer.writeln(
        '  口头禅：${profile.voicePrint.catchphrases.take(3).join('；')}',
      );
    }
    if (profile.soul.identityAnchors.isNotEmpty) {
      buffer.writeln(
        '  身份锚点：${profile.soul.identityAnchors.take(3).join('；')}',
      );
    }
    if (profile.soul.coreValues.isNotEmpty) {
      buffer.writeln('  核心价值：${profile.soul.coreValues.take(3).join('；')}');
    }
  }
  return buffer.toString().trimRight();
}
