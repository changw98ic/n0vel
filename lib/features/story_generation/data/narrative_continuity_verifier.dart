import 'scene_runtime_models.dart';

enum NarrativeContinuityIssueKind {
  malformedLedger,
  duplicateEntity,
  missingDeclaredEvidence,
  unexplainedRename,
  holderMismatch,
  locationMismatch,
  statusMismatch,
  unexplainedReappearance,
}

class NarrativeContinuityLedgerEntry {
  NarrativeContinuityLedgerEntry({
    required this.entityId,
    required List<String> aliases,
    required this.holder,
    this.location = '',
    required this.status,
    required this.sourceSceneId,
  }) : aliases = List<String>.unmodifiable(aliases);

  final String entityId;
  final List<String> aliases;
  final String holder;
  final String location;
  final String status;
  final String sourceSceneId;

  Map<String, Object?> toJson() => <String, Object?>{
    'entityId': entityId,
    'aliases': aliases,
    'holder': holder,
    if (location.isNotEmpty) 'location': location,
    'status': status,
    'sourceSceneId': sourceSceneId,
  };
}

class NarrativeContinuityFinding {
  const NarrativeContinuityFinding({
    required this.kind,
    required this.entityId,
    required this.alias,
    required this.expectedHolder,
    required this.observedHolder,
    required this.sourceSceneId,
    required this.position,
    required this.excerpt,
    required this.explanation,
  });

  final NarrativeContinuityIssueKind kind;
  final String entityId;
  final String alias;
  final String expectedHolder;
  final String observedHolder;
  final String sourceSceneId;
  final int position;
  final String excerpt;
  final String explanation;
}

class NarrativeContinuityReport {
  NarrativeContinuityReport({
    List<NarrativeContinuityLedgerEntry> ledgerEntries = const [],
    List<NarrativeContinuityLedgerEntry>? resultingLedgerEntries,
    List<NarrativeContinuityFinding> findings = const [],
    this.ledgerIgnored = false,
  }) : ledgerEntries = List<NarrativeContinuityLedgerEntry>.unmodifiable(
         ledgerEntries,
       ),
       resultingLedgerEntries =
           List<NarrativeContinuityLedgerEntry>.unmodifiable(
             resultingLedgerEntries ?? ledgerEntries,
           ),
       findings = List<NarrativeContinuityFinding>.unmodifiable(findings);

  final List<NarrativeContinuityLedgerEntry> ledgerEntries;
  final List<NarrativeContinuityLedgerEntry> resultingLedgerEntries;
  final List<NarrativeContinuityFinding> findings;
  final bool ledgerIgnored;

  bool get passed => findings.isEmpty;

  List<Map<String, Object?>> get resultingLedgerJson => <Map<String, Object?>>[
    for (final entry in resultingLedgerEntries) entry.toJson(),
  ];
}

/// Verifies high-confidence physical state transitions for tracked props.
///
/// The verifier intentionally ignores a plain noun mention. It only treats an
/// entity as physically present when a named cast member retrieves, holds,
/// recovers, or transfers one of its aliases, or when an outline supplies a
/// strict `continuityEntityDeclarations` event contract. Declared events bind
/// typed identity/state changes to unique literal evidence in the exact final
/// prose. This avoids guessing entities or transition verbs from arbitrary
/// nouns while still allowing the first observed scene to create a ledger row.
class NarrativeContinuityVerifier {
  const NarrativeContinuityVerifier();

  NarrativeContinuityReport verify({
    required SceneBrief brief,
    required String prose,
  }) {
    final isRequired =
        brief.formalExecution ||
        brief.metadata['requireContinuityLedger'] == true;
    final hasLedger = brief.metadata.containsKey('continuityLedger');

    if (!hasLedger) {
      return isRequired
          ? _malformedReport(
              'continuityLedger is required but missing.',
              brief: brief,
            )
          : NarrativeContinuityReport();
    }

    late final List<NarrativeContinuityLedgerEntry> ledger;
    try {
      ledger = _parseLedger(
        brief.metadata['continuityLedger'],
        strictContract: isRequired,
      );
    } on _ContinuityLedgerFormatError catch (error) {
      if (!isRequired) {
        return NarrativeContinuityReport(ledgerIgnored: true);
      }
      return _malformedReport(error.message, brief: brief);
    }

    late final List<_DeclaredEntity> declarations;
    try {
      declarations = _parseDeclarations(
        brief.metadata['continuityEntityDeclarations'],
        present: brief.metadata.containsKey('continuityEntityDeclarations'),
      );
    } on _DuplicateEntityDeclarationError catch (error) {
      return _contractReport(
        kind: NarrativeContinuityIssueKind.duplicateEntity,
        detail: error.message,
        brief: brief,
        ledger: ledger,
      );
    } on _ContinuityLedgerFormatError catch (error) {
      return _malformedReport(error.message, brief: brief, ledger: ledger);
    }

    final trimmedProse = prose.trim();
    final actors = _ActorRegistry.fromBrief(brief, ledger);
    final findings = <NarrativeContinuityFinding>[];
    final findingKeys = <String>{};
    final resultingById = <String, NarrativeContinuityLedgerEntry>{
      for (final entry in ledger) entry.entityId: entry,
    };
    final declaredEntityIds = <String>{};

    _applyDeclarations(
      declarations: declarations,
      prose: trimmedProse,
      actors: actors,
      currentSceneId: '${brief.chapterId}/${brief.sceneId}',
      ledger: resultingById,
      declaredEntityIds: declaredEntityIds,
      findings: findings,
      findingKeys: findingKeys,
    );

    for (final entry in ledger) {
      if (declaredEntityIds.contains(entry.entityId)) continue;
      if (!entry.aliases.any(trimmedProse.contains)) {
        continue;
      }
      resultingById[entry.entityId] = _verifyEntry(
        entry: entry,
        prose: trimmedProse,
        actors: actors,
        currentSceneId: '${brief.chapterId}/${brief.sceneId}',
        findings: findings,
        findingKeys: findingKeys,
      );
    }

    return NarrativeContinuityReport(
      ledgerEntries: ledger,
      resultingLedgerEntries: resultingById.values.toList(growable: false),
      findings: findings,
    );
  }

  NarrativeContinuityReport _malformedReport(
    String detail, {
    required SceneBrief brief,
    List<NarrativeContinuityLedgerEntry> ledger = const [],
  }) {
    return NarrativeContinuityReport(
      ledgerEntries: ledger,
      findings: [
        NarrativeContinuityFinding(
          kind: NarrativeContinuityIssueKind.malformedLedger,
          entityId: '',
          alias: '',
          expectedHolder: '',
          observedHolder: '',
          sourceSceneId: '${brief.chapterId}/${brief.sceneId}',
          position: -1,
          excerpt: '',
          explanation: 'continuityLedger 无法安全解析：$detail',
        ),
      ],
    );
  }

