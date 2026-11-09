import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart' show SftpAbortError;
import 'package:warpgate_core/core/diagnostics/live_objects.dart';
import 'package:warpgate_core/features/connection/domain/ssh_client.dart';
import 'package:warpgate_core/features/connection/engine/native/native_engine.dart';
import 'package:warpgate_core/src/engine/api/sftp.dart' as rs;

SftpFileAttrs _attrs(rs.SftpAttrs a) => SftpFileAttrs(
  size: a.size?.toInt(),
  userID: a.uid,
  groupID: a.gid,
  mode: a.permissions == null ? null : SftpFileMode.value(a.permissions!),
  accessTime: a.atime,
  modifyTime: a.mtime,
);

class NativeSftpClient implements SshSftp {
  NativeSftpClient(this._sftp) {
    LiveObjects.opened('native sftp session');
  }

  final rs.SftpSession _sftp;
  bool _closed = false;

  @override
  Future<List<SftpName>> listdir(String path) => guardNative(
    () async => [
      for (final entry in await _sftp.list(path: path))
        SftpName(filename: entry.filename, longname: entry.longname, attr: _attrs(entry.attrs)),
    ],
  );

  @override
  Future<SftpFileAttrs> stat(String path, {bool followLink = true}) =>
      guardNative(() async => _attrs(await _sftp.stat(path: path, followLinks: followLink)));

  @override
  Future<void> setStat(String path, SftpFileAttrs attrs) async {
    final mode = attrs.mode;
    if (mode == null) return;
    await guardNative(() => _sftp.setPermissions(path: path, mode: mode.value));
  }

  @override
  Future<void> mkdir(String path) => guardNative(() => _sftp.mkdir(path: path));

  @override
  Future<void> rmdir(String path) => guardNative(() => _sftp.rmdir(path: path));

  @override
  Future<void> remove(String path) => guardNative(() => _sftp.remove(path: path));

  @override
  Future<void> rename(String from, String to) => guardNative(() => _sftp.rename(from: from, to: to));

  @override
  Future<String> absolute(String path) => guardNative(() => _sftp.realpath(path: path));

  @override
  Future<SshSftpFile> open(String path, {SftpFileOpenMode mode = SftpFileOpenMode.read}) async =>
      NativeSftpFile(await guardNative(() => _sftp.open(path: path, flags: mode.flag)));

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    LiveObjects.closed('native sftp session');
    try {
      await _sftp.close();
    } on Object {
      return;
    }
  }
}

class NativeSftpFile implements SshSftpFile {
  NativeSftpFile(this._file) {
    LiveObjects.opened('native sftp file');
  }

  static const chunk = 255 * 1024;
  static const window = 32;

  final rs.SftpFile _file;
  bool _closed = false;

  @override
  Stream<Uint8List> read({int? length, int offset = 0, void Function(int bytes)? onProgress}) async* {
    final end = length == null ? null : offset + length;
    final inflight = <(int, int, Future<Uint8List?>)>[];
    var next = offset;
    var delivered = 0;
    var eof = false;
    Future<Uint8List?> request(int at, int size) =>
        guardNative(() => _file.read(offset: BigInt.from(at), len: size))..ignore();
    void fill() {
      while (!eof && inflight.length < window && (end == null || next < end)) {
        final size = end == null ? chunk : (end - next).clamp(0, chunk);
        if (size == 0) break;
        inflight.add((next, size, request(next, size)));
        next += size;
      }
    }

    fill();
    while (inflight.isNotEmpty) {
      final (at, size, pending) = inflight.removeAt(0);
      final data = await pending;
      if (data == null || data.isEmpty) {
        eof = true;
        inflight.clear();
        break;
      }
      delivered += data.length;
      onProgress?.call(delivered);
      yield data;
      if (data.length < size) {
        final rest = at + data.length;
        inflight.insert(0, (rest, size - data.length, request(rest, size - data.length)));
      }
      fill();
    }
  }

  @override
  SshSftpWriter write(Stream<Uint8List> data, {int offset = 0, void Function(int total)? onProgress}) =>
      NativeSftpWriter(this, data, offset, onProgress);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    LiveObjects.closed('native sftp file');
    try {
      await _file.close();
    } on Object {
      return;
    }
  }
}

class NativeSftpWriter implements SshSftpWriter {
  NativeSftpWriter(this._owner, Stream<Uint8List> stream, int offset, void Function(int total)? onProgress)
    : _input = StreamIterator(stream) {
    unawaited(_run(offset, onProgress));
  }

  static const window = 16;

  final NativeSftpFile _owner;
  final StreamIterator<Uint8List> _input;
  final _done = Completer<void>();
  bool _aborted = false;

  Future<void> _run(int offset, void Function(int total)? onProgress) async {
    var position = offset;
    var acknowledged = 0;
    final inflight = <Future<int>>[];
    final buffer = BytesBuilder(copy: false);
    Future<void> settle(Future<int> pending) async {
      acknowledged += await pending;
      if (!_aborted) onProgress?.call(acknowledged);
    }

    Future<void> send(Uint8List data) async {
      final at = position;
      position += data.length;
      inflight.add(
        guardNative(() => _owner._file.write(offset: BigInt.from(at), data: data)).then((_) => data.length)..ignore(),
      );
      while (inflight.length >= window) {
        await settle(inflight.removeAt(0));
      }
    }

    try {
      while (!_aborted && await _input.moveNext()) {
        buffer.add(_input.current);
        while (buffer.length >= NativeSftpFile.chunk) {
          final bytes = buffer.takeBytes();
          await send(Uint8List.sublistView(bytes, 0, NativeSftpFile.chunk));
          if (bytes.length > NativeSftpFile.chunk) {
            buffer.add(Uint8List.sublistView(bytes, NativeSftpFile.chunk));
          }
        }
      }
      if (!_aborted && buffer.isNotEmpty) await send(buffer.takeBytes());
      while (inflight.isNotEmpty) {
        await settle(inflight.removeAt(0));
      }
      if (!_done.isCompleted) _done.complete();
    } on Object catch (error, stack) {
      inflight.clear();
      unawaited(_input.cancel());
      if (!_done.isCompleted) _done.completeError(error, stack);
    }
  }

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> abort() async {
    _aborted = true;
    if (!_done.isCompleted) {
      _done
        ..completeError(SftpAbortError('The transfer was cancelled'))
        ..future.ignore();
    }
    await _input.cancel();
  }
}
