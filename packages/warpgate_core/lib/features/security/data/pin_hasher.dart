import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

abstract final class PinHasher {
  static const _iterations = 120000;

  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  static Future<String> hash(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    final bytes = await key.extractBytes();
    return '${base64.encode(salt)}:${base64.encode(bytes)}';
  }

  static Future<bool> verify(String pin, String stored) async {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final key = await _kdf.deriveKeyFromPassword(
      password: pin,
      nonce: base64.decode(parts[0]),
    );
    final candidate = await key.extractBytes();
    final expected = base64.decode(parts[1]);
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate[i] ^ expected[i];
    }
    return diff == 0;
  }
}
