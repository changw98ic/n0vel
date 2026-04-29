import 'story_generation_models.dart';

String compactText(String value, {required int maxChars}) {
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return '${normalized.substring(0, maxChars - 3)}...';
}

String characterAnchorsText(List<CharacterProfile> profiles) {
  if (profiles.isEmpty) return '';
  final buffer = StringBuffer();
  for (final profile in profiles) {
    buffer.writeln('${profile.name}（${profile.role}）');
    if (profile.coreDrives.isNotEmpty) {
      buffer.writeln('  核心驱动：${profile.coreDrives.take(3).join('；')}');
    }
    if (profile.fears.isNotEmpty) {
      buffer.writeln('  恐惧：${profile.fears.take(2).join('；')}');
    }
    if (profile.values.isNotEmpty) {
      buffer.writeln('  价值观：${profile.values.take(2).join('；')}');
    }
    if (profile.speechTraits.isNotEmpty) {
      buffer.writeln('  语言特征：${profile.speechTraits.take(3).join('；')}');
    }
    if (profile.boundaries.isNotEmpty) {
      buffer.writeln('  禁忌：${profile.boundaries.take(2).join('；')}');
    }
  }
  return buffer.toString().trimRight();
}
