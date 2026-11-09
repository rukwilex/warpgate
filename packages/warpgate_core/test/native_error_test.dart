import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:test/test.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/src/engine/api/error.dart';

void main() {
  Object map(EngineErrorKind kind, String message, [int? code]) =>
      nativeError(EngineError(kind: kind, message: message, code: code));

  test('channel request failures map to a channel request error', () {
    expect(map(EngineErrorKind.channelRequest, 'refused'), isA<SSHChannelRequestError>());
    expect(map(EngineErrorKind.channel, 'closed'), isA<SSHChannelOpenError>());
  });

  test('a server disconnect keeps its reason code and message', () {
    final error = map(EngineErrorKind.disconnect, 'protocol error from peer', 2);
    expect(error, isA<SSHDisconnectError>().having((e) => e.reasonCode, 'code', 2));
    expect(SshErrorText.describe(error), 'The server closed the connection: protocol error from peer');
  });

  test('a lost socket shows the underlying cause', () {
    final error = map(EngineErrorKind.socket, 'Connection reset by peer');
    expect(SshErrorText.describe(error), 'The connection was lost: Connection reset by peer');
  });

  test('a cancelled connect is permanent and not retried', () {
    final error = map(EngineErrorKind.cancelled, 'cancelled');
    expect(error, isA<ConnectCancelledException>());
    expect(SshErrorText.isPermanent(error), isTrue);
  });

  test('every kind maps to a typed error', () {
    expect(map(EngineErrorKind.hostKey, 'x'), isA<SSHHostkeyError>());
    expect(map(EngineErrorKind.auth, 'x'), isA<SSHAuthFailError>());
    expect(map(EngineErrorKind.authAbort, 'x'), isA<SSHAuthAbortError>());
    expect(map(EngineErrorKind.keyDecrypt, 'x'), isA<SSHKeyDecryptError>());
    expect(map(EngineErrorKind.keyDecode, 'x'), isA<SSHKeyDecodeError>());
    expect(map(EngineErrorKind.timeout, 'x'), isA<TimeoutException>());
    expect(map(EngineErrorKind.handshake, 'x'), isA<SSHHandshakeError>());
    expect(map(EngineErrorKind.sftpStatus, 'x', 3), isA<SftpStatusError>().having((e) => e.code, 'code', 3));
    expect(map(EngineErrorKind.internal, 'x'), isA<SSHStateError>());
  });
}