  NarrativeContinuityReport _contractReport({
    required NarrativeContinuityIssueKind kind,
    required String detail,
    required SceneBrief brief,
    required List<NarrativeContinuityLedgerEntry> ledger,
  }) {
    return NarrativeContinuityReport(
      ledgerEntries: ledger,
      findings: [
        NarrativeContinuityFinding(
          kind: kind,
          entityId: '',
          alias: '',
          expectedHolder: '',
          observedHolder: '',
          sourceSceneId: '${brief.chapterId}/${brief.sceneId}',
          position: -1,
          excerpt: '',
          explanation: 'continuityEntityDeclarations 无法安全应用：$detail',
        ),
      ],
    );
  }

  List<NarrativeContinuityLedgerEntry> _parseLedger(
    Object? rawLedger, {
    required bool strictContract,
  }) {
    if (rawLedger is! List) {
      throw const _ContinuityLedgerFormatError(
        'continuityLedger must be a list.',
      );
    }

    final entries = <NarrativeContinuityLedgerEntry>[];
    final entityIds = <String>{};
    final aliasOwners = <String, String>{};

    for (var index = 0; index < rawLedger.length; index += 1) {
      final rawEntry = rawLedger[index];
      if (rawEntry is! Map) {
        throw _ContinuityLedgerFormatError('entry $index must be an object.');
      }
      final entry = <String, Object?>{};
      for (final rawMapEntry in rawEntry.entries) {
        if (rawMapEntry.key is! String) {
          throw _ContinuityLedgerFormatError(
            'entry $index contains a non-string key.',
          );
        }
        entry[rawMapEntry.key as String] = rawMapEntry.value;
      }

      final entityId = _requiredString(entry, 'entityId', index);
      final status = _requiredString(entry, 'status', index);
      final sourceSceneId = _requiredString(entry, 'sourceSceneId', index);
      final rawHolder = entry['holder'];
      if (rawHolder is! String) {
        throw _ContinuityLedgerFormatError(
          'entry $index holder must be a string.',
        );
      }
      final holder = rawHolder.trim();
      final rawLocation = entry['location'];
      if (rawLocation != null && rawLocation is! String) {
        throw _ContinuityLedgerFormatError(
          'entry $index location must be a string when present.',
        );
      }
      final location = rawLocation is String ? rawLocation.trim() : '';
      if (holder.isEmpty && location.isEmpty && !_isUnavailableStatus(status)) {
        throw _ContinuityLedgerFormatError(
          'entry $index has neither holder nor location for active status '
          '"$status".',
        );
      }
      if (strictContract) {
        const allowedStatuses = <String>{
          'held',
          'stored',
          'lost',
          'destroyed',
          'discarded',
        };
        if (!allowedStatuses.contains(status)) {
          throw _ContinuityLedgerFormatError(
            'entry $index has unsupported canonical status "$status".',
          );
        }
        if (status == 'held' && holder.isEmpty) {
          throw _ContinuityLedgerFormatError(
            'entry $index held status requires a holder.',
          );
        }
        if (status == 'stored' && location.isEmpty) {
          throw _ContinuityLedgerFormatError(
            'entry $index stored status requires a location.',
          );
        }
        if (_isUnavailableStatus(status) &&
            (holder.isNotEmpty || location.isEmpty)) {
          throw _ContinuityLedgerFormatError(
            'entry $index unavailable status requires an empty holder and '
            'a last-known location.',
          );
        }
      }

      final rawAliases = entry['aliases'];
      if (rawAliases is! List || rawAliases.isEmpty) {
        throw _ContinuityLedgerFormatError(
          'entry $index aliases must be a non-empty list.',
        );
      }
      final aliases = <String>[];
      for (final rawAlias in rawAliases) {
        if (rawAlias is! String || rawAlias.trim().isEmpty) {
          throw _ContinuityLedgerFormatError(
            'entry $index contains an invalid alias.',
          );
        }
        final alias = rawAlias.trim();
        if (aliases.contains(alias)) {
          if (strictContract) {
            throw _ContinuityLedgerFormatError(
              'entry $index contains duplicate alias "$alias".',
            );
          }
          continue;
        }
        aliases.add(alias);
      }
      aliases.sort((left, right) => right.length.compareTo(left.length));

      if (!entityIds.add(entityId)) {
        throw _ContinuityLedgerFormatError('duplicate entityId "$entityId".');
      }
      for (final alias in aliases) {
        final previousOwner = aliasOwners[alias];
        if (previousOwner != null && previousOwner != entityId) {
          throw _ContinuityLedgerFormatError(
            'alias "$alias" belongs to multiple entities.',
          );
        }
        aliasOwners[alias] = entityId;
      }

      entries.add(
        NarrativeContinuityLedgerEntry(
          entityId: entityId,
          aliases: aliases,
          holder: holder,
          location: location,
          status: status,
          sourceSceneId: sourceSceneId,
        ),
      );
    }

    return entries;
  }

