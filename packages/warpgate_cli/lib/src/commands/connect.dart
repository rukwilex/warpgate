import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_cli/src/args.dart';
import 'package:warpgate_cli/src/cli.dart';
import 'package:warpgate_cli/src/terminal.dart';
import 'package:warpgate_core/actions/handlers.dart';
import 'package:warpgate_core/actions/registry.dart';
import 'package:warpgate_core/actions/runtime.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/features/connection/data/port_forwarder.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/multi_exec/data/multi_exec_runner.dart';

abstract final class ConnectCommands {
  static final Map<String, LocalCommand> all = {
    'ssh': _ssh,
    'exec': _exec,
    'snippets.run': _snippetRun,
  };

  static Future<JsonMap?> _ssh(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    var host = rt.host(args['host']! as String);
    final jump = args['jump'] as String?;
    if (jump != null) {
      final via = rt.host(jump);
      host = host.copyWith(jumpHostId: () => via.id);
      rt.remember(host);
    }
    final client = await rt.pool.client(host.id);
    rt.pool.retain(host.id);
    await _startForwards(context, rt, host, args);
    final words = ((args['command'] as List?) ?? const <Object?>[]).cast<String>();
    final tmux = args['tmux'] == true;
    final remote = words.isNotEmpty
        ? words.join(' ')
        : tmux
        ? 'tmux new-session -A -s warpgate'
        : null;
    if (remote == null) {
      throw ExitWith(await _shell(client));
    }
    if (tmux && words.isEmpty) {
      throw ExitWith(await _shell(client, command: remote));
    }
    throw ExitWith(await _stream(client, remote));
  }

  static Future<List<ActiveForward>> _startForwards(
    CliContext context,
    WarpgateRuntime rt,
    Host host,
    JsonMap args,
  ) async {
    final specs = <PortForwardSpec>[
      for (final (kind, flag) in const [
        ('local', 'local-forward'),
        ('remote', 'remote-forward'),
        ('dynamic', 'dynamic-forward'),
      ])
        for (final value in ((args[flag] as List?) ?? const <Object?>[]).cast<String>())
          ForwardSpecs.parse(kind, value),
    ];
    final started = <ActiveForward>[];
    for (final spec in specs) {
      await rt.forwarder.start(host.id, spec);
      final state = rt.forwarder.forwards.firstWhere((item) => item.spec.id == spec.id);
      if (state.state == ForwardState.failed) {
        throw ActionFailure('Could not start the forward on port ${spec.bindPort}: ${state.error}', kind: ExitKind.connection);
      }
      context.output.note('Forwarding ${spec.kind.name} port ${spec.bindPort}');
      started.add(state);
    }
    return started;
  }

  static Future<int> _shell(SSHClient client, {String? command}) async {
    final columns = stdout.hasTerminal ? stdout.terminalColumns : 80;
    final rows = stdout.hasTerminal ? stdout.terminalLines : 24;
    final pty = SSHPtyConfig(
      type: Platform.environment['TERM'] ?? 'xterm-256color',
      width: columns,
      height: rows,
    );
    final session = command == null
        ? await client.shell(pty: pty)
        : await client.execute(command, pty: pty);
    final raw = RawTerminal()..enter();
    StreamSubscription<ProcessSignal>? resize;
    Timer? poller;
    var lastColumns = columns;
    var lastRows = rows;
    void update() {
      if (!stdout.hasTerminal) return;
      final nextColumns = stdout.terminalColumns;
      final nextRows = stdout.terminalLines;
      if (nextColumns == lastColumns && nextRows == lastRows) return;
      lastColumns = nextColumns;
      lastRows = nextRows;
      session.resizeTerminal(nextColumns, nextRows);
    }

    if (Platform.isWindows) {
      poller = Timer.periodic(const Duration(milliseconds: 500), (_) => update());
    } else {
      resize = ProcessSignal.sigwinch.watch().listen((_) => update());
    }
    final input = stdin.listen(
      (bytes) => session.write(Uint8List.fromList(bytes)),
      onDone: () {
        if (!stdin.hasTerminal) session.stdin.close();
      },
    );
    final signals = <StreamSubscription<ProcessSignal>>[
      ProcessSignal.sigint.watch().listen((_) => session.write(Uint8List.fromList([3]))),
      if (!Platform.isWindows)
        ProcessSignal.sigterm.watch().listen((_) => session.close()),
    ];
    try {
      final outDone = session.stdout.forEach(stdout.add);
      final errDone = session.stderr.forEach(stderr.add);
      await session.done;
      await Future.wait([outDone, errDone]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => const [],
      );
      return session.exitCode ?? 0;
    } finally {
      raw.leave();
      await input.cancel();
      await resize?.cancel();
      poller?.cancel();
      for (final signal in signals) {
        await signal.cancel();
      }
    }
  }

