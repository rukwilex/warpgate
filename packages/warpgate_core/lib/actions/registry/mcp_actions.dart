import 'package:warpgate_core/actions/action_spec.dart';

abstract final class McpActionSpecs {
  static final List<ActionSpec> all = [
    const ActionSpec(
      name: 'mcp.serve',
      cli: 'mcp serve',
      title: 'Serve MCP',
      summary: 'Run a stdio MCP server for Claude Code',
      permission: ActionPermission.write,
      examples: ['warpgate mcp serve', 'claude mcp add warpgate -- warpgate mcp serve'],
      result: {},
    ),
    ActionSpec(
      name: 'mcp.status',
      cli: 'mcp status',
      title: 'MCP status',
      summary: 'Show whether Claude Code access is on',
      permission: ActionPermission.read,
      examples: ['warpgate mcp status', 'warpgate mcp status --json'],
      text: 'Claude Code access is {state} on port {port}. {allowed} hosts allowed',
      result: Shape.object({'state': Shape.string, 'enabled': Shape.boolean, 'port': Shape.integer, 'allowed': Shape.integer, 'tools': Shape.integer}),
    ),
    ActionSpec(
      name: 'mcp.token.show',
      cli: 'mcp token show',
      title: 'Show MCP token',
      summary: 'Print the Claude Code access token. Asks first',
      permission: ActionPermission.destructive,
      confirm: 'Print the access token to this terminal?',
      examples: ['warpgate mcp token show', 'warpgate mcp token show --yes'],
      text: '{token}',
      result: Shape.object({'token': Shape.string}),
    ),
    ActionSpec(
      name: 'mcp.token.rotate',
      cli: 'mcp token rotate',
      title: 'Rotate MCP token',
      summary: 'Replace the Claude Code access token',
      permission: ActionPermission.destructive,
      mode: ActionMode.prefersApp,
      confirm: 'Replace the access token? Connected clients stop working until updated.',
      examples: ['warpgate mcp token rotate', 'warpgate mcp token rotate --yes'],
      text: 'Replaced the token',
      result: Shape.object({'rotated': Shape.boolean}),
    ),
    ActionSpec(
      name: 'mcp.install',
      cli: 'mcp install',
      title: 'Add to Claude Code',
      summary: 'Print the claude mcp add command, or run it',
      permission: ActionPermission.write,
      args: [flag('run', 'Run the command instead of printing it')],
      examples: ['warpgate mcp install', 'warpgate mcp install --run'],
      text: '{command}',
      result: Shape.object({'command': Shape.string, 'ran': Shape.boolean}),
    ),
  ];
}
