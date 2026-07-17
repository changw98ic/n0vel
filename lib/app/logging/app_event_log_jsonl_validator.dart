import 'dart:convert';
import 'dart:io';

/// Result of validating a single JSONL file.
class JsonlValidationResult {
  const JsonlValidationResult({
    required this.filePath,
    required this.totalLines,
    required this.validLines,
    required this.corruptedLines,
    required this.corruptedLineNumbers,
  });

  final String filePath;
  final int totalLines;
  final int validLines;
  final int corruptedLines;
  final List<int> corruptedLineNumbers;

  bool get isClean => corruptedLines == 0;

  @override
  String toString() =>
      'JsonlValidationResult($filePath: $validLines/$totalLines valid, '
      '$corruptedLines corrupted)';
}

/// Status summary for a JSONL file on disk.
class JsonlFileStatus {
  const JsonlFileStatus({
    required this.file,
    required this.sizeBytes,
    required this.validation,
  });

  final File file;
  final int sizeBytes;
  final JsonlValidationResult? validation;
}

/// Validates and repairs JSONL log files produced by [IoAppEventLogStorage].
///
/// Each line is expected to be in one of two formats:
/// - Length-prefixed: `<byteLength>|<json>\n`
/// - Plain (legacy):  `<json>\n`
///
/// A line is considered *valid* when:
/// 1. The line is non-empty.
/// 2. If it starts with digits followed by `|`, the declared byte length
///    matches the actual JSON payload length **and** the payload is valid JSON.
/// 3. Otherwise, the entire line (trimmed) must be valid JSON.
class JsonlValidator {
  JsonlValidator._();

  /// Validate a single JSONL file.
  static JsonlValidationResult validateFile(File file) {
    final corruptedLineNumbers = <int>[];
    var validLines = 0;
    var totalLines = 0;

    final lines = _readLinesSync(file);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      totalLines++;
      if (_isValidLine(line)) {
        validLines++;
      } else {
        corruptedLineNumbers.add(i + 1); // 1-indexed for readability.
      }
    }

    return JsonlValidationResult(
      filePath: file.path,
      totalLines: totalLines,
      validLines: validLines,
      corruptedLines: corruptedLineNumbers.length,
      corruptedLineNumbers: corruptedLineNumbers,
    );
  }

  /// Attempt to repair a JSONL file by removing corrupted lines.
  ///
  /// The repair writes a temporary file, validates it, then atomically
  /// renames it over the original. If the repair fails partway through,
  /// the original file is left untouched.
  static Future<void> repairFile(File file) async {
    if (!await file.exists()) return;

    final lines = _readLinesSync(file);
    final validLines = <String>[];
    for (final line in lines) {
      if (line.isNotEmpty && _isValidLine(line)) {
        validLines.add(line);
      }
    }

    // Write to a temp file in the same directory, then rename.
    final tmpPath = '${file.path}.tmp-repair';
    final tmpFile = File(tmpPath);
    final sink = tmpFile.openWrite()
      ..writeAll(validLines, '\n')
      ..write('\n');
    await sink.flush();
    await sink.close();

    // Verify the temp file is itself clean before replacing.
    final check = validateFile(tmpFile);
    if (check.corruptedLines > 0) {
      // Should never happen, but be defensive.
      await tmpFile.delete();
      return;
    }

    await tmpFile.rename(file.path);
  }

  /// Audit all JSONL files in a directory.
  static Future<List<JsonlFileStatus>> auditDirectory(Directory dir) async {
    if (!await dir.exists()) return const [];

    final results = <JsonlFileStatus>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.jsonl')) continue;

      final stat = await entity.stat();
      final validation = validateFile(entity);
      results.add(
        JsonlFileStatus(
          file: entity,
          sizeBytes: stat.size,
          validation: validation,
        ),
      );
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Read all lines from a file synchronously.
  /// Returns lines without trailing newlines.
  static List<String> _readLinesSync(File file) {
    if (!file.existsSync()) return const [];
    return file.readAsLinesSync();
  }

  /// Check if a single line is a valid JSONL record.
  static bool _isValidLine(String line) {
    if (line.isEmpty) return false;

    // Try length-prefixed format: "<len>|<json>"
    final pipeIdx = line.indexOf('|');
    if (pipeIdx > 0) {
      final prefix = line.substring(0, pipeIdx);
      final declaredLength = int.tryParse(prefix);
      if (declaredLength != null) {
        final payload = line.substring(pipeIdx + 1);
        final payloadBytes = utf8.encode(payload);
        if (payloadBytes.length != declaredLength) {
          return false;
        }
        return _isValidJson(payload);
      }
    }

    // Fallback: plain JSON line (legacy / non-prefixed).
    return _isValidJson(line);
  }

  static bool _isValidJson(String text) {
    try {
      jsonDecode(text);
      return true;
    } catch (_) {
      return false;
    }
  }
}
