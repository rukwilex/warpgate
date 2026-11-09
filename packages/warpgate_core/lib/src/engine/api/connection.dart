import '../frb_generated.dart';
import 'channel.dart';
import 'error.dart';
import 'forwarding.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import 'sftp.dart';
import 'util.dart';

Future<SshClient> connect({
  required ConnectParams params,
  required CancelToken cancel,
  required FutureOr<bool> Function(String, String) verifier,
}) => WarpgateEngine.instance.api.crateApiConnectionConnect(
  params: params,
  cancel: cancel,
  verifier: verifier,
);

abstract class SshClient implements RustOpaqueInterface {
  Future<ForwardedConnection?> acceptForwarded();

  Future<bool> authAgent({required String user, String? socket});

  Future<bool> authKey({
    required String user,
    required String pem,
    String? passphrase,
  });

  Future<bool> authKeyboardInteractive({
    required String user,
    required FutureOr<List<String>?> Function(
      String,
      String,
      List<String>,
      List<bool>,
    )
    responder,
  });

  Future<bool> authNone({required String user});

  Future<bool> authPassword({required String user, required String password});

  Future<void> cancelForwardRemote({required String host, required int port});

  Future<SshClient> connectVia({
    required ConnectParams params,
    required FutureOr<bool> Function(String, String) verifier,
  });

  Future<void> disconnect();

  Future<int> forwardRemote({required String host, required int port});

  bool isClosed();

  Future<SshChannel> openDirectTcpip({required String host, required int port});

  Future<SshChannel> openSession();

  Future<void> ping({required int timeoutMs});

  String? remoteVersion();

  Future<SftpSession> sftp();

  Future<void> waitClosed();
}

class ConnectParams {
  final String host;
  final int port;
  final int connectTimeoutMs;
  final int handshakeTimeoutMs;
  final String clientId;

  const ConnectParams({
    required this.host,
    required this.port,
    required this.connectTimeoutMs,
    required this.handshakeTimeoutMs,
    required this.clientId,
  });

  @override
  int get hashCode =>
      host.hashCode ^
      port.hashCode ^
      connectTimeoutMs.hashCode ^
      handshakeTimeoutMs.hashCode ^
      clientId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectParams &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port &&
          connectTimeoutMs == other.connectTimeoutMs &&
          handshakeTimeoutMs == other.handshakeTimeoutMs &&
          clientId == other.clientId;
}
