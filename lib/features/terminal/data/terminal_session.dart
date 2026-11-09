import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:warpgate/features/terminal/data/terminal_ingest.dart';
import 'package:warpgate/features/terminal/domain/terminal_geometry.dart';
import 'package:warpgate/features/terminal/domain/terminal_reflow.dart';
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/core/diagnostics/watchdog.dart';
import 'package:warpgate_core/core/platform/native.dart';
import 'package:warpgate_core/features/connection/data/connection_pool.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/link_state.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:xterm/xterm.dart';

abstract interface class TerminalBackend {
  int? get pid;
  Stream<Uint8List> get output;
  Future<void> get done;
  bool get connectionLost;
  void write(Uint8List data);
  void resize(int columns, int rows);
  void acknowledge();
  void close();
}

class SshShellBackend implements TerminalBackend {
  new(this._client, this._session);

  final SshClient _client;
  final SshSession _session;

  @override
  int? get pid => null;

  @override
  Stream<Uint8List> get output =>
      StreamGroup.merge([_session.stdout, _session.stderr]);

  @override
  Future<void> get done => _session.done;

  @override
  bool get connectionLost => _client.isClosed;

  @override
  void write(Uint8List data) => _session.write(data);

  @override
  void resize(int columns, int rows) => _session.resizeTerminal(columns, rows);

  @override
  void acknowledge() {}

  @override
  void close() => _session.close();
}

class LocalPtyBackend implements TerminalBackend {
  new(this._pty);

  final Pty _pty;

  @override
  int? get pid => _pty.pid;

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<void> get done => _pty.exitCode;

  @override
  bool get connectionLost => false;

  @override
  void write(Uint8List data) => _pty.write(data);

  @override
  void resize(int columns, int rows) => _pty.resize(rows, columns);

  bool _closing = false;

  @override
  void acknowledge() {
    if (!_closing) _pty.ackRead();
  }

  @override
  void close() {
    if (_closing) return;
    _closing = true;
    LiveObjects.opened('closing local shell');
    if (!Platform.isWindows && !Native.signalGroup(_pty.pid, 1)) {
      _pty.kill(ProcessSignal.sighup);
    }
    _pty.close();
    final killer = Timer(const Duration(seconds: 3), () {
      if (Platform.isWindows || !Native.signalGroup(_pty.pid, 9)) {
        _pty.kill(Platform.isWindows ? ProcessSignal.sigterm : ProcessSignal.sigkill);
      }
    });
    unawaited(
      _pty.exitCode.whenComplete(() {
        killer.cancel();
        LiveObjects.closed('closing local shell');
      }),
    );
  }
}

abstract final class StreamGroup {
  static Stream<T> merge<T>(List<Stream<T>> streams) {
    late final StreamController<T> controller;
    final subscriptions = <StreamSubscription<T>>[];
    var open = streams.length;
    controller = StreamController<T>(
      onListen: () {
        for (final stream in streams) {
          subscriptions.add(
            stream.listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                open -= 1;
                if (open == 0) unawaited(controller.close());
              },
            ),
          );
        }
      },
      onPause: () {
        for (final s in subscriptions) {
          s.pause();
        }
      },
      onResume: () {
        for (final s in subscriptions) {
          s.resume();
        }
      },
      onCancel: () => Future.wait(subscriptions.map((s) => s.cancel())),
    );
    return controller.stream;
  }
}

enum FolderHookResult { installed, unsupported, failed }

enum FolderShell {
  bash('~/.bashrc'),
  zsh('~/.zshrc'),
  fish('~/.config/fish/conf.d/warpgate.fish');

  new(this.rcFile);

  final String rcFile;

  static FolderShell? parse(String name) =>
      values.where((shell) => shell.name == name).firstOrNull;

  String get hook => switch (this) {
    FolderShell.bash => r'__wg_osc7() { printf "\033]7;file://%s%s\033\\" "${HOSTNAME:-$(hostname)}" "$PWD"; }; [[ "$PROMPT_COMMAND" == *__wg_osc7* ]] || PROMPT_COMMAND="__wg_osc7${PROMPT_COMMAND:+;$PROMPT_COMMAND}"',
    FolderShell.zsh => r'__wg_osc7() { printf "\033]7;file://%s%s\033\\" "$HOST" "$PWD"; }; autoload -Uz add-zsh-hook && add-zsh-hook precmd __wg_osc7',
    FolderShell.fish => r'function __wg_osc7 --on-event fish_prompt; printf "\e]7;file://%s%s\e\\" (hostname) $PWD; end',
  };
}

