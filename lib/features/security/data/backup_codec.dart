import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:warpgate/core/data/app_database.dart';

class BackupException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class BackupCodec {
  static const format = 'warpgate-backup';
  static const version = 1;
  static const _iterations = 150000;

  static final _cipher = AesGcm.with256bits();

  static Pbkdf2 _kdf(int iterations) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);

  static Future<String> encrypt(JsonMap payload, String passphrase) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _kdf(_iterations)
        .deriveKeyFromPassword(password: passphrase, nonce: salt);
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: key,
    );
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'kdf': {
        'name': 'pbkdf2-sha256',
        'iterations': _iterations,
        'salt': base64.encode(salt),
      },
      'cipher': 'aes-256-gcm',
      'nonce': base64.encode(box.nonce),
      'mac': base64.encode(box.mac.bytes),
      'data': base64.encode(box.cipherText),
    });
  }

  static Future<JsonMap> decrypt(String file, String passphrase) async {
    final Map<String, Object?> envelope;
    try {
      envelope = (jsonDecode(file) as Map).cast();
    } on Object {
      throw const BackupException('This file is not a Warpgate backup');
    }
    if (envelope['format'] != format) {
      throw const BackupException('This file is not a Warpgate backup');
    }
    final kdf = (envelope['kdf']! as Map).cast<String, Object?>();
    final key = await _kdf(kdf['iterations']! as int).deriveKeyFromPassword(
      password: passphrase,
      nonce: base64.decode(kdf['salt']! as String),
    );
    try {
      final clear = await _cipher.decrypt(
        SecretBox(
          base64.decode(envelope['data']! as String),
          nonce: base64.decode(envelope['nonce']! as String),
          mac: Mac(base64.decode(envelope['mac']! as String)),
        ),
        secretKey: key,
      );
      return (jsonDecode(utf8.decode(clear)) as Map).cast();
    } on SecretBoxAuthenticationError {
      throw const BackupException(
        'The passphrase is wrong or the file is damaged',
      );
    }
  }
}
