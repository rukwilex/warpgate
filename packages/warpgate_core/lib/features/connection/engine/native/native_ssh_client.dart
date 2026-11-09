import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/native/native_auth.dart';
import 'package:warpgate_core/features/connection/engine/native/native_channels.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/features/connection/engine/native/native_sftp.dart';
import 'package:warpgate_core/features/connection/engine/tunnel_socket.dart';
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart' show CancelToken;
import 'package:warpgate_core/src/engine/api/connection.dart' as rs;
import 'package:warpgate_core/src/engine/api/util.dart' as rs;

class NativeSshClient implements SshClient {
  new _(this._client, this.username) {
    LiveObjects.opened('native ssh client');
    unawaited(
      guardNative(_client.waitClosed).then<void>(
        (_) => _finish(null),
        onError: _finish,
      ),
    );
  }

  static const pingTimeout = Duration(seconds: 15);

  static Future<NativeSshClient> connect({
    required String host,
    required int port,
    required NativeAuth auth,
    required Future<bool> Function(String type, String fingerprint) verify,
    NativeSshClient? jump,
    CancelToken? cancel,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration handshakeTimeout = const Duration(seconds: 15),
    String clientId = 'SSH-2.0-Warpgate_1.0',
  }) async {
    cancel?.throwIfCancelledAs(const ConnectCancelledException());
    final params = rs.ConnectParams(
      host: host,
      port: port,
      connectTimeoutMs: connectTimeout.inMilliseconds,
      handshakeTimeoutMs: handshakeTimeout.inMilliseconds,
      clientId: clientId,
    );
    final token = rs.CancelToken();
    cancel?.onCancel(token.cancel);
    final opening = guardNative(
      () => jump == null
          ? rs.connect(params: params, cancel: token, verifier: verify)
          : jump._client.connectVia(params: params, verifier: verify),
    );
    final client = await _unlessCancelled(opening, cancel);
    final wrapped = NativeSshClient._(client, auth.username);
    cancel?.onCancel(() => unawaited(wrapped.close()));
    try {
      await wrapped._authenticate(auth);
      cancel?.throwIfCancelledAs(const ConnectCancelledException());
    } on Object {
      await wrapped.close();
      if (cancel?.isCancelled ?? false) throw const ConnectCancelledException();
      rethrow;
    }
    return wrapped;
  }

  static Future<rs.SshClient> _unlessCancelled(Future<rs.SshClient> opening, CancelToken? cancel) {
    if (cancel == null) return opening;
    final result = Completer<rs.SshClient>();
    cancel.onCancel(() {
      if (result.isCompleted) return;
      result.completeError(const ConnectCancelledException());
      unawaited(opening.then((client) => client.disconnect(), onError: (_) {}));
    });
    unawaited(
      opening.then(
        (client) => result.isCompleted ? null : result.complete(client),
        onError: (Object error, StackTrace stack) => result.isCompleted ? null : result.completeError(error, stack),
      ),
    );
    return result.future;
  }

  final rs.SshClient _client;
  @override
  final String username;
  final _done = Completer<void>();
  bool _closed = false;

  Future<void> _authenticate(NativeAuth auth) async {
    final user = auth.username;
    SSHKeyDecodeError? keyError;
    var rejected = false;
    for (final credential in auth.credentials) {
      try {
        final ok = await guardNative(
          () => switch (credential) {
            AgentCredential(:final socket) => _client.authAgent(user: user, socket: socket).catchError((_) => false),
            KeyCredential(:final pem, :final passphrase) => _client.authKey(
              user: user,
              pem: pem,
              passphrase: passphrase,
            ),
          },
        );
        if (ok) return;
        rejected = true;
      } on SSHKeyDecodeError catch (error) {
        keyError ??= error;
      }
    }
    final password = auth.password;
    if (password != null) {
      final value = await password();
      if (value != null) {
        if (await guardNative(() => _client.authPassword(user: user, password: value))) return;
        rejected = true;
      }
    }
    final interactive = auth.keyboardInteractive;
    if (interactive != null) {
      final ok = await guardNative(
        () => _client.authKeyboardInteractive(
          user: user,
          responder: (name, instruction, prompts, echoes) => interactive(
            SSHUserInfoRequest(name, instruction, [
              for (var i = 0; i < prompts.length; i++) SSHUserInfoPrompt(prompts[i], echoes[i]),
            ]),
          ),
        ),
      );
      if (ok) return;
      rejected = true;
    }
    if (keyError != null && !rejected) throw keyError;
    throw SSHAuthFailError('All authentication methods failed');
  }

