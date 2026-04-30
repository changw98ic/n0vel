import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_formatter_trace.dart';

class FileAppLlmCallTraceSink implements AppLlmCallTraceSink {
  FileAppLlmCallTraceSink(this.file);

  final File file;

  @override
  Future<void> record(AppLlmCallTraceEntry entry) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

class FileStoryGenerationFormatterTraceSink
    implements StoryGenerationFormatterTraceSink {
  FileStoryGenerationFormatterTraceSink(this.file);

  final File file;

  @override
  Future<void> record(StoryGenerationFormatterTraceEntry entry) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}
