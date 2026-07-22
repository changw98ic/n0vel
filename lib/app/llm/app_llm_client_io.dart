import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../state/ai_request_service.dart';
import '../../features/story_generation/data/pipeline_event_log.dart';
import 'app_llm_canonical_hash.dart';
import 'app_llm_client_contract.dart';
import 'app_llm_client_types.dart';
import 'app_llm_provider_adapters.dart';
import 'app_llm_provider_outcome_seal.dart';
import 'app_llm_response_decoding.dart';

AppLlmClient createAppLlmClient() => _IoAppLlmClient();

bool supportsPlatformFormalDispatch() => true;

@pragma('vm:isolate-unsendable')
final class _IoFormalDispatchPermit {
  _IoFormalDispatchPermit(AppLlmChatRequest request)
    : nonce = request.dispatchEvidenceNonce!,
      requestBindingDigest = _formalTransportPermitBindingDigest(request);

  final String nonce;
  final String requestBindingDigest;
  bool consumed = false;
}

@pragma('vm:isolate-unsendable')
final class _IoFormalDispatchEpoch {
  _IoFormalDispatchEpoch(this.permit);

  final _IoFormalDispatchPermit permit;
  bool physicalDispatchClaimed = false;
  bool closed = false;
}

_IoFormalDispatchEpoch? _activeFormalDispatchEpoch;

@pragma('vm:isolate-unsendable')
final class _IoPlatformFormalDispatchAdmission {
  _IoPlatformFormalDispatchAdmission({
    required AppLlmChatRequest request,
    required _IoFormalDispatchEpoch epoch,
  }) : _request = request,
       _epoch = epoch;

  final AppLlmChatRequest _request;
  final _IoFormalDispatchEpoch _epoch;
  bool _dispatchClaimed = false;

  Future<AppLlmChatResult> dispatch() {
    if (_dispatchClaimed || _epoch.closed) {
      return Future<AppLlmChatResult>.value(
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'formal platform dispatch admission is closed or consumed',
        ),
      );
    }
    // Burn synchronously before entering async transport code. The admitted
    // request remains inside this private unsendable holder and is never
    // handed to the application-injected AppLlmClient graph.
    _dispatchClaimed = true;
    // llm-call-site: boundary.provider.io-formal-admission
    return _IoAppLlmClient().chat(_request);
  }

  void close() => _closeFormalDispatchEpoch(_epoch);
}

Object attachPlatformFormalDispatchPermit({
  required AppLlmChatRequest request,
  required Object committedIntentAuthority,
  required Map<String, Object?> formalDispatchIntent,
  required Object formalDispatchRouteIdentity,
  required Object centralDispatchAuthority,
}) {
  validateAppLlmSinglePhysicalDispatchRequest(request);
  if (centralDispatchAuthority is! AppLlmCentralFormalDispatchAuthority) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'invalid-central-dispatch-authority',
      'formal dispatch requires central registered-prompt and settings-route admission',
    );
  }
  // The central key is consumed first. A genuine key presented with any
  // modified request, intent, or route is burned before journal admission.
  if (!centralDispatchAuthority.consumeFor(
    request: request,
    formalDispatchIntent: formalDispatchIntent,
    formalDispatchRouteIdentity: formalDispatchRouteIdentity,
  )) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'central-dispatch-authority-mismatch',
      'central dispatch authority is reused or does not bind this exact request',
    );
  }
  if (committedIntentAuthority is! PipelineCommittedIntentAuthority) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'invalid-committed-intent-authority',
      'formal dispatch requires authority issued by the durable evidence journal',
    );
  }
  // Consumption precedes all later checks. A genuine authority presented with
  // a modified request is burned and can never be replayed with a second one.
  if (!committedIntentAuthority.consumeForFormalDispatch(
    formalDispatchIntent,
  )) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'committed-intent-authority-mismatch',
      'formal dispatch authority is reused or does not bind this complete intent',
    );
  }
  if (!_formalIntentMatchesFrozenRequest(
    request: request,
    formalDispatchIntent: formalDispatchIntent,
    formalDispatchRouteIdentity: formalDispatchRouteIdentity,
  )) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'committed-intent-request-mismatch',
      'the frozen provider request differs from its committed write-ahead intent',
    );
  }
  if (_activeFormalDispatchEpoch != null) {
    throw const AppLlmPhysicalDispatchPreflightException(
      'formal-dispatch-epoch-active',
      'another formal client graph is still inside the IO admission epoch',
    );
  }
  final permit = _IoFormalDispatchPermit(request);
  final epoch = _IoFormalDispatchEpoch(permit);
  _activeFormalDispatchEpoch = epoch;
  return _IoPlatformFormalDispatchAdmission(
    request: request.withFormalDispatchPermit(permit),
    epoch: epoch,
  );
}

