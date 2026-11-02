import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:warpgate/features/connection/data/connection_pool.dart';
import 'package:warpgate/features/connection/data/ssh_errors.dart';
import 'package:warpgate/features/hosts/domain/host.dart';

enum ForwardState { starting, active, failed, stopped }

@immutable
class ActiveForward {
  const new({
    required this.hostId,
    required this.spec,
    required this.state,
    this.connections = 0,
    this.error,
  });

  final String hostId;
  final PortForwardSpec spec;
  final ForwardState state;
  final int connections;
  final String? error;

  String get key => '$hostId/${spec.id}';

  ActiveForward copyWith({
    ForwardState? state,
    int? connections,
    String? error,
  }) => ActiveForward(
    hostId: hostId,
    spec: spec,
    state: state ?? this.state,
    connections: connections ?? this.connections,
    error: error,
  );
}

class PortForwarder {
  new(this._pool);

  final ConnectionPool _pool;
  final Map<String, ActiveForward> _forwards = {};
  final Map<String, Future<void> Function()> _stoppers = {};
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  List<ActiveForward> get forwards => List.unmodifiable(_forwards.values);

  bool isRunning(String hostId, String specId) =>
      _forwards['$hostId/$specId']?.state == ForwardState.active;

  void _set(ActiveForward forward) {
    _forwards[forward.key] = forward;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> start(String hostId, PortForwardSpec spec) async {
    final initial = ActiveForward(
      hostId: hostId,
      spec: spec,
      state: ForwardState.starting,
    );
    if (_forwards[initial.key]?.state == ForwardState.active) return;
    _set(initial);
    try {
      final ssh = await _pool.client(hostId);
      _pool.retain(hostId);
      final stop = switch (spec.kind) {
        ForwardKind.local => await _local(ssh, initial),
        ForwardKind.remote => await _remote(ssh, initial),
        ForwardKind.dynamic => await _dynamic(ssh, spec),
      };
      _stoppers[initial.key] = () async {
        await stop();
        _pool.release(hostId);
      };
      _set(initial.copyWith(state: ForwardState.active));
      unawaited(
        ssh.done.whenComplete(() {
          if (_forwards[initial.key]?.state == ForwardState.active) {
            _stoppers.remove(initial.key);
            _set(
              initial.copyWith(
                state: ForwardState.failed,
                error: 'The connection closed',
              ),
            );
          }
        }),
      );
    } on Object catch (error) {
      _set(
        initial.copyWith(
          state: ForwardState.failed,
          error: SshErrorText.describe(error),
        ),
      );
    }
  }

  Future<void> stop(String hostId, String specId) async {
    final key = '$hostId/$specId';
    final stopper = _stoppers.remove(key);
    await stopper?.call();
    final current = _forwards[key];
    if (current != null) _set(current.copyWith(state: ForwardState.stopped));
  }

  Future<void> stopHost(String hostId) async {
    for (final forward in List.of(_forwards.values)) {
      if (forward.hostId == hostId) await stop(hostId, forward.spec.id);
    }
  }

  void _bump(String key, int delta) {
    final current = _forwards[key];
    if (current != null) {
      _set(current.copyWith(connections: current.connections + delta));
    }
  }

  Future<Future<void> Function()> _local(
    SSHClient ssh,
    ActiveForward forward,
  ) async {
    final spec = forward.spec;
    final server = await ServerSocket.bind(spec.bindHost, spec.bindPort);
    server.listen((socket) async {
      _bump(forward.key, 1);
      try {
        final channel = await ssh.forwardLocal(
          spec.targetHost,
          spec.targetPort,
        );
        await _pipe(socket, channel);
      } on Object {
        socket.destroy();
      } finally {
        _bump(forward.key, -1);
      }
    });
    return server.close;
  }

  Future<Future<void> Function()> _remote(
    SSHClient ssh,
    ActiveForward forward,
  ) async {
    final spec = forward.spec;
    final remote = await ssh.forwardRemote(port: spec.bindPort);
    if (remote == null) {
      throw StateError('The server refused to listen on port ${spec.bindPort}');
    }
    final subscription = remote.connections.listen((channel) async {
      _bump(forward.key, 1);
      try {
        final socket = await Socket.connect(spec.targetHost, spec.targetPort);
        await _pipe(socket, channel);
      } on Object {
        await channel.close();
      } finally {
        _bump(forward.key, -1);
      }
    });
    return () async {
      await subscription.cancel();
      await ssh.cancelForwardRemote(remote);
    };
  }

  Future<Future<void> Function()> _dynamic(
    SSHClient ssh,
    PortForwardSpec spec,
  ) async {
    final forward = await ssh.forwardDynamic(
      bindHost: spec.bindHost,
      bindPort: spec.bindPort,
    );
    return forward.close;
  }

  Future<void> _pipe(Socket socket, SSHForwardChannel channel) async {
    final upstream = socket.cast<List<int>>().pipe(channel.sink);
    final downstream = channel.stream.cast<List<int>>().pipe(socket);
    await Future.any([upstream, downstream]);
    socket.destroy();
    await channel.close();
  }

  Future<void> dispose() async {
    for (final stopper in _stoppers.values) {
      await stopper();
    }
    _stoppers.clear();
    await _changes.close();
  }
}