  List<_DeclaredEntity> _parseDeclarations(
    Object? rawDeclarations, {
    required bool present,
  }) {
    if (!present) return const <_DeclaredEntity>[];
    if (rawDeclarations is! List) {
      throw const _ContinuityLedgerFormatError(
        'continuityEntityDeclarations must be a list.',
      );
    }

    final rawEntities = <Map<String, Object?>>[];
    final entityIds = <String>{};
    final aliasOwners = <String, String>{};
    for (var index = 0; index < rawDeclarations.length; index += 1) {
      final rawEntity = rawDeclarations[index];
      final entity = _stringObjectMap(rawEntity, label: 'declaration $index');
      _rejectUnknownKeys(entity, const <String>{
        'entityId',
        'aliases',
        'events',
      }, label: 'declaration $index');
      final entityId = _requiredString(entity, 'entityId', index);
      if (!entityIds.add(entityId)) {
        throw _DuplicateEntityDeclarationError(
          'duplicate declared entityId "$entityId".',
        );
      }
      final aliases = _strictStringList(
        entity['aliases'],
        label: 'declaration $index aliases',
      );
      for (final alias in aliases) {
        final owner = aliasOwners[alias];
        if (owner != null && owner != entityId) {
          throw _DuplicateEntityDeclarationError(
            'alias "$alias" is declared for both "$owner" and "$entityId".',
          );
        }
        aliasOwners[alias] = entityId;
      }
      rawEntities.add(entity);
    }

    final eventIds = <String>{};
    final entities = <_DeclaredEntity>[];
    for (var index = 0; index < rawEntities.length; index += 1) {
      final entity = rawEntities[index];
      final entityId = _requiredString(entity, 'entityId', index);
      final aliases = _strictStringList(
        entity['aliases'],
        label: 'declaration $index aliases',
      );
      final rawEvents = entity['events'];
      if (rawEvents is! List || rawEvents.isEmpty) {
        throw _ContinuityLedgerFormatError(
          'declaration $index events must be a non-empty list.',
        );
      }
      final events = <_DeclaredEntityEvent>[];
      for (var eventIndex = 0; eventIndex < rawEvents.length; eventIndex += 1) {
        final rawEvent = _stringObjectMap(
          rawEvents[eventIndex],
          label: 'declaration $index event $eventIndex',
        );
        _rejectUnknownKeys(rawEvent, const <String>{
          'eventId',
          'kind',
          'evidence',
          'alias',
          'previousAlias',
          'fromHolder',
          'holder',
          'location',
          'status',
        }, label: 'declaration $index event $eventIndex');
        final eventId = _requiredContractString(
          rawEvent,
          'eventId',
          label: 'declaration $index event $eventIndex',
        );
        if (!eventIds.add(eventId)) {
          throw _ContinuityLedgerFormatError(
            'duplicate declared eventId "$eventId".',
          );
        }
        final rawKind = _requiredContractString(
          rawEvent,
          'kind',
          label: 'event "$eventId"',
        );
        final kind = _DeclaredEntityEventKind.values
            .where((value) => value.name == rawKind)
            .firstOrNull;
        if (kind == null) {
          throw _ContinuityLedgerFormatError(
            'event "$eventId" has unsupported kind "$rawKind".',
          );
        }
        final evidence = _requiredContractString(
          rawEvent,
          'evidence',
          label: 'event "$eventId"',
        );
        final alias = _requiredContractString(
          rawEvent,
          'alias',
          label: 'event "$eventId"',
        );
        if (!aliases.contains(alias)) {
          throw _ContinuityLedgerFormatError(
            'event "$eventId" alias "$alias" is not declared for '
            '"$entityId".',
          );
        }
        final previousAlias = _optionalContractString(
          rawEvent,
          'previousAlias',
          label: 'event "$eventId"',
        );
        final fromHolder = _optionalContractString(
          rawEvent,
          'fromHolder',
          label: 'event "$eventId"',
        );
        final holder = _optionalContractString(
          rawEvent,
          'holder',
          label: 'event "$eventId"',
          allowEmpty: true,
        );
        final location = _optionalContractString(
          rawEvent,
          'location',
          label: 'event "$eventId"',
          allowEmpty: true,
        );
        final status = _optionalContractString(
          rawEvent,
          'status',
          label: 'event "$eventId"',
          allowEmpty: true,
        );
        _validateDeclaredEventShape(
          eventId: eventId,
          kind: kind,
          evidence: evidence,
          alias: alias,
          previousAlias: previousAlias,
          fromHolder: fromHolder,
          holder: holder,
          location: location,
          status: status,
        );
        events.add(
          _DeclaredEntityEvent(
            eventId: eventId,
            kind: kind,
            evidence: evidence,
            alias: alias,
            previousAlias: previousAlias,
            fromHolder: fromHolder,
            holder: holder,
            location: location,
            status: status,
          ),
        );
      }
      entities.add(
        _DeclaredEntity(entityId: entityId, aliases: aliases, events: events),
      );
    }
    return List<_DeclaredEntity>.unmodifiable(entities);
  }

  Map<String, Object?> _stringObjectMap(Object? raw, {required String label}) {
    if (raw is! Map) {
      throw _ContinuityLedgerFormatError('$label must be an object.');
    }
    final result = <String, Object?>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) {
        throw _ContinuityLedgerFormatError('$label contains a non-string key.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  void _rejectUnknownKeys(
    Map<String, Object?> value,
    Set<String> allowed, {
    required String label,
  }) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
    if (unknown.isNotEmpty) {
      throw _ContinuityLedgerFormatError(
        '$label contains unsupported field "${unknown.first}".',
      );
    }
  }

  List<String> _strictStringList(Object? raw, {required String label}) {
    if (raw is! List || raw.isEmpty) {
      throw _ContinuityLedgerFormatError('$label must be a non-empty list.');
    }
    final result = <String>[];
    for (final value in raw) {
      if (value is! String || value.trim().isEmpty) {
        throw _ContinuityLedgerFormatError(
          '$label contains a non-string or blank alias.',
        );
      }
      final normalized = value.trim();
      if (result.contains(normalized)) {
        throw _ContinuityLedgerFormatError(
          '$label contains duplicate alias "$normalized".',
        );
      }
      result.add(normalized);
    }
    return List<String>.unmodifiable(result);
  }

  String _requiredContractString(
    Map<String, Object?> value,
    String field, {
    required String label,
  }) {
    final raw = value[field];
    if (raw is! String || raw.trim().isEmpty) {
      throw _ContinuityLedgerFormatError(
        '$label field "$field" must be a non-empty string.',
      );
    }
    return raw.trim();
  }

  String _optionalContractString(
    Map<String, Object?> value,
    String field, {
    required String label,
    bool allowEmpty = false,
  }) {
    if (!value.containsKey(field)) return '';
    final raw = value[field];
    if (raw is! String || (!allowEmpty && raw.trim().isEmpty)) {
      throw _ContinuityLedgerFormatError(
        '$label field "$field" must be a string'
        '${allowEmpty ? '' : ' and cannot be blank'}.',
      );
    }
    return raw.trim();
  }

