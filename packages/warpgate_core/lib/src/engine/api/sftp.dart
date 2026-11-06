import '../frb_generated.dart';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

abstract class SftpFile implements RustOpaqueInterface {
  Future<void> close();

  Future<Uint8List?> read({required BigInt offset, required int len});

  Future<BigInt?> size();

  Future<void> write({required BigInt offset, required List<int> data});
}

abstract class SftpSession implements RustOpaqueInterface {
  Future<void> close();

  Future<List<SftpEntry>> list({required String path});

  Future<void> mkdir({required String path});

  Future<SftpFile> open({required String path, required int flags});

  Future<String> realpath({required String path});

  Future<void> remove({required String path});

  Future<void> rename({required String from, required String to});

  Future<void> rmdir({required String path});

  Future<void> setPermissions({required String path, required int mode});

  Future<SftpAttrs> stat({required String path, required bool followLinks});
}

class SftpAttrs {
  final BigInt? size;
  final int? uid;
  final int? gid;
  final int? permissions;
  final int? atime;
  final int? mtime;

  const SftpAttrs({
    this.size,
    this.uid,
    this.gid,
    this.permissions,
    this.atime,
    this.mtime,
  });

  @override
  int get hashCode =>
      size.hashCode ^
      uid.hashCode ^
      gid.hashCode ^
      permissions.hashCode ^
      atime.hashCode ^
      mtime.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SftpAttrs &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          uid == other.uid &&
          gid == other.gid &&
          permissions == other.permissions &&
          atime == other.atime &&
          mtime == other.mtime;
}

class SftpEntry {
  final String filename;
  final String longname;
  final SftpAttrs attrs;

  const SftpEntry({
    required this.filename,
    required this.longname,
    required this.attrs,
  });

  @override
  int get hashCode => filename.hashCode ^ longname.hashCode ^ attrs.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SftpEntry &&
          runtimeType == other.runtimeType &&
          filename == other.filename &&
          longname == other.longname &&
          attrs == other.attrs;
}
