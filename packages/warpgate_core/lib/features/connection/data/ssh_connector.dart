import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
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
import 'package:warpgate_core/features/sftp/domain/file_endpoint.dart' show CancelToken;

typedef SocketDialer = Future<SSHSocket> Function(String host, int port);

abstract interface class SshConnector {
  Future<SshClient> open(Host host, {SshClient? jump, required CancelToken cancel});
}

class EngineSshConnector implements SshConnector {
  EngineSshConnector({required HostCredentials credentials, required HostPrompts prompts, SocketDialer? dial})
    : _dart = DartSshConnector(credentials: credentials, prompts: prompts, dial: dial),
      _native = dial == null ? NativeSshConnector(credentials: credentials, prompts: prompts) : null;

  final DartSshConnector _dart;
  final NativeSshConnector? _native;

  @override
  Future<SshClient> open(Host host, {SshClient? jump, required CancelToken cancel}) async {
    final native = _native;
    if (native != null && (jump == null || jump is NativeSshClient) && await NativeEngine.ensureLoaded()) {
      if (NativeEngine.active) return native.open(host, jump: jump, cancel: cancel);
    }
    return _dart.open(host, jump: jump, cancel: cancel);
  }
}

class NativeSshConnector implements SshConnector {
  NativeSshConnector({required HostCredentials credentials, required HostPrompts prompts})
    : _credentials = credentials,
      _prompts = prompts;

  final HostCredentials _credentials;
  final HostPrompts _prompts;

  @override
  Future<SshClient> open(Host host, {SshClient? jump, required CancelToken cancel}) async {
    if (jump != null && jump is! NativeSshClient) {
      throw StateError('The jump host uses the other SSH engine. Reconnect it and try again');
    }
    return NativeSshClient.connect(
      host: host.address,
      port: host.port,
      jump: jump as NativeSshClient?,
      cancel: cancel,
      connectTimeout: SshDefaults.connectTimeout,
      handshakeTimeout: SshDefaults.handshakeTimeout,
      clientId: 'SSH-2.0-${SshDefaults.ident}',
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
  DartSshConnector({required HostCredentials credentials, required HostPrompts prompts, SocketDialer? dial})
    : _credentials = credentials,
      _prompts = prompts,
      _dial = dial ?? _defaultDial;

  static Future<SSHSocket> _defaultDial(String host, int port) =>
      SSHSocket.connect(host, port, timeout: SshDefaults.connectTimeout);

  final HostCredentials _credentials;
  final HostPrompts _prompts;
  final SocketDialer _dial;

  @override
  Future<SshClient> open(Host host, {SshClient? jump, required CancelToken cancel}) async {
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
      ssh.close();
      if (cancel.isCancelled) throw const ConnectCancelledException();
      rethrow;
    }
    if (cancel.isCancelled) {
      ssh.close();
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
    pending.then(
      (value) => result.isCompleted ? discard(value) : result.complete(value),
      onError: (Object error, StackTrace stack) => result.isCompleted ? null : result.completeError(error, stack),
    );
    return result.future;
  }
}
