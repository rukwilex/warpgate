import 'package:warpgate_cli/src/args.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

abstract final class Help {
  static const version = '1.0.0';

  static String _pad(String value, int width) => value.padRight(width);

  static String _usageLine(ActionSpec action) {
    final parts = <String>['warpgate', action.cli];
    if (action.options.isNotEmpty) parts.add('[flags]');
    for (final arg in action.positionals) {
      final dots = arg.variadic ? '...' : '';
      final name = arg.name;
      parts.add(arg.required ? '<$name$dots>' : '[$name$dots]');
    }
    return parts.join(' ').replaceAll('<command...>', '-- <command...>').replaceAll('<text...>', '-- <text...>');
  }

  static void _rows(StringBuffer out, List<(String, String)> rows) {
    if (rows.isEmpty) return;
    final width = rows.map((row) => row.$1.length).reduce((a, b) => a > b ? a : b);
    for (final (left, right) in rows) {
      out.writeln('  ${_pad(left, width)}  $right');
    }
  }

  static String _flagLabel(ArgSpec arg) {
    final short = arg.short == null ? '    ' : '-${arg.short}, ';
    final value = arg.takesValue ? ' <${arg.valueName}>' : '';
    return '$short--${arg.name}$value';
  }

  static String _flagHelp(ArgSpec arg) {
    final parts = <String>[arg.summary];
    if (arg.choices.isNotEmpty) parts.add('One of: ${arg.choices.join(', ')}');
    if (arg.defaultValue != null) parts.add('Default: ${arg.defaultValue}');
    if (arg.repeatable) parts.add('Can be repeated');
    return parts.join('. ');
  }

  static const globals = <(String, String)>[
    ('-h, --help', 'Show help'),
    ('    --version', 'Print the version'),
    ('    --json', 'Print stable JSON on stdout'),
    ('    --quiet', 'Print only what was asked for'),
    ('    --no-color', 'Turn off color. NO_COLOR also works'),
    ('-y, --yes', 'Skip confirmations'),
    ('-v, --verbose', 'Print more detail on stderr'),
    ('    --profile <NAME>', 'Use a separate set of hosts, keys and settings'),
    ('    --no-app', 'Do not talk to the running app'),
  ];

  static String forAction(ActionSpec action) {
    final out = StringBuffer()
      ..writeln(action.summary)
      ..writeln()
      ..writeln('Usage:')
      ..writeln('  ${_usageLine(action)}');
    if (action.positionals.isNotEmpty) {
      out
        ..writeln()
        ..writeln('Arguments:');
      _rows(out, [
        for (final arg in action.positionals)
          (arg.name, arg.choices.isEmpty ? arg.summary : '${arg.summary}. One of: ${arg.choices.join(', ')}'),
      ]);
    }
    if (action.options.isNotEmpty) {
      out
        ..writeln()
        ..writeln('Flags:');
      _rows(out, [
        for (final arg in action.options) (_flagLabel(arg), _flagHelp(arg)),
      ]);
    }
    if (action.mode == ActionMode.app) {
      out
        ..writeln()
        ..writeln('Needs the app. Warpgate starts if it is not running.');
    }
    if (action.notes != null) {
      out
        ..writeln()
        ..writeln(action.notes);
    }
    if (action.aliases.isNotEmpty) {
      out
        ..writeln()
        ..writeln('Also: ${[for (final alias in action.aliases) 'warpgate $alias'].join(', ')}');
    }
    out
      ..writeln()
      ..writeln('Examples:');
    for (final example in action.examples) {
      out.writeln('  $example');
    }
    out
      ..writeln()
      ..writeln('Run warpgate --help for flags that work on every command.');
    return out.toString();
  }

  static String forGroup(String group) {
    final actions = {...CommandTree.inGroup(group)}.toList();
    final out = StringBuffer()
      ..writeln('warpgate $group')
      ..writeln()
      ..writeln('Usage:')
      ..writeln('  warpgate $group <command> [flags]')
      ..writeln()
      ..writeln('Commands:');
    _rows(out, [
      for (final action in actions)
        (action.cli.startsWith('$group ') ? action.cli.substring(group.length + 1) : action.cli, action.summary),
    ]);
    out
      ..writeln()
      ..writeln('Run warpgate $group <command> --help for details.');
    return out.toString();
  }

  static String root() {
    final out = StringBuffer()
      ..writeln('warpgate: SSH and SFTP for people who run many servers at once.')
      ..writeln()
      ..writeln('Usage:')
      ..writeln('  warpgate <command> [args] [flags]')
      ..writeln()
      ..writeln('Connect:');
    const connect = ['ssh', 'exec', 'open'];
    const files = ['ls', 'cat', 'get', 'put', 'cp', 'mv', 'rm', 'mkdir', 'chmod', 'stat', 'edit', 'find', 'du'];
    const other = ['go', 'completion', 'doctor', 'version', 'help', 'install', 'uninstall'];
    (String, String) row(String path) => (path, CommandTree.paths[path]!.summary);
    _rows(out, connect.map(row).toList());
    out
      ..writeln()
      ..writeln('Files:');
    _rows(out, files.map(row).toList());
    out
      ..writeln()
      ..writeln('Manage:');
    const groupText = {
      'hosts': 'Saved hosts',
      'groups': 'Host groups',
      'keys': 'SSH keys',
      'known-hosts': 'Trusted host keys',
      'transfers': 'The transfer queue',
      'forward': 'Saved port forwards',
      'snippets': 'Saved commands',
      'sessions': 'Terminals open in the app',
      'broadcast': 'Type into several terminals',
      'workspaces': 'Workspaces in the app',
      'layouts': 'Saved layouts and presets',
      'panes': 'Panes in the app',
      'tabs': 'Tabs in the app',
      'files': 'Files in the app, and every file command',
      'app': 'The app window',
      'settings': 'App settings',
      'backup': 'Encrypted backups',
      'mcp': 'Claude Code access',
    };
    _rows(out, [for (final MapEntry(:key, :value) in groupText.entries) (key, value)]);
    out
      ..writeln()
      ..writeln('Other:');
    _rows(out, other.map(row).toList());
    out
      ..writeln()
      ..writeln('Flags for every command:');
    _rows(out, globals);
    out
      ..writeln()
      ..writeln('Exit codes:');
    _rows(out, [
      for (final kind in ExitKind.values) ('${kind.code}', kind.meaning),
    ]);
    out
      ..writeln()
      ..writeln('Hosts can be a label, an id, user@host[:port], or @group. Remote paths are host:path.')
      ..writeln('Run warpgate <command> --help for details and examples.');
    return out.toString();
  }

  static String resolve(List<String> words) {
    if (words.isEmpty) return root();
    final action = CommandTree.paths[words.join(' ')];
    if (action != null) return forAction(action);
    if (words.length == 1 && CommandTree.groups.contains(words.first)) {
      return forGroup(words.first);
    }
    final near = Suggest.closest(words.join(' '), CommandTree.paths.keys);
    throw ActionFailure(
      'There is no help for "${words.join(' ')}"',
      kind: ExitKind.usage,
      hint: near == null ? 'Run warpgate --help to see the commands' : 'Did you mean warpgate help $near?',
    );
  }
}