  void _finish(Object? error) {
    if (_done.isCompleted) return;
    final requested = _closed;
    _closed = true;
    LiveObjects.closed('native ssh client');
    if (error == null || requested) {
      _done.complete();
    } else {
      _done.completeError(error);
    }
  }

  @override
  String? get remoteVersion => _client.remoteVersion();

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => _closed || _client.isClosed();

  @override
  Future<void> ping() => guardNative(() => _client.ping(timeoutMs: pingTimeout.inMilliseconds));

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _client.disconnect();
    } on Object {
      return;
    }
  }

  Future<NativeSshSession> _session({String? command, SSHPtyConfig? pty, Map<String, String>? environment}) async {
    final channel = await guardNative(_client.openSession);
    try {
      if (pty != null) {
        await guardNative(() => channel.requestPty(term: pty.type, columns: pty.width, rows: pty.height));
      }
      for (final MapEntry(:key, :value) in (environment ?? const <String, String>{}).entries) {
        try {
          await channel.setEnv(name: key, value: value);
        } on Object {
          continue;
        }
      }
      if (command == null) {
        await guardNative(channel.requestShell);
      } else {
        await guardNative(() => channel.exec(command: command));
      }
    } on Object {
      unawaited(channel.close().catchError((_) {}));
      rethrow;
    }
    return NativeSshSession(channel);
  }

  @override
  Future<SshSession> shell({SSHPtyConfig? pty = const SSHPtyConfig(), Map<String, String>? environment}) =>
      _session(pty: pty, environment: environment);

  @override
  Future<SshSession> execute(String command, {SSHPtyConfig? pty, Map<String, String>? environment}) =>
      _session(command: command, pty: pty, environment: environment);

  @override
  Future<SshSftp> sftp() async => NativeSftpClient(await guardNative(_client.sftp));

  @override
  Future<SshTunnel> forwardLocal(String host, int port) async =>
      NativeForwardChannel(await guardNative(() => _client.openDirectTcpip(host: host, port: port)));

  @override
  Future<SSHDynamicForward> forwardDynamic({String bindHost = '127.0.0.1', int? bindPort}) => startDynamicForward(
    bindHost: bindHost,
    bindPort: bindPort,
    options: const SSHDynamicForwardOptions(),
    dial: (host, port) async => tunnelSocket(await forwardLocal(host, port)),
  );

  final List<NativeRemoteForward> _remotes = [];
  bool _accepting = false;

  @override
  Future<SshRemoteForward?> forwardRemote({String? host, int? port, RemoteConnectionFilter? filter}) async {
    final bindHost = host ?? 'localhost';
    try {
      final assigned = await guardNative(() => _client.forwardRemote(host: bindHost, port: port ?? 0));
      final forward = NativeRemoteForward(bindHost, assigned, filter);
      _remotes.add(forward);
      if (!_accepting) unawaited(_accept());
      return forward;
    } on Object {
      return null;
    }
  }

  Future<void> _accept() async {
    _accepting = true;
    try {
      while (!isClosed && _remotes.isNotEmpty) {
        final next = await _client.acceptForwarded();
        if (next == null) break;
        final target = _remotes.where((r) => r.port == next.connectedPort).firstOrNull;
        final channel = NativeForwardChannel(next.channel);
        final filter = target?.filter;
        if (target == null || (filter != null && !filter(next.originHost, next.originPort))) {
          unawaited(channel.close());
          continue;
        }
        target._connections.add(channel);
      }
    } on Object {
      return;
    } finally {
      _accepting = false;
    }
  }

  @override
  Future<bool> cancelForwardRemote(SshRemoteForward forward) async {
    if (forward is! NativeRemoteForward || !_remotes.remove(forward)) return false;
    unawaited(forward._connections.close());
    try {
      await _client.cancelForwardRemote(host: forward.host, port: forward.port);
      return true;
    } on Object {
      return false;
    }
  }
}

class NativeRemoteForward implements SshRemoteForward {
  new(this.host, this.port, this.filter);

  @override
  final String host;
  @override
  final int port;
  final RemoteConnectionFilter? filter;
  final _connections = StreamController<SshTunnel>();

  @override
  Stream<SshTunnel> get connections => _connections.stream;
}

extension on CancelToken {
  void throwIfCancelledAs(Object error) {
    if (isCancelled) throw error;
  }
}
