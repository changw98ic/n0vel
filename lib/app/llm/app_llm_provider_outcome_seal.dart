import 'dart:convert';

import 'package:cryptography/dart.dart';

import 'app_llm_canonical_hash.dart';
import 'app_llm_client_types.dart';

/// Credential-free canonical seal material for the exact result returned by
/// the provider IO boundary. Text and failure detail are represented only by
/// exact UTF-8 byte length and raw SHA-256 digest.
Map<String, Object?> appLlmProviderOutcomeSealForResult({
  required AppLlmChatResult result,
  required AppLlmProvider requestedProvider,
  required String requestedModel,
}) => <String, Object?>{
  'contract': 'app-llm-provider-outcome-seal-v1',
  'succeeded': result.succeeded,
  'requestedProvider': requestedProvider.name,
  'requestedModel': requestedModel,
  'statusCode': result.statusCode,
  'failureKind': result.failureKind?.name,
  'dispatchFailureDisposition': result.dispatchFailureDisposition?.name,
  'providerModel': result.providerModel,
  'providerResponseIdUtf8': appLlmExactUtf8Seal(result.providerResponseId),
  'promptTokens': result.promptTokens,
  'completionTokens': result.completionTokens,
  'totalTokens': result.totalTokens,
  'textUtf8': appLlmExactUtf8Seal(result.text),
  'detailUtf8': appLlmExactUtf8Seal(result.detail),
};

String appLlmProviderOutcomeSealDigest(Map<String, Object?> seal) =>
    AppLlmCanonicalHash.domainHash('app-llm-provider-outcome-seal-v1', seal);

Map<String, Object?>? appLlmExactUtf8Seal(String? value) {
  if (value == null) return null;
  final bytes = utf8.encode(value);
  final digest = const DartSha256().hashSync(bytes).bytes;
  final hex = digest
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return <String, Object?>{'byteLength': bytes.length, 'digest': 'sha256:$hex'};
}
