import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/secret_store.dart';
import 'package:warpgate/features/security/data/backup_codec.dart';

class BackupService {
  new(this._store, this._secrets);

  static const collections = [
    'hosts',
    'host_groups',
    'known_hosts',
    'keys',
    'snippets',
    'workbench',
    'saved_layouts',
    'settings',
  ];

  final DocumentStore _store;
  final SecretStore _secrets;

  Future<String> export({
    required String passphrase,
    required bool includeSecrets,
  }) async {
    final data = <String, Object?>{};
    for (final collection in collections) {
      data[collection] = await _store.all(collection);
    }
    final secrets = <String, String>{};
    if (includeSecrets) {
      for (final key in (data['keys']! as List).cast<JsonMap>()) {
        final id = key['id']! as String;
        for (final name in [
          SecretKeys.privateKey(id),
          SecretKeys.keyPassphrase(id),
        ]) {
          final value = await _secrets.read(name);
          if (value != null) secrets[name] = value;
        }
      }
      for (final host in (data['hosts']! as List).cast<JsonMap>()) {
        final name = SecretKeys.hostPassword(host['id']! as String);
        final value = await _secrets.read(name);
        if (value != null) secrets[name] = value;
      }
    } else {
      data['keys'] = const <Object?>[];
    }
    return await BackupCodec.encrypt({
      'createdAt': DateTime.now().toIso8601String(),
      'collections': data,
      'secrets': secrets,
    }, passphrase);
  }

  Future<({int hosts, int keys, int snippets})> restore(
    String file,
    String passphrase,
  ) async {
    final payload = await BackupCodec.decrypt(file, passphrase);
    final data = (payload['collections']! as Map).cast<String, Object?>();
    for (final collection in collections) {
      final docs =
          (data[collection] as List?)?.cast<Map<Object?, Object?>>() ??
          const [];
      for (final doc in docs) {
        final json = doc.cast<String, Object?>();
        final id =
            (json['id'] ??
                    json['endpoint'] ??
                    (collection == 'settings' ? 'app' : 'state'))
                as String;
        await _store.put(collection, id, json);
      }
    }
    final secrets =
        (payload['secrets'] as Map?)?.cast<String, String>() ?? const {};
    for (final MapEntry(:key, :value) in secrets.entries) {
      await _secrets.write(key, value);
    }
    int count(String name) => (data[name] as List?)?.length ?? 0;
    return (
      hosts: count('hosts'),
      keys: count('keys'),
      snippets: count('snippets'),
    );
  }
}
