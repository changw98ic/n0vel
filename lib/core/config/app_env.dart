import 'dart:io';

class AppEnv {
  AppEnv._();

  static const String _defaultEndpoint = 'https://ollama.com/v1';
  static const String _defaultModel = 'glm-5.1';
  static const String _defaultApiKey =
      '3750c7c11d5c4b47b41151ab74fbfa5d.z6BJ1aaV317ecl7LhlMuVj3q';
  static const String _defaultDbPath =
      'C:/Users/changw98/Documents/writing_assistant.db';

  static final Map<String, String> _values = <String, String>{};
  static bool _loaded = false;

  static Future<void> load({String fileName = '.env'}) async {
    if (_loaded) {
      return;
    }
    final file = _findEnvFile(fileName);
    if (file != null) {
      _parse(await file.readAsString());
    }
    _loaded = true;
  }

  static void ensureLoadedSync({String fileName = '.env'}) {
    if (_loaded) {
      return;
    }
    final file = _findEnvFile(fileName);
    if (file != null) {
      _parse(file.readAsStringSync());
    }
    _loaded = true;
  }

  static String? get(String key) {
    ensureLoadedSync();
    final value = _values[key];
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static String get localEndpoint =>
      get('WUCHANG_ENDPOINT') ?? get('TEST_AI_ENDPOINT') ?? _defaultEndpoint;

  static String get localModelName =>
      get('WUCHANG_MODEL') ?? get('TEST_AI_MODEL') ?? _defaultModel;

  static String get localApiKey =>
      get('WUCHANG_API_KEY') ?? get('TEST_AI_API_KEY') ?? _defaultApiKey;

  static String get testAiEndpoint =>
      get('TEST_AI_ENDPOINT') ?? get('WUCHANG_ENDPOINT') ?? _defaultEndpoint;

  static String get testAiModel =>
      get('TEST_AI_MODEL') ?? get('WUCHANG_MODEL') ?? _defaultModel;

  static String get testAiApiKey =>
      get('TEST_AI_API_KEY') ?? get('WUCHANG_API_KEY') ?? _defaultApiKey;

  static String get testDbPath => get('TEST_DB_PATH') ?? _defaultDbPath;

  static int get wuchangStartChapter =>
      int.tryParse(get('WUCHANG_START_CHAPTER') ?? '') ?? 1;

  static int get wuchangEndChapter =>
      int.tryParse(get('WUCHANG_END_CHAPTER') ?? '') ?? 30;

  static bool get wuchangResumeImport =>
      (get('WUCHANG_RESUME_IMPORT') ?? '').toLowerCase() == 'true';

  static void _parse(String content) {
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final normalizedLine =
          line.startsWith('export ') ? line.substring(7).trim() : line;
      final separatorIndex = normalizedLine.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      final key = normalizedLine.substring(0, separatorIndex).trim();
      if (key.isEmpty) {
        continue;
      }

      var value = normalizedLine.substring(separatorIndex + 1).trim();
      if (value.length >= 2) {
        final quote = value[0];
        if ((quote == '"' || quote == "'") && value.endsWith(quote)) {
          value = value.substring(1, value.length - 1);
        }
      }

      _values[key] = value;
    }
  }

  static File? _findEnvFile(String fileName) {
    final visited = <String>{};
    for (final start in _candidateDirectories()) {
      var current = start;
      while (visited.add(current.path)) {
        final candidate = File(
          '${current.path}${Platform.pathSeparator}$fileName',
        );
        if (candidate.existsSync()) {
          return candidate;
        }

        final parent = current.parent;
        if (parent.path == current.path) {
          break;
        }
        current = parent;
      }
    }
    return null;
  }

  static Iterable<Directory> _candidateDirectories() sync* {
    yield Directory.current;

    final executableDir = File(Platform.resolvedExecutable).parent;
    if (executableDir.path != Directory.current.path) {
      yield executableDir;
    }
  }
}
