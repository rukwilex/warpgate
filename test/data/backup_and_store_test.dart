import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/features/security/data/backup_codec.dart';
import 'package:warpgate_core/features/security/data/backup_service.dart';
import 'package:warpgate_core/features/security/data/pin_hasher.dart';

void main() {
  test('document store put, get, list, trim and delete', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftDocumentStore(db);
    for (var i = 0; i < 5; i++) {
      await store.put('c', 'id$i', {'n': i}, at: DateTime(2026, 1, 1, 0, i));
    }
    expect((await store.get('c', 'id2'))!['n'], 2);
    expect((await store.all('c', newestFirst: true)).first['n'], 4);
    await store.trim('c', 2);
    expect((await store.all('c')).map((e) => e['n']), [3, 4]);
    await store.delete('c', 'id3');
    expect(await store.all('c'), hasLength(1));
    await db.close();
  });

  test('backup round trip with and without secrets', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = DriftDocumentStore(db);
    final secrets = MemorySecretStore();
    await store.put('hosts', 'h', {
      'id': 'h',
      'label': 'db',
      'address': 'x',
      'username': 'u',
    });
    await store.put('keys', 'k', {'id': 'k', 'name': 'key'});
    await secrets.write(SecretKeys.privateKey('k'), 'PEM');
    await secrets.write(SecretKeys.hostPassword('h'), 'pw');
    final service = BackupService(store, secrets);
    final withSecrets = await service.export(
      passphrase: 'long passphrase',
      includeSecrets: true,
    );
    final without = await service.export(
      passphrase: 'long passphrase',
      includeSecrets: false,
    );
    expect(withSecrets, isNot(contains('PEM')));

    final targetDb = AppDatabase(NativeDatabase.memory());
    final targetStore = DriftDocumentStore(targetDb);
    final targetSecrets = MemorySecretStore();
    final restored = await BackupService(
      targetStore,
      targetSecrets,
    ).restore(withSecrets, 'long passphrase');
    expect(restored.hosts, 1);
    expect(await targetSecrets.read(SecretKeys.privateKey('k')), 'PEM');
    expect(await targetSecrets.read(SecretKeys.hostPassword('h')), 'pw');

    final payload = await BackupCodec.decrypt(without, 'long passphrase');
    expect((payload['collections']! as Map)['keys'], isEmpty);
    expect(
      () => BackupCodec.decrypt(withSecrets, 'wrong'),
      throwsA(isA<BackupException>()),
    );
    await db.close();
    await targetDb.close();
  });

  test('pin hashes verify only the right pin', () async {
    final hash = await PinHasher.hash('2468');
    expect(await PinHasher.verify('2468', hash), isTrue);
    expect(await PinHasher.verify('1357', hash), isFalse);
  });
}
