import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pinenacl/ed25519.dart' as ed25519;
import 'package:pointycastle/export.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';

class KeyFormatException implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class KeyCodec {
  static Future<KeyMaterial> generate({
    required KeyAlgorithm algorithm,
    required String comment,
    String? passphrase,
    int rsaBits = 3072,
  }) =>
      Isolate.run(() => _generateSync(algorithm, comment, passphrase, rsaBits));

  static KeyMaterial _generateSync(
    KeyAlgorithm algorithm,
    String comment,
    String? passphrase,
    int rsaBits,
  ) {
    final pair = switch (algorithm) {
      KeyAlgorithm.ed25519 => _ed25519(comment),
      KeyAlgorithm.rsa => _rsa(comment, rsaBits),
      _ => throw const KeyFormatException(
        'Only Ed25519 and RSA keys can be generated',
      ),
    };
    return describe(pair, pair.toPem(passphrase: passphrase), comment: comment);
  }

  static OpenSSHEd25519KeyPair _ed25519(String comment) {
    final signing = ed25519.SigningKey.generate();
    return OpenSSHEd25519KeyPair(
      Uint8List.fromList(signing.verifyKey.asTypedList),
      Uint8List.fromList(signing.asTypedList),
      comment,
    );
  }

  static OpenSSHRsaKeyPair _rsa(String comment, int bits) {
    final random = Random.secure();
    final secure = FortunaRandom()
      ..seed(
        KeyParameter(
          Uint8List.fromList(
            List<int>.generate(32, (_) => random.nextInt(256)),
          ),
        ),
      );
    final generator = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), bits, 64),
          secure,
        ),
      );
    final pair = generator.generateKeyPair();
    final private = pair.privateKey;
    final public = pair.publicKey;
    final p = private.p!;
    final q = private.q!;
    return OpenSSHRsaKeyPair(
      public.modulus!,
      public.exponent!,
      private.privateExponent!,
      q.modInverse(p),
      p,
      q,
      comment,
    );
  }

  static KeyMaterial parse(String pem, {String? passphrase}) {
    final trimmed = pem.trim();
    if (!trimmed.startsWith('-----BEGIN')) {
      throw const KeyFormatException(
        'This is not a private key in PEM or OpenSSH format',
      );
    }
    if (SSHKeyPair.isEncryptedPem(trimmed) &&
        (passphrase == null || passphrase.isEmpty)) {
      throw const KeyFormatException(
        'This key is protected. Enter its passphrase',
      );
    }
    final List<SSHKeyPair> pairs;
    try {
      pairs = SSHKeyPair.fromPem(trimmed, passphrase);
    } on Object {
      throw const KeyFormatException(
        'The key could not be read. Check the passphrase',
      );
    }
    if (pairs.isEmpty) throw const KeyFormatException('The file holds no keys');
    return describe(pairs.first, '$trimmed\n');
  }

  static bool needsPassphrase(String pem) =>
      SSHKeyPair.isEncryptedPem(pem.trim());

  static KeyMaterial describe(SSHKeyPair pair, String pem, {String? comment}) {
    final blob = pair.toPublicKey().encode();
    final type = wireType(blob);
    final label = comment ?? pair.comment ?? '';
    final line = [
      type,
      base64.encode(blob),
      if (label.isNotEmpty) label,
    ].join(' ');
    return KeyMaterial(
      privatePem: pem,
      publicLine: line,
      fingerprint: fingerprint(blob),
      algorithm: KeyAlgorithm.fromWireType(type),
    );
  }

  static String wireType(Uint8List blob) {
    final length = ByteData.sublistView(blob, 0, 4).getUint32(0);
    return utf8.decode(blob.sublist(4, 4 + length));
  }

  static String fingerprint(Uint8List blob) {
    final digest = SHA256Digest().process(blob);
    return 'SHA256:${base64.encode(digest).replaceAll('=', '')}';
  }

  static String installCommand(String publicLine) {
    final quoted = shellQuote(publicLine.trim());
    return 'umask 077; mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && '
        'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && '
        '(grep -qxF $quoted ~/.ssh/authorized_keys || echo $quoted >> ~/.ssh/authorized_keys)';
  }

  static String shellQuote(String value) =>
      "'${value.replaceAll("'", r"'\''")}'";
}
