import 'dart:io';

import 'package:warpgate_cli/src/secrets/platform_vault.dart';
import 'package:warpgate_core/core/data/document_store.dart';
import 'package:warpgate_core/core/data/secret_store.dart';
import 'package:warpgate_core/core/data/vault_secret_store.dart';
import 'package:warpgate_core/core/errors/exit_codes.dart';
import 'package:warpgate_core/core/platform/app_paths.dart';
import 'package:warpgate_core/ipc/ipc.dart';
class GuardedVault implements KeyVault {
  const new(this._inner, this._store);

  final KeyVault _inner;
  final DocumentStore _store;

  @override
  Future<String?> read(String name) => _inner.read(name);

  @override
  Future<void> write(String name, String value) async {
    final existing = await _store.all(VaultSecretStore.collection, limit: 1);
    if (existing.isNotEmpty) {
      throw const VaultUnavailable(
        'Saved secrets exist, but their key could not be read from secure storage',
      );
    }
    await _inner.write(name, value);
  }
}

class IpcSecretStore implements SecretStore {
  const new(this._client);

  final IpcClient _client;

  @override
  Future<String?> read(String key) async =>
      (await _client.call('secret.read', {'key': key}))['value'] as String?;

  @override
  Future<void> write(String key, String value) =>
      _client.call('secret.write', {'key': key, 'value': value});

  @override
  Future<void> delete(String key) => _client.call('secret.delete', {'key': key});
}

class ProfileKeyVault implements KeyVault {
  const new(this._inner, this._account);

  final KeyVault _inner;
  final String _account;

  @override
  Future<String?> read(String name) => _inner.read(_account);

  @override
  Future<void> write(String name, String value) => _inner.write(_account, value);
}

class CliSecrets implements SecretStore {
  new({
    required this.store,
    required this.paths,
    required this.client,
    Map<String, String>? environment,
  }) : _environment = environment ?? Platform.environment;

  final DocumentStore store;
  final AppPaths paths;
  final Future<IpcClient?> Function() client;
  final Map<String, String> _environment;
  SecretStore? _resolved;

  static KeyVault platformVault(AppPaths paths) {
    final vault = Platform.isMacOS
        ? MacKeychain()
        : Platform.isWindows
        ? WindowsDpapi(paths.root)
        : const LinuxSecretTool();
    return paths.profile == null
        ? vault
        : ProfileKeyVault(vault, paths.keychainAccount);
  }

  Future<SecretStore> _store() async {
    final known = _resolved;
    if (known != null) return known;
    final keyFile = _environment['WARPGATE_MASTER_KEY_FILE'];
    if (keyFile != null) {
      return _resolved = VaultSecretStore(
        store: store,
        master: MasterKeySource(primary: FileKeyVault(keyFile)),
      );
    }
    final attached = await client();
    if (attached != null) return _resolved = IpcSecretStore(attached);
    return _resolved = VaultSecretStore(
      store: store,
      master: MasterKeySource(
        primary: GuardedVault(platformVault(paths), store),
      ),
    );
  }

  Future<T> _guard<T>(Future<T> Function(SecretStore store) body) async {
    try {
      return await body(await _store());
    } on VaultUnavailable catch (error) {
      throw ActionFailure(
        error.message,
        hint: 'Open Warpgate and try again, or run warpgate doctor',
      );
    }
  }

  @override
  Future<String?> read(String key) => _guard((store) => store.read(key));

  @override
  Future<void> write(String key, String value) =>
      _guard((store) => store.write(key, value));

  @override
  Future<void> delete(String key) => _guard((store) => store.delete(key));
}
