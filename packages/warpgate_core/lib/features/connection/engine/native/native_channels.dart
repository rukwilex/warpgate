import 'dart:async';
import 'dart:typed_data';

import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/src/engine/api/ssh.dart' as rs;

class ChannelPump {
  new(
    this.channel, {
    required this.onData,
    required this.onExtended,
    required this.onClosed,
  });

  static const int chunk = 256 * 1024;

  final rs.SshChannel channel;
  final void Function(Uint8List data) onData;
  final void Function(Uint8List data) onExtended;
  final void Function() onClosed;
  bool _running = false;
  bool _stopped = false;
  bool _paused = false;
  Completer<void>? _resume;

  void start() {
    if (_running || _stopped) return;
    _running = true;
    unawaited(_loop());
  }

  void pause() => _paused = true;

  void resume() {
    _paused = false;
    _resume?.complete();
    _resume = null;
  }

  void stop() {
    _stopped = true;
    resume();
  }

  Future<void> _loop() async {
    try {
      while (!_stopped) {
        if (_paused) {
          await (_resume ??= Completer<void>()).future;
          continue;
        }
        final next = await channel.read(maxBytes: chunk);
        if (next.data.isNotEmpty) onData(next.data);
        if (next.extended.isNotEmpty) onExtended(next.extended);
        if (next.closed) break;
      }
    } on Object {
      _stopped = true;
    }
    onClosed();
  }
}

class NativeSshSession implements SshSession {
  new(this._channel) {
    LiveObjects.opened('native ssh channel');
    _pump = ChannelPump(_channel, onData: _stdout.add, onExtended: _stderr.add, onClosed: _finish);
    for (final controller in [_stdout, _stderr]) {
      controller
        ..onListen = _pump.start
        ..onPause = _syncPause
        ..onResume = _syncPause;
    }
    _stdin.stream.listen(write, onDone: () => _writes = _writes.then((_) => _channel.eof()).catchError((_) {}));
  }

  final rs.SshChannel _channel;
  late final ChannelPump _pump;
  final _stdout = StreamController<Uint8List>();
  final _stderr = StreamController<Uint8List>();
  final _stdin = StreamController<Uint8List>();
  final _done = Completer<void>();
  int? _exitCode;
  Future<void> _writes = Future.value();

  void _syncPause() {
    final paused = (_stdout.hasListener && _stdout.isPaused) || (_stderr.hasListener && _stderr.isPaused);
    if (paused) {
      _pump.pause();
    } else {
      _pump.resume();
    }
  }

  void _finish() {
    if (_done.isCompleted) return;
    LiveObjects.closed('native ssh channel');
    _exitCode = _channel.exitStatus();
    unawaited(_stdout.close());
    unawaited(_stderr.close());
    _done.complete();
  }

  @override
  StreamSink<Uint8List> get stdin => _stdin.sink;

  @override
  Stream<Uint8List> get stdout => _stdout.stream;

  @override
  Stream<Uint8List> get stderr => _stderr.stream;

  @override
  int? get exitCode => _exitCode ?? (_done.isCompleted ? _channel.exitStatus() : null);

  @override
  Future<void> get done => _done.future;

  @override
  void write(Uint8List data) {
    final copy = Uint8List.fromList(data);
    _writes = _writes.then((_) => _channel.write(data: copy)).catchError((_) {});
  }

  @override
  void resizeTerminal(int columns, int rows) {
    unawaited(_channel.windowChange(columns: columns, rows: rows).catchError((_) {}));
  }

  @override
  void close() {
    _pump.stop();
    unawaited(_channel.close().catchError((_) {}));
    _finish();
  }

  @override
  Future<int?> waitForExit({Duration? timeout}) {
    final waiting = done.then((_) => exitCode);
    return timeout == null ? waiting : waiting.timeout(timeout);
  }
}

class NativeForwardChannel implements SshTunnel {
  new(this._channel) {
    LiveObjects.opened('native forward channel');
    _pump = ChannelPump(_channel, onData: _incoming.add, onExtended: (_) {}, onClosed: _finish);
    _incoming
      ..onListen = _pump.start
      ..onPause = _pump.pause
      ..onResume = _pump.resume
      ..onCancel = () => unawaited(close());
    _outgoing.stream.listen(
      (data) => _writes = _writes.then((_) => _channel.write(data: Uint8List.fromList(data))).catchError((_) {}),
      onDone: () => _writes = _writes.then((_) => _channel.eof()).catchError((_) {}),
    );
  }

  final rs.SshChannel _channel;
  late final ChannelPump _pump;
  final _incoming = StreamController<Uint8List>();
  final _outgoing = StreamController<List<int>>();
  final _done = Completer<void>();
  Future<void> _writes = Future.value();

  void _finish() {
    if (_done.isCompleted) return;
    LiveObjects.closed('native forward channel');
    unawaited(_incoming.close());
    _done.complete();
  }

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    _pump.stop();
    try {
      await _channel.close();
    } on Object {
      return;
    } finally {
      _finish();
    }
  }
}
