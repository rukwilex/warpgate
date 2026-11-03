import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/vault_secret_store.dart';

class CountingVault implements KeyVault {
  new({this.fail = false});

  final bool fail;
  final Map<String, String> items = {};
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> read(String name) async {
    reads++;
    if (fail) throw PlatformException(code: '-34018');
    return items[name];
  }

  @override
  Future<void> write(String name, String value) async {
    writes++;
    if (fail) throw PlatformException(code: '-34018');
    items[name] = value;
  }
}

void main() {
  late DocumentStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = DriftDocumentStore(AppDatabase(NativeDatabase.memory()));
  });

  test('secrets round trip and are not stored in clear text', () async {
    final vault = CountingVault();
    final secrets = VaultSecretStore(
      store: store,
      master: MasterKeySource(primary: vault),
    );
    await secrets.write('host.a.password', 'hunter2');
    expect(await secrets.read('host.a.password'), 'hunter2');
    final raw = await store.get(VaultSecretStore.collection, 'host.a.password');
    expect(raw.toString(), isNot(contains('hunter2')));
    await secrets.delete('host.a.password');
    expect(await secrets.read('host.a.password'), isNull);
  });

  test('the keychain is touched at most once per launch', () async {
    final vault = CountingVault();
    final first = VaultSecretStore(
      store: store,
      master: MasterKeySource(primary: vault),
    );
    for (var i = 0; i < 20; i++) {
      await first.write('k$i', 'v$i');
      await first.read('k$i');
    }
    expect(vault.reads, 1);
    expect(vault.writes, 1);
    final source = MasterKeySource(primary: vault);
    final second = VaultSecretStore(store: store, master: source);
    for (var i = 0; i < 20; i++) {
      expect(await second.read('k$i'), 'v$i');
    }
    expect(source.accesses, 1);
  });

  test(
    'a value encrypted under one name cannot be read under another',
    () async {
      final secrets = VaultSecretStore(
        store: store,
        master: MasterKeySource(primary: CountingVault()),
      );
      await secrets.write('a', 'secret');
      final copied = await store.get(VaultSecretStore.collection, 'a');
      await store.put(VaultSecretStore.collection, 'b', copied!);
      expect(await secrets.read('b'), isNull);
    },
  );

  test(
    'falls back to the second keychain when the first is unavailable',
    () async {
      final fallback = CountingVault();
      final secrets = VaultSecretStore(
        store: store,
        master: MasterKeySource(
          primary: CountingVault(fail: true),
          fallback: fallback,
        ),
      );
      await secrets.write('x', 'y');
      expect(await secrets.read('x'), 'y');
      expect(fallback.items, contains(MasterKeySource.itemName));
    },
  );

  test(
    'legacy secrets move into the vault and leave the old storage',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'host.h1.password': 'old-pass',
        'key.k1.private': 'PEM',
      });
      const legacy = FlutterSecureStorage();
      final secrets = VaultSecretStore(
        store: store,
        master: MasterKeySource(primary: CountingVault()),
        legacy: const SecureStorageLegacy(legacy),
      );
      expect(await secrets.read('host.h1.password'), 'old-pass');
      expect(await secrets.read('key.k1.private'), 'PEM');
      expect(await legacy.readAll(), isEmpty);
      await legacy.write(key: 'late', value: 'ignored');
      final again = VaultSecretStore(
        store: store,
        master: MasterKeySource(primary: CountingVault()),
        legacy: const SecureStorageLegacy(legacy),
      );
      expect(await again.read('late'), isNull);
    },
  );
}