abstract final class FolderTracking {
  static const paneVariable = 'LC_WARPGATE_PANE';

  static final _osc7 = RegExp(
    r'\x1b\]7;file://[^/\x07\x1b]*(/[^\x07\x1b]*)(?:\x07|\x1b\\)',
  );

  static String? parseOsc7(String data) {
    final matches = _osc7.allMatches(data);
    if (matches.isEmpty) return null;
    final raw = matches.last.group(1)!;
    try {
      return Uri.decodeComponent(raw);
    } on Object {
      return raw;
    }
  }

  static String? parseLsof(String output) {
    for (final line in output.split('\n')) {
      if (line.startsWith('n/')) return line.substring(1);
    }
    return null;
  }

  static String procScript(String paneId) {
    final needle = KeyCodec.shellQuote('$paneVariable=$paneId');
    const find = '/proc/[0-9]*/environ 2>/dev/null | cut -d/ -f3); ';
    const pick =
        r'for p in $ids; do pp=$(cut -d" " -f4 /proc/$p/stat 2>/dev/null); '
        r'case " $ids " in *" $pp "*) ;; *) readlink /proc/$p/cwd; exit 0;; esac; done';
    return '${r'ids=$(grep -lzx '}$needle $find$pick';
  }

  static String installScript(FolderShell shell) {
    final rc = shell.rcFile.replaceFirst('~', r'$HOME');
    final line = KeyCodec.shellQuote(shell.hook);
    return 'mkdir -p "\$(dirname "$rc")" && touch "$rc" && '
        '(grep -q __wg_osc7 "$rc" || printf "\\n%s\\n" $line >> "$rc")';
  }
}

sealed class SessionTarget {
  const new();
}

class SshTarget extends SessionTarget {
  const new({required this.host, this.tmuxSession, this.directory});

  final Host host;
  final String? tmuxSession;
  final String? directory;
}

class LocalTarget extends SessionTarget {
  const new({this.directory});

  final String? directory;
}

typedef InputSink = void Function(TerminalSession origin, String data);

class TerminalSession extends IngestSink {
  new({
    required this.id,
    required this._target,
    required this._pool,
    this.maxLines = 10000,
    this.autoReconnect = true,
    this.resizeInterval = const Duration(milliseconds: 80),
    this.openBackend,
    String? restoredScrollback,
  }) : terminal = Terminal(maxLines: maxLines) {
    terminal
      ..reflowEnabled = false
      ..onOutput = _handleUserInput
      ..onResize = _handleResize
      ..onTitleChange = (value) => title.value = value;
    LiveObjects.opened('terminal session');
    if (restoredScrollback != null && restoredScrollback.isNotEmpty) {
      terminal.write(
        '\x1b[2m${restoredScrollback.replaceAll('\n', '\r\n')}\x1b[0m\r\n',
      );
    }
  }

  final String id;
  final int maxLines;
  final bool autoReconnect;
  final Duration resizeInterval;
  final Future<TerminalBackend> Function()? openBackend;
  final Terminal terminal;
  late final _resizeThrottle = ResizeThrottle(
    interval: resizeInterval,
    send: (columns, rows) {
      _columns = columns;
      _rows = rows;
      _backend?.resize(columns, rows);
    },
  );
  final ConnectionPool _pool;
  final SessionTarget _target;

  final status = ValueNotifier<LinkStatus>(LinkStatus.idle);
  final notice = ValueNotifier<String?>(null);
  final title = ValueNotifier<String?>(null);
  final cwd = ValueNotifier<String?>(null);

  InputSink? inputSink;
  String Function(String data)? inputModifier;

  TerminalBackend? _backend;
  StreamSubscription<Uint8List>? _output;
  bool _ackOwed = false;
  late final _queue = IngestQueue(
    write: _handleRemoteOutput,
    onHigh: () => _output?.pause(),
    onLow: () {
      final output = _output;
      if (output != null && output.isPaused) output.resume();
      if (_ackOwed) {
        _ackOwed = false;
        _backend?.acknowledge();
      }
    },
  );

