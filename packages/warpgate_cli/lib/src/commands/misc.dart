import 'dart:convert';
import 'dart:io';

import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/doctor.dart';
import 'package:warpgate_cli/src/commands/editor.dart';
import 'package:warpgate_cli/src/commands/install.dart';
import 'package:warpgate_cli/src/commands/mcp.dart';
import 'package:warpgate_cli/src/completion.dart';
import 'package:warpgate_cli/src/help.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';

abstract final class MiscCommands {
  static final Map<String, LocalCommand> all = {
    'version': _version,
    'help': _help,
    'completion': _completion,
    ...DoctorCommands.all,
    ...InstallCommands.all,
    ...McpCommands.all,
  };

  static Future<String> _stdinText() => utf8.decodeStream(stdin);

  static Future<JsonMap> prepare(CliContext context, ActionSpec action, JsonMap args) async {
    final prepared = {...args};
    if (prepared.remove('password-stdin') == true) {
      prepared['_password'] = (await _stdinText()).trimRight();
    } else if (action.name == 'hosts.add' && prepared['auth'] == 'password') {
      final typed = context.prompter.secret('Password (leave empty to ask each time)');
      if (typed != null && typed.isNotEmpty) prepared['_password'] = typed;
    }
    final fromStdin = prepared.remove('passphrase-stdin') == true;
    if (fromStdin) {
      prepared['_passphrase'] = (await _stdinText()).trimRight();
    } else if (action.name == 'keys.import') {
      final typed = context.prompter.secret('Key passphrase (leave empty if none)');
      if (typed != null && typed.isNotEmpty) prepared['_passphrase'] = typed;
    } else if (action.name == 'backup.export' || action.name == 'backup.import') {
      final first = context.prompter.secret('Backup passphrase');
      if (first == null || first.isEmpty) {
        throw const ActionFailure(
          'A backup needs a passphrase',
          kind: ExitKind.usage,
          hint: 'Pass it with --passphrase-stdin when there is no terminal',
        );
      }
      if (action.name == 'backup.export' && context.prompter.secret('Repeat the passphrase') != first) {
        throw const ActionFailure('The passphrases do not match', kind: ExitKind.usage);
      }
      prepared['_passphrase'] = first;
    }
    if (action.name == 'snippets.add' && prepared['body'] == null) {
      if (stdin.hasTerminal) {
        throw const ActionFailure('Pass the command text, or pipe it in', kind: ExitKind.usage);
      }
      prepared['body'] = (await _stdinText()).trimRight();
    }
    if (action.name == 'snippets.edit' && prepared['body'] == null && prepared['name'] == null) {
      final rt = await context.runtime();
      final snippet = await ActionHandlers.findSnippet(rt, prepared['snippet']! as String);
      prepared['body'] = await Editors.editText(snippet.body);
    }
    return prepared;
  }

  static Future<JsonMap?> _version(CliContext context, ActionSpec action, JsonMap args) async => {
    'version': Help.version,
    'schema_version': 1,
  };

  static Future<JsonMap?> _help(CliContext context, ActionSpec action, JsonMap args) async {
    final words = ((args['command'] as List?) ?? const <Object?>[]).cast<String>();
    final text = Help.resolve(words);
    if (context.output.json) return {'help': text};
    context.output.write(text);
    return null;
  }

  static Future<JsonMap?> _completion(CliContext context, ActionSpec action, JsonMap args) async {
    final shell = args['shell']! as String;
    return {'script': Completion.script(shell)};
  }
}