  static Future<int> _stream(SSHClient client, String command, {Duration? timeout}) async {
    final session = await client.execute(command);
    final outDone = session.stdout.forEach(stdout.add);
    final errDone = session.stderr.forEach(stderr.add);
    StreamSubscription<List<int>>? input;
    if (!stdin.hasTerminal) {
      input = stdin.listen(
        (bytes) => session.write(Uint8List.fromList(bytes)),
        onDone: session.stdin.close,
      );
    }
    final interrupt = ProcessSignal.sigint.watch().listen((_) {
      session.close();
    });
    try {
      final int? code;
      try {
        code = await session.waitForExit(timeout: timeout);
      } on TimeoutException {
        session.close();
        throw ActionFailure('The command did not finish in ${timeout!.inSeconds} s');
      }
      await Future.wait([outDone, errDone]).timeout(
        const Duration(seconds: 2),
        onTimeout: () => const [],
      );
      return code ?? ExitKind.general.code;
    } finally {
      await input?.cancel();
      await interrupt.cancel();
    }
  }

  static JsonMap _runJson(Host host, ExecResult result) => {
    'host': host.label,
    'exit_code': result.exitCode,
    'stdout': result.stdout,
    'stderr': result.stderr,
    'duration_ms': result.duration.inMilliseconds,
    'timed_out': result.timedOut,
    'error': result.error,
  };

  static Future<JsonMap?> _exec(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    final hosts = rt.many(args['targets']! as String);
    final command = (args['command']! as List).cast<String>().join(' ');
    final timeout = Durations.parse(args['timeout'] as String?);
    return _runOn(
      context,
      action,
      rt,
      hosts,
      command,
      timeout: timeout,
      parallel: int.tryParse('${args['parallel']}') ?? MultiExecRunner.defaultParallelism,
      stopOnFailure: args['stop-on-failure'] == true,
    );
  }

  static Future<JsonMap?> _runOn(
    CliContext context,
    ActionSpec action,
    WarpgateRuntime rt,
    List<Host> hosts,
    String command, {
    required int parallel,
    Duration? timeout,
    bool stopOnFailure = false,
  }) async {
    final output = context.output;
    if (hosts.length == 1 && !output.json) {
      final client = await rt.pool.client(hosts.single.id);
      throw ExitWith(await _stream(client, command, timeout: timeout));
    }
    if (hosts.length == 1) {
      await rt.pool.client(hosts.single.id);
    }
    final run = await MultiExecRunner(rt.pool).run(
      command,
      [for (final host in hosts) host.id],
      timeout: timeout ?? const Duration(seconds: 60),
      parallelism: stopOnFailure ? 1 : parallel.clamp(1, 256),
      stopOnFailure: stopOnFailure,
    );
    final results = <JsonMap>[];
    var failed = 0;
    var succeeded = 0;
    for (final host in hosts) {
      final state = run.runs[host.id]!;
      final result = state.result;
      if (result == null) {
        failed++;
        results.add(
          _runJson(host, ExecResult.failure('Not run, an earlier host failed', Duration.zero)),
        );
        continue;
      }
      if (result.succeeded) {
        succeeded++;
      } else {
        failed++;
      }
      results.add(_runJson(host, result));
    }
    final summary = {'results': results, 'succeeded': succeeded, 'failed': failed};
    if (output.json) {
      output.emit(action, summary);
    } else {
      for (final item in results) {
        final code = item['exit_code'];
        final ok = code == 0 && item['error'] == null && item['timed_out'] != true;
        final detail = item['error'] ?? (item['timed_out'] == true ? 'timed out' : 'exit $code');
        output.line(
          ok
              ? output.green('${item['host']}')
              : '${output.red('${item['host']}')} ${output.dim('$detail')}',
        );
        final out = (item['stdout']! as String).trimRight();
        final err = (item['stderr']! as String).trimRight();
        if (out.isNotEmpty) output.line(out);
        if (err.isNotEmpty) output.line(err);
      }
      output.note('$succeeded succeeded, $failed failed');
    }
    if (hosts.length == 1) {
      final code = results.single['exit_code'];
      throw ExitWith(code is int ? code : ExitKind.connection.code);
    }
    if (failed > 0) throw ExitWith(ExitKind.partial.code);
    throw const ExitWith(0);
  }

  static Future<JsonMap?> _snippetRun(CliContext context, ActionSpec action, JsonMap args) async {
    final rt = await context.runtime();
    final snippet = await ActionHandlers.findSnippet(rt, args['snippet']! as String);
    final values = <String, String>{};
    for (final pair in ((args['var'] as List?) ?? const <Object?>[]).cast<String>()) {
      final equals = pair.indexOf('=');
      if (equals <= 0) {
        throw ActionFailure('Could not read "$pair". Use key=value', kind: ExitKind.usage);
      }
      values[pair.substring(0, equals)] = pair.substring(equals + 1);
    }
    for (final variable in snippet.variables) {
      if (values.containsKey(variable.name) || variable.fallback != null) continue;
      final answer = context.prompter.ask('${variable.name}:');
      if (answer == null) {
        throw ActionFailure(
          'The snippet needs a value for ${variable.name}',
          kind: ExitKind.usage,
          hint: 'Pass --var ${variable.name}=value',
        );
      }
      values[variable.name] = answer;
    }
    return _runOn(
      context,
      action,
      rt,
      rt.many(args['on']! as String),
      snippet.render(values),
      timeout: Durations.parse(args['timeout'] as String?),
      parallel: int.tryParse('${args['parallel']}') ?? MultiExecRunner.defaultParallelism,
    );
  }
}
