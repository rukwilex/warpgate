import 'package:meta/meta.dart';
import 'package:warpgate_core/core/data/document_store.dart';

enum KeyAlgorithm {
  ed25519('Ed25519'),
  rsa('RSA'),
  ecdsa('ECDSA'),
  other('Other');

  new(this.label);

  final String label;

  static KeyAlgorithm fromWireType(String type) => switch (type) {
    'ssh-ed25519' => KeyAlgorithm.ed25519,
    'ssh-rsa' => KeyAlgorithm.rsa,
    _ when type.startsWith('ecdsa-') => KeyAlgorithm.ecdsa,
    _ => KeyAlgorithm.other,
  };
}

@immutable
class SshKey {
  const new({
    required this.id,
    required this.name,
    required this.algorithm,
    required this.publicKey,
    required this.fingerprint,
    required this.createdAt,
    this.hasPassphrase = false,
  });

  factory fromJson(JsonMap json) => SshKey(
    id: json['id']! as String,
    name: json['name']! as String,
    algorithm: KeyAlgorithm.values.byName(json['algorithm']! as String),
    publicKey: json['publicKey']! as String,
    fingerprint: json['fingerprint']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    hasPassphrase: json['hasPassphrase'] as bool? ?? false,
  );

  final String id;
  final String name;
  final KeyAlgorithm algorithm;
  final String publicKey;
  final String fingerprint;
  final DateTime createdAt;
  final bool hasPassphrase;

  SshKey rename(String value) => SshKey(
    id: id,
    name: value,
    algorithm: algorithm,
    publicKey: publicKey,
    fingerprint: fingerprint,
    createdAt: createdAt,
    hasPassphrase: hasPassphrase,
  );

  JsonMap toJson() => {
    'id': id,
    'name': name,
    'algorithm': algorithm.name,
    'publicKey': publicKey,
    'fingerprint': fingerprint,
    'createdAt': createdAt.toIso8601String(),
    'hasPassphrase': hasPassphrase,
  };
}

@immutable
class KeyMaterial {
  const new({
    required this.privatePem,
    required this.publicLine,
    required this.fingerprint,
    required this.algorithm,
  });

  final String privatePem;
  final String publicLine;
  final String fingerprint;
  final KeyAlgorithm algorithm;
}
