import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:novel_writer/app/llm/app_llm_client.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:cryptography/dart.dart';
import '../domain/contracts/settings_contract.dart';
import 'evaluation/agent_evaluation_trace_context.dart';
import 'generation_evidence_fingerprints.dart';
import 'story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/data/request_rate_limiter.dart';

const int _defaultMaxTransientRetries = 3;
const int storyGenerationDefaultMaxTokens =
    AppLlmChatRequest.unlimitedMaxTokens;
const int storyGenerationEditorialMaxTokens = 4096;
const int storyGenerationMaxEscalatedTokens = 65536;
const Duration _baseRetryDelay = Duration(milliseconds: 500);
const Duration _maxRetryDelay = Duration(seconds: 30);
final _retryJitter = Random();

typedef StoryGenerationAttemptDispatcher =
    Future<AppLlmChatResult> Function({
      required int maxTokens,
      required int attempt,
      required int transientRetryCount,
      required int outputRetryCount,
    });

typedef StoryGenerationAttemptEvidenceRecorder =
    void Function(StoryGenerationAttemptEvidence evidence);

/// Durable boundary for a completed provider attempt.
///
/// The retry state machine awaits this callback before it may dispatch the
/// next attempt or return the current result. This is deliberately separate
/// from the synchronous in-memory [StoryGenerationAttemptEvidenceRecorder]: a
/// capture used to build a later scene envelope is not process-crash
/// fail-closed evidence.
typedef StoryGenerationAttemptEvidencePersister =
    Future<void> Function(StoryGenerationAttemptEvidence evidence);

/// Write-ahead boundary for a provider attempt that has not produced an
/// outcome yet. A formal no-redraw dispatch must await this record before any
/// network transport can start.
typedef StoryGenerationAttemptIntentPersister =
    Future<Object?> Function(StoryGenerationAttemptIntent intent);

/// Persists the exact raw UTF-8 identity of a candidate before any
/// deterministic, council, or evaluator gate is allowed to inspect it.
typedef StoryGenerationArtifactEvidenceSealer =
    Future<ArtifactDigest> Function({
      required String stageId,
      required String artifactText,
      required String sourceLogicalAttemptId,
      required String sourceCallSiteId,
    });

typedef StoryGenerationAttemptEvidenceEnricher =
    StoryGenerationAttemptEvidence Function(
      StoryGenerationAttemptEvidence evidence,
      AppLlmChatResult result,
    );

/// Credential-free identity of one intended physical provider dispatch.
///
/// The record deliberately contains hashes and route identity only. It is
/// durable before transport and is later closed by an attempt-evidence record
/// carrying the same [logicalAttemptId].
final class StoryGenerationAttemptIntent {
  StoryGenerationAttemptIntent({
    required this.evidenceRunId,
    required this.sceneId,
    required this.preparedBriefDigest,
    required this.logicalAttemptId,
    required this.attempt,
    required this.maxTokens,
    required this.transientRetryCount,
    required this.outputRetryCount,
    required this.stageId,
    required this.callSiteId,
    required this.variantId,
    required this.generationBundleHash,
    required Map<String, Object?> promptReleaseRef,
    required this.promptReleaseContentHash,
    required this.renderedMessagesDigest,
    required this.resolvedVariablesDigest,
    required this.rendererContractHash,
    required this.selectedRouteBindingHash,
    required this.generationArmPolicy,
    required this.retryContractHash,
    required this.evaluationPhase,
  }) : promptReleaseRef = Map<String, Object?>.unmodifiable(promptReleaseRef);

  final String evidenceRunId;
  final String sceneId;
  final String preparedBriefDigest;
  final String logicalAttemptId;
  final int attempt;
  final int maxTokens;
  final int transientRetryCount;
  final int outputRetryCount;
  final String stageId;
  final String callSiteId;
  final String variantId;
  final String generationBundleHash;
  final Map<String, Object?> promptReleaseRef;
  final String promptReleaseContentHash;
  final String renderedMessagesDigest;
  final String resolvedVariablesDigest;
  final String rendererContractHash;
  final String selectedRouteBindingHash;
  final String generationArmPolicy;
  final String retryContractHash;
  final StoryGenerationEvaluationPhase? evaluationPhase;

  /// Rehydrates a write-ahead intent only after its enclosing journal has
  /// independently recomputed the record digest and sequence.  This parser is
  /// deliberately narrow: it is not a convenience JSON decoder for callers.
  factory StoryGenerationAttemptIntent.fromVerifiedPrivateJson(
    Map<String, Object?> json,
  ) => StoryGenerationAttemptIntent(
    evidenceRunId: json['evidenceRunId']! as String,
    sceneId: json['sceneId']! as String,
    preparedBriefDigest: json['preparedBriefDigest']! as String,
    logicalAttemptId: json['logicalAttemptId']! as String,
    attempt: json['attempt']! as int,
    maxTokens: json['maxTokens']! as int,
    transientRetryCount: json['transientRetryCount']! as int,
    outputRetryCount: json['outputRetryCount']! as int,
    stageId: json['stageId']! as String,
    callSiteId: json['callSiteId']! as String,
    variantId: json['variantId']! as String,
    generationBundleHash: json['generationBundleHash']! as String,
    promptReleaseRef: Map<String, Object?>.from(
      json['promptReleaseRef']! as Map,
    ),
    promptReleaseContentHash: json['promptReleaseContentHash']! as String,
    renderedMessagesDigest: json['renderedMessagesDigest']! as String,
    resolvedVariablesDigest: json['resolvedVariablesDigest']! as String,
    rendererContractHash: json['rendererContractHash']! as String,
    selectedRouteBindingHash: json['selectedRouteBindingHash']! as String,
    generationArmPolicy: json['generationArmPolicy']! as String,
    retryContractHash: json['retryContractHash']! as String,
    evaluationPhase: json['evaluationPhase'] == null
        ? null
        : StoryGenerationEvaluationPhase.values.byName(
            json['evaluationPhase']! as String,
          ),
  );

  Map<String, Object?> toPrivateJson() => <String, Object?>{
    'evidenceRunId': evidenceRunId,
    'sceneId': sceneId,
    'preparedBriefDigest': preparedBriefDigest,
    'logicalAttemptId': logicalAttemptId,
    'attempt': attempt,
    'maxTokens': maxTokens,
    'transientRetryCount': transientRetryCount,
    'outputRetryCount': outputRetryCount,
    'stageId': stageId,
    'callSiteId': callSiteId,
    'variantId': variantId,
    'generationBundleHash': generationBundleHash,
    'promptReleaseRef': promptReleaseRef,
    'promptReleaseContentHash': promptReleaseContentHash,
    'renderedMessagesDigest': renderedMessagesDigest,
    'resolvedVariablesDigest': resolvedVariablesDigest,
    'rendererContractHash': rendererContractHash,
    'selectedRouteBindingHash': selectedRouteBindingHash,
    'generationArmPolicy': generationArmPolicy,
    'retryContractHash': retryContractHash,
    'evaluationPhase': evaluationPhase?.name,
    'physicalDispatchPolicy': AppLlmPhysicalDispatchPolicy.single.name,
  };

  String get privateIntentDigest => AppLlmCanonicalHash.domainHash(
    'story-generation-attempt-intent-record-v1',
    toPrivateJson(),
  );
}

/// Semantic inputs needed to bind a judge call to the exact artifact and
/// rubric it evaluates. Raw prose and judge input are used only to compute the
/// fingerprint and are never serialized into attempt evidence.
final class StoryGenerationEvaluationFingerprintSeed {
  const StoryGenerationEvaluationFingerprintSeed({
    required this.artifactDigest,
    required this.evaluationBundleHash,
    required this.judgeInput,
    required this.rubricHash,
    required this.blindingPolicy,
  });

  final ArtifactDigest artifactDigest;
  final String evaluationBundleHash;
  final Object? judgeInput;
  final String rubricHash;
  final String blindingPolicy;
}

/// Provider-boundary proof that no completion was created for a failed
/// dispatch. Free-form error text is deliberately insufficient evidence.
typedef StoryGenerationNoCompletionProof =
    bool Function(AppLlmChatResult result);

enum StoryGenerationRetryPolicyScope {
  productionAdaptive,
  experimentNoContentRedraw,
}

enum StoryGenerationRetryDisposition {
  retryMoreTokens,
  retrySemanticOutput,
  retryTransientFailure,
  retryNoProviderCompletion,
  returned,
}

/// A formal no-redraw run is missing provenance required to make the sample
/// admissible. Callers that normally degrade optional review failures must
/// rethrow this error so an experiment cannot silently continue unmeasured.
final class StoryGenerationEvidencePreflightFailure extends StateError {
  StoryGenerationEvidencePreflightFailure(
    super.message, {
    this.code = 'story_generation_evidence_preflight_failed',
  });

  final String code;
}

/// A provider result or final artifact cannot be released because its private
/// evidence chain is incomplete or does not reconcile with durable records.
final class StoryGenerationEvidenceIntegrityFailure extends StateError {
  StoryGenerationEvidenceIntegrityFailure(super.message);
}

/// Semantic role of a provider-backed evaluation. The phase is included in
/// the evaluation fingerprint so a preliminary review of identical prose
/// cannot be replayed as the final council.
enum StoryGenerationEvaluationPhase { preliminaryReview, finalCouncil, quality }

/// Zone-local binding for the exact artifact currently being evaluated.
///
/// The runner owns this scope. Reviewers and scorers may read it, but merely
/// entering the scope does not grant finalization authority: the provider IO
/// outcome, frozen parser, parsed object identity, terminal receipt, and the
/// sealed runner all have to reconcile later.
final class StoryGenerationEvaluationScope {
  const StoryGenerationEvaluationScope._({
    required this.phase,
    required this.artifactDigest,
  });

  static final Object _zoneKey = Object();

  final StoryGenerationEvaluationPhase phase;
  final ArtifactDigest artifactDigest;

  static StoryGenerationEvaluationScope? get current =>
      Zone.current[_zoneKey] as StoryGenerationEvaluationScope?;

  static R run<R>({
    required StoryGenerationEvaluationPhase phase,
    required String artifactText,
    required R Function() body,
  }) => runZoned(
    body,
    zoneValues: <Object, Object>{
      _zoneKey: StoryGenerationEvaluationScope._(
        phase: phase,
        artifactDigest: ArtifactDigest.fromUtf8String(artifactText),
      ),
    },
  );
}

Object storyGenerationEvaluationJudgeInput({
  required StoryGenerationEvaluationPhase phase,
  required String stageId,
  required String callSiteId,
  required ArtifactDigest artifactDigest,
}) => <String, Object?>{
  'contract': 'story-generation-evaluation-role-v1',
  'phase': phase.name,
  'stageId': stageId,
  'callSiteId': callSiteId,
  'artifactDigest': artifactDigest.toCanonicalMap(),
};

String storyGenerationEvaluationRubricHash({
  required StoryGenerationEvaluationPhase phase,
  required StoryPromptInvocation promptInvocation,
}) => AppLlmCanonicalHash.domainHash(
  'story-generation-evaluation-rubric-v1',
  <String, Object?>{
    'phase': phase.name,
    'stageId': promptInvocation.callSite.stageId,
    'callSiteId': promptInvocation.callSite.callSiteId,
    'variantId': promptInvocation.callSite.variantId,
    'promptReleaseContentHash': promptInvocation.release.contentHash,
    'parserRelease': promptInvocation.release.parserRelease,
  },
);

String storyGenerationParsedOutputDigest(Object? canonicalParsedOutput) =>
    AppLlmCanonicalHash.domainHash(
      'story-generation-parsed-evaluation-output-v1',
      AppLlmCanonicalHash.immutableSnapshot(canonicalParsedOutput),
    );

final Expando<_FormalEvaluationOutcomeAdmission>
_formalEvaluationOutcomeAdmissions = Expando<_FormalEvaluationOutcomeAdmission>(
  'formal-evaluation-provider-outcome-admission',
);

/// One-shot provider-outcome capability returned only for the exact live
/// [AppLlmChatResult] whose formal attempt was durably persisted.
///
/// The constructor is private. Consuming it reveals only immutable provider
/// provenance. It deliberately has no public API that accepts a parsed DTO:
/// concrete frozen parsers own their own private DTO registries.
@pragma('vm:isolate-unsendable')
final class StoryGenerationFormalOutcomeAdmission {
  StoryGenerationFormalOutcomeAdmission._(this._admission);

  final _FormalEvaluationOutcomeAdmission _admission;
  bool _consumed = false;

  /// Burns this capability and returns the provider provenance exactly once.
  /// The returned value cannot mint or register a parsed object by itself.
  StoryGenerationFormalOutcomeProvenance? consume() {
    if (_consumed) return null;
    _consumed = true;
    return StoryGenerationFormalOutcomeProvenance._(
      stageId: _admission.stageId,
      callSiteId: _admission.callSiteId,
      logicalAttemptId: _admission.logicalAttemptId,
      providerOutcomeSealHash: _admission.providerOutcomeSealHash,
      providerArtifactDigest: _admission.providerArtifactDigest,
      evaluatedArtifactDigest: _admission.evaluatedArtifactDigest,
      promptReleaseContentHash: _admission.promptReleaseContentHash,
      parserRelease: _admission.parserRelease,
      evaluationPhase: _admission.evaluationPhase,
      evaluationFingerprintDigest: _admission.evaluationFingerprintDigest,
    );
  }
}

/// Immutable provider provenance returned after one successful durable
/// outcome admission. It is runtime-only and cannot be constructed or
/// deserialized by callers.
@pragma('vm:isolate-unsendable')
final class StoryGenerationFormalOutcomeProvenance {
  const StoryGenerationFormalOutcomeProvenance._({
    required this.stageId,
    required this.callSiteId,
    required this.logicalAttemptId,
    required this.providerOutcomeSealHash,
    required this.providerArtifactDigest,
    required this.evaluatedArtifactDigest,
    required this.promptReleaseContentHash,
    required this.parserRelease,
    required this.evaluationPhase,
    required this.evaluationFingerprintDigest,
  });