Future<AppLlmChatResult> dispatchPlatformFormalAdmission(Object admission) =>
    admission is _IoPlatformFormalDispatchAdmission
    ? admission.dispatch()
    : Future<AppLlmChatResult>.value(
        const AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.network,
          detail: 'invalid private platform formal dispatch admission',
        ),
      );

void closePlatformFormalAdmission(Object admission) {
  if (admission is _IoPlatformFormalDispatchAdmission) admission.close();
}

void _closeFormalDispatchEpoch(_IoFormalDispatchEpoch epoch) {
  if (epoch.closed) return;
  epoch.closed = true;
  if (identical(_activeFormalDispatchEpoch, epoch)) {
    _activeFormalDispatchEpoch = null;
  }
}

bool _formalIntentMatchesFrozenRequest({
  required AppLlmChatRequest request,
  required Map<String, Object?> formalDispatchIntent,
  required Object formalDispatchRouteIdentity,
}) {
  if (formalDispatchRouteIdentity is! Map) return false;
  final routeIdentity = Map<String, Object?>.from(formalDispatchRouteIdentity);
  if (formalDispatchIntent['logicalAttemptId'] !=
          request.dispatchEvidenceNonce ||
      formalDispatchIntent['physicalDispatchPolicy'] !=
          AppLlmPhysicalDispatchPolicy.single.name ||
      formalDispatchIntent['maxTokens'] is! int ||
      AppLlmChatRequest.normalizeMaxTokens(
            formalDispatchIntent['maxTokens']! as int,
          ) !=
          request.effectiveMaxTokens ||
      formalDispatchIntent['selectedRouteBindingHash'] !=
          AppLlmCanonicalHash.domainHash(
            'story-generation-configured-model-route-v1',
            routeIdentity,
          ) ||
      formalDispatchIntent['renderedMessagesDigest'] !=
          AppLlmCanonicalHash.domainHash('rendered-messages-v1', <Object?>[
            for (final message in request.messages) message.toJson(),
          ])) {
    return false;
  }
  final cacheIdentity = request.formalCacheIdentity;
  final dispatchIdentity = request.formalDispatchIdentity;
  final intentPromptReleaseRef = formalDispatchIntent['promptReleaseRef'];
  if (cacheIdentity == null ||
      dispatchIdentity == null ||
      intentPromptReleaseRef is! Map ||
      dispatchIdentity.completeIntentDigest !=
          AppLlmCanonicalHash.domainHash(
            'story-generation-attempt-intent-record-v1',
            formalDispatchIntent,
          ) ||
      formalDispatchIntent['stageId'] != cacheIdentity.stageId ||
      formalDispatchIntent['generationBundleHash'] !=
          cacheIdentity.generationBundleHash ||
      formalDispatchIntent['stageId'] != dispatchIdentity.stageId ||
      formalDispatchIntent['callSiteId'] != dispatchIdentity.callSiteId ||
      formalDispatchIntent['variantId'] != dispatchIdentity.variantId ||
      formalDispatchIntent['generationBundleHash'] !=
          dispatchIdentity.generationBundleHash ||
      formalDispatchIntent['promptReleaseContentHash'] !=
          dispatchIdentity.promptReleaseContentHash ||
      formalDispatchIntent['renderedMessagesDigest'] !=
          dispatchIdentity.renderedMessagesDigest ||
      formalDispatchIntent['resolvedVariablesDigest'] !=
          dispatchIdentity.resolvedVariablesDigest ||
      formalDispatchIntent['rendererContractHash'] !=
          dispatchIdentity.rendererContractHash ||
      dispatchIdentity.promptReleaseRefDigest !=
          AppLlmCanonicalHash.domainHash(
            'formal-dispatch-prompt-release-ref-v1',
            intentPromptReleaseRef,
          ) ||
      intentPromptReleaseRef['contentHash'] !=
          dispatchIdentity.promptReleaseContentHash ||
      dispatchIdentity.parserRelease != cacheIdentity.parserRelease) {
    return false;
  }
  final selectedEndpoint = routeIdentity['selectedEndpoint'];
  if (selectedEndpoint is! Map ||
      selectedEndpoint['baseUrl']?.toString().trim() !=
          request.baseUrl.trim() ||
      selectedEndpoint['model']?.toString().trim() != request.model.trim() ||
      selectedEndpoint['provider'] != request.provider.name ||
      selectedEndpoint['physicalDispatchPolicy'] !=
          AppLlmPhysicalDispatchPolicy.single.name ||
      routeIdentity['physicalDispatchPolicy'] !=
          AppLlmPhysicalDispatchPolicy.single.name ||
      routeIdentity['streamFallback'] != false ||
      routeIdentity['gatewayRetries'] != 0 ||
      routeIdentity['providerFailover'] != false ||
      routeIdentity['reconnectProbe'] != false) {
    return false;
  }
  return true;
}

