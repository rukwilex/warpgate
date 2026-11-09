import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/action_spec.dart';
import 'package:warpgate_core/actions/registry/shapes.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';

abstract final class ConnectActionSpecs {
  static final List<ActionSpec> all = [
    ActionSpec(
      name: 'ssh',
      cli: 'ssh',
      title: 'Open a shell',
      summary: 'Open an interactive shell on a host, or run one command',
      permission: ActionPermission.write,
      passthrough: true,
      args: [
        pos('host', ActionHelp.host, complete: CompletionKind.host),
        pos('command', 'Command to run instead of a shell', required: false, variadic: true),
        opt('local-forward', 'Forward a local port: [bind:]port:host:hostport', short: 'L', value: 'SPEC', repeatable: true),
        opt('remote-forward', 'Forward a remote port: port:host:hostport', short: 'R', value: 'SPEC', repeatable: true),
        opt('dynamic-forward', 'Start a SOCKS proxy: [bind:]port', short: 'D', value: 'SPEC', repeatable: true),
        opt('jump', 'Connect through this host', short: 'J', value: 'HOST', complete: CompletionKind.host),
        flag('tmux', 'Attach the persistent tmux session'),
      ],
      examples: [
        'warpgate ssh prod',
        'warpgate ssh deploy@10.0.0.5:2222 uptime',
        'warpgate ssh prod -L 8080:localhost:80 -J bastion',
      ],
      result: Shape.object({'exit_code': Shape.integer}),
    ),
    ActionSpec(
      name: 'exec',
      cli: 'exec',
      title: 'Run a command',
      summary: 'Run a command on one host or many in parallel',
      permission: ActionPermission.destructive,
      passthrough: true,
      mcp: const [McpTools.runCommand, McpTools.runOnHosts],
      args: [
        pos('targets', 'Hosts: a label, @group, or a comma-separated list', complete: CompletionKind.hostOrGroup),
        pos('command', 'Command to run, after --', variadic: true),
        opt('parallel', 'Hosts to run at once', short: 'p', value: 'N', defaultValue: '8'),
        opt('timeout', 'Stop waiting after this long, such as 30s or 5m. On several hosts the default is 60s', short: 't', value: 'TIME'),
        flag('stop-on-failure', 'Run hosts one at a time and stop at the first failure'),
      ],
      examples: [
        'warpgate exec prod -- uptime',
        'warpgate exec @web --parallel 4 -- systemctl restart nginx',
        'warpgate exec a,b,c --json -- df -h /',
      ],
      notes: "On one host the exit code is the remote command's. On several hosts it is 0 when all succeed and 7 when any fail.",
      result: Shape.object({
        'results': Shape.list(Shapes.hostRun),
        'succeeded': Shape.integer,
        'failed': Shape.integer,
      }),
    ),
  ];
}
