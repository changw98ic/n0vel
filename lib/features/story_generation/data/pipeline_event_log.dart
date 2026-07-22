import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';

import '../domain/contracts/event_log.dart';
import '../domain/contracts/stage_runner.dart';
import 'generation_evidence_fingerprints.dart';
import 'story_generation_pass_retry.dart';

/// Maximum events held in the in-memory ring buffer.
const int _defaultRingBufferSize = 1024;

/// Private JSONL event committed after each completed formal provider call.
const String storyGenerationAttemptIntentRecordedEventType =
    'story_generation_attempt_intent_recorded';
const String storyGenerationAttemptIntentEventSchemaVersion =
    'story-generation-attempt-intent-event-v1';
const String storyGenerationEvidenceJournalClaimRecordedEventType =
    'story_generation_evidence_journal_claim_recorded';
const String storyGenerationEvidenceJournalClaimSchemaVersion =
    'story-generation-evidence-journal-claim-v1';
const String storyGenerationAttemptEvidenceRecordedEventType =
    'story_generation_attempt_evidence_recorded';
const String storyGenerationAttemptEvidenceEventSchemaVersion =
    'story-generation-attempt-evidence-event-v1';
const String storyGenerationArtifactSealRecordedEventType =
    'story_generation_artifact_seal_recorded';
const String storyGenerationArtifactSealSchemaVersion =
    'story-generation-artifact-seal-v1';
const String storyGenerationAttemptEvidenceEnvelopeRecordedEventType =
    'story_generation_attempt_evidence_envelope_recorded';
const String storyGenerationAttemptEvidenceEnvelopePendingEventType =
    'story_generation_attempt_evidence_envelope_pending';
const String storyGenerationEvidenceInvalidatedEventType =
    'story_generation_evidence_invalidated';
const String storyGenerationEvidenceInvalidatedSchemaVersion =
    'story-generation-evidence-invalidated-v1';
const Set<String> storyGenerationFinalProseSourceCallSites = <String>{
  'scene-editorial-generator',
  'language-polish',
};

/// Private-manifest persistence required by no-redraw experiment runs.
///
/// Implementations must make a completed [flush] observable through
/// [readPersistedEvents]. A volatile ring buffer is not an evidence sink. This
/// boundary must never persist a blind-review projection beside private
/// provider or arm identities; G004 exports blind packages separately.
abstract interface class PipelineEvidenceSink {
  bool get canPersistAndRetrieveEvidence;

  /// Stable, non-secret locator for the persisted evidence.
  String? get evidenceLocator;

  /// Fails before provider dispatch when persistence cannot be prepared.
  Future<void> prepareEvidencePersistence();

  /// Atomically claims one run/scene identity and durably records that claim.
  ///
  /// A fresh claim returns an empty list only after its journal-open record is
  /// append-visible. Existing durable records are returned without appending a
  /// second claim. A concurrent in-process claim for the same run/scene
  /// namespace must fail across every sink before either caller can persist an
  /// intent.
  Future<List<PipelineEvent>> claimStoryGenerationEvidenceJournal({
    required String evidenceRunId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
  });

  /// Append one private evidence event and make it observable before the
  /// returned future completes. Retry state machines use this as a commit
  /// barrier between physical/formal attempts.
  Future<void> appendAndFlushEvidence(PipelineEvent event);

  Future<List<PipelineEvent>> readPersistedEvents();
}

/// Runtime-only proof that this exact concrete JSONL writer currently owns
/// both its process reservation and its OS file lock.
///
/// Merely implementing [PipelineEvidenceSink], returning an absolute-looking
/// locator, or replaying self-consistent events cannot create this value. It is
/// issued and consumed inside this library before a journal is exposed.
@pragma('vm:isolate-unsendable')
final class _DurableEvidenceSinkAuthority {
  _DurableEvidenceSinkAuthority._({
    required PipelineEventLogImpl issuer,
    required String absoluteJsonlPath,
  }) : _issuer = issuer,
       _absoluteJsonlPath = absoluteJsonlPath;

  final PipelineEventLogImpl _issuer;
  final String _absoluteJsonlPath;
  bool _consumed = false;

  bool consumeFor(PipelineEventLogImpl sink) {
    if (_consumed) return false;
    _consumed = true;
    return identical(_issuer, sink) &&
        sink._holdsPreparedEvidenceLease(_absoluteJsonlPath);
  }
}

/// One attempt intent rehydrated from its persisted journal-admission slot.
///
/// The sequence is evidence, not presentation order. Consumers issuing a
/// durable receipt must retain it rather than deriving a new sequence from a
/// list they happen to hold in memory.
final class VerifiedStoryGenerationAttemptAdmission {
  const VerifiedStoryGenerationAttemptAdmission({
    required this.sequenceNo,
    required this.intent,
  });

  final int sequenceNo;
  final StoryGenerationAttemptIntent intent;
}

/// Exact prose-producing provider attempt re-read from the durable artifact
/// seal after terminal journal verification.
///
/// This is deliberately narrower than "any successful attempt whose bytes
/// happen to match": the logical attempt and its allowlisted prose callsite
/// are both part of the durable receipt identity.
final class VerifiedStoryGenerationFinalProseSource {
  const VerifiedStoryGenerationFinalProseSource._({
    required this.logicalAttemptId,
    required this.callSiteId,
  });

  final String logicalAttemptId;
  final String callSiteId;

  Map<String, Object?> toCanonicalMap() => <String, Object?>{
    'logicalAttemptId': logicalAttemptId,
    'callSiteId': callSiteId,
  };
}

/// Runtime-only one-shot authority proving that one complete formal intent was
/// appended, flushed, and re-read under this journal's durable claim.
///
/// The class is final and its constructor is library-private: callers can
/// carry the value but cannot construct, implement, deserialize, or reset it.
@pragma('vm:isolate-unsendable')
final class PipelineCommittedIntentAuthority {
  PipelineCommittedIntentAuthority._(StoryGenerationAttemptIntent intent)
    : _privateIntentDigest = intent.privateIntentDigest;

  final String _privateIntentDigest;
  bool _consumed = false;

  /// Consumes this authority against the complete canonical intent, not only
  /// its logical id. A mismatched attempt burns the authority and fails closed.
  bool consumeForFormalDispatch(Map<String, Object?> completeIntent) {
    if (_consumed) return false;
    _consumed = true;
    return AppLlmCanonicalHash.domainHash(
          'story-generation-attempt-intent-record-v1',
          completeIntent,
        ) ==
        _privateIntentDigest;
  }
}

/// One-shot, runtime-only authority to mint a receipt from a terminally
/// revalidated journal. It binds the public receipt factory to the exact
/// canonical chain that this journal re-read from storage; it is never
/// persisted or reconstructed from receipt-shaped DTOs.
@pragma('vm:isolate-unsendable')
final class StoryGenerationEvidenceReceiptAuthority {
  StoryGenerationEvidenceReceiptAuthority._(
    this._scopeDigest,
    this.finalProseSource,
  );

  final String _scopeDigest;
  final VerifiedStoryGenerationFinalProseSource finalProseSource;
  bool _consumed = false;

  bool consumeForReceipt({
    required String evidenceRunId,
    required String sceneId,
    required String generationArmPolicy,
    required String preparedBriefDigest,
    required Iterable<StoryGenerationAttemptIntent> intents,
    required StoryGenerationAttemptEvidenceEnvelope envelope,
    required ArtifactDigest sealedArtifactDigest,
  }) {
    if (_consumed) return false;
    // Burn on first presentation, including mismatch, so the authority cannot
    // be probed and retried as a receipt-pairing oracle.
    _consumed = true;
    final observed = _receiptAuthorityDigest(
      evidenceRunId: evidenceRunId,
      sceneId: sceneId,
      generationArmPolicy: generationArmPolicy,
      preparedBriefDigest: preparedBriefDigest,
      intents: intents,
      terminalEnvelopeDigest: _terminalEnvelopeDigest(envelope),
      sealedArtifactDigest: sealedArtifactDigest,
      finalProseSource: finalProseSource,
    );
    if (observed != _scopeDigest) return false;
    return true;
  }
}

