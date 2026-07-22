import 'dart:convert';
import 'dart:io';

import 'package:cryptography/dart.dart';
import 'package:novel_writer/app/llm/app_llm_call_site_inventory.dart';
import 'package:novel_writer/app/llm/app_llm_canonical_hash.dart';
import 'package:novel_writer/app/llm/app_llm_client_contract.dart';
import 'package:novel_writer/app/llm/app_llm_client_io.dart';
import 'package:novel_writer/app/llm/app_llm_client_types.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_invocation.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_release.dart';
import 'package:novel_writer/app/llm/app_llm_prompt_version.dart';
import 'package:novel_writer/app/state/local_settings_file.dart';
import 'package:novel_writer/domain/prompt_language.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_calibration_harness.dart';
import 'package:novel_writer/features/story_generation/data/literary_quality_policy.dart';
import 'package:novel_writer/features/story_generation/data/scene_literary_quality_evaluator.dart';
import 'package:novel_writer/features/story_generation/data/story_generation_pass_retry.dart';
import 'package:novel_writer/features/story_generation/data/story_prompt_registry.dart';
import 'package:novel_writer/features/story_generation/domain/contracts/settings_contract.dart';
import 'package:novel_writer/features/story_generation/domain/literary_quality_models.dart';

import '../test/test_support/literary_quality_test_data.dart';