  void _validateDeclaredEventShape({
    required String eventId,
    required _DeclaredEntityEventKind kind,
    required String evidence,
    required String alias,
    required String previousAlias,
    required String fromHolder,
    required String holder,
    required String location,
    required String status,
  }) {
    if (!evidence.contains(alias)) {
      throw _ContinuityLedgerFormatError(
        'event "$eventId" evidence does not contain alias "$alias".',
      );
    }
    if (kind == _DeclaredEntityEventKind.rename) {
      if (previousAlias.isEmpty ||
          previousAlias == alias ||
          !evidence.contains(previousAlias)) {
        throw _ContinuityLedgerFormatError(
          'rename event "$eventId" must bind distinct old and new aliases '
          'in its evidence.',
        );
      }
      if (fromHolder.isNotEmpty ||
          holder.isNotEmpty ||
          location.isNotEmpty ||
          status.isNotEmpty) {
        throw _ContinuityLedgerFormatError(
          'rename event "$eventId" cannot mutate physical state.',
        );
      }
      return;
    }

    if (location.isEmpty) {
      throw _ContinuityLedgerFormatError(
        'event "$eventId" must declare a location.',
      );
    }
    if (!evidence.contains(location)) {
      throw _ContinuityLedgerFormatError(
        'event "$eventId" evidence does not contain location "$location".',
      );
    }
    const availableStatuses = <String>{'held', 'stored'};
    switch (kind) {
      case _DeclaredEntityEventKind.introduce:
        if (!availableStatuses.contains(status) ||
            (holder.isEmpty && status != 'stored') ||
            fromHolder.isNotEmpty) {
          throw _ContinuityLedgerFormatError(
            'introduce event "$eventId" must create held/stored state.',
          );
        }
      case _DeclaredEntityEventKind.observe:
        if (!availableStatuses.contains(status) ||
            (holder.isEmpty && status != 'stored') ||
            fromHolder.isNotEmpty) {
          throw _ContinuityLedgerFormatError(
            'observe event "$eventId" must declare held/stored state.',
          );
        }
      case _DeclaredEntityEventKind.transfer:
        if (fromHolder.isEmpty ||
            holder.isEmpty ||
            fromHolder == holder ||
            status != 'held') {
          throw _ContinuityLedgerFormatError(
            'transfer event "$eventId" requires distinct fromHolder/holder '
            'actors and status "held".',
          );
        }
      case _DeclaredEntityEventKind.relocate:
        if (!availableStatuses.contains(status) ||
            fromHolder.isEmpty ||
            holder.isEmpty ||
            fromHolder != holder) {
          throw _ContinuityLedgerFormatError(
            'relocate event "$eventId" must keep one explicit holder and '
            'declare held/stored state.',
          );
        }
      case _DeclaredEntityEventKind.lose:
        if (fromHolder.isEmpty || holder.isNotEmpty || status != 'lost') {
          throw _ContinuityLedgerFormatError(
            'lose event "$eventId" requires fromHolder, empty holder, and '
            'status "lost".',
          );
        }
      case _DeclaredEntityEventKind.destroy:
        if (fromHolder.isEmpty || holder.isNotEmpty || status != 'destroyed') {
          throw _ContinuityLedgerFormatError(
            'destroy event "$eventId" requires fromHolder, empty holder, '
            'and status "destroyed".',
          );
        }
      case _DeclaredEntityEventKind.discard:
        if (fromHolder.isEmpty || holder.isNotEmpty || status != 'discarded') {
          throw _ContinuityLedgerFormatError(
            'discard event "$eventId" requires fromHolder, empty holder, '
            'and status "discarded".',
          );
        }
      case _DeclaredEntityEventKind.recover:
        if (!availableStatuses.contains(status) ||
            (holder.isEmpty && status != 'stored') ||
            fromHolder.isNotEmpty) {
          throw _ContinuityLedgerFormatError(
            'recover event "$eventId" must restore held/stored state.',
          );
        }
      case _DeclaredEntityEventKind.rename:
        throw StateError('rename returned before physical event validation');
    }
  }

