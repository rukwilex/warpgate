import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:warpgate_core/core/data/app_data_migration.dart';
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
      throw VaultUnavailable('$path must be readable only by you. Run chmod 600 on it');
    }
    return (await file.readAsString()).trim();
  }

  @override
  Future<void> write(String name, String value) =>
      throw VaultUnavailable('The key file $path is read only');
}

typedef _CFStringNative = Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, Uint32);
typedef _CFString = Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _CFDataNative = Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, IntPtr);
typedef _CFData = Pointer<Void> Function(Pointer<Void>, Pointer<Uint8>, int);
typedef _CFDictNative = Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>, Pointer<Pointer<Void>>, IntPtr, Pointer<Void>, Pointer<Void>);
typedef _CFDict = Pointer<Void> Function(Pointer<Void>, Pointer<Pointer<Void>>, Pointer<Pointer<Void>>, int, Pointer<Void>, Pointer<Void>);
typedef _SecCopyNative = Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _SecCopy = int Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef _SecAddNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef _SecAdd = int Function(Pointer<Void>, Pointer<Void>);
typedef _DataLenNative = IntPtr Function(Pointer<Void>);
typedef _DataLen = int Function(Pointer<Void>);
typedef _DataPtr = Pointer<Uint8> Function(Pointer<Void>);

class MacKeychain implements KeyVault {
  new({this.service = AppIdentity.bundleId});

  static const _notFound = -25300;
  static const _utf8 = 0x08000100;

  final String service;
  final _cf = DynamicLibrary.open(
    '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
  );
  final _sec = DynamicLibrary.open(
    '/System/Library/Frameworks/Security.framework/Security',
  );

  Pointer<Void> _secConst(String name) => _sec.lookup<Pointer<Void>>(name).value;

  Pointer<Void> _cfConst(String name) => _cf.lookup<Pointer<Void>>(name).value;

  Pointer<Void> _string(String value) {
    final bytes = Native.cString(utf8.encode(value));
    final result = _cf.lookupFunction<_CFStringNative, _CFString>(
      'CFStringCreateWithCString',
    )(nullptr, bytes, _utf8);
    Native.free(bytes.cast());
    return result;
  }

  Pointer<Void> _dictionary(List<(Pointer<Void>, Pointer<Void>)> items) {
    final size = sizeOf<Pointer<Void>>() * items.length;
    final keys = Native.malloc(size).cast<Pointer<Void>>();
    final values = Native.malloc(size).cast<Pointer<Void>>();
    for (final (index, item) in items.indexed) {
      keys[index] = item.$1;
      values[index] = item.$2;
    }
    final result = _cf.lookupFunction<_CFDictNative, _CFDict>('CFDictionaryCreate')(
      nullptr,
      keys,
      values,
      items.length,
      _cf.lookup('kCFTypeDictionaryKeyCallBacks'),
      _cf.lookup('kCFTypeDictionaryValueCallBacks'),
    );
    Native.free(keys.cast());
    Native.free(values.cast());
    return result;
  }

  List<(Pointer<Void>, Pointer<Void>)> _query(String name, {required bool dataProtection}) => [
    (_secConst('kSecClass'), _secConst('kSecClassGenericPassword')),
    (_secConst('kSecAttrService'), _string(service)),
    (_secConst('kSecAttrAccount'), _string(name)),
    if (dataProtection)
      (_secConst('kSecUseDataProtectionKeychain'), _cfConst('kCFBooleanTrue')),
  ];

  String? _read(String name, {required bool dataProtection}) {
    final query = _dictionary([
      ..._query(name, dataProtection: dataProtection),
      (_secConst('kSecReturnData'), _cfConst('kCFBooleanTrue')),
    ]);
    final out = Native.malloc(sizeOf<Pointer<Void>>()).cast<Pointer<Void>>();
    final status = _sec.lookupFunction<_SecCopyNative, _SecCopy>(
      'SecItemCopyMatching',
    )(query, out);
    try {
      if (status != 0) {
        if (status == _notFound || dataProtection) return null;
        throw VaultUnavailable('The keychain refused access (code $status)');
      }
      final data = out.value;
      final length = _cf.lookupFunction<_DataLenNative, _DataLen>('CFDataGetLength')(data);
      final bytes = _cf.lookupFunction<_DataPtr, _DataPtr>('CFDataGetBytePtr')(data);
      return utf8.decode(Uint8List.fromList(bytes.asTypedList(length)));
    } finally {
      Native.free(out.cast());
    }
  }

  bool get hasItem {
    return _exists(MasterKeySource.itemName, dataProtection: true) ||
        _exists(MasterKeySource.itemName, dataProtection: false);
  }

