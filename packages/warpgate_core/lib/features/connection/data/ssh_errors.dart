import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

abstract final class SshErrorText {
  static String describe(Object error) => switch (error) {
    SSHAuthFailError() => 'The server rejected these credentials',
    SSHAuthAbortError() => 'Sign-in was cancelled',
    SSHHostkeyError() =>
      'The host key was not trusted, so the connection was closed',
    SSHKeyDecryptError() => 'The key passphrase is wrong',
    SSHKeyDecodeError() => 'The private key could not be read',
    SSHHandshakeError() =>
      'The server and the app found no common encryption settings',
    SSHChannelOpenError(:final description) =>
      'The server refused the channel: $description',
    SocketException(:final osError)
        when osError?.errorCode == 61 || osError?.errorCode == 111 =>
      'Connection refused. Check the port and that sshd is running',
    SocketException(:final message)
        when message.contains('Failed host lookup') =>
      'The address could not be resolved',
    SocketException() => 'The host could not be reached',
    SSHSocketError() => 'The connection was lost',
    TimeoutException() => 'The host did not answer in time',
    SSHDisconnectError() => 'The server closed the connection',
    MissingCredentialsException(:final message) => message,
    DeadLinkError() => 'The server stopped answering, so the connection was closed',
    StateError(:final message) => message,
    _ => error.toString(),
  };

  static bool isPermanent(Object error) =>
      error is SSHAuthError ||
      error is SSHHostkeyError ||
      error is SSHKeyDecodeError ||
      error is MissingCredentialsException;
}

class MissingCredentialsException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

class DeadLinkError implements Exception {
  const new();

  @override
  String toString() => 'The server stopped answering keep-alive checks';
}
