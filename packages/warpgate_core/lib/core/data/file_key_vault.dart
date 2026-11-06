import 'dart:io';

import 'package:warpgate_core/core/data/vault_secret_store.dart';
import 'package:warpgate_core/core/platform/native.dart';

class VaultUnavailable implements Exception {
  const new(this.message);

  final String message;

  @override
  String toString() => message;
}

class FileKeyVault implements KeyVault {
  const new(this.path);

  final String path;

  @override
  Future<String?> read(String name) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw VaultUnavailable('The key file $path does not exist');
    }
    final mode = Native.modeOf(path);
    if (mode != null && mode & 63 != 0) {
      throw VaultUnavailable(
        '$path must be readable only by you. Run chmod 600 on it',
      );
    }
    return (await file.readAsString()).trim();
  }

  @override
  Future<void> write(String name, String value) =>
      throw VaultUnavailable('The key file $path is read only');
}
