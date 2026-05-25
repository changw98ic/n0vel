import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:novel_writer/app/server/local_server.dart';
import 'package:novel_writer/app/server/local_server_config.dart';
import 'package:novel_writer/app/server/local_server_project_catalog.dart';
import 'package:novel_writer/domain/workspace_models.dart' show ProjectRecord;

void main() {
  group('LocalServer', () {
    test('server starts and listens on loopback', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      expect(server.state, LocalServerState.stopped);
      expect(server.isRunning, isFalse);

      await server.start();

      expect(server.state, LocalServerState.running);
      expect(server.isRunning, isTrue);
      expect(server.boundPort, greaterThan(0));

      await server.stop();

      expect(server.state, LocalServerState.stopped);
      expect(server.isRunning, isFalse);
    });

    test('GET /health returns 200 JSON', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/health'),
      );
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'application/json');

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, Object?>;

      expect(data['status'], 'ok');
      expect(data['version'], isNotNull);
      expect(data['uptime'], isA<int>());

      client.close();
      await server.stop();
    });

    test('GET /projects returns injected project records', () async {
      const projects = [
        ProjectRecord(
          id: 'project-001',
          sceneId: 'scene-001',
          title: 'Test Project 1',
          genre: 'Fantasy',
          summary: 'A fantasy epic',
          recentLocation: 'Chapter 1',
          lastOpenedAtMs: 1000000,
        ),
        ProjectRecord(
          id: 'project-002',
          sceneId: 'scene-002',
          title: 'Test Project 2',
          genre: 'Sci-Fi',
          summary: 'Space adventure',
          recentLocation: 'Chapter 2',
          lastOpenedAtMs: 2000000,
        ),
      ];

      const catalog = StaticLocalServerProjectCatalog(projects);
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/projects'),
      );
      final response = await request.close();

      expect(response.statusCode, 200);
      expect(response.headers.contentType?.mimeType, 'application/json');

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, Object?>;

      final returnedProjects = data['projects'] as List<Object?>;
      expect(returnedProjects, hasLength(2));

      final first = returnedProjects[0] as Map<String, Object?>;
      expect(first['id'], 'project-001');
      expect(first['title'], 'Test Project 1');
      expect(first['genre'], 'Fantasy');

      final second = returnedProjects[1] as Map<String, Object?>;
      expect(second['id'], 'project-002');
      expect(second['title'], 'Test Project 2');

      client.close();
      await server.stop();
    });

    test('unknown route returns 404 JSON', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/unknown'),
      );
      final response = await request.close();

      expect(response.statusCode, 404);

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, Object?>;

      final error = data['error'] as Map<String, Object?>;
      expect(error['code'], 'route_not_found');
      expect(error['message'], contains('Route not found'));
      expect(error['requestId'], isNotNull);

      client.close();
      await server.stop();
    });

    test('unsupported method on known route returns 405 JSON', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();

      // POST to /health (known route, wrong method)
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/health'),
      );
      final response = await request.close();

      expect(response.statusCode, 405);

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, Object?>;

      final error = data['error'] as Map<String, Object?>;
      expect(error['code'], 'method_not_allowed');

      client.close();
      await server.stop();
    });

    test('stop closes the server so port no longer accepts requests', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();
      final port = server.boundPort;

      await server.stop();
      expect(server.isRunning, isFalse);

      // Give the OS time to release the port
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Connection should be refused
      var caughtException = false;
      try {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/health'),
        );
        await request.close();
        client.close();
      } catch (e) {
        caughtException = true;
      }

      expect(caughtException, isTrue);
    });

    test('empty catalog returns empty projects list', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();

      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/projects'),
      );
      final response = await request.close();

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, Object?>;

      final returnedProjects = data['projects'] as List<Object?>;
      expect(returnedProjects, isEmpty);

      client.close();
      await server.stop();
    });

    test('config validation rejects invalid ports', () {
      const config = LocalServerConfig(port: -1);
      expect(config.isValid, isFalse);
    });

    test('start throws when config is invalid', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: -1);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      expect(() => server.start(), throwsA(isA<ArgumentError>()));
    });

    test('start throws when already running', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      await server.start();

      expect(() => server.start(), throwsA(isA<StateError>()));

      await server.stop();
    });

    test('stop throws when not running', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      expect(() => server.stop(), throwsA(isA<StateError>()));
    });

    test('forTest creates config with port 0', () {
      const config = LocalServerConfig(port: 3727);
      final testConfig = config.forTest();

      expect(testConfig.port, 0);
      expect(testConfig.host, config.host);
    });

    test('stateStream broadcasts state changes', () async {
      const catalog = StaticLocalServerProjectCatalog();
      const config = LocalServerConfig(port: 0);
      final server = LocalServer(config: config, catalog: catalog);

      addTearDown(server.dispose);

      final states = <LocalServerState>[];
      final subscription = server.stateStream.listen(states.add);

      await server.start();
      await server.stop();
      // Allow stream events to be processed
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Stream emits state transitions, not initial state
      expect(states, contains(LocalServerState.starting));
      expect(states, contains(LocalServerState.running));
      expect(states, contains(LocalServerState.stopping));
      // Final stopped state is emitted after stop completes
      expect(states.last, LocalServerState.stopped);

      await subscription.cancel();
    });
  });

  group('StaticLocalServerProjectCatalog', () {
    test('getProjectById returns project or null', () {
      const projects = [
        ProjectRecord(
          id: 'project-001',
          sceneId: 'scene-001',
          title: 'Test',
          genre: 'Fantasy',
          summary: 'A test',
          recentLocation: 'Chapter 1',
          lastOpenedAtMs: 1000,
        ),
      ];

      const catalog = StaticLocalServerProjectCatalog(projects);

      expect(catalog.getProjectById('project-001')?.id, 'project-001');
      expect(catalog.getProjectById('missing'), isNull);
    });

    test('getProjects returns unmodifiable list', () {
      const projects = [
        ProjectRecord(
          id: 'project-001',
          sceneId: 'scene-001',
          title: 'Test',
          genre: 'Fantasy',
          summary: 'A test',
          recentLocation: 'Chapter 1',
          lastOpenedAtMs: 1000,
        ),
      ];

      const catalog = StaticLocalServerProjectCatalog(projects);
      final returned = catalog.getProjects();

      expect(
        () => returned.add(
          const ProjectRecord(
            id: 'project-002',
            sceneId: 'scene-002',
            title: 'Test 2',
            genre: 'Sci-Fi',
            summary: 'Another test',
            recentLocation: 'Chapter 2',
            lastOpenedAtMs: 2000,
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('LocalServerConfig', () {
    test('isValid accepts loopback addresses', () {
      expect(
        const LocalServerConfig(host: '127.0.0.1', port: 3727).isValid,
        isTrue,
      );
      expect(const LocalServerConfig(host: '::1', port: 3727).isValid, isTrue);
      expect(
        const LocalServerConfig(host: 'localhost', port: 3727).isValid,
        isTrue,
      );
    });

    test('isValid rejects non-loopback addresses', () {
      expect(
        const LocalServerConfig(host: '0.0.0.0', port: 3727).isValid,
        isFalse,
      );
      expect(
        const LocalServerConfig(host: '192.168.1.1', port: 3727).isValid,
        isFalse,
      );
    });

    test('isValid rejects invalid ports', () {
      expect(
        const LocalServerConfig(host: '127.0.0.1', port: -1).isValid,
        isFalse,
      );
      expect(
        const LocalServerConfig(host: '127.0.0.1', port: 70000).isValid,
        isFalse,
      );
    });

    test('copyWith creates new config with updated values', () {
      const config = LocalServerConfig(host: '127.0.0.1', port: 3727);

      final updated = config.copyWith(port: 8080, enabled: true);

      expect(updated.host, '127.0.0.1');
      expect(updated.port, 8080);
      expect(updated.enabled, isTrue);
      expect(config.port, 3727); // Original unchanged
    });
  });
}
