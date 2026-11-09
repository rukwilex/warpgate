import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:warpgate_core/core/async/cancel_token.dart';
import 'package:warpgate_core/features/connection/data/host_credentials.dart';
import 'package:warpgate_core/features/connection/data/host_prompts.dart';
import 'package:warpgate_core/features/connection/data/ssh_defaults.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/dart/dart_ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/native/native_auth.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/features/connection/engine/native/native_ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/tunnel_socket.dart';
import 'package:warpgate_core/features/hosts/domain/host.dart';

typedef SocketDialer = Future<SSHSocket> Function(String host, int port);

abstract interface class SshConnector {
  Future<SshClient> open(Host host, {required CancelToken cancel, SshClient? jump});
}

class EngineSshConnector implements SshConnector {
  new({required HostCredentials credentials, required HostPrompts prompts, SocketDialer? dial})
    : _dart = DartSshConnector(credentials: credentials, prompts: prompts, dial: dial),
      _native = dial == null ? NativeSshConnector(credentials: credentials, prompts: prompts) : null;

  final DartSshConnector _dart;
  final NativeSshConnector? _native;

  @override
  Future<SshClient> open(Host host, {required CancelToken cancel, SshClient? jump}) async {
    final native = _native;
    if (native != null && (jump == null || jump is NativeSshClient) && await NativeEngine.ensureLoaded()) {
      if (NativeEngine.active) return await native.open(host, jump: jump, cancel: cancel);
    }
    return await _dart.open(host, jump: jump, cancel: cancel);
  }
}

class NativeSshConnector implements SshConnector {
  new({required this._credentials, required this._prompts});

  final HostCredentials _credentials;
  final HostPrompts _prompts;

  @override
  Future<SshClient> open(Host host, {required CancelToken cancel, SshClient? jump}) async {
    if (jump != null && jump is! NativeSshClient) {
      throw StateError('The jump host uses the other SSH engine. Reconnect it and try again');
    }
    return await NativeSshClient.connect(
      host: host.address,
      port: host.port,
      jump: jump as NativeSshClient?,
      cancel: cancel,
      verify: (type, fingerprint) => _prompts.verifyHostKey(host, type, fingerprint),
      auth: NativeAuth(
        username: host.username,
        credentials: await _credentials.nativeCredentials(host),
        password: _prompts.usesPassword(host) ? () => _prompts.password(host) : null,
        keyboardInteractive: (request) => _prompts.keyboardInteractive(host, request),
      ),
    );
  }
}

class DartSshConnector implements SshConnector {
  new({required this._credentials, required this._prompts, SocketDialer? dial})
    : _dial = dial ?? _defaultDial;

  static Future<SSHSocket> _defaultDial(String host, int port) =>
      SSHSocket.connect(host, port, timeout: SshDefaults.connectTimeout);

  final HostCredentials _credentials;
  final HostPrompts _prompts;
  final SocketDialer _dial;

  @override
  Future<SshClient> open(Host host, {required CancelToken cancel, SshClient? jump}) async {
    final socket = await _cancellable(
      jump == null
          ? _dial(host.address, host.port)
          : jump
                .forwardLocal(host.address, host.port)
                .timeout(SshDefaults.connectTimeout)
                .then<SSHSocket>(tunnelSocket),
      cancel,
      (socket) => socket.destroy(),
    );
    final SSHClient ssh;
    try {
      ssh = SSHClient(
        socket,
        username: host.username,
        identities: await _credentials.identities(host),
        keepAliveInterval: null,
        algorithms: SshDefaults.algorithms,
        handshakeTimeout: SshDefaults.handshakeTimeout,
        onVerifyHostKey: (type, fingerprint) => _prompts.verifyHostKey(host, type, utf8.decode(fingerprint)),
        onPasswordRequest: _prompts.usesPassword(host) ? () => _prompts.password(host) : null,
        onUserInfoRequest: (request) => _prompts.keyboardInteractive(host, request),
        ident: SshDefaults.ident,
      );
    } on Object {
      socket.destroy();
      rethrow;
    }
    cancel.onCancel(ssh.close);
    try {
      await ssh.authenticated;
    } on Object {
      unawaited(ssh.close());
      if (cancel.isCancelled) throw const ConnectCancelledException();
      rethrow;
    }
    if (cancel.isCancelled) {
      unawaited(ssh.close());
      throw const ConnectCancelledException();
    }
    return DartSshClient(ssh);
  }

  static Future<T> _cancellable<T>(Future<T> pending, CancelToken cancel, void Function(T value) discard) {
    if (cancel.isCancelled) {
      unawaited(pending.then(discard, onError: (_) {}));
      return Future.error(const ConnectCancelledException());
    }
    final result = Completer<T>();
    cancel.onCancel(() {
      if (!result.isCompleted) result.completeError(const ConnectCancelledException());
    });
    unawaited(
      pending.then(
        (value) => result.isCompleted ? discard(value) : result.complete(value),
        onError: (Object error, StackTrace stack) => result.isCompleted ? null : result.completeError(error, stack),
      ),
    );
    return result.future;
  }
}