bool _consumeFormalDispatchPermit(AppLlmChatRequest request) {
  if (request.physicalDispatchPolicy != AppLlmPhysicalDispatchPolicy.single) {
    return _activeFormalDispatchEpoch == null;
  }
  final permit = request.formalDispatchPermitForTransport;
  if (permit is! _IoFormalDispatchPermit || permit.consumed) {
    return false;
  }
  // Any genuine presentation burns the capability before comparing the full
  // request. A decorator cannot extract the permit, alter provider/prompt
  // semantics, and then retry either the altered or original request.
  permit.consumed = true;
  final epoch = _activeFormalDispatchEpoch;
  if (epoch == null ||
      epoch.closed ||
      !identical(epoch.permit, permit) ||
      epoch.physicalDispatchClaimed ||
      permit.nonce != request.dispatchEvidenceNonce ||
      permit.requestBindingDigest !=
          _formalTransportPermitBindingDigest(request)) {
    return false;
  }
  epoch.physicalDispatchClaimed = true;
  return true;
}

String _formalTransportPermitBindingDigest(AppLlmChatRequest request) {
  final cacheIdentity = request.formalCacheIdentity;
  final dispatchIdentity = request.formalDispatchIdentity;
  return AppLlmCanonicalHash.domainHash(
    'app-llm-io-formal-transport-permit-v1',
    <String, Object?>{
      'baseUrl': request.baseUrl,
      'apiKeyDigest': AppLlmCanonicalHash.domainHash(
        'app-llm-provider-credential-v1',
        request.apiKey,
      ),
      'model': request.model,
      'provider': request.provider.name,
      'timeout': <String, Object?>{
        'connectTimeoutMs': request.timeout.connectTimeoutMs,
        'sendTimeoutMs': request.timeout.sendTimeoutMs,
        'receiveTimeoutMs': request.timeout.receiveTimeoutMs,
        'idleTimeoutMs': request.timeout.idleTimeoutMs,
        'effectiveIdleTimeoutMs': request.timeout.effectiveIdleTimeoutMs,
      },
      'normalizedMaxTokens': request.effectiveMaxTokens,
      'messages': <Object?>[
        for (final message in request.messages) message.toJson(),
      ],
      'preferStreaming': request.preferStreaming,
      'physicalDispatchPolicy': request.physicalDispatchPolicy.name,
      'dispatchEvidenceNonce': request.dispatchEvidenceNonce,
      'formalCacheIdentity': cacheIdentity == null
          ? null
          : <String, Object?>{
              'stageId': cacheIdentity.stageId,
              'generationBundleHash': cacheIdentity.generationBundleHash,
              'parserRelease': cacheIdentity.parserRelease,
            },
      'formalDispatchIdentity': dispatchIdentity == null
          ? null
          : <String, Object?>{
              'completeIntentDigest': dispatchIdentity.completeIntentDigest,
              'stageId': dispatchIdentity.stageId,
              'callSiteId': dispatchIdentity.callSiteId,
              'variantId': dispatchIdentity.variantId,
              'generationBundleHash': dispatchIdentity.generationBundleHash,
              'promptReleaseContentHash':
                  dispatchIdentity.promptReleaseContentHash,
              'promptReleaseRefDigest': dispatchIdentity.promptReleaseRefDigest,
              'renderedMessagesDigest': dispatchIdentity.renderedMessagesDigest,
              'resolvedVariablesDigest':
                  dispatchIdentity.resolvedVariablesDigest,
              'rendererContractHash': dispatchIdentity.rendererContractHash,
              'parserRelease': dispatchIdentity.parserRelease,
            },
    },
  );
}

/// Isolate-local, deliberately non-persistent admission registry for formal
/// physical dispatches. A formal nonce represents one provider attempt, not
/// one client instance or decorator invocation. Keeping it at library scope
/// prevents a wrapper from calling two independently-created IO clients in
/// this isolate with the same request and presenting either private receipt as
/// "single". It is not a cross-isolate authority.
final Set<String> _admittedFormalDispatchNonces = <String>{};

