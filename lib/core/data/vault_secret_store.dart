import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:warpgate/core/data/app_data_migration.dart';
import 'package:warpgate/core/data/app_database.dart';
import 'package:warpgate/core/data/secret_store.dart';

abstract interface class KeyVault {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class StorageKeyVault implements KeyVault {
  const new(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}

class MasterKeySource {
  new({required this.primary, this.fallback, Random? random})
    : _random = random ?? Random.secure();

  static const itemName = 'warpgate.master-key';

  final KeyVault primary;
  final KeyVault? fallback;
  final Random _random;

  Future<List<int>>? _key;
  int _accesses = 0;

  int get accesses => _accesses;

  Future<List<int>> obtain() => _key ??= _load();

  Future<List<int>> _load() async {
    final (vault, existing) = await _readFrom();
    if (existing != null) return base64Decode(existing);
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final encoded = base64Encode(bytes);
    try {
      _accesses++;
      await vault.write(itemName, encoded);
    } on PlatformException {
      final second = fallback;
      if (second == null || identical(second, vault)) rethrow;
      _accesses++;
      await second.write(itemName, encoded);
    }
    return bytes;
  }

  Future<(KeyVault, String?)> _readFrom() async {
    try {
      _accesses++;
      return (primary, await primary.read(itemName));
    } on PlatformException {
      final second = fallback;
      if (second == null) rethrow;
      _accesses++;
      return (second, await second.read(itemName));
    }
  }
}

class VaultSecretStore implements SecretStore {
  new({required this._store, required this._master, this.legacy});

  static const collection = 'vault';
  static const metaCollection = 'vault_meta';
  static const migratedId = 'legacy-migrated';

  final DocumentStore _store;
  final MasterKeySource _master;
  final FlutterSecureStorage? legacy;
  final _cipher = AesGcm.with256bits();
  SecretKey? _secretKey;
  Future<void>? _migration;

  Future<SecretKey> _key() async =>
      _secretKey ??= SecretKey(await _master.obtain());

  Future<void> _ready() => _migration ??= _migrateLegacy();

  @override
  Future<String?> read(String key) async {
    await _ready();
    final json = await _store.get(collection, key);
    if (json == null) return null;
    final box = SecretBox.fromConcatenation(
      base64Decode(json['box']! as String),
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    try {
      final clear = await _cipher.decrypt(
        box,
        secretKey: await _key(),
        aad: utf8.encode(key),
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    await _ready();
    await _put(key, value);
  }

  Future<void> _put(String key, String value) async {
    final box = await _cipher.encrypt(
      utf8.encode(value),
      secretKey: await _key(),
      aad: utf8.encode(key),
    );
    await _store.put(collection, key, {
      'box': base64Encode(box.concatenation()),
    });
  }

  @override
  Future<void> delete(String key) async {
    await _ready();
    await _store.delete(collection, key);
  }

  Future<void> _migrateLegacy() async {
    final source = legacy;
    if (source == null) return;
    final done = await _store.get(metaCollection, migratedId);
    if (done != null) return;
    Map<String, String> items;
    try {
      items = Map.of(await source.readAll());
    } on Object catch (error) {
      debugPrint('Could not read secrets from the previous storage: $error');
      items = const {};
    }
    for (final MapEntry(:key, :value) in items.entries) {
      if (key == MasterKeySource.itemName) continue;
      await _put(key, value);
    }
    await _store.put(metaCollection, migratedId, {
      'at': DateTime.now().toIso8601String(),
      'count': items.length,
    });
    for (final key in items.keys) {
      if (key == MasterKeySource.itemName) continue;
      try {
        await source.delete(key: key);
      } on Object catch (error) {
        debugPrint('Could not remove an old secret: $error');
      }
    }
  }
}

abstract final class PlatformVault {
  static const _channel = MethodChannel('warpgate/keychain');

  static const legacyMac = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static Future<String?> _macGroup() async {
    try {
      return await _channel.invokeMethod<String>('accessGroup');
    } on Object {
      return null;
    }
  }

  static Future<VaultSecretStore> create(DocumentStore store) async {
    if (!kIsWeb && Platform.isMacOS) {
      final group = await _macGroup();
      final signed =
          group != null &&
          group.endsWith('.${AppIdentity.keychainGroup}') &&
          !group.startsWith(r'$(');
      final primary = signed
          ? StorageKeyVault(
              FlutterSecureStorage(
                mOptions: MacOsOptions(
                  groupId: group,
                  accountName: AppIdentity.bundleId,
                ),
              ),
            )
          : const StorageKeyVault(
              FlutterSecureStorage(
                mOptions: MacOsOptions(
                  usesDataProtectionKeychain: false,
                  accountName: AppIdentity.bundleId,
                ),
              ),
            );
      return VaultSecretStore(
        store: store,
        master: MasterKeySource(
          primary: primary,
          fallback: signed
              ? const StorageKeyVault(
                  FlutterSecureStorage(
                    mOptions: MacOsOptions(
                      usesDataProtectionKeychain: false,
                      accountName: AppIdentity.bundleId,
                    ),
                  ),
                )
              : null,
        ),
        legacy: legacyMac,
      );
    }
    const storage = FlutterSecureStorage();
    return VaultSecretStore(
      store: store,
      master: MasterKeySource(primary: const StorageKeyVault(storage)),
      legacy: storage,
    );
  }
}

class DeferredSecretStore implements SecretStore {
  new(this._inner);

  final Future<SecretStore> _inner;

  @override
  Future<String?> read(String key) => _inner.then((store) => store.read(key));

  @override
  Future<void> write(String key, String value) =>
      _inner.then((store) => store.write(key, value));

  @override
  Future<void> delete(String key) => _inner.then((store) => store.delete(key));
}