  void _applyDeclarations({
    required List<_DeclaredEntity> declarations,
    required String prose,
    required _ActorRegistry actors,
    required String currentSceneId,
    required Map<String, NarrativeContinuityLedgerEntry> ledger,
    required Set<String> declaredEntityIds,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
  }) {
    final aliasOwners = <String, String>{
      for (final entry in ledger.values)
        for (final alias in entry.aliases) alias: entry.entityId,
    };

    for (final declaration in declarations) {
      declaredEntityIds.add(declaration.entityId);
      final existing = ledger[declaration.entityId];
      final newAliases = existing == null
          ? declaration.aliases
          : declaration.aliases
                .where((alias) => !existing.aliases.contains(alias))
                .toList(growable: false);
      final renameTargets = {
        for (final event in declaration.events)
          if (event.kind == _DeclaredEntityEventKind.rename) event.alias,
      };

      var rejected = false;
      for (final alias in declaration.aliases) {
        final owner = aliasOwners[alias];
        if (owner != null && owner != declaration.entityId) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.duplicateEntity,
            entityId: declaration.entityId,
            alias: alias,
            sourceSceneId: currentSceneId,
            explanation:
                '实体「${declaration.entityId}」声明的别名「$alias」已属于'
                '另一实体「$owner」，不能把两个物理对象折叠为同一别名。',
            findings: findings,
            findingKeys: findingKeys,
          );
          rejected = true;
        }
      }
      if (existing != null) {
        for (final alias in newAliases) {
          if (renameTargets.contains(alias)) continue;
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.unexplainedRename,
            entityId: declaration.entityId,
            alias: alias,
            sourceSceneId: existing.sourceSceneId,
            explanation:
                '实体「${declaration.entityId}」新增别名「$alias」却没有 '
                'rename 事件及同时包含旧、新别名的正文证据。',
            findings: findings,
            findingKeys: findingKeys,
          );
          rejected = true;
        }
      }
      if (rejected) continue;

      final resolved = _applyDeclaredEntity(
        declaration: declaration,
        existing: existing,
        prose: prose,
        actors: actors,
        currentSceneId: currentSceneId,
        aliasOwners: aliasOwners,
        findings: findings,
        findingKeys: findingKeys,
      );
      if (resolved == null) continue;
      ledger[declaration.entityId] = resolved;
      for (final alias in resolved.aliases) {
        aliasOwners[alias] = resolved.entityId;
      }
    }
  }

  NarrativeContinuityLedgerEntry? _applyDeclaredEntity({
    required _DeclaredEntity declaration,
    required NarrativeContinuityLedgerEntry? existing,
    required String prose,
    required _ActorRegistry actors,
    required String currentSceneId,
    required Map<String, String> aliasOwners,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
  }) {
    NarrativeContinuityLedgerEntry? current = existing;
    var lastEvidencePosition = -1;
    for (final event in declaration.events) {
      final position = prose.indexOf(event.evidence);
      final evidenceIsUnique =
          position >= 0 &&
          prose.indexOf(event.evidence, position + event.evidence.length) < 0;
      if (!evidenceIsUnique || position <= lastEvidencePosition) {
        _addDeclaredFinding(
          kind: NarrativeContinuityIssueKind.missingDeclaredEvidence,
          entityId: declaration.entityId,
          alias: event.alias,
          sourceSceneId: currentSceneId,
          position: position,
          excerpt: position < 0
              ? ''
              : _excerpt(prose, position, position + event.evidence.length),
          explanation: position < 0
              ? '事件「${event.eventId}」声明的唯一正文证据未出现在最终正文中。'
              : '事件「${event.eventId}」的正文证据重复或顺序与声明不一致，'
                    '无法唯一绑定状态变化。',
          findings: findings,
          findingKeys: findingKeys,
        );
        return current;
      }
      lastEvidencePosition = position;

      if (!_eventActorsAreBound(
        event: event,
        actors: actors,
        findings: findings,
        findingKeys: findingKeys,
        entityId: declaration.entityId,
        sourceSceneId: currentSceneId,
        position: position,
      )) {
        return current;
      }

      if (event.kind == _DeclaredEntityEventKind.rename) {
        if (current == null ||
            !current.aliases.contains(event.previousAlias) ||
            current.aliases.contains(event.alias)) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.unexplainedRename,
            entityId: declaration.entityId,
            alias: event.alias,
            sourceSceneId: current?.sourceSceneId ?? currentSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'rename 事件「${event.eventId}」没有从该实体的现有别名'
                '「${event.previousAlias}」唯一迁移到新别名「${event.alias}」。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        final owner = aliasOwners[event.alias];
        if (owner != null && owner != declaration.entityId) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.duplicateEntity,
            entityId: declaration.entityId,
            alias: event.alias,
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'rename 事件「${event.eventId}」试图占用实体「$owner」已有的'
                '别名「${event.alias}」。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        current = NarrativeContinuityLedgerEntry(
          entityId: current.entityId,
          aliases: <String>[...current.aliases, event.alias],
          holder: current.holder,
          location: current.location,
          status: current.status,
          sourceSceneId: currentSceneId,
        );
        aliasOwners[event.alias] = current.entityId;
        continue;
      }

      if (current == null) {
        if (event.kind != _DeclaredEntityEventKind.introduce) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.unexplainedReappearance,
            entityId: declaration.entityId,
            alias: event.alias,
            sourceSceneId: currentSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                '实体「${declaration.entityId}」尚无账本身份，却以 '
                '${event.kind.name} 事件出现；首个事件必须是 introduce。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return null;
        }
        current = NarrativeContinuityLedgerEntry(
          entityId: declaration.entityId,
          aliases: declaration.aliases,
          holder: actors.canonicalizeKnown(event.holder) ?? event.holder,
          location: event.location,
          status: event.status,
          sourceSceneId: currentSceneId,
        );
        continue;
      }

      if (event.kind == _DeclaredEntityEventKind.introduce) {
        _addDeclaredFinding(
          kind: NarrativeContinuityIssueKind.duplicateEntity,
          entityId: declaration.entityId,
          alias: event.alias,
          sourceSceneId: current.sourceSceneId,
          position: position,
          excerpt: event.evidence,
          explanation:
              '实体「${declaration.entityId}」已存在，不能通过第二个 introduce '
              '事件制造同一物理对象的副本。',
          findings: findings,
          findingKeys: findingKeys,
        );
        return current;
      }

      final findingCountBefore = findings.length;
      final next = _applyDeclaredTransition(
        current: current,
        event: event,
        actors: actors,
        currentSceneId: currentSceneId,
        position: position,
        findings: findings,
        findingKeys: findingKeys,
      );
      if (identical(next, current) && findings.length > findingCountBefore) {
        return current;
      }
      current = next;
    }
    return current;
  }

  bool _eventActorsAreBound({
    required _DeclaredEntityEvent event,
    required _ActorRegistry actors,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
    required String entityId,
    required String sourceSceneId,
    required int position,
  }) {
    for (final actorReference in <String>{
      if (event.fromHolder.isNotEmpty) event.fromHolder,
      if (event.holder.isNotEmpty) event.holder,
    }) {
      final actorId = actors.canonicalizeKnown(actorReference);
      if (actorId != null &&
          actors.evidenceNames(actorId).any(event.evidence.contains)) {
        continue;
      }
      _addDeclaredFinding(
        kind: NarrativeContinuityIssueKind.malformedLedger,
        entityId: entityId,
        alias: event.alias,
        sourceSceneId: sourceSceneId,
        position: position,
        excerpt: event.evidence,
        explanation:
            '事件「${event.eventId}」的参与者「$actorReference」不在当前 cast '
            '或正文证据中，不能作为物理状态权威。',
        findings: findings,
        findingKeys: findingKeys,
      );
      return false;
    }
    return true;
  }

  NarrativeContinuityLedgerEntry _applyDeclaredTransition({
    required NarrativeContinuityLedgerEntry current,
    required _DeclaredEntityEvent event,
    required _ActorRegistry actors,
    required String currentSceneId,
    required int position,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
  }) {
    final currentHolder =
        actors.canonicalizeKnown(current.holder) ?? current.holder;
    final fromHolder =
        actors.canonicalizeKnown(event.fromHolder) ?? event.fromHolder;
    final nextHolder = actors.canonicalizeKnown(event.holder) ?? event.holder;

    if (_isUnavailableStatus(current.status) &&
        event.kind != _DeclaredEntityEventKind.recover) {
      _addDeclaredFinding(
        kind: NarrativeContinuityIssueKind.unexplainedReappearance,
        entityId: current.entityId,
        alias: event.alias,
        sourceSceneId: current.sourceSceneId,
        position: position,
        excerpt: event.evidence,
        explanation:
            '实体「${current.entityId}」当前状态为「${current.status}」，'
            '事件「${event.eventId}」却未使用 recover 恢复来源。',
        findings: findings,
        findingKeys: findingKeys,
      );
      return current;
    }
    if (event.kind == _DeclaredEntityEventKind.recover) {
      if (!_isRecoverableStatus(current.status)) {
        _addDeclaredFinding(
          kind: NarrativeContinuityIssueKind.unexplainedReappearance,
          entityId: current.entityId,
          alias: event.alias,
          sourceSceneId: current.sourceSceneId,
          position: position,
          excerpt: event.evidence,
          explanation:
              '实体「${current.entityId}」状态为「${current.status}」，不能以 '
              'recover 事件恢复；destroyed 实体不可复原。',
          findings: findings,
          findingKeys: findingKeys,
        );
        return current;
      }
      return _entryAfterEvent(
        current,
        holder: nextHolder,
        location: event.location,
        status: event.status,
        sourceSceneId: currentSceneId,
      );
    }

    if (event.fromHolder.isNotEmpty && currentHolder != fromHolder) {
      _addDeclaredFinding(
        kind: NarrativeContinuityIssueKind.holderMismatch,
        entityId: current.entityId,
        alias: event.alias,
        expectedHolder: actors.displayName(currentHolder),
        observedHolder: actors.displayName(fromHolder),
        sourceSceneId: current.sourceSceneId,
        position: position,
        excerpt: event.evidence,
        explanation:
            '事件「${event.eventId}」声称由「${actors.displayName(fromHolder)}」'
            '发起，但账本持有人是「${actors.displayName(currentHolder)}」，此前无交接。',
        findings: findings,
        findingKeys: findingKeys,
      );
      return current;
    }

    switch (event.kind) {
      case _DeclaredEntityEventKind.observe:
        if (currentHolder != nextHolder) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.holderMismatch,
            entityId: current.entityId,
            alias: event.alias,
            expectedHolder: actors.displayName(currentHolder),
            observedHolder: actors.displayName(nextHolder),
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'observe 事件「${event.eventId}」把实体交给了另一持有人，'
                '却没有 transfer 事件。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        if (current.location != event.location) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.locationMismatch,
            entityId: current.entityId,
            alias: event.alias,
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'observe 事件「${event.eventId}」把实体从「${current.location}」'
                '跳到「${event.location}」，却没有 relocate 事件。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        if (current.status != event.status) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.statusMismatch,
            entityId: current.entityId,
            alias: event.alias,
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'observe 事件「${event.eventId}」把状态从「${current.status}」'
                '改为「${event.status}」，却没有对应的 typed transition。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        return current;
      case _DeclaredEntityEventKind.transfer:
        if (current.status != 'held') {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.statusMismatch,
            entityId: current.entityId,
            alias: event.alias,
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'transfer 事件「${event.eventId}」不能把状态从'
                '「${current.status}」暗中改为「held」。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        return _entryAfterEvent(
          current,
          holder: nextHolder,
          location: event.location,
          status: event.status,
          sourceSceneId: currentSceneId,
        );
      case _DeclaredEntityEventKind.relocate:
        if (currentHolder != nextHolder) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.holderMismatch,
            entityId: current.entityId,
            alias: event.alias,
            expectedHolder: actors.displayName(currentHolder),
            observedHolder: actors.displayName(nextHolder),
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'relocate 事件「${event.eventId}」不能代替 transfer '
                '改变持有人。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        if (current.status != event.status) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.statusMismatch,
            entityId: current.entityId,
            alias: event.alias,
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'relocate 事件「${event.eventId}」不能把状态从'
                '「${current.status}」暗中改为「${event.status}」。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        if (current.location == event.location) {
          _addDeclaredFinding(
            kind: NarrativeContinuityIssueKind.locationMismatch,
            entityId: current.entityId,
            alias: event.alias,
            sourceSceneId: current.sourceSceneId,
            position: position,
            excerpt: event.evidence,
            explanation:
                'relocate 事件「${event.eventId}」没有改变位置；'
                '应使用 observe 记录未变状态。',
            findings: findings,
            findingKeys: findingKeys,
          );
          return current;
        }
        return _entryAfterEvent(
          current,
          holder: nextHolder,
          location: event.location,
          status: event.status,
          sourceSceneId: currentSceneId,
        );
      case _DeclaredEntityEventKind.lose:
      case _DeclaredEntityEventKind.destroy:
      case _DeclaredEntityEventKind.discard:
        return _entryAfterEvent(
          current,
          holder: nextHolder,
          location: event.location,
          status: event.status,
          sourceSceneId: currentSceneId,
        );
      case _DeclaredEntityEventKind.introduce:
      case _DeclaredEntityEventKind.recover:
      case _DeclaredEntityEventKind.rename:
        throw StateError('event kind handled before declared transition');
    }
  }

  NarrativeContinuityLedgerEntry _entryAfterEvent(
    NarrativeContinuityLedgerEntry current, {
    required String holder,
    required String location,
    required String status,
    required String sourceSceneId,
  }) => NarrativeContinuityLedgerEntry(
    entityId: current.entityId,
    aliases: current.aliases,
    holder: holder,
    location: location,
    status: status,
    sourceSceneId: sourceSceneId,
  );

  void _addDeclaredFinding({
    required NarrativeContinuityIssueKind kind,
    required String entityId,
    required String alias,
    required String sourceSceneId,
    required String explanation,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
    String expectedHolder = '',
    String observedHolder = '',
    int position = -1,
    String excerpt = '',
  }) {
    final key = <Object?>[
      kind.name,
      entityId,
      alias,
      sourceSceneId,
      position,
      explanation,
    ].join('|');
    if (!findingKeys.add(key)) return;
    findings.add(
      NarrativeContinuityFinding(
        kind: kind,
        entityId: entityId,
        alias: alias,
        expectedHolder: expectedHolder,
        observedHolder: observedHolder,
        sourceSceneId: sourceSceneId,
        position: position,
        excerpt: excerpt,
        explanation: explanation,
      ),
    );
  }

  String _requiredString(Map<String, Object?> entry, String field, int index) {
    final raw = entry[field];
    if (raw is! String || raw.trim().isEmpty) {
      throw _ContinuityLedgerFormatError(
        'entry $index field "$field" must be a non-empty string.',
      );
    }
    return raw.trim();
  }

  NarrativeContinuityLedgerEntry _verifyEntry({
    required NarrativeContinuityLedgerEntry entry,
    required String prose,
    required _ActorRegistry actors,
    required String currentSceneId,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
  }) {
    var available = !_isUnavailableStatus(entry.status);
    String? currentHolder = available
        ? actors.canonicalize(entry.holder)
        : null;
    var stateChanged = false;
    final events = _eventsFor(entry, prose, actors);

    for (final event in events) {
      switch (event.type) {
        case _ContinuityEventType.recovery:
          available = true;
          currentHolder = event.actorId;
          stateChanged = true;
          continue;
        case _ContinuityEventType.possession:
          if (!available) {
            _addReappearanceFinding(
              entry: entry,
              event: event,
              prose: prose,
              actors: actors,
              findings: findings,
              findingKeys: findingKeys,
            );
            continue;
          }
          if (currentHolder != event.actorId) {
            _addHolderFinding(
              entry: entry,
              event: event,
              expectedHolderId: currentHolder,
              prose: prose,
              actors: actors,
              findings: findings,
              findingKeys: findingKeys,
            );
          }
          continue;
        case _ContinuityEventType.transfer:
          if (!available) {
            _addReappearanceFinding(
              entry: entry,
              event: event,
              prose: prose,
              actors: actors,
              findings: findings,
              findingKeys: findingKeys,
            );
            available = true;
          } else if (currentHolder != event.actorId) {
            _addHolderFinding(
              entry: entry,
              event: event,
              expectedHolderId: currentHolder,
              prose: prose,
              actors: actors,
              findings: findings,
              findingKeys: findingKeys,
            );
          }
          currentHolder = event.targetActorId;
          stateChanged = true;
          continue;
      }
    }

    return NarrativeContinuityLedgerEntry(
      entityId: entry.entityId,
      aliases: entry.aliases,
      holder: available ? currentHolder ?? entry.holder : '',
      location: entry.location,
      status: available ? 'held' : entry.status,
      sourceSceneId: stateChanged ? currentSceneId : entry.sourceSceneId,
    );
  }

  void _addHolderFinding({
    required NarrativeContinuityLedgerEntry entry,
    required _ContinuityEvent event,
    required String? expectedHolderId,
    required String prose,
    required _ActorRegistry actors,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
  }) {
    final expectedHolder = actors.displayName(expectedHolderId);
    final observedHolder = actors.displayName(event.actorId);
    final key = [
      entry.entityId,
      NarrativeContinuityIssueKind.holderMismatch.name,
      expectedHolderId ?? '',
      event.actorId,
    ].join('|');
    if (!findingKeys.add(key)) return;

    findings.add(
      NarrativeContinuityFinding(
        kind: NarrativeContinuityIssueKind.holderMismatch,
        entityId: entry.entityId,
        alias: event.alias,
        expectedHolder: expectedHolder,
        observedHolder: observedHolder,
        sourceSceneId: entry.sourceSceneId,
        position: event.start,
        excerpt: _excerpt(prose, event.start, event.end),
        explanation:
            '实体「${entry.entityId}」在 ${entry.sourceSceneId} 记录由'
            '「$expectedHolder」持有；当前正文却由「$observedHolder」物理取用或转交'
            '别名「${event.alias}」，此前未见交接。aliases 只用于同一实体归一，'
            '不能证明所有权转移。',
      ),
    );
  }

  void _addReappearanceFinding({
    required NarrativeContinuityLedgerEntry entry,
    required _ContinuityEvent event,
    required String prose,
    required _ActorRegistry actors,
    required List<NarrativeContinuityFinding> findings,
    required Set<String> findingKeys,
  }) {
    final observedHolder = actors.displayName(event.actorId);
    final key = [
      entry.entityId,
      NarrativeContinuityIssueKind.unexplainedReappearance.name,
      event.actorId,
    ].join('|');
    if (!findingKeys.add(key)) return;

    findings.add(
      NarrativeContinuityFinding(
        kind: NarrativeContinuityIssueKind.unexplainedReappearance,
        entityId: entry.entityId,
        alias: event.alias,
        expectedHolder: '',
        observedHolder: observedHolder,
        sourceSceneId: entry.sourceSceneId,
        position: event.start,
        excerpt: _excerpt(prose, event.start, event.end),
        explanation:
            '实体「${entry.entityId}」在 ${entry.sourceSceneId} 的状态为'
            '「${entry.status}」，当前却由「$observedHolder」以别名'
            '「${event.alias}」再次物理出现，正文此前未提供找回或重获来源。',
      ),
    );
  }

  List<_ContinuityEvent> _eventsFor(
    NarrativeContinuityLedgerEntry entry,
    String prose,
    _ActorRegistry actors,
  ) {
    final byKey = <String, _ContinuityEvent>{};
    const broadGap = r'[^。！？；\n]{0,24}?';
    const tightGap = r'[^。！？；，,\n]{0,10}?';
    const storage =
        r'从(?:自己(?:的)?|其)?(?:贴身)?'
        r'(?:衣领|衣袋|口袋|内袋|怀里|怀中|袖中|袖口|腰间|背包|包里|胸前)'
        r'(?:内侧|里面|里|内|中)?';
    const takeVerb = r'(?:摸出|掏出|取出|抽出|拿出|翻出)';
    const holdVerb = r'(?:手持|拿着|握着|攥着|带着|怀揣|持有)';
    const transferVerb =
        r'(?:交还给|递还给|转交给|移交给|交给|递给|塞给|还给|'
        r'塞进|拍进|拍回|推入|放进|递到|交到)';
    const targetPlace = r'(?:的)?(?:手中|手里|掌心|怀里|怀中|胸口|衣袋|口袋|内袋)?';
    const recoveryVerb = r'(?:重新拿到|重新找到|找回|捡回|捡到|寻回|夺回|取回)';

    void addMatches({
      required RegExp pattern,
      required _ContinuityEventType type,
      required String actorId,
      required String alias,
      String? targetActorId,
    }) {
      for (final match in pattern.allMatches(prose)) {
        final event = _ContinuityEvent(
          type: type,
          actorId: actorId,
          targetActorId: targetActorId,
          alias: alias,
          start: match.start,
          end: match.end,
        );
        final key = [
          type.name,
          actorId,
          targetActorId ?? '',
          alias,
          match.start,
          match.end,
        ].join('|');
        byKey[key] = event;
      }
    }

    for (final alias in entry.aliases) {
      final escapedAlias = RegExp.escape(alias);
      for (final actor in actors.tokens) {
        final escapedActor = RegExp.escape(actor.token);
        addMatches(
          pattern: RegExp(
            '$escapedActor$tightGap$storage$broadGap$takeVerb$broadGap$escapedAlias',
          ),
          type: _ContinuityEventType.possession,
          actorId: actor.actorId,
          alias: alias,
        );
        addMatches(
          pattern: RegExp(
            '$escapedActor$tightGap(?:再次|又)?$takeVerb$broadGap$escapedAlias',
          ),
          type: _ContinuityEventType.possession,
          actorId: actor.actorId,
          alias: alias,
        );
        addMatches(
          pattern: RegExp(
            '$escapedActor$tightGap$holdVerb$broadGap$escapedAlias',
          ),
          type: _ContinuityEventType.possession,
          actorId: actor.actorId,
          alias: alias,
        );
        addMatches(
          pattern: RegExp(
            '$escapedAlias$tightGap(?:落在|在)$tightGap$escapedActor'
            r'(?:手中|手里|掌心|怀里|怀中|身上)',
          ),
          type: _ContinuityEventType.possession,
          actorId: actor.actorId,
          alias: alias,
        );

        if (_isRecoverableStatus(entry.status)) {
          addMatches(
            pattern: RegExp(
              '$escapedActor$broadGap$recoveryVerb$broadGap$escapedAlias',
            ),
            type: _ContinuityEventType.recovery,
            actorId: actor.actorId,
            alias: alias,
          );
        }
      }

      for (final from in actors.tokens) {
        final escapedFrom = RegExp.escape(from.token);
        for (final to in actors.tokens) {
          if (from.actorId == to.actorId) continue;
          final escapedTo = RegExp.escape(to.token);
          addMatches(
            pattern: RegExp(
              '$escapedFrom$broadGap$escapedAlias$broadGap$transferVerb'
              '$broadGap$escapedTo$targetPlace',
            ),
            type: _ContinuityEventType.transfer,
            actorId: from.actorId,
            targetActorId: to.actorId,
            alias: alias,
          );
          addMatches(
            pattern: RegExp(
              '$escapedFrom$broadGap$transferVerb$broadGap$escapedTo'
              '$broadGap$escapedAlias',
            ),
            type: _ContinuityEventType.transfer,
            actorId: from.actorId,
            targetActorId: to.actorId,
            alias: alias,
          );
        }
      }
    }

    final events = byKey.values.toList(growable: false)
      ..sort((left, right) {
        final position = left.start.compareTo(right.start);
        if (position != 0) return position;
        final priority = left.type.priority.compareTo(right.type.priority);
        if (priority != 0) return priority;
        return left.end.compareTo(right.end);
      });
    return events;
  }

  String _excerpt(String prose, int start, int end) {
    final excerptStart = start > 12 ? start - 12 : 0;
    final candidateEnd = end + 18;
    final excerptEnd = candidateEnd < prose.length
        ? candidateEnd
        : prose.length;
    return prose
        .substring(excerptStart, excerptEnd)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

bool _isUnavailableStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return const <String>{
        'lost',
        'missing',
        'absent',
        'destroyed',
        'consumed',
        'disposed',
        'discarded',
        'unavailable',
        '丢失',
        '遗失',
        '失踪',
        '销毁',
        '损毁',
        '消耗',
        '不存在',
      }.contains(normalized) ||
      normalized.startsWith('lost:') ||
      normalized.startsWith('missing:');
}