bool _admitFormalPhysicalDispatch(AppLlmChatRequest request) {
  if (request.physicalDispatchPolicy != AppLlmPhysicalDispatchPolicy.single) {
    return true;
  }
  final nonce = request.dispatchEvidenceNonce;
  // Request validation has already required a canonical nonce for `single`.
  if (nonce == null) return false;
  return _admittedFormalDispatchNonces.add(nonce);
}

bool isTrustedPlatformAppLlmProviderBoundaryReceipt({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmChatRequest request,
}) =>
    receipt is _IoProviderBoundaryReceipt &&
    _sameFrozenRequest(receipt._request, request);

bool _sameFrozenRequest(AppLlmChatRequest left, AppLlmChatRequest right) {
  if (left.baseUrl != right.baseUrl ||
      left.apiKey != right.apiKey ||
      left.model != right.model ||
      left.provider != right.provider ||
      left.maxTokens != right.maxTokens ||
      left.physicalDispatchPolicy != right.physicalDispatchPolicy ||
      left.dispatchEvidenceNonce != right.dispatchEvidenceNonce ||
      left.messages.length != right.messages.length) {
    return false;
  }
  for (var index = 0; index < left.messages.length; index += 1) {
    if (left.messages[index].role != right.messages[index].role ||
        left.messages[index].content != right.messages[index].content) {
      return false;
    }
  }
  return true;
}

bool verifyPlatformAppLlmProviderBoundaryReceipt({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmProviderBoundaryExpectation expectation,
}) {
  if (receipt is! _IoProviderBoundaryReceipt) {
    return false;
  }
  return _providerBoundaryReceiptMatchesExpectation(receipt, expectation);
}

bool _providerBoundaryReceiptMatchesExpectation(
  _IoProviderBoundaryReceipt receipt,
  AppLlmProviderBoundaryExpectation expectation,
) {
  if (expectation.physicalDispatchPolicy !=
      AppLlmPhysicalDispatchPolicy.single) {
    return false;
  }
  final request = receipt._request;
  if (request.physicalDispatchPolicy != expectation.physicalDispatchPolicy ||
      request.baseUrl.trim() != expectation.baseUrl ||
      request.model.trim() != expectation.model ||
      request.provider != expectation.provider ||
      request.effectiveMaxTokens != expectation.normalizedMaxTokens ||
      request.dispatchEvidenceNonce != expectation.dispatchEvidenceNonce ||
      request.messages.length != expectation.messages.length) {
    return false;
  }
  for (var index = 0; index < request.messages.length; index += 1) {
    final observed = request.messages[index];
    final expected = expectation.messages[index];
    if (observed.role != expected.role ||
        observed.content != expected.content) {
      return false;
    }
  }
  return true;
}

String? consumeTrustedPlatformProviderOutcomeSealDigest({
  required AppLlmProviderBoundaryReceipt receipt,
  required AppLlmProviderBoundaryExpectation expectation,
}) => receipt is _IoProviderBoundaryReceipt
    ? receipt._consumeProviderOutcomeWitnessSeal(expectation)
    : null;