  final String stageId;
  final String callSiteId;
  final String logicalAttemptId;
  final String providerOutcomeSealHash;
  final ArtifactDigest providerArtifactDigest;
  final ArtifactDigest evaluatedArtifactDigest;
  final String promptReleaseContentHash;
  final String parserRelease;
  final StoryGenerationEvaluationPhase evaluationPhase;
  final String evaluationFingerprintDigest;
}

final class _FormalEvaluationOutcomeAdmission {
  const _FormalEvaluationOutcomeAdmission({
    required this.stageId,
    required this.callSiteId,
    required this.logicalAttemptId,
    required this.providerOutcomeSealHash,
    required this.providerArtifactDigest,
    required this.evaluatedArtifactDigest,
    required this.promptReleaseContentHash,
    required this.parserRelease,
    required this.evaluationPhase,
    required this.evaluationFingerprintDigest,
  });

  final String stageId;
  final String callSiteId;
  final String logicalAttemptId;
  final String providerOutcomeSealHash;
  final ArtifactDigest providerArtifactDigest;
  final ArtifactDigest evaluatedArtifactDigest;
  final String promptReleaseContentHash;
  final String parserRelease;
  final StoryGenerationEvaluationPhase evaluationPhase;
  final String evaluationFingerprintDigest;
}

/// Takes the provider-bound outcome capability for one exact live result.
/// Any mismatched presentation burns the registry entry fail closed.
StoryGenerationFormalOutcomeAdmission?
takeStoryGenerationFormalOutcomeAdmission({
  required AppLlmChatResult result,
  required String stageId,
  required String callSiteId,
  required String parserRelease,
  required StoryGenerationEvaluationPhase evaluationPhase,
  required ArtifactDigest evaluatedArtifactDigest,
}) {
  final admission = _formalEvaluationOutcomeAdmissions[result];
  _formalEvaluationOutcomeAdmissions[result] = null;
  if (admission == null ||
      admission.stageId != stageId ||
      admission.callSiteId != callSiteId ||
      admission.parserRelease != parserRelease ||
      admission.evaluationPhase != evaluationPhase ||
      !_sameArtifactDigest(
        admission.evaluatedArtifactDigest,
        evaluatedArtifactDigest,
      )) {
    return null;
  }
  return StoryGenerationFormalOutcomeAdmission._(admission);
}

bool _sameArtifactDigest(ArtifactDigest left, ArtifactDigest right) =>
    left.digest == right.digest && left.byteLength == right.byteLength;

/// Controls whether the retry state machine may dispatch another provider
/// request after seeing a provider outcome.
///
/// [productionAdaptive] preserves the existing product behavior: empty,
/// truncated, malformed, or transient transport outcomes may be retried within
/// the existing request-level limits.
///
/// [experimentNoContentRedraw] is for causal generation experiments where a
/// successful but weak completion is still the sampled completion. It forbids
/// content redraws and indeterminate transport replays. The only replay it
/// allows is a bounded retry when the provider boundary explicitly proves no
/// completion was created.
class StoryGenerationRetryPolicy {
  const StoryGenerationRetryPolicy.productionAdaptive({this.maxTotalAttempts})
    : scope = StoryGenerationRetryPolicyScope.productionAdaptive,
      maxNoProviderCompletionRetries = 0,
      assert(maxTotalAttempts == null || maxTotalAttempts > 0);

  const StoryGenerationRetryPolicy.experimentNoContentRedraw({
    this.maxTotalAttempts,
    this.maxNoProviderCompletionRetries = 0,
  }) : scope = StoryGenerationRetryPolicyScope.experimentNoContentRedraw,
       assert(maxTotalAttempts == null || maxTotalAttempts > 0),
       assert(maxNoProviderCompletionRetries >= 0);

  final StoryGenerationRetryPolicyScope scope;
  final int? maxTotalAttempts;
  final int maxNoProviderCompletionRetries;

  bool get allowsContentRedraw =>
      scope == StoryGenerationRetryPolicyScope.productionAdaptive;
}

class StoryGenerationRetryScope {
  static final Object _zoneKey = Object();
  static final Object _attemptEvidenceRecorderZoneKey = Object();
  static final Object _attemptEvidencePersisterZoneKey = Object();
  static final Object _attemptIntentPersisterZoneKey = Object();
  static final Object _artifactEvidenceSealerZoneKey = Object();
  static final Object _generationArmPolicyZoneKey = Object();
  static final Object _evidenceRunIdZoneKey = Object();
  static final Object _evidenceSceneIdZoneKey = Object();
  static final Object _preparedBriefDigestZoneKey = Object();

  static StoryGenerationRetryPolicy? get current =>
      Zone.current[_zoneKey] as StoryGenerationRetryPolicy?;

  static StoryGenerationAttemptEvidenceRecorder?
  get currentAttemptEvidenceRecorder =>
      Zone.current[_attemptEvidenceRecorderZoneKey]
          as StoryGenerationAttemptEvidenceRecorder?;

  static StoryGenerationAttemptEvidencePersister?
  get currentAttemptEvidencePersister =>
      Zone.current[_attemptEvidencePersisterZoneKey]
          as StoryGenerationAttemptEvidencePersister?;

  static StoryGenerationAttemptIntentPersister?
  get currentAttemptIntentPersister =>
      Zone.current[_attemptIntentPersisterZoneKey]
          as StoryGenerationAttemptIntentPersister?;

  static StoryGenerationArtifactEvidenceSealer?
  get currentArtifactEvidenceSealer =>
      Zone.current[_artifactEvidenceSealerZoneKey]
          as StoryGenerationArtifactEvidenceSealer?;

  static String? get currentGenerationArmPolicy =>
      Zone.current[_generationArmPolicyZoneKey] as String?;

  static String? get currentEvidenceRunId =>
      Zone.current[_evidenceRunIdZoneKey] as String?;

  static String? get currentEvidenceSceneId =>
      Zone.current[_evidenceSceneIdZoneKey] as String?;

  static String? get currentPreparedBriefDigest =>
      Zone.current[_preparedBriefDigestZoneKey] as String?;

  static R run<R>({
    required StoryGenerationRetryPolicy policy,
    StoryGenerationAttemptEvidenceRecorder? onAttemptEvidence,
    StoryGenerationAttemptEvidencePersister? persistAttemptEvidence,
    StoryGenerationAttemptIntentPersister? persistAttemptIntent,
    StoryGenerationArtifactEvidenceSealer? sealArtifactEvidence,
    String? generationArmPolicy,
    String? evidenceRunId,
    String? evidenceSceneId,
    String? preparedBriefDigest,
    required R Function() body,
  }) {
    final zoneValues = <Object, Object>{_zoneKey: policy};
    if (onAttemptEvidence != null) {
      zoneValues[_attemptEvidenceRecorderZoneKey] = onAttemptEvidence;
    }
    if (persistAttemptEvidence != null) {
      zoneValues[_attemptEvidencePersisterZoneKey] = persistAttemptEvidence;
    }
    if (persistAttemptIntent != null) {
      zoneValues[_attemptIntentPersisterZoneKey] = persistAttemptIntent;
    }
    if (sealArtifactEvidence != null) {
      zoneValues[_artifactEvidenceSealerZoneKey] = sealArtifactEvidence;
    }
    final normalizedArmPolicy = generationArmPolicy?.trim();
    if (normalizedArmPolicy != null && normalizedArmPolicy.isNotEmpty) {
      zoneValues[_generationArmPolicyZoneKey] = normalizedArmPolicy;
    }
    final normalizedRunId = evidenceRunId?.trim();
    if (normalizedRunId != null && normalizedRunId.isNotEmpty) {
      zoneValues[_evidenceRunIdZoneKey] = normalizedRunId;
    }
    final normalizedSceneId = evidenceSceneId?.trim();
    if (normalizedSceneId != null && normalizedSceneId.isNotEmpty) {
      zoneValues[_evidenceSceneIdZoneKey] = normalizedSceneId;
    }
    final normalizedPreparedBriefDigest = preparedBriefDigest?.trim();
    if (normalizedPreparedBriefDigest != null &&
        normalizedPreparedBriefDigest.isNotEmpty) {
      zoneValues[_preparedBriefDigestZoneKey] = normalizedPreparedBriefDigest;
    }
    return runZoned(body, zoneValues: zoneValues);
  }
}

class StoryGenerationAttemptEvidence {
  StoryGenerationAttemptEvidence({
    required this.attempt,
    required this.maxTokens,
    required this.transientRetryCount,
    required this.outputRetryCount,
    required this.succeeded,
    required this.failureKind,
    required this.statusCode,
    required this.providerModel,
    required this.providerResponseId,
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.responseDigest,
    required this.disposition,
    this.stageId,
    this.callSiteId,
    this.variantId,
    this.preparedBriefDigest,
    this.logicalAttemptId,
    this.generationBundleHash,
    Map<String, Object?>? promptReleaseRef,
    this.promptReleaseContentHash,
    this.renderedMessagesDigest,
    this.resolvedVariablesDigest,
    this.rendererContractHash,
    this.selectedRouteBindingHash,
    Map<String, Object?>? selectedRouteBinding,
    this.observedDispatchResolutionHash,
    Map<String, Object?>? observedDispatchResolution,
    this.routeResolutionRequired = false,
    this.routeResolutionVerified = false,
    this.providerBoundaryReceiptHash,
    Map<String, Object?>? providerBoundaryReceipt,
    this.providerOutcomeSealHash,
    Map<String, Object?>? providerOutcomeSeal,
    this.providerBoundaryPhysicalDispatchCount,
    this.providerBoundaryReceiptRequired = false,
    this.providerBoundaryReceiptVerified = false,
    this.formalDispatchWitness,
    this.dispatchFailureDisposition,
    this.artifactDigest,
    this.generationFingerprint,
    this.evaluationFingerprint,
    this.evaluationParserRelease,
    this.evaluationPhase,
    this.evaluationFingerprintRequired = false,
  }) : promptReleaseRef = promptReleaseRef == null
           ? null
           : Map<String, Object?>.unmodifiable(promptReleaseRef),
       selectedRouteBinding = selectedRouteBinding == null
           ? null
           : Map<String, Object?>.unmodifiable(selectedRouteBinding),
       observedDispatchResolution = observedDispatchResolution == null
           ? null
           : Map<String, Object?>.unmodifiable(observedDispatchResolution),
       providerBoundaryReceipt = providerBoundaryReceipt == null
           ? null
           : Map<String, Object?>.unmodifiable(providerBoundaryReceipt),
       providerOutcomeSeal = providerOutcomeSeal == null
           ? null
           : Map<String, Object?>.unmodifiable(providerOutcomeSeal);

  final int attempt;
  final int maxTokens;
  final int transientRetryCount;
  final int outputRetryCount;
  final bool succeeded;
  final AppLlmFailureKind? failureKind;
  final int? statusCode;
  final String? providerModel;
  final String? providerResponseId;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? responseDigest;
  final StoryGenerationRetryDisposition disposition;
  final String? stageId;
  final String? callSiteId;
  final String? variantId;
  final String? preparedBriefDigest;
  final String? logicalAttemptId;
  final String? generationBundleHash;
  final Map<String, Object?>? promptReleaseRef;
  final String? promptReleaseContentHash;
  final String? renderedMessagesDigest;
  final String? resolvedVariablesDigest;
  final String? rendererContractHash;
  final String? selectedRouteBindingHash;
  final Map<String, Object?>? selectedRouteBinding;
  final String? observedDispatchResolutionHash;
  final Map<String, Object?>? observedDispatchResolution;
  final bool routeResolutionRequired;
  final bool routeResolutionVerified;
  final String? providerBoundaryReceiptHash;
  final Map<String, Object?>? providerBoundaryReceipt;
  final String? providerOutcomeSealHash;
  final Map<String, Object?>? providerOutcomeSeal;
  final int? providerBoundaryPhysicalDispatchCount;
  final bool providerBoundaryReceiptRequired;
  final bool providerBoundaryReceiptVerified;

  /// Runtime-only proof issued by the concrete App LLM IO boundary. It is
  /// intentionally omitted from [toJson]; rehydration must re-verify the
  /// durable canonical chain rather than deserialize a capability.
  final AppLlmFormalDispatchWitness? formalDispatchWitness;
  final AppLlmDispatchFailureDisposition? dispatchFailureDisposition;
  final ArtifactDigest? artifactDigest;
  final GenerationFingerprint? generationFingerprint;
  final EvaluationFingerprint? evaluationFingerprint;
  final String? evaluationParserRelease;
  final StoryGenerationEvaluationPhase? evaluationPhase;
  final bool evaluationFingerprintRequired;

  /// Completeness is derived from sealed fields; callers cannot assert it.
  bool get evidenceComplete {
    final hasFormalIdentity =
        _nonEmpty(stageId) &&
        _nonEmpty(callSiteId) &&
        _nonEmpty(variantId) &&
        _sha256Digest(preparedBriefDigest) &&
        (!routeResolutionRequired || _sha256Digest(logicalAttemptId)) &&
        _sha256Digest(generationBundleHash) &&
        promptReleaseRef != null &&
        _sha256Digest(promptReleaseContentHash) &&
        _sha256Digest(renderedMessagesDigest) &&
        _sha256Digest(resolvedVariablesDigest) &&
        _sha256Digest(rendererContractHash) &&
        _sha256Digest(selectedRouteBindingHash) &&
        (!routeResolutionRequired ||
            (routeResolutionVerified &&
                _sha256Digest(observedDispatchResolutionHash))) &&
        (!providerBoundaryReceiptRequired ||
            (providerBoundaryReceiptVerified &&
                providerBoundaryPhysicalDispatchCount == 1 &&
                _sha256Digest(providerBoundaryReceiptHash) &&
                _sha256Digest(providerOutcomeSealHash) &&
                providerOutcomeSeal != null));
    if (!hasFormalIdentity) return false;
    if (!succeeded) return failureKind != null;
    if (artifactDigest == null) return false;
    if (evaluationFingerprintRequired) {
      return generationFingerprint == null &&
          evaluationFingerprint != null &&
          _nonEmpty(evaluationParserRelease) &&
          evaluationPhase != null;
    }
    return generationFingerprint != null &&
        evaluationFingerprint == null &&
        evaluationParserRelease == null &&
        evaluationPhase == null;
  }

