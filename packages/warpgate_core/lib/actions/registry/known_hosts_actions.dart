import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/action_spec.dart';
import 'package:warpgate_core/actions/registry/shapes.dart';

abstract final class KnownHostActionSpecs {
  static final List<ActionSpec> all = [
    ActionSpec(
      name: 'known-hosts.list',
      cli: 'known-hosts list',
      title: 'List known hosts',
      summary: 'List trusted host keys',
      permission: ActionPermission.read,
      examples: ['warpgate known-hosts list', 'warpgate known-hosts list --json'],
      table: const TableSpec('known_hosts', [TableColumn('endpoint', 'ENDPOINT'), TableColumn('key_type', 'TYPE'), TableColumn('fingerprint', 'FINGERPRINT')]),
      result: Shape.object({'known_hosts': Shape.list(Shapes.knownHost)}),
    ),
    ActionSpec(
      name: 'known-hosts.rm',
      cli: 'known-hosts rm',
      title: 'Forget a host key',
      summary: 'Forget a trusted host key',
      permission: ActionPermission.destructive,
      mode: ActionMode.prefersApp,
      confirm: 'Forget the host key of {endpoint}?',
      args: [pos('endpoint', 'Endpoint as address:port, or a host label', complete: CompletionKind.knownHost)],
      examples: ['warpgate known-hosts rm 10.0.0.5:22', 'warpgate known-hosts rm prod --yes'],
      text: 'Forgot {endpoint}',
      result: Shape.object({'endpoint': Shape.string}),
    ),
    ActionSpec(
      name: 'known-hosts.trust',
      cli: 'known-hosts trust',
      title: 'Trust a host key',
      summary: 'Fetch the key of a host, show it and save it',
      permission: ActionPermission.write,
      args: [
        pos('host', ActionHelp.host, complete: CompletionKind.host),
        opt('fingerprint', 'Only trust this exact fingerprint', value: 'FINGERPRINT'),
      ],
      examples: ['warpgate known-hosts trust prod', 'warpgate known-hosts trust prod --fingerprint "SHA256:abc"'],
      text: 'Trusted {endpoint}\n{key_type} {fingerprint}',
      result: Shapes.knownHost,
    ),
  ];
}
