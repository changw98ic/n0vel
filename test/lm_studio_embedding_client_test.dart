import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/lm_studio_embedding_client.dart';

void main() {
  test('parses ordered batched embeddings from /v1/embeddings', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handled = server.first.then((request) async {
      expect(request.uri.path, '/v1/embeddings');
      expect(jsonDecode(await utf8.decoder.bind(request).join()), {
        'model': 'qwen3-embedding-8b',
        'input': ['剑来', '诡秘'],
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'model': 'qwen3-embedding-8b',
          'data': [
            {'index': 1, 'embedding': List<double>.filled(4, 2)},
            {'index': 0, 'embedding': List<double>.filled(4, 1)},
          ],
        }),
      );
      await request.response.close();
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    final vectors = await client.embedAll(['剑来', '诡秘']);

    expect(vectors, [List<double>.filled(4, 1), List<double>.filled(4, 2)]);
    await handled;
  });

  test('reads LM Studio embedding model metadata', () async {
    final server = await _serveJson({
      'models': [
        {
          'type': 'embedding',
          'publisher': 'lmstudio-community',
          'key': 'qwen3-embedding-8b',
          'display_name': 'Qwen3 Embedding 8B',
          'quantization': {'name': 'Q4_K_M', 'bits_per_weight': 4},
          'size_bytes': 4676804928,
          'params_string': '8B',
          'format': 'gguf',
          'max_context_length': 40960,
        },
      ],
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    final first = await client.fetchModelInfo();

    expect(first.model, 'qwen3-embedding-8b');
    expect(first.quantization, 'Q4_K_M');
    expect(first.sizeBytes, 4676804928);
  });

  test('reads llama.cpp OpenAI-compatible model metadata', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handled = server.first.then((request) async {
      expect(request.uri.path, '/v1/models');
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': [
            {
              'id': 'qwen3-embedding-8b',
              'meta': {
                'n_embd': 4096,
                'n_ctx': 512,
                'size': 4670855968,
                'ftype': 'Q4_K - Medium',
              },
            },
          ],
        }),
      );
      await request.response.close();
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
      metadataApi: EmbeddingServerMetadataApi.llamaCpp,
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    final info = await client.fetchModelInfo();

    expect(info.embeddingDimensions, 4096);
    expect(info.contextLength, 512);
    expect(info.quantization, 'Q4_K - Medium');
    expect(info.sizeBytes, 4670855968);
    await handled;
  });

  test('rejects a llama.cpp embedding dimension mismatch', () async {
    final server = await _serveJson({
      'data': [
        {
          'id': 'qwen3-embedding-8b',
          'meta': {'n_embd': 2560, 'n_ctx': 512},
        },
      ],
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
      metadataApi: EmbeddingServerMetadataApi.llamaCpp,
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    await expectLater(
      client.fetchModelInfo(),
      throwsA(isA<LmStudioEmbeddingProtocolException>()),
    );
  });

  test('behavior fingerprint is stable for identical probe vectors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'model': 'qwen3-embedding-8b',
          'data': [
            {'index': 0, 'embedding': List<double>.filled(4, 0.25)},
            {'index': 1, 'embedding': List<double>.filled(4, -0.5)},
          ],
        }),
      );
      await request.response.close();
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    final first = await client.fetchBehaviorFingerprint();
    final second = await client.fetchBehaviorFingerprint();

    expect(first, second);
    expect(first, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
  });

  test('verifies behavior probes inside an application batch', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestNumber = 0;
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      final inputs = (body['input'] as List).cast<String>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'model': 'qwen3-embedding-8b',
          'data': [
            for (var index = 0; index < inputs.length; index++)
              {
                'index': index,
                'embedding': List<double>.filled(
                  4,
                  index < inputs.length - 2
                      ? 3
                      : (index - (inputs.length - 2)).toDouble(),
                ),
              },
          ],
        }),
      );
      requestNumber++;
      await request.response.close();
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });
    final fingerprint = await client.fetchBehaviorFingerprint();

    final vectors = await client.embedAllVerifyingBehavior([
      '正文甲',
      '正文乙',
    ], expectedFingerprint: fingerprint);

    expect(vectors, [List<double>.filled(4, 3), List<double>.filled(4, 3)]);
    expect(requestNumber, 2);
  });

  test('rejects application embeddings when in-batch probes change', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestNumber = 0;
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      final inputs = (body['input'] as List).cast<String>();
      final changedProbeBatch = requestNumber > 0;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'model': 'qwen3-embedding-8b',
          'data': [
            for (var index = 0; index < inputs.length; index++)
              {
                'index': index,
                'embedding': List<double>.filled(
                  4,
                  index < inputs.length - 2
                      ? 3
                      : (index - (inputs.length - 2)).toDouble() +
                            (changedProbeBatch ? 0.5 : 0),
                ),
              },
          ],
        }),
      );
      requestNumber++;
      await request.response.close();
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });
    final fingerprint = await client.fetchBehaviorFingerprint();

    await expectLater(
      client.embedAllVerifyingBehavior([
        '正文',
      ], expectedFingerprint: fingerprint),
      throwsA(isA<LmStudioEmbeddingProtocolException>()),
    );
    expect(requestNumber, 2);
  });

  test(
    'rejects missing, duplicate, and out-of-range embedding indexes',
    () async {
      final invalidDataSets = <List<Map<String, Object?>>>[
        [
          {'embedding': List<double>.filled(4, 1)},
          {'index': 1, 'embedding': List<double>.filled(4, 2)},
        ],
        [
          {'index': 0, 'embedding': List<double>.filled(4, 1)},
          {'index': 0, 'embedding': List<double>.filled(4, 2)},
        ],
        [
          {'index': 0, 'embedding': List<double>.filled(4, 1)},
          {'index': 2, 'embedding': List<double>.filled(4, 2)},
        ],
      ];
      for (final data in invalidDataSets) {
        final server = await _serveJson({
          'model': 'qwen3-embedding-8b',
          'data': data,
        });
        final client = LmStudioEmbeddingClient(
          model: 'qwen3-embedding-8b',
          expectedDimensions: 4,
          baseUrl: 'http://${server.address.host}:${server.port}',
        );
        await expectLater(
          client.embedAll(['a', 'b']),
          throwsA(isA<LmStudioEmbeddingProtocolException>()),
        );
        client.close(force: true);
        await server.close(force: true);
      }
    },
  );

  test('rejects a response from a different model', () async {
    final server = await _serveJson({
      'model': 'another-model',
      'data': [
        {'index': 0, 'embedding': List<double>.filled(4, 1)},
      ],
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-embedding-8b',
      expectedDimensions: 4,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    await expectLater(
      client.embed('probe'),
      throwsA(isA<LmStudioEmbeddingProtocolException>()),
    );
  });

  test('rejects a model that LM Studio classifies as an llm', () async {
    final server = await _serveJson({
      'models': [
        {'type': 'llm', 'key': 'qwen3-vl-embedding-8b'},
      ],
    });
    final client = LmStudioEmbeddingClient(
      model: 'qwen3-vl-embedding-8b',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    await expectLater(
      client.fetchModelInfo(),
      throwsA(isA<LmStudioEmbeddingProtocolException>()),
    );
  });
}

Future<HttpServer> _serveJson(Object payload) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  });
  return server;
}