bool _isRecoverableStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return const <String>{
        'lost',
        'missing',
        'absent',
        'unavailable',
        'discarded',
        '丢失',
        '遗失',
        '失踪',
      }.contains(normalized) ||
      normalized.startsWith('lost:') ||
      normalized.startsWith('missing:');
}

class _ActorRegistry {
  _ActorRegistry._(this.tokens, this._displayByActorId, this._actorIdByToken);

  factory _ActorRegistry.fromBrief(
    SceneBrief brief,
    List<NarrativeContinuityLedgerEntry> ledger,
  ) {
    final tokens = <_ActorToken>[];
    final displayByActorId = <String, String>{};
    final actorIdByToken = <String, String>{};

    void addActor({
      required String actorId,
      required String displayName,
      required Iterable<String> aliases,
    }) {
      final canonical = actorId.trim();
      if (canonical.isEmpty) return;
      displayByActorId.putIfAbsent(canonical, () => displayName.trim());
      for (final rawAlias in aliases) {
        final alias = rawAlias.trim();
        if (alias.isEmpty) continue;
        final existing = actorIdByToken[alias];
        if (existing != null && existing != canonical) continue;
        actorIdByToken[alias] = canonical;
      }
    }

    for (final candidate in brief.cast) {
      final actorId = candidate.characterId.trim().isEmpty
          ? candidate.name.trim()
          : candidate.characterId.trim();
      addActor(
        actorId: actorId,
        displayName: candidate.name.trim().isEmpty
            ? actorId
            : candidate.name.trim(),
        aliases: [candidate.characterId, candidate.name],
      );
    }
    for (final entry in ledger) {
      final holder = entry.holder.trim();
      if (holder.isEmpty || actorIdByToken.containsKey(holder)) continue;
      addActor(actorId: holder, displayName: holder, aliases: [holder]);
    }

    for (final tokenEntry in actorIdByToken.entries) {
      tokens.add(_ActorToken(actorId: tokenEntry.value, token: tokenEntry.key));
    }
    tokens.sort(
      (left, right) => right.token.length.compareTo(left.token.length),
    );
    return _ActorRegistry._(tokens, displayByActorId, actorIdByToken);
  }