Future<void> main(List<String> args) async {
  final settingsFile = File(args.isEmpty ? 'setting.json' : args.first);
  final settings = await loadLocalSettingsObjectFile(file: settingsFile);
  final profile = _ProviderProfile.resolve(settings);
  if (!profile.isUsable) {
    stderr.writeln(
      'No usable provider profile in ${settingsFile.path}; real smoke aborted.',
    );
    exitCode = 64;
    return;
  }

  final evidenceDirectory = Directory(
    args.length >= 2 ? args[1] : _defaultEvidenceDirectory(),
  );
  if (await evidenceDirectory.exists()) {
    stderr.writeln(
      'Evidence directory already exists: ${evidenceDirectory.path}',
    );
    exitCode = 73;
    return;
  }
  await evidenceDirectory.create(recursive: true);

  final capture = _CapturingSettingsContract(
    client: createAppLlmClient(),
    profile: profile,
  );
  String? generatedProse;
  try {
    final generationInvocation = StoryPromptRegistry.production.invocation(
      stageId: 'editorial',
      callSiteId: 'scene-editor',
    );
    final generationVariables = <String, Object?>{
      'sceneTitle': '雨夜柜机',
      'targetLength': 650,
      'sceneSummary':
          '纯合成原创测试场景。柳溪必须在零点前从蓝色柜机取出港务底册；'
          '开锁会触发警报并暴露位置；沈渡提出替她引走追兵，但真实雇主仍未知。'
          '不要模仿任何具体作者、作品或已知角色。',
      'acceptedBeats':
          '1. 柳溪听见追兵接近并确认柜机警报仍在线。\n'
          '2. 她权衡暴露位置的代价后主动开锁。\n'
          '3. 警报触发，沈渡以实际行动引开第一拨追兵。\n'
          '4. 柳溪取到底册，但发现沈渡留下的撤离路线另有条件。\n'
          '5. 场景以底册离开柜机、两人关系转为条件性信任收束。',
      'allowedNarrationContext':
          '第三人称限知，只写柳溪可见、可听、可推断的信息；'
          '用具体动作承担情绪；节奏可在追兵逼近时短暂压缩，危险过去后恢复。',
    };
    final generationMessages = generationInvocation
        .render(generationVariables)
        .messages;
    final generationEvidence = generationInvocation.evidence(
      generationMessages,
      resolvedVariables: generationVariables,
    );
    await _writePrettyJson(
      File('${evidenceDirectory.path}/generation-request.json'),
      {
        'artifactVersion': 'literary-quality-real-generation-request-v1',
        'promptReleaseHash': generationInvocation.release.contentHash,
        'generationBundleHash': generationInvocation.generationBundleHash,
        'resolvedVariables': generationVariables,
        'messages': [
          for (final message in generationMessages) message.toJson(),
        ],
        'promptEvidence': generationEvidence.toTraceMetadata(),
      },
    );
    final generationResult = await requestFormalStoryGenerationPassWithRetry(
      settingsStore: capture,
      messages: generationMessages,
      maxOutputRetries: 0,
      traceName: 'literary_quality_wp2_real_generation',
      traceMetadata: const {
        'realSmoke': true,
        'syntheticOnly': true,
        'namedImitation': false,
      },
      promptInvocation: generationInvocation,
      promptInvocationEvidence: generationEvidence,
    );
    if (!generationResult.succeeded) {
      throw StateError(
        'real generation failed: ${generationResult.failureKind} '
        '${generationResult.detail ?? ''}',
      );
    }
    _rejectSecretBearingProviderOutput(capture.calls, profile.apiKey);
    final prose = generationResult.text!.trim();
    generatedProse = prose;
    if (prose.length < 250) {
      throw StateError(
        'real generation returned only ${prose.length} UTF-16 code units',
      );
    }
    final observedGenerationModel = generationResult.providerModel?.trim();
    if (observedGenerationModel == null || observedGenerationModel.isEmpty) {
      throw StateError(
        'real generation did not expose the actual provider model release',
      );
    }
    final generationResponseId = generationResult.providerResponseId?.trim();
    if (generationResponseId == null || generationResponseId.isEmpty) {
      throw StateError(
        'real generation did not expose the provider response id',
      );
    }

    final literaryRegistry = StoryPromptRegistry.literaryEvaluation();
    final literaryInvocation = literaryRegistry.invocation(
      stageId: 'literary-quality',
      callSiteId: 'scene-evaluator',
    );
    final corpus = LiteraryQualityDevelopmentCorpus.loadSync(
      Directory('test/fixtures/story_quality/dev_v1'),
    );
    final developmentArtifact =
        LiteraryQualityDevelopmentCalibrationArtifact.loadSync(
          File(
            'test/fixtures/story_quality/dev_v1/'
            'calibration-development.json',
          ),
          corpus,
        );
    final authority = buildLiteraryQualityTestAuthority();
    final evaluatorModelRelease = observedGenerationModel;
    final certification = EvaluatorPolicyCertification(
      certificationId: 'wp2-real-smoke-development',
      rubricVersion: corpus.rubricVersion,
      promptReleaseHash: literaryInvocation.release.contentHash,
      evaluatorModelRelease: evaluatorModelRelease,
      thresholdPolicyVersion: LiteraryQualityPolicy.thresholdPolicyVersion,
      status: EvaluatorPolicyCertificationStatus.development,
      calibrationArtifactHash: developmentArtifact.artifactHash,
      blindReviewArtifactHash: AppLlmCanonicalHash.domainHash(
        'literary-blind-review-pending-v1',
        corpus.corpusHash,
      ),
      certifiedAtMs: 0,
    );
    final evaluationInput = SceneLiteraryQualityEvaluationInput(
      prose: prose,
      contractChain: authority.contractChain,
      voiceProfile: authority.voiceProfile,
      sceneCraftContract: authority.sceneCraftContract,
      ledgerSnapshotHash: 'ledger-snapshot-1',
      deterministicGate: DeterministicGateRef(
        evidenceHash: AppLlmCanonicalHash.domainHash(
          'literary-real-smoke-deterministic-evidence-v1',
          {
            'proseHash': AppLlmCanonicalHash.domainHash(
              'smoke-prose-v1',
              prose,
            ),
          },
        ),
        passed: true,
      ),
      rubricVersion: corpus.rubricVersion,
      calibration: SceneLiteraryQualityCalibration(
        certification: certification,
        historicalOverallLowerBound: 0.50,
        findingClassLowerBounds: const {
          QualityFindingClass.hardError: 0.50,
          QualityFindingClass.craftWeakness: 0.50,
          QualityFindingClass.styleChoice: 0.50,
          QualityFindingClass.effectiveDeviation: 0.50,
        },
        repeatAgreementConfidence: 0.50,
      ),
      createdAtMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    final evaluationVariables = <String, Object?>{
      'evaluationInputJson': AppLlmCanonicalHash.canonicalJson(
        evaluationInput.promptInputJson,
      ),
    };
    final evaluationMessages = literaryInvocation
        .render(evaluationVariables)
        .messages;
    final evaluationEvidence = literaryInvocation.evidence(
      evaluationMessages,
      resolvedVariables: evaluationVariables,
    );
    await _writePrettyJson(
      File('${evidenceDirectory.path}/evaluation-request.json'),
      {
        'artifactVersion': 'literary-quality-real-evaluation-request-v1',
        'promptReleaseHash': literaryInvocation.release.contentHash,
        'generationBundleHash': literaryInvocation.generationBundleHash,
        'promptInput': evaluationInput.promptInputJson,
        'messages': [
          for (final message in evaluationMessages) message.toJson(),
        ],
        'promptEvidence': evaluationEvidence.toTraceMetadata(),
        'trustedAuthority': {
          'contractChain': authority.contractChain.toJson(),
          'voiceProfile': authority.voiceProfile.toJson(),
          'sceneCraftContract': authority.sceneCraftContract.toJson(),
          'ledgerSnapshotHash': evaluationInput.ledgerSnapshotHash,
          'deterministicGate': evaluationInput.deterministicGate.toJson(),
          'rubricVersion': evaluationInput.rubricVersion,
          'calibration': {
            'certification': certification.toJson(),
            'historicalOverallLowerBound':
                evaluationInput.calibration.historicalOverallLowerBound,
            'findingClassLowerBounds': {
              for (final entry
                  in evaluationInput
                      .calibration
                      .findingClassLowerBounds
                      .entries)
                entry.key.wire: entry.value,
            },
            'repeatAgreementConfidence':
                evaluationInput.calibration.repeatAgreementConfidence,
          },
          'createdAtMs': evaluationInput.createdAtMs,
        },
      },
    );
    final evaluator = SceneLiteraryQualityEvaluator(
      settingsStore: capture,
      promptRegistry: literaryRegistry,
    );
    final layeredResult = await evaluator.evaluate(evaluationInput);
    final evaluatorCapture = capture.calls.lastWhere(
      (call) => call.traceName == 'scene_literary_quality_evaluation',
    );
    final evaluatorResult = evaluatorCapture.result;
    if (evaluatorResult == null || !evaluatorResult.succeeded) {
      throw StateError('evaluator attempt completed without a usable result');
    }
    final evaluatorResponseId = evaluatorResult.providerResponseId?.trim();
    if (evaluatorResponseId == null || evaluatorResponseId.isEmpty) {
      throw StateError(
        'real evaluator did not expose the provider response id',
      );
    }
    if (evaluatorCapture.promptInvocationEvidence?.renderedMessagesDigest !=
        evaluationEvidence.renderedMessagesDigest) {
      throw StateError('captured evaluator request differs from replay');
    }
    _rejectSecretBearingProviderOutput(capture.calls, profile.apiKey);
    await _writeAttemptEvidence(
      evidenceDirectory: evidenceDirectory,
      calls: capture.calls,
      apiKey: profile.apiKey,
    );
    await File(
      '${evidenceDirectory.path}/generated-prose.txt',
    ).writeAsString('$prose\n');
    await _writePrettyJson(
      File('${evidenceDirectory.path}/layered-result.json'),
      layeredResult.toJson(),
    );
    await File(
      '${evidenceDirectory.path}/raw-evaluator-output.json',
    ).writeAsString('${evaluatorResult.text!.trim()}\n');
    await _writePrettyJson(File('${evidenceDirectory.path}/metadata.json'), {
      'artifactVersion': 'literary-quality-wp2-real-smoke-v2',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'syntheticOnly': true,
      'namedImitation': false,
      'providerHost': Uri.parse(profile.baseUrl).host,
      'requestedModel': profile.model,
      'generationProviderModel': generationResult.providerModel,
      'evaluatorProviderModel': evaluatorResult.providerModel,
      'generationProviderResponseId': generationResponseId,
      'evaluatorProviderResponseId': evaluatorResponseId,
      'generationPromptReleaseHash': generationInvocation.release.contentHash,
      'generationBundleHash': generationInvocation.generationBundleHash,
      'generationRequestHash': generationEvidence.renderedMessagesDigest,
      'generationResponseHash': AppLlmCanonicalHash.domainHash(
        'literary-real-smoke-generation-response-v1',
        prose,
      ),
      'evaluatorPromptReleaseHash': literaryInvocation.release.contentHash,
      'evaluatorBundleHash': literaryInvocation.generationBundleHash,
      'evaluatorRequestHash':
          evaluatorCapture.promptInvocationEvidence?.renderedMessagesDigest,
      'evaluatorResponseHash': AppLlmCanonicalHash.domainHash(
        'literary-real-smoke-evaluator-response-v1',
        evaluatorResult.text,
      ),
      'developmentCorpusHash': corpus.corpusHash,
      'developmentCalibrationArtifactHash': developmentArtifact.artifactHash,
      'calibratedConfidence': layeredResult.calibratedConfidence,
      'evaluatorSelfConfidence': layeredResult.evaluatorSelfConfidence,
      'candidateStatus': layeredResult.decision.status.wire,
      'candidateReason': layeredResult.decision.reasonCode,
      'generationUsage': _usageJson(generationResult),
      'evaluatorUsage': _usageJson(evaluatorResult),
      'manualReview': 'pending',
      'limitations': const [
        'Development confidence is conservatively fixed at 0.50 because the 300-fixture real evaluator run and formal 600 human adjudications have not been completed.',
        'This smoke does not enable or replace the legacy 95/90 gate.',
      ],
    });
    await _writeEvidenceManifest(evidenceDirectory);

    stdout.writeln('Real generation + literary evaluator smoke passed.');
    stdout.writeln('Evidence: ${evidenceDirectory.path}');
    stdout.writeln('Generated prose code units: ${prose.length}');
    stdout.writeln('Model: ${evaluatorResult.providerModel}');
    stdout.writeln(
      'Craft: ${layeredResult.craft.craftOverall.toStringAsFixed(2)} / '
      'critical ${layeredResult.craft.criticalCraftMinimum.toStringAsFixed(2)}',
    );
    stdout.writeln(
      'Findings: ${layeredResult.findings.length}; '
      'status=${layeredResult.decision.status.wire}',
    );
  } catch (error) {
    await _writeFailureEvidence(
      evidenceDirectory: evidenceDirectory,
      generatedProse: generatedProse,
      calls: capture.calls,
      error: error,
      apiKey: profile.apiKey,
    );
    stderr.writeln(
      'Real smoke failed; see redacted evidence at ${evidenceDirectory.path}.',
    );
    exitCode = 1;
  }
}

Map<String, Object?> _usageJson(AppLlmChatResult result) => {
  'latencyMs': result.latencyMs,
  'promptTokens': result.promptTokens,
  'completionTokens': result.completionTokens,
  'totalTokens': result.totalTokens,
};

String _defaultEvidenceDirectory() {
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  return '.omx/evidence/literary-quality-wp2-real-smoke-$stamp';
}

Future<void> _writePrettyJson(File file, Map<String, Object?> value) => file
    .writeAsString('${const JsonEncoder.withIndent('  ').convert(value)}\n');

Future<void> _writeFailureEvidence({
  required Directory evidenceDirectory,
  required String? generatedProse,
  required List<_CapturedCall> calls,
  required Object error,
  required String apiKey,
}) async {
  final generatedProseContainsSecret =
      generatedProse != null && _containsExactSecret(generatedProse, apiKey);
  if (generatedProse != null && !generatedProseContainsSecret) {
    await File(
      '${evidenceDirectory.path}/generated-prose.txt',
    ).writeAsString('$generatedProse\n');
  }
  final suppressedAttemptFields = await _writeAttemptEvidence(
    evidenceDirectory: evidenceDirectory,
    calls: calls,
    apiKey: apiKey,
  );
  await _writePrettyJson(File('${evidenceDirectory.path}/failure.json'), {
    'artifactVersion': 'literary-quality-wp2-real-smoke-failure-v1',
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'errorType': error.runtimeType.toString(),
    'errorHash': AppLlmCanonicalHash.domainHash(
      'literary-real-smoke-error-v1',
      error.toString(),
    ),
    'attemptCount': calls.length,
    'secretBearingFieldsSuppressed':
        suppressedAttemptFields + (generatedProseContainsSecret ? 1 : 0),
    'containsSecrets': false,
  });
  await _writeEvidenceManifest(evidenceDirectory);
}

Future<int> _writeAttemptEvidence({
  required Directory evidenceDirectory,
  required List<_CapturedCall> calls,
  required String apiKey,
}) async {
  var suppressed = 0;
  final attempts = <Map<String, Object?>>[];
  for (var index = 0; index < calls.length; index += 1) {
    final text = calls[index].result?.text?.trim();
    final providerModel = calls[index].result?.providerModel;
    final providerResponseId = calls[index].result?.providerResponseId;
    final providerDetail = calls[index].result?.detail;
    final textContainsSecret =
        text != null && _containsExactSecret(text, apiKey);
    final providerModelContainsSecret =
        providerModel != null && _containsExactSecret(providerModel, apiKey);
    final providerResponseIdContainsSecret =
        providerResponseId != null &&
        _containsExactSecret(providerResponseId, apiKey);
    final providerDetailContainsSecret =
        providerDetail != null && _containsExactSecret(providerDetail, apiKey);
    final storesRawOutput =
        text != null && text.isNotEmpty && !textContainsSecret;
    if (textContainsSecret) suppressed += 1;
    if (providerModelContainsSecret) suppressed += 1;
    if (providerResponseIdContainsSecret) suppressed += 1;
    if (providerDetailContainsSecret) suppressed += 1;
    if (storesRawOutput) {
      await File(
        '${evidenceDirectory.path}/attempt-${index + 1}-output.txt',
      ).writeAsString('$text\n');
    }
    attempts.add(
      calls[index].toEvidenceJson(
        rawOutputStored: storesRawOutput,
        providerModelStored: !providerModelContainsSecret,
        providerResponseIdStored: !providerResponseIdContainsSecret,
        providerDetailStored: !providerDetailContainsSecret,
      ),
    );
  }
  await _writePrettyJson(File('${evidenceDirectory.path}/attempts.json'), {
    'artifactVersion': 'literary-quality-wp2-real-smoke-attempts-v2',
    'hashAlgorithms': const {
      'responseHash':
          'AppLlmCanonicalHash.domainHash:'
          'literary-real-smoke-attempt-response-v1',
      'providerModelHash':
          'AppLlmCanonicalHash.domainHash:'
          'literary-real-smoke-provider-model-v1',
      'providerResponseIdHash':
          'AppLlmCanonicalHash.domainHash:'
          'literary-real-smoke-provider-response-id-v1',
      'detailHash':
          'AppLlmCanonicalHash.domainHash:'
          'literary-real-smoke-provider-detail-v1',
      'manifestFileHash': 'raw file bytes SHA-256',
    },
    'attempts': attempts,
    'secretBearingFieldsSuppressed': suppressed,
    'containsSecrets': false,
  });
  return suppressed;
}

void _rejectSecretBearingProviderOutput(
  Iterable<_CapturedCall> calls,
  String apiKey,
) {
  for (final call in calls) {
    final text = call.result?.text;
    if (text != null && _containsExactSecret(text, apiKey)) {
      throw StateError(
        'provider output matched the configured secret; raw output suppressed',
      );
    }
    final providerModel = call.result?.providerModel;
    if (providerModel != null && _containsExactSecret(providerModel, apiKey)) {
      throw StateError(
        'provider model matched the configured secret; raw field suppressed',
      );
    }
    final providerResponseId = call.result?.providerResponseId;
    if (providerResponseId != null &&
        _containsExactSecret(providerResponseId, apiKey)) {
      throw StateError(
        'provider response id matched the configured secret; raw field '
        'suppressed',
      );
    }
    final providerDetail = call.result?.detail;
    if (providerDetail != null &&
        _containsExactSecret(providerDetail, apiKey)) {
      throw StateError(
        'provider detail matched the configured secret; raw field suppressed',
      );
    }
  }
}

bool _containsExactSecret(String value, String apiKey) {
  final secret = apiKey.trim();
  return secret.isNotEmpty && value.contains(secret);
}

Future<void> _writeEvidenceManifest(Directory evidenceDirectory) async {
  final files = await evidenceDirectory
      .list()
      .where((entity) => entity is File)
      .cast<File>()
      .where((file) => !file.path.endsWith('/manifest.json'))
      .toList();
  files.sort((left, right) => left.path.compareTo(right.path));
  final manifest = <String, Object?>{
    'artifactVersion': 'literary-quality-wp2-real-smoke-manifest-v1',
    'files': [
      for (final file in files)
        {
          'name': file.uri.pathSegments.last,
          'bytes': await file.length(),
          'sha256': _rawFileSha256(file),
        },
    ],
  };
  final target = File('${evidenceDirectory.path}/manifest.json');
  final temporary = File('${target.path}.tmp');
  await _writePrettyJson(temporary, manifest);
  await temporary.rename(target.path);
}

String _rawFileSha256(File file) {
  final digest = const DartSha256().hashSync(file.readAsBytesSync());
  final hex = digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'sha256:$hex';
}

final class _ProviderProfile {
  const _ProviderProfile({
    required this.providerName,
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  factory _ProviderProfile.resolve(Map<String, Object?> settings) {
    final direct = _ProviderProfile(
      providerName: _readString(settings, 'providerName'),
      baseUrl: _readString(settings, 'baseUrl'),
      model: _normalizeRequestedModel(_readString(settings, 'model')),
      apiKey: _readString(settings, 'apiKey'),
    );
    if (direct.isUsable) return direct;
    final profiles = settings['providerProfiles'];
    if (profiles is List) {
      for (final value in profiles) {
        if (value is! Map) continue;
        final json = value.map(
          (key, item) => MapEntry(key.toString(), item as Object?),
        );
        final profile = _ProviderProfile(
          providerName: _readString(json, 'providerName'),
          baseUrl: _readString(json, 'baseUrl'),
          model: _normalizeRequestedModel(_readString(json, 'model')),
          apiKey: _readString(json, 'apiKey'),
        );
        if (profile.isUsable) return profile;
      }
    }
    return direct;
  }

  final String providerName;
  final String baseUrl;
  final String model;
  final String apiKey;

  bool get isUsable =>
      providerName.isNotEmpty &&
      _isRemoteHttpsEndpoint(baseUrl) &&
      model.isNotEmpty &&
      apiKey.isNotEmpty &&
      !_containsExactSecret(providerName, apiKey) &&
      !_containsExactSecret(baseUrl, apiKey) &&
      !_containsExactSecret(model, apiKey);
}

String _readString(Map<String, Object?> json, String key) =>
    json[key]?.toString().trim() ?? '';

bool _isRemoteHttpsEndpoint(String baseUrl) {
  final uri = Uri.tryParse(baseUrl.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return host != 'localhost' && host != '127.0.0.1' && host != '::1';
}

String _normalizeRequestedModel(String model) {
  final trimmed = model.trim();
  return switch (trimmed.toLowerCase()) {
    'kimi-2.6' => 'kimi-k2.6',
    'mimo-v25-pro' => 'mimo-v2.5-pro',
    'mimo-v25' => 'mimo-v2.5',
    _ => trimmed,
  };
}

AppLlmProvider _providerForProfile(_ProviderProfile profile) {
  final configured = profile.providerName.toAppLlmProvider();
  if (configured != AppLlmProvider.openaiCompatible) return configured;
  final host = Uri.parse(profile.baseUrl).host.toLowerCase();
  if (host.contains('xiaomimimo.com')) return AppLlmProvider.mimo;
  if (host.contains('bigmodel.cn') || host.contains('zhipuai.cn')) {
    return AppLlmProvider.zhipu;
  }
  return configured;
}

final class _CapturedCall {
  _CapturedCall({
    required this.traceName,
    required Map<String, Object?> traceMetadata,
    required this.promptInvocationEvidence,
    required this.maxTokens,
    required this.stageId,
    required this.callSiteId,
    required this.variantId,
    required this.generationBundleHash,
  }) : traceMetadata = Map<String, Object?>.unmodifiable(traceMetadata);

  final String? traceName;
  final Map<String, Object?> traceMetadata;
  final PromptInvocationEvidence? promptInvocationEvidence;
  final int maxTokens;
  final String? stageId;
  final String? callSiteId;
  final String? variantId;
  final String? generationBundleHash;
  AppLlmChatResult? result;
  String? thrownErrorType;
  String? thrownErrorHash;

  Map<String, Object?> toEvidenceJson({
    required bool rawOutputStored,
    required bool providerModelStored,
    required bool providerResponseIdStored,
    required bool providerDetailStored,
  }) => {
    'traceName': traceName,
    'traceMetadata': traceMetadata,
    'maxTokens': maxTokens,
    'stageId': stageId,
    'callSiteId': callSiteId,
    'variantId': variantId,
    'generationBundleHash': generationBundleHash,
    'succeeded': result?.succeeded ?? false,
    'providerModel': providerModelStored ? result?.providerModel : null,
    'providerModelHash': result?.providerModel == null
        ? null
        : AppLlmCanonicalHash.domainHash(
            'literary-real-smoke-provider-model-v1',
            result!.providerModel,
          ),
    'providerResponseId': providerResponseIdStored
        ? result?.providerResponseId
        : null,
    'providerResponseIdHash': result?.providerResponseId == null
        ? null
        : AppLlmCanonicalHash.domainHash(
            'literary-real-smoke-provider-response-id-v1',
            result!.providerResponseId,
          ),
    'failureKind': result?.failureKind?.name,
    'statusCode': result?.statusCode,
    'thrownErrorType': thrownErrorType,
    'thrownErrorHash': thrownErrorHash,
    'providerDetail': providerDetailStored ? result?.detail : null,
    'detailHash': result?.detail == null
        ? null
        : AppLlmCanonicalHash.domainHash(
            'literary-real-smoke-provider-detail-v1',
            result!.detail,
          ),
    'responseHash': result?.text == null
        ? null
        : AppLlmCanonicalHash.domainHash(
            'literary-real-smoke-attempt-response-v1',
            result!.text,
          ),
    'rawOutputStored': rawOutputStored,
    'promptReleaseHash': promptInvocationEvidence?.release.contentHash,
    'requestHash': promptInvocationEvidence?.renderedMessagesDigest,
    'usage': result == null ? null : _usageJson(result!),
  };
}

final class _CapturingSettingsContract
    implements StoryGenerationSettingsContract {
  _CapturingSettingsContract({required this.client, required this.profile});

  final AppLlmClient client;
  final _ProviderProfile profile;
  final List<_CapturedCall> calls = [];

  @override
  PromptLanguage get promptLanguage => PromptLanguage.zh;

  @override
  Future<AppLlmChatResult> requestAiCompletion({
    required List<AppLlmChatMessage> messages,
    int? maxTokens,
    String? traceName,
    Map<String, Object?> traceMetadata = const {},
    PromptReleaseRef? promptReleaseRef,
    PromptInvocationEvidence? promptInvocationEvidence,
    PromptVersion? promptVersion,
    String? stageId,
    String? callSiteId,
    String? variantId,
    String? generationBundleHash,
  }) async {
    final authority = AppLlmCallSiteAuthority.registeredPrompt(
      promptReleaseRef: promptReleaseRef,
      promptInvocationEvidence: promptInvocationEvidence,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      generationBundleHash: generationBundleHash,
    );
    if (authority is! AppLlmRegisteredPromptAuthority) {
      throw StateError('real smoke requires registered prompt authority');
    }
    authority.validateMessages(messages);
    final effectiveMaxTokens = maxTokens ?? AppLlmChatRequest.defaultMaxTokens;
    final capturedCall = _CapturedCall(
      traceName: traceName,
      traceMetadata: traceMetadata,
      promptInvocationEvidence: promptInvocationEvidence,
      maxTokens: effectiveMaxTokens,
      stageId: stageId,
      callSiteId: callSiteId,
      variantId: variantId,
      generationBundleHash: generationBundleHash,
    );
    calls.add(capturedCall);
    try {
      final result = await client.chat(
        AppLlmChatRequest(
          baseUrl: profile.baseUrl,
          apiKey: profile.apiKey,
          model: profile.model,
          timeout: const AppLlmTimeoutConfig(
            connectTimeoutMs: 10000,
            sendTimeoutMs: 30000,
            receiveTimeoutMs: 180000,
            idleTimeoutMs: 60000,
          ),
          maxTokens: effectiveMaxTokens,
          messages: messages,
          provider: _providerForProfile(profile),
          preferStreaming: true,
          formalCacheIdentity:
              stageId != null &&
                  generationBundleHash != null &&
                  promptInvocationEvidence != null
              ? AppLlmFormalCacheRequestIdentity(
                  stageId: stageId,
                  generationBundleHash: generationBundleHash,
                  parserRelease: promptInvocationEvidence.release.parserRelease,
                )
              : null,
        ),
      );
      capturedCall.result = result;
      return result;
    } catch (error) {
      capturedCall.thrownErrorType = error.runtimeType.toString();
      capturedCall.thrownErrorHash = AppLlmCanonicalHash.domainHash(
        'literary-real-smoke-dispatch-error-v1',
        error.toString(),
      );
      rethrow;
    }
  }
}
