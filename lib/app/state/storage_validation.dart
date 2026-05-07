// ============================================================================
// Data Validation Layer — validates workspace data at storage boundaries.
// ============================================================================

enum ValidationSeverity { error, warning }

class ValidationError {
  const ValidationError({
    required this.field,
    required this.message,
    this.context,
    this.severity = ValidationSeverity.error,
    this.suggestion,
  });

  final String field;
  final String message;
  final String? context;
  final ValidationSeverity severity;

  /// Actionable fix instruction shown to the user alongside the error message.
  final String? suggestion;

  bool get isWarning => severity == ValidationSeverity.warning;

  bool get isError => severity == ValidationSeverity.error;

  @override
  String toString() {
    final prefix = context != null ? '$context.' : '';
    final severityTag = severity == ValidationSeverity.warning
        ? '[WARNING] '
        : '';
    final base = '$prefix$field: $severityTag$message';
    if (suggestion != null) {
      return '$base -> $suggestion';
    }
    return base;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationError &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          message == other.message &&
          context == other.context &&
          severity == other.severity &&
          suggestion == other.suggestion;

  @override
  int get hashCode =>
      Object.hash(field, message, context, severity, suggestion);
}

class ValidationResult {
  const ValidationResult._({required this.errors});

  final List<ValidationError> errors;

  bool get isValid => errors.isEmpty;

  bool get hasErrors => errors.any((e) => e.isError);

  bool get hasWarnings => errors.any((e) => e.isWarning);

  Iterable<ValidationError> get warnings => errors.where((e) => e.isWarning);

  Iterable<ValidationError> get errorsOnly => errors.where((e) => e.isError);

  factory ValidationResult.ok() => const ValidationResult._(errors: []);

  factory ValidationResult.fail(List<ValidationError> errors) =>
      ValidationResult._(errors: List.unmodifiable(errors));

  ValidationResult merge(ValidationResult other) {
    if (errors.isEmpty) return other;
    if (other.errors.isEmpty) return this;
    return ValidationResult._(errors: [...errors, ...other.errors]);
  }
}

class WorkspaceDataValidator {
  ValidationResult validateWorkspaceData(Map<String, Object?> data) {
    var result = _validateStructure(data);
    if (!result.isValid) return result;

    final projectIds = <String>{};
    final projects = (data['projects'] as List<Object?>?) ?? const [];
    for (var i = 0; i < projects.length; i++) {
      final entry = projects[i];
      if (entry is! Map) continue;
      final project = Map<String, Object?>.from(entry);
      final projectResult = _prefixErrors(
        validateProject(project),
        'projects[$i]',
      );
      result = result.merge(projectResult);
      final id = project['id']?.toString() ?? '';
      if (id.isNotEmpty) projectIds.add(id);
    }

    final sceneIds = _collectSceneIds(data['scenesByProject']);

    result = result.merge(
      _validateScopedCollection(
        data: data,
        key: 'charactersByProject',
        validator: (c) => validateCharacter(c, validSceneIds: sceneIds),
        validProjectIds: projectIds,
      ),
    );
    result = result.merge(
      _validateScopedCollection(
        data: data,
        key: 'scenesByProject',
        validator: validateScene,
        validProjectIds: projectIds,
      ),
    );
    result = result.merge(
      _validateScopedCollection(
        data: data,
        key: 'worldNodesByProject',
        validator: (n) => validateWorldNode(n, validSceneIds: sceneIds),
        validProjectIds: projectIds,
      ),
    );
    result = result.merge(
      _validateScopedCollection(
        data: data,
        key: 'auditIssuesByProject',
        validator: validateAuditIssue,
        validProjectIds: projectIds,
      ),
    );

    return result;
  }

