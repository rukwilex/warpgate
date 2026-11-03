import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate_core/features/keys/data/key_codec.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';

void main() {
  test(
    'generates an Ed25519 key that parses back with the same fingerprint',
    () async {
      final material = await KeyCodec.generate(
        algorithm: KeyAlgorithm.ed25519,
        comment: 'test',
      );
      expect(material.publicLine, startsWith('ssh-ed25519 '));
      expect(material.publicLine, endsWith(' test'));
      final parsed = KeyCodec.parse(material.privatePem);
      expect(parsed.fingerprint, material.fingerprint);
      expect(parsed.fingerprint, startsWith('SHA256:'));
    },
  );

  test('encrypted keys need their passphrase', () async {
    final material = await KeyCodec.generate(
      algorithm: KeyAlgorithm.ed25519,
      comment: 'x',
      passphrase: 'correct horse',
    );
    expect(KeyCodec.needsPassphrase(material.privatePem), isTrue);
    expect(
      () => KeyCodec.parse(material.privatePem),
      throwsA(isA<KeyFormatException>()),
    );
    expect(
      () => KeyCodec.parse(material.privatePem, passphrase: 'wrong'),
      throwsA(isA<KeyFormatException>()),
    );
    expect(
      KeyCodec.parse(
        material.privatePem,
        passphrase: 'correct horse',
      ).fingerprint,
      material.fingerprint,
    );
  });

  test('generated keys sign data', () async {
    final material = await KeyCodec.generate(
      algorithm: KeyAlgorithm.ed25519,
      comment: 'sig',
    );
    final pair = SSHKeyPair.fromPem(material.privatePem).single;
    expect(pair.type, 'ssh-ed25519');
  });

  test('rejects text that is not a key', () {
    expect(() => KeyCodec.parse('hello'), throwsA(isA<KeyFormatException>()));
  });

  test('install command quotes the key', () {
    final command = KeyCodec.installCommand("ssh-ed25519 AAAA it's-me");
    expect(command, contains(r"'ssh-ed25519 AAAA it'\''s-me'"));
    expect(command, contains('authorized_keys'));
  });
}
