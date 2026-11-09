import 'package:warpgate_core/actions/action_spec.dart';
import 'package:warpgate_core/actions/registry/shapes.dart';

abstract final class SnippetActionSpecs {
  static final List<ActionSpec> all = [
    ActionSpec(
      name: 'snippets.list',
      cli: 'snippets list',
      title: 'List snippets',
      summary: 'List saved snippets',
      permission: ActionPermission.read,
      examples: ['warpgate snippets list', 'warpgate snippets list --json'],
      table: const TableSpec('snippets', [TableColumn('name', 'NAME'), TableColumn('variables', 'VARIABLES'), TableColumn('body', 'COMMAND')]),
      result: Shape.object({'snippets': Shape.list(Shapes.snippet)}),
    ),
    ActionSpec(
      name: 'snippets.add',
      cli: 'snippets add',
      title: 'Add a snippet',
      summary: 'Save a snippet. Use {{name}} or {{name|default}} for variables',
      permission: ActionPermission.write,
      mode: ActionMode.prefersApp,
      args: [
        pos('name', 'Snippet name'),
        pos('body', 'Command text. Reads stdin when left out', required: false),
      ],
      examples: ['warpgate snippets add restart "sudo systemctl restart {{service}}"', 'warpgate snippets add cleanup < cleanup.sh'],
      text: 'Saved {name}',
      result: Shape.object({'id': Shape.string, 'name': Shape.string}),
    ),
    ActionSpec(
      name: 'snippets.edit',
      cli: 'snippets edit',
      title: 'Edit a snippet',
      summary: r'Change a snippet, in $EDITOR when no body is given',
      permission: ActionPermission.write,
      mode: ActionMode.prefersApp,
      args: [
        pos('snippet', 'Snippet name or id', complete: CompletionKind.snippet),
        pos('body', 'New command text', required: false),
        opt('name', 'New name', value: 'NAME'),
      ],
      examples: ['warpgate snippets edit restart', 'warpgate snippets edit restart "sudo service {{service}} restart"'],
      text: 'Saved {name}',
      result: Shape.object({'id': Shape.string, 'name': Shape.string}),
    ),
    ActionSpec(
      name: 'snippets.rm',
      cli: 'snippets rm',
      title: 'Remove a snippet',
      summary: 'Delete a snippet',
      permission: ActionPermission.destructive,
      mode: ActionMode.prefersApp,
      confirm: 'Delete snippet {snippet}?',
      args: [pos('snippet', 'Snippet name or id', complete: CompletionKind.snippet)],
      examples: ['warpgate snippets rm restart', 'warpgate snippets rm restart --yes'],
      text: 'Removed {name}',
      result: Shape.object({'id': Shape.string, 'name': Shape.string}),
    ),
    ActionSpec(
      name: 'snippets.run',
      cli: 'snippets run',
      title: 'Run a snippet',
      summary: 'Run a snippet on hosts',
      permission: ActionPermission.destructive,
      palette: const [PaletteEntry('snippets.run', 'Run snippet', CommandCategory.multi)],
      args: [
        pos('snippet', 'Snippet name or id', complete: CompletionKind.snippet),
        opt('on', 'Hosts: a label, @group, or a comma-separated list', value: 'TARGETS', required: true, complete: CompletionKind.hostOrGroup),
        opt('var', 'Variable as key=value', value: 'K=V', repeatable: true),
        opt('parallel', 'Hosts to run at once', short: 'p', value: 'N', defaultValue: '8'),
        opt('timeout', 'Stop waiting after this long', short: 't', value: 'TIME', defaultValue: '60s'),
      ],
      examples: ['warpgate snippets run restart --on prod --var service=nginx', 'warpgate snippets run cleanup --on @web --parallel 2'],
      result: Shape.object({'results': Shape.list(Shapes.hostRun), 'succeeded': Shape.integer, 'failed': Shape.integer}),
    ),
  ];
}
