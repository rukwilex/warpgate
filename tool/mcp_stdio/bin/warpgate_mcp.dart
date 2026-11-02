import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  if (options.token.isEmpty) {
    stderr.writeln('Set WARPGATE_MCP_TOKEN or pass --token. Copy it from Warpgate, Settings, Claude Code.');
    exitCode = 64;
    return;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final endpoint = Uri.parse('http://127.0.0.1:${options.port}/mcp');
  String? protocolVersion;
  final pending = <Future<void>>[];

  Future<void> forward(String line) async {
    final Object? message;
    try {
      message = jsonDecode(line);
    } on FormatException {
      _write({
        'jsonrpc': '2.0',
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error'},
      });
      return;
    }
    final id = message is Map ? message['id'] : null;
    if (message is Map && message['method'] == 'initialize') {
      final params = message['params'];
      if (params is Map && params['protocolVersion'] is String) protocolVersion = params['protocolVersion'] as String;
    }
    try {
      final request = await client.postUrl(endpoint);
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'application/json, text/event-stream')
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${options.token}');
      final version = protocolVersion;
      if (version != null) request.headers.set('MCP-Protocol-Version', version);
      request.add(utf8.encode(line));
      final response = await request.close();
      final body = await utf8.decodeStream(response);
      if (response.statusCode == HttpStatus.accepted || body.trim().isEmpty) return;
      if (response.statusCode == HttpStatus.unauthorized) {
        _write(_error(id, 'Warpgate rejected the token. Copy a fresh one from Settings, Claude Code.'));
        return;
      }
      final decoded = jsonDecode(body);
      if (decoded is List) {
        decoded.forEach(_write);
      } else {
        _write(decoded);
      }
    } on SocketException {
      if (id != null) _write(_error(id, 'Warpgate is not running, or Claude Code access is off in its settings.'));
    }
  }

  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    pending.add(forward(line));
  }
  await Future.wait(pending);
  client.close();
}

Map<String, Object?> _error(Object? id, String message) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': -32603, 'message': message},
};

void _write(Object? message) => stdout.writeln(jsonEncode(message));

class _Options {
  const new(this.port, this.token);

  factory parse(List<String> arguments) {
    var port = int.tryParse(Platform.environment['WARPGATE_MCP_PORT'] ?? '') ?? 7823;
    var token = Platform.environment['WARPGATE_MCP_TOKEN'] ?? '';
    for (var i = 0; i < arguments.length - 1; i++) {
      switch (arguments[i]) {
        case '--port':
          port = int.tryParse(arguments[i + 1]) ?? port;
        case '--token':
          token = arguments[i + 1];
      }
    }
    return _Options(port, token);
  }

  final int port;
  final String token;
}
