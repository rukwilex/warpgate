import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/features/mcp/data/mcp_protocol.dart';

typedef ToolHandler = Future<JsonMap> Function(String name, JsonMap arguments);

class McpDispatcher {
  new({required this.tools, required this.handle, this.instructions});

  final List<McpToolSpec> Function() tools;
  final ToolHandler handle;
  final String? instructions;

  static const serverInfo = {
    'name': 'warpgate',
    'title': 'Warpgate',
    'version': '1.0.0',
  };

  Future<JsonMap?> dispatch(JsonMap message, {String? headerVersion}) async {
    final id = message['id'];
    final method = message['method'];
    final isNotification = !message.containsKey('id');
    if (message['jsonrpc'] != '2.0' || method is! String) {
      return isNotification
          ? null
          : rpcError(
              id,
              JsonRpcCodes.invalidRequest,
              'Invalid JSON-RPC request',
            );
    }
    final params =
        (message['params'] as Map?)?.cast<String, Object?>() ?? const {};
    if (isNotification) return null;
    try {
      final result = await _route(method, params, headerVersion);
      return rpcResult(id, result);
    } on McpError catch (error) {
      return rpcError(id, error.code, error.message, error.data);
    } on Object catch (error) {
      return rpcError(id, JsonRpcCodes.internalError, error.toString());
    }
  }

  Future<JsonMap> _route(
    String method,
    JsonMap params,
    String? headerVersion,
  ) async {
    final meta = (params['_meta'] as Map?)?.cast<String, Object?>();
    final metaVersion =
        meta?['io.modelcontextprotocol/protocolVersion'] as String?;
    final requested = metaVersion ?? headerVersion;
    if (requested != null &&
        method != 'initialize' &&
        !McpVersions.supported.contains(requested)) {
      throw McpError(
        JsonRpcCodes.unsupportedVersion,
        'Unsupported protocol version $requested',
        {'supported': McpVersions.supported},
      );
    }
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': McpVersions.negotiate(
            params['protocolVersion'] as String?,
          ),
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': serverInfo,
          'instructions': ?instructions,
        };
      case 'server/discover':
        return {
          'resultType': 'complete',
          'supportedVersions': McpVersions.supported,
          'capabilities': {'tools': <String, Object?>{}},
          'serverInfo': serverInfo,
          'instructions': ?instructions,
        };
      case 'ping':
        return {};
      case 'tools/list':
        return {
          'resultType': 'complete',
          'tools': [for (final tool in tools()) tool.toJson()],
        };
      case 'tools/call':
        final name = params['name'];
        if (name is! String || !tools().any((tool) => tool.name == name)) {
          throw McpError(JsonRpcCodes.invalidParams, 'Unknown tool: $name');
        }
        final arguments =
            (params['arguments'] as Map?)?.cast<String, Object?>() ?? const {};
        try {
          return await handle(name, arguments);
        } on ToolFailure catch (failure) {
          return toolResult(failure.message, isError: true);
        }
      default:
        throw McpError(
          JsonRpcCodes.methodNotFound,
          'Method not found: $method',
        );
    }
  }
}

class McpHttpServer {
  new({required this.dispatcher, required this.token, required this.port});

  final McpDispatcher dispatcher;
  final String Function() token;
  final int port;

  HttpServer? _server;

  bool get isRunning => _server != null;

  int? get boundPort => _server?.port;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server = server;
    server.listen((request) => unawaited(_handle(request)));
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  static bool _localOrigin(String? origin) {
    if (origin == null || origin.isEmpty || origin == 'null') return true;
    final uri = Uri.tryParse(origin);
    return uri != null &&
        const {'localhost', '127.0.0.1', '[::1]', '::1'}.contains(uri.host);
  }

  static bool _sameToken(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_localOrigin(request.headers.value('origin'))) {
        response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (request.uri.path != '/mcp') {
        response.statusCode = HttpStatus.notFound;
        return;
      }
      final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (!auth.startsWith('Bearer ') ||
          !_sameToken(auth.substring(7).trim(), token())) {
        response
          ..statusCode = HttpStatus.unauthorized
          ..headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
        return;
      }
      if (request.method != 'POST') {
        response
          ..statusCode = HttpStatus.methodNotAllowed
          ..headers.set(HttpHeaders.allowHeader, 'POST');
        return;
      }
      final body = await utf8.decodeStream(request);
      final Object? decoded;
      try {
        decoded = jsonDecode(body);
      } on FormatException {
        _json(
          response,
          HttpStatus.badRequest,
          rpcError(null, JsonRpcCodes.parseError, 'Parse error'),
        );
        return;
      }
      final headerVersion = request.headers.value('mcp-protocol-version');
      if (decoded is List) {
        final replies = <JsonMap>[];
        for (final item in decoded.whereType<Map<Object?, Object?>>()) {
          final reply = await dispatcher.dispatch(
            item.cast(),
            headerVersion: headerVersion,
          );
          if (reply != null) replies.add(reply);
        }
        if (replies.isEmpty) {
          response.statusCode = HttpStatus.accepted;
        } else {
          _json(response, HttpStatus.ok, replies);
        }
        return;
      }
      if (decoded is! Map) {
        _json(
          response,
          HttpStatus.badRequest,
          rpcError(null, JsonRpcCodes.invalidRequest, 'Invalid request'),
        );
        return;
      }
      final message = decoded.cast<String, Object?>();
      if (!message.containsKey('method')) {
        response.statusCode = HttpStatus.accepted;
        return;
      }
      final reply = await dispatcher.dispatch(
        message,
        headerVersion: headerVersion,
      );
      if (reply == null) {
        response.statusCode = HttpStatus.accepted;
        return;
      }
      final error = reply['error'] as Map?;
      final stateless = McpVersions.isStateless(
        headerVersion ?? McpVersions.legacyDefault,
      );
      final status = switch (error?['code']) {
        JsonRpcCodes.methodNotFound when stateless => HttpStatus.notFound,
        JsonRpcCodes.unsupportedVersion => HttpStatus.badRequest,
        _ => HttpStatus.ok,
      };
      _json(response, status, reply);
    } on Object {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }

  void _json(HttpResponse response, int status, Object body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
  }
}