  StoryGenerationAttemptEvidence copyWithFormalEvidence({
    required String stageId,
    required String callSiteId,
    required String variantId,
    required String preparedBriefDigest,
    required String? logicalAttemptId,
    required String generationBundleHash,
    required Map<String, Object?> promptReleaseRef,
    required String promptReleaseContentHash,
    required String renderedMessagesDigest,
    required String resolvedVariablesDigest,
    required String rendererContractHash,
    required String? selectedRouteBindingHash,
    required Map<String, Object?>? selectedRouteBinding,
    required String? observedDispatchResolutionHash,
    required Map<String, Object?>? observedDispatchResolution,
    required bool routeResolutionRequired,
    required bool routeResolutionVerified,
    required String? providerBoundaryReceiptHash,
    required Map<String, Object?>? providerBoundaryReceipt,
    String? providerOutcomeSealHash,
    Map<String, Object?>? providerOutcomeSeal,
    required int? providerBoundaryPhysicalDispatchCount,
    required bool providerBoundaryReceiptRequired,
    required bool providerBoundaryReceiptVerified,
    AppLlmFormalDispatchWitness? formalDispatchWitness,
    required ArtifactDigest? artifactDigest,
    required GenerationFingerprint? generationFingerprint,
    required EvaluationFingerprint? evaluationFingerprint,
    required String? evaluationParserRelease,
    required StoryGenerationEvaluationPhase? evaluationPhase,
    required bool evaluationFingerprintRequired,
  }) {
    return StoryGenerationAttemptEvidence(
      attempt: attempt,
      maxTokens: maxTokens,
      transientRetryCount: transientRetryCount,
      outputRetryCount: outputRetryCount,
      succeeded: succeeded,
      failureKind: failureKind,
      statusCode: statusCode,
      providerModel: providerModel,
      providerResponseId: providerResponseId,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      responseDigest: responseDigest,
      disposition: disposition,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      preparedBriefDigest: preparedBriefDigest,
      logicalAttemptId: logicalAttemptId,
      generationBundleHash: generationBundleHash,
      promptReleaseRef: promptReleaseRef,
      promptReleaseContentHash: promptReleaseContentHash,
      renderedMessagesDigest: renderedMessagesDigest,
      resolvedVariablesDigest: resolvedVariablesDigest,
      rendererContractHash: rendererContractHash,
      selectedRouteBindingHash: selectedRouteBindingHash,
      selectedRouteBinding: selectedRouteBinding,
      observedDispatchResolutionHash: observedDispatchResolutionHash,
      observedDispatchResolution: observedDispatchResolution,
      routeResolutionRequired: routeResolutionRequired,
      routeResolutionVerified: routeResolutionVerified,
      providerBoundaryReceiptHash: providerBoundaryReceiptHash,
      providerBoundaryReceipt: providerBoundaryReceipt,
      providerOutcomeSealHash:
          providerOutcomeSealHash ?? this.providerOutcomeSealHash,
      providerOutcomeSeal: providerOutcomeSeal ?? this.providerOutcomeSeal,
      providerBoundaryPhysicalDispatchCount:
          providerBoundaryPhysicalDispatchCount,
      providerBoundaryReceiptRequired: providerBoundaryReceiptRequired,
      providerBoundaryReceiptVerified: providerBoundaryReceiptVerified,
      formalDispatchWitness: formalDispatchWitness,
      dispatchFailureDisposition: dispatchFailureDisposition,
      artifactDigest: artifactDigest,
      generationFingerprint: generationFingerprint,
      evaluationFingerprint: evaluationFingerprint,
      evaluationParserRelease: evaluationParserRelease,
      evaluationPhase: evaluationPhase,
      evaluationFingerprintRequired: evaluationFingerprintRequired,
    );
  }

  Map<String, Object?> toJson() => {
    'attempt': attempt,
    'maxTokens': maxTokens,
    'transientRetryCount': transientRetryCount,
    'outputRetryCount': outputRetryCount,
    'succeeded': succeeded,
    if (failureKind != null) 'failureKind': failureKind!.name,
    if (statusCode != null) 'statusCode': statusCode,
    if (providerModel != null) 'providerModel': providerModel,
    if (providerResponseId != null) 'providerResponseId': providerResponseId,
    if (promptTokens != null) 'promptTokens': promptTokens,
    if (completionTokens != null) 'completionTokens': completionTokens,
    if (totalTokens != null) 'totalTokens': totalTokens,
    if (responseDigest != null) 'responseDigest': responseDigest,
    'disposition': disposition.name,
    if (stageId != null) 'stageId': stageId,
    if (callSiteId != null) 'callSiteId': callSiteId,
    if (variantId != null) 'variantId': variantId,
    if (preparedBriefDigest != null) 'preparedBriefDigest': preparedBriefDigest,
    if (logicalAttemptId != null) 'logicalAttemptId': logicalAttemptId,
    if (generationBundleHash != null)
      'generationBundleHash': generationBundleHash,
    if (promptReleaseRef != null) 'promptReleaseRef': promptReleaseRef,
    if (promptReleaseContentHash != null)
      'promptReleaseContentHash': promptReleaseContentHash,
    if (renderedMessagesDigest != null)
      'renderedMessagesDigest': renderedMessagesDigest,
    if (resolvedVariablesDigest != null)
      'resolvedVariablesDigest': resolvedVariablesDigest,
    if (rendererContractHash != null)
      'rendererContractHash': rendererContractHash,
    if (selectedRouteBindingHash != null)
      'selectedRouteBindingHash': selectedRouteBindingHash,
    if (selectedRouteBinding != null)
      'selectedRouteBinding': selectedRouteBinding,
    if (observedDispatchResolutionHash != null)
      'observedDispatchResolutionHash': observedDispatchResolutionHash,
    if (observedDispatchResolution != null)
      'observedDispatchResolution': observedDispatchResolution,
    'routeResolutionRequired': routeResolutionRequired,
    'routeResolutionVerified': routeResolutionVerified,
    if (providerBoundaryReceiptHash != null)
      'providerBoundaryReceiptHash': providerBoundaryReceiptHash,
    if (providerBoundaryReceipt != null)
      'providerBoundaryReceipt': providerBoundaryReceipt,
    if (providerOutcomeSealHash != null)
      'providerOutcomeSealHash': providerOutcomeSealHash,
    if (providerOutcomeSeal != null) 'providerOutcomeSeal': providerOutcomeSeal,
    if (providerBoundaryPhysicalDispatchCount != null)
      'providerBoundaryPhysicalDispatchCount':
          providerBoundaryPhysicalDispatchCount,
    'providerBoundaryReceiptRequired': providerBoundaryReceiptRequired,
    'providerBoundaryReceiptVerified': providerBoundaryReceiptVerified,
    if (dispatchFailureDisposition != null)
      'dispatchFailureDisposition': dispatchFailureDisposition!.name,
    if (artifactDigest != null)
      'artifactDigest': artifactDigest!.toCanonicalMap(),
    if (generationFingerprint != null) ...{
      'generationFingerprintDigest': generationFingerprint!.digest,
      'generationFingerprint': generationFingerprint!.toCanonicalMap(),
    },
    if (evaluationFingerprint != null) ...{
      'evaluationFingerprintDigest': evaluationFingerprint!.digest,
      'evaluationFingerprint': evaluationFingerprint!.toCanonicalMap(),
    },
    if (evaluationParserRelease != null)
      'evaluationParserRelease': evaluationParserRelease,
    if (evaluationPhase != null) 'evaluationPhase': evaluationPhase!.name,
    'evaluationFingerprintRequired': evaluationFingerprintRequired,
    'evidenceComplete': evidenceComplete,
  };

  String get privateEvidenceDigest => AppLlmCanonicalHash.domainHash(
    'story-generation-attempt-evidence-record-v1',
    toJson(),
  );

  /// Export safe for anonymous comparison packages. Provider/model identity
  /// remains available only in the private provenance record returned by
  /// [toJson].
  Map<String, Object?> toBlindReviewJson() => <String, Object?>{
    // Attempt count, token shape, provider status, artifact/fingerprint hashes,
    // and callsite identity can all be joined back to the private arm manifest.
    // A blind reviewer receives only an admission bit; G004 assigns a separate
    // opaque package id when it builds the actual review package.
    'evidenceComplete': evidenceComplete,
  };
}

/// Result of the canonical, side-effect-free validation of a serialized
/// provider attempt record.
///
/// Receipts deliberately receive JSON rather than a live
/// [StoryGenerationAttemptEvidence] instance.  That means they must not trust
/// the instance getter (or the serialized `evidenceComplete` bit) as an
/// authority.  This value exposes the recomputed admission decision together
/// with deterministic rejection reasons so a durable receipt can fail closed.
final class StoryGenerationAttemptEvidenceVerification {
  StoryGenerationAttemptEvidenceVerification({
    required this.evidenceComplete,
    required List<String> errors,
  }) : errors = List<String>.unmodifiable(errors);

  final bool evidenceComplete;
  final List<String> errors;
}