String _receiptAuthorityDigest({
  required String evidenceRunId,
  required String sceneId,
  required String generationArmPolicy,
  required String preparedBriefDigest,
  required Iterable<StoryGenerationAttemptIntent> intents,
  required String terminalEnvelopeDigest,
  required ArtifactDigest sealedArtifactDigest,
  required VerifiedStoryGenerationFinalProseSource finalProseSource,
}) => AppLlmCanonicalHash.domainHash(
  'story-generation-receipt-authority-v3',
  <String, Object?>{
    'evidenceRunId': evidenceRunId,
    'sceneId': sceneId,
    'generationArmPolicy': generationArmPolicy,
    'preparedBriefDigest': preparedBriefDigest,
    'intents': <Object?>[for (final intent in intents) intent.toPrivateJson()],
    'terminalEnvelopeDigest': terminalEnvelopeDigest,
    'sealedArtifactDigest': sealedArtifactDigest.toCanonicalMap(),
    'finalProseSource': finalProseSource.toCanonicalMap(),
  },
);

String _terminalEnvelopeDigest(
  StoryGenerationAttemptEvidenceEnvelope envelope,
) => _terminalEnvelopeDigestFromPrivate(envelope.toPrivateJson());

String _terminalEnvelopeDigestFromPrivate(Map<String, Object?> envelope) =>
    AppLlmCanonicalHash.domainHash(
      'story-generation-terminal-envelope-v1',
      envelope,
    );

