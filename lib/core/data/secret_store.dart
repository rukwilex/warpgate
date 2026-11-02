import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  const new([
    this._storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

abstract final class SecretKeys {
  static String hostPassword(String hostId) => 'host.$hostId.password';
  static String privateKey(String keyId) => 'key.$keyId.private';
  static String keyPassphrase(String keyId) => 'key.$keyId.passphrase';
  static const appPin = 'app.pin';
  static const mcpToken = 'mcp.token';
}
