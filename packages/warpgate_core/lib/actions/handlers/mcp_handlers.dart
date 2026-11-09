import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/support/action_call.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';

abstract final class McpHandlers {
  static final Map<String, ActionHandler> all = {
    'mcp.status': _mcpStatus,
    'mcp.token.show': _mcpTokenShow,
    'mcp.token.rotate': _mcpTokenRotate,
  };

  static Future<JsonMap> _mcpStatus(ActionCall call) async {
    final settings = await call.runtime.settings.load();
    return {
      'state': settings.mcpEnabled ? 'on' : 'off',
      'enabled': settings.mcpEnabled,
      'port': settings.mcpPort,
      'allowed': call.runtime.hosts.catalog.hosts
          .where((host) => host.mcpPermission != McpPermission.off)
          .length,
      'tools': McpTools.all.length,
    };
  }

  static String newToken() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(ActionLimits.tokenBytes, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Future<JsonMap> _mcpTokenShow(ActionCall call) async {
    final secrets = call.runtime.secrets;
    var token = await secrets.read(SecretKeys.mcpToken);
    if (token == null) {
      token = newToken();
      await secrets.write(SecretKeys.mcpToken, token);
    }
    return {'token': token};
  }

  static Future<JsonMap> _mcpTokenRotate(ActionCall call) async {
    await call.runtime.secrets.write(SecretKeys.mcpToken, newToken());
    return {'rotated': true};
  }
}