  bool _exists(String name, {required bool dataProtection}) {
    final query = _dictionary(_query(name, dataProtection: dataProtection));
    final status = _sec.lookupFunction<_SecCopyNative, _SecCopy>(
      'SecItemCopyMatching',
    )(query, nullptr);
    return status == 0;
  }

  @override
  Future<String?> read(String name) async =>
      _read(name, dataProtection: true) ?? _read(name, dataProtection: false);

  @override
  Future<void> write(String name, String value) async {
    final bytes = utf8.encode(value);
    final buffer = Native.cString(bytes);
    final data = _cf.lookupFunction<_CFDataNative, _CFData>('CFDataCreate')(
      nullptr,
      buffer,
      bytes.length,
    );
    Native.free(buffer.cast());
    final attributes = _dictionary([
      ..._query(name, dataProtection: false),
      (_secConst('kSecValueData'), data),
    ]);
    final status = _sec.lookupFunction<_SecAddNative, _SecAdd>('SecItemAdd')(
      attributes,
      nullptr,
    );
    if (status != 0) {
      throw VaultUnavailable('The keychain refused to save (code $status)');
    }
  }
}

class LinuxSecretTool implements KeyVault {
  const new();

  static const _attribute = '${AppIdentity.bundleId}.secureStorage';
  static const _label = '${AppIdentity.bundleId}/FlutterSecureStorage';

  Future<Map<String, Object?>> _all() async {
    final ProcessResult result;
    try {
      result = await Process.run('secret-tool', ['lookup', 'account', _attribute]);
    } on ProcessException {
      throw const VaultUnavailable(
        'secret-tool is not installed. Install libsecret-tools, or keep Warpgate open',
      );
    }
    final text = result.stdout.toString().trim();
    if (result.exitCode != 0 || text.isEmpty) return {};
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  @override
  Future<String?> read(String name) async => (await _all())[name] as String?;

  @override
  Future<void> write(String name, String value) async {
    final next = {...await _all(), name: value};
    final process = await Process.start('secret-tool', [
      'store',
      '--label=$_label',
      'account',
      _attribute,
    ]);
    process.stdin.write(jsonEncode(next));
    await process.stdin.close();
    if (await process.exitCode != 0) {
      throw const VaultUnavailable('The system keyring refused to save');
    }
  }
}

final class _Blob extends Struct {
  @Uint32()
  external int size;
  external Pointer<Uint8> data;
}

typedef _ProtectNative = Int32 Function(Pointer<_Blob>, Pointer<Uint16>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Blob>);
typedef _Protect = int Function(Pointer<_Blob>, Pointer<Uint16>, Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<_Blob>);
typedef _UnprotectNative = Int32 Function(Pointer<_Blob>, Pointer<Pointer<Uint16>>, Pointer<Void>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Blob>);
typedef _Unprotect = int Function(Pointer<_Blob>, Pointer<Pointer<Uint16>>, Pointer<Void>, Pointer<Void>, Pointer<Void>, int, Pointer<_Blob>);

class WindowsDpapi implements KeyVault {
  const new(this.root);

  final String root;

  String get _path => p.join(root, 'flutter_secure_storage.dat');

  Uint8List _crypt(Uint8List input, {required bool protect}) {
    final crypt = DynamicLibrary.open('crypt32.dll');
    final source = Native.malloc(sizeOf<_Blob>()).cast<_Blob>();
    final target = Native.malloc(sizeOf<_Blob>()).cast<_Blob>();
    final buffer = Native.cString(input);
    source.ref
      ..size = input.length
      ..data = buffer;
    final ok = protect
        ? crypt.lookupFunction<_ProtectNative, _Protect>('CryptProtectData')(source, nullptr, nullptr, nullptr, nullptr, 0, target)
        : crypt.lookupFunction<_UnprotectNative, _Unprotect>('CryptUnprotectData')(source, nullptr, nullptr, nullptr, nullptr, 0, target);
    if (ok == 0) {
      throw const VaultUnavailable('Windows could not read the protected data');
    }
    return Uint8List.fromList(target.ref.data.asTypedList(target.ref.size));
  }

  Map<String, Object?> _all() {
    final file = File(_path);
    if (!file.existsSync()) return {};
    final clear = _crypt(file.readAsBytesSync(), protect: false);
    return (jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>();
  }

  @override
  Future<String?> read(String name) async => _all()[name] as String?;

  @override
  Future<void> write(String name, String value) async {
    final next = {..._all(), name: value};
    final bytes = _crypt(Uint8List.fromList(utf8.encode(jsonEncode(next))), protect: true);
    await File(_path).writeAsBytes(bytes, flush: true);
  }
}
