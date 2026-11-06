import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import 'package:warpgate_cli/src/args.dart';
import 'package:warpgate_cli/src/commands/connect.dart';
import 'package:warpgate_cli/src/commands/copy.dart';
import 'package:warpgate_cli/src/commands/misc.dart';
import 'package:warpgate_cli/src/completion.dart';
import 'package:warpgate_cli/src/help.dart';
import 'package:warpgate_cli/src/output.dart';
import 'package:warpgate_cli/src/prompts.dart';
import 'package:warpgate_cli/src/secrets/cli_secrets.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/sqlite_document_store.dart';
import 'package:warpgate_core/features/connection/data/disk_keys.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/interaction/interaction_broker.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/ipc/ipc.dart';

class ExitWith implements Exception {
  const new(this.code);

  final int code;
}

typedef LocalCommand = Future<JsonMap?> Function(CliContext context, ActionSpec action, JsonMap args);

class CliContext {
  new(this.globals, this.output, this.paths)
    : prompter = Prompter(output, assumeYes: globals.yes);

  final GlobalOptions globals;
  final Output output;
  final AppPaths paths;
  final Prompter prompter;
  SqliteDocumentStore? _store;
  WarpgateRuntime? _runtime;
  IpcClient? _client;
  bool _triedClient = false;

  SqliteDocumentStore get store => _store ??= SqliteDocumentStore.open(paths.database);

  Future<IpcClient?> client() async {
    if (globals.noApp) return null;
    if (_triedClient) return _client;
    _triedClient = true;
    _client = await IpcClient.connect(paths);
    return _client;
  }

  Future<WarpgateRuntime> runtime() async {
    final known = _runtime;
    if (known != null) return known;
    final broker = InteractionBroker();
    prompter.attach(broker);
    final runtime = WarpgateRuntime(
      store: store,
      secrets: CliSecrets(store: store, paths: paths, client: client),
      broker: broker,
      fallbackIdentities: _diskIdentities,
      fallbackKeys: (_) async => DiskKeys.pems(),
    );
    await runtime.loadCatalog();
    return _runtime = runtime;
  }

  static Future<List<SSHIdentity>> _diskIdentities(Host host) async => DiskKeys.identities();