class _IoAppLlmClient
    implements AppLlmClient, AppLlmSinglePhysicalDispatchCapability {
  @override
  bool get supportsSinglePhysicalDispatch => true;

  @override
  Future<AppLlmChatResult> chat(AppLlmChatRequest request) async {
    request = request.freezeMessages();
    validateAppLlmSinglePhysicalDispatchRequest(request);
    // A streaming attempt and its non-stream fallback are one user-visible
    // request. They must share a deadline so a provider that keeps a stream
    // alive without completing cannot double (or indefinitely extend) the
    // caller's configured receive timeout.
    final deadline = DateTime.now().add(
      Duration(milliseconds: request.timeout.receiveTimeoutMs),
    );
    if (!request.preferStreaming ||
        request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single) {
      return _chatOnce(request, stream: false, deadline: deadline);
    }
    final streamed = await _chatOnce(request, stream: true, deadline: deadline);
    if (streamed.succeeded ||
        streamed.failureKind != AppLlmFailureKind.invalidResponse) {
      return streamed;
    }
    return _chatOnce(request, stream: false, deadline: deadline);
  }

  Future<AppLlmChatResult> _chatOnce(
    AppLlmChatRequest request, {
    required bool stream,
    required DateTime deadline,
  }) async {
    if (request.physicalDispatchPolicy != AppLlmPhysicalDispatchPolicy.single &&
        _activeFormalDispatchEpoch != null) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail:
            'adaptive physical dispatch is blocked inside the active formal admission epoch',
      );
    }
    final adapter = AppLlmProviderAdapters.of(request.provider);
    final endpoint = resolveAppLlmTransportEndpoint(
      request.baseUrl,
      adapter.endpointPath,
    );
    if (_isInsecureScheme(request.baseUrl)) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.insecureScheme,
        detail: '仅支持 HTTPS 连接。请将接口地址改为 https:// 开头。',
      );
    }
    if (endpoint == null) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: '接口地址无法解析为有效地址。',
      );
    }
    // This runs synchronously immediately before constructing the transport
    // operation, so a duplicate nonce cannot reach Dio's onRequest hook or
    // the network, even through another createAppLlmClient() instance.
    if (!_consumeFormalDispatchPermit(request)) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail:
            'formal physical dispatch permit is missing, invalid, or consumed',
      );
    }
    if (!_admitFormalPhysicalDispatch(request)) {
      return const AppLlmChatResult.failure(
        failureKind: AppLlmFailureKind.network,
        detail: 'formal physical dispatch nonce was already admitted',
      );
    }

    AppLlmProviderBoundaryReceipt? providerBoundaryReceipt;
    AppLlmChatResult withObservedReceipt(AppLlmChatResult result) {
      final receipt = providerBoundaryReceipt;
      if (receipt == null) return result;
      (receipt as _IoProviderBoundaryReceipt)._sealProviderOutcome(result);
      return result.withProviderBoundaryReceipt(receipt);
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(
          milliseconds: request.timeout.connectTimeoutMs,
        ),
        receiveTimeout: Duration(
          milliseconds: request.timeout.receiveTimeoutMs,
        ),
        sendTimeout: Duration(milliseconds: request.timeout.sendTimeoutMs),
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        followRedirects:
            request.physicalDispatchPolicy !=
            AppLlmPhysicalDispatchPolicy.single,
        maxRedirects:
            request.physicalDispatchPolicy ==
                AppLlmPhysicalDispatchPolicy.single
            ? 0
            : 5,
        headers: adapter.buildHeaders(request.apiKey),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (request.physicalDispatchPolicy ==
              AppLlmPhysicalDispatchPolicy.single) {
            providerBoundaryReceipt ??= _IoProviderBoundaryReceipt(
              request: request,
              transportEndpoint: options.uri.toString(),
            );
          }
          handler.next(options);
        },
      ),
    );

    final stopwatch = Stopwatch()..start();
    final cancelToken = CancelToken();

    Duration remaining() {
      final value = deadline.difference(DateTime.now());
      if (value <= Duration.zero) {
        cancelToken.cancel('chat deadline exceeded');
        throw TimeoutException('chat deadline exceeded');
      }
      return value;
    }

    Future<T> beforeDeadline<T>(Future<T> Function() operation) {
      final timeout = remaining();
      return operation().timeout(
        timeout,
        onTimeout: () {
          cancelToken.cancel('chat deadline exceeded');
          throw TimeoutException('chat deadline exceeded');
        },
      );
    }

    try {
      final response = await beforeDeadline(
        () =>
            // llm-call-site: boundary.provider.io-stream-http
            dio.postUri<ResponseBody>(
              endpoint,
              data: adapter.buildBody(
                model: request.model,
                messages: request.messages,
                stream: stream,
                maxTokens: request.effectiveMaxTokens,
              ),
              cancelToken: cancelToken,
            ),
      );
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        final body = await beforeDeadline(
          () => _readResponseBody(
            response.data,
            timeoutMs: request.timeout.receiveTimeoutMs,
          ),
        );
        stopwatch.stop();
        if (statusCode == HttpStatus.unauthorized ||
            statusCode == HttpStatus.forbidden) {
          return withObservedReceipt(
            AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.unauthorized,
              statusCode: statusCode,
              detail: _normalizeDetail(body),
            ),
          );
        }
        if (statusCode == HttpStatus.notFound) {
          return withObservedReceipt(
            AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.modelNotFound,
              statusCode: statusCode,
              detail: _normalizeDetail(body),
            ),
          );
        }
        if (statusCode == HttpStatus.tooManyRequests) {
          return withObservedReceipt(
            AppLlmChatResult.failure(
              failureKind: AppLlmFailureKind.rateLimited,
              statusCode: statusCode,
              detail: _normalizeDetail(body),
            ),
          );
        }
        return withObservedReceipt(
          AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.server,
            statusCode: statusCode,
            detail: _normalizeDetail(body),
          ),
        );
      }

      final body = await beforeDeadline(
        () => _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        ),
      );
      stopwatch.stop();

      final decoded = request.provider == AppLlmProvider.anthropic
          ? decodeAnthropicMessageStreamBody(body) ??
                decodeAnthropicMessageResponseBody(body)
          : decodeOpenAiChatStreamBody(body) ??
                decodeOpenAiChatResponseBody(body);
      final outputText = decoded?.text ?? adapter.decodeOutputText(body);
      if (outputText == null || outputText.trim().isEmpty) {
        return withObservedReceipt(
          AppLlmChatResult.failure(
            failureKind: AppLlmFailureKind.invalidResponse,
            statusCode: statusCode,
            detail: '模型返回成功，但响应体里没有可用文本。',
          ),
        );
      }

      return withObservedReceipt(
        AppLlmChatResult.success(
          text: outputText.trim(),
          latencyMs: stopwatch.elapsedMilliseconds,
          promptTokens: decoded?.promptTokens,
          completionTokens: decoded?.completionTokens,
          totalTokens: decoded?.totalTokens,
          providerModel: decoded?.providerModel,
          providerResponseId: decoded?.providerResponseId,
        ),
      );
    } on DioException catch (error) {
      final failure = _mapDioException(error);
      return withObservedReceipt(
        AppLlmChatResult.failure(
          failureKind: failure.failureKind,
          statusCode: failure.statusCode,
          detail: failure.detail,
          dispatchFailureDisposition: providerBoundaryReceipt == null
              ? null
              : AppLlmDispatchFailureDisposition.indeterminateException,
        ),
      );
    } on FormatException catch (error) {
      return withObservedReceipt(
        AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.invalidResponse,
          detail: error.message,
          dispatchFailureDisposition: providerBoundaryReceipt == null
              ? null
              : AppLlmDispatchFailureDisposition.indeterminateException,
        ),
      );
    } on TimeoutException {
      return withObservedReceipt(
        AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.timeout,
          detail: '请求在超时时间内未完成。',
          dispatchFailureDisposition: providerBoundaryReceipt == null
              ? null
              : AppLlmDispatchFailureDisposition.indeterminateException,
        ),
      );
    } catch (error) {
      return withObservedReceipt(
        AppLlmChatResult.failure(
          failureKind: AppLlmFailureKind.server,
          detail: error.toString(),
          dispatchFailureDisposition: providerBoundaryReceipt == null
              ? null
              : AppLlmDispatchFailureDisposition.indeterminateException,
        ),
      );
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> _readResponseBody(
    ResponseBody? body, {
    required int timeoutMs,
  }) async {
    if (body == null) {
      return '';
    }

    final bytes = await body.stream
        .expand((chunk) => chunk)
        .toList()
        .timeout(Duration(milliseconds: timeoutMs));
    return utf8.decode(bytes, allowMalformed: true);
  }

  bool _isInsecureScheme(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.isScheme('HTTP')) return false;
    return !_isLocalhost(uri.host);
  }

  bool _isLocalhost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        // The single-dispatch preflight also treats an explicitly configured
        // wildcard bind address as local. Keep the transport rule identical:
        // otherwise preflight admits an HTTP route that the IO client rejects
        // before its physical boundary, leaving a misleading zero-dispatch
        // experiment failure.
        host == '0.0.0.0' ||
        host.endsWith('.localhost');
  }

  String? _normalizeDetail(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            return message.trim();
          }
        }
        final message = decoded['message']?.toString();
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      // Fall through to raw body.
    }
    return trimmed;
  }

  @override
  Stream<String> chatStream(AppLlmChatRequest request) async* {
    request = request.freezeMessages();
    validateAppLlmSinglePhysicalDispatchRequest(request);
    if (_activeFormalDispatchEpoch != null) {
      throw const AppLlmPhysicalDispatchPreflightException(
        'formal-dispatch-epoch-stream-blocked',
        'stream dispatch is blocked inside the active formal admission epoch',
      );
    }
    if (request.physicalDispatchPolicy == AppLlmPhysicalDispatchPolicy.single) {
      throw const AppLlmPhysicalDispatchPreflightException(
        'single-stream-unsupported',
        'single physical dispatch requires the atomic chat interface',
      );
    }
    final adapter = AppLlmProviderAdapters.of(request.provider);
    final endpoint = resolveAppLlmTransportEndpoint(
      request.baseUrl,
      adapter.endpointPath,
    );
    if (_isInsecureScheme(request.baseUrl)) {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.insecureScheme,
        detail: '仅支持 HTTPS 连接。请将接口地址改为 https:// 开头。',
      );
    }
    if (endpoint == null) {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.network,
        detail: '接口地址无法解析为有效地址。',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(
          milliseconds: request.timeout.connectTimeoutMs,
        ),
        receiveTimeout: Duration(
          milliseconds: request.timeout.receiveTimeoutMs,
        ),
        sendTimeout: Duration(milliseconds: request.timeout.sendTimeoutMs),
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: adapter.buildHeaders(request.apiKey),
      ),
    );

    try {
      // llm-call-site: boundary.provider.io-chat-http
      final response = await dio.postUri<ResponseBody>(
        endpoint,
        data: adapter.buildBody(
          model: request.model,
          messages: request.messages,
          maxTokens: request.effectiveMaxTokens,
        ),
      );

      final statusCode = response.statusCode ?? 0;

      if (statusCode == HttpStatus.unauthorized ||
          statusCode == HttpStatus.forbidden) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        );
        throw AppLlmStreamException(
          failureKind: AppLlmFailureKind.unauthorized,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      if (statusCode == HttpStatus.notFound) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        );
        throw AppLlmStreamException(
          failureKind: AppLlmFailureKind.modelNotFound,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      if (statusCode < 200 || statusCode >= 300) {
        final body = await _readResponseBody(
          response.data,
          timeoutMs: request.timeout.receiveTimeoutMs,
        );
        throw AppLlmStreamException(
          failureKind: AppLlmFailureKind.server,
          statusCode: statusCode,
          detail: _normalizeDetail(body),
        );
      }

      final body = response.data;
      if (body == null) {
        throw const AppLlmStreamException(
          failureKind: AppLlmFailureKind.invalidResponse,
          detail: '服务器返回空响应体。',
        );
      }

      yield* _parseSseDeltas(
        body,
        request.timeout.effectiveIdleTimeoutMs,
        adapter,
      );
    } on AppLlmStreamException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioExceptionToStream(error);
    } on TimeoutException {
      throw const AppLlmStreamException(
        failureKind: AppLlmFailureKind.timeout,
        detail: '请求在超时时间内未完成。',
      );
    } catch (error) {
      throw AppLlmStreamException(
        failureKind: AppLlmFailureKind.server,
        detail: error.toString(),
      );
    } finally {
      dio.close(force: true);
    }
  }

  Stream<String> _parseSseDeltas(
    ResponseBody body,
    int timeoutMs,
    AppLlmProviderAdapter adapter,
  ) {
    return body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(Duration(milliseconds: timeoutMs))
        .handleError((Object error, StackTrace stackTrace) {
          throw const AppLlmStreamException(
            failureKind: AppLlmFailureKind.timeout,
            detail: '请求在超时时间内未完成。',
          );
        }, test: (error) => error is TimeoutException)
        .expand((line) {
          final trimmed = line.trim();
          if (!trimmed.startsWith('data:')) return <String>[];
          final payload = trimmed.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') return <String>[];

          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              final choices = decoded['choices'];
              if (choices is List && choices.isNotEmpty) {
                final firstChoice = choices.first;
                if (firstChoice is Map) {
                  final delta = firstChoice['delta'];
                  if (delta is Map) {
                    final content = normalizeLlmContent(delta['content']);
                    if (content != null && content.isNotEmpty) {
                      return <String>[content];
                    }
                  }
                }
              }
            }
          } on FormatException {
            // Skip malformed SSE payload.
          }
          final adapterText = adapter.decodeOutputText('data: $payload\n\n');
          if (adapterText != null && adapterText.isNotEmpty) {
            return <String>[adapterText];
          }
          return <String>[];
        });
  }

  AppLlmStreamException _mapDioExceptionToStream(DioException error) {
    final mapped = _mapDioException(error);
    return AppLlmStreamException(
      failureKind: mapped.failureKind,
      statusCode: mapped.statusCode,
      detail: mapped.detail,
    );
  }

  _MappedFailure _mapDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final detail = _normalizeDioErrorDetail(error);
    final underlying = error.error;

    if (statusCode == HttpStatus.unauthorized ||
        statusCode == HttpStatus.forbidden) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.unauthorized,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (statusCode == HttpStatus.notFound) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.modelNotFound,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.timeout,
        statusCode: statusCode,
        detail: '请求在超时时间内未完成。',
      );
    }
    if (error.type == DioExceptionType.badCertificate ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.cancel) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.network,
        statusCode: statusCode,
        detail: detail,
      );
    }
    if (underlying is SocketException ||
        underlying is HttpException ||
        underlying is FormatException) {
      return _MappedFailure(
        failureKind: AppLlmFailureKind.network,
        statusCode: statusCode,
        detail: detail,
      );
    }
    return _MappedFailure(
      failureKind: statusCode == null
          ? AppLlmFailureKind.network
          : AppLlmFailureKind.server,
      statusCode: statusCode,
      detail: detail,
    );
  }

  String _normalizeDioErrorDetail(DioException error) {
    final raw = error.message ?? error.toString();
    return _redactApiKeys(raw);
  }

  String _redactApiKeys(String text) {
    return _redactSkTokens(_redactBearerTokens(text));
  }

  String _redactBearerTokens(String text) {
    final lower = text.toLowerCase();
    final buffer = StringBuffer();
    var index = 0;
    while (index < text.length) {
      final bearerIndex = lower.indexOf('bearer', index);
      if (bearerIndex == -1) {
        buffer.write(text.substring(index));
        break;
      }
      buffer.write(text.substring(index, bearerIndex));
      var tokenStart = bearerIndex + 'bearer'.length;
      if (tokenStart >= text.length ||
          !_isWhitespace(text.codeUnitAt(tokenStart))) {
        buffer.write(text[bearerIndex]);
        index = bearerIndex + 1;
        continue;
      }
      while (tokenStart < text.length &&
          _isWhitespace(text.codeUnitAt(tokenStart))) {
        tokenStart += 1;
      }
      var tokenEnd = tokenStart;
      while (tokenEnd < text.length &&
          !_isWhitespace(text.codeUnitAt(tokenEnd))) {
        tokenEnd += 1;
      }
      buffer
        ..write(text.substring(bearerIndex, tokenStart))
        ..write('[REDACTED]');
      index = tokenEnd;
    }
    return buffer.toString();
  }

  String _redactSkTokens(String text) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < text.length) {
      final tokenIndex = text.indexOf('sk-', index);
      if (tokenIndex == -1) {
        buffer.write(text.substring(index));
        break;
      }
      buffer.write(text.substring(index, tokenIndex));
      var tokenEnd = tokenIndex + 3;
      while (tokenEnd < text.length &&
          _isAlphaNumeric(text.codeUnitAt(tokenEnd))) {
        tokenEnd += 1;
      }
      final token = text.substring(tokenIndex, tokenEnd);
      if (token.length > 7) {
        buffer.write('${token.substring(0, 7)}...[REDACTED]');
      } else {
        buffer.write(token);
      }
      index = tokenEnd;
    }
    return buffer.toString();
  }

  bool _isWhitespace(int codeUnit) {
    return codeUnit == 0x20 ||
        codeUnit == 0x09 ||
        codeUnit == 0x0A ||
        codeUnit == 0x0D;
  }

  bool _isAlphaNumeric(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A);
  }
}

