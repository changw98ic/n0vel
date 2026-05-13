import 'package:novel_writer/app/state/app_storage_clone.dart';
import 'story_generation_models.dart';
import 'story_prompt_templates.dart';

part 'character_cognition_models.dart';
part 'knowledge_pipeline_models.dart';
part 'roleplay_turn_output.dart';
part 'scene_director_models.dart';
part 'scene_task_card.dart';
part 'scene_beat_models.dart';
part 'scene_pipeline_output.dart';

// ---------------------------------------------------------------------------
// Helpers (shared with story_generation_models.dart pattern)
// ---------------------------------------------------------------------------

List<T> _immutableList<T>(List<T> items) => List<T>.unmodifiable(items);

Map<String, Object?> _immutableMap(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in cloneStorageMap(value).entries)
        entry.key: _immutableValue(entry.value),
    });

Object? _immutableValue(Object? value) {
  if (value is Map<String, Object?>) return _immutableMap(value);
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _immutableValue(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable([
      for (final item in value) _immutableValue(item),
    ]);
  }
  return value;
}
