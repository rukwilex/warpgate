import 'package:dartssh2/dartssh2.dart';

abstract final class SshDefaults {
  static const algorithms = SSHAlgorithms(
    cipher: [
      SSHCipherType.chacha20poly1305,
      SSHCipherType.aes128ctr,
      SSHCipherType.aes256ctr,
      SSHCipherType.aes128gcm,
      SSHCipherType.aes256gcm,
    ],
    mac: [
      SSHMacType.hmacSha256Etm,
      SSHMacType.hmacSha512Etm,
      SSHMacType.hmacSha256,
      SSHMacType.hmacSha512,
    ],
  );

  static const ident = 'Warpgate_1.0';
  static const connectTimeout = Duration(seconds: 12);
  static const handshakeTimeout = Duration(seconds: 15);
  static const idleTimeout = Duration(seconds: 90);
  static const probeTimeout = Duration(seconds: 10);
  static const livenessTick = Duration(seconds: 1);
  static const execTimeout = Duration(seconds: 30);
}