  int get pendingBytes => _queue.pendingBytes;

  bool get throttled => _queue.throttled;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _userClosed = false;
  int _attempt = 0;
  int _generation = 0;
  int _columns = 80;
  int _rows = 24;
  bool _retained = false;

  SessionTarget get target => _target;

  String? get hostId => switch (_target) {
    SshTarget(:final host) => host.id,
    LocalTarget() => null,
  };

  bool get isRunning => _backend != null;

  Future<void> start() async {
    if (_disposed || _backend != null) return;
    _userClosed = false;
    _retryTimer?.cancel();
    final generation = ++_generation;
    _setStatus(
      LinkStatus(
        _attempt == 0 ? LinkState.connecting : LinkState.reconnecting,
        attempt: _attempt,
      ),
    );
    try {
      final backend = await _open();
      if (_disposed || generation != _generation) {
        backend.close();
        return;
      }
      _backend = backend;
      _attempt = 0;
      backend.resize(terminal.viewWidth, terminal.viewHeight);
      _output = backend.output.listen(_receive);
      _setStatus(const LinkStatus(LinkState.connected));
      unawaited(
        backend.done.then(
          (_) => _handleEnded(backend),
          onError: (_) => _handleEnded(backend),
        ),
      );
    } on Object catch (error) {
      if (generation == _generation) _handleFailure(error);
    }
  }

  Future<TerminalBackend> _open() async {
    final custom = openBackend;
    if (custom != null) return await custom();
    switch (_target) {
      case LocalTarget(:final directory):
        final shell =
            Platform.environment['SHELL'] ??
            (Platform.isWindows ? 'powershell.exe' : '/bin/bash');
        _columns = terminal.viewWidth;
        _rows = terminal.viewHeight;
        final pty = Pty.start(
          shell,
          arguments: Platform.isWindows ? const [] : const ['-l'],
          workingDirectory: directory ?? Platform.environment['HOME'],
          environment: {...Platform.environment, 'TERM': 'xterm-256color'},
          columns: _columns,
          rows: _rows,
          ackRead: true,
        );
        return LocalPtyBackend(pty);
      case SshTarget(:final host, :final tmuxSession, :final directory):
        final client = await _pool.client(host.id);
        _columns = terminal.viewWidth;
        _rows = terminal.viewHeight;
        if (!_retained) {
          _pool.retain(host.id);
          _retained = true;
        }
        final pty = SSHPtyConfig(width: _columns, height: _rows);
        if (tmuxSession != null) {
          final probe = await _pool.exec(
            host.id,
            'command -v tmux',
            timeout: const Duration(seconds: 8),
          );
          if (probe.succeeded && probe.stdout.trim().isNotEmpty) {
            notice.value = null;
            final dir = directory == null
                ? ''
                : ' -c ${KeyCodec.shellQuote(directory)}';
            final session = await client.execute(
              'tmux new-session -A -s ${KeyCodec.shellQuote(tmuxSession)}$dir',
              pty: pty,
            );
            return SshShellBackend(client, session);
          }
          notice.value =
              'tmux is not installed on ${host.label}, so this pane uses a plain shell. Programs stop when the connection drops.';
        }
        final SshSession session;
        try {
          session = await client.shell(
            pty: pty,
            environment: {FolderTracking.paneVariable: id},
          );
        } on SSHChannelRequestError {
          return await _plainShell(client, pty, host, directory);
        }
        final backend = SshShellBackend(client, session);
        final start = directory ?? host.startDirectory;
        if (start != null && start.isNotEmpty) {
          backend.write(utf8.encode('cd ${KeyCodec.shellQuote(start)}\r'));
        }
        return backend;
    }
  }

  Future<TerminalBackend> _plainShell(
    SshClient client,
    SSHPtyConfig pty,
    Host host,
    String? directory,
  ) async {
    final backend = SshShellBackend(client, await client.shell(pty: pty));
    final start = directory ?? host.startDirectory;
    if (start != null && start.isNotEmpty) {
      backend.write(utf8.encode('cd ${KeyCodec.shellQuote(start)}\r'));
    }
    return backend;
  }