  final List<_ActorToken> tokens;
  final Map<String, String> _displayByActorId;
  final Map<String, String> _actorIdByToken;

  String canonicalize(String token) => _actorIdByToken[token] ?? token;

  String? canonicalizeKnown(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) return '';
    if (_displayByActorId.containsKey(normalized)) return normalized;
    return _actorIdByToken[normalized];
  }

  Iterable<String> evidenceNames(String actorId) sync* {
    for (final entry in _actorIdByToken.entries) {
      if (entry.value == actorId) yield entry.key;
    }
  }

  String displayName(String? actorId) {
    if (actorId == null || actorId.isEmpty) return '无有效持有人';
    return _displayByActorId[actorId] ?? actorId;
  }
}

class _ActorToken {
  const _ActorToken({required this.actorId, required this.token});

  final String actorId;
  final String token;
}

enum _ContinuityEventType {
  recovery(0),
  possession(1),
  transfer(2);

  const _ContinuityEventType(this.priority);

  final int priority;
}

class _ContinuityEvent {
  const _ContinuityEvent({
    required this.type,
    required this.actorId,
    required this.alias,
    required this.start,
    required this.end,
    this.targetActorId,
  });

  final _ContinuityEventType type;
  final String actorId;
  final String? targetActorId;
  final String alias;
  final int start;
  final int end;
}

