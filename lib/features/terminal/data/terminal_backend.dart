import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/core/platform/native.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';

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