  void _receive(Uint8List data) {
    _queue.add(data);
    if (_queue.throttled) {
      _ackOwed = true;
    } else {
      _backend?.acknowledge();
    }
    TerminalIngest.instance.notify(this);
  }

  @override
  bool drainSome(int maxBytes) {
    if (_disposed) return false;
    _queue.take(maxBytes);
    return !_queue.isEmpty;
  }

  void _handleRemoteOutput(String data) {
    terminal.write(data);
    _trackDirectory(data);
  }

  void _trackDirectory(String data) {
    if (!data.contains('\x1b]7;')) return;
    final path = FolderTracking.parseOsc7(data);
    if (path == null) return;
    reportsFolder = true;
    cwd.value = path;
  }

  bool reportsFolder = false;

  Future<String?> probeFolder() async {
    try {
      switch (_target) {
        case SshTarget(:final host):
          if (_backend == null) return null;
          final result = await _pool.exec(
            host.id,
            FolderTracking.procScript(id),
            timeout: const Duration(seconds: 5),
          );
          final path = result.stdout.trim();
          return path.startsWith('/') ? path : null;
        case LocalTarget():
          final pid = _backend?.pid;
          if (pid == null) return null;
          if (Platform.isLinux) {
            return await Link('/proc/$pid/cwd').target();
          }
          if (Platform.isMacOS) {
            final result = await Process.run('lsof', [
              '-a',
              '-p',
              '$pid',
              '-d',
              'cwd',
              '-Fn',
            ]);
            return FolderTracking.parseLsof(result.stdout as String);
          }
          return null;
      }
    } on Object {
      return null;
    }
  }

  Future<String?> pollFolder() async {
    if (reportsFolder) return cwd.value;
    final path = await probeFolder();
    if (path != null && !_disposed && path != cwd.value) cwd.value = path;
    return path;
  }

  Future<FolderHookResult> installFolderHook({bool applyNow = true}) async {
    final target = _target;
    if (target is! SshTarget) return FolderHookResult.unsupported;
    final probe = await _pool.exec(
      target.host.id,
      r'basename "${SHELL:-sh}"',
      timeout: const Duration(seconds: 8),
    );
    final shell = FolderShell.parse(probe.stdout.trim());
    if (shell == null) return FolderHookResult.unsupported;
    final install = await _pool.exec(
      target.host.id,
      FolderTracking.installScript(shell),
      timeout: const Duration(seconds: 8),
    );
    if (!install.succeeded) return FolderHookResult.failed;
    if (applyNow && _backend != null) send(' ${shell.hook}\r');
    return FolderHookResult.installed;
  }

  void _handleUserInput(String data) {
    if (_backend == null) {
      if (data.contains('\r')) handleEnterWhileIdle();
      return;
    }
    final modifier = inputModifier;
    inputModifier = null;
    final text = modifier == null ? data : modifier(data);
    final sink = inputSink;
    if (sink != null) {
      sink(this, text);
    } else {
      send(text);
    }
  }

  void send(String data) =>
      _backend?.write(Uint8List.fromList(utf8.encode(data)));

  void paste(String text) => terminal.paste(text);

  void _handleResize(int columns, int rows, int pixelWidth, int pixelHeight) {
    if (_backend == null) {
      _columns = columns;
      _rows = rows;
    }
    _resizeThrottle.request(columns, rows);
  }

  List<int>? resize(int columns, int rows) {
    if (columns < TerminalGrid.minColumns || rows < TerminalGrid.minRows) {
      return null;
    }
    final oldWidth = terminal.viewWidth;
    if (columns == oldWidth && rows == terminal.viewHeight) return null;
    final main = terminal.mainBuffer;
    ReflowResult? result;
    if (columns != oldWidth) {
      final lines = main.lines;
      result = TerminalReflow.reflow(
        lines: [for (var i = 0; i < lines.length; i++) lines[i]],
        oldWidth: oldWidth,
        newWidth: columns,
        newHeight: rows,
        cursorX: main.cursorX,
        cursorRow: main.absoluteCursorY,
        maxLines: maxLines,
      );
    }
    terminal.resize(columns, rows);
    if (result != null) {
      main.lines.replaceWith(result.lines);
      main.setCursor(result.cursorX, result.cursorScreenY);
      Watchdog.during(Activity.terminalResize, main.compactScrollback);
      terminal.notifyListeners();
    }
    return result?.rowMap;
  }