final class _IoProviderBoundaryReceipt
    implements AppLlmProviderBoundaryReceipt {
  _IoProviderBoundaryReceipt({
    required AppLlmChatRequest request,
    required this.transportEndpoint,
  }) : _request = request;

  final AppLlmChatRequest _request;
  String? _providerOutcomeSealDigest;
  bool _outcomeWitnessIssued = false;

  void _sealProviderOutcome(AppLlmChatResult result) {
    if (_providerOutcomeSealDigest != null) {
      throw StateError('provider outcome was already sealed');
    }
    _providerOutcomeSealDigest = appLlmProviderOutcomeSealDigest(
      appLlmProviderOutcomeSealForResult(
        result: result,
        requestedProvider: _request.provider,
        requestedModel: _request.model,
      ),
    );
  }

  String? _consumeProviderOutcomeWitnessSeal(
    AppLlmProviderBoundaryExpectation expectation,
  ) {
    if (_outcomeWitnessIssued) return null;
    // Any genuine presentation burns issuance, including a wrong expectation.
    _outcomeWitnessIssued = true;
    if (!_providerBoundaryReceiptMatchesExpectation(this, expectation)) {
      return null;
    }
    return _providerOutcomeSealDigest;
  }

  @override
  String get contract => 'app-llm-provider-boundary-receipt-v1';

  @override
  int get physicalDispatchCount => 1;

  @override
  String get requestedBaseUrl => _request.baseUrl.trim();

  @override
  String get requestedModel => _request.model;

  @override
  AppLlmProvider get requestedProvider => _request.provider;

  @override
  final String transportEndpoint;

  @override
  String get dispatchEvidenceNonce => _request.dispatchEvidenceNonce!;

  @override
  Map<String, Object?> toCredentialFreeJson() => <String, Object?>{
    'contract': contract,
    'physicalDispatchCount': physicalDispatchCount,
    'requestedBaseUrl': requestedBaseUrl,
    'requestedModel': requestedModel,
    'requestedProvider': requestedProvider.name,
    'transportEndpoint': transportEndpoint,
    'dispatchEvidenceNonce': dispatchEvidenceNonce,
  };
}

class _MappedFailure {
  const _MappedFailure({
    required this.failureKind,
    required this.statusCode,
    required this.detail,
  });

  final AppLlmFailureKind failureKind;
  final int? statusCode;
  final String? detail;
}