  Future<IpcClient> requireApp(ActionSpec action) async {
    final existing = await client();
    if (existing != null) return existing;
    if (globals.noApp) {
      throw ActionFailure(
        'warpgate ${action.cli} needs the app',
        hint: 'Leave out --no-app, or open Warpgate',
      );
    }
    if (await AppInstance.isRunning(paths)) {
      throw ActionFailure(
        'Warpgate is running, but its command line connection is not answering',
        hint: 'Quit and reopen Warpgate. If it stays, run warpgate doctor',
      );
    }
    final started = await startApp(this);
    _triedClient = false;
    if (started) {
      for (var attempt = 0; attempt < 40; attempt++) {
        final connected = await IpcClient.connect(paths);
        if (connected != null) {
          _client = connected;
          _triedClient = true;
          return connected;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    throw ActionFailure(
      'warpgate ${action.cli} needs the app, and it could not be started',
      hint: 'Open Warpgate, then run this again',
    );
  }

  Future<void> close() async {
    await _runtime?.close();
    await _client?.close();
    _store?.close();
  }
}

abstract final class CustomOutput {
  static bool render(CliContext context, ActionSpec action, JsonMap result) {
    final output = context.output;
    if (output.json || action.name != 'files.ls') return false;
    if (result['_long'] == true) return false;
    for (final item in (result['entries']! as List).cast<JsonMap>()) {
      final depth = (item['depth'] as int?) ?? 0;
      final folder = item['type'] == 'directory' ? '/' : '';
      output.line('${'  ' * depth}${item['name']}$folder');
    }
    return true;
  }
}

abstract final class Dispatch {
  static final Map<String, LocalCommand> local = {
    ...ConnectCommands.all,
    ...CopyCommands.all,
    ...MiscCommands.all,
  };

  static bool hasHandler(ActionSpec action) =>
      action.mode == ActionMode.app ||
      local.containsKey(action.name) ||
      ActionHandlers.all.containsKey(action.name);
}

Future<int> runCli(List<String> arguments) async {
  final bootstrap = _Bootstrap.from(arguments);
  if (arguments.isNotEmpty && arguments.first == '__complete') {
    return Completion.run(arguments.sublist(1));
  }
  ParsedCommand parsed;
  try {
    parsed = ArgParser.parse(arguments);
  } on ActionFailure catch (failure) {
    bootstrap.output.failure(failure);
    return failure.kind.code;
  }
  final globals = parsed.globals;
  final output = Output(
    json: globals.json,
    quiet: globals.quiet,
    noColor: globals.noColor,
    verbose: globals.verbose,
  );
  if (globals.version) {
    if (globals.json) {
      output.emit(ActionRegistry.byName['version']!, {'version': Help.version, 'schema_version': 1});
    } else {
      output.line('warpgate ${Help.version}');
    }
    return 0;
  }
  final action = parsed.action;
  if (action == null) {
    output.write(parsed.group == null ? Help.root() : Help.forGroup(parsed.group!));
    return 0;
  }
  if (globals.help) {
    output.write(Help.forAction(action));
    return 0;
  }
  final context = CliContext(
    globals,
    output,
    AppPaths.resolve(profile: globals.profile),
  );
  final completer = Completer<int>();
  StreamSubscription<ProcessSignal>? interrupt;
  if (!action.passthrough) {
    interrupt = ProcessSignal.sigint.watch().listen((_) {
      if (!completer.isCompleted) completer.complete(ExitKind.interrupted.code);
    });
  }
  unawaited(
    _run(context, action, Map.of(parsed.values)).then((code) {
      if (!completer.isCompleted) completer.complete(code);
    }),
  );
  final code = await completer.future;
  await interrupt?.cancel();
  try {
    await context.close().timeout(const Duration(seconds: 2));
  } on Object catch (error) {
    output.debug('Could not close cleanly: $error');
  }
  return code;
}

class _Bootstrap {
  const new(this.output);

  factory from(List<String> arguments) => _Bootstrap(
    Output(
      json: arguments.contains('--json'),
      quiet: arguments.contains('--quiet'),
      noColor: arguments.contains('--no-color'),
      verbose: false,
    ),
  );

  final Output output;
}

Future<int> _run(CliContext context, ActionSpec action, JsonMap args) async {
  try {
    _absolutePaths(action, args);
    await _confirm(context, action, args);
    final result = await execute(context, action, args);
    if (result != null) {
      if (!CustomOutput.render(context, action, result)) {
        context.output.render(action, result);
      }
    }
    return 0;
  } on ExitWith catch (exit) {
    return exit.code;
  } on Object catch (error) {
    final failure = context.prompter.hostKeyRejected
        ? ActionFailure(
            'The host key was not trusted',
            kind: ExitKind.hostKey,
            hint: 'Check it, then run warpgate known-hosts trust <host>',
          )
        : Failures.classify(error);
    context.output.failure(failure);
    return failure.kind.code;
  }
}

void _absolutePaths(ActionSpec action, JsonMap args) {
  for (final arg in action.positionals) {
    if (arg.complete != CompletionKind.localPath) continue;
    final value = args[arg.name];
    if (value is String && value != '-' && !value.startsWith('~')) {
      args[arg.name] = p.absolute(value);
    }
  }
}

Future<void> _confirm(CliContext context, ActionSpec action, JsonMap args) async {
  final template = action.confirm;
  if (template == null || context.globals.yes) return;
  final question = Output.fill(
    template,
    {'key': 'all settings', ...args},
  );
  if (!context.prompter.interactive) {
    throw ActionFailure(
      'This changes or deletes data, so it needs confirmation',
      kind: ExitKind.usage,
      hint: 'Add --yes to run it without a prompt',
    );
  }
  if (!context.prompter.confirm(question)) {
    throw const ExitWith(1);
  }
}

Future<JsonMap?> execute(CliContext context, ActionSpec action, JsonMap args) async {
  final prepared = await MiscCommands.prepare(context, action, args);
  if (action.mode == ActionMode.app) {
    final client = await context.requireApp(action);
    return client.call('action', {'name': action.name, 'args': prepared});
  }
  if (action.mode == ActionMode.prefersApp) {
    final client = await context.client();
    if (client != null) {
      return client.call('action', {'name': action.name, 'args': prepared});
    }
  }
  final custom = Dispatch.local[action.name];
  if (custom != null) return custom(context, action, prepared);
  final handler = ActionHandlers.all[action.name];
  if (handler == null) {
    throw ActionFailure('warpgate ${action.cli} is not available in this build');
  }
  final runtime = await context.runtime();
  final result = await handler(
    ActionCall(runtime, prepared, confirm: (message) async => context.prompter.confirm(message)),
  );
  if (action.name == 'files.ls' && prepared['long'] == true && !context.output.json) {
    result['_long'] = true;
  }
  if (action.name == 'hosts.list') await _overlayStatus(context, result);
  return result;
}

Future<void> _overlayStatus(CliContext context, JsonMap result) async {
  final client = await context.client();
  if (client == null) return;
  try {
    final statuses = await client.call('link.statuses');
    for (final host in (result['hosts']! as List).cast<JsonMap>()) {
      final status = statuses[host['id']];
      if (status is String) host['status'] = status;
    }
  } on Object catch (error) {
    context.output.debug('Could not read link status from the app: $error');
  }
}

Future<bool> startApp(CliContext context) async {
  final executable = Platform.resolvedExecutable;
  final directory = p.dirname(executable);
  final environment = <String, String>{
    if (context.paths.profile != null) 'WARPGATE_PROFILE': context.paths.profile!,
    if (Platform.environment['WARPGATE_HOME'] case final home?) 'WARPGATE_HOME': home,
  };
  context.output.note('Starting Warpgate');
  try {
    if (Platform.isMacOS) {
      final contents = p.dirname(directory);
      final bundle = p.basename(p.dirname(contents)).endsWith('.app')
          ? p.dirname(contents)
          : null;
      final result = await Process.run('open', [
        for (final MapEntry(:key, :value) in environment.entries) ...['--env', '$key=$value'],
        if (bundle != null) bundle else ...['-b', 'eu.kwilex.warpgate'],
      ]);
      return result.exitCode == 0;
    }
    final name = Platform.isWindows ? 'warpgate.exe' : 'warpgate';
    final bundled = p.join(directory, name);
    if (!File(bundled).existsSync()) return false;
    await Process.start(bundled, const [], mode: ProcessStartMode.detached, environment: environment);
    return true;
  } on Object catch (error) {
    context.output.debug('Could not start the app: $error');
    return false;
  }
}