  void settleSize() => _resizeThrottle.settle();

  void _handleEnded(TerminalBackend backend) {
    if (!identical(_backend, backend)) return;
    final lost = backend.connectionLost;
    if (!_disposed) _queue.flush();
    _teardown();
    if (_disposed) return;
    if (_userClosed) {
      _setStatus(LinkStatus.idle);
      return;
    }
    if (lost && autoReconnect && _target is SshTarget) {
      _pool.dropSftp(hostId!);
      _scheduleRetry('The connection dropped');
      return;
    }
    terminal.write(
      '\r\n\x1b[2m[session ended — press Enter to start again]\x1b[0m\r\n',
    );
    _setStatus(const LinkStatus(LinkState.idle, message: 'Session ended'));
  }

  void _handleFailure(Object error) {
    _teardown();
    if (_disposed) return;
    if (error is ConnectCancelledException) {
      _setStatus(const LinkStatus(LinkState.idle, message: 'Connecting was cancelled'));
      return;
    }
    final message = SshErrorText.describe(error);
    if (SshErrorText.isPermanent(error) ||
        !autoReconnect ||
        _target is LocalTarget) {
      _setStatus(LinkStatus(LinkState.dropped, message: message));
      return;
    }
    _scheduleRetry(message);
  }

  void _scheduleRetry(String message) {
    if (_attempt >= Backoff.maxAttempts) {
      _setStatus(
        LinkStatus(
          LinkState.dropped,
          message: '$message. Gave up after $_attempt attempts',
        ),
      );
      return;
    }
    final delay = Backoff.delay(_attempt);
    _attempt += 1;
    _setStatus(
      LinkStatus(
        LinkState.reconnecting,
        message: message,
        attempt: _attempt,
        nextRetry: DateTime.now().add(delay),
      ),
    );
    _retryTimer = Timer(delay, () => unawaited(start()));
  }

  void cancelConnect() {
    final state = status.value.state;
    if (_backend != null || (state != LinkState.connecting && state != LinkState.reconnecting)) return;
    _retryTimer?.cancel();
    _attempt = 0;
    _generation++;
    final id = hostId;
    if (id != null && _pool.status(id).state == LinkState.connecting) {
      _pool.cancelConnect(id);
    }
    _setStatus(const LinkStatus(LinkState.idle, message: 'Connecting was cancelled'));
  }

  Future<void> retryNow() async {
    _retryTimer?.cancel();
    _attempt = 0;
    await start();
  }

  void handleEnterWhileIdle() {
    if (_backend == null && status.value.state == LinkState.idle) {
      unawaited(start());
    }
  }

  void _teardown() {
    unawaited(_output?.cancel());
    _output = null;
    _backend = null;
    _ackOwed = false;
    TerminalIngest.instance.forget(this);
    _queue.clear();
  }

  void _setStatus(LinkStatus value) {
    if (!_disposed) status.value = value;
  }

  Future<void> stop() async {
    _userClosed = true;
    _retryTimer?.cancel();
    _backend?.close();
    _teardown();
    _setStatus(LinkStatus.idle);
  }

  String tail(int lines) => TerminalText.tail(terminal, lines);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    LiveObjects.closed('terminal session');
    _resizeThrottle.dispose();
    _retryTimer?.cancel();
    _backend?.close();
    _teardown();
    if (_retained && hostId != null) _pool.release(hostId!);
    status.dispose();
    notice.dispose();
    title.dispose();
    cwd.dispose();
  }
}

abstract final class TerminalText {
  static String tail(Terminal terminal, int lines) {
    final buffer = terminal.buffer;
    var end = buffer.lines.length;
    while (end > 0 && buffer.lines[end - 1].getText().trim().isEmpty) {
      end--;
    }
    final start = (end - lines).clamp(0, end);
    return [
      for (var i = start; i < end; i++) buffer.lines[i].getText().trimRight(),
    ].join('\n');
  }
}