/// Process-crash fail-closed private journal for one no-redraw scene run.
///
/// Sequence numbers are reserved synchronously before the first await, so
/// concurrent role/provider calls cannot claim the same slot. Each completed
/// attempt and candidate seal is appended and flushed before its caller may
/// continue. The final envelope is persisted only after it reconciles with
/// those records. The sink promises append visibility after `IOSink.flush`;
/// it does not claim power-loss durability because no filesystem `fsync`
/// contract is available at this boundary.
final class PipelineStoryGenerationEvidenceJournal {
  PipelineStoryGenerationEvidenceJournal._({
    required PipelineEventLogImpl sink,
    required _DurableEvidenceSinkAuthority durableSinkAuthority,
    required String evidenceRunId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
  }) : _sink = sink,
       evidenceRunId = _requiredJournalIdentity(evidenceRunId, 'evidenceRunId'),
       sceneId = _requiredJournalIdentity(sceneId, 'sceneId'),
       preparedBriefDigest = _requiredSha256(
         preparedBriefDigest,
         'preparedBriefDigest',
       ),
       generationArmPolicy = _requiredJournalIdentity(
         generationArmPolicy,
         'generationArmPolicy',
       ) {
    if (!durableSinkAuthority.consumeFor(sink)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'evidence journal requires one concrete locked JSONL sink authority',
      );
    }
  }

  final PipelineEventLogImpl _sink;
  final String sceneId;
  final String preparedBriefDigest;
  final String generationArmPolicy;
  final String evidenceRunId;
  final Map<String, _IntentReservation> _intentReservations =
      <String, _IntentReservation>{};
  final List<StoryGenerationAttemptIntent> _reservedIntents =
      <StoryGenerationAttemptIntent>[];
  final List<_AttemptReservation> _reservedAttempts = <_AttemptReservation>[];
  ArtifactDigest? _reservedArtifactSeal;
  String? _sealedArtifactSourceLogicalAttemptId;
  String? _sealedArtifactSourceCallSiteId;
  Future<ArtifactDigest>? _artifactSealCommit;
  List<VerifiedStoryGenerationAttemptAdmission>?
  _verifiedAdmissionOrderedAdmissions;
  bool _receiptAuthorityIssued = false;
  bool _terminalEvidenceComplete = false;
  String? _verifiedTerminalEnvelopeDigest;
  VerifiedStoryGenerationFinalProseSource? _verifiedFinalProseSource;
  _EvidenceJournalState _state = _EvidenceJournalState.created;

  int get attemptCount => _reservedAttempts.length;
  ArtifactDigest? get artifactSeal => _reservedArtifactSeal;
  List<StoryGenerationAttemptIntent> get intents =>
      List<StoryGenerationAttemptIntent>.unmodifiable(_reservedIntents);

  /// The only intent ordering that may feed a receipt. It is reconstructed
  /// from the terminally re-read JSONL chain, not accepted from a caller's
  /// in-memory list or completion order.
  List<StoryGenerationAttemptIntent> get verifiedAdmissionOrderedIntents {
    final verified = verifiedAdmissionOrderedAdmissions;
    return List<StoryGenerationAttemptIntent>.unmodifiable(
      verified.map((admission) => admission.intent),
    );
  }

  /// Rehydrated records including their persisted admission sequence number.
  /// This is the required source for durable receipt issuance.
  List<VerifiedStoryGenerationAttemptAdmission>
  get verifiedAdmissionOrderedAdmissions {
    final verified = _verifiedAdmissionOrderedAdmissions;
    if (verified == null || _state != _EvidenceJournalState.closed) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'admission-order intents are unavailable before terminal verification',
      );
    }
    return List<VerifiedStoryGenerationAttemptAdmission>.unmodifiable(verified);
  }

  /// Hands the receipt factory a one-shot authority only after the terminal
  /// envelope event has been flushed and re-read from the evidence sink.
  StoryGenerationEvidenceReceiptAuthority issueReceiptAuthority({
    required ArtifactDigest sealedArtifactDigest,
  }) {
    final verified = _verifiedAdmissionOrderedAdmissions;
    final terminalEnvelopeDigest = _verifiedTerminalEnvelopeDigest;
    final finalProseSource = _verifiedFinalProseSource;
    if (_state != _EvidenceJournalState.closed ||
        verified == null ||
        !_terminalEvidenceComplete ||
        terminalEnvelopeDigest == null ||
        finalProseSource == null ||
        _receiptAuthorityIssued ||
        _reservedArtifactSeal?.digest != sealedArtifactDigest.digest ||
        _reservedArtifactSeal?.byteLength != sealedArtifactDigest.byteLength) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'receipt authority is unavailable before one terminal verified journal',
      );
    }
    _receiptAuthorityIssued = true;
    return StoryGenerationEvidenceReceiptAuthority._(
      _receiptAuthorityDigest(
        evidenceRunId: evidenceRunId,
        sceneId: sceneId,
        generationArmPolicy: generationArmPolicy,
        preparedBriefDigest: preparedBriefDigest,
        intents: verified.map((admission) => admission.intent),
        terminalEnvelopeDigest: terminalEnvelopeDigest,
        sealedArtifactDigest: sealedArtifactDigest,
        finalProseSource: finalProseSource,
      ),
      finalProseSource,
    );
  }

  /// Opens a fresh scene journal or rejects a reused/indeterminate identity.
  /// This scan is required before the retry scope (and therefore before any
  /// provider dispatch) is entered.
  Future<void> _prepare() async {
    if (_state != _EvidenceJournalState.created) {
      throw StateError('evidence journal was already prepared');
    }
    final existing = await _sink.claimStoryGenerationEvidenceJournal(
      evidenceRunId: evidenceRunId,
      sceneId: sceneId,
      preparedBriefDigest: preparedBriefDigest,
      generationArmPolicy: generationArmPolicy,
    );
    if (existing.isEmpty) {
      _state = _EvidenceJournalState.open;
      return;
    }

    final hasTerminal = existing.any(
      (event) =>
          event.eventType ==
              storyGenerationAttemptEvidenceEnvelopeRecordedEventType ||
          event.eventType == storyGenerationEvidenceInvalidatedEventType,
    );
    if (hasTerminal) {
      _state = _EvidenceJournalState.closed;
      throw StoryGenerationEvidenceIntegrityFailure(
        'evidence run/scene identity is already closed and cannot dispatch again',
      );
    }

    final intentIds = <String>{};
    final outcomeIds = <String>{};
    for (final event in existing) {
      final privateRecord = _stringMap(event.metadata['private']);
      final logicalAttemptId = privateRecord?['logicalAttemptId']?.toString();
      if (event.eventType == storyGenerationAttemptIntentRecordedEventType &&
          _sha256(logicalAttemptId)) {
        intentIds.add(logicalAttemptId!);
      }
      if (event.eventType == storyGenerationAttemptEvidenceRecordedEventType &&
          _sha256(logicalAttemptId)) {
        outcomeIds.add(logicalAttemptId!);
      }
    }
    final orphanIds = intentIds.difference(outcomeIds).toList()..sort();
    await _appendInvalidation(
      reason: orphanIds.isEmpty
          ? 'unfinished_journal_recovered'
          : 'indeterminate_provider_attempt_recovered',
      logicalAttemptIds: orphanIds,
    );
    _state = _EvidenceJournalState.invalidated;
    throw StoryGenerationEvidenceIntegrityFailure(
      orphanIds.isEmpty
          ? 'evidence run/scene identity has unfinished durable records'
          : 'write-ahead intent has no durable outcome; provider replay is forbidden',
    );
  }

  Future<PipelineCommittedIntentAuthority> persistIntent(
    StoryGenerationAttemptIntent intent,
  ) async {
    _requireOpen('persist an attempt intent');
    if (intent.evidenceRunId != evidenceRunId ||
        intent.sceneId != sceneId ||
        intent.preparedBriefDigest != preparedBriefDigest ||
        intent.generationArmPolicy != generationArmPolicy) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'attempt intent does not belong to this evidence journal',
      );
    }
    if (_intentReservations.containsKey(intent.logicalAttemptId)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'duplicate logical provider attempt intent',
      );
    }
    final sequenceNo = _intentReservations.length;
    final reservation = _IntentReservation(
      sequenceNo: sequenceNo,
      digest: intent.privateIntentDigest,
    );
    // Reserve synchronously before the first await so concurrent role calls
    // cannot claim the same intent sequence or logical id.
    _intentReservations[intent.logicalAttemptId] = reservation;
    _reservedIntents.add(intent);
    final intentEvent = PipelineEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      stageId: 'experiment_evidence',
      eventType: storyGenerationAttemptIntentRecordedEventType,
      metadata: <String, Object?>{
        'schemaVersion': storyGenerationAttemptIntentEventSchemaVersion,
        'visibility': 'private',
        'evidenceRunId': evidenceRunId,
        'sceneId': sceneId,
        'preparedBriefDigest': preparedBriefDigest,
        'private': <String, Object?>{
          'sequenceNo': sequenceNo,
          'attemptIntentDigest': intent.privateIntentDigest,
          ...intent.toPrivateJson(),
        },
      },
    );
    await _sink.appendAndFlushEvidence(intentEvent);

    // Append success alone is insufficient authority. Re-read the sink and
    // prove this exact sequence is unique, follows this journal's durable
    // claim, and still validates against the in-memory reservation/digest.
    final persisted = await _sink.readPersistedEvents();
    final runEvents = _eventsForThisJournal(persisted);
    final claims = runEvents
        .where(
          (event) =>
              event.eventType ==
              storyGenerationEvidenceJournalClaimRecordedEventType,
        )
        .toList(growable: false);
    if (claims.length != 1 || runEvents.indexOf(claims.single) != 0) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'attempt intent authority requires one durable leading journal claim',
      );
    }
    _validatePersistedJournalClaim(claims.single);
    final matching = runEvents
        .where((event) {
          if (event.eventType !=
              storyGenerationAttemptIntentRecordedEventType) {
            return false;
          }
          final privateRecord = event.metadata['private'];
          return privateRecord is Map &&
              privateRecord['sequenceNo'] == sequenceNo &&
              privateRecord['logicalAttemptId'] == intent.logicalAttemptId;
        })
        .toList(growable: false);
    if (matching.length != 1 ||
        runEvents.indexOf(matching.single) <=
            runEvents.indexOf(claims.single) ||
        _validatePersistedIntent(matching.single, sequenceNo) !=
            intent.logicalAttemptId) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'attempt intent authority could not re-read its unique claimed sequence',
      );
    }
    reservation.intentCommitted = true;
    return PipelineCommittedIntentAuthority._(intent);
  }

  Future<void> persistAttempt(StoryGenerationAttemptEvidence evidence) async {
    _requireOpen('persist an attempt outcome');
    final verification = verifyStoryGenerationAttemptEvidenceJson(
      Map<String, Object?>.from(evidence.toJson()),
    );
    if (!verification.evidenceComplete) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'attempt outcome is not canonically admissible: '
        '${verification.errors.join(', ')}',
      );
    }
    final logicalAttemptId = evidence.logicalAttemptId;
    final intent = logicalAttemptId == null
        ? null
        : _intentReservations[logicalAttemptId];
    if (intent == null || !intent.intentCommitted || intent.outcomeReserved) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'attempt outcome is missing one committed write-ahead intent',
      );
    }
    if (evidence.routeResolutionRequired ||
        evidence.providerBoundaryReceiptRequired) {
      final receipt = evidence.providerBoundaryReceipt;
      final providerOutcomeSeal = evidence.providerOutcomeSeal;
      final witness = evidence.formalDispatchWitness;
      if (receipt == null ||
          providerOutcomeSeal == null ||
          witness == null ||
          !witness.consumeForStoryGenerationAttempt(
            logicalAttemptId: logicalAttemptId!,
            providerBoundaryReceipt: receipt,
            providerOutcomeSeal: providerOutcomeSeal,
          )) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'formal attempt provenance was not issued by the App LLM IO boundary',
        );
      }
    }
    final sequenceNo = _reservedAttempts.length;
    final evidenceDigest = evidence.privateEvidenceDigest;
    intent.outcomeReserved = true;
    _reservedAttempts.add(
      _AttemptReservation(
        logicalAttemptId: logicalAttemptId!,
        digest: evidenceDigest,
      ),
    );
    await _sink.appendAndFlushEvidence(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'experiment_evidence',
        eventType: storyGenerationAttemptEvidenceRecordedEventType,
        metadata: <String, Object?>{
          'schemaVersion': storyGenerationAttemptEvidenceEventSchemaVersion,
          'visibility': 'private',
          'evidenceRunId': evidenceRunId,
          'sceneId': sceneId,
          'preparedBriefDigest': preparedBriefDigest,
          'evidenceComplete': evidence.evidenceComplete,
          'private': <String, Object?>{
            'sequenceNo': sequenceNo,
            'attemptEvidenceDigest': evidenceDigest,
            'generationArmPolicy': generationArmPolicy,
            ...evidence.toJson(),
          },
        },
      ),
    );
    intent.outcomeCommitted = true;
  }

  Future<ArtifactDigest> sealArtifact({
    required String stageId,
    required String artifactText,
    required String sourceLogicalAttemptId,
    required String sourceCallSiteId,
  }) {
    _requireOpen('seal an artifact');
    if (!_sha256(sourceLogicalAttemptId) ||
        !storyGenerationFinalProseSourceCallSites.contains(sourceCallSiteId)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'artifact seal requires a successful final-prose provider attempt id',
      );
    }
    final digest = ArtifactDigest.fromUtf8String(artifactText);
    final reserved = _reservedArtifactSeal;
    if (reserved != null &&
        (reserved.digest != digest.digest ||
            _sealedArtifactSourceLogicalAttemptId != sourceLogicalAttemptId ||
            _sealedArtifactSourceCallSiteId != sourceCallSiteId)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'no-redraw run attempted to seal two different candidate artifacts',
      );
    }
    _reservedArtifactSeal ??= digest;
    _sealedArtifactSourceLogicalAttemptId ??= sourceLogicalAttemptId;
    _sealedArtifactSourceCallSiteId ??= sourceCallSiteId;
    return _artifactSealCommit ??= _commitArtifactSeal(
      stageId: stageId,
      digest: digest,
      sourceLogicalAttemptId: sourceLogicalAttemptId,
      sourceCallSiteId: sourceCallSiteId,
    );
  }

  Future<ArtifactDigest> _commitArtifactSeal({
    required String stageId,
    required ArtifactDigest digest,
    required String sourceLogicalAttemptId,
    required String sourceCallSiteId,
  }) async {
    await _sink.appendAndFlushEvidence(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'experiment_evidence',
        eventType: storyGenerationArtifactSealRecordedEventType,
        metadata: <String, Object?>{
          'schemaVersion': storyGenerationArtifactSealSchemaVersion,
          'visibility': 'private',
          'evidenceRunId': evidenceRunId,
          'sceneId': sceneId,
          'preparedBriefDigest': preparedBriefDigest,
          'private': <String, Object?>{
            'sealedAtStageId': stageId,
            'generationArmPolicy': generationArmPolicy,
            'artifactDigest': digest.toCanonicalMap(),
            'sourceLogicalAttemptId': sourceLogicalAttemptId,
            'sourceCallSiteId': sourceCallSiteId,
          },
        },
      ),
    );
    return digest;
  }

  Future<bool> persistAndVerifyEnvelope({
    required StoryGenerationAttemptEvidenceEnvelope envelope,
    required bool completed,
    required ArtifactDigest? finalArtifactDigest,
  }) async {
    _requireOpen('persist an evidence envelope');
    _verifyEnvelopeAgainstReservations(envelope);
    final unclosedIntents = _intentReservations.entries
        .where((entry) => !entry.value.outcomeCommitted)
        .map((entry) => entry.key)
        .toList(growable: false);
    if (unclosedIntents.isNotEmpty) {
      await _appendInvalidation(
        reason: 'indeterminate_provider_attempt',
        logicalAttemptIds: unclosedIntents,
      );
      _state = _EvidenceJournalState.invalidated;
      throw StoryGenerationEvidenceIntegrityFailure(
        'write-ahead intent has no durable attempt outcome',
      );
    }
    final sealed = _reservedArtifactSeal;
    final sealedSourceIsValid = _sealedArtifactSourceMatchesEnvelope(envelope);
    final evidenceComplete =
        completed &&
        finalArtifactDigest != null &&
        sealed != null &&
        finalArtifactDigest.digest == sealed.digest &&
        finalArtifactDigest.byteLength == sealed.byteLength &&
        envelope.evidenceComplete &&
        sealedSourceIsValid;
    _state = _EvidenceJournalState.pending;
    try {
      await _sink.appendAndFlushEvidence(
        _envelopeEvent(
          eventType: storyGenerationAttemptEvidenceEnvelopePendingEventType,
          admissionState: 'pending',
          envelope: envelope,
          completed: completed,
          evidenceComplete: false,
          proposedEvidenceComplete: evidenceComplete,
          finalArtifactDigest: finalArtifactDigest,
        ),
      );
      await _verifyPersistedChain(
        envelope: envelope,
        envelopeEventType:
            storyGenerationAttemptEvidenceEnvelopePendingEventType,
        completed: completed,
        finalArtifactDigest: finalArtifactDigest,
        evidenceComplete: evidenceComplete,
      );
      await _sink.appendAndFlushEvidence(
        _envelopeEvent(
          eventType: storyGenerationAttemptEvidenceEnvelopeRecordedEventType,
          admissionState: evidenceComplete ? 'committed' : 'rejected',
          envelope: envelope,
          completed: completed,
          evidenceComplete: evidenceComplete,
          finalArtifactDigest: finalArtifactDigest,
        ),
      );
      await _verifyPersistedChain(
        envelope: envelope,
        envelopeEventType:
            storyGenerationAttemptEvidenceEnvelopeRecordedEventType,
        completed: completed,
        finalArtifactDigest: finalArtifactDigest,
        evidenceComplete: evidenceComplete,
      );
      _verifiedAdmissionOrderedAdmissions =
          await _rehydrateVerifiedAdmissionOrderedAdmissions();
      _verifiedTerminalEnvelopeDigest =
          await _rehydrateVerifiedTerminalEnvelopeDigest();
      _verifiedFinalProseSource = finalArtifactDigest == null
          ? null
          : await _rehydrateVerifiedFinalProseSource();
      _terminalEvidenceComplete = evidenceComplete;
      _state = _EvidenceJournalState.closed;
      return evidenceComplete;
    } on Object {
      await _bestEffortInvalidate('envelope_verification_failed');
      rethrow;
    }
  }

  Future<List<VerifiedStoryGenerationAttemptAdmission>>
  _rehydrateVerifiedAdmissionOrderedAdmissions() async {
    final persisted = await _sink.readPersistedEvents();
    final events = _eventsForThisJournal(persisted)
        .where(
          (event) =>
              event.eventType == storyGenerationAttemptIntentRecordedEventType,
        )
        .toList(growable: false);
    if (events.length != _intentReservations.length) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'terminal journal intent count changed during receipt admission',
      );
    }
    final ordered = <VerifiedStoryGenerationAttemptAdmission>[];
    for (var index = 0; index < events.length; index += 1) {
      _validatePersistedIntent(events[index], index);
      final privateRecord = _requiredPrivateRecord(events[index]);
      final payload = Map<String, Object?>.from(privateRecord)
        ..remove('sequenceNo')
        ..remove('attemptIntentDigest');
      ordered.add(
        VerifiedStoryGenerationAttemptAdmission(
          sequenceNo: index,
          intent: StoryGenerationAttemptIntent.fromVerifiedPrivateJson(payload),
        ),
      );
    }
    return List<VerifiedStoryGenerationAttemptAdmission>.unmodifiable(ordered);
  }

  Future<String> _rehydrateVerifiedTerminalEnvelopeDigest() async {
    final persisted = await _sink.readPersistedEvents();
    final terminalEvents = _eventsForThisJournal(persisted)
        .where(
          (event) =>
              event.eventType ==
              storyGenerationAttemptEvidenceEnvelopeRecordedEventType,
        )
        .toList(growable: false);
    if (terminalEvents.length != 1) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'terminal journal envelope count changed during receipt admission',
      );
    }
    final persistedEnvelope = Map<String, Object?>.from(
      _requiredPrivateRecord(terminalEvents.single),
    );
    if (persistedEnvelope.remove('generationArmPolicy') !=
        generationArmPolicy) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'terminal journal envelope arm policy changed during receipt admission',
      );
    }
    return _terminalEnvelopeDigestFromPrivate(persistedEnvelope);
  }

  Future<VerifiedStoryGenerationFinalProseSource>
  _rehydrateVerifiedFinalProseSource() async {
    final persisted = await _sink.readPersistedEvents();
    final sealEvents = _eventsForThisJournal(persisted)
        .where(
          (event) =>
              event.eventType == storyGenerationArtifactSealRecordedEventType,
        )
        .toList(growable: false);
    final reservedSeal = _reservedArtifactSeal;
    if (sealEvents.length != 1 || reservedSeal == null) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'terminal final-prose source requires one durable artifact seal',
      );
    }
    _validatePersistedArtifactSeal(
      sealEvents.single,
      reservedSeal,
      sourceLogicalAttemptId: _sealedArtifactSourceLogicalAttemptId,
      sourceCallSiteId: _sealedArtifactSourceCallSiteId,
    );
    final privateRecord = _requiredPrivateRecord(sealEvents.single);
    final logicalAttemptId = privateRecord['sourceLogicalAttemptId'];
    final callSiteId = privateRecord['sourceCallSiteId'];
    if (logicalAttemptId is! String ||
        !_sha256(logicalAttemptId) ||
        callSiteId is! String ||
        !storyGenerationFinalProseSourceCallSites.contains(callSiteId)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'durable artifact seal has an invalid final-prose source',
      );
    }
    return VerifiedStoryGenerationFinalProseSource._(
      logicalAttemptId: logicalAttemptId,
      callSiteId: callSiteId,
    );
  }

  PipelineEvent _envelopeEvent({
    required String eventType,
    required String admissionState,
    required StoryGenerationAttemptEvidenceEnvelope envelope,
    required bool completed,
    required bool evidenceComplete,
    bool? proposedEvidenceComplete,
    required ArtifactDigest? finalArtifactDigest,
  }) => PipelineEvent(
    timestampMs: DateTime.now().millisecondsSinceEpoch,
    stageId: 'experiment_evidence',
    eventType: eventType,
    metadata: <String, Object?>{
      'schemaVersion': envelope.schemaVersion,
      'visibility': 'private',
      'evidenceRunId': evidenceRunId,
      'sceneId': sceneId,
      'preparedBriefDigest': preparedBriefDigest,
      'runStatus': completed ? 'completed' : 'incomplete',
      'admissionState': admissionState,
      'evidenceComplete': evidenceComplete,
      'proposedEvidenceComplete': proposedEvidenceComplete,
      'attemptRecordCount': _reservedAttempts.length,
      'attemptEvidenceDigests': <String>[
        for (final attempt in _reservedAttempts) attempt.digest,
      ],
      if (_reservedArtifactSeal != null)
        'sealedArtifactDigest': _reservedArtifactSeal!.toCanonicalMap(),
      if (finalArtifactDigest != null)
        'finalArtifactDigest': finalArtifactDigest.toCanonicalMap(),
      'private': <String, Object?>{
        ...envelope.toPrivateJson(),
        'generationArmPolicy': generationArmPolicy,
      },
    },
  );

  void _verifyEnvelopeAgainstReservations(
    StoryGenerationAttemptEvidenceEnvelope envelope,
  ) {
    if (envelope.attempts.length != _reservedAttempts.length) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'attempt envelope count does not match durable reservations',
      );
    }
    for (var index = 0; index < envelope.attempts.length; index += 1) {
      if (envelope.attempts[index].privateEvidenceDigest !=
              _reservedAttempts[index].digest ||
          envelope.attempts[index].logicalAttemptId !=
              _reservedAttempts[index].logicalAttemptId) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'attempt envelope order does not match durable sequence $index',
        );
      }
    }
  }

  bool _sealedArtifactSourceMatchesEnvelope(
    StoryGenerationAttemptEvidenceEnvelope envelope,
  ) {
    final sealed = _reservedArtifactSeal;
    final sourceId = _sealedArtifactSourceLogicalAttemptId;
    final sourceCallSiteId = _sealedArtifactSourceCallSiteId;
    if (sealed == null ||
        sourceId == null ||
        sourceCallSiteId == null ||
        !storyGenerationFinalProseSourceCallSites.contains(sourceCallSiteId)) {
      return false;
    }
    return envelope.attempts.any(
      (attempt) =>
          attempt.logicalAttemptId == sourceId &&
          attempt.succeeded &&
          attempt.callSiteId == sourceCallSiteId &&
          attempt.artifactDigest?.domainTag == sealed.domainTag &&
          attempt.artifactDigest?.byteLength == sealed.byteLength &&
          attempt.artifactDigest?.digest == sealed.digest,
    );
  }

  Future<void> _verifyPersistedChain({
    required StoryGenerationAttemptEvidenceEnvelope envelope,
    required String envelopeEventType,
    required bool completed,
    required ArtifactDigest? finalArtifactDigest,
    required bool evidenceComplete,
  }) async {
    final persisted = await _sink.readPersistedEvents();
    final runEvents = _eventsForThisJournal(persisted);
    for (final event in runEvents) {
      if (event.metadata.containsKey('blind')) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'private evidence journal contains blind-custody data',
        );
      }
    }

    final claims = runEvents
        .where(
          (event) =>
              event.eventType ==
              storyGenerationEvidenceJournalClaimRecordedEventType,
        )
        .toList(growable: false);
    if (claims.length != 1 || runEvents.indexOf(claims.single) != 0) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'private evidence journal must begin with exactly one durable claim',
      );
    }
    _validatePersistedJournalClaim(claims.single);
    const claimPosition = 0;

    final intents = runEvents
        .where(
          (event) =>
              event.eventType == storyGenerationAttemptIntentRecordedEventType,
        )
        .toList(growable: false);
    if (intents.length != _intentReservations.length) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted intent count does not reconcile with provider attempts',
      );
    }
    final intentEventPosition = <String, int>{};
    for (var index = 0; index < intents.length; index += 1) {
      final logicalAttemptId = _validatePersistedIntent(intents[index], index);
      final intentPosition = runEvents.indexOf(intents[index]);
      if (intentPosition <= claimPosition) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'attempt intent $index is not preceded by its durable journal claim',
        );
      }
      intentEventPosition[logicalAttemptId] = intentPosition;
    }

    final attempts = runEvents
        .where(
          (event) =>
              event.eventType ==
              storyGenerationAttemptEvidenceRecordedEventType,
        )
        .toList(growable: false);
    if (attempts.length != _reservedAttempts.length) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted attempt count does not reconcile with the envelope',
      );
    }
    for (var index = 0; index < attempts.length; index += 1) {
      final logicalAttemptId = _validatePersistedAttempt(
        attempts[index],
        index,
      );
      final intentPosition = intentEventPosition[logicalAttemptId];
      if (intentPosition == null ||
          intentPosition >= runEvents.indexOf(attempts[index])) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'attempt outcome $index is not preceded by its durable intent',
        );
      }
    }

    final seals = runEvents
        .where(
          (event) =>
              event.eventType == storyGenerationArtifactSealRecordedEventType,
        )
        .toList(growable: false);
    final reservedSeal = _reservedArtifactSeal;
    if ((reservedSeal == null && seals.isNotEmpty) ||
        (reservedSeal != null && seals.length != 1)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted artifact seal count does not reconcile with the run',
      );
    }
    if (reservedSeal != null) {
      _validatePersistedArtifactSeal(
        seals.single,
        reservedSeal,
        sourceLogicalAttemptId: _sealedArtifactSourceLogicalAttemptId,
        sourceCallSiteId: _sealedArtifactSourceCallSiteId,
      );
    }

    final envelopes = runEvents
        .where((event) => event.eventType == envelopeEventType)
        .toList(growable: false);
    if (envelopes.length != 1) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'private attempt envelope phase is missing or duplicated',
      );
    }
    _validatePersistedEnvelope(
      event: envelopes.single,
      envelope: envelope,
      pending:
          envelopeEventType ==
          storyGenerationAttemptEvidenceEnvelopePendingEventType,
      completed: completed,
      finalArtifactDigest: finalArtifactDigest,
      evidenceComplete: evidenceComplete,
    );
  }

  String _validatePersistedIntent(PipelineEvent event, int sequenceNo) {
    _validatePrivateEventHeader(
      event,
      storyGenerationAttemptIntentEventSchemaVersion,
    );
    final privateRecord = _requiredPrivateRecord(event);
    final persistedDigest = privateRecord['attemptIntentDigest']?.toString();
    final payload = Map<String, Object?>.from(privateRecord)
      ..remove('sequenceNo')
      ..remove('attemptIntentDigest');
    final recomputed = AppLlmCanonicalHash.domainHash(
      'story-generation-attempt-intent-record-v1',
      payload,
    );
    final logicalAttemptId = payload['logicalAttemptId']?.toString();
    final reservation = logicalAttemptId == null
        ? null
        : _intentReservations[logicalAttemptId];
    if (privateRecord['sequenceNo'] != sequenceNo ||
        persistedDigest != recomputed ||
        reservation == null ||
        reservation.sequenceNo != sequenceNo ||
        reservation.digest != recomputed ||
        payload['evidenceRunId'] != evidenceRunId ||
        payload['sceneId'] != sceneId ||
        payload['preparedBriefDigest'] != preparedBriefDigest ||
        payload['generationArmPolicy'] != generationArmPolicy ||
        !_sha256(logicalAttemptId)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted attempt intent $sequenceNo failed canonical validation',
      );
    }
    return logicalAttemptId!;
  }

  String _validatePersistedAttempt(PipelineEvent event, int sequenceNo) {
    _validatePrivateEventHeader(
      event,
      storyGenerationAttemptEvidenceEventSchemaVersion,
    );
    final privateRecord = _requiredPrivateRecord(event);
    final persistedDigest = privateRecord['attemptEvidenceDigest']?.toString();
    final payload = Map<String, Object?>.from(privateRecord)
      ..remove('sequenceNo')
      ..remove('attemptEvidenceDigest')
      ..remove('generationArmPolicy');
    final recomputed = AppLlmCanonicalHash.domainHash(
      'story-generation-attempt-evidence-record-v1',
      payload,
    );
    final reservation = sequenceNo < _reservedAttempts.length
        ? _reservedAttempts[sequenceNo]
        : null;
    final logicalAttemptId = payload['logicalAttemptId']?.toString();
    if (privateRecord['sequenceNo'] != sequenceNo ||
        privateRecord['generationArmPolicy'] != generationArmPolicy ||
        persistedDigest != recomputed ||
        reservation == null ||
        reservation.digest != recomputed ||
        reservation.logicalAttemptId != logicalAttemptId ||
        event.metadata['evidenceComplete'] != payload['evidenceComplete'] ||
        !_sha256(logicalAttemptId)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted attempt record $sequenceNo failed canonical validation',
      );
    }
    final verification = verifyStoryGenerationAttemptEvidenceJson(payload);
    if (!verification.evidenceComplete) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted attempt record $sequenceNo is not canonically admissible: '
        '${verification.errors.join(', ')}',
      );
    }
    return logicalAttemptId!;
  }

  void _validatePersistedArtifactSeal(
    PipelineEvent event,
    ArtifactDigest expected, {
    required String? sourceLogicalAttemptId,
    required String? sourceCallSiteId,
  }) {
    _validatePrivateEventHeader(
      event,
      storyGenerationArtifactSealSchemaVersion,
    );
    final privateRecord = _requiredPrivateRecord(event);
    if (privateRecord['generationArmPolicy'] != generationArmPolicy ||
        privateRecord['sourceLogicalAttemptId'] != sourceLogicalAttemptId ||
        privateRecord['sourceCallSiteId'] != sourceCallSiteId ||
        !_canonicalEquals(
          privateRecord['artifactDigest'],
          expected.toCanonicalMap(),
        )) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted artifact seal digest or byte length does not match candidate',
      );
    }
  }

  void _validatePersistedEnvelope({
    required PipelineEvent event,
    required StoryGenerationAttemptEvidenceEnvelope envelope,
    required bool pending,
    required bool completed,
    required ArtifactDigest? finalArtifactDigest,
    required bool evidenceComplete,
  }) {
    _validatePrivateEventHeader(event, envelope.schemaVersion);
    final metadata = event.metadata;
    final persistedDigests = metadata['attemptEvidenceDigests'];
    final expectedDigests = <String>[
      for (final attempt in _reservedAttempts) attempt.digest,
    ];
    final privateEnvelope = _requiredPrivateRecord(event);
    final nestedAttempts = privateEnvelope['attempts'];
    if (metadata['attemptRecordCount'] != _reservedAttempts.length ||
        persistedDigests is! List ||
        !_sameStrings(persistedDigests, expectedDigests) ||
        metadata['runStatus'] != (completed ? 'completed' : 'incomplete') ||
        metadata['admissionState'] !=
            (pending
                ? 'pending'
                : (evidenceComplete ? 'committed' : 'rejected')) ||
        metadata['evidenceComplete'] != (pending ? false : evidenceComplete) ||
        (pending && metadata['proposedEvidenceComplete'] != evidenceComplete) ||
        privateEnvelope['schemaVersion'] != envelope.schemaVersion ||
        privateEnvelope['visibility'] != 'private' ||
        privateEnvelope['evidenceComplete'] != envelope.evidenceComplete ||
        privateEnvelope['generationArmPolicy'] != generationArmPolicy ||
        nestedAttempts is! List ||
        nestedAttempts.length != _reservedAttempts.length ||
        !_optionalArtifactMatches(
          metadata['sealedArtifactDigest'],
          _reservedArtifactSeal,
        ) ||
        !_optionalArtifactMatches(
          metadata['finalArtifactDigest'],
          finalArtifactDigest,
        )) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'private attempt envelope does not reconcile with durable records',
      );
    }
    for (var index = 0; index < nestedAttempts.length; index += 1) {
      final nested = _stringMap(nestedAttempts[index]);
      if (nested == null) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'private envelope attempt $index is not an object',
        );
      }
      final persistedDigest = nested['attemptEvidenceDigest']?.toString();
      final payload = Map<String, Object?>.from(nested)
        ..remove('sequenceNo')
        ..remove('attemptEvidenceDigest');
      final recomputed = AppLlmCanonicalHash.domainHash(
        'story-generation-attempt-evidence-record-v1',
        payload,
      );
      if (nested['sequenceNo'] != index ||
          persistedDigest != recomputed ||
          recomputed != _reservedAttempts[index].digest ||
          payload['logicalAttemptId'] !=
              _reservedAttempts[index].logicalAttemptId) {
        throw StoryGenerationEvidenceIntegrityFailure(
          'private envelope attempt $index failed canonical validation',
        );
      }
    }
  }

  void _validatePrivateEventHeader(PipelineEvent event, String schemaVersion) {
    if (event.stageId != 'experiment_evidence' ||
        event.metadata['schemaVersion'] != schemaVersion ||
        event.metadata['visibility'] != 'private' ||
        event.metadata['evidenceRunId'] != evidenceRunId ||
        event.metadata['sceneId'] != sceneId ||
        event.metadata['preparedBriefDigest'] != preparedBriefDigest ||
        event.metadata.containsKey('blind')) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted private evidence header is invalid',
      );
    }
  }

  void _validatePersistedJournalClaim(PipelineEvent event) {
    _validatePrivateEventHeader(
      event,
      storyGenerationEvidenceJournalClaimSchemaVersion,
    );
    final privateRecord = _requiredPrivateRecord(event);
    if (privateRecord['generationArmPolicy'] != generationArmPolicy ||
        privateRecord['claimState'] != 'open') {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted evidence journal claim is invalid',
      );
    }
  }

  Map<String, Object?> _requiredPrivateRecord(PipelineEvent event) {
    final value = _stringMap(event.metadata['private']);
    if (value == null || value.containsKey('blind')) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted private evidence payload is invalid',
      );
    }
    return value;
  }

  List<PipelineEvent> _eventsForThisJournal(Iterable<PipelineEvent> events) =>
      events
          .where(
            (event) =>
                event.metadata['evidenceRunId'] == evidenceRunId &&
                event.metadata['sceneId'] == sceneId,
          )
          .toList(growable: false);

  void _requireOpen(String operation) {
    if (_state != _EvidenceJournalState.open) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'cannot $operation after evidence journal is ${_state.name}',
      );
    }
  }

  Future<void> _appendInvalidation({
    required String reason,
    Iterable<String> logicalAttemptIds = const <String>[],
  }) => _sink.appendAndFlushEvidence(
    PipelineEvent(
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      stageId: 'experiment_evidence',
      eventType: storyGenerationEvidenceInvalidatedEventType,
      metadata: <String, Object?>{
        'schemaVersion': storyGenerationEvidenceInvalidatedSchemaVersion,
        'visibility': 'private',
        'evidenceRunId': evidenceRunId,
        'sceneId': sceneId,
        'preparedBriefDigest': preparedBriefDigest,
        'admissionState': 'invalidated',
        'evidenceComplete': false,
        'private': <String, Object?>{
          'generationArmPolicy': generationArmPolicy,
          'reason': reason,
          'logicalAttemptIds': List<String>.unmodifiable(logicalAttemptIds),
        },
      },
    ),
  );

  Future<void> _bestEffortInvalidate(String reason) async {
    try {
      await _appendInvalidation(reason: reason);
    } on Object {
      // Preserve the original verification/storage failure. Either way, this
      // in-memory journal is terminal and cannot dispatch again.
    }
    _state = _EvidenceJournalState.invalidated;
  }
}

