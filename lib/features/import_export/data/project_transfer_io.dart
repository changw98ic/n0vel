import 'dart:convert';
import 'dart:io';

import 'project_transfer_models.dart';
import 'store_payload_contributor.dart';

/// Extract a zip [packageFile] into a temporary directory.
///
/// Returns the temp [Directory] on success, or `null` if extraction fails.
/// The caller is responsible for deleting the directory when done.
Future<Directory?> extractTransferPackage(
  File packageFile,
  String unzipExecutable,
) async {
  final extraction = await Directory.systemTemp.createTemp(
    'novel_writer_project_import',
  );
  final unzipResult = await Process.run(unzipExecutable, [
    '-oq',
    packageFile.path,
    '-d',
    extraction.path,
  ]);
  if (unzipResult.exitCode != 0) {
    if (await extraction.exists()) {
      await extraction.delete(recursive: true);
    }
    return null;
  }
  return extraction;
}

/// Verify checksums recorded in the extraction directory.
///
/// Returns `true` when all recorded checksums match, or when no checksums
/// file exists (treated as OK for forward compatibility).
Future<bool> verifyPackageChecksums(Directory extraction) async {
  final checksumsFile = File(
    '${extraction.path}/$projectTransferChecksumsFilename',
  );
  if (!await checksumsFile.exists()) return true;
  final checksumsMap = decodeProjectTransferObjectMap(
    jsonDecode(await checksumsFile.readAsString()),
  );
  for (final entry in checksumsMap.entries) {
    final payloadFile = File('${extraction.path}/${entry.key}');
    if (!await payloadFile.exists()) continue;
    final actual = computePayloadChecksum(await payloadFile.readAsString());
    if (actual != entry.value.toString()) return false;
  }
  return true;
}

/// Check that every [StorePayloadContributor] has a corresponding file in
/// the extraction directory.
Future<bool> hasRequiredStorePayloads(
  Directory extraction,
  List<StorePayloadContributor> payloads,
) async {
  for (final payload in payloads) {
    final file = File('${extraction.path}/${payload.filename}');
    if (!await file.exists()) return false;
  }
  return true;
}

/// Import all sync store payloads found in [extraction].
Future<void> importStorePayloads(
  Directory extraction,
  List<StorePayloadContributor> payloads,
) async {
  final imports = await Future.wait([
    for (final payload in payloads) _readStorePayload(extraction, payload),
  ]);
  for (final item in imports) {
    if (item == null) continue;
    item.payload.importJson(item.data);
  }
}

/// Import all async store payloads found in [extraction].
Future<void> importAsyncStorePayloads(
  Directory extraction,
  List<AsyncStorePayloadContributor> payloads,
  String? projectId,
) async {
  if (projectId == null || projectId.isEmpty) return;
  for (final payload in payloads) {
    await _readAsyncStorePayload(extraction, payload, projectId);
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

Future<DecodedStorePayload?> _readStorePayload(
  Directory extraction,
  StorePayloadContributor payload,
) async {
  final file = File('${extraction.path}/${payload.filename}');
  if (!await file.exists()) return null;
  return DecodedStorePayload(
    payload: payload,
    data: decodeProjectTransferObjectMap(jsonDecode(await file.readAsString())),
  );
}

Future<void> _readAsyncStorePayload(
  Directory extraction,
  AsyncStorePayloadContributor payload,
  String projectId,
) async {
  final file = File('${extraction.path}/${payload.filename}');
  if (!await file.exists()) return;
  await payload.importJson(
    projectId,
    decodeProjectTransferObjectMap(jsonDecode(await file.readAsString())),
  );
}
