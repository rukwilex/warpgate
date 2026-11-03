import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:warpgate_core/core/data/app_data_migration.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/vault_secret_store.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';

export 'package:warpgate_core/core/data/vault_secret_store.dart';

class StorageKeyVault implements KeyVault {
  const new(this._storage, {this.item});

  final FlutterSecureStorage _storage;
  final String? item;

  @override
  Future<String?> read(String name) => _storage.read(key: item ?? name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: item ?? name, value: value);
}

class SecureStorageLegacy implements LegacySecrets {
  const new(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
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
    final profile = AppPaths.resolve(platformRoot: '');
    final item = profile.profile == null ? null : profile.keychainAccount;
    final isolated = item != null || Platform.environment.containsKey('WARPGATE_HOME');
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
              item: item,
            )
          : StorageKeyVault(
              const FlutterSecureStorage(
                mOptions: MacOsOptions(
                  usesDataProtectionKeychain: false,
                  accountName: AppIdentity.bundleId,
                ),
              ),
              item: item,
            );
      return VaultSecretStore(
        store: store,
        master: MasterKeySource(
          primary: primary,
          fallback: signed
              ? StorageKeyVault(
                  const FlutterSecureStorage(
                    mOptions: MacOsOptions(
                      usesDataProtectionKeychain: false,
                      accountName: AppIdentity.bundleId,
                    ),
                  ),
                  item: item,
                )
              : null,
        ),
        legacy: isolated ? null : const SecureStorageLegacy(legacyMac),
        onWarning: debugPrint,
      );
    }
    const storage = FlutterSecureStorage();
    return VaultSecretStore(
      store: store,
      master: MasterKeySource(primary: StorageKeyVault(storage, item: item)),
      legacy: isolated ? null : const SecureStorageLegacy(storage),
      onWarning: debugPrint,
    );
  }
}
