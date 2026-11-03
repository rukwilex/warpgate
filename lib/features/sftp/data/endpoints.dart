import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:warpgate/features/sftp/domain/file_endpoint.dart';

class SftpEndpoint extends FileEndpoint {
  new(this._sftp, {required this.label});

  final SftpClient _sftp;

  @override
  final String label;

  String? _home;

  @override
  bool get isLocal => false;

  @override
  p.Context get paths => p.posix;

  @override
  Future<String> home() async => _home ??= await _sftp.absolute('.');

  FileEntry _entry(String directory, SftpName name) {
    final attrs = name.attr;
    final (owner, group) = FileEntry.ownerFromLongName(name.longname);
    return FileEntry(
      owner: owner ?? attrs.userID?.toString(),
      group: group ?? attrs.groupID?.toString(),
      name: name.filename,
      path: paths.join(directory, name.filename),
      isDirectory: attrs.isDirectory,
      isLink: attrs.isSymbolicLink,
      size: attrs.size ?? 0,
      modified: attrs.modifyTime == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000),
      mode: attrs.mode?.value,
    );
  }

  @override
  Future<List<FileEntry>> list(String directory) async {
    final names = await _guard(() => _sftp.listdir(directory));
    final entries = <FileEntry>[];
    for (final name in names) {
      if (name.filename == '.' || name.filename == '..') continue;
      var entry = _entry(directory, name);
      if (entry.isLink) {
        try {
          final target = await _sftp.stat(entry.path);
          entry = FileEntry(
            name: entry.name,
            path: entry.path,
            isDirectory: target.isDirectory,
            isLink: true,
            size: target.size ?? 0,
            modified: entry.modified,
            mode: target.mode?.value,
            owner: entry.owner,
            group: entry.group,
          );
        } on Object {
          entries.add(entry);
          continue;
        }
      }
      entries.add(entry);
    }
    return entries;
  }

  @override
  Future<FileEntry?> stat(String path) async {
    try {
      final attrs = await _sftp.stat(path);
      return FileEntry(
        name: paths.basename(path),
        path: path,
        isDirectory: attrs.isDirectory,
        size: attrs.size ?? 0,
        modified: attrs.modifyTime == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(attrs.modifyTime! * 1000),
        mode: attrs.mode?.value,
      );
    } on SftpStatusError {
      return null;
    }
  }

  @override
  Future<void> createDirectory(String path) => _guard(() => _sftp.mkdir(path));

  @override
  Future<void> rename(String from, String to) =>
      _guard(() => _sftp.rename(from, to));

  @override
  Future<void> deleteFile(String path) => _guard(() => _sftp.remove(path));

  @override
  Future<void> removeEmptyDirectory(String path) =>
      _guard(() => _sftp.rmdir(path));

  @override
  Future<void> setMode(String path, int mode) => _guard(
    () => _sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode))),
  );

  @override
  Stream<Uint8List> read(String path, {int offset = 0}) async* {
    final file = await _guard(() => _sftp.open(path));
    try {
      yield* file.read(offset: offset);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  }) async {
    final mode = offset == 0
        ? SftpFileOpenMode.create |
              SftpFileOpenMode.write |
              SftpFileOpenMode.truncate
        : SftpFileOpenMode.create | SftpFileOpenMode.write;
    final file = await _guard(() => _sftp.open(path, mode: mode));
    try {
      final writer = file.write(data, offset: offset, onProgress: onProgress);
      cancel?.onCancel(() => unawaited(writer.abort()));
      await writer.done;
      cancel?.throwIfCancelled();
    } finally {
      await file.close();
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on SftpStatusError catch (error) {
      throw FileOperationException(_describe(error));
    }
  }

  static String _describe(SftpStatusError error) => switch (error.code) {
    2 => 'No such file or folder',
    3 => 'Permission denied',
    4 =>
      error.message.isEmpty
          ? 'The server could not complete this action'
          : error.message,
    _ => error.message,
  };
}

class LocalEndpoint extends FileEndpoint {
  new({this.label = 'This device'});

  @override
  final String label;

  @override
  bool get isLocal => true;

  @override
  p.Context get paths => p.context;

  @override
  Future<String> home() async {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home != null && !Platform.isIOS && !Platform.isAndroid) return home;
    return (await getApplicationDocumentsDirectory()).path;
  }

  @override
  Future<List<FileEntry>> list(String directory) async {
    final entries = <FileEntry>[];
    try {
      await for (final item in Directory(directory).list(followLinks: false)) {
        final entry = await _describe(item.path);
        if (entry != null) entries.add(entry);
      }
    } on FileSystemException catch (error) {
      throw FileOperationException(_message(error));
    }
    return entries;
  }

  Future<FileEntry?> _describe(String path) async {
    final type = FileSystemEntity.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    final isLink = type == FileSystemEntityType.link;
    final stat = await FileStat.stat(path);
    return FileEntry(
      name: paths.basename(path),
      path: path,
      isDirectory: stat.type == FileSystemEntityType.directory,
      isLink: isLink,
      size: stat.size < 0 ? 0 : stat.size,
      modified: stat.modified,
      mode: stat.mode & 0xFFF,
    );
  }

  @override
  Future<FileEntry?> stat(String path) => _describe(path);

  @override
  Future<void> createDirectory(String path) =>
      _guard(() => Directory(path).create());

  @override
  Future<void> rename(String from, String to) async {
    final type = FileSystemEntity.typeSync(from, followLinks: false);
    await _guard(
      () => type == FileSystemEntityType.directory
          ? Directory(from).rename(to)
          : File(from).rename(to),
    );
  }

  @override
  Future<void> deleteFile(String path) => _guard(() => File(path).delete());

  @override
  Future<void> deleteDirectory(String path) =>
      _guard(() => Directory(path).delete(recursive: true));

  @override
  Future<void> removeEmptyDirectory(String path) =>
      _guard(() => Directory(path).delete());

  @override
  Future<void> setMode(String path, int mode) async {
    if (Platform.isWindows) return;
    await Process.run('chmod', [(mode & 0xFFF).toRadixString(8), path]);
  }

  @override
  Stream<Uint8List> read(String path, {int offset = 0}) =>
      File(path).openRead(offset).map(Uint8List.fromList);

  @override
  Future<void> write(
    String path,
    Stream<Uint8List> data, {
    int offset = 0,
    void Function(int written)? onProgress,
    CancelToken? cancel,
  }) async {
    final file = await File(path)
        .open(mode: offset == 0 ? FileMode.write : FileMode.append);
    try {
      if (offset > 0) await file.setPosition(offset);
      var written = offset;
      await for (final chunk in data) {
        cancel?.throwIfCancelled();
        await file.writeFrom(chunk);
        written += chunk.length;
        onProgress?.call(written - offset);
      }
      await file.flush();
    } on FileSystemException catch (error) {
      throw FileOperationException(_message(error));
    } finally {
      await file.close();
    }
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FileSystemException catch (error) {
      throw FileOperationException(_message(error));
    }
  }

  static String _message(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (code == 13 || code == 1) return 'Permission denied';
    if (code == 2) return 'No such file or folder';
    if (code == 17) return 'Something with this name already exists';
    if (code == 66 || code == 39) return 'The folder is not empty';
    return error.osError?.message ?? error.message;
  }
}