  ValidationResult validateProject(Map<String, Object?> project) {
    final errors = <ValidationError>[];

    _requireNonEmpty(
      project['id'],
      'id',
      '项目 id 不能为空',
      errors,
      suggestion: '请确保项目在创建时自动生成了唯一 id',
    );
    _requireNonEmpty(
      project['sceneId'],
      'sceneId',
      '项目 sceneId 不能为空',
      errors,
      suggestion: '请在项目设置中关联一个初始场景',
    );
    _requireNonEmptyTrimmed(
      project['title'],
      'title',
      '项目 title 不能为空白',
      errors,
      suggestion: '请在项目设置中填写标题',
    );

    final ts = project['lastOpenedAtMs'];
    if (ts is! int || ts <= 0) {
      errors.add(
        const ValidationError(
          field: 'lastOpenedAtMs',
          message: 'lastOpenedAtMs 必须是正整数',
          suggestion: '请在打开项目时自动记录时间戳',
        ),
      );
    }

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult validateScene(Map<String, Object?> scene) {
    final errors = <ValidationError>[];

    _requireNonEmpty(
      scene['id'],
      'id',
      '场景 id 不能为空',
      errors,
      suggestion: '请确保场景在创建时自动生成了唯一 id',
    );
    _requireNonEmptyTrimmed(
      scene['title'],
      'title',
      '场景 title 不能为空白',
      errors,
      suggestion: '请在场景编辑中填写标题',
    );

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult validateCharacter(
    Map<String, Object?> character, {
    Set<String>? validSceneIds,
  }) {
    final errors = <ValidationError>[];

    _requireNonEmptyTrimmed(
      character['name'],
      'name',
      '角色 name 不能为空白',
      errors,
      suggestion: '请在角色编辑中填写名称',
    );

    _validateLinkedSceneIds(
      character['linkedSceneIds'],
      'linkedSceneIds',
      validSceneIds: validSceneIds,
      errors: errors,
    );

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult validateWorldNode(
    Map<String, Object?> node, {
    Set<String>? validSceneIds,
  }) {
    final errors = <ValidationError>[];

    _requireNonEmptyTrimmed(
      node['title'],
      'title',
      '世界节点 title 不能为空白',
      errors,
      suggestion: '请世界节点编辑中填写标题',
    );

    _validateLinkedSceneIds(
      node['linkedSceneIds'],
      'linkedSceneIds',
      validSceneIds: validSceneIds,
      errors: errors,
    );

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult validateAuditIssue(Map<String, Object?> issue) {
    final errors = <ValidationError>[];

    _requireNonEmptyTrimmed(
      issue['title'],
      'title',
      '问题检查 title 不能为空白',
      errors,
      suggestion: '请在问题检查编辑中填写标题',
    );

    final status = issue['status']?.toString();
    if (status != null &&
        status.isNotEmpty &&
        !const {'open', 'resolved', 'ignored'}.contains(status)) {
      errors.add(
        ValidationError(
          field: 'status',
          message: 'status 必须是 open/resolved/ignored 之一，实际值: $status',
          severity: ValidationSeverity.warning,
          suggestion: '请将 status 修改为 open、resolved 或 ignored',
        ),
      );
    }

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult validateStyleProfile(Map<String, Object?> profile) {
    final errors = <ValidationError>[];

    _requireNonEmptyTrimmed(
      profile['name'],
      'name',
      '风格配置 name 不能为空白',
      errors,
      suggestion: '请在风格配置编辑中填写名称',
    );

    final source = profile['source']?.toString();
    if (source != null &&
        source.isNotEmpty &&
        !const {'questionnaire', 'sample', 'custom'}.contains(source)) {
      errors.add(
        ValidationError(
          field: 'source',
          message: 'source 应为 questionnaire/sample/custom 之一，实际值: $source',
          severity: ValidationSeverity.warning,
          suggestion: '请将 source 修改为 questionnaire、sample 或 custom',
        ),
      );
    }

    final jsonData = profile['jsonData'];
    if (jsonData != null && jsonData is! Map) {
      errors.add(
        const ValidationError(
          field: 'jsonData',
          message: 'jsonData 必须是 Map 类型',
          suggestion: '请确保 jsonData 是一个有效的 JSON 对象（Map），而非字符串或其他类型',
        ),
      );
    }

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  ValidationResult _validateStructure(Map<String, Object?> data) {
    final errors = <ValidationError>[];
    const listKeys = ['projects'];
    const mapKeys = [
      'charactersByProject',
      'scenesByProject',
      'worldNodesByProject',
      'auditIssuesByProject',
      'projectStyles',
      'projectAuditStates',
    ];

    for (final key in listKeys) {
      final value = data[key];
      if (value != null && value is! List) {
        errors.add(
          ValidationError(
            field: key,
            message: '$key 必须是 List，实际类型: ${value.runtimeType}',
            suggestion: '请检查数据导入流程，确保 $key 以 JSON 数组格式存储',
          ),
        );
      }
    }

    for (final key in mapKeys) {
      final value = data[key];
      if (value != null && value is! Map) {
        errors.add(
          ValidationError(
            field: key,
            message: '$key 必须是 Map，实际类型: ${value.runtimeType}',
            suggestion: '请检查数据导入流程，确保 $key 以 JSON 对象格式存储',
          ),
        );
      }
    }

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult _validateScopedCollection({
    required Map<String, Object?> data,
    required String key,
    required ValidationResult Function(Map<String, Object?>) validator,
    required Set<String> validProjectIds,
  }) {
    final raw = data[key];
    if (raw is! Map) return ValidationResult.ok();

    var result = ValidationResult.ok();
    final scoped = Map<Object?, Object?>.from(raw);

    for (final entry in scoped.entries) {
      final projectId = entry.key.toString();
      if (validProjectIds.isNotEmpty && !validProjectIds.contains(projectId)) {
        result = result.merge(
          ValidationResult.fail([
            ValidationError(
              field: key,
              message: '引用了不存在的项目 id: $projectId',
              context: key,
              suggestion: '请先创建该项目，或移除 $key 中对该项目 id 的引用',
            ),
          ]),
        );
        continue;
      }

      final items = entry.value;
      if (items is! List) continue;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) continue;
        final itemResult = validator(Map<String, Object?>.from(item));
        for (final error in itemResult.errors) {
          result = result.merge(
            ValidationResult.fail([
              ValidationError(
                field: error.field,
                message: error.message,
                context: '$key.$projectId[$i]',
                severity: error.severity,
                suggestion: error.suggestion,
              ),
            ]),
          );
        }
      }
    }

    return result;
  }

  Set<String> _collectSceneIds(Object? raw) {
    if (raw is! Map) return const {};
    final ids = <String>{};
    for (final entry in raw.entries) {
      final items = entry.value;
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map) continue;
        final id = item['id']?.toString() ?? '';
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  }

  void _validateLinkedSceneIds(
    Object? value,
    String field, {
    Set<String>? validSceneIds,
    required List<ValidationError> errors,
  }) {
    if (value == null) return;
    if (value is! List) {
      errors.add(
        ValidationError(
          field: field,
          message: '$field 必须是 List 类型',
          suggestion: '请确保 $field 以 JSON 数组格式存储场景 id 列表',
        ),
      );
      return;
    }
    for (var i = 0; i < value.length; i++) {
      final item = value[i]?.toString().trim() ?? '';
      if (item.isEmpty) {
        errors.add(
          ValidationError(
            field: '$field[$i]',
            message: '$field[$i] 不能为空字符串',
            suggestion: '请移除空字符串引用或替换为有效的场景 id',
          ),
        );
        continue;
      }
      if (validSceneIds != null &&
          validSceneIds.isNotEmpty &&
          !validSceneIds.contains(item)) {
        errors.add(
          ValidationError(
            field: '$field[$i]',
            message: '引用了不存在的场景 id: $item',
            severity: ValidationSeverity.warning,
            suggestion: '请先在场景管理中创建该场景，或移除对该场景的引用',
          ),
        );
      }
    }
  }

  void _requireNonEmpty(
    Object? value,
    String field,
    String message,
    List<ValidationError> errors, {
    String? suggestion,
  }) {
    final str = value?.toString();
    if (str == null || str.isEmpty) {
      errors.add(
        ValidationError(field: field, message: message, suggestion: suggestion),
      );
    }
  }

  void _requireNonEmptyTrimmed(
    Object? value,
    String field,
    String message,
    List<ValidationError> errors, {
    String? suggestion,
  }) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty) {
      errors.add(
        ValidationError(field: field, message: message, suggestion: suggestion),
      );
    }
  }

  ValidationResult _prefixErrors(ValidationResult source, String context) {
    if (source.isValid) return source;
    return ValidationResult.fail([
      for (final error in source.errors)
        ValidationError(
          field: error.field,
          message: error.message,
          context: context,
          severity: error.severity,
          suggestion: error.suggestion,
        ),
    ]);
  }
}