/// Recomputes no-redraw attempt admissibility from its canonical private JSON.
///
/// This is intentionally pure and public because both the journal and the
/// receipt verifier must make the same decision without reconstructing a live
/// transport result.  In particular, a persisted `evidenceComplete: true`
/// never grants admission by itself.
StoryGenerationAttemptEvidenceVerification
verifyStoryGenerationAttemptEvidenceJson(Map<String, Object?> json) {
  final errors = <String>[];
  void require(bool condition, String message) {
    if (!condition) errors.add(message);
  }

  bool digest(Object? value) =>
      value is String && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);
  bool nonEmpty(Object? value) => value is String && value.trim().isNotEmpty;
  bool nonNegativeInt(Object? value) => value is int && value >= 0;
  bool isEnumName<T extends Enum>(Object? value, Iterable<T> values) =>
      value is String && values.any((candidate) => candidate.name == value);
  Map<String, Object?>? map(Object? value) {
    if (value is! Map) return null;
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) return null;
      normalized[entry.key as String] = entry.value;
    }
    return normalized;
  }

  void requireKnownKeys(Set<String> required, Set<String> optional) {
    final allowed = <String>{...required, ...optional};
    require(
      json.keys.toSet().containsAll(required) &&
          json.keys.every(allowed.contains),
      'attempt evidence has an unsupported v1 shape',
    );
  }

  const commonRequired = <String>{
    'attempt',
    'maxTokens',
    'transientRetryCount',
    'outputRetryCount',
    'succeeded',
    'disposition',
    'stageId',
    'callSiteId',
    'variantId',
    'preparedBriefDigest',
    'logicalAttemptId',
    'generationBundleHash',
    'promptReleaseRef',
    'promptReleaseContentHash',
    'renderedMessagesDigest',
    'resolvedVariablesDigest',
    'rendererContractHash',
    'selectedRouteBindingHash',
    'selectedRouteBinding',
    'observedDispatchResolutionHash',
    'observedDispatchResolution',
    'routeResolutionRequired',
    'routeResolutionVerified',
    'providerBoundaryReceiptHash',
    'providerBoundaryReceipt',
    'providerOutcomeSealHash',
    'providerOutcomeSeal',
    'providerBoundaryPhysicalDispatchCount',
    'providerBoundaryReceiptRequired',
    'providerBoundaryReceiptVerified',
    'evaluationFingerprintRequired',
    'evidenceComplete',
  };
  const transportOptional = <String>{
    'statusCode',
    'providerModel',
    'providerResponseId',
    'promptTokens',
    'completionTokens',
    'totalTokens',
    'responseDigest',
    'dispatchFailureDisposition',
  };
  final succeededForShape = json['succeeded'];
  final evaluationRequiredForShape =
      json['evaluationFingerprintRequired'] == true;
  if (succeededForShape == true) {
    if (evaluationRequiredForShape) {
      requireKnownKeys(<String>{
        ...commonRequired,
        'providerModel',
        'providerResponseId',
        'artifactDigest',
        'evaluationFingerprintDigest',
        'evaluationFingerprint',
        'evaluationParserRelease',
        'evaluationPhase',
      }, transportOptional);
    } else {
      requireKnownKeys(<String>{
        ...commonRequired,
        'providerModel',
        'providerResponseId',
        'artifactDigest',
        'generationFingerprintDigest',
        'generationFingerprint',
      }, transportOptional);
    }
  } else if (succeededForShape == false) {
    requireKnownKeys(
      <String>{...commonRequired, 'failureKind'},
      <String>{
        ...transportOptional,
        'evaluationParserRelease',
        'evaluationPhase',
      },
    );
  }

  require(nonNegativeInt(json['attempt']), 'attempt is invalid');
  require(nonNegativeInt(json['maxTokens']), 'maxTokens is invalid');
  require(
    nonNegativeInt(json['transientRetryCount']),
    'transientRetryCount is invalid',
  );
  require(
    nonNegativeInt(json['outputRetryCount']),
    'outputRetryCount is invalid',
  );
  require(
    isEnumName(json['disposition'], StoryGenerationRetryDisposition.values),
    'retry disposition is invalid',
  );

  // These are the immutable intent/outcome join fields.  A receipt may only
  // bind no-redraw records, so optional or merely truthy identity is not
  // sufficient here.
  for (final field in const <String>['stageId', 'callSiteId', 'variantId']) {
    require(nonEmpty(json[field]), '$field is missing');
  }
  for (final field in const <String>[
    'preparedBriefDigest',
    'logicalAttemptId',
    'generationBundleHash',
    'promptReleaseContentHash',
    'renderedMessagesDigest',
    'resolvedVariablesDigest',
    'rendererContractHash',
    'selectedRouteBindingHash',
    'observedDispatchResolutionHash',
    'providerBoundaryReceiptHash',
    'providerOutcomeSealHash',
  ]) {
    require(digest(json[field]), '$field is not a canonical digest');
  }
  require(map(json['promptReleaseRef']) != null, 'promptReleaseRef is invalid');
  final selectedRouteBinding = map(json['selectedRouteBinding']);
  final observedResolution = map(json['observedDispatchResolution']);
  final providerReceipt = map(json['providerBoundaryReceipt']);
  final providerOutcomeSeal = map(json['providerOutcomeSeal']);
  require(
    selectedRouteBinding != null &&
        _isExactStoryGenerationSingleRouteBinding(selectedRouteBinding),
    'selected route binding has an unsupported v1 shape',
  );
  require(
    observedResolution != null &&
        _isExactStoryGenerationDispatchResolution(observedResolution),
    'observed dispatch resolution has an unsupported v1 shape',
  );
  require(
    providerReceipt != null &&
        _isExactStoryGenerationProviderBoundaryReceipt(providerReceipt),
    'provider boundary receipt has an unsupported v1 shape',
  );
  require(
    selectedRouteBinding != null &&
        AppLlmCanonicalHash.domainHash(
              'story-generation-configured-model-route-v1',
              selectedRouteBinding,
            ) ==
            json['selectedRouteBindingHash'],
    'configured route binding cannot be independently recomputed',
  );
  require(
    observedResolution != null &&
        AppLlmCanonicalHash.domainHash(
              'story-generation-selected-physical-endpoint-v1',
              observedResolution,
            ) ==
            json['observedDispatchResolutionHash'],
    'observed dispatch route cannot be independently recomputed',
  );
  require(
    providerReceipt != null &&
        AppLlmCanonicalHash.domainHash(
              'story-generation-provider-boundary-receipt-v1',
              providerReceipt,
            ) ==
            json['providerBoundaryReceiptHash'],
    'provider boundary receipt cannot be independently recomputed',
  );
  require(
    providerOutcomeSeal != null &&
        _isExactAppLlmProviderOutcomeSeal(providerOutcomeSeal) &&
        appLlmProviderOutcomeSealDigest(providerOutcomeSeal) ==
            json['providerOutcomeSealHash'],
    'provider outcome seal cannot be independently recomputed',
  );
  final selectedEndpoint = selectedRouteBinding == null
      ? null
      : map(selectedRouteBinding['selectedEndpoint']);
  require(
    selectedEndpoint != null &&
        observedResolution != null &&
        providerReceipt != null &&
        selectedEndpoint['baseUrl'] == observedResolution['baseUrl'] &&
        selectedEndpoint['model'] == observedResolution['model'] &&
        selectedEndpoint['provider'] == observedResolution['provider'] &&
        observedResolution['contract'] == 'app-llm-dispatch-resolution-v1' &&
        observedResolution['physicalDispatchPolicy'] == 'single' &&
        providerReceipt['contract'] == 'app-llm-provider-boundary-receipt-v1' &&
        providerReceipt['physicalDispatchCount'] == 1 &&
        providerReceipt['requestedBaseUrl'] == observedResolution['baseUrl'] &&
        providerReceipt['requestedModel'] == observedResolution['model'] &&
        providerReceipt['requestedProvider'] ==
            observedResolution['provider'] &&
        providerReceipt['dispatchEvidenceNonce'] == json['logicalAttemptId'],
    'provider receipt, observed route, and selected endpoint disagree',
  );
  require(
    providerOutcomeSeal != null &&
        providerReceipt != null &&
        providerOutcomeSeal['requestedProvider'] ==
            providerReceipt['requestedProvider'] &&
        providerOutcomeSeal['requestedModel'] ==
            providerReceipt['requestedModel'] &&
        providerOutcomeSeal['succeeded'] == json['succeeded'] &&
        providerOutcomeSeal['failureKind'] == json['failureKind'] &&
        providerOutcomeSeal['statusCode'] == json['statusCode'] &&
        providerOutcomeSeal['providerModel'] == json['providerModel'] &&
        _canonicalJsonEquals(
          providerOutcomeSeal['providerResponseIdUtf8'],
          appLlmExactUtf8Seal(json['providerResponseId']?.toString()),
        ) &&
        providerOutcomeSeal['promptTokens'] == json['promptTokens'] &&
        providerOutcomeSeal['completionTokens'] == json['completionTokens'] &&
        providerOutcomeSeal['totalTokens'] == json['totalTokens'] &&
        providerOutcomeSeal['dispatchFailureDisposition'] ==
            json['dispatchFailureDisposition'],
    'provider outcome seal disagrees with persisted attempt fields',
  );
  require(
    selectedEndpoint != null &&
        observedResolution != null &&
        providerReceipt != null &&
        _hasConsistentStoryGenerationTransportEndpoints(
          selectedEndpoint: selectedEndpoint,
          observedResolution: observedResolution,
          providerReceipt: providerReceipt,
        ),
    'provider receipt transport endpoint is not the selected provider adapter endpoint',
  );
  require(
    json['routeResolutionRequired'] == true &&
        json['routeResolutionVerified'] == true,
    'physical route identity is not verified',
  );
  require(
    json['providerBoundaryReceiptRequired'] == true &&
        json['providerBoundaryReceiptVerified'] == true &&
        json['providerBoundaryPhysicalDispatchCount'] == 1,
    'provider boundary receipt is not one verified physical dispatch',
  );

  final succeeded = json['succeeded'];
  require(succeeded is bool, 'succeeded is invalid');
  final failureKind = json['failureKind'];
  require(
    succeeded is! bool ||
        succeeded ||
        isEnumName(failureKind, AppLlmFailureKind.values),
    'failed attempt lacks a typed failure kind',
  );
  require(
    succeeded is! bool || !succeeded || failureKind == null,
    'successful attempt cannot carry a failure kind',
  );

  final disposition = json['disposition'];
  if (disposition ==
      StoryGenerationRetryDisposition.retryNoProviderCompletion.name) {
    require(false, 'v1 has no provider-specific no-completion replay proof');
  }

  final artifact = map(json['artifactDigest']);
  final fingerprint = map(json['generationFingerprint']);
  final fingerprintDigest = json['generationFingerprintDigest'];
  if (succeeded == true) {
    require(
      nonEmpty(json['providerModel']),
      'successful attempt lacks provider model',
    );
    require(
      nonEmpty(json['providerResponseId']),
      'successful attempt lacks provider response id',
    );
    require(artifact != null, 'successful attempt lacks artifact digest');
    if (artifact != null) {
      require(
        _isExactStoryArtifactDigest(artifact),
        'successful artifact digest is invalid',
      );
      require(
        json['responseDigest'] == artifact['digest'],
        'successful response digest does not seal the provider artifact',
      );
      final textUtf8 = providerOutcomeSeal == null
          ? null
          : map(providerOutcomeSeal['textUtf8']);
      require(
        textUtf8 != null &&
            textUtf8['byteLength'] == artifact['byteLength'] &&
            textUtf8['digest'] == artifact['digest'] &&
            providerOutcomeSeal?['detailUtf8'] == null,
        'successful provider outcome does not seal the exact artifact bytes',
      );
    }
    require(
      evaluationRequiredForShape ||
          (fingerprint != null && digest(fingerprintDigest)),
      'successful generation attempt lacks generation fingerprint',
    );
    require(
      !evaluationRequiredForShape ||
          (fingerprint == null && fingerprintDigest == null),
      'evaluation attempt cannot carry a generation fingerprint',
    );
    if (!evaluationRequiredForShape &&
        fingerprint != null &&
        fingerprintDigest is String) {
      final tag = fingerprint['domainTag'];
      require(
        tag == GenerationFingerprint.defaultDomainTag &&
            fingerprint.keys.toSet().containsAll(const <String>{
              'domainTag',
              'canonicalContract',
              'semanticInput',
              'generationBundleHash',
              'modelRoute',
              'decodingParameters',
              'armPolicy',
              'retryPolicy',
            }) &&
            fingerprint.keys.length == 8 &&
            AppLlmCanonicalHash.domainHash(
                  GenerationFingerprint.defaultDomainTag,
                  fingerprint,
                ) ==
                fingerprintDigest,
        'generation fingerprint digest is invalid',
      );
    }
  } else if (succeeded == false) {
    require(artifact == null, 'failed attempt cannot carry artifact digest');
    require(
      fingerprint == null && fingerprintDigest == null,
      'failed attempt cannot carry generation fingerprint',
    );
    final detailUtf8 = providerOutcomeSeal == null
        ? null
        : map(providerOutcomeSeal['detailUtf8']);
    require(
      providerOutcomeSeal?['textUtf8'] == null &&
          ((detailUtf8 == null && json['responseDigest'] == null) ||
              (detailUtf8 != null &&
                  detailUtf8['digest'] == json['responseDigest'])),
      'failed provider outcome does not seal its exact failure detail',
    );
  }

  final evaluationFingerprint = map(json['evaluationFingerprint']);
  final evaluationFingerprintDigest = json['evaluationFingerprintDigest'];
  final evaluationRequired = json['evaluationFingerprintRequired'] == true;
  final evaluationParserRelease = json['evaluationParserRelease'];
  final evaluationPhase = json['evaluationPhase'];
  require(
    !evaluationRequired ||
        succeeded != true ||
        (succeeded == true &&
            evaluationFingerprint != null &&
            digest(evaluationFingerprintDigest) &&
            nonEmpty(evaluationParserRelease) &&
            isEnumName(evaluationPhase, StoryGenerationEvaluationPhase.values)),
    'required evaluation fingerprint is missing',
  );
  require(
    evaluationRequired ||
        (evaluationFingerprint == null &&
            evaluationFingerprintDigest == null &&
            evaluationParserRelease == null &&
            evaluationPhase == null),
    'generation attempt cannot carry evaluation provenance',
  );
  if (evaluationFingerprint != null || evaluationFingerprintDigest != null) {
    var evaluationDigestMatches = false;
    if (evaluationFingerprint != null &&
        evaluationFingerprintDigest is String) {
      try {
        evaluationDigestMatches =
            AppLlmCanonicalHash.domainHash(
              EvaluationFingerprint.defaultDomainTag,
              evaluationFingerprint,
            ) ==
            evaluationFingerprintDigest;
      } on Object {
        evaluationDigestMatches = false;
      }
    }
    require(
      succeeded == true &&
          evaluationFingerprint != null &&
          evaluationFingerprintDigest is String &&
          evaluationFingerprint['domainTag'] ==
              EvaluationFingerprint.defaultDomainTag &&
          evaluationFingerprint['canonicalContract'] ==
              AppLlmCanonicalHash.contract &&
          _isCanonicalSha256(evaluationFingerprint['evaluationBundleHash']) &&
          _isCanonicalSha256(evaluationFingerprint['judgeModelRoute']) &&
          _isCanonicalSha256(evaluationFingerprint['rubricHash']) &&
          _nonEmptyCanonicalString(evaluationFingerprint['blindingPolicy']) &&
          evaluationFingerprint.keys.toSet().containsAll(const <String>{
            'domainTag',
            'canonicalContract',
            'artifactDigest',
            'evaluationBundleHash',
            'judgeInput',
            'judgeModelRoute',
            'rubricHash',
            'blindingPolicy',
          }) &&
          evaluationFingerprint.keys.length == 8 &&
          evaluationDigestMatches,
      'evaluation fingerprint shape or digest is invalid',
    );
    final evaluatedArtifact = evaluationFingerprint == null
        ? null
        : map(evaluationFingerprint['artifactDigest']);
    final judgeInput = evaluationFingerprint == null
        ? null
        : map(evaluationFingerprint['judgeInput']);
    final judgeEvaluatedArtifact = judgeInput == null
        ? null
        : map(judgeInput['evaluatedArtifactDigest']);
    require(
      evaluatedArtifact != null &&
          _isExactStoryArtifactDigest(evaluatedArtifact) &&
          judgeInput != null &&
          _hasExactKeys(judgeInput, const <String>{
            'evaluatedArtifactDigest',
            'semanticInputDigest',
          }) &&
          _isCanonicalSha256(judgeInput['semanticInputDigest']) &&
          judgeEvaluatedArtifact != null &&
          _isExactStoryArtifactDigest(judgeEvaluatedArtifact) &&
          _canonicalJsonEquals(judgeEvaluatedArtifact, evaluatedArtifact),
      'evaluation fingerprint judge input binding is invalid',
    );
  }
  require(
    json['evidenceComplete'] == true,
    'serialized evidenceComplete is not true',
  );
  return StoryGenerationAttemptEvidenceVerification(
    evidenceComplete: errors.isEmpty,
    errors: errors,
  );
}

bool _isExactStoryGenerationSingleRouteBinding(Map<String, Object?> value) {
  const required = <String>{
    'contract',
    'traceName',
    'physicalDispatchPolicy',
    'cachePolicy',
    'streamFallback',
    'gatewayRetries',
    'providerFailover',
    'reconnectProbe',
    'selectedEndpoint',
  };
  if (!_hasExactKeys(value, required)) return false;
  final selectedEndpoint = _asStringMap(value['selectedEndpoint']);
  return value['contract'] ==
          'story-generation-single-physical-dispatch-route-v1' &&
      _nonEmptyCanonicalString(value['traceName']) &&
      value['physicalDispatchPolicy'] ==
          AppLlmPhysicalDispatchPolicy.single.name &&
      value['cachePolicy'] == 'bypass-read-write' &&
      value['streamFallback'] == false &&
      value['gatewayRetries'] == 0 &&
      value['providerFailover'] == false &&
      value['reconnectProbe'] == false &&
      selectedEndpoint != null &&
      _isExactStoryGenerationDispatchResolution(selectedEndpoint);
}

