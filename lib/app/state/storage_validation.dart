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
  });

  final String field;
  final String message;
  final String? context;
  final ValidationSeverity severity;

  bool get isWarning => severity == ValidationSeverity.warning;

  bool get isError => severity == ValidationSeverity.error;

  @override
  String toString() {
    final prefix = context != null ? '$context.' : '';
    if (severity == ValidationSeverity.warning) {
      return '$prefix$field: [WARNING] $message';
    }
    return '$prefix$field: $message';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationError &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          message == other.message &&
          context == other.context &&
          severity == other.severity;

  @override
  int get hashCode => Object.hash(field, message, context, severity);
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
    );
    _requireNonEmpty(
      project['sceneId'],
      'sceneId',
      '项目 sceneId 不能为空',
      errors,
    );
    _requireNonEmptyTrimmed(
      project['title'],
      'title',
      '项目 title 不能为空白',
      errors,
    );

    final ts = project['lastOpenedAtMs'];
    if (ts is! int || ts <= 0) {
      errors.add(const ValidationError(
        field: 'lastOpenedAtMs',
        message: 'lastOpenedAtMs 必须是正整数',
      ));
    }

    return errors.isEmpty
        ? ValidationResult.ok()
        : ValidationResult.fail(errors);
  }

  ValidationResult validateScene(Map<String, Object?> scene) {
    final errors = <ValidationError>[];

    _requireNonEmpty(scene['id'], 'id', '场景 id 不能为空', errors);
    _requireNonEmptyTrimmed(
      scene['title'],
      'title',
      '场景 title 不能为空白',
      errors,
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
      '审计问题 title 不能为空白',
      errors,
    );

    final status = issue['status']?.toString();
    if (status != null &&
        status.isNotEmpty &&
        !const {'open', 'resolved', 'ignored'}.contains(status)) {
      errors.add(ValidationError(
        field: 'status',
        message: 'status 必须是 open/resolved/ignored 之一，实际值: $status',
        severity: ValidationSeverity.warning,
      ));
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
    );

    final source = profile['source']?.toString();
    if (source != null &&
        source.isNotEmpty &&
        !const {'questionnaire', 'sample', 'custom'}.contains(source)) {
      errors.add(ValidationError(
        field: 'source',
        message: 'source 应为 questionnaire/sample/custom 之一，实际值: $source',
        severity: ValidationSeverity.warning,
      ));
    }

    final jsonData = profile['jsonData'];
    if (jsonData != null && jsonData is! Map) {
      errors.add(const ValidationError(
        field: 'jsonData',
        message: 'jsonData 必须是 Map 类型',
      ));
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
        errors.add(ValidationError(
          field: key,
          message: '$key 必须是 List，实际类型: ${value.runtimeType}',
        ));
      }
    }

    for (final key in mapKeys) {
      final value = data[key];
      if (value != null && value is! Map) {
        errors.add(ValidationError(
          field: key,
          message: '$key 必须是 Map，实际类型: ${value.runtimeType}',
        ));
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
        result = result.merge(ValidationResult.fail([
          ValidationError(
            field: key,
            message: '引用了不存在的项目 id: $projectId',
            context: key,
          ),
        ]));
        continue;
      }

      final items = entry.value;
      if (items is! List) continue;

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item is! Map) continue;
        final itemResult = validator(Map<String, Object?>.from(item));
        for (final error in itemResult.errors) {
          result = result.merge(ValidationResult.fail([
            ValidationError(
              field: error.field,
              message: error.message,
              context: '$key.$projectId[$i]',
              severity: error.severity,
            ),
          ]));
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
      errors.add(ValidationError(
        field: field,
        message: '$field 必须是 List 类型',
      ));
      return;
    }
    for (var i = 0; i < value.length; i++) {
      final item = value[i]?.toString().trim() ?? '';
      if (item.isEmpty) {
        errors.add(ValidationError(
          field: '$field[$i]',
          message: '$field[$i] 不能为空字符串',
        ));
        continue;
      }
      if (validSceneIds != null &&
          validSceneIds.isNotEmpty &&
          !validSceneIds.contains(item)) {
        errors.add(ValidationError(
          field: '$field[$i]',
          message: '引用了不存在的场景 id: $item',
          severity: ValidationSeverity.warning,
        ));
      }
    }
  }

  void _requireNonEmpty(
    Object? value,
    String field,
    String message,
    List<ValidationError> errors,
  ) {
    final str = value?.toString();
    if (str == null || str.isEmpty) {
      errors.add(ValidationError(field: field, message: message));
    }
  }

  void _requireNonEmptyTrimmed(
    Object? value,
    String field,
    String message,
    List<ValidationError> errors,
  ) {
    final str = value?.toString().trim();
    if (str == null || str.isEmpty) {
      errors.add(ValidationError(field: field, message: message));
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
        ),
    ]);
  }
}