class _ContinuityLedgerFormatError implements Exception {
  const _ContinuityLedgerFormatError(this.message);

  final String message;
}

class _DuplicateEntityDeclarationError implements Exception {
  const _DuplicateEntityDeclarationError(this.message);

  final String message;
}

class _DeclaredEntity {
  _DeclaredEntity({
    required this.entityId,
    required List<String> aliases,
    required List<_DeclaredEntityEvent> events,
  }) : aliases = List<String>.unmodifiable(aliases),
       events = List<_DeclaredEntityEvent>.unmodifiable(events);

  final String entityId;
  final List<String> aliases;
  final List<_DeclaredEntityEvent> events;
}

enum _DeclaredEntityEventKind {
  introduce,
  observe,
  transfer,
  relocate,
  lose,
  destroy,
  discard,
  recover,
  rename,
}

class _DeclaredEntityEvent {
  const _DeclaredEntityEvent({
    required this.eventId,
    required this.kind,
    required this.evidence,
    required this.alias,
    required this.previousAlias,
    required this.fromHolder,
    required this.holder,
    required this.location,
    required this.status,
  });

  final String eventId;
  final _DeclaredEntityEventKind kind;
  final String evidence;
  final String alias;
  final String previousAlias;
  final String fromHolder;
  final String holder;
  final String location;
  final String status;
}