enum _EvidenceJournalState { created, open, pending, closed, invalidated }

final class _IntentReservation {
  _IntentReservation({required this.sequenceNo, required this.digest});

  final int sequenceNo;
  final String digest;
  bool intentCommitted = false;
  bool outcomeReserved = false;
  bool outcomeCommitted = false;
}

final class _AttemptReservation {
  const _AttemptReservation({
    required this.logicalAttemptId,
    required this.digest,
  });

  final String logicalAttemptId;
  final String digest;
}

String _requiredJournalIdentity(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'required');
  }
  return normalized;
}

String _requiredSha256(String value, String field) {
  final normalized = _requiredJournalIdentity(value, field);
  if (!_sha256(normalized)) {
    throw ArgumentError.value(value, field, 'must be sha256:<lower-hex>');
  }
  return normalized;
}

Map<String, Object?>? _stringMap(Object? value) {
  if (value is! Map) return null;
  return Map<String, Object?>.from(value);
}

bool _sha256(String? value) =>
    value != null && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

bool _canonicalEquals(Object? left, Object? right) {
  try {
    return AppLlmCanonicalHash.canonicalJson(left) ==
        AppLlmCanonicalHash.canonicalJson(right);
  } on Object {
    return false;
  }
}

bool _optionalArtifactMatches(Object? persisted, ArtifactDigest? expected) {
  if (expected == null) return persisted == null;
  return _canonicalEquals(persisted, expected.toCanonicalMap());
}

