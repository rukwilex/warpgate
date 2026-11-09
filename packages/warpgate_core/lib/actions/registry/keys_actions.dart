import 'package:warpgate_core/actions/action_constants.dart';
import 'package:warpgate_core/actions/action_spec.dart';
import 'package:warpgate_core/actions/registry/shapes.dart';

abstract final class KeyActionSpecs {
  static final List<ActionSpec> all = [
    ActionSpec(
      name: 'keys.list',
      cli: 'keys list',
      title: 'List keys',
      summary: 'List saved SSH keys',
      permission: ActionPermission.read,
      examples: ['warpgate keys list', 'warpgate keys list --json'],
      table: const TableSpec('keys', [TableColumn('name', 'NAME'), TableColumn('algorithm', 'TYPE'), TableColumn('fingerprint', 'FINGERPRINT')]),
      result: Shape.object({'keys': Shape.list(Shapes.key)}),
    ),
    ActionSpec(
      name: 'keys.generate',
      cli: 'keys generate',
      title: 'Generate a key',
      summary: 'Create a new SSH key',
      permission: ActionPermission.write,
      mode: ActionMode.prefersApp,
      args: [
        pos('name', 'Key name'),
        opt('type', 'Key type', short: 't', value: 'TYPE', choices: ['ed25519', 'rsa'], defaultValue: 'ed25519'),
      ],
      examples: ['warpgate keys generate work', 'warpgate keys generate legacy --type rsa'],
      text: 'Created {name}\n{public_key}',
      result: Shapes.key,
    ),
    ActionSpec(
      name: 'keys.import',
      cli: 'keys import',
      title: 'Import a key',
      summary: 'Save a private key from a file',
      permission: ActionPermission.write,
      mode: ActionMode.prefersApp,
      args: [
        pos('file', 'Private key file', complete: CompletionKind.localPath),
        opt('name', 'Key name. Defaults to the file name', short: 'n', value: 'NAME'),
        flag('passphrase-stdin', 'Read the passphrase from stdin'),
      ],
      examples: ['warpgate keys import ~/.ssh/id_ed25519', 'warpgate keys import ./deploy.pem --name deploy'],
      text: 'Imported {name}',
      result: Shapes.key,
    ),
    ActionSpec(
      name: 'keys.export-public',
      cli: 'keys export-public',
      title: 'Export public key',
      summary: 'Print the public half of a key',
      permission: ActionPermission.read,
      args: [pos('key', 'Key name or id', complete: CompletionKind.key)],
      examples: ['warpgate keys export-public work', 'warpgate keys export-public work >> authorized_keys'],
      text: '{public_key}',
      result: Shape.object({'public_key': Shape.string}),
    ),
    ActionSpec(
      name: 'keys.install',
      cli: 'keys install',
      title: 'Install a key',
      summary: "Add a key to a host's authorized_keys",
      permission: ActionPermission.write,
      args: [
        pos('key', 'Key name or id', complete: CompletionKind.key),
        pos('host', ActionHelp.host, complete: CompletionKind.host),
      ],
      examples: ['warpgate keys install work prod', 'warpgate keys install work deploy@10.0.0.5'],
      text: 'Installed {key} on {host}',
      result: Shape.object({'key': Shape.string, 'host': Shape.string}),
    ),
    ActionSpec(
      name: 'keys.rm',
      cli: 'keys rm',
      title: 'Remove a key',
      summary: 'Delete a saved key',
      permission: ActionPermission.destructive,
      mode: ActionMode.prefersApp,
      confirm: 'Delete key {key}? This cannot be undone.',
      args: [pos('key', 'Key name or id', complete: CompletionKind.key)],
      examples: ['warpgate keys rm old', 'warpgate keys rm old --yes'],
      text: 'Removed {name}',
      result: Shape.object({'id': Shape.string, 'name': Shape.string}),
    ),
  ];
}