bool _isExactStoryArtifactDigest(Map<String, Object?> value) =>
    _hasExactKeys(value, const <String>{
      'domainTag',
      'byteContract',
      'byteLength',
      'digest',
    }) &&
    value['domainTag'] == ArtifactDigest.defaultDomainTag &&
    value['byteContract'] == 'exact-utf8-bytes-no-normalization-v1' &&
    value['byteLength'] is int &&
    (value['byteLength']! as int) >= 0 &&
    _isCanonicalSha256(value['digest']);

bool _isExactStoryGenerationDispatchResolution(Map<String, Object?> value) {
  const required = <String>{
    'contract',
    'endpointId',
    'baseUrl',
    'model',
    'provider',
    'isLocal',
    'physicalDispatchPolicy',
  };
  const optional = <String>{'providerProfileId'};
  if (!_hasExactKeys(value, required, optional: optional) ||
      value['contract'] != 'app-llm-dispatch-resolution-v1' ||
      !_nonEmptyCanonicalString(value['endpointId']) ||
      !_isSafeProviderBaseUrl(value['baseUrl']) ||
      !_nonEmptyCanonicalString(value['model']) ||
      !_isAppLlmProviderName(value['provider']) ||
      value['isLocal'] is! bool ||
      value['physicalDispatchPolicy'] !=
          AppLlmPhysicalDispatchPolicy.single.name) {
    return false;
  }
  final profileId = value['providerProfileId'];
  return profileId == null || _nonEmptyCanonicalString(profileId);
}

bool _isExactStoryGenerationProviderBoundaryReceipt(
  Map<String, Object?> value,
) {
  const required = <String>{
    'contract',
    'physicalDispatchCount',
    'requestedBaseUrl',
    'requestedModel',
    'requestedProvider',
    'transportEndpoint',
    'dispatchEvidenceNonce',
  };
  return _hasExactKeys(value, required) &&
      value['contract'] == 'app-llm-provider-boundary-receipt-v1' &&
      value['physicalDispatchCount'] == 1 &&
      _isSafeProviderBaseUrl(value['requestedBaseUrl']) &&
      _nonEmptyCanonicalString(value['requestedModel']) &&
      _isAppLlmProviderName(value['requestedProvider']) &&
      _isCanonicalSha256(value['dispatchEvidenceNonce']) &&
      _isSafeAbsoluteTransportEndpoint(value['transportEndpoint']);
}

bool _isExactAppLlmProviderOutcomeSeal(Map<String, Object?> value) {
  const required = <String>{
    'contract',
    'succeeded',
    'requestedProvider',
    'requestedModel',
    'statusCode',
    'failureKind',
    'dispatchFailureDisposition',
    'providerModel',
    'providerResponseIdUtf8',
    'promptTokens',
    'completionTokens',
    'totalTokens',
    'textUtf8',
    'detailUtf8',
  };
  if (!_hasExactKeys(value, required) ||
      value['contract'] != 'app-llm-provider-outcome-seal-v1' ||
      value['succeeded'] is! bool ||
      !_isAppLlmProviderName(value['requestedProvider']) ||
      !_nonEmptyCanonicalString(value['requestedModel'])) {
    return false;
  }
  final statusCode = value['statusCode'];
  final failureKind = value['failureKind'];
  final failureDisposition = value['dispatchFailureDisposition'];
  final providerModel = value['providerModel'];
  if ((statusCode != null && (statusCode is! int || statusCode < 0)) ||
      (failureKind != null &&
          !AppLlmFailureKind.values.any(
            (candidate) => candidate.name == failureKind,
          )) ||
      (failureDisposition != null &&
          !AppLlmDispatchFailureDisposition.values.any(
            (candidate) => candidate.name == failureDisposition,
          )) ||
      (providerModel != null && !_nonEmptyCanonicalString(providerModel))) {
    return false;
  }
  for (final field in const <String>[
    'promptTokens',
    'completionTokens',
    'totalTokens',
  ]) {
    final count = value[field];
    if (count != null && (count is! int || count < 0)) return false;
  }
  for (final field in const <String>[
    'providerResponseIdUtf8',
    'textUtf8',
    'detailUtf8',
  ]) {
    final seal = value[field];
    if (seal != null && !_isExactUtf8Seal(_asStringMap(seal))) return false;
  }
  return true;
}

bool _isExactUtf8Seal(Map<String, Object?>? value) =>
    value != null &&
    _hasExactKeys(value, const <String>{'byteLength', 'digest'}) &&
    value['byteLength'] is int &&
    (value['byteLength']! as int) >= 0 &&
    _isCanonicalSha256(value['digest']);

bool _hasConsistentStoryGenerationTransportEndpoints({
  required Map<String, Object?> selectedEndpoint,
  required Map<String, Object?> observedResolution,
  required Map<String, Object?> providerReceipt,
}) {
  if (!_isExactStoryGenerationDispatchResolution(selectedEndpoint) ||
      !_isExactStoryGenerationDispatchResolution(observedResolution) ||
      !_isExactStoryGenerationProviderBoundaryReceipt(providerReceipt)) {
    return false;
  }
  if (!_canonicalJsonEquals(selectedEndpoint, observedResolution)) return false;
  final baseUri = Uri.tryParse(selectedEndpoint['baseUrl'] as String);
  final host = baseUri?.host.toLowerCase();
  final expectedLocal =
      host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '0.0.0.0';
  if (selectedEndpoint['isLocal'] != expectedLocal) return false;
  if (providerReceipt['requestedBaseUrl'] != selectedEndpoint['baseUrl'] ||
      providerReceipt['requestedModel'] != selectedEndpoint['model'] ||
      providerReceipt['requestedProvider'] != selectedEndpoint['provider']) {
    return false;
  }
  final provider = (selectedEndpoint['provider'] as String).toAppLlmProvider();
  final expected = resolveAppLlmTransportEndpoint(
    selectedEndpoint['baseUrl'] as String,
    AppLlmProviderAdapters.of(provider).endpointPath,
  );
  final observed = Uri.tryParse(providerReceipt['transportEndpoint'] as String);
  return expected != null &&
      observed != null &&
      _sameAbsoluteEndpoint(expected, observed);
}

bool _hasExactKeys(
  Map<String, Object?> value,
  Set<String> required, {
  Set<String> optional = const <String>{},
}) =>
    value.keys.toSet().containsAll(required) &&
    value.keys.every(<String>{...required, ...optional}.contains);

Map<String, Object?>? _asStringMap(Object? value) {
  if (value is! Map) return null;
  try {
    return Map<String, Object?>.from(value);
  } on Object {
    return null;
  }
}

bool _nonEmptyCanonicalString(Object? value) =>
    value is String && value.isNotEmpty && value == value.trim();

bool _isCanonicalSha256(Object? value) =>
    value is String && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

bool _isAppLlmProviderName(Object? value) =>
    value is String &&
    AppLlmProvider.values.any((provider) => provider.name == value);

