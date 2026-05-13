import '../../../domain/workspace_models.dart';
import '../../../app/state/app_version_store.dart';
import '../../../app/state/story_outline_store.dart';

enum StandardExportFormat { markdown, plainText, html, json }

enum StandardExportMode { fullProject, manuscript, finalDraft }

extension StandardExportModeX on StandardExportMode {
  bool get isManuscriptDelivery =>
      this == StandardExportMode.manuscript ||
      this == StandardExportMode.finalDraft;
}

class StandardExportInput {
  const StandardExportInput({
    required this.project,
    required this.characters,
    required this.scenes,
    required this.worldNodes,
    this.draftText = '',
    this.versionEntries = const [],
    this.outline,
    this.mode = StandardExportMode.fullProject,
  });

  final ProjectRecord project;
  final List<CharacterRecord> characters;
  final List<SceneRecord> scenes;
  final List<WorldNodeRecord> worldNodes;
  final String draftText;
  final List<VersionEntry> versionEntries;
  final StoryOutlineSnapshot? outline;
  final StandardExportMode mode;
}

String? markdownHeadingTitle(String line) {
  final trimmedLeft = line.trimLeft();
  var marks = 0;
  while (marks < trimmedLeft.length &&
      marks < 3 &&
      trimmedLeft.codeUnitAt(marks) == 0x23) {
    marks++;
  }
  if (marks == 0 ||
      marks >= trimmedLeft.length ||
      !isWhitespaceCodeUnit(trimmedLeft.codeUnitAt(marks))) {
    return null;
  }
  final title = trimmedLeft.substring(marks).trim();
  return title.isEmpty ? null : title;
}

bool lineMatchesChapterTitle(String line, String title) {
  var candidate = line.trim();
  var marks = 0;
  while (marks < candidate.length &&
      marks < 3 &&
      candidate.codeUnitAt(marks) == 0x23) {
    marks++;
  }
  if (marks > 0) {
    candidate = candidate.substring(marks).trim();
  }
  return candidate == title;
}

Iterable<String> splitParagraphs(String text) sync* {
  final buffer = StringBuffer();
  for (final line in text.split('\n')) {
    if (line.trim().isEmpty) {
      final paragraph = buffer.toString().trim();
      if (paragraph.isNotEmpty) {
        yield paragraph;
      }
      buffer.clear();
    } else {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.write(line);
    }
  }

  final paragraph = buffer.toString().trim();
  if (paragraph.isNotEmpty) {
    yield paragraph;
  }
}

String removeWhitespace(String value) {
  final buffer = StringBuffer();
  for (final codeUnit in value.codeUnits) {
    if (!isWhitespaceCodeUnit(codeUnit)) {
      buffer.writeCharCode(codeUnit);
    }
  }
  return buffer.toString();
}

bool isWhitespaceCodeUnit(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x0B ||
      codeUnit == 0x0C;
}
