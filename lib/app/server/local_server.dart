// ============================================================================
// LocalServer
// ============================================================================
//
// Local HTTP server for n0vel. M7-05 implements basic lifecycle and two
// endpoints (/health, /projects). M7-06 adds capability auth.
//
// See M7-05: Server Foundation
// See docs/local-server-api-design.md

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:novel_writer/domain/workspace_models.dart' show ProjectRecord;

import 'capability_auth.dart';
import 'local_server_config.dart';
import 'local_server_project_catalog.dart';
import 'local_server_route_scope.dart';

/// Server state for lifecycle tracking.
enum LocalServerState { stopped, starting, running, stopping }

/// JSON encoder for responses.
const _jsonEncoder = JsonEncoder.withIndent('  ');

/// HTTP response helper.
class _HttpResponse {
  _HttpResponse(this.response);

  final HttpResponse response;

  Future<void> json(int statusCode, Map<String, Object?> data) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(_jsonEncoder.convert(data));
    await response.flush();
    await response.close();
  }

  Future<void> error(int statusCode, String code, String message) async {
    await json(statusCode, {
      'error': {
        'code': code,
        'message': message,
        'requestId': _generateRequestId(),
      },
    });
  }

  String _generateRequestId() {
    return 'req-${DateTime.now().microsecondsSinceEpoch}';
  }
}

/// Local HTTP server with start/stop lifecycle.
class LocalServer {
  LocalServer({
    required this.config,
    required LocalServerProjectCatalog catalog,
    CapabilityAuth? auth,
  }) : _catalog = catalog,
       _auth = auth ?? CapabilityAuth.denyAll();

  final LocalServerConfig config;
  final LocalServerProjectCatalog _catalog;
  final CapabilityAuth _auth;

  HttpServer? _server;
  final _stateController = StreamController<LocalServerState>.broadcast();
  DateTime? _startedAt;

  /// Current server state.
  LocalServerState _state = LocalServerState.stopped;
  LocalServerState get state => _state;

  /// Stream of state changes.
  Stream<LocalServerState> get stateStream => _stateController.stream;

  /// Actual bound port (useful when config.port is 0).
  int get boundPort => _server?.port ?? 0;

  /// Whether the server is running.
  bool get isRunning => _state == LocalServerState.running;

  /// Start the server.
  Future<void> start() async {
    if (_state != LocalServerState.stopped) {
      throw StateError('Server is not stopped (current: $_state)');
    }
    if (!config.isValid) {
      throw ArgumentError('Invalid server configuration');
    }

    _setState(LocalServerState.starting);
    try {
      _server = await HttpServer.bind(_bindAddress(config.host), config.port);
      _startedAt = DateTime.now();
      _server!.listen(_handleRequest, onError: _handleError);
      _setState(LocalServerState.running);
    } catch (e) {
      _setState(LocalServerState.stopped);
      rethrow;
    }
  }

  /// Stop the server.
  Future<void> stop() async {
    if (_state != LocalServerState.running) {
      throw StateError('Server is not running (current: $_state)');
    }

    _setState(LocalServerState.stopping);
    await _server?.close();
    _server = null;
    _startedAt = null;
    _setState(LocalServerState.stopped);
  }

  void _setState(LocalServerState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _handleError(dynamic error, StackTrace stack) {
    // Log and ignore per plan; M7-06 adds structured logging.
    // print('Server error: $error');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = _HttpResponse(request.response);

    try {
      final path = request.uri.path;
      final method = request.method;

      // Route dispatch
      if (method == 'GET' && path == '/health') {
        await _handleHealth(response);
        return;
      }

      if (method == 'GET' && path == '/projects') {
        final authResult = _auth.authorize(
          authorizationHeader: request.headers.value(
            HttpHeaders.authorizationHeader,
          ),
          route: LocalServerRoutes.projects,
        );
        if (!authResult.allowed) {
          await response.error(
            authResult.statusCode,
            authResult.errorCode,
            authResult.message,
          );
          return;
        }
        await _handleProjects(response);
        return;
      }

      if (_isKnownPath(path)) {
        await response.error(
          HttpStatus.methodNotAllowed,
          'method_not_allowed',
          'Method not allowed: $method $path',
        );
        return;
      }

      await response.error(
        HttpStatus.notFound,
        'route_not_found',
        'Route not found: $method $path',
      );
    } catch (e) {
      await response.error(500, 'internal_error', 'Internal server error');
    }
  }

  InternetAddress _bindAddress(String host) {
    if (host == 'localhost') {
      return InternetAddress.loopbackIPv4;
    }
    return InternetAddress(host);
  }

  bool _isKnownPath(String path) {
    return path == LocalServerRoutes.health.pattern ||
        path == LocalServerRoutes.projects.pattern;
  }

  Future<void> _handleHealth(_HttpResponse response) async {
    final uptime = _startedAt != null
        ? DateTime.now().difference(_startedAt!).inSeconds
        : 0;

    await response.json(200, {
      'status': 'ok',
      'version': '1.0.0',
      'uptime': uptime,
    });
  }

  Future<void> _handleProjects(_HttpResponse response) async {
    final projects = _catalog.getProjects();

    await response.json(200, {
      'projects': projects.map((p) => _serializeProject(p)).toList(),
    });
  }

  Map<String, Object?> _serializeProject(ProjectRecord p) {
    return {
      'id': p.id,
      'sceneId': p.sceneId,
      'title': p.title,
      'genre': p.genre,
      'summary': p.summary,
      'recentLocation': p.recentLocation,
      'lastOpenedAtMs': p.lastOpenedAtMs,
    };
  }

  /// Dispose resources.
  Future<void> dispose() async {
    if (_state == LocalServerState.running) {
      await stop();
    }
    await _stateController.close();
  }
}