bool _isSafeProviderBaseUrl(Object? value) {
  if (!_nonEmptyCanonicalString(value)) return false;
  final uri = Uri.tryParse(value as String);
  return uri != null &&
      uri.isAbsolute &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

bool _isSafeAbsoluteTransportEndpoint(Object? value) {
  if (!_nonEmptyCanonicalString(value)) return false;
  final uri = Uri.tryParse(value as String);
  return uri != null &&
      uri.isAbsolute &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment;
}

bool _sameAbsoluteEndpoint(Uri left, Uri right) =>
    left.isAbsolute &&
    right.isAbsolute &&
    left.scheme.toLowerCase() == right.scheme.toLowerCase() &&
    left.host.toLowerCase() == right.host.toLowerCase() &&
    _effectivePort(left) == _effectivePort(right) &&
    left.path == right.path &&
    left.query == right.query &&
    left.fragment == right.fragment &&
    left.userInfo == right.userInfo;

bool _canonicalJsonEquals(Object? left, Object? right) {
  try {
    return AppLlmCanonicalHash.canonicalJson(left) ==
        AppLlmCanonicalHash.canonicalJson(right);
  } on Object {
    return false;
  }
}

final class StoryGenerationAttemptEvidenceCapture {
  StoryGenerationAttemptEvidenceCapture();

  final List<StoryGenerationAttemptEvidence> _attempts = [];

  void record(StoryGenerationAttemptEvidence evidence) {
    _attempts.add(evidence);
  }

  List<StoryGenerationAttemptEvidence> get attempts =>
      List<StoryGenerationAttemptEvidence>.unmodifiable(_attempts);

  StoryGenerationAttemptEvidenceEnvelope toEnvelope() =>
      StoryGenerationAttemptEvidenceEnvelope(attempts: attempts);
}

final class StoryGenerationAttemptEvidenceEnvelope {
  StoryGenerationAttemptEvidenceEnvelope({
    required Iterable<StoryGenerationAttemptEvidence> attempts,
    this.schemaVersion = 'story-generation-attempt-evidence-envelope-v1',
  }) : attempts = List<StoryGenerationAttemptEvidence>.unmodifiable(attempts);

  final String schemaVersion;
  final List<StoryGenerationAttemptEvidence> attempts;

  bool get evidenceComplete =>
      attempts.isNotEmpty &&
      attempts.every((attempt) => attempt.evidenceComplete);

  Map<String, Object?> toPrivateJson() => {
    'schemaVersion': schemaVersion,
    'visibility': 'private',
    'evidenceComplete': evidenceComplete,
    'attempts': [
      for (var index = 0; index < attempts.length; index += 1)
        {
          'sequenceNo': index,
          'attemptEvidenceDigest': attempts[index].privateEvidenceDigest,
          ...attempts[index].toJson(),
        },
    ],
  };

  Map<String, Object?> toBlindReviewJson() => {
    'schemaVersion': schemaVersion,
    'visibility': 'blind',
    'evidenceComplete': evidenceComplete,
  };
}

bool _nonEmpty(String? value) => value != null && value.trim().isNotEmpty;

bool _sha256Digest(String? value) =>
    value != null && RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(value);

Duration _exponentialBackoffWithJitter(int attempt) {
  final delayMs =
      _baseRetryDelay.inMilliseconds * (1 << attempt); // 2^attempt * base
  final cappedMs = delayMs.clamp(0, _maxRetryDelay.inMilliseconds);
  final jitterMs = _retryJitter.nextInt((cappedMs * 0.2).ceil() + 1);
  return Duration(milliseconds: cappedMs + jitterMs);
}

Future<AppLlmChatResult> requestFormalStoryGenerationPassWithRetry({
  required StoryGenerationSettingsContract settingsStore,
  required List<AppLlmChatMessage> messages,
  int maxTransientRetries = _defaultMaxTransientRetries,
  int maxOutputRetries = 2,
  int initialMaxTokens = storyGenerationDefaultMaxTokens,
  int maxEscalatedTokens = storyGenerationMaxEscalatedTokens,
  bool Function(String text)? shouldRetryOutput,
  RequestRateLimiter? rateLimiter,
  StoryGenerationRetryPolicy? retryPolicy,
  StoryGenerationNoCompletionProof? provesNoProviderCompletion,
  StoryGenerationAttemptEvidenceRecorder? onAttemptEvidence,
  StoryGenerationAttemptEvidencePersister? persistAttemptEvidence,
  StoryGenerationEvaluationFingerprintSeed? evaluationFingerprintSeed,
  String? traceName,
  Map<String, Object?> traceMetadata = const {},
  required StoryPromptInvocation promptInvocation,
  required PromptInvocationEvidence promptInvocationEvidence,
}) {
  if (!promptInvocationEvidence.matchesMessages(messages) ||
      promptInvocationEvidence.promptReleaseRef !=
          promptInvocation.promptReleaseRef ||
      promptInvocationEvidence.release.contentHash !=
          promptInvocation.release.contentHash) {
    throw StateError('formal prompt invocation evidence mismatch');
  }
  final identity = _validateFormalPromptIdentity(
    stageId: promptInvocation.callSite.stageId,
    callSiteId: promptInvocation.callSite.callSiteId,
    variantId: promptInvocation.callSite.variantId,
    generationBundleHash: promptInvocation.generationBundleHash,
  );
  final evaluationContext = AgentEvaluationTraceContext.current;
  if (evaluationContext != null &&
      evaluationContext.generationBundleHash != identity.generationBundleHash) {
    throw StateError(
      'formal evaluation cell bundle does not match prompt invocation bundle',
    );
  }
  if (evaluationContext != null && evaluationFingerprintSeed != null) {
    if (evaluationFingerprintSeed.evaluationBundleHash !=
        evaluationContext.evaluationBundleHash) {
      throw StoryGenerationEvidencePreflightFailure(
        'formal evaluation fingerprint bundle does not match the trace',
        code: 'story_generation_formal_trace_bundle_mismatch',
      );
    }
    if (evaluationFingerprintSeed.blindingPolicy !=
        'formal-evaluation-context-v1') {
      throw StoryGenerationEvidencePreflightFailure(
        'formal evaluation trace requires its frozen blinding policy',
        code: 'story_generation_formal_trace_blinding_mismatch',
      );
    }
  } else if (evaluationFingerprintSeed?.blindingPolicy ==
      'formal-evaluation-context-v1') {
    throw StoryGenerationEvidencePreflightFailure(
      'formal evaluation blinding policy requires a trace context',
      code: 'story_generation_formal_blinding_without_trace',
    );
  }
  final formalRetryPolicy = _effectiveRetryPolicy(retryPolicy);
  final evaluationScope = StoryGenerationEvaluationScope.current;
  if ((evaluationFingerprintSeed == null) != (evaluationScope == null)) {
    throw StoryGenerationEvidencePreflightFailure(
      'evaluation fingerprint and runner evaluation scope must be presented '
      'together',
      code: 'story_generation_evaluation_scope_mismatch',
    );
  }
  if (evaluationFingerprintSeed != null && evaluationScope != null) {
    if (!_sameArtifactDigest(
      evaluationFingerprintSeed.artifactDigest,
      evaluationScope.artifactDigest,
    )) {
      throw StoryGenerationEvidencePreflightFailure(
        'evaluation fingerprint artifact does not match the runner scope',
        code: 'story_generation_evaluation_artifact_mismatch',
      );
    }
    final allowed = switch (evaluationScope.phase) {
      StoryGenerationEvaluationPhase.preliminaryReview ||
      StoryGenerationEvaluationPhase.finalCouncil =>
        identity.stageId == 'review' &&
            const <String>{
              'judge',
              'consistency',
              'reader-flow',
              'lexicon',
              'adjudication',
            }.contains(identity.callSiteId),
      StoryGenerationEvaluationPhase.quality =>
        identity.stageId == 'quality-gate' &&
            identity.callSiteId == 'quality-scorer',
    };
    if (!allowed) {
      throw StoryGenerationEvidencePreflightFailure(
        'evaluation phase is not valid for the registered prompt callsite',
        code: 'story_generation_evaluation_callsite_mismatch',
      );
    }
  }
  final scopedArmPolicy = StoryGenerationRetryScope.currentGenerationArmPolicy;
  if (!formalRetryPolicy.allowsContentRedraw &&
      (scopedArmPolicy == null || scopedArmPolicy.trim().isEmpty)) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw formal generation requires an explicit arm policy',
    );
  }
  final generationArmPolicy =
      scopedArmPolicy ?? 'variant:${identity.variantId}';
  final resolvedTraceName =
      traceName ?? _inferStoryGenerationTraceName(messages);
  final singlePhysicalSettings =
      settingsStore is StoryGenerationSinglePhysicalDispatchSettingsContract
      ? settingsStore as StoryGenerationSinglePhysicalDispatchSettingsContract
      : null;
  if (!formalRetryPolicy.allowsContentRedraw &&
      singlePhysicalSettings == null) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw formal generation requires a single-physical-dispatch '
      'settings contract',
    );
  }
  Object? configuredRouteIdentity;
  StoryGenerationSinglePhysicalDispatchRouteLease? singlePhysicalRouteLease;
  if (!formalRetryPolicy.allowsContentRedraw) {
    singlePhysicalRouteLease = singlePhysicalSettings!
        .prepareStoryGenerationSinglePhysicalDispatchRoute(
          traceName: resolvedTraceName,
        );
    configuredRouteIdentity = singlePhysicalRouteLease?.credentialFreeIdentity;
  } else if (settingsStore is StoryGenerationModelRouteIdentityProvider) {
    configuredRouteIdentity =
        (settingsStore as StoryGenerationModelRouteIdentityProvider)
            .storyGenerationModelRouteIdentity(traceName: resolvedTraceName);
  }
  if (!formalRetryPolicy.allowsContentRedraw &&
      configuredRouteIdentity == null) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw formal generation requires a configured model-route identity',
    );
  }
  final configuredRouteHash = configuredRouteIdentity == null
      ? null
      : AppLlmCanonicalHash.domainHash(
          'story-generation-configured-model-route-v1',
          configuredRouteIdentity,
        );
  final configuredSelectedEndpoint = _selectedEndpointFromRouteIdentity(
    configuredRouteIdentity,
  );
  final configuredSelectedEndpointHash = configuredSelectedEndpoint == null
      ? null
      : AppLlmCanonicalHash.domainHash(
          'story-generation-selected-physical-endpoint-v1',
          configuredSelectedEndpoint,
        );
  if (!formalRetryPolicy.allowsContentRedraw &&
      configuredSelectedEndpointHash == null) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw formal generation requires one frozen selected endpoint',
    );
  }
  final retryContractHash = AppLlmCanonicalHash.domainHash(
    'story-generation-retry-contract-v1',
    <String, Object?>{
      'scope': formalRetryPolicy.scope.name,
      'maxTotalAttempts': formalRetryPolicy.maxTotalAttempts,
      'maxNoProviderCompletionRetries':
          formalRetryPolicy.maxNoProviderCompletionRetries,
      'maxTransientRetries': maxTransientRetries,
      'maxOutputRetries': maxOutputRetries,
      'initialMaxTokens': initialMaxTokens,
      'maxEscalatedTokens': maxEscalatedTokens,
      'semanticOutputRetryEnabled': shouldRetryOutput != null,
      'noProviderCompletionProofEnabled': provesNoProviderCompletion != null,
      'physicalDispatchPolicy': formalRetryPolicy.allowsContentRedraw
          ? AppLlmPhysicalDispatchPolicy.adaptive.name
          : AppLlmPhysicalDispatchPolicy.single.name,
    },
  );
  final scopedEvidenceRunId = StoryGenerationRetryScope.currentEvidenceRunId
      ?.trim();
  final scopedEvidenceSceneId = StoryGenerationRetryScope.currentEvidenceSceneId
      ?.trim();
  final scopedPreparedBriefDigest = StoryGenerationRetryScope
      .currentPreparedBriefDigest
      ?.trim();
  final scopedIntentPersister =
      StoryGenerationRetryScope.currentAttemptIntentPersister;
  if (!formalRetryPolicy.allowsContentRedraw &&
      (scopedEvidenceRunId == null ||
          scopedEvidenceRunId.isEmpty ||
          scopedEvidenceSceneId == null ||
          scopedEvidenceSceneId.isEmpty ||
          !_sha256Digest(scopedPreparedBriefDigest) ||
          scopedIntentPersister == null)) {
    throw StoryGenerationEvidencePreflightFailure(
      'no-redraw formal generation requires a stable evidence run/scene '
      'identity, prepared brief digest, and durable write-ahead intent persister',
    );
  }

  String logicalAttemptIdFor({
    required int attempt,
    required int maxTokens,
    required int transientRetryCount,
    required int outputRetryCount,
  }) => AppLlmCanonicalHash.domainHash(
    'story-generation-logical-attempt-id-v1',
    <String, Object?>{
      'evidenceRunId': scopedEvidenceRunId,
      'sceneId': scopedEvidenceSceneId,
      'preparedBriefDigest': scopedPreparedBriefDigest,
      'attempt': attempt,
      'maxTokens': maxTokens,
      'transientRetryCount': transientRetryCount,
      'outputRetryCount': outputRetryCount,
      'stageId': identity.stageId,
      'callSiteId': identity.callSiteId,
      'variantId': identity.variantId,
      'generationBundleHash': identity.generationBundleHash,
      'promptReleaseContentHash': promptInvocation.promptReleaseRef.contentHash,
      'renderedMessagesDigest': promptInvocationEvidence.renderedMessagesDigest,
      'resolvedVariablesDigest':
          promptInvocationEvidence.resolvedVariablesDigest,
      'rendererContractHash': promptInvocationEvidence.rendererContractHash,
      'selectedRouteBindingHash': configuredRouteHash,
      'generationArmPolicy': generationArmPolicy,
      'retryContractHash': retryContractHash,
      'evaluationPhase': evaluationScope?.phase.name,
    },
  );
  return requestStoryGenerationPassWithRetry(
    dispatch:
        ({
          required maxTokens,
          required attempt,
          required transientRetryCount,
          required outputRetryCount,
        }) async {
          final logicalAttemptId = formalRetryPolicy.allowsContentRedraw
              ? null
              : logicalAttemptIdFor(
                  attempt: attempt,
                  maxTokens: maxTokens,
                  transientRetryCount: transientRetryCount,
                  outputRetryCount: outputRetryCount,
                );
          final formalIntent = formalRetryPolicy.allowsContentRedraw
              ? null
              : StoryGenerationAttemptIntent(
                  evidenceRunId: scopedEvidenceRunId!,
                  sceneId: scopedEvidenceSceneId!,
                  preparedBriefDigest: scopedPreparedBriefDigest!,
                  logicalAttemptId: logicalAttemptId!,
                  attempt: attempt,
                  maxTokens: maxTokens,
                  transientRetryCount: transientRetryCount,
                  outputRetryCount: outputRetryCount,
                  stageId: identity.stageId,
                  callSiteId: identity.callSiteId,
                  variantId: identity.variantId,
                  generationBundleHash: identity.generationBundleHash,
                  promptReleaseRef: promptInvocation.promptReleaseRef.toJson(),
                  promptReleaseContentHash:
                      promptInvocation.promptReleaseRef.contentHash,
                  renderedMessagesDigest:
                      promptInvocationEvidence.renderedMessagesDigest,
                  resolvedVariablesDigest:
                      promptInvocationEvidence.resolvedVariablesDigest,
                  rendererContractHash:
                      promptInvocationEvidence.rendererContractHash,
                  selectedRouteBindingHash: configuredRouteHash!,
                  generationArmPolicy: generationArmPolicy,
                  retryContractHash: retryContractHash,
                  evaluationPhase: evaluationScope?.phase,
                );
          final attemptTraceMetadata = <String, Object?>{
            ...traceMetadata,
            'attempt': attempt,
            'transientRetryCount': transientRetryCount,
            'outputRetryCount': outputRetryCount,
            'maxTokens': maxTokens,
            'physicalDispatchPolicy': formalRetryPolicy.allowsContentRedraw
                ? AppLlmPhysicalDispatchPolicy.adaptive.name
                : AppLlmPhysicalDispatchPolicy.single.name,
            'promptReleaseRef': promptInvocation.promptReleaseRef.toJson(),
            'stageId': identity.stageId,
            'callSiteId': identity.callSiteId,
            'variantId': identity.variantId,
            'generationBundleHash': identity.generationBundleHash,
            if (evaluationContext != null)
              ...evaluationContext.toTraceMetadata(),
          };
          if (!formalRetryPolicy.allowsContentRedraw) {
            // The durable journal flush and the central dispatch share one
            // opaque lexical lease. No request permit exists before the flush
            // succeeds, and the exact logical attempt can consume it once.
            final committedIntentAuthority = await scopedIntentPersister!(
              formalIntent!,
            );
            if (committedIntentAuthority == null) {
              throw StoryGenerationEvidencePreflightFailure(
                'write-ahead intent persister returned no durable commit authority',
              );
            }
            // llm-call-site: boundary.story.single-physical-retry-dispatch
            return singlePhysicalSettings!
                .requestAiCompletionSinglePhysicalDispatch(
                  messages: messages,
                  maxTokens: maxTokens,
                  dispatchEvidenceNonce: logicalAttemptId!,
                  formalDispatchIntent: formalIntent.toPrivateJson(),
                  committedIntentAuthority: committedIntentAuthority,
                  traceName: resolvedTraceName,
                  promptReleaseRef: promptInvocation.promptReleaseRef,
                  promptInvocationEvidence: promptInvocationEvidence,
                  stageId: identity.stageId,
                  callSiteId: identity.callSiteId,
                  variantId: identity.variantId,
                  generationBundleHash: identity.generationBundleHash,
                  traceMetadata: attemptTraceMetadata,
                  routeLease: singlePhysicalRouteLease!,
                );
          }
          // llm-call-site: boundary.story.retry-dispatch
          return settingsStore.requestAiCompletion(
            messages: messages,
            maxTokens: maxTokens,
            traceName: resolvedTraceName,
            promptReleaseRef: promptInvocation.promptReleaseRef,
            promptInvocationEvidence: promptInvocationEvidence,
            stageId: identity.stageId,
            callSiteId: identity.callSiteId,
            variantId: identity.variantId,
            generationBundleHash: identity.generationBundleHash,
            traceMetadata: attemptTraceMetadata,
          );
        },
    maxTransientRetries: maxTransientRetries,
    maxOutputRetries: maxOutputRetries,
    initialMaxTokens: initialMaxTokens,
    maxEscalatedTokens: maxEscalatedTokens,
    shouldRetryOutput: shouldRetryOutput,
    rateLimiter: rateLimiter,
    retryPolicy: retryPolicy,
    provesNoProviderCompletion: provesNoProviderCompletion,
    onAttemptEvidence: onAttemptEvidence,
    persistAttemptEvidence: persistAttemptEvidence,
    requireCompleteAttemptEvidence: !formalRetryPolicy.allowsContentRedraw,
    enrichAttemptEvidence: (evidence, result) {
      final logicalAttemptId = formalRetryPolicy.allowsContentRedraw
          ? null
          : logicalAttemptIdFor(
              attempt: evidence.attempt,
              maxTokens: evidence.maxTokens,
              transientRetryCount: evidence.transientRetryCount,
              outputRetryCount: evidence.outputRetryCount,
            );
      final providerModel = result.providerModel?.trim();
      final providerBoundaryReceipt = result.providerBoundaryReceipt;
      final providerBoundaryReceiptJson = providerBoundaryReceipt
          ?.toCredentialFreeJson();
      final providerBoundaryReceiptHash = providerBoundaryReceiptJson == null
          ? null
          : AppLlmCanonicalHash.domainHash(
              'story-generation-provider-boundary-receipt-v1',
              providerBoundaryReceiptJson,
            );
      final providerOutcomeSeal = providerBoundaryReceipt == null
          ? null
          : appLlmProviderOutcomeSealForResult(
              result: result,
              requestedProvider: providerBoundaryReceipt.requestedProvider,
              requestedModel: providerBoundaryReceipt.requestedModel,
            );
      final providerOutcomeSealHash = providerOutcomeSeal == null
          ? null
          : appLlmProviderOutcomeSealDigest(providerOutcomeSeal);
      final formalDispatchWitness =
          !formalRetryPolicy.allowsContentRedraw &&
              providerBoundaryReceipt != null
          ? _formalDispatchWitnessForSelectedEndpoint(
              providerBoundaryReceipt,
              configuredSelectedEndpoint,
              messages: messages,
              maxTokens: evidence.maxTokens,
              dispatchEvidenceNonce: logicalAttemptId,
            )
          : null;
      final providerBoundaryReceiptVerified = formalDispatchWitness != null;
      final observedDispatchResolution = result.dispatchResolution
          ?.toCredentialFreeJson();
      final observedDispatchResolutionHash = observedDispatchResolution == null
          ? null
          : AppLlmCanonicalHash.domainHash(
              'story-generation-selected-physical-endpoint-v1',
              observedDispatchResolution,
            );
      final routeResolutionVerified =
          !formalRetryPolicy.allowsContentRedraw &&
          providerBoundaryReceiptVerified &&
          configuredSelectedEndpointHash != null &&
          observedDispatchResolutionHash == configuredSelectedEndpointHash;
      final hasModelRoute =
          configuredRouteHash != null &&
          providerModel != null &&
          providerModel.isNotEmpty &&
          (formalRetryPolicy.allowsContentRedraw || routeResolutionVerified);
      final modelRoute = hasModelRoute
          ? AppLlmCanonicalHash.domainHash(
              'story-generation-observed-model-route-v1',
              <String, Object?>{
                'configuredRouteHash': configuredRouteHash,
                'providerEchoedModel': providerModel,
              },
            )
          : null;
      final artifactDigest = result.succeeded && result.text != null
          ? ArtifactDigest.fromUtf8String(result.text!)
          : null;
      final generationFingerprint =
          result.succeeded &&
              artifactDigest != null &&
              hasModelRoute &&
              evaluationFingerprintSeed == null
          ? GenerationFingerprint(
              semanticInput: {
                'stageId': identity.stageId,
                'callSiteId': identity.callSiteId,
                'promptReleaseContentHash':
                    promptInvocation.promptReleaseRef.contentHash,
                'renderedMessagesDigest':
                    promptInvocationEvidence.renderedMessagesDigest,
                'resolvedVariablesDigest':
                    promptInvocationEvidence.resolvedVariablesDigest,
                'rendererContractHash':
                    promptInvocationEvidence.rendererContractHash,
                ...?scopedPreparedBriefDigest == null
                    ? null
                    : <String, Object?>{
                        'preparedBriefDigest': scopedPreparedBriefDigest,
                      },
              },
              generationBundleHash: identity.generationBundleHash,
              modelRoute: modelRoute!,
              decodingParameters: {'maxTokens': evidence.maxTokens},
              armPolicy: generationArmPolicy,
              retryPolicy: retryContractHash,
            )
          : null;
      final evaluationFingerprint =
          result.succeeded && hasModelRoute && evaluationFingerprintSeed != null
          ? EvaluationFingerprint(
              artifactDigest: evaluationFingerprintSeed.artifactDigest,
              evaluationBundleHash:
                  evaluationFingerprintSeed.evaluationBundleHash,
              judgeInput: evaluationFingerprintSeed.judgeInput,
              judgeModelRoute: modelRoute!,
              rubricHash: evaluationFingerprintSeed.rubricHash,
              blindingPolicy: evaluationFingerprintSeed.blindingPolicy,
            )
          : null;
      return evidence.copyWithFormalEvidence(
        stageId: identity.stageId,
        callSiteId: identity.callSiteId,
        variantId: identity.variantId,
        preparedBriefDigest:
            scopedPreparedBriefDigest ??
            AppLlmCanonicalHash.domainHash(
              'story-generation-adaptive-prepared-brief-v1',
              <String, Object?>{
                'stageId': identity.stageId,
                'callSiteId': identity.callSiteId,
                'variantId': identity.variantId,
                'generationBundleHash': identity.generationBundleHash,
              },
            ),
        logicalAttemptId: logicalAttemptId,
        generationBundleHash: identity.generationBundleHash,
        promptReleaseRef: promptInvocation.promptReleaseRef.toJson(),
        promptReleaseContentHash: promptInvocation.promptReleaseRef.contentHash,
        renderedMessagesDigest: promptInvocationEvidence.renderedMessagesDigest,
        resolvedVariablesDigest:
            promptInvocationEvidence.resolvedVariablesDigest,
        rendererContractHash: promptInvocationEvidence.rendererContractHash,
        selectedRouteBindingHash: configuredRouteHash,
        selectedRouteBinding: configuredRouteIdentity is Map
            ? Map<String, Object?>.from(configuredRouteIdentity)
            : null,
        observedDispatchResolutionHash: observedDispatchResolutionHash,
        observedDispatchResolution: observedDispatchResolution != null
            ? Map<String, Object?>.from(observedDispatchResolution)
            : null,
        routeResolutionRequired: !formalRetryPolicy.allowsContentRedraw,
        routeResolutionVerified: routeResolutionVerified,
        providerBoundaryReceiptHash: providerBoundaryReceiptHash,
        providerBoundaryReceipt: providerBoundaryReceiptJson,
        providerOutcomeSealHash: providerOutcomeSealHash,
        providerOutcomeSeal: providerOutcomeSeal,
        providerBoundaryPhysicalDispatchCount:
            providerBoundaryReceipt?.physicalDispatchCount,
        providerBoundaryReceiptRequired: !formalRetryPolicy.allowsContentRedraw,
        providerBoundaryReceiptVerified: providerBoundaryReceiptVerified,
        formalDispatchWitness: formalDispatchWitness,
        artifactDigest: artifactDigest,
        generationFingerprint: generationFingerprint,
        evaluationFingerprint: evaluationFingerprint,
        evaluationParserRelease: evaluationFingerprintSeed == null
            ? null
            : promptInvocation.release.parserRelease,
        evaluationPhase: evaluationFingerprintSeed == null
            ? null
            : evaluationScope!.phase,
        evaluationFingerprintRequired: evaluationFingerprintSeed != null,
      );
    },
  );
}

