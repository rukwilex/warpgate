import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/commands/copy.dart';
import 'package:warpgate_cli/src/completion.dart';
import 'package:warpgate_cli/src/help.dart';
import 'package:warpgate_cli/src/secrets/platform_vault.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/vault_secret_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/ssh_agent_client.dart';
import 'package:warpgate_core/features/hosts/data/hosts_service.dart';
import 'package:warpgate_core/features/mcp/data/mcp_protocol.dart';
import 'package:warpgate_core/features/mcp/data/mcp_server.dart';
import 'package:warpgate_core/features/mcp/data/mcp_toolbox.dart';
import 'package:warpgate_core/features/mcp/domain/mcp_tools.dart';
import 'package:warpgate_core/features/settings/domain/app_settings.dart';
import 'package:warpgate_core/features/sftp/data/endpoint_resolver.dart';
import 'package:warpgate_core/features/transfers/data/transfer_scheduler.dart';
import 'package:warpgate_core/features/transfers/domain/transfer_job.dart';
import 'package:warpgate_core/ipc/ipc.dart';

abstract final class MiscCommands {
  static final Map<String, LocalCommand> all = {
    'version': _version,
    'help': _help,
    'completion': _completion,
    'doctor': _doctor,
    'install': _install,
    'uninstall': _uninstall,
    'mcp.serve': _mcpServe,
    'mcp.install': _mcpInstall,
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
      prepared['body'] = await _editText(snippet.body);
    }
    return prepared;
  }

  static Future<String> _editText(String initial) async {
    final environment = Platform.environment;
    final editor = environment['VISUAL'] ?? environment['EDITOR'] ?? (Platform.isWindows ? 'notepad' : 'vi');
    final temp = await Directory.systemTemp.createTemp('warpgate-snippet-');
    final file = File(p.join(temp.path, 'snippet.sh'));
    await file.writeAsString(initial);
    try {
      final words = editor.split(' ');
      final process = await Process.start(
        words.first,
        [...words.skip(1), file.path],
        mode: ProcessStartMode.inheritStdio,
      );
      if (await process.exitCode != 0) {
        throw ActionFailure('$editor did not finish cleanly. Nothing was saved');
      }
      return (await file.readAsString()).trimRight();
    } finally {
      await temp.delete(recursive: true);
    }
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

  static String? _installTarget() {
    final environment = Platform.environment;
    final home = environment['HOME'] ?? environment['USERPROFILE'];
    if (home == null) return null;
    return p.join(home, '.local', 'bin', 'warpgate');
  }

  static bool _isWritable(String directory) {
    if (!Directory(directory).existsSync()) return false;
    final probe = File(p.join(directory, '.warpgate-$pid'));
    try {
      probe
        ..writeAsStringSync('')
        ..deleteSync();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static bool onPath(String directory) {
    final separator = Platform.isWindows ? ';' : ':';
    return (Platform.environment['PATH'] ?? '')
        .split(separator)
        .any((item) => p.equals(item, directory));
  }

  static String get _windowsBin => p.join(
    Platform.environment['LOCALAPPDATA'] ?? '',
    'Warpgate',
    'bin',
  );

  static List<String> installPlaces() {
    final override = Platform.environment['WARPGATE_INSTALL_DIR'];
    if (override != null) return [p.join(override, 'warpgate')];
    return Platform.isWindows
        ? [p.join(_windowsBin, 'warpgate.cmd')]
        : ['/usr/local/bin/warpgate', ?_installTarget()];
  }

  static Future<JsonMap?> _install(CliContext context, ActionSpec action, JsonMap args) async {
    final executable = Platform.resolvedExecutable;
    if (Platform.isWindows && !Platform.environment.containsKey('WARPGATE_INSTALL_DIR')) {
      final directory = Directory(_windowsBin);
      await directory.create(recursive: true);
      final shim = File(p.join(directory.path, 'warpgate.cmd'));
      await shim.writeAsString('@echo off\r\n"$executable" %*\r\n', flush: true);
      final script =
          r"$p=[Environment]::GetEnvironmentVariable('Path','User');"
          "\$d='${directory.path}';"
          r"if(($p -split ';') -notcontains $d){[Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$d).TrimStart(';'),'User')}";
      final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      if (result.exitCode != 0) {
        throw ActionFailure('Could not change your PATH: ${result.stderr}');
      }
      return {'path': shim.path, 'needs_new_shell': true};
    }
    final places = installPlaces();
    final chosen = _isWritable(p.dirname(places.first)) ? places.first : places.last;
    final directory = Directory(p.dirname(chosen));
    await directory.create(recursive: true);
    final link = Link(chosen);
    if (link.existsSync()) {
      await link.delete();
    } else if (File(chosen).existsSync()) {
      throw ActionFailure('$chosen already exists and is not a link. Remove it first');
    }
    await link.create(executable);
    if (!onPath(directory.path)) {
      context.output.note('Add ${directory.path} to your PATH to run warpgate from any folder.');
    }
    return {'path': chosen, 'needs_new_shell': !onPath(directory.path)};
  }

  static Future<JsonMap?> _uninstall(CliContext context, ActionSpec action, JsonMap args) async {
    var removed = false;
    for (final place in installPlaces()) {
      final link = Link(place);
      if (Platform.isWindows && File(place).existsSync()) {
        await File(place).delete();
        removed = true;
      } else if (link.existsSync()) {
        await link.delete();
        removed = true;
      }
    }
    return {'removed': removed};
  }

  static Future<JsonMap?> _doctor(CliContext context, ActionSpec action, JsonMap args) async {
    final checks = <JsonMap>[];
    void check(String name, {required bool ok, required String detail, String? fix}) {
      checks.add({'name': name, 'ok': ok, 'detail': detail, 'fix': fix});
    }

    final executable = Platform.resolvedExecutable;
    check('Program', ok: true, detail: executable);
    final installed = installPlaces().where((place) => Link(place).existsSync() || File(place).existsSync()).toList();
    check(
      'Installed',
      ok: installed.isNotEmpty,
      detail: installed.isEmpty ? 'No warpgate command found' : installed.first,
      fix: installed.isEmpty ? 'Run warpgate-cli --install, or use Settings, Command line' : null,
    );
    final linked = installed.isEmpty || onPath(p.dirname(installed.first));
    check(
      'On PATH',
      ok: installed.isNotEmpty && linked,
      detail: installed.isEmpty
          ? 'Not installed'
          : linked
          ? '${p.dirname(installed.first)} is on PATH'
          : '${p.dirname(installed.first)} is not on PATH',
      fix: linked ? null : 'Add ${installed.isEmpty ? '' : p.dirname(installed.first)} to PATH',
    );
    final paths = context.paths;
    try {
      final hosts = await context.store.all('hosts');
      check('Database', ok: true, detail: '${paths.database}, ${hosts.length} hosts');
    } on Object catch (error) {
      check('Database', ok: false, detail: '$error', fix: 'Check that ${paths.root} can be written');
    }
    final client = await context.client();
    final stuck = client == null && !context.globals.noApp && await AppInstance.isRunning(paths);
    check(
      'App connection',
      ok: !stuck,
      detail: context.globals.noApp
          ? 'Skipped, --no-app was passed'
          : client != null
          ? 'Connected to the running app'
          : stuck
          ? 'The app is running but not answering'
          : 'The app is not running. Commands that show things in the app will start it',
      fix: stuck ? 'Quit and reopen Warpgate' : null,
    );
    final keyFile = Platform.environment['WARPGATE_MASTER_KEY_FILE'];
    if (keyFile != null) {
      final vault = FileKeyVault(keyFile);
      try {
        await vault.read(MasterKeySource.itemName);
        check('Secure storage', ok: true, detail: 'Using the key file $keyFile');
      } on VaultUnavailable catch (error) {
        check('Secure storage', ok: false, detail: error.message);
      }
    } else if (client != null) {
      check('Secure storage', ok: true, detail: 'Secrets come from the running app');
    } else if (Platform.isMacOS) {
      final present = MacKeychain().hasItem;
      check(
        'Secure storage',
        ok: present,
        detail: present
            ? 'The keychain has the Warpgate key. macOS may ask to allow access'
            : 'No Warpgate key in the keychain yet',
        fix: present ? null : 'Open Warpgate once, or keep it open while using saved secrets',
      );
    } else if (Platform.isLinux) {
      final result = await Process.run('which', ['secret-tool']);
      check(
        'Secure storage',
        ok: result.exitCode == 0,
        detail: result.exitCode == 0 ? 'secret-tool is available' : 'secret-tool is missing',
        fix: result.exitCode == 0 ? null : 'Install libsecret-tools, or keep Warpgate open',
      );
    } else {
      check('Secure storage', ok: true, detail: 'Windows data protection');
    }
    final location = SshAgentClient.location;
    if (location == null) {
      check(
        'ssh-agent',
        ok: false,
        detail: 'SSH_AUTH_SOCK is not set',
        fix: r'Run eval "$(ssh-agent)" and ssh-add',
      );
    } else {
      final agent = await SshAgentClient.connect(location);
      if (agent == null) {
        check('ssh-agent', ok: false, detail: 'Could not reach $location', fix: 'Start ssh-agent or Pageant');
      } else {
        final keys = await agent.keys();
        await agent.close();
        check('ssh-agent', ok: true, detail: '${keys.length} keys loaded');
      }
    }
    final allOk = checks.every((item) => item['ok'] == true);
    final result = {'checks': checks, 'ok': allOk};
    final output = context.output;
    if (output.json) {
      output.emit(action, result);
      throw ExitWith(allOk ? 0 : ExitKind.general.code);
    }
    for (final item in checks) {
      final ok = item['ok'] == true;
      output.line(
        '${ok ? output.green('ok  ') : output.red('fail')}  ${'${item['name']}'.padRight(15)} ${item['detail']}',
      );
      if (!ok && item['fix'] != null) {
        output.line('      ${''.padRight(15)} ${output.dim('Fix: ${item['fix']}')}');
      }
    }
    throw ExitWith(allOk ? 0 : ExitKind.general.code);
  }

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
    final environment = _CliMcpEnvironment(context, rt);
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

class _CliMcpEnvironment implements McpEnvironment {
  new(this._context, this._runtime);

  final CliContext _context;
  final WarpgateRuntime _runtime;
  late AppSettings _settings;
  late final _workbench = _IpcWorkbench(_context);
  late final _transfers = _LocalTransfers(_runtime);
  late final InteractionBroker _broker = _approvals();

  Future<void> settle() async => _settings = await _runtime.settings.load();

  InteractionBroker _approvals() {
    final broker = InteractionBroker()..attach();
    broker.requests.listen((request) {
      unawaited(() async {
        if (request is! ApprovalRequest) {
          request.dismiss();
          return;
        }
        final client = await _context.client();
        if (client == null) {
          request.dismiss();
          return;
        }
        try {
          final reply = await client.call('approve', {
            'source': request.source,
            'action': request.action,
            'target': request.target,
            'detail': request.detail,
          });
          request.respond(reply['approved'] == true);
        } on Object {
          request.dismiss();
        }
      }());
    });
    return broker;
  }

  @override
  HostsCatalog get catalog => _runtime.hosts.catalog;

  @override
  Future<void> get ready async {
    await _runtime.loadCatalog();
    await settle();
    await _workbench.refresh();
  }

  @override
  AppSettings get settings => _settings;

  @override
  ConnectionPool get pool => _runtime.pool;

  @override
  EndpointResolver get endpoints => _runtime.endpoints;

  @override
  InteractionBroker get broker => _broker;

  @override
  McpWorkbench get workbench => _workbench;

  @override
  McpTransfers get transfers => _transfers;

  @override
  Future<void> log(McpActivity entry) async {
    await _runtime.store.put('mcp_activity', entry.id, entry.toJson(), at: entry.at);
    await _runtime.store.trim('mcp_activity', 500);
  }
}

class _IpcWorkbench implements McpWorkbench {
  new(this._context);

  final CliContext _context;
  List<JsonMap> _sessions = const [];
  List<JsonMap> _workspaces = const [];

  static const _needsApp = ToolFailure(
    'This needs the Warpgate app, and it is not running. Ask the user to open it',
  );

  Future<JsonMap> _action(String name, JsonMap args) async {
    final client = await _context.client();
    if (client == null) throw _needsApp;
    return client.call('action', {'name': name, 'args': args});
  }

  Future<void> refresh() async {
    final client = await _context.client();
    if (client == null) {
      final stored = await _context.store.get('workbench', 'state');
      final active = stored?['activeWorkspaceId'];
      _workspaces = [
        for (final item in (stored?['workspaces'] as List?) ?? const <Object?>[])
          if (item is Map)
            {
              'id': item['id'],
              'name': item['name'],
              'active': item['id'] == active,
              'tabs': (item['tabs'] as List?)?.length ?? 0,
            },
      ];
      _sessions = const [];
      return;
    }
    final sessions = await client.call('action', {'name': 'sessions.list', 'args': const <String, Object?>{}});
    _sessions = ((sessions['sessions'] as List?) ?? const <Object?>[]).cast<JsonMap>();
    final workspaces = await client.call('action', {'name': 'workspaces.list', 'args': const <String, Object?>{}});
    _workspaces = ((workspaces['workspaces'] as List?) ?? const <Object?>[]).cast<JsonMap>();
  }

  JsonMap? _find(String id) {
    for (final session in _sessions) {
      if (session['session_id'] == id) return session;
    }
    return null;
  }

  @override
  List<JsonMap> workspaces() => _workspaces;

  @override
  List<JsonMap> sessions() => _sessions;

  @override
  Future<String> openSession(String hostId, {String? workspaceId}) async {
    final result = await _action('sessions.open', {
      'host': hostId,
      'workspace': ?workspaceId,
      '_origin': 'claude_code',
    });
    return result['session_id']! as String;
  }

  @override
  Future<void> closeSession(String id) => _action('sessions.close', {'session': id});

  @override
  String? hostOfSession(String id) => _find(id)?['host_id'] as String?;

  @override
  String? titleOfSession(String id) => _find(id)?['host_label'] as String?;

  @override
  Future<String?> readSession(String id, int lines) async {
    final result = await _action('sessions.read', {'session': id, 'lines': '$lines'});
    return result['text'] as String?;
  }

  @override
  Future<bool> sendToSession(String id, String text) async {
    await _action('sessions.send', {'session': id, 'text': text});
    return true;
  }

  @override
  bool sessionIsLive(String id) => _find(id) != null;
}

class _LocalTransfers implements McpTransfers {
  new(WarpgateRuntime runtime) : _queue = CopyCommands.scheduler(runtime);

  final TransferScheduler _queue;

  @override
  List<TransferJob> get jobs => _queue.jobs;

  @override
  TransferJob? byId(String id) => _queue.byId(id);

  @override
  void cancel(String id) => _queue.cancel(id);

  @override
  String enqueue({
    required TransferRef source,
    required TransferRef target,
    required String name,
    required bool isDirectory,
  }) {
    final id = _queue.enqueue(
      source: source,
      target: target,
      name: name,
      isDirectory: isDirectory,
      origin: 'claude_code',
      ownerPid: pid,
      start: false,
    );
    unawaited(_queue.run(id, policy: ConflictPolicy.overwrite));
    return id;
  }
}
