import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../domain/pov_models.dart';
import '../../../core/database/database.dart';

/// POV 任务仓库（内存存储）
class POVRepository {
  final AppDatabase _db;
  final Map<String, POVTask> _tasks = {};
  final Uuid _uuid = const Uuid();

  POVRepository(this._db);

  /// 创建任务
  Future<POVTask> createTask({
    required String workId,
    required String chapterId,
    required String characterId,
    required String originalContent,
    required POVConfig config,
  }) async {
    final id = 'pov_${DateTime.now().millisecondsSinceEpoch}';

    final task = POVTask(
      id: id,
      workId: workId,
      chapterId: chapterId,
      characterId: characterId,
      originalContent: originalContent,
      config: config,
      status: POVTaskStatus.pending,
      createdAt: DateTime.now(),
    );

    _tasks[id] = task;
    return task;
  }

  /// 获取任务
  Future<POVTask?> getTask(String id) async {
    return _tasks[id];
  }

  /// 获取作品的所有任务
  Future<List<POVTask>> getTasksByWork(String workId) async {
    return _tasks.values.where((t) => t.workId == workId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 获取章节的所有任务
  Future<List<POVTask>> getTasksByChapter(String chapterId) async {
    return _tasks.values.where((t) => t.chapterId == chapterId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// 更新任务
  Future<void> updateTask(POVTask task) async {
    _tasks[task.id] = task;
  }

  /// 删除任务
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }

  /// 取消任务
  Future<POVTask?> cancelTask(String id) async {
    final task = _tasks[id];
    if (task != null &&
        (task.status == POVTaskStatus.pending ||
            task.status == POVTaskStatus.analyzing ||
            task.status == POVTaskStatus.generating)) {
      final cancelledTask = task.copyWith(status: POVTaskStatus.cancelled);
      _tasks[id] = cancelledTask;
      return cancelledTask;
    }
    return task;
  }

  /// 清理已完成的任务
  Future<void> clearCompletedTasks({int keepLast = 10}) async {
    final completed =
        _tasks.entries
            .where(
              (e) =>
                  e.value.status == POVTaskStatus.completed ||
                  e.value.status == POVTaskStatus.failed ||
                  e.value.status == POVTaskStatus.cancelled,
            )
            .toList()
          ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));

    // 保留最近的 N 个
    final toRemove = completed.skip(keepLast);
    for (final entry in toRemove) {
      _tasks.remove(entry.key);
    }
  }

  // ========== POV 模板 CRUD 操作 ==========

  /// 创建模板
  Future<POVTemplate> createTemplate({
    required String name,
    required String description,
    required POVConfig config,
    String? workId,
    List<String>? suitableCharacterTypes,
    String? exampleOutput,
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final record = POVTemplateRecordsCompanion.insert(
      id: id,
      name: name,
      description: description,
      mode: config.mode.name,
      style: config.style.name,
      keepDialogue: Value(config.keepDialogue),
      addInnerThoughts: Value(config.addInnerThoughts),
      expandObservations: Value(config.expandObservations),
      emotionalIntensity: Value(config.emotionalIntensity),
      useCharacterVoice: Value(config.useCharacterVoice),
      customInstructions: Value(config.customInstructions),
      targetWordCount: Value(config.targetWordCount),
      suitableCharacterTypes: Value(
        suitableCharacterTypes != null
            ? jsonEncode(suitableCharacterTypes)
            : null,
      ),
      exampleOutput: Value(exampleOutput),
      isBuiltIn: const Value(false),
      sortOrder: Value(sortOrder),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.pOVTemplateRecords).insert(record);
    return getTemplateById(id)!;
  }

  /// 获取所有模板（内置 + 用户自定义）
  Future<List<POVTemplate>> getAllTemplates({String? workId}) async {
    // 获取内置模板
    final builtIn = _builtInTemplates;

    // 获取用户自定义模板
    final customTemplates =
        await (_db.select(_db.pOVTemplateRecords)
              ..where(
                (t) => workId == null
                    ? t.workId.isNull()
                    : t.workId.equals(workId) | t.workId.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();

    final custom = customTemplates.map(_recordToTemplate).toList();

    return [...builtIn, ...custom];
  }

  /// 根据ID获取模板
  POVTemplate? getTemplateById(String id) {
    // 检查是否是内置模板
    final builtIn = _builtInTemplates.where((t) => t.id == id).firstOrNull;
    if (builtIn != null) return builtIn;

    // 从数据库查询（需要异步，这里返回null表示需要异步查询）
    return null;
  }

  /// 异步根据ID获取模板
  Future<POVTemplate?> getTemplateByIdAsync(String id) async {
    // 检查是否是内置模板
    final builtIn = _builtInTemplates.where((t) => t.id == id).firstOrNull;
    if (builtIn != null) return builtIn;

    // 从数据库查询
    final record =
        await (_db.select(_db.pOVTemplateRecords)
              ..where((t) => t.id.equals(id))
              ..limit(1))
            .get();

    if (record.isEmpty) return null;
    return _recordToTemplate(record.first);
  }

  /// 更新模板
  Future<void> updateTemplate(POVTemplate template) async {
    if (template.isBuiltIn) {
      throw ArgumentError('Cannot update built-in templates');
    }

    final now = DateTime.now();
    await (_db.update(
      _db.pOVTemplateRecords,
    )..where((t) => t.id.equals(template.id))).write(
      POVTemplateRecordsCompanion(
        name: Value(template.name),
        description: Value(template.description),
        mode: Value(template.config.mode.name),
        style: Value(template.config.style.name),
        keepDialogue: Value(template.config.keepDialogue),
        addInnerThoughts: Value(template.config.addInnerThoughts),
        expandObservations: Value(template.config.expandObservations),
        emotionalIntensity: Value(template.config.emotionalIntensity),
        useCharacterVoice: Value(template.config.useCharacterVoice),
        customInstructions: Value(template.config.customInstructions),
        targetWordCount: Value(template.config.targetWordCount),
        suitableCharacterTypes: Value(
          template.suitableCharacterTypes.isNotEmpty
              ? jsonEncode(template.suitableCharacterTypes)
              : null,
        ),
        exampleOutput: Value(template.exampleOutput),
        updatedAt: Value(now),
      ),
    );
  }

  /// 删除模板
  Future<void> deleteTemplate(String id) async {
    // 不允许删除内置模板
    final builtIn = _builtInTemplates.where((t) => t.id == id).firstOrNull;
    if (builtIn != null) {
      throw ArgumentError('Cannot delete built-in templates');
    }

    await (_db.delete(
      _db.pOVTemplateRecords,
    )..where((t) => t.id.equals(id))).go();
  }

  /// 复制模板
  Future<POVTemplate> duplicateTemplate(String id, {String? workId}) async {
    final template = await getTemplateByIdAsync(id);
    if (template == null) {
      throw ArgumentError('Template not found: $id');
    }

    return createTemplate(
      name: '${template.name} (副本)',
      description: template.description,
      config: template.config,
      workId: workId,
      suitableCharacterTypes: template.suitableCharacterTypes,
      exampleOutput: template.exampleOutput,
    );
  }

  /// 将数据库记录转换为 POVTemplate
  POVTemplate _recordToTemplate(POVTemplateRecord record) {
    List<String>? suitableTypes;
    if (record.suitableCharacterTypes != null) {
      try {
        suitableTypes = List<String>.from(
          jsonDecode(record.suitableCharacterTypes!),
        );
      } catch (_) {
        suitableTypes = [];
      }
    }

    return POVTemplate(
      id: record.id,
      name: record.name,
      description: record.description,
      config: POVConfig(
        mode: POVMode.values.firstWhere(
          (e) => e.name == record.mode,
          orElse: () => POVMode.rewrite,
        ),
        style: POVStyle.values.firstWhere(
          (e) => e.name == record.style,
          orElse: () => POVStyle.firstPerson,
        ),
        keepDialogue: record.keepDialogue,
        addInnerThoughts: record.addInnerThoughts,
        expandObservations: record.expandObservations,
        emotionalIntensity: record.emotionalIntensity,
        useCharacterVoice: record.useCharacterVoice,
        customInstructions: record.customInstructions,
        targetWordCount: record.targetWordCount,
      ),
      suitableCharacterTypes: suitableTypes ?? [],
      exampleOutput: record.exampleOutput,
      isBuiltIn: record.isBuiltIn,
    );
  }
}

/// 内置 POV 模板
final _builtInTemplates = <POVTemplate>[
  POVTemplate(
    id: 'first_person_standard',
    name: '标准第一人称',
    description: '使用第一人称完整重写，保留原有情节',
    config: const POVConfig(
      mode: POVMode.rewrite,
      style: POVStyle.firstPerson,
      keepDialogue: true,
      addInnerThoughts: true,
      expandObservations: true,
    ),
    isBuiltIn: true,
  ),
  POVTemplate(
    id: 'third_person_limited',
    name: '第三人称限知',
    description: '使用第三人称限知视角重写',
    config: const POVConfig(
      mode: POVMode.rewrite,
      style: POVStyle.thirdPersonLimited,
      keepDialogue: true,
      addInnerThoughts: true,
      expandObservations: false,
    ),
    isBuiltIn: true,
  ),
];