/// Pure retry state machine. The caller owns authorization and transport;
/// production story generation must use
/// [requestFormalStoryGenerationPassWithRetry], which supplies a registered
/// prompt authority before dispatch reaches the provider.
Future<AppLlmChatResult> requestStoryGenerationPassWithRetry({
  required StoryGenerationAttemptDispatcher dispatch,
  int maxTransientRetries = _defaultMaxTransientRetries,
  int maxOutputRetries = 2,
  int initialMaxTokens = storyGenerationDefaultMaxTokens,
  int maxEscalatedTokens = storyGenerationMaxEscalatedTokens,
  bool Function(String text)? shouldRetryOutput,
  RequestRateLimiter? rateLimiter,
  StoryGenerationRetryPolicy? retryPolicy,
  StoryGenerationNoCompletionProof? provesNoProviderCompletion,
  StoryGenerationAttemptEvidenceRecorder? onAttemptEvidence,
  StoryGenerationAttemptEvidencePersister? persistAttemptEvidence,
  bool requireCompleteAttemptEvidence = false,
  StoryGenerationAttemptEvidenceEnricher? enrichAttemptEvidence,
}) async {
  final scopedPolicy = StoryGenerationRetryScope.current;
  final scopedRecorder =
      StoryGenerationRetryScope.currentAttemptEvidenceRecorder;
  final scopedPersister =
      StoryGenerationRetryScope.currentAttemptEvidencePersister;
  final effectivePolicy = _effectiveRetryPolicy(retryPolicy);
  final attemptEvidenceRecorder = _attemptEvidenceRecorder(
    scopedRecorder: scopedRecorder,
    callerRecorder: onAttemptEvidence,
  );
  final attemptEvidencePersister = _attemptEvidencePersister(
    scopedPersister: scopedPersister,
    callerPersister: persistAttemptEvidence,
  );
  if (!effectivePolicy.allowsContentRedraw) {
    if (scopedPolicy != null &&
        !scopedPolicy.allowsContentRedraw &&
        scopedRecorder == null) {
      throw StoryGenerationEvidencePreflightFailure(
        'no-redraw retry scope requires a scoped attempt evidence recorder',
      );
    }
    if (attemptEvidenceRecorder == null) {
      throw StoryGenerationEvidencePreflightFailure(
        'no-redraw retry policy requires an attempt evidence recorder',
      );
    }
    if (scopedPolicy != null &&
        !scopedPolicy.allowsContentRedraw &&
        scopedPersister == null) {
      throw StoryGenerationEvidencePreflightFailure(
        'no-redraw retry scope requires a scoped durable attempt evidence '
        'persister',
      );
    }
    if (attemptEvidencePersister == null) {
      throw StoryGenerationEvidencePreflightFailure(
        'no-redraw retry policy requires a durable attempt evidence '
        'persister',
      );
    }
  }
  var transientRetries = 0;
  var outputRetries = 0;
  var noProviderCompletionRetries = 0;
  var maxTokens = _normalizeTokenLimit(initialMaxTokens);
  final tokenCeiling = _normalizeTokenLimit(maxEscalatedTokens);
  var attempt = 0;

  while (true) {
    if (rateLimiter != null) {
      await rateLimiter.acquire();
    }
    final result = await dispatch(
      maxTokens: maxTokens,
      attempt: attempt,
      transientRetryCount: transientRetries,
      outputRetryCount: outputRetries,
    );
    final currentAttempt = attempt;
    attempt += 1;
    final canDispatchAgain = _canDispatchAnotherAttempt(
      attemptsMade: attempt,
      policy: effectivePolicy,
    );

    if (effectivePolicy.allowsContentRedraw &&
        canDispatchAgain &&
        _shouldRetryWithMoreTokens(result: result, maxTokens: maxTokens)) {
      final nextMaxTokens = _nextTokenLimit(maxTokens, ceiling: tokenCeiling);
      if (nextMaxTokens > maxTokens) {
        await _recordAttemptEvidence(
          recorder: attemptEvidenceRecorder,
          persister: attemptEvidencePersister,
          requireCompleteEvidence: requireCompleteAttemptEvidence,
          enricher: enrichAttemptEvidence,
          attempt: currentAttempt,
          maxTokens: maxTokens,
          transientRetryCount: transientRetries,
          outputRetryCount: outputRetries,
          result: result,
          disposition: StoryGenerationRetryDisposition.retryMoreTokens,
        );
        maxTokens = nextMaxTokens;
        continue;
      }
    }

    if (effectivePolicy.allowsContentRedraw &&
        canDispatchAgain &&
        result.succeeded &&
        (shouldRetryOutput?.call(result.text ?? '') ?? false) &&
        outputRetries < maxOutputRetries) {
      await _recordAttemptEvidence(
        recorder: attemptEvidenceRecorder,
        persister: attemptEvidencePersister,
        requireCompleteEvidence: requireCompleteAttemptEvidence,
        enricher: enrichAttemptEvidence,
        attempt: currentAttempt,
        maxTokens: maxTokens,
        transientRetryCount: transientRetries,
        outputRetryCount: outputRetries,
        result: result,
        disposition: StoryGenerationRetryDisposition.retrySemanticOutput,
      );
      outputRetries += 1;
      continue;
    }

    if (result.succeeded) {
      await _recordAttemptEvidence(
        recorder: attemptEvidenceRecorder,
        persister: attemptEvidencePersister,
        requireCompleteEvidence: requireCompleteAttemptEvidence,
        enricher: enrichAttemptEvidence,
        attempt: currentAttempt,
        maxTokens: maxTokens,
        transientRetryCount: transientRetries,
        outputRetryCount: outputRetries,
        result: result,
        disposition: StoryGenerationRetryDisposition.returned,
      );
      return result;
    }

    if (effectivePolicy.scope ==
            StoryGenerationRetryPolicyScope.experimentNoContentRedraw &&
        canDispatchAgain &&
        _hasNoProviderCompletionProof(
          result,
          provesNoProviderCompletion: provesNoProviderCompletion,
        ) &&
        noProviderCompletionRetries <
            effectivePolicy.maxNoProviderCompletionRetries) {
      await _recordAttemptEvidence(
        recorder: attemptEvidenceRecorder,
        persister: attemptEvidencePersister,
        requireCompleteEvidence: requireCompleteAttemptEvidence,
        enricher: enrichAttemptEvidence,
        attempt: currentAttempt,
        maxTokens: maxTokens,
        transientRetryCount: transientRetries,
        outputRetryCount: outputRetries,
        result: result,
        disposition: StoryGenerationRetryDisposition.retryNoProviderCompletion,
      );
      noProviderCompletionRetries += 1;
      continue;
    }

    if (!effectivePolicy.allowsContentRedraw ||
        !canDispatchAgain ||
        !isRetryableStoryGenerationTransportFailure(result) ||
        transientRetries >= maxTransientRetries) {
      await _recordAttemptEvidence(
        recorder: attemptEvidenceRecorder,
        persister: attemptEvidencePersister,
        requireCompleteEvidence: requireCompleteAttemptEvidence,
        enricher: enrichAttemptEvidence,
        attempt: currentAttempt,
        maxTokens: maxTokens,
        transientRetryCount: transientRetries,
        outputRetryCount: outputRetries,
        result: result,
        disposition: StoryGenerationRetryDisposition.returned,
      );
      return result;
    }

    await _recordAttemptEvidence(
      recorder: attemptEvidenceRecorder,
      persister: attemptEvidencePersister,
      requireCompleteEvidence: requireCompleteAttemptEvidence,
      enricher: enrichAttemptEvidence,
      attempt: currentAttempt,
      maxTokens: maxTokens,
      transientRetryCount: transientRetries,
      outputRetryCount: outputRetries,
      result: result,
      disposition: StoryGenerationRetryDisposition.retryTransientFailure,
    );
    transientRetries += 1;
    await Future<void>.delayed(
      _exponentialBackoffWithJitter(transientRetries - 1),
    );
  }
}

bool _canDispatchAnotherAttempt({
  required int attemptsMade,
  required StoryGenerationRetryPolicy policy,
}) {
  final cap = policy.maxTotalAttempts;
  return cap == null || attemptsMade < cap;
}

