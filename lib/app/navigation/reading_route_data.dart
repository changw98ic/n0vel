class ReadingSceneDocument {
  const ReadingSceneDocument({
    required this.sceneId,
    required this.locationLabel,
    required this.text,
  });

  final String sceneId;
  final String locationLabel;
  final String text;
}

class ReadingSessionData {
  const ReadingSessionData({
    required this.projectTitle,
    required this.initialSceneId,
    required this.documents,
  });

  final String projectTitle;
  final String initialSceneId;
  final List<ReadingSceneDocument> documents;

  String get signature => [
    projectTitle,
    initialSceneId,
    for (final document in documents)
      '${document.sceneId}:${document.locationLabel}:${document.text}',
  ].join('|');
}
