import 'dart:convert';

abstract final class McpConnectSnippets {
  static String httpCommand(String url, String token) =>
      'claude mcp add --transport http warpgate $url --header "Authorization: Bearer $token"';

  static String mcpJson(String url, String token) =>
      const JsonEncoder.withIndent('  ').convert({
        'mcpServers': {
          'warpgate': {
            'type': 'http',
            'url': url,
            'headers': {'Authorization': 'Bearer $token'},
          },
        },
      });

  static String stdioCommand(String token, int port) =>
      'claude mcp add warpgate -e WARPGATE_MCP_TOKEN=$token -- warpgate-mcp --port $port';
}
