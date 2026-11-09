import 'dart:convert';

import 'package:warpgate_cli/src/help.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

abstract final class DocsGenerator {
  static const _sections = <(String, List<String>)>[
    ('Connect', ['ssh', 'exec', 'open']),
    ('Hosts and groups', ['hosts', 'groups']),
    ('Keys', ['keys', 'known-hosts']),
    ('Files', ['ls', 'cat', 'get', 'put', 'cp', 'mv', 'rm', 'mkdir', 'chmod', 'stat', 'edit', 'find', 'du', 'files']),
    ('Transfers and forwards', ['transfers', 'forward']),
    ('Snippets', ['snippets']),
    ('Sessions and the app', ['sessions', 'broadcast', 'workspaces', 'layouts', 'panes', 'tabs', 'go', 'app']),
    ('Settings, backup and Claude Code', ['settings', 'backup', 'mcp']),
    ('Setup', ['completion', 'doctor', 'version', 'help', 'install', 'uninstall']),
  ];

  static String _mode(ActionSpec action) => switch (action.mode) {
    ActionMode.local => 'Runs in the command. No app needed',
    ActionMode.prefersApp => 'Goes through the app when it is running, otherwise writes the database directly',
    ActionMode.app => 'Needs the app, and starts it if it is not running',
  };

  static const _intro = '''
# Warpgate command line

`warpgate` does everything the app does from a terminal. This file is generated from the action registry by `packages/warpgate_cli/tool/gen_docs.dart`. Do not edit it by hand.

## Quick start

```sh
warpgate-cli --install
warpgate hosts add prod deploy@10.0.0.5
warpgate known-hosts trust prod
warpgate exec prod -- uptime
warpgate cp prod:/var/log/app.log ./
warpgate completion zsh > ~/.zfunc/_warpgate
warpgate doctor
```

In the app, Settings → Command line installs and removes the command too.

## How hosts and paths are written

- A host is a label, an id, the start of an id, or `user@host[:port]`.
- `@web` means every host in the group `web`. Commands that take many hosts also accept `a,b,@web`.
- A remote path is `host:path`, and `host:` alone is the home folder. Anything else is local. To force a local path that contains a colon, write `./a:b`.
- A host written as `user@host` that is not saved signs in with ssh-agent, then the unencrypted keys in `~/.ssh`, then asks for a password.

## Standalone and attached

Without the app, the command uses the same database as the app directly. With the app running:

- Reads and SSH work still run in the command, so they stay fast.
- Changes go through the app so its screens update at once. Changes made with `--no-app` show up in the app within a second.
- Commands that show something in the app need it. They start it, or say how, and wait up to 10 seconds.

`--no-app` forces standalone mode.

### Secrets

Saved passwords and keys are read the first time they are needed:

1. From the file in `WARPGATE_MASTER_KEY_FILE`, for machines with no keychain. The file must be readable only by you.
2. From the running app, one secret at a time. The app refuses while it is locked.
3. From secure storage: the keychain on macOS, the system keyring through `secret-tool` on Linux, Windows data protection on Windows.

`warpgate` never prints a secret, with one exception that asks first: `warpgate mcp token show`.

### Profiles

`--profile work` or `WARPGATE_PROFILE=work` keeps a separate set of hosts, keys and settings. `WARPGATE_HOME` moves the data folder.

## Host keys

An unknown key is shown and asked about in a terminal. With no terminal it is refused with exit code 5, so run `warpgate known-hosts trust <host>` first. A changed key is always refused with no terminal, and a terminal has to type `trust`.

## Output

- Tables go to stdout. Progress goes to stderr, and only when stdout is a terminal.
- `--json` prints one object on stdout and nothing else. Every object has a `schema` field such as `warpgate.hosts.list/1`. The number changes when a field is removed or changes meaning.
- Errors with `--json` go to stderr: `{"schema":"warpgate.error/1","code":3,"kind":"notFound","message":"...","hint":"..."}`.
- Color follows the terminal, `--no-color` and `NO_COLOR`.

''';

  static const _scripting = r'''
## Scripting examples

Restart a service on a group, one host at a time, and stop at the first failure:

```sh
warpgate exec @web --stop-on-failure -- sudo systemctl restart nginx
```

Check which hosts failed:

```sh
warpgate exec @web --json -- systemctl is-active nginx \
  | jq -r '.results[] | select(.exit_code != 0) | .host'
```

Copy the latest backup from prod to staging, directly when staging can be reached from prod:

```sh
latest=$(warpgate exec prod -- ls -1t /var/backups | head -n 1)
warpgate cp --verify "prod:/var/backups/$latest" staging:/tmp/
warpgate cp --direct "prod:/var/backups/$latest" staging:/tmp/
```

Open a 2x2 layout of four hosts in the app:

```sh
warpgate open web-1
warpgate open web-2 --split right
warpgate open web-3 --split right
warpgate open web-4 --split right
warpgate layouts apply grid
```

Add a host from a script, with the password on stdin so it stays out of your shell history:

```sh
printf %s "$PW" | warpgate hosts add lab me@lab --auth password --password-stdin
```

Tell apart what went wrong:

```sh
warpgate exec prod -- true
case $? in
  0) echo fine ;;
  4) echo "credentials rejected" ;;
  5) echo "host key not trusted" ;;
  6) echo "could not connect" ;;
esac
```
''';

  static String render() {
    final out = StringBuffer(_intro.trimLeft())
      ..writeln('## Exit codes')
      ..writeln()
      ..writeln('| Code | Meaning |')
      ..writeln('| --- | --- |');
    for (final kind in ExitKind.values) {
      out.writeln('| ${kind.code} | ${kind.meaning} |');
    }
    out
      ..writeln()
      ..writeln('On `exec` and `ssh` with one host, the code is the one the remote command returned.')
      ..writeln()
      ..writeln('## Flags for every command')
      ..writeln()
      ..writeln('```');
    for (final (flag, text) in Help.globals) {
      out.writeln('${flag.padRight(24)}$text');
    }
    out
      ..writeln('```')
      ..writeln()
      ..writeln('## Commands')
      ..writeln();
    final done = <String>{};
    for (final (title, words) in _sections) {
      out
        ..writeln('### $title')
        ..writeln();
      for (final word in words) {
        for (final action in ActionRegistry.all) {
          if (action.cli != word && !action.cli.startsWith('$word ')) continue;
          if (!done.add(action.name)) continue;
          _command(out, action);
        }
      }
    }
    for (final action in ActionRegistry.all) {
      if (done.add(action.name)) _command(out, action);
    }
    out.write(_scripting);
    return out.toString();
  }

  static void _command(StringBuffer out, ActionSpec action) {
    out
      ..writeln('#### warpgate ${action.cli}')
      ..writeln()
      ..writeln('```')
      ..write(Help.forAction(action))
      ..writeln('```')
      ..writeln()
      ..writeln('${_mode(action)}. Permission: ${action.permission.name}.');
    if (action.mcp.isNotEmpty) {
      out.writeln('MCP tools: ${action.mcp.map((tool) => '`${tool.name}`').join(', ')}.');
    }
    if (action.palette.isNotEmpty) {
      out.writeln('Palette: ${action.palette.map((entry) => '`${entry.id}`').join(', ')}.');
    }
    if (action.result.isNotEmpty) {
      out
        ..writeln()
        ..writeln('JSON schema `${action.schemaId}`:')
        ..writeln()
        ..writeln('```json')
        ..writeln(const JsonEncoder.withIndent('  ').convert(action.result))
        ..writeln('```');
    }
    out.writeln();
  }
}