StoryGenerationRetryPolicy _effectiveRetryPolicy(
  StoryGenerationRetryPolicy? retryPolicy,
) {
  final scopedPolicy = StoryGenerationRetryScope.current;
  // A frozen experiment scope is authoritative. A nested callsite cannot
  // weaken it by explicitly requesting the adaptive production policy.
  return scopedPolicy != null && !scopedPolicy.allowsContentRedraw
      ? scopedPolicy
      : retryPolicy ??
            scopedPolicy ??
            const StoryGenerationRetryPolicy.productionAdaptive();
}

StoryGenerationAttemptEvidenceRecorder? _attemptEvidenceRecorder({
  required StoryGenerationAttemptEvidenceRecorder? scopedRecorder,
  required StoryGenerationAttemptEvidenceRecorder? callerRecorder,
}) {
  if (scopedRecorder == null) {
    return callerRecorder;
  }
  if (callerRecorder == null) {
    return scopedRecorder;
  }
  return (evidence) {
    scopedRecorder(evidence);
    callerRecorder(evidence);
  };
}

StoryGenerationAttemptEvidencePersister? _attemptEvidencePersister({
  required StoryGenerationAttemptEvidencePersister? scopedPersister,
  required StoryGenerationAttemptEvidencePersister? callerPersister,
}) {
  if (scopedPersister == null) {
    return callerPersister;
  }
  if (callerPersister == null) {
    return scopedPersister;
  }
  return (evidence) async {
    // A scoped experiment sink is authoritative and must commit first. An
    // optional caller sink may mirror the same private evidence afterwards.
    await scopedPersister(evidence);
    await callerPersister(evidence);
  };
}

Future<void> _recordAttemptEvidence({
  required StoryGenerationAttemptEvidenceRecorder? recorder,
  required StoryGenerationAttemptEvidencePersister? persister,
  required bool requireCompleteEvidence,
  required StoryGenerationAttemptEvidenceEnricher? enricher,
  required int attempt,
  required int maxTokens,
  required int transientRetryCount,
  required int outputRetryCount,
  required AppLlmChatResult result,
  required StoryGenerationRetryDisposition disposition,
}) async {
  if (recorder == null && persister == null) {
    return;
  }
  final evidence = StoryGenerationAttemptEvidence(
    attempt: attempt,
    maxTokens: maxTokens,
    transientRetryCount: transientRetryCount,
    outputRetryCount: outputRetryCount,
    succeeded: result.succeeded,
    failureKind: result.failureKind,
    statusCode: result.statusCode,
    providerModel: result.providerModel,
    providerResponseId: result.providerResponseId,
    promptTokens: result.promptTokens,
    completionTokens: result.completionTokens,
    totalTokens: result.totalTokens,
    responseDigest: await _digestProviderOutcome(result),
    disposition: disposition,
    dispatchFailureDisposition: result.dispatchFailureDisposition,
  );
  final enrichedEvidence = enricher?.call(evidence, result) ?? evidence;
  // Durability is part of attempt completion. Never retry or return before
  // the private attempt record is observable from persistent storage.
  await persister?.call(enrichedEvidence);
  recorder?.call(enrichedEvidence);
  if (requireCompleteEvidence && !enrichedEvidence.evidenceComplete) {
    throw StoryGenerationEvidenceIntegrityFailure(
      'no-redraw provider attempt evidence is incomplete after persistence',
    );
  }
  if (requireCompleteEvidence &&
      persister != null &&
      enrichedEvidence.succeeded &&
      enrichedEvidence.evaluationFingerprintRequired) {
    final logicalAttemptId = enrichedEvidence.logicalAttemptId;
    final stageId = enrichedEvidence.stageId;
    final callSiteId = enrichedEvidence.callSiteId;
    final providerOutcomeSealHash = enrichedEvidence.providerOutcomeSealHash;
    final providerArtifactDigest = enrichedEvidence.artifactDigest;
    final evaluatedArtifactDigest =
        enrichedEvidence.evaluationFingerprint?.artifactDigest;
    final promptReleaseContentHash = enrichedEvidence.promptReleaseContentHash;
    final parserRelease = enrichedEvidence.evaluationParserRelease;
    final evaluationPhase = enrichedEvidence.evaluationPhase;
    final evaluationFingerprintDigest =
        enrichedEvidence.evaluationFingerprint?.digest;
    if (logicalAttemptId == null ||
        stageId == null ||
        callSiteId == null ||
        providerOutcomeSealHash == null ||
        providerArtifactDigest == null ||
        evaluatedArtifactDigest == null ||
        promptReleaseContentHash == null ||
        parserRelease == null ||
        evaluationPhase == null ||
        evaluationFingerprintDigest == null) {
      throw StoryGenerationEvidenceIntegrityFailure(
        'persisted evaluation outcome cannot mint runtime provenance',
      );
    }
    _formalEvaluationOutcomeAdmissions[result] =
        _FormalEvaluationOutcomeAdmission(
          stageId: stageId,
          callSiteId: callSiteId,
          logicalAttemptId: logicalAttemptId,
          providerOutcomeSealHash: providerOutcomeSealHash,
          providerArtifactDigest: providerArtifactDigest,
          evaluatedArtifactDigest: evaluatedArtifactDigest,
          promptReleaseContentHash: promptReleaseContentHash,
          parserRelease: parserRelease,
          evaluationPhase: evaluationPhase,
          evaluationFingerprintDigest: evaluationFingerprintDigest,
        );
  }
}

Future<String?> _digestProviderOutcome(AppLlmChatResult result) async {
  final text = result.text;
  final detail = result.detail;
  final material = text ?? detail;
  if (material == null) {
    return null;
  }
  final hash = await const DartSha256().hash(utf8.encode(material));
  return 'sha256:${_hex(hash.bytes)}';
}

Object? _selectedEndpointFromRouteIdentity(Object? routeIdentity) {
  if (routeIdentity is! Map) return null;
  return routeIdentity['selectedEndpoint'];
}

AppLlmFormalDispatchWitness? _formalDispatchWitnessForSelectedEndpoint(
  AppLlmProviderBoundaryReceipt receipt,
  Object? selectedEndpoint, {
  required List<AppLlmChatMessage> messages,
  required int maxTokens,
  required String? dispatchEvidenceNonce,
}) {
  if (receipt.contract != 'app-llm-provider-boundary-receipt-v1' ||
      receipt.physicalDispatchCount != 1 ||
      selectedEndpoint is! Map) {
    return null;
  }
  final configuredBaseUrl = selectedEndpoint['baseUrl']?.toString();
  final configuredModel = selectedEndpoint['model']?.toString();
  final configuredProvider = selectedEndpoint['provider']?.toString();
  AppLlmProvider? provider;
  for (final candidate in AppLlmProvider.values) {
    if (candidate.name == configuredProvider) {
      provider = candidate;
      break;
    }
  }
  if (configuredBaseUrl == null ||
      configuredModel == null ||
      configuredProvider == null ||
      provider == null ||
      receipt.requestedBaseUrl != configuredBaseUrl ||
      receipt.requestedModel != configuredModel ||
      receipt.requestedProvider.name != configuredProvider) {
    return null;
  }
  final expectedTransportUri = resolveAppLlmTransportEndpoint(
    configuredBaseUrl,
    AppLlmProviderAdapters.of(receipt.requestedProvider).endpointPath,
  );
  final observedTransportUri = Uri.tryParse(
    receipt.transportEndpoint,
  )?.normalizePath();
  if (expectedTransportUri == null ||
      observedTransportUri == null ||
      !expectedTransportUri.isAbsolute ||
      !observedTransportUri.isAbsolute ||
      expectedTransportUri.scheme.toLowerCase() !=
          observedTransportUri.scheme.toLowerCase() ||
      expectedTransportUri.host.toLowerCase() !=
          observedTransportUri.host.toLowerCase() ||
      _effectivePort(expectedTransportUri) !=
          _effectivePort(observedTransportUri) ||
      expectedTransportUri.path != observedTransportUri.path ||
      expectedTransportUri.query != observedTransportUri.query ||
      expectedTransportUri.fragment != observedTransportUri.fragment ||
      expectedTransportUri.userInfo != observedTransportUri.userInfo) {
    return null;
  }
  return issueAppLlmFormalDispatchWitness(
    receipt: receipt,
    expectation: AppLlmProviderBoundaryExpectation(
      baseUrl: configuredBaseUrl,
      model: configuredModel,
      provider: provider,
      messages: messages,
      maxTokens: maxTokens,
      physicalDispatchPolicy: AppLlmPhysicalDispatchPolicy.single,
      dispatchEvidenceNonce: dispatchEvidenceNonce!,
    ),
  );
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return switch (uri.scheme.toLowerCase()) {
    'https' => 443,
    'http' => 80,
    _ => -1,
  };
}

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

({
  String stageId,
  String callSiteId,
  String variantId,
  String generationBundleHash,
})
_validateFormalPromptIdentity({
  required String stageId,
  required String callSiteId,
  required String variantId,
  required String generationBundleHash,
}) {
  String requiredValue(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'required');
    }
    return normalized;
  }

  final hash = requiredValue(generationBundleHash, 'generationBundleHash');
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(hash)) {
    throw ArgumentError.value(
      generationBundleHash,
      'generationBundleHash',
      'must be a sha256:<lower-hex> digest',
    );
  }
  return (
    stageId: requiredValue(stageId, 'stageId'),
    callSiteId: requiredValue(callSiteId, 'callSiteId'),
    variantId: requiredValue(variantId, 'variantId'),
    generationBundleHash: hash,
  );
}

String _inferStoryGenerationTraceName(List<AppLlmChatMessage> messages) {
  final taskPattern = RegExp(r'^(任务|任务类型)[:：]\s*(.+)$');
  for (final message in messages.reversed) {
    for (final rawLine in message.content.split('\n')) {
      final match = taskPattern.firstMatch(rawLine.trim());
      final value = match?.group(2)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  }
  return 'story_generation_pass';
}

int _normalizeTokenLimit(int value) {
  if (value <= AppLlmChatRequest.unlimitedMaxTokens) {
    return AppLlmChatRequest.unlimitedMaxTokens;
  }
  if (value < storyGenerationEditorialMaxTokens) {
    return storyGenerationEditorialMaxTokens;
  }
  return value > storyGenerationMaxEscalatedTokens
      ? storyGenerationMaxEscalatedTokens
      : value;
}

int _nextTokenLimit(int current, {required int ceiling}) {
  if (current <= AppLlmChatRequest.unlimitedMaxTokens) {
    return AppLlmChatRequest.unlimitedMaxTokens;
  }
  if (current < storyGenerationEditorialMaxTokens) {
    return storyGenerationEditorialMaxTokens.clamp(1, ceiling);
  }
  final doubled = current * 2;
  return doubled > ceiling ? ceiling : doubled;
}

bool _shouldRetryWithMoreTokens({
  required AppLlmChatResult result,
  required int maxTokens,
}) {
  if (maxTokens <= AppLlmChatRequest.unlimitedMaxTokens) {
    return false;
  }
  if (result.succeeded) {
    final text = result.text ?? '';
    return _looksEmptyOrTruncated(
      text: text,
      completionTokens: result.completionTokens,
      maxTokens: maxTokens,
    );
  }

  if (result.failureKind != AppLlmFailureKind.invalidResponse) {
    return false;
  }

  final detail = (result.detail ?? '').toLowerCase();
  return detail.contains('没有可用文本') ||
      detail.contains('empty') ||
      detail.contains('truncated') ||
      detail.contains('截断') ||
      detail.contains('max token') ||
      detail.contains('finish_reason') ||
      detail.contains('length');
}

bool _hasNoProviderCompletionProof(
  AppLlmChatResult result, {
  required StoryGenerationNoCompletionProof? provesNoProviderCompletion,
}) {
  // A v1 provider-boundary receipt establishes one physical dispatch but does
  // not yet carry a provider-specific, independently verifiable completion
  // ledger.  In particular, a generic 429/5xx and a local enum are not proof
  // that the provider created no completion.  Keep no-redraw samples
  // fail-closed until that stronger boundary contract exists; callbacks cannot
  // manufacture the missing proof.
  return false;
}

bool _looksEmptyOrTruncated({
  required String text,
  required int? completionTokens,
  required int maxTokens,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return true;
  }

  if (completionTokens != null && completionTokens >= (maxTokens * 0.95)) {
    return true;
  }

  if (trimmed.length <= 8 &&
      (trimmed == '...' || trimmed == '…' || trimmed == '……')) {
    return true;
  }

  return trimmed.endsWith('，') ||
      trimmed.endsWith('、') ||
      trimmed.endsWith('：') ||
      trimmed.endsWith(':');
}

bool isRetryableStoryGenerationTransportFailure(AppLlmChatResult result) {
  if (result.succeeded) {
    return false;
  }

  if (result.failureKind == AppLlmFailureKind.network ||
      result.failureKind == AppLlmFailureKind.timeout ||
      result.failureKind == AppLlmFailureKind.rateLimited) {
    return true;
  }

  if (result.failureKind != AppLlmFailureKind.server &&
      result.failureKind != AppLlmFailureKind.invalidResponse) {
    return false;
  }

  final detail = (result.detail ?? '').toLowerCase();
  return detail.contains('connection closed before full header was received') ||
      detail.contains('connection reset by peer') ||
      detail.contains('broken pipe') ||
      detail.contains('software caused connection abort') ||
      detail.contains('connection terminated') ||
      detail.contains('temporarily unavailable') ||
      detail.contains('server overloaded') ||
      detail.contains('overloaded') ||
      detail.contains('please try again') ||
      detail.contains('try again in') ||
      detail.contains('please retry shortly') ||
      detail.contains('too many requests') ||
      detail.contains('rate limit') ||
      detail.contains('rate-limit') ||
      detail.contains('resource exhausted') ||
      detail.contains('timed out');
}
