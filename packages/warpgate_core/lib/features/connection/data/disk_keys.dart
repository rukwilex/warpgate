import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;

abstract final class DiskKeys {
  static const names = ['id_ed25519', 'id_ecdsa', 'id_rsa'];

  static List<String> pems() {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return const [];
    final found = <String>[];
    for (final name in names) {
      final file = File(p.join(home, '.ssh', name));
      if (!file.existsSync()) continue;
      try {
        final pem = file.readAsStringSync();
        if (SSHKeyPair.isEncryptedPem(pem)) continue;
        found.add(pem);
      } on Object {
        continue;
      }
    }
    return found;
  }

  static List<SSHIdentity> identities() {
    final found = <SSHIdentity>[];
    for (final pem in pems()) {
      try {
        found.addAll(SSHKeyPair.fromPem(pem));
      } on Object {
        continue;
      }
    }
    return found;
  }
}
