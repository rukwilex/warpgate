import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate_core/features/mcp/data/mcp_protocol.dart';
import 'package:warpgate_core/features/mcp/data/mcp_server.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';

void main() {
  final dispatcher = McpDispatcher(
    tools: () => McpTools.all,
    handle: (name, args) async {
      if (name == 'list_hosts') return toolResult({'hosts': <Object?>[]});
      throw const ToolFailure('denied');
    },
  );

  test('initialize negotiates the version', () async {
    final reply = await dispatcher.dispatch({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-06-18',
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': 't', 'version': '1'},
      },
    });
    final result = reply!['result']! as Map;
    expect(result['protocolVersion'], '2025-06-18');
    expect((result['serverInfo']! as Map)['name'], 'warpgate');
    final unknown = await dispatcher.dispatch({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'initialize',
      'params': {'protocolVersion': '1999-01-01'},
    });
    expect((unknown!['result']! as Map)['protocolVersion'], McpVersions.latest);
  });

  test('tools/list exposes every tool with a schema', () async {
    final reply = await dispatcher.dispatch({
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'tools/list',
    });
    final tools = ((reply!['result']! as Map)['tools']! as List)
        .cast<Map<String, Object?>>();
    expect(
      tools.map((t) => t['name']),
      containsAll(['run_command', 'transfer_between_hosts', 'read_terminal']),
    );
    expect(
      tools.every((t) => (t['inputSchema']! as Map)['type'] == 'object'),
      isTrue,
    );
  });

  test(
    'tool failures are results with isError, unknown tools are protocol errors',
    () async {
      final failed = await dispatcher.dispatch({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {
          'name': 'run_command',
          'arguments': {'command': 'ls'},
        },
      });
      expect((failed!['result']! as Map)['isError'], isTrue);
      final unknown = await dispatcher.dispatch({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {'name': 'nope'},
      });
      expect((unknown!['error']! as Map)['code'], JsonRpcCodes.invalidParams);
    },
  );

  test(
    'notifications get no reply and unsupported versions are refused',
    () async {
      expect(
        await dispatcher.dispatch({
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
        isNull,
      );
      final refused = await dispatcher.dispatch({
        'jsonrpc': '2.0',
        'id': 6,
        'method': 'tools/list',
        'params': {
          '_meta': {'io.modelcontextprotocol/protocolVersion': '2000-01-01'},
        },
      });
      expect(
        (refused!['error']! as Map)['code'],
        JsonRpcCodes.unsupportedVersion,
      );
    },
  );

  group('http transport', () {
    late McpHttpServer server;
    late HttpClient client;

    setUp(() async {
      HttpOverrides.global = null;
      server = McpHttpServer(
        dispatcher: dispatcher,
        token: () => 'secret',
        port: 0,
      );
      await server.start();
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    Future<(int, String)> post(
      Object body, {
      String? token = 'secret',
      String? origin,
    }) async {
      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/mcp'),
      );
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (origin != null) request.headers.set('origin', origin);
      request.write(jsonEncode(body));
      final response = await request.close();
      return (response.statusCode, await utf8.decodeStream(response));
    }

    test('requires the bearer token', () async {
      expect(
        (await post({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
        }, token: null)).$1,
        HttpStatus.unauthorized,
      );
      expect(
        (await post({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
        }, token: 'wrong')).$1,
        HttpStatus.unauthorized,
      );
      final ok = await post({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'});
      expect(ok.$1, HttpStatus.ok);
      expect(jsonDecode(ok.$2), {
        'jsonrpc': '2.0',
        'id': 1,
        'result': <String, Object?>{},
      });
    });

    test(
      'rejects foreign origins and answers notifications with 202',
      () async {
        expect(
          (await post({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'ping',
          }, origin: 'https://evil.example')).$1,
          HttpStatus.forbidden,
        );
        expect(
          (await post({
            'jsonrpc': '2.0',
            'id': 1,
            'method': 'ping',
          }, origin: 'http://localhost:3000')).$1,
          HttpStatus.ok,
        );
        expect(
          (await post({
            'jsonrpc': '2.0',
            'method': 'notifications/initialized',
          })).$1,
          HttpStatus.accepted,
        );
      },
    );

    test('GET is not allowed', () async {
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/mcp'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer secret');
      final response = await request.close();
      await response.drain<void>();
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });
}
