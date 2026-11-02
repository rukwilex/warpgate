import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:warpgate/features/connection/data/connection_pool.dart';
import 'package:warpgate/features/connection/data/ssh_errors.dart';
import 'package:warpgate/features/connection/domain/link_state.dart';
import 'package:warpgate/features/hosts/domain/host.dart';
import 'package:warpgate/features/keys/data/key_codec.dart';
import 'package:xterm/xterm.dart';

abstract interface class TerminalBackend {
  Stream<Uint8List> get output;
  Future<void> get done;
  bool get connectionLost;
  void write(Uint8List data);
  void resize(int columns, int rows);
  void close();
}

class SshShellBackend implements TerminalBackend {
  new(this._client, this._session);

  final SSHClient _client;
  final SSHSession _session;

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
  void close() => _session.close();
}

class LocalPtyBackend implements TerminalBackend {
  new(this._pty);

  final Pty _pty;

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

  @override
  void close() => _pty.kill();
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

class TerminalSession {
  new({
    required this.id,
    required this._target,
    required this._pool,
    this.maxLines = 10000,
    this.autoReconnect = true,
    String? restoredScrollback,
  }) : terminal = Terminal(maxLines: maxLines) {
    terminal
      ..onOutput = _handleUserInput
      ..onResize = _handleResize
      ..onTitleChange = (value) => title.value = value;
    if (restoredScrollback != null && restoredScrollback.isNotEmpty) {
      terminal.write(
        '\x1b[2m${restoredScrollback.replaceAll('\n', '\r\n')}\x1b[0m\r\n',
      );
    }
  }

  final String id;
  final int maxLines;
  final bool autoReconnect;
  final Terminal terminal;
  final ConnectionPool _pool;
  final SessionTarget _target;

  final status = ValueNotifier<LinkStatus>(LinkStatus.idle);
  final notice = ValueNotifier<String?>(null);
  final title = ValueNotifier<String?>(null);
  final cwd = ValueNotifier<String?>(null);

  InputSink? inputSink;
  String Function(String data)? inputModifier;

  TerminalBackend? _backend;
  StreamSubscription<String>? _output;
  Timer? _retryTimer;
  bool _disposed = false;
  bool _userClosed = false;
  int _attempt = 0;
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
    _setStatus(
      LinkStatus(
        _attempt == 0 ? LinkState.connecting : LinkState.reconnecting,
        attempt: _attempt,
      ),
    );
    try {
      final backend = await _open();
      if (_disposed) {
        backend.close();
        return;
      }
      _backend = backend;
      _attempt = 0;
      backend.resize(_columns, _rows);
      _output = backend.output
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(_handleRemoteOutput);
      _setStatus(const LinkStatus(LinkState.connected));
      unawaited(
        backend.done.then(
          (_) => _handleEnded(backend),
          onError: (_) => _handleEnded(backend),
        ),
      );
    } on Object catch (error) {
      _handleFailure(error);
    }
  }

  Future<TerminalBackend> _open() async {
    switch (_target) {
      case LocalTarget(:final directory):
        final shell =
            Platform.environment['SHELL'] ??
            (Platform.isWindows ? 'powershell.exe' : '/bin/bash');
        final pty = Pty.start(
          shell,
          arguments: Platform.isWindows ? const [] : const ['-l'],
          workingDirectory: directory ?? Platform.environment['HOME'],
          environment: {...Platform.environment, 'TERM': 'xterm-256color'},
          columns: _columns,
          rows: _rows,
        );
        return LocalPtyBackend(pty);
      case SshTarget(:final host, :final tmuxSession, :final directory):
        final client = await _pool.client(host.id);
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
        final session = await client.shell(pty: pty);
        final backend = SshShellBackend(client, session);
        final start = directory ?? host.startDirectory;
        if (start != null && start.isNotEmpty) {
          backend.write(utf8.encode('cd ${KeyCodec.shellQuote(start)}\r'));
        }
        return backend;
    }
  }

  void _handleRemoteOutput(String data) {
    terminal.write(data);
    _trackDirectory(data);
  }

  void _trackDirectory(String data) {
    final match = RegExp(r'\x1b\]7;file://[^/]*(/[^\x07\x1b]*)')
        .firstMatch(data);
    if (match != null) cwd.value = Uri.decodeComponent(match.group(1)!);
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
    _columns = columns;
    _rows = rows;
    _backend?.resize(columns, rows);
  }

  void _handleEnded(TerminalBackend backend) {
    if (!identical(_backend, backend)) return;
    final lost = backend.connectionLost;
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
    _disposed = true;
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
