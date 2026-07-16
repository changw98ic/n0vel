import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_writer/app/rag/ollama_embedding_client.dart';

void main() {
  test('parses batched 4096-dimensional embeddings from /api/embed', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handled = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/embed');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body, {
        'model': 'qwen3-embedding',
        'input': ['剑气纵横', '灰雾之上'],
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'model': 'qwen3-embedding',
          'embeddings': [
            List<double>.generate(4096, (index) => index / 4096),
            List<double>.generate(4096, (index) => -index / 4096),
          ],
        }),
      );
      await request.response.close();
    });

    final client = OllamaEmbeddingClient(
      model: 'qwen3-embedding',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    final embeddings = await client.embedAll(['剑气纵横', '灰雾之上']);

    expect(embeddings, hasLength(2));
    expect(embeddings.first, hasLength(4096));
    expect(embeddings.first[2048], 0.5);
    expect(embeddings.last[2048], -0.5);
    await handled;
  });

  test('rejects an embedding whose dimensions do not match', () async {
    final server = await _serveJson({
      'embeddings': [
        [0.1, 0.2, 0.3],
      ],
    });
    final client = OllamaEmbeddingClient(
      model: 'qwen3-embedding',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    await expectLater(
      client.embed('dimension mismatch'),
      throwsA(
        isA<OllamaEmbeddingDimensionException>()
            .having((error) => error.expected, 'expected', 4096)
            .having((error) => error.actual, 'actual', 3)
            .having((error) => error.embeddingIndex, 'embeddingIndex', 0),
      ),
    );
  });

  test('surfaces Ollama HTTP errors with status and response body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.first.then((request) async {
      await request.drain<void>();
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.write('model is not available');
      await request.response.close();
    });
    final client = OllamaEmbeddingClient(
      model: 'qwen3-embedding',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    await expectLater(
      client.embed('failure'),
      throwsA(
        isA<OllamaEmbeddingHttpException>()
            .having(
              (error) => error.statusCode,
              'statusCode',
              HttpStatus.serviceUnavailable,
            )
            .having(
              (error) => error.responseBody,
              'responseBody',
              'model is not available',
            ),
      ),
    );
  });

  test('reads model identity and embedding details from /api/tags', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handled = server.first.then((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/api/tags');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'models': [
            {
              'name': 'qwen3-embedding:latest',
              'model': 'qwen3-embedding:latest',
              'digest': 'sha256:0123456789abcdef',
              'details': {
                'embedding_length': 4096,
                'quantization_level': 'Q8_0',
              },
            },
          ],
        }),
      );
      await request.response.close();
    });
    final client = OllamaEmbeddingClient(
      model: 'qwen3-embedding',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    final info = await client.fetchModelInfo();

    expect(info.name, 'qwen3-embedding:latest');
    expect(info.model, 'qwen3-embedding:latest');
    expect(info.digest, 'sha256:0123456789abcdef');
    expect(info.embeddingLength, 4096);
    expect(info.quantization, 'Q8_0');
    await handled;
  });

  test('reports when the configured model is absent from /api/tags', () async {
    final server = await _serveJson({
      'models': [
        {
          'name': 'another-model:latest',
          'model': 'another-model:latest',
          'digest': 'sha256:other',
          'details': {'embedding_length': 768},
        },
      ],
    });
    final client = OllamaEmbeddingClient(
      model: 'qwen3-embedding',
      expectedDimensions: 4096,
      baseUrl: 'http://${server.address.host}:${server.port}',
    );
    addTearDown(() {
      client.close(force: true);
      return server.close(force: true);
    });

    await expectLater(
      client.fetchModelInfo(),
      throwsA(
        isA<OllamaEmbeddingModelNotFoundException>().having(
          (error) => error.model,
          'model',
          'qwen3-embedding',
        ),
      ),
    );
  });
}

Future<HttpServer> _serveJson(Object payload) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.first.then((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  });
  return server;
}
