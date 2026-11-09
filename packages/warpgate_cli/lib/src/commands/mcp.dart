import 'dart:convert';
import 'dart:io';

import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/mcp_environment.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/mcp/data/mcp_protocol.dart';
import 'package:warpgate_core/features/mcp/data/mcp_server.dart';
import 'package:warpgate_core/features/mcp/data/mcp_toolbox.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';

abstract final class McpCommands {
  static final Map<String, LocalCommand> all = {
    'mcp.serve': _mcpServe,
    'mcp.install': _mcpInstall,
  };

  static Future<JsonMap?> _mcpInstall(CliContext context, ActionSpec action, JsonMap args) async {
    final executable = Platform.resolvedExecutable;
    final words = ['mcp', 'add', 'warpgate', '--', executable, 'mcp', 'serve'];
    final command = 'claude ${words.join(' ')}';
    if (args['run'] != true) return {'command': command, 'ran': false};
    final ProcessResult result;
    try {
      result = await Process.run('claude', words);
    } on ProcessException {
      throw ActionFailure(
        'The claude command is not on your PATH',
        hint: 'Run this yourself once it is: $command',
      );
    }
    if (result.exitCode != 0) {
      throw ActionFailure('claude mcp add failed: ${result.stderr}');
    }
    return {'command': command, 'ran': true};
  }

  static Future<JsonMap?> _mcpServe(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    final environment = CliMcpEnvironment(context, rt);
    await environment.settle();
    final toolbox = McpToolbox(environment);
    final dispatcher = McpDispatcher(
      tools: () => McpTools.all,
      handle: toolbox.call,
      instructions:
          "Warpgate is the user's SSH and SFTP workbench. Hosts have per-host permissions. "
          "Use run_command for non-interactive work; it never touches the user's terminal.",
    );
    final pending = <Future<void>>[];
    void send(Object? message) => stdout.writeln(jsonEncode(message));
    await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      Object? message;
      try {
        message = jsonDecode(line);
      } on FormatException {
        send(rpcError(null, JsonRpcCodes.parseError, 'Parse error'));
        continue;
      }
      if (message is! Map) {
        send(rpcError(null, JsonRpcCodes.invalidRequest, 'Invalid request'));
        continue;
      }
      pending.add(
        dispatcher.dispatch(message.cast<String, Object?>()).then((reply) {
          if (reply != null) send(reply);
        }),
      );
    }
    await Future.wait(pending);
    throw const ExitWith(0);
  }
}
