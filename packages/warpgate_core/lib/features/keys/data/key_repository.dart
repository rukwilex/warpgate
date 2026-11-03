import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/util/ids.dart';
import 'package:warpgate_core/features/keys/domain/ssh_key.dart';

class KeyRepository {
  new(this._store, this._secrets);

  static const collection = 'keys';

  final DocumentStore _store;
  final SecretStore _secrets;

  Future<List<SshKey>> all() async => [
    for (final json in await _store.all(collection)) SshKey.fromJson(json),
  ];

  Future<SshKey> save({
    required String name,
    required KeyMaterial material,
    String? passphrase,
  }) async {
    final key = SshKey(
      id: Ids.next(),
      name: name,
      algorithm: material.algorithm,
      publicKey: material.publicLine,
      fingerprint: material.fingerprint,
      createdAt: DateTime.now(),
      hasPassphrase: passphrase != null && passphrase.isNotEmpty,
    );
    await _secrets.write(SecretKeys.privateKey(key.id), material.privatePem);
    if (key.hasPassphrase) {
      await _secrets.write(SecretKeys.keyPassphrase(key.id), passphrase!);
    }
    await _store.put(collection, key.id, key.toJson());
    return key;
  }

  Future<void> update(SshKey key) =>
      _store.put(collection, key.id, key.toJson());

  Future<void> delete(String id) async {
    await _store.delete(collection, id);
    await _secrets.delete(SecretKeys.privateKey(id));
    await _secrets.delete(SecretKeys.keyPassphrase(id));
  }

  Future<({String pem, String? passphrase})?> privateMaterial(String id) async {
    final pem = await _secrets.read(SecretKeys.privateKey(id));
    if (pem == null) return null;
    return (
      pem: pem,
      passphrase: await _secrets.read(SecretKeys.keyPassphrase(id)),
    );
  }

  Future<void> restore(SshKey key, String pem, String? passphrase) async {
    await _secrets.write(SecretKeys.privateKey(key.id), pem);
    if (passphrase != null) {
      await _secrets.write(SecretKeys.keyPassphrase(key.id), passphrase);
    }
    await _store.put(collection, key.id, key.toJson());
  }
}
