import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:test/test.dart';
import 'package:warpgate_core/features/connection/data/ssh_errors.dart';
import 'package:warpgate_core/features/connection/engine/native_ssh.dart';

void main() {
  Object map(String text) => nativeError(AnyhowException(text));

  test('channel request failures map to a channel request error', () {
    expect(map('channel_request: the server refused the request'), isA<SSHChannelRequestError>());
    expect(map('channel: the channel closed'), isA<SSHChannelOpenError>());
  });

  test('a server disconnect keeps its reason code and message', () {
    final error = map('disconnect 2: protocol error from peer');
    expect(error, isA<SSHDisconnectError>().having((e) => e.reasonCode, 'code', 2));
    expect(SshErrorText.describe(error), 'The server closed the connection: protocol error from peer');
  });

  test('a lost socket shows the underlying cause', () {
    final error = map('socket: Connection reset by peer');
    expect(SshErrorText.describe(error), 'The connection was lost: Connection reset by peer');
  });

  test('known kinds map to their typed errors', () {
    expect(map('hostkey: the host key was not trusted'), isA<SSHHostkeyError>());
    expect(map('auth: rejected'), isA<SSHAuthFailError>());
    expect(map('key_decrypt: bad passphrase'), isA<SSHKeyDecryptError>());
    expect(map('key_decode: bad key'), isA<SSHKeyDecodeError>());
    expect(map('timeout: slow'), isA<TimeoutException>());
    expect(map('sftp_status 3: denied'), isA<SftpStatusError>().having((e) => e.code, 'code', 3));
  });
}