bool _sameStrings(List<Object?> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// Propagates one durable sink through factories which create and discard
/// short-lived pipeline runners, including concurrent chapter orchestration.
final class PipelineEvidenceLogScope {
  const PipelineEvidenceLogScope._();

  static final Object _zoneKey = Object();

  static PipelineEventLogImpl? get current =>
      Zone.current[_zoneKey] as PipelineEventLogImpl?;

  static R run<R>({
    required PipelineEventLogImpl eventLog,
    required R Function() body,
  }) {
    if (!eventLog._hasConfiguredAbsoluteJsonlPath) {
      throw ArgumentError.value(
        eventLog,
        'eventLog',
        'must persist and retrieve no-redraw evidence',
      );
    }
    return runZoned(body, zoneValues: {_zoneKey: eventLog});
  }
}

/// Concrete [PipelineEventLog] with JSONL persistence and in-memory ring buffer.
///
/// Reuses the JSONL pattern from [AppEventLogStorage] but is scoped to
/// pipeline events only.
final class PipelineEventLogImpl extends PipelineEventLog
    implements PipelineEvidenceSink {
  PipelineEventLogImpl({
    String? jsonlPath,
    int ringBufferSize = _defaultRingBufferSize,
  }) : _jsonlPath = _normalizedJsonlPath(jsonlPath),
       _ringBufferSize = ringBufferSize;

  final String? _jsonlPath;
  final int _ringBufferSize;
  final List<PipelineEvent> _buffer = [];
  static final Set<String> _processEvidenceLeases = <String>{};
  static final Set<String> _processJournalClaims = <String>{};
  // Deliberate process-lifetime anti-replay tombstones. A caller-owned
  // run/scene namespace may reopen its original JSONL after a crash-style
  // dispose, but can never be rebound to a different evidence file in this
  // process. Private IO receipts cannot cross isolates/process restarts.
  static final Map<String, String> _processJournalNamespaceLocators =
      <String, String>{};
  final Set<String> _ownedJournalClaims = <String>{};
  IOSink? _sink;
  RandomAccessFile? _evidenceLeaseFile;
  bool _ownsProcessEvidenceLease = false;
  Future<void> _flushTail = Future<void>.value();

  @override
  bool get canPersistAndRetrieveEvidence => _jsonlPath != null;

  @override
  String? get evidenceLocator => _jsonlPath;

  bool get _hasConfiguredAbsoluteJsonlPath {
    final path = _jsonlPath;
    return path != null && path == File(path).absolute.path;
  }

  bool _holdsPreparedEvidenceLease(String absoluteJsonlPath) {
    final path = _jsonlPath;
    return path != null &&
        path == absoluteJsonlPath &&
        path == File(path).absolute.path &&
        FileSystemEntity.typeSync(path, followLinks: true) ==
            FileSystemEntityType.file &&
        _sink != null &&
        _evidenceLeaseFile != null &&
        _ownsProcessEvidenceLease &&
        _processEvidenceLeases.contains(path);
  }

  /// The sole construction boundary for a formal no-redraw evidence journal.
  ///
  /// The returned journal has already claimed and re-read its durable JSONL
  /// namespace. No provider code may run until this future succeeds.
  Future<PipelineStoryGenerationEvidenceJournal>
  openStoryGenerationEvidenceJournal({
    required String evidenceRunId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
  }) async {
    await prepareEvidencePersistence();
    final path = _jsonlPath;
    if (path == null || !_holdsPreparedEvidenceLease(path)) {
      throw StateError(
        'pipeline evidence journal requires a real absolute JSONL path and '
        'an exclusive prepared writer lease',
      );
    }
    final journal = PipelineStoryGenerationEvidenceJournal._(
      sink: this,
      durableSinkAuthority: _DurableEvidenceSinkAuthority._(
        issuer: this,
        absoluteJsonlPath: path,
      ),
      evidenceRunId: evidenceRunId,
      sceneId: sceneId,
      preparedBriefDigest: preparedBriefDigest,
      generationArmPolicy: generationArmPolicy,
    );
    await journal._prepare();
    return journal;
  }

  @override
  void emit(PipelineEvent event) {
    _buffer.add(event);
    if (_buffer.length > _ringBufferSize) {
      _buffer.removeAt(0);
    }
    if (_jsonlPath != null) {
      _appendToFile(event);
    }
  }

  @override
  List<PipelineEvent> query({
    String? stageId,
    String? eventType,
    FailureCode? failureCode,
  }) {
    return _buffer.where((e) {
      if (stageId != null && e.stageId != stageId) return false;
      if (eventType != null && e.eventType != eventType) return false;
      if (failureCode != null && e.failureCode != failureCode) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> flush() {
    final operation = _flushTail.then<void>((_) async {
      await _sink?.flush();
    });
    _flushTail = operation;
    return operation;
  }

  @override
  Future<void> prepareEvidencePersistence() async {
    final path = _jsonlPath;
    if (path == null) {
      throw StateError('pipeline event log has no persistent evidence sink');
    }
    if (_evidenceLeaseFile != null && _ownsProcessEvidenceLease) {
      await flush();
      return;
    }
    if (_processEvidenceLeases.contains(path)) {
      throw StateError(
        'pipeline evidence sink already has a writer lease for $path',
      );
    }
    // Reserve synchronously before opening/locking so two instances in this
    // isolate cannot race past the process-local guard.
    _processEvidenceLeases.add(path);
    _ownsProcessEvidenceLease = true;
    RandomAccessFile? leaseFile;
    final openedSinkForEvidence = _sink == null;
    try {
      leaseFile = await File('$path.lock').open(mode: FileMode.append);
      await leaseFile.lock(FileLock.exclusive);
      _evidenceLeaseFile = leaseFile;
      final evidenceFile = File(path);
      if (!await evidenceFile.exists()) {
        // IOSink creation is lazy on some platforms. Materialize the actual
        // JSONL file before a durable-sink authority is ever issued.
        await evidenceFile.create();
      }
      _sink ??= evidenceFile.openWrite(mode: FileMode.append);
      await flush();
    } on Object catch (error) {
      _evidenceLeaseFile = null;
      _processEvidenceLeases.remove(path);
      _ownsProcessEvidenceLease = false;
      try {
        await leaseFile?.unlock();
      } on Object {
        // The file may have failed before the lock was acquired.
      }
      try {
        await leaseFile?.close();
      } on Object {
        // Preserve the lock acquisition error.
      }
      if (openedSinkForEvidence) {
        try {
          await _sink?.close();
        } on Object {
          // Preserve the preparation error.
        }
        _sink = null;
      }
      throw StateError(
        'pipeline evidence sink could not acquire exclusive writer lease: '
        '$error',
      );
    }
  }

  @override
  Future<List<PipelineEvent>> claimStoryGenerationEvidenceJournal({
    required String evidenceRunId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
  }) {
    final path = _jsonlPath;
    if (path == null) {
      throw StateError('pipeline event log has no persistent evidence sink');
    }
    if (_evidenceLeaseFile == null ||
        !_ownsProcessEvidenceLease ||
        !_processEvidenceLeases.contains(path)) {
      throw StateError(
        'pipeline journal claim requires an exclusive prepared writer lease',
      );
    }
    final normalizedRunId = _requiredJournalIdentity(
      evidenceRunId,
      'evidenceRunId',
    );
    final normalizedSceneId = _requiredJournalIdentity(sceneId, 'sceneId');
    final normalizedBriefDigest = _requiredSha256(
      preparedBriefDigest,
      'preparedBriefDigest',
    );
    final normalizedArmPolicy = _requiredJournalIdentity(
      generationArmPolicy,
      'generationArmPolicy',
    );
    final claimKey = AppLlmCanonicalHash.domainHash(
      'pipeline-story-generation-journal-process-claim-v1',
      <String, Object?>{
        'evidenceRunId': normalizedRunId,
        'sceneId': normalizedSceneId,
      },
    );
    final boundLocator = _processJournalNamespaceLocators[claimKey];
    if (boundLocator != null && boundLocator != path) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'evidence run/scene namespace is already bound to another durable '
        'JSONL locator',
      );
    }
    _processJournalNamespaceLocators[claimKey] = path;
    // This reservation happens before the first await. It closes the gap
    // between the persisted-event scan and journal-open append for every
    // concrete sink in this isolate, not merely two instances sharing a path.
    if (!_processJournalClaims.add(claimKey)) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'evidence run/scene identity already has an in-process journal claim',
      );
    }
    _ownedJournalClaims.add(claimKey);
    return _claimStoryGenerationEvidenceJournal(
      evidenceRunId: normalizedRunId,
      sceneId: normalizedSceneId,
      preparedBriefDigest: normalizedBriefDigest,
      generationArmPolicy: normalizedArmPolicy,
    );
  }

  Future<List<PipelineEvent>> _claimStoryGenerationEvidenceJournal({
    required String evidenceRunId,
    required String sceneId,
    required String preparedBriefDigest,
    required String generationArmPolicy,
  }) async {
    final persisted = await readPersistedEvents();
    final existing = persisted
        .where(
          (event) =>
              event.metadata['evidenceRunId'] == evidenceRunId &&
              event.metadata['sceneId'] == sceneId,
        )
        .toList(growable: false);
    if (existing.isNotEmpty) {
      return List<PipelineEvent>.unmodifiable(existing);
    }
    await appendAndFlushEvidence(
      PipelineEvent(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        stageId: 'experiment_evidence',
        eventType: storyGenerationEvidenceJournalClaimRecordedEventType,
        metadata: <String, Object?>{
          'schemaVersion': storyGenerationEvidenceJournalClaimSchemaVersion,
          'visibility': 'private',
          'evidenceRunId': evidenceRunId,
          'sceneId': sceneId,
          'preparedBriefDigest': preparedBriefDigest,
          'admissionState': 'open',
          'evidenceComplete': false,
          'private': <String, Object?>{
            'generationArmPolicy': generationArmPolicy,
            'claimState': 'open',
          },
        },
      ),
    );
    return const <PipelineEvent>[];
  }

  @override
  Future<void> appendAndFlushEvidence(PipelineEvent event) async {
    final path = _jsonlPath;
    if (path == null) {
      throw StateError('pipeline event log has no persistent evidence sink');
    }
    if (_evidenceLeaseFile == null ||
        !_ownsProcessEvidenceLease ||
        !_processEvidenceLeases.contains(path)) {
      throw StateError(
        'pipeline evidence append requires an exclusive prepared writer lease',
      );
    }
    emit(event);
    await flush();
  }

  @override
  Future<List<PipelineEvent>> readPersistedEvents() async {
    final path = _jsonlPath;
    if (path == null) {
      throw StateError('pipeline event log has no persistent evidence sink');
    }
    await flush();
    final file = File(path);
    if (!await file.exists()) return const [];
    final events = <PipelineEvent>[];
    for (final rawLine in await file.readAsLines()) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        throw const FormatException('pipeline JSONL event must be an object');
      }
      events.add(PipelineEvent.fromJson(Map<String, Object?>.from(decoded)));
    }
    return List<PipelineEvent>.unmodifiable(events);
  }

  void _appendToFile(PipelineEvent event) {
    final path = _jsonlPath;
    if (path == null) return;
    final encoded = jsonEncode(event.toJson());
    final operation = _flushTail.then<void>((_) {
      _sink ??= File(path).openWrite(mode: FileMode.append);
      _sink!.writeln(encoded);
    });
    _flushTail = operation;
  }

  /// Release resources. Call when the log is no longer needed.
  Future<void> dispose() async {
    await flush();
    await _sink?.close();
    _sink = null;
    final path = _jsonlPath;
    final leaseFile = _evidenceLeaseFile;
    _evidenceLeaseFile = null;
    try {
      if (leaseFile != null) {
        try {
          await leaseFile.unlock();
        } finally {
          await leaseFile.close();
        }
      }
    } finally {
      for (final claim in _ownedJournalClaims) {
        _processJournalClaims.remove(claim);
      }
      _ownedJournalClaims.clear();
      if (_ownsProcessEvidenceLease && path != null) {
        _processEvidenceLeases.remove(path);
      }
      _ownsProcessEvidenceLease = false;
    }
  }
}

String? _normalizedJsonlPath(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return File(normalized).absolute.path;
}
