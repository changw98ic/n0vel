class SceneLocationParts {
  const SceneLocationParts({
    required this.rawLabel,
    required this.chapterLabel,
    required this.sceneLabel,
    required this.title,
  });

  final String rawLabel;
  final String chapterLabel;
  final String sceneLabel;
  final String title;

  static final RegExp _chapterNumberPattern = RegExp(r'第\s*(\d+)\s*章');
  static final RegExp _sceneNumberPattern = RegExp(r'场景\s*0*(\d+)');

  int? get chapterNumber => int.tryParse(
    _chapterNumberPattern.firstMatch(chapterLabel)?.group(1) ?? '',
  );

  int? get sceneNumber =>
      int.tryParse(_sceneNumberPattern.firstMatch(sceneLabel)?.group(1) ?? '');

  String get fullLabel {
    if (sceneLabel.isEmpty) {
      return chapterLabel;
    }
    return '$chapterLabel / $sceneLabel';
  }

  String get chapterLocation {
    if (title.isEmpty) {
      return chapterLabel;
    }
    return '$chapterLabel · $title';
  }

  static SceneLocationParts fromLocation(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) {
      return fromLabel('');
    }
    final parts = trimmed.split('·');
    final labelParts = fromLabel(parts.first);
    final title = parts.length < 2 ? '' : parts.sublist(1).join('·').trim();
    return SceneLocationParts(
      rawLabel: labelParts.rawLabel,
      chapterLabel: labelParts.chapterLabel,
      sceneLabel: labelParts.sceneLabel,
      title: title,
    );
  }

  static SceneLocationParts fromLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return const SceneLocationParts(
        rawLabel: '',
        chapterLabel: '',
        sceneLabel: '',
        title: '',
      );
    }
    final slashIndex = trimmed.indexOf('/');
    if (slashIndex < 0) {
      return SceneLocationParts(
        rawLabel: trimmed,
        chapterLabel: trimmed,
        sceneLabel: '',
        title: '',
      );
    }
    final chapter = trimmed.substring(0, slashIndex).trim();
    final scene = trimmed.substring(slashIndex + 1).trim();
    return SceneLocationParts(
      rawLabel: trimmed,
      chapterLabel: chapter.isEmpty ? trimmed : chapter,
      sceneLabel: scene,
      title: '',
    );
  }

  static int? firstSceneNumberIn(String text) =>
      int.tryParse(_sceneNumberPattern.firstMatch(text)?.group(1) ?? '');
}

String chapterLocationLabel(String location) {
  return SceneLocationParts.fromLocation(location).chapterLocation;
}

String chapterLabelOnly(String label) {
  return SceneLocationParts.fromLabel(label).chapterLabel;
}
